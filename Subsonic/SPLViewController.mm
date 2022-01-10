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
//  ThirdViewController.m

#import <QuartzCore/QuartzCore.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVAudioSession.h>
#import <AudioToolbox/AudioToolbox.h>
#import "Settings.h"
#import "SPLViewController.h"
#import "mo_audio.hh" //stuff that helps set up low-level audio
#import "Environment.h"

SPLView * __weak spl_view = nil;
BOOL *spl_freeze_p = nil;

//Accumulator Buffer=====================

//const UInt32 accumulatorDataLength = 131072;  //16384; //32768; 65536; 131072;
//const UInt32 splAccumulatorDataLength = SPL_FFT_POINTS; //8192; //16384; //32768; 65536; 131072;
UInt64 splAccumulatorDataLength; //8192; //16384; //32768; 65536; 131072;
UInt32 splAccumulatorFillIndex = 0;
Float32 *splAccumulator = nil;

long long flushSPLCount = 0;
NSDate *splFlushDate = nil;
Float64 minSPLValue = DBL_MAX;
Float64 maxSPLValue = DBL_MIN;
Float64 avgSPLValue = PIANISSIMO;

void initSPL(void) {
    flushSPLCount = 0;
    minSPLValue = DBL_MAX;
    maxSPLValue = DBL_MIN;
    avgSPLValue = PIANISSIMO;
    
    splAccumulatorDataLength = [UserDefaults sharedManager].fftPoints;
}

static void initializeSPLAccumulator() {
    initSPL();
    // 念のため、splAccumulator のサイズを 2倍にした。
    splAccumulator = (Float32 *) malloc([UserDefaults sharedManager].numChannels * sizeof(Float32)*splAccumulatorDataLength);
    splAccumulatorFillIndex = 0;
}

static void destroySPLAccumulator() {
    if (splAccumulator!=NULL) {
        free(splAccumulator);
        splAccumulator = NULL;
    }
    splAccumulatorFillIndex = 0;
}

static BOOL splAccumulateFrames(Float32 *frames, UInt32 length) { //returned YES if full, NO otherwise.
    BOOL rc = NO;

    if (splAccumulatorFillIndex>=splAccumulatorDataLength) {
        rc = YES;
    } else {
        memmove(&splAccumulator[splAccumulatorFillIndex], frames, sizeof(Float32)*length);
        splAccumulatorFillIndex += length;
        if (splAccumulatorFillIndex>=splAccumulatorDataLength) {
            rc = YES;
        }
    }
    return rc;
}

static void emptySPLAccumulator() {
    splAccumulatorFillIndex = 0;
    memset(splAccumulator, 0, sizeof(Float32)*splAccumulatorDataLength);
}

#pragma mark Main Callback

void SPLAudioCallback(Float32 *buffer, UInt32 frameSize, void * userData)
{
    NSUInteger numChannels = [UserDefaults sharedManager].numChannels;
    //take only data from 1 channel
    Float32 zero = 0.0;
    // Adds scalar *B to each element of vector A and stores the result in the corresponding element of vector C.
    vDSP_vsadd(buffer, 2, &zero, buffer, 1, frameSize * numChannels);
    
    if (splAccumulateFrames(buffer, frameSize))
    {
        Float32 gain = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
        Float64 multiplier = pow(10.0, gain); // 1倍〜100倍
        for (int i = 0; i < frameSize; i++) {
            buffer[i] *= multiplier;
        }

//        DEBUG_LOG(@"%@", [NSDate date]);
        flushSPLCount++;
        
        if (*spl_freeze_p == NO) {
            //=========================================
            Float32 rmsValue = PIANISSIMO;
#if (RMS == OFF)
            // Spectrogram と同じで MS っぽい。
            vDSP_measqv(buffer, 1, &rmsValue, frameSize);
#else
            // RMS
            vDSP_rmsqv(buffer, 1, &rmsValue, frameSize);
#endif
            // リングバッファにデータを1つ追加する。
            [spl_view enqueueData:rmsValue];
            if (rmsValue < minSPLValue) {
                minSPLValue = rmsValue;
            }
            if (rmsValue > maxSPLValue) {
                maxSPLValue = rmsValue;
            }
            Float32 sum = (avgSPLValue * flushSPLCount) + rmsValue;
            Float32 avg = sum / (flushSPLCount + 1);
            avgSPLValue = avg;
            
            spl_view.rmsValue = rmsValue;
            spl_view.minValue = minSPLValue;
            spl_view.maxValue = maxSPLValue;
            spl_view.avgValue = avgSPLValue;
        }
        //            DEBUG_LOG(@"%s", __func__);
        NSDate *date = [NSDate date];
        if ([date timeIntervalSinceDate:splFlushDate] > REFRESH_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
            dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
                [spl_view setNeedsDisplay];
                // Start Add on May 3rd, 2021 by T.M.
                [spl_view.f3 setNeedsDisplay];
                // Start End on May 3rd, 2021 by T.M.
                [spl_view.f2 setNeedsDisplay];
                [spl_view.f1 setNeedsDisplay];
                [spl_view.f0 setNeedsDisplay];
                [spl_view.min setNeedsDisplay];
                [spl_view.max setNeedsDisplay];
                [spl_view.rms setNeedsDisplay];
            });
            splFlushDate = date;
        } else {
            DEBUG_LOG(@"%s レイテンシーが小さすぎ！", __func__);
        }
        emptySPLAccumulator(); //empty the accumulator when finished
    }
    memset(buffer, 0, sizeof(Float32)*frameSize * numChannels);
}

@interface SPLViewController ()

@end

@implementation SPLViewController

- (void) initSPL {
    initSPL();
}

- (void) postUpdate {
    
//    DEBUG_LOG(@"(%llu)", accelometerSPLBufferFillIndex);
    
    dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
        [spl_view setNeedsDisplay];
        // Start Add on May 3rd, 2021 by T.M.
        [spl_view.f3 setNeedsDisplay];
        // End Add on May 3rd, 2021 by T.M.
        [spl_view.f2 setNeedsDisplay];
        [spl_view.f1 setNeedsDisplay];
        [spl_view.f0 setNeedsDisplay];
        [spl_view.min setNeedsDisplay];
        [spl_view.max setNeedsDisplay];
        [spl_view.rms setNeedsDisplay];
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

    //initialize stuff
    initializeSPLAccumulator();

    splFlushDate = [NSDate date];
}

- (void) viewWillAppear:(BOOL)animated {
    DEBUG_LOG(@"%s", __func__);
    [super viewWillAppear:animated];
    
#if (CSV_OUT == ON)
#if (CSV_OUT_ONE_BUTTON == ON)
    _splView.stopSwitch.hidden = YES;
#else
    _splView.stopSwitch.hidden = NO;
#endif
    _splView.playPauseSwitch.hidden = NO;
#endif

    // 最適なハードウェアI/Oバッファ時間（レイテンシー）を指定する（5ms 〜 500ms）。
    // デフォルト23msとなっているが、実際には、10ms であった。
    // 最新のデフォルト46msとなっている。
    NSError *setPreferenceError = nil;
#if (SPL_SMALL_LATENCY == ON)
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:AU_BUFFERING_FAST_LATENCY error:&setPreferenceError];
#else
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:AU_BUFFERING_SLOW_LATENCY error:&setPreferenceError];
#endif
    DEBUG_LOG(@"preferredIOBufferDuration=%g", [[AVAudioSession sharedInstance] preferredIOBufferDuration]);
    
    // 4S(simulator):0.0464399 (23ms の2倍の穏やかな設定)
    // 4S:0
    // 6:0
    // 0.008

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
    self.splView.header.text = @"";

    // ドット表示体を作成する。
    self.splView.dot.layer.cornerRadius = self.splView.dot.frame.size.width / 2.0;

    // SPLAudioCallback に先立つこと。
    spl_freeze_p = &_freeze;
    self.splView.delegate = self;
    spl_view = self.splView;

    // VFD の dB とラベルの重なりをなくす。
    self.splView.dbLabel.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);

    _splView.gainLabel.text = NSLocalizedString(@"Mic Gain", @"");
    _splView.gainSlider.minimumValue = 0.0; // 10^(0)=0dB 0〜40dB に変更した。May 25, 2021
    _splView.gainSlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
    _splView.gainSlider.maximumValue = 2.0; // 10^(+2)=+40dB 0〜40dB に変更した。May 25, 2021
    [_splView.typicalButton setTitle:NSLocalizedString(@"Typical Settings", @"") forState:UIControlStateNormal];

    [_splView setGainInfo];
    [_splView setUnitBase];
}

- (void) viewDidAppear:(BOOL)animated {
    DEBUG_LOG(@"%s", __func__);
    [super viewDidAppear:animated];

    if ([UserDefaults sharedManager].microphoneEnabled) {
        if (splAccumulator) {
            [self initMomuAudio];
            
            _freeze = NO;
            [self setLedMeasuring:_freeze == NO];
        }
    } else {// とりあえず設定しないと落ちる。
        MoAudio::m_callback = SPLAudioCallback;
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    DEBUG_LOG(@"%s", __func__);
    [super viewWillDisappear:animated];
    
    self.splView.delegate = nil;

    if ([UserDefaults sharedManager].microphoneEnabled) {
        [self finalizeMomuAudio];
    }
#if (CSV_OUT == ON)
    [_splView stopAction:nil];
#endif
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    self.toPortrait = (size.width < size.height);

    // maintainPinch を実行する。
    [self.splView setNeedsLayout];
    
    // VFD の dB とラベルの重なりをなくす。
    self.splView.dbLabel.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
    _contentConstraint.constant = CONSTRAINT_MAGIC;
}

- (void) traitCollectionDidChange: (UITraitCollection *) previousTraitCollection {
    [super traitCollectionDidChange: previousTraitCollection];

    // maintainPinch を実行する。
    [self.splView setNeedsLayout];
    
    // VFD の dB とラベルの重なりをなくす。
    self.splView.dbLabel.hidden = (([[UserDefaults sharedManager] isIPhone4] || [[UserDefaults sharedManager] isIPhone5]) && [[UserDefaults sharedManager] isPortrait]);
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

- (void) initMomuAudio {
    bool result = false;

//    result = MoAudio::init( FFT_SAMPLE_RATE, FFT_FRAMESIZE, FFT_NUMCHANNELS, false);
//    if (result)
    {// MoAudio::init は MainViewController で一回だけやる。
        MoAudio::stop();
        result = MoAudio::start( SPLAudioCallback );
        if (result) {
            // マイクの AGC をオフにする。 <AudioToolbox/AudioToolbox.h>
#if MEASUREMENT
// 使用しない。使用するとカテゴリが変わったという扱いになる。

            // 常時計測モード（AGC OFF）
//            UInt32 mode = kAudioSessionMode_Measurement;
//            AudioSessionSetProperty(kAudioSessionProperty_Mode, sizeof(mode), &mode);
#endif
        } else {
            DEBUG_LOG(@" MoAudio start ERROR");
        }
    }
}

// 何もやらない。
- (void) finalizeMomuAudio {

//    MoAudio::shutdown();
}

- (void) setLedMeasuring:(BOOL)onOff {
    
    if (onOff) {
        [self.splView.led setImage:[UIImage imageNamed:@"greenLED"]];
    } else {
        [self.splView.led setImage:[UIImage imageNamed:@"redLED"]];
    }
}

#pragma mark - SPLViewProtocol delegate

- (void) singleTapped {
    _freeze ^= 1;
    [self setLedMeasuring:_freeze == NO];
}

- (void) setFreezeMeasurement:(BOOL)yesNo {
    _freeze = yesNo;
    [self setLedMeasuring:_freeze == NO];
}
@end
