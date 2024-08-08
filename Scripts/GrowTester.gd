extends Area3D

@onready var coll = $CollisionShape3D
@onready var ray = $RayCast3D
var dis : float
var tex : Image
var coord : Vector2i
var positive := false
signal collided

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	scale = Vector3.ONE * 0.01


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	if(get_overlapping_bodies().size() == 0 and scale.x < 1):
		scale += Vector3.ONE * 0.02
		dis = scale.x #scale should be uniform
	else:
		#test if point is a positive (outside) or negative (inside)
		var spaceRid := get_world_3d().space
		var space := PhysicsServer3D.space_get_direct_state(spaceRid)
		#use global coordinnates
		var query := PhysicsRayQueryParameters3D.create(global_position,global_position + Vector3(0,0,5.0))
		query.hit_back_faces = true
		query.collide_with_areas = false
		var result := space.intersect_ray(query)
		var numCol := 0
		var last_result
		while(not result.is_empty()):
			numCol += 1
			var newStart = result.position			
			query.from = newStart
			query.to = newStart + Vector3(0.0,0.0,5.0)
			last_result = result
			result = space.intersect_ray(query)
			
		positive = (numCol % 2 == 0)
		if positive:
			dis += 0.5
		else:
			dis = 0.5 - dis
		dis = clamp(dis,0,1)
		tex.set_pixel(coord.x,coord.y,Color(dis,dis,dis))
		collided.emit()
		queue_free()
		pass
