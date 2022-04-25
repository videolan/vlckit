//
//  VLCConsoleLogger.m
//  MobileVLCKit
//
//  Created by umxprime on 25/04/2022.
//

#import <VLCConsoleLogger.h>
#import <VLCLogMessageFormatter.h>

@implementation VLCConsoleLogger

@synthesize level;

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _formatter = [VLCLogMessageFormatter new];
    return self;
}

- (void)handleMessage:(nonnull NSString *)message
             logLevel:(VLCLogLevel)level
              context:(nullable VLCLogContext *)context {
    NSString *formattedMessage = [_formatter formatWithMessage:message
                                                      logLevel:level
                                                       context:context];
    VKLog(@"%@", formattedMessage);
}

@end
