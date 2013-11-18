/*****************************************************************************
 * iPodConverter: Controller
 *****************************************************************************
 * Copyright (C) 2007-2012 Pierre d'Herbemont and VideoLAN
 *
 * Authors: Pierre d'Herbemont
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

#import <Cocoa/Cocoa.h>
#import <VLCKit/VLCKit.h>
#import <VLCKit/VLCMediaPlayer.h>

@interface Controller : NSObject
{
    IBOutlet NSView * conversionView;
    IBOutlet NSWindow * window;
    IBOutlet NSButton * openConvertedFileButton;

    NSNumber * selectedStreamOutput;

    VLCMedia * media;
    VLCStreamSession * streamSession;
}

- (void)awakeFromNib;

@property (retain) VLCMedia * media;
@property (retain) VLCStreamSession * streamSession;
@property (assign) NSNumber * selectedStreamOutput;
@property (retain,readonly) NSString * outputFilePath;

- (IBAction)convert:(id)sender;
- (IBAction)openConvertedFile:(id)sender;
- (IBAction)openConvertedEnclosingFolder:(id)sender;
@end
