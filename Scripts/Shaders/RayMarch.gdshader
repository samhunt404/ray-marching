shader_type spatial;

uniform float smoothing = 0.2;
uniform float minStep =  0.001;
uniform int stepCount = 100;
uniform float tolerance = 0.01;
uniform float lod = 0.5;
uniform vec3 base_col : source_color;

uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler3D SceneTex : filter_nearest;

float sceneSDF(vec3 p)
{
	vec3 adjP = p+vec3(0.5);
	//convert p from object to texture space
	float raw = textureLod(SceneTex,adjP,lod).a;
	//declaring bounds between 0 and 1
	if(adjP.x <= 0.0 ||
	 adjP.y <= 0.0 ||
	 adjP.z <= 0.0 ||
	 adjP.x >=1.0 ||
	 adjP.y >= 1.0 ||
	 adjP.z >= 1.0)
	{
		raw = 0.0;
	}
	
	//clip+1.0-clip should just be 1 always but just multiplying it by 1 doesn't work so...
	float signed = (1.0-raw);
	return signed;
}
vec3 sceneNormal(vec3 p)
{
	float devStep = 1.0/float(textureSize(SceneTex,0).x) * smoothing;
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
		vec3 ray = (view_dir * max(sd,minStep) * shouldEnd);
		
		pixel_position += ray;
		trueDepth += sd * shouldEnd;
		//pixel_position += -(INV_VIEW_MATRIX * vec4(VIEW,1.0)).xyz * sd;
		currStep += int(!overshot);

	}
	vec3 color = textureLod(SceneTex,(pixel_position + 1.0)/2.0,lod).rgb * base_col;

	NORMAL = (VIEW_MATRIX * MODEL_MATRIX * vec4(sceneNormal(pixel_position),0.0)).xyz;
	//alpha to hide parts of mesh which shouldn't be visible (other ways of doing this may be better)
	ALPHA = float(undershot);
	ALBEDO = (color);
	EMISSION = vec3(float(overshot) * ALBEDO);
}

void light() {
	//diffuse
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR;
	//shadow??

}
