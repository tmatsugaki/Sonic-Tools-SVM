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
//  AccelometerScopeView.h

#import <UIKit/UIKit.h>
#import "definitions.h"
#import "UIPinchGestureRecognizerAxis.h"
#include "SevenSegmentDisplayView.h"

/*
 * FFT サンプリングレートなど
 */
#define ACCELO_SCOPE_SAMPLE_RATE        32  // 32
#define ACCELO_SCOPE_OP_SIZE            32  // 32
#define ACCELO_SCOPE_NUMCHANNELS        1   // 1

#define kOutputBus                      0
#define kInputBus                       1
/*
 * 描画用バッファ
 */
#define Accelo_SCOPE_BUFFER_SIZE        256     // 512
#define NUM_H_DECADES                   10      // 10
#define NUM_V_DECADES                   20      // 20

@protocol AccelometerScopeViewProtocol <NSObject>
- (void) singleTapped;
- (void) setFreezeMeasurement:(BOOL)yesNo;
@end

@interface AccelometerScopeView : UIView {
    NSUInteger zoomShifter;
    BOOL scrollBarVisibility;
}
@property (strong, nonatomic) IBOutlet UILabel *lblMaxRed;
@property (strong, nonatomic) IBOutlet UILabel *lblAvgRed;
@property (strong, nonatomic) IBOutlet UILabel *lblMinRed;
@property (strong, nonatomic) IBOutlet UILabel *lblMaxGreen;
@property (strong, nonatomic) IBOutlet UILabel *lblAvgGreen;
@property (strong, nonatomic) IBOutlet UILabel *lblMinGreen;
@property (strong, nonatomic) IBOutlet UILabel *lblMaxBlue;
@property (strong, nonatomic) IBOutlet UILabel *lblAvgBlue;
@property (strong, nonatomic) IBOutlet UILabel *lblMinBlue;
@property (strong, nonatomic) IBOutlet UIImageView *led;
@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet UIView *bannerView;

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
@property (assign, nonatomic) Float32 *rawDataX;
@property (assign, nonatomic) Float32 *rawDataY;
@property (assign, nonatomic) Float32 *rawDataZ;
@property (assign, nonatomic) Float32 maxRed;
@property (assign, nonatomic) Float32 avgRed;
@property (assign, nonatomic) Float32 minRed;
@property (assign, nonatomic) Float32 maxGreen;
@property (assign, nonatomic) Float32 avgGreen;
@property (assign, nonatomic) Float32 minGreen;
@property (assign, nonatomic) Float32 maxBlue;
@property (assign, nonatomic) Float32 avgBlue;
@property (assign, nonatomic) Float32 minBlue;
@property (assign, nonatomic) id <AccelometerScopeViewProtocol> delegate;

- (void) enqueueData:(Float32) data xyz:(NSUInteger)xyz;
- (Float32) peekData:(NSInteger)index xyz:(NSUInteger)xyz;
@end
