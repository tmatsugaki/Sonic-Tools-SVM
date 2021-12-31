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
//  ScopeViewController.m

#import <QuartzCore/QuartzCore.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVAudioSession.h>
#import <AudioToolbox/AudioToolbox.h>
#import "Settings.h"
#import "ScopeViewController.h"
#import "ScopeHelper.h"
#import "mo_audio.hh" //stuff that helps set up low-level audio
#include "Environment.h"

ScopeView * __weak scope_view = nil;
BOOL *scope_freeze_p = nil;

//Accumulator Buffer=====================

//const UInt32 accumulatorDataLength = 131072;  //16384; //32768; 65536; 131072;
const UInt32 scopeAccumulatorDataLength = SCOPE_CHUNK_SIZE; //8192; //16384; //32768; 65536; 131072;
UInt32 scopeAccumulatorFillIndex = 0;
Float32 *scopeAccumulator = nil;
NSDate *scopeFlushDate = nil;

//long long flushScopeCount = 0;

static void initializeScopeAccumulator() {
    // scopeAccumulator のサイズを 2倍にしたところ落ちなくなった。
    scopeAccumulator = (Float32 *) malloc([UserDefaults sharedManager].numChannels * sizeof(Float32)*scopeAccumulatorDataLength);
    scopeAccumulatorFillIndex = 0;
}

static void destroyScopeAccumulator() {
    if (scopeAccumulator!=NULL) {
        free(scopeAccumulator);
        scopeAccumulator = NULL;
    }
    scopeAccumulatorFillIndex = 0;
}

static BOOL scopeAccumulateFrames(Float32 *frames, UInt32 length) { //returned YES if full, NO otherwise.
    BOOL rc = NO;

    if (scopeAccumulatorFillIndex>=scopeAccumulatorDataLength) {
        rc = YES;
    } else {
        memmove(&scopeAccumulator[scopeAccumulatorFillIndex], frames, sizeof(Float32)*length);
        scopeAccumulatorFillIndex += length;
        if (scopeAccumulatorFillIndex>=scopeAccumulatorDataLength) {
            rc = YES;
        }
    }
    return rc;
}

static void emptyScopeAccumulator() {
    scopeAccumulatorFillIndex = 0;
    memset(scopeAccumulator, 0, sizeof(Float32)*scopeAccumulatorDataLength);
}

#pragma mark Main Callback

// 256/44100 = 5.8ms
void ScopeAudioCallback(Float32 *buffer, UInt32 frameSize, void *userData)
{
    NSUInteger numChannels = [UserDefaults sharedManager].numChannels;
    //take only data from 1 channel
    Float32 zero = 0.0;
    // Adds scalar *B to each element of vector A and stores the result in the corresponding element of vector C.
    vDSP_vsadd(buffer, 2, &zero, buffer, 1, frameSize * numChannels);
    
    if (scopeAccumulateFrames(buffer, frameSize))
    {
//        flushScopeCount++;
        
        if (*scope_freeze_p == NO) {
            for (NSUInteger i = 0; i < frameSize; i++) {
                // リングバッファにデータを1つ追加する。
                [scope_view enqueueData:buffer[i]];
            }
        }
        NSDate *date = [NSDate date];
        if ([date timeIntervalSinceDate:scopeFlushDate] > REFRESH_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
            dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
                [scope_view setNeedsDisplay];
                emptyScopeAccumulator(); //empty the accumulator when finished
            });
            scopeFlushDate = date;
        } else {
            emptyScopeAccumulator(); //empty the accumulator when finished
//            DEBUG_LOG(@"%s レイテンシーが小さすぎ！", __func__);
        }
    }
    memset(buffer, 0, sizeof(Float32)*frameSize * numChannels);
}

@interface ScopeViewController ()

@end

@implementation ScopeViewController

- (void) postUpdate {
    
//    DEBUG_LOG(@"(%llu)", scopeAccumulatorFillIndex);
    
    dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
        [scope_view setNeedsDisplay];
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

    // -80dB 〜 80dB (-0.99999999 〜 0.99999999) [0.0 〜 1.0]
    Float32 triggerLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"triggerLevel"];
    Float32 value = (triggerLevel + 0.99999999) / ((0.99999999 - -0.99999999));
    [self.scopeView.triggerLevel setValue:value];

    NSUInteger autoTriggerMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"autoTrigger"];
    [self.scopeView.autoTrigger setSelectedSegmentIndex:autoTriggerMode];
    if (autoTriggerMode)
    {
        [self.scopeView.triggerLevel setEnabled:NO];
    } else {
        [self.scopeView.triggerLevel setEnabled:YES];
    }
    //initialize stuff
    initializeScopeAccumulator();

    scopeFlushDate = [NSDate date];
}

- (void) viewWillAppear:(BOOL)animated {
    DEBUG_LOG(@"%s", __func__);
    [super viewWillAppear:animated];

    // 最適なハードウェアI/Oバッファ時間（レイテンシー）を指定する（5ms 〜 500ms）。
    // デフォルト23msとなっているが、実際には、10ms であった。
    // 最新のデフォルト46msとなっている。
    NSError *setPreferenceError = nil;
#if (SCOPE_SMALL_LATENCY == ON)
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:AU_BUFFERING_FAST_LATENCY error:&setPreferenceError];
#else
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:AU_BUFFERING_SLOW_LATENCY error:&setPreferenceError];
#endif
    DEBUG_LOG(@"preferredIOBufferDuration=%g", [[AVAudioSession sharedInstance] preferredIOBufferDuration]);

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
    self.scopeView.header.text = @"";

    // ScoreAudioCallback に先立つこと。
    scope_freeze_p = &_freeze;
    self.scopeView.delegate = self;
    scope_view = self.scopeView;

    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"autoTrigger"] == 0)
    {// お節介でトリガーレベルに 0.0 を設定する。
        [_scopeView.triggerLevel setValue:0.5];
        [[NSUserDefaults standardUserDefaults] setFloat:0.0 forKey:@"triggerLevel"];
        [_scopeView.triggerLevel setEnabled:NO];
    } else {
        [_scopeView.triggerLevel setEnabled:YES];
    }
    _scopeView.gainLabel.text = NSLocalizedString(@"Mic Gain", @"");
    _scopeView.gainSlider.minimumValue = 0.0; // 10^(0)=0dB 0〜40dB に変更した。May 25, 2021
    _scopeView.gainSlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
    _scopeView.gainSlider.maximumValue = 2.0; // 10^(+2)=+40dB 0〜40dB に変更した。May 25, 2021
    [_scopeView.typicalButton setTitle:NSLocalizedString(@"Typical Settings", @"") forState:UIControlStateNormal];

    [_scopeView setGainInfo];
//    [_scopeView setUnitBase];
}

- (void) viewDidAppear:(BOOL)animated {
    DEBUG_LOG(@"%s", __func__);
    [super viewDidAppear:animated];

    if ([UserDefaults sharedManager].microphoneEnabled) {
        if (scopeAccumulator) {
            [self initMomuAudio];
            
            _freeze = NO;
            [self setLedMeasuring:_freeze == NO];
        }
    } else {// とりあえず設定しないと落ちる。
        MoAudio::m_callback = ScopeAudioCallback;
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    DEBUG_LOG(@"%s", __func__);
    [super viewWillDisappear:animated];
    
    self.scopeView.delegate = nil;

    if ([UserDefaults sharedManager].microphoneEnabled) {
        [self finalizeMomuAudio];
//        FFTHelperRelease(fftConverter);
    }
}

#if 0
- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                 duration:(NSTimeInterval)duration
{
    self.toPortrait = (toInterfaceOrientation == UIInterfaceOrientationPortrait || toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);

    // maintainPinch を実行する。
    [self.scopeView setNeedsLayout];
    _contentConstraint.constant = 80.0;
}
#else
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    self.toPortrait = (size.width < size.height);

    // maintainPinch を実行する。
    [self.scopeView setNeedsLayout];
    _contentConstraint.constant = 80.0;
}
#endif

#if 0
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {

    // maintainPinch を実行する。
    [self.scopeView setNeedsLayout];
}
#else
- (void) traitCollectionDidChange: (UITraitCollection *) previousTraitCollection {
    [super traitCollectionDidChange: previousTraitCollection];

    // maintainPinch を実行する。
    [self.scopeView setNeedsLayout];
}
#endif

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
        result = MoAudio::start( ScopeAudioCallback );
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

#pragma mark - ScopeViewProtocol delegate

- (void) setLedMeasuring:(BOOL)onOff {

    if (onOff) {
        [self.scopeView.led setImage:[UIImage imageNamed:@"greenLED"]];
    } else {
        [self.scopeView.led setImage:[UIImage imageNamed:@"redLED"]];
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
