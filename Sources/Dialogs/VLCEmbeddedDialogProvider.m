/*****************************************************************************
 * VLCEmbeddedDialogProvider.m: an implementation of the libvlc dialog API
 *****************************************************************************
 * Copyright (C) 2016, 2022 VideoLabs SAS
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

#import <VLCEmbeddedDialogProvider.h>
#import <VLCLibrary.h>
#import <VLCiOSLegacyDialogProvider.h>
#import <VLCEmbeddedDialogProvider.h>

@interface VLCEmbeddedDialogProvider ()
{
    VLCLibrary *_libraryInstance;
}

- (void)displayError:(NSArray * _Nonnull)dialogData;
- (void)displayLoginDialog:(NSArray * _Nonnull)dialogData;
- (void)displayQuestion:(NSArray * _Nonnull)dialogData;
- (void)displayProgressDialog:(NSArray * _Nonnull)dialogData;
- (void)updateDisplayedProgressDialog:(NSArray * _Nonnull)dialogData;
- (void)dismissCurrentDialogViewController;

@end

static void displayErrorCallback(void *p_data,
                                 const char *psz_title,
                                 const char *psz_text)
{
    @autoreleasepool {
        VLCEmbeddedDialogProvider *dialogProvider = (__bridge VLCEmbeddedDialogProvider *)p_data;
        [dialogProvider performSelectorOnMainThread:@selector(displayError:)
                                         withObject:@[toNSStr(psz_title),
                                                      toNSStr(psz_text)]
                                      waitUntilDone:NO];
    }
}

static void displayLoginCallback(void *p_data,
                                 libvlc_dialog_id *p_id,
                                 const char *psz_title,
                                 const char *psz_text,
                                 const char *psz_default_username,
                                 bool b_ask_store)
{
    @autoreleasepool {
        VLCEmbeddedDialogProvider *dialogProvider = (__bridge VLCEmbeddedDialogProvider *)p_data;
        [dialogProvider performSelectorOnMainThread:@selector(displayLoginDialog:)
                                         withObject:@[[NSValue valueWithPointer:p_id],
                                                      toNSStr(psz_title),
                                                      toNSStr(psz_text),
                                                      toNSStr(psz_default_username),
                                                      @(b_ask_store)]
                                      waitUntilDone:NO];
    }
}

static void displayQuestionCallback(void *p_data,
                                    libvlc_dialog_id *p_id,
                                    const char *psz_title,
                                    const char *psz_text,
                                    libvlc_dialog_question_type i_type,
                                    const char *psz_cancel,
                                    const char *psz_action1,
                                    const char *psz_action2)
{
    @autoreleasepool {
        VLCEmbeddedDialogProvider *dialogProvider = (__bridge  VLCEmbeddedDialogProvider *)p_data;
        [dialogProvider performSelectorOnMainThread:@selector(displayQuestion:)
                                         withObject:@[[NSValue valueWithPointer:p_id],
                                                      toNSStr(psz_title),
                                                      toNSStr(psz_text),
                                                      @(i_type),
                                                      toNSStr(psz_cancel),
                                                      toNSStr(psz_action1),
                                                      toNSStr(psz_action2)]
                                      waitUntilDone:NO];
    }
}

static void displayProgressCallback(void *p_data,
                                    libvlc_dialog_id *p_id,
                                    const char *psz_title,
                                    const char *psz_text,
                                    bool b_indeterminate,
                                    float f_position,
                                    const char *psz_cancel)
{
    @autoreleasepool {
        VLCEmbeddedDialogProvider *dialogProvider = (__bridge VLCEmbeddedDialogProvider *)p_data;
        [dialogProvider performSelectorOnMainThread:@selector(displayProgressDialog:)
                                         withObject:@[[NSValue valueWithPointer:p_id],
                                                      toNSStr(psz_title),
                                                      toNSStr(psz_text),
                                                      @(b_indeterminate),
                                                      @(f_position),
                                                      toNSStr(psz_cancel)]
                                      waitUntilDone:NO];
    }
}

static void cancelCallback(void *p_data,
                           libvlc_dialog_id *p_id)
{
    @autoreleasepool {
        VLCEmbeddedDialogProvider *dialogProvider = (__bridge VLCEmbeddedDialogProvider *)p_data;
        [dialogProvider performSelectorOnMainThread:@selector(dismissCurrentDialogViewController)
                                         withObject:nil
                                      waitUntilDone:NO];
    }
}

static void updateProgressCallback(void *p_data,
                                   libvlc_dialog_id *p_id,
                                   float f_position,
                                   const char *psz_text)
{
    @autoreleasepool {
        VLCEmbeddedDialogProvider *dialogProvider = (__bridge VLCEmbeddedDialogProvider *)p_data;
        [dialogProvider performSelectorOnMainThread:@selector(updateDisplayedProgressDialog:)
                                         withObject:@[[NSValue valueWithPointer:p_id],
                                                      @(f_position),
                                                      toNSStr(psz_text)]
                                      waitUntilDone:NO];
    }
}

@implementation VLCEmbeddedDialogProvider

- (void)dealloc
{
    libvlc_dialog_set_callbacks(_libraryInstance.instance,
                                NULL,
                                NULL);
}

- (instancetype)initWithLibrary:(VLCLibrary *)library
{
    self = [super init];

    if (self != nil) {
        if (library == nil) {
            library = [VLCLibrary sharedLibrary];
        }

        _libraryInstance = library;

        /* callback setup */
        const libvlc_dialog_cbs cbs = {
            displayLoginCallback,
            displayQuestionCallback,
            displayProgressCallback,
            cancelCallback,
            updateProgressCallback
        };

        libvlc_dialog_set_callbacks(_libraryInstance.instance,
                                    &cbs,
                                    (__bridge void *)self);

        libvlc_dialog_set_error_callback(_libraryInstance.instance,
                                         &displayErrorCallback,
                                         (__bridge void *)self);
    }

    return self;
}

- (void)displayError:(NSArray * _Nonnull)dialogData
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:dialogData[0]
                                                                             message:dialogData[1]
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *action = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                     style:UIAlertActionStyleDestructive
                                                   handler:nil];
    [alertController addAction:action];
    if ([alertController respondsToSelector:@selector(setPreferredAction:)]) {
        [alertController setPreferredAction:action];
    }
    [[[[UIApplication sharedApplication].delegate.window rootViewController] presentedViewController] presentViewController:alertController
                                                                                                                   animated:YES
                                                                                                                 completion:nil];
}

- (void)displayLoginDialog:(NSArray * _Nonnull)dialogData
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:dialogData[1]
                                                                             message:dialogData[2]
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    __block UITextField *usernameField = nil;
    __block UITextField *passwordField = nil;
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        usernameField = textField;
        textField.placeholder = NSLocalizedString(@"User", nil);
        if (![dialogData[3] isEqualToString:@""])
            textField.text = dialogData[3];
    }];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.secureTextEntry = YES;
        textField.placeholder = NSLocalizedString(@"Password", nil);
        passwordField = textField;
    }];

    UIAlertAction *loginAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Login", nil)
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
                                                            NSString *username = usernameField.text;
                                                            NSString *password = passwordField.text;

                                                            libvlc_dialog_post_login([dialogData[0] pointerValue],
                                                                                     username ? [username UTF8String] : "",
                                                                                     password ? [password UTF8String] : "",
                                                                                     NO);
                                                        }];
    [alertController addAction:loginAction];
    if ([alertController respondsToSelector:@selector(setPreferredAction:)]) {
        [alertController setPreferredAction:loginAction];
    }

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction * _Nonnull action) {
                                                          libvlc_dialog_dismiss([dialogData[0] pointerValue]);
                                                      }]];
    if ([dialogData[4] boolValue]) {
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Save", nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                              NSString *username = usernameField.text;
                                                              NSString *password = passwordField.text;

                                                              libvlc_dialog_post_login([dialogData[0] pointerValue],
                                                                                       username ? [username UTF8String] : NULL,
                                                                                       password ? [password UTF8String] : NULL,
                                                                                       YES);
                                                          }]];
    }

    [[[[UIApplication sharedApplication].delegate.window rootViewController] presentedViewController] presentViewController:alertController
                                                                                                                   animated:YES
                                                                                                                 completion:nil];
}

- (void)displayQuestion:(NSArray * _Nonnull)dialogData
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:dialogData[1]
                                                                             message:dialogData[2]
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    if (![dialogData[4] isEqualToString:@""]) {
        [alertController addAction:[UIAlertAction actionWithTitle:dialogData[4]
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                              libvlc_dialog_post_action([dialogData[0] pointerValue], 3);
                                                          }]];
    }

    if (![dialogData[5] isEqualToString:@""]) {
        UIAlertAction *yesAction = [UIAlertAction actionWithTitle:dialogData[5]
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                              libvlc_dialog_post_action([dialogData[0] pointerValue], 1);
                                                          }];
        [alertController addAction:yesAction];
        if ([alertController respondsToSelector:@selector(setPreferredAction:)]) {
            [alertController setPreferredAction:yesAction];
        }
    }

    if (![dialogData[6] isEqualToString:@""]) {
        [alertController addAction:[UIAlertAction actionWithTitle:dialogData[6]
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                              libvlc_dialog_post_action([dialogData[0] pointerValue], 2);
                                                          }]];
    }

    [[[[UIApplication sharedApplication].delegate.window rootViewController] presentedViewController] presentViewController:alertController animated:YES completion:nil];
    
}

- (void)displayProgressDialog:(NSArray * _Nonnull)dialogData
{
    VKLog(@"%s: %@", __PRETTY_FUNCTION__, dialogData);
}

- (void)updateDisplayedProgressDialog:(NSArray * _Nonnull)dialogData
{
    VKLog(@"%s: %@", __PRETTY_FUNCTION__, dialogData);
}

- (void)dismissCurrentDialogViewController
{
    [[[[UIApplication sharedApplication].delegate.window rootViewController] presentedViewController] dismissViewControllerAnimated:YES completion:nil];
}

@end
