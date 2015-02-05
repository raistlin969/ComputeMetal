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

#import <simd/simd.h>

#define ARC4RANDOM_MAX      0x100000000

@implementation Mandelbrot
{
    __weak id<MTLDevice> _device;
    __weak id<MTLLibrary> _library;

    id<MTLRenderPipelineState> _firstPassPipelineState;

    id<MTLRenderPipelineState> _multiPassPipelineState;

    id<MTLRenderPipelineState> _finalPassPipelineState;

    id<MTLRenderPipelineState> _even;
    id<MTLRenderPipelineState> _odd;

    MTLRenderPassDescriptor *_firstRenderPassDescriptor;
    MTLRenderPassDescriptor *_multiRenderPassDescriptor;
    MTLRenderPassDescriptor *_evenPass;
    MTLRenderPassDescriptor *_oddPass;

    Quad *_quad;
    MandelData _data;

    CGSize _size;

    simd::float4 _color;

    id<MTLBuffer> _mandelDataBuffer;
    id<MTLBuffer> _colorBuffer;


    //these two textures are used to ping pong back and forth for the iterations
    //first pass will also write to one of these
    id<MTLTexture> _texture1;
    id<MTLTexture> _texture2;


    BOOL _changed;

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
        _data.iteration = 0;
        _data.maxIteration = 256;
        _data.iteration = 0;
        _data.iterationStep = 20;
        _color = {1.0, 0.0, 0.0, 1.0};
        _changed = YES;
    }
    return self;
}

- (BOOL)configure:(MetalView *)view
{
    int w = [UIScreen mainScreen].bounds.size.width;
    float scale = [UIScreen mainScreen].scale;
    int ww = w * scale;
    int h = [UIScreen mainScreen].bounds.size.height;
    int hh = h * scale;
    _size.width = ww;//[UIScreen mainScreen].nativeBounds.size.width;
    _size.height = hh;//[UIScreen mainScreen].nativeBounds.size.height;

    _quad = [[Quad alloc] initWithDevice:_device];
    if(!_quad)
    {
        NSLog(@"ERROR: Failed creating a quad object");
        return NO;
    }
    _quad.size = _size;
    _colorBuffer = [_device newBufferWithBytes:&_color length:sizeof(simd::float4) options:0];

    _mandelDataBuffer = [_device newBufferWithBytes:&_data length:sizeof(MandelData) options:0];

    id<MTLFunction> vertexFunction = _newFunctionFromLibrary(_library, @"passThroughVertex");
    id<MTLFunction> firstFragment = _newFunctionFromLibrary(_library, @"passFirstFragment");
    id<MTLFunction> multiFragment = _newFunctionFromLibrary(_library, @"passMultiFragment");
    id<MTLFunction> finalFragment = _newFunctionFromLibrary(_library, @"passFinal");

    MTLRenderPipelineDescriptor *firstDesc = [MTLRenderPipelineDescriptor new];
    firstDesc.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    firstDesc.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    firstDesc.sampleCount = 1;
    firstDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
    firstDesc.vertexFunction = vertexFunction;
    firstDesc.fragmentFunction = firstFragment;
    firstDesc.label = @"First Pass";

    MTLRenderPipelineDescriptor *multiDesc = [MTLRenderPipelineDescriptor new];
    multiDesc.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    multiDesc.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    multiDesc.sampleCount = 1;
    multiDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
    multiDesc.vertexFunction = vertexFunction;
    multiDesc.fragmentFunction = multiFragment;
    multiDesc.label = @"Multi Pass";

    MTLRenderPipelineDescriptor *evenDesc = [MTLRenderPipelineDescriptor new];
    evenDesc.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    evenDesc.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    evenDesc.sampleCount = 1;
    evenDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
    evenDesc.vertexFunction = vertexFunction;
    evenDesc.fragmentFunction = multiFragment;
    evenDesc.label = @"Multi Pass";

    MTLRenderPipelineDescriptor *oddDesc = [MTLRenderPipelineDescriptor new];
    oddDesc.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    oddDesc.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    oddDesc.sampleCount = 1;
    oddDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
    oddDesc.vertexFunction = vertexFunction;
    oddDesc.fragmentFunction = multiFragment;
    oddDesc.label = @"Multi Pass";

    MTLRenderPipelineDescriptor *finalDesc = [MTLRenderPipelineDescriptor new];
    finalDesc.depthAttachmentPixelFormat = view.depthPielFormat;
    finalDesc.stencilAttachmentPixelFormat = view.stencilPixelFormat;
    finalDesc.sampleCount = view.sampleCount;
    finalDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    finalDesc.vertexFunction = vertexFunction;
    finalDesc.fragmentFunction = finalFragment;
    finalDesc.label = @"final Pass";

    NSError *error = nil;

    _firstPassPipelineState = [_device newRenderPipelineStateWithDescriptor:firstDesc error:&error];
    CheckPipelineError(_firstPassPipelineState, error);

    _multiPassPipelineState = [_device newRenderPipelineStateWithDescriptor:multiDesc error:&error];
    CheckPipelineError(_multiPassPipelineState, error);

    _even = [_device newRenderPipelineStateWithDescriptor:evenDesc error:&error];
    CheckPipelineError(_even, error);

    _odd = [_device newRenderPipelineStateWithDescriptor:oddDesc error:&error];
    CheckPipelineError(_odd, error);

    _finalPassPipelineState = [_device newRenderPipelineStateWithDescriptor:finalDesc error:&error];
    CheckPipelineError(_finalPassPipelineState, error);

    

    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:_size.width height:_size.height mipmapped:NO];

    _texture1 = [_device newTextureWithDescriptor:desc];
    _texture2 = [_device newTextureWithDescriptor:desc];

    if(_firstRenderPassDescriptor == nil)
        _firstRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    if(_multiRenderPassDescriptor == nil)
        _multiRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];

    _firstRenderPassDescriptor.colorAttachments[0].texture = _texture2;
    _firstRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    _firstRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    _multiRenderPassDescriptor.colorAttachments[0].texture = _texture2;
    _multiRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    _multiRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    _oddPass.colorAttachments[0].texture = _texture1;
    _oddPass.colorAttachments[0].loadAction = MTLLoadActionLoad;
    _oddPass.colorAttachments[0].storeAction = MTLStoreActionStore;

    _evenPass.colorAttachments[0].texture = _texture2;
    _evenPass.colorAttachments[0].loadAction = MTLLoadActionLoad;
    _evenPass.colorAttachments[0].storeAction = MTLStoreActionStore;


    return YES;
}

- (void)encode:(id<MTLCommandBuffer>)commandBuffer
{
    id<MTLRenderCommandEncoder> firstPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_firstRenderPassDescriptor];

    MandelData *data = (MandelData*)[_mandelDataBuffer contents];
    if(_changed)
    {
        data->iteration = 0;
        [firstPassEncoder pushDebugGroup:@"First Pass"];
        [firstPassEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [firstPassEncoder setRenderPipelineState:_firstPassPipelineState];
        [firstPassEncoder setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];

        [_quad encode:firstPassEncoder];

        [firstPassEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];
        //[firstPassEncoder endEncoding];
        [firstPassEncoder popDebugGroup];
        _changed = NO;
    }
    if(data->iteration < data->maxIteration)
    {
        [firstPassEncoder setFragmentTexture:_texture2 atIndex:0];
        [firstPassEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [firstPassEncoder setRenderPipelineState:_multiPassPipelineState];
        data->iteration += data->iterationStep;
        [firstPassEncoder setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];
        [_quad encode:firstPassEncoder];
        //for(NSUInteger i = 0; i < 20; i++)
        //{
            [firstPassEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];
        //[firstPassEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];
        //}
    }
    [firstPassEncoder endEncoding];

    if(data->iteration > data->maxIteration)
    {
        id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
        [blit copyFromTexture:_texture2 sourceSlice:0 sourceLevel:0 sourceOrigin:{0,0,0} sourceSize:{_texture2.width, _texture2.height, 1} toTexture:_texture1 destinationSlice:0 destinationLevel:0 destinationOrigin:{0,0,0}];
        [blit endEncoding];
    }

    NSLog(@"iteration: %d", data->iteration);



//    id<MTLRenderCommandEncoder> multiPassEncoder;
//    multiPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_multiRenderPassDescriptor];
//    [multiPassEncoder setFragmentTexture:_texture2 atIndex:0];
//    [multiPassEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
//    [multiPassEncoder setRenderPipelineState:_multiPassPipelineState];
//    [multiPassEncoder setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];
//    [_quad encode:multiPassEncoder];
//    for(NSUInteger i = 0; i < _maxIterations; i++)
//    {
//        [multiPassEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];
//    }
//    [multiPassEncoder endEncoding];
}

- (void)encodeFinal:(id<MTLRenderCommandEncoder>)finalEncoder
{
    [finalEncoder pushDebugGroup:@"Final Pass"];
    [finalEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    [finalEncoder setRenderPipelineState:_finalPassPipelineState];
    [_quad encode:finalEncoder];
    [finalEncoder setFragmentTexture:_texture1 atIndex:0];
    [finalEncoder setFragmentBuffer:_colorBuffer offset:0 atIndex:0];
    [finalEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];
    [finalEncoder endEncoding];
    [finalEncoder popDebugGroup];
}

- (void)reshape:(MetalView *)view
{
    _quad.bounds = view.layer.frame;
}

- (void)changeColors
{
    simd::float4 *color = (simd::float4*)[_colorBuffer contents];
    color->x = ((float)arc4random() / ARC4RANDOM_MAX);
    color->y = ((float)arc4random() / ARC4RANDOM_MAX);
    color->z = ((float)arc4random() / ARC4RANDOM_MAX);
    _changed = YES;
}

- (void)panX:(float)x Y:(float)y
{
    MandelData *data = (MandelData*)[_mandelDataBuffer contents];
    data->pan.x = x;
    data->pan.y = y;

    _data.pan.x = x;
    _data.pan.y = y;
    _changed = YES;
    NSLog(@"%f,  %f", x, y);
}

- (void)zoom:(float)zoom
{
    MandelData *data = (MandelData*)[_mandelDataBuffer contents];
    data->zoom = zoom;
    _data.zoom = zoom;
    _changed = YES;
}
@end



























