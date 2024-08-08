extends Area3D

@onready var coll = $CollisionShape3D
var dis : float
var tex : Image
var coord : Vector2i
var positive := false
signal collided
# Called when the node enters the scene tree for the first time.
func _enter_tree() -> void:
	scale = Vector3(1,1,1)
	var rays := get_children()
	for c in rays:
		if(c is RayCast3D):
			
			c.force_raycast_update()
			if not c.is_colliding():
				
				positive = true
	scale = Vector3.ONE * 0.01
	if(not positive):
		print("Positive negativity")
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	if(get_overlapping_bodies().size() == 0 and scale.x < 1):
		
		scale += Vector3.ONE * 0.02
		dis = scale.x #scale should be uniform
	else:
		if positive:
			dis += 0.5
		else:
			dis = 0.5 - dis
		dis = clamp(dis,0,1)
		tex.set_pixel(coord.x,coord.y,Color(dis,dis,dis))
		collided.emit()
		queue_free()
		pass
