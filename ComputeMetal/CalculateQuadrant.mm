//
//  CalculateQuadrant.m
//  ComputeMetal
//
//  Created by Michael Davidson on 3/27/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import "CalculateQuadrant.h"

@implementation CalculateQuadrant
{
    __weak id<MTLTexture> _texture;
    MTLRegion _region;
}

-(instancetype)initWithTexture:(id<MTLTexture>)texture Region:(MTLRegion)region
{
    self = [super init];
    if(self)
    {
        _texture = texture;
        _region = region;
    }
    return self;
}

@end
