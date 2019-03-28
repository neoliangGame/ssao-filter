using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ssao : MonoBehaviour
{

    public Material ssaoMaterial;
    public Material filterMaterial;

    List<Vector4> randomOffsets;
    float randomOffsetDistance = 0.6f;
    int randomOffsetCount = 32;

    void Start()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.DepthNormals;
        CountRandomOffsets();
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        RenderTexture temp1 = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.ARGBHalf);
        RenderTexture temp2 = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.ARGBHalf);
        if (ssaoMaterial != null)
        {
            ssaoMaterial.SetVectorArray("randomOffsets", randomOffsets);
            Graphics.Blit(source, temp1, ssaoMaterial);
        }
        else
        {
            Graphics.Blit(source, temp1);
        }
        
        if(filterMaterial != null)
        {
            filterMaterial.SetVector("_DirectionVec", new Vector4(1f, 0f, 0f, 0f));
            Graphics.Blit(temp1, temp2, filterMaterial,1);
            filterMaterial.SetVector("_DirectionVec", new Vector4(0f, 1f, 0f, 0f));
            Graphics.Blit(temp2, destination, filterMaterial,1);
        }
        else
        {
            Graphics.Blit(temp1, destination);
        }
        RenderTexture.ReleaseTemporary(temp1);
        RenderTexture.ReleaseTemporary(temp2);
    }

    void CountRandomOffsets()
    {
        randomOffsets = new List<Vector4>();
        float x, y, z;
        float dirX, dirY, dirZ;
        float dirScale;
        //float scale = 1f / randomOffsetCount;
        for (int i = 0;i < randomOffsetCount; i++)
        {
            dirScale = ((float)randomOffsetCount + i) / (randomOffsetCount * 2f);
            dirScale *= dirScale;

            dirX = Random.Range(-1f, 1f);
            dirX = dirX > 0f ? 1f : -1f;
            dirY = Random.Range(-1f, 1f);
            dirY = dirY > 0f ? 1f : -1f;
            dirZ = Random.Range(-1f, 1f);
            dirZ = dirZ > 0f ? 1f : -1f;

            x = Random.Range(0.06f, randomOffsetDistance);
            y = Random.Range(0.06f, randomOffsetDistance);
            z = Random.Range(0.06f, randomOffsetDistance);
            Vector4 oneRandomOffset = new Vector4(
                x * dirScale * dirX, y * dirScale * dirY, z * dirScale * dirZ, 0f);//越近的数量越多，因为对值取平方，会聚集点
            randomOffsets.Add(oneRandomOffset);
        }
        
    }
}
