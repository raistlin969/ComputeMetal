//
//  MetalView.h
//  ComputeMetal
//
//  Created by Michael Davidson on 1/15/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

@protocol MetalViewDelegate;


@interface MetalView : UIView

@property(nonatomic, weak) IBOutlet id<MetalViewDelegate> metalViewDelegate;

//view has handle to the metal device when created
@property(nonatomic, strong, readonly) id<MTLDevice> device;

//the current drawable within the views CAMetalLayer
@property(nonatomic, strong, readonly) id<CAMetalDrawable> currentDrawable;

//the current framebuffer can be read by delegate during -[MetalViewDelegate render:]
//this call may block until the framebuffer is available
@property(nonatomic, strong, readonly) MTLRenderPassDescriptor *renderPassDescriptor;

//set these pixel formats to have the main drawable framebuffer get created with depth and/or stencil attachments
@property(nonatomic) MTLPixelFormat depthPielFormat;
@property(nonatomic) MTLPixelFormat stencilPixelFormat;
@property(nonatomic) NSUInteger sampleCount;

//view controller will call off main thread
-(void)display;

//release any color/depth/stencil resources. view controller will call when paused
-(void)releaseTextures;

@end

//rendering delegate
@protocol MetalViewDelegate <NSObject>

@required
//called if the view changes orientation or size, renderer can precompute its matricies here
- (void)reshape:(MetalView *)view;

//delegate should perform all rendering here
- (void)render:(MetalView *)view;

@end
