extends Node3D

@export var imgSize : int
@export_node_path("ColorPicker") var colPickNode
@export_node_path("VSlider") var brushSize
@export_node_path("Camera3D") var TargetCam
@export_node_path("Node3D") var cube

var sdfImg : ImageTexture3D
var colImg : ImageTexture3D

var draw := false
var origin : Vector3
var target : Vector3

func _set_eraser() -> void:
	pass
func _set_brush() -> void:
	pass

func _ready() -> void:
	var dummyArr := Array([])
	dummyArr.resize(imgSize)
	var dumyImg := Image.create(imgSize,imgSize,true,Image.FORMAT_RGB8)
	dumyImg.fill(Color.WHITE)
	dummyArr.fill(dumyImg)
	
	sdfImg.create(Image.FORMAT_R8,imgSize,imgSize,imgSize,true,dummyArr)
	colImg.create(Image.FORMAT_RGB8,imgSize,imgSize,imgSize,true,dummyArr)
	

func _draw(pos : Vector3, dir : Vector3) -> void:
	var collision := false
	while not collision:
		var transformPos = cube.to_local()
		var coord = Vector3i(transformPos * imgSize)
		
		var sdf = sdfImg.get_data()[coord.z].get_pixel(coord.x,coord.y).r
		sdf -= 0.5
		
	pass

func _physics_process(_delta: float) -> void:
	if(draw):
		draw = false
		var query = PhysicsRayQueryParameters3D.create(origin,target)
		var results : Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		
		if(results):
			var pos : Vector3 = results.position
			var dir : Vector3 = (pos-origin).normalized()
			_draw(pos,dir)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		draw = true
		var cam := $Camera3D
		origin = cam.project_ray_origin(event.position)
		target = origin + cam.project_ray_normal(event.position) * 5000.0
