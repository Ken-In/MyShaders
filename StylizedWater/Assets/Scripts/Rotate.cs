using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Rotate : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        Transform objectTransform = transform;

        float rotationAmount = rotationSpeed * Time.deltaTime;

        objectTransform.Rotate(rotationAmount, 0f, 0f);
    }

    [SerializeField] private float rotationSpeed = 10f;
}
