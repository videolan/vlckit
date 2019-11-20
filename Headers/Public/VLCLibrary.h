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
#import "VLCAudio.h"
#import "VLCMediaList.h"
#import "VLCMedia.h"

@class VLCAudio;

NS_ASSUME_NONNULL_BEGIN

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
 * Enables/disables debug logging to console
 * \note NSLog is used to log messages
 */
@property (readwrite, nonatomic) BOOL debugLogging;

/**
 * Gets/sets the debug logging level
 * \note Logging level
 * 0: info/notice
 * 1: error
 * 2: warning
 * 3-4: debug
 * \note values set here will be consired only when logging to console
 * \warning If an invalid level is provided, level defaults to 0
 */
@property (readwrite, nonatomic) int debugLoggingLevel;

/**
 * Activates debug logging to a file stream
 * If the file already exists, the log will be appended by the end. If it does not exist, will be created.
 * The file will continously updated with new messages from this library instance.
 * \note It is the client app's obligation to ensure that the target file path is writable and all subfolders exist
 * \warning when enabling this feature, logging to the console or an object target will be stopped automatically
 * \return Returns NO on failure
 */
- (BOOL)setDebugLoggingToFile:(NSString *)filePath;

/**
 * Activates debug logging to an object target following the VLCLibraryLogReceiverProtocol protocol
 * The target will be continously called as new messages arrive from this library instance.
 * \warning when enabling this feature, logging to the console or a file will be stopped automatically
 */
@property (readwrite, nonatomic) id<VLCLibraryLogReceiverProtocol> debugLoggingTarget;

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

@protocol VLCLibraryLogReceiverProtocol <NSObject>
@required
/**
 * called when VLC wants to print a debug message
 * \param message the debug message
 * \param level the debug level
 */
- (void)handleMessage:(NSString *)message
           debugLevel:(int)level;
@end

NS_ASSUME_NONNULL_END
