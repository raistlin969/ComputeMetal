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

    MTLRenderPassDescriptor *_firstRenderPassDescriptor;
    MTLRenderPassDescriptor *_multiRenderPassDescriptor;

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

    NSUInteger _maxIterations;
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
        _maxIterations = 10;
        _color = {1.0, 0.0, 0.0, 1.0};
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

    _finalPassPipelineState = [_device newRenderPipelineStateWithDescriptor:finalDesc error:&error];
    CheckPipelineError(_finalPassPipelineState, error);

    

    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:_size.width height:_size.height mipmapped:NO];

    _texture1 = [_device newTextureWithDescriptor:desc];
    _texture2 = [_device newTextureWithDescriptor:desc];

    if(_firstRenderPassDescriptor == nil)
        _firstRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    if(_multiRenderPassDescriptor == nil)
        _multiRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];

    _firstRenderPassDescriptor.colorAttachments[0].texture = _texture1;
    _firstRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    _firstRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    _multiRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    _multiRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;


    return YES;
}

- (void)encode:(id<MTLCommandBuffer>)commandBuffer
{
    id<MTLRenderCommandEncoder> firstPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_firstRenderPassDescriptor];

    [firstPassEncoder pushDebugGroup:@"First Pass"];
    [firstPassEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    [firstPassEncoder setRenderPipelineState:_firstPassPipelineState];
    [firstPassEncoder setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];

    [_quad encode:firstPassEncoder];

    [firstPassEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];
    [firstPassEncoder endEncoding];
    [firstPassEncoder popDebugGroup];

    for(NSUInteger i = 0; i < _maxIterations; i++)
    {
        id<MTLRenderCommandEncoder> multiPassEncoder;

        if(i % 2 == 0)
        {
            _multiRenderPassDescriptor.colorAttachments[0].texture = _texture2;
            multiPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_multiRenderPassDescriptor];
            [multiPassEncoder pushDebugGroup:[NSString stringWithFormat: @"Multi Pass #%lui", (unsigned long)i ]];
            [multiPassEncoder setFragmentTexture:_texture1 atIndex:0];
        }
        else
        {
            _multiRenderPassDescriptor.colorAttachments[0].texture = _texture1;
            multiPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_multiRenderPassDescriptor];
            [multiPassEncoder pushDebugGroup:[NSString stringWithFormat: @"Multi Pass #%lui", (unsigned long)i ]];
            [multiPassEncoder setFragmentTexture:_texture2 atIndex:0];
        }
        [multiPassEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [multiPassEncoder setRenderPipelineState:_multiPassPipelineState];
        [_quad encode:multiPassEncoder];
        [multiPassEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];
        [multiPassEncoder endEncoding];
        [multiPassEncoder popDebugGroup];
    }

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
}

- (void)panX:(float)x Y:(float)y
{
    MandelData *data = (MandelData*)[_mandelDataBuffer contents];
    data->pan.x = x;
    data->pan.y = y;

    _data.pan.x = x;
    _data.pan.y = y;
}

- (void)zoom:(float)zoom
{
    MandelData *data = (MandelData*)[_mandelDataBuffer contents];
    data->zoom = zoom;
    _data.zoom = zoom;
}
@end



























