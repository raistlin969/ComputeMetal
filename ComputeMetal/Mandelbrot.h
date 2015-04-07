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
#include <vector>

@interface Mandelbrot : NSObject

- (instancetype)initWithDevice:(id<MTLDevice>)device Library:(id<MTLLibrary>)library;
- (BOOL)configure:(MetalView *)view;
- (void)encode;
- (void)encodeFinal:(id<MTLRenderCommandEncoder>)finalEncoder;
- (void)reshape:(MetalView *)view;

- (void)changeColors;
- (void)panX:(float)x Y:(float)y;
- (void)zoom:(float)zoom;
-(void)performIterationsOnArea:(float4*)area describedByRegion:(MTLRegion)region;
-(void)performIterationsOnArea:(std::vector<float4*>&)area describedByRegions:(std::vector<MTLRegion>*)regions;
-(void)fillArea:(std::vector<float4*>&)area describedByRegions:(std::vector<MTLRegion>*)regions;
@end
