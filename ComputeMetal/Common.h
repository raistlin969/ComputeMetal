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


#endif

#endif