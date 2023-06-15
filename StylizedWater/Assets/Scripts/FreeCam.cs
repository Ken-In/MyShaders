using UnityEngine;
using UnityEngine.EventSystems;

public enum CamViewMode
{
    FREE,
    TOP,
    LIMIT
}
public class FreeCam : MonoBehaviour
{
    private Transform camTrans;

    private bool _isFirstClick = true;

    public CamViewMode viewMode = CamViewMode.FREE;

    [SerializeField]
    private Vector3 _resetTrans;
    private Vector3 _resetAngles;

    public float m_speed = 3f;
    public float m_mSpeed = 0.5f;
    public float m_rSpeed = 5f;
    public float m_sSpeed = 5f;
    public float m_maxDistance = 10f;
    public float moveSmoothing = 0.2f;

    private float m_deltX = 0f;
    private float m_deltY = 0f;

    void Start()
    {
        camTrans = transform;
    }
    void Update()
    {

        if (viewMode != CamViewMode.LIMIT)
        {
            CameraKeyMove();
            CameraMiddleMove();
            CameraRotate();
            CameraScale();
        }

        CameraMode();

        if (Input.GetKeyUp(KeyCode.Space))
        {
            CameraReset();
        }


    }
    private void CameraMode()
    {
        switch (viewMode)
        {
            case CamViewMode.TOP:
                camTrans.localRotation = Quaternion.Euler(90, camTrans.localRotation.eulerAngles.y, camTrans.localRotation.eulerAngles.z);
                break;
            default:
                break;
        }
    }
    void CameraScale()
    {
        if (Input.GetAxis("Mouse ScrollWheel") != 0)
        {
            float m_distance = Input.GetAxis("Mouse ScrollWheel") * m_sSpeed;
            Vector3 newPos = camTrans.localPosition + camTrans.forward * m_distance;
            //Debug.Log(newPos.magnitude);
            if (newPos.magnitude >= m_maxDistance) return;
            camTrans.localPosition = newPos;
        }
    }
    void CameraRotate()
    {
        if (Input.GetMouseButton(1))
        {
            if (!_isFirstClick)
            {
                m_deltX += Input.GetAxis("Mouse X") * m_rSpeed;
                m_deltY -= Input.GetAxis("Mouse Y") * m_rSpeed;
            }
            else
            {
                _isFirstClick = false;
                m_deltX = _resetAngles.y;
                m_deltY = _resetAngles.x;
            }

            m_deltX = ClampAngle(m_deltX, -360, 360);
            m_deltY = ClampAngle(m_deltY, -70, 70);

            camTrans.localRotation = Quaternion.Euler(m_deltY, m_deltX, 0);
        }

    }
    void CameraKeyMove()
    {
        if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow))
        {
            camTrans.Translate(Vector3.forward * Time.deltaTime * m_speed);
        }
        if (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow))
        {
            camTrans.Translate(Vector3.back * Time.deltaTime * m_speed);
        }
        if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow))
        {
            camTrans.Translate(Vector3.left * Time.deltaTime * m_speed);
        }
        if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow))
        {
            camTrans.Translate(Vector3.right * Time.deltaTime * m_speed);
        }
    }
    void CameraMiddleMove()
    {
        if (Input.GetMouseButton(2))
        {
            float dx = Input.GetAxis("Mouse X");
            float dy = Input.GetAxis("Mouse Y");
            Vector3 yz = camTrans.forward + camTrans.up;
            yz.y = 0;
            Vector3 TargetLookAt = camTrans.position;
            TargetLookAt -= (yz * dy + transform.right * dx) * m_mSpeed;
            camTrans.position = Vector3.Lerp(camTrans.position, TargetLookAt, moveSmoothing);
        }
    }
    public void CameraReset()
    {
        camTrans.localPosition = _resetTrans;
        camTrans.localRotation = Quaternion.Euler(_resetAngles);
    }
    float ClampAngle(float angle, float minAngle, float maxAgnle)
    {
        if (angle <= -360)
            angle += 360;
        if (angle >= 360)
            angle -= 360;

        return Mathf.Clamp(angle, minAngle, maxAgnle);
    }

}

