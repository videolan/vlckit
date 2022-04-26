/*****************************************************************************
 * VLCLogging.h: [Mobile/TV]VLCKit.framework VLCLogging header
 *****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Maxime Chapelet <umxprime # videolabs.io>
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

#ifndef VLCLogging_h
#define VLCLogging_h

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int, VLCLogLevel) {
    kVLCLogLevelError = 0,
    kVLCLogLevelWarning,
    kVLCLogLevelInfo,
    kVLCLogLevelDebug
};

@interface VLCLogContext: NSObject
/**
 * Emitter (temporarily) unique object ID or 0
 */
@property (nonatomic, readonly) uintptr_t objectId;

/**
 * Emitter object type name
 */
@property (nonatomic, readonly) NSString *objectType;

/**
 * Emitter module
 */
@property (nonatomic, readonly) NSString *module;

/**
 * Additional header (used by VLM media) or nil
 */
@property (nonatomic, readonly, nullable) NSString *header;

/**
 * Source code file name or nil
 */
@property (nonatomic, readonly, nullable) NSString *file;

/**
 * Source code file line number or -1
 */
@property (nonatomic, readonly) int line;

/**
 * Source code calling function name or NULL
 */
@property (nonatomic, readonly, nullable) NSString *function;

/**
 * Emitter thread ID
 */
@property (nonatomic, readonly) unsigned long threadId;

@end

/**
 * Flags used by VLCLogMessageFormatting protocol's contextFlags property
 */
typedef NS_OPTIONS(int, VLCLogContextFlag) {
    kVLCLogLevelContextNone = 0,                /// Log no additionnal context
    kVLCLogLevelContextModule = 1,              /// Log responsible module and object type
    kVLCLogLevelContextFileLocation = 1<<1,     /// Log file path and line number if available
    kVLCLogLevelContextCallingFunction = 2<<1,  /// Log calling function name
    kVLCLogLevelContextCustom = 3<<1,           /// Log custom context, see -[VLCLogMessageFormatting customContext] property
    kVLCLogLevelContextAll = 0xF                /// Log all available additional context
};

@protocol VLCLogMessageFormatting <NSObject>

/**
 * Flags for detailed logging context
 * \see VLCLogContextFlag
 */
@property (readwrite, nonatomic) VLCLogContextFlag contextFlags;

/**
 * Custom infos that will be appended to log messages.
 * Ideally the customContext object should respond to the `description` selector in order to return a `NSString`
 */
@property (readwrite, nonatomic, nullable) id customContext;

- (NSString *)formatWithMessage:(NSString *)message
                       logLevel:(VLCLogLevel)level
                        context:(nullable VLCLogContext *)context;

@end

@protocol VLCLogging <NSObject>
@required
/**
 * Gets/sets the logging level
 * \see VLCLogLevel
 */
@property (readwrite, nonatomic) VLCLogLevel level;

/**
 * called when VLC wants to print a log message
 * \param message the log message
 * \param level the log level
 * \param context the log context
 */
- (void)handleMessage:(NSString *)message
             logLevel:(VLCLogLevel)level
              context:(nullable VLCLogContext *)context;
@end

NS_ASSUME_NONNULL_END

#endif /* VLCLogHandler_h */
