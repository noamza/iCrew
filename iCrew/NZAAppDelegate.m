//
//  NZAAppDelegate.m
//  iCrew
//
//  Created by Almog, Noam (ARC-AF)[UNIV OF CALIFORNIA   SANTA CRUZ] on 3/4/14.
//  Copyright (c) 2014 Almog, Noam (ARC-AF)[UNIV OF CALIFORNIA   SANTA CRUZ]. All rights reserved.
//
//

#import "NZAAppDelegate.h"
#import "NZAMainViewController.h"

@implementation NZAAppDelegate

NZAMainViewController *nv;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    nv = (NZAMainViewController*) self.window.rootViewController;
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    //You can determine whether your app can process location updates in the background by checking the value of the backgroundRefreshStatus property of the UIApplication class.
    
    //self.UIApplication.backgroundRefreshStatus; //check to see if background location is available

    NSLog(@"** entered background **");
    [nv getBGLocation];
    //write data to disk
    //needs to finish in 5 secs
    //beginBackgroundTaskWithExpirationHandler:
    //use UIApplicationDidEnterBackgroundNotification for other objects
    

    
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    [nv setLocationBackToNormal];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
