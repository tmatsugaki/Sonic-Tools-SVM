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
//  PinkNoise.mm

#import "PinkNoise.h"

@implementation PinkNoise

- (instancetype)init {
    self = [super init];
    if (self) {
        for (int i = 0; i < NUM_FILTERS; i++) {
            _pinkNoise[i] = 0.0f;
        }
        _whiteNoise = 0.0f;
    }
    return self;
}

// バッファ全体に対してピンクノイズフィルターを適用するメソッド
- (void)processBuffer:(Float32 *)buffer withFrameSize:(UInt32)frameSize {
    // ピンクノイズフィルタの係数
    Float32 coefficients[NUM_FILTERS] = {0.99886, 0.99332, 0.96900, 0.86650, 0.55000, -0.7616, 0.115926};
    Float32 gains[NUM_FILTERS] = {0.0555179, 0.0750759, 0.1538520, 0.3104856, 0.5329522, -0.0168980, 0.115926};

    for (UInt32 i = 0; i < frameSize; i++) {
        _whiteNoise = buffer[i];  // バッファの現在のサンプルをホワイトノイズとして扱う
        
        // フィルタ処理の計算
        for (int j = 0; j < NUM_FILTERS; j++) {
            _pinkNoise[j] = coefficients[j] * _pinkNoise[j] + _whiteNoise * gains[j];
        }

        // ピンクノイズの合計
        Float32 pink = _pinkNoise[0] + _pinkNoise[1] + _pinkNoise[2] + _pinkNoise[3] + _pinkNoise[4] + _pinkNoise[5] + _pinkNoise[6] + _whiteNoise * 0.5362;

        // 結果をバッファに書き込む
        buffer[i] = pink * 0.11f;  // 出力レベルを調整
    }
}
@end
