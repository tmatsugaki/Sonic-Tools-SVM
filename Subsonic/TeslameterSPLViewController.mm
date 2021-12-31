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
//  TeslameterSPLViewController.m

#import "TeslameterSPLViewController.h"
#import "Environment.h"

static unsigned long long teslameterSPLBufferFillIndex = 0;

#import "FFTHelper.hh"

#pragma mark - Teslameter

long long flushTeslaSPLCount = 0;
NSDate *teslaRMSFlushDate = nil;

Float64 minTeslaSPLRedValue = DBL_MAX;
Float64 maxTeslaSPLRedValue = DBL_MIN;
Float64 avgTeslaSPLRedValue = 0;
Float64 minTeslaSPLGreenValue = DBL_MAX;
Float64 maxTeslaSPLGreenValue = DBL_MIN;
Float64 avgTeslaSPLGreenValue = 0;
Float64 minTeslaSPLBlueValue = DBL_MAX;
Float64 maxTeslaSPLBlueValue = DBL_MIN;
Float64 avgTeslaSPLBlueValue = 0;

void initTeslameterSPL(void) {
    flushTeslaSPLCount = 0;

    minTeslaSPLRedValue = DBL_MAX;
    maxTeslaSPLRedValue = DBL_MIN;
    avgTeslaSPLRedValue = 0;
    minTeslaSPLGreenValue = DBL_MAX;
    maxTeslaSPLGreenValue = DBL_MIN;
    avgTeslaSPLGreenValue = 0;
    minTeslaSPLBlueValue = DBL_MAX;
    maxTeslaSPLBlueValue = DBL_MIN;
    avgTeslaSPLBlueValue = 0;
}

TeslameterSPLView * __weak teslameter_spl_view = nil;
BOOL *teslameter_spl_freeze_p = nil;

@interface TeslameterSPLViewController ()

@end

@implementation TeslameterSPLViewController

#pragma mark - TeslameterSPL

- (void) initTeslameterSPL {
    initTeslameterSPL();
}

- (void) postUpdate {
    
//    DEBUG_LOG(@"(%llu)", accelometerSPLBufferFillIndex);
    
#if (LOAD_DUMMY_DATA && TARGET_IPHONE_SIMULATOR)
// このパスを通過する。
    [self locationManager:_locationManager didUpdateHeading:nil];
#else
    dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
        [teslameter_spl_view setNeedsDisplay];
        [teslameter_spl_view.f3 setNeedsDisplay];
        [teslameter_spl_view.f2 setNeedsDisplay];
        [teslameter_spl_view.f1 setNeedsDisplay];
        [teslameter_spl_view.f0 setNeedsDisplay];
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
        
        // start the compass
        [self.locationManager startUpdatingHeading];
    }
    teslaRMSFlushDate = [NSDate date];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
#if (CSV_OUT == ON)
#if (CSV_OUT_ONE_BUTTON == ON)
    _teslameterSPLView.stopSwitch.hidden = YES;
#else
    _teslameterSPLView.stopSwitch.hidden = NO;
#endif
    _teslameterSPLView.playPauseSwitch.hidden = NO;
#endif

#if LOAD_DUMMY_DATA
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:REFRESH_INTERVAL target:self selector:@selector(postUpdate) userInfo:nil repeats:YES];
#endif
    if (self.navigationController) {
        DEBUG_LOG(@"%g", self.navigationController.navigationBar.frame.size.height);
    }
    self.teslameterSPLView.header.text = @"";

    self.teslameterSPLView.delegate = self;
    teslameter_spl_view = self.teslameterSPLView;
    // startMeasurement に先立つこと。
    teslameter_spl_freeze_p = &_freeze;

    self.teslameterSPLView.dot.layer.cornerRadius = self.teslameterSPLView.dot.frame.size.width / 2.0;

    // start the compass
    [self.locationManager startUpdatingHeading];

    // VFD の μT とラベルの重なりをなくす。
    self.teslameterSPLView.lblUT.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    _freeze = NO;
    [self setLedMeasuring:_freeze == NO];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.teslameterSPLView.delegate = nil;

    // 全てのオペレーションキューを停止する。
    [queue cancelAllOperations];

    // stop the compass
    [self.locationManager stopUpdatingHeading];

#if (CSV_OUT == ON)
    [_teslameterSPLView stopAction:nil];
#endif
}

#if 0
- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                 duration:(NSTimeInterval)duration
{
    self.toPortrait = (toInterfaceOrientation == UIInterfaceOrientationPortrait || toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
    
    // maintainPinch を実行する。
    [self.teslameterSPLView setNeedsLayout];
    _contentConstraint.constant = CONSTRAINT_MAGIC;

    // VFD の μT とラベルの重なりをなくす。
    self.teslameterSPLView.lblUT.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
}
#else
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    self.toPortrait = (size.width < size.height);

    // maintainPinch を実行する。
    [self.teslameterSPLView setNeedsLayout];
    _contentConstraint.constant = CONSTRAINT_MAGIC;
    
    // VFD の μT とラベルの重なりをなくす。
    self.teslameterSPLView.lblUT.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
}
#endif

#if 0
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    
    // maintainPinch を実行する。
    [self.teslameterSPLView setNeedsLayout];
    // VFD の μT とラベルの重なりをなくす。
    self.teslameterSPLView.lblUT.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
}
#else
- (void) traitCollectionDidChange: (UITraitCollection *) previousTraitCollection {
    [super traitCollectionDidChange: previousTraitCollection];

    // maintainPinch を実行する。
    [self.teslameterSPLView setNeedsLayout];
    // VFD の μT とラベルの重なりをなくす。
    self.teslameterSPLView.lblUT.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
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
    // magnitude = sqrt(x^2 + y^2 + z^2)
    CGFloat magnitude = sqrt((heading.x*heading.x + heading.y*heading.y + heading.z*heading.z) / 1.0);
    [self.magnitudeLabel setText:[NSString stringWithFormat:@"%.1f", magnitude]];
    
    // Update the graph with the new magnetic reading.
    [self.graphView updateHistoryWithX:heading.x y:heading.y z:heading.z];
#else
    if (*teslameter_spl_freeze_p == NO) {
        flushTeslaSPLCount++;
        
        Float32 x = ABS(heading.x);
        Float32 y = ABS(heading.y);
        Float32 z = ABS(heading.z);
        Float64 sumX = avgTeslaSPLRedValue * (flushTeslaSPLCount-1) + x;
        Float64 sumY = avgTeslaSPLGreenValue * (flushTeslaSPLCount-1) + y;
        Float64 sumZ = avgTeslaSPLBlueValue * (flushTeslaSPLCount-1) + z;

        if (maxTeslaSPLRedValue < x) {
            maxTeslaSPLRedValue = x;
        }
        if (x && minTeslaSPLRedValue > x) {
            minTeslaSPLRedValue = x;
        }
        avgTeslaSPLRedValue = sumX / ((Float64) flushTeslaSPLCount);
        //
        if (maxTeslaSPLGreenValue < y) {
            maxTeslaSPLGreenValue = y;
        }
        if (y && minTeslaSPLGreenValue > y) {
            minTeslaSPLGreenValue = y;
        }
        avgTeslaSPLGreenValue = sumY / ((Float64) flushTeslaSPLCount);
        //
        if (maxTeslaSPLBlueValue < z) {
            maxTeslaSPLBlueValue = z;
        }
        if (z && minTeslaSPLBlueValue > z) {
            minTeslaSPLBlueValue = z;
        }
        avgTeslaSPLBlueValue = sumZ / ((Float64) flushTeslaSPLCount);
        
        Float32 rmsValue = sqrt((x * x + y * y + z * z) / 1.0);
        
//        DEBUG_LOG(@"X:%g, Y:%g, Z:%g [%g]", x, y, z, rmsValue);
        
        // リングバッファにデータを1つ追加する。
        [teslameter_spl_view enqueueData:rmsValue];
        
        teslameter_spl_view.rmsValue = rmsValue;
        teslameter_spl_view.maxRMS = sqrt((maxTeslaSPLRedValue  * maxTeslaSPLRedValue +
                                          maxTeslaSPLGreenValue * maxTeslaSPLGreenValue +
                                          maxTeslaSPLBlueValue  * maxTeslaSPLBlueValue) / 1.0);
        teslameter_spl_view.avgRMS = sqrt((avgTeslaSPLRedValue  * avgTeslaSPLRedValue +
                                          avgTeslaSPLGreenValue * avgTeslaSPLGreenValue +
                                          avgTeslaSPLBlueValue  * avgTeslaSPLBlueValue) / 1.0);
        teslameter_spl_view.minRMS = sqrt((minTeslaSPLRedValue  * minTeslaSPLRedValue +
                                          minTeslaSPLGreenValue * minTeslaSPLGreenValue +
                                          minTeslaSPLBlueValue  * minTeslaSPLBlueValue) / 1.0);
    }
    NSDate *date = [NSDate date];
    if ([date timeIntervalSinceDate:teslaRMSFlushDate] > REFRESH_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
        [teslameter_spl_view setNeedsDisplay];
        [teslameter_spl_view.f3 setNeedsDisplay];
        [teslameter_spl_view.f2 setNeedsDisplay];
        [teslameter_spl_view.f1 setNeedsDisplay];
        [teslameter_spl_view.f0 setNeedsDisplay];
        teslaRMSFlushDate = date;
    } else {
        DEBUG_LOG(@"%s レイテンシーが小さすぎ！", __func__);
    }
    teslameterSPLBufferFillIndex++;
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
        [self.teslameterSPLView.led setImage:[UIImage imageNamed:@"greenLED"]];
    } else {
        [self.teslameterSPLView.led setImage:[UIImage imageNamed:@"redLED"]];
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
