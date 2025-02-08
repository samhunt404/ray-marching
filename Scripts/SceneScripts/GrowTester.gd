class_name GrowTester extends Area3D

@onready var coll := $CollisionShape3D
@onready var ray := $RayCast3D
var index := 0
var res = 0.004
var coord : Vector2i
var tex : Image
var texIndex := 0

var foundNearest := false
var currDis := 0.0

var foundSign := false
var collCount := 0
@onready var currentPos := global_position

signal pixelReady

var currentlyWriting = false
func _ready() -> void:
	coll.scale = Vector3.ONE * 0.001

func _physics_process(_delta) -> void:
	if not foundSign:
		ray.global_position = currentPos
		ray.target_position = Vector3(0,0,5)
		ray.force_raycast_update()
		if(ray.is_colliding()):
			collCount += 1
			currentPos = ray.get_collision_point()
			return
		else:
			foundSign = true
	if not foundNearest:
		var s = 1 if collCount % 2 == 0 else -1
		coll.scale += Vector3.ONE * res * s
		if(coll.scale.x > 1.5 || get_overlapping_bodies().size() > 0):
			foundNearest = true
			currDis = coll.scale.x
		else:
			return
	if foundNearest and foundSign and not currentlyWriting:
		currentlyWriting = true
		_write_texture()


func _write_texture() -> void:
	var dis := currDis
	if(collCount % 2 == 0):
		dis = dis + 0.5
	else:
		dis = 0.5 - dis
	var color = Color.WHITE
	color.v = dis
	tex.set_pixel(coord.x,coord.y,color)
	pixelReady.emit(index)

func _reset() -> void:
	foundSign = false
	ray.global_position = global_position
	foundNearest = false
	currentlyWriting = false
	pass
