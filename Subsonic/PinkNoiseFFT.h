//
//  PinkNoise.h
//  Subsonic
//
//  Created by 松垣卓士 on 2024/10/09.
//  Copyright © 2024 Rikki Systems Inc. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

@interface PinkNoiseFFT : NSObject {
    FFTSetup fftSetup;               // FFTのセットアップ
    DSPSplitComplex splitComplex;    // 複素数データ
    Float32 *window;                 // ウィンドウ関数
    UInt32 fftSize;                  // FFTサイズ
    UInt32 log2n;                    // FFTサイズの対数
}

- (instancetype)initWithFFTSize:(UInt32)size;
- (void)processBuffer:(Float32 *)buffer withFrameSize:(UInt32)frameSize;

@end
