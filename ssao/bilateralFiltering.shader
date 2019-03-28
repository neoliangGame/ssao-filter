Shader "neo/bilateralFiltering"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_DirectionVec("Direction",Vector) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass//0-color
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			float4 _MainTex_TexelSize;

			float4 _DirectionVec;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

			float countColorWeight(float4 a, float4 b) {
				float x = 1 - abs(a.x - b.x);
				float y = 1 - abs(a.y - b.y);
				float z = 1 - abs(a.z - b.z);
				return (x + y + z) * 0.333333;
			}

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
				//高斯分布：0.37		0.317		0.198		0.115
				float uvDelta = _MainTex_TexelSize.xy * _DirectionVec.xy;
				float4 col11 = tex2D(_MainTex, i.uv + uvDelta);
				float4 col12 = tex2D(_MainTex, i.uv - uvDelta);
				float weight11 = 0.6 * countColorWeight(col, col11);
				float weight12 = 0.6 * countColorWeight(col, col12);
				col += col11 * weight11 + col12 * weight12;

				float4 col21 = tex2D(_MainTex, i.uv + uvDelta * 2);
				float4 col22 = tex2D(_MainTex, i.uv - uvDelta * 2);
				float weight21 = 0.4 * countColorWeight(col, col21);
				float weight22 = 0.4 * countColorWeight(col, col22);
				col += col21 * weight21 + col22 * weight22;

				float4 col31 = tex2D(_MainTex, i.uv + uvDelta * 3);
				float4 col32 = tex2D(_MainTex, i.uv - uvDelta * 3);
				float weight31 = 0.2 * countColorWeight(col, col31);
				float weight32 = 0.2 * countColorWeight(col, col32);
				col += col31 * weight31 + col32 * weight32;

				float4 col41 = tex2D(_MainTex, i.uv + uvDelta * 4);
				float4 col42 = tex2D(_MainTex, i.uv - uvDelta * 4);
				float weight41 = 0.1 * countColorWeight(col, col41);
				float weight42 = 0.1 * countColorWeight(col, col42);
				col += col41 * weight41 + col42 * weight42;
				
				float weight = 1 + weight11 + weight12 + weight21 + weight22 + weight31 + weight32 + weight41 + weight42;
				col /= weight;

                return col;
            }
            ENDCG
        }

		Pass//1-normal
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;

			float4 _DirectionVec;

			sampler2D _CameraDepthNormalsTexture;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			float countNormalWeight(float2 uva, float2 uvb) {
				float4 normalDepthA = tex2D(_CameraDepthNormalsTexture, uva);
				float3 normalA = DecodeViewNormalStereo(normalDepthA);
				//float linearDepth;
				//DecodeDepthNormal(normalDepthA, linearDepth, normalA);

				float4 normalDepthB = tex2D(_CameraDepthNormalsTexture, uvb);
				float3 normalB = DecodeViewNormalStereo(normalDepthB);
				//DecodeDepthNormal(normalDepthB, linearDepth, normalB);

				float normalDiff = dot(normalize(normalA), normalize(normalB));

				//float normalAllowed = step(0.3, normalDiff);
				//normalDiff = min(normalDiff, 1);
				return smoothstep(0.3,1, normalDiff);
			}

			fixed4 frag(v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);
				float2 uvDelta = _MainTex_TexelSize.xy * _DirectionVec.xy;
			
				//高斯分布：0.37		0.317		0.198		0.115

				//float3 centerNormal;// = normalDepth.xy;

				//float linearDepth;// = DecodeFloatRG(normalDepth.zw);//Linear01Depth(rawDepth);
				//DecodeDepthNormal(normalDepth, linearDepth, centerNormal);
				
				float2 uv11 = i.uv + uvDelta;
				float2 uv12 = i.uv - uvDelta;
				float4 col11 = tex2D(_MainTex, uv11);
				float4 col12 = tex2D(_MainTex, uv12);
				float weight11 = 0.6 * countNormalWeight(i.uv, uv11);
				float weight12 = 0.6 * countNormalWeight(i.uv, uv12);
				col += col11 * weight11 + col12 * weight12;

				float2 uv21 = i.uv + uvDelta * 2;
				float2 uv22 = i.uv - uvDelta * 2;
				float4 col21 = tex2D(_MainTex, uv21);
				float4 col22 = tex2D(_MainTex, uv22);
				float weight21 = 0.4 * countNormalWeight(i.uv, uv21);
				float weight22 = 0.4 * countNormalWeight(i.uv, uv22);
				col += col21 * weight21 + col22 * weight22;

				float2 uv31 = i.uv + uvDelta * 3;
				float2 uv32 = i.uv - uvDelta * 3;
				float4 col31 = tex2D(_MainTex, uv31);
				float4 col32 = tex2D(_MainTex, uv32);
				float weight31 = 0.2 * countNormalWeight(i.uv, uv31);
				float weight32 = 0.2 * countNormalWeight(i.uv, uv32);
				col += col31 * weight31 + col32 * weight32;

				float2 uv41 = i.uv + uvDelta * 4;
				float2 uv42 = i.uv - uvDelta * 4;
				float4 col41 = tex2D(_MainTex, uv41);
				float4 col42 = tex2D(_MainTex, uv42);
				float weight41 = 0.1 * countNormalWeight(i.uv, uv41);
				float weight42 = 0.1 * countNormalWeight(i.uv, uv42);
				col += col41 * weight41 + col42 * weight42;

				float weight = 1 + weight11 + weight12 + weight21 + weight22 + weight31 + weight32 + weight41 + weight42;
				col /= weight;

				return col;
			}
			ENDCG
	}
    }
}
