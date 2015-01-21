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

static const uint32_t countQuadTexCoords = 6;
static const uint32_t sizeQuadTexCoords = countQuadTexCoords * sizeof(simd::float2);
static const uint32_t countQuadVertices = countQuadTexCoords;
static const uint32_t sizeQuadVertices = countQuadVertices * sizeof(simd::float4);

static const simd::float4 quadVertices[countQuadVertices] =
{
    { -1.0f,  -1.0f, 0.0f, 1.0f },
    {  1.0f,  -1.0f, 0.0f, 1.0f },
    { -1.0f,   1.0f, 0.0f, 1.0f },

    {  1.0f,  -1.0f, 0.0f, 1.0f },
    { -1.0f,   1.0f, 0.0f, 1.0f },
    {  1.0f,   1.0f, 0.0f, 1.0f }
};

static const simd::float2 quadTexCoords[countQuadTexCoords] =
{
    { 0.0f, 0.0f },
    { 1.0f, 0.0f },
    { 0.0f, 1.0f },

    { 1.0f, 0.0f },
    { 0.0f, 1.0f },
    { 1.0f, 1.0f }
};

@implementation Quad
{
    @private
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _texCoordBuffer;

    CGSize _size;
    CGRect _bounds;
    float _aspect;

    NSUInteger _vertexIndex;
    NSUInteger _texCoordIndex;
    NSUInteger _samplerIndex;

    simd::float2 _scale;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    self = [super init];
    if(self)
    {
        if(!device)
        {
            NSLog(@"ERROR: Invalid device");
            return nil;
        }

        _vertexBuffer = [device newBufferWithBytes:quadVertices length:sizeQuadVertices options:MTLResourceOptionCPUCacheModeDefault];

        if(!_vertexBuffer)
        {
            NSLog(@"ERROR: Failed creating vertex buffer for a quad");
            return nil;
        }
        _vertexBuffer.label = @"quad vertices";

        _texCoordBuffer = [device newBufferWithBytes:quadTexCoords length:sizeQuadTexCoords options:MTLResourceOptionCPUCacheModeDefault];

        if(!_texCoordBuffer)
        {
            NSLog(@"ERROR: Failed creating a 2d texture coordinate buffer");
            return nil;
        }
        _texCoordBuffer.label = @"quad texcoords";

        _vertexIndex = 0;
        _texCoordIndex = 1;
        _samplerIndex = 0;

        _size = CGSizeMake(0.0, 0.0);
        _bounds = CGRectMake(0.0, 0.0, 0.0, 0.0);
        _aspect = 1.0f;
        _scale = 1.0f;
    }
    return self;
}

- (void)setBounds:(CGRect)bounds
{
    _bounds = bounds;
    _aspect = fabsf(_bounds.size.width / _bounds.size.height);

    float aspect = 1.0f/_aspect;
    simd::float2 scale = 0.0f;

    scale.x = aspect * _size.width / _bounds.size.width;
    scale.y = _size.height / _bounds.size.height;

    //did the scaling factor change
    BOOL newScale = (scale.x != _scale.x) || (scale.y != _scale.y);

    //set the (x,y) bounds of the quad
    if(newScale)
    {
        _scale = scale;

        //update the vertex buffer with the quad bounds
        simd::float4 *vertices = (simd::float4 *)[_vertexBuffer contents];

        if(vertices != NULL)
        {
            //first triangle
            vertices[0].x = -_scale.x;
            vertices[0].y = -_scale.y;

            vertices[1].x = _scale.x;
            vertices[1].y = -_scale.y;

            vertices[2].x = -_scale.x;
            vertices[2].y = _scale.y;

            //second triangle
            vertices[3].x = _scale.x;
            vertices[3].y = -_scale.y;

            vertices[4].x = -_scale.x;
            vertices[4].y = _scale.y;

            vertices[5].x = _scale.x;
            vertices[5].y = _scale.y;
        }
    }
}

- (void)encode:(id<MTLRenderCommandEncoder>)renderEncoder
{
    [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:_vertexIndex];
    [renderEncoder setVertexBuffer:_texCoordBuffer offset:0 atIndex:_texCoordIndex];
}

@end



























