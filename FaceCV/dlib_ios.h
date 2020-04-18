//
//  dlib_ios.h
//  TryDlibVideoStream
//
//  Created by DboyLiao on 13/03/2017.
//

#ifndef dlib_ios_h
#define dlib_ios_h

#include "dlib/pixel.h"
#include "dlib/array2d/array2d_kernel.h"

void UIImageToDlibImage(const UIImage* uiImage, dlib::array2d<dlib::bgr_pixel>& dlibImage, bool alphaExists = false);
UIImage* DlibImageToUIImage(dlib::array2d<dlib::bgr_pixel>& dlibImage);

#endif /* dlib_ios_h */
