shader_type spatial;
render_mode unshaded;

uniform int stepCount = 100;
uniform float tolerance = 0.001;
uniform sampler2D debugRainbow;
uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D scene_texture : hint_screen_texture;
uniform sampler3D SceneScalarField;

varying bool shown;
varying vec3 currPos;

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
	float sphereDis = sdfSphere(p,vec3(0.0,1.0,0.0),0.25);
	float squareDis = sdfCube(p,vec3(0.0,-1.0,0.0),0.5);
	float torusDis = sdTorus(p,vec2(0.5,0.1));
	//this small constant is just 1/256, slightly easier to multiply vectors than devide
	//normalzes position to uv
	vec3 adjPos = p * 0.00390625;
	//clipping value, 0 if outside boudns, 1 if in. prevents scene from tiling infinitely
	float clip = float(max(max(adjPos.x,adjPos.y),adjPos.z) < 1.0 && min(min(adjPos.x,adjPos.y),adjPos.z) > 0.0);
	float raw = texture(SceneScalarField,p * 0.00390625).x;
	float signed = (raw - 0.5) * clip; 
	//I imagine you can scale this signed value and it just scales the litteral size of the scene, though I don't know that to be true
	
	return signed;
	//return min(min(sphereDis,torusDis),squareDis);
}
void vertex() {
	//POSITION = vec4(VERTEX,0.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0);
	vec4 view_coords = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_coords.xyz /= view_coords.w;

	vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_coords.xyz, 1.0)).xyz;
	vec3 obj_position = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;

	vec3 cam_pos = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 view_dir = normalize(obj_position - cam_pos);
	
	//get current position of pixel in world space
	vec3 pixel_position = CAMERA_POSITION_WORLD;
	////set alpha to 0 initially
	int currStep = 0;
	float trueDepth = 0.0;
	bool overshot;
	bool undershot;
	for(int i = 0;i<stepCount;i++)
	{
		float sd = sceneSDF(pixel_position);
		overshot = sd > 10000.0; //arbitrarily large value
		undershot = abs(sd) < tolerance; //arbitrarily small value
		float shouldEnd = float(!(overshot || undershot)); //1 if chill, 0 if not
		
		vec3 color = texture(debugRainbow,vec2(trueDepth * 0.001)).xyz;
		//weird way of doing a shader-style 
		ALBEDO = float(undershot) * (color)  + float(!undershot) * texture(scene_texture,SCREEN_UV).rgb;
		
		//pixel_position +=  -(INV_VIEW_MATRIX * vec4(VIEW,1.0)).xyz * 0.001;
		pixel_position +=  view_dir * sd * shouldEnd;
		trueDepth += sd * shouldEnd;
		//pixel_position += -(INV_VIEW_MATRIX * vec4(VIEW,1.0)).xyz * sd;
		currStep += int(!overshot);
		
	}
	currPos = pixel_position;
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
