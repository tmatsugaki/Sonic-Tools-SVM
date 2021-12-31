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
//  AccelometerScopeViewController.m

#import "AccelometerScopeViewController.h"
#include "FFTHelper.hh"
#include "Environment.h"

static unsigned long long accelometerScopeBufferFillIndex = 0;

#import "FFTHelper.hh"

long long flushAcceloScopeCount = 0;
NSDate *accelScopeFlushDate = nil;

void initAccelometerScope(void) {
    flushAcceloScopeCount = 0;
}

Float64 minAcceloScopeRedValue = DBL_MAX;
Float64 maxAcceloScopeRedValue = DBL_MIN;
Float64 avgAcceloScopeRedValue = 0;
Float64 minAcceloScopeGreenValue = DBL_MAX;
Float64 maxAcceloScopeGreenValue = DBL_MIN;
Float64 avgAcceloScopeGreenValue = 0;
Float64 minAcceloScopeBlueValue = DBL_MAX;
Float64 maxAcceloScopeBlueValue = DBL_MIN;
Float64 avgAcceloScopeBlueValue = 0;

AccelometerScopeView * __weak accelometer_scope_view = nil;
BOOL *accelometer_scope_freeze_p = nil;

@interface AccelometerScopeViewController ()

@end

@implementation AccelometerScopeViewController

- (void) postUpdate {
    
//    DEBUG_LOG(@"(%llu)", accelometerSPLBufferFillIndex);
    
#if (LOAD_DUMMY_DATA && TARGET_IPHONE_SIMULATOR)
// このパスを通過する。
    if (*accelometer_scope_freeze_p == NO) {
        flushAcceloScopeCount++;
        
        Float32 x = 0.0;
        Float32 y = 0.0;
        Float32 z = 0.0;
        Float64 sumX = avgAcceloScopeRedValue * (flushAcceloScopeCount-1) + x;
        Float64 sumY = avgAcceloScopeGreenValue * (flushAcceloScopeCount-1) + y;
        Float64 sumZ = avgAcceloScopeBlueValue * (flushAcceloScopeCount-1) + z;

        if (maxAcceloScopeRedValue < x) {
            maxAcceloScopeRedValue = x;
        }
        if (x && minAcceloScopeRedValue > x) {
            minAcceloScopeRedValue = x;
        }
        avgAcceloScopeRedValue = sumX / ((Float64) flushAcceloScopeCount);
        //
        if (maxAcceloScopeGreenValue < y) {
            maxAcceloScopeGreenValue = y;
        }
        if (y && minAcceloScopeGreenValue > y) {
            minAcceloScopeGreenValue = y;
        }
        avgAcceloScopeGreenValue = sumY / ((Float64) flushAcceloScopeCount);
        //
        if (maxAcceloScopeBlueValue < z) {
            maxAcceloScopeBlueValue = z;
        }
        if (z && minAcceloScopeBlueValue > z) {
            minAcceloScopeBlueValue = z;
        }
        avgAcceloScopeBlueValue = sumZ / ((Float64) flushAcceloScopeCount);
        
        // リングバッファにデータを1つ追加する。
        [accelometer_scope_view enqueueData:x xyz:0];
        // リングバッファにデータを1つ追加する。
        [accelometer_scope_view enqueueData:y xyz:1];
        // リングバッファにデータを1つ追加する。
        [accelometer_scope_view enqueueData:z xyz:2];
        
        accelometer_scope_view.maxRed = maxAcceloScopeRedValue;
//        accelometer_scope_view.avgRed = avgAcceloScopeRedValue;
        accelometer_scope_view.avgRed = maxAcceloScopeRedValue;
        accelometer_scope_view.minRed = minAcceloScopeRedValue;
        accelometer_scope_view.maxGreen = maxAcceloScopeGreenValue;
//        accelometer_scope_view.avgGreen = avgAcceloScopeGreenValue;
        accelometer_scope_view.avgGreen = maxAcceloScopeGreenValue;
        accelometer_scope_view.minGreen = minAcceloScopeGreenValue;
        accelometer_scope_view.maxBlue = maxAcceloScopeBlueValue;
//        accelometer_scope_view.avgBlue = avgAcceloScopeBlueValue;
        accelometer_scope_view.avgBlue = maxAcceloScopeBlueValue;
        accelometer_scope_view.minBlue = minAcceloScopeBlueValue;
    }
    NSDate *date = [NSDate date];
    if ([date timeIntervalSinceDate:accelScopeFlushDate] > REFRESH_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
        dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
            [accelometer_scope_view setNeedsDisplay];
        });
        accelScopeFlushDate = date;
    } else {
        DEBUG_LOG(@"%s レイテンシーが小さすぎ！", __func__);
    }
    accelometerScopeBufferFillIndex++;
#else
    dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
        [accelometer_scope_view setNeedsDisplay];
    });
#endif
}

#pragma mark - AccelometerScope

- (void) initAccelometerScope {
    initAccelometerScope();
}

- (void) startMeasurement {
    queue = [NSOperationQueue currentQueue];
    // startAccelerometerUpdatesToQueue:withHandler:
    [motionManager startAccelerometerUpdatesToQueue:queue
                                        withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
                                            if (*accelometer_scope_freeze_p == NO) {
                                                CMAcceleration acceleration = accelerometerData.acceleration;
                                                
                                                flushAcceloScopeCount++;
                                                
                                                Float32 x = -acceleration.x; // Reverse
                                                Float32 y = -acceleration.y; // Reverse
                                                Float32 z = -acceleration.z; // Reverse
                                                Float64 sumX = avgAcceloScopeRedValue * (flushAcceloScopeCount-1) + x;
                                                Float64 sumY = avgAcceloScopeGreenValue * (flushAcceloScopeCount-1) + y;
                                                Float64 sumZ = avgAcceloScopeBlueValue * (flushAcceloScopeCount-1) + z;
                                                //                                            DEBUG_LOG(@"%g,%g,%g", x, y, z);
                                                //
                                                if (maxAcceloScopeRedValue < x) {
                                                    maxAcceloScopeRedValue = x;
                                                }
                                                if (x && minAcceloScopeRedValue > x) {
                                                    minAcceloScopeRedValue = x;
                                                }
                                                avgAcceloScopeRedValue = sumX / ((Float64) flushAcceloScopeCount);
                                                //
                                                if (maxAcceloScopeGreenValue < y) {
                                                    maxAcceloScopeGreenValue = y;
                                                }
                                                if (y && minAcceloScopeGreenValue > y) {
                                                    minAcceloScopeGreenValue = y;
                                                }
                                                avgAcceloScopeGreenValue = sumY / ((Float64) flushAcceloScopeCount);
                                                //
                                                if (maxAcceloScopeBlueValue < z) {
                                                    maxAcceloScopeBlueValue = z;
                                                }
                                                if (z && minAcceloScopeBlueValue > z) {
                                                    minAcceloScopeBlueValue = z;
                                                }
                                                avgAcceloScopeBlueValue = sumZ / ((Float64) flushAcceloScopeCount);

                                                // リングバッファにデータを1つ追加する。
                                                [accelometer_scope_view enqueueData:x xyz:0];
                                                // リングバッファにデータを1つ追加する。
                                                [accelometer_scope_view enqueueData:y xyz:1];
                                                // リングバッファにデータを1つ追加する。
                                                [accelometer_scope_view enqueueData:z xyz:2];
                                                
                                                accelometer_scope_view.maxRed = maxAcceloScopeRedValue;
                                                accelometer_scope_view.avgRed = avgAcceloScopeRedValue;
                                                accelometer_scope_view.minRed = minAcceloScopeRedValue;
                                                accelometer_scope_view.maxGreen = maxAcceloScopeGreenValue;
                                                accelometer_scope_view.avgGreen = avgAcceloScopeGreenValue;
                                                accelometer_scope_view.minGreen = minAcceloScopeGreenValue;
                                                accelometer_scope_view.maxBlue = maxAcceloScopeBlueValue;
                                                accelometer_scope_view.avgBlue = avgAcceloScopeBlueValue;
                                                accelometer_scope_view.minBlue = minAcceloScopeBlueValue;
                                            }
                                            NSDate *date = [NSDate date];
                                            if ([date timeIntervalSinceDate:accelScopeFlushDate] > REFRESH_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
                                                dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
                                                    [accelometer_scope_view setNeedsDisplay];
                                                });
                                                accelScopeFlushDate = date;
                                            } else {
                                                DEBUG_LOG(@"%s レイテンシーが小さすぎ！", __func__);
                                            }
                                            accelometerScopeBufferFillIndex++;
                                    }];
}

- (void) stopMeasurement {
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    _freeze = YES;
    [self setLedMeasuring:_freeze == NO];

    accelScopeFlushDate = [NSDate date];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
#if LOAD_DUMMY_DATA
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:REFRESH_INTERVAL target:self selector:@selector(postUpdate) userInfo:nil repeats:YES];
#endif
    self.accelometerScopeView.delegate = self;
    self.accelometerScopeView.header.text = @"";
    accelometer_scope_view = self.accelometerScopeView;

    // startMeasurement に先立つこと。
    accelometer_scope_freeze_p = &_freeze;
    
    _freeze = NO;
    [self setLedMeasuring:_freeze == NO];

    // 加速度センサー関連の初期化
    if (motionManager == nil) {
        motionManager = [[CMMotionManager alloc] init];
        motionManager.accelerometerUpdateInterval  = 1.0 / ACCELO_SCOPE_SAMPLE_RATE; // Update at 32Hz
    }
    if (motionManager.accelerometerAvailable) {
        DEBUG_LOG(@"Accelerometer avaliable");
        [self startMeasurement];
    }
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.accelometerScopeView.delegate = nil;

    // 全てのオペレーションキューを停止する。
    [queue cancelAllOperations];

    if (motionManager.accelerometerAvailable) {
        [motionManager stopAccelerometerUpdates];
    }
}

#if 0
- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                 duration:(NSTimeInterval)duration
{
    self.toPortrait = (toInterfaceOrientation == UIInterfaceOrientationPortrait || toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);

    // maintainPinch を実行する。
    [self.accelometerScopeView setNeedsLayout];
    _contentConstraint.constant = CONSTRAINT_MAGIC;
}
#else
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    self.toPortrait = (size.width < size.height);

    // maintainPinch を実行する。
    [self.accelometerScopeView setNeedsLayout];
    _contentConstraint.constant = CONSTRAINT_MAGIC;
}
#endif

#if 0
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    // maintainPinch を実行する。
    [self.accelometerScopeView setNeedsLayout];
}
#else
- (void) traitCollectionDidChange: (UITraitCollection *) previousTraitCollection {
    [super traitCollectionDidChange: previousTraitCollection];

    // maintainPinch を実行する。
    [self.accelometerScopeView setNeedsLayout];
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
        [self.accelometerScopeView.led setImage:[UIImage imageNamed:@"greenLED"]];
    } else {
        [self.accelometerScopeView.led setImage:[UIImage imageNamed:@"redLED"]];
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
