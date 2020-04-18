//
//  ProcessImage.h
//  FaceCV
//
//  Created by Fadli Ishak on 2020/04/18.
//  Copyright © 2020 Fadli Ishak. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProcessImage : NSObject
//+ or - (返り値 *)関数名:(引数の型 *)引数名;
//+ : クラスメソッド
//- : インスタンスメソッド

- (UIImage *)toGrayImg:(UIImage *)img;

@end

NS_ASSUME_NONNULL_END
