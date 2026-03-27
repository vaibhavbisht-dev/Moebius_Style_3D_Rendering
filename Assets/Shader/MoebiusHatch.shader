Shader "Hidden/MoebiusHatch"
{
    Properties
    {
        _HatchTex("Cross-Hatch Texture (RGB: Horiz/Vert/Diag)", 2D) = "white" {}
        _HatchTiling("Hatch Tiling", Float) = 50.0 
        _HatchIntensity("Hatch Darkness", Range(0, 1)) = 0.6 // NEW: Controls how dark the lines are
        _SpecularThreshold("Specular Threshold", Range(0,1)) = 0.95
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100
        ZWrite Off Cull Off ZTest Always

        Pass
        {
            Name "MoebiusHatchPostProcess"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _HatchTiling;
                float _HatchIntensity; // NEW
                float _SpecularThreshold;
            CBUFFER_END

            TEXTURE2D(_HatchTex);
            SAMPLER(sampler_HatchTex);

            float4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;
                
                // Sample the base scene rendering
                float4 sourceColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);

                // Sample depth to ignore the skybox
                float depth = SampleSceneDepth(uv);
                if (depth <= 0.00001) return sourceColor;

                // Sample scene normal to reconstruct lighting
                float3 normalWS = SampleSceneNormals(uv);
                
                float3 lightDir = _MainLightPosition.xyz; 
                float NdotL = saturate(dot(normalWS, lightDir));

                // Screen-space UV mapping for the hatching lines
                float2 screenUV = uv;
                screenUV.x *= _ScreenParams.x / _ScreenParams.y; 
                screenUV *= _HatchTiling;

                // Sample hatching texture
                float3 hatch = SAMPLE_TEXTURE2D(_HatchTex, sampler_HatchTex, screenUV).rgb;

                // Draw hatch lines progressively based on shadow depths
                float shading = 1.0;
                if (NdotL < 0.75) shading *= hatch.r;
                if (NdotL < 0.50) shading *= hatch.g;
                if (NdotL < 0.25) shading *= hatch.b;

                // NEW: Fade the intensity of the black lines so they aren't so harsh
                shading = lerp(1.0, shading, _HatchIntensity);

                // Calculate Specular Highlight
                float specular = step(_SpecularThreshold, NdotL);
                
                // Combine original color with shadows
                float3 finalColor = sourceColor.rgb * shading;
                finalColor = lerp(finalColor, float3(1, 1, 1), specular); 

                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}