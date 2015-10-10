//
//  ViewController.m
//  cameraTestExpand
//
//  Created by jzy on 15/10/9.
//  Copyright © 2015年 jzy. All rights reserved.
//


#import "ViewController.h"
#import "cameraEngine.h"


@interface ViewController ()
@property (strong,nonatomic) CameraEngine *engine;

@property (strong, nonatomic) IBOutlet UIView *viewContainer;
@property (strong, nonatomic) IBOutlet UIView *focusCursor;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.engine = [[CameraEngine alloc]initRecordInView:self.viewContainer andFocusView:self.focusCursor];
}

-(BOOL)shouldAutorotate{
    return NO;
}

#pragma mark 按钮点击事件
- (IBAction)startAction:(id)sender {
    [self.engine start:^{
        
    }];
}
- (IBAction)tagerCamera:(id)sender {
    [self.engine changeTargetCamera];
}
- (IBAction)lightUp:(id)sender {    //闪光灯
    [self.engine flash];
}

- (IBAction)focusChange:(id)sender {
//    UISlider *slider = (UISlider *)sender;
//    AVCaptureDevice *currentDevice = [self.captureDeviceInput device];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
