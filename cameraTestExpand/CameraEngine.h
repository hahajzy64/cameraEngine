//
//  CameraEngine.h
//  cameraTestExpand
//
//  Created by jzy on 15/10/10.
//  Copyright © 2015年 jzy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CameraEngine : NSObject
/**
 *音量键+ 回调
 */
@property (nonatomic, copy) dispatch_block_t upBlock;

/*
 *手指捏合缩放镜头回调
 */
@property (nonatomic, copy) void (^focusChange)(float changeValue);

/**
 *  showView:镜头预览, focusView:焦点
 */
- (instancetype)initRecordInView:(UIView *)showView andFocusView:(UIView *)focusView;

/**
 *  闪光灯，调用打开，再调用关闭
 */
- (void)flash;

/**
 *  切换前后镜头
 */
- (void)changeTargetCamera;

/**
 *  开始录制
 */
- (void)start:(void (^)(void))success;

/**
 *  停止录制
 */
- (void)stop:(void (^)(void))success;

/**
 *  保存视频
 */
- (void)save:(void (^)(void))success;

/**
 *  添加音量键控制功能，默认已添加
 */
- (void)addVolumeButtonEvents;

/**
 *  移除音量键控制功能
 */
- (void)removeVolumeButtonEvents;

/**
 *  Slider拉伸缩放
 *
 *  @param scalePercent 缩放度 (0.0 - 1.0)
 */
- (void)setVideoZoomFactor:(float)scalePercent;

@end
