//
//  ProcessImage.m
//  FaceCV
//
//  Created by Fadli Ishak on 2020/04/18.
//  Copyright © 2020 Fadli Ishak. All rights reserved.
//


#include <opencv2/opencv.hpp>
#include <opencv2/core/core.hpp>
#include <opencv2/core/types_c.h>
#include <opencv2/imgproc.hpp>
#include <dlib/image_processing/frontal_face_detector.h>
#include <dlib/image_processing.h>
#include <dlib/image_io.h>
#include <dlib/opencv/cv_image.h>
#import "ProcessImage.h"
#import "dlib_ios.h"

@implementation ProcessImage

dlib::shape_predictor sp;

- (UIImage *) toGrayImg:(UIImage *)img{
    
    NSString *modelFileName = [[NSBundle mainBundle] pathForResource:@"shape_predictor_68_face_landmarks" ofType:@"dat"];
    std::string modelFileNameCString = [modelFileName UTF8String];
    
    dlib::deserialize(modelFileNameCString) >> sp;
    
    dlib::frontal_face_detector faceDetector = dlib::get_frontal_face_detector();
    
    //dlib::array2d<dlib::bgr_pixel> dlibImage;
    //dlib::array2d<dlib::bgr_pixel> dimg;
    //dimg.set_size(img.size.height, img.size.width);
    
    // *************** UIImage -> cv::Mat変換 ***************
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(img.CGImage);
    CGFloat cols = img.size.width;
    CGFloat rows = img.size.height;
    
    cv::Mat mat(rows,cols, CV_8UC4);

    CGContextRef contextRef = CGBitmapContextCreate(mat.data,
                                                    cols,
                                                    rows,
                                                    8,
                                                    mat.step[0],
                                                    colorSpace,
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault);

    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), img.CGImage);
    CGContextRelease(contextRef);

    // *************** 処理 ***************
    cv::Mat grayImg;
    cv::cvtColor(mat, grayImg, cv::COLOR_BGR2GRAY); //グレースケール変換
    
    
    // Convert OpenCV image format to Dlib's image format
    //dlib::cv_image<dlib::bgr_pixel> dlibIm(mat);
    //dlib::cv_image<unsigned char> dlibIm(grayImg);
    
    //dlib::array2d<unsigned char> dlib_img;
    //dlib::assign_image(dlib_img, dlib::cv_image<unsigned char>(mat));
    
    dlib::array2d<dlib::bgr_pixel> dlibImage;
    UIImageToDlibImage(img, dlibImage);
    
    // Detect faces in the image
    std::vector<dlib::rectangle> faceRects = faceDetector(dlibImage);
    
    for ( size_t i = 0; i < faceRects.size(); i++ )
    {
        int x1 = (int)faceRects[i].left();
        int y1 = (int)faceRects[i].top();
        int x2 = (int)faceRects[i].right();
        int y2 = (int)faceRects[i].bottom();
        
        cv::rectangle(mat, cv::Point(x1, y1), cv::Point(x2, y2), cv::Scalar(0, 255, 0));
    }
    
    dlib::array2d<dlib::bgr_pixel> dlibImage2;
    dlib::assign_image(dlibImage2, dlib::cv_image<dlib::bgr_pixel>(mat));
    
    UIImage* resImg = DlibImageToUIImage(dlibImage2);
    return resImg;
}
@end
