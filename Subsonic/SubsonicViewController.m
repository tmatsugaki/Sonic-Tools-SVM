/*
    Sonic Tools SVM (FFT Analyzer/RTA for iOS)
    Copyright (C) 2017-2024  Takuji Matsugaki

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
//  SubsonicViewController.m
//

#import <Accelerate/Accelerate.h>
#import "SubsonicViewController.h"
#import "Environment.h"

@interface SubsonicViewController ()

@end

@implementation SubsonicViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.toPortrait = (self.view.frame.size.width < self.view.frame.size.height);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - AdMob Utilities

- (CGFloat) getAdmobAdHeight {
#if (ADMOB == ON)
    CGFloat height;
    
    if ([Environment isIPad] || [Environment isMIPad] || [Environment isLIPad]) {
        height = [Environment isPortrait] ? 90.0 : 90.0;
    } else {
        height = 50.0;
    }
    return height;
#else
    return 0.0;
#endif
}

#if (ADMOB == ON)
- (void) setupAdmob:(NSString *)adUnitID {
    
    if ([Environment isIPhone4] == NO && _banner == nil) {
#if ADMOB
        GADAdSize size;
        
        if ([Environment isIPad] || [Environment isMIPad] || [Environment isLIPad]) {
            size = [Environment isPortrait] ? kGADAdSizeSmartBannerPortrait : kGADAdSizeSmartBannerLandscape;
        } else {
            size = kGADAdSizeSmartBannerPortrait;
        }
        // バナーのビューを作成する
        // 利用可能な広告サイズの定数値は GADAdSize.h で定義されている
        self.banner = [[GADBannerView alloc] initWithAdSize:size];
        self.banner.adUnitID = adUnitID;
        self.banner.rootViewController = self;
        
        [self.bannerView addSubview:_banner];
        
        GADRequest *request = [GADRequest request];
        request.testDevices = @[kGADSimulatorID,                        // All simulators
                                @"61ed1e6cd70d2e8e96a7b510d0fb046d",    // iPhone4S
                                @"cfed5cdc6473318d42ca243a060d5412",    // iPad2
                                @"24a68e0fa469e4fc409f749098c47679",    // iPhone5S
                                @"a829960a38bdff398c3be9ab1fbb1285"];   // iPhone7
        [self.banner loadRequest:request];
#endif
    }
}

- (void) setupAdmobFor_iPad:(NSString *)adUnitID {
    
#if (ADMOB && SUPPORT_IPAD)
    if ([Environment isIPad] || [Environment isMIPad] || [Environment isLIPad]) {
        if (_banner) {
            [_banner removeFromSuperview];
        }
        // バナーのビューを作成する
        // 利用可能な広告サイズの定数値は GADAdSize.h で定義されている
        self.banner = [[GADBannerView alloc] initWithAdSize:[Environment isPortrait] ? kGADAdSizeSmartBannerPortrait : kGADAdSizeSmartBannerLandscape];
        self.banner.adUnitID = adUnitID;
        self.banner.rootViewController = self;
        
        [self.bannerView addSubview:_banner];
        
        GADRequest *request = [GADRequest request];
        request.testDevices = @[kGADSimulatorID,                        // All simulators
                                @"61ed1e6cd70d2e8e96a7b510d0fb046d",    // iPhone4S
                                @"cfed5cdc6473318d42ca243a060d5412",    // iPad2
                                @"24a68e0fa469e4fc409f749098c47679",    // iPhone5S
                                @"a829960a38bdff398c3be9ab1fbb1285"];   // iPhone7
        [self.banner loadRequest:request];
    }
#endif
}
#endif
@end
