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
#import "QuadNode.h"

#import <simd/simd.h>
#include <vector>

#define ARC4RANDOM_MAX      0x100000000

@implementation Mandelbrot
{
    __weak id<MTLDevice> _device;
    __weak id<MTLLibrary> _library;

    id<MTLCommandQueue> _queue;
    
    id<MTLRenderPipelineState> _finalPassPipelineState;

    id<MTLComputePipelineState> _kernel;

    Quad *_quad;
    MandelData _data;

    CGSize _size;

    simd::float4 _color;

    id<MTLBuffer> _mandelDataBuffer;
    id<MTLBuffer> _colorBuffer;

    id<MTLTexture> _original;
//    id<MTLTexture> _texture1;
//    id<MTLTexture> _texture2;
//    id<MTLTexture> _texture3;

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

    MTLRenderPassDescriptor *_generateC;

    BOOL _highResReady;
    int _iteration;

    id<MTLTexture> _iterationCountTexture;
    id<MTLBuffer> _nodes;

    BOOL _nwDone, _neDone, _swDone, _seDone;
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
        _queue = [_device newCommandQueue];
        _nwDone = _neDone = _swDone = _seDone = NO;
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

    _nodes = [_device newBufferWithLength:sizeof(MandelNode) * 4 options:0];

    id<MTLFunction> vertexFunction = _newFunctionFromLibrary(_library, @"passThroughVertex");
    id<MTLFunction> finalFragment = _newFunctionFromLibrary(_library, @"passFinal");
    id<MTLFunction> mandelKernel = _newFunctionFromLibrary(_library, @"mandelIterationKernel");

    id<MTLFunction> lowResolutionFragment = _newFunctionFromLibrary(_library, @"lowResolutionFragment");
    id<MTLFunction> highResolutionFragment = _newFunctionFromLibrary(_library, @"highResolutionFragment");
    id<MTLFunction> generateCFragment = _newFunctionFromLibrary(_library, @"generateZFragment");

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

    desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:1024 height:1024 mipmapped:NO];
    _lowResolutionOutput = [_device newTextureWithDescriptor:desc];

    desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:1024 height:1024 mipmapped:NO];
    _highResolutionZ = [_device newTextureWithDescriptor:desc];
    _highResolutionOutput = [_device newTextureWithDescriptor:desc];


    if(_lowResPass == nil)
        _lowResPass = [MTLRenderPassDescriptor renderPassDescriptor];
    if(_generateHighResZPass == nil)
        _generateHighResZPass = [MTLRenderPassDescriptor renderPassDescriptor];
    if(_highResFrameIterationPass == nil)
        _highResFrameIterationPass = [MTLRenderPassDescriptor renderPassDescriptor];

    if(_generateC == nil)
        _generateC = [MTLRenderPassDescriptor renderPassDescriptor];


    _lowResPass.colorAttachments[0].texture = _lowResolutionOutput;
    _lowResPass.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    _lowResPass.colorAttachments[0].storeAction = MTLStoreActionStore;

    _generateHighResZPass.colorAttachments[0].texture = _highResolutionOutput;
    _generateHighResZPass.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    _generateHighResZPass.colorAttachments[0].storeAction = MTLStoreActionStore;

    _highResFrameIterationPass.colorAttachments[0].texture = _highResolutionOutput;
    _highResFrameIterationPass.colorAttachments[0].loadAction = MTLLoadActionLoad;
    _highResFrameIterationPass.colorAttachments[0].storeAction = MTLStoreActionStore;


    desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:2048 height:2048 mipmapped:NO];
    _original = [_device newTextureWithDescriptor:desc];

    _generateC.colorAttachments[0].texture = _original;
    _generateC.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    _generateC.colorAttachments[0].storeAction = MTLStoreActionStore;


    desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR16Uint width:1024 height:1024 mipmapped:NO];
    _iterationCountTexture = [_device newTextureWithDescriptor:desc];

    return YES;
}

- (void)encode
{
    if(!_changed)
        return;
    _highResReady = NO;
    id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
    id<MTLRenderCommandEncoder> genC = [commandBuffer renderCommandEncoderWithDescriptor:_generateHighResZPass];
    [genC setFrontFacingWinding:MTLWindingCounterClockwise];
    [genC setRenderPipelineState:_calculateZ];
    [genC setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];
    [_quad encode:genC];
    [genC drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    [genC endEncoding];

    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer>) {
        [self someFunc];
        _changed = NO;
    }];

//    id<MTLComputeCommandEncoder> compute = [commandBuffer computeCommandEncoder];
//    [compute pushDebugGroup:@"compute"];
//    [compute setComputePipelineState:_kernel];
//    [compute setTexture:_highResolutionOutput atIndex:0];
//    [compute setTexture:_iterationCountTexture atIndex:1];
//    [compute setBuffer:_nodes offset:0 atIndex:0];
//    //[compute setTexture:_lowResolutionOutput atIndex:1];
//    MTLSize threadPerGroup = {16, 16, 1};
//    MTLSize numThreadGroups = {_highResolutionOutput.width/16, _highResolutionOutput.height/16, 1};
//    [compute dispatchThreadgroups:numThreadGroups threadsPerThreadgroup:threadPerGroup];
//    [compute endEncoding];
//    [compute popDebugGroup];


//    id<MTLRenderCommandEncoder> orig = [commandBuffer renderCommandEncoderWithDescriptor:_generateC];
//    [orig setFrontFacingWinding:MTLWindingCounterClockwise];
//    [orig setRenderPipelineState:_calculateZ];
//    [orig setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];
//
//    [_quad encode:orig];
//
//    [orig drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
//    [orig endEncoding];

//    id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
//
//
//    id<MTLRenderCommandEncoder> highRes = [commandBuffer renderCommandEncoderWithDescriptor:_generateHighResZPass];
//    [highRes setFrontFacingWinding:MTLWindingCounterClockwise];
//    [highRes setRenderPipelineState:_fullIteration];
//    [highRes setFragmentBuffer:_mandelDataBuffer offset:0 atIndex:0];
//
//    [_quad encode:highRes];
//
//    [highRes drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
//    [highRes endEncoding];
//
    [commandBuffer commit];
    
}

-(void)performIterationsOnArea:(float4*)area describedByRegion:(MTLRegion)region
{
    id<MTLBuffer> buffer = [_device newBufferWithBytes:area length:1024*sizeof(float4) options:0];
    id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
    id<MTLComputeCommandEncoder> compute = [commandBuffer computeCommandEncoder];
    [compute setComputePipelineState:_kernel];
    
    [compute setBuffer:buffer offset:0 atIndex:0];
    MTLSize threadsPerGroup = {1, 1, 1};
    MTLSize numThreadGroups = {1024, 1, 1};
    [compute dispatchThreadgroups:numThreadGroups threadsPerThreadgroup:threadsPerGroup];
    [compute endEncoding];
    
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer>)
     {
         float4 *dataDone = (float4*)[buffer contents];
         [_highResolutionOutput replaceRegion:region mipmapLevel:0 withBytes:dataDone bytesPerRow:sizeof(float4)*region.size.width];
     }];
    
    [commandBuffer commit];
}

-(void)performIterationsOnArea:(std::vector<float4*>&)area describedByRegions:(std::vector<MTLRegion>*)regions
{
    if(area.size() <= 0 || regions->size() <= 0)
        return;
    
    NSUInteger regionWidth = (*regions)[0].size.width;
    NSUInteger regionHeight = (*regions)[0].size.height;
    NSUInteger regionArea = regionWidth * regionHeight;
    
    float4 *data = new float4[regionArea*area.size()];
    int pos = 0;
    for(std::vector<float4*>::iterator it = area.begin(); it != area.end(); ++it)
    {
        memcpy(&data[pos], *it, regionArea*sizeof(float4));
        pos+=regionArea;
        delete *it;
    }
    id<MTLBuffer> buffer = [_device newBufferWithBytes:data length:area.size()*sizeof(float4)*regionArea options:0];
    id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
    id<MTLComputeCommandEncoder> compute = [commandBuffer computeCommandEncoder];
    [compute setComputePipelineState:_kernel];
    
    [compute setBuffer:buffer offset:0 atIndex:0];
    MTLSize threadsPerGroup = {1, 1, 1};
    MTLSize numThreadGroups = {area.size()*regionArea, 1, 1};
    [compute dispatchThreadgroups:numThreadGroups threadsPerThreadgroup:threadsPerGroup];
    [compute endEncoding];
    area.clear();
    
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer>)
     {
         float4 *dataDone = (float4*)[buffer contents];
         int i = 0;
         for(std::vector<MTLRegion>::const_iterator it = regions->begin(); it != regions->end(); ++it)
         {
             [_highResolutionOutput replaceRegion:*it mipmapLevel:0 withBytes:&dataDone[i] bytesPerRow:sizeof(float4)*regionWidth];
             i+=regionArea;
         }
         _nwDone = YES;
     }];
    
    [commandBuffer commit];
    delete [] data;
}

-(void)someFunc
{
    QuadNode *root = [[QuadNode alloc] initWithSize:{1024, 1024} atX:0 Y:0];

    uint x = root.mandelNode.x;
    uint y = root.mandelNode.y;
    uint2 size = root.mandelNode.size / 2;

    root.nw = [[QuadNode alloc] initWithSize:size atX:x Y:y];
    root.ne = [[QuadNode alloc] initWithSize:size atX:x + size.x Y:y];
    root.sw = [[QuadNode alloc] initWithSize:size atX:x Y:y + size.y];
    root.se = [[QuadNode alloc] initWithSize:size atX:x + size.x Y:y + size.y];

    @autoreleasepool
    {
        dispatch_queue_t nwQ = dispatch_queue_create("nw" , NULL);
        dispatch_queue_t neQ = dispatch_queue_create("ne" , NULL);
        dispatch_queue_t swQ = dispatch_queue_create("sw" , NULL);
        dispatch_queue_t seQ = dispatch_queue_create("se" , NULL);

        dispatch_async(nwQ, ^{
            std::vector<float4*> area[4];
            std::vector<MTLRegion> *regions = new std::vector<MTLRegion>[4];
            
            [root.nw subdivideTexture:_highResolutionOutput currentDepth:4 levelRegions:area regionInfo:regions mandelbrot:self];
            [self performIterationsOnArea:area[0] describedByRegions:&regions[0]];
        });
        dispatch_async(neQ, ^{
            std::vector<float4*> area[4];
            std::vector<MTLRegion> *regions = new std::vector<MTLRegion>[4];
            
            [root.ne subdivideTexture:_highResolutionOutput currentDepth:4 levelRegions:area regionInfo:regions mandelbrot:self];
            [self performIterationsOnArea:area[0] describedByRegions:&regions[0]];
        });
        dispatch_async(swQ, ^{
            std::vector<float4*> area[4];
            std::vector<MTLRegion> *regions = new std::vector<MTLRegion>[4];
            
            [root.sw subdivideTexture:_highResolutionOutput currentDepth:4 levelRegions:area regionInfo:regions mandelbrot:self];
            [self performIterationsOnArea:area[0] describedByRegions:&regions[0]];
        });
        dispatch_async(seQ, ^{
            std::vector<float4*> area[4];
            std::vector<MTLRegion> *regions = new std::vector<MTLRegion>[4];
            
            [root.se subdivideTexture:_highResolutionOutput currentDepth:4 levelRegions:area regionInfo:regions mandelbrot:self];
            [self performIterationsOnArea:area[0] describedByRegions:&regions[0]];
        });
    }
   // _highResReady = YES;
}

- (void)encodeFinal:(id<MTLRenderCommandEncoder>)finalEncoder
{
    if(!_nwDone)// || !_neDone || !_swDone || !_seDone)
    {
        [finalEncoder endEncoding];
        return;
    }
    [finalEncoder pushDebugGroup:@"Final Pass"];
    [finalEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    [finalEncoder setRenderPipelineState:_finalPassPipelineState];
    [_quad encode:finalEncoder];
        [finalEncoder setFragmentTexture:_highResolutionOutput atIndex:0];
//    else
//        [finalEncoder setFragmentTexture:_lowResolutionOutput atIndex:0];

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



























