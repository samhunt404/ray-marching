shader_type spatial;

const vec3 DIR = normalize(vec3(0.75,1,0.25));
uniform float smoothing = 8.0;
uniform float minStep =  0.001;
uniform int stepCount = 100;
uniform float tolerance = 0.01;

uniform vec3 base_col : source_color;

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
}
vec3 sceneNormal(vec3 p)
{
	float devStep = 1.0/float(textureSize(SceneScalarField,0).x) * smoothing;
	mat3 pplus = mat3(
		vec3(p + vec3(devStep,0.0,0.0)),
		vec3(p + vec3(0.0,devStep,0.0)),
		vec3(p + vec3(0.0,0.0,devStep))
	);
	mat3 pminus = mat3(
		vec3(p - vec3(devStep,0.0,0.0)),
		vec3(p - vec3(0.0,devStep,0.0)),
		vec3(p - vec3(0.0,0.0,devStep))
	);
	vec3 norm = vec3(sceneSDF(pplus[0]) - sceneSDF(pminus[0]),
					sceneSDF(pplus[1]) - sceneSDF(pminus[1]),
					sceneSDF(pplus[2]) - sceneSDF(pminus[2]));
	//norm = (norm - sceneSDF(p))/devStep;
	norm = normalize(norm);
	norm = clamp(norm,-1.0,1.0);
	return norm;
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

	//do math in object space
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
		//float sd = sceneSDF(pixel_position);
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
	vec3 color = base_col;

	NORMAL = (VIEW_MATRIX * MODEL_MATRIX * vec4(sceneNormal(pixel_position),0.0)).xyz;
	//alpha to hide parts of mesh which shouldn't be visible (other ways of doing this may be better)
	ALPHA = float(undershot);
	ALBEDO = (color);
	EMISSION = vec3(float(overshot) * ALBEDO);
}

void light() {
	//diffuse
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR;
	
}
