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
//  BrownNoiseFilter.mm
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
