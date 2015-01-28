//
//  Common.h
//  ComputeMetal
//
//  Created by Michael Davidson on 1/26/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#ifndef ComputeMetal_Common_h
#define ComputeMetal_Common_h

#import <simd/simd.h>

#ifdef __cplusplus

using namespace simd;

typedef struct
{
    float2 pan;
    float zoom;
    float aspect;
} MandelData;

typedef struct
{
    float4 out1 [[color(0)]];
    float2 out2 [[color(1)]];
} FragOutput;

#endif

#endif