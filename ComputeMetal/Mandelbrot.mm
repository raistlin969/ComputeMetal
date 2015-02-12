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

    id<MTLComputePipelineState> _kernel;

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
    id<MTLTexture> _texture3;

    BOOL _changed;

    id<MTLRenderPipelineState> _calculateZ;
    id<MTLRenderPipelineState> _fullIteration;
    id<MTLRenderPipelineState> _frameIteration;

    id<MTLTexture> _highResolutionZ;

    id<MTLTexture> _lowResolutionOutput;
    id<MTLTexture> _highResolutionOutput;

    MTLRenderPassDescriptor *_lowResPass;
    MTLRenderPassDescriptor *_generateHighResZPass;
    MTLRenderPassDescriptor *_highResFrameIterationPass;

    BOOL _highResReady;
    int _iteration;
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
        _data.iterationStep = 256;
        _color = {1.0, 0.0, 0.0, 1.0};
        _changed = YES;
        _highResReady = NO;
        _iteration = 0;
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
    _size.width = 512;//ww;//[UIScreen mainScreen].nativeBounds.size.width;
    _size.height = 512;//hh;//[UIScreen mainScreen].nativeBounds.size.height;

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
    id<MTLFunction> mandelKernel = _newFunctionFromLibrary(_library, @"mandelKernel");

    id<MTLFunction> lowResolutionFragment = _newFunctionFromLibrary(_library, @"lowResolutionFragment");
    id<MTLFunction> highResolutionFragment = _newFunctionFromLibrary(_library, @"highResolutionFragment");
    id<MTLFunction> generateCFragment = _newFunctionFromLibrary(_library, @"generateZFragment");

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

    MTLRenderPipelineDescriptor *lowDesc = [MTLRenderPipelineDescriptor new];
    lowDesc.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    lowDesc.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    lowDesc.sampleCount = 1;
    lowDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
    lowDesc.vertexFunction = vertexFunction;
    lowDesc.fragmentFunction = lowResolutionFragment;
    lowDesc.label = @"Low Res Pass";

    MTLRenderPipelineDescriptor *highDesc = [MTLRenderPipelineDescriptor new];
    highDesc.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    highDesc.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    highDesc.sampleCount = 1;
    highDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
    highDesc.vertexFunction = vertexFunction;
    highDesc.fragmentFunction = highResolutionFragment;
    highDesc.label = @"High Res Pass";

    MTLRenderPipelineDescriptor *zDesc = [MTLRenderPipelineDescriptor new];
    zDesc.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    zDesc.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    zDesc.sampleCount = 1;
    zDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
    zDesc.vertexFunction = vertexFunction;
    zDesc.fragmentFunction = generateCFragment;
    zDesc.label = @"Gen Z Pass";

    NSError *error = nil;

    _firstPassPipelineState = [_device newRenderPipelineStateWithDescriptor:firstDesc error:&error];
    CheckPipelineError(_firstPassPipelineState, error);

    _multiPassPipelineState = [_device newRenderPipelineStateWithDescriptor:multiDesc error:&error];
    CheckPipelineError(_multiPassPipelineState, error);

    _finalPassPipelineState = [_device newRenderPipelineStateWithDescriptor:finalDesc error:&error];
    CheckPipelineError(_finalPassPipelineState, error);

    _calculateZ = [_device newRenderPipelineStateWithDescriptor:zDesc error:&error];
    CheckPipelineError(_calculateZ, error);

    _fullIteration = [_device newRenderPipelineStateWithDescriptor:lowDesc error:&error];
    CheckPipelineError(_fullIteration, error);

    _frameIteration = [_device newRenderPipelineStateWithDescriptor:highDesc error:&error];
    CheckPipelineError(_frameIteration, error);

    _kernel = [_device newComputePipelineStateWithFunction:mandelKernel error:&error];
    CheckPipelineError(_kernel, error);

    

    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:_size.width height:_size.height mipmapped:NO];

    _texture1 = [_device newTextureWithDescriptor:desc];
    _texture2 = [_device newTextureWithDescriptor:desc];


    desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:512 height:512 mipmapped:NO];
    _lowResolutionOutput = [_device newTextureWithDescriptor:desc];

    desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:1024 height:1024 mipmapped:NO];
    _highResolutionZ = [_device newTextureWithDescriptor:desc];
    _highResolutionOutput = [_device newTextureWithDescriptor:desc];

    if(_firstRenderPassDescriptor == nil)
        _firstRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    if(_multiRenderPassDescriptor == nil)
        _multiRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];

    if(_lowResPass == nil)
        _lowResPass = [MTLRenderPassDescriptor renderPassDescriptor];
    if(_generateHighResZPass == nil)
        _generateHighResZPass = [MTLRenderPassDescriptor renderPassDescriptor];
    if(_highResFrameIterationPass == nil)
        _highResFrameIterationPass = [MTLRenderPassDescriptor renderPassDescriptor];

    _firstRenderPassDescriptor.colorAttachments[0].texture = _texture2;
    _firstRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    _firstRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    _multiRenderPassDescriptor.colorAttachments[0].texture = _texture2;
    _multiRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    _multiRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    _lowResPass.colorAttachments[0].texture = _lowResolutionOutput;
    _lowResPass.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    _lowResPass.colorAttachments[0].storeAction = MTLStoreActionStore;

    _generateHighResZPass.colorAttachments[0].texture = _highResolutionOutput;
    _generateHighResZPass.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    _generateHighResZPass.colorAttachments[0].storeAction = MTLStoreActionStore;

    _highResFrameIterationPass.colorAttachments[0].texture = _highResolutionOutput;
    _highResFrameIterationPass.colorAttachments[0].loadAction = MTLLoadActionLoad;
    _highResFrameIterationPass.colorAttachments[0].storeAction = MTLStoreActionStore;

    _texture3 = [_device newTextureWithDescriptor:desc];
    return YES;
}

- (void)encode:(id<MTLCommandBuffer>)commandBuffer
{
    if(_changed)
    {
        id<MTLRenderCommandEncoder> lowRes = [commandBuffer renderCommandEncoderWithDescriptor:_lowResPass];
        [lowRes setFrontFacingWinding:MTLWindingCounterClockwise];
        [lowRes setRenderPipelineState:_fullIteration];
        [lowRes setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];

        [_quad encode:lowRes];

        [lowRes drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [lowRes endEncoding];

        id<MTLRenderCommandEncoder> highRes = [commandBuffer renderCommandEncoderWithDescriptor:_generateHighResZPass];
        [highRes setFrontFacingWinding:MTLWindingCounterClockwise];
        [highRes setRenderPipelineState:_calculateZ];
        [highRes setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];

        [_quad encode:highRes];

        [highRes drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [highRes endEncoding];
        _highResReady = NO;
        _iteration = 0;
        _changed = NO;
    }
    else
    {
        id<MTLRenderCommandEncoder> highRes = [commandBuffer renderCommandEncoderWithDescriptor:_highResFrameIterationPass];
        [highRes setFrontFacingWinding:MTLWindingCounterClockwise];
        [highRes setRenderPipelineState:_frameIteration];
        [highRes setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];
        [highRes setFragmentTexture:_highResolutionOutput atIndex:0];

        [_quad encode:highRes];

        for(int i = 0; i < 20; i++)
        {
            [highRes drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        }
        [highRes endEncoding];
        _iteration+=20;
        if(_iteration > 256)
            _highResReady = YES;
    }




//    id<MTLRenderCommandEncoder> firstPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_firstRenderPassDescriptor];
//
//    if(_changed)
//    {
//        data->iteration = 0;
//        [firstPassEncoder pushDebugGroup:@"First Pass"];
//        [firstPassEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
//        [firstPassEncoder setRenderPipelineState:_firstPassPipelineState];
//        [firstPassEncoder setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];
//
//        [_quad encode:firstPassEncoder];
//
//        [firstPassEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];
//        //[firstPassEncoder endEncoding];
//        [firstPassEncoder popDebugGroup];
//        //_changed = NO;
//
//        [firstPassEncoder setFragmentTexture:_texture2 atIndex:0];
//        [firstPassEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
//        [firstPassEncoder setRenderPipelineState:_multiPassPipelineState];
//        data->iteration += data->iterationStep;
//        [firstPassEncoder setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];
//        [_quad encode:firstPassEncoder];
//        [firstPassEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];
//    }
//    [firstPassEncoder endEncoding];

}

- (void)encodeFinal:(id<MTLRenderCommandEncoder>)finalEncoder
{
    [finalEncoder pushDebugGroup:@"Final Pass"];
    [finalEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    [finalEncoder setRenderPipelineState:_finalPassPipelineState];
    [_quad encode:finalEncoder];
    if(_highResReady)
        [finalEncoder setFragmentTexture:_highResolutionOutput atIndex:0];
    else
        [finalEncoder setFragmentTexture:_lowResolutionOutput atIndex:0];

    [finalEncoder setFragmentBuffer:_colorBuffer offset:0 atIndex:0];
    [finalEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
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
//    _changed = YES;
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



























