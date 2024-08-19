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
//  MainViewController.m

#import <AVFoundation/AVAudioSession.h>
#import "MainViewController.h"
#import "mo_audio.hh" //stuff that helps set up low-level audio
#import "FFTView.h"
#import "UserDefaults.h"

#define kSelectedTabIndexKey        @"SelectedTabIndex"
#define kTabbarTagOrderKey          @"TabbarTagOrder"

void dummyAudioCallback(Float32 *buffer, UInt32 frameSize, void *userData) {
}

@interface MainViewController ()

@end

@implementation MainViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    BOOL result = MoAudio::init( [UserDefaults sharedManager].sampleRate, [UserDefaults sharedManager].frameSize, [UserDefaults sharedManager].numChannels);
    if (result) {
#if 1
        OSStatus stat;
#if MEASUREMENT
        // AGC ON/計測モードを選択可能
        //        if ([[NSUserDefaults standardUserDefaults] boolForKey:kSpectrumAgcKey])
        //        {// マイクの AGC をオンにする。
        //            //                UInt32 mode = kAudioSessionMode_Default; いつも計測にする！！
        //            UInt32 mode = kAudioSessionMode_Measurement;
        //            stat = AudioSessionSetProperty(kAudioSessionProperty_Mode, sizeof(mode), &mode);
        //        } else
        {// マイクの AGC をオフにする。 <AudioToolbox/AudioToolbox.h>
#if 1
            UInt32 mode = kAudioSessionMode_Measurement;
            stat = AudioSessionSetProperty(kAudioSessionProperty_Mode, sizeof(mode), &mode);
#endif
            
#if 0
            // テスト用
            if ([Environment systemMajorVersion] >= 10) {
                mode = kAUVoiceIOProperty_BypassVoiceProcessing;
            } else {
                mode = kAudioSessionMode_Measurement;
            }
            stat = AudioSessionSetProperty(kAudioSessionProperty_Mode, sizeof(mode), &mode);
#endif
        }
#endif
        DEBUG_LOG(@"%s stat=%d", __func__, stat);
#endif
    } else {
        DEBUG_LOG(@" MoAudio init ERROR");
    }
    MoAudio::m_callback = dummyAudioCallback;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (! lastItem) {// 最初の時だけ初期化する。
        DEBUG_LOG(@"%@", self.customizableViewControllers);
        DEBUG_LOG(@"%@", self.viewControllers);

        NSMutableArray *newViewControllers = [[NSMutableArray alloc] init];

        if (self.customizableViewControllers) {
            NSArray *tabBarTagOrder = [[NSUserDefaults standardUserDefaults] objectForKey:kTabbarTagOrderKey];
            NSMutableArray *candidateViewControllers = [[NSMutableArray alloc] initWithArray:self.customizableViewControllers];
            
            for (NSUInteger i = 0; i < [tabBarTagOrder count]; i++) {
                NSInteger tag = [((NSNumber *) tabBarTagOrder[i]) integerValue];
                if (tag) {
                    NSUInteger index = tag - 1;
                    [newViewControllers addObject:self.customizableViewControllers[index]];
                    [candidateViewControllers removeObject:self.customizableViewControllers[index]];
                }
            }
            [newViewControllers addObjectsFromArray:candidateViewControllers];
            [self setViewControllers:newViewControllers];
        }
        DEBUG_LOG(@"%lu", (unsigned long)[self tabIndexToSelect]);
        [self setSelectedIndex:[self tabIndexToSelect]];
        lastItem = self.tabBar.selectedItem;
    }
}

- (void)didReceiveMemoryWarning {
    DEBUG_LOG(@"%s", __func__);
    
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UIResponder

- (BOOL) canBecomeFirstResponder {
    return YES;
}

- (BOOL) canResignFirstResponder {
    return YES;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (NSUInteger) tabIndexToSelect;
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:kSelectedTabIndexKey]; // defaults to zero
}

#pragma mark - UITabBarDelegate
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    DEBUG_LOG(@"%s %lu", __func__, (unsigned long)self.selectedIndex);

    NSUInteger index = [self.tabBar.items indexOfObject:item];
    [[NSUserDefaults standardUserDefaults] setInteger:(index != NSNotFound ? index : 0) forKey:kSelectedTabIndexKey];
}

- (void)tabBar:(UITabBar *)tabBar didEndCustomizingItems:(NSArray<UITabBarItem *> *)items
       changed:(BOOL)changed {
    NSArray *tabBarTagOrder = [items valueForKey:@"tag"];
    DEBUG_LOG(@"%s %@", __func__, tabBarTagOrder);

    if (changed) {
        [[NSUserDefaults standardUserDefaults] setObject:tabBarTagOrder forKey:kTabbarTagOrderKey];
    }
}

#pragma mark - UITabBarControllerDelegate

#if 0
- (void)tabBarController:(UITabBarController *)tabBarController
 didSelectViewController:(UIViewController *)viewController;
{
    DEBUG_LOG(@"%s", __func__);

    [[NSUserDefaults standardUserDefaults] setInteger:tabBarController.selectedIndex forKey:kSelectedTabIndexKey];
}

- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers
                 changed:(BOOL)changed
{
    DEBUG_LOG(@"%s", __func__);
    NSArray *tabBarTagOrder = [tabBarController.tabBar.items valueForKey:@"tag"];

    if (changed) {
        [[NSUserDefaults standardUserDefaults] setObject:tabBarTagOrder forKey:kTabbarTagOrderKey];
    }
}
#endif
@end
