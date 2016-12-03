//
//  ViewController.h
//  GLEssentials
//
//  Created by Felix Paul Kühne on 19.11.13.
//  Copyright (c) 2013 VideoLAN. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EAGLView.h"

@interface ViewController : UIViewController

@property (readwrite) IBOutlet UIView *videoView;
@property (readwrite) IBOutlet EAGLView *glView;

@end
