extends MeshInstance3D

@export var chunkImge : ImageTexture3D
@export var size : int = 256

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	size = nearest_po2(size) # ensure texture is still a power of 2
	if chunkImge == null:
		#create and fill an array with empty pixels
		var imgArr := [];
		imgArr.resize(size)
		var img := Image.create(size,size,false,Image.FORMAT_L8)
		img.fill(Color.BLACK)
		imgArr.fill(img);
		chunkImge = ImageTexture3D.new()
		chunkImge.create(Image.FORMAT_L8,size,size,size,false,imgArr)

	#create local rendering device
	var rd := RenderingServer.create_local_rendering_device()

	var shader_file := load("res://ChunkGen.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)

	#prep input shader
	var inputFormat := RDTextureFormat.new()
	inputFormat.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	#set for 3d textures
	inputFormat.height = size
	inputFormat.width = size
	inputFormat.depth = size
	inputFormat.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	var inputRID = rd.texture_create(inputFormat,RDTextureView.new())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
