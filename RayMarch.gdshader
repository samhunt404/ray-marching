shader_type spatial;

uniform int stepCount = 1000;
uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D scene_texture : hint_screen_texture;
varying vec3 position;
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
void vertex() {
	POSITION = vec4(VERTEX,1.0);
	position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
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
	vec3 pixel_position = world_pos;
	////set alpha to 0 initially
	ALBEDO = texture(scene_texture,SCREEN_UV).rgb;
	int currStep = 0;
	float trueDepth = 0.0;
	for(int i = 0;i<stepCount;i++)
	{
		float sd = sdTorus(pixel_position,vec2(0.5,0.1));
		//pixel_position +=  -(INV_VIEW_MATRIX * vec4(VIEW,1.0)).xyz * 0.001;
		pixel_position +=  -view_dir * sd;
		trueDepth += sd;
		//pixel_position += -(INV_VIEW_MATRIX * vec4(VIEW,1.0)).xyz * sd;
		currStep ++;
		//don't continue if you've overshot
		if(sd > 10000.0)
		{
			//this may cause performance loss with fragments having differing loop sizes
			//typically shaders don't like branching logic
			break;
		}
		if(abs(sd) < 0.001)
		{
			//this may cause performance loss with fragments having differing loop sizes
			ALBEDO = vec3(1.0,0.0,0.0) - vec3(trueDepth/5000.0);
			break;
		}
	}
}

void light() {
	//disables lighting effects, but allows for control
	DIFFUSE_LIGHT = vec3(1.0);
}
