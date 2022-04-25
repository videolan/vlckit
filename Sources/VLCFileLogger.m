//
//  VLCFileLogger.m
//  MobileVLCKit
//
//  Created by umxprime on 25/04/2022.
//

#import <VLCFileLogger.h>
#import <VLCLogMessageFormatter.h>

@implementation VLCFileLogger

@synthesize level;

+ (instancetype)createWithFileHandle:(NSFileHandle *)fileHandle {
    return  [[self alloc] initWithFileHandle:fileHandle];
}

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle {
    self = [super init];
    if (!self) return nil;
    _fileHandle = fileHandle;
    _formatter = [VLCLogMessageFormatter new];
    return self;
}

- (void)handleMessage:(nonnull NSString *)message
             logLevel:(VLCLogLevel)level
              context:(VLCLogContext * _Nullable)context {
    NSString *formattedMessage = [_formatter formatWithMessage:message logLevel:level context:context];
    [_fileHandle writeData:[formattedMessage dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
