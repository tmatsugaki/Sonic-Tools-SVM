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
//  ToneGeneratorViewController.h

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

enum {
    kSin, kSaw, kTriangle
};

#define REFRESH_INTERVAL    STD_REFRESH_INTERVAL    // 0.05
#define RENDER_INTERVAL     STD_RENDER_INTERVAL     // 0.05

#define kOscillatorFrequencyKey     @"Frequency"
#define kOscillatorWaveTypeKey      @"WaveType"

@interface ToneGeneratorViewController : UIViewController <UITextFieldDelegate> {
@public
    Float32 frequency;
    Float32 sampleRate;
    Float32 theta;
}
@property (strong, nonatomic) IBOutlet UISegmentedControl *mode;
@property (strong, nonatomic) IBOutlet UIButton *min;
@property (strong, nonatomic) IBOutlet UIButton *max;
@property (strong, nonatomic) IBOutlet UIStepper *stepper;
@property (strong, nonatomic) IBOutlet UITextField *frequncy;
@property (strong, nonatomic) IBOutlet UIButton *play;
@property (strong, nonatomic) IBOutlet UIButton *stop;
@property (strong, nonatomic) IBOutlet UIButton *rise;
@property (strong, nonatomic) IBOutlet UIButton *down;
- (void)stopProc;
@end
