//
//  CameraEngine.h
//  cameraTestExpand
//
//  Created by jzy on 15/10/10.
//  Copyright © 2015年 jzy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CameraEngine : NSObject

- (instancetype)initRecordInView:(UIView *)showView andFocusView:(UIView *)focusView;

- (void)flash;
- (void)changeTargetCamera;

- (void)start:(void (^)(void))success;
- (void)stop:(void (^)(void))success;
- (void)save:(void (^)(void))success;

@end
