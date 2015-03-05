//
//  QuadNode.h
//  ComputeMetal
//
//  Created by Michael Davidson on 3/2/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "Common.h"

@interface QuadNode : NSObject

@property(nonatomic) MandelNode mandelNode;
@property(strong, nonatomic) QuadNode *nw;
@property(strong, nonatomic) QuadNode *ne;
@property(strong, nonatomic) QuadNode *sw;
@property(strong, nonatomic) QuadNode *se;


-(void)subdivideTexture:(id<MTLTexture>)c currentDepth:(int)depth;
-(void)createBufferSize:(int)size;
-(void)destroyBuffer;
-(instancetype)initWithSize:(uint2)size atX:(uint)x Y:(uint)y;

@end