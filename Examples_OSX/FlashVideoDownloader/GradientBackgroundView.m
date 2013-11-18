/*****************************************************************************
 * FlashVideoDownloader: GradientBackgroundView.m
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

#import "GradientBackgroundView.h"

/**********************************************************
 * Why not drawing something nice?
 */

@implementation GradientBackgroundView
- (void)awakeFromNib
{
    /* Buggy nib files... Force us to be on the back of the view hierarchy */
    NSView * superView;
    [self retain];
    superView = [self superview];
    [self removeFromSuperview];
    [superView addSubview:self positioned: NSWindowBelow relativeTo:nil];
}
- (void)drawRect:(NSRect)rect
{

    NSColor * topGradient = [NSColor colorWithCalibratedWhite:.12f alpha:1.0];
    NSColor * bottomGradient   = [NSColor colorWithCalibratedWhite:0.55f alpha:0.9];
    NSGradient * gradient = [[NSGradient alloc] initWithColorsAndLocations:bottomGradient, 0.f, bottomGradient, 0.1f, topGradient, 1.f, nil];
    [gradient drawInRect:self.bounds angle:90.0];
    [super drawRect:rect];
}
@end
