//
//  RDQRCodeCreator.h
//
//  Created by radar on 2018/3/26.
//  Copyright © 2018年 Radar. All rights reserved.
//

//本类使用前，请在info.plist里边添加如下两个属性
/*
 Privacy - Photo Library Usage Description
 Privacy - Camera Usage Description
*/

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface RDQRCodeCreator : NSObject

+ (UIImage*)createQRCode:(NSString*)codeString withFace:(UIImage*)faceImage; //创建二维码 如faceImage=nil则无头像

@end
