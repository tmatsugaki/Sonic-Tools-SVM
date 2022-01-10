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
//  AccelometerSPLViewController.m

#import "AccelometerSPLViewController.h"
#include "FFTHelper.hh"
#include "Environment.h"

static unsigned long long accelometerSPLBufferFillIndex = 0;

#import "FFTHelper.hh"

#pragma mark - Accelometer

Float32 accelo_spl_buffer[ACCELO_SPL_SAMPLE_RATE];

long long flushAcceloSPLCount = 0;
NSDate *accelSplFlushDate = nil;

Float64 minAcceloSPLRedValue = DBL_MAX;
Float64 maxAcceloSPLRedValue = DBL_MIN;
Float64 avgAcceloSPLRedValue = 0;
Float64 minAcceloSPLGreenValue = DBL_MAX;
Float64 maxAcceloSPLGreenValue = DBL_MIN;
Float64 avgAcceloSPLGreenValue = 0;
Float64 minAcceloSPLBlueValue = DBL_MAX;
Float64 maxAcceloSPLBlueValue = DBL_MIN;
Float64 avgAcceloSPLBlueValue = 0;

void initAccelometerSPL(void) {
    flushAcceloSPLCount = 0;

    minAcceloSPLRedValue = DBL_MAX;
    maxAcceloSPLRedValue = DBL_MIN;
    avgAcceloSPLRedValue = 0;
    minAcceloSPLGreenValue = DBL_MAX;
    maxAcceloSPLGreenValue = DBL_MIN;
    avgAcceloSPLGreenValue = 0;
    minAcceloSPLBlueValue = DBL_MAX;
    maxAcceloSPLBlueValue = DBL_MIN;
    avgAcceloSPLBlueValue = 0;
}

AccelometerSPLView * __weak accelometer_spl_view = nil;
BOOL *accelometer_spl_freeze_p = nil;

@interface AccelometerSPLViewController ()

@end

@implementation AccelometerSPLViewController

- (void) postUpdate {
    
//    DEBUG_LOG(@"(%llu)", accelometerSPLBufferFillIndex);
    
#if (LOAD_DUMMY_DATA && TARGET_IPHONE_SIMULATOR)
// このパスを通過する。
    if (*accelometer_spl_freeze_p == NO) {
        flushAcceloSPLCount++;
        
        Float32 x = 0;
        Float32 y = 0;
        Float32 z = 0;
        Float64 sumX = avgAcceloSPLRedValue * (flushAcceloSPLCount-1) + x;
        Float64 sumY = avgAcceloSPLGreenValue * (flushAcceloSPLCount-1) + y;
        Float64 sumZ = avgAcceloSPLBlueValue * (flushAcceloSPLCount-1) + z;
        //
        if (maxAcceloSPLRedValue < x) {
            maxAcceloSPLRedValue = x;
        }
        if (x && minAcceloSPLRedValue > x) {
            minAcceloSPLRedValue = x;
        }
        avgAcceloSPLRedValue = sumX / ((Float64) flushAcceloSPLCount);
        //
        if (maxAcceloSPLGreenValue < y) {
            maxAcceloSPLGreenValue = y;
        }
        if (y && minAcceloSPLGreenValue > y) {
            minAcceloSPLGreenValue = y;
        }
        avgAcceloSPLGreenValue = sumY / ((Float64) flushAcceloSPLCount);
        //
        if (maxAcceloSPLBlueValue < z) {
            maxAcceloSPLBlueValue = z;
        }
        if (z && minAcceloSPLBlueValue > z) {
            minAcceloSPLBlueValue = z;
        }
        avgAcceloSPLBlueValue = sumZ / ((Float64) flushAcceloSPLCount);
        
        Float32 rmsValue = sqrt((x * x + y * y + z * z) / 1.0);
        
        //                                                DEBUG_LOG(@"X:%g, Y:%g, Z:%g [%g]", x, y, z, rmsValue);
        
        // リングバッファにデータを1つ追加する。
        [accelometer_spl_view enqueueData:rmsValue];
        
        accelometer_spl_view.rmsValue = rmsValue;
        accelometer_spl_view.maxRMS = sqrt((maxAcceloSPLRedValue   * maxAcceloSPLRedValue +
                                           maxAcceloSPLGreenValue * maxAcceloSPLGreenValue +
                                           maxAcceloSPLBlueValue  * maxAcceloSPLBlueValue) / 1.0);
//        accelometer_spl_view.avgRMS = sqrt((avgAcceloSPLRedValue   * avgAcceloSPLRedValue +
//                                           avgAcceloSPLGreenValue * avgAcceloSPLGreenValue +
//                                           avgAcceloSPLBlueValue  * avgAcceloSPLBlueValue) / 1.0);
        accelometer_spl_view.avgRMS = sqrt((maxAcceloSPLRedValue   * maxAcceloSPLRedValue +
                                           maxAcceloSPLGreenValue * maxAcceloSPLGreenValue +
                                           maxAcceloSPLBlueValue  * maxAcceloSPLBlueValue) / 1.0);
        accelometer_spl_view.minRMS = sqrt((minAcceloSPLRedValue   * minAcceloSPLRedValue +
                                           minAcceloSPLGreenValue * minAcceloSPLGreenValue +
                                           minAcceloSPLBlueValue  * minAcceloSPLBlueValue) / 1.0);
    }
    NSDate *date = [NSDate date];
    if ([date timeIntervalSinceDate:accelSplFlushDate] > REFRESH_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
        dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
            [accelometer_spl_view setNeedsDisplay];
            [accelometer_spl_view.f2 setNeedsDisplay];
            [accelometer_spl_view.f1 setNeedsDisplay];
            [accelometer_spl_view.f0 setNeedsDisplay];
        });
        accelSplFlushDate = date;
    } else {
        DEBUG_LOG(@"%s レイテンシーが小さすぎ！", __func__);
    }
    accelometerSPLBufferFillIndex++;
#else
    dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
        [accelometer_spl_view setNeedsDisplay];
        [accelometer_spl_view.f2 setNeedsDisplay];
        [accelometer_spl_view.f1 setNeedsDisplay];
        [accelometer_spl_view.f0 setNeedsDisplay];
    });
#endif
}

#pragma mark - AccelometerSPL

- (void) initAccelometerSPL {
    initAccelometerSPL();
}

- (void) startMeasurement {
    queue = [NSOperationQueue currentQueue];
    // startAccelerometerUpdatesToQueue:withHandler:
    [motionManager startAccelerometerUpdatesToQueue:queue
                                        withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {

                                            if (*accelometer_spl_freeze_p == NO) {
                                                CMAcceleration acceleration = accelerometerData.acceleration;
                                                
                                                flushAcceloSPLCount++;
                                                
                                                Float32 x = ABS(acceleration.x);
                                                Float32 y = ABS(acceleration.y);
                                                Float32 z = ABS(acceleration.z);
                                                Float64 sumX = avgAcceloSPLRedValue * (flushAcceloSPLCount-1) + x;
                                                Float64 sumY = avgAcceloSPLGreenValue * (flushAcceloSPLCount-1) + y;
                                                Float64 sumZ = avgAcceloSPLBlueValue * (flushAcceloSPLCount-1) + z;
                                                //
                                                if (maxAcceloSPLRedValue < x) {
                                                    maxAcceloSPLRedValue = x;
                                                }
                                                if (x && minAcceloSPLRedValue > x) {
                                                    minAcceloSPLRedValue = x;
                                                }
                                                avgAcceloSPLRedValue = sumX / ((Float64) flushAcceloSPLCount);
                                                //
                                                if (maxAcceloSPLGreenValue < y) {
                                                    maxAcceloSPLGreenValue = y;
                                                }
                                                if (y && minAcceloSPLGreenValue > y) {
                                                    minAcceloSPLGreenValue = y;
                                                }
                                                avgAcceloSPLGreenValue = sumY / ((Float64) flushAcceloSPLCount);
                                                //
                                                if (maxAcceloSPLBlueValue < z) {
                                                    maxAcceloSPLBlueValue = z;
                                                }
                                                if (z && minAcceloSPLBlueValue > z) {
                                                    minAcceloSPLBlueValue = z;
                                                }
                                                avgAcceloSPLBlueValue = sumZ / ((Float64) flushAcceloSPLCount);
                                                Float32 rmsValue = sqrt((x * x + y * y + z * z) / 1.0);
                                                
                                                //                                                DEBUG_LOG(@"X:%g, Y:%g, Z:%g [%g]", x, y, z, rmsValue);
                                                
                                                // リングバッファにデータを1つ追加する。
                                                [accelometer_spl_view enqueueData:rmsValue];
                                                
                                                accelometer_spl_view.rmsValue = rmsValue;
                                                accelometer_spl_view.maxRMS = sqrt((maxAcceloSPLRedValue   * maxAcceloSPLRedValue +
                                                                                   maxAcceloSPLGreenValue * maxAcceloSPLGreenValue +
                                                                                   maxAcceloSPLBlueValue  * maxAcceloSPLBlueValue) / 1.0);
                                                accelometer_spl_view.avgRMS = sqrt((avgAcceloSPLRedValue   * avgAcceloSPLRedValue +
                                                                                   avgAcceloSPLGreenValue * avgAcceloSPLGreenValue +
                                                                                   avgAcceloSPLBlueValue  * avgAcceloSPLBlueValue) / 1.0);
                                                accelometer_spl_view.minRMS = sqrt((minAcceloSPLRedValue   * minAcceloSPLRedValue +
                                                                                   minAcceloSPLGreenValue * minAcceloSPLGreenValue +
                                                                                   minAcceloSPLBlueValue  * minAcceloSPLBlueValue) / 1.0);
                                            }
                                            NSDate *date = [NSDate date];
                                            if ([date timeIntervalSinceDate:accelSplFlushDate] > REFRESH_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
                                                dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
                                                    [accelometer_spl_view setNeedsDisplay];
                                                    [accelometer_spl_view.f2 setNeedsDisplay];
                                                    [accelometer_spl_view.f1 setNeedsDisplay];
                                                    [accelometer_spl_view.f0 setNeedsDisplay];
                                                });
                                                accelSplFlushDate = date;
                                            } else {
                                                DEBUG_LOG(@"%s レイテンシーが小さすぎ！", __func__);
                                            }
                                            accelometerSPLBufferFillIndex++;
                                        }];
}

- (void) stopMeasurement {
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

//    _freeze = YES;
    [self setLedMeasuring:_freeze == NO];

    accelSplFlushDate = [NSDate date];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
#if (CSV_OUT == ON)
#if (CSV_OUT_ONE_BUTTON == ON)
    _accelometerSPLView.stopSwitch.hidden = YES;
#else
    _accelometerSPLView.stopSwitch.hidden = NO;
#endif
    _accelometerSPLView.playPauseSwitch.hidden = NO;
#endif

#if LOAD_DUMMY_DATA
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:REFRESH_INTERVAL target:self selector:@selector(postUpdate) userInfo:nil repeats:YES];
#endif
    if (self.navigationController) {
        DEBUG_LOG(@"%g", self.navigationController.navigationBar.frame.size.height);
    }
    self.accelometerSPLView.header.text = @"";

    self.accelometerSPLView.delegate = self;
    accelometer_spl_view = self.accelometerSPLView;
    // startMeasurement に先立つこと。
    accelometer_spl_freeze_p = &_freeze;

    self.accelometerSPLView.dot.layer.cornerRadius = self.accelometerSPLView.dot.frame.size.width / 2.0;
    // 加速度センサー関連の初期化
    if (motionManager == nil) {
        motionManager = [[CMMotionManager alloc] init];
        motionManager.accelerometerUpdateInterval  = 1.0 / ACCELO_SPL_SAMPLE_RATE; // ACCELO_SPL_SAMPLE_RATE Update at 32Hz
    }
    if (motionManager.accelerometerAvailable) {
        DEBUG_LOG(@"Accelerometer avaliable");
        [self startMeasurement];
    }
    // VFD の G とラベルの重なりをなくす。
    self.accelometerSPLView.lblG.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    _freeze = NO;
    [self setLedMeasuring:_freeze == NO];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.accelometerSPLView.delegate = nil;

    // 全てのオペレーションキューを停止する。
    [queue cancelAllOperations];

    if (motionManager.accelerometerAvailable) {
        [motionManager stopAccelerometerUpdates];
    }
#if (CSV_OUT == ON)
    [_accelometerSPLView stopAction:nil];
#endif
}

#if 0
- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                 duration:(NSTimeInterval)duration
{
    self.toPortrait = (toInterfaceOrientation == UIInterfaceOrientationPortrait || toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
    
    // maintainPinch を実行する。
    [self.accelometerSPLView setNeedsLayout];

    // VFD の G とラベルの重なりをなくす。
    self.accelometerSPLView.lblG.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
}
#else
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    self.toPortrait = (size.width < size.height);

    // maintainPinch を実行する。
    [self.accelometerSPLView setNeedsLayout];    
    // VFD の G とラベルの重なりをなくす。
    self.accelometerSPLView.lblG.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
}
#endif

#if 0
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    
    // maintainPinch を実行する。
    [self.accelometerSPLView setNeedsLayout];
    // VFD の G とラベルの重なりをなくす。
    self.accelometerSPLView.lblG.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
}
#else
- (void) traitCollectionDidChange: (UITraitCollection *) previousTraitCollection {
    [super traitCollectionDidChange: previousTraitCollection];

    // maintainPinch を実行する。
    [self.accelometerSPLView setNeedsLayout];
    // VFD の G とラベルの重なりをなくす。
    self.accelometerSPLView.lblG.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
}
#endif

- (void)didReceiveMemoryWarning {
    DEBUG_LOG(@"%s", __func__);
    
    [super didReceiveMemoryWarning];
}

#pragma mark - UIResponder

- (BOOL) canBecomeFirstResponder {
    return YES;
}

- (BOOL) canResignFirstResponder {
    return YES;
}

#pragma mark - AccelometerViewProtocol delegate

- (void) setLedMeasuring:(BOOL)onOff {
    
    if (onOff) {
        [self.accelometerSPLView.led setImage:[UIImage imageNamed:@"greenLED"]];
    } else {
        [self.accelometerSPLView.led setImage:[UIImage imageNamed:@"redLED"]];
    }
}

- (void) singleTapped {
    _freeze ^= 1;
    [self setLedMeasuring:_freeze == NO];
}

- (void) setFreezeMeasurement:(BOOL)yesNo {
    _freeze = yesNo;
    [self setLedMeasuring:_freeze == NO];
}
@end
