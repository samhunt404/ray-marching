extends Node3D

@export var size := 16
@export var growTester : PackedScene
var count: = 0
var imgArr = Array([])

func _ready() -> void:
	for z in range(size):
		var img = Image.create(size,size,false,Image.FORMAT_L8)
		img.crop(size,size)
		imgArr.append(img)
	
	for y in range(size):
		for x in range(size):
			var tester : ThreadedGrower = growTester.instantiate()
			add_child(tester)
			tester.position = Vector3(x,y,0) * (1.0/float(size))
			tester.coord = Vector2i(x,y)
			tester.index = get_children().find(tester)
			tester.pixelReady.connect(_increment_pixel)
			_increment_pixel(tester.index)


func _increment_pixel(i : int) ->void:
	var target = get_children()[i]
	if(target.texIndex < size):
		target.tex = imgArr[target.texIndex]
		target.texIndex += 1
		
		target.position.z += (1.0/float(size))
		target._reset()
		count += 1
	
	if(count % (size * size) == 0):
		print("finished imgage ", count / float(size * size))

	if(count >= (size * size * size)):
		var outTex := ImageTexture3D.new()
		outTex.create(Image.FORMAT_L8,size,size,size,false,imgArr)
		ResourceSaver.save(outTex,"res://outtest.tres")
		print("saved_image")
		
		get_tree().call_deferred("quit")
