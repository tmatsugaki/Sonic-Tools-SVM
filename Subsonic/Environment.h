/*
    Sonic Tools SVM (FFT Analyzer/RTA for iOS)
    Copyright (C) 2017-2021  Takuji Matsugaki

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
//  Environment.h

#import <UIKit/UIKit.h>

#ifdef DEBUG
#define DEBUG_LOG(...) NSLog(__VA_ARGS__)
#define LOG_CURRENT_METHOD NSLog(NSStringFromSelector(_cmd))
#define LOG     ON
#else
#define DEBUG_LOG(...) ;
#define LOG_CURRENT_METHOD ;
#endif

@interface Environment : NSObject {

}

+ (BOOL) isPortrait;
+ (BOOL) isLIPad;
+ (BOOL) isMIPad;
+ (BOOL) isIPad;
+ (BOOL) isIPhone4;
+ (BOOL) isIPhone5;
+ (BOOL) isIPhone6;
+ (BOOL) isIPhone6P;
+ (BOOL) isAnalogSuitable;
+ (CGFloat) normalizeEnvRealtedValue:(CGFloat)value;
+ (BOOL) isNewIdleTimer;
+ (BOOL) isCustomizeableVolumeSlider;
+ (BOOL) isFFTSavvy;
+ (BOOL) isFlatUI;
+ (BOOL) hasAlertController;
+ (NSInteger) systemMajorVersion;
+ (BOOL) support_iCloud;
+ (CGFloat) minHeaderHeight;

+ (UIViewController *) peekModalViewController;
+ (UIViewController *) getPresentedViewController;
//+ (void) dissmissPresentedViewController;

@end
