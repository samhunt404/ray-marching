shader_type spatial;

uniform float smoothing = 0.2;
uniform float minStep =  0.001;
uniform int stepCount = 100;
uniform float tolerance = 0.01;
uniform float lod = 0.5;
uniform ivec3 resolution = ivec3(21);
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

vec3 round_to_resolution(vec3 position)
{
	return round(position / vec3(resolution)) * vec3(resolution);
}
float raycast(vec3 dir,vec3 pos)
{
	vec3 dir_rad = dir * PI;
	vec3 cursor_position = pos;
	int curr_step = 0;
	float true_depth = 0.0;
	bool overshot;
	bool hit;
	float should_end = 1.0;
	
	for(int i = 0; i < stepCount;i++)
	{
		float distance_read = sceneSDF(cursor_position);
		overshot = distance_read > 256.0; //arbitrarily large value
		hit = abs(distance_read) <  tolerance;
		
		should_end = float(!(overshot || hit));
		
		//pixel_position +=  -(INV_VIEW_MATRIX * vec4(VIEW,1.0)).xyz * 0.001;
		vec3 ray = (dir * max(distance_read,minStep) * should_end);
		
		cursor_position += ray;
		curr_step += int(!overshot);	
	}
	float zvalue;
	float yvalue;
	float xvalue;
	
	//sample z walls
	vec3 cursor_position_z = cursor_position;
	cursor_position_z.z = round_to_resolution(cursor_position_z).z;
	cursor_position_z.x = (atan(dir.z/-dir.x)) + cursor_position_z.x;
	cursor_position_z.y = (atan(dir.z/-dir.y)) + cursor_position_z.y;
	
	//sample y walls
	vec3 cursor_position_y = cursor_position;
	cursor_position_y.y = round_to_resolution(cursor_position_y).y;
	cursor_position_y.x = (atan(dir.y/-dir.x)) + cursor_position_y.x;
	cursor_position_y.z = (atan(dir.y/-dir.z)) + cursor_position_y.z;
	
	//sample x walls
	vec3 cursor_position_x = cursor_position;
	cursor_position_x.x = round_to_resolution(cursor_position_x).x;
	cursor_position_x.y = (atan(dir.x/-dir.y)) + cursor_position_x.y;
	cursor_position_x.z = (atan(dir.x/-dir.z)) + cursor_position_x.z;
	
	float disx = distance(cursor_position,cursor_position_x);
	float disy = distance(cursor_position,cursor_position_y);
	float disz = distance(cursor_position,cursor_position_z);
	
	float minDis = min(min(disx,disy),disz);
	
	//also tells us normal
	if(minDis == disx)
	{
		cursor_position = cursor_position_x;
	}
	if(minDis == disy)
	{
		cursor_position = cursor_position_y;
	}
	if(minDis == disz)
	{
		cursor_position = cursor_position_z;
	}
	
	return distance(cursor_position_z,pos);
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
	
	vec3 view_rad = (view_dir + vec3(1.0)) * 0.5 * PI;
	
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
	ALBEDO = color;
	EMISSION = vec3(float(overshot) * ALBEDO);
	
}

// 
