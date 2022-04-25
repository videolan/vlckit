//
//  VLCFileLogger.h
//  MobileVLCKit
//
//  Created by umxprime on 25/04/2022.
//

#import <Foundation/Foundation.h>

#import "VLCLogging.h"

NS_ASSUME_NONNULL_BEGIN

@interface VLCFileLogger : NSObject<VLCLogging>

@property (nonatomic, readonly) NSFileHandle *fileHandle;

@property (nonatomic, readonly) id<VLCLogMessageFormatting> formatter;

+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)createWithFileHandle:(NSFileHandle *)fileHandle;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle;
@end

NS_ASSUME_NONNULL_END
