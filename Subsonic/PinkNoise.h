/*
    Sonic Tools SVM (FFT Analyzer/RTA for iOS)
    Copyright (C) 2017-2024  Takuji Matsugaki

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
//  PinkNoiseFFT.h

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

#define NUM_FILTERS 7

@interface PinkNoise : NSObject {
    Float32 _pinkNoise[NUM_FILTERS];
    Float32 _whiteNoise;
}

- (void)processBuffer:(Float32 *)buffer withFrameSize:(UInt32)frameSize;
@end
