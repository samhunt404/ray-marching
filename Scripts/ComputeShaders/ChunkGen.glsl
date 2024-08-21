#[compute]
#version 460

// invocations in the (x y z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(r32f, set = 0, binding = 0) restrict uniform image3D chunkTex;
layout(r32f, set = 0, binding = 1) restrict readonly uniform image3D objTex;
layout(set = 0, binding = 2,std430) restrict buffer ObjectTransform
{
    vec4 translation;
    vec4 rotation;
    vec4 scale;
}
object_transform;


void main()
{
    
}