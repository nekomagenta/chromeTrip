extends Node2D


onready var disabledSprites = get_node("Sprites")
onready var childrenArray = disabledSprites.get_children()
onready var parentNode = get_node("Node2D")
var texture
var count = 20
var speed = 300
var isInitial = true
var time = 0

func _ready():
	texture = childrenArray[0].get_texture()
	set_process(true)
	
func genPos():
	var posX
	var posY
	if isInitial:
		posX = rand_range(1200,2000)
	else:
		posX = rand_range(1200,2000)
	posY = rand_range(480,700)
	return Vector2(posX,posY)
	
func genSpeed(_posY):
	var speedY = _posY
	return speedY
	
func genScale(_posY):
	var tmp = _posY/300
	var myscale = Vector2(tmp,tmp)
	return myscale

func newSprite():
	var sprite = Sprite.new()
	sprite.texture = texture
	sprite.region_enabled=true;
	sprite.set_region_rect(disabledSprites.get_node("Sprite"+str(int(rand_range(1,disabledSprites.get_child_count())))).get_region_rect())
	parentNode.add_child(sprite)
	sprite.position = genPos()
	sprite.z = sprite.position.y
	sprite.scale= genScale(sprite.position.y)
	if rand_range(0,2) > 1:
		sprite.flip_h = true

func _process(delta):
	time += delta
	if count > parentNode.get_child_count() and time > 1:
		time = 0
		newSprite()
	for object in parentNode.get_children():
		object.position.x -= delta * genSpeed(object.position.y)
		if object.position.x<-100 and !object.is_queued_for_deletion():
#			get_parent().call_deferred("remove_child",object)
#			call_deferred("queue_free")
			object.queue_free()
#			print("prallaxforground sprite deleted")
	