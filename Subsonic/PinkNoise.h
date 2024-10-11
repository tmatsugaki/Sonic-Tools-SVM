//
//  PinkNoiseFFT.h
//  Subsonic
//
//  Created by 松垣卓士 on 2024/10/09.
//  Copyright © 2024 Rikki Systems Inc. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

#define NUM_FILTERS 7

@interface PinkNoise : NSObject {
    Float32 _pinkNoise[NUM_FILTERS];
    Float32 _whiteNoise;
}

- (void)processBuffer:(Float32 *)buffer withFrameSize:(UInt32)frameSize;
@end
