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
//  AccelometerSpectrumView.h

#import <UIKit/UIKit.h>
#import "definitions.h"
#import "UIPinchGestureRecognizerAxis.h"
#include "SevenSegmentDisplayView.h"

/*
 * FFT サンプリングレートなど
 */
#define ACCELO_SPECTRUM_SAMPLE_RATE         128     // 128
#define ACCELO_SPECTRUM_HALF_SAMPLE_RATE    64      // 64
#define ACCELO_SPECTRUM_NUMCHANNELS         1       // 1
#define ACCELO_SPECTRUM_FFT_SIZE            128     // 128
#define ACCELO_SPECTRUM_HALF_FFT_SIZE       64      // 64

#define kOutputBus                          0
#define kInputBus                           1
/*
 * 描画用バッファ
 */
#define Accelo_Spectrum_BUFFER_SIZE         ACCELO_SPECTRUM_HALF_FFT_SIZE   // 64

@protocol AccelometerSpectrumViewProtocol <NSObject>
- (void) singleTapped;
- (void) setFreezeMeasurement:(BOOL)yesNo;
@end

@interface AccelometerSpectrumView : UIView {
    NSUInteger zoomShifter;
    BOOL scrollBarVisibility;
}
@property (strong, nonatomic) IBOutlet UIImageView *led;
@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet UIView *bannerView;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f1;
@property (strong, nonatomic) IBOutlet SevenSegmentDisplayView *f0;
// Data
@property (strong, atomic) UIPinchGestureRecognizerAxis *pinchRecognizer;
@property (assign, nonatomic) CGPoint scrollLimit;
@property (assign, nonatomic) CGFloat pinchScaleX;
@property (assign, nonatomic) CGFloat pinchScaleY;
@property (assign, nonatomic) CGPoint panStartPt;
@property (assign, nonatomic) CGPoint panEndPt;
@property (assign, nonatomic) CGPoint panOffset;

@property (assign, nonatomic) NSInteger tailX;
@property (assign, nonatomic) NSInteger tailY;
@property (assign, nonatomic) NSInteger tailZ;
//@property (assign, nonatomic) Float32 *rawDataX;
//@property (assign, nonatomic) Float32 *rawDataY;
//@property (assign, nonatomic) Float32 *rawDataZ;
@property (assign, nonatomic) NSUInteger maxIndex;
@property (assign, nonatomic) Float32 maxHZ;
@property (assign, nonatomic) Float32 maxHZValue;
@property (assign, nonatomic) Float32 *fftDataX;
@property (assign, nonatomic) Float32 *fftDataY;
@property (assign, nonatomic) Float32 *fftDataZ;
@property (assign, nonatomic) id <AccelometerSpectrumViewProtocol> delegate;

- (void) memmove:(Float32 *) dstX srcX:(Float32 *) srcX dstY:(Float32 *) dstY srcY:(Float32 *) srcY dstZ:(Float32 *) dstZ srcZ:(Float32 *) srcZ len:(NSUInteger)len;
@end
