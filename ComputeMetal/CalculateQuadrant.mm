//
//  CalculateQuadrant.m
//  ComputeMetal
//
//  Created by Michael Davidson on 3/27/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import "CalculateQuadrant.h"
#import "Mandelbrot.h"
#import <simd/simd.h>
#include <vector>
#import "QuadNode.h"

using namespace simd;

@implementation CalculateQuadrant
{
    __weak id<MTLTexture> _texture;
    __weak Mandelbrot *_mandel;
    MTLRegion _region;
    simd::float4 *_top;
    simd::float4 *_bottom;
    simd::float4 *_left;
    simd::float4 *_right;

}

-(id)initWithTexture:(id<MTLTexture>)texture Region:(MTLRegion)region Mandelbrot:(Mandelbrot *)man
{
    self = [super init];
    if(self)
    {
        _texture = texture;
        _mandel = man;
        _region = region;
    }
    return self;
}

-(void)main
{
    @autoreleasepool
    {
        QuadNode *root = [[QuadNode alloc] initWithSize:{static_cast<unsigned int>(_region.size.width), static_cast<unsigned int>(_region.size.height)} atX:_region.origin.x Y:_region.origin.y];

        std::vector<float4*> area[4];
        std::vector<MTLRegion> *regions = new std::vector<MTLRegion>[4];

        [root subdivideTexture:_texture currentDepth:4 levelRegions:area regionInfo:regions mandelbrot:_mandel];
        if(self.isCancelled)
            return;
        [_mandel performIterationsOnArea:area[0] describedByRegions:&regions[0]];
        if(self.isCancelled)
            return;
        for(int i = 1; i < 4; i++)
        {
            if(self.isCancelled)
                return;
            [_mandel fillArea:area[i] describedByRegions:&regions[i]];
        }

    }
}

//-(instancetype)initWithTexture:(id<MTLTexture>)texture Region:(MTLRegion)region
//{
//    self = [super init];
//    if(self)
//    {
//        _texture = texture;
//        _region = region;
//
//        _top = new float4[_region.size.width];
//        _bottom = new float4[_region.size.width];
//        _right = new float4[_region.size.height];
//        _left = new float4[_region.size.height];
//    }
//    return self;
//}

-(void)dealloc
{
    delete[] _top;
    delete [] _bottom;
    delete [] _right;
    delete [] _left;
}

@end
