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
//  SpectrumViewController.h

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "definitions.h"
#import "SubsonicViewController.h"
#import "FFTView.h"

#define kSpectrumPeakHoldKey            @"PeakHold"
#define kSpectrumModeKey                @"SpectrumMode"
#define kSelectedHzKey                  @"SelectedHz"
//#define kSpectrumAgcKey                 @"SpectrumAGC"
#define kSpectrumCSVKey                 @"SoundSpectrumCSV"
#define kFFTMathModeLinearKey           @"FFTMathModeLinear"
#define kSpectrogramMathModeLinearKey   @"SpectrogramMathModeLinear"
#define kRTAModeLineKey                 @"RTAModeLine"
#define kFFTHideRulerKey                @"FFTHideRuler"
#define kFFTVolumeDecadesKey            @"FFTVolumeDecades"
#define kFFTPinchScaleXKey              @"FFTPinchScaleX"
#define kFFTPinchScaleYKey              @"FFTPinchScaleY"
#define kFFTPanOffsetXKey               @"FFTPanOffsetX"
#define kFFTPanOffsetYKey               @"FFTPanOffsetY"
#define kFFTColoringKey                 @"FFTColoring"
#define kRTAColoringKey                 @"RTAColoring"
#define kRTAAverageModeKey              @"RTAAverageMode"
#define kSpectrogramNoiseLevelKey       @"FFTNoiseLevel"
//#define kLatencyKey                     @"Latency"

enum {
    kSpectrumFFT,
    kSpectrumRTA,
    kSpectrumRTA1_3,
    kSpectrumRTA1_6,
    kSpectrumRTA1_12,
    kSpectrogram,
    kSpectrumLast
};

#define REFRESH_INTERVAL        STD_REFRESH_INTERVAL    // 0.05

@interface SpectrumViewController : SubsonicViewController <FFTViewProtocol> {
    BOOL fftInitialized;
}
@property (strong, nonatomic) IBOutlet FFTView *fftView;
@property (assign, nonatomic) IBOutlet NSLayoutConstraint *contentConstraint;
@property (assign, nonatomic) BOOL freeze;
@property (strong, nonatomic) NSTimer *refreshTimer;
@end

