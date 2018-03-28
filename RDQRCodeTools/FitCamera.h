//
//  FitCamera.h
//
//  Created by Radar on 16/4/13.
//  Copyright © 2016年 Radar. All rights reserved.
//
//注：本类没有适配iPhoneX，这是一个比较老的类了，后续再继续优化

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#define SHOWALERT(title, msg) [[[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show]


#define Iphone4 CGSizeEqualToSize([UIScreen mainScreen].bounds.size, CGSizeMake(320, 480))?YES:NO
#define Iphone5 CGSizeEqualToSize([UIScreen mainScreen].bounds.size, CGSizeMake(320, 568))?YES:NO
#define Iphone6 CGSizeEqualToSize([UIScreen mainScreen].bounds.size, CGSizeMake(375, 667))?YES:NO
#define Iphone6Plus CGSizeEqualToSize([UIScreen mainScreen].bounds.size, CGSizeMake(414, 736))?YES:NO
#define ScreenSize [UIScreen mainScreen].bounds.size
#define Color(r,g,b,a)  [UIColor colorWithRed:r/225.0 green:g/225.0 blue:b/225.9 alpha:a]

/***********************   配置区   ***************************/


/*
 此处是配置扫描秒区域适配各种屏幕的大小
 介于iPhone4和iPhone5的屏幕宽度一样，所以就归为一类
 猿类们可以根据自己项目的要求设置在不同屏幕中显示的大小
 不管怎么调整扫描区域在屏幕的位置始终是居中， 如果不想剧中则自行改代码去吧
 */
#define Iphone45ScanningSize_width 230
#define Iphone45ScanningSize_height 230
#define Iphone6ScanningSize_width 260
#define Iphone6ScanningSize_height 260
#define Iphone6PlusScanningSize_width 290
#define Iphone6PlusScanningSize_height 290
#define TransparentArea(a,b)  CGSizeMake(a, b)



#define LineColor Color(225,0,225,.2) //扫描线的颜色，RGBA,用户可以定义任何颜色
#define LineShadowLastInterval .4 //此属性决定扫描线后面的尾巴的长短，值越大越长，当然XDScaningLineMode必须为XDScaningLineDeafult，其他无效
#define LineMoveSpeed 1 //扫描线移动的速度，值为每1/60秒移动的点数，数值越大移动速度越快
#define NavigationBarHidden YES //是否隐藏导航栏（前提是有导航栏，没有导航栏此设置无效）

#define ButtonSize CGSizeMake(40,40) //扫描界面所有触发事件的按钮的大小
#define ButtonFromBottom 80 // 屏幕下面的按钮到屏幕底部的距离


typedef NS_ENUM(NSInteger, DDScaningViewCoverMode) {
    DDScaningViewCoverModeClear,
    DDScaningViewCoverModeNormal, //默认
    DDScaningViewCoverModeBlur,
};

typedef NS_ENUM(NSInteger, DDScaningViewShapeMode) {
    DDScaningViewShapeModeSquare, //默认
    DDScaningViewShapeModeRound,
    
};

typedef NS_ENUM(NSInteger, DDScaningLineMoveMode) {
    DDScaningLineMoveModeDown, //默认
    DDScaningLineMoveModeUpAndDown,
    DDScaningLineMoveModeNone,
    
};

typedef NS_ENUM(NSInteger, DDScaningLineMode) {
    DDScaningLineModeNone, //什么都没有
    DDScaningLineModeDeafult, //默认
    DDScaningLineModeImge,  //以一个图为扫描线，微信，百度
    DDScaningLineModeGrid, //类似京东
};

typedef NS_ENUM(NSInteger, DDScaningWarningTone) {
    DDScaningWarningToneSound, //声音
    DDScaningWarningToneVibrate, //震动
    DDScaningWarningToneSoundAndVibrate, //声音和振动
};


typedef NS_ENUM(NSInteger, DDScaningType) {
    DDScaningPhotoType, //拍封面识别
    DDScaningCode,     //扫描二维码识别
   
};



@protocol FitCameraDelegate <NSObject>
@optional
- (void)cameraDidFinishFocus;
- (void)cameraDidStareFocus;

- (void)getCameraLight:(float)lightValue;

-(void)getScanCode:(NSString*)scanCode;

-(void)alertViewFinished;

@end

@interface FitCamera : NSObject <AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, CAAnimationDelegate> 

@property (nonatomic,assign) id<FitCameraDelegate>delegate;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic,assign) DDScaningType scanType;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) AVCaptureMetadataOutput *stillDataOutput;
@property (nonatomic, assign) BOOL isManualFocus;//判断是否手动对焦
@property (nonatomic, assign)float brightnessValue;
@property (nonatomic, strong) UIImageView *focusImageView;

/**
 *  添加摄像范围到View
 *
 *  @param parent 传进来的parent的大小，就是摄像范围的大小
 */
- (void)configureWithParentLayer:(UIView *)parent;

/**
 *  切换前后镜
 */
- (void)switchCamera:(BOOL)isFrontCamera didFinishChanceBlock:(void(^)(void))completion;


/**
 *  切换闪光灯模式
 */
- (void)switchFlashMode:(UIButton*)sender;

/**
 *  点击对焦
 */
- (void)focusInPoint:(CGPoint)devicePoint;


/**
 *  开启对焦监听 默认YES
 */
- (void)setFocusObserver:(BOOL)yes;


-(void)addDataOutput;

- (void)addStillImageOutput;

@end


@class DDScanningView;
@protocol DDScanningViewDelegate <NSObject>
@optional
-(void)codeBtn;
@end

@interface DDScanningView : UIView
{
    UIButton *topShowBtn;
    UIButton *codeBtn;
}
@property (weak, nonatomic) id<DDScanningViewDelegate> delegate;
@property (assign,nonatomic) DDScaningType scaningType;
@property (assign,nonatomic) CGRect clearDrawRect;
@property (assign,nonatomic) BOOL isStop;
+ (NSInteger)width;
+ (NSInteger)height;
- (instancetype)initWithFrame:(CGRect)frame withScanType:(DDScaningType)scanType withManger:(FitCamera*)cManager;

-(void)refreshTopLabelText:(float)brightNessV;

-(void)stopAnimation;
-(void)startAnimation;

@end

