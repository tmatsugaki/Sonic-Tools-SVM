//
//  BrownNoiseFilter.mm
//  Subsonic
//
//  Created by 松垣卓士 on 2024/10/09.
//  Copyright © 2024 Rikki Systems Inc. All rights reserved.
//
// 1/f^2
#import <Accelerate/Accelerate.h>
#import "BrownNoiseFilter.h"

void brownNoiseFilter(Float32 *buffer, UInt32 frameSize) {
    static Float32 prevOutput = 0.0;
    static Float32 decay = 0.99; // ブラウンノイズに近い減衰係数

    // vDSP フィルタリングの準備
    vDSP_Stride stride = 1;
    
    // 過去の出力を保持する配列
    Float32 *prevOutputs = (Float32 *)calloc(frameSize, sizeof(Float32));

    // 低周波フィルタリング
    for (UInt32 i = 0; i < frameSize; i++) {
        // 現在の入力に対して前回の出力を減衰させて加える
        buffer[i] = (prevOutput + buffer[i]) * decay;

        // 次のサンプルに向けて過去の出力を更新
        prevOutput = buffer[i];
    }

    // vDSPの加算関数を使用して過去の出力との加重平均を計算
    vDSP_vsmul(buffer, stride, &decay, buffer, stride, frameSize);

    for (UInt32 i = 0; i < frameSize; i++) {
        buffer[i] *= 0.11f;
    }

    // メモリ解放
    free(prevOutputs);
}
