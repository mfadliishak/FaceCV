//
//  DlibWrapper.m
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 16.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

#import "DlibWrapper.h"
#import <UIKit/UIKit.h>

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
+ (void)drawCrossLinesWithShape:(dlib::full_object_detection)shape withImg:(dlib::array2d<dlib::bgr_pixel>&)img
                 withLeft:(unsigned long)leftPointIndex
                withRight: (unsigned long)RightPointIndex
             withTopLeft:(unsigned long)topLeftPointIndex
            withTopRight:(unsigned long)topRightPointIndex
          withBottomLeft:(unsigned long)bottomLeftPointIndex
         withBottomRight:(unsigned long)bottomRightPointIndex;

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
        _isBlink = NO;
        _faceIndex = -1;
        dlib::rectangle oneFaceRect = convertedRectangles[j];
        
        // detect all landmarks
        dlib::full_object_detection shape = sp(img, oneFaceRect);
        //std::cout << shape.part(36) << std::endl;
        
        // and draw them into the image (samplebuffer)
        //for (unsigned long k = 0; k < shape.num_parts(); k++) {
        //    dlib::point p = shape.part(k);
        //    draw_solid_circle(img, p, 3, dlib::rgb_pixel(0, 255, 255));
        //}
        
        //draw at eye landmarks
        for (unsigned long k: self.eyeLandMarkPoints) {
            dlib::point p = shape.part(k);
            draw_solid_circle(img, p, 3, dlib::rgb_pixel(0, 255, 255));
        }
        
        // draw the horizontal and vertical lines
        dlib::point LE_leftPoint = shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_36]);
        dlib::point LE_rightPoint = shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_39]);
        dlib::point LE_centerTopPoint = [DlibWrapper lineMidPoint:shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_37]) withPoint2:shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_38])];
        dlib::point LE_centerBottomPoint = [DlibWrapper lineMidPoint:shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_41]) withPoint2:shape.part(self.eyeLandMarkPoints[EyeLandMarks::LEFT_40])];
        
        dlib::draw_line(img, LE_leftPoint, LE_rightPoint, dlib::rgb_pixel(0, 255, 0));
        dlib::draw_line(img, LE_centerTopPoint, LE_centerBottomPoint, dlib::rgb_pixel(0, 255, 0));
        
        double horLineLenght = std::hypot(LE_leftPoint.x() - LE_rightPoint.x(),
                                          LE_leftPoint.y() - LE_rightPoint.y());
        double verLineLength = std::hypot(LE_centerTopPoint.x() - LE_centerBottomPoint.x(),
                                        LE_centerTopPoint.y() - LE_centerBottomPoint.y());
        
        double ratio = horLineLenght / verLineLength;
        
        //std::cout << "ratio: " << ratio << std::endl;
        
        if(ratio < 3 ) {
            std::cout << "blink" << j << std::endl;
            _isBlink = YES;
            _faceIndex = (int)j;
        }
        
        
        
        /*
        // draw left eye lines
        [DlibWrapper drawCrossLinesWithShape:shape withImg:img
                                    withLeft:self.eyeLandMarkPoints[EyeLandMarks::LEFT_36]
                                  withRight:self.eyeLandMarkPoints[EyeLandMarks::LEFT_39]
                                withTopLeft:self.eyeLandMarkPoints[EyeLandMarks::LEFT_37]
                               withTopRight:self.eyeLandMarkPoints[EyeLandMarks::LEFT_38]
                             withBottomLeft:self.eyeLandMarkPoints[EyeLandMarks::LEFT_41]
                            withBottomRight:self.eyeLandMarkPoints[EyeLandMarks::LEFT_40]];
        // draw right eye lines
        [DlibWrapper drawCrossLinesWithShape:shape withImg:img
                withLeft:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_42]
              withRight:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_45]
            withTopLeft:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_43]
           withTopRight:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_44]
         withBottomLeft:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_47]
        withBottomRight:self.eyeLandMarkPoints[EyeLandMarks::RIGHT_46]];
         */
        
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

+ (void)drawCrossLinesWithShape:(dlib::full_object_detection)shape
                  withImg:(dlib::array2d<dlib::bgr_pixel>&)img
                 withLeft:(unsigned long)leftPointIndex
                withRight: (unsigned long)RightPointIndex
             withTopLeft:(unsigned long)topLeftPointIndex
            withTopRight:(unsigned long)topRightPointIndex
          withBottomLeft:(unsigned long)bottomLeftPointIndex
         withBottomRight:(unsigned long)bottomRightPointIndex {
    
    dlib::point LE_leftPoint = shape.part(leftPointIndex);
    dlib::point LE_rightPoint = shape.part(RightPointIndex);
    dlib::point LE_centerTopPoint = [DlibWrapper lineMidPoint:shape.part(topLeftPointIndex) withPoint2:shape.part(topRightPointIndex)];
    dlib::point LE_centerBottomPoint = [DlibWrapper lineMidPoint:shape.part(bottomLeftPointIndex) withPoint2:shape.part(bottomRightPointIndex)];
    
    dlib::draw_line(img, LE_leftPoint, LE_rightPoint, dlib::rgb_pixel(0, 255, 0));
    dlib::draw_line(img, LE_centerTopPoint, LE_centerBottomPoint, dlib::rgb_pixel(0, 255, 0));
    
}

@end
