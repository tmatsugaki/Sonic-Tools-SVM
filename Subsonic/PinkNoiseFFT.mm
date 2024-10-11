//
//  PinkNoiseFFT.mm
//  Subsonic
//
//  Created by 松垣卓士 on 2024/10/09.
//  Copyright © 2024 Rikki Systems Inc. All rights reserved.
//
// 1/f (3dB/oct)
#import "PinkNoiseFFT.h"

@implementation PinkNoiseFFT

- (instancetype)initWithFFTSize:(UInt32)size {
    self = [super init];
    if (self) {
        fftSize = size;
        log2n = log2f(fftSize);

        // ①FFTのセットアップ
        fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);

        // ②複素数のバッファを確保
        splitComplex.realp = (float *)malloc(fftSize >> 1 * sizeof(float));
        splitComplex.imagp = (float *)malloc(fftSize >> 1 * sizeof(float));

        // ③窓関数を用意
        window = (float *)malloc(fftSize * sizeof(float));
        vDSP_hann_window(window, fftSize, vDSP_HANN_NORM);
    }
    return self;
}

- (void)dealloc {
    // メモリ解放
    vDSP_destroy_fftsetup(fftSetup);
    free(splitComplex.realp);
    free(splitComplex.imagp);
    free(window);
}

// バッファに対してピンクノイズフィルタを適用する
- (void)processBuffer:(Float32 *)buffer withFrameSize:(UInt32)frameSize {
    assert(frameSize == fftSize);  // FFTサイズとフレームサイズは同じである必要がある

    // ウィンドウ関数を適用
    vDSP_vmul(buffer, 1, window, 1, buffer, 1, fftSize);

    // 時間ドメインのデータを周波数ドメインに変換（FFT）
    vDSP_ctoz((DSPComplex *)buffer, 2, &splitComplex, 1, fftSize >> 1);

    // 周波数特性の修正 (1/f)
    for (UInt32 i = 1; i < fftSize >> 1; i++) {
        Float32 frequencyFactor = 1.0f / sqrtf(i);
        splitComplex.realp[i] *= frequencyFactor;
        splitComplex.imagp[i] *= frequencyFactor;
    }

    // 周波数ドメインから時間ドメインに逆変換（逆FFT）
    vDSP_ztoc(&splitComplex, 1, (DSPComplex *)buffer, 2, fftSize >> 1);

    // 正規化
    Float32 scale = 1.0f / (2 * fftSize);
    vDSP_vsmul(buffer, 1, &scale, buffer, 1, fftSize);
}
@end
