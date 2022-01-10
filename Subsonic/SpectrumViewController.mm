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
//  SpectrumViewController.m

#import "Settings.h"
#import "SpectrumViewController.h"
#import <AVFoundation/AVAudioSession.h>
#import <AudioToolbox/AudioToolbox.h>
#import "Environment.h"
//#include "mo_audio.hh"
#import "WindowFunctionViewController.h"

#import "FFTView.h"

#import <QuartzCore/QuartzCore.h>
//#import <GLKit/GLKit.h>

#pragma mark - FFT

#import "mo_audio.hh" //stuff that helps set up low-level audio
#import "FFTHelper.hh"

/// Nyquist Maximum Frequency
//const Float32 spectrumNyquistMaxFreq = FFT_SAMPLE_RATE/2.0;

/// caculates HZ value for specified index from a FFT bins vector
Float32 spectrumFrequencyHerzValue(long frequencyIndex, long fftVectorSize, Float32 nyquistFrequency ) {
    return ((Float32)frequencyIndex/(Float32)fftVectorSize) * nyquistFrequency;
}

// The Main FFT Helper
//FFTHelperRef *specrumFftConverter = NULL;
FFTHelperRef specrumFftConverter;

//Accumulator Buffer=====================

UInt32 fftAccumulatorFillIndex = 0;
Float32 *fftAccumulator = nil;
NSDate *spectrumFlushDate = nil;

static void initializeFFTAccumulator() {
    // 念のため、fftAccumulator のサイズを 2倍にした。
    fftAccumulator = (Float32 *) malloc([UserDefaults sharedManager].numChannels * sizeof(Float32)*[UserDefaults sharedManager].fftPoints);
    fftAccumulatorFillIndex = 0;
}

static void destroyFFTAccumulator() {
    if (fftAccumulator!=NULL) {
        free(fftAccumulator);
        fftAccumulator = NULL;
    }
    fftAccumulatorFillIndex = 0;
}

static BOOL fftAccumulateFrames(Float32 *frames, UInt32 length) { //returned YES if full, NO otherwise.
    BOOL rc = NO;

    if (fftAccumulatorFillIndex>=[UserDefaults sharedManager].fftPoints) {
        rc = YES;
    } else {
        memmove(&fftAccumulator[fftAccumulatorFillIndex], frames, sizeof(Float32)*length);
        fftAccumulatorFillIndex += length;
        if (fftAccumulatorFillIndex>=[UserDefaults sharedManager].fftPoints) {
            rc = YES;
        }
    }
    return rc;
}

static void emptyFFTAccumulator() {
    fftAccumulatorFillIndex = 0;
    memset(fftAccumulator, 0, sizeof(Float32) * [UserDefaults sharedManager].fftPoints);
}
//=======================================

//=======================================

/// max value from vector with value index (using Accelerate Framework)
static Float32 spectrumVectorMaxValueACC32_index(Float32 *vector, unsigned long size, long step, unsigned long *outIndex) {
    Float32 maxVal;
    // Copies the element with the greatest value from real vector A to real scalar *C, and writes its zero-based index to integer scalar *IC. The index is the actual array index, not the pre-stride index. If vector A contains more than one instance of the maximum value, *IC contains the index of the first instance. If N is zero (0), this function returns a value of -INFINITY in *C, and the value in *IC is undefined.
    vDSP_maxvi(vector, step, &maxVal, outIndex, size);
    return maxVal;
}

///returns HZ of the strongest frequency.
static Float32 spectrumStrongestFrequencyHZ(Float32 *buffer, FFTHelperRef *fftHelper, long frameSize, unsigned long *maxIndexRet, Float32 *freqValue) {
    
    NSUInteger sampleRate = [UserDefaults sharedManager].sampleRate;
    NSUInteger fftPoints = [UserDefaults sharedManager].fftPoints;

    // on Jul 13, 2021 by T.M.
    // スペクトログラムの場合はマイクゲイン＆ノイズ除去後の増幅をさせる！
    Float32 gain = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
    Float64 multiplier = pow(10.0, gain); // 1倍〜100倍
    for (int i = 0; i < frameSize; i++) {
        buffer[i] *= multiplier;
    }
    //the actual FFT happens here
    //****************************************************************************
    Float32 *fftData = computeFFT(fftHelper, buffer, frameSize);
    //****************************************************************************
    
    fftData[0] = PIANISSIMO;
    unsigned long length = frameSize/2.0;
    Float32 max = 0;
    max = spectrumVectorMaxValueACC32_index(fftData, length, 1, maxIndexRet);
    if (freqValue!=NULL) { *freqValue = max; }
    Float32 HZ = spectrumFrequencyHerzValue(*maxIndexRet, length, sampleRate / 2.0);

    if (*maxIndexRet > 0 && *maxIndexRet < fftPoints - 1) {
        // 補間処理
        CGPoint points[3];
        Float32 curValue;
        Float32 maxValue = -INFINITY;
        NSUInteger maxIndex = NSNotFound;
        Float32 df = sampleRate / fftPoints;  //
        Float32 df2 = 2.0 * df;
        Float32 f0 = HZ - df;
        Float32 f1 = HZ;
        Float32 f2 = HZ + df;
        NSUInteger times = 40 * (fftPoints / 2048); // 【注意】即値
        
        points[0].x = f0;
        points[0].y = fftHelper->outFFTData[*maxIndexRet-1];
        points[1].x = f1;
        points[1].y = fftHelper->outFFTData[*maxIndexRet];
        points[2].x = f2;
        points[2].y = fftHelper->outFFTData[*maxIndexRet+1];
        
//        DEBUG_LOG(@"0:%g,%g", points[0].x, points[0].y);
//        DEBUG_LOG(@"1:%g,%g", points[1].x, points[1].y);
//        DEBUG_LOG(@"2:%g,%g", points[2].x, points[2].y);
        
        for (NSUInteger i = 0; i < times; i++) {
            Float32 x = f0 + (df2 / times) * i;
            curValue = lagrangeInterp(points, 3, x);
//            DEBUG_LOG(@"lagrangeInterp(%ld):%g", i, curValue);
            if (curValue > maxValue) {
                maxValue = curValue;
                maxIndex = i;
            }
        }
//        DEBUG_LOG(@"HZ:%g, [%g] HZ改:%g[%ld/%ld]", HZ, f0, *freqValue, maxIndex, times);
        HZ = f0 + df2 * (maxIndex / ((Float32)times));
    }
    return HZ;
}

FFTView * __weak spectrum_view = nil;
BOOL *spectrum_freeze_p = nil;

#pragma mark Main Callback

void SpectrumAudioCallback(Float32 *buffer, UInt32 frameSize, void *userData)
{
//    DEBUG_LOG(@"%d", [NSThread isMainThread]);
//    @synchronized (self)
    {
        NSUInteger numChannels = [UserDefaults sharedManager].numChannels;
        NSUInteger fftPoints = [UserDefaults sharedManager].fftPoints;
        //take only data from 1 channel
        Float32 zero = 0.0;
        //    NSUInteger mod = FFT_FFT_POINTS / 8192;
//        static unsigned long long counter = 0;
        /* Performs the following operation:
         Adds scalar *B to each element of vector A and stores the result in the corresponding element of vector C.*/
        vDSP_vsadd(buffer, 2, &zero, buffer, 1, frameSize * numChannels);   // ここで落ちるのはメモリー不足？
        
        if (fftAccumulateFrames(buffer, frameSize)) {
            if (*spectrum_freeze_p == NO) {
                //            DEBUG_LOG(@"FFT");
                //=========================================
                unsigned long maxHZIndex = NSNotFound;
                Float32 maxHZValue = 0;
                Float32 maxHZ = spectrumStrongestFrequencyHZ(fftAccumulator, &specrumFftConverter, fftPoints, &maxHZIndex, &maxHZValue);
                
                spectrum_view.maxIndex = maxHZIndex;
                spectrum_view.maxHZ = maxHZ;
                spectrum_view.maxHZValue = maxHZValue ? maxHZValue : -PIANISSIMO;  // 最大120dB とする。
                // FFTはリングバッファでなく1行分のデータをブロックコピー
                [spectrum_view setFFTData:specrumFftConverter.outFFTData];
            }
            NSDate *date = [NSDate date];
            if ([date timeIntervalSinceDate:spectrumFlushDate] > REFRESH_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
                dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
                    [spectrum_view setNeedsDisplay];
                    [spectrum_view.f4 setNeedsDisplay];
                    [spectrum_view.f3 setNeedsDisplay];
                    [spectrum_view.f2 setNeedsDisplay];
                    [spectrum_view.f1 setNeedsDisplay];
                    [spectrum_view.f0 setNeedsDisplay];
                });
                spectrumFlushDate = date;
            } else {
                DEBUG_LOG(@"%s レイテンシーが小さすぎ！", __func__);
            }
            emptyFFTAccumulator(); //empty the accumulator when finished
        }
        memset(buffer, 0, sizeof(Float32)*frameSize * numChannels);
    }
}

#pragma mark - SpectrumViewController

@interface SpectrumViewController ()

@end

@implementation SpectrumViewController

- (void) postUpdate {
    
//    DEBUG_LOG(@"(%llu)", accelometerSPLBufferFillIndex);
    
    dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
        [spectrum_view setNeedsDisplay];
        [spectrum_view.f4 setNeedsDisplay];
        [spectrum_view.f3 setNeedsDisplay];
        [spectrum_view.f2 setNeedsDisplay];
        [spectrum_view.f1 setNeedsDisplay];
        [spectrum_view.f0 setNeedsDisplay];
    });
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    DEBUG_LOG(@"%s", __func__);
    [super viewDidLoad];

//    _freeze = YES;
    [self setLedMeasuring:_freeze == NO];

    // 表示体を VFD モードにする。
    [[NSUserDefaults standardUserDefaults] setInteger:kDisplayModeVFD forKey:kDisplayModeKey];

    initializeFFTAccumulator();

    //initialize stuff
//    specrumFftConverter = FFTHelperCreate(FFT_FFT_POINTS);
    fftInitialized = FFTHelperInitialize(&specrumFftConverter, [UserDefaults sharedManager].fftPoints);

    spectrumFlushDate = [NSDate date];
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kSpectrogramNoiseLevelKey] == nil) {
        [[NSUserDefaults standardUserDefaults] setFloat:0.3 forKey:kSpectrogramNoiseLevelKey];
    }
}

- (void) viewWillAppear:(BOOL)animated {
    DEBUG_LOG(@"%s", __func__);

    [super viewWillAppear:animated];

    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];

#if (CSV_OUT == ON)
#if (CSV_OUT_ONE_BUTTON == ON)
    _fftView.stopSwitch.hidden = YES;
#else
    _fftView.stopSwitch.hidden = NO;
#endif
    _fftView.playPauseSwitch.hidden = NO;
#endif

#if (FFT_SMALL_LATENCY == ON)
    // 最適なハードウェアI/Oバッファ時間（レイテンシー）を指定する（5ms 〜 500ms）。
    // デフォルト23msとなっているが、実際には、10ms であった。
    // 最新のデフォルト46msとなっている。
    NSError *setPreferenceError = nil;
    
    // いつも高速(5ms)
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:AU_BUFFERING_FAST_LATENCY error:&setPreferenceError];
    DEBUG_LOG(@"preferredIOBufferDuration=%g", [[AVAudioSession sharedInstance] preferredIOBufferDuration]);
#endif

    UIViewController *viewController = [[self navigationController] topViewController];
    if (viewController) {
        DEBUG_LOG(@"");
    }

    AVAudioSession *session = [AVAudioSession sharedInstance];
    if ([session respondsToSelector:@selector(requestRecordPermission:)]) {
        [session performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
            [UserDefaults sharedManager].microphoneEnabled = granted;
            if (granted) {
                // Microphone enabled code
                DEBUG_LOG(@"Microphone is enabled..");
            }
            else {
                // Microphone disabled code
                DEBUG_LOG(@"Microphone is disabled..");
                
                // We're in a background thread here, so jump to main thread to do UI work.
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Microphone Access Denied", @"Microphone Access Denied")
                                                                                             message:NSLocalizedString(@"This app requires access to your device's Microphone.\n\nPlease enable Microphone access for this app in Settings.app.", @"This app requires access to your device's Microphone.\n\nPlease enable Microphone access for this app in Settings.app.")
                                                                                      preferredStyle:UIAlertControllerStyleAlert];
                    
                    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Close", @"Close")
                                                                        style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction *action) {
                                                                          // 何もしない。
                                                                      }]];
                    [self presentViewController:alertController animated:YES completion:nil];
                });
            }
        }];
    }
    
    [self maintainControll:[[UserDefaults sharedManager] isPortrait]];
    self.fftView.header.text = @"";
    self.fftView.windowFunctionButton.layer.masksToBounds = YES;
    self.fftView.windowFunctionButton.layer.cornerRadius = 4.0;
    
    [_fftView maintainControl:spectrumMode];
    // ピーク値をクリアする。
    [self.fftView clearPeaks];
    
    // SpectrumAudioCallback に先立つこと。
    spectrum_freeze_p = &_freeze;

    self.fftView.delegate = self;
    spectrum_view = self.fftView;
    
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
    }

    // ヘッダーに設定情報を表示する。
    NSString *pathStr = [[NSBundle mainBundle] bundlePath];
    NSString *settingsBundlePath = [pathStr stringByAppendingPathComponent:@"Settings.bundle"];
    NSString *rootFinalPath = [settingsBundlePath stringByAppendingPathComponent:@"Root.plist"];
    
    NSDictionary *rootSettingsDict = [NSDictionary dictionaryWithContentsOfFile:rootFinalPath];
    NSArray *rootPrefSpecifierArray = [rootSettingsDict objectForKey:@"PreferenceSpecifiers"];

    NSString *windowFunctionTitle = @"";
    NSString *windowFunctionName = @"";
//    NSString *latencyTitle = @"";
    NSString *latencyName = @"";

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
//            } else if ([keyValueStr isEqualToString:kLatencyKey]) {
//                NSNumber *currentValue = [[NSUserDefaults standardUserDefaults] objectForKey:kLatencyKey];
//
//                latencyTitle = NSLocalizedString(title, @"");
//                latencyName = NSLocalizedString(titles[((NSNumber *) currentValue).integerValue], @"");
            }
        }
    }
    if ([windowFunctionName length] || [latencyName length]) {
//        self.fftView.header.text = [NSString stringWithFormat:@"%@[%@] %@[%@]", windowFunctionTitle, windowFunctionName, latencyTitle, latencyName];
        self.fftView.header.text = [NSString stringWithFormat:@"%@[%@]", windowFunctionTitle, windowFunctionName];
        [self performSelector:@selector(setHeaderMessage:) withObject:@"" afterDelay:10];
    }
    switch (spectrumMode) {
        case kSpectrumRTA:
        case kSpectrumRTA1_3:
        case kSpectrumRTA1_6:
        case kSpectrumRTA1_12:
            [_fftView.colorLabel setText:NSLocalizedString(@"RTA Color", @"")];
            break;
            
        default:
            [_fftView.colorLabel setText:NSLocalizedString(@"FFT Color", @"")];
            break;
    }
    [_fftView.windowFunctionLabel setText:NSLocalizedString(@"Window Function", @"")];
    [_fftView.windowFunctionSegment setTitle:NSLocalizedString(@"Rectangular", @"不使用") forSegmentAtIndex:0];
    [_fftView.windowFunctionSegment setTitle:NSLocalizedString(@"Hamming", @"ハミング") forSegmentAtIndex:1];
    [_fftView.windowFunctionSegment setTitle:NSLocalizedString(@"Hanning", @"ハニング") forSegmentAtIndex:2];
    [_fftView.windowFunctionSegment setTitle:NSLocalizedString(@"Blackman", @"ブラックマン") forSegmentAtIndex:3];
    [_fftView.gainLabel setText:NSLocalizedString(@"Mic Gain", @"")];
    [_fftView.noiseReductionLabel setText:NSLocalizedString(@"Noise Reduction", @"")];
    [_fftView.typicalButton setTitle:NSLocalizedString(@"Typical Settings", @"") forState:UIControlStateNormal];
    [_fftView.exploreButton setTitle:NSLocalizedString(@"Exploration Settings", @"") forState:UIControlStateNormal];

    [_fftView setGainInfo];
    [_fftView setUnitBase];
}

- (void) setHeaderMessage:(NSString *)message {
    self.fftView.header.text = message;
}

- (void) viewDidAppear:(BOOL)animated {
    DEBUG_LOG(@"%s", __func__);
    [super viewDidAppear:animated];

    if ([UserDefaults sharedManager].microphoneEnabled && fftInitialized)
    {
        if (fftAccumulator) {
            [self initMomuAudio];
            
            _freeze = NO;
            [self setLedMeasuring:_freeze == NO];
        }
    } else {// とりあえず設定しないと落ちる。
        MoAudio::m_callback = SpectrumAudioCallback;
    }
    DEBUG_LOG(@"%g < %g", _fftView.frame.origin.y, self.navigationController.navigationBar.frame.size.height + self.bannerView.frame.origin.y + self.bannerView.frame.size.height);
}

- (void) viewWillDisappear:(BOOL)animated {
    DEBUG_LOG(@"%s", __func__);
    [super viewWillDisappear:animated];

    self.fftView.delegate = nil;

    if ([UserDefaults sharedManager].microphoneEnabled) {
        [self finalizeMomuAudio];
    }
#if (CSV_OUT == ON)
    [_fftView stopAction:nil];
#endif
}

- (void) initMomuAudio {
    bool result = false;

//    result = MoAudio::init( FFT_SAMPLE_RATE, FFT_FRAMESIZE, FFT_NUMCHANNELS, false);
//    if (result)
    {// MoAudio::init は MainViewController で一回だけやる。
        MoAudio::stop();
        result = MoAudio::start( SpectrumAudioCallback );
        if (result) {
        } else {
            DEBUG_LOG(@" MoAudio start ERROR");
        }
    }
}

// 何もやらない。
- (void) finalizeMomuAudio {

//    MoAudio::shutdown();
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
//    [_fftView pauseReceiveData:YES];
    
#if (SPECTROGRAM_COMP == ON)
    [_fftView pauseReceiveData:YES];
#endif
    self.toPortrait = (size.width < size.height);

//    if ((self.traitCollection.verticalSizeClass != previousTraitCollection.verticalSizeClass) ||
//        self.traitCollection.horizontalSizeClass != previousTraitCollection.horizontalSizeClass)
//    {
//    }

    _fftView.windowFunctionButton.hidden = YES;
    _fftView.windowFunctionSegment.hidden = YES;
    [self maintainControll:self.toPortrait];
    
    // maintainPinch を実行する。
    [self.fftView setNeedsLayout];
    _contentConstraint.constant = CONSTRAINT_MAGIC;
}

- (void) traitCollectionDidChange: (UITraitCollection *) previousTraitCollection {
//    BOOL hideExceptGraphView = (self.traitCollection.verticalSizeClass != UIUserInterfaceSizeClassRegular);
    
    [super traitCollectionDidChange: previousTraitCollection];
    
    if ((self.traitCollection.verticalSizeClass != previousTraitCollection.verticalSizeClass) ||
        self.traitCollection.horizontalSizeClass != previousTraitCollection.horizontalSizeClass)
    {
    }
//    fftView.logOrLinear.hidden = _toPortrait;
//    fftView.agcLabel.hidden = _toPortrait;
//    fftView.agcSwitch.hidden = _toPortrait;
    
    [_fftView maintainControl:[[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey]];
    
    [self maintainControll:self.toPortrait];
    
    // maintainPinch を実行する。
    [self.fftView setNeedsLayout];

#if (SPECTROGRAM_COMP == ON)
    [_fftView pauseReceiveData:NO];
#endif
}

- (void) dealloc {
//    destroyAccumulator();
//    FFTHelperRelease(specrumFftConverter);
}

- (void)didReceiveMemoryWarning {
    DEBUG_LOG(@"%s", __func__);
    
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UIResponder

- (BOOL) canBecomeFirstResponder {
    return YES;
}

- (BOOL) canResignFirstResponder {
    return YES;
}

#pragma mark - Core

- (void) maintainControll:(BOOL)portrait {

    BOOL is_iPad = [Environment isIPad] || [Environment isMIPad] || [Environment isLIPad];
    // ポートレイトや RTA の場合は、Linear/Log のセグメントを表示しない。
    self.fftView.logOrLinear.hidden = (is_iPad == NO) && portrait;
//    fftView.agcLabel.hidden = portrait;
    self.fftView.agcSwitch.hidden = (is_iPad == NO) && portrait;
    
    [_fftView maintainControl:[[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey]];
}

#pragma mark - AVAudioSession delegates
- (IBAction) toggleMathMode:(id)sender {

    UIButton *mathToggle = (UIButton *) sender;
    
    switch ([[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey]) {
        case kSpectrumFFT:
            {
                BOOL isLinear = ! [[NSUserDefaults standardUserDefaults] boolForKey:kFFTMathModeLinearKey];
                
                if (isLinear) {
                    [mathToggle setTitle:@"Linear" forState:UIControlStateNormal];
                } else {
                    [mathToggle setTitle:@"Log" forState:UIControlStateNormal];
                }
                [[NSUserDefaults standardUserDefaults] setBool:isLinear forKey:kFFTMathModeLinearKey];
            }
            break;
        case kSpectrogram:
            {
                BOOL isLinear = ! [[NSUserDefaults standardUserDefaults] boolForKey:kSpectrogramMathModeLinearKey];
                
                if (isLinear) {
                    [mathToggle setTitle:@"Linear" forState:UIControlStateNormal];
                } else {
                    [mathToggle setTitle:@"Log" forState:UIControlStateNormal];
                }
                [[NSUserDefaults standardUserDefaults] setBool:isLinear forKey:kSpectrogramMathModeLinearKey];
            }
            break;
    }
}

#pragma mark - FFTViewProtocol delegate

- (void) setLedMeasuring:(BOOL)onOff {
    
    if (onOff) {
        [self.fftView.led setImage:[UIImage imageNamed:@"greenLED"]];
    } else {
        [self.fftView.led setImage:[UIImage imageNamed:@"redLED"]];
    }
}

- (void) singleTapped {
    _freeze ^= 1;
    [self setLedMeasuring:_freeze == NO];

//    if (_freeze) {
//        MoAudio::start(SpectrumAudioCallback);
//    } else {
//        MoAudio::stop();
//    }
}

- (void) setFreezeMeasurement:(BOOL)yesNo {
    _freeze = yesNo;
    [self setLedMeasuring:_freeze == NO];
}

#pragma mark - FFT(対数/リニア)またはRTA(ボックス/ライン)を選択するコールバック

- (IBAction) chooseLogOrLinear:(id)sender {
    
    UISegmentedControl *segmentControl = (UISegmentedControl *) sender;
    BOOL mathModeLinear = (segmentControl.selectedSegmentIndex == 1);
    BOOL rtaModeLine = (segmentControl.selectedSegmentIndex == 1);
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];

    switch (spectrumMode) {
        case kSpectrogram:// Spectrogram
            // スペクトログラムのモード変更なのでリングバッファをクリアする。
            [_fftView initializeRingBuffer];
            [[NSUserDefaults standardUserDefaults] setBool:mathModeLinear forKey:kSpectrogramMathModeLinearKey];
            break;
        case kSpectrumFFT:// FFT
            [[NSUserDefaults standardUserDefaults] setBool:mathModeLinear forKey:kFFTMathModeLinearKey];
            break;
        default:// RTA
            [[NSUserDefaults standardUserDefaults] setBool:rtaModeLine forKey:kRTAModeLineKey];
            break;
    }
}

- (IBAction) windowFunctionButtonAction:(id)sender {
    WindowFunctionViewController *windowFunctionMenu = [self.storyboard instantiateViewControllerWithIdentifier:STORY_BOARD_ID_WINDOW_FUNCATION];

    windowFunctionMenu.fftView = _fftView;
    [self presentViewController:windowFunctionMenu animated:YES completion:nil];
}
@end
