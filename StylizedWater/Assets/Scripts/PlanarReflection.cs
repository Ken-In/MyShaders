using System;
using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;

public class PlanarReflection : MonoBehaviour
{
    private Vector2 Resolution;
    [SerializeField] private Camera ReflectionCamera;
    [SerializeField] private RenderTexture ReflectionRenderTexture;
    [SerializeField] private int ReflectionResloution = 512;

    public float m_ClipPlaneOffset = 0.07f;
    public LayerMask m_ReflectLayers = -1;
    
    private void OnEnable()
    {
        RenderPipelineManager.beginCameraRendering += runPlannarReflection;
    }
    
    private void OnDisable() {
        Cleanup();
    }
    
    private void OnDestroy() {
        Cleanup();
    }

    private void Cleanup()
    {
        RenderPipelineManager.beginCameraRendering -= runPlannarReflection;
    }

    private void runPlannarReflection(ScriptableRenderContext context, Camera camera)
    {
        UpdateReflectionCamera(camera);
    }

    private Vector4 CameraSpacePlane (Camera cam, Vector3 pos, Vector3 normal, float sideSign)
    {
        Vector3 offsetPos = pos + normal * m_ClipPlaneOffset;
        Matrix4x4 m = cam.worldToCameraMatrix;
        Vector3 cpos = m.MultiplyPoint( offsetPos );
        Vector3 cnormal = m.MultiplyVector( normal ).normalized * sideSign;
        return new Vector4( cnormal.x, cnormal.y, cnormal.z, -Vector3.Dot(cpos,cnormal) );
    }
    
    private void UpdateReflectionCamera(Camera camera)
    {
        Vector3 planeNormal = transform.up;
        Vector3 planePos = transform.position;
        Vector4 clipPlane = CameraSpacePlane(ReflectionCamera, planePos, planeNormal, 1.0f);
        Matrix4x4 projection = ReflectionCamera.CalculateObliqueMatrix(clipPlane);
        ReflectionCamera.projectionMatrix = projection;
        ReflectionCamera.cullingMask = ~(1<<4) & m_ReflectLayers.value; // never render water layer
        ReflectionCamera.clearFlags = CameraClearFlags.SolidColor;

    }


    private void LateUpdate()
    {
        ReflectionCamera.fieldOfView = Camera.main.fieldOfView;
        ReflectionCamera.transform.position = new Vector3(Camera.main.transform.position.x,
            -Camera.main.transform.position.y + transform.position.y, Camera.main.transform.position.z);
        ReflectionCamera.transform.rotation = Quaternion.Euler(-Camera.main.transform.eulerAngles.x, Camera.main.transform.eulerAngles.y, 0f);

        Resolution = new Vector2(Camera.main.pixelWidth, Camera.main.pixelHeight);
        
        ReflectionRenderTexture.Release();
        ReflectionRenderTexture.width = Mathf.RoundToInt(Resolution.x) * ReflectionResloution / Mathf.RoundToInt(Resolution.y);
        ReflectionRenderTexture.height = ReflectionResloution;
    }
}
