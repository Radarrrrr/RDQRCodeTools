//
//  FitCamera.m
//
//  Created by Radar on 16/4/13.
//  Copyright © 2016年 Radar. All rights reserved.
//

#import "FitCamera.h"
#import <ImageIO/ImageIO.h>


#define screenScale [UIScreen mainScreen].scale
#define Round_Scale(x) round(x*screenScale)/screenScale
#define ATINT(x) Round_Scale([UIScreen mainScreen].bounds.size.width/375.0*(x))

#define adjustingFocus @"adjustingFocus"


@interface FitCamera()
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) AVCaptureDeviceInput *inputDevice;
@property (nonatomic, copy) void (^switchBlock)(void);

@end

@implementation FitCamera
- (void)dealloc
{
    //NSLog(@"照相机管理人释放了");
    if ([self.session isRunning]) {
        [self.session stopRunning];
        self.session = nil;
    }
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device && [device isFocusPointOfInterestSupported]) {
        [device removeObserver:self forKeyPath:adjustingFocus context:nil];
    }
}

- (void)configureWithParentLayer:(UIView *)parent
{
    if (self.session) {
        return;
    }
    if (!parent) {
        SHOWALERT(@"提示", @"请加入负载视图");
        return;
    }
    
    self.session = [[AVCaptureSession alloc] init];
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = parent.bounds;
    [parent.layer addSublayer:self.previewLayer];
    //对焦队列
    [self createQueue];
    //加入输入设备（前置或后置摄像头）
    [self addVideoInputFrontCamera:NO];
    [self addDataOutput];
//
    [self addStillImageOutput];
    //加入对焦框
    [self initfocusImageWithParent:parent];
    //对焦MVO
    [self setFocusObserver:YES];
    [self.session startRunning];
}



/**
 *  对焦的框
 */
- (void)initfocusImageWithParent:(UIView *)view;
{
    UIImageView *imgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"touch_focus_x.png"]];
    imgView.alpha = 0;
    if (view.superview!=nil) {
        [view.superview addSubview:imgView];
    }
    self.focusImageView = imgView;
}
/**
 *  创建一个队列，防止阻塞主线程
 */
- (void)createQueue {
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    self.sessionQueue = sessionQueue;
}
/**
 *  添加输入设备
 *
 *  @param front 前或后摄像头
 */
- (void)addVideoInputFrontCamera:(BOOL)front {
    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    for (AVCaptureDevice *device in devices) {
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if ([device position] == AVCaptureDevicePositionBack) {
                backCamera = device;
            }  else {
                frontCamera = device;
            }
        }
    }
    NSError *error = nil;
    if (front) {
        AVCaptureDeviceInput *frontFacingCameraDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        
        if (!error) {
            if ([_session canAddInput:frontFacingCameraDeviceInput]) {
                [_session addInput:frontFacingCameraDeviceInput];
                self.inputDevice = frontFacingCameraDeviceInput;
            } else {
                NSLog(@"Couldn't add front facing video input");
            }
        }else{
            NSLog(@"你的设备没有照相机");
        }
    } else {
        AVCaptureDeviceInput *backFacingCameraDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        if (!error) {
            if ([_session canAddInput:backFacingCameraDeviceInput]) {
                [_session addInput:backFacingCameraDeviceInput];
                self.inputDevice = backFacingCameraDeviceInput;
            } else {
                NSLog(@"Couldn't add back facing video input");
            }
        }else{
            NSLog(@"你的设备没有照相机");
        }
    }
    if (error) {
        SHOWALERT(@"未获得授权使用摄像头", @"请在IOS\"设置\"-\"隐私\"-\"相机\"中打开");
    }
}


/**
 *  添加输出设备
 */
- (void)addStillImageOutput
{
    
    AVCaptureStillImageOutput *tmpOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];//输出jpeg
    tmpOutput.outputSettings = outputSettings;
    
    //    AVCaptureConnection *videoConnection = [self findVideoConnection];
    
    [_session addOutput:tmpOutput];
    
    self.stillImageOutput = tmpOutput;
    
    AVCaptureVideoDataOutput *videoOut =[[AVCaptureVideoDataOutput alloc] init];
    [videoOut setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    [_session addOutput:videoOut];
    
    
    
}

-(void)addDataOutput
{
    
    AVCaptureMetadataOutput  *output = [[AVCaptureMetadataOutput alloc]init];
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    [_session addOutput:output];
    self.stillDataOutput=output;
    
    NSLog(@"%@======available",[output availableMetadataObjectTypes]);
    
    if ([[output availableMetadataObjectTypes] count]>0){
        
        output.metadataObjectTypes = @[AVMetadataObjectTypeEAN13Code,
                                       AVMetadataObjectTypeEAN8Code,
                                       AVMetadataObjectTypeCode128Code,
                                       AVMetadataObjectTypeQRCode];

    }

    CGFloat screenHeight = ScreenSize.height;
    CGFloat screenWidth = ScreenSize.width;
    CGRect cropRect = CGRectMake((screenWidth - TransparentArea([DDScanningView width], [DDScanningView height]).width) / 2,
                                 (screenHeight - TransparentArea([DDScanningView width], [DDScanningView height]).height) / 2,
                                 TransparentArea([DDScanningView width], [DDScanningView height]).width,
                                 TransparentArea([DDScanningView width], [DDScanningView height]).height);
    
    [output setRectOfInterest:CGRectMake(cropRect.origin.y / screenHeight,
                                         cropRect.origin.x / screenWidth,
                                         cropRect.size.height / screenHeight,
                                         cropRect.size.width / screenWidth)];
    
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    
    if (metadataObjects.count > 0) {
        AVMetadataMachineReadableCodeObject *metadateObject = [metadataObjects objectAtIndex:0];
        NSString *stringValue = metadateObject.stringValue;
        if (stringValue && ![stringValue isEqualToString:@""]) 
        {
            if(self.delegate&&[self.delegate respondsToSelector:@selector(getScanCode:)]){
                [_delegate getScanCode:stringValue];
            }
        }

    }
    
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection NS_AVAILABLE(10_7, NA)
{
//    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL,
//                                                                 sampleBuffer, kCMAttachmentMode_ShouldPropagate);
//    NSDictionary *metadata = [[NSMutableDictionary alloc]
//                              initWithDictionary:(__bridge NSDictionary*)metadataDict];
//    CFRelease(metadataDict);
//    NSDictionary *exifMetadata = [[metadata
//                                   objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    
   // 感光亮度 不太准 是靠识别图片的方式
//   self.brightnessValue = [[exifMetadata
//                              objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
//    
//    if(self.delegate&&[self.delegate respondsToSelector:@selector(getCameraLight:)]){
//        [_delegate getCameraLight:_brightnessValue];
//
//    }

}



/**
 *  切换闪光灯模式
 *  （切换顺序：最开始是auto，然后是off，最后是on，一直循环）
 *  @param sender: 闪光灯按钮
 */
- (void)switchFlashMode:(UIButton*)sender
{
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (!captureDeviceClass) {
        SHOWALERT(@"提示", @"您的设备没有拍照功能");
        return;
    }
    NSString *imgStr = @"";
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [device lockForConfiguration:nil];
    if ([device hasFlash]) {
        if (device.flashMode == AVCaptureFlashModeOff) {
            device.flashMode = AVCaptureFlashModeOn;
            imgStr = @"close_flash";
            
        } else if (device.flashMode == AVCaptureFlashModeOn) {
            device.flashMode = AVCaptureFlashModeAuto;
            imgStr = @"auto_flash";
            
        } else if (device.flashMode == AVCaptureFlashModeAuto) {
            device.flashMode = AVCaptureFlashModeOff;
            imgStr = @"open_flash";
        }
        if (sender) {
            [sender setImage:[UIImage imageNamed:imgStr] forState:UIControlStateNormal];
        }
    } else {
        SHOWALERT(@"提示", @"您的设备没有闪光灯功能");
    }
    [device unlockForConfiguration];
}
/**
 *  前后镜
 *
 *  @param isFrontCamera
 */
- (void)switchCamera:(BOOL)isFrontCamera didFinishChanceBlock:(void (^)(void))completion
{
    if (!_inputDevice) {
        
        if (completion) {
            completion();
        }
        SHOWALERT(@"提示", @"您的设备没有摄像头");
        return;
    }
    if (completion) {
        self.switchBlock = [completion copy];
    }
    CABasicAnimation *caAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
    //    caAnimation.removedOnCompletion = NO;
    //    caAnimation.fillMode = kCAFillModeForwards;
    caAnimation.fromValue = @(0);
    caAnimation.toValue = @(M_PI);
    caAnimation.duration = 1.f;
    caAnimation.repeatCount = 1;
    caAnimation.delegate = self;
    caAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.previewLayer addAnimation:caAnimation forKey:@"anim"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_session beginConfiguration];
        [_session removeInput:_inputDevice];
        [self addVideoInputFrontCamera:isFrontCamera];
        [_session commitConfiguration];
    });
}
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if (self.switchBlock) {
        self.switchBlock();
    }
}
/**
 *  点击对焦
 *
 *  @param devicePoint
 */
- (void)focusInPoint:(CGPoint)devicePoint
{
    if (CGRectContainsPoint(_previewLayer.bounds, devicePoint) == NO) {
        return;
    }
    self.isManualFocus = YES;
    [self focusImageAnimateWithCenterPoint:devicePoint];
    devicePoint = [self convertToPointOfInterestFromViewCoordinates:devicePoint];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
    
    
    
    
}
- (void)focusImageAnimateWithCenterPoint:(CGPoint)point
{
    CGPoint imagePoint = CGPointMake(point.x, point.y+64);
    [self.focusImageView setCenter:imagePoint];
    self.focusImageView.transform = CGAffineTransformMakeScale(2.0, 2.0);
    __weak FitCamera *weakSelf =self;
    [UIView animateWithDuration:0.3f delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
        weakSelf.focusImageView.alpha = 1.f;
        weakSelf.focusImageView.transform = CGAffineTransformMakeScale(1.0, 1.0);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5f delay:0.5f options:UIViewAnimationOptionAllowUserInteraction animations:^{
            weakSelf.focusImageView.alpha = 0.f;
        } completion:^(BOOL finished) {
            weakSelf.isManualFocus = YES;
        }];
    }];
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    
    dispatch_async(_sessionQueue, ^{
        AVCaptureDevice *device = [self.inputDevice device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode])
            {
                [device setFocusMode:focusMode];
                [device setFocusPointOfInterest:point];
            }
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode])
            {
                [device setExposureMode:exposureMode];
                [device setExposurePointOfInterest:point];
            }
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        }
        else
        {
            NSLog(@"%@", error);
        }
    });
}

/**
 *  外部的point转换为camera需要的point(外部point/相机页面的frame)
 *
 *  @param viewCoordinates 外部的point
 *
 *  @return 相对位置的point
 */
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates {
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = _previewLayer.bounds.size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = self.previewLayer;
    
    if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResize]) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for(AVCaptureInputPort *port in [[self.session.inputs lastObject]ports]) {
            if([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspect]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if(point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if(point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                    
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}



/**
 *  查找摄像头连接设备
 */
- (AVCaptureConnection *)findVideoConnection {
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in _stillImageOutput.connections) {
        for (AVCaptureInputPort *port in connection.inputPorts) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
            break;
        }
    }
    return videoConnection;
}
#pragma -mark Observer
- (void)setFocusObserver:(BOOL)yes
{
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device && [device isFocusPointOfInterestSupported]) {
        if (yes) {
            [device addObserver:self forKeyPath:adjustingFocus options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
        }else{
            [device removeObserver:self forKeyPath:adjustingFocus context:nil];
            
        }
        
    }else{
        SHOWALERT(@"未获得授权使用摄像头", @"请在IOS\"设置\"-\"隐私\"-\"相机\"中打开");
    }
}


//监听对焦是否完成了
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:adjustingFocus]) {
        BOOL isAdjustingFocus = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (isAdjustingFocus) {
            if (self.isManualFocus==NO) {
                [self focusImageAnimateWithCenterPoint:CGPointMake(self.previewLayer.bounds.size.width/2, self.previewLayer.bounds.size.height/2)];
            }
            if ([self.delegate respondsToSelector:@selector(cameraDidStareFocus)]) {
                [self.delegate cameraDidStareFocus];
            }
        }else{
            
            if ([self.delegate respondsToSelector:@selector(cameraDidFinishFocus)]) {
                [self.delegate cameraDidFinishFocus];
            }
        }
        
        
    }
}

@end

#pragma DDScanningView

@interface DDScanningView ()
@property (strong, nonatomic) UIView *line;
@property (strong, nonatomic) NSTimer *timer;
@property (assign, nonatomic) CGFloat origin;
@property (assign, nonatomic) BOOL isReachEdge;


@property (assign , nonatomic) DDScaningLineMoveMode lineMoveMode;
@property (assign, nonatomic) DDScaningLineMode lineMode;
@property (assign, nonatomic) DDScaningWarningTone warninTone;

@property (strong,nonatomic) FitCamera *cameraManger;




@end


@implementation DDScanningView

- (instancetype)initWithFrame:(CGRect)frame withScanType:(DDScaningType)scanType withManger:(FitCamera*)cManager{
    self = [super initWithFrame:frame];
    if (self) {
        self.scaningType=scanType;
        self.cameraManger=cManager;
        [self initConfig];
        
        
    }
    return self;
}


- (void)initConfig{
    
    self.backgroundColor = [UIColor clearColor];
    
    topShowBtn =[UIButton buttonWithType:UIButtonTypeCustom];
    topShowBtn.backgroundColor =[UIColor clearColor];
    topShowBtn.titleLabel.textColor=[UIColor whiteColor];
    topShowBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    topShowBtn.titleLabel.textAlignment=NSTextAlignmentCenter;
    [self addSubview:topShowBtn];
    
    codeBtn =[UIButton buttonWithType:UIButtonTypeCustom];
    codeBtn.backgroundColor=[UIColor clearColor];
    codeBtn.layer.borderWidth=1;
    codeBtn.layer.borderColor=[UIColor whiteColor].CGColor;
    codeBtn.layer.cornerRadius=20;
    [codeBtn setTitle:@"输入条码" forState:UIControlStateNormal];
    codeBtn.titleLabel.textColor=[UIColor whiteColor];
    codeBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [codeBtn addTarget:self action:@selector(codeBtn) forControlEvents:UIControlEventTouchUpInside];
    //[self addSubview:codeBtn];
    
    self.isStop=NO;
    self.lineMode = DDScaningLineModeImge;//使用线图模式
    self.lineMoveMode = DDScaningLineMoveModeDown;
    
    
    
}
-(void)refreshTopLabelText:(float)brightNessV
{
    if (brightNessV<4&&self.scaningType==DDScaningPhotoType) {
        
//        [topShowBtn setTitle:@"当前画面太暗,建议打开闪光灯" forState:UIControlStateNormal];
    }else{
        if (self.scaningType==DDScaningCode){
            
        [topShowBtn setTitle:@"二维码/条形码到框内扫描即可" forState:UIControlStateNormal];
        }else{
        [topShowBtn setTitle:@"请将图书封面放入取景框拍照" forState:UIControlStateNormal];
            
        }
    }
    
}
-(void)codeBtn
{
    if (self.delegate&&[self.delegate respondsToSelector:@selector(codeBtn)]) {
        [_delegate codeBtn];
    }
}

- (UIView *)creatLine{
    
    if (_lineMoveMode == DDScaningLineMoveModeNone) return nil;
    
    UIView *line = [[UIView alloc]initWithFrame:CGRectMake(self.frame.size.width*.5 - TransparentArea([DDScanningView width], [DDScanningView height]).width*.5, self.frame.size.height*.5 - TransparentArea([DDScanningView width], [DDScanningView height]).height*.5, TransparentArea([DDScanningView width], [DDScanningView height]).width, 2)];
    if (_lineMode == DDScaningLineModeDeafult) {
        line.backgroundColor = LineColor;
        self.origin = line.frame.origin.y;
    }
    
    if (_lineMode == DDScaningLineModeImge) {
        line.backgroundColor = [UIColor clearColor];
        self.origin = line.frame.origin.y;
        UIImageView *v = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"fc_scan_line"]];
        v.contentMode = UIViewContentModeScaleAspectFill;
        v.frame = CGRectMake(0, 0, line.frame.size.width, line.frame.size.height);
        [line addSubview:v];
    }
    
    //网格动画 以防后改
    if (_lineMode == DDScaningLineModeGrid) {
        line.clipsToBounds = YES;
        CGRect frame = line.frame;
        frame.size.height = TransparentArea([DDScanningView width], [DDScanningView height]).height;
        line.frame = frame;
        UIImageView *iv = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"scan_net@2x.png"]];
        iv.frame = CGRectMake(0, -TransparentArea([DDScanningView width], [DDScanningView height]).height, line.frame.size.width, TransparentArea([DDScanningView width], [DDScanningView height]).height);
        [line addSubview:iv];
    }
    
    return line;
}


- (void)starMove{
    
    if (_lineMode == DDScaningLineModeDeafult) {  //注意！！！此模式非常消耗性能的哦
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.0125 target:self selector:@selector(showLine) userInfo:nil repeats:YES];
        [self.timer fire];
    }
    
    if (_lineMode == DDScaningLineModeImge) {
        
        [self showLine];
    }
    
    if (_lineMode == DDScaningLineModeGrid) {
        
        UIImageView *iv = _line.subviews[0];
        [UIView animateWithDuration:1.5 delay:0.1 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            iv.transform = CGAffineTransformTranslate(iv.transform, 0, TransparentArea([DDScanningView width], [DDScanningView height]).height);
        } completion:^(BOOL finished) {
            iv.frame = CGRectMake(0, -TransparentArea([DDScanningView width], [DDScanningView height]).height, _line.frame.size.width, TransparentArea([DDScanningView width], [DDScanningView height]).height);
            [self starMove];
        }];
    }
}

- (void)showLine{
    
    if (_lineMode == DDScaningLineModeDeafult) {
        CGRect frame = self.line.frame;
        self.isReachEdge?(frame.origin.y -= LineMoveSpeed):(frame.origin.y += LineMoveSpeed);
        self.line.frame = frame;
        
        UIView *shadowLine = [[UIView alloc]initWithFrame:self.line.frame];
        shadowLine.backgroundColor = self.line.backgroundColor;
        [self addSubview:shadowLine];
        [UIView animateWithDuration:LineShadowLastInterval animations:^{
            shadowLine.alpha = 0;
        } completion:^(BOOL finished) {
            [shadowLine removeFromSuperview];
        }];
        
        if (_lineMoveMode == DDScaningLineMoveModeDown) {
            if (self.line.frame.origin.y - self.origin >= TransparentArea([DDScanningView width], [DDScanningView height]).height) {
                [self.line removeFromSuperview];
                CGRect frame = self.line.frame;
                frame.origin.y = ScreenSize.height*.5 - TransparentArea([DDScanningView width], [DDScanningView height]).height*.5;
                self.line.frame = frame;
            }
            
        }else if(_lineMoveMode==DDScaningLineMoveModeUpAndDown){
            if (self.line.frame.origin.y - self.origin >= TransparentArea([DDScanningView width], [DDScanningView height]).height) {
                self.isReachEdge = !self.isReachEdge;
            }else if (self.line.frame.origin.y == self.origin){
                self.isReachEdge = !self.isReachEdge;
            }
        }
    }
    
    if (_lineMode == DDScaningLineModeImge) {
        [self imagelineMoveWithMode:_lineMoveMode];
    }
}

- (void)imagelineMoveWithMode:(DDScaningLineMoveMode)mode{
   
    if(self.isStop==YES) {
        return;
    }
    
    [UIView animateWithDuration:2 animations:^{
        CGRect frame = self.line.frame;
        frame.origin.y +=  TransparentArea([DDScanningView width], [DDScanningView height]).height-2;
        self.line.frame = frame;
        // NSLog(@"%f====finish",self.line.frame.origin.y);
    } completion:^(BOOL finished) {
        if (mode == DDScaningLineMoveModeDown) {
            CGRect frame = self.line.frame;
            frame.origin.y = self.frame.size.height*.5 - TransparentArea([DDScanningView width], [DDScanningView height]).height*.5;
            self.line.frame = frame;
            //NSLog(@"%f====finish",self.line.frame.origin.y);
            [self imagelineMoveWithMode:mode];
        }else{
            [UIView animateWithDuration:2 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                CGRect frame = self.line.frame;
                frame.origin.y = self.frame.size.height*.5 - TransparentArea([DDScanningView width], [DDScanningView height]).height*.5;
                self.line.frame = frame;
            } completion:^(BOOL finished) {
                [self imagelineMoveWithMode:mode];
            }];
        }
    }];

}

- (void)drawRect:(CGRect)rect{
   
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetRGBFillColor(context, 40/255.0, 40/255.0, 40/255.0, .5);
    CGContextFillRect(context, rect);
    //SLog(@"%@", NSStringFromCGSize(TransparentArea([DDScanningView width], [DDScanningView height])));
    
    if (self.line) {
        [_line removeFromSuperview];
    }
    
    if (self.scaningType==DDScaningCode) {
        _clearDrawRect = CGRectMake(rect.size.width / 2 - TransparentArea([DDScanningView width], [DDScanningView height]).width / 2,
                                   rect.size.height / 2 - TransparentArea([DDScanningView width], [DDScanningView height]).height / 2,
                                   TransparentArea([DDScanningView width], [DDScanningView height]).width,TransparentArea([DDScanningView width], [DDScanningView height]).height);
        
        
        //输入条码按钮显示
        codeBtn.hidden=NO;
        codeBtn.frame =CGRectMake(0, 0,100, 40);
        codeBtn.center =CGPointMake(self.frame.size.width/2,(self.frame.size.height-CGRectGetMaxY(_clearDrawRect))/2+CGRectGetMaxY(_clearDrawRect));
        ;
        self.isStop=NO;
    
        self.line = [self creatLine];
        [self addSubview:_line];
        [self starMove];
        [topShowBtn setTitle:@"条形码到框内扫描即可" forState:UIControlStateNormal];
        
        //重新聚焦到摄像机中心
        [self.cameraManger focusImageAnimateWithCenterPoint:CGPointMake(self.frame.size.width/2, self.frame.size.height/2)];
       
    }else{
    
        _clearDrawRect = CGRectMake(rect.size.width / 2 - TransparentArea([DDScanningView width], [DDScanningView height]).width / 2,
                                   rect.size.height / 2 - ATINT(TransparentArea([DDScanningView width], [DDScanningView height]).height+80)/2,
                                   TransparentArea([DDScanningView width], [DDScanningView height]).width, ATINT(TransparentArea([DDScanningView width], [DDScanningView height]).height+80));
        self.isStop=YES;
        codeBtn.hidden=YES;
        [topShowBtn setTitle:@"请将图书封面放入取景框拍照" forState:UIControlStateNormal];
    }
    
    topShowBtn.frame =CGRectMake(0,0, _clearDrawRect.size.width, 30);
    topShowBtn.center=CGPointMake(self.frame.size.width/2,_clearDrawRect.origin.y/2);
    
    //NSLog(@"======rect%f %f %f %f",_clearDrawRect.origin.x,_clearDrawRect.origin.y,_clearDrawRect.size.width,_clearDrawRect.size.height);
    //NSLog(@"%f%f===view",self.frame.size.width,self.frame.size.height);
    CGContextClearRect(context, _clearDrawRect);
    [self addWhiteRect:context rect:_clearDrawRect];
    [self addCornerLineWithContext:context rect:_clearDrawRect];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    
    if (self.scaningType==DDScaningPhotoType) {
        if (CGRectContainsPoint(_clearDrawRect, point)) {
            [self.cameraManger focusInPoint:point];
        }
    }
}


- (void)addWhiteRect:(CGContextRef)ctx rect:(CGRect)rect {
    CGContextStrokeRect(ctx, rect);
    CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 1);
    CGContextSetLineWidth(ctx, 0.8);
    CGContextAddRect(ctx, rect);
    CGContextStrokePath(ctx);
}

- (void)addCornerLineWithContext:(CGContextRef)ctx rect:(CGRect)rect{
   
    //画四个边角
    CGContextSetLineWidth(ctx, 2);
    CGContextSetRGBStrokeColor(ctx, 225 /255.0, 79/255.0, 40/255.0, 1);//黄色
    
    //左上角
    CGPoint poinsTopLeftA[] = {
        CGPointMake(rect.origin.x, rect.origin.y-1),
        CGPointMake(rect.origin.x , rect.origin.y + 15)
    };
    CGPoint poinsTopLeftB[] = {CGPointMake(rect.origin.x, rect.origin.y),CGPointMake(rect.origin.x + 15, rect.origin.y)};
    [self addLine:poinsTopLeftA pointB:poinsTopLeftB ctx:ctx];
    //左下角
    CGPoint poinsBottomLeftA[] = {CGPointMake(rect.origin.x, rect.origin.y + rect.size.height - 15),CGPointMake(rect.origin.x ,rect.origin.y + rect.size.height+1)};
    CGPoint poinsBottomLeftB[] = {CGPointMake(rect.origin.x , rect.origin.y + rect.size.height) ,CGPointMake(rect.origin.x +15, rect.origin.y + rect.size.height)};
    [self addLine:poinsBottomLeftA pointB:poinsBottomLeftB ctx:ctx];
    //右上角
    CGPoint poinsTopRightA[] = {CGPointMake(rect.origin.x+ rect.size.width - 15, rect.origin.y),CGPointMake(rect.origin.x + rect.size.width+1,rect.origin.y )};
    CGPoint poinsTopRightB[] = {CGPointMake(rect.origin.x+ rect.size.width, rect.origin.y),CGPointMake(rect.origin.x + rect.size.width,rect.origin.y + 15  )};
    [self addLine:poinsTopRightA pointB:poinsTopRightB ctx:ctx];
    
    CGPoint poinsBottomRightA[] = {CGPointMake(rect.origin.x+ rect.size.width, rect.origin.y+rect.size.height+ -15),CGPointMake(rect.origin.x + rect.size.width,rect.origin.y +rect.size.height+1)};
    CGPoint poinsBottomRightB[] = {CGPointMake(rect.origin.x+ rect.size.width - 15 , rect.origin.y + rect.size.height),CGPointMake(rect.origin.x + rect.size.width,rect.origin.y + rect.size.height )};
    [self addLine:poinsBottomRightA pointB:poinsBottomRightB ctx:ctx];
    CGContextStrokePath(ctx);
}

- (void)addLine:(CGPoint[])pointA pointB:(CGPoint[])pointB ctx:(CGContextRef)ctx {
    CGContextAddLines(ctx, pointA, 2);
    CGContextAddLines(ctx, pointB, 2);
}

+ (NSInteger)width{
    if (Iphone4||Iphone5) {
        return Iphone45ScanningSize_width;
    }else if(Iphone6){
        return Iphone6ScanningSize_width;
    }else if(Iphone6Plus){
        return Iphone6PlusScanningSize_width;
    }else{
        return Iphone45ScanningSize_width;
    }
}

+ (NSInteger)height{
    if (Iphone4||Iphone5) {
        return Iphone45ScanningSize_height;
    }else if(Iphone6){
        return Iphone6ScanningSize_height;
    }else if(Iphone6Plus){
        return Iphone6PlusScanningSize_height;
    }else{
        return Iphone45ScanningSize_height;
    }
}

-(void)stopAnimation{
    
    self.isStop=YES;
}

-(void)startAnimation
{
    self.isStop=NO;
    [self starMove];
}

- (void)viewWillDisappear:(NSNotification *)noti{
    [self.timer invalidate];
    self.timer = nil;
     //NSLog(@"%@dealloc====", self.description);
}
- (void)dealloc{
    //NSLog(@"%@dealloc", self.description);
}
@end
