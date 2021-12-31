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
//  AccelometerSPLViewController.h

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import "definitions.h"
#import "AccelometerSPLView.h"
#import "SubsonicViewController.h"

#define kAcceloSPLHideRulerKey        @"AcceloSPLHideRuler"
#define kAcceloSPLVolumeDecadesKey    @"AcceloSPLVolumeDecades"

#define kAcceloSPLPinchScaleXKey      @"AcceloSPLPinchScaleX"
#define kAcceloSPLPinchScaleYKey      @"AcceloSPLPinchScaleY"
#define kAcceloSPLPanOffsetXKey       @"AcceloPLPanOffsetX"
#define kAcceloSPLPanOffsetYKey       @"AcceloSPLPanOffsetY"

#define kAcceloSPLCSVKey              @"AcceloSPLCSV"

#if LOAD_DUMMY_DATA
#define REFRESH_INTERVAL                0.1     // 0.025s 25ms(40Hz) が望ましいが高CPU負荷、iPhone4S だと 0.075 辺りが限界。
#else
#define REFRESH_INTERVAL                STD_REFRESH_INTERVAL
#endif

@interface AccelometerSPLViewController : SubsonicViewController <AccelometerSPLViewProtocol> {
    CMMotionManager *motionManager;
    NSOperationQueue *queue;
}
@property (strong, nonatomic) IBOutlet AccelometerSPLView *accelometerSPLView;
@property (assign, nonatomic) IBOutlet NSLayoutConstraint *contentConstraint;
@property (assign, nonatomic) BOOL freeze;
@property (strong, nonatomic) NSTimer *refreshTimer;

- (void) initAccelometerSPL;
@end

