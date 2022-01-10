/*
    Sonic Tools SVM (FFT Analyzer/RTA for iOS)
    Copyright (C) 2017-2022  Takuji Matsugaki

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
//
//  AppDelegate.m

#import <StoreKit/SKStoreReviewController.h>
#import "AppDelegate.h"
#import "definitions.h"
#import "Environment.h"
#include "mo_audio.hh"
#include "UserDefaults.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    DEBUG_LOG(@"%s %@", __func__, kDocumentPath);
    
    [[UserDefaults sharedManager] initialize];
    
//    [Fabric with:@[[Crashlytics class]]];
    [SKStoreReviewController requestReview];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    DEBUG_LOG(@"%s", __func__);
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    DEBUG_LOG(@"%s", __func__);
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

    MoAudio::stop();
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    DEBUG_LOG(@"%s", __func__);
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    DEBUG_LOG(@"%s", __func__);
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

    // 常時画面ロックしない。
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}


- (void)applicationWillTerminate:(UIApplication *)application {
    DEBUG_LOG(@"%s", __func__);
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}
@end
