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
//
//  definitions.h

#ifndef definitions_h
#define definitions_h

#define ON							1
#define OFF							0

#define FATAL_LOG(...) NSLog(__VA_ARGS__)

#ifdef DEBUG
#define DEBUG_LOG(...) NSLog(__VA_ARGS__)
#define LOG_CURRENT_METHOD NSLog(NSStringFromSelector(_cmd))
#define LOG     ON
#else
#define DEBUG_LOG(...) ;
#define LOG_CURRENT_METHOD ;
#endif

#define SPECTROGRAM_COMP            OFF             // ON（残務：リングバッファの引き継ぎ、iPad で回転させた時のシーケンス絡みのバグがある）
#define RTA_MARKER                  ON              // ON
#define PRECISE_RTA                 ON              // ON
#define RTA_LOOKUP                  ON              // ON
#define CSV_OUT                     ON              // ON TSVファイル出力（日下さんのリクエスト）
#define CSV_OUT_ONE_BUTTON          ON              // ON TSVファイル出力でボタンをシンプルにする

// ******************************************************
#define FFT_SMALL_LATENCY               ON             // ON
#define SCOPE_SMALL_LATENCY             OFF            // OFF
#define SPL_SMALL_LATENCY               OFF            // OFF
// 4S で 7ms でも辛い（オーディオ出力バッファのレイテンシーは標準で 23ms とあるが実際には 10ms であった。）
#define AU_BUFFERING_SLOW_LATENCY                   0.046           // 昔の 0.023 から 0.0464399 に変更されてた。
#define AU_BUFFERING_FAST_LATENCY                   0.005           // 4S で 7ms でも辛い（オーディオ出力バッファのレイテンシーは標準で 23ms とあるが実際には 10ms であった。）
// ******************************************************
#define MEASUREMENT                 ON              // ON
#define SUPPORT_IPAD                ON              // ON
#define CENTERING                   ON              // ON

#define AUDIBLE_MULTIPLE_F          1000000.0       // 1000000.0 マイクを交えた 0dB は 20μPa(20x10^-6)

#define CONSTRAINT_MAGIC            61.0

#define FULL_DYNAMIC_RANGE_DECADE   8.0             // 16.0??
#define FULL_DYNAMIC_RANGE_DECIBEL  160.0

#define SPL_DYNAMIC_RANGE_DECADE    6.0
#define SPL_DYNAMIC_RANGE_DECIBEL   120.0

#define FRAME_OFFSET                16.0
#define  CGGraphRectMake(rect) CGRectMake(rect.origin.x + FRAME_OFFSET, rect.origin.y + FRAME_OFFSET, rect.size.width - 2.0 * FRAME_OFFSET, rect.size.height - 2.0 * FRAME_OFFSET)

#define ZERO_VU                     0.0f                // 0VU
#define PIANISSIMO                  0.000000000001      // -120db 1.0x10^-12 (可聴の一番小さい音)
#define SILENT                      0.0000000000000001  // -160dB 1.0x10^-16 (無音状態)

#define EFFECTIVE_FREQUENCY        10.0f            // 10.0f 従来 20Hzにしていたので低域での誤差が酷かった！！

#define STD_REFRESH_INTERVAL        0.05            // 0.05
#define STD_RENDER_INTERVAL         0.05            // 0.05

// admob
#ifdef DEBUG
#define adMobUnitID1     @"ca-app-pub-3940256099942544/6300978111"  // 音声スペクトラムビュー
#define adMobUnitID2     @"ca-app-pub-3940256099942544/6300978111"  // 音声スコープビュー
#define adMobUnitID3     @"ca-app-pub-3940256099942544/6300978111"  // 音声RMSビュー
#define adMobUnitID4     @"ca-app-pub-3940256099942544/6300978111"  // 震動スペクトラムビュー
#define adMobUnitID5     @"ca-app-pub-3940256099942544/6300978111"  // 震動スコープビュー
#define adMobUnitID6     @"ca-app-pub-3940256099942544/6300978111"  // 震動RMSビュー
#define adMobUnitID7     @"ca-app-pub-3940256099942544/6300978111"  // 磁界スコープビュー
#define adMobUnitID8     @"ca-app-pub-3940256099942544/6300978111"  // 磁界RMSビュー
#else
#define adMobUnitID1     @"ca-app-pub-7364995006862208/8350127971"  // 音声スペクトラムビュー
#define adMobUnitID2     @"ca-app-pub-7364995006862208/3919928373"  // 音声スコープビュー
#define adMobUnitID3     @"ca-app-pub-7364995006862208/2303594378"  // 音声RMSビュー
#define adMobUnitID4     @"ca-app-pub-7364995006862208/5257060775"  // 震動スペクトラムビュー
#define adMobUnitID5     @"ca-app-pub-7364995006862208/3780327572"  // 震動スコープビュー
#define adMobUnitID6     @"ca-app-pub-7364995006862208/6733793979"  // 震動RMSビュー
#define adMobUnitID7     @"ca-app-pub-7364995006862208/5736994772"  // 磁界スコープビュー
#define adMobUnitID8     @"ca-app-pub-7364995006862208/7213727975"  // 磁界RMSビュー
#endif

#ifdef DEBUG
#define LOAD_DUMMY_DATA             0   // !!! 要注意
#define SAVE_DUMMY_DATA             0   // !!! 要注意
#define kDocumentPath               [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]
#define kBundlePath                 [[NSBundle mainBundle] bundlePath]
#endif

#define kWindowFunctionKey              @"Window Function"
#define STORY_BOARD_ID_WINDOW_FUNCATION @"WINDOW_FUNCTION"

#define kMicGainKey                     @"MicGain"

#endif /* definitions_h */
