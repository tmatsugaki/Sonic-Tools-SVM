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
//  HorizontalIndicator.m

#import "ScrollIndicator.h"

@implementation ScrollIndicator

- (void)drawRect:(CGRect)rect {
    // コンテントの描画
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    CGContextSetLineWidth(context, kScrollBarLineWidth);
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:kScrollBarAlpha].CGColor);
    
    CGContextBeginPath(context);
    if (self.frame.size.width > self.frame.size.height) {
        CGContextMoveToPoint(context, _leadingRatio * self.frame.size.width, 0.0);
        CGContextAddLineToPoint(context, _contentRatio * self.frame.size.width, 0.0);
    } else {
        CGContextMoveToPoint(context, 0.0, _leadingRatio * self.frame.size.height);
        CGContextAddLineToPoint(context, 0.0, _contentRatio * self.frame.size.height);
    }
    CGContextStrokePath(context);

    CGContextRestoreGState(context);
}
@end
