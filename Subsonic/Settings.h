/*
    Sonic Tools SVM (FFT Analyzer/RTA for iOS)
    Copyright (C) 2017-2021  Takuji Matsugaki

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
//  Settings.h

#ifndef Settings_h
#define Settings_h

// 共通
#define kAVFormatIDKey              @"AVFormatIDKey"                // kAudioFormatLinearPCM
#define kAVNumberOfChannelsKey      @"AVNumberOfChannelsKey"        // 2
//#define kAVSampleRateKey            @"AVSampleRateKey"              // 44100.0
//#define kAVFFTPointsKey             @"AVFFTPointsKey"               // 4096
//#define kAVFrameSizeKey             @"AVFrameSizeKey"               // 2048
// エンコーダー
#define kAVEncoderBitRateKey        @"AVEncoderBitRateKey"          // 12800
#define kAVEncoderAudioQualityKey   @"AVEncoderAudioQualityKey"     // AVAudioQualityHigh
// PCM
#define kAVLinearPCMBitDepthKey     @"AVLinearPCMBitDepthKey"       // 16
#define kAVLinearPCMIsBigEndianKey  @"AVLinearPCMIsBigEndianKey"    // NO
#define kAVLinearPCMIsFloatKey      @"AVLinearPCMIsFloatKey"        // NO

#endif /* Settings_h */
