//
//  Renderer.h
//  ComputeMetal
//
//  Created by Michael Davidson on 1/15/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

@interface Renderer : NSObject

@property(nonatomic, copy) NSString *vertexFunctionName;
@property(nonatomic, copy) NSString *fragmentFunctionName;

-(instancetype)initWithLayer:(CAMetalLayer *)metalLayer;

-(id<MTLBuffer>)newBufferWithBytes:(const void *)bytes length:(NSUInteger)length;

-(void)startFrame;
-(void)endFrame;

@end
