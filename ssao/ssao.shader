Shader "neo/ssao"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
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
				float4 worldPos : COLOR0;
				//float4 cameraPos : COLOR1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			//float4x4 cameraToWorldMatrix;
			//float4x4 worldToCameraMatrix;

			float4 randomOffsets[32];

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.worldPos = mul(unity_ObjectToWorld,v.vertex);
				//o.cameraPos = mul(UNITY_MATRIX_MV,v.vertex);
                return o;
            }

			//sampler2D _CameraDepthTexture;
			sampler2D _CameraDepthNormalsTexture;
			float4 GetWorldPositionFromDepthValue(float2 uv, float linearDepth)
			{
				//_ProjectionParams(1|-1(是否翻转),near,far,1/far)
				float camPosZ = _ProjectionParams.y + (_ProjectionParams.z - _ProjectionParams.y) * linearDepth;
				// unity_CameraProjection._m11 = near / t，其中t是视锥体near平面的高度的一半。
				// 投影矩阵的推导见：http://www.songho.ca/opengl/gl_projectionmatrix.html。
				// 这里求的height和width是坐标点所在的视锥体截面（与摄像机方向垂直）的高和宽，并且
				// 假设相机投影区域的宽高比和屏幕一致。
				float height = 2 * camPosZ / unity_CameraProjection._m11;
				float width = _ScreenParams.x / _ScreenParams.y * height;
				float camPosX = width * uv.x - width / 2;
				float camPosY = height * uv.y - height / 2;
				float4 camPos = float4(camPosX, camPosY, camPosZ, 0.0);
				return  mul(unity_CameraToWorld, camPos);
			}

			float2 GetScreenPositionFromCameraPosition(float4 cameraPos) {
				//float4 cameraPos = mul(unity_WorldToCamera, worldPos);
				float height = 2 * cameraPos.z / unity_CameraProjection._m11;
				float width = _ScreenParams.x / _ScreenParams.y * height;
				float uvx = (cameraPos.x + (width * 0.5)) / width;
				float uvy = (cameraPos.y + (height * 0.5)) / height;
				return float2(uvx, uvy);
			}

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
				float4 normalDepth = tex2D(_CameraDepthNormalsTexture,i.uv);
				float3 centerNormal;// = normalDepth.xy;

				//float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
				// 注意：经过投影变换之后的深度和相机空间里的z已经不是线性关系。所以要先将其转换为线性深度。
				// 见：https://developer.nvidia.com/content/depth-precision-visualized
				float linearDepth;// = DecodeFloatRG(normalDepth.zw);//Linear01Depth(rawDepth);
				DecodeDepthNormal(normalDepth, linearDepth, centerNormal);
				float4 worldPos = GetWorldPositionFromDepthValue(i.uv, linearDepth);
				float4 cameraPos = mul(unity_WorldToCamera, worldPos);
				//float4 worldPos = mul(unity_CameraToWorld, cameraPos);
				float ao = 0;
				for (int i = 0; i < 32; i++) {
					//float dotNP = dot(randomOffsets[i].xyz, centerNormal);
					float3 randOffset = float3(randomOffsets[i].x, randomOffsets[i].y, -randomOffsets[i].z);//Z值取反，按理说摄像机坐标才需要
					float dotDir = dot(normalize(centerNormal), normalize(randOffset));
					dotDir = step(0, dotDir);//step(threshold,x)= (threshold<x)? 1 : 0;
					dotDir = lerp(-1, 1, dotDir);//这两行代替if判断语句  lerp(a,b,x)=(1-x)*a + x * b
					//float4 randPos = worldPos + randomOffsets[i] *dotDir;//与顶点法线相反的线给纠成正面
					//float4 randCamPos = mul(unity_WorldToCamera, randPos);

					//猜测的没错，取出来的法线是在摄像机坐标，这里直接把偏移加到摄像机坐标点，再乘以方向纠正
					float4 randCamPos = cameraPos + randomOffsets[i] * dotDir;


					//float3 cameraPos = mul((float3x3)UNITY_MATRIX_V, randPos.xyz);
					float randPosLinearZ = (randCamPos.z - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y);

					float4 clipPos = mul(unity_CameraProjection, randCamPos);
					float2 randScreenPos = (clipPos.xy / (-clipPos.w)) * 0.5 +0.5;
					//float2 randScreenPos = GetScreenPositionFromCameraPosition(randCamPos);
					float4 randNormalDepth = tex2D(_CameraDepthNormalsTexture, randScreenPos);
					float randLinearDepth = DecodeFloatRG(randNormalDepth.zw);

					float isVisible = step(randPosLinearZ,randLinearDepth);
					float absDiff = abs(randPosLinearZ - randLinearDepth);
					float diffAllowed = step(0.01, absDiff);
					ao += lerp(isVisible,1, diffAllowed);
				}
				ao *= 0.03125;
				ao = lerp(0.1, 1, ao);

				return col * ao;// col * ao;
            }
            ENDCG
        }
    }
}
