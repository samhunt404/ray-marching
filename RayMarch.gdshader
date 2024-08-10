shader_type spatial;
render_mode unshaded;
const vec3 DIR = normalize(vec3(0.25,1,0.25));
uniform float DERRIV_STEP = 0.0625;
uniform float minStep =  0.001;
uniform int stepCount = 100;
uniform float tolerance = 0.01;
uniform vec3 col : source_color;
uniform vec3 env_col : source_color;

uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler3D SceneScalarField : filter_nearest;


float sdfSphere(vec3 point, vec3 sphere_position, float sphere_scale)
{
	return distance(point,sphere_position) - sphere_scale;
}
float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}
float sdfCube(vec3 p,vec3 o,float scale)
{
	float adj = max(max(abs(p.x-o.x),abs(p.y-o.y)),abs(p.z-o.z));
	return adj - scale;
}
float sceneSDF(vec3 p)
{
	vec3 adjP = p+vec3(0.5);
	//clipping value, 0 if outside boudns, 1 if in. prevents scene from tiling infinitely
	float clip = float(max(max(adjP.x,adjP.y),adjP.z) < 1.0 && min(min(adjP.x,adjP.y),adjP.z) > 0.0);
	//convert p from object to texture space
	float raw = texture(SceneScalarField,adjP,1.0).x;
	//clip+1.0-clip should just be 1 always but just multiplying it by 1 doesn't work so...
	float signed = (raw) * clip + (0.5 - clip);
	signed *= 2.0; 
	//I imagine you can scale this signed value and it just scales the litteral size of the scene, though I don't know that to be true
	
	return signed;
	//return min(min(sphereDis,torusDis),squareDis);
}
vec3 sceneNormal(vec3 p)
{
	vec3 norm = vec3(sceneSDF(p + vec3(DERRIV_STEP,0.0,0.0)) - sceneSDF(p - vec3(DERRIV_STEP,0.0,0.0)),
					sceneSDF(p + vec3(0.0,DERRIV_STEP,0.0)) - sceneSDF(p - vec3(0.0,DERRIV_STEP,0.0)),
					sceneSDF(p + vec3(0.0,0.0,DERRIV_STEP)) - sceneSDF(p - vec3(0.0,0.0,DERRIV_STEP)));
	norm = normalize(norm);
	return clamp(norm,normalize(vec3(-1.0)),normalize(vec3(1.0)));
}
void vertex() {
	//POSITION = vec4(VERTEX,0.0);
}

void fragment() {
	vec3 lightDir = (inverse(MODEL_MATRIX) * vec4(DIR,0.0)).xyz;	
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0);
	vec4 view_coords = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_coords.xyz /= view_coords.w;

	vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_coords.xyz, 1.0)).xyz;
	//do math in object space
	vec3 obj_position = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;
	vec3 cam_pos = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 view_dir = -(inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * vec4(VIEW,0.0)).xyz;
	
	//get current position of pixel in obect space
	vec3 pixel_position = cam_pos;
	////set alpha to 0 initially
	int currStep = 0;
	float trueDepth = 0.0;
	bool overshot;
	bool undershot;
	float shouldEnd = 1.0;
	for(int i = 0;i<stepCount;i++)
	{
		float sd = sceneSDF(pixel_position);
		overshot = sd > 256.0; //arbitrarily large value
		undershot = abs(sd) < tolerance; //arbitrarily small value
		shouldEnd = float(!(overshot || undershot)); //1 if chill, 0 if not
		

		//pixel_position +=  -(INV_VIEW_MATRIX * vec4(VIEW,1.0)).xyz * 0.001;
		pixel_position += (view_dir * max(sd,minStep) * shouldEnd);
		trueDepth += sd * shouldEnd;
		//pixel_position += -(INV_VIEW_MATRIX * vec4(VIEW,1.0)).xyz * sd;
		currStep += int(!overshot);
		
	}
	vec3 color = clamp(dot(lightDir,sceneNormal(pixel_position) * 10.0) * col + env_col,vec3(0.0),vec3(1.0));
	//weird way of doing a shader-style 
	ALPHA = float(undershot);
	ALBEDO = (color);
	EMISSION = vec3(float(overshot) * ALBEDO);
}

void light() {
	DIFFUSE_LIGHT = vec3(1.0);
	////disables lighting effects, but allows for control
	//SPECULAR_LIGHT = vec3(0.0);
	//vec3 lightDir = (INV_VIEW_MATRIX * vec4(LIGHT,0.0)).xyz;
	//bool hitObj = false;
	////slight offset to reduce artefacts, smaller values create more banding but are more accurate
	////it seems like there's a math function which would offset it perfectly as the artefacts are predictable
	////but I'm really bad at calculus (or trig, genuinely can't tell with this problem)
	//vec3 pixelPosition = currPos;
	//for(int i=0;i<stepCount;i++)
	//{
		//float sd = sceneSDF(pixelPosition);
		//hitObj = abs(sd) < 0.0001;
		//
		//pixelPosition += lightDir * sd * float(!hitObj);
	//}
	//DIFFUSE_LIGHT = vec3(float(!hitObj));
}
