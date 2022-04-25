//
//  VLCLogMessageFormatter.m
//  MobileVLCKit
//
//  Created by umxprime on 25/04/2022.
//

#import "VLCLogMessageFormatter.h"

@implementation VLCLogMessageFormatter

@synthesize contextFlags = _contextFlags, customContext = _customContext;

- (const NSString *)prefixFromLevel:(VLCLogLevel)level {
    switch (level)
    {
        case kVLCLogLevelInfo:
            return @"INF";
        case kVLCLogLevelError:
            return @"ERR";
        case kVLCLogLevelWarning:
            return @"WARN";
        case kVLCLogLevelDebug:
        default:
            return @"DBG";
    }
}

- (void)setCustomContext:(id)customContext {
    if (customContext) {
        _contextFlags |= kVLCLogLevelContextCustom;
    }
    _customContext = customContext;
}

- (NSString *)contextDescription:(VLCLogContext *)context {
    if (_contextFlags == kVLCLogLevelContextNone)
        return @"";
    NSString *messageContext = [NSString new];
    if (_contextFlags & kVLCLogLevelContextModule)
        messageContext = [messageContext stringByAppendingFormat:@" [%@/%@]", context.module, context.objectType];
    if (_contextFlags & kVLCLogLevelContextFileLocation)
        messageContext = [messageContext stringByAppendingFormat:@" [%@:%d]", context.file, context.line];
    if (_contextFlags & kVLCLogLevelContextCallingFunction)
        messageContext = [messageContext stringByAppendingFormat:@" [from %@]", context.function];
    if (_contextFlags & kVLCLogLevelContextCustom && _customContext && [_customContext respondsToSelector:@selector(description)])
        messageContext = [messageContext stringByAppendingFormat:@" [%@]", [_customContext description]];
    return messageContext;
}

- (nonnull NSString *)formatWithMessage:(nonnull NSString *)message
                               logLevel:(VLCLogLevel)level
                                context:(nullable VLCLogContext *)context { 
    return [NSString stringWithFormat:@"[%@] %@%@\n",
            [self prefixFromLevel:level],
            message,
            [self contextDescription:context]];
}

@end
