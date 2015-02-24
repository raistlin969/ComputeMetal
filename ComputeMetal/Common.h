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
    uint32_t iteration;
    uint32_t maxIteration;
    uint32_t iterationStep;
} MandelData;

typedef struct
{
    float4 out1 [[color(0)]];
//    float2 out2 [[color(1)]];
} FragOutput;

struct MandelNode
{
    uint x;
    uint y;
    uint2 size;
    uint iterations;
//    MandelNode *nw;
//    MandelNode *ne;
//    MandelNode *sw;
//    MandelNode *se;

    MandelNode()
    {
        x = 0;
        y = 0;
        size = 0;
        iterations = 0;
//        nw = 0;
//        ne = 0;
//        sw = 0;
//        se = 0;
    }
};

#endif

#endif