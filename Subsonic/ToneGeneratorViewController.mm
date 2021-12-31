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
//  ToneGeneratorViewController.m

#import <AudioToolbox/AudioToolbox.h>
#import "definitions.h"
#import "ToneGeneratorViewController.h"
#import "NSString+TM.h"
#import "TextFieldUtil.h"

enum {
    kSweepNone,
    kSweepRise,
    kSweepDown
};
//AudioUnit m_au;
static AudioComponentInstance m_au;
static AudioStreamBasicDescription m_dataFormat;
//AudioStreamBasicDescription streamFormat;
static Float64 m_hwSampleRate = 44100.0;
static AURenderCallbackStruct m_renderProc;
NSDate *toneFlushDate = nil;
NSUInteger sweepMode = kSweepNone;

OSStatus renderTone(
                    ToneGeneratorViewController *inRefCon,
                    AudioUnitRenderActionFlags 	*ioActionFlags,
                    const AudioTimeStamp 		*inTimeStamp,
                    UInt32 						inBusNumber,
                    UInt32 						inNumberFrames,
                    AudioBufferList 			*ioData);
//-----------------------------------------------------------------------------
// name: setupRemoteIO()
// desc: setup Audio Unit Remote I/O
//-----------------------------------------------------------------------------
static bool setupRemoteIO( AudioUnit & inRemoteIOUnit, AURenderCallbackStruct inRenderProc,
                   AudioStreamBasicDescription & outASBD )
{
    // open the output unit
    AudioComponentDescription desc;

    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    // find next component
    AudioComponent defaultOutput = AudioComponentFindNext( NULL, &desc );
    
    // status code
    OSStatus err;
    
    // the stream description
    AudioStreamBasicDescription localASBD;
    
    // open remote I/O unit
    err = AudioComponentInstanceNew( defaultOutput, &inRemoteIOUnit );
    if( err )
    {
        // TODO: "couldn't open the remote I/O unit"
        return false;
    }
    
#if 0
    UInt32 one = 1;
    // enable input
    err = AudioUnitSetProperty( inRemoteIOUnit, kAudioOutputUnitProperty_EnableIO,
                               kAudioUnitScope_Input, 1, &one, sizeof(one) );
    if( err )
    {
        // TODO: "couldn't enable input on the remote I/O unit"
        return false;
    }
    
    // set render proc
    err = AudioUnitSetProperty( inRemoteIOUnit, kAudioUnitProperty_SetRenderCallback,
                               kAudioUnitScope_Input, 0, &inRenderProc, sizeof(inRenderProc) );
    if( err )
    {
        // TODO: "couldn't set remote i/o render callback"
        return false;
    }
    
    UInt32 size = sizeof(localASBD);
    // get and set client format
    err = AudioUnitGetProperty( inRemoteIOUnit, kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Input, 0, &localASBD, &size );
    if( err )
    {
        // TODO: "couldn't get the remote I/O unit's output client format"
        return false;
    }
#else
    UInt32 one = 1;
    // enable input
    err = AudioUnitSetProperty( inRemoteIOUnit, kAudioOutputUnitProperty_EnableIO,
                               kAudioUnitScope_Output, 1, &one, sizeof(one) );
    if( err )
    {
        // TODO: "couldn't enable input on the remote I/O unit"
        return false;
    }
    
    // set render proc
    err = AudioUnitSetProperty( inRemoteIOUnit, kAudioUnitProperty_SetRenderCallback,
                               kAudioUnitScope_Output, 0, &inRenderProc, sizeof(inRenderProc) );
    if( err )
    {
        // TODO: "couldn't set remote i/o render callback"
        return false;
    }
    
    UInt32 size = sizeof(localASBD);
    // get and set client format
    err = AudioUnitGetProperty( inRemoteIOUnit, kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Output, 0, &localASBD, &size );
    if( err )
    {
        // TODO: "couldn't get the remote I/O unit's output client format"
        return false;
    }
#endif

#if 0
    localASBD.mFormatID = outASBD.mFormatID;
    localASBD.mSampleRate = outASBD.mSampleRate;
    localASBD.mFormatFlags = kAudioFormatFlagIsSignedInteger |
                               kAudioFormatFlagIsPacked |
                               kAudioFormatFlagIsNonInterleaved |
                               (24 << kLinearPCMFormatFlagsSampleFractionShift);
    localASBD.mChannelsPerFrame = outASBD.mChannelsPerFrame;
#else
    localASBD.mFormatID = kAudioFormatLinearPCM;
    localASBD.mSampleRate = m_hwSampleRate;
    localASBD.mFormatFlags = kAudioFormatFlagsNativeFloatPacked |
                             kAudioFormatFlagIsNonInterleaved;
    localASBD.mChannelsPerFrame = 1;
#endif
    localASBD.mBytesPerPacket = 4;
    localASBD.mFramesPerPacket = 1;
    localASBD.mBytesPerFrame = 4;
    localASBD.mBitsPerChannel = 32;
    
    // set stream property
    err = AudioUnitSetProperty( inRemoteIOUnit, kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Input, 0, &localASBD, sizeof(localASBD) );
    if( err )
    {
        // TODO: "couldn't set the remote I/O unit's input client format"
        return false;
    }
    
    size = sizeof(outASBD);
    // get it again
    err = AudioUnitGetProperty( inRemoteIOUnit, kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Input, 0, &outASBD, &size );
    if( err )
    {
        // TODO: "couldn't get the remote I/O unit's output client format"
        return false;
    }
    err = AudioUnitSetProperty( inRemoteIOUnit, kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Output, 1, &outASBD, sizeof(outASBD) );
    if( err )
    {
        // TODO: "couldn't set the remote I/O unit's input client format"
        return false;
    }
    // print the format
    // printf( "format for remote i/o:\n" );
    // outFormat.Print();
    
    // initialize remote I/O unit
    err = AudioUnitInitialize( inRemoteIOUnit );
    if( err )
    {
        // TODO: "couldn't initialize the remote I/O unit"
        return false;
    }
    
    return true;
}

//-----------------------------------------------------------------------------
// name: rioInterruptionListener()
// desc: handler for interruptions to start and end
//-----------------------------------------------------------------------------
static void rioInterruptionListener(ToneGeneratorViewController *inClientData, UInt32 inInterruptionState)
{
    ToneGeneratorViewController *viewController = (ToneGeneratorViewController *)inClientData;
    
    [viewController stopProc];
}

//-----------------------------------------------------------------------------
// name: propListener()
// desc: audio session property listener
//-----------------------------------------------------------------------------
static void propListener( void * inClientData, AudioSessionPropertyID inID,
                         UInt32 inDataSize, const void * inData )
{
    NSDictionary *routeDictionary = (__bridge NSDictionary *)inData;
    NSInteger reason = ((NSNumber *) [routeDictionary objectForKey:((NSString *) CFSTR(kAudioSession_AudioRouteChangeKey_Reason))]).intValue;
    BOOL initialize = NO;
    
    switch (reason) {
            break;
        case kAudioSessionRouteChangeReason_Unknown:
            DEBUG_LOG(@"%s kAudioSessionRouteChangeReason_Unknown (ToneGenerator)", __func__);
            break;
        case kAudioSessionRouteChangeReason_NewDeviceAvailable:
            DEBUG_LOG(@"%s kAudioSessionRouteChangeReason_NewDeviceAvailable (ToneGenerator)", __func__);
            break;
        case kAudioSessionRouteChangeReason_OldDeviceUnavailable:
            DEBUG_LOG(@"%s kAudioSessionRouteChangeReason_OldDeviceUnavailable (ToneGenerator)", __func__);
            break;
        case kAudioSessionRouteChangeReason_CategoryChange:
            DEBUG_LOG(@"%s kAudioSessionRouteChangeReason_CategoryChange (ToneGenerator)", __func__);
            break;
        case kAudioSessionRouteChangeReason_Override:
            DEBUG_LOG(@"%s kAudioSessionRouteChangeReason_Override (ToneGenerator)", __func__);
            initialize = YES;
            break;
        case kAudioSessionRouteChangeReason_WakeFromSleep:
            DEBUG_LOG(@"%s kAudioSessionRouteChangeReason_WakeFromSleep (ToneGenerator)", __func__);
            break;
        case kAudioSessionRouteChangeReason_NoSuitableRouteForCategory:
            DEBUG_LOG(@"%s kAudioSessionRouteChangeReason_NoSuitableRouteForCategory (ToneGenerator)", __func__);
            break;
        default:// AirPlay からスピーカーに戻る時のパス？
            DEBUG_LOG(@"%s default (momu)", __func__);
            break;
    }

    // detect audio route change
    if( inID == kAudioSessionProperty_AudioRouteChange )
    {
        // status code
        OSStatus err;
        
        // if there was a route change, we need to dispose the current rio unit and create a new one
        err = AudioComponentInstanceDispose( m_au );
        if( err )
        {
            // TODO: "couldn't dispose remote i/o unit"
            return;
        }
        
        // set up
        setupRemoteIO( m_au, m_renderProc, m_dataFormat );
        
        UInt32 size = sizeof(m_hwSampleRate);
        // get sample rate
        err = AudioSessionGetProperty( kAudioSessionProperty_CurrentHardwareSampleRate,
                                      &size, &m_hwSampleRate );
        if( err )
        {
            // TODO: "couldn't get new sample rate"
            return;
        }
        
        // check input
//        MoAudio::checkInput();
        
        // start audio unit
        err = AudioOutputUnitStart( m_au );
        if( err )
        {
            // TODO: "couldn't start unit"
            return;
        }
        
        // get route
        CFStringRef newRoute;
        size = sizeof(CFStringRef);
        err = AudioSessionGetProperty( kAudioSessionProperty_AudioRoute, &size, &newRoute );
        if( err )
        {
            // TODO: "couldn't get new audio route"
            return;
        }
        
        // check route
        if( newRoute )
        {
            // CFShow( newRoute );
            if( CFStringCompare( newRoute, CFSTR("Headset"), NULL ) == kCFCompareEqualTo )
            { }
            else if( CFStringCompare( newRoute, CFSTR("Receiver" ), NULL ) == kCFCompareEqualTo )
            { }
            else if( CFStringCompare( newRoute, CFSTR("ReceiverAndMicrophone" ), NULL ) == kCFCompareEqualTo )
            { /* イヤホン */
                UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
                AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                                         sizeof(audioRouteOverride),
                                         &audioRouteOverride);
            }
            else if( CFStringCompare( newRoute, CFSTR("SpeakerAndMicrophone" ), NULL ) == kCFCompareEqualTo )
            { /* デフォルト */ }
            else // unknown
            { }
            DEBUG_LOG(@"%s (ToneGenerator) [%@]", __func__, newRoute);
        }
    }
}

OSStatus renderTone(
                    ToneGeneratorViewController *inRefCon,
                    AudioUnitRenderActionFlags 	*ioActionFlags,
                    const AudioTimeStamp 		*inTimeStamp,
                    UInt32 						inBusNumber,
                    UInt32 						inNumberFrames,
                    AudioBufferList 			*ioData)

{
    // Get the tone parameters out of the view controller
    ToneGeneratorViewController *viewController = (ToneGeneratorViewController *) inRefCon;

    @synchronized (viewController) {
        /* __block */ Float32 theta = viewController->theta;
        // Fixed amplitude is good enough for our purposes
        const Float32 amplitude = 0.25;

//        dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
            // This is a mono tone generator so we only need the first buffer
            //    Float32 theta_increment = 2.0 * M_PI * viewController->frequency / viewController->sampleRate;
//            NSUInteger frequency = atoi([inRefCon.frequncy.text UTF8String]);
            NSUInteger frequency = [[NSUserDefaults standardUserDefaults] integerForKey:kOscillatorFrequencyKey];
            Float32 theta_increment = 2.0 * M_PI * ((Float32) frequency) / 44100.0;
            
            const int channel = 0;
            Float32 *buffer = (Float32 *)ioData->mBuffers[channel].mData;
            NSUInteger waveType = [[NSUserDefaults standardUserDefaults] integerForKey:kOscillatorWaveTypeKey];

            // Generate the samples
            for (UInt32 frame = 0; frame < inNumberFrames; frame++)
            {
//                switch (viewController.mode.selectedSegmentIndex) {
                switch (waveType) {
                    case kSin:
                        buffer[frame] = sin(theta) * amplitude;
                        break;
                    case kSaw:
                        buffer[frame] = ((theta / 6.0) - (floor(theta / 6.0) - floor(-theta / 6.0)) / 2.0) * amplitude;
                        break;
                    case kTriangle:
                        buffer[frame] = acos(cos(theta)) * amplitude;
                        break;
                }
                theta += theta_increment;
                if (theta > 2.0 * M_PI)
                {
                    theta -= 2.0 * M_PI;
                }
            }
            // Store the theta back in the view controller
            viewController->theta = theta;
            
            switch (sweepMode)
            {
            case kSweepRise:
            case kSweepDown:
                NSUInteger delta = 0;

                if (frequency < 100) {
                    delta += 1;
                } else if (frequency < 500) {
                    delta += 2;
                } else if (frequency < 1000) {
                    delta += 3;
                } else if (frequency < 5000) {
                    delta += 4;
                } else if (frequency < 10000) {
                    delta += 5;
                } else if (frequency < 50000) {
                    delta += 6;
                } else if (frequency < 100000) {
                    delta += 7;
                }
                if (sweepMode == kSweepRise) {
                    frequency += delta;
                } else {
                    frequency -= delta;
                }
                if (frequency >= 22050) {
                    frequency = 22050;
                }
                [[NSUserDefaults standardUserDefaults] setInteger:MAX(frequency, 20.0) forKey:kOscillatorFrequencyKey];
                NSDate *date = [NSDate date];
                if ([date timeIntervalSinceDate:toneFlushDate] > RENDER_INTERVAL) {// 更新が頻繁過ぎると、OverCommit（スタック不足） になる。
                    dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
                        if (frequency >= 20 && frequency < 22050) {
                            inRefCon.frequncy.text = [NSString stringWithFormat:@"%lu", (unsigned long)frequency];
                            inRefCon.stepper.value = frequency;
                        } else {
                            inRefCon.frequncy.text = @"20";
                            inRefCon.stepper.value = 20.0;
                            [viewController stopProc];

                            [[NSUserDefaults standardUserDefaults] setInteger:20 forKey:kOscillatorFrequencyKey];
                        }
                    });
                    toneFlushDate = date;
                    DEBUG_LOG(@"%s %dHz %@", __func__, frequency, toneFlushDate);
                } else {
                    DEBUG_LOG(@"%s %dHz レイテンシーが小さすぎ！", __func__, frequency);
                }
                break;
            }
//        });
    }
    return noErr;
}

@interface ToneGeneratorViewController ()

@end

@implementation ToneGeneratorViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    
    toneFlushDate = [NSDate date];
    
    [super viewDidLoad];

//    [_sweep setImage:[UIImage imageNamed:@"sweepON"] forState:UIControlStateSelected];
//    [_sweep setImage:[UIImage imageNamed:@"sweepOFF"] forState:UIControlStateNormal];

    sampleRate = 44100;
    
    OSStatus result = AudioSessionInitialize(NULL, NULL, (AudioSessionInterruptionListener) rioInterruptionListener, (__bridge void *)(self));
    if (result == kAudioSessionNoError)
    {
#if 1
//        UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback; // オリジナル
        // momu の方式に合わせたけど、ReceiverAndMicrophone という扱いになって kAudioSessionRouteChangeReason_CategoryChange が発生する。
        UInt32 sessionCategory = kAudioSessionCategory_PlayAndRecord;
        AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
#endif
    }
#if 0
//    AudioSessionSetActive(true); // momu に任す。
    NSError *activationError = nil;
    [[AVAudioSession sharedInstance] setActive: YES error: &activationError];
#endif
    
    _frequncy.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {

    static BOOL showsUp = NO;
    
    [super viewWillAppear:animated];

    if (showsUp == NO) {
        _stepper.value = [[NSUserDefaults standardUserDefaults] floatForKey:kOscillatorFrequencyKey];
        _frequncy.text = [NSString stringWithFormat:@"%lu", (unsigned long) _stepper.value];
    }
    _frequncy.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:18.0];
    showsUp = YES;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

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

- (void) createToneUnit
{
    // Configure the search parameters to find the default playback output unit
    // (called the kAudioUnitSubType_RemoteIO on iOS but
    // kAudioUnitSubType_DefaultOutput on Mac OS X)
    AudioComponentDescription desc;

    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    // Get the default playback output unit
    AudioComponent defaultOutput = AudioComponentFindNext(NULL, &desc);
    NSAssert(defaultOutput, @"Can't find default output");
    
    // Create a new unit based on this that we'll use for output
    OSErr err = AudioComponentInstanceNew(defaultOutput, &m_au);
    NSAssert1(m_au, @"Error creating unit: %hd", err);
    
    // Set our tone rendering function on the unit
    m_renderProc.inputProc = (AURenderCallback __nullable) renderTone;
    m_renderProc.inputProcRefCon = (__bridge void * _Nullable)((ToneGeneratorViewController *) self);
    err = AudioUnitSetProperty(m_au,
                               kAudioUnitProperty_SetRenderCallback,
                               kAudioUnitScope_Output,
                               0,
                               &m_renderProc,
                               sizeof(m_renderProc));
    NSAssert1(err == noErr, @"Error setting callback: %hd", err);
    
    // Set the format to 32 bit, single channel, floating point, linear PCM

    m_dataFormat.mSampleRate = sampleRate;
    m_dataFormat.mFormatID = kAudioFormatLinearPCM;
    m_dataFormat.mFormatFlags = kAudioFormatFlagsNativeFloatPacked |
                                kAudioFormatFlagIsNonInterleaved;
    m_dataFormat.mBytesPerPacket = 4;
    m_dataFormat.mFramesPerPacket = 1;
    m_dataFormat.mBytesPerFrame = 4;
    m_dataFormat.mChannelsPerFrame = 1;
    m_dataFormat.mBitsPerChannel = 32;
    err = AudioUnitSetProperty (m_au,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Input,
                                0,
                                &m_dataFormat,
                                sizeof(AudioStreamBasicDescription));
    NSAssert1(err == noErr, @"Error setting stream format: %hd", err);
    // set property listener
//    err = AudioSessionAddPropertyListener( kAudioSessionProperty_AudioRouteChange, propListener, NULL );
//    NSAssert1(err == noErr, @"Error setting stream format: %hd", err);
}

- (IBAction)modeAction:(UISegmentedControl *)modeCtrl
{
    dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
        switch (modeCtrl.selectedSegmentIndex) {
            case 0:// Tone
                self.frequncy.enabled = YES;
                break;
            case 1:// Sweep
                self.frequncy.enabled = NO;
                break;
        }
        [[NSUserDefaults standardUserDefaults] setInteger:modeCtrl.selectedSegmentIndex forKey:kOscillatorWaveTypeKey];
    });
}

- (IBAction)sweepAction:(UIButton *)button
{
//    button.selected ^= 1;
    [self stop:button];
}

- (IBAction)stepAction:(UIStepper *)stepper
{
    _frequncy.text = [NSString stringWithFormat:@"%.0f", stepper.value];
    [[NSUserDefaults standardUserDefaults] setFloat:stepper.value forKey:kOscillatorFrequencyKey];
    [self stopProc];
    [self play:nil];
}

- (IBAction)textAction:(UITextField *)text
{
    _stepper.value = (Float32) atoi(text.text.UTF8String);
}


- (IBAction)play:(UIButton *)selectedButton {
    NSInteger freq = atoi(_frequncy.text.UTF8String);
    
    sweepMode = kSweepNone;
    [self stop:nil];

    if (freq < 20 || freq > 22050) {
        _frequncy.text = @"20";
        _stepper.value = 20.0;
        [[NSUserDefaults standardUserDefaults] setFloat:_stepper.value forKey:kOscillatorFrequencyKey];
    }
    [self createToneUnit];
    
    // Stop changing parameters on the unit
    OSErr err = AudioUnitInitialize(m_au);
    NSAssert1(err == noErr, @"Error initializing unit: %hd", err);
    
    // Start playback
    err = AudioOutputUnitStart(m_au);
    NSAssert1(err == noErr, @"Error starting unit: %hd", err);
    
    switch (_mode.selectedSegmentIndex) {
        case kSin:// Sin
            break;
        case kSaw:// Saw
            break;
        case kTriangle:// Triangle
            break;
    }
    //        _sweep.enabled = NO;
    //        _frequncy.enabled = NO;
    
    [_frequncy resignFirstResponder];   // これのせいで落ちている？
//    [selectedButton setImage:[UIImage imageNamed:@"stop"] forState:0];
}

- (IBAction)stop:(UIButton *)selectedButton {
    if (m_au) {
        AudioOutputUnitStop(m_au);
        AudioUnitUninitialize(m_au);
        AudioComponentInstanceDispose(m_au);
        m_au = nil;
    }
}

- (IBAction)rise:(UIButton *)selectedButton {
    [self play:selectedButton];
    sweepMode = kSweepRise;
}

- (IBAction)down:(UIButton *)selectedButton {
    [self play:selectedButton];
    sweepMode = kSweepDown;
}

- (IBAction)togglePlay:(UIButton *)selectedButton
{
    if (m_au)
    {// Stop
        AudioOutputUnitStop(m_au);
        AudioUnitUninitialize(m_au);
        AudioComponentInstanceDispose(m_au);
        m_au = nil;
        
//        _sweep.enabled = YES;
//        _frequncy.enabled = YES;
        [selectedButton setImage:[UIImage imageNamed:@"play"] forState:0];
    } else {// Start
        NSInteger freq = atoi(_frequncy.text.UTF8String);

        if (freq < 20 || freq > 22050) {
            _frequncy.text = @"20";
            _stepper.value = 20.0;
            [[NSUserDefaults standardUserDefaults] setFloat:_stepper.value forKey:kOscillatorFrequencyKey];
        }
        [self createToneUnit];
        
        // Stop changing parameters on the unit
        OSErr err = AudioUnitInitialize(m_au);
        NSAssert1(err == noErr, @"Error initializing unit: %hd", err);
        
        // Start playback
        err = AudioOutputUnitStart(m_au);
        NSAssert1(err == noErr, @"Error starting unit: %hd", err);
        
        switch (_mode.selectedSegmentIndex) {
            case kSin:// Sin
                break;
            case kSaw:// Saw
                break;
            case kTriangle:// Triangle
                break;
        }
//        _sweep.enabled = NO;
//        _frequncy.enabled = NO;

        [_frequncy resignFirstResponder];   // これのせいで落ちている？
        [selectedButton setImage:[UIImage imageNamed:@"stop"] forState:0];
    }
}

- (void)stopProc
{
    [self stop:nil];
}

- (void) setFrequecyValue:(NSUInteger)freq {
    _frequncy.text = [NSString stringWithFormat:@"%ld", freq];
    _stepper.value = freq;
    [[NSUserDefaults standardUserDefaults] setFloat:freq forKey:kOscillatorFrequencyKey];
    
    if (sweepMode == kSweepRise && freq > 22050) {
        dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
            [self stopProc];
            self.frequncy.text = @"22050";
            self.stepper.value = 22050.0;
            [[NSUserDefaults standardUserDefaults] setFloat:self.stepper.value forKey:kOscillatorFrequencyKey];
        });
    } else if (sweepMode == kSweepDown && freq < 20) {
        dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
            [self stopProc];
            self.frequncy.text = @"20";
            self.stepper.value = 20.0;
            [[NSUserDefaults standardUserDefaults] setFloat:self.stepper.value forKey:kOscillatorFrequencyKey];
        });
    }
}

- (IBAction) min:(id)sender {
    [self setFrequecyValue:20];
}

- (IBAction) max:(id)sender {
    [self setFrequecyValue:22050];
}

- (void) increment {

    NSUInteger freq = atoi(_frequncy.text.UTF8String);

#if 1
    if (freq < 100) {
        freq += 1;
    } else if (freq < 500) {
        freq += 2;
    } else if (freq < 1000) {
        freq += 3;
    } else if (freq < 5000) {
        freq += 4;
    } else if (freq < 10000) {
        freq += 5;
    } else if (freq < 50000) {
        freq += 6;
    } else if (freq < 100000) {
        freq += 7;
    }
#else
    freq++;
#endif
    _frequncy.text = [NSString stringWithFormat:@"%lu", (unsigned long)freq];
    _stepper.value = freq;
    [[NSUserDefaults standardUserDefaults] setFloat:freq forKey:@"Frequency"];

    if (sweepMode == kSweepRise && freq > 22050) {
        dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
            [self stopProc];
            self.frequncy.text = @"22050";
            self.stepper.value = 22050.0;
            [[NSUserDefaults standardUserDefaults] setFloat:self.stepper.value forKey:kOscillatorFrequencyKey];
        });
    } else if (sweepMode == kSweepDown && freq < 20) {
        dispatch_async(dispatch_get_main_queue(), ^{ // UI更新はメインスレッドやること！！
            [self stopProc];
            self.frequncy.text = @"20";
            self.stepper.value = 20.0;
            [[NSUserDefaults standardUserDefaults] setFloat:self.stepper.value forKey:kOscillatorFrequencyKey];
        });
    }
}

#pragma mark - UITextFieldDelegate

// テキストフィールドの編集完了を試行する。
- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    
    DEBUG_LOG(@"%s", __func__);
    
    // キーボードを閉じる（FirstResponder をキャンセルする）
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldWillBeginEditing:(UITextField *)textField {
    
    DEBUG_LOG(@"%s", __func__);
}

// マップ表示中の場合は、マップを徐々に消去しテーブルビューを徐々に伸長する。
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    
    DEBUG_LOG(@"%s", __func__);
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    
    DEBUG_LOG(@"%s", __func__);
    _stepper.value = atoi(textField.text.UTF8String);
    [[NSUserDefaults standardUserDefaults] setFloat:_stepper.value forKey:kOscillatorFrequencyKey];
}

// テキストフィールドの入力値変更イベント
- (BOOL)textField:(UITextField *)textField
shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string
{
    return [TextFieldUtil textFieldValidNumber:textField
                 shouldChangeCharactersInRange:range
                             replacementString:string];
}
@end
