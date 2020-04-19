//
//  DlibWrapper.m
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 16.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

#import "DlibWrapper.h"
#import <UIKit/UIKit.h>

#include <dlib/opencv.h>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/core/core.hpp>
#include <dlib/image_processing/frontal_face_detector.h>
#include <dlib/image_processing.h>
#include <dlib/image_io.h>

enum EyeLandMarks {
    LEFT_36 = 0, LEFT_37, LEFT_38, LEFT_39, LEFT_40, LEFT_41,
    RIGHT_42, RIGHT_43, RIGHT_44, RIGHT_45, RIGHT_46, RIGHT_47
};

@interface DlibWrapper ()

@property (assign) BOOL prepared;
@property (assign) std::vector<unsigned long> eyeLandMarkPoints;

+ (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects;
+ (dlib::point)lineMidPoint:(dlib::point)point1 withPoint2:(dlib::point) point2;
+ (double)getBlinkingRatio:(dlib::full_object_detection)shape withImg:(dlib::array2d<dlib::bgr_pixel>&)img
                 withLeft:(unsigned long)leftPointIndex
                withRight: (unsigned long)RightPointIndex
             withTopLeft:(unsigned long)topLeftPointIndex
            withTopRight:(unsigned long)topRightPointIndex
          withBottomLeft:(unsigned long)bottomLeftPointIndex
         withBottomRight:(unsigned long)bottomRightPointIndex;

+ (double) getGazeRatio:(std::vector<dlib::point>) dlibPoints withMat:(cv::Mat&) matImg
            withMatGray:(cv::Mat&) matGray withImg:(dlib::array2d<dlib::bgr_pixel>&)img
           withImgWidth:(int)width withImgHeight:(int)height;

@end
@implementation DlibWrapper {
    dlib::shape_predictor sp;
}


- (instancetype)init {
    self = [super init];
    if (self) {
        _prepared = NO;
        _isBlink = NO;
        _faceIndex = -1;
    }
    return self;
}

- (void)prepare {
    NSString *modelFileName = [[NSBundle mainBundle] pathForResource:@"shape_predictor_68_face_landmarks" ofType:@"dat"];
    std::string modelFileNameCString = [modelFileName UTF8String];
    
    dlib::deserialize(modelFileNameCString) >> sp;
    
    dlib::frontal_face_detector faceDetector = dlib::get_frontal_face_detector();
    
    // FIXME: test this stuff for memory leaks (cpp object destruction)
    self.prepared = YES;
    
    self.eyeLandMarkPoints = {
        36, 37, 38, 39, 40, 41, //left
        42, 43, 44, 45, 46, 47
    };
}

- (void)doWorkOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects {
    
    if (!self.prepared) {
        [self prepare];
    }
    
    dlib::array2d<dlib::bgr_pixel> img;
    
    // MARK: magic
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    char *baseBuffer = (char *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    // set_size expects rows, cols format
    img.set_size(height, width);
    
    // copy samplebuffer image data into dlib image format
    img.reset();
    long position = 0;
    while (img.move_next()) {
        dlib::bgr_pixel& pixel = img.element();

        // assuming bgra format here
        long bufferLocation = position * 4; //(row * width + column) * 4;
        char b = baseBuffer[bufferLocation];
        char g = baseBuffer[bufferLocation + 1];
        char r = baseBuffer[bufferLocation + 2];
        //        we do not need this
        //        char a = baseBuffer[bufferLocation + 3];
        
        dlib::bgr_pixel newpixel(b, g, r);
        pixel = newpixel;
        
        position++;
    }
    
    // unlock buffer again until we need it again
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    // convert the face bounds list to dlib format
    std::vector<dlib::rectangle> convertedRectangles = [DlibWrapper convertCGRectValueArray:rects];
    
    // for every detected face
    for (unsigned long j = 0; j < convertedRectangles.size(); ++j)
    {
        cv::Mat matImg = dlib::toMat(img);
        cv::Mat matGray = cv::Mat();
        cv::cvtColor(matImg, matGray, cv::COLOR_BGR2GRAY);
        
        _isBlink = NO;
        _faceIndex = -1;
        dlib::rectangle oneFaceRect = convertedRectangles[j];
        
        // detect all landmarks
        dlib::full_object_detection shape = sp(img, oneFaceRect);
        //std::cout << shape.part(36) << std::endl;
        
        //draw at eye landmarks
        /*for (unsigned long k: self.eyeLandMarkPoints) {
            dlib::point p = shape.part(k);
            draw_solid_circle(img, p, 3, dlib::rgb_pixel(0, 255, 255));
        }*/
        
        // draw left eye lines, get blinking ratio
        double blinkingRatioLeft = [DlibWrapper getBlinkingRatio:shape withImg:img
                withLeft:self.eyeLandMarkPoints[EyeLandMarks::LEFT_36]
              withRight:self.eyeLandMarkPoints[EyeLandMarks::LEFT_39]
            withTopLeft:self.eyeLandMarkPoints[EyeLandMarks::LEFT_37]
           withTopRight:self.eyeLandMarkPoints[EyeLandMarks::LEFT_38]
         withBottomLeft:self.eyeLandMarkPoints[EyeLandMarks::LEFT_41]
        withBottomRight:self.eyeLandMarkPoints[EyeLandMarks::LEFT_40]];
        
        // draw right eye lines
        double blinkingRatioRight = [DlibWrapper getBlinkingRatio:shape withImg:img
                withLeft:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_42]
              withRight:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_45]
            withTopLeft:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_43]
           withTopRight:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_44]
         withBottomLeft:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_47]
        withBottomRight:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_46]];
        
        double blinkingRatio = (blinkingRatioLeft + blinkingRatioRight) / 2;
        
        //std::cout << "ratio: " << blinkingRatio << std::endl;
        
        if(blinkingRatio > 5.7 ) {
            //std::cout << "blink" << j << std::endl;
            _isBlink = YES;
            _faceIndex = (int)j;
        }
        
        // gaze detection
        //=================
        std::vector<dlib::point> leftEyeRegion = {
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_36]),
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_37]),
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_38]),
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_39]),
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_40]),
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_41]),
        };
        std::vector<dlib::point> rightEyeRegion = {
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::RIGHT_42]),
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::RIGHT_43]),
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::RIGHT_44]),
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::RIGHT_45]),
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::RIGHT_46]),
            shape.part(self.eyeLandMarkPoints[EyeLandMarks::RIGHT_47]),
        };
        
        double leftGazeRatio = [DlibWrapper getGazeRatio:leftEyeRegion withMat:matImg   withMatGray:matGray withImg:img withImgWidth:width withImgHeight:height];
        
        double rightGazeRatio = [DlibWrapper getGazeRatio:rightEyeRegion withMat:matImg   withMatGray:matGray withImg:img withImgWidth:width withImgHeight:height];
        
        double gazeRatio = (leftGazeRatio + rightGazeRatio) / 2;
        
        std::ostringstream gzRatioStr;
        gzRatioStr << gazeRatio << std::endl;
        
        if ( gazeRatio > 1.0) {
            cv::putText(matImg, "RIGHT", cv::Point(width / 2, height - 200), cv::FONT_HERSHEY_PLAIN, 5, cv::Scalar(0, 0, 255), 3);
            
            std::cout << "RIGHT" << std::endl;
        
        }
        else if (gazeRatio > 0.0) {
            cv::putText(matImg, "CENTER", cv::Point(width / 2, height - 200), cv::FONT_HERSHEY_PLAIN, 5, cv::Scalar(0, 0, 255), 3);
            
            std::cout << "CENTER" << std::endl;
        }
        else {
            cv::putText(matImg, "LEFT", cv::Point(width / 2, height - 200), cv::FONT_HERSHEY_PLAIN, 5, cv::Scalar(0, 0, 255), 3);
            
            std::cout << "LEFT" << std::endl;
        
        }
        
    }
    
    // lets put everything back where it belongs
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    // copy dlib image data back into samplebuffer
    img.reset();
    position = 0;
    while (img.move_next()) {
        dlib::bgr_pixel& pixel = img.element();
        
        // assuming bgra format here
        long bufferLocation = position * 4; //(row * width + column) * 4;
        baseBuffer[bufferLocation] = pixel.blue;
        baseBuffer[bufferLocation + 1] = pixel.green;
        baseBuffer[bufferLocation + 2] = pixel.red;
        //        we do not need this
        //        char a = baseBuffer[bufferLocation + 3];
        
        position++;
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

+ (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects {
    std::vector<dlib::rectangle> myConvertedRects;
    for (NSValue *rectValue in rects) {
        CGRect rect = [rectValue CGRectValue];
        long left = rect.origin.x;
        long top = rect.origin.y;
        long right = left + rect.size.width;
        long bottom = top + rect.size.height;
        dlib::rectangle dlibRect(left, top, right, bottom);

        myConvertedRects.push_back(dlibRect);
    }
    return myConvertedRects;
}

+ (dlib::point)lineMidPoint:(dlib::point)point1 withPoint2:(dlib::point)point2 {
    return dlib::point( (unsigned long)((point1.x() + point2.x()) / 2),
                        (unsigned long)((point1.y() + point2.y()) / 2));
}

+ (double)getBlinkingRatio:(dlib::full_object_detection)shape
                  withImg:(dlib::array2d<dlib::bgr_pixel>&)img
                 withLeft:(unsigned long)leftPointIndex
                withRight: (unsigned long)RightPointIndex
             withTopLeft:(unsigned long)topLeftPointIndex
            withTopRight:(unsigned long)topRightPointIndex
          withBottomLeft:(unsigned long)bottomLeftPointIndex
         withBottomRight:(unsigned long)bottomRightPointIndex {
    
    dlib::point leftPoint = shape.part(leftPointIndex);
    dlib::point rightPoint = shape.part(RightPointIndex);
    dlib::point centerTopPoint = [DlibWrapper lineMidPoint:shape.part(topLeftPointIndex) withPoint2:shape.part(topRightPointIndex)];
    dlib::point centerBottomPoint = [DlibWrapper lineMidPoint:shape.part(bottomLeftPointIndex) withPoint2:shape.part(bottomRightPointIndex)];
    
    //dlib::draw_line(img, leftPoint, rightPoint, dlib::rgb_pixel(0, 255, 0));
    //dlib::draw_line(img, centerTopPoint, centerBottomPoint, dlib::rgb_pixel(0, 255, 0));
    
    double horLineLenght = std::hypot(leftPoint.x() - rightPoint.x(),
                                      leftPoint.y() - rightPoint.y());
    double verLineLength = std::hypot(centerTopPoint.x() - centerBottomPoint.x(),
                                    centerTopPoint.y() - centerBottomPoint.y());
    
    double ratio = horLineLenght / verLineLength;
    
    return ratio;
}

+ (double) getGazeRatio:(std::vector<dlib::point>) dlibPoints  withMat:(cv::Mat&)matImg
            withMatGray:(cv::Mat&)matGray withImg:(dlib::array2d<dlib::bgr_pixel>&)img
           withImgWidth:(int)width withImgHeight:(int)height {

    int min_x = 999;
    int max_x = 0;
    int min_y = 999;
    int max_y = 0;
    
    double gazeRatio = 0;
    std::vector<cv::Point> points;
    
    for(int i=0; i < dlibPoints.size(); i++){
        points.push_back(cv::Point(dlibPoints[i].x(), dlibPoints[i].y()));
        
        if(min_x > dlibPoints[i].x()) {
            min_x = dlibPoints[i].x();
        }
        if(min_y > dlibPoints[i].y()) {
            min_y = dlibPoints[i].y();
        }
        if(max_x < dlibPoints[i].x()) {
            max_x = dlibPoints[i].x();
        }
        if(max_y < dlibPoints[i].y()) {
            max_y = dlibPoints[i].y();
        }
    }
    
    try {
        // draw eyeris
        //cv::polylines(matImg, points, true, cv::Scalar(0, 0, 255), 2);
        
        // crop grayscale image and get only the eye
        cv::Rect cropRect(min_x, min_y, max_x - min_x, max_y - min_y);
        cv::Mat matEyeImgGray = matGray(cropRect);
        cv::Mat matEyeImg = matImg(cropRect);

        // set the threshold value for the cropped eye image
        cv::Mat eyeImgGraytThres = cv::Mat();
        cv::threshold(matEyeImgGray, eyeImgGraytThres, 70, 250, cv::THRESH_BINARY);
        
        int widthThres = eyeImgGraytThres.cols;
        int heightThres = eyeImgGraytThres.rows;
        
        cv::Rect cropLeftSide(0, 0, (int)(widthThres / 2), heightThres);
        cv::Rect cropRightSide((int)(widthThres / 2), 0, (int)(widthThres / 2), heightThres);
        
        cv::Mat leftSideThres = eyeImgGraytThres(cropLeftSide);
        cv::Mat rightSideThres = eyeImgGraytThres(cropRightSide);

        int leftSideWhite = cv::countNonZero(leftSideThres);
        int rightSideWhite = cv::countNonZero(rightSideThres);
        
        if (leftSideWhite == 0) {
            gazeRatio = 1;
        }
        else if (rightSideWhite == 0) {
            gazeRatio = 5;
        }
        else {
            gazeRatio = leftSideWhite / rightSideWhite;
        }

        //Then define mask image
        cv::Mat mask = cv::Mat::zeros(matImg.size(), CV_8UC1);
        
        std::vector<std::vector<cv::Point> > fillContAll;
        fillContAll.push_back(points);
        
        // color the mask with white on the eye region
        cv::polylines(mask, points, true, cv::Scalar::all(255), 2);
        cv::fillPoly(mask, fillContAll, cv::Scalar::all(255));
        
        cv::Mat matEyeGray = cv::Mat();
        cv::bitwise_and(matGray, mask, matEyeGray);
        
        // threshold to detect pupil
        cv::Mat matPupilThres = cv::Mat();
        cv::threshold(eyeImgGraytThres, matPupilThres, 7, 255, cv::THRESH_BINARY_INV);
        
        // to reduce noice
        cv::GaussianBlur(matPupilThres, matPupilThres, cv::Size(7, 7), 0);
        
        // get the pupils points
        std::vector<std::vector<cv::Point>> contours;
        cv::findContours(matPupilThres, contours, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE);
        
        // sort contours area to find the biggest
        std::sort(contours.begin(), contours.end(),
                  [](const std::vector<cv::Point>& c1, const std::vector<cv::Point>& c2){
            return cv::contourArea(c1, false) < cv::contourArea(c2, false);
        });
        
        // draw the biggest contour
        if (contours.size() > 0) {
            cv::Rect pRect = cv::boundingRect(contours[contours.size()-1]);
            cv::rectangle(matEyeImg, pRect, cv::Scalar(255, 0, 255), 2);
            //cv::line(matEyeImg, cv::Point(pRect.x + (int)(pRect.width / 2), 0), cv::Point(pRect.x + (int)(pRect.width / 2), matEyeImg.rows), cv::Scalar(255, 0, 0), 2);
            //cv::line(matEyeImg, cv::Point(0, pRect.y + (int)(pRect.height / 2)), cv::Point(matEyeImg.cols, pRect.y + (int)(pRect.height / 2)), cv::Scalar(255, 0, 0), 2);
        }
        //cv::drawContours(matEyeImg, contours, contours.size()-1, cv::Scalar(0, 0, 255), 3);
        
        //matEyeImg.copyTo(matImg(cv::Rect(min_x, min_y, matEyeImg.cols, matEyeImg.rows)));
        
    }
    catch(cv::Exception & e) {
        std::cerr << "getGazeRatio err: " << e.msg << std::endl;
    }
    
    return gazeRatio;
}

@end
