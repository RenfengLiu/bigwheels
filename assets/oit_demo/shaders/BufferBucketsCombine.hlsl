// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#define IS_SHADER
#include "Common.hlsli"
#include "FullscreenVS.hlsli"

RWTexture2D<uint>  CountTexture    : register(CUSTOM_UAV_0_REGISTER);
RWTexture2D<uint2> FragmentTexture : register(CUSTOM_UAV_1_REGISTER);

float4 psmain(VSOutput input) : SV_TARGET
{
    const uint2 bucketIndex   = (uint2)input.position.xy;
    const int fragmentCount   = min(min((int)CountTexture[bucketIndex], g_Globals.bufferBucketsFragmentsMaxCount), BUFFER_BUCKETS_SIZE_PER_PIXEL);
    CountTexture[bucketIndex] = 0U; // Reset fragment count for the next frame

    uint2 sortedFragments[BUFFER_BUCKETS_SIZE_PER_PIXEL];

    // Copy the fragments into local memory for sorting
    {
        uint2 fragmentIndex = bucketIndex;
        fragmentIndex.y *= BUFFER_BUCKETS_SIZE_PER_PIXEL;
        for(int i = 0; i < fragmentCount; ++i)
        {
            sortedFragments[i] = FragmentTexture[fragmentIndex];
            fragmentIndex.y += 1U;
        }
    }

    if(fragmentCount <= 0)
    {
        return (float4)0.0f;
    }

    // Sort the fragments by depth (back to front)
    {
        for(int i = 0; i < fragmentCount - 1; ++i)
        {
            for(int j = i + 1; j < fragmentCount; ++j)
            {
                if(sortedFragments[j].y > sortedFragments[i].y)
                {
                    const uint2 tmp  = sortedFragments[i];
                    sortedFragments[i] = sortedFragments[j];
                    sortedFragments[j] = tmp;
                }
            }
        }
    }

    // Merge the fragments to get the final color
    float4 color = float4(0.0f, 0.0f, 0.0f, 1.0f);
    for(int i = 0; i < fragmentCount; ++i)
    {
        MergeColor(color, UnpackColor(sortedFragments[i].x));
    }
    color.a = 1.0f - color.a;
    return color;
}
