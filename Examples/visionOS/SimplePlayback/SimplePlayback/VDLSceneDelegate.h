//
//  VDLSceneDelegate.h
//  SimplePlayback
//
//  Created by Felix Paul Kühne on 17.03.24.
//  Copyright © 2024 VideoLAN. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class VDLViewController;

@interface VDLSceneDelegate : UIResponder

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) VDLViewController *viewController;

@end

NS_ASSUME_NONNULL_END
