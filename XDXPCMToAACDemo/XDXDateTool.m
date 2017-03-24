//
//  XDXDateTool.m
//  
//
//  Created by zhangqi on 17/3/2016.
//
//

#import "XDXDateTool.h"

@interface XDXDateTool()

@property (nonatomic,strong) NSDateFormatter *dateformatter;

@end

@implementation XDXDateTool
static XDXDateTool *_instance = nil;

- (NSDateFormatter *)dateformatter
{
    static NSDateFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
    });
    return dateFormatter;
}


+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    if (_instance == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _instance = [super allocWithZone:zone];
        });
    }
    return _instance;
}

- (id)init
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super init];
    });
    return _instance;
}

+ (instancetype)shareXDXDateTool
{
     return [[self alloc] init];
}

+ (id)mutableCopyWithZone:(struct _NSZone *)zone
{
    return _instance;
}

- (NSString *)getDateWithFormatYearMonthDayHoreMinuteSecond
{
    [self.dateformatter setDateFormat:@"yyyy-MM-dd-hh:mm:ss"];
    return [self.dateformatter stringFromDate:[NSDate date]];
}

- (NSString *)getDateWithFormat_yyyy_MM_dd_HH_mm_ss
{
    [self.dateformatter setDateFormat:@"yyyy_MM_dd__HH_mm_ss"];
    return [self.dateformatter stringFromDate:[NSDate date]];
}

- (NSString *)getDateWithFormat_MMddyy_hhmmaAndDate:(NSDate *)date
{
    [self.dateformatter setAMSymbol:@"AM"];
    [self.dateformatter setPMSymbol:@"PM"];
    [self.dateformatter setDateFormat:@"MM/dd/yyyy hh:mm:a"];
    return [self.dateformatter stringFromDate:date];
}

- (NSString *)getDateWithFormat_MMdd_hhmmaAndDate:(NSDate *)date
{
    [self.dateformatter setTimeZone:[NSTimeZone localTimeZone]];
    [self.dateformatter setDateFormat:@"MM-dd hh:mm a"];
    return [self.dateformatter stringFromDate:date];
}

- (NSString *)getDateWithFormat_MMMdhmma
{
    [self.dateformatter setDateFormat:@"MMM d, h:mm a"];
    return [self.dateformatter stringFromDate:[NSDate date]];
}

@end
