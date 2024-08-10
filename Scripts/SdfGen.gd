extends Node3D

@export var size := 16
@export var growTester : PackedScene
var count = 0
var imgCount = 0
var imgArr = Array([])

func _ready() -> void:
	createImg(0)

func createImg(z : int) -> void:
	var currImg = Image.create(size,size,false,Image.FORMAT_L8)
	currImg.crop(size,size)
	for y in range(size):
		for x in range(size):
			var curr := growTester.instantiate()
			add_child.call_deferred(curr)
			curr.position = Vector3(x,y,z) * (1.0/size)
			curr.coord = Vector2i(x,y)
			curr.tex = currImg
			curr.collided.connect(addTest)
	imgArr.append(currImg)

func addTest() -> void:
	count += 1
	
	if(count >= size * size):
		print("Finished image i: ",imgCount)
		imgCount += 1
		count = 0
		if(imgCount >= size):
			var tempTex = ImageTexture3D.new()
			tempTex.create(Image.FORMAT_L8,size,size,size,false,imgArr)
			ResourceSaver.save(tempTex,"res://test.tres")
			print("Saved")
			queue_free()
		else:
			createImg(imgCount)
		
