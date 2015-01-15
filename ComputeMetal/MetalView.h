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

@interface MetalView : UIView

@property(nonatomic, strong) CAMetalLayer *metalLayer;

@end
