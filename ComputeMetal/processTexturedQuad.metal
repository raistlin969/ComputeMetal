//
//  processTexturedQuad.metal
//  ComputeMetal
//
//  Created by Michael Davidson on 1/20/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#include <metal_stdlib>
#include <metal_texture>
#include <metal_geometric>

using namespace metal;

struct VertexInOut
{
    float4 _position [[position]];
    float2 _texCoord [[user(texturecoord)]];
};

vertex VertexInOut texturedQuadVertex(constant float4 *position [[buffer(0)]],
                                      constant packed_float2 *texCoords [[buffer(1)]],
                                      uint vid [[vertex_id]])
{
    VertexInOut out;
    out._position = position[vid];
    out._texCoord = texCoords[vid];
    return out;
}

fragment float4 texturedQuadFragment(VertexInOut inFrag [[stage_in]],
                                     texture2d<float> tex2D [[texture(0)]],
                                     constant float4 *newColor [[buffer(0)]],
                                     float4 pos [[position]])
{
    constexpr sampler quad_sampler;

    float4 color = float4(0.0, 0.0, 0.0, 1.0);
    float2 z = inFrag._texCoord;
    z *= float2(3.0, 2.0);
    z -= float2(2.0, 1.0);

    float2 c = z;
    uint it = 0;
    for(int i = 0; i < 256; i++)
    {
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
        z += c;

        if(dot(z,z) > 4.0)
            break;

        it++;
    }

    if(it < 256)
        color = newColor[0];

    //float4 color = tex2D.sample(quad_sampler, inFrag._texCoord);
    return color;
}

kernel void test(texture2d<float, access::write> outTexture [[texture(0)]],
                 uint2 gid [[thread_position_in_grid]],
                 uint2 tpgr [[threads_per_threadgroup]],
                 uint2 tptg [[thread_position_in_threadgroup]])
{
    float r = tptg.x / (float)tpgr.x;
    float g = tptg.y / (float)tpgr.y;
    float4 color = float4(r, g, 0.0, 1.0);
    outTexture.write(color, gid);
}