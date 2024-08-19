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
//  TeslameterSPLView.h

#import <UIKit/UIKit.h>
#import "definitions.h"
#import "UIPinchGestureRecognizerAxis.h"
#include "SevenSegmentDisplayView.h"

/*
 * FFT サンプリングレートなど
 */
#define TESLA_SPL_NUMCHANNELS      1       // 1

#define kOutputBus                  0
#define kInputBus                   1
/*
 * 描画用バッファ
 */
#define Tesla_SPL_BUFFER_SIZE      256       // 512

@protocol TeslameterSPLViewProtocol <NSObject>
- (void) singleTapped;
- (void) setFreezeMeasurement:(BOOL)yesNo;
@end

@interface TeslameterSPLView : UIView {
    NSUInteger zoomShifter;
    BOOL scrollBarVisibility;
}
@property (strong, nonatomic) IBOutlet UILabel *lblMaxRMS;
@property (strong, nonatomic) IBOutlet UILabel *lblAvgRMS;
@property (strong, nonatomic) IBOutlet UILabel *lblMinRMS;
@property (strong, nonatomic) IBOutlet UIImageView *led;
@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet UIView *bannerView;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f3;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f2;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f1;
@property (strong, nonatomic) IBOutlet UIView *dot;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f0;
@property (strong, nonatomic) IBOutlet UILabel *lblUT;
@property (strong, nonatomic) IBOutlet UIButton *clearButton;

@property (strong, atomic) UIPinchGestureRecognizerAxis *pinchRecognizer;
@property (assign, nonatomic) CGPoint scrollLimit;
@property (assign, nonatomic) CGFloat pinchScaleX;
@property (assign, nonatomic) CGFloat pinchScaleY;
@property (assign, nonatomic) CGPoint panStartPt;
@property (assign, nonatomic) CGPoint panEndPt;
@property (assign, nonatomic) CGPoint panOffset;

// データ用リングバッファ
@property (assign, nonatomic) NSInteger dataTail;
@property (assign, nonatomic) Float32 *rawData;

@property (assign, nonatomic) Float32 rmsValue;
@property (assign, nonatomic) Float32 maxRMS;
@property (assign, nonatomic) Float32 avgRMS;
@property (assign, nonatomic) Float32 minRMS;
@property (assign, nonatomic) id <TeslameterSPLViewProtocol> delegate;

- (void) enqueueData:(Float32) data;
- (Float32) peekData:(NSInteger)index;

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
@property (assign, nonatomic) Float64 rawMF;
@end
