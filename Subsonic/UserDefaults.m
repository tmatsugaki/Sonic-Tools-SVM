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

#import "UserDefaults.h"
#import "Environment.h"
#import "Settings.h"

@interface UserDefaults ()
//- (void) observerCore:(BOOL)force;
@end

@implementation UserDefaults

static UserDefaults *sharedDefaults = nil;
//static NSInteger initCount = 0;

+ (UserDefaults *) sharedManager {
    @synchronized(self)
    {
        if (sharedDefaults == nil) {
            sharedDefaults = [[self alloc] init];
        }
    }
    return sharedDefaults;
}

- (void) initialize {
    isIPhone4 = [Environment isIPhone4];
    isIPhone5 = [Environment isIPhone5];
    isIPhone6 = [Environment isIPhone6];
    isIPad    = [Environment isIPad];
    isMIPad   = [Environment isMIPad];
    isLIPad   = [Environment isLIPad];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[NSLocale systemLocale]];
    [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    [dateFormatter setCalendar:[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian]];

    _numChannels = [[NSUserDefaults standardUserDefaults] integerForKey:kAVNumberOfChannelsKey];
    if (_numChannels == 0) {
        _numChannels = 2;
        [[NSUserDefaults standardUserDefaults] setInteger:_numChannels forKey:kAVNumberOfChannelsKey];
    }
    _sampleRate = 44100.0;
    _fftPoints  = 4096;
    _frameSize  = 4096.0;
}

+ (id) allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedDefaults == nil) {
            sharedDefaults = [super allocWithZone:zone];
            return sharedDefaults;
        }
    }
    return nil;
}

- (id) copyWithZone:(NSZone*)zone {
    return self;  // シングルトン状態を保持するため何もせず self を返す
}

#if NEEDED
- (oneway void) release {
    // シングルトン状態を保持するため何もしない
}
#endif

- (BOOL) isIPhone4 {
    return isIPhone4;
}

- (BOOL) isIPhone5 {
    return isIPhone5;
}

- (BOOL) isIPhone6 {
    return isIPhone6;
}

- (BOOL) isIPhone7 {
    return isIPhone7;
}

- (BOOL) isIPad {
    return isIPad;
}

- (BOOL) isMIPad {
    return isMIPad;
}

- (BOOL) isLIPad {
    return isLIPad;
}

- (BOOL) isPortrait {
    return [Environment isPortrait];
}

- (NSString *) timeStamp {
    
    NSDate *now = [NSDate date];
    [dateFormatter setDateFormat:PRECISE_DATE_FORMAT];
    return [dateFormatter stringFromDate:now];
}

#define DEFAULT_MIC_GAIN_IPHONE     15.0
#define DEFAULT_MIC_GAIN_IPAD       21.7

- (Float64) getDefaultMicGain {
    Float64 gain;

    // log10(7.5) = log10(pow(10, gain))
    if ([Environment isIPad] || [Environment isMIPad] || [Environment isLIPad]) {
        gain = log10(DEFAULT_MIC_GAIN_IPAD / 2.0);
    } else {
        gain = log10(DEFAULT_MIC_GAIN_IPHONE / 2.0);
    }
    return gain;
}
@end
