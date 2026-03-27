Shader "Hidden/MoebiusOutline"
{
    Properties
    {
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)
        _OutlineThickness ("Outline Thickness", Float) = 1.0
        _DepthThreshold ("Depth Threshold", Float) = 0.01
        _NormalThreshold ("Normal Threshold", Float) = 0.5
        _NoiseTex ("Noise Texture", 2D) = "gray" {}
        _WiggleStrength ("Wiggle Strength", Float) = 0.005
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100
        ZWrite Off Cull Off ZTest Always

        Pass
        {
            Name "MoebiusOutline"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _OutlineColor;
                float _OutlineThickness;
                float _DepthThreshold;
                float _NormalThreshold;
                float _WiggleStrength;
            CBUFFER_END

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            float4 Frag(Varyings input) : SV_Target
            {
                float2 baseUV = input.texcoord;
                
                // Wiggle UV sampling slightly over time for the OUTLINES ONLY
                float2 wiggleNoise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, baseUV * 5.0 + _Time.y * 0.5).rg;
                float2 wiggledUV = baseUV + (wiggleNoise - 0.5) * _WiggleStrength;

                float2 texelSize = float2(1.0 / _ScreenParams.x, 1.0 / _ScreenParams.y) * _OutlineThickness;

                // 3x3 Sobel matrix offsets
                float2 offset[9] = {
                    float2(-1, 1), float2(0, 1), float2(1, 1),
                    float2(-1, 0), float2(0, 0), float2(1, 0),
                    float2(-1,-1), float2(0,-1), float2(1,-1)
                };

                float depthX = 0; float depthY = 0;
                float3 normalX = 0; float3 normalY = 0;

                float kernelX[9] = {1, 0, -1, 2, 0, -2, 1, 0, -1};
                float kernelY[9] = {1, 2, 1, 0, 0, 0, -1, -2, -1};

                for(int i=0; i<9; i++)
                {
                    // Using wiggledUV here so the edge detection shakes, but nothing else
                    float2 sampleUV = wiggledUV + offset[i] * texelSize;
                    float depth = SampleSceneDepth(sampleUV);
                    float3 normal = SampleSceneNormals(sampleUV);

                    depthX += depth * kernelX[i];
                    depthY += depth * kernelY[i];

                    normalX += normal * kernelX[i];
                    normalY += normal * kernelY[i];
                }

                float depthEdge = sqrt(depthX * depthX + depthY * depthY);
                float normalEdge = sqrt(dot(normalX, normalX) + dot(normalY, normalY));

                // Combine edges based on defined thresholds
                float edge = step(_DepthThreshold, depthEdge) + step(_NormalThreshold, normalEdge);
                edge = saturate(edge);

                // Sample the base scene rendering using the perfectly stable baseUV
                float4 sourceColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, baseUV);

                // Removed Film Grain! We now just lerp directly from the clean scene color to the outline.
                return lerp(sourceColor, _OutlineColor, edge);
            }
            ENDHLSL
        }
    }
}