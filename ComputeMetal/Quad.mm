//
//  Quad.m
//  ComputeMetal
//
//  Created by Michael Davidson on 1/18/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#include <simd/simd.h>
#import "Quad.h"

static const uint32_t kCntQuadTexCoords = 6;
static const uint32_t kSzQuadTexCoords  = kCntQuadTexCoords * sizeof(simd::float2);


static const uint32_t countQuadTexCoords = 6;
static const uint32_t sizeQuadTexCoords = countQuadTexCoords * sizeof(simd::float2);
static const uint32_t countQuadVertices = countQuadTexCoords;
static const uint32_t sizeQuadVertices = countQuadVertices * sizeof(simd::float4);

@implementation Quad

@end
