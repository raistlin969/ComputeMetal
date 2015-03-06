//
//  MetalView.m
//  ComputeMetal
//
//  Created by Michael Davidson on 1/15/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import "MetalView.h"

@implementation MetalView
{
@private
    __weak CAMetalLayer *_metalLayer;
    BOOL _layerSizeDidUpdate;
    id<MTLTexture> _depthTex;
    id<MTLTexture> _stencilTex;
    id<MTLTexture> _msaaTex;
}

@synthesize currentDrawable = _currentDrawable;
@synthesize renderPassDescriptor = _renderPassDescriptor;

+(Class)layerClass
{
    return [CAMetalLayer class];
}

- (CGSize)metalLayerDrawableSize
{
    return _metalLayer.drawableSize;
}

- (void)initCommon
{
    self.opaque = YES;
    self.backgroundColor = nil;
    self.changeColors = NO;
    self.panNeeded = NO;
    self.zoomNeeded = NO;
    self.panX = 0.5;
    self.panY = 0.0;
    self.zoom = 3.0;
    
    _metalLayer = (CAMetalLayer *)self.layer;
    
    _device = MTLCreateSystemDefaultDevice();
    _metalLayer.device = _device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    //this is the default, but if we want to perform compute on final redering, set to no
    _metalLayer.framebufferOnly = YES;
}

- (void)didMoveToWindow
{
    self.contentScaleFactor = [UIScreen mainScreen].scale;
    UIScreen *mainScreen = [UIScreen mainScreen];
    NSLog(@"Screen bounds: %@, Screen resolution: %@, scale: %f, nativeScale: %f",
          NSStringFromCGRect(mainScreen.bounds), mainScreen.coordinateSpace, mainScreen.scale, mainScreen.nativeScale);
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if(self = [super initWithCoder:aDecoder])
    {
        [self initCommon];
    }
    return self;
}

- (void)releaseTextures
{
    _depthTex = nil;
    _stencilTex = nil;
    _msaaTex = nil;
}

- (void)setupRenderPassDescriptorForTexture:(id<MTLTexture>)texture
{
    if(_renderPassDescriptor == nil)
        _renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];

    //create a color attachment every frame since we have to recreate the texture every frame
    MTLRenderPassColorAttachmentDescriptor *colorAttachment = _renderPassDescriptor.colorAttachments[0];
    colorAttachment.texture = texture;
    
    //clear every frame
    colorAttachment.loadAction = MTLLoadActionClear;
    colorAttachment.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    //if sample count is > 1 then render into msaa
    if(_sampleCount > 1)
    {
        BOOL doUpdate = (_msaaTex.width != texture.width) || (_msaaTex.height != texture.height) ||
        (_msaaTex.sampleCount != texture.sampleCount);
        
        if(!_msaaTex || (_msaaTex && doUpdate))
        {
            MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:texture.width height:texture.height mipmapped:NO];
            
            desc.textureType = MTLTextureType2DMultisample;
            
            //sample count was specified to the view by the renderer
            //this must match the sample count given to any pipeline state using this render pass desc
            desc.sampleCount = _sampleCount;
            
            _msaaTex = [_device newTextureWithDescriptor:desc];
        }
        
        //when multisampling. perform rendering to _msaaTex, then resolve
        //to 'texture' at the end of the scene
        colorAttachment.texture = _msaaTex;
        colorAttachment.resolveTexture = texture;
        
        //set store action to resolve in this case
        colorAttachment.storeAction = MTLStoreActionMultisampleResolve;
    }
    else
    {
        //store only attachments that will be rendered to the screen, as is this case
        colorAttachment.storeAction = MTLStoreActionStore;
    }//color 0
    
    //now create depth and stencil
    if(_depthPielFormat != MTLPixelFormatInvalid)
    {
        BOOL doUpdate = (_depthTex.width != texture.width) || (_depthTex.height != texture.height) ||
        (_depthTex.sampleCount != texture.sampleCount);
        
        if(!_depthTex || doUpdate)
        {
            //if we need a depth texture and dont have one or if the one we have is the wrong size
            MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:_depthPielFormat width:texture.width height:texture.height mipmapped:NO];
            
            desc.textureType = (_sampleCount > 1) ? MTLTextureType2DMultisample : MTLTextureType2D;
            desc.sampleCount = _sampleCount;
            
            _depthTex = [_device newTextureWithDescriptor:desc];
            
            MTLRenderPassDepthAttachmentDescriptor * depthAttachment = _renderPassDescriptor.depthAttachment;
            depthAttachment.texture = _depthTex;
            depthAttachment.loadAction = MTLLoadActionClear;
            depthAttachment.storeAction = MTLStoreActionDontCare;
            depthAttachment.clearDepth = 1.0;
        }
    }//depth
    
    if(_stencilPixelFormat != MTLPixelFormatInvalid)
    {
        BOOL doUpdate = (_stencilTex.width != texture.width) || (_stencilTex.height != texture.height)
        || (_stencilTex.sampleCount != texture.sampleCount);
        
        if(!_stencilTex || doUpdate)
        {
            MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:_stencilPixelFormat width:texture.width height:texture.height mipmapped:NO];
            
            desc.textureType = (_sampleCount > 1) ? MTLTextureType2DMultisample : MTLTextureType2D;
            desc.sampleCount = _sampleCount;
            
            _stencilTex = [_device newTextureWithDescriptor:desc];
            
            MTLRenderPassStencilAttachmentDescriptor *stencilAttachment = _renderPassDescriptor.stencilAttachment;
            stencilAttachment.texture = _stencilTex;
            stencilAttachment.loadAction = MTLLoadActionClear;
            stencilAttachment.storeAction = MTLStoreActionDontCare;
            stencilAttachment.clearStencil = 0;
        }
    }
}

- (MTLRenderPassDescriptor *)renderPassDescriptor
{
    id<CAMetalDrawable> drawable = self.currentDrawable;
    if(!drawable)
    {
        NSLog(@"ERROR: Failed to get a drawable");
        _renderPassDescriptor = nil;
    }
    else
    {
        [self setupRenderPassDescriptorForTexture:drawable.texture];
    }
    return _renderPassDescriptor;
}

- (id<CAMetalDrawable>)currentDrawable
{
    if(_currentDrawable == nil)
        _currentDrawable = [_metalLayer nextDrawable];
    return _currentDrawable;
}

- (void)display
{
    //create autorelease pool per frame to avoid possible deadlock situations
    //because there are 3 CAMetalDrawables sitting in an autorelease pool
    
    @autoreleasepool
    {
        //handle display changes here
        if(_layerSizeDidUpdate)
        {
            //set metal layer to drawable size incase orientation or size changes
            CGSize drawableSize = self.bounds.size;
            drawableSize.width *= self.contentScaleFactor;
            drawableSize.height *= self.contentScaleFactor;
            
            _metalLayer.drawableSize = drawableSize;
            
            //renderer delegate method so renderer can resize anything if needed
            //[_metalViewDelegate reshape:self];
            
            _layerSizeDidUpdate = NO;
        }
        
        //rendering delegate method to ask renderer to draw this frame
        [self.metalViewDelegate render:self];
        
        //do not retain current drawable beyond the frame
        _currentDrawable = nil;
    }
}

- (void)setContentScaleFactor:(CGFloat)contentScaleFactor
{
    [super setContentScaleFactor:contentScaleFactor];
    _layerSizeDidUpdate = YES;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _layerSizeDidUpdate = YES;
}

@end


























