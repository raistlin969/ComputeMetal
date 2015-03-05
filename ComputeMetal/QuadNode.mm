//
//  QuadNode.m
//  ComputeMetal
//
//  Created by Michael Davidson on 3/2/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import "QuadNode.h"

using namespace simd;

@implementation QuadNode
{
    float4 *_buffer;

    float4 *_top;
    float4 *_bottom;
    float4 *_right;
    float4 *_left;
}

-(id)initWithSize:(uint2)size atX:(uint)x Y:(uint)y
{
    self = [super init];
    if(self)
    {
        _nw = nil;
        _ne = nil;
        _sw = nil;
        _se = nil;
        _buffer = NULL;
        _mandelNode.size = size;
        _mandelNode.x = x;
        _mandelNode.y = y;
        _top = new float4[size.x];
        _bottom = new float4[size.x];
        _right = new float4[size.y];
        _left = new float4[size.y];
    }
    return self;
}

-(void)dealloc
{
    delete[] _top;
    delete [] _bottom;
    delete [] _right;
    delete [] _left;
}

-(void)createBufferSize:(int)size
{
    _buffer = new float4[size];
}

-(void)destroyBuffer
{
    if(_buffer)
        delete[] _buffer;
}

-(void)subdivideTexture:(id<MTLTexture>)c currentDepth:(int)depth
{
    MTLRegion top;
    MTLRegion bottom;
    MTLRegion right;
    MTLRegion left;
    MTLSize width;
    MTLSize height;

    MTLRegion square = MTLRegionMake2D(_mandelNode.x, _mandelNode.y, _mandelNode.size.x, _mandelNode.size.y);

    width = MTLSizeMake(_mandelNode.size.x, 1, 1);
    height = MTLSizeMake(1, _mandelNode.size.y, 1);

    top.size = width;
    top.origin = MTLOriginMake(_mandelNode.x, _mandelNode.y, 0);

    bottom.size = width;
    bottom.origin = MTLOriginMake(_mandelNode.x, _mandelNode.y + _mandelNode.size.y - 1, 0);

    left.size = height;
    left.origin = MTLOriginMake(_mandelNode.x, _mandelNode.y, 0);

    right.size = height;
    right.origin = MTLOriginMake(_mandelNode.x + _mandelNode.size.x - 1, _mandelNode.y, 0);

    [c getBytes:_top bytesPerRow:sizeof(float4)*width.width fromRegion:top mipmapLevel:0];
    [c getBytes:_bottom bytesPerRow:sizeof(float4)*width.width fromRegion:bottom mipmapLevel:0];
    [c getBytes:_left bytesPerRow:sizeof(float4) fromRegion:left mipmapLevel:0];
    [c getBytes:_right bytesPerRow:sizeof(float4) fromRegion:right mipmapLevel:0];

    

    BOOL same = YES;
    float2 topZ;
    float2 bottomZ;
    float2 leftZ;
    float2 rightZ;

    for(int i = 0; i < _mandelNode.size.x; i++) //square, so either x or y
    {
        topZ = _top[i].xy;
        bottomZ = _bottom[i].xy;
        leftZ = _left[i].xy;
        rightZ = _right[i].xy;

        BOOL topDone = NO, bottomDone = NO, leftDone = NO, rightDone = NO;
        for(int it = 0; it < 256; it++)
        {
            if(!topDone)
            {
                if(dot(topZ, topZ) > 4.0)
                {
                    _top[i].z = (float)it;
                    topDone = YES;
                }
                else
                {
                    topZ.x = (topZ.x * topZ.x - topZ.y*topZ.y) + _top[i].x;
                    topZ.y = (2.0*topZ.x*topZ.y) + _top[i].y;
                    _top[i].z = (float)it;
                }
            }
            if(!bottomDone)
            {
                if(dot(bottomZ, bottomZ) > 4.0)
                {
                    _bottom[i].z = (float)it;
                    bottomDone = YES;
                }
                else
                {
                    bottomZ.x = (bottomZ.x * bottomZ.x - bottomZ.y*bottomZ.y) + _bottom[i].x;
                    bottomZ.y = (2.0*bottomZ.x*bottomZ.y) + _bottom[i].y;
                    _bottom[i].z = (float)it;
                }
            }
            if(!leftDone)
            {
                if(dot(leftZ, leftZ) > 4.0)
                {
                    _left[i].z = (float)it;
                    leftDone = YES;
                }
                else
                {
                    leftZ.x = (leftZ.x * leftZ.x - leftZ.y*leftZ.y) + _left[i].x;
                    leftZ.y = (2.0*leftZ.x*leftZ.y) + _left[i].y;
                    _left[i].z = (float)it;
                }
            }
            if(!rightDone)
            {
                if(dot(rightZ, rightZ) > 4.0)
                {
                    _right[i].z = (float)it;
                    rightDone = YES;
                }
                else
                {
                    rightZ.x = (rightZ.x * rightZ.x - rightZ.y*rightZ.y) + _right[i].x;
                    rightZ.y = (2.0*rightZ.x*rightZ.y) + _right[i].y;
                    _right[i].z = (float)it;
                }
            }
            if(topDone && bottomDone && leftDone && rightDone)
                break;
        }
        if(_top[0].z != _top[i].z || _top[0].z != _bottom[i].z || _top[0].z != _right[i].z || _top[0].z != _left[i].z)
        {
            same = NO;
            break;
        }
    }

    if(!same && depth >= 0)
    {
        uint x = self.mandelNode.x;
        uint y = self.mandelNode.y;
        uint2 size = self.mandelNode.size / 2;

        self.nw = [[QuadNode alloc] initWithSize:size atX:x Y:y];
        self.ne = [[QuadNode alloc] initWithSize:size atX:x + size.x Y:y];
        self.sw = [[QuadNode alloc] initWithSize:size atX:x Y:y + size.y];
        self.se = [[QuadNode alloc] initWithSize:size atX:x + size.x Y:y + size.y];

        [self.nw subdivideTexture:c currentDepth:depth-1];
        [self.ne subdivideTexture:c currentDepth:depth-1];
        [self.sw subdivideTexture:c currentDepth:depth-1];
        [self.se subdivideTexture:c currentDepth:depth-1];
    }
    else
    {
        for(int i = 0; i < _mandelNode.size.x; i++)
        {
            _top[i].w = 1.0;
            _bottom[i].w = 1.0;
            _left[i].w = 1.0;
            _right[i].w = 1.0;
        }
        [c replaceRegion:top mipmapLevel:0 withBytes:_top bytesPerRow:sizeof(float4)*width.width];
        [c replaceRegion:bottom mipmapLevel:0 withBytes:_bottom bytesPerRow:sizeof(float4)*width.width];
        [c replaceRegion:left mipmapLevel:0 withBytes:_left bytesPerRow:sizeof(float4)];
        [c replaceRegion:right mipmapLevel:0 withBytes:_right bytesPerRow:sizeof(float4)];
    }
}

@end
