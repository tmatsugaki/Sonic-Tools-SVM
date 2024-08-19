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
//  MiscViewController.m

#include "definitions.h"
#include "MiscViewController.h"
#import "Environment.h"

@interface MiscViewController ()

@end

@implementation MiscViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    _infoTitle.text = NSLocalizedString(@"Info", @"情報");
    NSString *versionString = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    _version.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Version", @"バージョン"), versionString];
}

- (void)didReceiveMemoryWarning
{
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

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 1.0;
}

- (NSInteger) tableView:(UITableView *)tableView
  numberOfRowsInSection:(NSInteger)section {
    
//    return 4;
    return 3;
}

// Customize the appearance of table view cells.
- (UITableViewCell *) tableView:(UITableView *)tableView
          cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Misc"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:@"Misc"];
    }
    // アイコンがあれば表示する。
    NSString *imageName = nil;
    NSString *title = nil;
    
    //    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.backgroundColor = [UIColor clearColor];
    switch (indexPath.row) {
#if 0
        case 0:
            title = NSLocalizedString(@"Support Mail", @"ご意見・不具合報告");
            break;
        case 1:
            title = NSLocalizedString(@"GoWebsite", @"Webサイト");
            break;
        case 2:
            title = NSLocalizedString(@"WriteReviews", @"レビューを書く");
            break;
        case 3:
            title = NSLocalizedString(@"Other Apps", @"他のアプリ");
            break;
#else
        case 0:
            title = NSLocalizedString(@"Support Mail", @"ご意見・不具合報告");
            break;
        case 1:
            title = NSLocalizedString(@"Other Apps", @"他のアプリ");
            break;
        case 2:
            title = NSLocalizedString(@"WriteReviews", @"レビューを書く");
            break;
#endif
    }
    if (imageName) {
        [cell.imageView setImage:[UIImage imageNamed:imageName]];
    }
    cell.textLabel.text = title;
    return cell;
}

#pragma mark - Table view delegate

- (CGFloat) tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 32.0;
}

- (void) tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    switch (indexPath.row) {
#if 0
        case 0: {// ご意見・不具合報告
            NSString *appNameString = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleDisplayName"];
            NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
            NSString *sysVersionString = [[UIDevice currentDevice] systemVersion];
            [self sendMailWithSubject:NSLocalizedString(@"Subsonic Support", @"Subsonic サポート") message:[NSString stringWithFormat:@"\n\n%@ %@\niOS %@", appNameString, appVersionString, sysVersionString]];
        }
            break;
        case 1: {// Webサイト
            NSString *urlStr = NSLocalizedString(@"https://rikkicat.wordpress.com/ios-apps-j/", @"https://rikkicat.wordpress.com/ios-apps-j/");
            // NSURL *url = [NSURL URLWithString:[urlStr encodeURL:NSUTF8StringEncoding]];
            // URL エンコードしないこと！！
            NSURL *url = [NSURL URLWithString:urlStr];
            
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url];
            }
        }
            break;
        case 2: {// レビューを書く
            NSString *urlStr = NSLocalizedString(@"https://itunes.apple.com/jp/app/fa-yaochekka/id814832089?l=ja&ls=1&mt=8", @"https://itunes.apple.com/jp/app/fa-yaochekka/id814832089?l=ja&ls=1&mt=8");
//                NSURL *url = [NSURL URLWithString:[urlStr encodeURL:NSUTF8StringEncoding]];
            // URL エンコードしないこと！！
            NSURL *url = [NSURL URLWithString:urlStr];
            
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url];
            }
        }
            break;
        case 3: {// 他のアプリ
            NSString *urlStr = NSLocalizedString(@"https://itunes.apple.com/jp/developer/rikki-systems-inc/id497295364", @"https://itunes.apple.com/jp/developer/rikki-systems-inc/id497295364");
//                NSURL *url = [NSURL URLWithString:[urlStr encodeURL:NSUTF8StringEncoding]];
            // URL エンコードしないこと！！
            NSURL *url = [NSURL URLWithString:urlStr];
            
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url];
            }
        }
            break;
#else
        case 0: {// ご意見・不具合報告
            NSString *appNameString = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleDisplayName"];
            NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
            NSString *sysVersionString = [[UIDevice currentDevice] systemVersion];
            [self sendMailWithSubject:NSLocalizedString(@"Subsonic Support", @"Subsonic サポート") message:[NSString stringWithFormat:@"\n\n%@ %@\niOS %@", appNameString, appVersionString, sysVersionString]];
        }
            break;
        case 1: {// 他のアプリ
            NSString *urlStr = NSLocalizedString(@"https://itunes.apple.com/jp/developer/rikki-systems-inc/id497295364", @"https://itunes.apple.com/jp/developer/rikki-systems-inc/id497295364");
//                NSURL *url = [NSURL URLWithString:[urlStr encodeURL:NSUTF8StringEncoding]];
            // URL エンコードしないこと！！
            NSURL *url = [NSURL URLWithString:urlStr];
            
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url];
            }
        }
            break;
        case 2: {// レビューを書く
            NSString *urlStr = NSLocalizedString(@"https://itunes.apple.com/us/app/sonic-tools/id1245046029?mt=8", @"https://itunes.apple.com/jp/app/sonic-tools/id1245046029?mt=8");
//                NSURL *url = [NSURL URLWithString:[urlStr encodeURL:NSUTF8StringEncoding]];
            // URL エンコードしないこと！！
            NSURL *url = [NSURL URLWithString:urlStr];
            
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url];
            }
        }
            break;
#endif
    }
}

#pragma mark - MFMailComposeViewControllerDelegate

//メール送信
- (void) sendMailWithSubject:(NSString *)subject message:(NSString *)message {
    
    //メール送信可能かどうかのチェック
    if ([MFMailComposeViewController canSendMail]) {
        // モーダルダイアログを表示する。（iOS7 でステータスバーにめり込まない様に）
        //メールコントローラの生成
        MFMailComposeViewController *pickerCtl = [[MFMailComposeViewController alloc] init];
        pickerCtl.mailComposeDelegate = self;
        
        //メールのテキストの指定
        [pickerCtl setSubject:subject];
        [pickerCtl setToRecipients:[NSArray arrayWithObject:@"subsonic@rikki.mydns.jp"]];
        [pickerCtl setMessageBody:message isHTML:NO];
        
        //        [pickerCtl addAttachmentData:[NSData dataWithContentsOfFile:partSummaryPath] mimeType:@"text/csv" fileName:partSummaryFileName];
        
        //メールコントローラのビューを開く
        [self presentViewController:pickerCtl animated:YES completion:nil];
    } else {
        [self noteAlert:NSLocalizedString(@"Can't send an e-mail.", @"メールを送信できません。")];
    }
}

//メール送信完了時に呼ばれる
- (void) mailComposeController:(MFMailComposeViewController *)controller
           didFinishWithResult:(MFMailComposeResult)result
                         error:(NSError*)error
{
    if (error != nil) {
        [self noteAlert:NSLocalizedString(@"Failed to send an e-mail.", @"メールの送信に失敗しました。")];
    }
    //オープン中のビューコントローラを閉じる
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIAlertViewDelegate

- (void) noteAlert:(NSString *)str {
    
    // 多重にアラートが表示されるのを抑止する。
//    if ([Environment peekModalViewController] == nil)
    {
        UIViewController *presentedVC = [Environment getPresentedViewController];
        
        if (presentedVC) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Notify", @"通知")
                                                                                     message:str
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Close", @"閉じる")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *action) {
                                                              }]];
            [presentedVC presentViewController:alertController animated:YES completion:nil];
        }
    }
}
@end
