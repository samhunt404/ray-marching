#[compute]
#version 460

// invocations in the (x y z) dimension
layout(local_size_x = 3, local_size_y = 3, local_size_z = 3) in;

layout(r32f, set = 0, binding = 0) restrict uniform image3D StartImage;
layout(r32f, set = 0, binding = 1) restrict uniform image3D OutImage;
layout(set = 0, binding = 2,std430) restrict buffer JumpFloodData
{
    float stepLength;
    int passNum;
}

void main()
{
    // r/w texture coordinates
    vec3 texCoord = vec3(gl_WorkGroupID);
    // coordinates to check
    vec3 testCoord = vec3(gl_WorkGroupID + (gl_LocalInvocationID - uvec3(1)) * stepLength);

    vec4 col = imageLoad(StartImage,testCoord);
    
    if(col == vec4(1.0,1.0,0.0,0.0))
    {

    }else
    {
        
    }
}