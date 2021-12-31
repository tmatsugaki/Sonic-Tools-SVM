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
//  AccelometerSpectrumViewController.m

#import "AccelometerSpectrumViewController.h"
#include "FFTHelper.hh"
#include "Environment.h"

static unsigned long long accelometerSpectrumBufferFillIndex = 0;
Float32 accelo_spectrum_x_buffer[ACCELO_SPECTRUM_FFT_SIZE];
Float32 accelo_spectrum_y_buffer[ACCELO_SPECTRUM_FFT_SIZE];
Float32 accelo_spectrum_z_buffer[ACCELO_SPECTRUM_FFT_SIZE];

#import "FFTHelper.hh"

/// Nyquist Maximum Frequency
const Float32 acceloSpectrumNyquistMaxFreq = ACCELO_SPECTRUM_SAMPLE_RATE/2.0;

BOOL weakAccelometer = NO;
NSDate *accelSpectrumFlushDate = nil;

/// caculates HZ value for specified index from a FFT bins vector
Float32 acceloSpectrumFrequencyHerzValue(long frequencyIndex, long fftVectorSize, Float32 nyquistFrequency ) {
    return ((Float32)frequencyIndex/(Float32)fftVectorSize) * nyquistFrequency;
}

// The Main FFT Helper
//FFTHelperRef *acceloSpectrumFftConverter = NULL;
FFTHelperRef acceloSpectrumFftConverter;

/// max value from vector with value index (using Accelerate Framework)
static Float32 acceloSpectrumVectorMaxValueACC32_index(Float32 *vector, unsigned long size, long step, unsigned long *outIndex) {
    Float32 maxVal;
    // Vector maximum value with index; single precision.
    vDSP_maxvi(vector, step, &maxVal, outIndex, size);
    return maxVal;
}

///returns HZ of the strongest frequency.
static Float32 acceloSpectrumStrongestFrequencyHZ(Float32 *buffer, FFTHelperRef *fftHelper, UInt32 frameSize, unsigned long *maxIndex, Float32 *freqValue) {
    
    //the actual FFT happens here
    //****************************************************************************
    Float32 *fftData = computeFFT(fftHelper, buffer, frameSize);
    //****************************************************************************
    
    fftData[0] = 0.0;    // 0.0 G
    if (weakAccelometer) {
        fftData[1] = 0.0;    // 0.0 G
    }
    unsigned long length = frameSize/2.0;
    Float32 max = 0;
    max = acceloSpectrumVectorMaxValueACC32_index(fftData, length, 1, maxIndex);
    if (freqValue!=NULL) { *freqValue = max; }
    Float32 HZ = acceloSpectrumFrequencyHerzValue(*maxIndex, length, acceloSpectrumNyquistMaxFreq);
    return HZ;
}

long long flushAcceloSpectrumCount = 0;
Float64 minAcceloSpectrumValue = 100.0; // 100 G
Float64 maxAcceloSpectrumValue = 0.0;   // 0.0 G
Float64 avgAcceloSpectrumValue = 0.0;

void initAccelometerSpectrum(void) {
    flushAcceloSpectrumCount = 0;
    
    minAcceloSpectrumValue = 100.0;
    maxAcceloSpectrumValue = 0.0;
    avgAcceloSpectrumValue = 0.0;
}

AccelometerSpectrumView * __weak accelometer_spectrum_view = nil;
BOOL *accelometer_spectrum_freeze_p = nil;

@interface AccelometerSpectrumViewController ()

@end

@implementation AccelometerSpectrumViewController

- (void) postUpdate {
    
//    DEBUG_LOG(@"(%llu)", accelometerSpectrumBufferFillIndex);
#if (LOAD_DUMMY_DATA && TARGET_IPHONE_SIMULATOR)
// このパスを通過する。
    static long long flushCounter = 0;
    static long long oneHzCounter = 0;

    if ((accelometerSpectrumBufferFillIndex % ACCELO_SPECTRUM_FFT_SIZE) == ACCELO_SPECTRUM_FFT_SIZE - 1)
    {
        if (*accelometer_spectrum_freeze_p == NO) {
            unsigned long maxHZIndex[3];
            Float32 maxHZValue[3];
            Float32 maxHZ[3];
            Float32 fftResult[3][ACCELO_SPECTRUM_FFT_SIZE/2];
            NSUInteger resultIndex;
            
            if (weakAccelometer) {
                DEBUG_LOG(@"maxHZValue:%g", maxHZValue);
            }
            resultIndex = [self getResult:maxHZIndex maxHZValue:maxHZValue maxHZ:maxHZ fftResult:fftResult];
            [accelometer_spectrum_view memmove:accelometer_spectrum_view.fftDataX
                                          srcX:&fftResult[0][0]
                                          dstY:accelometer_spectrum_view.fftDataY
                                          srcY:&fftResult[1][0]
                                          dstZ:accelometer_spectrum_view.fftDataZ
                                          srcZ:&fftResult[2][0]
                                           len:ACCELO_SPECTRUM_FFT_SIZE/2];
            accelometer_spectrum_view.maxIndex = maxHZIndex[resultIndex];
            accelometer_spectrum_view.maxHZ = maxHZ[resultIndex];
            if (maxHZ[resultIndex] == 1.0) {
                oneHzCounter++;
            }
            accelometer_spectrum_view.maxHZValue = maxHZValue[resultIndex] ? maxHZValue[resultIndex] : 0.0;  // 0G とする。
            flushCounter++;
            if (flushCounter == 10 && flushCounter == oneHzCounter)
            {// Accelerometer seems to be dull.
                weakAccelometer = YES;
            }
        }
        NSDate *date = [NSDate date];
        if ([date timeIntervalSinceDate:accelSpectrumFlushDate] > REFRESH_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
            dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
                [accelometer_spectrum_view setNeedsDisplay];
                [accelometer_spectrum_view.f1 setNeedsDisplay];
                [accelometer_spectrum_view.f0 setNeedsDisplay];
            });
            accelSpectrumFlushDate = date;
        } else {
            DEBUG_LOG(@"%s レイテンシーが小さすぎ！", __func__);
        }
    }
    accelometerSpectrumBufferFillIndex++;
#else
    dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
        [accelometer_spectrum_view setNeedsDisplay];
        [accelometer_spectrum_view.f1 setNeedsDisplay];
        [accelometer_spectrum_view.f0 setNeedsDisplay];
    });
#endif
}

#pragma mark - AccelometerSpectrum

- (void) initAccelometerSpectrum {
    initAccelometerSpectrum();
}

- (NSUInteger) getResult:(unsigned long [])maxHZIndex
              maxHZValue:(Float32 []) maxHZValue
                   maxHZ:(Float32 []) maxHZ
               fftResult:(Float32 [][ACCELO_SPECTRUM_FFT_SIZE/2])fftResult {
//    unsigned long maxHZIndex[3];
//    Float32 maxHZValue[3];
//    Float32 maxHZ[3];
//    Float32 fftResult[3][ACCELO_SPECTRUM_FFT_SIZE/2];
    NSUInteger resultIndex;
    
    maxHZ[0] = acceloSpectrumStrongestFrequencyHZ(accelo_spectrum_x_buffer, &acceloSpectrumFftConverter, ACCELO_SPECTRUM_FFT_SIZE, &maxHZIndex[0], &maxHZValue[0]);
    // FFTはリングバッファでなく1行分のデータをブロックコピー
    memcpy(fftResult[0], acceloSpectrumFftConverter.outFFTData, sizeof(Float32)*ACCELO_SPECTRUM_FFT_SIZE/2);
    
    maxHZ[1] = acceloSpectrumStrongestFrequencyHZ(accelo_spectrum_y_buffer, &acceloSpectrumFftConverter, ACCELO_SPECTRUM_FFT_SIZE, &maxHZIndex[1], &maxHZValue[1]);
    // FFTはリングバッファでなく1行分のデータをブロックコピー
    memcpy(fftResult[1], acceloSpectrumFftConverter.outFFTData, sizeof(Float32)*ACCELO_SPECTRUM_FFT_SIZE/2);
    
    maxHZ[2] = acceloSpectrumStrongestFrequencyHZ(accelo_spectrum_z_buffer, &acceloSpectrumFftConverter, ACCELO_SPECTRUM_FFT_SIZE, &maxHZIndex[2], &maxHZValue[2]);
    // FFTはリングバッファでなく1行分のデータをブロックコピー
    memcpy(fftResult[2], acceloSpectrumFftConverter.outFFTData, sizeof(Float32)*ACCELO_SPECTRUM_FFT_SIZE/2);
    
//    DEBUG_LOG(@"X:%.1fHz[%g], Y:%.1fHz[%g], Z:%.1fHz[%g]", maxHZ[0], maxHZValue[0], maxHZ[1], maxHZValue[1], maxHZ[2], maxHZValue[2]);
    
    if (maxHZValue[0] > maxHZValue[1])
    {// x > y
        if (maxHZValue[2] > maxHZValue[0])
        {// z > x > y
            resultIndex = 2;
        } else
        {//
            resultIndex = 0;
        }
    } else
    {// y > x
        if (maxHZValue[2] > maxHZValue[1])
        {// z > y > x
            resultIndex = 2;
        } else
        {// y > x
            resultIndex = 1;
        }
    }
    return resultIndex;
}

- (void) startMeasurement {
    static long long flushCounter = 0;
    static long long oneHzCounter = 0;
    queue = [NSOperationQueue currentQueue];
    // startAccelerometerUpdatesToQueue:withHandler:
    [motionManager startAccelerometerUpdatesToQueue:queue
                                        withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
                                            
                                            CMAcceleration acceleration = accelerometerData.acceleration;
                                            
                                            Float32 x = ABS(acceleration.x);
                                            Float32 y = ABS(acceleration.y);
                                            Float32 z = ABS(acceleration.z);

                                            NSUInteger index = (accelometerSpectrumBufferFillIndex % ACCELO_SPECTRUM_FFT_SIZE);
                                            accelo_spectrum_x_buffer[index] = x;
                                            accelo_spectrum_y_buffer[index] = y;
                                            accelo_spectrum_z_buffer[index] = z;
                                            if ((accelometerSpectrumBufferFillIndex % ACCELO_SPECTRUM_FFT_SIZE) == ACCELO_SPECTRUM_FFT_SIZE - 1)
                                            {
                                                if (*accelometer_spectrum_freeze_p == NO) {
                                                    unsigned long maxHZIndex[3];
                                                    Float32 maxHZValue[3];
                                                    Float32 maxHZ[3];
                                                    Float32 fftResult[3][ACCELO_SPECTRUM_FFT_SIZE/2];
                                                    NSUInteger resultIndex;

                                                    if (weakAccelometer) {
                                                        DEBUG_LOG(@"maxHZValue:%g", maxHZValue);
                                                    }
                                                    resultIndex = [self getResult:maxHZIndex maxHZValue:maxHZValue maxHZ:maxHZ fftResult:fftResult];

                                                    [accelometer_spectrum_view memmove:accelometer_spectrum_view.fftDataX
                                                                                  srcX:&fftResult[0][0]
                                                                                  dstY:accelometer_spectrum_view.fftDataY
                                                                                  srcY:&fftResult[1][0]
                                                                                  dstZ:accelometer_spectrum_view.fftDataZ
                                                                                  srcZ:&fftResult[2][0]
                                                                                   len:ACCELO_SPECTRUM_FFT_SIZE/2];
                                                    accelometer_spectrum_view.maxIndex = maxHZIndex[resultIndex];
                                                    accelometer_spectrum_view.maxHZ = maxHZ[resultIndex];
                                                    if (maxHZ[resultIndex] == 1.0) {
                                                        oneHzCounter++;
                                                    }
                                                    accelometer_spectrum_view.maxHZValue = maxHZValue[resultIndex] ? maxHZValue[resultIndex] : 0.0;  // 0G とする。
                                                    flushCounter++;
                                                    if (flushCounter == 10 && flushCounter == oneHzCounter)
                                                    {// Accelerometer seems to be dull.
                                                        weakAccelometer = YES;
                                                    }
                                                }
                                                NSDate *date = [NSDate date];
                                                if ([date timeIntervalSinceDate:accelSpectrumFlushDate] > REFRESH_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
                                                    dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
                                                        [accelometer_spectrum_view setNeedsDisplay];
                                                        [accelometer_spectrum_view.f1 setNeedsDisplay];
                                                        [accelometer_spectrum_view.f0 setNeedsDisplay];
                                                    });
                                                    accelSpectrumFlushDate = date;
                                                } else {
                                                    DEBUG_LOG(@"%s レイテンシーが小さすぎ！", __func__);
                                                }
                                            }
                                            accelometerSpectrumBufferFillIndex++;
                                        }];
}

- (void) stopMeasurement {
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    _freeze = YES;
    [self setLedMeasuring:_freeze == NO];

    //initialize stuff
//    acceloSpectrumFftConverter = FFTHelperCreate(ACCELO_SPECTRUM_FFT_SIZE);
    fftInitialized = FFTHelperInitialize(&acceloSpectrumFftConverter, ACCELO_SPECTRUM_FFT_SIZE);

    accelSpectrumFlushDate = [NSDate date];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

#if LOAD_DUMMY_DATA
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:REFRESH_INTERVAL target:self selector:@selector(postUpdate) userInfo:nil repeats:YES];
#endif
    self.accelometerSpectrumView.header.text = @"";

    self.accelometerSpectrumView.delegate = self;
    accelometer_spectrum_view = self.accelometerSpectrumView;
    // startMeasurement に先立つこと。
    accelometer_spectrum_freeze_p = &_freeze;

//    self.accelometerSpectrumView.dot.layer.cornerRadius = self.accelometerSpectrumView.dot.frame.size.width / 2.0;
    if (! fftInitialized) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"FFT Analyzer isn't initialized owing to memory shortage.", @"FFT Analyzer isn't initialized owing to memory shortage.")
                                                                                 message:NSLocalizedString(@"Please deallocate unused memory.", @"Please deallocate unused memory.")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Close", @"Close")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
                                                              // 何もしない
                                                          }]];
        [self presentViewController:alertController animated:YES completion:nil];
    } else {
        // 加速度センサー関連の初期化
        if (motionManager == nil) {
            motionManager = [[CMMotionManager alloc] init];
            motionManager.accelerometerUpdateInterval  = 1.0 / ACCELO_SPECTRUM_SAMPLE_RATE; // Update at 32Hz
        }
        if (motionManager.accelerometerAvailable) {
            DEBUG_LOG(@"Accelerometer avaliable");
            [self startMeasurement];
        }
    }
    // ヘッダーに設定情報を表示する。
    NSString *pathStr = [[NSBundle mainBundle] bundlePath];
    NSString *settingsBundlePath = [pathStr stringByAppendingPathComponent:@"Settings.bundle"];
    NSString *rootFinalPath = [settingsBundlePath stringByAppendingPathComponent:@"Root.plist"];
    
    NSDictionary *rootSettingsDict = [NSDictionary dictionaryWithContentsOfFile:rootFinalPath];
    NSArray *rootPrefSpecifierArray = [rootSettingsDict objectForKey:@"PreferenceSpecifiers"];
    
    NSString *windowFunctionTitle = @"";
    NSString *windowFunctionName = @"";
    
    for (NSDictionary *prefItem in rootPrefSpecifierArray)
    {
        NSString *keyValueStr = [prefItem objectForKey:@"Key"];
        id defaultValue = [prefItem objectForKey:@"DefaultValue"];
        NSString *title = [prefItem objectForKey:@"Title"];
        NSArray *titles = [prefItem objectForKey:@"Titles"];
        
        if (defaultValue) {
            if ([keyValueStr isEqualToString:kWindowFunctionKey]) {
                NSNumber *currentValue = [[NSUserDefaults standardUserDefaults] objectForKey:kWindowFunctionKey];
                
                windowFunctionTitle = NSLocalizedString(title, @"");
                windowFunctionName = NSLocalizedString(titles[((NSNumber *) currentValue).integerValue], @"");
            }
        }
    }
    if ([windowFunctionName length]) {
        self.accelometerSpectrumView.header.text = [NSString stringWithFormat:@"%@[%@]", windowFunctionTitle, windowFunctionName];
        [self performSelector:@selector(setHeaderMessage:) withObject:@"" afterDelay:10];
    }
}

- (void) setHeaderMessage:(NSString *)message {
    self.accelometerSpectrumView.header.text = message;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    //initialize stuff
//    acceloSpectrumFftConverter = FFTHelperCreate(ACCELO_SPECTRUM_FFT_SIZE);
    
    _freeze = NO;
    [self setLedMeasuring:_freeze == NO];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.accelometerSpectrumView.delegate = nil;

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

//    if (_toPortrait) {
//        _vfdContraint.constant = 30 + 26;
//        _hzContraint.constant = 61 + 26;
//    } else {
//        _vfdContraint.constant = 30;
//        _hzContraint.constant = 61;
//    }

    // maintainPinch を実行する。
    [self.accelometerSpectrumView setNeedsLayout];
    _contentConstraint.constant = CONSTRAINT_MAGIC;
}
#else
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    self.toPortrait = (size.width < size.height);

    // maintainPinch を実行する。
    [self.accelometerSpectrumView setNeedsLayout];
    _contentConstraint.constant = CONSTRAINT_MAGIC;
}
#endif

#if 0
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    
    // maintainPinch を実行する。
    [self.accelometerSpectrumView setNeedsLayout];
}
#else
- (void) traitCollectionDidChange: (UITraitCollection *) previousTraitCollection {
    [super traitCollectionDidChange: previousTraitCollection];

    // maintainPinch を実行する。
    [self.accelometerSpectrumView setNeedsLayout];
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
        [self.accelometerSpectrumView.led setImage:[UIImage imageNamed:@"greenLED"]];
    } else {
        [self.accelometerSpectrumView.led setImage:[UIImage imageNamed:@"redLED"]];
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
