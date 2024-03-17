//
//  NSObject+VDLSceneDelegate.m
//  SimplePlayback
//
//  Created by Felix Paul Kühne on 17.03.24.
//  Copyright © 2024 VideoLAN. All rights reserved.
//

#import "VDLSceneDelegate.h"
#import "VDLViewController.h"

@interface VDLSceneDelegate () <UISceneDelegate>
{
}

@end

@implementation VDLSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions
{
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];

    self.viewController = [[VDLViewController alloc] initWithNibName:@"VDLViewController" bundle:nil];
    self.window.rootViewController = self.viewController;

    [self.window makeKeyAndVisible];
}

- (void)sceneDidDisconnect:(UIScene *)scene
{
}

- (void)sceneDidBecomeActive:(UIScene *)scene
{
    [self.window makeKeyAndVisible];
}

- (void)sceneWillResignActive:(UIScene *)scene
{
}

- (void)sceneWillEnterForeground:(UIScene *)scene
{
}

- (void)sceneDidEnterBackground:(UIScene *)scene
{
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
{
}

- (void)scene:(UIScene *)scene willContinueUserActivityWithType:(NSString *)userActivityType
{
}

- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity
{
}

- (void)scene:(UIScene *)scene didFailToContinueUserActivityWithType:(NSString *)userActivityType error:(NSError *)error
{
}

@end
