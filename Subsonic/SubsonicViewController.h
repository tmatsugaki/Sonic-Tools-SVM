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
//  SubsonicViewController.h
//

#import <UIKit/UIKit.h>
#import "definitions.h"
#if (ADMOB == ON)
#import <GoogleMobileAds/GADBannerView.h>
#endif
#import "UserDefaults.h"

@interface SubsonicViewController : UIViewController {
}
//@property (assign, nonatomic) BOOL freeze;
@property (assign, nonatomic) BOOL toPortrait;
#if (ADMOB == ON)
@property (strong, nonatomic) GADBannerView *banner;
#endif
@property (strong, nonatomic) IBOutlet UIView *bannerView;

#if (ADMOB == ON)
- (CGFloat) getAdmobAdHeight;
- (void) setupAdmob:(NSString *)adUnitID;
- (void) setupAdmobFor_iPad:(NSString *)adUnitID;
#endif
@end
