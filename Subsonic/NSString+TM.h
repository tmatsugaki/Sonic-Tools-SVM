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
//  NSString+TM.h

#import <Foundation/Foundation.h>

@interface NSString (TM)

+ (NSString *) commaString:(NSNumber *)number;

- (BOOL) writeToFile:(NSString *)path;
- (BOOL) safeWriteToFile:(NSString *)path atomically:(BOOL)flag;
- (NSString *) replaceString:(NSString *)keyword withString:(NSString *)replacement;
- (NSString *) replacedString:(NSString *)whichString withString:(NSString *)withString;
- (BOOL) isCellPhoneNumber;
- (BOOL) isPhoneNumber;
- (BOOL) isMailAddress;
- (NSString *) normalizePhoneNumber;
- (BOOL) isHankakuString;
- (BOOL) isZenkakuString;

// 半角→全角
- (NSString *) stringToFullwidth;
// 全角→半角
- (NSString *) stringToHalfwidth;
// カタカナ→ひらがな
- (NSString *) stringKatakanaToHiragana;
// ひらがな→カタカナ
- (NSString *) stringHiraganaToKatakana;
// ひらがな→ローマ字
- (NSString *) stringHiraganaToLatin;
// ローマ字→ひらがな
- (NSString *) stringLatinToHiragana;
// カタカナ→ローマ字
- (NSString *) stringKatakanaToLatin;
// ローマ字→カタカナ
- (NSString *) stringLatinToKatakana;
@end
