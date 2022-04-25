//
//  VLCConsoleLogger.h
//  MobileVLCKit
//
//  Created by umxprime on 25/04/2022.
//

#import <Foundation/Foundation.h>

#import "VLCLogging.h"

NS_ASSUME_NONNULL_BEGIN

@interface VLCConsoleLogger : NSObject<VLCLogging>

@property (nonatomic, readonly) id<VLCLogMessageFormatting> formatter;

@end

NS_ASSUME_NONNULL_END
