#[compute]
#version 460

// invocations in the (x y z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(r8, set = 0, binding = 0) restrict uniform image3D scene_tex;

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
    //find proper sdfVal
    float pixels = sdfSphere(coord,vec3(params.start.xyz),params.brushSize);
    float pixelc = sdfCube(coord,vec3(params.start.xyz),params.brushSize);

    float pixelv = (pixels * (params.sphere)) + (pixelc * (1.0 - params.sphere));

    float readDistance = imageLoad(scene_tex,coord).a;
    
    //only draw if the calculated sdfVal is less than the read sdfVal at current coordinates
    float pixeld = min(pixelv,readDistance);

    //erasing is litterally inverse of drawing, isn't perfect because of noise so the eraser size tends to be smaller than the brush
    float pixele = max(1.0 - pixelv,readDistance);

    float sdfVal = (pixeld * (1.0 - params.erase)) + (pixele * (params.erase)); //one of these values will be zero
    
    float brushAdg = max(params.brushSize + 0.3,1.0);
    float drawc = sdfCube(coord,(vec3(params.start ) + vec3(0.5 *gl_NumWorkGroups)) * 0.5,brushAdg) * (1.0-params.sphere);
    float draws = sdfSphere(coord,(vec3(params.start) + vec3(0.5 * gl_NumWorkGroups)) * 0.5,brushAdg) * (params.sphere);
    float draw = float(drawc + draws < 0.5);

    vec3 pixelColRead = imageLoad(scene_tex,coord).rgb;

    //coordinates are very off, but only in this calculat
    vec4 pixelCol = mix(vec4(pixelColRead,1.0),params.col,draw);

    imageStore(scene_tex,coord,vec4(pixelCol.rgb,sdfVal));
}