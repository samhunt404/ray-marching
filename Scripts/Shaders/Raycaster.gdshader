shader_type spatial;
render_mode unshaded;

uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D mapTex : filter_nearest;
uniform float debugangle;

const float P2 = PI/2.0;
const float P3 = 3.0 * PI / 2.0;

float line_segment_distance(vec2 v, vec2 w, vec2 p) {
  // Return minimum distance between line segment vw and point p
  float l2 = (abs(w.x - v.x) * abs(w.x - v.x)) + (abs(w.y - v.y) * abs(w.y - v.y));
  if (l2 == 0.0) return distance(p, v);   // v == w case
  // Consider the line extending the segment, parameterized as v + t (w - v).
  // We find projection of point p onto the line. 
  // It falls where t = [(p-v) . (w-v)] / |w-v|^2
  // We clamp t from [0,1] to handle points outside the segment vw.
  float t = max(0, min(1, dot(p - v, w - v) / l2));
  vec2 projection = v + t * (w - v);  // Projection falls on the segment
  return distance(p, projection);
}

vec2 minDis(vec2 a, vec2 b, vec2 o)
{
	float disA = distance(o,a);
	float disB = distance(o,b);
	
	return disA < disB ? a : b;
}

void fragment() 
{
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0);
	vec4 view_coords = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_coords.xyz /= view_coords.w;

	//do math in object space
	vec3 cam_pos = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 view_dir = -(inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * vec4(VIEW,0.0)).xyz;
	
	
	//needed values
	vec2 view_dir_xy_norm = normalize(view_dir.xz);
	float ray_angle = atan(view_dir_xy_norm.y,view_dir_xy_norm.x);
	ray_angle = mod(ray_angle,TAU);
	vec2 ray_offset;
	
	vec2 player_in_map = cam_pos.xz * 0.2 + 0.5;
	vec2 ray_pos;
	float invTan = -1.0/tan(ray_angle); //unsure, dunno why you would take the invTangent of an angle, perhaps just tangent
	
	vec2 hDis;
	vec2 vDis;
	
	//---- check horizontal lines ----
	if(ray_angle > PI) //looking up
	{
		ray_pos.y = floor(player_in_map.y * 128.0) / 128.0;
		ray_pos.x = (player_in_map.y - ray_pos.y) * invTan + player_in_map.x;
		ray_offset.y = -1.0/128.0;
		ray_offset.x = -ray_offset.y * invTan;
	}
	if(ray_angle < PI) //looking up
	{
		ray_pos.y = floor(player_in_map.y * 128.0 + 1.0) / 128.0;
		ray_pos.x = (player_in_map.y - ray_pos.y) * invTan + player_in_map.x;
		ray_offset.y = 1.0/128.0;
		ray_offset.x = -ray_offset.y * invTan;
	}
	if(ray_angle == 0.0)
	{
		ray_pos = player_in_map;
	}
	
	for(int i = 0; i < 12; i++)
	{
		bool hit = texture(mapTex,ray_pos).r <= 0.001;
		//i += 12 * int(hit);
		ray_pos += ray_offset * float(!hit);
	}
	hDis = ray_pos;
	//---- check vertical lines ----
	
	float ntan = -invTan;
	if(ray_angle > P2 && ray_angle < P3) //looking up
	{
		ray_pos.x = floor(player_in_map.x * 128.0) / 128.0;
		ray_pos.y = (player_in_map.x - ray_pos.x) * ntan + player_in_map.y;
		ray_offset.x = -1.0/128.0;
		ray_offset.y = -ray_offset.x * ntan;
	}
	if(ray_angle < P2 || ray_angle > P3) //looking up
	{
		ray_pos.x = floor(player_in_map.x * 128.0 + 1.0) / 128.0;
		ray_pos.y = (player_in_map.x - ray_pos.x) * ntan + player_in_map.y;
		ray_offset.x = 1.0/128.0;
		ray_offset.y = -ray_offset.y * ntan;
	}
	if(ray_angle == 0.0)
	{
		ray_pos = player_in_map;
	}
	
	for(int i = 0; i < 12; i++)
	{
		bool hit = texture(mapTex,ray_pos).r <= 0.001;
		//i += 12 * int(hit);
		ray_pos += ray_offset * float(!hit);
	}
	vDis = ray_pos;
	
	float hitDistance  = min(distance(player_in_map,hDis),distance(player_in_map,vDis));
	
	vec2 hitpoint = (view_dir_xy_norm  * hitDistance) + player_in_map;
	
	
	
	
	//draw map
	//ALBEDO = texture(mapTex,SCREEN_UV).rgb;
	//if(distance(SCREEN_UV,player_in_map) < 0.01)
	//{
		//ALBEDO = vec3(0.05,0.05,0.2);
	//} 
	//if(distance(SCREEN_UV,hitpoint) < 0.01)
	//{
		//ALBEDO = vec3(0.2,0.05,0.05);
	//}
	ALBEDO.r -= hitDistance;
	
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
