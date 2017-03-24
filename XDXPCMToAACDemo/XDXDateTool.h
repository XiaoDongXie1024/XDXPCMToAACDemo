//
//  XDXDateTool.h
//  
//
//  Created by zhangqi on 17/3/2016.
//
//

#import <Foundation/Foundation.h>

@interface XDXDateTool : NSObject

+ (instancetype)shareXDXDateTool;
- (NSString *)getDateWithFormatYearMonthDayHoreMinuteSecond;
- (NSString *)getDateWithFormat_yyyy_MM_dd_HH_mm_ss;
- (NSString *)getDateWithFormat_MMddyy_hhmmaAndDate:(NSDate *)date;
- (NSString *)getDateWithFormat_MMdd_hhmmaAndDate:(NSDate *)date;
- (NSString *)getDateWithFormat_MMMdhmma;

@end
