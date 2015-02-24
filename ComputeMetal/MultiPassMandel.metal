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

fragment float4 borderFragment(VertexInOut inFrag [[stage_in]],
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
                          texture2d<uint> previous [[texture(0)]],
                          float4 pos [[position]])
{
    float4 color = float4(0.0, 0.0, 0.0, 1.0);
    constexpr sampler quad_sampler;

    uint4 p = uint4(pos);
    uint input = previous.read(p.xy).x;// previous.sample(quad_sampler, inFrag._texCoord);

    if(input < 256)
        color.r = float(input)/255.0;
    return color;
}

kernel void mandelKernel(texture2d<float, access::read> inTexture [[texture(0)]],
                         texture2d<uint, access::write> outTexture [[texture(1)]],
                         constant MandelNode *nodes [[buffer(0)]],
                         uint2 tptg [[thread_position_in_threadgroup]],
                         uint2 gid [[thread_position_in_grid]])
{
    float4 input = inTexture.read(gid);
    float2 z = input.xy;
    float2 c = input.xy;
    uint32_t i = 0;
//    for(i = 0; i <= 256; i++)
//    {
//        if(dot(z, z) > 4.0) //leave unchanged, but copy through
//        {
//            break;
//        }
//        else
//        {
//            z = float2(z.x * z.x - z.y*z.y, 2.0*z.x*z.y) + c;
//        }
//    }
    if(gid.x == nodes[0].x || gid.x == nodes[1].x || gid.x == nodes[2].x || gid.x == nodes[3].x ||
       gid.x == nodes[0].x + nodes[0].size.x - 1 ||
       gid.x == nodes[1].x + nodes[1].size.x - 1 ||
       gid.x == nodes[2].x + nodes[2].size.x - 1 ||
       gid.x == nodes[3].x + nodes[3].size.x - 1 ||
       gid.y == nodes[0].y || gid.y == nodes[1].y || gid.y == nodes[2].y || gid.y == nodes[3].y ||
       gid.y == nodes[0].y + nodes[0].size.y - 1 ||
       gid.y == nodes[1].y + nodes[1].size.y - 1 ||
       gid.y == nodes[2].y + nodes[2].size.y - 1 ||
       gid.y == nodes[3].y + nodes[3].size.y - 1)
        i = 255;
    outTexture.write(i, gid);
}

kernel void test(texture2d<float, access::write> outTexture [[texture(0)]],
                 uint2 gid [[thread_position_in_grid]],
                 uint2 tpgr [[threads_per_threadgroup]],
                 uint2 tptg [[thread_position_in_threadgroup]],
                 uint2 tgpg [[threadgroup_position_in_grid]])
{
    float r = 0.0;
    float g = 0.0;
    float b = 0.0;
    if(tptg.x == 0 || tptg.y == 0)
        r = 1.0;
    if(gid.x == 0 || gid.x == 1022 || gid.y == 0 || gid.y == 1022)
        g = 1.0;
//    if(tgpg.x == 63 || tgpg.y == 63)
//        b = 1.0;
    float4 color = float4(r, g, b, 1.0);
    outTexture.write(color, gid);
}









