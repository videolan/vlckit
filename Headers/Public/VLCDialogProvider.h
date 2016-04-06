/*****************************************************************************
 * VLCDialogProvider.h: an implementation of the libvlc dialog API
 *****************************************************************************
 * Copyright (C) 2016 VideoLabs SAS
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
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

@class VLCLibrary;

typedef NS_ENUM(NSUInteger, VLCDialogQuestionType) {
    VLCDialogQuestionNormal,
    VLCDialogQuestionWarning,
    VLCDialogQuestionCritical,
};

@protocol VLCCustomDialogRendererProtocol <NSObject>

/**
 * called when VLC wants to show an error
 * \param the dialog title
 * \param the error message
 */
- (void)showErrorWithTitle:(NSString * _Nonnull)error
      message:(NSString * _Nonnull)message;

/**
 * called when user logs in to something
 * If VLC includes a keychain module for your platform, a user can store stuff
 * \param login title
 * \param an explaining message
 * \param a default username within context
 * \param indicator whether storing is even a possibility
 * \param reference you need to send the results to
 */
- (void)showLoginWithTitle:(NSString * _Nonnull)title
                   message:(NSString * _Nonnull)message
           defaultUsername:(NSString * _Nullable)username
          askingForStorage:(BOOL)askingForStorage
             withReference:(NSValue * _Nonnull)reference;

/**
 * called when VLC needs the user to decide something
 * \param the dialog title
 * \param an explaining message text
 * \param a question type
 * \param cancel button text
 * \param action 1 text
 * \param action 2 text
 * \param reference you need to send the action to
 */
- (void)showQuestionWithTitle:(NSString * _Nonnull)title
                      message:(NSString * _Nonnull)message
                         type:(VLCDialogQuestionType)questionType
                 cancelString:(NSString * _Nullable)cancelString
                action1String:(NSString * _Nullable)action1String
                action2String:(NSString * _Nullable)action2String
                withReference:(NSValue * _Nonnull)reference;

/**
 * called when VLC wants to show some progress
 * \param the dialog title
 * \param an explaining message
 * \param indicator whether progress indeterminate
 * \param initial progress position
 * \param optional string for cancel button if operation is cancellable
 * \param reference VLC will include in updates
 */
- (void)showProgressWithTitle:(NSString * _Nonnull)title
                      message:(NSString * _Nonnull)message
              isIndeterminate:(BOOL)isIndeterminate
                     position:(float)position
                 cancelString:(NSString * _Nullable)cancelString
                withReference:(NSValue * _Nonnull)reference;

/** called when VLC wants to update an existing progress dialog
 * \param reference to the existing progress dialog
 * \param updated message
 * \param current position
 */
- (void)updateProgressWithReference:(NSValue * _Nonnull)reference
                            message:(NSString * _Nullable)message
                            postion:(float)position;

/** VLC decided to destroy a dialog
 * \param reference to the dialog to destroy
 */
- (void)cancelDialogWithReference:(NSValue * _Nonnull)reference;

@end

@interface VLCDialogProvider : NSObject

/**
 * initializer method to run the dialog provider instance on a specific library instance
 *
 * \param the library instance
 * \param enable custom UI mode
 * \note if library param is NULL, [VLCLibrary sharedLibrary] will be used
 * \return the dialog provider instance, can be NULL on malloc failures
 */
- (instancetype _Nullable)initWithLibrary:(VLCLibrary * _Nullable)library
                                 customUI:(BOOL)customUI;

/**
 * initializer method to run the dialog provider instance on a specific library instance
 *
 * \param an object implementing the custom dialog rendering API
 * \return the object set
 */
@property (weak, readwrite, nonatomic, nullable) id<VLCCustomDialogRendererProtocol> customRenderer;

/**
 * if you requested custom UI mode for dialogs, use this method respond to a login dialog
 * \param username or NULL if cancelled
 * \param password or NULL if cancelled
 * \param reference to the dialog you respond to
 * \param shall VLC store the login securely?
 * \note This method does not have any effect if you don't use custom UI mode */
- (void)postUsername:(NSString * _Nonnull)username
         andPassword:(NSString * _Nonnull)password
  forDialogReference:(NSValue * _Nonnull)dialogReference
               store:(BOOL)store;

/**
 * if you requested custom UI mode for dialogs, use this method respond to a question dialog
 * \param the button number the user pressed, use 3 if s/he cancelled, otherwise respectively 1 or 2 depending on the selected action
 * \param reference to the dialog you respond to
 * \note This method does not have any effect if you don't use custom UI mode */
- (void)postAction:(int)buttonNumber
forDialogReference:(NSValue * _Nonnull)dialogReference;

/**
 * if you requested custom UI mode for dialogs, use this method to cancel a progress dialog
 * \param reference to the dialog you want to cancel
 * \note This method does not have any effect if you don't use custom UI mode */
- (void)dismissDialogWithReference:(NSValue * _Nonnull)dialogReference;

@end
