extends Node3D

var thread : Thread
var coord : Vector2i
var tex : Image

@onready var nodeTransform := global_transform
@onready var currentPosition := global_position
var dis := 0.0
var intersectCount := 0
var query : PhysicsRayQueryParameters3D
var result : Dictionary
var foundPositive := false

var space_state : PhysicsDirectSpaceState3D
signal collided
func  _ready() -> void:
	query = PhysicsRayQueryParameters3D.create(global_position,global_position + Vector3(0,0,5))
func _physics_process(_delta: float) -> void:
	get_distance()

#func _physics_process(_delta: float) -> void:
	#get_distance()
	

func get_distance() -> void:
	var space_rid := get_world_3d().space
	space_state = PhysicsServer3D.space_get_direct_state(space_rid)
	var sresult : Array
	var foundEnd = false
	if dis < 1.5 and not foundEnd:
		var shape := SphereShape3D.new()
		shape.radius = dis
		var squery := PhysicsShapeQueryParameters3D.new()
		squery.shape = shape
		squery.transform = nodeTransform
		
		sresult = space_state.intersect_shape(squery)
		if(sresult.size() > 0):
			foundEnd = true
		else:
			dis += 0.01
			return
	
	var positive := false
	#from and to in global coordinates
	#don't run the condition if we never hit the collider
	
	if not foundPositive:
		#march slightly forward to prevent getting stuck on a surface
		query.from = currentPosition + Vector3(0,0,0.001)
		query.to = currentPosition + Vector3(0,0,5)
		result = space_state.intersect_ray(query)
		
		if(result.is_empty()):
			foundPositive = true
		else:
			currentPosition = result.position
			intersectCount += 1
			return
	#even number of collisions means ray started outside the mesh
	positive = (intersectCount % 2 == 0)
	var color := Color.WHITE
	
	if(positive):
		color.v = dis + 0.5
	else:
		color.v = 0.5 - dis
	tex.set_pixel(coord.x,coord.y,color)
	
	collided.emit()
	queue_free()
