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
//  ColorUtil.h

#import <UIKit/UIKit.h>

typedef enum {
    kIndexColorWhite,
    kIndexColorRed,
    kIndexColorGreen,
    kIndexColorBlue,
    kIndexColorCyan,
    kIndexColorMagenta,
    kIndexColorYellow,
    kIndexColorOrange,
    kIndexColorBlack,
    kIndexColorLightGray,
    kIndexColorGray,
    kIndexColorDarkGray,
    kIndexColorDefault = kIndexColorRed
} IndexedColor;

@interface ColorUtil : NSObject {
}

+ (UIColor *) bloodyRed;
+ (UIColor *) deadRed;
+ (UIColor *) clearWhite;
+ (UIColor *) sectionHeaderColor;
+ (UIColor *) graySectionHeaderColor;
+ (UIColor *) darkListGray;
+ (UIColor *) jblBlue;
+ (UIColor *) alminium;
+ (UIColor *) vuMeterYellow;
+ (UIColor *) clearGlassBlue;
+ (UIColor *) mechanicGray;
+ (UIColor *) darkMechanicGray;
+ (UIColor *) clearShadowGray3;
+ (UIColor *) clearShadowGray4;

+ (UIColor *) vfdOn;
+ (UIColor *) vfdOnWeak;
+ (UIColor *) vfdOff:(CGFloat)alpha;
+ (UIColor *) pdOn;
+ (UIColor *) pdOff;
+ (UIColor *) lcdBase;
+ (UIColor *) lcdOn;
+ (UIColor *) lcdOff:(CGFloat)alpha;
+ (UIColor *) ledBack;
+ (UIColor *) ledOnGreen;
+ (UIColor *) ledWarnYellow;
+ (UIColor *) ledOff;

+ (UIColor *) cellHiliteColor;

+ (UIColor *) getColor:(IndexedColor)index;
// UI用のカラーインデクス
+ (NSUInteger) messageColorIndex;
+ (NSUInteger) warnColorIndex;
+ (NSUInteger) errorColorIndex;
+ (NSUInteger) urlColorIndex;
+ (NSUInteger) pathColorIndex;
+ (NSUInteger) artistColorIndex;
+ (NSUInteger) albumColorIndex;
+ (NSUInteger) tuneColorIndex;

+ (UIColor *) pageControlColor:(BOOL)current;
+ (UIColor *) iOS7Blue;
@end
