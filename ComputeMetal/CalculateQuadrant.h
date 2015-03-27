//
//  CalculateQuadrant.h
//  ComputeMetal
//
//  Created by Michael Davidson on 3/27/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Metal/Metal.h>

@interface CalculateQuadrant : NSOperation

-(instancetype)initWithTexture:(id<MTLTexture>)texture Region:(MTLRegion)region;

@end
