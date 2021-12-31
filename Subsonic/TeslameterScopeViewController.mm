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
//  TeslameterScopeViewController.m

#import "TeslameterScopeViewController.h"
#import "Environment.h"

static unsigned long long teslameterScopeBufferFillIndex = 0;

//#import "FFTHelper.hh"

long long flushTeslaScopeCount = 0;
NSDate *teslaScopeFlushDate = nil;

void initTeslameterScope(void) {
    flushTeslaScopeCount = 0;
}

Float64 minTeslaScopeRedValue = DBL_MAX;
Float64 maxTeslaScopeRedValue = DBL_MIN;
Float64 avgTeslaScopeRedValue = 0;
Float64 minTeslaScopeGreenValue = DBL_MAX;
Float64 maxTeslaScopeGreenValue = DBL_MIN;
Float64 avgTeslaScopeGreenValue = 0;
Float64 minTeslaScopeBlueValue = DBL_MAX;
Float64 maxTeslaScopeBlueValue = DBL_MIN;
Float64 avgTeslaScopeBlueValue = 0;

TeslameterScopeView * __weak teslameter_scope_view = nil;
BOOL *teslameter_scope_freeze_p = nil;

@interface TeslameterScopeViewController ()

@end

@implementation TeslameterScopeViewController

#pragma mark - TeslameterScope

- (void) initTeslameterScope {
    initTeslameterScope();
}

- (void) postUpdate {
    
//    DEBUG_LOG(@"(%llu)", accelometerSPLBufferFillIndex);
    
#if (LOAD_DUMMY_DATA && TARGET_IPHONE_SIMULATOR)
// このパスを通過する。
    [self locationManager:_locationManager didUpdateHeading:nil];
#else
    dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
        [teslameter_scope_view setNeedsDisplay];
    });
#endif
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    _freeze = YES;
    [self setLedMeasuring:_freeze == NO];

    // setup the location manager
    _locationManager = [[CLLocationManager alloc] init];
    
    // check if the hardware has a compass
    if ([CLLocationManager headingAvailable] == NO) {
        // No compass is available. This application cannot function without a compass,
        // so a dialog will be displayed and no magnetic data will be measured.
        self.locationManager = nil;
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"No Compass!", @"No Compass!")
                                                                                 message:NSLocalizedString(@"This device does not have the ability to measure magnetic fields.", @"This device does not have the ability to measure magnetic fields.")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Close", @"Close")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
                                                              // 何もしない
                                                          }]];
        [self presentViewController:alertController animated:YES completion:nil];
    } else {
        // heading service configuration
        self.locationManager.headingFilter = kCLHeadingFilterNone;
        
        // setup delegate callbacks
        self.locationManager.delegate = self;
    }
    teslaScopeFlushDate = [NSDate date];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
#if LOAD_DUMMY_DATA
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:REFRESH_INTERVAL target:self selector:@selector(postUpdate) userInfo:nil repeats:YES];
#endif
    self.teslameterScopeView.delegate = self;
    self.teslameterScopeView.header.text = @"";
    teslameter_scope_view = self.teslameterScopeView;

    // startMeasurement に先立つこと。
    teslameter_scope_freeze_p = &_freeze;
    
    _freeze = NO;
    [self setLedMeasuring:_freeze == NO];

    // start the compass
    [self.locationManager startUpdatingHeading];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.teslameterScopeView.delegate = nil;

    // 全てのオペレーションキューを停止する。
    [queue cancelAllOperations];

    // stop the compass
    [self.locationManager stopUpdatingHeading];
}

#if 0
- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                 duration:(NSTimeInterval)duration
{
    self.toPortrait = (toInterfaceOrientation == UIInterfaceOrientationPortrait || toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);

    // maintainPinch を実行する。
    [self.teslameterScopeView setNeedsLayout];
    _contentConstraint.constant = CONSTRAINT_MAGIC;
}
#else
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    self.toPortrait = (size.width < size.height);

    // maintainPinch を実行する。
    [self.teslameterScopeView setNeedsLayout];
    _contentConstraint.constant = CONSTRAINT_MAGIC;
}
#endif

#if 0
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    // maintainPinch を実行する。
    [self.teslameterScopeView setNeedsLayout];
}
#else
- (void) traitCollectionDidChange: (UITraitCollection *) previousTraitCollection {
    [super traitCollectionDidChange: previousTraitCollection];

    // maintainPinch を実行する。
    [self.teslameterScopeView setNeedsLayout];
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

#pragma mark - CLLocationManagerDelegate

// This delegate method is invoked when the location manager has heading data.
- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)heading {

#if 0
    // Update the labels with the raw x, y, and z values.
    self.xLabel.text = [NSString stringWithFormat:@"%.1f", heading.x];
    self.yLabel.text = [NSString stringWithFormat:@"%.1f", heading.y];
    self.zLabel.text = [NSString stringWithFormat:@"%.1f", heading.z];
    
    // Compute and display the magnitude (size or strength) of the vector.
    //      magnitude = sqrt(x^2 + y^2 + z^2)
    CGFloat magnitude = sqrt((heading.x*heading.x + heading.y*heading.y + heading.z*heading.z) / 1.0);
    [self.magnitudeLabel setText:[NSString stringWithFormat:@"%.1f", magnitude]];
    
    // Update the graph with the new magnetic reading.
    [self.graphView updateHistoryWithX:heading.x y:heading.y z:heading.z];
#else
    if (*teslameter_scope_freeze_p == NO) {
        flushTeslaScopeCount++;
        
        Float32 x = ABS(heading.x);
        Float32 y = ABS(heading.y);
        Float32 z = ABS(heading.z);
        Float64 sumX = avgTeslaScopeRedValue * (flushTeslaScopeCount-1) + x;
        Float64 sumY = avgTeslaScopeGreenValue * (flushTeslaScopeCount-1) + y;
        Float64 sumZ = avgTeslaScopeBlueValue * (flushTeslaScopeCount-1) + z;

        if (maxTeslaScopeRedValue < x) {
            maxTeslaScopeRedValue = x;
        }
        if (x && minTeslaScopeRedValue > x) {
            minTeslaScopeRedValue = x;
        }
        avgTeslaScopeRedValue = sumX / ((Float64) flushTeslaScopeCount);
        //
        if (maxTeslaScopeGreenValue < y) {
            maxTeslaScopeGreenValue = y;
        }
        if (y && minTeslaScopeGreenValue > y) {
            minTeslaScopeGreenValue = y;
        }
        avgTeslaScopeGreenValue = sumY / ((Float64) flushTeslaScopeCount);
        //
        if (maxTeslaScopeBlueValue < z) {
            maxTeslaScopeBlueValue = z;
        }
        if (z && minTeslaScopeBlueValue > z) {
            minTeslaScopeBlueValue = z;
        }
        avgTeslaScopeBlueValue = sumZ / ((Float64) flushTeslaScopeCount);
        
        // リングバッファにデータを1つ追加する。
        [teslameter_scope_view enqueueData:x xyz:0];
        // リングバッファにデータを1つ追加する。
        [teslameter_scope_view enqueueData:y xyz:1];
        // リングバッファにデータを1つ追加する。
        [teslameter_scope_view enqueueData:z xyz:2];
        
        teslameter_scope_view.maxRed = maxTeslaScopeRedValue;
#if (LOAD_DUMMY_DATA && TARGET_IPHONE_SIMULATOR)
        teslameter_scope_view.avgRed = maxTeslaScopeRedValue;
#else
        teslameter_scope_view.avgRed = avgTeslaScopeRedValue;
#endif
        teslameter_scope_view.minRed = minTeslaScopeRedValue;
        teslameter_scope_view.maxGreen = maxTeslaScopeGreenValue;
#if (LOAD_DUMMY_DATA && TARGET_IPHONE_SIMULATOR)
        teslameter_scope_view.avgGreen = maxTeslaScopeGreenValue;
#else
        teslameter_scope_view.avgGreen = avgTeslaScopeGreenValue;
#endif
        teslameter_scope_view.minGreen = minTeslaScopeGreenValue;
        teslameter_scope_view.maxBlue = maxTeslaScopeBlueValue;
#if (LOAD_DUMMY_DATA && TARGET_IPHONE_SIMULATOR)
        teslameter_scope_view.avgBlue = maxTeslaScopeBlueValue;
#else
        teslameter_scope_view.avgBlue = avgTeslaScopeBlueValue;
#endif
        teslameter_scope_view.minBlue = minTeslaScopeBlueValue;
    }
    NSDate *date = [NSDate date];
    if ([date timeIntervalSinceDate:teslaScopeFlushDate] > REFRESH_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
        [teslameter_scope_view setNeedsDisplay];
        teslaScopeFlushDate = date;
    } else {
        DEBUG_LOG(@"%s レイテンシーが小さすぎ！", __func__);
    }
    teslameterScopeBufferFillIndex++;
#endif
}

// This delegate method is invoked when the location managed encounters an error condition.
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if ([error code] == kCLErrorDenied) {
        // This error indicates that the user has denied the application's request to use location services.
        [manager stopUpdatingHeading];
    } else if ([error code] == kCLErrorHeadingFailure) {
        // This error indicates that the heading could not be determined, most likely because of strong magnetic interference.
    }
}

#pragma mark - AccelometerViewProtocol delegate

- (void) setLedMeasuring:(BOOL)onOff {
    
    if (onOff) {
        [self.teslameterScopeView.led setImage:[UIImage imageNamed:@"greenLED"]];
    } else {
        [self.teslameterScopeView.led setImage:[UIImage imageNamed:@"redLED"]];
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
