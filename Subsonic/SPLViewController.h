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
//  SPLViewController.h

#import <UIKit/UIKit.h>
#import "definitions.h"
#import "SPLView.h"
#import "SubsonicViewController.h"

#define kSPLHideRulerKey        @"SPLHideRuler"
#define kSPLVolumeDecadesKey    @"SPLVolumeDecades"

#define kSPLPinchScaleXKey      @"SPLPinchScaleX"
#define kSPLPinchScaleYKey      @"SPLPinchScaleY"
#define kSPLPanOffsetXKey       @"SPLPanOffsetX"
#define kSPLPanOffsetYKey       @"SPLPanOffsetY"

//#define kSPLGainKey             @"SPLGain"

#define kSPLCSVKey              @"SPLCSV"

//#define REFRESH_INTERVAL        0.1 // 0.05s 50ms(20Hz) が望ましいが、iPhone4S だと 0.075 辺りが限界。
//#define REFRESH_INTERVAL        0.1 // iPhone4S だと 0.075 辺りが限界。0.046より緩慢にしないと意味がない。
#define REFRESH_INTERVAL        STD_REFRESH_INTERVAL    // 0.05

@interface SPLViewController : SubsonicViewController <SPLViewProtocol> {
}
@property (strong, nonatomic) IBOutlet SPLView *splView;
@property (assign, nonatomic) IBOutlet NSLayoutConstraint *contentConstraint;
@property (assign, nonatomic) BOOL freeze;
@property (strong, nonatomic) NSTimer *refreshTimer;

- (void) initSPL;
@end

