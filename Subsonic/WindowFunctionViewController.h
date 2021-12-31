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
//  WindowFunctionViewController.h

#import <UIKit/UIKit.h>
#import "definitions.h"
#import "FFTView.h"

NS_ASSUME_NONNULL_BEGIN

@interface WindowFunctionViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (strong, nonatomic) IBOutlet UILabel *windowFunctionTitle;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (assign, nonatomic) FFTView *fftView;
@end

NS_ASSUME_NONNULL_END
