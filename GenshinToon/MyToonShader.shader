Shader "Unlit/MyTestShader"
{
    Properties
    {
        [Header(Feature)]
        [Space(15)]
        [KeywordEnum(Body, Face)] _RENDER("Body Parts", float) = 0
        
        [Header(Texture)]
        [Space(15)]
        _BaseMap("BaseMap", 2D) = "white" {}
        [NoScaleOffset]_LightMap("LightMap", 2D) = "white" {}
        [NoScaleOffset]_RampMap("RampMap", 2D) = "white" {}
        [NoScaleOffset]_MetalMap("MetalMap", 2D) = "white" {}
        [NoScaleOffset]_AdditionalMap("AdditionalMap", 2D) = "white" {}
        
        [Header(Parameter)]
        [Space(15)]
        [Enum(Day,2,Night,1)]_TimeShift("Day&Night Switch", int) = 2
        
        [Space(10)]
        _ShadowRampThreshold("Shadow Ramp Threshold", range(0.0, 1.0)) = 0.35
        _LitRampLerp ("Lit Ramp Lerp", range(0.0, 1.0)) = 0.7
        _FaceRampOffset ("Face Ramp Offset", range(0.0, 1.0)) = 0.25
        
        [Space(10)]
        _SpecularExp ("Specular Exp", range(1.0, 128.0)) = 16
        _NonMetalSpecularIntensity("NonMetal Specular Intensity", range(0.0, 1.0)) = 0.2
        _MetalSpecularIntensity("Metal Specular Intensity", range(0.0, 100.0)) = 30
        
        [Space(10)]
        [HideInInspector] _FresnelRimOffset ("Fresnel RimOffset", range(-1.0, 1.0)) = 0.1
        _DepthRimOffset ("Depth RimOffset", range(0.0, 0.01)) = 0.002
        _RimIntensity  ("Rim Intensity", range(0.0, 10.0)) = 1.0
        _RimLightThreshold ("RimLight Threshold", range(0.0, 1.0)) = 0.09
        _RimLightColor ("RimLight Color", color) = (0.5, 0.5, 0.5)
        
        [Space(10)]
        _EmissionThreshold ("Emission Threshold", range(0.0, 1.0)) = 0.02
        _EmissionIntensity("Emission Intensity", range(0.0, 10.0)) = 1.0
        
        [Space(10)]
        _OutlineColor("Outline Color", color) = (0.0, 0.0, 0.0)
        _OutlineWidth("Outline Width", range(0.0, 0.01)) = 0.01
        
    }
    SubShader
    {
        LOD 100
        Tags 
        { 
            "Queue"="Geometry" 
            "RenderType" = "Opaque" 
            "IgnoreProjector" = "True" 
            "RenderPipeline" = "UniversalPipeline"
        }
        
        HLSLINCLUDE
        #pragma vertex vert
        #pragma fragment frag
        #pragma shader_feature _RENDER_BODY _RENDER_FACE
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

        //为了支持 Batcher 在 CBUFFER 下声明 Material properties
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        float4 _LightMap_ST;
        float4 _RampMap_ST;
        float4 _MetalMap_ST;
        float4 _AdditionalMap_ST;
        int _TimeShift;
        float _ShadowRampThreshold;
        float _LitRampLerp;
        float _FaceRampOffset;
        float _SpecularExp;
        float _MetalSpecularIntensity;
        float _NonMetalSpecularIntensity;
        float _FresnelRimOffset;
        float _DepthRimOffset;
        float _RimIntensity;
        float _RimLightThreshold;
        float4 _RimLightColor;
        float _EmissionThreshold;
        float _EmissionIntensity;
        float4 _OutlineColor;
        float _OutlineWidth;
        CBUFFER_END
        
        //纹理与采样器类型使用URP宏另外声明
        TEXTURE2D(_BaseMap);
        SAMPLER(sampler_BaseMap);
        TEXTURE2D(_LightMap);
        SAMPLER(sampler_LightMap);
        TEXTURE2D(_RampMap);
        SAMPLER(sampler_RampMap);
        TEXTURE2D(_MetalMap);
        SAMPLER(sampler_MetalMap);
        TEXTURE2D(_AdditionalMap);
        SAMPLER(sampler_AdditionalMap);
        TEXTURE2D_X_FLOAT(_CameraDepthTexture); 
        SAMPLER(sampler_CameraDepthTexture);
        
        //应用阶段结构体声明
        struct appdata
        {
            float4 posOS            : POSITION;
            float2 uv               : TEXCOORD0;
            float3 normalOS         : NORMAL;
            float4 tangentOS        : TANGENT;
            float4 vertexColor      : COLOR;
        };

        //几何阶段结构体声明
        struct v2f
        {
            float4 posCS            : SV_POSITION;
            float2 uv               : TEXCOORD0;
            float3 posWS            : TEXCOORD1;
            float3 nDirWS         : TEXCOORD2;
            float4 col              : COLOR;
        };

        float4 TransformHClipToViewPortPos(float4 positionCS)
        {
            float4 o = positionCS * 0.5f;
            o.xy = float2(o.x, o.y * _ProjectionParams.x) + o.w;
            o.zw = positionCS.zw;
            return o / o.w;
        }
        
        ENDHLSL
        
        Pass
        {
            Cull Off

            Name "Forward"
            Tags{ "LightMode" = "UniversalForward" } 
            HLSLPROGRAM

            //顶点着色器
            v2f vert(appdata v)
            {
                v2f o;
 
                o.posCS = TransformObjectToHClip(v.posOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                o.posWS = TransformObjectToWorld(v.posOS);
                o.nDirWS = TransformObjectToWorldNormal(v.normalOS);
                o.col=v.vertexColor;

                return o;
            }

            //片段着色器
            half4 frag(v2f i) : SV_Target
            {
                // 主光源
                Light mainLight = GetMainLight();
                float4 mainLightColor = float4(mainLight.color, 1);

                // 方向
                float3 lDirWS = normalize(mainLight.direction);
                float3 vDirWS = normalize(GetCameraPositionWS() - i.posWS);
                float3 nDirVS = normalize(TransformWorldToView(i.nDirWS));
                float ndotl = dot(i.nDirWS, lDirWS);
                float ndoth = dot(i.nDirWS, normalize(vDirWS + lDirWS));
                float ndotv = dot(i.nDirWS, vDirWS);
                float ldotv = dot(lDirWS, vDirWS);
                
                //BaseMap基础色
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                // lightMap
                // a channel: 材质分层
                // r channel: 高光类型分层(金属，非金属，无高光)
                // g channel: AO区域
                // b channel: 高光强度 黑色非高光
                float4 lightMap = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, i.uv);

#if _RENDER_BODY

                // ----------------------- diffuse ---------------------------- //
                // Lambert & Ramp
                float MatID = lightMap.a * 0.45;
                float rampVmove = (_TimeShift - 1.0) * 0.5;
                half lambert = saturate(ndotl) * lightMap.g + 0.5;
                float rampValue = lambert - 0.003;

                half3 RampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampValue, MatID + rampVmove)).rgb;
                //float ShadowRamp = smoothstep(_ShadowRampThreshold, _ShadowRampThreshold + 0.05, ndotl);
                float ShadowRamp = step(_ShadowRampThreshold, ndotl);
                half3 litColor = lerp(RampColor * mainLightColor * baseColor, mainLightColor * baseColor, _LitRampLerp);
                half3 diffuse = lerp(RampColor * baseColor.rgb, litColor, ShadowRamp);
                
                // ---------------------- specular ---------------------------- //
                float ks = 0.04;
                float specularIntensity = lightMap.b;
                float secularContrib = pow(saturate(ndoth), _SpecularExp) * specularIntensity;
                float3 specularColor = mainLightColor * secularContrib * _NonMetalSpecularIntensity;
                
                // metal
                float metalMask = step(0.9, lightMap.r);
                float metalMap = SAMPLE_TEXTURE2D(_MetalMap, sampler_MetalMap, vDirWS.xy * 0.5 + 0.5).r;
                float metalContrib = metalMap * _MetalSpecularIntensity * secularContrib;
                half3 specular = lerp(specularColor, metalContrib * baseColor.rgb * mainLightColor, metalMask);

                // ---------------------- rimLight ---------------------------- //
                // fresnel rimLight
                // float fresnelRimMask = (1 - smoothstep(_FresnelRimOffset, _FresnelRimOffset + 0.03, saturate(ndotv)));

                 //screen depth rimLight
                float3 normalWS = i.nDirWS;
                float3 normalVS = TransformWorldToViewDir(normalWS, true);
                float3 positionVS = TransformWorldToView(i.posWS);
                float3 samplePositionVS = float3(positionVS.xy + normalVS.xy * _DepthRimOffset, positionVS.z);
                float4 samplePositionCS = TransformWViewToHClip(samplePositionVS);
                float4 samplePositionVP = TransformHClipToViewPortPos(samplePositionCS);

                float4 positionNDC = TransformWorldToHClip(i.posWS);

                float depth = positionNDC.z / positionNDC.w;
                float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams); // 离相机越近越小
                float offsetDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, samplePositionVP).r; // _CameraDepthTexture.r = input.positionNDC.z / input.positionNDC.w
                float linearEyeOffsetDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);
                float depthDiff = linearEyeOffsetDepth - linearEyeDepth;
                float rimMask = step(_RimLightThreshold, depthDiff);

                // float2 scrUV = float2(i.posCS.x / _ScreenParams.x, i.posCS.y / _ScreenParams.y);
                // float2 offsetPos = scrUV + float2(nDirVS.xy *_DepthRimOffset* clamp(-ldotv,0.5,1) / i.posCS.w);
                // float offsetDepth = LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture ,offsetPos),_ZBufferParams);
                // float originalDepth = LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, scrUV),_ZBufferParams);
                // float rimMask = step(0.25,smoothstep(0,_RimLightThreshold,offsetDepth-originalDepth));
                half4 rimLight = rimMask * _RimIntensity * _RimLightColor * baseColor;
                
                // ---------------------- emission ---------------------------- //
                float emissionMask = smoothstep(_EmissionThreshold, _EmissionThreshold + 0.1, baseColor.a);
                half3 emission = emissionMask * baseColor.a * baseColor.rgb * _EmissionIntensity;

                half4 color = half4(diffuse + specular + emission + rimLight, 1);


#elif _RENDER_FACE
                float3 Up = float3(0, 1, 0);
                float3 Front = unity_ObjectToWorld._13_23_33;
                float3 Right = cross(Up, Front);

                float2 lDir = normalize(lDirWS.xz);
                float rdotl = dot(normalize(Right.xz), lDir);
                float fdotl = dot(normalize(Front.xz), lDir);
                float faceShadowR = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, float2(-i.uv.x, i.uv.y)).a;
                float faceShadowL = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, i.uv).a;

                float shadowMap = faceShadowL * step(0, -rdotl) + faceShadowR * step(0, rdotl);
                float inShadow = step(0, shadowMap - (1 - fdotl) / 2);

                float2 rampUV = float2(clamp(inShadow, 0.1, 0.9), _FaceRampOffset + (_TimeShift - 1.0) * 0.5);
                half3 rampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, rampUV);
                half3 litColor = lerp(rampColor * mainLightColor, mainLightColor * baseColor, _LitRampLerp);
                half4 color = half4(lerp(rampColor, max(litColor, rampColor), inShadow) * baseColor.rgb, 1);
                //color = SAMPLE_TEXTURE2D(_AdditionalMap, sampler_AdditionalMap, i.uv).r;
#endif
                
                return color;
            }
            ENDHLSL
        }
        
        Pass
        {
            Cull Front
            
            Name "Outline"
            Tags{"LightMode" = "SRPDefaultUnlit"}
            HLSLPROGRAM

            v2f vert(appdata v)
            {
                v2f o;
                float outlineWidthMap = _AdditionalMap.SampleLevel(sampler_AdditionalMap,v.uv,1);
                v.posOS.xyz += v.normalOS.xyz * outlineWidthMap * _OutlineWidth;
                o.uv = v.uv;
                o.posCS = TransformObjectToHClip(v.posOS.xyz);

                return o;
            }

            half4 frag(v2f i) : SV_TARGET
            {
                half4 color = _OutlineColor;
                return color;
            }
            
            ENDHLSL
        }
        
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull off

            HLSLPROGRAM

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }
    }
}
