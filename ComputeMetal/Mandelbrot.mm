//
//  Mandelbrot.m
//  ComputeMetal
//
//  Created by Michael Davidson on 1/29/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import "Mandelbrot.h"
#import "Quad.h"
#import "Utilities.h"

@implementation Mandelbrot
{
    __weak id<MTLDevice> _device;
    __weak id<MTLLibrary> _library;

    MTLRenderPassDescriptor *_firstPassDescriptor;
    id<MTLRenderPipelineState> _firstPassPipelineState;

    MTLRenderPassDescriptor *_evenPassDescriptor;
    id<MTLRenderPipelineState> _evenPassPipelineState;

    MTLRenderPassDescriptor *oddPassDescriptor;
    id<MTLRenderPipelineState> _oddPassPipelineState;

    MTLRenderPassDescriptor *finalPassDescriptor;
    id<MTLRenderPipelineState> _finalPassPipelineState;

    Quad *_quad;

    NSMutableArray *_renderCommandEncoders;

    id<MTLBuffer> _mandelDataBuffer;


    //these two textures are used to ping pong back and forth for the iterations
    //first pass will also write to one of these, probably #2 to keep the numbers
    //lined up with even and odd during the ping pong
    id<MTLTexture> _texture1;
    id<MTLTexture> _texture2;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device Library:(id<MTLLibrary>)library
{
    self = [super init];
    if(self)
    {
        _device = device;
        _library = library;
        _data.aspect = 1.0;
        _data.zoom = 3;
        _data.pan = {0.5, 0.0};
    }
    return self;
}

@end



























