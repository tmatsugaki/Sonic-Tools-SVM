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
//  ColorUtil.m

#import <UIKit/UIKit.h>
#import "ColorUtil.h"

@implementation ColorUtil

+ (UIColor *) bloodyRed {
	return [UIColor colorWithRed:0.85 green:0.05 blue:0.05 alpha:1.0];
}

+ (UIColor *) deadRed {
	return [UIColor colorWithRed:0.85 green:0.15 blue:0.15 alpha:1.0];
}

+ (UIColor *) clearWhite {
	return [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.0];
}

+ (UIColor *) sectionHeaderColor {
	return [UIColor colorWithRed:0.1 green:0.2 blue:0.3 alpha:0.5];
}

+ (UIColor *) graySectionHeaderColor {
	return [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:0.5];
}

+ (UIColor *) darkListGray {
	return [UIColor colorWithRed:44.0/255.0 green:44.0/255.0 blue:44.0/255.0 alpha:1.0];
}
/*
 * アナログ表示デバイス用
 */
+ (UIColor *) jblBlue {
	return [UIColor colorWithRed:0.1 green:0.2 blue:0.3 alpha:1.0];
}

+ (UIColor *) alminium {
	return [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:0.8];
}

// Stickies の黄色と同じ色
+ (UIColor *) vuMeterYellow {
#if (FLAT_UI == ON)
    // Stickies の黄色より淡い黄色
	return [UIColor colorWithRed:253.0/256.0 green:243.0/256.0 blue:215.0/256.0 alpha:1.0];
#else
    // Stickies の黄色と同じ色
	return [UIColor colorWithRed:253.0/256.0 green:243.0/256.0 blue:155.0/256.0 alpha:1.0];
#endif
}

+ (UIColor *) clearGlassBlue {
	return [UIColor colorWithRed:0.3 green:0.3 blue:0.6 alpha:0.3];
}

+ (UIColor *) mechanicGray {
	return [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
}

+ (UIColor *) darkMechanicGray {
	return [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
}

// モノクロのシャドー
+ (UIColor *) clearShadowGray3 {
	return [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.3];
}

// モノクロのシャドー（少し濃いめ）
+ (UIColor *) clearShadowGray4 {
	return [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.4];
}

/*
 * デジタル表示体用
 */
// 水色の VFD風
+ (UIColor *) vfdOn {
	return [UIColor colorWithRed:179.0/256.0 green:219.0/256.0 blue:212.0/256.0 alpha:1.0];
}

// 水色の VFD風（半透明）
+ (UIColor *) vfdOnWeak {
    return [UIColor colorWithRed:179.0/256.0 green:219.0/256.0 blue:212.0/256.0 alpha:0.4];
}

+ (UIColor *) vfdOff:(CGFloat)alpha {
	return [UIColor colorWithRed:81.0/256.0 green:84.0/256.0 blue:67.0/256.0 alpha:alpha];
}

// PlasmaDisplay風
+ (UIColor *) pdOn {
//	return [UIColor colorWithRed:255.0/256.0 green:140.0/256.0 blue:0.0/256.0 alpha:1.0];
//	return [UIColor colorWithRed:193.0/256.0 green:56.0/256.0 blue:50.0/256.0 alpha:1.0];
//	return [UIColor colorWithRed:191.0/256.0 green:80.0/256.0 blue:76.0/256.0 alpha:1.0];
	return [UIColor colorWithRed:204.0/256.0 green:75.0/256.0 blue:71.0/256.0 alpha:1.0];
}

+ (UIColor *) pdOff {
	return [UIColor colorWithRed:81.0/256.0 green:84.0/256.0 blue:97.0/256.0 alpha:1.0];
}

// STNモノクロ液晶風
+ (UIColor *) lcdBase {
	return [UIColor colorWithRed:224.0/256.0 green:229.0/256.0 blue:201/256.0 alpha:1.0];
}

+ (UIColor *) lcdOn {
	return [UIColor colorWithRed:81.0/256.0 green:84.0/256.0 blue:67.0/256.0 alpha:1.0];
}

+ (UIColor *) lcdOff:(CGFloat)alpha {
	return [UIColor colorWithRed:207.0/256.0 green:211.0/256.0 blue:179.0/256.0 alpha:alpha];
}

// 緑色のLED風
+ (UIColor *) ledBack {
	return [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0];
}

+ (UIColor *) ledOnGreen {
	return [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:1.0];
}

+ (UIColor *) ledWarnYellow {
	return [UIColor colorWithRed:1.0 green:1.0 blue:0.0 alpha:1.0];
}

+ (UIColor *) ledOff {
	return [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
}

// UI カラー
+ (UIColor *) cellHiliteColor {
    return [UIColor grayColor];
}

+ (UIColor *) getColor:(IndexedColor)index {
    
    UIColor *color = nil;
    switch (index) {
    case kIndexColorWhite:
        color = [UIColor whiteColor];
        break;
    case kIndexColorRed:
        color = [UIColor redColor];
        break;
    case kIndexColorGreen:
        color = [UIColor greenColor];
        break;
    case kIndexColorBlue:
        color = [UIColor blueColor];
        break;
    case kIndexColorCyan:
        color = [UIColor cyanColor];
        break;
    case kIndexColorMagenta:
        color = [UIColor magentaColor];
        break;
    case kIndexColorYellow:
        color = [UIColor yellowColor];
        break;
    case kIndexColorOrange:
        color = [UIColor orangeColor];
        break;
    case kIndexColorBlack:
        color = [UIColor blackColor];
        break;
    case kIndexColorLightGray:
        color = [UIColor lightGrayColor];
        break;
    case kIndexColorGray:
        color = [UIColor grayColor];
        break;
    case kIndexColorDarkGray:
        color = [UIColor darkGrayColor];
        break;
    default:
        color = [UIColor blackColor];
        break;
    }
    return color;
}

+ (NSUInteger) messageColorIndex {
    return kIndexColorDarkGray;
}

+ (NSUInteger) warnColorIndex {
    return kIndexColorYellow;
}

+ (NSUInteger) errorColorIndex {
    return kIndexColorRed;
}

+ (NSUInteger) urlColorIndex {
    return kIndexColorWhite;
}

+ (NSUInteger) pathColorIndex {
    return kIndexColorWhite;
}

+ (NSUInteger) artistColorIndex {
    return kIndexColorRed;
}

+ (NSUInteger) albumColorIndex {
    return kIndexColorRed;
}

+ (NSUInteger) tuneColorIndex {
    return kIndexColorWhite;
}

+ (UIColor *) pageControlColor:(BOOL)current {
    // アクティブなのがより白い。どちらも半透明
    if (current) {
        return [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.9];
    } else {
        return [UIColor colorWithRed:0.7f green:0.7f blue:0.7f alpha:0.3];
    }
}

+ (UIColor *) iOS7Blue {
	return [UIColor colorWithRed:0.0/256.0 green:122.0/256.0 blue:255.0/256.0 alpha:1.0];
}
@end
