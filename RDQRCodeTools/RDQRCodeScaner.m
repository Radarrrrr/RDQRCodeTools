//
//  RDQRCodeScaner.m
//
//  Created by radar on 2018/3/27.
//  Copyright © 2018年 radar. All rights reserved.
//



#import "RDQRCodeScaner.h"

#define AppWidth [[UIScreen mainScreen] bounds].size.width
#define AppHeigt [[UIScreen mainScreen] bounds].size.height


@interface RDQRCodeScaner ()  

@property (nonatomic, strong) FitCamera *manager;
@property (nonatomic, strong) DDScanningView  *overView;

@property (nonatomic, assign) BOOL isHasResult;
@property (nonatomic, copy)   void(^scanHandler)(NSString *qrcode);

@end


@implementation RDQRCodeScaner

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    //扫码器承载层
    UIView *pickView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, AppWidth, AppHeigt-64)];
    [self.view addSubview:pickView];
    
    //扫描控制器
    self.manager = [[FitCamera alloc] init];
    [_manager configureWithParentLayer:pickView]; // 传入View的frame 就是摄像的范围
    _manager.delegate = self;
    
    //覆盖层效果
    self.overView = [[DDScanningView alloc]initWithFrame:CGRectMake(0, 0,  AppWidth, AppHeigt-64) withScanType:1 withManger:_manager];
    _overView.delegate = self;
    [self.view addSubview:_overView];
    
    //相册选择二维码
    UIBarButtonItem *albumItem = [[UIBarButtonItem alloc] initWithTitle:@"相册" style:UIBarButtonItemStylePlain target:self action:@selector(albumAction)];
    self.navigationItem.rightBarButtonItem = albumItem;
    
}

- (void)viewWillAppear:(BOOL)animated
{
    self.isHasResult = NO;
}

- (void)dealloc
{
    //记得停止动画
    if (_overView && !_overView.isStop) 
    {
        [_overView stopAnimation];
    }
    
    //NSLog(@"照相机释放了");
    if (_manager) {
        self.manager.delegate = nil;
        self.manager = nil;
    }
}


- (UIImage *)imageSizeWithScreenImage:(UIImage *)image
{
    CGFloat imageWidth = image.size.width;
    CGFloat imageHeight = image.size.height;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    if (imageWidth <= screenWidth && imageHeight <= screenHeight) {
        return image;
    }
    
    CGFloat max = MAX(imageWidth, imageHeight);
    CGFloat scale = max / (screenHeight * 2.0);
    
    CGSize size = CGSizeMake(imageWidth / scale, imageHeight / scale);
    UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}



#pragma mark - 通过相册选择二维码识别
- (void)albumAction
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.delegate = self;
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) 
    {
        UIImagePickerController* pickController = [[UIImagePickerController alloc] init];
        pickController.delegate = self;
        pickController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        
        [self  presentViewController:imagePicker animated:YES completion:^{
            [_overView stopAnimation];
        }];
    }
    else 
    {
        SHOWALERT(@"提示", @"您的设备无法读取相册");
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    // 对选取照片的处理，如果选取的图片尺寸过大，则压缩选取图片，否则不作处理
    
    [picker dismissViewControllerAnimated:YES completion:^{
        [_overView startAnimation];
        
        //处理图片
        UIImage *image = [self imageSizeWithScreenImage:info[UIImagePickerControllerOriginalImage]];
        
        // CIDetector(CIDetector可用于人脸识别)进行图片解析，从而使我们可以便捷的从相册中获取到二维码
        // 声明一个 CIDetector，并设定识别类型 CIDetectorTypeQRCode
        CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
        
        // 取得识别结果
        NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
        
        if (features.count == 0)
        {
            NSLog(@"暂未识别出图片中的二维码 - - %@", features);
            
            SHOWALERT(nil, @"暂未识别出图片中的二维码");
            return;
        } 
        else
        {        
            //只识别第一个二维码，多个的暂时不考虑
            CIQRCodeFeature *feature = [features objectAtIndex:0];
            NSString *resultStr = feature.messageString;
            
            NSLog(@"相册图片识别到二维码：%@", resultStr);
            
            [self handleCodeString:resultStr];
        }
        
    }];
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:^{
        [_overView startAnimation];
    }];
    
}



#pragma mark - 扫描二维码识别
//FitCameraDelegate
-(void)getScanCode:(NSString*)scanCode
{
    if(!scanCode || [scanCode isEqualToString:@""]) return;
    if(_isHasResult) return;
    
    self.isHasResult = YES;
    
    NSLog(@"扫码识别到二维码：%@", scanCode);
    
    [self handleCodeString:scanCode];
}


#pragma mark - 处理二维码识别结果
- (void)handleCodeString:(NSString*)codeString
{
    if(!codeString || [codeString isEqualToString:@""]) return;
    
    //做扫码成功以后的事情
    //先把自己倒回去释放掉
    [self.navigationController popViewControllerAnimated:NO];
    
    //通过block返回调用方
    if(_scanHandler)
    {
        _scanHandler(codeString);
    }
}


#pragma mark - 外部方法
+ (void)pushToOpenScanner:(UINavigationController *)fromNav completion:(void(^)(NSString *qrcode))completion
{
    if(!fromNav || ![fromNav isKindOfClass:[UINavigationController class]]) return;
    
    RDQRCodeScaner *scanerVC = [[RDQRCodeScaner alloc] init];
    scanerVC.scanHandler = completion;
    
    [fromNav pushViewController:scanerVC animated:YES];
}



@end
