//
//  VLCLogging.h
//  MobileVLCKit
//
//  Created by umxprime on 25/04/2022.
//

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
 * Additional header (used by VLM media)
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

typedef NS_OPTIONS(int, VLCLogContextFlag) {
    kVLCLogLevelContextNone = 0,
    kVLCLogLevelContextModule = 1,
    kVLCLogLevelContextFileLocation = 2,
    kVLCLogLevelContextCallingFunction = 4,
    kVLCLogLevelContextCustom = 8,
    kVLCLogLevelContextAll = 15
};

@protocol VLCLogMessageFormatting <NSObject>

/**
 * Flags for detailed logging context
 */
@property (readwrite, nonatomic) VLCLogContextFlag contextFlags;

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
