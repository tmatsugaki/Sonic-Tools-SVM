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
//  ScopeView.h

#import <UIKit/UIKit.h>
#import "definitions.h"
#import "UIPinchGestureRecognizerAxis.h"
#import "SevenSegmentDisplayView.h"
#import "FFTView.h"
#import "FFTScopeSettings.h"
/*
 * FFT サンプリングレートなど
 */
#define SCOPE_NUMCHANNELS           FFT_NUMCHANNELS     // 2:
#define SCOPE_CHUNK_SIZE            2048                // 2048: 2048にしただけでは駄目だったので、FFT_FRAMESIZE を 512 → 2048 にしたところ安定化した！？ TAK on Jun 5th, 2017
#define DEFAULT_VOLT_RANGE          4.0                 // 10m[Pa|FS] のレンジ
/*
 * 描画用バッファ
 */
#define SCOPE_BUFFER_SIZE           1024                // 512: 1024 辺りが描画の限界で

@protocol ScopeViewProtocol <NSObject>

- (void) singleTapped;
- (void) setFreezeMeasurement:(BOOL)yesNo;
@end

@interface ScopeView : UIView {
    NSUInteger scopeBufferSize;
    NSUInteger zoomShifter;
    BOOL scrollBarVisibility;
}
@property (strong, nonatomic) IBOutlet UIImageView *led;
@property (strong, nonatomic) IBOutlet UILabel *leftHeader;
@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet UISegmentedControl *autoTrigger;
@property (strong, nonatomic) IBOutlet UISlider *triggerLevel;

@property (strong, nonatomic) IBOutlet FFTScopeSettings *settingsView;
@property (strong, nonatomic) IBOutlet UILabel *gainLabel;
@property (strong, nonatomic) IBOutlet UISlider *gainSlider;
@property (strong, nonatomic) IBOutlet UIButton *typicalButton;
@property (strong, nonatomic) IBOutlet UIButton *clearButton;
@property (strong, nonatomic) IBOutlet UILabel *gainInfo;

@property (strong, nonatomic) UIView *bannerView;

// データ用リングバッファ
@property (assign, nonatomic) NSInteger dataTail;
@property (assign, nonatomic) Float32 *rawData;

// Pinch
@property (strong, atomic) UIPinchGestureRecognizerAxis *pinchRecognizer;
@property (strong, atomic) UIPanGestureRecognizer *panRecognizer;
@property (strong, atomic) UILongPressGestureRecognizer *longPressRecognizer;

@property (assign, nonatomic) CGPoint scrollLimit;
@property (assign, nonatomic) CGFloat pinchScaleX;
@property (assign, nonatomic) CGFloat pinchScaleY;
@property (assign, nonatomic) CGPoint pinchStartX;
@property (assign, nonatomic) CGFloat pinchStartY;

// Pan
@property (assign, nonatomic) CGPoint panStartPt;
@property (assign, nonatomic) CGPoint panEndPt;
@property (assign, nonatomic) CGPoint panOffset;

//@property (strong, atomic) NSMutableArray *rmsArray;
@property (assign, nonatomic) id <ScopeViewProtocol> delegate;

- (void) enqueueData:(Float32) data;
- (Float32) peekData:(NSInteger)index;
- (void) postUpdate;
- (void) setGainInfo;
@end
