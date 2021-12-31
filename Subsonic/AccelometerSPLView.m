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
//  AccelometerSPLView.m

#import <Accelerate/Accelerate.h>
#import "ColorUtil.h"
#import "AccelometerSPLViewController.h"
#import "AccelometerSPLView.h"
#import "ScrollIndicator.h"

@implementation AccelometerSPLView

// Designated initializer
- (id) initWithCoder:(NSCoder*)decoder
{
    self = [super initWithCoder:decoder];
    if (self != nil) {
        self.rawData = malloc(Accelo_SPL_BUFFER_SIZE * sizeof(Float32));
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
        UIPanGestureRecognizer *panRecognizer =
        [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(handlePan:)];
        [self addGestureRecognizer:panRecognizer];
        /*
         * 長押しレコグナイザーを追加する。
         */
        UILongPressGestureRecognizer *longPressRecognizer =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(handleLongPress:)];
        [self addGestureRecognizer:longPressRecognizer];
        
        _pinchScaleX = [[NSUserDefaults standardUserDefaults] floatForKey:kAcceloSPLPinchScaleXKey];
        _pinchScaleY = [[NSUserDefaults standardUserDefaults] floatForKey:kAcceloSPLPinchScaleYKey];
        _panOffset.x = [[NSUserDefaults standardUserDefaults] floatForKey:kAcceloSPLPanOffsetXKey];
        _panOffset.y = [[NSUserDefaults standardUserDefaults] floatForKey:kAcceloSPLPanOffsetYKey];
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
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kAcceloSPLCSVKey];
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

//    UITraitCollection *trait = self.traitCollection;
//
//    if ([trait userInterfaceStyle] == UIUserInterfaceStyleDark) {
//        if (@available(iOS 13.0, *)) {
//            [_clearButton setBackgroundColor:[UIColor systemBackgroundColor]];
//        } else {
//            [_clearButton setBackgroundColor:[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0]];
//        }
//    } else {
        [_clearButton setBackgroundColor:[UIColor whiteColor]];
//    }

#if (CENTERING == ON)
    CGRect rect = self.frame;
    CGRect frame = CGGraphRectMake(rect);
    [self maintainScrollableArea:frame];
    [self maintainPinch];
    [self maintainPan];
#else
    [self maintainPinch];
#endif
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

    if (((AccelometerSPLViewController *) _delegate).freeze) {
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
    CGRect frame = CGGraphRectMake(rect);
    Float32 volumeDecades = 10;
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
    static NSInteger dbLabel[] = {10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0};
    for (NSUInteger i = 0; i < volumeDecades + 1; i++) {
        NSString *title = [NSString stringWithFormat:@"%ld", (long)dbLabel[i]];
        Float32 hOffset = 10.5 * [title length] / 2.0; // 15
        CGPoint point = CGPointMake((org_x - hOffset), org_y + (db_ruler_delta * i - 5.0) + offset.y);
        
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
    BOOL isHideRuler = [[NSUserDefaults standardUserDefaults] boolForKey:kAcceloSPLHideRulerKey];
    Float32 volumeDecades = 10;
    Float32 org_x = frame.origin.x;
    Float32 org_y = frame.origin.y;
    Float32 width = frame.size.width * scaleX;
    Float32 db_ruler_delta = scaleY * frame.size.height / volumeDecades;
    
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
    //    BOOL isHideRuler = [[NSUserDefaults standardUserDefaults] boolForKey:kAcceloScopeHideRulerKey];
    Float32 org_x = frame.origin.x;
    Float32 org_y = frame.origin.y;
    Float32 width = frame.size.width * scaleX;
    Float32 bot_y = org_y + frame.size.height;
    
    UIFont *font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:11.0];
    UIColor *color = nil;
    
    CGContextSetLineWidth(context, 0.2);
    // 横ステップ
    color = [ColorUtil vfdOn];
    CGContextSetStrokeColorWithColor(context, [ColorUtil vfdOn].CGColor);
    CGContextSetFillColorWithColor(context, [ColorUtil vfdOn].CGColor);
    // リニア縦罫線
    CGContextBeginPath(context);
    NSUInteger times = Accelo_SPL_BUFFER_SIZE / 32.0;
    Float32 ruler_dh = width / times;
    NSUInteger mod = scaleX > 2.0 ? 1 : 5;
    
    for (NSUInteger i = 0; i <= times; i++) {
        Float32 hpos = ruler_dh * i + org_x;
        if (i && (i % mod) == 0) {
            NSString *title = [NSString stringWithFormat:@"%lus", i];
            Float32 hOffset = 7.0 * [title length] / 2.0; // 6.0
            CGPoint point = CGPointMake(hpos - hOffset + offset.x, bot_y + 2);
            [title drawAtPoint:point withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color}];
        }
        if (i > 0 && hpos + offset.x >= FRAME_OFFSET)
        {
            CGContextMoveToPoint(context   , hpos + offset.x, org_y);
            CGContextAddLineToPoint(context, hpos + offset.x, bot_y);
        }
    }
    CGContextStrokePath(context);
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
    Float32 width = size.width * scaleX;;
    Float32 height = size.height * scaleY;
    Float32 volumeDecades = 10;
    
    UIGraphicsBeginImageContext(size);
    
// drawAtPoint:withAttributes: が上下反転しているのを補正する。
//    CGContextTranslateCTM(context, 0, frame.size.height);
//    CGContextScaleCTM(context, scale, -scale);
    
//    BOOL fill = NO;
//    BOOL isHideRuler = [[NSUserDefaults standardUserDefaults] boolForKey:kHideRulerKey];
    Float32 org_x = 0.0;
    Float32 org_y = 0.0;
    Float32 bot_y = org_y + height;
//    Float32 db_ruler_delta = height / volumeDecades;
    
    // データのプロット
    CGContextSetLineWidth(context, 1.0);
//    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.4].CGColor);
    
    CGContextSetStrokeColorWithColor(context, [UIColor redColor].CGColor);
    CGContextBeginPath(context);
    for (NSUInteger i = 0; i < Accelo_SPL_BUFFER_SIZE; i++) {
        Float32 fract;
        Float32 hpos;
        Float32 volumeOffset;
        Float32 rawAccel = [self peekData:i];
        volumeOffset = height * rawAccel / volumeDecades;    // -160dB〜0dB (160dB log10(100000000)=8)
        fract = (1.0 * i / ((Float32) Accelo_SPL_BUFFER_SIZE));
        if (i == 0) {
            hpos = org_x + 1.0;
            CGContextMoveToPoint(context   , hpos + offset.x, bot_y - volumeOffset + offset.y);
        } else {
            hpos = (fract * width) + org_x;
            if (volumeOffset) {// ratio == 0.0
                CGContextAddLineToPoint(context, hpos + offset.x, bot_y - volumeOffset + offset.y);
            }
        }
        if (rawAccel > PIANISSIMO) {
            self.rawAccel = rawAccel;
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
    _scrollLimit.y = (frame.size.height * [_pinchRecognizer getScaleY]) - (frame.size.height);
}

- (void) drawRect:(CGRect)rect {
    
    Float32 decibel, db;
    
    if (_rmsValue > 0.99 && _rmsValue < 1.0) {
        _rmsValue = 1.0;
    }
    decibel = _rmsValue;
    db = decibel;
    
    // 10の位
    db = fmod(db, 100.0);
    if (decibel >= 10.0) {
        _f2.status = DCELL_LEVEL_ON;
        _f2.tag = (int) floor(db / 10.0);
    } else {
        _f2.status = DCELL_SHUTDOWN;
    }
    // 1の位
    db = fmod(db, 10.0);
    if (decibel >= 1.0) {
        _f1.status = DCELL_LEVEL_ON;
        _f1.tag = (int) floor(db / 1.0);
    } else {
//        _f1.status = DCELL_SHUTDOWN;
        _f1.status = DCELL_LEVEL_ON;
        _f1.tag = 0;
    }
    // 0.1の位
    db = fmod(10.0 * db, 10.0);
    _f0.status = DCELL_LEVEL_ON;  // 常時ON
    _f0.tag = (int) floor(db);

    self.lblMaxRMS.text = [NSString stringWithFormat:@"%.1f", _maxRMS];
#if (LOAD_DUMMY_DATA && TARGET_IPHONE_SIMULATOR)
    self.lblAvgRMS.text = [NSString stringWithFormat:@"%.1f", _maxRMS];
#else
    self.lblAvgRMS.text = [NSString stringWithFormat:@"%.1f", _avgRMS];
#endif
    self.lblMinRMS.text = [NSString stringWithFormat:@"%.1f", _minRMS];
    
//    DEBUG_LOG(@"%g->%gdB [%lu%lu.%lu]", rmsValue, decibel[i], (long)accelometer_spl_view.f2.tag, (long)accelometer_spl_view.f1.tag, (long)accelometer_spl_view.f0.tag);

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
                       size:frame.size
                     scaleX:_pinchScaleX
                     scaleY:_pinchScaleY
                     offset:_panOffset
              generateImage:NO];
#else
    // クリッピングを frame に制限する。
    CGContextClipToRect(context, frame);
    CGContextTranslateCTM(context, FRAME_OFFSET, FRAME_OFFSET);
    UIImage *image = [self drawPoints:context
                                 size:frame.size
                               scaleX:_pinchScaleX
                               scaleY:_pinchScaleY
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
    for (NSUInteger i = 0; i < Accelo_SPL_BUFFER_SIZE; i++) {
        _rawData[i] = PIANISSIMO;
    }
    [((AccelometerSPLViewController *) _delegate) initAccelometerSPL];
}

- (void) enqueueData:(Float32) data {
    @synchronized (self) {
        _rawData[_dataTail++ % Accelo_SPL_BUFFER_SIZE] = data;
    }
}

- (Float32) peekData:(NSInteger)index {
    
    Float32 value = PIANISSIMO;
    
    @synchronized (self) {
        if (_dataTail <= Accelo_SPL_BUFFER_SIZE) {
            value = _rawData[index];
        } else {
            value = _rawData[(index + _dataTail + (Accelo_SPL_BUFFER_SIZE - 1)) % Accelo_SPL_BUFFER_SIZE];
        }
    }
    return value;
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
    [_pinchRecognizer setScaleY:1.0];
    _pinchScaleX = 1.0;
    _pinchScaleY = 1.0;
    _panOffset.x = 0.0;
    _panOffset.y = 0.0;
    zoomShifter = 0;

    //    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kMathModeLinearKey];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kAcceloSPLHideRulerKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_pinchScaleX forKey:kAcceloSPLPinchScaleXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_pinchScaleY forKey:kAcceloSPLPinchScaleYKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kAcceloSPLPanOffsetXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kAcceloSPLPanOffsetYKey];
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
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kAcceloSPLPanOffsetXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kAcceloSPLPanOffsetYKey];
}

#pragma mark - レコグナイザーのコールバック

- (void) panOffsetClear {
    // パンオフセットをクリア
    _panOffset = CGPointMake(0.0, 0.0);
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kAcceloSPLPanOffsetXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kAcceloSPLPanOffsetYKey];
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
            [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.x forKey:kAcceloSPLPanOffsetXKey];
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
            [[NSUserDefaults standardUserDefaults] setFloat:_panOffset.y forKey:kAcceloSPLPanOffsetYKey];
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
    
    [[NSUserDefaults standardUserDefaults] setFloat:_pinchScaleX forKey:kAcceloSPLPinchScaleXKey];
    [[NSUserDefaults standardUserDefaults] setFloat:_pinchScaleY forKey:kAcceloSPLPinchScaleYKey];
}

- (void) handlePinch:(UIPinchGestureRecognizerAxis *)sender {

    DEBUG_LOG(@"%s scale[%g] state[%ld]", __func__, _pinchRecognizer.scale, (long)sender.state);
    
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

#pragma mark - Stop,Play/Pause のコールバック関係

enum {
    CSV_Stop,
    CSV_Rec
#if (CSV_OUT_ONE_BUTTON == OFF)
    , CSV_Pause
#endif
};

//#define kFileNamePrefix     @"Vibration RMS"

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
    [[NSUserDefaults standardUserDefaults] setInteger:newCSV forKey:kAcceloSPLCSVKey];
    
    [self closeCSV];
}

- (IBAction) playPauseAction:(id)sender {
    
    NSUInteger oldPlayPause = [[NSUserDefaults standardUserDefaults] integerForKey:kAcceloSPLCSVKey];
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
    [[NSUserDefaults standardUserDefaults] setInteger:newPlayPause forKey:kAcceloSPLCSVKey];
}

- (void) openCSV {
    //    ドキュメントフォルダ/log.txt
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* dir = [paths objectAtIndex:0];
    NSString *fileName = [NSString stringWithFormat:@"%@_%@.csv", NSLocalizedString(@"VIB RMS", @""), [_fileDateFormatter stringFromDate:[NSDate date]]];
    NSString* path = [dir stringByAppendingPathComponent:fileName];
    self.fp = fopen([path UTF8String], "a");
    if (_fp) {
        fprintf(_fp, "Timestamp,Acceleration(G)\n");
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
    NSUInteger oldPlayPause = [[NSUserDefaults standardUserDefaults] integerForKey:kAcceloSPLCSVKey];
    
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
            NSString *str = [NSString stringWithFormat:@"%@,%g\n", [_dataDateFormatter stringFromDate:[NSDate date]], _rawAccel];
            fprintf(_fp, "%s", [str UTF8String]);
            DEBUG_LOG(@"%@", str);
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
@end
