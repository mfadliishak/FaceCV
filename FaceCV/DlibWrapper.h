//
//  DlibWrapper.h
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 16.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

extern const int kGAZE_INDEX_RIGHT;
extern const int kGAZE_INDEX_CENTER;
extern const int kGAZE_INDEX_LEFT;
extern const int kGAZE_INDEX_NONE;

@interface DlibWrapper : NSObject

- (instancetype)init;
- (void)doWorkOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects;
- (void)prepare;

@property (assign) BOOL isBlink;
@property (assign) int faceIndex;
@property (assign) int gazeIndex;

@end
