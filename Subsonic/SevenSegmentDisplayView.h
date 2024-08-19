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
//  DigitalLevelMeterView.h

#import <UIKit/UIKit.h>
//#import "definitions.h"

#define kDisplayModeLCD		0		//
#define kDisplayModeVFD		1		//

#define kHalfRatio          4.0     // UNIT に対するセグメントの太さの分割比
#define kGapRatio           6.0     // UNIT に対するセグメント間のギャップの分割比

#define kDoubleTapDetectPeriod      0.020

#define lcdOffAlpha                     0.3
#define vfdOffAlpha                     0.2

#define kDisplayModeKey             @"DisplayMode"

enum {
    DCELL_SHUTDOWN, DCELL_LEVEL_OFF, DCELL_LEVEL_ON
};

@interface SevenSegmentDisplayView : UIView {
}
@property (assign, nonatomic) BOOL lazy;
@property (assign, nonatomic) NSUInteger status;
@end
