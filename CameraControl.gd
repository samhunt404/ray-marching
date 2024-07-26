extends Camera3D

var controlToggle := false
@export var sensitivity := 0.5
@export var speed := 20.0

func _process(delta):
	var x := float(Input.is_action_pressed("right")) - float(Input.is_action_pressed("left"))
	var y := float(Input.is_action_pressed("up")) - float(Input.is_action_pressed("down"))
	var z := float(Input.is_action_pressed("backward")) - float(Input.is_action_pressed("forward"))
	
	var d = Vector3(x,y,z) * delta * speed
	#error catching
	if(rotation.length() > 0):
		d = d.rotated(rotation.normalized(),rotation.length())
	
	position += d * delta * speed

func _input(event):
	if(event.is_action_pressed("Hold_Control")):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		controlToggle = true
	if(event.is_action_released("Hold_Control")):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		controlToggle = false
	
	if(event is InputEventMouseMotion and controlToggle):
		rotation_degrees.x -= event.relative.y * sensitivity
		rotation_degrees.y -= event.relative.x * sensitivity
