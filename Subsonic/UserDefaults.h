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
//  UserDefaults

#import <Foundation/Foundation.h>
#import "definitions.h"

#define PRECISE_DATE_FORMAT             @"yyyy/MM/dd HH:mm:ss.SSS"

@interface UserDefaults : NSObject {
    NSDateFormatter *dateFormatter;
    BOOL isIPhone4;
    BOOL isIPhone5;
    BOOL isIPhone6;
    BOOL isIPhone7;
    BOOL isIPad;
    BOOL isMIPad;
    BOOL isLIPad;
}
@property (assign, nonatomic) BOOL microphoneEnabled;
@property (assign, nonatomic) NSUInteger numChannels;
@property (assign, nonatomic) NSUInteger fftPoints;
@property (assign, nonatomic) Float64 sampleRate;
@property (assign, nonatomic) Float64 frameSize;

+ (UserDefaults *) sharedManager;
- (void) initialize;

- (BOOL) isIPhone4;
- (BOOL) isIPhone5;
- (BOOL) isIPhone6;
- (BOOL) isIPad;
- (BOOL) isMIPad;
- (BOOL) isLIPad;
- (BOOL) isPortrait;
- (Float64) getDefaultMicGain;

- (NSString *) timeStamp;
@end
