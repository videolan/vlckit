//
//  VDLMainViewController.m
//  Dropin-Player
//
//  Created by Felix Paul Kühne on 19.11.13.
//  Copyright (c) 2013 VideoLAN. All rights reserved.
//

#import "VDLMainViewController.h"
#import "VDLAppDelegate.h"

@interface VDLMainViewController ()

@end

@implementation VDLMainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (IBAction)startPlayback:(id)sender
{
    VDLAppDelegate *appDelegate = (VDLAppDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate playStreamFromURL:[NSURL URLWithString:@"http://streams.videolan.org/streams/mp4/Mr_MrsSmith-h264_aac.mp4"]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
