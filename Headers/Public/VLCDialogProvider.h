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

- (void)showErrorWithTitle:(NSString * _Nonnull)error
      message:(NSString * _Nonnull)message;
- (void)showLoginWithTitle:(NSString * _Nonnull)title
                   message:(NSString * _Nonnull)message
           defaultUsername:(NSString * _Nullable)username
          askingForStorage:(BOOL)askingForStorage
             withReference:(NSValue * _Nonnull)reference;
- (void)showQuestionWithTitle:(NSString * _Nonnull)title
                      message:(NSString * _Nonnull)message
                         type:(VLCDialogQuestionType)questionType
                 cancelString:(NSString * _Nullable)cancelString
                action1String:(NSString * _Nullable)action1String
                action2String:(NSString * _Nullable)action2String
                withReference:(NSValue * _Nonnull)reference;
- (void)showProgressWithTitle:(NSString * _Nonnull)title
                      message:(NSString * _Nonnull)message
              isIndeterminate:(BOOL)isIndeterminate
                     position:(float)position
                 cancelString:(NSString * _Nullable)cancelString
                withReference:(NSValue * _Nonnull)reference;
- (void)updateProgressWithReference:(NSValue * _Nonnull)reference
                            message:(NSString * _Nullable)message
                            postion:(float)position;
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
- (instancetype __nullable)initWithLibrary:(VLCLibrary * __nullable)library customUI:(BOOL)customUI;

/**
 * initializer method to run the dialog provider instance on a specific library instance
 *
 * \param an object implementing the custom dialog rendering API
 * \return the object set
 */
@property (weak, readwrite, nonatomic, nullable) id<VLCCustomDialogRendererProtocol> customRenderer;

- (void)postUsername:(NSString * _Nullable)username andPassword:(NSString * _Nullable)password forDialogReference:(NSValue * _Nonnull)dialogReference store:(BOOL)store;
- (void)postAction:(int)buttonNumber forDialogReference:(NSValue * _Nonnull)dialogReference;
- (void)dismissDialogWithReference:(NSValue * _Nonnull)dialogReference;

@end
