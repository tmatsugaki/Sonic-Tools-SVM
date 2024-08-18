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
#import <Foundation/Foundation.h>
#include <stdio.h>
#include "FFTHelper.hh"
#include "definitions.h"

bool FFTHelperInitialize(FFTHelperRef *helperRef, long numberOfSamples) {

    vDSP_Length log2m = log2f(numberOfSamples);
    bool rc = false;

    helperRef->fftSetup = vDSP_create_fftsetup(log2m, FFT_RADIX2);
    if (helperRef->fftSetup) {
        long nOver2 = numberOfSamples/2;
        helperRef->splitComplex.realp = (Float32*) malloc(nOver2*sizeof(Float32));
        if (helperRef->splitComplex.realp) {
            helperRef->splitComplex.imagp = (Float32*) malloc(nOver2*sizeof(Float32));
            if (helperRef->splitComplex.imagp) {
                helperRef->outFFTData = (Float32 *) malloc(nOver2*sizeof(Float32));
                if (helperRef->outFFTData) {
                    memset(helperRef->outFFTData, 0, nOver2*sizeof(Float32));
                    
                    helperRef->invertedCheckData = (Float32*) malloc(numberOfSamples*sizeof(Float32));
                    if (helperRef->invertedCheckData) {
                        helperRef->window = (Float32 *) malloc(numberOfSamples*sizeof(Float32));
                        if (helperRef->window) {
                            helperRef->numberOfSamples = numberOfSamples;
                            rc = true;
                        } else {
                            DEBUG_LOG(@"%s Can't allocate helperRef->window !!", __func__);
                        }
                    } else {
                        DEBUG_LOG(@"%s Can't allocate helperRef->invertedCheckData !!", __func__);
                    }
                } else {
                    DEBUG_LOG(@"%s Can't allocate helperRef->outFFTData !!", __func__);
                }
            } else {
                DEBUG_LOG(@"%s Can't allocate helperRef->splitComplex.imagp !!", __func__);
            }
        } else {
            DEBUG_LOG(@"%s Can't allocate helperRef->splitComplex.realp !!", __func__);
        }
    } else {
        DEBUG_LOG(@"%s Can't allocate helperRef->fftSetup !!", __func__);
    }
    return rc;
}

void FFTHelperFinalize(FFTHelperRef *helperRef) {

    if (helperRef->window) {
        free(helperRef->window);
        helperRef->window = NULL;
    }
    if (helperRef->invertedCheckData) {
        free(helperRef->invertedCheckData);
        helperRef->invertedCheckData = NULL;
    }
    if (helperRef->outFFTData) {
        free(helperRef->outFFTData);
        helperRef->outFFTData = NULL;
    }
    if (helperRef->splitComplex.imagp) {
        free(helperRef->splitComplex.imagp);
        helperRef->splitComplex.imagp = NULL;
    }
    if (helperRef->splitComplex.realp) {
        free(helperRef->splitComplex.realp);
        helperRef->splitComplex.realp = NULL;
    }
    if (helperRef->fftSetup) {
        vDSP_destroy_fftsetup(helperRef->fftSetup);
        helperRef->fftSetup = nil;
    }
}

Float32 *computeFFT(FFTHelperRef *helperRef, Float32 *data, long length) {
    
    vDSP_Length log2m = log2f(length);
    
    // 【窓関数】
    NSUInteger windowFunction = [[NSUserDefaults standardUserDefaults] integerForKey:kWindowFunctionKey];

    if (windowFunction)
    {// RTA
        switch (windowFunction) {
        case 1:
            vDSP_hamm_window(helperRef->window, length, 0);
            break;
        case 2:
            vDSP_hann_window(helperRef->window, length, 0);
            break;
        case 3:
            vDSP_blkman_window(helperRef->window, length, 0);
            break;
        }
        vDSP_vmul(data, 1, helperRef->window, 1, data, 1, length);
    }
    // 【入力を複素数にする】
    //Convert float array of reals samples to COMPLEX_SPLIT array A
    if (helperRef->fftSetup &&
        helperRef->splitComplex.realp &&
        helperRef->splitComplex.imagp &&
        helperRef->outFFTData)
    {
        // Copies the contents of an interleaved complex vector C to a split complex vector Z; single precision.
        vDSP_ctoz((COMPLEX *) data, 2, &helperRef->splitComplex, 1, length/2);
        // 【FFT実行】
        // Computes an in-place single-precision real discrete Fourier transform, either from the time domain to the frequency domain (forward) or from the frequency domain to the time domain (inverse).
        vDSP_fft_zrip(helperRef->fftSetup, &(helperRef->splitComplex), 1, log2m, FFT_FORWARD);
        
        // 【FFT結果の正規化】
#if 1
        Float32 mFFTNormFactor = 1.0/(2*length);
        // Single-precision real vector-scalar multiply.
        vDSP_vsmul(helperRef->splitComplex.realp, 1, &mFFTNormFactor, helperRef->splitComplex.realp, 1, length/2);
        vDSP_vsmul(helperRef->splitComplex.imagp, 1, &mFFTNormFactor, helperRef->splitComplex.imagp, 1, length/2);
#endif

#if 1
        // 【RMS】
        // 【相乗平均を出力結果とし、半分のデータを利用する】
        // Vector distance; single precision.
        // For the first N elements of A and B, this function takes the square root of the sum of the squares of corresponding elements, leaving the results in C:
        vDSP_vdist(helperRef->splitComplex.realp, 1, helperRef->splitComplex.imagp, 1, helperRef->outFFTData, 1, length/2);
#elif 0
        // Complex vector magnitudes squared; single precision.
        // Calculates the squared magnitudes of complex vector A, leaving the result in C.
        // where Re are the real parts of A and Im are the imaginary parts.
        // 【相乗を出力結果とし、半分のデータを利用する】
        DSP_zvmags(&helperRef->splitComplex, 1, helperRef->outFFTData, 1, length/2);
#else
        for (int i = 0; i < length/2; i++) {
            float real = helperRef->splitComplex.realp[i];
            float imag = helperRef->splitComplex.imagp[i];
            float distance = sqrt(real*real + imag*imag);
            helperRef->outFFTData[i] = distance;
        }
#endif
    } else {
        DEBUG_LOG(@"FFTHelper不正！！");
    }
    //to check everything (checking by reversing to time-domain data) =============================
//    vDSP_fft_zrip(helperRef->fftSetup, &(helperRef->complexA), 1, log2m, FFT_INVERSE);
//    vDSP_ztoc( &(helperRef->complexA), 1, (COMPLEX *) helperRef->invertedCheckData , 2, numSamples/2);
    //=============================================================================================
    return helperRef->outFFTData;
}

Float64 lagrangeInterp(CGPoint points[], NSUInteger n, Float32 x)
/*
 * pnt   : 点群を表す配列
 * n     : 点群の個数
 * x     : 求めたいxの値
 * 戻り値 : xに対応する関数値 y
 */
{
    NSUInteger i, j;
    /* 計算用変数の初期化 */
    Float64 p, s = 0.0;
    
    for (i = 0; i < n; i++) {
        p = points[i].y;   /* 積の計算 */
        for (j = 0; j < n; j++) {
            if (i != j) {
                p *= (x - points[j].x) / (points[i].x - points[j].x);
            }
        }
        s += p;
    }
    return s;
}
