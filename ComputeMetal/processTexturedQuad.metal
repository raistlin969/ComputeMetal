//
//  processTexturedQuad.metal
//  ComputeMetal
//
//  Created by Michael Davidson on 1/20/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#include <metal_stdlib>
#include <metal_texture>

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
                                     texture2d<float> tex2D [[texture(0)]])
{
    constexpr sampler quad_sampler;

    float4 color = tex2D.sample(quad_sampler, inFrag._texCoord);

    return color;
}

kernel void test(texture2d<float, access::read> inTexture [[texture(0)]],
                 texture2d<float, access::write> outTexture [[texture(1)]],
                 uint2 gid [[thread_position_in_grid]])
{
    float4 color = float4(1.0, 0.0, 0.0, 1.0);
    outTexture.write(color, gid);
}