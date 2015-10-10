//
//  ViewController.m
//  cameraTestExpand
//
//  Created by jzy on 15/10/9.
//  Copyright © 2015年 jzy. All rights reserved.
//


#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/PHPhotoLibrary.h>

static const NSString *AVCaptureStillImageIsCapturingStillImageContext = @"AVCaptureStillImageIsCapturingStillImageContext";

@interface ViewController ()<AVCaptureFileOutputRecordingDelegate,UIGestureRecognizerDelegate>
typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层
@property (strong,nonatomic) AVCaptureSession *captureSession;//负责输入和输出设置之间的数据传递
@property (strong,nonatomic) AVCaptureDevice *captureDevice;//录像设备（镜头）
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (strong,nonatomic) AVCaptureMovieFileOutput *captureMovieFileOutput;//视频输出流
@property (assign,nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;//后台任务标识

//@property (strong,nonatomic) AVCaptureStillImageOutput *stillImageOutput;
//@property (assign,nonatomic) CGFloat effectiveScale;
//@property (assign,nonatomic) CGFloat beginGestureScale;

@property (strong, nonatomic) IBOutlet UIView *viewContainer;
@property (strong, nonatomic) IBOutlet UIView *focusCursor;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    1. session
//    AVFoundation是基于session(会话)概念的。 一个session用于控制数据从input设备到output设备的流向。
//    声明一个session:
    self.captureSession = [[AVCaptureSession alloc]init];
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset3840x2160]) {//设置分辨率
        _captureSession.sessionPreset=AVCaptureSessionPreset3840x2160;
    }else{
        [self.captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    }
    
//    2. capture device
//    定义好session后，就该定义session所使用的设备了。（使用AVMediaTypeVideo 来支持视频和图片，用AVMediaTypeAudio来支持录音）
//    取得后置摄像头
    self.captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
//    取得音频输入设备
    AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
//    // Make a still image output
//    self.stillImageOutput = [[AVCaptureStillImageOutput alloc]init];
//    [self.stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:(__bridge void * _Nullable)(AVCaptureStillImageIsCapturingStillImageContext)];
//    if ( [self.captureSession canAddOutput:self.stillImageOutput] )
//        [self.captureSession addOutput:self.stillImageOutput];
    
//    3. capture device input
//    有了capture device, 然后就获取其input capture device（也就是之前实例化的摄像头，和录音设备），并将该input device加到session上。
    NSError *error;
    self.captureDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:self.captureDevice error:&error];
    
    AVCaptureDeviceInput *captureDeviceInput2 = [[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    
    if ([self.captureSession canAddInput:self.captureDeviceInput]){
        [self.captureSession addInput:self.captureDeviceInput];
//        AVCaptureConnection *captureConnection=[_captureMovieFileOutput     connectionWithMediaType:AVMediaTypeVideo];              //这个是什么。。
//        if ([captureConnection isVideoStabilizationSupported ]) {
//            captureConnection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;
//        }
    }
    if ([self.captureSession canAddInput:captureDeviceInput2]) {
        [self.captureSession addInput:captureDeviceInput2];
    }
    
//初始化设备输出对象，用于获得输出数据
    self.captureMovieFileOutput=[[AVCaptureMovieFileOutput alloc]init];
//将设备输出添加到会话中
    if ([self.captureSession canAddOutput:self.captureMovieFileOutput]) {
        [self.captureSession addOutput:self.captureMovieFileOutput];
    }
    
//    4. preview
//    在定义output device之前，我们可以先使用preview layer来显示一下camera buffer中的内容。这也将是相机的“取景器”。
//    AVCaptureVideoPreviewLayer可以用来快速呈现相机(摄像头)所收集到的原始数据。
//    我们使用第一步中定义的session来创建preview layer, 并将其添加到main view layer上。
    
    self.captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:self.captureSession];
    [self.captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    CALayer *rootLayer = self.viewContainer.layer;
    [rootLayer setMasksToBounds:YES];
    [self.captureVideoPreviewLayer setFrame:CGRectMake(0, 0, self.viewContainer.frame.size.width, self.viewContainer.frame.size.height + self.viewContainer.frame.origin.y)];//这里高度加上了self.viewContainer.frame.origin.y才对
    [rootLayer insertSublayer:self.captureVideoPreviewLayer atIndex:0];
    
//    5. start Run
//    最后需要start the session.(不然不显示取景器,也可以放到viewDidAppear中。不过同样地效果，viewDidAppear显示慢一些)
    [self.captureSession startRunning];
    
    [self addNotificationToCaptureDevice:self.captureDevice];
    [self addGenstureRecognizer];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    //    [self.captureSession startRunning];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.captureSession stopRunning];
//    [self.stillImageOutput removeObserver:self forKeyPath:@"isCapturingStillImage"];
}

-(BOOL)shouldAutorotate{
    return NO;
}

#pragma mark 按钮点击事件
- (IBAction)startAction:(id)sender {
    UIButton *btn = (UIButton *)sender;
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
        [btn setTitle:@"停止" forState:UIControlStateNormal];
    }
    else{
        [self.captureMovieFileOutput stopRecording];//停止录制
        [btn setTitle:@"开始" forState:UIControlStateNormal];
    }
}
- (IBAction)tagerCamera:(id)sender {
    AVCaptureDevice *currentDevice=[self.captureDeviceInput device];
    AVCaptureDevicePosition currentPosition=[currentDevice position];
    [self removeNotificationFromCaptureDevice:currentDevice];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition=AVCaptureDevicePositionFront;
    if (currentPosition==AVCaptureDevicePositionUnspecified||currentPosition==AVCaptureDevicePositionFront) {
        toChangePosition=AVCaptureDevicePositionBack;
    }
    toChangeDevice=[self getCameraDeviceWithPosition:toChangePosition];
    [self addNotificationToCaptureDevice:toChangeDevice];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.captureSession beginConfiguration];
    //移除原有输入对象
    [self.captureSession removeInput:self.captureDeviceInput];
    //添加新的输入对象
    if ([self.captureSession canAddInput:toChangeDeviceInput]) {
        [self.captureSession addInput:toChangeDeviceInput];
        self.captureDeviceInput=toChangeDeviceInput;
    }
    //提交会话配置
    [self.captureSession commitConfiguration];
}
- (IBAction)lightUp:(id)sender {    //闪光灯
    if ([self getCurrentDevicePosition] == AVCaptureDevicePositionFront) {//前置摄像头就不开
    }else{
        if(self.captureDevice.torchMode == AVCaptureTorchModeOff){//打开  (用hasTorch不行,不管开没开闪光灯都是返回ture)
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

- (IBAction)focusChange:(id)sender {
//    UISlider *slider = (UISlider *)sender;
//    AVCaptureDevice *currentDevice = [self.captureDeviceInput device];
}

#pragma mark - 通知
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
 *  设备连接成功
 *
 *  @param notification 通知对象
 */
-(void)deviceConnected:(NSNotification *)notification{
    NSLog(@"设备已连接...");
}
/**
 *  设备连接断开
 *
 *  @param notification 通知对象
 */
-(void)deviceDisconnected:(NSNotification *)notification{
    NSLog(@"设备已断开.");
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
        UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"成功" message:@"成功保存视频到相簿." delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil, nil];
        [alertView show];
        NSLog(@"成功保存视频到相簿.");
    }];
    
}

#pragma mark - 私有方法

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}
/**
 *  取得当前摄像头position
 *
 *  @return 摄像头position
 */
-(AVCaptureDevicePosition)getCurrentDevicePosition{
    AVCaptureDevice *currentDevice=[self.captureDeviceInput device];
    AVCaptureDevicePosition currentPosition=[currentDevice position];
    return currentPosition;
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [self.captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

/**
 *  设置闪光灯模式     //拍照模式下才有用
 *
 *  @param flashMode 闪光灯模式
 */
//-(void)setFlashMode:(AVCaptureFlashMode )flashMode{
//    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
//        if ([captureDevice isFlashModeSupported:flashMode]) {
//            [captureDevice setFlashMode:flashMode];
//        }
//    }];
//}

/**
 *  设置聚焦模式
 *
 *  @param focusMode 聚焦模式  lensPosition
 */
-(void)setFocusMode:(AVCaptureFocusMode )focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}
/**
 *  设置曝光模式
 *
 *  @param exposureMode 曝光模式
 */
-(void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
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
-(void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.viewContainer addGestureRecognizer:tapGesture];
}
-(void)tapScreen:(UITapGestureRecognizer *)tapGesture{
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
-(void)setFocusCursorWithPoint:(CGPoint)point{
    self.focusCursor.center=point;
    self.focusCursor.transform=CGAffineTransformMakeScale(1.5, 1.5);
    self.focusCursor.alpha=1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.focusCursor.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.focusCursor.alpha=0;
        
    }];
}

//#pragma mark 点击事件代理
//- (IBAction)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer {
//    BOOL allTouchesAreOnThePreviewLayer = YES;
//    NSUInteger numTouches = [recognizer numberOfTouches], i;
//    for ( i = 0; i < numTouches; ++i ) {
//        CGPoint location = [recognizer locationOfTouch:i inView:self.viewContainer];
//        CGPoint convertedLocation = [self.captureVideoPreviewLayer convertPoint:location fromLayer:self.captureVideoPreviewLayer.superlayer];
//        if ( ! [self.captureVideoPreviewLayer containsPoint:convertedLocation] ) {
//            allTouchesAreOnThePreviewLayer = NO;
//            break;
//        }
//    }
//    
//    if ( allTouchesAreOnThePreviewLayer ) {
//        self.effectiveScale = self.beginGestureScale * recognizer.scale;
//        if (self.effectiveScale < 1.0)
//            self.effectiveScale = 1.0;
//        CGFloat maxScaleAndCropFactor = [[self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
//        if (self.effectiveScale > maxScaleAndCropFactor)
//            self.effectiveScale = maxScaleAndCropFactor;
//        [CATransaction begin];
//        [CATransaction setAnimationDuration:.025];
//        [self.captureVideoPreviewLayer setAffineTransform:CGAffineTransformMakeScale(self.effectiveScale, self.effectiveScale)];
//        [CATransaction commit];
//    }
//}




- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
