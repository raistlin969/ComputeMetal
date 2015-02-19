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
#import "MetalView.h"

@interface Mandelbrot : NSObject

- (instancetype)initWithDevice:(id<MTLDevice>)device Library:(id<MTLLibrary>)library;
- (BOOL)configure:(MetalView *)view;
- (void)encode;
- (void)encodeFinal:(id<MTLRenderCommandEncoder>)finalEncoder;
- (void)reshape:(MetalView *)view;

- (void)changeColors;
- (void)panX:(float)x Y:(float)y;
- (void)zoom:(float)zoom;

@end
