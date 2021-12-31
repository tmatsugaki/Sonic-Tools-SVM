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
//  FFTView.m

//#import <AVFoundation/AVAudioSession.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import "FFTHelper.hh"
#import "FFTView.h"
#import "ColorUtil.h"
#import "Environment.h"
#import "SpectrumViewController.h"
#import "ScrollIndicator.h"
#import "WindowFunctionViewController.h"

#define GRAVITY         ON

#define currentRow() MIN(datumTail, effectiveRows - 1)
// 色相を寒色(低)→暖色（高）の値に変換する。
static float s_gain = 10.0;
static float s_offset_x = 0.2;
static float s_offset_green = 0.6;
// RTA用変数
typedef struct {
    NSUInteger count;
    Float64 avgRatio;
    Float64 curRatio;
    Float64 peakRatio;
    Float64 peakValue;
    CGRect bar;
} RTA;
static RTA gRTA[120]; // 6*10バンド

#if (RTA_LOOKUP == ON)
NSUInteger *rta1Index;
NSUInteger *rta1_3Index;
NSUInteger *rta1_6Index;
NSUInteger *rta1_12Index;
#endif

// リングバッファの材料
//static NSUInteger allocatedRows = 0;
//static NSUInteger effectiveRows = 0;
//static uint8_t *lineBuffer = nil;
//static CGImageRef *lineBuffers = nil;
//static NSInteger datumTail = 0;         // lineBuffer[datumTail] は新規に使うべき場所
//static CGImageRef enqueueCandidate;
//static BOOL busy;

static float sigmoid(float x, float g, float o) {
    return (tanh((x + o) * g / 2) + 1) / 2;
}

static void heat(CGFloat x, CGFloat *rRet, CGFloat *gRet, CGFloat *bRet) {  // 0.0〜1.0の値を青から赤の色に変換する
    x = x * 2 - 1;  // -1 <= x < 1 に変換
    
    *rRet = sigmoid(x, s_gain, -1 * s_offset_x);
    *bRet = 1.0 - sigmoid(x, s_gain, s_offset_x);
    *gRet = sigmoid(x, s_gain, s_offset_green) + (1.0 - sigmoid(x, s_gain, -1 * s_offset_green)) - 1;
}

static void bufferFree(void *info, const void *data, size_t size)
{
    if (data) {
        free((void *)data);
    }
}

static size_t align16(size_t size)
{
    if (size) {
        return (((size - 1) >> 4) << 4) + 16;
    } else {
        return 0;
    }
}

static size_t align32(size_t size)
{
    if (size) {
        return (((size - 1) >> 5) << 5) + 32;
    } else {
        return 0;
    }
}

@implementation FFTView

// Designated initializer
- (id) initWithCoder:(NSCoder*)decoder
{
    self = [super initWithCoder:decoder];
    if (self != nil) {// FFT_HALF_DATA_POINTS = 8192 なので、その半分の
        self.allocatedRows = 0;
        self.effectiveRows = 0;
        self.lineBuffers = nil;
        self.lineBuffer = nil;
        self.datumTail = 0;         // lineBuffer[datumTail] は新規に使うべき場所
        self.enqueueCandidate = nil;
#if (SPECTROGRAM_COMP == ON)
        self.busy = NO;
#endif
        NSUInteger fftPoints = [UserDefaults sharedManager].fftPoints;

        fftBufferSize = fftPoints / 2;
        // Float32 が 2048個
        assert(fftData = calloc(fftBufferSize, sizeof(Float32)));
        assert(peakData = calloc(fftBufferSize, sizeof(Float32)));
#if (RTA_LOOKUP == ON)
        assert(peakRatio = calloc(fftBufferSize, sizeof(Float64)));
#endif
//        [self clearBuffer:self];
        for (NSUInteger i = 0; i < fftBufferSize; i++) {
            fftData[i] = PIANISSIMO;
        }
        self.maxHZValue = -PIANISSIMO; // 最大120dB とする。

        /*
         * ピンチレコグナイザーを追加する。
         */
        self.pinchRecognizer = [[UIPinchGestureRecognizerAxis alloc]
                                initWithTarget:self
                                action:@selector(handlePinch:)];
        [self addGestureRecognizer:(_pinchRecognizer)];
        /*
         * パンレコグナイザーを追加する。
         */
        self.panRecognizer =
        [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(handlePan:)];
        [self addGestureRecognizer:_panRecognizer];
        /*
         * 長押しレコグナイザーを追加する。
         */
        self.longPressRecognizer =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(handleLongPress:)];
        [self addGestureRecognizer:_longPressRecognizer];
        
        _pinchScaleX = [[NSUserDefaults standardUserDefaults] floatForKey:kFFTPinchScaleXKey];
        _pinchScaleY = [[NSUserDefaults standardUserDefaults] floatForKey:kFFTPinchScaleYKey];
        _panOffset.x = [[NSUserDefaults standardUserDefaults] floatForKey:kFFTPanOffsetXKey];
        _panOffset.y = [[NSUserDefaults standardUserDefaults] floatForKey:kFFTPanOffsetYKey];
        if (_pinchScaleX < 1.0) {
            _pinchScaleX = 1.0;
            _panOffset.x = 0.0;
            _panOffset.y = 0.0;
        }
        if (_pinchScaleY < 1.0) {
            _pinchScaleY = 1.0;
            _panOffset.x = 0.0;
            _panOffset.y = 0.0;
        }
#if (CENTERING == ON)
        [_pinchRecognizer setScaleX:_pinchScaleX];
        [_pinchRecognizer setScaleY:_pinchScaleY];
#endif
        [self initFormatter];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kSpectrumCSVKey];

#if (RTA_LOOKUP == ON)
        NSUInteger spectrumModeSave = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
        Float64 halfSampleRate = [UserDefaults sharedManager].sampleRate / 2.0;
        Float64 freqDelta = round(halfSampleRate / fftBufferSize);
        rta1Index = calloc(sizeof(NSUInteger), halfSampleRate);
        rta1_3Index = calloc(sizeof(NSUInteger), 3 * halfSampleRate);
        rta1_6Index = calloc(sizeof(NSUInteger), 6 * halfSampleRate);
        rta1_12Index = calloc(sizeof(NSUInteger), 12 * halfSampleRate);

        [[NSUserDefaults standardUserDefaults] setInteger:kSpectrumRTA forKey:kSpectrumModeKey];
        for (NSUInteger dataIndex = 0; dataIndex < fftBufferSize; dataIndex++) {
            rta1Index[dataIndex] = [self frequency2LogIndex:freqDelta * dataIndex];
        }
        [[NSUserDefaults standardUserDefaults] setInteger:kSpectrumRTA1_3 forKey:kSpectrumModeKey];
        for (NSUInteger dataIndex = 0; dataIndex < fftBufferSize; dataIndex++) {
            for (NSUInteger div = 0; div < 3; div++) {
                rta1_3Index[3 * dataIndex + div] = [self frequency2LogIndex:freqDelta * (dataIndex + ((Float64) div) / 3.0)];
            }
        }
        [[NSUserDefaults standardUserDefaults] setInteger:kSpectrumRTA1_6 forKey:kSpectrumModeKey];
        for (NSUInteger dataIndex = 0; dataIndex < fftBufferSize; dataIndex++) {
            for (NSUInteger div = 0; div < 6; div++) {
                rta1_6Index[6 * dataIndex + div] = [self frequency2LogIndex:freqDelta * (dataIndex + ((Float64) div) / 6.0)];
            }
        }
        [[NSUserDefaults standardUserDefaults] setInteger:kSpectrumRTA1_12 forKey:kSpectrumModeKey];
        for (NSUInteger dataIndex = 0; dataIndex < fftBufferSize; dataIndex++) {
            for (NSUInteger div = 0; div < 12; div++) {
                rta1_12Index[12 * dataIndex + div] = [self frequency2LogIndex:freqDelta * (dataIndex + ((Float64) div) / 12.0)];
            }
        }
        [[NSUserDefaults standardUserDefaults] setInteger:spectrumModeSave forKey:kSpectrumModeKey];
#endif
    }
    return self;
}

- (void) initializeRTA {
    for (NSUInteger barIndex = 0; barIndex < 120; barIndex++) {
        gRTA[barIndex].count = 0;
#if 0
        gRTA[barIndex].avgRatio = 0.0;
        gRTA[barIndex].curRatio = 0.0;
        gRTA[barIndex].peakRatio = 0.0;
        gRTA[barIndex].peakValue = 0.0;
#endif
        gRTA[barIndex].bar = CGRectMake(0.0, 0.0, 0.0, 0.0);
    }
}

- (void) layoutSubviews {

    @synchronized (self) {
        [super layoutSubviews];

        CGRect rect = self.frame;
        CGRect frame = CGGraphRectMake(rect);
        
        _peakHold.layer.cornerRadius = 5.0;
        _agcSwitch.layer.cornerRadius = 5.0;

        if (self.lineBuffers == nil) {
            self.allocatedRows = MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
            // 長い辺の長さのスペクトログラム用データバッファを確保する。
            // ポインタの置き場を確保するだけ。
            self.lineBuffers = calloc(sizeof(CGImageRef), self.allocatedRows);
            self.datumTail = 0;
        }
        /****************************************************************
         * リングバッファのサイズが変化した場合は施しが必要！！
         ****************************************************************/
        NSUInteger nextEffectiveRows = frame.size.height;

#if (SPECTROGRAM_COMP == ON)
        if (self.effectiveRows != 0 && self.effectiveRows != nextEffectiveRows)
        {
            if (self.datumTail >= nextEffectiveRows)
            {// イメージバッファが全て充填されている場合
                [self maintainRingBuffer:self.effectiveRows after:nextEffectiveRows];
            }
        }
        self.effectiveRows = nextEffectiveRows;
#else
        self.effectiveRows = nextEffectiveRows;
        [self initializeRingBuffer];
#endif
//        DEBUG_LOG(@"effectiveRows:%d", (int) self.effectiveRows);
        
        [self maintainScrollableArea:frame];
        [self maintainPinch];
        [self maintainPan];
    }
    [self initializeRTA];
    [self setGainInfo]; // Added on Jun 13, 2021 by T.M.
    [self setUnitBase]; // Added on Jun 13, 2021 by T.M.
}

#pragma mark - UIResponder (Event Handler)

// 【注意】コンテクストメニューの初期化をすることに注意
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event // タップ開始
{
    switch ((int) event.type) {
        case UIEventTypeTouches:
            // 【注意】loupeGesture に備えて、CCPメニューから「全選択解除」を取り除く。
            //       設定するのは、singleTapAction か handleLongPress ！！
            [UIMenuController sharedMenuController].menuItems = nil;
            break;
    }
    [super touchesBegan:touches withEvent:event];
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {

    switch ((int) event.type) {
        case UIEventTypeTouches:
            switch ([[touches anyObject] tapCount]) {
                case 1:
                    [self singleTapAction:self];
                    break;
            }
            break;
    }
    [super touchesEnded:touches withEvent:event];
}

- (IBAction) singleTapAction:(id) sender {
    
    [_delegate singleTapped];

    if (((SpectrumViewController *) _delegate).freeze) {
        _header.text = [[UserDefaults sharedManager] timeStamp];
    } else {
        _header.text = @"";
    }
}

#pragma mark - View lifecycle Utils

#pragma mark - 平均化
- (void) startAverage:(NSUInteger)averageMode {

    if ([_averageTimer isValid] == YES) {
        [_averageTimer invalidate];
    }
    switch (averageMode) {
        case 1:
            self.averageTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30.0 target:self selector:@selector(clearAverageCount) userInfo:nil repeats:YES];
            break;
        case 2:
            self.averageTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/15.0 target:self selector:@selector(clearAverageCount) userInfo:nil repeats:YES];
            break;
    }
}

- (void) stopAverage {
    if ([_averageTimer isValid] == YES) {
        [_averageTimer invalidate];
    }
    self.averageTimer = nil;
}

#pragma mark - 描画ツール群
// 縦ステップ
- (void) drawFrame:(CGContextRef)context
              rect:(CGRect)rect
             scale:(CGFloat)scale
            offset:(CGPoint)offset
{
    CGRect frame = CGGraphRectMake(rect);
    Float32 org_x = frame.origin.x;
    Float32 org_y = frame.origin.y;
    Float32 width = frame.size.width;
    Float32 height = frame.size.height;
    Float32 bot_y = org_y + height;

    CGContextSetLineWidth(context, 1.0);
    // 外枠（拡大なしの座標）
    CGContextSetStrokeColorWithColor(context, [ColorUtil vfdOn].CGColor);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context   , org_x, org_y);
    CGContextAddLineToPoint(context, org_x, bot_y);
    CGContextAddLineToPoint(context, org_x + width, bot_y);
    CGContextStrokePath(context);
}

// 縦ステップ
- (void) drawVerticalSteps:(CGContextRef)context
                      rect:(CGRect)rect
                    scaleY:(CGFloat)scaleY
                    offset:(CGPoint)offset
{
    CGRect frame = CGGraphRectMake(rect);
    Float32 volumeDecades = FULL_DYNAMIC_RANGE_DECADE;

    if (_pinchScaleY >= 4.0) {
        volumeDecades *= 4;
    } else if (_pinchScaleY >= 2.0) {
        volumeDecades *= 2;
    }
    Float32 org_x = frame.origin.x;
    Float32 org_y = frame.origin.y;
    Float32 height = frame.size.height;
    Float32 bot_y = org_y + height;
    Float32 db_ruler_delta = scaleY * frame.size.height / volumeDecades;

    UIFont *font = nil;
    UIColor *color = nil;
    
    CGContextSetLineWidth(context, 0.2);
    // 縦ステップ
    font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:7.5];
    color = [ColorUtil vfdOn];
    CGContextSetStrokeColorWithColor(context, [ColorUtil vfdOn].CGColor);
    CGContextSetFillColorWithColor(context, [ColorUtil vfdOn].CGColor);
    // Active(-40dB〜120dB)
    static NSInteger dbLabelVolts[] = {120, 100, 80, 60, 40, 20, 0, -20, -40}; // 8+1
    static NSInteger dbLabelVolts2X[] = {120, 110, 100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 0, -10, -20, -30, -40}; // 16+1
    static NSInteger dbLabelVolts4X[] = {120, 115, 110, 105, 100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50, 45, 40, 35, 30, 25, 20, 15, 10, 5, 0, -5, -10, -15, -20, -25, -30, -35, -40}; // 32+1
    NSInteger *dbLabel = nil;
    if (_pinchScaleY >= 4.0) {
        dbLabel = dbLabelVolts4X;
    } else if (_pinchScaleY >= 2.0) {
        dbLabel = dbLabelVolts2X;
    } else {
        dbLabel = dbLabelVolts;
    }
    for (NSUInteger i = 0; i < volumeDecades + 1; i++) {
        NSString *title = [NSString stringWithFormat:@"%ld", (long)dbLabel[i]];
        Float32 hOffset = 10.5 * [title length] / 2.0; // 15
        CGPoint point = CGPointMake((org_x - hOffset), org_y + (db_ruler_delta * i - 5.0) + offset.y);  // #1
        
        if (point.y > org_y - 5.5 && point.y < bot_y - 3.75) {// 7.5ポイントの半分（論理クリッピング）
            [title drawAtPoint:point withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color}];
        }
    }
}

// 横罫線
- (void) drawHorizontalGuide:(CGContextRef)context
                        rect:(CGRect)rect
                      scaleX:(CGFloat)scaleX
                      scaleY:(CGFloat)scaleY
                      offset:(CGPoint)offset
{
    CGRect frame = CGGraphRectMake(rect);
    BOOL isHideRuler = [[NSUserDefaults standardUserDefaults] boolForKey:kFFTHideRulerKey] &&
                       [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey] == kSpectrogram;
    Float32 volumeDecades = FULL_DYNAMIC_RANGE_DECADE;
    if (_pinchScaleY >= 4.0) {
        volumeDecades *= 4;
    } else if (_pinchScaleY >= 2.0) {
        volumeDecades *= 2;
    }
    Float32 org_x = frame.origin.x;
    Float32 org_y = frame.origin.y;
    Float32 width  = frame.size.width  * scaleX;
    Float32 height = frame.size.height * scaleY;
    Float32 db_ruler_delta = height / volumeDecades;

    CGContextSetLineWidth(context, 0.2);
    if (! isHideRuler) {// 横罫線
        CGContextBeginPath(context);
        for (NSUInteger i = 0; i < volumeDecades; i++) {
            Float32 vPos = (org_y + db_ruler_delta * i) + offset.y;

            if (vPos >= FRAME_OFFSET && vPos <= org_y + frame.size.height)    // 論理クリッピング #2
            {// 論理クリッピング
                CGContextMoveToPoint(context   , fmax(FRAME_OFFSET, org_x + offset.x), vPos);  // #3
                CGContextAddLineToPoint(context,           (org_x + width) + offset.x, vPos);  // #4
            }
        }
        CGContextStrokePath(context);
    }
}

// 横ステップと縦罫線(FFT)
- (void) drawHorizontalStepsAndVerticalGuide:(CGContextRef)context
                                        rect:(CGRect)rect
                                      scaleX:(CGFloat)scaleX
                                      offset:(CGPoint)offset
{
    NSUInteger halfSampleRate = [UserDefaults sharedManager].sampleRate / 2.0;   // デフォルトは 22050Hz
    Float64 multiplier = halfSampleRate / 22050.0;
    CGRect frame = CGGraphRectMake(rect);
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    BOOL isLinear = (spectrumMode == kSpectrumFFT && [[NSUserDefaults standardUserDefaults] boolForKey:kFFTMathModeLinearKey]) ||
                    (spectrumMode == kSpectrogram && [[NSUserDefaults standardUserDefaults] boolForKey:kSpectrogramMathModeLinearKey]);
    BOOL isHideRuler = [[NSUserDefaults standardUserDefaults] boolForKey:kFFTHideRulerKey] &&
                       [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey] == kSpectrogram;
    Float32 org_x = frame.origin.x;
    Float32 org_y = frame.origin.y;
    Float32 width = frame.size.width * scaleX;
    Float32 bot_y = org_y + frame.size.height;
    
    UIFont *font = nil;
    UIColor *color = nil;
    
    CGContextSetLineWidth(context, 0.2);
    // 横ステップ
    font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:11.0];
    color = [ColorUtil vfdOn];
    CGContextSetStrokeColorWithColor(context, [ColorUtil vfdOn].CGColor);
    CGContextSetFillColorWithColor(context, [ColorUtil vfdOn].CGColor);

    if (isLinear)
    {// リニア縦罫線
        if (! isHideRuler) {
            CGContextBeginPath(context);
        }
        // 22050Hz の按分が基本
        Float32 scaleMax = 20000.0;
        NSUInteger divisor = 20;
        NSUInteger numBars = 24;
        
        if (multiplier > 1.0) {
            scaleMax = multiplier * scaleMax;
            divisor  = multiplier * divisor;
        }
        Float32 ruler_dh = (scaleMax / halfSampleRate * width) / divisor;
        for (NSUInteger i = 0; i < numBars; i++) {
            Float32 hpos = multiplier * ruler_dh * i + org_x;

            if (i && ((i & 1) == 0 || _pinchScaleX >= 2.0)) {
                NSString *title = [NSString stringWithFormat:@"%luK", (unsigned long) (multiplier * i)];
                Float32 hOffset = (7.0 * [title length] / 2.0); // 6.0
                CGPoint point = CGPointMake((hpos - hOffset) + offset.x, bot_y + 2.0);  // #5
                [title drawAtPoint:point withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color}];
            }
            if (! isHideRuler) {
                if (i > 0 && (hpos + offset.x) > FRAME_OFFSET) {// 論理クリッピング #6
                    CGContextMoveToPoint(context   , hpos + offset.x, org_y);   // #7
                    CGContextAddLineToPoint(context, hpos + offset.x, bot_y);   // #8
                }
            }
        }
        if (! isHideRuler) {
            CGContextStrokePath(context);
        }
    } else
    {// 対数縦罫線
        static Float32 rulers[] = {EFFECTIVE_FREQUENCY,   20.0f,   30.0f,   40.0f,   50.0f,   60.0f,   70.0f,   80.0f,   90.0f,
                                                100.0f,  200.0f,  300.0f,  400.0f,  500.0f,  600.0f,  700.0f,  800.0f,  900.0f,
                                               1000.0f, 2000.0f, 3000.0f, 4000.0f, 5000.0f, 6000.0f, 7000.0f, 8000.0f, 9000.0f,
                                              10000.0f,20000.0f};
        static BOOL shows[]     = {NO,YES,NO,NO,YES,NO,NO,NO,NO,
            YES,YES,NO,NO,YES,NO,NO,NO,NO,
            YES,YES,NO,NO,YES,NO,NO,NO,NO,
            YES,YES,NO,NO,YES,NO,NO,NO,NO,
            YES,YES};
        
        if (! isHideRuler) {
            CGContextBeginPath(context);
        }
        NSUInteger count = sizeof(rulers) / sizeof(Float32);
        Float32 inactiveArea = (log10(EFFECTIVE_FREQUENCY) / log10(halfSampleRate)) * width;

        for (NSUInteger i = 0; i < count; i++) {// ずれて居る。
            Float32 fract;
            Float32 hpos;

            if (rulers[i] > EFFECTIVE_FREQUENCY) {
                fract = log10(multiplier * rulers[i] - EFFECTIVE_FREQUENCY) / log10(halfSampleRate);
                hpos = ((fract * (width + inactiveArea)) - inactiveArea + org_x);
            } else {
                fract = 0.0;
                hpos = org_x;
            }
            if (shows[i]) {
                NSString *title = nil;
                if (multiplier * rulers[i] >= 1000.0f) {
                    title = [NSString stringWithFormat:@"%1.0fK", multiplier * rulers[i] / 1000.0f];
                } else {
                    title = [NSString stringWithFormat:@"%1.0f" , multiplier * rulers[i]];
                }
                Float32 hOffset = 7.0 * [title length] / 2.0; // 6.0
                CGPoint point = CGPointMake((hpos - hOffset) + offset.x, bot_y + 2.0);  // #9
                [title drawAtPoint:point withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color}];
            }
            if (! isHideRuler) {
                if (hpos + offset.x > FRAME_OFFSET) {// 論理クリッピング #10
                    CGContextMoveToPoint(context   , hpos + offset.x, org_y);   // #11
                    CGContextAddLineToPoint(context, hpos + offset.x, bot_y);   // #12
                }
            }
        }
        if (! isHideRuler) {
            CGContextStrokePath(context);
        }
    }
}

// 横ステップと縦罫線(RTA)
- (void) drawHorizontalStepsAndVerticalGuideRTA:(CGContextRef)context
                                           rect:(CGRect)rect
{
    NSUInteger halfSampleRate = [UserDefaults sharedManager].sampleRate / 2.0;   // デフォルトは 22050Hz
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    Float64 multiplier = halfSampleRate / 22050.0;
    CGRect frame = CGGraphRectMake(rect);
    BOOL isHideRuler = [[NSUserDefaults standardUserDefaults] boolForKey:kFFTHideRulerKey] &&
                       [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey] == kSpectrogram;
    Float32 org_x = frame.origin.x;
    Float32 org_y = frame.origin.y;
    Float32 width = frame.size.width;
    Float32 bot_y = org_y + frame.size.height;
    
    UIFont *font = nil;
    UIColor *color = nil;
    
    CGContextSetLineWidth(context, 0.2);
    // 横ステップ
    font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:11.0];
    color = [ColorUtil vfdOn];
    CGContextSetStrokeColorWithColor(context, [ColorUtil vfdOn].CGColor);
    CGContextSetFillColorWithColor(context, [ColorUtil vfdOn].CGColor);
    // リニア縦罫線
    if (! isHideRuler) {
        CGContextBeginPath(context);
    }
    // 22050Hz の按分が基本
    Float32 scaleMax = 20000.0;
    NSUInteger divisor = 9;
    NSUInteger numBars = 10;

    if (multiplier > 1.0) {
        scaleMax = multiplier * scaleMax;
        divisor  = multiplier * divisor;
    }
    static char *labels[] = {"32", "64", "128", "256", "512", "1K", "2K", "4K", "8K", "16K"};
    Float32 ruler_dh = (scaleMax / halfSampleRate * width) / divisor;
    for (NSUInteger i = 0; i < numBars; i++) {
        Float32 hpos = multiplier * ruler_dh * i + org_x;
        NSString *title = [NSString stringWithFormat:@"%s", labels[i]];
        Float32 hOffset = (7.0 * [title length] / 2.0); // 6.0
        CGPoint point = CGPointMake((hpos - hOffset) + (ruler_dh / 2), bot_y + 2.0);  // #5
        [title drawAtPoint:point withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color}];
        if (! isHideRuler && spectrumMode == 0) {
            if (i > 0 && hpos > FRAME_OFFSET) {// 論理クリッピング #6
                CGContextMoveToPoint(context   , hpos, org_y);   // #7
                CGContextAddLineToPoint(context, hpos, bot_y);   // #8
            }
        }
    }
    if (! isHideRuler) {
        CGContextStrokePath(context);
    }
}

- (void) drawRuler:(CGContextRef)context
              rect:(CGRect)rect
            scaleX:(CGFloat)scaleX
            scaleY:(CGFloat)scaleY
            offset:(CGPoint)offset
{
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    CGContextTranslateCTM(context, 0, 0);
    CGContextScaleCTM(context, 1, 1);
    
    switch (spectrumMode)
    {
        case kSpectrumFFT:
            [self drawFrame:context rect:rect scale:scaleX offset:offset];
            [self drawVerticalSteps:context rect:rect scaleY:scaleY offset:offset];
            [self drawHorizontalStepsAndVerticalGuide:context rect:rect scaleX:scaleX offset:offset];
            [self drawHorizontalGuide:context rect:rect scaleX:scaleX scaleY:scaleY offset:offset];
            break;
        case kSpectrogram:
            [self drawFrame:context rect:rect scale:1.0 offset:CGPointMake(0.0, 0.0)];
//            [self drawVerticalSteps:context rect:rect scaleY:1.0 offset:CGPointMake(0.0, 0.0)];
            [self drawHorizontalStepsAndVerticalGuide:context rect:rect scaleX:1.0 offset:CGPointMake(0.0, 0.0)];
            [self drawHorizontalGuide:context rect:rect scaleX:1.0 scaleY:1.0 offset:CGPointMake(0.0, 0.0)];
            break;
        default:
            [self drawFrame:context rect:rect scale:scaleX offset:offset];
            [self drawVerticalSteps:context rect:rect scaleY:1.0 offset:CGPointMake(0.0, 0.0)];
            [self drawHorizontalStepsAndVerticalGuideRTA:context rect:rect];
            [self drawHorizontalGuide:context rect:rect scaleX:1.0 scaleY:1.0 offset:CGPointMake(0.0, 0.0)];
            break;
    }
}

- (void) drawPoints:(CGContextRef)context
         dataBuffer:(Float32 *)dataBuffer
          fillColor:(UIColor *)fillColor
               rect:(CGRect)rect
             scaleX:(CGFloat)scaleX
             scaleY:(CGFloat)scaleY
             offset:(CGPoint)offset
           coloring:(BOOL)coloring
{
    @synchronized (self) {
        NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
        NSUInteger halfSampleRate = [UserDefaults sharedManager].sampleRate / 2.0;   // デフォルトは 22050Hz
        BOOL fill = YES;
        BOOL isLinear = (spectrumMode == kSpectrumFFT && [[NSUserDefaults standardUserDefaults] boolForKey:kFFTMathModeLinearKey]) ||
                        (spectrumMode == kSpectrogram && [[NSUserDefaults standardUserDefaults] boolForKey:kSpectrogramMathModeLinearKey]);
        Float32 width = rect.size.width * scaleX;
        Float32 height = rect.size.height * scaleY;
//        Float32 volumeDecades = FULL_DYNAMIC_RANGE_DECADE;
        // スペクトログラム用変数
        size_t lineHeight = 1 * scaleY;
        size_t bitsPerComponent = 8;
        size_t bytesPerRow = align16(4 * width);
//        size_t bytesPerRow = align32(4 * width);
        size_t bufferSize = bytesPerRow * height;
        CGContextRef imageContext = nil;
        CGColorSpaceRef colorSpace = nil;
        CGBitmapInfo bitmapInfo = (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrderDefault);
//        CGBitmapInfo bitmapInfo = (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);

        if (spectrumMode == kSpectrogram || (spectrumMode == kSpectrumFFT && coloring)) {
            CGContextSetLineWidth(context, 2.0);
        } else {
            CGContextSetLineWidth(context, 1.0);
        }
        if (spectrumMode == kSpectrumFFT)
        {
            if (coloring == NO)
            {// フィルのFFT
                CGContextSetStrokeColorWithColor(context, [UIColor redColor].CGColor);
                CGContextSetFillColorWithColor(context, fillColor.CGColor);
                CGContextBeginPath(context);
            }
        } else
        {// 現在のコンテキストにビットイメージを描画する。
            // 冒頭の 1行用のイメージを確保
            self.lineBuffer = malloc(bufferSize);
            colorSpace = CGColorSpaceCreateDeviceRGB();
            imageContext = CGBitmapContextCreate(self.lineBuffer, width, lineHeight, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo);

            for (NSUInteger row = 1; row < self.effectiveRows; row++) {
                CGImageRef imageRef = [self peekImage:row];
                
                if (imageRef) {
                    CGContextDrawImage(context, CGRectMake(0.0, row, width + offset.x, lineHeight + offset.y), imageRef);
                }
            }
        }
        Float32 inactiveArea = (log10(EFFECTIVE_FREQUENCY) / log10(halfSampleRate)) * width;

        // データのプロット
        for (NSUInteger i = 0; i < fftBufferSize; i++) {
            Float64 rawSPL = dataBuffer[i];
            
            if (dataBuffer == fftData && peakData[i] < rawSPL) {
                peakData[i] = rawSPL;
            }
            if (rawSPL == 0.0) {// rawSPL が 0 だと log10(rawSPL) が +INF になって障害が発生する。
                rawSPL = SILENT;
            }
            Float64 decibel = [self volumeToDecibel:rawSPL];

            if (spectrumMode == kSpectrogram)
            {
                // スペクトログラムだと -120dB 辺りでカットオフしないと視覚的に検知しにくい。
                // ノイズカットオフのレベルは 0.0〜0.5 を -80.0dB〜0.0dB にマップする。
                Float32 noiseLevel = [[NSUserDefaults standardUserDefaults] floatForKey:kSpectrogramNoiseLevelKey];
                if (decibel < (noiseLevel - 1.0) * FULL_DYNAMIC_RANGE_DECIBEL) {
                    decibel = -FULL_DYNAMIC_RANGE_DECIBEL; // 無音
                } else
                {// カットオフしなかったデータのみ増幅の対象にする。
                    Float32 gain = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
                    // ゲインは 0.0〜2.0 を 0.0dB〜40.0dB にマップする。
                    Float64 multiplier = pow(10, gain); // Pa/FS の 1/2 が有効な倍率だが見かけを2倍になどしない。
                    decibel += 20.0 * log10(multiplier);
                }
            } else
            {
                decibel = MAX(MIN(decibel, 0), -FULL_DYNAMIC_RANGE_DECIBEL);
            }
            Float64 ratio = (FULL_DYNAMIC_RANGE_DECIBEL + fmaxf(-FULL_DYNAMIC_RANGE_DECIBEL, decibel)) / FULL_DYNAMIC_RANGE_DECIBEL;
            Float64 volumeOffset = height * ratio;    // -160dB〜0dB (160dB log10(100000000)=8)
            Float64 fract;
            Float64 hpos;
            
            if (isLinear)
            {
                fract = (1.0 * i / ((Float32) fftBufferSize));
                hpos = (fract * width);
            } else {// ずれて居る。
                Float64 hz = halfSampleRate * (i / ((Float32) fftBufferSize));
                
                if (hz >= EFFECTIVE_FREQUENCY) {
                    fract = log10(hz - EFFECTIVE_FREQUENCY) / log10(halfSampleRate);
                    hpos = ((fract * (width + inactiveArea)) - inactiveArea);
                    hpos = fmax(0.0, hpos);
                } else {
                    fract = 0.0;
                    hpos = 0.0;
                }
            }

            if (spectrumMode == kSpectrumFFT)
            {
                if (coloring == NO)
                {// フィルのFFT
                    if (i == 0) {
                        CGContextMoveToPoint(context   , hpos + offset.x, height - volumeOffset + offset.y);    // #13
                    } else {
                        CGContextAddLineToPoint(context, hpos + offset.x, height - volumeOffset + offset.y);    // #14
                    }
                } else
                {// ポリラインのFFT
                    if (i == 0) {
                        CGContextMoveToPoint(context   , hpos + offset.x, height - volumeOffset + offset.y);    // #13
                    } else {
                        CGContextBeginPath(context);
                        CGFloat hue = volumeOffset / height;
                        CGFloat r, g, b;
                        // スペクトログラムでは 2乗を使うがこちらは素の値を使う！！
                        heat(hue, &r, &g, &b);
                        fillColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
                        CGContextSetStrokeColorWithColor(context, fillColor.CGColor);
                        
                        CGContextMoveToPoint(context   , hpos + offset.x, height + offset.y);    // #13
                        CGContextAddLineToPoint(context, hpos + offset.x, height - volumeOffset + offset.y);    // #14
                        CGContextStrokePath(context);
                    }
                }
            } else
            {// Spectrogram
                if (i == 0) {
                    CGContextBeginPath(imageContext);
                    CGContextMoveToPoint(imageContext   , hpos + 1 + offset.x, 0 + offset.y);    // #13
                } else {
                    CGFloat hue = volumeOffset / height;
                    CGFloat r, g, b;
                    // スペクトログラムでは 2乗を使う！！
                    heat(hue * hue, &r, &g, &b);
//                    heat(hue, &r, &g, &b);
                    fillColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
                    CGContextSetStrokeColorWithColor(imageContext, fillColor.CGColor);
                    
                    CGContextAddLineToPoint(imageContext, hpos + offset.x, 0 + offset.y);    // #14
                    CGContextStrokePath(imageContext);
                    
                    if (i < fftBufferSize - 1) {
                        CGContextBeginPath(imageContext);
                        CGContextMoveToPoint(imageContext   , hpos + offset.x, 0 + offset.y);    // #13
                    }
                }
            }
        }
        if (spectrumMode == kSpectrumFFT)
        {// FFT
            if (coloring == NO)
            {// フィルのFFT
                if (fill) {
                    // クランプする。
                    CGContextAddLineToPoint(context, width + offset.x, height + offset.y);  // #15
                    CGContextClosePath(context);
                    CGContextFillPath(context);
                } else {
                    CGContextStrokePath(context);
                }
            }
        } else
        {// Spectrogram
            size_t bitsPerPixel = 32;
            // 冒頭の 1行用のイメージを保存して破棄する。
            CGContextRelease(imageContext);
            imageContext = NULL;
            CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, self.lineBuffer, bufferSize, bufferFree);
            CGImageRef image = CGImageCreate(width, lineHeight, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpace, bitmapInfo, dataProvider, NULL, NO, kCGRenderingIntentDefault);
            CGDataProviderRelease(dataProvider);
            dataProvider = NULL;
            CGColorSpaceRelease(colorSpace);
            colorSpace = NULL;
            
            if (self.enqueueCandidate)
            {// 使用されなかったエンキュー候補。
                CGImageRelease(self.enqueueCandidate);
                self.enqueueCandidate = nil;
            }
            // ここで直接 enqueueImage するのはダメ。
            self.enqueueCandidate = image;
            
//            [self enqueueImage:image];
            // image の破棄は enqueueImage の中で適宜行われる！！
        }
    }
}

// RTA のセクションの代表値計算
- (void) calcRTA:(Float32 *)dataBuffer
{
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    NSUInteger barIndex = 0;
    Float64 halfSampleRate = [UserDefaults sharedManager].sampleRate / 2.0;
//    Float64 freqDelta = round(halfSampleRate / fftBufferSize);

    // インデクスの計算 fftBufferSize は 2048
    for (NSUInteger dataIndex = 0; dataIndex < fftBufferSize; dataIndex++) {
        if (dataBuffer == fftData && peakData[dataIndex] < dataBuffer[dataIndex]) {
            peakData[dataIndex] = dataBuffer[dataIndex];
        }
#if (PRECISE_RTA == OFF)
       Float64 hz = 0.0;
       Float64 log2hz = 0.0;
       switch (spectrumMode) {
            case kSpectrumRTA:// Full Octave RTA
                hz = dataIndex >> 1;
                log2hz = log2(hz);
                barIndex = round(fmax(log2hz, 0.0));
                [self processBar:dataBuffer[dataIndex] barIndex:barIndex];
                break;
            case kSpectrumRTA1_3:// 1/3 Octave RTA
                for (NSUInteger i = 0; i < 3; i++) {
                    hz = (((Float64) dataIndex) / 2.0) + (((Float64) i) / 3.0);
                    log2hz = log2(hz);
                    barIndex = 3.0 * fmax(log2hz, 0.0);
                    [self processBar:dataBuffer[dataIndex] barIndex:barIndex];
                }
                break;
            case kSpectrumRTA1_6:// 1/6 Octave RTA
                for (NSUInteger i = 0; i < 6; i++) {
                    hz = (((Float64) dataIndex) / 2.0) + (((Float64) i) / 6.0);
                    log2hz = log2(hz);
                    barIndex = 6.0 * fmax(log2hz, 0.0);
                    [self processBar:dataBuffer[dataIndex] barIndex:barIndex];
                }
                break;
           case kSpectrumRTA1_12:// 1/12 Octave RTA
               for (NSUInteger i = 0; i < 12; i++) {
                   hz = (((Float64) dataIndex) / 2.0) + (((Float64) i) / 12.0);
                   log2hz = log2(hz);
                   barIndex = 12.0 * fmax(log2hz, 0.0);
                   [self processBar:dataBuffer[dataIndex] barIndex:barIndex];
               }
               break;
        }
#else
        switch (spectrumMode) {
            case kSpectrumRTA:// Full Octave RTA
#if (RTA_LOOKUP == OFF)
                barIndex = [self frequency2LogIndex:freqDelta * dataIndex];
#else
                barIndex = rta1Index[dataIndex];
#endif
                [self processBar:dataBuffer[dataIndex] barIndex:barIndex];
                break;
            case kSpectrumRTA1_3:// 1/3 Octave RTA
                for (NSUInteger div = 0; div < 3; div++) {
#if (RTA_LOOKUP == OFF)
                    barIndex = [self frequency2LogIndex:freqDelta * (dataIndex + ((Float64) div) / 3.0)];
#else
                    barIndex = rta1_3Index[3 * dataIndex + div];
#endif
                    [self processBar:dataBuffer[dataIndex] barIndex:barIndex];
                }
                break;
            case kSpectrumRTA1_6:// 1/6 Octave RTA
                for (NSUInteger div = 0; div < 6; div++) {
#if (RTA_LOOKUP == OFF)
                    barIndex = [self frequency2LogIndex:freqDelta * (dataIndex + ((Float64) div) / 6.0)];
#else
                    barIndex = rta1_6Index[6 * dataIndex + div];
#endif
                    [self processBar:dataBuffer[dataIndex] barIndex:barIndex];
                }
                break;
            case kSpectrumRTA1_12:// 1/12 Octave RTA
                for (NSUInteger div = 0; div < 12; div++) {
#if (RTA_LOOKUP == OFF)
                    barIndex = [self frequency2LogIndex:freqDelta * (dataIndex + ((Float64) div) / 12.0)];
#else
                    barIndex = rta1_12Index[12 * dataIndex + div];
#endif
                    [self processBar:dataBuffer[dataIndex] barIndex:barIndex];
                }
                break;
        }
#endif
    }
}

- (void) clearAverageCount {
    for (NSUInteger i = 0; i < sizeof(gRTA) / sizeof(RTA); i++) {
        gRTA[i].count = 1;
    }
}

- (Float64) processBar:(Float64) rawSPL
//               divisor:(NSUInteger)divisor
              barIndex:(NSUInteger)barIndex
{
    NSUInteger averageMode = [[NSUserDefaults standardUserDefaults] integerForKey:kRTAAverageModeKey];
    // 音圧の処理
    if (rawSPL == 0.0) {// rawSPL が 0 だと log10(rawSPL) が +INF になって障害が発生する。
        rawSPL = SILENT;
    }
    Float64 decibel = [self volumeToDecibel:rawSPL];
    Float64 ratio = (FULL_DYNAMIC_RANGE_DECIBEL + fmaxf(-FULL_DYNAMIC_RANGE_DECIBEL, decibel)) / FULL_DYNAMIC_RANGE_DECIBEL;

    if (averageMode)
    {// 平均化する。
        gRTA[barIndex].curRatio = ratio;
        if (gRTA[barIndex].count == 0) {
            gRTA[barIndex].avgRatio = ratio;
            gRTA[barIndex].peakRatio = ratio;
            gRTA[barIndex].peakValue = rawSPL;
        } else {// 平均化処理（主処理）
            Float64 sumRatio = gRTA[barIndex].avgRatio * gRTA[barIndex].count + ratio;
            gRTA[barIndex].avgRatio = sumRatio / (gRTA[barIndex].count + 1);
        }
        if (ratio > gRTA[barIndex].peakRatio) {
            gRTA[barIndex].peakRatio = ratio;
            gRTA[barIndex].peakValue = rawSPL;
        }
        gRTA[barIndex].count++;
    } else
    {// 平均化しない。
        if (ratio > gRTA[barIndex].peakRatio) {
            gRTA[barIndex].peakRatio = ratio;
            gRTA[barIndex].peakValue = rawSPL;
        }
    }
    return ratio;
}

- (void) drawMarker:(CGContextRef)context
               size:(CGSize)size
       flipVertical:(BOOL)flipVertical
             scaleX:(CGFloat)scaleX
             scaleY:(CGFloat)scaleY
             offset:(CGPoint)offset
{
    NSUInteger halfSampleRate = [UserDefaults sharedManager].sampleRate / 2.0;   // デフォルトは 22050Hz
    Float32 width = size.width * scaleX;
    Float32 height = size.height * scaleY;
    CGPoint maxPos;
    Float64 rawSPL = fftData[_maxIndex];

    if (rawSPL == 0.0) {// rawSPL が 0 だと log10(rawSPL) が +INF になって障害が発生する。
        rawSPL = SILENT;
    }
    // 対数の値は dB(20log()) の 1/20
    Float64 decibel = [self volumeToDecibel:rawSPL];
    // ゲインは -0.125〜0.125 を -20.0dB〜20.0dB にマップする。
//    Float32 gain = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
    Float64 ratio = (FULL_DYNAMIC_RANGE_DECIBEL + fmaxf(-FULL_DYNAMIC_RANGE_DECIBEL, decibel)) / FULL_DYNAMIC_RANGE_DECIBEL;
    Float64 volumeOffset = height * ratio;    // -160dB〜0dB (160dB log10(100000000)=8)
    
    Float32 inactiveArea = (log10(EFFECTIVE_FREQUENCY) / log10(halfSampleRate)) * width;
    Float64 fract;
    Float64 hpos;
    BOOL isLinear = [[NSUserDefaults standardUserDefaults] boolForKey:kFFTMathModeLinearKey];
    
    if (isLinear)
    {
        fract = (1.0 * _maxIndex / ((Float32) fftBufferSize));
        hpos = (fract * width);
    } else {// ずれて居る。
        Float64 hz = halfSampleRate * (_maxIndex / ((Float32) fftBufferSize));
        
        if (hz >= EFFECTIVE_FREQUENCY) {
            fract = log10(hz - EFFECTIVE_FREQUENCY) / log10(halfSampleRate);
            hpos = ((fract * (width + inactiveArea)) - inactiveArea);
            hpos = fmax(0.0, hpos);
        } else {
            fract = 0.0;
            hpos = 0.0;
        }
    }
    maxPos.x = hpos;
    maxPos.y = height - volumeOffset;
    
    // マーカーの表示（マーカー）
    CGContextBeginPath(context);
    CGContextSetStrokeColorWithColor(context, [UIColor yellowColor].CGColor);
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kFFTHideRulerKey] &&
        [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey] == kSpectrogram)
    {
        CGContextSetLineWidth(context, 0.3);
        CGContextMoveToPoint(context, 0.0, maxPos.y);
        CGContextAddLineToPoint(context, width, maxPos.y);
        CGContextMoveToPoint(context, maxPos.x, 0.0);
        CGContextAddLineToPoint(context, maxPos.x, height);
    } else {// + カーソル
        CGContextSetLineWidth(context, 1.0);
        CGContextMoveToPoint(context, maxPos.x - 10.0 + offset.x, maxPos.y + offset.y);     // #16
        CGContextAddLineToPoint(context, maxPos.x + 10.0 + offset.x, maxPos.y + offset.y);  // #17
        CGContextMoveToPoint(context, maxPos.x + offset.x, maxPos.y - 10.0 + offset.y);     // #18
        CGContextAddLineToPoint(context, maxPos.x + offset.x, maxPos.y + 10.0 + offset.y);  // #19
    }
    CGContextStrokePath(context);
    
    // マーカーの表示（情報）
    // drawAtPoint:withAttributes: が上下反転しているのを補正する。
    if (flipVertical) {
        // アフィン変換の座標系を補正する。
        CGContextTranslateCTM(context, 0, size.height);
        CGContextScaleCTM(context, scaleX, -scaleY);
    }
    UIFont *font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:11.0];
    UIColor *color = [ColorUtil vfdOn];
    CGPoint point;
    
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    NSString *hz = [NSString stringWithFormat:@"%.0fHz", _maxHZ];
    CGFloat hzWidth = [self widthOfString:hz withFont:font];
    NSString *dbLabel = [NSString stringWithFormat:@"%.2fdB", 20.0 * (log10(AUDIBLE_MULTIPLE_F * _maxHZValue))];
    CGFloat dbWidth = [self widthOfString:dbLabel withFont:font];
    BOOL limited =  ((maxPos.x + hzWidth + 4.0 + offset.x > width) || (maxPos.x + dbWidth + 4.0 + offset.x > width));

    if (limited) {
        point = CGPointMake(maxPos.x - (hzWidth + 4.0) + offset.x, maxPos.y - 28.0 + offset.y); // #20
    } else {
        point = CGPointMake(maxPos.x + 4.0 + offset.x, maxPos.y - 28.0 + offset.y); // #20
    }
    [hz drawAtPoint:point withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color}];

    if (limited) {
        point = CGPointMake(maxPos.x - (dbWidth + 4.0) + offset.x, maxPos.y - 15.0 + offset.y); // #21
    } else {
        point = CGPointMake(maxPos.x + 4.0 + offset.x, maxPos.y - 15.0 + offset.y); // #21
    }
    [dbLabel drawAtPoint:point withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color}];
    
    if (flipVertical) {
        // アフィン変換の座標系を初期化する。
        CGContextTranslateCTM(context, 0, 0);
        CGContextScaleCTM(context, scaleX, scaleY);
    }
}

- (CGFloat)widthOfString:(NSString *)string withFont:(UIFont *)font {
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
    return [[[NSAttributedString alloc] initWithString:string attributes:attributes] size].width;
}

//#define SMOOTHING   0

#pragma mark - RTA

- (NSInteger) point2LogIndex:(CGPoint)point {
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    Float64 index = -1.0;
    NSUInteger size = 10.0;
    
    switch (spectrumMode) {
        case kSpectrumRTA1_3:
            size *= 3.0;
            break;
        case kSpectrumRTA1_6:
            size *= 6.0;
            break;
        case kSpectrumRTA1_12:
            size *= 12.0;
            break;
    }
    if (point.x < gRTA[0].bar.origin.x) {
        index = -1.0;
    } else if (point.x > gRTA[size - 1].bar.origin.x + gRTA[size - 1].bar.size.width) {
        index = INFINITY;
    } else {
        for (NSUInteger i = 0; i < size; i++) {
            if (i < size - 1) {
                if (point.x > gRTA[i].bar.origin.x && point.x < gRTA[i + 1].bar.origin.x) {
                    index = i;
                    break;
                }
            } else {
                index = size - 1;
                break;
            }
        }
    }
//    DEBUG_LOG(@"%s index:%d", __func__, (int) round(index));
    return round(index);
}

- (NSInteger) frequency2LogIndex:(Float64)hz {
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    Float64 index = 0;
    Float64 log2hz = log2(MAX(hz, 25.0));   // 25Hz 未満は扱わない！

    switch (spectrumMode) {
        case kSpectrumRTA:// log2(hz) - 5.0
            index = log2hz - 5.0;
            break;
        case kSpectrumRTA1_3:// round(3.0*(log2(hz) - 4.0)) - 2.0
            index = round(3.0*(log2hz - 4.0)) - 2.0;
            break;
        case kSpectrumRTA1_6:// round(6.0*(log2(hz) - 4.0)) - 4.0
            index = round(6.0*(log2hz - 4.0)) - 4.0;
            break;
        case kSpectrumRTA1_12:// round(12.0*(log2(hz) - 4.0)) - 6.0
            index = round(12.0*(log2hz - 4.0)) - 8.0;
            break;
    }
    return index;
}

- (Float64) logIndex2Frequency:(NSInteger)index {
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    Float64 hz = 0.0;
    
    if (index < 0 || index >= 120) {
        hz = 0.0;
    } else {
        Float64 m = index;
        switch (spectrumMode) {
            case kSpectrumRTA:// 32*2^i = 2^(i+5)
                hz = pow(2.0, m + 5.0);
                break;
            case kSpectrumRTA1_3:// 16*2^((i+2)/3) = 2^((i+2)/3+4)
                hz = pow(2.0, (m + 2.0) / 3.0 + 4.0);
                break;
            case kSpectrumRTA1_6:// 16*2^((i+4)/6) = 2^((i+4)/6+4)
                hz = pow(2.0, (m + 4.0) / 6.0 + 4.0);
                break;
            case kSpectrumRTA1_12:// 16*2^((i+4)/6) = 2^((i+4)/6+4)
                hz = 16.0 * pow(2.0, m / 12.0 + 2.0 / 3.0);
                break;
        }
    }
    DEBUG_LOG(@"%s index:%d Hz:%g", __func__, (int) index, round(hz));
    return hz;
}

- (void) drawPointsRTA:(CGContextRef)context
            dataBuffer:(Float32 *)dataBuffer
             fillColor:(UIColor *)fillColor
                  rect:(CGRect)rect
              coloring:(BOOL)coloring
              useCache:(BOOL)useCache
{
    NSUInteger halfSampleRate = [UserDefaults sharedManager].sampleRate / 2.0;   // デフォルトは 22050Hz
    Float32 width = rect.size.width;
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];

    // データのプロット
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, [UIColor redColor].CGColor);
    CGContextSetFillColorWithColor(context, fillColor.CGColor);

    CGRect frame = CGGraphRectMake(rect);
    Float64 multiplier = halfSampleRate / 22050.0;

    Float64 divisor = 0.0;
    NSUInteger numBars = 0;
    CGFloat hOffset = 3.0;

    switch (spectrumMode) {
        case kSpectrumRTA:// Full Octave RTA
            divisor = 9.0;
            numBars = 10;
            hOffset = 3.0;
            break;
        case kSpectrumRTA1_3:// 1/3 Octave RTA
            divisor = 9.0 * 3.0;
            numBars = 30;
            hOffset = 2.0;
            break;
        case kSpectrumRTA1_6:// 1/6 Octave RTA
            divisor = 9.0 * 6.0;
            numBars = 60;
            hOffset = 1.0;
            break;
        case kSpectrumRTA1_12:// 1/12 Octave RTA
            divisor = 9.0 * 12.0;
            numBars = 120;
            hOffset = 1.0;
            break;
    }
    Float32 scaleMax = 20000.0;
    if (multiplier > 1.0) {
        scaleMax = multiplier * scaleMax;
        divisor  = multiplier * divisor;
    }
    Float32 ruler_dh = (scaleMax / halfSampleRate * (width - hOffset)) / divisor;
    for (NSUInteger i = 0; i < numBars; i++) {
        Float32 hpos = multiplier * ruler_dh * i;

        gRTA[i].bar = CGRectMake(hpos + hOffset, 2.0, ruler_dh - 2.0, frame.origin.y + frame.size.height - 4.0);
    }
    NSUInteger averageMode = [[NSUserDefaults standardUserDefaults] integerForKey:kRTAAverageModeKey];
    // レクタングルの作成
    if (averageMode == 0) {
        for (NSUInteger i = 0; i < numBars; i++) {
            gRTA[i].curRatio = 0.0;
            gRTA[i].peakRatio = 0.0;
            gRTA[i].peakValue = PIANISSIMO;
        }
    }
    if (useCache == NO) {
        [self calcRTA:dataBuffer];
        for (NSUInteger i = 0; i < numBars; i++) {
            CGFloat height;
            
            switch (averageMode) {
                case 1:// 平均化した結果を使うがピークを優先する。
                case 2:// 平均化した結果を使うがピークを優先する。
                    if (gRTA[i].curRatio > gRTA[i].avgRatio) {
                        height = gRTA[i].bar.size.height * gRTA[i].curRatio;
                    } else {
                        height = gRTA[i].bar.size.height * gRTA[i].avgRatio;
                    }
                    break;
                case 3:// 平均化した結果のみ使う
                    height = gRTA[i].bar.size.height * gRTA[i].avgRatio;
                    break;
                default:// 平均化しない
                    height = gRTA[i].bar.size.height * gRTA[i].peakRatio;
                    break;
            }
            gRTA[i].bar.origin.y += gRTA[i].bar.size.height - height;
            gRTA[i].bar.size.height = height;
        }
#if (RTA_LOOKUP == ON)
        for (NSUInteger i = 0; i < numBars; i++) {// RTA のピークの Ratio を保存する。
            if (peakRatio[i] < gRTA[i].peakRatio) {
                peakRatio[i] = gRTA[i].peakRatio;
            }
        }
#endif
    } else {
#if (RTA_LOOKUP == ON)
        for (NSUInteger i = 0; i < numBars; i++) {
            CGFloat height = gRTA[i].bar.size.height * peakRatio[i];
            gRTA[i].bar.origin.y += gRTA[i].bar.size.height - height;
            gRTA[i].bar.size.height = height;
        }
#endif
    }

    if ([[NSUserDefaults standardUserDefaults] integerForKey:kRTAModeLineKey] == 0)
    {
        // バー表示
        for (NSUInteger i = 0; i < numBars; i++) {
            if (coloring == YES) {
                NSUInteger height = rect.size.height;
                CGFloat hue = gRTA[i].bar.size.height / height;
                CGFloat r, g, b;

                heat(hue, &r, &g, &b);
                fillColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
                CGContextSetFillColorWithColor(context, fillColor.CGColor);
                CGContextFillRect(context, gRTA[i].bar);
            } else {
                CGContextFillRect(context, gRTA[i].bar);
            }
        }
    } else
    {// ライン表示
        BOOL fill = YES;

        CGContextBeginPath(context);

        Float32 width = rect.size.width;
        Float32 height = rect.size.height;

        for (NSUInteger i = 0; i < numBars - 1; i++) {
            if (i == 0) {
                CGContextMoveToPoint(context   , gRTA[i].bar.origin.x - 2.0, gRTA[i].bar.origin.y);    // #13
            } else {
                NSUInteger ss = i;
#if SMOOTHING
                CGFloat cp1x = bars[ss].origin.x + bars[ss].size.width / 2.0;
                CGFloat cp1y = bars[ss].origin.y;
                CGFloat cp2x = bars[ss].origin.x + bars[ss].size.width;
                CGFloat cp2y = (bars[ss].origin.y + bars[ee].origin.y) / 2.0;
                // 中点（水平）
                CGContextAddCurveToPoint(context, cp1x, cp1y, cp2x, cp2y, bars[ss].origin.x + bars[ss].size.width / 2.0, bars[ss].origin.y);
#else
//                NSUInteger ee = i + 1;
                // 中点（水平）
                CGContextAddLineToPoint(context, gRTA[ss].bar.origin.x + gRTA[ss].bar.size.width / 2.0, gRTA[ss].bar.origin.y);    // #14
#endif
            }
        }
        if (fill) {
            NSUInteger ee = numBars - 1;
#if SMOOTHING
            CGFloat cp1x = bars[ss].origin.x + bars[ss].size.width / 2.0;
            CGFloat cp1y = bars[ss].origin.y;
            CGFloat cp2x = bars[ss].origin.x + bars[ss].size.width;
            CGFloat cp2y = (bars[ss].origin.y + bars[ee].origin.y) / 2.0;
            // 右端（水平）
            CGContextAddCurveToPoint(context, cp1x, cp1y, cp2x, cp2y, bars[ee].origin.x + bars[ee].size.width, bars[ee].origin.y);
#else
//            NSUInteger ss = numBars - 2;
            // 右端（水平）
            CGContextAddLineToPoint(context, gRTA[ee].bar.origin.x + gRTA[ee].bar.size.width, gRTA[ee].bar.origin.y);  // #15
#endif
            // クランプする。
            CGContextAddLineToPoint(context, width, height);  // #15
            CGContextAddLineToPoint(context, gRTA[0].bar.origin.x - 2.0, height - 1.0);  // #15
            CGContextClosePath(context);
            CGContextFillPath(context);
        } else {
            CGContextStrokePath(context);
        }
    }
}

- (void) drawMarkerRTA:(CGContextRef)context
                  rect:(CGRect)rect
{
    if ([[NSUserDefaults standardUserDefaults] integerForKey:kRTAModeLineKey] == 0) {
        CGRect frame = CGGraphRectMake(rect);
        Float64 hz = [[NSUserDefaults standardUserDefaults] doubleForKey:kSelectedHzKey];
        static unsigned long tickCount = 0;

        if (hz > 0.0) {
            NSUInteger selectedRTAIndex = [self frequency2LogIndex:hz];
            // マーカー表示
            CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.5].CGColor);
            CGContextSetLineWidth(context, 1.0);
            // 縦
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, gRTA[selectedRTAIndex].bar.origin.x + gRTA[selectedRTAIndex].bar.size.width / 2.0, 0.0);
            CGContextAddLineToPoint(context, gRTA[selectedRTAIndex].bar.origin.x + gRTA[selectedRTAIndex].bar.size.width / 2.0, frame.origin.y + frame.size.height);
            // 横
            CGContextMoveToPoint(context,
                                 0.0,
                                 (frame.origin.y + frame.size.height) - (gRTA[selectedRTAIndex].bar.size.height + 2.0));
            CGContextAddLineToPoint(context,
                                    frame.origin.x + frame.size.width,
                                    (frame.origin.y + frame.size.height) - (gRTA[selectedRTAIndex].bar.size.height + 2.0));
            CGContextStrokePath(context);
            
            if ((tickCount++ % 3) == 0) {
                // Start Mod on May 3rd, 2021 by T.M.
                Float64 decibel = [self volumeToDecibel:gRTA[selectedRTAIndex].peakValue] + 120.0;
                _rtaHzText.text = [NSString stringWithFormat:@"%g", round(hz)];
                _rtaDecibelText.text = [NSString stringWithFormat:@"%.1f", decibel];
                // End Mod on May 3rd, 2021 by T.M.
            }
            if (_rtaHzText.hidden == YES) {
                _rtaHzText.hidden = NO;
            }
            if (_rtaHzLabel.hidden == YES) {
                _rtaHzLabel.hidden = NO;
            }
            if (_rtaDecibelText.hidden == YES) {
                _rtaDecibelText.hidden = NO;
            }
            if (_rtaDecibelLabel.hidden == YES) {
                _rtaDecibelLabel.hidden = NO;
            }
        } else {
            if (_rtaHzText.hidden == NO) {
                _rtaHzText.hidden = YES;
            }
            if (_rtaHzLabel.hidden == NO) {
                _rtaHzLabel.hidden = YES;
            }
            if (_rtaDecibelText.hidden == NO) {
                _rtaDecibelText.hidden = YES;
            }
            if (_rtaDecibelLabel.hidden == NO) {
                _rtaDecibelLabel.hidden = YES;
            }
        }
    }
}
#pragma mark - Main

- (UIImage *) drawPoints:(CGContextRef)context
                    rect:(CGRect)rect
                  scaleX:(CGFloat)scaleX
                  scaleY:(CGFloat)scaleY
                  offset:(CGPoint)offset
           generateImage:(BOOL)generateImage
{
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    BOOL coloring = NO;

    switch (spectrumMode) {
        case kSpectrumFFT:
            coloring = [[NSUserDefaults standardUserDefaults] boolForKey:kFFTColoringKey];
            break;
        case kSpectrumRTA:
        case kSpectrumRTA1_3:
        case kSpectrumRTA1_6:
        case kSpectrumRTA1_12:
            coloring = [[NSUserDefaults standardUserDefaults] boolForKey:kRTAColoringKey];
            break;
    }

    if (generateImage) {
        UIGraphicsBeginImageContext(rect.size);
    }
    UIColor *mainFillColor = [[NSUserDefaults standardUserDefaults] boolForKey:kSpectrumPeakHoldKey] ?
                                    [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.5] : // ピークがあるので濃くする。
                                    [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.4];  // 標準のスクリーン・トーン

    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSpectrumPeakHoldKey]) {
        UIColor *peakColor = nil;
        if (coloring) {
            // グレー
            peakColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.15];
        } else {
            // シアン
            peakColor = [UIColor colorWithRed:0.0 green:1.0 blue:1.0 alpha:0.15];
        }
        if (spectrumMode == kSpectrogram)
        {
            // スペクトログラムではピークを描画しない。
        } else if (spectrumMode == kSpectrumFFT)
        {// FFT
            [self drawPoints:context
                  dataBuffer:peakData
                   fillColor:peakColor
                        rect:rect
                      scaleX:[_pinchRecognizer getScaleX]
                      scaleY:[_pinchRecognizer getScaleY]
                      offset:_panOffset
                    coloring:NO];
        } else
        {// RTA
            [self drawPointsRTA:context
                     dataBuffer:peakData
                      fillColor:peakColor
                           rect:rect
                       coloring:NO
                       useCache:YES];
        }
    }
    if (spectrumMode == kSpectrogram)
    {// FFT/Spectrogram のデータ描画
        [self drawPoints:context
              dataBuffer:fftData
               fillColor:mainFillColor
                    rect:rect
                  scaleX:1.0
                  scaleY:1.0
                  offset:CGPointMake(0.0, 0.0)
                coloring:coloring];
    } else if (spectrumMode == kSpectrumFFT)
    {// FFT/Spectrogram のデータ描画
        [self drawPoints:context
              dataBuffer:fftData
               fillColor:mainFillColor
                    rect:rect
                  scaleX:[_pinchRecognizer getScaleX]
                  scaleY:[_pinchRecognizer getScaleY]
                  offset:_panOffset
                coloring:coloring];
    } else
    {// RTA のデータ描画
        [self drawPointsRTA:context
                 dataBuffer:fftData
                  fillColor:mainFillColor
                       rect:rect
                   coloring:coloring
                   useCache:NO];
#if (RTA_MARKER == ON)
        [self drawMarkerRTA:context rect:rect];
#endif
    }
    if (generateImage) {
        UIImage *pdfImage = UIGraphicsGetImageFromCurrentImageContext();//autoreleased
        UIGraphicsEndImageContext();
        return pdfImage;
    } else {
        return nil;
    }
}

#pragma mark - View lifecycle

- (void) maintainScrollableArea:(CGRect)frame {
    // 仮想ビューのサイズ計算（スクロール可能な範囲を規定する）
    _scrollLimit.x = (frame.size.width  * [_pinchRecognizer getScaleX]) - (frame.size.width);
    _scrollLimit.y = (frame.size.height * [_pinchRecognizer getScaleY]) - (frame.size.height);
}

- (void) drawRect:(CGRect)rect {

    NSUInteger freq = nearbyintf(_maxHZ);
    NSUInteger f = freq;
    static unsigned long tickCount = 0;
    
    if ((tickCount++ % 2) == 0)
    {
        if (freq >= 10000) {
            _f4.status = DCELL_LEVEL_ON;
            _f4.tag = f / 10000;
        } else {
            _f4.status = DCELL_SHUTDOWN;
        }
        f %= 10000;
        if (freq >= 1000) {
            _f3.status = DCELL_LEVEL_ON;
            _f3.tag = f / 1000;
        } else {
            _f3.status = DCELL_SHUTDOWN;
        }
        f %= 1000;
        if (freq >= 100) {
            _f2.status = DCELL_LEVEL_ON;
            _f2.tag = f / 100;
        } else {
            _f2.status = DCELL_SHUTDOWN;
        }
        f %= 100;
        if (freq >= 10) {
            _f1.status = DCELL_LEVEL_ON;
            _f1.tag = f / 10;
        } else {
            _f1.status = DCELL_SHUTDOWN;
        }
        f %= 10;
        _f0.status = DCELL_LEVEL_ON;  // 常時ON
        _f0.tag = f;
    }
    // コンテントの描画
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    CGRect frame = CGGraphRectMake(rect);
    // アフィン変換の座標系を初期化する。
    CGContextTranslateCTM(context, 0, 0);
    CGContextScaleCTM(context, 1, 1);
    
    // 仮想ビューのサイズ計算（スクロール可能な範囲を規定する）
    //    [self maintainScrollableArea:frame];
    
    [self drawRuler:context
               rect:rect
             scaleX:[_pinchRecognizer getScaleX]
             scaleY:[_pinchRecognizer getScaleY]
             offset:_panOffset];
#if 1
    // クリッピングを frame に制限する。
    CGContextClipToRect(context, frame);
    CGContextTranslateCTM(context, FRAME_OFFSET, FRAME_OFFSET);
    (void) [self drawPoints:context
                       rect:frame
                     scaleX:[_pinchRecognizer getScaleX]
                     scaleY:[_pinchRecognizer getScaleY]
                     offset:_panOffset
              generateImage:NO];
    // クリッピングを最大にする。
    CGContextClipToRect(context, rect);
    CGContextTranslateCTM(context, 0.0, 0.0);
#else
    // クリッピングを frame に制限する。
    CGContextClipToRect(context, frame);
    CGContextTranslateCTM(context, FRAME_OFFSET, FRAME_OFFSET);
    UIImage *image = [self drawPoints:context
                                 rect:frame
                               scaleX:[_pinchRecognizer getScaleX]
                               scaleY:[_pinchRecognizer getScaleY]
                               offset:_panOffset
                        generateImage:YES];
    
    if (image) {
        CGContextDrawImage(context, frame, image.CGImage);
    }
    // クリッピングを最大にする。
    CGContextClipToRect(context, rect);
    CGContextTranslateCTM(context, 0.0, 0.0);
#endif
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    
    if (spectrumMode == kSpectrumFFT)
    {// FFT
        if ([UserDefaults sharedManager].microphoneEnabled)
        {
            [self drawMarker:context
                        size:frame.size
                flipVertical:NO
                      scaleX:[_pinchRecognizer getScaleX]
                      scaleY:[_pinchRecognizer getScaleY]
                      offset:_panOffset];
        }
    }
    [self drawScrollIndicator:context rect:rect];
    CGContextRestoreGState(context);
}

- (IBAction) clearBuffer:(id)sender {
    for (NSUInteger i = 0; i < fftBufferSize; i++) {
        fftData[i] = PIANISSIMO;
    }
}

- (void) clearPeaks {
    for (NSUInteger i = 0; i < fftBufferSize; i++) {
        peakData[i] = PIANISSIMO;
        peakRatio[i] = 0.0;
    }
}

- (void) panFrom:(CGPoint)from
              to:(CGPoint)to
{
    _panOffset.x += (to.x - from.x);
    _panOffset.y += (to.y - from.y);
    [self maintainPan];
}

- (void) centering:(CGPoint)location
{
    // ピンチ絡みは bounds！！
    CGRect bounds = CGGraphRectMake(self.bounds);
    [self panFrom:location
               to:CGPointMake(bounds.origin.x + bounds.size.width / 2.0,
                              bounds.origin.y + bounds.size.height / 2.0)];
}

#pragma mark - コントロールのメンテナンス

#if (SPECTROGRAM_COMP == ON)
- (void) pauseReceiveData:(BOOL)yesNo {
    // ポーズだと間に合わないケースがあるのでフラグを追加した。
    self.busy = yesNo;
    [_delegate setFreezeMeasurement:yesNo];
}
#endif

- (void) maintainWindowFunctionControl {
    if ([Environment isPortrait] &&
        ([Environment isIPad] == NO && [Environment isMIPad] == NO && [Environment isLIPad] == NO))
    {
        NSString *windowFunctionName = nil;
        NSUInteger windowFunction = [[NSUserDefaults standardUserDefaults] integerForKey:kWindowFunctionKey];
        
        _windowFunctionSegment.hidden = YES;
        _windowFunctionButton.hidden = NO;
        switch (windowFunction) {
            case 0:
                windowFunctionName = @"Rectangular";
                break;
            case 1:
                windowFunctionName = @"Hamming";
                break;
            case 2:
                windowFunctionName = @"Hanning";
                break;
            case 3:
                windowFunctionName = @"Blackman";
                break;
        }
        [_windowFunctionButton setTitle:NSLocalizedString(windowFunctionName, @"") forState:UIControlStateNormal];
        
    } else {
        _windowFunctionSegment.hidden = NO;
        _windowFunctionButton.hidden = YES;
    }
}

- (void) maintainControl:(NSUInteger)spectrumMode {

#if (CSV_OUT == ON)
//    [self stopAction:nil];
#endif
    BOOL isLinear = (spectrumMode == kSpectrumFFT && [[NSUserDefaults standardUserDefaults] boolForKey:kFFTMathModeLinearKey]) ||
                    (spectrumMode == kSpectrogram && [[NSUserDefaults standardUserDefaults] boolForKey:kSpectrogramMathModeLinearKey]);
    BOOL isRTA_markerShown = [[NSUserDefaults standardUserDefaults] doubleForKey:kSelectedHzKey] != 0.0;

    if (spectrumMode != kSpectrogram) {
        [_peakHold setTitle:NSLocalizedString(@"Peak Hold", @"") forState:UIControlStateNormal];
//        [_peakHold setTitle:NSLocalizedString(@"Peak Hold ON", @"") forState:UIControlStateSelected];
//        [_peakHold setSelected:[[NSUserDefaults standardUserDefaults] boolForKey:kSpectrumPeakHoldKey]];
    } else {
        [_peakHold setTitle:NSLocalizedString(@"Grid", @"") forState:UIControlStateNormal];
//        [_peakHold setTitle:NSLocalizedString(@"Show Grid", @"") forState:UIControlStateSelected];
//        [_peakHold setSelected:! [[NSUserDefaults standardUserDefaults] boolForKey:kFFTHideRulerKey]];
    }
    
    _gainSlider.minimumValue = 0.0; // 10^(0)=0dB 0〜40dB に変更した。May 25, 2021
    _gainSlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
    _gainSlider.maximumValue = 2.0; // 10^(+2)=+40dB 0〜40dB に変更した。May 25, 2021

//    UITraitCollection *trait = self.traitCollection;
//
//    if ([trait userInterfaceStyle] == UIUserInterfaceStyleDark) {
//        if (@available(iOS 13.0, *)) {
//            [_agcSwitch setBackgroundColor:[UIColor systemBackgroundColor]];
//        } else {
//            [_agcSwitch setBackgroundColor:[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0]];
//        }
//    } else {
        [_agcSwitch setBackgroundColor:[UIColor whiteColor]];
//    }
    // 線形・対数のデフォルト値を反映する。
    switch (spectrumMode) {
        case kSpectrumFFT: // FFT
            _colorLabel.hidden = NO;
            [_colorLabel setText:NSLocalizedString(@"FFT Color", @"")];
            _colorSwitch.hidden = NO;
            [_agcSwitch setTitle:@"FFT" forState:UIControlStateNormal];
            [_logOrLinear setTitle:NSLocalizedString(@"Log", @"対数") forSegmentAtIndex:0];
            [_logOrLinear setTitle:NSLocalizedString(@"Linear", @"リニア") forSegmentAtIndex:1];
            [_logOrLinear setSelectedSegmentIndex:isLinear ? 1 : 0];
            // ゲイン
            _gainLabel.text = NSLocalizedString(@"Mic Gain", @"");
            _gainLabel.hidden = NO;
            _gainSlider.hidden = NO;
            _noiseReductionLabel.hidden = YES;
            _noiseReductionSlider.hidden = YES;
            _rtaHzText.hidden = YES;
            _rtaHzLabel.hidden = YES;
            _rtaDecibelText.hidden = YES;
            _rtaDecibelLabel.hidden = YES;
            break;
        case kSpectrumRTA: // Full Octave RTA
            _colorLabel.hidden = NO;
            [_colorLabel setText:NSLocalizedString(@"RTA Color", @"")];
            _colorSwitch.hidden = NO;
            [_agcSwitch setTitle:@"RTA" forState:UIControlStateNormal];
            [_logOrLinear setTitle:NSLocalizedString(@"Bar", @"バー") forSegmentAtIndex:0];
            [_logOrLinear setTitle:NSLocalizedString(@"Line", @"ライン") forSegmentAtIndex:1];
            [_logOrLinear setSelectedSegmentIndex:[[NSUserDefaults standardUserDefaults] boolForKey:kRTAModeLineKey] ? 1 : 0];
            // ゲイン
            _gainLabel.text = NSLocalizedString(@"Mic Gain", @"");
            _gainLabel.hidden = NO;
            _gainSlider.hidden = NO;
            _noiseReductionLabel.hidden = YES;
            _noiseReductionSlider.hidden = YES;
            _rtaHzText.hidden = ! isRTA_markerShown;
            _rtaHzLabel.hidden = ! isRTA_markerShown;
            _rtaDecibelText.hidden = ! isRTA_markerShown;
            _rtaDecibelLabel.hidden = ! isRTA_markerShown;
            break;
        case kSpectrumRTA1_3: // 1/3 Octave RTA
            _colorLabel.hidden = NO;
            [_colorLabel setText:NSLocalizedString(@"RTA Color", @"")];
            _colorSwitch.hidden = NO;
            [_agcSwitch setTitle:@"RTA 1/3" forState:UIControlStateNormal];
            [_logOrLinear setTitle:NSLocalizedString(@"Bar", @"バー") forSegmentAtIndex:0];
            [_logOrLinear setTitle:NSLocalizedString(@"Line", @"ライン") forSegmentAtIndex:1];
            [_logOrLinear setSelectedSegmentIndex:[[NSUserDefaults standardUserDefaults] boolForKey:kRTAModeLineKey] ? 1 : 0];
            // ゲイン
            _gainLabel.text = NSLocalizedString(@"Mic Gain", @"");
            _gainLabel.hidden = NO;
            _gainSlider.hidden = NO;
            _noiseReductionLabel.hidden = YES;
            _noiseReductionSlider.hidden = YES;
            _rtaHzText.hidden = ! isRTA_markerShown;
            _rtaHzLabel.hidden = ! isRTA_markerShown;
            _rtaDecibelText.hidden = ! isRTA_markerShown;
            _rtaDecibelLabel.hidden = ! isRTA_markerShown;
            break;
        case kSpectrumRTA1_6: // 1/6 Octave RTA
            _colorLabel.hidden = NO;
            [_colorLabel setText:NSLocalizedString(@"RTA Color", @"")];
            _colorSwitch.hidden = NO;
            [_agcSwitch setTitle:@"RTA 1/6" forState:UIControlStateNormal];
            [_logOrLinear setTitle:NSLocalizedString(@"Bar", @"バー") forSegmentAtIndex:0];
            [_logOrLinear setTitle:NSLocalizedString(@"Line", @"ライン") forSegmentAtIndex:1];
            [_logOrLinear setSelectedSegmentIndex:[[NSUserDefaults standardUserDefaults] boolForKey:kRTAModeLineKey] ? 1 : 0];
            // ゲイン
            _gainLabel.text = NSLocalizedString(@"Mic Gain", @"");
            _gainLabel.hidden = NO;
            _gainSlider.hidden = NO;
            _noiseReductionLabel.hidden = YES;
            _noiseReductionSlider.hidden = YES;
            _rtaHzText.hidden = ! isRTA_markerShown;
            _rtaHzLabel.hidden = ! isRTA_markerShown;
            _rtaDecibelText.hidden = ! isRTA_markerShown;
            _rtaDecibelLabel.hidden = ! isRTA_markerShown;
            break;
        case kSpectrumRTA1_12: // 1/12 Octave RTA
            _colorLabel.hidden = NO;
            [_colorLabel setText:NSLocalizedString(@"RTA Color", @"")];
            _colorSwitch.hidden = NO;
            [_agcSwitch setTitle:@"RTA 1/12" forState:UIControlStateNormal];
            [_logOrLinear setTitle:NSLocalizedString(@"Bar", @"バー") forSegmentAtIndex:0];
            [_logOrLinear setTitle:NSLocalizedString(@"Line", @"ライン") forSegmentAtIndex:1];
            [_logOrLinear setSelectedSegmentIndex:[[NSUserDefaults standardUserDefaults] boolForKey:kRTAModeLineKey] ? 1 : 0];
            // ゲイン
            _gainLabel.text = NSLocalizedString(@"Mic Gain", @"");
            _gainLabel.hidden = NO;
            _gainSlider.hidden = NO;
            _noiseReductionLabel.hidden = YES;
            _noiseReductionSlider.hidden = YES;
            _rtaHzText.hidden = ! isRTA_markerShown;
            _rtaHzLabel.hidden = ! isRTA_markerShown;
            _rtaDecibelText.hidden = ! isRTA_markerShown;
            _rtaDecibelLabel.hidden = ! isRTA_markerShown;
            break;
        case kSpectrogram: // Spectrogram
            _colorLabel.hidden = YES;
            _colorSwitch.hidden = YES;
            [_agcSwitch setTitle:NSLocalizedString(@"Spectrogram", @"") forState:UIControlStateNormal];
            [_logOrLinear setTitle:NSLocalizedString(@"Log", @"対数") forSegmentAtIndex:0];
            [_logOrLinear setTitle:NSLocalizedString(@"Linear", @"リニア") forSegmentAtIndex:1];
            [_logOrLinear setSelectedSegmentIndex:isLinear ? 1 : 0];
            // ゲイン
            _gainLabel.text = NSLocalizedString(@"Mic Gain", @"");
            _gainLabel.hidden = NO;
            _gainSlider.hidden = NO;
            _noiseReductionLabel.hidden = NO;
            _noiseReductionSlider.hidden = NO;
            _noiseReductionSlider.minimumValue = 0.0;
            _noiseReductionSlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:kSpectrogramNoiseLevelKey];
            _noiseReductionSlider.maximumValue = 0.5;
            _rtaHzText.hidden = YES;
            _rtaHzLabel.hidden = YES;
            _rtaDecibelText.hidden = YES;
            _rtaDecibelLabel.hidden = YES;
            break;
    }
    [self maintainPeakGridButton];
    [self maintainWindowFunctionControl];
    [self setupFFTSettings];
}

#pragma mark - データセット

- (void) setFFTData:(Float32 *)buffer {
#if (SPECTROGRAM_COMP == ON)
    if (self.busy == NO)
#endif
    {
        @synchronized (self) {
            memcpy(fftData, buffer, sizeof(Float32) * fftBufferSize);
            // 事前に drawRect で生成したイメージをエンキューする。
            if (self.enqueueCandidate) {
                [self enqueueImage:self.enqueueCandidate];
                self.enqueueCandidate = nil;
            }
        }
    }
}

#pragma mark - リングバッファ

- (void) initializeRingBuffer {
    @synchronized (self) {
        if (self.lineBuffers) {
            for (NSUInteger row = 0; row < self.allocatedRows; row++) {
                if (self.lineBuffers[row])
                {// CGImageCreate で確保したメモリは配列内で CGImageRelease を待っている。
                    CGImageRelease(self.lineBuffers[row]);
                    self.lineBuffers[row] = nil;
                }
            }
        }
        self.datumTail = 0;
    }
}

- (void) maintainRingBuffer:(NSUInteger)beforeRows
                      after:(NSUInteger)afterRows
{
    @synchronized (self) {
        NSInteger difference = beforeRows - afterRows;
        
        if (difference > 0)
        {// 【縮小】
            // 小さな方の数だけ作業エリアを確保する。
            CGImageRef *imageRefs = calloc(sizeof(CGImageRef), afterRows);
            
            if (imageRefs) {
                NSUInteger index = 0;
                //【以前大きかった時のリングバッファの内容を適宜振り分ける。】
                for (NSUInteger i = 0; i < beforeRows; i++) {
                    NSUInteger physicalIndex = (i + self.datumTail - 1 + beforeRows) % beforeRows;
                    
                    if (beforeRows - i > afterRows)
                    {// 【冒頭の使用しない部分を破棄する。】
                        if (self.lineBuffers[physicalIndex])
                        {// CGImageCreate で確保したメモリは配列内で CGImageRelease を待っている。
                            // 用済みで不要となった CGImage をリリースする。
                            CGImageRelease(self.lineBuffers[physicalIndex]);
                            self.lineBuffers[physicalIndex] = nil;
                        }
                    } else
                    {// 【後端の有効な部分をワークに格納する。】
                        imageRefs[index++] = self.lineBuffers[physicalIndex];
                    }
                }
                //【ワークに格納した有効な部分をリストアする。】
                for (NSUInteger i = 0; i < afterRows; i++) {
                    self.lineBuffers[i] = imageRefs[i];
                }
                self.datumTail = afterRows;
                free(imageRefs);
            }
        } else
        {// 【拡大】
            //【小さな方の数だけ作業エリアを確保する。】
            CGImageRef *imageRefs = calloc(sizeof(CGImageRef), beforeRows);
            
            if (imageRefs) {
                NSUInteger index = 0;
                //【以前小さかった時のリングバッファの内容を全てワークに格納する。】
                for (NSUInteger i = 0; i < beforeRows; i++) {
                    NSUInteger physicalIndex = (i + self.datumTail - 1 + beforeRows) % beforeRows;
                    imageRefs[index++] = self.lineBuffers[physicalIndex];
                }
                //【ワークに格納した有効な部分をリストアする。】
                for (NSUInteger i = 0; i < afterRows; i++) {
                    if (i < beforeRows)
                    {//【ワークに格納した有効な部分をリストアする。】
                        self.lineBuffers[i] = imageRefs[i];
                    } else
                    {//【後端の使用しない部分を破棄する。】
                        if (self.lineBuffers[i])
                        {// CGImageCreate で確保したメモリは配列内で CGImageRelease を待っている。
                            // 用済みで不要となった CGImage をリリースする。
                            CGImageRelease(self.lineBuffers[i]);
                            self.lineBuffers[i] = nil;
                        }
                    }
                }
                self.datumTail = beforeRows;
                free(imageRefs);
            }
        }
    }
}

// datumTail はエンキューでインクリメントされる。
- (void) enqueueImage:(CGImageRef) imageRef {
    @synchronized (self) {
        NSInteger index = self.datumTail++ % self.effectiveRows;
        
        if (self.lineBuffers[index])
        {// CGImageCreate で確保したメモリは配列内で CGImageRelease を待っている。
            // 用済みで不要となった CGImage をリリースする。
            CGImageRelease(self.lineBuffers[index]);
            self.lineBuffers[index] = nil;
        }
        self.lineBuffers[index] = imageRef;
    }
}

- (CGImageRef) peekImage:(NSInteger)index {
    @synchronized (self) {
        if (self.datumTail <= self.effectiveRows) {
            return self.lineBuffers[index];
        } else {
            return self.lineBuffers[(index + self.datumTail - 1 + self.effectiveRows) % self.effectiveRows];
        }
    }
}

#pragma mark - ユーザーデフォルト

- (void) setDefaults {

//    _pinchRecognizer.scale  = 1.0;
    [_pinchRecognizer setScaleX:1.0];
    [_pinchRecognizer setScaleY:1.0];
    _pinchScaleX = 1.0;
    _pinchScaleY = 1.0;
    _panOffset.x = 0.0;
    _panOffset.y = 0.0;
    zoomShifter = 0;

//    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kMathModeLinearKey];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFFTHideRulerKey];
    [[NSUserDefaults standardUserDefaults] setFloat:[_pinchRecognizer getScaleX] forKey:kFFTPinchScaleXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:[_pinchRecognizer getScaleY] forKey:kFFTPinchScaleYKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kFFTPanOffsetXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kFFTPanOffsetYKey];
}

#pragma mark - レコグナイザーのコールバック用ツール

// 拡大縮小に伴って XYオフセットを調整する。
- (void) maintainPinch {
    
    CGRect bounds = CGGraphRectMake(self.bounds);
    NSUInteger onWidth   = bounds.origin.x                + bounds.size.width;
    NSUInteger onHeight  = bounds.origin.y                + bounds.size.height;
    NSUInteger offWidth  = bounds.origin.x + _panOffset.x + bounds.size.width  * [_pinchRecognizer getScaleX];
    NSUInteger offHeight = bounds.origin.y + _panOffset.y + bounds.size.height * [_pinchRecognizer getScaleY];
    
    // 縮小した結果スクロール範囲外になった場合はスクロールオフセットを調整する。
    if (onWidth > offWidth)
    {
        [_pinchRecognizer limitScaleX:(bounds.size.width - _panOffset.x) /  bounds.size.width];
    }
    if (onHeight > offHeight)
    {
        [_pinchRecognizer limitScaleY:(bounds.size.height - _panOffset.y) / bounds.size.height];
    }
}

// パンに伴って XYオフセットを調整する。
- (void) maintainPan {
    CGRect bounds = CGGraphRectMake(self.bounds);
    // 仮想ビューのサイズ計算（スクロール可能な範囲を規定する）
    [self maintainScrollableArea:bounds];
    _panOffset.x = fmin(_panOffset.x, 0.0);
    _panOffset.y = fmin(_panOffset.y, 0.0);
    _panOffset.x = fmax(_panOffset.x, -_scrollLimit.x);
    _panOffset.y = fmax(_panOffset.y, -_scrollLimit.y);
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kFFTPanOffsetXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kFFTPanOffsetYKey];
}

#pragma mark - レコグナイザーのコールバック

- (void) panOffsetClear {
    // パンオフセットをクリア
    _panOffset = CGPointMake(0.0, 0.0);
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kFFTPanOffsetXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kFFTPanOffsetYKey];
}

- (void) pinchBegan:(UIPinchGestureRecognizerAxis *)sender {
    // scaleX:1.0, scaleSaveX:_pinchScaleX
    // scaleY:1.0, scaleSaveY:_pinchScaleY
    sender.scaleX = _pinchScaleX;    // #1x
    sender.scaleY = _pinchScaleY;    // #1y
    ///
//    [self centering:sender.startLocation];                   // Apr 11, 2019
    [sender createStartRect:self
                       loc1:[sender locationOfTouch:0 inView:self]
                       loc2:[sender locationOfTouch:1 inView:self]];
}

- (void) pinchChanged:(UIPinchGestureRecognizerAxis *)sender {
    CGRect frame = CGGraphRectMake(self.frame);
    CGFloat lastVirtualWidth = _pinchScaleX * frame.size.width;
    CGFloat lastVirtualHeight = _pinchScaleY * frame.size.height;
#if 0
    [_pinchRecognizer createCurrentRect:self
                                   loc1:loc1
                                   loc2:loc2];
#else
    [_pinchRecognizer createCurrentRect:self
                                   loc1:CGPointMake([sender locationOfTouch:0 inView:self].x + _panOffset.x,
                                                    [sender locationOfTouch:0 inView:self].y + _panOffset.y)
                                   loc2:CGPointMake([sender locationOfTouch:1 inView:self].x + _panOffset.x,
                                                    [sender locationOfTouch:1 inView:self].y + _panOffset.y)];
#endif
    // 拡大の場合はセンタリングする？ →そうした Apr 11, 2019
    CGFloat scaleX = [_pinchRecognizer getScaleX];
    // とても重要②
    if (scaleX < _pinchScaleX)
    {// 縮小
        _pinchScaleX = scaleX;
#if 1
        if (scaleX <= 1.0)
        {// ピンチスケールは最小化
            _pinchScaleX = 1.0;
            // ピンチに付帯したパンオフセット処理
            _panOffset = CGPointMake(0.0, _panOffset.y);
            [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kFFTPanOffsetXKey];
        }
#endif
    } else {
        _pinchScaleX = scaleX;
    }
    
    CGFloat scaleY = [_pinchRecognizer getScaleY];
    // とても重要③
    if (scaleY < _pinchScaleY)
    {// 縮小
        _pinchScaleY = scaleY;
#if 1
        if (scaleY <= 1.0)
        {// ピンチスケールは最小化
            _pinchScaleY = 1.0;
            // ピンチに付帯したパンオフセット処理
            _panOffset = CGPointMake(_panOffset.x, 0.0);
            [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kFFTPanOffsetYKey];
        }
#endif
    } else {
        _pinchScaleY = scaleY;
    }
    [self maintainPinch];
    
    CGFloat currentVirtualWidth = _pinchScaleX * frame.size.width;
    CGFloat currentVirtualHeight = _pinchScaleY * frame.size.height;
    //    DEBUG_LOG(@"growSizeX:%g, growSizeY:%g", currentSizeX - lastSizeX, currentSizeY - lastSizeY);
#if 0
    // ピンチで成長した増分をパンオフセットをピンチの起点の場所に応じて調整したいところだが、暫定的にいつもど真ん中でピンチされている設定する。
    CGFloat startPointRatioX = 2.0;
    CGFloat startPointRatioY = 2.0;
#else
    // ピンチで成長する増分は、ピンチ開始した地点が座標系の原点から遠くなれば小さくなる。
    CGFloat startPointRatioX = (frame.size.width / _pinchRecognizer.startLocation.x);
    CGFloat startPointRatioY = (frame.size.height / _pinchRecognizer.startLocation.y);
#endif
    CGFloat deltaX = (currentVirtualWidth - lastVirtualWidth) / startPointRatioX;
    CGFloat deltaY = (currentVirtualHeight - lastVirtualHeight) / startPointRatioY;
    DEBUG_LOG(@"ΔX:%g, ΔY:%g", deltaX, deltaY);
    _panOffset.x -= deltaX;
    _panOffset.y -= deltaY;
    
    [self maintainPan];
}

- (void) pinchEnded:(UIPinchGestureRecognizerAxis *)sender {
    sender.scaleX = _pinchScaleX;
    sender.scaleY = _pinchScaleY;
    [self maintainPinch];
    
    [[NSUserDefaults standardUserDefaults] setFloat:_pinchScaleX forKey:kFFTPinchScaleXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_pinchScaleY forKey:kFFTPinchScaleYKey];
}

- (void) handlePinch:(UIPinchGestureRecognizerAxis *)sender {

    DEBUG_LOG(@"%s", __func__);

    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];

    if ([sender numberOfTouches] >= 2) {
        if (spectrumMode != kSpectrumFFT)
        {// RTA/Spectrogram の場合ピンチを許可しない。
            //
        } else
        {
            switch ((int) sender.state) {
                case UIGestureRecognizerStateBegan:
                    [self pinchBegan:sender];
                    break;
                case UIGestureRecognizerStateChanged:
                    // UIGestureRecognizerStateEnded で遅延実行させた hideScrollIndicator を中止させる。
                    [NSObject cancelPreviousPerformRequestsWithTarget:self];
                    scrollBarVisibility = YES;
                    [self pinchChanged:sender];
                    break;
                case UIGestureRecognizerStateEnded:
                    [self performSelector:@selector(hideScrollIndicator) withObject:nil afterDelay:kScrollBarDesolveDelay];
                    [self pinchEnded:sender];
                    break;
                default:
                    [self performSelector:@selector(hideScrollIndicator) withObject:nil afterDelay:kScrollBarDesolveDelay];
                    break;
            }
        }
    }
}

- (void) handlePan:(UIPanGestureRecognizer *)sender {

    DEBUG_LOG(@"%s", __func__);

    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];

#if (RTA_MARKER == ON)
    if (spectrumMode == kSpectrogram)
    {// Spectrogram の場合パンを許可しない。
        //
    } else if (spectrumMode == kSpectrumRTA ||
               spectrumMode == kSpectrumRTA1_3 ||
               spectrumMode == kSpectrumRTA1_6 ||
               spectrumMode == kSpectrumRTA1_12)
    {
        Float64 hz = 0.0;
        CGPoint pt = CGPointMake([sender locationInView:self].x - FRAME_OFFSET, [sender locationInView:self].y - FRAME_OFFSET);

        switch ((int) sender.state) {
            case UIGestureRecognizerStateBegan:
            case UIGestureRecognizerStateChanged:
                hz = [self logIndex2Frequency:[self point2LogIndex:pt]];
                [[NSUserDefaults standardUserDefaults] setDouble:hz forKey:kSelectedHzKey];
                DEBUG_LOG(@"%g Hz", hz);
                break;
            case UIGestureRecognizerStateEnded:
                break;
            case UIGestureRecognizerStateCancelled:
            case UIGestureRecognizerStateFailed:
                [[NSUserDefaults standardUserDefaults] setDouble:0.0 forKey:kSelectedHzKey];
                break;
        }
        DEBUG_LOG(@"%s[%g,%g]", __func__, _panOffset.x, _panOffset.y);
    } else
#else
    if (spectrumMode != kSpectrumFFT)
    {// RTA/Spectrogram の場合パンを許可しない。
        //
    } else
#endif
    {
        static CGPoint offsetSave;
        
        switch ((int) sender.state) {
            case UIGestureRecognizerStateBegan:
                offsetSave = _panOffset;
                _panStartPt = [sender locationInView:self];
                break;
            case UIGestureRecognizerStateChanged:
                // UIGestureRecognizerStateEnded で遅延実行させた hideScrollIndicator を中止させる。
                [NSObject cancelPreviousPerformRequestsWithTarget:self];
                if (_pinchScaleX > 1.0 || _pinchScaleY > 1.0) {
                    scrollBarVisibility = YES;
                }
                _panEndPt = [sender locationInView:self];
                _panOffset.x += _panEndPt.x - _panStartPt.x;
                _panOffset.y += _panEndPt.y - _panStartPt.y;
                // 引き継ぐ（初期タップをエミュレートする）
                _panStartPt = [sender locationInView:self];
            case UIGestureRecognizerStateEnded:
                [self maintainPan];
                [self performSelector:@selector(hideScrollIndicator) withObject:nil afterDelay:kScrollBarDesolveDelay];
                break;
            case UIGestureRecognizerStateCancelled:
            case UIGestureRecognizerStateFailed:
                _panOffset = offsetSave;
                [self maintainPan];
                [self performSelector:@selector(hideScrollIndicator) withObject:nil afterDelay:kScrollBarDesolveDelay];
                break;
        }
        DEBUG_LOG(@"%s[%g,%g]", __func__, _panOffset.x, _panOffset.y);
    }
}

- (void) drawScrollIndicator:(CGContextRef)context
                        rect:(CGRect)rect
{
    return;
}

- (void) hideScrollIndicator {
    return;
    // このグラフにスクロールインジケーターは似合わない。
    scrollBarVisibility = NO;
    [self setNeedsDisplay];
}

- (void) handleLongPress:(UILongPressGestureRecognizer *)sender {
    
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];

    if (spectrumMode == kSpectrogram && _settingsView.hidden == NO)
    {// Spectrogram で FFT設定ビューが表示中の場合には長押しを許可しない。
        //
    } else {
        if (sender.state == UIGestureRecognizerStateBegan)
        {
            // ポーズ解除
            [_delegate setFreezeMeasurement:NO];
            _header.text = @"";
            
            [self setDefaults];
            [self initializeRingBuffer];
        }
    }
}

#pragma mark - FFT設定のユーティリティー

- (void) fftTypicalSettings {
    Float64 gain = [[UserDefaults sharedManager] getDefaultMicGain];

    [[NSUserDefaults standardUserDefaults] setFloat:gain forKey:kMicGainKey];
    _gainSlider.value = gain;

    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];

    switch (spectrumMode) {
        case kSpectrumFFT:
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFFTHideRulerKey];
            [[NSUserDefaults standardUserDefaults] setInteger:3 forKey:kWindowFunctionKey];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFFTColoringKey];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFFTMathModeLinearKey];
            [self stopAverage];
            [_windowFunctionButton setTitle:NSLocalizedString(@"Blackman", @"ブラックマン") forState:UIControlStateNormal];
            break;
        case kSpectrumRTA:
        case kSpectrumRTA1_3:
        case kSpectrumRTA1_6:
        case kSpectrumRTA1_12:
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFFTHideRulerKey];
            [[NSUserDefaults standardUserDefaults] setInteger:3 forKey:kWindowFunctionKey];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kRTAColoringKey];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFFTMathModeLinearKey];
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kRTAAverageModeKey];
            [self initializeRTA];
            [self startAverage:[[NSUserDefaults standardUserDefaults] integerForKey:kRTAAverageModeKey]];
            break;
        case kSpectrogram:
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFFTHideRulerKey];
            [[NSUserDefaults standardUserDefaults] setInteger:3 forKey:kWindowFunctionKey];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kSpectrogramMathModeLinearKey];
            [[NSUserDefaults standardUserDefaults] setFloat:0.3 forKey:kSpectrogramNoiseLevelKey];
            [self stopAverage];
            break;
    }
    [self setupFFTSettings];
    [self initializeRingBuffer];
    [[NSUserDefaults standardUserDefaults] setDouble:0.0 forKey:kSelectedHzKey];
}

- (void) fftExplorationSettings {
    Float64 gain = [[UserDefaults sharedManager] getDefaultMicGain];

    [[NSUserDefaults standardUserDefaults] setFloat:gain forKey:kMicGainKey];
    _gainSlider.value = gain;

    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];

    switch (spectrumMode) {
        case kSpectrumFFT:
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFFTHideRulerKey];
            [[NSUserDefaults standardUserDefaults] setInteger:3 forKey:kWindowFunctionKey];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kFFTColoringKey];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kFFTMathModeLinearKey];
            [self stopAverage];
            [_windowFunctionButton setTitle:NSLocalizedString(@"Blackman", @"ブラックマン") forState:UIControlStateNormal];
            break;
        case kSpectrumRTA:
        case kSpectrumRTA1_3:
        case kSpectrumRTA1_6:
        case kSpectrumRTA1_12:
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFFTHideRulerKey];
            [[NSUserDefaults standardUserDefaults] setInteger:3 forKey:kWindowFunctionKey];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kRTAColoringKey];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kRTAModeLineKey];
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kRTAAverageModeKey];
            [self initializeRTA];
            [self startAverage:[[NSUserDefaults standardUserDefaults] integerForKey:kRTAAverageModeKey]];
            break;
        case kSpectrogram:
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kFFTHideRulerKey];
            [[NSUserDefaults standardUserDefaults] setInteger:3 forKey:kWindowFunctionKey];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kSpectrogramMathModeLinearKey];
            [[NSUserDefaults standardUserDefaults] setFloat:0.0 forKey:kSpectrogramNoiseLevelKey];
            [self stopAverage];
            break;
    }
    [self setupFFTSettings];
    [self initializeRingBuffer];
    [[NSUserDefaults standardUserDefaults] setDouble:0.0 forKey:kSelectedHzKey];
}

- (void) setupFFTSettings {
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    BOOL isLinear = (spectrumMode == kSpectrumFFT && [[NSUserDefaults standardUserDefaults] boolForKey:kFFTMathModeLinearKey]) ||
                    (spectrumMode == kSpectrogram && [[NSUserDefaults standardUserDefaults] boolForKey:kSpectrogramMathModeLinearKey]);
    BOOL polyLine = [[NSUserDefaults standardUserDefaults] boolForKey:kRTAModeLineKey];
    NSUInteger windowFunction = [[NSUserDefaults standardUserDefaults] integerForKey:kWindowFunctionKey];
    // ユーザーデフォルトに収める Gain の値は Level-0(0.0) から 20dB区切りで Level-7(160.0)
    Float32 gain = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
    // ユーザーデフォルトに収める Noise Level の値は Level-0(0.0) から 20dB区切りで Level-7(160.0)
    Float32 noiseLevel = [[NSUserDefaults standardUserDefaults] floatForKey:kSpectrogramNoiseLevelKey];
//    NSUInteger rtaAverage = [[NSUserDefaults standardUserDefaults] integerForKey:kRTAAverageModeKey];
    BOOL coloring = NO;

    switch (spectrumMode) {
        case kSpectrumFFT:
            coloring = [[NSUserDefaults standardUserDefaults] boolForKey:kFFTColoringKey];
            break;
        case kSpectrumRTA:
        case kSpectrumRTA1_3:
        case kSpectrumRTA1_6:
        case kSpectrumRTA1_12:
            coloring = [[NSUserDefaults standardUserDefaults] boolForKey:kRTAColoringKey];
            break;
    }
    [_colorSwitch setOn:coloring];
    [_windowFunctionSegment setSelectedSegmentIndex:windowFunction];

    [_gainSlider setValue:gain];

    switch (spectrumMode) {
        case kSpectrogram:
            [_logOrLinear setSelectedSegmentIndex:isLinear ? 1 : 0];
            [_noiseReductionSlider setValue:noiseLevel];
            break;
        case kSpectrumFFT:
            [_logOrLinear setSelectedSegmentIndex:isLinear ? 1 : 0];
            break;
        case kSpectrumRTA:
        case kSpectrumRTA1_3:
        case kSpectrumRTA1_6:
        case kSpectrumRTA1_12:
            [_logOrLinear setSelectedSegmentIndex:polyLine ? 1 : 0];
            break;
    }
}

#pragma mark - ピークホールドのアクション

- (IBAction) peakHoldAction:(id)sender {
    
//    [self hapticFeedbackMediumImpact];

    if ([[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey] == kSpectrogram) {
        BOOL newHideGrid = ! [[NSUserDefaults standardUserDefaults] boolForKey:kFFTHideRulerKey];
        
        [_peakHold setSelected:! newHideGrid];
        if (! newHideGrid) {
            [_peakHold setBackgroundColor:[UIColor whiteColor]];
        } else {
            [_peakHold setBackgroundColor:[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0]];
        }
        [[NSUserDefaults standardUserDefaults] setBool:newHideGrid forKey:kFFTHideRulerKey];
        [self setNeedsDisplay];
    } else {
        BOOL newPeakHold = ! [[NSUserDefaults standardUserDefaults] boolForKey:kSpectrumPeakHoldKey];
        _peakHold.selected = newPeakHold;

        if (newPeakHold) {
            [self clearPeaks];
            [_peakHold setBackgroundColor:[UIColor whiteColor]];
        } else {
            [_peakHold setBackgroundColor:[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0]];
        }
//        [_peakHold setSelected:newPeakHold];
        [[NSUserDefaults standardUserDefaults] setBool:newPeakHold forKey:kSpectrumPeakHoldKey];
    }
}

#pragma mark - マイクの AGCのアクション

- (void) maintainPeakGridButton {
    // ピークホールド・グリッドのデフォルト値を反映する。
    if ([[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey] == kSpectrogram)
    {
        [_peakHold setSelected:! [[NSUserDefaults standardUserDefaults] boolForKey:kFFTHideRulerKey]];

        if (! [[NSUserDefaults standardUserDefaults] boolForKey:kFFTHideRulerKey]) {
            [_peakHold setBackgroundColor:[UIColor whiteColor]];
        } else {
            [_peakHold setBackgroundColor:[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0]];
        }
    } else {
        [_peakHold setSelected:[[NSUserDefaults standardUserDefaults] boolForKey:kSpectrumPeakHoldKey]];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kSpectrumPeakHoldKey]) {
            [_peakHold setBackgroundColor:[UIColor whiteColor]];
        } else {
            [_peakHold setBackgroundColor:[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0]];
        }
    }
}

- (IBAction) agcAction:(id)sender {

//    [self hapticFeedbackMediumImpact];

#if 0
    BOOL newAGC = ! [[NSUserDefaults standardUserDefaults] boolForKey:kSpectrumAgcKey];
    OSStatus stat;
    
    _agcSwitch.selected = newAGC;
    
    if (newAGC) {// デフォルトモード
        UInt32 mode = kAudioSessionMode_Default;
        stat = AudioSessionSetProperty(kAudioSessionProperty_Mode, sizeof(mode), &mode);
        [_agcSwitch setImage:[UIImage imageNamed:@"agcON"] forState:UIControlStateNormal];
    } else {// 計測用モード
#if 1
        UInt32 mode = kAudioSessionMode_Measurement;
        stat = AudioSessionSetProperty(kAudioSessionProperty_Mode, sizeof(mode), &mode);
#else
        UInt32 mode;
        if ([Environment systemMajorVersion] >= 10) {
            mode = kAUVoiceIOProperty_BypassVoiceProcessing;
        } else {
            mode = kAudioSessionMode_Measurement;
        }
        stat = AudioSessionSetProperty(kAudioSessionProperty_Mode, sizeof(mode), &mode);
#endif
        [_agcSwitch setImage:[UIImage imageNamed:@"agcOFF"] forState:UIControlStateNormal];
    }
    DEBUG_LOG(@"%s stat=%d", __func__, stat);
    [[NSUserDefaults standardUserDefaults] setBool:newAGC forKey:kSpectrumAgcKey];
#else
    NSUInteger newMode = ([[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey] + 1) % kSpectrumLast;
    
//    _agcSwitch.selected = newMode;
    _agcSwitch.selected = YES;
    
    // ユーザーデフォルト値を反映する。
    [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kSpectrumModeKey];
    [self initializeRTA];
    [self maintainControl:newMode];
    [self setUnitBase];
#if (CSV_OUT == ON)
    [self stopAction:nil];
#endif
#endif
}

#pragma mark - Settingsのアクション

- (IBAction) settingsAction:(id)sender {

//    [self hapticFeedbackMediumImpact];

    [self maintainWindowFunctionControl];

    if (_settingsView.hidden) {
//        [_settingsView becomeFirstResponder];

        BOOL isntSpectrogram = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey] != kSpectrogram;

        _settingsView.alpha = 0.0;
        [self setupFFTSettings];
        _settingsView.hidden = NO;
        _colorLabel.hidden = ! isntSpectrogram;
        _colorSwitch.hidden = ! isntSpectrogram;
        _gainLabel.hidden = NO;
        _gainSlider.hidden = NO;
        _noiseReductionLabel.hidden = isntSpectrogram;
        _noiseReductionSlider.hidden = isntSpectrogram;
        [UIView animateWithDuration:0.5
                         animations:^{self.settingsView.alpha = 1.0;}
                         completion:^(BOOL finished) {
                             [self removeGestureRecognizer:self.pinchRecognizer];
                             [self removeGestureRecognizer:self.panRecognizer];
                             [self removeGestureRecognizer:self.longPressRecognizer];
                         }];
    } else {
//        [_settingsView resignFirstResponder];

        [UIView animateWithDuration:0.5
                         animations:^{self.settingsView.alpha = 0.0;}
                         completion:^(BOOL finished) {
                             [self addGestureRecognizer:self.pinchRecognizer];
                             [self addGestureRecognizer:self.panRecognizer];
                             [self addGestureRecognizer:self.longPressRecognizer];
                             self.settingsView.hidden = YES;
                         }];
    }
}

#pragma mark - Colorのアクション

- (IBAction) colorAction:(id)sender {
    
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    
    switch (spectrumMode) {
        case kSpectrumRTA:
        case kSpectrumRTA1_3:
        case kSpectrumRTA1_6:
        case kSpectrumRTA1_12:
            [[NSUserDefaults standardUserDefaults] setBool:((UISwitch *) sender).on forKey:kRTAColoringKey];
            break;
        default:
            [[NSUserDefaults standardUserDefaults] setBool:((UISwitch *) sender).on forKey:kFFTColoringKey];
            break;
    }
}

#pragma mark - Window Functionのアクション

- (IBAction) windowFunctionAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:((UISegmentedControl *) sender).selectedSegmentIndex forKey:kWindowFunctionKey];
}

#pragma mark - Gainのアクション
// ユーザーデフォルトに収める Mic Gain の値は 0.0dB(x1) から 40.0dB(x100)
- (IBAction) gainAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setFloat:((UISlider *) sender).value forKey:kMicGainKey];
    [self setGainInfo]; // Added on Jun 13, 2021 by T.M.
    [self setUnitBase]; // Added on Jun 13, 2021 by T.M.
}

#pragma mark - Averageのアクション
// ユーザーデフォルトに収める Average の値は 0,1,2,3
// 実際の値は 平均化しない,1,4,無限大
- (IBAction) averageAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:((UISegmentedControl *) sender).selectedSegmentIndex forKey:kRTAAverageModeKey];
    [self initializeRTA];

    switch ([[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey]) {
        case kSpectrumRTA:
        case kSpectrumRTA1_3:
        case kSpectrumRTA1_6:
        case kSpectrumRTA1_12:
            [self startAverage:[[NSUserDefaults standardUserDefaults] integerForKey:kRTAAverageModeKey]];
            break;
            
        default:
            [self stopAverage];
            break;
    }
}

#pragma mark - Noise Levelのアクション

// ユーザーデフォルトに収める Noise Level の値は Level-0(0.0) から 20dB区切りで Level-7(160.0)
- (IBAction) noiseLevelAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setFloat:((UISlider *) sender).value forKey:kSpectrogramNoiseLevelKey];
}

#pragma mark - Typicalのアクション

- (IBAction) typicalAction:(id)sender {
    [self fftTypicalSettings];
    [self maintainPeakGridButton];
    [self setGainInfo]; // Added on Jun 13, 2021 by T.M.
    [self setUnitBase]; // Added on Jun 13, 2021 by T.M.
}

- (IBAction) exploreAction:(id)sender {
    [self fftExplorationSettings];
    [self maintainPeakGridButton];
    [self setGainInfo]; // Added on Jun 13, 2021 by T.M.
    [self setUnitBase]; // Added on Jun 13, 2021 by T.M.
}

#pragma mark - Stop,Play/Pause のコールバック関係

enum {
    CSV_Stop,
    CSV_Rec
#if (CSV_OUT_ONE_BUTTON == OFF)
    , CSV_Pause
#endif
};

#pragma mark - Haptic Feedback

- (void) hapticFeedbackLightImpact {
    if ([Environment systemMajorVersion] >= 10) {
        UIImpactFeedbackGenerator *myGen = [[UIImpactFeedbackGenerator alloc] initWithStyle:(UIImpactFeedbackStyleLight)];
        [myGen prepare];
        [myGen impactOccurred];
    }
}

- (void) hapticFeedbackMediumImpact {
    if ([Environment systemMajorVersion] >= 10) {
        UIImpactFeedbackGenerator *myGen = [[UIImpactFeedbackGenerator alloc] initWithStyle:(UIImpactFeedbackStyleMedium)];
        [myGen prepare];
        [myGen impactOccurred];
    }
}

- (void) hapticFeedbackHeavyImpact {
    if ([Environment systemMajorVersion] >= 10) {
        UIImpactFeedbackGenerator *myGen = [[UIImpactFeedbackGenerator alloc] initWithStyle:(UIImpactFeedbackStyleHeavy)];
        [myGen prepare];
        [myGen impactOccurred];
    }
}

- (void) hapticFeedbackSelection {
    if ([Environment systemMajorVersion] >= 10) {
        UISelectionFeedbackGenerator *myGen = [[UISelectionFeedbackGenerator alloc] init];
        [myGen prepare];
        [myGen selectionChanged];
    }
}

- (void) hapticFeedbackNotificationError {
    if ([Environment systemMajorVersion] >= 10) {
        UINotificationFeedbackGenerator *myGen = [[UINotificationFeedbackGenerator alloc] init];
        [myGen prepare];
        [myGen notificationOccurred:UINotificationFeedbackTypeError];
    }
}

- (void) hapticFeedbackNotificationSuccess {
    if ([Environment systemMajorVersion] >= 10) {
        UINotificationFeedbackGenerator *myGen = [[UINotificationFeedbackGenerator alloc] init];
        [myGen prepare];
        [myGen notificationOccurred:UINotificationFeedbackTypeSuccess];
    }
}

- (void) hapticFeedbackNotificationWarning {
    if ([Environment systemMajorVersion] >= 10) {
        UINotificationFeedbackGenerator *myGen = [[UINotificationFeedbackGenerator alloc] init];
        [myGen prepare];
        [myGen notificationOccurred:UINotificationFeedbackTypeWarning];
    }
}

- (void) initFormatter {
    self.fileDateFormatter = [[NSDateFormatter alloc] init];
    // グレゴリー暦（英語シンプル）
    [_fileDateFormatter setLocale:[NSLocale systemLocale]];
    [_fileDateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    [_fileDateFormatter setCalendar:[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian]];
    // ソースの日付形式は、yyyy-MM-dd HH-mm-ss
    [_fileDateFormatter setDateFormat:@"yyyy-MM-dd HH-mm-ss"];
    
    self.dataDateFormatter = [[NSDateFormatter alloc] init];
    // グレゴリー暦（英語シンプル）
    [_dataDateFormatter setLocale:[NSLocale systemLocale]];
    [_dataDateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    [_dataDateFormatter setCalendar:[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian]];
    // ソースの日付形式は、yyyy/MM/dd HH:mm:ss.SSS
    [_dataDateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss.SSS"];
}

#if (CSV_OUT == ON)
- (IBAction) stopAction:(id)sender {
    
    NSUInteger newCSV = CSV_Stop;
    
    _stopSwitch.selected = YES;
    _playPauseSwitch.selected = NO;

    [_stopSwitch setImage:[UIImage imageNamed:@"rec_stop_red"] forState:UIControlStateNormal];
    [_playPauseSwitch setImage:[UIImage imageNamed:@"rec_start_red"] forState:UIControlStateNormal];
    [[NSUserDefaults standardUserDefaults] setInteger:newCSV forKey:kSpectrumCSVKey];
    
    [self closeCSV];
}

- (IBAction) playPauseAction:(id)sender {
    
    NSUInteger oldPlayPause = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumCSVKey];
#if (CSV_OUT_ONE_BUTTON == ON)
    NSUInteger newPlayPause = (oldPlayPause == CSV_Rec) ? CSV_Stop : CSV_Rec;
#else
    NSUInteger newPlayPause = (oldPlayPause == CSV_Rec) ? CSV_Pause : CSV_Rec;
#endif
    
    _stopSwitch.selected = NO;
    _playPauseSwitch.selected = YES;
    
    if (oldPlayPause == CSV_Stop) {
        [self openCSV];
    }
    
    [_stopSwitch setImage:[UIImage imageNamed:@"rec_stop"] forState:UIControlStateNormal];
#if (CSV_OUT_ONE_BUTTON == ON)
    if (newPlayPause == CSV_Stop) {// 保存やめる
        [self closeCSV];
    }
    [_playPauseSwitch setImage:[UIImage imageNamed:@"rec_start_red"] forState:UIControlStateNormal];
#else
    if (newPlayPause == CSV_Rec) {// 保存中
        [_playPauseSwitch setImage:[UIImage imageNamed:@"rec_pause_red"] forState:UIControlStateNormal];
    } else {// ポーズ中
        [_playPauseSwitch setImage:[UIImage imageNamed:@"rec_start_red"] forState:UIControlStateNormal];
    }
#endif
    [[NSUserDefaults standardUserDefaults] setInteger:newPlayPause forKey:kSpectrumCSVKey];
}

- (void) openCSV {
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    //    ドキュメントフォルダ/log.txt
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* dir = [paths objectAtIndex:0];
    NSString *fileName = nil;
    if (spectrumMode == kSpectrogram) {
        fileName = [NSString stringWithFormat:@"%@_%@.csv", NSLocalizedString(@"SND Spectrogram", @""), [_fileDateFormatter stringFromDate:[NSDate date]]];
    } else {
        fileName = [NSString stringWithFormat:@"%@_%@.csv", NSLocalizedString(@"SND Spectrum", @""), [_fileDateFormatter stringFromDate:[NSDate date]]];
    }
    NSString* path = [dir stringByAppendingPathComponent:fileName];
    self.fp = fopen([path UTF8String], "a");
    if (_fp) {
        if (spectrumMode == kSpectrogram) {
            NSMutableString *buffer = [[NSMutableString alloc] init];
            for (NSUInteger i = 1; i < fftBufferSize; i++) {
                [buffer appendFormat:@"%ldHz", 22050 * i / fftBufferSize];
                if (i < fftBufferSize - 1) {
                    [buffer appendString:@","];
                }
            }
            [buffer appendString:@"\n"];
            fprintf(_fp, "%s", [buffer UTF8String]);
        } else {
            fprintf(_fp, "Timestamp,LoudestFrequency(Hz),Loudness(dB)\n");
        }
    }
    if ([_logTimer isValid] == YES) {
        [_logTimer invalidate];
    }
    self.logTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(putCSV) userInfo:nil repeats:YES];
}

- (void) closeCSV {
    if (_fp) {
        fclose(_fp);
    }
    self.fp = nil;
    if ([_logTimer isValid] == YES) {
        [_logTimer invalidate];
        self.logTimer = nil;
    }
}

- (void) putCSV {
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    NSUInteger oldPlayPause = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumCSVKey];

    if (oldPlayPause == CSV_Rec) {// 保存中
#if (CSV_OUT_ONE_BUTTON == ON)
        if (_logCounter % 2) {
            [_playPauseSwitch setImage:[UIImage imageNamed:@"rec_start_cyan"] forState:UIControlStateNormal];
        } else {
            [_playPauseSwitch setImage:[UIImage imageNamed:@"rec_start_red"] forState:UIControlStateNormal];
        }
#else
        if (_logCounter % 2) {
            [_playPauseSwitch setImage:[UIImage imageNamed:@"rec_pause_cyan"] forState:UIControlStateNormal];
        } else {
            [_playPauseSwitch setImage:[UIImage imageNamed:@"rec_pause_red"] forState:UIControlStateNormal];
        }
#endif
        if (_fp) {
            if (spectrumMode == kSpectrogram) {
                NSMutableString *buffer = [[NSMutableString alloc] init];
                
                for (NSUInteger i = 1; i < fftBufferSize; i++) {
                    Float64 rawSPL = fftData[i];
                    
                    if (peakData[i] < rawSPL) {
                        peakData[i] = rawSPL;
                    }
                    if (rawSPL == 0.0) {// rawSPL が 0 だと log10(rawSPL) が +INF になって障害が発生する。
                        rawSPL = SILENT;
                    }
//                    Float32 gain = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
                    /*
                    Float64 decibel = MAX(20.0 * log10(AUDIBLE_MULTIPLE_F * rawSPL), -40.0);
                    decibel += gain * FULL_DYNAMIC_RANGE_DECIBEL; // ゲインに応じて最大80dBの増幅をする。
                    */
//                    Float64 multiplier = pow(10, gain); // Pa/FS の 1/2 が有効な倍率だが見かけを2倍になどしない。
//                    Float64 decibel = 20.0 * log10(multiplier);
                    Float64 decibel = 20.0 * (log10(AUDIBLE_MULTIPLE_F * rawSPL));

                    NSString *db = [NSString stringWithFormat:@"%.2f", decibel];
                    [buffer appendString: db];
                    if (i < fftBufferSize - 1) {
                        [buffer appendString:@","];
                    }
                }
                [buffer appendString:@"\n"];
                fprintf(_fp, "%s", [buffer UTF8String]);
                DEBUG_LOG(@"%@", buffer);
            } else {
                Float64 decibel = 20.0 * log10(AUDIBLE_MULTIPLE_F * _maxHZValue);
                NSString *hz = [NSString stringWithFormat:@"%.0f", _maxHZ];
                NSString *db = [NSString stringWithFormat:@"%.2f", decibel];
                NSString *str = [NSString stringWithFormat:@"%@,%@,%@\n", [_dataDateFormatter stringFromDate:[NSDate date]], hz, db];
                
                fprintf(_fp, "%s", [str UTF8String]);
                DEBUG_LOG(@"%@", str);
            }
        }
    } else {// ポーズ中
        if (_logCounter % 2) {
            [_playPauseSwitch setImage:[UIImage imageNamed:@"rec_start_cyan"] forState:UIControlStateNormal];
        } else {
            [_playPauseSwitch setImage:[UIImage imageNamed:@"rec_start_red"] forState:UIControlStateNormal];
        }
    }
    _logCounter++;
}
#endif
//#define DECIBEL_OFFSET      100.0

- (Float64) volumeToDecibel:(Float64)rawSPL {
#if 0
    Float64 one = 1.0f;
    Float64 decibel;
    // Vector convert power or amplitude to decibels; double precision.
    vDSP_vdbconD(rawSPL, 1, &one, &decibel, 1, 1, 1); // Volt
    DEBUG_LOG(@"%gdB", decibel);
//    decibel += DECIBEL_OFFSET;
    return decibel;
#else
    // 対数の値は dB(20log()) の 1/20
    return 20.0 * log10(rawSPL);
#endif
}
// Start Add on Jun 13, 2021 by T.M.
- (void) setGainInfo {
    
    Float32 gain = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
    Float64 multiplier = pow(10, gain); // Pa/FS の 1/2 が有効な倍率だが見かけを2倍になどしない。
    Float64 dB = 20.0 * log10(multiplier);

    _gainInfo.text = [NSString stringWithFormat:@"%.1fdB (x%.1f)", dB, multiplier];
    _gainSlider.value = gain;
}

- (void) setUnitBase {
    NSUInteger spectrumMode = [[NSUserDefaults standardUserDefaults] integerForKey:kSpectrumModeKey];
    Float32 gain = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
    switch (spectrumMode) {
        case kSpectrogram:
            _dB.text = @"";
            break;
        default:
            _dB.text = (gain == 0) ? @"dBFS" : @"dBPa";
            break;
    }
}
// End Add on Jun 13, 2021 by T.M.
@end
