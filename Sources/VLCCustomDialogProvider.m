/*****************************************************************************
 * VLCCustomDialogProvider.m: an implementation of the libvlc dialog API
 * Included to allow custom UIs with full flexibility
 *****************************************************************************
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

#import <VLCCustomDialogProvider.h>
#import <VLCLibrary.h>

@interface VLCCustomDialogProvider ()
{
    VLCLibrary *_libraryInstance;
}

- (void)displayError:(NSArray * _Nonnull)dialogData;
- (void)displayLoginDialog:(NSArray * _Nonnull)dialogData;
- (void)displayQuestion:(NSArray * _Nonnull)dialogData;
- (void)displayProgressDialog:(NSArray * _Nonnull)dialogData;
- (void)updateDisplayedProgressDialog:(NSArray * _Nonnull)dialogData;
- (void)cancelDialog:(NSValue *)dialogId;

@end

static void displayErrorCallback(void *p_data,
                                 const char *psz_title,
                                 const char *psz_text)
{
    @autoreleasepool {
        VLCCustomDialogProvider *dialogProvider = (__bridge VLCCustomDialogProvider *)p_data;
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
        VLCCustomDialogProvider *dialogProvider = (__bridge VLCCustomDialogProvider *)p_data;
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
        VLCCustomDialogProvider *dialogProvider = (__bridge  VLCCustomDialogProvider *)p_data;
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
        VLCCustomDialogProvider *dialogProvider = (__bridge VLCCustomDialogProvider *)p_data;
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
        VLCCustomDialogProvider *dialogProvider = (__bridge VLCCustomDialogProvider *)p_data;
        [dialogProvider performSelectorOnMainThread:@selector(cancelDialog:)
                                         withObject:[NSValue valueWithPointer:p_id]
                                      waitUntilDone:NO];
    }
}

static void updateProgressCallback(void *p_data,
                                   libvlc_dialog_id *p_id,
                                   float f_position,
                                   const char *psz_text)
{
    @autoreleasepool {
        VLCCustomDialogProvider *dialogProvider = (__bridge VLCCustomDialogProvider *)p_data;
        [dialogProvider performSelectorOnMainThread:@selector(updateDisplayedProgressDialog:)
                                         withObject:@[[NSValue valueWithPointer:p_id],
                                                      toNSStr(psz_text),
                                                      @(f_position)]
                                      waitUntilDone:NO];
    }
}

@implementation VLCCustomDialogProvider

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
    if (!self.customRenderer) {
        return;
    }

    if ([self.customRenderer respondsToSelector:@selector(showErrorWithTitle:message:)]) {
        [self.customRenderer showErrorWithTitle:dialogData[0] message:dialogData[1]];
    }
}

- (void)displayLoginDialog:(NSArray * _Nonnull)dialogData
{
    if (!self.customRenderer) {
        return;
    }

    if ([self.customRenderer respondsToSelector:@selector(showLoginWithTitle:message:defaultUsername:askingForStorage:withReference:)]) {
        [self.customRenderer showLoginWithTitle:dialogData[1]
                                        message:dialogData[2]
                                defaultUsername:[dialogData[3] isEqualToString:@""] ? NULL : dialogData[3]
                               askingForStorage:[dialogData[4] boolValue]
                                  withReference:dialogData[0]];
    }
}

- (void)postUsername:(NSString *)username andPassword:(NSString *)password forDialogReference:(NSValue *)dialogReference store:(BOOL)store
{
    if (username == nil || password == nil) {
        libvlc_dialog_dismiss([dialogReference pointerValue]);
        return;
    }

    libvlc_dialog_post_login([dialogReference pointerValue],
                             [username UTF8String],
                             [password UTF8String],
                             store);
}

- (void)displayQuestion:(NSArray * _Nonnull)dialogData
{
    if (!self.customRenderer) {
        return;
    }

    if ([self.customRenderer respondsToSelector:@selector(showQuestionWithTitle:message:type:cancelString:action1String:action2String:withReference:)]) {
        [self.customRenderer showQuestionWithTitle:dialogData[1]
                                           message:dialogData[2]
                                              type:[dialogData[3] unsignedIntegerValue]
                                      cancelString:[dialogData[4] isEqualToString:@""] ? NULL : dialogData[4]
                                     action1String:[dialogData[5] isEqualToString:@""] ? NULL : dialogData[5]
                                     action2String:[dialogData[6] isEqualToString:@""] ? NULL : dialogData[6]
                                     withReference:dialogData[0]];
    }
}

- (void)postAction:(int)buttonNumber forDialogReference:(NSValue *)dialogReference
{
    libvlc_dialog_post_action([dialogReference pointerValue],
                              buttonNumber);
}

- (void)displayProgressDialog:(NSArray * _Nonnull)dialogData
{
    if (!self.customRenderer) {
        return;
    }

    if ([self.customRenderer respondsToSelector:@selector(showProgressWithTitle:message:isIndeterminate:position:cancelString:withReference:)]) {
        [self.customRenderer showProgressWithTitle:dialogData[1]
                                           message:dialogData[2]
                                   isIndeterminate:[dialogData[3] boolValue]
                                          position:[dialogData[4] floatValue]
                                      cancelString:[dialogData[5] isEqualToString:@""] ? NULL : dialogData[5]
                                     withReference:dialogData[0]];
    }
}

- (void)updateDisplayedProgressDialog:(NSArray * _Nonnull)dialogData
{
    if (!self.customRenderer) {
        return;
    }

    if ([self.customRenderer respondsToSelector:@selector(updateProgressWithReference:message:position:)]) {
        [self.customRenderer updateProgressWithReference:dialogData[0]
                                                 message:dialogData[1]
                                                 position:[dialogData[2] floatValue]];
    }
}

- (void)cancelDialog:(NSValue *)dialogId
{
    if (!self.customRenderer) {
        return;
    }

    if ([self.customRenderer respondsToSelector:@selector(cancelDialogWithReference:)]) {
        [self.customRenderer cancelDialogWithReference:dialogId];
    }
}

- (void)dismissDialogWithReference:(NSValue *)dialogReference
{
    libvlc_dialog_dismiss([dialogReference pointerValue]);
}

@end
