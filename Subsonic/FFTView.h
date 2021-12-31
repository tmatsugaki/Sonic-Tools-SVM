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
//  FFTView.h

#import <UIKit/UIKit.h>
#import "definitions.h"
#import "UIPinchGestureRecognizerAxis.h"
#import "SevenSegmentDisplayView.h"
#import "FFTSpectrumSettings.h"

/*
 * FFT サンプリングレートなど
 */
#define kOutputBus                  0
#define kInputBus                   1
/*
 * 描画用バッファ
 */
@protocol FFTViewProtocol <NSObject>
- (void) singleTapped;
- (void) setFreezeMeasurement:(BOOL)yesNo;
- (void) maintainControl:(NSUInteger)spectrumMode;
@end

@interface FFTView : UIView {
    NSUInteger fftBufferSize;
    Float32 *peakData;
#if (RTA_LOOKUP == ON)
    Float64 *peakRatio;
#endif
    Float32 *fftData;
    NSUInteger zoomShifter;
    BOOL scrollBarVisibility;
}
//@property (assign, nonatomic) NSUInteger fftBufferSize;
@property (strong, nonatomic) IBOutlet UIImageView *led;
@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet UILabel *dB;
//@property (strong, nonatomic) IBOutlet UILabel *agcLabel;
@property (strong, nonatomic) IBOutlet UIButton *peakHold;
@property (strong, nonatomic) IBOutlet UIButton *agcSwitch;
@property (strong, nonatomic) IBOutlet UISegmentedControl *logOrLinear;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f4;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f3;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f2;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f1;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f0;

@property (strong, nonatomic) IBOutlet UILabel *rtaHzLabel;
@property (strong, nonatomic) IBOutlet UILabel *rtaHzText;
@property (strong, nonatomic) IBOutlet UILabel *rtaDecibelLabel;
@property (strong, nonatomic) IBOutlet UILabel *rtaDecibelText;

@property (strong, nonatomic) IBOutlet FFTSpectrumSettings *settingsView;
@property (strong, nonatomic) IBOutlet UILabel *colorLabel;
@property (strong, nonatomic) IBOutlet UISwitch *colorSwitch;
@property (strong, nonatomic) IBOutlet UILabel *windowFunctionLabel;
@property (strong, nonatomic) IBOutlet UIButton *windowFunctionButton; // 小さな iPhone のポートレート用
@property (strong, nonatomic) IBOutlet UISegmentedControl *windowFunctionSegment;
@property (strong, nonatomic) IBOutlet UILabel *gainLabel;
@property (strong, nonatomic) IBOutlet UISlider *gainSlider;
@property (strong, nonatomic) IBOutlet UILabel *gainInfo;
#if 1
@property (strong, nonatomic) IBOutlet UISegmentedControl *averageSegment;
//@property (strong, nonatomic) IBOutlet UILabel *averageLabel;
//@property (strong, nonatomic) IBOutlet UILabel *averageText;
#endif
@property (strong, nonatomic) IBOutlet UILabel *noiseReductionLabel;
@property (strong, nonatomic) IBOutlet UISlider *noiseReductionSlider;
@property (strong, nonatomic) IBOutlet UIButton *typicalButton;
@property (strong, nonatomic) IBOutlet UIButton *exploreButton;

@property (strong, atomic) UIPinchGestureRecognizerAxis *pinchRecognizer;
@property (strong, atomic) UIPanGestureRecognizer *panRecognizer;
@property (strong, atomic) UILongPressGestureRecognizer *longPressRecognizer;

@property (assign, nonatomic) CGPoint scrollLimit;
@property (assign, nonatomic) CGFloat pinchScaleX;
@property (assign, nonatomic) CGFloat pinchScaleY;
@property (assign, nonatomic) CGPoint panStartPt;
@property (assign, nonatomic) CGPoint panEndPt;
@property (assign, nonatomic) CGPoint panOffset;

@property (assign, nonatomic) NSUInteger mode;      // 0:FFT, 1:RTA
//@property (assign, nonatomic) Float32 *fftData;

@property (assign, nonatomic) NSUInteger maxIndex;
@property (assign, nonatomic) Float32 maxHZ;
@property (assign, nonatomic) Float32 maxHZValue;
@property (assign, nonatomic) id <FFTViewProtocol> delegate;

// リングバッファ(クリティカルなので、atomic にすること)
@property (assign, atomic) NSUInteger allocatedRows;
@property (assign, atomic) NSUInteger effectiveRows;
@property (assign, atomic) CGImageRef *lineBuffers;
@property (assign, atomic) uint8_t *lineBuffer;
@property (assign, atomic) NSInteger datumTail;
@property (assign, atomic) CGImageRef enqueueCandidate;
#if (SPECTROGRAM_COMP == ON)
@property (assign, atomic) BOOL busy;
#endif

// for CSV output
#if (CSV_OUT == ON)
- (IBAction) stopAction:(id)sender;
@property (strong, nonatomic) IBOutlet UIButton *stopSwitch;
@property (strong, nonatomic) IBOutlet UIButton *playPauseSwitch;
#endif
@property (strong, nonatomic) NSDateFormatter *fileDateFormatter;
@property (strong, nonatomic) NSDateFormatter *dataDateFormatter;
@property (assign, nonatomic) FILE *fp;
@property (strong, nonatomic) NSTimer *logTimer;
@property (assign, nonatomic) NSUInteger logCounter;

@property (strong, nonatomic) NSTimer *averageTimer;

#if (SPECTROGRAM_COMP == ON)
- (void) pauseReceiveData:(BOOL)yesNo;
#endif
- (void) maintainControl:(NSUInteger)spectrumMode;
- (void) maintainPeakGridButton;
- (void) clearPeaks;
- (void) initializeRTA;
- (void) initializeRingBuffer;
- (void) setFFTData:(Float32 *)buffer;
- (void) enqueueImage:(CGImageRef) imageRef;
- (CGImageRef) peekImage:(NSInteger)index;
- (void) setGainInfo;
- (void) setUnitBase;
@end
