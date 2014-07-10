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

@property (nonatomic, strong) id target;    //< Target object that should receive the message (retained until method is called).
@property (nonatomic) SEL sel;      //< A selector that identifies the message to be sent to the target.
@property (nonatomic, copy) NSString * name;           //< Name to be used for NSNotification
@property (nonatomic, strong) id object;                  //< Object argument to pass to the target via the selector.
@property (nonatomic) message_type_t type;            //< Type of queued message.

@end

@implementation message_t

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[message_t class]]) return NO;

    message_t *otherObject = object;
    BOOL notificationMatches =
        (otherObject.type == VLCNotification              && [otherObject.name isEqualToString:self.name]) ||
        (otherObject.type == VLCObjectMethodWithArrayArg  && [otherObject.object isEqual:self.object]) ||
        (otherObject.type == VLCObjectMethodWithObjectArg && [otherObject.object isEqual:self.object]);

    return [otherObject.target isEqual:_target] &&
            otherObject.sel == self.sel         &&
            otherObject.type == self.type       &&
            notificationMatches;
}

@end

@interface VLCEventManager ()
{
    NSMutableArray *_messageQueue;      //< Holds a queue of messages.
    NSMutableArray *_pendingMessagesOnMainThread;   //< Holds the message that are being posted on main thread.
    NSLock          *_pendingMessagesLock;
    pthread_t        _dispatcherThread;  //< Thread responsible for dispatching messages.
    pthread_mutex_t  _queueLock;         //< Queue lock.
    pthread_cond_t   _signalData;        //< Data lock.
}

- (void)startEventLoop;

- (void)callDelegateOfObjectAndSendNotificationWithArgs:(message_t *)message;
- (void)callObjectMethodWithArgs:(message_t *)message;
- (void)callDelegateOfObject:(id)aTarget withDelegateMethod:(SEL)aSelector withNotificationName:(NSString *)aNotificationName;
- (pthread_cond_t *)signalData;
- (pthread_mutex_t *)queueLock;

- (void)addMessageToHandleOnMainThread:(message_t *)message;

@end

/**
 * Provides a function for the main entry point for the dispatch thread. It dispatches any messages that is queued.
 * \param user_data Pointer to the VLCEventManager instance that instiated this thread.
 */
static void * EventDispatcherMainLoop(void * user_data)
{
    VLCEventManager * self = (__bridge VLCEventManager *)(user_data);

    [self startEventLoop];

    return NULL;
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

        _messageQueue = [NSMutableArray new];
        _pendingMessagesOnMainThread = [NSMutableArray new];
        _pendingMessagesLock = [[NSLock alloc] init];

        pthread_mutex_init(&_queueLock, NULL);
        pthread_cond_init(&_signalData, NULL);
        pthread_create(&_dispatcherThread, NULL, EventDispatcherMainLoop, (__bridge void *)(self));
    }
    return self;
}

- (void)dealloc
{
    pthread_kill(_dispatcherThread, SIGKILL);
    pthread_join(_dispatcherThread, NULL);
}

#pragma mark -

- (void)startEventLoop {
    for (;;) {
        @autoreleasepool {
            message_t * message, * message_newer = NULL;

            /* Wait for some data */

            /* Wait until we have something on the queue */
            pthread_mutex_lock([self queueLock]);
            while (_messageQueue.count <= 0)
                pthread_cond_wait([self signalData], [self queueLock]);

            /* Get the first object off the queue. */
            message = [_messageQueue lastObject];    // Released in 'call'
            [_messageQueue removeLastObject];

            /* Remove duplicate notifications (keep the newest one). */
            if (message.type == VLCNotification) {
                NSInteger last_match_msg = -1;
                for (NSInteger i = _messageQueue.count - 1; i >= 0; i--) {
                    message_newer = _messageQueue[i];
                    if (message_newer.type == VLCNotification &&
                        message_newer.target == message.target &&
                        [message_newer.name isEqualToString:message.name]) {
                        if (last_match_msg >= 0) {
                            [_messageQueue removeObjectAtIndex:(NSUInteger) last_match_msg];
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
                for (NSInteger i = [_messageQueue count] - 1; i >= 0; i--) {
                    message_newer = _messageQueue[i];
                    if (message_newer.type == VLCObjectMethodWithArrayArg &&
                        message_newer.target == message.target &&
                        message_newer.sel == message.sel) {
                        if (!newArg) {
                            newArg = [NSMutableArray arrayWithArray:message.object];
                        }

                        [newArg addObjectsFromArray:message_newer.object];
                        [_messageQueue removeObjectAtIndex:(NSUInteger) i];
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

        /* Sleep a bit not to flood the interface */
        usleep(300);
    }
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
        [_messageQueue insertObject:message atIndex:0];
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
        [_messageQueue insertObject:message atIndex:0];
        pthread_cond_signal([self signalData]);
        pthread_mutex_unlock([self queueLock]);
    }
}

- (void)cancelCallToObject:(id)target
{
    // Remove all queued message
    pthread_mutex_lock([self queueLock]);
    [_pendingMessagesLock lock];

    for (NSInteger i = _messageQueue.count - 1; i >= 0; i--) {
        message_t *message = _messageQueue[i];
        if (message.target == target)
            [_messageQueue removeObjectAtIndex:i];
    }

    // Remove all pending messages
    NSMutableArray *messages = _pendingMessagesOnMainThread;
    // need to interate in reverse since we are removing objects
    for (NSInteger i = [messages count] - 1; i >= 0; i--) {
        message_t *message = messages[i];

        if (message.target == target)
            [messages removeObjectAtIndex:(NSUInteger) i];
    }

    [_pendingMessagesLock unlock];
    pthread_mutex_unlock([self queueLock]);
}

- (void)addMessageToHandleOnMainThread:(message_t *)message
{
    [_pendingMessagesLock lock];
    [_pendingMessagesOnMainThread addObject:message];
    [_pendingMessagesLock unlock];

}

- (BOOL)markMessageHandledOnMainThreadIfExists:(message_t *)message
{
    [_pendingMessagesLock lock];
    BOOL cancelled = ![_pendingMessagesOnMainThread containsObject:message];
    if (!cancelled) {
        [_pendingMessagesOnMainThread removeObject:message];
    }
    [_pendingMessagesLock unlock];

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

- (pthread_cond_t *)signalData
{
    return &_signalData;
}

- (pthread_mutex_t *)queueLock
{
    return &_queueLock;
}

@end
