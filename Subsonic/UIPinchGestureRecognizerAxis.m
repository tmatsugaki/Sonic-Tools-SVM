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
//  UIPinchGestureRecognizerAxis.m

#import "UIPinchGestureRecognizerAxis.h"

@implementation UIPinchGestureRecognizerAxis

- (id) initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:(id)target action:(SEL)action];
    if (self != nil) {
        scaleX = 1.0;
        scaleY = 1.0;
        scaleSaveX = 1.0;
        scaleSaveY = 1.0;
/* 
 CGPoint startLoc[2];
 CGPoint currentLoc[2];
 CGRect pinchStartRect;
 CGRect pinchRect;
 CGFloat localScaleX;
 CGFloat localScaleY;
 */
    }
    return self;
}

- (void) setScaleX:(CGFloat)scale {
    switch (self.state) {
        case UIGestureRecognizerStateBegan:
            scaleX = 1.0;
            scaleSaveX = scale;
            break;
        case UIGestureRecognizerStateChanged:
            scaleX = scale;
            if (scaleX * scaleSaveX < MIN_PINCH_DIVISER)
            {// 1.0 以下は禁止
                scaleX = MIN_PINCH_DIVISER / scaleSaveX;
            } else if (scaleX * scaleSaveX > MAX_PINCH_DIVISER)
            {// 8.0 以上は禁止
                scaleX = MAX_PINCH_DIVISER / scaleSaveX;
            }
            break;
        case UIGestureRecognizerStateEnded:
            scaleX = 1.0;
            scaleSaveX = scale;
            break;
        default:
            scaleX = scale;
            scaleSaveX = 1.0;
            break;
    }
}

- (void) setScaleY:(CGFloat)scale {
    switch (self.state) {
        case UIGestureRecognizerStateBegan:
            scaleY = 1.0;
            scaleSaveY = scale;
            break;
        case UIGestureRecognizerStateChanged:
            scaleY = scale;
            if (scaleY * scaleSaveY < MIN_PINCH_DIVISER)
            {// 1.0 以下は禁止
                scaleY = MIN_PINCH_DIVISER / scaleSaveY;
            } else if (scaleY * scaleSaveY > MAX_PINCH_DIVISER)
            {// 8.0 以上は禁止
                scaleY = MAX_PINCH_DIVISER / scaleSaveY;
            }
            break;
        case UIGestureRecognizerStateEnded:
            scaleY = 1.0;
            scaleSaveY = scale;
            break;
        default:
            scaleY = scale;
            scaleSaveY = 1.0;
            break;
    }
}

- (CGFloat) getScaleX {
    return scaleX * scaleSaveX;
}

- (CGFloat) getScaleY {
    return scaleY * scaleSaveY;
}

- (void) createStartRect:(UIView *)view loc1:(CGPoint)loc1 loc2:(CGPoint)loc2 {
    startLoc[0] = [self locationOfTouch:0 inView:view];
    startLoc[1] = [self locationOfTouch:1 inView:view];
    pinchStartRect = CGRectMake(startLoc[0].x,
                                startLoc[0].y,
                                startLoc[1].x - startLoc[0].x,
                                startLoc[1].y - startLoc[0].y);
}

- (void) createCurrentRect:(UIView *)view loc1:(CGPoint)loc1 loc2:(CGPoint)loc2 {
    currentLoc[0] = [self locationOfTouch:0 inView:view];
    currentLoc[1] = [self locationOfTouch:1 inView:view];
    currentPinchRect = CGRectMake(currentLoc[0].x,
                                  currentLoc[0].y,
                                  currentLoc[1].x - currentLoc[0].x,
                                  currentLoc[1].y - currentLoc[0].y);
    
    localScaleX = fabs(currentPinchRect.size.width / pinchStartRect.size.width);
    if (pinchStartRect.size.width) {
        // scaleX:localScaleX, scaleSaveX:N/C(当初の_pinchScaleX)
        [self setScaleX:localScaleX];
    }
    localScaleY = fabs(currentPinchRect.size.height / pinchStartRect.size.height);
    if (pinchStartRect.size.height) {
        // scaleY:localScaleY, scaleSaveY:N/C(当初の_pinchScaleY)
        [self setScaleY:localScaleY];
    }
    //      DEBUG_LOG(@"move :[%g][%g]", pinchRect.origin.x - pinchStartRect.origin.x    , pinchRect.origin.y - pinchStartRect.origin.y);
    //      DEBUG_LOG(@"reize:[%g][%g]", _pinchRecognizer.scaleX, _pinchRecognizer.scaleY);
}

- (void) limitScaleX:(CGFloat)scale {
    scaleX = scale / scaleSaveX;
}

- (void) limitScaleY:(CGFloat)scale {
    scaleY = scale / scaleSaveY;
}

- (CGPoint) startLocation {
    return CGPointMake((startLoc[0].x + startLoc[1].x) / 2.0, (startLoc[0].y + startLoc[1].y) / 2.0);
}

- (void) setPoint:(UIView *)view loc1:(CGPoint)loc1 loc2:(CGPoint)loc2 {
    switch (self.state) {
        case UIGestureRecognizerStateBegan:
            startLoc[0] = [self locationOfTouch:0 inView:view];
            startLoc[1] = [self locationOfTouch:1 inView:view];
            pinchStartRect = CGRectMake(startLoc[0].x,
                                        startLoc[0].y,
                                        startLoc[1].x - startLoc[0].x,
                                        startLoc[1].y - startLoc[0].y);
            break;
        case UIGestureRecognizerStateChanged:
            currentLoc[0] = [self locationOfTouch:0 inView:view];
            currentLoc[1] = [self locationOfTouch:1 inView:view];
            currentPinchRect = CGRectMake(currentLoc[0].x,
                                          currentLoc[0].y,
                                          currentLoc[1].x - currentLoc[0].x,
                                          currentLoc[1].y - currentLoc[0].y);

            localScaleX = fabs(currentPinchRect.size.width / pinchStartRect.size.width);
            if (pinchStartRect.size.width) {
                // scaleX:localScaleX, scaleSaveX:N/C(当初の_pinchScaleX)
                [self setScaleX:localScaleX];
            }
            localScaleY = fabs(currentPinchRect.size.height / pinchStartRect.size.height);
            if (pinchStartRect.size.height) {
                // scaleY:localScaleY, scaleSaveY:N/C(当初の_pinchScaleY)
                [self setScaleY:localScaleY];
            }
//            DEBUG_LOG(@"move :[%g][%g]", pinchRect.origin.x - pinchStartRect.origin.x    , pinchRect.origin.y - pinchStartRect.origin.y);
//            DEBUG_LOG(@"reize:[%g][%g]", _pinchRecognizer.scaleX, _pinchRecognizer.scaleY);
            break;
        default:
            break;
    }
}
@end
