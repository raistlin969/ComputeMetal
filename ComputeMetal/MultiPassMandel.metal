//
//  MultiPassMandel.metal
//  ComputeMetal
//
//  Created by Michael Davidson on 1/30/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#include <metal_stdlib>
#include "Common.h"

using namespace metal;


struct VertexInOut
{
    float4 _position [[position]];
    float2 _texCoord [[user(texturecoord)]];
};

vertex VertexInOut passThroughVertex(constant float4 *position [[buffer(0)]],
                                      constant float2 *texCoords [[buffer(1)]],
                                      uint vid [[vertex_id]])
{
    VertexInOut out;
    out._position = position[vid];
    out._texCoord = texCoords[vid];
    return out;
}

fragment float4 generateZFragment(VertexInOut inFrag [[stage_in]], constant MandelData *data [[buffer(0)]])
{
    float2 pan = data[0].pan;
    float zoom = data[0].zoom;
    float aspect = data[0].aspect;

    float2 c = (inFrag._texCoord - 0.5) * zoom * float2(1, aspect) - pan;

    return float4(c, 0.0, 0.0);
}

fragment float4 lowResolutionFragment(VertexInOut inFrag [[stage_in]],
                                      constant MandelData *data [[buffer(0)]])
{
    float2 pan = data[0].pan;
    float zoom = data[0].zoom;
    float aspect = data[0].aspect;

    float2 z = (inFrag._texCoord - 0.5) * zoom * float2(1, aspect) - pan;
    float2 c = z;

    float4 out = float4(0.0, 0.0, 0.0, 0.0);

    for(uint32_t i = 0; i < 256; i++)
    {
        z = out.xy;
        if(dot(z, z) > 4.0) //leave unchanged, but copy through
        {
            break;
        }
        else
        {
            out.xy = float2(z.x * z.x - z.y*z.y, 2.0*z.x*z.y) + c;
            out.z = out.z + 1.0;
            out.w = 0.0;
        }
    }
    return out;
}

fragment float4 highResolutionFragment(VertexInOut inFrag [[stage_in]],
                                      constant MandelData *data [[buffer(0)]],
                                       float4 previous [[color(0)]])
{
    float2 pan = data[0].pan;
    float zoom = data[0].zoom;
    float aspect = data[0].aspect;

    float2 c = (inFrag._texCoord - 0.5) * zoom * float2(1, aspect) - pan;
    float2 z = previous.xy;

    float4 out = float4(0.0, 0.0, 0.0, 0.0);

    if(dot(z, z) > 4.0) //leave unchanged, but copy through
    {
        out = previous;
    }
    else
    {
        out.xy = float2(z.x * z.x - z.y*z.y, 2.0*z.x*z.y) + c;
        out.z = previous.z + 1.0;
        out.w = 0.0;
    }
    return out;
}

fragment FragOutput passFirstFragment(VertexInOut inFrag [[stage_in]], constant MandelData *data [[buffer(0)]])
{
    float2 pan = data[0].pan;
    float zoom = data[0].zoom;
    float aspect = data[0].aspect;

    FragOutput out;

    float2 c = (inFrag._texCoord - 0.5) * zoom * float2(1, aspect) - pan;
    //float2 c = inFrag._texCoord - 0.5;
    out.out1 = float4(c, c);
    //out.out2 = c;
    return out;
}

fragment FragOutput passMultiFragment(VertexInOut inFrag [[stage_in]],
                                      constant MandelData *data [[buffer(0)]],
                                      texture2d<float> previous [[texture(0)]],
                                      FragOutput last)
{
    constexpr sampler quad_sampler;

    float2 pan = data[0].pan;
    float zoom = data[0].zoom;
    float aspect = data[0].aspect;

    //float4 input = previous.sample(quad_sampler, inFrag._texCoord);
    //float4 out;
    float4 input = last.out1;

    float2 z = input.xy;
    float2 c = (inFrag._texCoord - 0.5) * zoom * float2(1, aspect) - pan;
    //float2 c = (inFrag._texCoord - 0.5) * zoom * float2(1, aspect) - pan;
    //float2 c = inFrag._texCoord - 0.5;

    FragOutput test;
    test = last;

//    float q = ((c.x - 0.25) * (c.x - 0.25)) + (c.y*c.y);
//    float qq = q * (q + (c.x - 0.25));
//    if(qq < 0.25 * (c.y*c.y))
//        return test;
//
//    if(((c.x + 1.0) * (c.x + 1.0)) + (c.y*c.y) < 1.0/16.0)
//        return test;

    for(uint32_t i = 0; i < data[0].iterationStep; i++)
    {
        z = test.out1.xy;
        if(dot(z, z) > 4.0) //leave unchanged, but copy through
        {
            //test.out1 = input;
            break;
        }
        else
        {
            test.out1.xy = float2(z.x * z.x - z.y*z.y, 2.0*z.x*z.y) + c;
            test.out1.z = test.out1.z + 1.0;
            test.out1.w = 0.0;
        }
    }
    return test;
}

fragment float4 passFinal(VertexInOut inFrag [[stage_in]],
                          constant float4 *newColor [[buffer(0)]],
                          texture2d<float> previous [[texture(0)]])
{
    float4 color = float4(0.0, 0.0, 0.0, 1.0);
    constexpr sampler quad_sampler;

    float4 input = previous.sample(quad_sampler, inFrag._texCoord);
    float2 z = input.xy;
//    color = input;
    //float4 input = last.out1;
    //float2 z = input.xy;

    if(dot(z, z) > 4.0)
    {
        color.r = input.z / 255.0;
        //color.g = 0.6;
    }
    return color;
}

kernel void mandelKernel(texture2d<float, access::read> inTexture [[texture(0)]],
                         texture2d<float, access::write> outTexture [[texture(1)]],
                         uint2 gid [[thread_position_in_grid]])
{
    float4 input = inTexture.read(gid);
    float2 z = input.xy;
    float2 c = input.zw;
    float2 out = float2(0.0, 0.0);
    float it = 0.0;
    float4 color = float4(0.0, 0.0, 0.0, 1.0);
    for(uint32_t i = 0; i < 256; i++)
    {
        if(dot(z, z) > 4.0) //leave unchanged, but copy through
        {
            color.r = i / 255.0;
            break;
        }
        else
        {
            z = float2(z.x * z.x - z.y*z.y, 2.0*z.x*z.y) + c;
        }
        it = (float)i;
    }
    outTexture.write(color, gid);
}











