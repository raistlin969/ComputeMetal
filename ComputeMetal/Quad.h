//
//  Quad.h
//  ComputeMetal
//
//  Created by Michael Davidson on 1/18/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>

@interface Quad : NSObject

//indices
@property(nonatomic, readwrite) NSUInteger vertexIndex;
@property(nonatomic, readwrite) NSUInteger texCoordIndex;
@property(nonatomic, readwrite) NSUInteger samplerIndex;

//dimensions
@property(nonatomic, readwrite) CGSize size;
@property(nonatomic, readwrite) CGRect bounds;
@property(nonatomic, readonly) float aspect;

//designated initi
- (instancetype)initWithDevice:(id<MTLDevice>)device;

//encoder
- (void)encode:(id<MTLRenderCommandEncoder>)renderEncoder;


@end
