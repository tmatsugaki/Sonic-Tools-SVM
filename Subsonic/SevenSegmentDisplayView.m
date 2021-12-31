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
//  SevenSegmentDisplayView.m

#import <QuartzCore/CALayer.h>
#import "SevenSegmentDisplayView.h"
#import "Environment.h"
#import "ColorUtil.h"

@implementation SevenSegmentDisplayView

#pragma mark - View lifecycle

// 上から順に追加する。
- (void) layoutSubviews {
	
//	DEBUG_LOG(@"%s", __func__);

    // 【注意】背景をクリアカラーに設定し、opaque = NO にすること。
	self.backgroundColor = [UIColor clearColor];

    // このビューの背景色を親ビューの背景色に設定する。
//    [self superview].backgroundColor = [[self superview] superview].backgroundColor;
}

- (void) drawSegment:(CGContextRef)context
               frame:(CGRect)frame
             segment:(char)segment {

    CGFloat dx = frame.size.width  / 4.0;
    CGFloat dy = frame.size.height / 4.0;
    CGFloat x[5];
    CGFloat y[5];
    CGFloat unit = dx;
    CGFloat half = unit / kHalfRatio;   // 4分の1
    CGFloat gap  = unit / kGapRatio;    // 6分の1
    CGFloat halfGap = gap / 2.0;
    
    x[0] = 0;
    x[1] = dx;
    x[2] = 2 * dx;
    x[3] = 3 * dx;
    x[4] = 4 * dx;
    
    y[0] = 0;
    y[1] = dy;
    y[2] = 2 * dy;
    y[3] = 3 * dy;
    y[4] = 4 * dy;

    CGContextBeginPath(context);
#if 0
    switch (segment) {
        case 'a':
            CGContextMoveToPoint(context   , x[1] - half, y[1] - half);
            CGContextAddLineToPoint(context, x[3] + half, y[1] - half);
            CGContextAddLineToPoint(context, x[3] - half, y[1] + half);
            CGContextAddLineToPoint(context, x[1] + half, y[1] + half);
            break;
        case 'b':
            CGContextMoveToPoint(context   , x[3] + half, y[1] - half + gap);
            CGContextAddLineToPoint(context, x[3] + half, y[2] - (gap + half));
            CGContextAddLineToPoint(context, x[3]       , y[2] - (gap));
            CGContextAddLineToPoint(context, x[3] - half, y[2] - (gap + half));
            CGContextAddLineToPoint(context, x[3] - half, y[1] + (gap + half));
            break;
        case 'c':
            CGContextMoveToPoint(context   , x[3]       , y[2] + (gap));
            CGContextAddLineToPoint(context, x[3] + half, y[2] + (gap + half));
            CGContextAddLineToPoint(context, x[3] + half, y[3] + half - (gap));
            CGContextAddLineToPoint(context, x[3] - half, y[3] - (gap + half));
            CGContextAddLineToPoint(context, x[3] - half, y[2] + (gap + half));
            break;
        case 'd':
            CGContextMoveToPoint(context   , x[3] - half, y[3] - half);
            CGContextAddLineToPoint(context, x[1] + half, y[3] - half);
            CGContextAddLineToPoint(context, x[1] - half, y[3] + half);
            CGContextAddLineToPoint(context, x[3] + half, y[3] + half);
            break;
        case 'e':
            CGContextMoveToPoint(context   , x[1]       , y[2] + (gap));
            CGContextAddLineToPoint(context, x[1] + half, y[2] + (gap + half));
            CGContextAddLineToPoint(context, x[1] + half, y[3] - (half + gap));
            CGContextAddLineToPoint(context, x[1] - half, y[3] + half - (gap));
            CGContextAddLineToPoint(context, x[1] - half, y[2] + (gap + half));
            break;
        case 'f':
            CGContextMoveToPoint(context   , x[1] - half, y[1] - half + gap);
            CGContextAddLineToPoint(context, x[1] + half, y[1] + (gap + half));
            CGContextAddLineToPoint(context, x[1] + half, y[2] - (gap + half));
            CGContextAddLineToPoint(context, x[1]       , y[2] - (gap));
            CGContextAddLineToPoint(context, x[1] - half, y[2] - (gap + half));
            CGContextAddLineToPoint(context, x[1] - half, y[1] + (gap + half));
            break;
        case 'g':
            CGContextMoveToPoint(context   , x[1]       , y[2]);
            CGContextAddLineToPoint(context, x[1] + half, y[2] - half);
            CGContextAddLineToPoint(context, x[3] - half, y[2] - half);
            CGContextAddLineToPoint(context, x[3]       , y[2]);
            CGContextAddLineToPoint(context, x[3] - half, y[2] + half);
            CGContextAddLineToPoint(context, x[1] + half, y[2] + half);
            break;
    }
#else
    switch (segment) {
        case 'a':
            CGContextMoveToPoint(context   , x[1] - half, y[1] - half);
            CGContextAddLineToPoint(context, x[3] + half, y[1] - half);
            CGContextAddLineToPoint(context, x[3] - half, y[1] + half);
            CGContextAddLineToPoint(context, x[1] + half, y[1] + half);
            break;
        case 'b':
            CGContextMoveToPoint(context   , x[3] + half    , y[1] - half + gap);
            CGContextAddLineToPoint(context, x[3] + half    , y[2] - (gap + half) + gap);   //
            CGContextAddLineToPoint(context, x[3] + halfGap , y[2] - (gap) + halfGap);      //
            CGContextAddLineToPoint(context, x[3] - half    , y[2] - (gap + half));
            CGContextAddLineToPoint(context, x[3] - half    , y[1] + (gap + half));
            break;
        case 'c':
            CGContextMoveToPoint(context   , x[3] + halfGap , y[2] + (gap) - halfGap);      //
            CGContextAddLineToPoint(context, x[3] + half    , y[2] + (gap + half) - halfGap);   //
            CGContextAddLineToPoint(context, x[3] + half    , y[3] + half - (gap));
            CGContextAddLineToPoint(context, x[3] - half    , y[3] - (gap + half));
            CGContextAddLineToPoint(context, x[3] - half    , y[2] + (gap + half));
            break;
        case 'd':
            CGContextMoveToPoint(context   , x[3] - half, y[3] - half);
            CGContextAddLineToPoint(context, x[1] + half, y[3] - half);
            CGContextAddLineToPoint(context, x[1] - half, y[3] + half);
            CGContextAddLineToPoint(context, x[3] + half, y[3] + half);
            break;
        case 'e':
            CGContextMoveToPoint(context   , x[1] - halfGap , y[2] + (gap) - halfGap);      //
            CGContextAddLineToPoint(context, x[1] + half    , y[2] + (gap + half));
            CGContextAddLineToPoint(context, x[1] + half    , y[3] - (half + gap));
            CGContextAddLineToPoint(context, x[1] - half    , y[3] + half - (gap));
            CGContextAddLineToPoint(context, x[1] - half    , y[2] + (gap + half - halfGap));
            break;
        case 'f':
            CGContextMoveToPoint(context   , x[1] - half    , y[1] - half + gap);
            CGContextAddLineToPoint(context, x[1] + half    , y[1] + (gap + half));
            CGContextAddLineToPoint(context, x[1] + half    , y[2] - (gap + half));
            CGContextAddLineToPoint(context, x[1] - halfGap , y[2] - (gap) + halfGap);          //
            CGContextAddLineToPoint(context, x[1] - half    , y[2] - (gap + half) + gap);   //
            CGContextAddLineToPoint(context, x[1] - half    , y[1] + (gap + half));
            break;
        case 'g':
            CGContextMoveToPoint(context   , x[1]       , y[2]);
            CGContextAddLineToPoint(context, x[1] + half, y[2] - half);
            CGContextAddLineToPoint(context, x[3] - half, y[2] - half);
            CGContextAddLineToPoint(context, x[3]       , y[2]);
            CGContextAddLineToPoint(context, x[3] - half, y[2] + half);
            CGContextAddLineToPoint(context, x[1] + half, y[2] + half);
            break;
    }
#endif
    CGContextClosePath(context);
    CGContextFillPath(context);
}

- (void) drawSegments:(CGContextRef) context
                frame:(CGRect)frame {
#if (LOG == ON)
    //	DEBUG_LOG(@"%s", __func__);
#endif
    
    UIColor *backColor = nil;
    UIColor *offColor = nil;
    UIColor *onColor = nil;

    NSInteger displayMode = [[NSUserDefaults standardUserDefaults] integerForKey:kDisplayModeKey];

    switch (displayMode) {
        case kDisplayModeLCD:
            onColor   = [ColorUtil lcdOn];
            offColor  = [ColorUtil lcdOff:lcdOffAlpha];
            backColor = [ColorUtil lcdBase];
            // LCD はシックで良いが、背景が黒っぽい環境では非常に視認性が悪い。
            // 背景を基板の色で塗る。
            switch (_status) {
                case DCELL_SHUTDOWN:
                    CGContextSetFillColorWithColor(context, backColor.CGColor);
                    break;
                case DCELL_LEVEL_OFF:
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    break;
                case DCELL_LEVEL_ON:
                    CGContextSetFillColorWithColor(context, onColor.CGColor);
                    break;
            }
            break;

        case kDisplayModeVFD:
            onColor   = [ColorUtil vfdOn];
            offColor  = [ColorUtil vfdOff:vfdOffAlpha];
            backColor = [ColorUtil vfdOff:vfdOffAlpha];
            // VFD の色が視認性も良いし、シック。
            switch (_status) {
                case DCELL_SHUTDOWN:
                    // 背景をオフの色で塗る。
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    break;
                case DCELL_LEVEL_OFF:
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    break;
                case DCELL_LEVEL_ON:
                    CGContextSetFillColorWithColor(context, onColor.CGColor);
                    break;
            }
            // フレアを描きたい！！
            break;
    }
    if (_status) {
        switch (self.tag) {
            case 0:
                [self drawSegment:context frame:frame segment:'a'];
                [self drawSegment:context frame:frame segment:'b'];
                [self drawSegment:context frame:frame segment:'c'];
                [self drawSegment:context frame:frame segment:'d'];
                [self drawSegment:context frame:frame segment:'e'];
                [self drawSegment:context frame:frame segment:'f'];
                if (! _lazy) {
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    [self drawSegment:context frame:frame segment:'g'];
                }
                break;
            case 1:
                [self drawSegment:context frame:frame segment:'b'];
                [self drawSegment:context frame:frame segment:'c'];
                if (! _lazy) {
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    [self drawSegment:context frame:frame segment:'a'];
                    [self drawSegment:context frame:frame segment:'d'];
                    [self drawSegment:context frame:frame segment:'e'];
                    [self drawSegment:context frame:frame segment:'f'];
                    [self drawSegment:context frame:frame segment:'g'];
                }
                break;
            case 2:
                [self drawSegment:context frame:frame segment:'a'];
                [self drawSegment:context frame:frame segment:'b'];
                [self drawSegment:context frame:frame segment:'d'];
                [self drawSegment:context frame:frame segment:'e'];
                [self drawSegment:context frame:frame segment:'g'];
                if (! _lazy) {
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    [self drawSegment:context frame:frame segment:'c'];
                    [self drawSegment:context frame:frame segment:'f'];
                }
                break;
            case 3:
                [self drawSegment:context frame:frame segment:'a'];
                [self drawSegment:context frame:frame segment:'b'];
                [self drawSegment:context frame:frame segment:'c'];
                [self drawSegment:context frame:frame segment:'d'];
                [self drawSegment:context frame:frame segment:'g'];
                if (! _lazy) {
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    [self drawSegment:context frame:frame segment:'e'];
                    [self drawSegment:context frame:frame segment:'f'];
                }
                break;
            case 4:
                [self drawSegment:context frame:frame segment:'b'];
                [self drawSegment:context frame:frame segment:'c'];
                [self drawSegment:context frame:frame segment:'f'];
                [self drawSegment:context frame:frame segment:'g'];
                if (! _lazy) {
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    [self drawSegment:context frame:frame segment:'a'];
                    [self drawSegment:context frame:frame segment:'d'];
                    [self drawSegment:context frame:frame segment:'e'];
                }
                break;
            case 5:
                [self drawSegment:context frame:frame segment:'a'];
                [self drawSegment:context frame:frame segment:'c'];
                [self drawSegment:context frame:frame segment:'d'];
                [self drawSegment:context frame:frame segment:'f'];
                [self drawSegment:context frame:frame segment:'g'];
                if (! _lazy) {
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    [self drawSegment:context frame:frame segment:'b'];
                    [self drawSegment:context frame:frame segment:'e'];
                }
                break;
            case 6:
                [self drawSegment:context frame:frame segment:'a'];
                [self drawSegment:context frame:frame segment:'c'];
                [self drawSegment:context frame:frame segment:'d'];
                [self drawSegment:context frame:frame segment:'e'];
                [self drawSegment:context frame:frame segment:'f'];
                [self drawSegment:context frame:frame segment:'g'];
                if (! _lazy) {
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    [self drawSegment:context frame:frame segment:'b'];
                }
                break;
            case 7:
                [self drawSegment:context frame:frame segment:'a'];
                [self drawSegment:context frame:frame segment:'b'];
                [self drawSegment:context frame:frame segment:'c'];
                if (! _lazy) {
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    [self drawSegment:context frame:frame segment:'d'];
                    [self drawSegment:context frame:frame segment:'e'];
                    [self drawSegment:context frame:frame segment:'f'];
                    [self drawSegment:context frame:frame segment:'g'];
                }
                break;
            case 8:
                [self drawSegment:context frame:frame segment:'a'];
                [self drawSegment:context frame:frame segment:'b'];
                [self drawSegment:context frame:frame segment:'c'];
                [self drawSegment:context frame:frame segment:'d'];
                [self drawSegment:context frame:frame segment:'e'];
                [self drawSegment:context frame:frame segment:'f'];
                [self drawSegment:context frame:frame segment:'g'];
                break;
            case 9:
                [self drawSegment:context frame:frame segment:'a'];
                [self drawSegment:context frame:frame segment:'b'];
                [self drawSegment:context frame:frame segment:'c'];
                [self drawSegment:context frame:frame segment:'d'];
                [self drawSegment:context frame:frame segment:'f'];
                [self drawSegment:context frame:frame segment:'g'];
                if (! _lazy) {
                    CGContextSetFillColorWithColor(context, offColor.CGColor);
                    [self drawSegment:context frame:frame segment:'e'];
                }
                break;
        }
    } else {
        CGContextSetFillColorWithColor(context, offColor.CGColor);
        [self drawSegment:context frame:frame segment:'a'];
        [self drawSegment:context frame:frame segment:'b'];
        [self drawSegment:context frame:frame segment:'c'];
        [self drawSegment:context frame:frame segment:'d'];
        [self drawSegment:context frame:frame segment:'e'];
        [self drawSegment:context frame:frame segment:'f'];
        [self drawSegment:context frame:frame segment:'g'];
    }
}

- (void) drawRect:(CGRect)rect {
	
#if (LOG == ON)
//	DEBUG_LOG(@"%s", __func__);
#endif
//	self.clipsToBounds = YES;

    CGRect frame = rect;
    // コンテントの描画
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    [self drawSegments:context frame:frame];
    CGContextRestoreGState(context);
}
@end
