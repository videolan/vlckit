/*****************************************************************************
 * VLCEventManager.m: VLCKit.framework VLCEventManager implementation
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2007 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCEventManager.h"
#import <pthread.h>

/**
 * Defines the type of interthread message on the queue.
 */
typedef enum
{
    VLCNotification,                //< Standard NSNotification.
    VLCObjectMethodWithObjectArg,   //< Method with an object argument.
    VLCObjectMethodWithArrayArg     //< Method with an array argument.
} message_type_t;

/**
 * Data structured used to enqueue messages onto the queue.
 */
@interface message_t : NSObject

@property (nonatomic) id target;    //< Target object that should receive the message (retained until method is called).
@property (nonatomic) SEL sel;      //< A selector that identifies the message to be sent to the target.
@property (nonatomic, copy) NSString * name;           //< Name to be used for NSNotification
@property (nonatomic) id object;                  //< Object argument to pass to the target via the selector.
@property (nonatomic) message_type_t type;            //< Type of queued message.

@end

@implementation message_t

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[message_t class]]) return NO;

    message_t *otherObject = object;
    BOOL notificatonMatches =
        (otherObject.type == VLCNotification              && [otherObject.name isEqualToString:self.name]) ||
        (otherObject.type == VLCObjectMethodWithArrayArg  && [otherObject.object isEqual:self.object]) ||
        (otherObject.type == VLCObjectMethodWithObjectArg && [otherObject.object isEqual:self.object]);

    return [otherObject.target isEqual:_target] &&
            otherObject.sel == self.sel         &&
            otherObject.type == self.type       &&
            notificatonMatches;
}

@end

@interface VLCEventManager (Private)
- (void)callDelegateOfObjectAndSendNotificationWithArgs:(message_t *)message;
- (void)callObjectMethodWithArgs:(message_t *)message;
- (void)callDelegateOfObject:(id)aTarget withDelegateMethod:(SEL)aSelector withNotificationName:(NSString *)aNotificationName;
- (pthread_cond_t *)signalData;
- (pthread_mutex_t *)queueLock;
- (NSMutableArray *)messageQueue;
- (NSMutableArray *)pendingMessagesOnMainThread;
- (NSLock *)pendingMessagesLock;

- (void)addMessageToHandleOnMainThread:(message_t *)message;
@end

/**
 * Provides a function for the main entry point for the dispatch thread. It dispatches any messages that is queued.
 * \param user_data Pointer to the VLCEventManager instance that instiated this thread.
 */
static void * EventDispatcherMainLoop(void * user_data)
{
    VLCEventManager * self = (__bridge VLCEventManager *)(user_data);

    for (;;) {
            message_t * message, * message_newer = NULL;

            /* Sleep a bit not to flood the interface */
            usleep(300);

            /* Wait for some data */

            pthread_mutex_lock([self queueLock]);
            /* Wait until we have something on the queue */
            while ([[self messageQueue] count] <= 0)
                pthread_cond_wait([self signalData], [self queueLock]);

            /* Get the first object off the queue. */
            message = [[self messageQueue] lastObject];    // Released in 'call'
            [[self messageQueue] removeLastObject];

            /* Remove duplicate notifications (keep the newest one). */
            if (message.type == VLCNotification) {
                NSInteger last_match_msg = -1;
                for (NSInteger i = [[self messageQueue] count]-1; i >= 0; i--) {
                    message_newer = [self messageQueue][i];
                    if (message_newer.type == VLCNotification &&
                        message_newer.target == message.target &&
                        [message_newer.name isEqualToString:message.name]) {
                        if (last_match_msg >= 0) {
                            [[self messageQueue] removeObjectAtIndex:last_match_msg];
                        }
                        last_match_msg = i;
                    }
                }
                if (last_match_msg >= 0) {
                    // newer notification detected, ignore current one
                    pthread_mutex_unlock([self queueLock]);
                    continue;
                }
            } else if (message.type == VLCObjectMethodWithArrayArg) {
                NSMutableArray * newArg = nil;

                /* Collapse messages that takes array arg by sending one bigger array */
                for (NSInteger i = [[self messageQueue] count] - 1; i >= 0; i--) {
                    message_newer = [self messageQueue][i];
                    if (message_newer.type == VLCObjectMethodWithArrayArg &&
                        message_newer.target == message.target &&
                        message_newer.sel == message.sel) {
                        if (!newArg) {
                            newArg = [NSMutableArray arrayWithArray:message.object];
                        }

                        [newArg addObjectsFromArray:message_newer.object];
                        [[self messageQueue] removeObjectAtIndex:i];
                    }
                    /* It shouldn be a good idea not to collapse event with other kind of event in-between.
                     * This could be particulary problematic when the same object receive two related events
                     * (for instance Added and Removed).
                     * Ignore for now only if target is the same */
                    else if (message_newer.target == message.target)
                        break;
                }

                if (newArg)
                    message.object = newArg;
            }
            [self addMessageToHandleOnMainThread:message];

            pthread_mutex_unlock([self queueLock]);

            if (message.type == VLCNotification)
                [self performSelectorOnMainThread:@selector(callDelegateOfObjectAndSendNotificationWithArgs:)
                                       withObject:message
                                    waitUntilDone: NO];
            else
                [self performSelectorOnMainThread:@selector(callObjectMethodWithArgs:)
                                       withObject:message
                                    waitUntilDone: YES];
        }
    return nil;
}

@implementation VLCEventManager
+ (id)sharedManager
{
    static dispatch_once_t onceToken;
    static VLCEventManager *defaultManager = nil;
    dispatch_once(&onceToken, ^{
        defaultManager = [[VLCEventManager alloc] init];
    });

    return defaultManager;
}

- (void)dummy
{
    /* Put Cocoa in multithreaded mode by calling a dummy function */
}

- (id)init
{
    if (self = [super init]) {
        if (![NSThread isMultiThreaded]) {
            [NSThread detachNewThreadSelector:@selector(dummy) toTarget:self withObject:nil];
            NSAssert([NSThread isMultiThreaded], @"Can't put Cocoa in multithreaded mode");
        }

        messageQueue = [NSMutableArray new];
        pendingMessagesOnMainThread = [NSMutableArray new];
        pendingMessagesLock = [[NSLock alloc] init];

        pthread_mutex_init(&queueLock, NULL);
        pthread_cond_init(&signalData, NULL);
        pthread_create(&dispatcherThread, NULL, EventDispatcherMainLoop, (__bridge void *)(self));
    }
    return self;
}

- (void)dealloc
{
    pthread_kill(dispatcherThread, SIGKILL);
    pthread_join(dispatcherThread, NULL);
}

- (void)callOnMainThreadDelegateOfObject:(id)aTarget withDelegateMethod:(SEL)aSelector withNotificationName:(NSString *)aNotificationName
{
    /* Don't send on main thread before this gets sorted out */
    @autoreleasepool {
        message_t *message = [message_t new];
        message.sel = aSelector;
        message.target = aTarget;
        message.name = aNotificationName;
        message.type = VLCNotification;

        pthread_mutex_lock([self queueLock]);
        [[self messageQueue] insertObject:message atIndex:0];
        pthread_cond_signal([self signalData]);
        pthread_mutex_unlock([self queueLock]);
    }
}

- (void)callOnMainThreadObject:(id)aTarget withMethod:(SEL)aSelector withArgumentAsObject:(id)arg
{
    @autoreleasepool {
        message_t *message = [message_t new];
        message.sel = aSelector;
        message.target = aTarget;
        message.object = arg;
        message.type = [arg isKindOfClass:[NSArray class]] ? VLCObjectMethodWithArrayArg : VLCObjectMethodWithObjectArg;

        pthread_mutex_lock([self queueLock]);
        [[self messageQueue] insertObject:message atIndex:0];
        pthread_cond_signal([self signalData]);
        pthread_mutex_unlock([self queueLock]);
    }
}

- (void)cancelCallToObject:(id)target
{

    // Remove all queued message
    pthread_mutex_lock([self queueLock]);
    [pendingMessagesLock lock];

    NSMutableArray *queue = [self messageQueue];
    for (NSInteger i = [queue count] - 1; i >= 0; i--) {
        message_t *message = (message_t *)queue[i];
        if (message.target == target)
            [queue removeObjectAtIndex:i];
    }

    // Remove all pending messages
    NSMutableArray *messages = pendingMessagesOnMainThread;
    // need to interate in reverse since we are removing objects
    for (NSInteger i = [messages count] - 1; i >= 0; i--) {
        message_t *message = messages[i];

        if (message.target == target)
            [messages removeObjectAtIndex:i];
    }

    [pendingMessagesLock unlock];
    pthread_mutex_unlock([self queueLock]);
}
@end

@implementation VLCEventManager (Private)

- (void)addMessageToHandleOnMainThread:(message_t *)message
{
    [pendingMessagesLock lock];
    [pendingMessagesOnMainThread addObject:message];
    [pendingMessagesLock unlock];

}

- (BOOL)markMessageHandledOnMainThreadIfExists:(message_t *)message
{
    [pendingMessagesLock lock];
    BOOL cancelled = ![pendingMessagesOnMainThread containsObject:message];
    if (!cancelled) {
        [pendingMessagesOnMainThread removeObject:message];
    }
    [pendingMessagesLock unlock];

    return !cancelled;
}

- (void)callDelegateOfObjectAndSendNotificationWithArgs:(message_t *)message
{
    // Check that we were not cancelled, ie, target was released
    if ([self markMessageHandledOnMainThreadIfExists:message])
        [self callDelegateOfObject:message.target withDelegateMethod:message.sel withNotificationName:message.name];

}

- (void)callObjectMethodWithArgs:(message_t *)message
{
    // Check that we were not cancelled
    if ([self markMessageHandledOnMainThreadIfExists:message]) {
        void (*method)(id, SEL, id) = (void (*)(id, SEL, id))[message.target methodForSelector: message.sel];
        method(message.target, message.sel, message.object);
    }
}

- (void)callDelegateOfObject:(id)aTarget withDelegateMethod:(SEL)aSelector withNotificationName:(NSString *)aNotificationName
{
    [[NSNotificationCenter defaultCenter] postNotification: [NSNotification notificationWithName:aNotificationName object:aTarget]];

    id delegate = [aTarget delegate];
    if (!delegate || ![delegate respondsToSelector:aSelector])
        return;

    void (*method)(id, SEL, id) = (void (*)(id, SEL, id))[delegate methodForSelector: aSelector];
    method(delegate, aSelector, [NSNotification notificationWithName:aNotificationName object:aTarget]);
}

- (NSMutableArray *)messageQueue
{
    return messageQueue;
}

- (NSMutableArray *)pendingMessagesOnMainThread
{
    return pendingMessagesOnMainThread;
}

- (NSLock *)pendingMessagesLock
{
    return pendingMessagesLock;
}


- (pthread_cond_t *)signalData
{
    return &signalData;
}

- (pthread_mutex_t *)queueLock
{
    return &queueLock;
}
@end
