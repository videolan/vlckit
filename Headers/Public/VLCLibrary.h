/*****************************************************************************
 * VLCLibrary.h: VLCKit.framework VLCLibrary header
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2007-2019 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
 *          Felix Paul Kühne <fkuehne # videolan.org>
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

#import <Foundation/Foundation.h>

@class VLCAudio, VLCMediaList, VLCMedia;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int, VLCLogLevel) {
    kVLCLogLevelError = 0,
    kVLCLogLevelWarning,
    kVLCLogLevelInfo,
    kVLCLogLevelDebug
};

typedef NS_OPTIONS(int, VLCLogContextFlag) {
    kVLCLogLevelContextNone = 0,
    kVLCLogLevelContextModule = 1,
    kVLCLogLevelContextFileLocation = 2,
    kVLCLogLevelContextCallingFunction = 4,
};

typedef NS_ENUM(int, VLCLogOutput) {
    kVLCLogOutputDisabled = 0,
    kVLCLogOutputConsole,
    kVLCLogOutputFile,
    kVLCLogOutputExternalHandler
};

@protocol VLCLibraryLogReceiverProtocol;

/**
 * The VLCLibrary is the base library of VLCKit.framework. This object provides a shared instance that exposes the
 * internal functionalities of libvlc and libvlc-control. The VLCLibrary object is instantiated automatically when
 * VLCKit.framework is loaded into memory.  Also, it is automatically destroyed when VLCKit.framework is unloaded
 * from memory.
 *
 * Currently, the framework does not support multiple instances of VLCLibrary.
 * Furthermore, you cannot destroy any instance of VLCLibrary; this is done automatically by the dynamic link loader.
 */
@interface VLCLibrary : NSObject

/**
 * Returns the library's shared instance
 * \return The library's shared instance
 */
+ (VLCLibrary *)sharedLibrary;

/**
 * Returns an individual instance which can be customized with options
 * \param options NSArray with NSString instance containing the options
 * \return the individual library instance
 */
 - (instancetype)initWithOptions:(NSArray *)options;

/**
 * Enables/disables logging to console
 * \note NSLog is used to log messages
 */
@property (readwrite, nonatomic) BOOL debugLogging __deprecated_msg("Use logOutput instead");

/**
 * Log output type
 * Change to enable logging
 * Defaults to kVLCLogOutputDisabled
 */
@property (readonly, nonatomic) VLCLogOutput logOutput;

- (BOOL)changeLoggingOutput:(VLCLogOutput)logOutput;

/**
 * Gets/sets the logging level
 * \note Logging level
 * 0: info/notice
 * 1: error
 * 2: warning
 * 3-4: debug
 * \note values set here will be consired only when logging to console
 * \warning If an invalid level is provided, level defaults to 0
 */
@property (readwrite, nonatomic) int debugLoggingLevel __deprecated_msg("Use logLevel instead");

/**
 * Gets/sets the logging level
 * \see VLCLogLevel
 */
@property (readwrite, nonatomic) VLCLogLevel logLevel;

/**
 * Flags for detailed logging context
 * Defaults to kVLCLogLevelContextNone
 */
@property (readwrite, nonatomic) VLCLogContextFlag logContextFlags;

/**
 * Activates debug logging to a file stream
 * If the file already exists, the log will be appended by the end. If it does not exist, will be created.
 * The file will continously updated with new messages from this library instance.
 * \param filePath The absolute path to the file where logs will be appended
 * \note It is the client app's obligation to ensure that the target file path is writable and all subfolders exist
 * \warning when enabling this feature, logging to the console or an object target will be stopped automatically
 * \return Returns NO on failure
 */
- (BOOL)setDebugLoggingToFile:(NSString *)filePath __deprecated_msg("Use enableLoggingToFile instead");

/**
 * Activates logging to a file stream
 * If the file already exists, the log will be appended by the end. If it does not exist, will be created.
 * The file will continously updated with new messages from this library instance.
 * \param filePath The absolute path to the file where logs will be appended
 * \note It is the client app's obligation to ensure that the target file path is writable and all subfolders exist
 * \warning when enabling this feature, logging to the console or an object target will be stopped automatically
 * \return Returns NO on failure
 */
- (BOOL)enableLoggingToFile:(NSString * _Nonnull)filePath;

/**
 * The file path set with -[VLCLibrary enableLoggingToFile:]
 */
@property (readonly, nonatomic, nullable) NSString *loggingFilePath;

/**
 * Activates debug logging to an object target following the VLCLibraryLogReceiverProtocol protocol
 * The target will be continously called as new messages arrive from this library instance.
 * \warning when enabling this feature, logging to the console or a file will be stopped automatically
 */
@property (readwrite, nonatomic, nullable) id<VLCLibraryLogReceiverProtocol> debugLoggingTarget __deprecated_msg("Use enableLoggingWithExternalHandler: instead");

/**
 * The object set with -[VLCLibrary enableLoggingWithExternalHandler:]
 */
@property (readonly, nonatomic, nullable) id<VLCLibraryLogReceiverProtocol> loggingExternalHandler;

/**
 * Activates debug logging to an object target following the VLCLibraryLogReceiverProtocol protocol
 * The target will be continously called as new messages arrive from this library instance.
 * \param loggingTarget The object that conforms to VLCLibraryLogReceiverProtocol
 * \warning when enabling this feature, logging to the console or a file will be stopped automatically
 * \return Returns NO on failure
 */
- (BOOL)enableLoggingWithExternalHandler:(id<VLCLibraryLogReceiverProtocol>)loggingExternalHandler;

/**
 * Returns the library's version
 * \return The library version example "0.9.0-git Grishenko"
 */
@property (readonly, copy) NSString *version;

/**
 * Returns the compiler used to build the libvlc binary
 * \return The compiler version string.
 */
@property (readonly, copy) NSString *compiler;

/**
 * Returns the library's changeset
 * \return The library version example "adfee99"
 */
@property (readonly, copy) NSString *changeset;

/**
 * Sets the application name and HTTP User Agent
 * libvlc will pass it to servers when required by protocol
 * \param readableName Human-readable application name, e.g. "FooBar player 1.2.3"
 * \param userAgent HTTP User Agent, e.g. "FooBar/1.2.3 Python/2.6.0"
 */
- (void)setHumanReadableName:(NSString *)readableName withHTTPUserAgent:(NSString *)userAgent;

/**
 * Sets meta-information about the application
 * \param identifier Java-style application identifier, e.g. "com.acme.foobar"
 * \param version Application version numbers, e.g. "1.2.3"
 * \param icon Application icon name, e.g. "foobar"
 */
- (void)setApplicationIdentifier:(NSString *)identifier withVersion:(NSString *)version andApplicationIconName:(NSString *)icon;

/**
 * libvlc instance wrapped by the VLCLibrary instance
 * \note If you want to use it, you are most likely wrong (or want to add a proper ObjC API)
 */
@property (nonatomic, assign) void *instance;

@end

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

@protocol VLCLibraryLogReceiverProtocol <NSObject>
@optional
/**
 * called when VLC wants to print a log message
 * \param message the log message
 * \param level the log level
 */
- (void)handleMessage:(NSString *)message
           debugLevel:(int)level;
@required
/**
 * called when VLC wants to print a log message
 * \param message the log message
 * \param level the debug level
 * \param context the debug level
 */
- (void)handleMessage:(NSString *)message
             logLevel:(VLCLogLevel)level
              context:(VLCLogContext * _Nullable)context;
@end

NS_ASSUME_NONNULL_END
