//
//  RDQRCodeScaner.h
//
//  Created by radar on 2018/3/27.
//  Copyright © 2018年 radar. All rights reserved.
//
//注: 本类只能用PUSH方式唤起

//本类使用前，请在info.plist里边添加如下两个属性
/*
 Privacy - Photo Library Usage Description
 Privacy - Camera Usage Description
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FitCamera.h"

@interface RDQRCodeScaner : UIViewController <FitCameraDelegate, DDScanningViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

+ (void)pushToOpenScanner:(UINavigationController *)fromNav completion:(void(^)(NSString *qrcode))completion;

@end
