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
//  UIPinchGestureRecognizerAxis.h

#import <UIKit/UIKit.h>

#define MIN_PINCH_DIVISER   1.0
#define MAX_PINCH_DIVISER   16.0

@interface UIPinchGestureRecognizerAxis : UIPinchGestureRecognizer {
    CGFloat scaleX;
    CGFloat scaleY;
    CGFloat scaleSaveX;
    CGFloat scaleSaveY;

    CGPoint startLoc[2];
    CGPoint currentLoc[2];
    CGRect pinchStartRect;
    CGRect currentPinchRect;
    CGFloat localScaleX;
    CGFloat localScaleY;
}
- (void) setScaleX:(CGFloat)scale;
- (void) setScaleY:(CGFloat)scale;
- (CGFloat) getScaleX;
- (CGFloat) getScaleY;

- (CGPoint) startLocation;
- (void) createStartRect:(UIView *)view loc1:(CGPoint)loc1 loc2:(CGPoint)loc2;
- (void) createCurrentRect:(UIView *)view loc1:(CGPoint)loc1 loc2:(CGPoint)loc2;
//- (void) setPoint:(UIView *)view loc1:(CGPoint)loc1 loc2:(CGPoint)loc2;
- (void) limitScaleX:(CGFloat)scale;
- (void) limitScaleY:(CGFloat)scale;
@end
