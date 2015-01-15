//
//  MetalView.m
//  ComputeMetal
//
//  Created by Michael Davidson on 1/15/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import "MetalView.h"

@implementation MetalView

+(Class)layerClass
{
    return [CAMetalLayer class];
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if(self = [super initWithCoder:aDecoder])
    {
        _metalLayer = (CAMetalLayer *)[self layer];
    }
    return self;
}

@end
