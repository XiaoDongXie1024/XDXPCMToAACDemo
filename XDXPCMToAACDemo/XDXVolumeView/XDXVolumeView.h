//
//  XDXVolumeView.h
//  XDXPCMToAACDemo
//
//  Created by 小东邪 on 17/11/2017.
//

#import <UIKit/UIKit.h>

@interface XDXVolumeView : UIView

@property (nonatomic ,assign) CGFloat   currentVolumn;
@property (nonatomic ,assign) CGFloat   maxVolumn;

- (void)setCurrentVolumn:(CGFloat)currentVolumn isRecord:(BOOL)isRecord;

@end
