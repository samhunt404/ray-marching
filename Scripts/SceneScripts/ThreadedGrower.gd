class_name ThreadedGrower extends Node3D


var rayQuery : PhysicsRayQueryParameters3D
var collQuery : PhysicsShapeQueryParameters3D

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
	collQuery = PhysicsShapeQueryParameters3D.new()
	collQuery.shape = SphereShape3D.new()
	collQuery.shape.radius = 0.001
	collQuery.transform.origin = currentPos
	
	rayQuery = PhysicsRayQueryParameters3D.create(currentPos,currentPos + Vector3(0,0,5))
	rayQuery.collide_with_bodies = true
	rayQuery.hit_back_faces = true
	rayQuery.hit_from_inside = true

func _physics_process(_delta) -> void:
	var space_state := get_world_3d().direct_space_state
	if not foundSign:
		rayQuery.from = currentPos + Vector3(0,0,0.0)
		rayQuery.to = currentPos + Vector3(0,0,5)
		var collisionData = space_state.intersect_ray(rayQuery)
		
		if(collisionData.is_empty()):
			foundSign = true
		else:
			collCount += 1
			currentPos = collisionData.position
			return

	if not foundNearest:
		collQuery.transform.origin = global_position
		collQuery.shape.radius += res
		var collisionData = space_state.intersect_shape(collQuery)
		if(collQuery.shape.radius > 1.5 || collisionData.size() > 0):
			foundNearest = true
			currDis = collQuery.shape.radius
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
	var color = Color.BLACK
	color.a = dis
	tex.set_pixel(coord.x,coord.y,color)
	pixelReady.emit(index)

func _reset() -> void:
	foundSign = false
	rayQuery.from = global_position
	rayQuery.to = global_position + Vector3(0,0,5)
	currentPos = global_position
	collCount = 0
	
	collQuery.shape.radius = 0.001
	foundNearest = false
	currentlyWriting = false
	pass
