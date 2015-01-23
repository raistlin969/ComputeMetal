//
//  Renderer.m
//  ComputeMetal
//
//  Created by Michael Davidson on 1/15/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import <string>

#import "Renderer.h"
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import <simd/simd.h>

#import "Transforms.h"
#import "Quad.h"
#import "MetalView.h"

static const float UI_INTERFACE_ORIENTATION_LANDSCAPE_ANGLE = 35.0f;
static const float UI_INTERFACE_ORIENTATION_PORTRAIT_ANGLE = 50.0f;

static const float PRESPECTIVE_NEAR = 0.1f;
static const float PRESPECTIVE_FAR = 100.0f;

static const uint32_t SIZE_SIMD_FLOAT4x4 = sizeof(simd::float4);
static const uint32_t SIZE_BUFFER_LIMITS_PER_FRAME = SIZE_SIMD_FLOAT4x4;

static const uint32_t IN_FLIGHT_COMMAND_BUFFERS = 3;

@implementation Renderer
{
    @private
    UIInterfaceOrientation _orientation;

    //render globals
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _shaderLibrary;
    id<MTLDepthStencilState> _depthState;

    //compute ivars
    id<MTLComputePipelineState> _kernal;
    MTLSize _workgroupSize;
    MTLSize _localCount;

    //textured quad
    id<MTLTexture> _outTexture;
    id<MTLRenderPipelineState> _pipelineState;

    //quad representation
    Quad *_quad;

    //app control
    dispatch_semaphore_t _inFlightSemaphore;

    //dimensions
    CGSize _size;

    //viewing matrix is derived from an eye point, a reference point
    //indicating the center of the screen, and an up vector
    simd::float4x4 _lookAt;

    //translate the object in x,y,z space
    simd::float4x4 _translate;

    //quad transform buffers
    simd::float4x4 _transform;
    id<MTLBuffer> _transformBuffer;

}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        //init properties
        _sampleCount = 1;
        _depthPixelFormat = MTLPixelFormatInvalid;
        _stencilPixelFormat = MTLPixelFormatInvalid;
        _constantDataBufferIndex = 0;

        //create a default system device
        _device = MTLCreateSystemDefaultDevice();

        if(!_device)
        {
            NSLog(@"ERROR: Failed creating a device");
            //assert here because if the default system device isn't created, then we shouldn't continue
            assert(0);
        }

        //create a new command queue
        _commandQueue = [_device newCommandQueue];
        if(!_commandQueue)
        {
            NSLog(@"ERROR: failed creating a command queue");
            assert(0);
        }

        _shaderLibrary = [_device newDefaultLibrary];
        if(!_shaderLibrary)
        {
            NSLog(@"ERROR: failed creating a default shader library");
            assert(0);
        }

        _inFlightSemaphore = dispatch_semaphore_create(IN_FLIGHT_COMMAND_BUFFERS);
    }
    return self;
}

- (void)cleanup
{
    _pipelineState = nil;
    _kernal = nil;
    _shaderLibrary = nil;
    _transformBuffer = nil;
    _depthState = nil;
    _commandQueue = nil;
    _outTexture = nil;
    _quad = nil;
}

#pragma mark Setup

- (BOOL)prepareCompute
{
    NSError *error = nil;

    //create compute kernal functiion
    id<MTLFunction> function = [_shaderLibrary newFunctionWithName:@"test"];

    if(!function)
    {
        NSLog(@"ERROR: Failed creating a new function");
        return NO;
    }

    //create a compute kernal
    _kernal = [_device newComputePipelineStateWithFunction:function error:&error];
    if(!_kernal)
    {
        NSLog(@"ERROR: Failed creating a compute kernal: %@", error);
        return  NO;
    }

    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:_size.width height:_size.height mipmapped:NO];
    if(!desc)
    {
        NSLog(@"ERROR: Failed creating a texture 2d descriptor with RGBA 8 unorm format");
        return NO;
    }

    _outTexture = [_device newTextureWithDescriptor:desc];
    if(!_outTexture)
    {
        NSLog(@"ERROR: Failed creating an output 2d texture");
        return NO;
    }

    //set the compute kernals workgroup size and count
    _workgroupSize = MTLSizeMake(1, 1, 1);
    _localCount = MTLSizeMake(_size.width, _size.height, 1);

    return YES;
}

- (BOOL)preparePipelineState
{
    //get the fragment function from the library
    id<MTLFunction> fragmentProgram = [_shaderLibrary newFunctionWithName:@"texturedQuadFragment"];
    if(!fragmentProgram)
    {
        NSLog(@"ERROR: Couldn't load fragment function from default library");
    }

    //get the vertex function
    id<MTLFunction> vertexProgram = [_shaderLibrary newFunctionWithName:@"texturedQuadVertex"];
    if(!vertexProgram)
    {
        NSLog(@"ERROR: Couldn't load vertex function from default library");
    }

    //create pipeline state for quad
    MTLRenderPipelineDescriptor *quadPipelineStateDescriptor = [MTLRenderPipelineDescriptor new];
    if(!quadPipelineStateDescriptor)
    {
        NSLog(@"ERROR: Failed creating a pipeline state descriptor");
        return NO;
    }

    quadPipelineStateDescriptor.depthAttachmentPixelFormat = _depthPixelFormat;
    quadPipelineStateDescriptor.stencilAttachmentPixelFormat = _stencilPixelFormat;
    quadPipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    quadPipelineStateDescriptor.sampleCount = _sampleCount;
    quadPipelineStateDescriptor.vertexFunction = vertexProgram;
    quadPipelineStateDescriptor.fragmentFunction = fragmentProgram;

    NSError *error = nil;

    _pipelineState = [_device newRenderPipelineStateWithDescriptor:quadPipelineStateDescriptor error:&error];
    if(!_pipelineState)
    {
        NSLog(@"ERROR: Failed acquiring pipeline state description: %@", error);
        return NO;
    }
    return YES;
}

- (BOOL)prepareDepthStencilState
{
    MTLDepthStencilDescriptor *depthStateDescriptor = [MTLDepthStencilDescriptor new];
    if(!depthStateDescriptor)
    {
        NSLog(@"ERROR: Failed creating a depth stencil descriptor");
        return NO;
    }
    depthStateDescriptor.depthCompareFunction = MTLCompareFunctionAlways;
    depthStateDescriptor.depthWriteEnabled = YES;

    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDescriptor];
    if(!_depthState)
    {
        return NO;
    }
    return YES;
}

- (BOOL)prepareTexturedQuad
{
    _quad = [[Quad alloc] initWithDevice:_device];
    if(!_quad)
    {
        NSLog(@"ERROR: Failed creating a quad object");
        return NO;
    }
    _quad.size = _size;
    return YES;
}

- (BOOL)prepareTransformBuffer
{
    //allocate regions of memory for the constant buffer
    _transformBuffer = [_device newBufferWithLength:SIZE_BUFFER_LIMITS_PER_FRAME options:0];
    if(!_transformBuffer)
    {
        NSLog(@"ERROR: Failed to create transform buffer");
        return NO;
    }
    _transformBuffer.label = @"TransformBuffer";
    return YES;
}

- (void)prepareTransforms
{
    //create a viewing matrix derived from an eye point, a reference point
    //indicating the center of the screen, and an up vector
    simd::float3 eye = {0.0, 0.0, 0.0};
    simd::float3 center = {0.0, 0.0, 1.0};
    simd::float3 up = {0.0, 1.0, 0.0};

    _lookAt = AAPL::Math::lookAt(eye, center, up);

    //translate the object in x,y,z space
    _translate = AAPL::Math::translate(0.0f, -0.25f, 2.0f);
}

- (void)configure:(MetalView *)view
{
    view.depthPielFormat = _depthPixelFormat;
    view.stencilPixelFormat = _stencilPixelFormat;
    view.sampleCount = _sampleCount;

    //we need to set the framebuffer only property of the layer to No so we
    //can perform compute on the drawables texture.

    CAMetalLayer *metalLayer = (CAMetalLayer *)view.layer;
    metalLayer.framebufferOnly = NO;

    int w = [UIScreen mainScreen].bounds.size.width;
    float scale = [UIScreen mainScreen].scale;
    int ww = w * scale;
    int h = [UIScreen mainScreen].bounds.size.height;
    int hh = h * scale;
    _size.width = ww;//[UIScreen mainScreen].nativeBounds.size.width;
    _size.height = hh;//[UIScreen mainScreen].nativeBounds.size.height;

    if(![self preparePipelineState])
    {
        NSLog(@"ERROR: Failed creating a pipeline state");
        assert(0);
    }

    if(![self prepareTexturedQuad])
    {
        NSLog(@"ERROR: Failed creating a textured quad");
        assert(0);
    }

    if(![self prepareCompute])
    {
        NSLog(@"ERROR: Failed creating a compute stage");
        assert(0);
    }

    //prepare stencil

    //prepare transform buffers

    _orientation = UIInterfaceOrientationUnknown;

    //prepare transforms
}

#pragma mark render

- (void)compute:(id<MTLCommandBuffer>)commandBuffer
{
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    if(computeEncoder)
    {
        [computeEncoder setComputePipelineState:_kernal];
        [computeEncoder setTexture:_outTexture atIndex:0];
        [computeEncoder setTexture:_outTexture atIndex:1];
        MTLSize threadsPerGroup = {16, 16, 1};
        MTLSize numThreadGroups = {_outTexture.width/threadsPerGroup.width,
            _outTexture.height/threadsPerGroup.height, 1};
//        [computeEncoder dispatchThreadgroups:_localCount threadsPerThreadgroup:_workgroupSize];
        [computeEncoder dispatchThreadgroups:numThreadGroups threadsPerThreadgroup:threadsPerGroup];
        [computeEncoder endEncoding];
    }
}

- (void)encode:(id<MTLRenderCommandEncoder>)renderEncoder
{
    //set context state with the render encoder
    [renderEncoder pushDebugGroup:@"encode quad"];
    {
        [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
//        [renderEncoder setDepthStencilState:_depthState];
        [renderEncoder setRenderPipelineState:_pipelineState];
        //set transform buffer

        //
        [renderEncoder setFragmentTexture:_outTexture atIndex:0];

        //encode quad vertex and yexture coordinate buffers
        [_quad encode:renderEncoder];

        //tell render context we want to draw our primatives
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];

        [renderEncoder endEncoding];
        
    }
    [renderEncoder popDebugGroup];
}

- (void)reshape:(MetalView *)view
{
    //to correctly compute the aspect ratio determine the device intercase orientation
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;

    //update the quad and linear transformation matrices, if and only if, the device orientation is changed
    if(_orientation != orientation)
    {
        _orientation = orientation;

        //get the bounds for the current rendering layer
        _quad.bounds = view.layer.frame;

        //TODO: 3d stuff
    }
}

- (void)render:(MetalView *)view
{
    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

    //compute
    [self compute:commandBuffer];

    //create a render command encoder so we can render into something
    MTLRenderPassDescriptor *renderPassDescriptor = view.renderPassDescriptor;

    if(renderPassDescriptor)
    {
        //get a render encoder
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

        //render textured quad
        [self encode:renderEncoder];

        //dispatch the command buffer
        __block dispatch_semaphore_t dispatchSemaphore = _inFlightSemaphore;

        [commandBuffer addCompletedHandler:
         ^(id<MTLCommandBuffer> cmdb)
         {
             dispatch_semaphore_signal(dispatchSemaphore);
         }];

        //present and commit the command buffer
        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];
    }
}

//this method is called from the thread the main game loop is run
- (void)update:(MetalViewController *)controller
{
    //not used
}

//called whenever the main game loop is paused, such as when the app is backgrounded
- (void)viewController:(MetalViewController *)controller willPause:(BOOL)pause
{
    //not used
}

@end






























