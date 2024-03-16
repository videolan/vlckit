/*****************************************************************************
 * VLCiOSLegacyDialogProvider.m: an implementation of the libvlc dialog API
 * Included for compatiblity with iOS 7
 *****************************************************************************
 * Copyright (C) 2009, 2014-2015, 2022 VLC authors and VideoLAN
 * Copyright (C) 2016, 2022 VideoLabs SAS
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan org>
 *          Pierre d'Herbemont <pdherbemont # videolan org>
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

#import <VLCLibrary.h>
#import <VLCiOSLegacyDialogProvider.h>

@interface VLCiOSLegacyDialogProvider ()
{
    VLCLibrary *_libraryInstance;
}

- (instancetype)initWithLibrary:(VLCLibrary *)library;
- (void)displayError:(NSArray * _Nonnull)dialogData;
- (void)displayLoginDialog:(NSArray * _Nonnull)dialogData;
- (void)displayQuestion:(NSArray * _Nonnull)dialogData;
- (void)displayProgressDialog:(NSArray * _Nonnull)dialogData;
- (void)updateDisplayedProgressDialog:(NSArray * _Nonnull)dialogData;

@end

@interface VLCBlockingAlertView : UIAlertView <UIAlertViewDelegate>

@property (copy, nonatomic) void (^completion)(BOOL, NSInteger);

- (id)initWithTitle:(NSString *)title
            message:(NSString *)message
  cancelButtonTitle:(NSString *)cancelButtonTitle
  otherButtonTitles:(NSArray *)otherButtonTitles;

@end

static void displayErrorCallback(void *p_data,
                                 const char *psz_title,
                                 const char *psz_text)
{
    @autoreleasepool {
        VLCiOSLegacyDialogProvider *dialogProvider = (__bridge VLCiOSLegacyDialogProvider *)p_data;
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
        VLCiOSLegacyDialogProvider *dialogProvider = (__bridge VLCiOSLegacyDialogProvider *)p_data;
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
        VLCiOSLegacyDialogProvider *dialogProvider = (__bridge  VLCiOSLegacyDialogProvider *)p_data;
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
        VLCiOSLegacyDialogProvider *dialogProvider = (__bridge VLCiOSLegacyDialogProvider *)p_data;
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
        // FIXME: the saddest NO-OP
        VKLog(@"%s: %lli", __PRETTY_FUNCTION__, (int64_t)p_id);
    }
}

static void updateProgressCallback(void *p_data,
                                   libvlc_dialog_id *p_id,
                                   float f_position,
                                   const char *psz_text)
{
    @autoreleasepool {
        VLCiOSLegacyDialogProvider *dialogProvider = (__bridge VLCiOSLegacyDialogProvider *)p_data;
        [dialogProvider performSelectorOnMainThread:@selector(updateDisplayedProgressDialog:)
                                         withObject:@[[NSValue valueWithPointer:p_id],
                                                      @(f_position),
                                                      toNSStr(psz_text)]
                                      waitUntilDone:NO];
    }
}

@implementation VLCiOSLegacyDialogProvider

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
    VLCBlockingAlertView *alert = [[VLCBlockingAlertView alloc] initWithTitle:dialogData[0]
                                                                      message:dialogData[1]
                                                                     delegate:nil
                                                            cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                            otherButtonTitles:nil];
    alert.completion = nil;
    [alert show];
}

- (void)displayLoginDialog:(NSArray * _Nonnull)dialogData
{
    VLCBlockingAlertView *alert = [[VLCBlockingAlertView alloc] initWithTitle:dialogData[1]
                                                                      message:dialogData[2]
                                                                     delegate:nil
                                                            cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                            otherButtonTitles:NSLocalizedString(@"Login", nil), [dialogData[4] boolValue] ? NSLocalizedString(@"Store", nil) : nil, nil];
    alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    __weak typeof(alert) weakAlert = alert;
    alert.completion = ^(BOOL cancelled, NSInteger buttonIndex) {
        if (!cancelled) {
            NSString *username = [weakAlert textFieldAtIndex:0].text;
            NSString *password = [weakAlert textFieldAtIndex:1].text;
            libvlc_dialog_post_login([dialogData[0] pointerValue],
                                     username ? [username UTF8String] : "",
                                     password ? [password UTF8String] : "",
                                     buttonIndex != alert.firstOtherButtonIndex);
        } else {
            libvlc_dialog_dismiss([dialogData[0] pointerValue]);
        }
    };
    alert.delegate = alert;
    [alert show];
}

- (void)displayQuestion:(NSArray * _Nonnull)dialogData
{
    VLCBlockingAlertView * alert = [[VLCBlockingAlertView alloc] initWithTitle:dialogData[1]
                                                                       message:dialogData[2]
                                                                      delegate:nil
                                                             cancelButtonTitle:dialogData[4]
                                                             otherButtonTitles:dialogData[5], dialogData[6], nil];
    alert.completion = ^(BOOL cancelled, NSInteger buttonIndex) {
        if (cancelled)
            libvlc_dialog_post_action([dialogData[0] pointerValue], 3);
        else
            libvlc_dialog_post_action([dialogData[0] pointerValue], (int)buttonIndex);
    };
    alert.delegate = alert;
    [alert show];
}

- (void)displayProgressDialog:(NSArray * _Nonnull)dialogData
{
    VKLog(@"%s: %@", __PRETTY_FUNCTION__, dialogData);
}

- (void)updateDisplayedProgressDialog:(NSArray * _Nonnull)dialogData
{
    VKLog(@"%s: %@", __PRETTY_FUNCTION__, dialogData);
}

@end

@implementation VLCBlockingAlertView

- (id)initWithTitle:(NSString *)title
            message:(NSString *)message
  cancelButtonTitle:(NSString *)cancelButtonTitle
  otherButtonTitles:(NSArray *)otherButtonTitles
{
    self = [self initWithTitle:title
                       message:message
                      delegate:self
             cancelButtonTitle:cancelButtonTitle
             otherButtonTitles:nil];

    if (self) {
        for (NSString *buttonTitle in otherButtonTitles)
            [self addButtonWithTitle:buttonTitle];
    }
    return self;
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (self.completion) {
        self.completion(buttonIndex == self.cancelButtonIndex, buttonIndex);
        self.completion = nil;
    }
}
@end
