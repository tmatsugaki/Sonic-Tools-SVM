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
//  FileUtil.m

#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import "Environment.h"
//#import "debugOption.h"

typedef struct {
    NSInteger machine;
    NSInteger generation;
} sDeviceType;

#define GEN_UNKNOWN  1
#define VER_UNKNOWN  1

typedef enum {
    MACHINE_SIMULATOR,
    MACHINE_LIPAD,
    MACHINE_IPAD,
    MACHINE_IPHONE,
    MACHINE_IPOD,
    MACHINE_UNKNOWN,
} MachineType;

@implementation Environment

// フォントサイズや、ラウンドレクタングルの曲率を環境に応じた倍率で拡大して返す。
// 基本となるのでは、iPhone のポートレイトオリエンテーション
+ (CGFloat) normalizeEnvRealtedValue:(CGFloat)value {
	
	CGFloat result = value;

	if ([Environment isLIPad] || [Environment isIPad]) {
        if ([Environment isPortrait]) {
            result *= 768.0 / 320.0;
        } else {
            if ([Environment isLIPad]) {
                result *= 1366.0 / 480.0;
            } else {
                result *= 1024.0 / 480.0;
            }
        }
	} else {
        if ([Environment isPortrait]) {
        } else {
            result *= 480.0 / 320.0;
        }
	}
	return result;
}

+ (BOOL) isLIPad {
    return [UIScreen mainScreen].bounds.size.width == 1366.0 || [UIScreen mainScreen].bounds.size.height == 1366.0;
}

+ (BOOL) isMIPad {
    return [UIScreen mainScreen].bounds.size.width == 834.0 || [UIScreen mainScreen].bounds.size.height == 834.0;
}

+ (BOOL) isIPad {
    return [UIScreen mainScreen].bounds.size.width == 768.0 || [UIScreen mainScreen].bounds.size.height == 768.0;
}

+ (BOOL) isIPhone4 {
    return fmax([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) == 480.0;
}

+ (BOOL) isIPhone5 {
    return [UIScreen mainScreen].bounds.size.width == 568.0 || [UIScreen mainScreen].bounds.size.height == 568.0;
}

+ (BOOL) isIPhone6 {
#if DEBUG
    DEBUG_LOG(@"%g", [UIScreen mainScreen].bounds.size.height);
#endif
    return [UIScreen mainScreen].bounds.size.width == 667.0 || [UIScreen mainScreen].bounds.size.height == 667.0;
}

+ (BOOL) isIPhone6P {
    return [UIScreen mainScreen].bounds.size.width == 736.0 || [UIScreen mainScreen].bounds.size.height == 736.0;
}

// 暗い画面では、ポートレイトの場合や古い iOS に限って、アナログ的なスキューモーフィズムを許す。
+ (BOOL) isAnalogSuitable {
    return [Environment isPortrait] == NO || [Environment isFlatUI] == NO;
}

+ (BOOL) isPortrait {
//	UIDevice *device = [UIDevice currentDevice];
//	UIDeviceOrientation orientation = [device orientation];
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
	static BOOL isPortrait = YES;
    
	if (orientation == UIDeviceOrientationPortrait ||
        orientation == UIDeviceOrientationPortraitUpsideDown) {
        isPortrait = YES;
    } else if (orientation == UIDeviceOrientationLandscapeLeft ||
               orientation == UIDeviceOrientationLandscapeRight) {
        isPortrait = NO;
    }
    return isPortrait;
}

+ (BOOL) isNewIdleTimer {
    return [Environment systemMajorVersion] >= 6;
}

+ (BOOL) isCustomizeableVolumeSlider {
    return [Environment systemMajorVersion] >= 6;
}

+ (BOOL) isFFTSavvy {
    return [Environment systemMajorVersion] >= 6;
}

+ (BOOL) isFlatUI {
    return [Environment systemMajorVersion] >= 7;
}

+ (BOOL) hasAlertController {
    return [Environment systemMajorVersion] >= 8;
}

+ (NSInteger) systemMajorVersion {

	NSString *systemMajorVersion = [[UIDevice currentDevice] systemVersion];
    NSInteger vers = atoi(strtok((char *) [systemMajorVersion UTF8String], ","));

    return vers;
}

// iOS5 以降
+ (BOOL) support_iCloud {    
    return [Environment systemMajorVersion] >= 5;
}

+ (CGFloat) minHeaderHeight {
    
    if ([Environment systemMajorVersion] > 6) {
        return 1.0;
    } else {
        return 0.001;
    }
}

// 従来モーダルダイアログ（UIAlertView など）で使用していた presentedViewController を取得する。
// 【注意】rootViewController を含まない。
// 【用途】忠実に従来のアラート／モーダルダイアログ（UIAlertView）が表示されているかどうか判断する。
+ (UIViewController *) peekModalViewController {
    
    UIViewController *presentedVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    // 親のビューコントローラーを検索する。
    while (presentedVC.presentedViewController != nil && !presentedVC.presentedViewController.isBeingDismissed) {
        presentedVC = presentedVC.presentedViewController;
    }
    return presentedVC != [UIApplication sharedApplication].keyWindow.rootViewController ? presentedVC : nil;
}

// presentedViewController を取得する。
// 【注意】rootViewController を含む。
+ (UIViewController *) getPresentedViewController {
    
    UIViewController *presentedVC = [UIApplication sharedApplication].keyWindow.rootViewController;

    // 親のビューコントローラーを検索する。
    while (presentedVC.presentedViewController != nil && !presentedVC.presentedViewController.isBeingDismissed) {
        presentedVC = presentedVC.presentedViewController;
    }
    return presentedVC;
}

//+ (void) dissmissPresentedViewController {
//
//    // 親のビューコントローラーを検索し消去する。
//    UIViewController *baseView = [self peekModalViewController];
//
//    if (baseView) {
//        [baseView dismissViewControllerAnimated:NO completion:nil];
//    }
//}

@end
