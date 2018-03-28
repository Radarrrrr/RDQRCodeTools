//
//  RDQRCodeCreator.m
//
//  Created by radar on 2018/3/26.
//  Copyright © 2018年 Radar. All rights reserved.
//

#import "RDQRCodeCreator.h"
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

@implementation RDQRCodeCreator

+ (UIImage*)createQRCode:(NSString*)codeString withFace:(UIImage*)faceImage
{
    if(!codeString || [codeString isEqualToString:@""]) return nil;
    
    //生成二维码
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setDefaults];
    
    NSData *data = [codeString dataUsingEncoding:NSUTF8StringEncoding];
    [filter setValue:data forKeyPath:@"inputMessage"];
    
    CIImage *outputImage = [filter outputImage];
    
    UIImage *qrCode = [self createNonInterpolatedUIImageFormCIImage:outputImage withSize:200];
  
    //添加头像图片
    if(faceImage)
    {
        UIImage *faceImg = [self createRoundedRectImage:faceImage size:CGSizeMake(40, 40)];

        //组合头像和二维码
        qrCode = [self imageMergedForImage:qrCode maskImage:faceImg];
    }
    
    return qrCode;
}


/**
 * 根据CIImage生成指定大小的UIImage
 *
 * @param image CIImage
 * @param size 图片宽度
 */
+ (UIImage *)createNonInterpolatedUIImageFormCIImage:(CIImage *)image withSize:(CGFloat) size
{
    CGRect extent = CGRectIntegral(image.extent);
    CGFloat scale = MIN(size/CGRectGetWidth(extent), size/CGRectGetHeight(extent));
    
    // 1.创建bitmap;
    size_t width = CGRectGetWidth(extent) * scale;
    size_t height = CGRectGetHeight(extent) * scale;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:image fromRect:extent];
    
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    
    // 2.保存bitmap到图片
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    UIImage *qrImage = [UIImage imageWithCGImage:scaledImage];
    
    return qrImage;
}

+ (UIImage*)imageWithImage:(UIImage*)image scaledToSize:(CGSize)newSize
{
    // Create a graphics image context
    UIGraphicsBeginImageContext(newSize);
    
    // Tell the old image to draw in this new context, with the desired
    // new size
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    
    // Get the new image from the context
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    // End the context
    UIGraphicsEndImageContext();
    
    // Return the new image.
    return newImage;
}

+ (UIImage*)imageMergedForImage:(UIImage*)originImage maskImage:(UIImage*)maskImage
{
    if(originImage == nil) return nil;
    if(maskImage == nil) return originImage;
    
    CGSize imageSize = originImage.size;
    CGSize maskSize = maskImage.size;
    
    UIGraphicsBeginImageContext(imageSize);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // full the color in the context
    CGContextSetFillColorWithColor(ctx, [UIColor clearColor].CGColor);
    CGContextFillRect(ctx, CGRectMake(0.0, 0.0, imageSize.width, imageSize.height));
    
    // draw source image on the context
    [originImage drawInRect:CGRectMake(0.0, 0.0, imageSize.width, imageSize.height)];
    [maskImage   drawInRect:CGRectMake((imageSize.width-maskSize.width)/2, (imageSize.height-maskSize.height)/2, maskSize.width, maskSize.height)];
    
    UIImage* mergePhoto = UIGraphicsGetImageFromCurrentImageContext();    
    UIGraphicsEndImageContext();
    return mergePhoto;
}

//给图片做圆角
+ (UIImage *)createRoundedRectImage:(UIImage*)image size:(CGSize)size
{
    // the size of CGContextRef
    if(!image) return nil;
    
    int w = size.width;
    int h = size.height;
    
    UIImage *img = image;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedFirst);
    CGRect rect = CGRectMake(0, 0, w, h);
    
    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, w, h));
    
    // Draw a rounded rectangle
    CGContextBeginPath(context);
    [self addRoundedRectToPath:context rect:rect ovalWidth:6 ovalHeight:6];//30&30
    CGContextClosePath(context);
    CGContextClip(context);
    
    // Draw image into the rounded rect
    CGContextDrawImage(context, CGRectMake(0, 0, w, h), img.CGImage);
    
    CGImageRef imageMasked = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    UIImage *resultImage = [UIImage imageWithCGImage:imageMasked];
    CGImageRelease(imageMasked);
    
    return resultImage;
}
+ (void) addRoundedRectToPath:(CGContextRef)context rect:(CGRect)rect ovalWidth:(float) ovalWidth ovalHeight:(float) ovalHeight
{
    
    if (ovalWidth == 0 || ovalHeight == 0) {
        CGContextAddRect(context, rect);
        return;
    }
    
    float fw, fh;
    
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM(context, ovalWidth, ovalHeight);
    fw = CGRectGetWidth(rect) / ovalWidth;
    fh = CGRectGetHeight(rect) / ovalHeight;
    
    
    CGContextMoveToPoint(context, fw, fh/2);  // Start at lower right corner
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);  // Top right corner
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1); // Top left corner
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1); // Lower left corner
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1); // Back to lower right
    
    CGContextClosePath(context);
    CGContextRestoreGState(context);
    
}


@end
