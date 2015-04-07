//
//  CalculateQuadrant.h
//  ComputeMetal
//
//  Created by Michael Davidson on 3/27/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Metal/Metal.h>

@class Mandelbrot;

@interface CalculateQuadrant : NSOperation

//-(instancetype)initWithTexture:(id<MTLTexture>)texture Region:(MTLRegion)region;
-(id)initWithTexture:(id<MTLTexture>)texture Region:(MTLRegion)region Mandelbrot:(Mandelbrot*)man;

@end
