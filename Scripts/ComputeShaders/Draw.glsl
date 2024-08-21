#[compute]
#version 460

// invocations in the (x y z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(r8, set = 0, binding = 0) restrict uniform image3D SDF_Tex;
layout(rgba8, set = 0, binding = 1) restrict uniform image3D Col_Tex;

layout(push_constant, std430) uniform Params
{
    vec4 start;
    //vec4 end; //for a potential optimization to draw lines instead of dots
    float brushSize;
    float sphere;
    float erase;
    vec4 col;
}params;

float sdfSphere(vec3 p, vec3 o, float size)
{
    float trueSDF =  length(o-p) - size;
    trueSDF /= gl_NumWorkGroups.x;
    trueSDF += 0.5;

    return min(max(trueSDF,0.0),1.0);
}
float sdfCube(vec3 p, vec3 o, float size)
{
    vec3 diff = abs(p-o) - size;
    diff = diff/gl_NumWorkGroups.x;
    diff += 0.5;
    float trueSDF = max(max(diff.x,diff.y),diff.z);
    return min(max(trueSDF,0.0),1.0);
}

void main()
{
    ivec3 coord = ivec3(gl_WorkGroupID.xyz);
    //find proper pixel
    //for some reason offset by 1 byte meaning x value is always 0
    float pixels = sdfSphere(coord,vec3(params.start.xyz),params.brushSize);
    float pixelc = sdfCube(coord,vec3(params.start.xyz),params.brushSize);

    float pixelv = (pixels * (params.sphere)) + (pixelc * (1.0 - params.sphere));

    float readPixel = imageLoad(SDF_Tex,coord).r;
    
    //only draw if the calculated pixel is less than the read pixel
    vec4 pixeld = vec4(min(pixelv,readPixel));

    //erasing is litterally inverse of drawing, isn't perfect because of noise so the eraser size tends to be smaller than the brush
    vec4 pixele = vec4(max(1.0 - pixelv,readPixel));

    vec4 pixel = (pixeld * (1.0 - params.erase)) + (pixele * (params.erase)); //one of these values will be zero

    bool draw = (pixelv <= readPixel) && (params.erase < 0.99);
    vec4 pixelColr = imageLoad(Col_Tex,coord);

    vec4 pixelCol = (params.col * float(draw)) + (pixelColr * float(!draw)); //once again one of these will be zero

    imageStore(SDF_Tex,coord,pixel);
    imageStore(Col_Tex,coord,pixelCol);
}