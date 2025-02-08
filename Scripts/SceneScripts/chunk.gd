class_name Chunk
extends Node3D

@export var chunkImgClean : ImageTexture3D
@export var size : int = 256

#input variable needs to be a custom class, one I haven't written yet
func updateChunkTexture(objectAdd : VisualObject) -> void:
	size = nearest_po2(size) # ensure texture is still a power of 2
	if chunkImgClean == null:
		#create and fill an array with empty pixels
		var imgArr := [];
		imgArr.resize(size)
		var img := Image.create(size,size,false,Image.FORMAT_L8)
		img.fill(Color.BLACK)
		imgArr.fill(img);
		chunkImgClean = ImageTexture3D.new()
		chunkImgClean.create(Image.FORMAT_L8,size,size,size,false,imgArr)
	
	var chunkImg := chunkImgClean

	#create local rendering device
	var rd := RenderingServer.create_local_rendering_device()

	var shader_file := load("res://ChunkGen.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)

	#prep input shader
	var ChunkFormat := RDTextureFormat.new()
	ChunkFormat.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	#set for 3d textures
	ChunkFormat.height = size
	ChunkFormat.width = size
	ChunkFormat.depth = size
	ChunkFormat.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	var ChunkRID := rd.texture_create(ChunkFormat,RDTextureView.new(),[chunkImg.get_data()])
	
	var chunkUniform := RDUniform.new()
	chunkUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	chunkUniform.binding = 0 # needs to match the binding in the shader
	chunkUniform.add_id(ChunkRID)
	
	#prep object 3d texture
	var ObjFormat := RDTextureFormat.new()
	ObjFormat.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	ObjFormat.height = objectAdd.sdfTexture.get_height()
	ObjFormat.width = objectAdd.sdfTexture.get_width()
	ObjFormat.depth = objectAdd.sdfTexture.get_depth()
	ObjFormat.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	
	var objRID := rd.texture_create(ObjFormat,RDTextureView.new(),[chunkImg.get_data()])
	var objUniform := RDUniform.new()
	objUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	objUniform.binding = 1
	objUniform.add_id(objRID)
	
	#prep transform to buffer (unsure if most efficient way)
	var translation := to_local(objectAdd.position)
	var objBasis := basis * objectAdd.basis
	var objScale := objBasis.get_scale()
	var rot := objBasis.get_rotation_quaternion()
	#TODO: figure out if this can be read as vector4 from shader, each one is meant to be a vector4
	var tBytes := var_to_bytes(translation)
	var sBytes := var_to_bytes(objScale)
	var rBytes := var_to_bytes(rot)
	
	var tBuffer := rd.storage_buffer_create(tBytes.size(),tBytes)
	var sBuffer := rd.storage_buffer_create(sBytes.size(),sBytes)
	var rBuffer := rd.storage_buffer_create(rBytes.size(),rBytes)

	#create a uniform
	var transformUniform := RDUniform.new()
	transformUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	transformUniform.binding = 2
	#TODO: make sure adding three buffers to a uniform is ok
	transformUniform.add_id(tBuffer)
	transformUniform.add_id(sBuffer)
	transformUniform.add_id(rBuffer)
	
	var uniform_set := rd.uniform_set_create([chunkUniform,objUniform,transformUniform],shader,0)
	
	#create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list,pipeline)
	rd.compute_list_bind_uniform_set(compute_list,uniform_set,0)
	
	#TODO: 256x256x256 may be too big, equivelant to one 4096x4096 texture
	#possible lower the resolution to the nearest po2 of the objects size
	rd.compute_list_dispatch(compute_list,256,256,256)
	rd.compute_list_end()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
