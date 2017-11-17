//
//  XDXVolumeView.m
//  XDXPCMToAACDemo
//
//  Created by 小东邪 on 17/11/2017.
//

#import "XDXVolumeView.h"

#define kMaxVolumn 40

@interface XDXVolumeView ()

@property (nonatomic, strong) CALayer *activityLayer;

@end

@implementation XDXVolumeView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self.layer addSublayer:self.activityLayer];
        self.maxVolumn              = kMaxVolumn;
        self.currentVolumn          = 0;
        self.layer.bounds           = self.bounds;
        self.backgroundColor        =[UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
}

- (BOOL)wantsUpdateLayer {
    return YES;
}

- (CALayer *)activityLayer {

    if (!_activityLayer) {
        _activityLayer = [CALayer layer];
    }

    _activityLayer.backgroundColor = [UIColor yellowColor].CGColor;
    return _activityLayer;
}

- (void)setCurrentVolumn:(CGFloat)currentVolumn isRecord:(BOOL)isRecord {
    _currentVolumn  = currentVolumn;
    CGRect rect     = self.bounds;
    CGFloat width   = rect.size.width;
    CGFloat height  = rect.size.height;

    double scale    = currentVolumn / self.maxVolumn;

    if (width > height) {
        rect.size.width     = rect.size.width  * scale;
    }else {
        rect.size.height    = rect.size.height * scale;
    }

    if (!self.activityLayer) {
        self.activityLayer  = [CALayer layer];
        self.activityLayer.backgroundColor = [UIColor yellowColor].CGColor;
    }

    if (!isRecord) {
        if (width > height) {
            self.activityLayer.frame = CGRectMake(self.frame.size.width - rect.size.width, 0, rect.size.width, rect.size.height);
        }else {
            self.activityLayer.frame = CGRectMake(0, self.frame.size.height - rect.size.height, rect.size.width, rect.size.height);
        }
    }else {
        self.activityLayer.frame = rect;
    }
}

@end
