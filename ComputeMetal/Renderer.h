//
//  Renderer.h
//  ComputeMetal
//
//  Created by Michael Davidson on 1/15/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import "MetalView.h"
#import "MetalViewController.h"
#import <Metal/Metal.h>

@interface Renderer : NSObject <MetalViewControllerDelegate, MetalViewDelegate>

//renderer wil create a default device at init time
@property (nonatomic, strong, readonly) id<MTLDevice> device;

//this value will cycle from 0 to g_max_inflight_buffers whenever a display completes renderer clients
//can sync between g_max_inflight_buffers count buffers, and thus avoiding a constant buffer from
//being overwritten between draws
@property(nonatomic, readonly) NSUInteger constantDataBufferIndex;

//these queries exist so the View can initialize a framebuffer that matches the expectations of the renderer
@property(nonatomic, readonly) MTLPixelFormat depthPixelFormat;
@property(nonatomic, readonly) MTLPixelFormat stencilPixelFormat;
@property(nonatomic, readonly) NSUInteger sampleCount;

//load all assets before triggering rendering
- (void)configure:(MetalView *)view;

- (void)cleanup;

-(id<MTLBuffer>)newBufferWithBytes:(const void *)bytes length:(NSUInteger)length;

@end
