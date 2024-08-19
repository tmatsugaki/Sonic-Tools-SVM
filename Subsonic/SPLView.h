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
//  SPLView.h

#import <UIKit/UIKit.h>
#import "definitions.h"
#import "UIPinchGestureRecognizerAxis.h"
#import "SevenSegmentDisplayView.h"
#import "FFTView.h"
#import "FFTSPLSettings.h"
/*
 * 描画用バッファ
 */
#define SPL_BUFFER_SIZE         512     // 512
#define RMS                     OFF

#if (RMS == OFF)
#define DECIBEL_OFFSET          94.0   // 可聴の一番小さい音を -120dB ではなく -94dB としていると想定。
//#define DECIBEL_OFFSET          70.0   // 可聴の一番小さい音を -120dB ではなく -50dB としていると想定。
#else
//#define DECIBEL_OFFSET          80.0    // 可聴の一番小さい音を -120dB ではなく -40dB としていると想定。
#define DECIBEL_OFFSET          60.0    // 可聴の一番小さい音を -120dB ではなく -60dB としていると想定。
#endif

@protocol SPLViewProtocol <NSObject>
- (void) singleTapped;
- (void) setFreezeMeasurement:(BOOL)yesNo;
@end

@interface SPLView : UIView {
    NSUInteger zoomShifter;
    BOOL scrollBarVisibility;
}
@property (strong, nonatomic) IBOutlet UILabel *db;
@property (strong, nonatomic) IBOutlet UILabel *dbLabel;
@property (strong, nonatomic) IBOutlet UIImageView *led;
@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f3;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f2;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f1;
@property (strong, nonatomic) IBOutlet UIView *dot;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f0;

@property (strong, nonatomic) IBOutlet FFTSPLSettings *settingsView;
@property (strong, nonatomic) IBOutlet UILabel *gainLabel;
@property (strong, nonatomic) IBOutlet UISlider *gainSlider;
@property (strong, nonatomic) IBOutlet UILabel *gainInfo;
@property (strong, nonatomic) IBOutlet UIButton *typicalButton;
@property (strong, nonatomic) IBOutlet UIButton *clearButton;

@property (strong, nonatomic) IBOutlet UIView *bannerView;
@property (assign, nonatomic) Float32 rmsValue;
@property (assign, nonatomic) Float32 minValue;
@property (assign, nonatomic) Float32 avgValue;
@property (assign, nonatomic) Float32 maxValue;

@property (strong, nonatomic) IBOutlet UILabel *min;
@property (strong, nonatomic) IBOutlet UILabel *max;
@property (strong, nonatomic) IBOutlet UILabel *rms;

@property (strong, atomic) UIPinchGestureRecognizerAxis *pinchRecognizer;
@property (strong, atomic) UIPanGestureRecognizer *panRecognizer;
@property (strong, atomic) UILongPressGestureRecognizer *longPressRecognizer;

@property (assign, nonatomic) CGPoint scrollLimit;
@property (assign, nonatomic) CGFloat pinchScaleX;
@property (assign, nonatomic) CGFloat pinchScaleY;
@property (assign, nonatomic) CGPoint panStartPt;
@property (assign, nonatomic) CGPoint panEndPt;
@property (assign, nonatomic) CGPoint panOffset;

// データ用リングバッファ
@property (assign, nonatomic) NSInteger dataTail;
@property (assign, nonatomic) Float32 *rawData;

@property (assign, nonatomic) id <SPLViewProtocol> delegate;

- (void) enqueueData:(Float32) data;
- (Float32) peekData:(NSInteger)index;
- (void) setGainInfo;
- (void) setUnitBase;

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
@property (assign, nonatomic) Float64 decibel;
@property (assign, nonatomic) NSUInteger logCounter;
@end
