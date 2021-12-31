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
//  AccelometerScopeViewController.h

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import "definitions.h"
#import "AccelometerScopeView.h"
#import "SubsonicViewController.h"

#define kAcceloScopeHideRulerKey        @"AcceloScopeHideRuler"
#define kAcceloScopeVolumeDecadesKey    @"AcceloScopeVolumeDecades"

#define kAcceloScopePinchScaleXKey      @"AcceloScopePinchScaleX"
#define kAcceloScopePinchScaleYKey      @"AcceloScopePinchScaleY"
#define kAcceloScopePanOffsetXKey       @"AcceloScopePanOffsetX"
#define kAcceloScopePanOffsetYKey       @"AcceloScopePanOffsetY"

#if LOAD_DUMMY_DATA
#define REFRESH_INTERVAL                0.1     // 0.025s 25ms(40Hz) が望ましいが高CPU負荷、iPhone4S だと 0.075 辺りが限界。
#else
#define REFRESH_INTERVAL                STD_REFRESH_INTERVAL
#endif

@interface AccelometerScopeViewController : SubsonicViewController <AccelometerScopeViewProtocol> {
    CMMotionManager *motionManager;
    NSOperationQueue *queue;
    Float32 x_buffer[ACCELO_SCOPE_OP_SIZE];
    Float32 y_buffer[ACCELO_SCOPE_OP_SIZE];
    Float32 z_buffer[ACCELO_SCOPE_OP_SIZE];
}
@property (strong, nonatomic) IBOutlet AccelometerScopeView *accelometerScopeView;
@property (assign, nonatomic) IBOutlet NSLayoutConstraint *contentConstraint;
@property (assign, nonatomic) BOOL freeze;
@property (strong, nonatomic) NSTimer *refreshTimer;

- (void) initAccelometerScope;
@end

