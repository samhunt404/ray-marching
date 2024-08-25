extends Node3D

const RAYLENGTH = 1000.0

@export var drawSpeed := 0.1
@export var imageSize : int
@export_node_path("Camera3D") var camera
@export_node_path("MeshInstance3D") var cubeMesh

@onready var activeCam : Camera3D = get_node(camera)
@onready var activeMesh : MeshInstance3D = get_node(cubeMesh)

enum Brush {
	Box,
	Sphere,
	Eraser
}
var brushSize : float
var brushType : Brush = Brush.Sphere
var brushColor : Color

var SceneTex : ImageTexture3D

var rd : RenderingDevice

var scene_tex_id : RID
var transformBuffer : RID


var uniform_set : RID
var pipeline : RID

var ray_from : Vector3
var ray_to : Vector3
var planeDis : float
var queDraw := false


func _init_gpu() -> void:
	
	rd = RenderingServer.create_local_rendering_device()
	
	var shader_file := load("res://Scripts/ComputeShaders/Draw.glsl")
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)

	#unsure about all these formats, but it seems to function
	var sdfFormat = RDTextureFormat.new()
	sdfFormat.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	sdfFormat.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	sdfFormat.width = imageSize
	sdfFormat.height = imageSize
	sdfFormat.depth = imageSize
	sdfFormat.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
			
	#prep texture buffer, data will be set later
	scene_tex_id = rd.texture_create(sdfFormat,RDTextureView.new())
	var sdf_uniform := RDUniform.new()
	sdf_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	
	sdf_uniform.binding = 0 #matches the binding in the compute shader
	sdf_uniform.add_id(scene_tex_id)
	var byteArr = PackedByteArray([])
	for i in range(imageSize):
		var sdfBytes = SceneTex.get_data()[i].get_data()
		byteArr.append_array(sdfBytes)
	rd.texture_update(scene_tex_id,0,byteArr)
	
	uniform_set = rd.uniform_set_create([sdf_uniform],shader,0)
	pipeline = rd.compute_pipeline_create(shader)

func _pass_buffer(pos : Vector3) -> void:
	
	var data = PackedFloat32Array([
		pos.x,
		pos.y,
		pos.z,
		0.0, #buffer cause vectors are weird in gpu, vec3 is a vec4
		#endpos.x,
		#endpos.y,
		#endpos.z,
		brushSize,
		float(brushType == Brush.Sphere),
		float(brushType == Brush.Eraser),
		0.0,
		brushColor.r,
		brushColor.g,
		brushColor.b,
		1.0
		#expects extra bytes thanks to multiplicity issues (I think, math is hard)
		])
	
	
	var compute_list := rd.compute_list_begin()
	#little confused by this
	
	rd.compute_list_bind_compute_pipeline(compute_list,pipeline)
	rd.compute_list_bind_uniform_set(compute_list,uniform_set,0)
	
	rd.compute_list_set_push_constant(compute_list,data.to_byte_array(),data.size() * 4)
	
	rd.compute_list_dispatch(compute_list,imageSize,imageSize,imageSize)
	rd.compute_list_end()
	rd.submit()
	#should probably not call sync right after
	rd.sync()
	var tempSDFData = rd.texture_get_data(scene_tex_id,0)
	var SDFImgArr = Array([])
	for i in range(imageSize):
		var cropSDFData = tempSDFData.slice(i * 4 * imageSize * imageSize, (i + 1) * 4 * imageSize * imageSize)
		var SDFImg = Image.create_from_data(imageSize,imageSize,false,Image.FORMAT_RGBA8,cropSDFData)
		SDFImgArr.append(SDFImg)
		#multiply by 4 here to account for the r g b a chanels
	SceneTex.update(SDFImgArr)

func _ready() -> void:
	
	var arr := Array([])
	arr.resize(imageSize)
	#create a temprorary texture
	var dummyTex := Image.create(imageSize,imageSize,false,Image.FORMAT_RGBA8)
	dummyTex.fill(Color(0,0,0,1.0))
	arr.fill(dummyTex)
	SceneTex = ImageTexture3D.new()
	
	#TODO: test with mipmaps true (also look at CompressedImageTexture3D)
	SceneTex.create(Image.FORMAT_RGBA8,imageSize,imageSize,imageSize,false,arr)
	
	
	activeMesh.get_active_material(0).set_shader_parameter("minStep",1.0/float(imageSize))
	activeMesh.get_active_material(0).set_shader_parameter("SceneTex",SceneTex)
	_init_gpu()
	
	

func _physics_process(_delta: float) -> void:
	if(queDraw):
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(ray_from,ray_to)
		var result := space_state.intersect_ray(query)
		#stop if we hit nothing
		if(result.is_empty()):
			return
		var drawPos : Vector3 = result.position
		#set a distance
			
		_march(drawPos,(drawPos - query.from).normalized())

func _exit_tree() -> void:
	ResourceSaver.save(SceneTex,"res://Assets/Textures/WriteTest.tres")
	
func _march(pos : Vector3,dir : Vector3) -> void:
	var result := false
	var startPixel = to_local(pos)* imageSize
	var currentPixel = startPixel
	currentPixel.clamp(Vector3(0,0,0),Vector3(imageSize,imageSize,imageSize))

	#slowdown here, too many itteration
	while not result:
		#constrain cursor
		currentPixel = currentPixel.maxf(0)
		currentPixel = currentPixel.minf(imageSize  - 1)
		var pix := SceneTex.get_data()[int(currentPixel.z)].get_pixel(int(currentPixel.x),int(currentPixel.y)).a
		pix -= 0.5
		pix *= 2.0
		#IN THEORY you can adjust this by the pix value to reduce itteration count
		currentPixel += dir;
		var posMax = max(currentPixel.x,currentPixel.y,currentPixel.z)
		var posMin = min(currentPixel.x,currentPixel.y,currentPixel.z)
		
		#don't draw until you're past the plane
		if(startPixel.distance_to(currentPixel) < planeDis and planeDis > 0):
			currentPixel += dir * planeDis
		
		if(pix < 0.125 or posMax >= imageSize - 1 or posMin <= 0):
			result = true
			_pass_buffer(currentPixel)
			#set draw depth on first drawn pixel
			if(planeDis == 0):
				planeDis = startPixel.distance_to(currentPixel)
			break

func _input(event : InputEvent) -> void:
	if(event.is_action_pressed("Draw_Pixel")):
		#arbitrarily large value
		planeDis = 0
		ray_from = activeCam.project_ray_origin(event.position)
		ray_to = ray_from + activeCam.project_ray_normal(event.position) * RAYLENGTH
		queDraw = true
	if(event.is_action_released("Draw_Pixel")):
		queDraw = false
	if(event is InputEventMouseMotion and queDraw):
		ray_from = activeCam.project_ray_origin(event.position)
		#offset it behind the camera quite a ways so that the collision happens even if the
		#camera is inside the collider
		ray_from -= activeCam.project_ray_normal(event.position) * (RAYLENGTH/4.0) 
		
		ray_to = ray_from + activeCam.project_ray_normal(event.position) * RAYLENGTH
		
func _set_brush_size(newsize : float) -> void:
	brushSize = newsize

func _set_square() -> void:
	brushType = Brush.Box
func _set_sphere() -> void:
	brushType = Brush.Sphere
func _set_eraser() -> void:
	brushType = Brush.Eraser

func _set_color(newCol : Color) -> void:
	brushColor = newCol
	
