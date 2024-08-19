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
#ifndef ShazamTest_FFTHelper_h
#define ShazamTest_FFTHelper_h

#import <Accelerate/Accelerate.h>
#include <MacTypes.h>

#ifdef DEBUG
#define DEBUG_LOG(...) NSLog(__VA_ARGS__)
#define LOG_CURRENT_METHOD NSLog(NSStringFromSelector(_cmd))
#define LOG     ON
#else
#define DEBUG_LOG(...) ;
#define LOG_CURRENT_METHOD ;
#endif

typedef struct FFTHelperRef {
    long numberOfSamples;
    FFTSetup fftSetup;
    COMPLEX_SPLIT splitComplex;
    Float32 *outFFTData;
    Float32 *invertedCheckData;
    float *window;
} FFTHelperRef;

bool FFTHelperInitialize(FFTHelperRef *helperRef, long numberOfSamples);
void FFTHelperFinalize(FFTHelperRef *helperRef);
Float32 *computeFFT(FFTHelperRef *helperRef, Float32 *timeDomainData, long numSamples);
Float64 lagrangeInterp(CGPoint points[], NSUInteger numPoints, Float32 x);
#endif
