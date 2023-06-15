Shader "Skybox/SimpleSkybox"
{
	Properties
	{

		[Header(Sun Settings)]
        [Space][Space]
		_SunColor("Sun Color", Color) = (1.0,0.4,0.4,1.0)
		_SunRadius("Sun Radius",  Range(1, 20)) = 10
		_SunStrength("Sun Strength",  Range(0, 100)) = 100

        [Header(Moon Settings)]
        [Space][Space]
		_MoonColor("Moon Color", Color) = (1.0,1.0,0.0,1.0)
		_MoonRadius("Moon Radius",  Range(1, 20)) = 10
		_MoonStrength("Moon Strength",  Range(0, 100)) = 100
		_CrescentMoonOffset("Crescent Moon Offset",  Range(-0.2, 0.2)) = 0.07

        [Header(Day Sky Settings)]
        [Space][Space]
		_DaySkyTopColor("Day Sky Top Color", Color) = (0.0,0.8,0.95,1.0)
		_DaySkyBottomColor("Day Sky Bottom Color", Color) = (0.8,0.8,0.8,1.0)

        [Header(Night Sky Settings)]
        [Space][Space]
		_NightSkyTopColor("Night Sky Top Color", Color) = (0.0,0.0,0.0,1.0)
		_NightSkyBottomColor("Night Sky Bottom Color", Color) = (0.07,0.07,0.07,1.0)

        [Header(Horizon Settings)]
        [Space][Space]
		_HorizonDayColor("Horizon Day Color", Color) = (1.0,0.5,0.0,1.0)
		_HorizonNightColor("Horizon Night Color", Color) = (0.4,0.5,0.7,1.0)
		_HorizonWidth("Horizon Width",  Range(0, 0.5)) = 0.15
		_HorizonStrength("Horizon Strength",  Range(5, 50)) = 10
		_MidlineWidth("Midline Width",  Range(0, 0.1)) = 0.05
		_MidlineStrength("Midline Strength",  Range(5, 50)) = 10

        [Header(Star Settings)]
        [Space][Space]
        [NoScaleOffset]_Stars("starsColor Texture", 2D) = "black" {}
        _StarsSpeed("starsColor Speed", Range(0, 1)) = 0.1
        _StarsCutoff("starsColor Cutoff", Range(0, 0.3)) = 0.05
        _StarsStrength("starsColor Strength", Range(1, 30)) = 20

        [Header(Cloud Settings)]
        [Space][Space]
        [NoScaleOffset]_BaseNoise("BaseNoise Texture", 2D) = "black" {}
        [NoScaleOffset]_Distort("Distort Texture", 2D) = "black" {}
        [NoScaleOffset]_SecNoise("SecNoise Texture", 2D) = "black" {}
        _NoiseSpeed("Noise Speed", Range(0, 10)) = 1
        _NoiseScale("Noise Scale", Range(0.3, 0)) = 0.03
        _CloudSpeed("Cloud Speed", Range(0, 10)) = 1.5
        _CloudScale("Cloud Scale", Range(0.3, 0)) = 0.05
        _CloudCutoff("Cloud Cutoff", Range(0, 1)) = 0.0
        _CloudFizziness("Cloud Fizziness", Range(0, 1)) = 0.25
        _CloudMainDayColor("Cloud Main Day Color", Color) = (1.0,0.65,0.4,1.0)
        _CloudEdgeDayColor("Cloud Edge Day Color", Color) = (1.0,1.0,1.0,1.0)
        _CloudMainNightColor("Cloud Main Night Color", Color) = (0.15,0.25,0.5,1.0)
        _CloudEdgeNightColor("Cloud Edge Night Color", Color) = (0.15,0.4,0.65,1.0)
	}
		SubShader
		{
            Tags { "RenderType" = "Opaque" }
			LOD 100

			Pass
			{
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#include "UnityCG.cginc"

				#pragma shader_feature MIRROR
				#pragma shader_feature ADDCLOUD

				struct appdata
				{
					float4 vertex : POSITION;
					float3 uv : TEXCOORD0; // skybox的uv是三维向量
				};

				struct v2f
				{
					float3 uv : TEXCOORD0;
                    float3 worldPos : TEXCOORD1;
					float4 vertex : SV_POSITION;
				};

                float _SunRadius, _SunStrength, _MoonRadius, _MoonStrength, _CrescentMoonOffset;
                float _HorizonWidth, _HorizonStrength, _MidlineWidth, _MidlineStrength;
                float4 _SunColor, _MoonColor, _HorizonDayColor, _HorizonNightColor, _MidlineDayColor, _MidlineNightColor;
                float4 _DaySkyTopColor, _DaySkyBottomColor, _NightSkyTopColor, _NightSkyBottomColor;

                sampler2D _Stars;
                float _StarsSpeed, _StarsCutoff, _StarsStrength;

                sampler2D _BaseNoise, _Distort, _SecNoise;
                float _CloudSpeed, _CloudScale, _NoiseSpeed, _NoiseScale, _CloudCutoff, _CloudFizziness;
                float4 _CloudMainDayColor, _CloudEdgeDayColor, _CloudMainNightColor, _CloudEdgeNightColor;

				v2f vert(appdata v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);
                    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
					o.uv = v.uv;
					return o;
				}

				fixed4 frag(v2f i) : SV_Target
				{
                    //--------------------------------------- sun and moon --------------------------------------------
                    // sun
                    float sun = distance(i.uv.xyz, _WorldSpaceLightPos0); //得到skybox上sun的位置
                    float sunDisc = 1 - (sun * _SunRadius) ;
                    sunDisc = saturate(sunDisc * _SunStrength) * saturate(i.worldPos.y);

                    // moon 同上
                    float moon = distance(i.uv.xyz, -_WorldSpaceLightPos0);
                    float moonDisc = 1 - (moon * _MoonRadius);
                    moonDisc = saturate(moonDisc * _MoonStrength);

                    // 额外画一个月亮 两个月亮相减 即可得到残月 
                    float crescentMoon = distance(float3(i.uv.x + _CrescentMoonOffset, i.uv.yz), -_WorldSpaceLightPos0);
                    float crescentMoonDisc = 1 - (crescentMoon * _MoonRadius);
                    crescentMoonDisc = saturate(crescentMoonDisc * _MoonStrength);
                    moonDisc = saturate(moonDisc - crescentMoonDisc) * saturate(i.worldPos.y);

                    float4 sunAndMoon = sunDisc * _SunColor + moonDisc * _MoonColor;

                    //--------------------------------------- Gradient Sky --------------------------------------------
                    // day and night color
                    float3 gradientDayColor = lerp(_DaySkyBottomColor, _DaySkyTopColor, saturate(i.uv.y));
                    float3 gradientNightColor = lerp(_NightSkyBottomColor, _NightSkyTopColor, saturate(i.uv.y));
                    float3 gradientSkyColor = lerp(gradientNightColor, gradientDayColor, smoothstep(-1, 1, _WorldSpaceLightPos0.y)); //白天到黑夜渐变
                    float4 gradientSky = float4(gradientSkyColor, 1.0);

                    //--------------------------------------- Horizon Color -------------------------------------------
                    float horizonMask = saturate(_HorizonWidth - abs(i.uv.y));
                    float horizonStrength = smoothstep(-0.8, 0.5, _WorldSpaceLightPos0.y) * smoothstep(-1.0, 0.5, -_WorldSpaceLightPos0.y) * _HorizonStrength;// 这里magic number是自己调出来的 主要控制horizon出现时间
                    float horizonColorFactor = smoothstep(-0.2, 0.2, _WorldSpaceLightPos0.y); //缩小horizon颜色的渐变区间
                    float3 horizonColor = lerp(_HorizonNightColor, _HorizonDayColor, horizonColorFactor);
                    horizonColor = horizonColor * horizonMask * horizonStrength;
                    // midline 分离天空和地面
                    float midlineMask = saturate(_MidlineWidth - abs(i.uv.y));
                    float3 midlineColor = midlineMask * gradientSkyColor * _MidlineStrength;
                    float4 horizon = float4(horizonColor + midlineColor, 1.0);
                    //-------------------------------------------- Star -----------------------------------------------
                    float2 skyUV = i.worldPos.xz / i.worldPos.y;
                    float3 starsColor = tex2D(_Stars, skyUV + _Time.x * _StarsSpeed);
                    starsColor *= 1 - saturate(_WorldSpaceLightPos0.y + 0.6); // 白天不显示star +0.5就不会在白天过渡
                    starsColor *= step(_StarsCutoff, starsColor) * _StarsStrength; // star阈值和强度
                    float4 stars = float4(starsColor, 1.0);

                    //------------------------------------------- Cloud -----------------------------------------------
                    float baseNoise = tex2D(_BaseNoise, (skyUV + _CloudSpeed) * _CloudScale);
                    float distort = tex2D(_Distort, ((skyUV + baseNoise) + (_Time.x * _CloudSpeed)) * _CloudScale); 
                    float noise = tex2D(_SecNoise, ((skyUV + distort) + (_Time.x * _NoiseSpeed)) * _NoiseScale);
                    float finalNoise = saturate(distort * noise) * saturate(i.worldPos.y);// 去除地下的贴图采样

                    float clouds = saturate(smoothstep(_CloudCutoff, _CloudCutoff + _CloudFizziness, finalNoise));
                    float4 cloudEdgeColor = lerp(_CloudEdgeNightColor, _CloudEdgeDayColor, smoothstep(-0.2, 0.2, _WorldSpaceLightPos0.y));
                    float4 cloudMainColor = lerp(_CloudMainNightColor, _CloudMainDayColor, smoothstep(-0.2, 0.2, _WorldSpaceLightPos0.y));
                    float4 cloudsColored = lerp(cloudEdgeColor, cloudMainColor, clouds) * clouds;

                    stars *= saturate(1 - clouds * 5 - sunDisc - moonDisc);// stars不要挡住云和日月
                    sunAndMoon *= saturate(1 - clouds);// 日月不要挡住云
                    gradientSky *= saturate(1 - (sunDisc + moonDisc) * 0.8);// 渐变色不要和日月完全叠加 我稍微mix了一点
                    return sunAndMoon + horizon + gradientSky + stars + cloudsColored;
		        }
		        ENDCG
	    }
	}
}
