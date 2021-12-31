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
//  WindowFunctionViewController.m

#import "WindowFunctionViewController.h"

@interface WindowFunctionViewController ()

@end

@implementation WindowFunctionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [_windowFunctionTitle setText:NSLocalizedString(kWindowFunctionKey, @"")];
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WindowFunction"];
    NSInteger windowFunction = [[NSUserDefaults standardUserDefaults] integerForKey:kWindowFunctionKey];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:@"WindowFunction"];
    }
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = NSLocalizedString(@"Rectangular", @"不使用");
            break;
        case 1:
            cell.textLabel.text = NSLocalizedString(@"Hamming", @"ハミング");
            break;
        case 2:
            cell.textLabel.text = NSLocalizedString(@"Hanning", @"ハニング");
            break;
        case 3:
            cell.textLabel.text = NSLocalizedString(@"Blackman", @"ブラックマン");
            break;
    }
    cell.accessoryType = indexPath.row == windowFunction ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 1.0;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 4;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
}

- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection {
}

- (void)preferredContentSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container {
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    [[NSUserDefaults standardUserDefaults] setInteger:indexPath.row forKey:kWindowFunctionKey];
    [_fftView maintainControl:[[NSUserDefaults standardUserDefaults] integerForKey:kWindowFunctionKey]];

    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
