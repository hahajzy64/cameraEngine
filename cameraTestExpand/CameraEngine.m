//
//  CameraEngine.m
//  cameraTestExpand
//
//  Created by jzy on 15/10/10.
//  Copyright © 2015年 jzy. All rights reserved.
//
#import "cameraEngine.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface CameraEngine () <AVCaptureFileOutputRecordingDelegate>

@property (strong,nonatomic) AVCaptureSession *captureSession;//负责输入和输出设置之间的数据传递
@property (strong,nonatomic) AVCaptureDevice *captureDeviceVideo;//录像设备（镜头）
@property (strong,nonatomic) AVCaptureDevice *captureDeviceAudio;//录音设备
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInputVideo;//负责从captureDeviceVideo获得视频输入数据
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInputAudio;//负责从captureDeviceAudio获得音频输入数据
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层
@property (strong,nonatomic) AVCaptureMovieFileOutput *captureMovieFileOutput;//视频输出流
@property (assign,nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;//后台任务标识

@property (weak,nonatomic) UIView *viewContainer;//预览层
@property (weak,nonatomic) UIView *focusCursor;//聚焦图片

@end

@implementation CameraEngine

#pragma mark init
- (instancetype)initRecordInView:(UIView *)showView andFocusView:(UIView *)focusView{
    if (self = [super init]) {
        self.viewContainer = showView;
        self.focusCursor = focusView;
        
        CALayer *rootLayer = showView.layer;
        [rootLayer setMasksToBounds:YES];
        [self.captureVideoPreviewLayer setFrame:CGRectMake(0, 0, showView.frame.size.width, showView.frame.size.height + showView.frame.origin.y)];//这里高度加上了self.viewContainer.frame.origin.y才对
        [rootLayer insertSublayer:self.captureVideoPreviewLayer atIndex:0];
        
        [self.captureSession startRunning];
        [self addGenstureRecognizerInView];
    }
    return self;
}

#pragma mark getter
- (AVCaptureSession *)captureSession{
    if (!_captureSession) {
        _captureSession = [[AVCaptureSession alloc]init];
//        if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset3840x2160]) {//设置分辨率
//            _captureSession.sessionPreset = AVCaptureSessionPreset3840x2160;
//        }else{
            [_captureSession setSessionPreset:AVCaptureSessionPresetMedium];
//        }
        
        if ([_captureSession canAddInput:self.captureDeviceInputVideo]){
            [_captureSession addInput:self.captureDeviceInputVideo];
        }
        if ([_captureSession canAddInput:self.captureDeviceInputAudio]) {
            [_captureSession addInput:self.captureDeviceInputAudio];
        }
        if ([_captureSession canAddOutput:self.captureMovieFileOutput]) {
            [_captureSession addOutput:self.captureMovieFileOutput];
        }
        AVCaptureConnection *captureConnection=[self.captureMovieFileOutput     connectionWithMediaType:AVMediaTypeVideo];              //这个是什么。。之前没加切换不了前后摄像头。然而注释了也行了
        if ([captureConnection isVideoStabilizationSupported ]) {
            captureConnection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;
        }
    }
    return _captureSession;
}

- (AVCaptureDevice *)captureDeviceVideo{// 视频输入设备
    if (!_captureDeviceVideo) {
        _captureDeviceVideo = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];//取得后置摄像头
        if (!_captureDeviceVideo) {
            NSLog(@"取得后置摄像头时出现问题.");
        }
    }
    return _captureDeviceVideo;
}

- (AVCaptureDevice *)captureDeviceAudio{// 音频输入设备
    if (!_captureDeviceAudio) {
        _captureDeviceAudio = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
        if (!_captureDeviceAudio) {
            NSLog(@"取得麦克风时出现问题.");
        }
    }
    return _captureDeviceAudio;
}

- (AVCaptureDeviceInput *)captureDeviceInputVideo{// 视频输入设备数据
    if (!_captureDeviceInputVideo) {
        NSError *error;
        _captureDeviceInputVideo = [[AVCaptureDeviceInput alloc]initWithDevice:self.captureDeviceVideo error:&error];
        if(error){
            NSLog(@"设置视频输入设备数据发生错误，错误信息：%@",error.localizedDescription);
        }
    }
    return _captureDeviceInputVideo;
}

- (AVCaptureDeviceInput *)captureDeviceInputAudio{// 音频输入设备数据
    if (!_captureDeviceInputAudio) {
        NSError *error;
        _captureDeviceInputAudio = [[AVCaptureDeviceInput alloc]initWithDevice:self.captureDeviceAudio error:&error];
        if(error){
            NSLog(@"设置音频输入设备数据发生错误，错误信息：%@",error.localizedDescription);
        }
    }
    return _captureDeviceInputAudio;
}

- (AVCaptureMovieFileOutput *)captureMovieFileOutput{// 视频音频输出数据
    if (!_captureMovieFileOutput) {
        _captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc]init];
    }
    return _captureMovieFileOutput;
}

- (AVCaptureVideoPreviewLayer *)captureVideoPreviewLayer{// 视频预览
    if (!_captureVideoPreviewLayer) {
        _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:self.captureSession];
        [_captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    }
    return _captureVideoPreviewLayer;
}


#pragma mark 功能

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

/**
 *  当前摄像头是前镜头还是后镜头
 *
 *  @return 摄像头position
 */
-(AVCaptureDevicePosition)getCurrentDevicePosition{
    AVCaptureDevice *currentDevice=[self.captureDeviceInputVideo device];
    AVCaptureDevicePosition currentPosition=[currentDevice position];
    return currentPosition;
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [self.captureDeviceInputVideo device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

#pragma mark 对摄像头的操作
/**
 *  闪光灯，调用打开，再调用关闭
 */
- (void)flash{
    if ([self getCurrentDevicePosition] == AVCaptureDevicePositionFront) {//是前置摄像头就不开
        
    }else{
        if(self.captureDeviceVideo.torchMode == AVCaptureTorchModeOff){//打开  (用hasTorch不行,不管开没开闪光灯都是返回ture)
            [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
                [captureDevice setTorchMode:AVCaptureTorchModeOn];
            }];
        }else{                                                     //关闭
            [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
                [captureDevice setTorchMode:AVCaptureTorchModeOff];
            }];
        }
    }
}

/**
 *  前后摄像头切换
 */
- (void)changeTargetCamera{
    AVCaptureDevice *currentDevice = [self.captureDeviceInputVideo device];
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    [self removeNotificationFromCaptureDevice:currentDevice];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionFront;
    if (currentPosition == AVCaptureDevicePositionUnspecified||currentPosition == AVCaptureDevicePositionFront) {
        toChangePosition = AVCaptureDevicePositionBack;
    }
    toChangeDevice = [self getCameraDeviceWithPosition:toChangePosition];
    [self addNotificationToCaptureDevice:toChangeDevice];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.captureSession beginConfiguration];
    //移除原有输入对象
    [self.captureSession removeInput:self.captureDeviceInputVideo];
    //添加新的输入对象
    if ([self.captureSession canAddInput:toChangeDeviceInput]) {
        [self.captureSession addInput:toChangeDeviceInput];
        self.captureDeviceInputVideo = toChangeDeviceInput;
    }
    //提交会话配置
    [self.captureSession commitConfiguration];
}

/**
 *  设置聚焦点
 *
 *  @param point 聚焦点
 */
-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

/**
 *  添加点按手势，点按时聚焦
 */
- (void)addGenstureRecognizerInView{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.viewContainer addGestureRecognizer:tapGesture];
}

- (void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point= [tapGesture locationInView:self.viewContainer];
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
- (void)setFocusCursorWithPoint:(CGPoint)point{
    self.focusCursor.center=point;
    self.focusCursor.transform=CGAffineTransformMakeScale(1.5, 1.5);
    self.focusCursor.alpha=1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.focusCursor.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.focusCursor.alpha=0;
        
    }];
}

#pragma mark 通知
/**
 *  打印错误信息
 *
 *  @param error 错误
 *
 */
/**
 *  给输入设备添加通知
 */
-(void)addNotificationToCaptureDevice:(AVCaptureDevice *)captureDevice{
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled=YES;
    }];
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //捕获区域发生改变
    [notificationCenter addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
-(void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
/**
 *  移除所有通知
 */
-(void)removeNotification{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self];
}

-(void)addNotificationToCaptureSession:(AVCaptureSession *)captureSession{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //会话出错
    [notificationCenter addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:captureSession];
}

/**
 *  捕获区域改变
 *
 *  @param notification 通知对象
 */
-(void)areaChange:(NSNotification *)notification{
    NSLog(@"捕获区域改变...");
}

/**
 *  会话出错
 *
 *  @param notification 通知对象
 */
-(void)sessionRuntimeError:(NSNotification *)notification{
    NSLog(@"会话发生错误.");
}

#pragma mark 视频录制

- (void)start:(void (^)(void))success{
    //根据设备输出获得连接
    AVCaptureConnection *captureConnection=[self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    //根据连接取得设备输出的数据
    if (![self.captureMovieFileOutput isRecording]) {
        //如果支持多任务则则开始多任务
        if ([[UIDevice currentDevice] isMultitaskingSupported]) {
            self.backgroundTaskIdentifier=[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
        }
        
        //预览图层和视频方向保持一致
        captureConnection.videoOrientation=[self.captureVideoPreviewLayer connection].videoOrientation;
        NSString *outputFielPath=[NSTemporaryDirectory() stringByAppendingString:@"myMovie.mov"];
        NSLog(@"save path is :%@",outputFielPath);
        NSURL *fileUrl=[NSURL fileURLWithPath:outputFielPath];
        NSLog(@"fileUrl:%@",fileUrl);
        [self.captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    }
    else{
        [self.captureMovieFileOutput stopRecording];//停止录制
    }
}

- (void)stop:(void (^)(void))success{
    
}

- (void)save:(void (^)(void))success{
    
}

#pragma mark - 视频输出代理delegate
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    NSLog(@"开始录制...");
}
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    NSLog(@"视频录制完成.");
    //视频录入完成之后在后台将视频存储到相簿
    UIBackgroundTaskIdentifier lastBackgroundTaskIdentifier=self.backgroundTaskIdentifier;
    self.backgroundTaskIdentifier=UIBackgroundTaskInvalid;
    ALAssetsLibrary *assetsLibrary=[[ALAssetsLibrary alloc]init];
    [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"保存视频到相簿过程中发生错误，错误信息：%@",error.localizedDescription);
        }
        NSLog(@"outputUrl:%@",outputFileURL);
        [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
        if (lastBackgroundTaskIdentifier!=UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:lastBackgroundTaskIdentifier];
        }
        NSLog(@"成功保存视频到相簿.");
    }];
    
}

@end
