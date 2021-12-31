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
//  NSString+TM.m

#import "NSString+TM.h"

@implementation NSString (TM)

+ (NSString *) commaString:(NSNumber *)number {
    
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    
    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [numberFormatter setUsesGroupingSeparator:YES];
    
    return [numberFormatter stringFromNumber:number];
}

- (BOOL) writeToFile:(NSString *)path
{
    return [[self dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES];
}

- (BOOL) safeWriteToFile:(NSString *)path
              atomically:(BOOL)flag
{
    BOOL rc = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:path]) {
        NSString *tempPath = [NSString stringWithFormat:@"%@.tmp", path];
        rc = [[self dataUsingEncoding:NSUTF8StringEncoding] writeToFile:tempPath atomically:flag];
        if (rc) {
            NSString *backupItemName = [NSString stringWithFormat:@"%@.bak", [path lastPathComponent]];
            NSURL *originalItemURL   = [NSURL fileURLWithPath:tempPath];
            NSURL *newItemURL        = [NSURL fileURLWithPath:path];
            NSFileManagerItemReplacementOptions options = NSFileManagerItemReplacementUsingNewMetadataOnly | NSFileManagerItemReplacementWithoutDeletingBackupItem;
            NSURL *resultingURL = nil;
            NSError *error = nil;
            
            rc = [fileManager replaceItemAtURL:originalItemURL
                                 withItemAtURL:newItemURL
                                backupItemName:backupItemName
                                       options:options
                              resultingItemURL:&resultingURL
                                         error:&error];
        }
    } else {
        rc = [[self dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:flag];
    }
    return rc;
}

// 冒頭のマッチのみ置換する。
// mutateError が発生。改善すること。 Jun 7, 2012 by TAK
- (NSString *) replaceString:(NSString *)keyword
				  withString:(NSString *)replacement {
    
#if 0
    if ([self length] && [self rangeOfString:keyword].location != NSNotFound) {
        NSMutableString *replacedStr = [[[NSMutableString alloc] initWithString:self] autorelease];
        [replacedStr replaceCharactersInRange:range withString:replacement];
        return replacedStr;
    } else {
        return self;
    }
#else
    NSString *result = nil;
    
    if ([self length] && [keyword length]) {
        NSRange range = [self rangeOfString:keyword];
        
        if (range.location != NSNotFound) {
            NSMutableString *replacedStr = [[NSMutableString alloc] initWithString:self];
            [replacedStr replaceCharactersInRange:range withString:replacement];
            result = replacedStr;
        } else {
            result = self;
        }
    } else {
        result = @"";
    }
    return result;
#endif
}

// 全てのマッチを置換する。
- (NSString *) replacedString:(NSString *)whichString
                   withString:(NSString *)withString
{
	NSMutableString *newStr = [self mutableCopy];
	[newStr replaceOccurrencesOfString:whichString withString:withString
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [newStr length])];
	return newStr;
}

- (BOOL) isCellPhoneNumber {
    
    NSString *regExp = @"^[0-9]{2,4}[-| ]{0,1}[0-9]{2,4}[-| ]{0,1}[0-9]{2,4}$";
    NSRange urlMatch = [self rangeOfString:regExp
                                   options:NSRegularExpressionSearch];
    return (urlMatch.length != 0);
}

- (BOOL) isPhoneNumber {
    
    NSString *regExp = @"^[0-9]{2,4}[-| ]{0,1}[0-9]{2,4}[-| ]{0,1}[0-9]{2,4}$";
    NSRange urlMatch = [self rangeOfString:regExp
                                   options:NSRegularExpressionSearch];
    return (urlMatch.length != 0);
}

- (BOOL) isMailAddress {
    
    NSString *regExp = @"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}$";
    NSRange urlMatch = [self rangeOfString:regExp
                                   options:NSRegularExpressionSearch];
    return (urlMatch.length != 0);
}

- (NSString *) normalizePhoneNumber {
    
    NSMutableString *normalizedPhoneNumber = [[NSMutableString alloc] init];
    NSString *hankakuStr = [self stringToHalfwidth];
    NSCharacterSet *punctuationCharacterSet = [NSCharacterSet punctuationCharacterSet];
    unichar dashChr = [@"-" characterAtIndex:0];

    for (NSUInteger i = 0; i < [hankakuStr length]; i++) {
        unichar chr = [hankakuStr characterAtIndex:i];
        
        if ([punctuationCharacterSet characterIsMember:chr] == NO || chr == dashChr) {
            [normalizedPhoneNumber appendString:[NSString stringWithCharacters:&chr length:1]];
        }
    }
    return normalizedPhoneNumber;
}

- (NSString *) stringByURLEncoding:(NSStringEncoding)encoding
{
    NSArray *escapeChars = [NSArray arrayWithObjects:
                            @";" ,@"/" ,@"?" ,@":"
                            ,@"@" ,@"&" ,@"=" ,@"+"
                            ,@"$" ,@"," ,@"[" ,@"]"
                            ,@"#" ,@"!" ,@"'" ,@"("
                            ,@")" ,@"*"
                            ,nil];
    
    NSArray *replaceChars = [NSArray arrayWithObjects:
                             @"%3B" ,@"%2F" ,@"%3F"
                             ,@"%3A" ,@"%40" ,@"%26"
                             ,@"%3D" ,@"%2B" ,@"%24"
                             ,@"%2C" ,@"%5B" ,@"%5D"
                             ,@"%23" ,@"%21" ,@"%27"
                             ,@"%28" ,@"%29" ,@"%2A"
                             ,nil];
    
    NSMutableString *encodedString = [[self stringByAddingPercentEscapesUsingEncoding:encoding] mutableCopy];
    
    for (NSUInteger i = 0; i < [escapeChars count]; i++) {
        [encodedString replaceOccurrencesOfString:[escapeChars objectAtIndex:i]
                                       withString:[replaceChars objectAtIndex:i]
                                          options:NSLiteralSearch
                                            range:NSMakeRange(0, [encodedString length])];
    }
    return [NSString stringWithString: encodedString];
}

- (BOOL) isHankakuString {

    BOOL rc = YES;

    for (NSUInteger i = 0; i < [self length]; i++) {
		NSString *aChar = [self substringWithRange:NSMakeRange(i, 1)];
		NSString *encodedChar = [aChar stringByURLEncoding:NSUTF8StringEncoding];
		if ([encodedChar length] >= 4) {
			rc = NO;
            break;
		}
	}
	return rc;
}

- (BOOL) isZenkakuString {

    BOOL rc = YES;

	for (NSUInteger i = 0; i < [self length]; i++) {
		NSString *aChar = [self substringWithRange:NSMakeRange(i, 1)];
		NSString *encodedChar = [aChar stringByURLEncoding:NSUTF8StringEncoding];
		if ([encodedChar length] < 4) {
			rc = NO;
            break;
		}
	}
	return rc;
}

- (NSString *) stringTransformWithTransform:(CFStringRef)transform reverse:(Boolean)reverse {
    NSMutableString* retStr = [[NSMutableString alloc] initWithString:self];
    CFStringTransform((CFMutableStringRef)retStr, NULL, transform, reverse);
    return retStr;
}

- (NSString *) stringToFullwidth {
    return [self stringTransformWithTransform:kCFStringTransformFullwidthHalfwidth
                                      reverse:true];
}

- (NSString *) stringToHalfwidth {
    return [self stringTransformWithTransform:kCFStringTransformFullwidthHalfwidth
                                      reverse:false];
}

- (NSString *) stringKatakanaToHiragana {
    return [self stringTransformWithTransform:kCFStringTransformHiraganaKatakana
                                      reverse:true];
}

- (NSString *) stringHiraganaToKatakana {
    return [self stringTransformWithTransform:kCFStringTransformHiraganaKatakana
                                      reverse:false];
}

- (NSString *) stringHiraganaToLatin {
    return [self stringTransformWithTransform:kCFStringTransformLatinHiragana
                                      reverse:true];
}

- (NSString *) stringLatinToHiragana {
    return [self stringTransformWithTransform:kCFStringTransformLatinHiragana
                                      reverse:false];
}

- (NSString*) stringKatakanaToLatin {
    return [self stringTransformWithTransform:kCFStringTransformLatinKatakana
                                      reverse:true];
}

- (NSString *) stringLatinToKatakana {
    return [self stringTransformWithTransform:kCFStringTransformLatinKatakana
                                      reverse:false];
}

@end
