//
//  PinkNoise.mm
//  Subsonic
//
//  Created by 松垣卓士 on 2024/10/09.
//  Copyright © 2024 Rikki Systems Inc. All rights reserved.
//
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
