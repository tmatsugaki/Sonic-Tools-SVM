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
//  TextFieldUtil.m

#import "TextFieldUtil.h"
#import "NSString+TM.h"

@implementation TextFieldUtil

// 番号
+ (BOOL) textFieldValidNumber:(UITextField *)textField
  shouldChangeCharactersInRange:(NSRange)range
              replacementString:(NSString *)string {
    
    BOOL rc = YES;
    
    if ([string isEqualToString:@"\n"] ||
        [string isEqualToString:@"\b"] ||
        [string isEqualToString:@"☻"]) {
    } else if (strlen("44100") < range.location + range.length + [string length]) {
        rc = NO;
    } else {
        NSCharacterSet *phoneCharset = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
        // 半角文字列にして上記のキャラクタセットに属しないものを検知する。
        string = [string stringToHalfwidth];
        for (int i = 0; i < [string length]; i++) {
            unichar chr = [string characterAtIndex:i];
            if ([phoneCharset characterIsMember:chr] == NO) {
                rc = NO;
                break;
            }
        }
    }
    return rc;
}

// 電話番号
+ (BOOL) textFieldValidPhoneNum:(UITextField *)textField
  shouldChangeCharactersInRange:(NSRange)range
              replacementString:(NSString *)string {
    
    BOOL rc = YES;
    
    if ([string isEqualToString:@"\n"] ||
        [string isEqualToString:@"\b"] ||
        [string isEqualToString:@"☻"]) {
    } else if (strlen("(0979) 22 8752") < range.location + range.length + [string length]) {
        rc = NO;
    } else {
        NSCharacterSet *phoneCharset = [NSCharacterSet characterSetWithCharactersInString:@"( )-0123456789"];
        // 半角文字列にして上記のキャラクタセットに属しないものを検知する。
        string = [string stringToHalfwidth];
        for (int i = 0; i < [string length]; i++) {
            unichar chr = [string characterAtIndex:i];
            if ([phoneCharset characterIsMember:chr] == NO) {
                rc = NO;
                break;
            }
        }
    }
    return rc;
}

// 全角文字列のみ（ローマ字変換もできない！！）
+ (BOOL) textFieldValidZenkaku:(UITextField *)textField
 shouldChangeCharactersInRange:(NSRange)range
             replacementString:(NSString *)string
{
    BOOL rc = YES;
    
    if ([string isEqualToString:@"\n"] ||
        [string isEqualToString:@"\b"] ||
        [string isEqualToString:@"☻"]) {
    } else {
        NSCharacterSet *punctuationCharacterSet = [NSCharacterSet punctuationCharacterSet];
        NSCharacterSet *decimalDigitCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
        NSCharacterSet *symbolCharacterSet = [NSCharacterSet symbolCharacterSet];
        unichar dakuonChar = [@"゛" characterAtIndex:0];
        // 全角文字列
        NSString *fullwidthString = [string stringToFullwidth];
        // 半角文字列にしてパンクチュエーション／数字／シンボルを抽出する。
        string = [string stringToHalfwidth];
        
        for (int i = 0; i < [string length]; i++) {
            unichar chr = [string characterAtIndex:i];
            BOOL isPunc = [punctuationCharacterSet characterIsMember:chr];
            BOOL isDeciaml = [decimalDigitCharacterSet characterIsMember:chr];
            BOOL isSymbol  = (chr != dakuonChar) && [symbolCharacterSet characterIsMember:chr];

            if (isPunc || isDeciaml || isSymbol)
            {
                rc = NO;
                break;
            }
        }
        
        if ([string isEqualToString:fullwidthString] == NO)
        {// 数字／パンクチュエーション／シンボルはないので、最後に半角の存在をチェックする。
            rc = NO;
        }
    }
    return rc;
}

// パンクチュエーション／数字／シンボルは許可しない。
+ (BOOL) textFieldValidNonNumPuncSym:(UITextField *)textField
       shouldChangeCharactersInRange:(NSRange)range
                   replacementString:(NSString *)string
{
    BOOL rc = YES;
    
    if ([string isEqualToString:@"\n"] ||
        [string isEqualToString:@"\b"] ||
        [string isEqualToString:@"☻"]) {
    } else {
        NSCharacterSet *punctuationCharacterSet = [NSCharacterSet punctuationCharacterSet];
        NSCharacterSet *decimalDigitCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
        NSCharacterSet *symbolCharacterSet = [NSCharacterSet symbolCharacterSet];
        unichar dakuonChar = [@"゛" characterAtIndex:0];
        // 半角文字列にしてパンクチュエーション／数字／シンボルを抽出する。
        string = [string stringToHalfwidth];
        
        for (int i = 0; i < [string length]; i++) {
            unichar chr = [string characterAtIndex:i];
            BOOL isPunc = [punctuationCharacterSet characterIsMember:chr];
            BOOL isDeciaml = [decimalDigitCharacterSet characterIsMember:chr];
            BOOL isSymbol  = (chr != dakuonChar) && [symbolCharacterSet characterIsMember:chr];

            if (isPunc || isDeciaml || isSymbol)
            {
                rc = NO;
                break;
            }
        }
    }
    return rc;
}

// パンクチュエーション／数字／シンボルは許可しない。
// 英語の名前入力のための例外：".,'"
+ (BOOL) textFieldValidNonNumPuncSymExceptPeriodCommaSingle:(UITextField *)textField
                        shouldChangeCharactersInRange:(NSRange)range
                                    replacementString:(NSString *)string
{
    BOOL rc = YES;
    
//    DEBUG_LOG(@"[%02X]", [string characterAtIndex:0]);
    
    if ([string isEqualToString:@"\n"] ||
        [string isEqualToString:@"\b"] ||
        [string isEqualToString:@"☻"]) {
    } else {
        NSCharacterSet *punctuationCharacterSet = [NSCharacterSet punctuationCharacterSet];
        NSCharacterSet *decimalDigitCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
        NSCharacterSet *symbolCharacterSet = [NSCharacterSet symbolCharacterSet];
        unichar periodChar = [@"." characterAtIndex:0];
        unichar commaChar = [@"," characterAtIndex:0];
        unichar singleQuoteChar = [@"'" characterAtIndex:0];
        unichar dakuonChar = [@"゛" characterAtIndex:0];
        // 半角文字列にしてパンクチュエーション／数字／シンボルを抽出する。
        string = [string stringToHalfwidth];
        
        for (int i = 0; i < [string length]; i++) {
            unichar chr = [string characterAtIndex:i];
            BOOL unpermittedPunctuationChar = ([punctuationCharacterSet characterIsMember:chr] &&
                                                chr != periodChar &&
                                                chr != commaChar &&
                                                chr != singleQuoteChar);
            BOOL isDeciaml = [decimalDigitCharacterSet characterIsMember:chr];
            BOOL isSymbol  = chr != dakuonChar && [symbolCharacterSet characterIsMember:chr];

            if (unpermittedPunctuationChar || isDeciaml || isSymbol)
            {
                rc = NO;
                break;
            }
        }
    }
    return rc;
}

@end
