//
//  Mandelbrot.h
//  ComputeMetal
//
//  Created by Michael Davidson on 1/29/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "Common.h"

@interface Mandelbrot : NSObject

@property(nonatomic) MandelData data;


- (instancetype)initWithDevice:(id<MTLDevice>)device Library:(id<MTLLibrary>)library;

@end
