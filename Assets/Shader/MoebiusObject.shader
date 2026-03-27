Shader "Custom/MoebiusObject"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _HatchTex("Cross-Hatch Texture (RGB: Horiz/Vert/Diag)", 2D) = "white" {}
        _HatchTiling("Hatch Tiling", Float) = 10.0
        _SpecularThreshold("Specular Threshold", Range(0,1)) = 0.95
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }

        // Pass 1: Renders the flat colors and screen-space crosshatch shading
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float _HatchTiling;
                float _SpecularThreshold;
            CBUFFER_END

            TEXTURE2D(_HatchTex);
            SAMPLER(sampler_HatchTex);

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.screenPos = ComputeScreenPos(output.positionCS);
                return output;
            }

            float4 Frag(Varyings input) : SV_Target
            {
                Light mainLight = GetMainLight();
                float3 normalWS = normalize(input.normalWS);
                
                // Diffuse Lighting for thresholding
                float NdotL = saturate(dot(normalWS, mainLight.direction));

                // Screen-space UV mapping for the hatching lines
                float2 screenUV = input.screenPos.xy / input.screenPos.w;
                screenUV.x *= _ScreenParams.x / _ScreenParams.y; // Fix aspect ratio stretch
                screenUV *= _HatchTiling;

                // Sample hatching texture. R = horizontal, G = vertical, B = diagonal
                float3 hatch = SAMPLE_TEXTURE2D(_HatchTex, sampler_HatchTex, screenUV).rgb;

                // Video Logic: Draw hatch lines progressively based on shadow depths
                float shading = 1.0;
                if (NdotL < 0.75) shading *= hatch.r;
                if (NdotL < 0.50) shading *= hatch.g;
                if (NdotL < 0.25) shading *= hatch.b;

                float3 finalColor = _BaseColor.rgb * shading;
                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }

        // Pass 2: Triggers the outline for specular highlights
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormals" }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float _SpecularThreshold;
            CBUFFER_END

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                return output;
            }

            float4 Frag(Varyings input) : SV_Target
            {
                Light mainLight = GetMainLight();
                float3 normalWS = normalize(input.normalWS);
                
                // Specular highlight outline trick: If light hits highly exposed surface, 
                // suddenly flip the normal output. The post-process Sobel filter will 
                // detect this massive change and automatically draw an outline around it!
                float NdotL = saturate(dot(normalWS, mainLight.direction));
                if (NdotL > _SpecularThreshold)
                {
                    normalWS = -normalWS; 
                }

                return float4(normalWS, 0.0);
            }
            ENDHLSL
        }
    }
}