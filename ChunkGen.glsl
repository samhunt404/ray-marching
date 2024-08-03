#[compute]
#version 450

// invocations in the (x y z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(r32f, set = 0, binding = 0) uniform restrict readonly image3D chunkTex;
layout(r32f, set = 1, binding = 0) uniform restrict writeonly image3D sdfOut;
layout(r32f, set = 2, binding = 0) uniform restrict writeonly image3D colorOut;


void main()
{
    
}