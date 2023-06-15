Shader "Custom/WaterPlaneShader"
{
    Properties
    {    
        [Header(Texture)]
        [Space(15)]
        _MainColor("Main Color", color) = (1.0, 1.0, 1.0, 1.0)
    	[Space(15)]
		[NoScaleOffset]_ReflectionTex("Reflection Texture", 2D) = "white" {}
		_Distortion("Distortion", range(0.1, 0.3)) = 0.18
    	[Space(15)]
    	_FoamTex("Foam Texture", 2D) = "white" {}
    	_FoamThreshold("Foam Threshold", range(0, 5)) = 2
    	_FoamLinesSpeed("FoamLines Speed", range(0, 1)) = 0.2
    	_WaveSpeed("WaveSpeed",Range(0,1)) = 0.3
    	[Space(15)]
		_SpecularColor("Specular Color", color) = (1.0, 1.0, 1.0, 1.0)
    	_Gloss("GLoss",Range(1,100)) = 30
    	[Space(15)]
		_RefractionStrength("Refraction Strength", range(0, 0.1)) = 0.01
    }
    SubShader
    {
        LOD 100
        Tags 
        { 
            "Queue" = "Transparent" 
            "RenderType" = "Transparent" 
        }
    	Blend SrcAlpha OneMinusSrcAlpha
    	ZWrite off
        
        HLSLINCLUDE
        #pragma vertex vert
        #pragma fragment frag
        #pragma shader_feature _RENDER_BODY _RENDER_FACE
        #pragma PI 3.14159265359
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float4 _MainColor;
        float4 _ReflectionTex_ST;
        float _Distortion;
	    float4 _FoamTex_ST;
        float _FoamThreshold;
        float _FoamLinesSpeed;
        float _WaveSpeed;
        float4 _SpecularColor;
        float _Gloss;
        float _RefractionStrength;
        CBUFFER_END
        
        TEXTURE2D(_ReflectionTex); 
        SAMPLER(sampler_ReflectionTex);
        TEXTURE2D(_FoamTex); 
        SAMPLER(sampler_FoamTex);
        TEXTURE2D_X_FLOAT(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);
        TEXTURE2D(_CameraOpaqueTexture); 
        SAMPLER(sampler_CameraOpaqueTexture);
        
        struct appdata
        {
            float4 posOS : POSITION;
            float2 uv : TEXCOORD0;
            float3 normalOS : NORMAL;
        };

        struct v2f
        {
            float2 uv : TEXCOORD0;
            float4 posCS : SV_POSITION;
            float3 posWS : TEXCOORD1;
            float4 posScreen : TEXCOORD2;
            float3 normalWS : TEXCOORD3;
        	float2 foamUV : TEXCOORD4;
        };
        
        ENDHLSL
        
        Pass
        {
            Cull Back

            Name "Forward"
            Tags{ "LightMode" = "UniversalForward" } 
        	
            HLSLPROGRAM
            
            v2f vert(appdata v)
            {
                v2f o;
                o.uv = v.uv;
                o.posCS = TransformObjectToHClip(v.posOS);
                o.posWS = TransformObjectToWorld(v.posOS);
                o.posScreen = ComputeScreenPos(o.posCS);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
        		o.foamUV = TRANSFORM_TEX(o.posWS.xz, _FoamTex);
                return o;
            }

            half4 cosine_gradient(float x,  half4 phase, half4 amp, half4 freq, half4 offset){
				const float TAU = 2. * 3.14159265;
  				phase *= TAU;
  				x *= TAU;

  				return half4(
    				offset.r + amp.r * 0.5 * cos(x * freq.r + phase.r) + 0.5,
    				offset.g + amp.g * 0.5 * cos(x * freq.g + phase.g) + 0.5,
    				offset.b + amp.b * 0.5 * cos(x * freq.b + phase.b) + 0.5,
    				offset.a + amp.a * 0.5 * cos(x * freq.a + phase.a) + 0.5
  				);
			}

            half3 toRGB(half3 grad){
  				 return grad.rgb;
			}

			float2 rand(float2 st, int seed)
			{
				float2 s = float2(dot(st, float2(127.1, 311.7)) + seed, dot(st, float2(269.5, 183.3)) + seed);
				return -1 + 2 * frac(sin(s) * 43758.5453123);
			}
            
			float noise(float2 st, int seed)
			{
				st.y += _Time[1];

				float2 p = floor(st);
				float2 f = frac(st);
 
				float w00 = dot(rand(p, seed), f);
				float w10 = dot(rand(p + float2(1, 0), seed), f - float2(1, 0));
				float w01 = dot(rand(p + float2(0, 1), seed), f - float2(0, 1));
				float w11 = dot(rand(p + float2(1, 1), seed), f - float2(1, 1));
				
				float2 u = f * f * (3 - 2 * f);
 
				return lerp(lerp(w00, w10, u.x), lerp(w01, w11, u.x), u.y);
			}
            
            float3 swell(float3 normal , float3 pos , float anisotropy){
				float height = noise(pos.xz * 0.1,0);
				height *= anisotropy ;
				normal = normalize(
					cross ( 
						float3(0,ddy(height),1),
						float3(1,ddx(height),0)
					)
				);
				return normal;
			}

            
            half4 frag(v2f i) : SV_Target
            {
            	
                //------------------------------------ water color -------------------------------
                const half4 phases = half4(0.47, 0.55, 0.26, 0.);//周期
                const half4 amplitudes = half4(1.17, 1.49, 1.49, 0.);//振幅
                const half4 frequencies = half4(0.00, 0.34, 0.16, 0.);//频率
                const half4 offsets = half4(0.00, 0.68, 0.57, 0.);//相位
                
                half2 screenUV = i.posScreen.xy / i.posScreen.w;// 屏幕空间坐标
                float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                float sceneZ = LinearEyeDepth(depth, _ZBufferParams);// 场景的深度
                float waterZ = i.posScreen.w;// 水面的深度
                float diff = (sceneZ - waterZ)/ 5.0f;// 水面水底深度差值
            	
                half4 cos_grad = cosine_gradient(saturate(1.5-diff), phases, amplitudes, frequencies, offsets);
  				cos_grad = clamp(cos_grad, 0., 1.);

                half4 color = float4(toRGB(cos_grad), 1.0) * _MainColor;
                //------------------------------------ reflect color -----------------------------
                // normal
                float3  cameraDistance = i.posWS - _WorldSpaceCameraPos;
                float anisotropy = saturate(1/(ddy(length(cameraDistance.xz)))/5);
                float3 swelledNormal = swell(i.normalWS, i.posWS, anisotropy);

            	// skybox refelction color
            	half3 viewDirWS = normalize(_WorldSpaceCameraPos - i.posWS);
				half3 reflectDir = reflect(-viewDirWS, swelledNormal);
            	half4 reflectColor = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDir, 0.0);
            	
            	// reflectionTex color
            	float height = noise(i.posWS.xz * 0.1, 0);
            	float offset = height * _Distortion;
            	screenUV.x += pow(offset, 2) * saturate(diff);
            	float4 reflectTexColor = SAMPLE_TEXTURE2D_X(_ReflectionTex, sampler_ReflectionTex, float2(screenUV.x, 1 - screenUV.y));
            	reflectTexColor = reflectTexColor.a > 0.0 ? reflectTexColor - reflectColor : reflectTexColor;//物体倒影部分减去skybox reflect 避免颜色过亮失真
            	reflectColor += reflectTexColor;

            	//--------------------------------------- refract ----------------------------------
				half2 refractionUV = screenUV + swelledNormal.xz * _RefractionStrength;
            	half4 refractionColor = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, refractionUV);
				reflectColor += refractionColor;

            	//--------------------------------------- foam ----------------------------------
            	float foamDiff = saturate((sceneZ - waterZ) / _FoamThreshold);
				i.foamUV.y += _Time.y * _WaveSpeed;
            	float foamTex = SAMPLE_TEXTURE2D_X(_FoamTex, sampler_FoamTex, i.foamUV);
            	float foam = step( (foamDiff - saturate(sin((foamDiff + _Time.y *_FoamLinesSpeed) * 2 * PI)) * (1.0 - foamDiff)),foamTex) * smoothstep(0, 0.2, diff);
            	color += foam;

            	//--------------------------------------- specular ----------------------------------
				half3 lightDirWS = normalize(_MainLightPosition.xyz);
            	half3 halfVec = normalize(lightDirWS + viewDirWS);
            	half4 specular = _SpecularColor * pow(max(0, dot(swelledNormal, halfVec)), _Gloss);
            	color += specular;
            	
                //--------------------------------------- fresnel ----------------------------------
                float f0 = 0.02;
                float reflectFactor = f0 + (1 - f0) * pow((1 - dot(viewDirWS, swelledNormal)), 5.0);
				reflectFactor = saturate(reflectFactor * 2.0);
            	color = lerp(color, reflectColor, reflectFactor);

            	float3 v = i.posWS - _WorldSpaceCameraPos;
            	//地平线处边缘光，使海水更通透
				color += ddy(length(v.xz))/200;
                //color.a = saturate(diff);
            	color = foam > 0 ? foam : color;
            	color.a = lerp(saturate(diff * reflectFactor), 1, foam);
            	return color;
            }
            ENDHLSL
        }
    }
}