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
//  PinkNoiseFFT.mm
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
