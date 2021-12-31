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
//  ScopeView.m

#import <math.h>
#import <Accelerate/Accelerate.h>
#import "definitions.h"
#import "Environment.h"
#import "ScopeHelper.h"
#import "ColorUtil.h"
#import "ScopeView.h"
#import "ScopeViewController.h"
#import "ScrollIndicator.h"

@implementation ScopeView

// Designated initializer
- (id) initWithCoder:(NSCoder*)decoder
{
    self = [super initWithCoder:decoder];
    if (self != nil) {
        if ([[UserDefaults sharedManager] isIPhone4]) {
            scopeBufferSize = SCOPE_BUFFER_SIZE / 2.0;
        } else {
            scopeBufferSize = SCOPE_BUFFER_SIZE;
        }
        self.rawData = malloc(scopeBufferSize * sizeof(Float32));
        [self clearBuffer:self];

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

        _pinchScaleX = [[NSUserDefaults standardUserDefaults] floatForKey:kScopePinchScaleXKey];
        _pinchScaleY = [[NSUserDefaults standardUserDefaults] floatForKey:kScopePinchScaleYKey];
        _panOffset.x = [[NSUserDefaults standardUserDefaults] floatForKey:kScopePanOffsetXKey];
        _panOffset.y = [[NSUserDefaults standardUserDefaults] floatForKey:kScopePanOffsetYKey];
        if (_pinchScaleX < 1.0) {
            _pinchScaleX = 1.0;
            _panOffset.x = 0.0;
        }
        if (_pinchScaleY < 1.0) {
            _pinchScaleY = DEFAULT_VOLT_RANGE;  // 1mV のスケール
            _panOffset.y = 0.0;
        }
#if (CENTERING == ON)
        [_pinchRecognizer setScaleX:_pinchScaleX];
        [_pinchRecognizer setScaleY:_pinchScaleY];
#endif
    }
    return self;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    
    // 【注意】背景をクリアカラーに設定し、opaque = NO にすること。
    //    self.backgroundColor = [UIColor clearColor];
    
    // このビューの背景色を親ビューの背景色に設定する。
    //    [self superview].backgroundColor = [[self superview] superview].backgroundColor;
    
    _clearButton.layer.cornerRadius = 5.0;
    [_clearButton setTitle:NSLocalizedString(@"Clear", @"") forState:UIControlStateNormal];

#if (CENTERING == ON)
    CGRect rect = self.frame;
    CGRect frame = CGGraphRectMake(rect);
    [self maintainScrollableArea:frame];
    [self maintainPinch];
    [self maintainPan];
#else
    [self maintainPinch];
#endif
    [self setGainInfo]; // Added on Jun 13, 2021 by T.M.
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
            
//            if ([[event allTouches] count] == 2) {
//            }
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

    if (((ScopeViewController *) _delegate).freeze) {
        _header.text = [[UserDefaults sharedManager] timeStamp];
    } else {
        _header.text = @"";
    }
}

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
    // オシロは中点電位（0V）があるので、縦スクロールはさせない。酔って、scaleY は 1.0固定で使用すること。
    CGRect frame = CGGraphRectMake(rect);
    NSUInteger volumeDecades = 20;
    static NSInteger dbLabel[] = {10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, -1, -2, -3, -4, -5, -6, -7, -8, -9, -10};
    Float32 org_x = frame.origin.x;
    Float32 org_y = frame.origin.y;
    Float32 height = frame.size.height;
    Float32 bot_y = org_y + height;
    Float32 db_ruler_delta = scaleY * frame.size.height / volumeDecades;
    NSUInteger scaleVoltX = floor(_pinchScaleY) - 1;
    Float32 scaleVolts[] = {1.0,    // 1
                            2.0,    // 2
                            5.0,    // 3
                            10.0,   // 4
                            20.0,   // 5
                            50.0,   // 6
                            100.0,  // 7
                            200.0,  // 8
                            500.0,  // 9
                            500.0,  // 10
                            500.0,  // 11
                            500.0,  // 12
                            500.0,  // 13
                            500.0,  // 14
                            500.0,  // 15
                            500.0   // 16
    };

    NSUInteger scale = (int) floor(scaleVolts[scaleVoltX]);
    Float32 gain = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
    // gain == 0.0 は 10^0 = 1 で　Pa/FS = 1 を表す。
    NSString *unit = (gain == 0.0) ? @"FS" : @"Pa";
    NSString *scaleBase;
    switch (scale) {
        case 1:
            scaleBase = @"x 100m";
            break;
        case 2:
            scaleBase = @"x 50m";
            break;
        case 5:
            scaleBase = @"x 20m";
            break;
        case 10:
            scaleBase = @"x 10m";
            break;
        case 20:
            scaleBase = @"x 5m";
            break;
        case 50:
            scaleBase = @"x 2m";
            break;
        case 100:
            scaleBase = @"x 1m";
            break;
        case 200:
            scaleBase = @"x 500μ";
            break;
        case 500:
            scaleBase = @"x 200μ";
            break;
        default:
            scaleBase = @"x 200μ";
            break;
    }
    _leftHeader.text = [scaleBase stringByAppendingString:unit];
    
    UIFont *font = nil;
    UIColor *color = nil;
    
    CGContextSetLineWidth(context, 0.2);
    // 縦ステップ
    font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:7.5];
    color = [ColorUtil vfdOn];
    CGContextSetStrokeColorWithColor(context, [ColorUtil vfdOn].CGColor);
    CGContextSetFillColorWithColor(context, [ColorUtil vfdOn].CGColor);
    
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
    BOOL isHideRuler = [[NSUserDefaults standardUserDefaults] boolForKey:kScopeHideRulerKey];
    Float32 volumeDecades = 20;
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

            if (vPos >= FRAME_OFFSET && vPos <= org_y + frame.size.height)
            {// 論理クリッピング
                CGContextMoveToPoint(context   , fmax(FRAME_OFFSET, org_x + offset.x), vPos);
                CGContextAddLineToPoint(context,           (org_x + width) + offset.x, vPos);
            }
        }
        CGContextStrokePath(context);
    }
}

// 横ステップと縦罫線
- (void) drawHorizontalStepsAndVerticalGuide:(CGContextRef)context
                                        rect:(CGRect)rect
                                      scaleX:(CGFloat)scaleX
                                      offset:(CGPoint)offset
{
    CGRect frame = CGGraphRectMake(rect);
    BOOL isHideRuler = [[NSUserDefaults standardUserDefaults] boolForKey:kScopeHideRulerKey];
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

    if (! isHideRuler) {
        CGContextBeginPath(context);
    }
    // 22050Hz の按分が基本
    NSUInteger times = 23;
    Float32 ruler_dh = (width * 0.002300 / 0.002321) / times;
    NSUInteger mod = scaleX > 2.0 ? 1 : 5;

    for (NSUInteger i = 0; i <= times; i++) {
        Float32 hpos = ruler_dh * i + org_x;
        
        if (i && (i % mod) == 0) {
            NSString *title = [NSString stringWithFormat:@"%lums", (unsigned long) i];
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
}

- (void) drawRuler:(CGContextRef)context
              rect:(CGRect)rect
            scaleX:(CGFloat)scaleX
            scaleY:(CGFloat)scaleY
            offset:(CGPoint)offset
{
    CGContextTranslateCTM(context, 0, 0);
    CGContextScaleCTM(context, 1, 1);
    
    [self drawFrame:context rect:rect scale:scaleX offset:offset];
    [self drawVerticalSteps:context rect:rect scaleY:scaleY offset:offset];
    [self drawHorizontalStepsAndVerticalGuide:context rect:rect scaleX:scaleX offset:offset];
    [self drawHorizontalGuide:context rect:rect scaleX:scaleX scaleY:scaleY offset:offset];
}

- (UIImage *) drawPoints:(CGContextRef)context
                    size:(CGSize)size
                  scaleX:(CGFloat)scaleX
                  scaleY:(CGFloat)scaleY
                  offset:(CGPoint)offset
           generateImage:(BOOL)generateImage
{
    if (generateImage) {
        UIGraphicsBeginImageContext(size);
    }
    Float32 width = size.width * scaleX;
    Float32 height = size.height * scaleY;
    NSUInteger scaleVoltsIndex = floor(_pinchScaleY) - 1;
    Float32 scaleVolts[] = {
        1.0,    // 1
        2.0,    // 2
        5.0,    // 3
        10.0,   // 4
        20.0,   // 5
        50.0,   // 6
        100.0,  // 7
        200.0,  // 8
        500.0,  // 9
        500.0,  // 10
        500.0,  // 11
        500.0,  // 12
        500.0,  // 13
        500.0,  // 14
        500.0,  // 15
        500.0   // 16
    };
    UIGraphicsBeginImageContext(size);

    // drawAtPoint:withAttributes: が上下反転しているのを補正する。
//    CGContextTranslateCTM(context, 0, frame.size.height);
//    CGContextScaleCTM(context, scale, -scale);

    Float32 org_x = 0;
    Float32 org_y = 0;
    Float32 bot_y = org_y + height;
    CGPoint points[SCOPE_BUFFER_SIZE];
    
    // データのプロット
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, [UIColor redColor].CGColor);
    CGContextBeginPath(context);
    // リーディングエッジで自動トリガー
    NSUInteger autoTriggerMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"autoTrigger"];
    Float32 triggerLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"triggerLevel"];
    
    switch (autoTriggerMode) {
        case 1:
            [self autoTrigger:YES level:triggerLevel];
            break;
        case 2:
            [self autoTrigger:NO level:triggerLevel];
            break;
    }
    CGPoint lastPt = CGPointMake(0.0, 0.0);
#if BEZIER
    UIBezierPath *bezier = [[UIBezierPath alloc] init];
#endif
    for (NSUInteger i = 0; i < scopeBufferSize; i++) {
        Float32 fract;
        Float32 hpos;
        Float32 volts = scaleVolts[scaleVoltsIndex] * [self peekData:i];
        Float32 gain = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
        volts *= pow(10.0, gain); // ゲインは 0.0 〜 2.0 を 10^(0) 〜 10^(2) にマップする。
        Float32 ratio = volts + 0.5; // 0.5 は 0V を中央にする為のオフセット
        Float32 volumeOffset = height * ratio;
        
        fract = (1.0 * i / scopeBufferSize);
        if (i == 0) {
            hpos = org_x;
            CGContextMoveToPoint(context   , hpos + offset.x, bot_y - volumeOffset + offset.y);
        } else {
            hpos = (fract * width) + org_x;
            if (volumeOffset) {
                CGContextAddLineToPoint(context, hpos + offset.x, bot_y - volumeOffset + offset.y);
            } else {
                points[i] = lastPt;
            }
        }
    }
    CGContextStrokePath(context);

    if (generateImage) {
        UIImage *pdfImage = UIGraphicsGetImageFromCurrentImageContext();//autoreleased
        UIGraphicsEndImageContext();
        return pdfImage;
    } else {
        return nil;
    }
}

- (void) maintainScrollableArea:(CGRect)frame {
    // 仮想ビューのサイズ計算（スクロール可能な範囲を規定する）
    _scrollLimit.x = (frame.size.width  * [_pinchRecognizer getScaleX]) - (frame.size.width);
    _scrollLimit.y = 0.0;
}

- (void)drawRect:(CGRect)rect {
    
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
             scaleY:1.0
             offset:_panOffset];
#if 1
    // クリッピングを frame に制限する。
    CGContextClipToRect(context, frame);
    CGContextTranslateCTM(context, FRAME_OFFSET, FRAME_OFFSET);
    (void) [self drawPoints:context size:frame.size
                     scaleX:_pinchScaleX
                     scaleY:1.0
                     offset:_panOffset
              generateImage:NO];
#else
    // クリッピングを frame に制限する。
    CGContextClipToRect(context, frame);
    CGContextTranslateCTM(context, FRAME_OFFSET, FRAME_OFFSET);
    UIImage *image = [self drawPoints:context size:frame.size
                               scaleX:_pinchScaleX
                               scaleY:1.0
                               offset:_panOffset
                        generateImage:YES];
    if (image) {
        CGContextDrawImage(context, frame, image.CGImage);
    }
#endif
    // クリッピングを最大にする。
    CGContextClipToRect(context, rect);
    CGContextTranslateCTM(context, 0.0, 0.0);
    [self drawScrollIndicator:context rect:rect];

    CGContextRestoreGState(context);
}

- (IBAction) clearBuffer:(id)sender {
    _dataTail = 0;
    for (NSUInteger i = 0; i < scopeBufferSize; i++) {
        _rawData[i] = SILENT;
    }
}

- (void) autoTrigger:(BOOL)yesNo level:(Float32)level {

    BOOL leadingEdge = NO;
    BOOL trailingEdge = NO;
    Float32 currentValue = PIANISSIMO;
    Float32 lastValue = PIANISSIMO;
    
    if (_dataTail > scopeBufferSize) {
        NSUInteger index = _dataTail;
        
        for (NSUInteger cnt = 0; cnt < scopeBufferSize; cnt++) {
            currentValue = _rawData[index % scopeBufferSize];

            if (yesNo) {
                if (lastValue < level && currentValue > level) {
                    leadingEdge = YES;
//                    DEBUG_LOG(@"leadingEdge!!");
                    _dataTail = scopeBufferSize + index;
                    break;
                }
            } else {
                if (lastValue > level && currentValue < level) {
                    trailingEdge = YES;
//                    DEBUG_LOG(@"trailingEdge!!");
                    _dataTail = scopeBufferSize + index;
                    break;
                }
            }
            lastValue = currentValue;
            index++;
        }
    }
}

- (void) enqueueData:(Float32) data {
    @synchronized (self) {
        _rawData[_dataTail++ % scopeBufferSize] = data;
    }
}

- (Float32) peekData:(NSInteger)index {
    @synchronized (self) {
        if (_dataTail <= scopeBufferSize) {
            return _rawData[index];
        } else {
            return _rawData[(index + _dataTail + (scopeBufferSize - 1)) % scopeBufferSize];
        }
    }
}

- (void) updateMySelf {
    [self setNeedsDisplay];
}

- (void) postUpdate {
    [self performSelectorOnMainThread:@selector(updateMySelf) withObject:nil waitUntilDone:NO];
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

#pragma mark - ユーザーデフォルト

- (void) setDefaults {
    
    [_pinchRecognizer setScaleX:1.0];
    [_pinchRecognizer setScaleY:DEFAULT_VOLT_RANGE];
    _pinchScaleX = 1.0;
    _pinchScaleY = DEFAULT_VOLT_RANGE;  // 1mV のスケール
    _panOffset.x = 0.0;
    _panOffset.y = 0.0;
    zoomShifter = 0;

    //    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kMathModeLinearKey];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kScopeHideRulerKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_pinchScaleX forKey:kScopePinchScaleXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_pinchScaleY forKey:kScopePinchScaleYKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kScopePanOffsetXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kScopePanOffsetYKey];
}

#pragma mark - 自動トリガーのコールバック
- (IBAction) autoTriggerAction:(id)sender {

    UISegmentedControl *trigger = (UISegmentedControl *)sender;
    NSInteger index = trigger.selectedSegmentIndex;

    if (index == 0)
    {// お節介でトリガーレベルに 0.0 を設定する。
        [_triggerLevel setValue:0.5];
        [[NSUserDefaults standardUserDefaults] setFloat:0.0 forKey:@"triggerLevel"];
        [_triggerLevel setEnabled:NO];
    } else {
        [_triggerLevel setEnabled:YES];
    }
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"autoTrigger"];
}

- (IBAction) triggerLevelAction:(id)sender {

    // -80dB 〜 80dB (-0.99999999 〜 0.99999999)
    Float32 displacement = (0.99999999 - -0.99999999) * ((UISlider *)sender).value;
    Float32 triggerLevel = -0.99999999 + displacement;

    [[NSUserDefaults standardUserDefaults] setFloat:triggerLevel forKey:@"triggerLevel"];
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
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kScopePanOffsetXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kScopePanOffsetYKey];
}

#pragma mark - レコグナイザーのコールバック

- (void) panOffsetClear {
    // パンオフセットをクリア
    _panOffset = CGPointMake(0.0, 0.0);
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kScopePanOffsetXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kScopePanOffsetYKey];
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
                                   loc2:CGPointMake([sender locationOfTouch:0 inView:self].x + _panOffset.x,
                                                    [sender locationOfTouch:0 inView:self].y + _panOffset.y)];
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
            [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kScopePanOffsetXKey];
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
            [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kScopePanOffsetYKey];
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
    
    [[NSUserDefaults standardUserDefaults] setFloat:_pinchScaleX forKey:kScopePinchScaleXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_pinchScaleY forKey:kScopePinchScaleYKey];
}

- (void) handlePinch:(UIPinchGestureRecognizerAxis *)sender {

    if ([sender numberOfTouches] >= 2) {
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

- (void) handlePan:(UIPanGestureRecognizer *)sender {
    
    DEBUG_LOG(@"%s", __func__);

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
    
    if (sender.state == UIGestureRecognizerStateBegan)
    {
        // ポーズ解除
        [_delegate setFreezeMeasurement:NO];
        _header.text = @"";
        
        [self setDefaults];
    }
}

#pragma mark - Settingsのアクション

- (IBAction) settingsAction:(id)sender {
    
//    [self hapticFeedbackMediumImpact];

    if (_settingsView.hidden) {
//        [_settingsView becomeFirstResponder];
        
        _settingsView.alpha = 0.0;
        _settingsView.hidden = NO;
        _gainLabel.hidden = NO;
        _gainSlider.hidden = NO;
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

#pragma mark - Gainのアクション
// ユーザーデフォルトに収める Mic Gain の値は 0.0dB(x1) から 40.0dB(x100)
- (IBAction) gainAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setFloat:((UISlider *) sender).value forKey:kMicGainKey];
    [self setGainInfo]; // Added on May 25, 2021 by T.M.
}

#pragma mark - Typicalのアクション

- (IBAction) typicalAction:(id)sender {
    [self fftTypicalSettings];
}

- (void) fftTypicalSettings {
    Float64 gain = [[UserDefaults sharedManager] getDefaultMicGain];

    [[NSUserDefaults standardUserDefaults] setFloat:gain forKey:kMicGainKey];
    _gainSlider.value = gain;

    [self setGainInfo]; // Added on May 25, 2021 by T.M.
}

//#define DECIBEL_OFFSET      100.0
// 未使用
- (Float64) voltsToDecibel:(Float64 *)volts {
#if 0
    Float64 one = 1.0f;
    Float64 decibel;
    // Vector convert power or amplitude to decibels; double precision.
    vDSP_vdbconD(volts, 1, &one, &decibel, 1, 1, 1); // Volt
    DEBUG_LOG(@"%gdB", decibel);
//    decibel += DECIBEL_OFFSET;
    return decibel;
#else
    // 対数の値は dB(20log()) の 1/20
    return 20.0 * log10(*volts);
#endif
}

// Start Add on May 25, 2021 by T.M.
- (void) setGainInfo {
    
    Float32 gain = [[NSUserDefaults standardUserDefaults] floatForKey:kMicGainKey];
    Float64 multiplier = pow(10, gain); // Pa/FS の 1/2 が有効な倍率だが見かけを2倍になどしない。
    Float64 dB = [self voltsToDecibel:&multiplier];

    _gainInfo.text = [NSString stringWithFormat:@"%.1fdB (x%.1f)", dB, multiplier];
    _gainSlider.value = gain;
}
// End Add on May 25, 2021 by T.M.
@end
