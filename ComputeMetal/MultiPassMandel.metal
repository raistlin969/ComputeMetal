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

fragment float4 passFirstFragment(VertexInOut inFrag [[stage_in]], constant MandelData *data [[buffer(0)]])
{
    float2 pan = data[0].pan;
    float zoom = data[0].zoom;
    float aspect = data[0].aspect;

    float2 c = (inFrag._texCoord - 0.5) * zoom * float2(1, aspect) - pan;

    return float4(c, 0.0, 0.0);
}

fragment float4 passMultiFragment(VertexInOut inFrag [[stage_in]], texture2d<float> previous [[texture(0)]])
{
    constexpr sampler quad_sampler;

    float4 input = previous.sample(quad_sampler, inFrag._texCoord);
    float4 out;

    float2 z = input.xy;
    float2 c = inFrag._texCoord;

    if(dot(z, z) > 4.0) //leave unchanged, but copy through
        out = input;
    else
    {
        out.xy = float2(z.x * z.x - z.y*z.y, 2.0*z.x*z.y) + c;
        out.z = input.z + 1.0;
        out.w = 0.0;
    }
    return out;
}

fragment float4 passFinal(VertexInOut inFrag [[stage_in]], constant float4 *newColor [[buffer(0)]], texture2d<float> previous [[texture(0)]])
{
    float4 color = float4(0.0, 0.0, 0.0, 1.0);
    constexpr sampler quad_sampler;

    float4 input = previous.sample(quad_sampler, inFrag._texCoord);
    float2 z = input.xy;

    if(dot(z, z) > 4.0)
        color = newColor[0];

    return color;
}













