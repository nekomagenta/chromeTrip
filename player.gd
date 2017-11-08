extends RigidBody2D
# Default Character Properties (Should be overwritten)
var acceleration = 10000
var top_move_speed_org = 200
var top_move_speed = top_move_speed_org
var top_jump_speed = 800
var jumpSound = load("res://sounds/jump.ogg")
var killedSound = load("res://sounds/killed.ogg")
var soundPlayer = AudioStreamPlayer.new()

onready var playerColShape = get_node("playerShape")
# Grounded?
var grounded = false 
# Movement Vars
var directional_force = Vector2()
const DIRECTION = {
    ZERO = Vector2(0, 0),
    LEFT = Vector2(-1, 0),
    RIGHT = Vector2(1, 0),
    UP = Vector2(0, -1),
    DOWN = Vector2(0, 1)
}

#var FOWARD_MOTION = Vector2(0, 0)

#define the slave vars. slave var did not worked for me
sync var slave_pos = Transform2D()
sync var slave_motion = Vector2()
#sync var slave_can_jump = true
sync var alive = true
var reviving = false

onready var animPlayer = get_node("Sprite/AnimationPlayer")
 
# Jumping
var can_jump = true
var jump_time = 0
const TOP_JUMP_TIME = 0.1 # in seconds

var keys = [false,false,false,false] # right, left, up, down 

func _ready():
	
	soundPlayer.connect("finished",self,"_sound_finished")
	var root = get_tree().get_root().get_node("Control")
	set_process_input(true)
	add_child(soundPlayer)
	rpc("playAnimation","trexAnimRun")
	

func _integrate_forces(state):
	var final_force = Vector2()
#	if alive:
	if is_network_master():
		
		if !alive:
			pass
#			state.set_sleep_state(true)
			
		if reviving:
			reviving = false
			state.set_transform( slave_pos )
#			state.set_sleep_state(false)
#			state.set_sleep_state(false)
#		print(position)
		directional_force = DIRECTION.ZERO  # +FOWARD_MOTION
		apply_force(state)
		final_force = state.get_linear_velocity() + (directional_force * acceleration)
	 
		if(final_force.x > top_move_speed):
			final_force.x = top_move_speed
		elif(final_force.x < -top_move_speed):
			final_force.x = -top_move_speed
	
		if(final_force.y > top_jump_speed):
			final_force.y = top_jump_speed
		elif(final_force.y < -top_jump_speed):
			final_force.y = -top_jump_speed
		
		# set the slave motion values
		rset("slave_motion",final_force)
		rset("slave_pos",state.get_transform())
	else:
		
		state.set_transform(slave_pos)
		final_force = slave_motion
		
	state.set_linear_velocity(final_force)
	
# Apply force
func apply_force(state):

    # Move Right
	if keys[0]:
		directional_force += DIRECTION.RIGHT

	# Move Left
	if keys[1]:
		directional_force += DIRECTION.LEFT
     
    # Jump
	if keys[2]:
		if jump_time < TOP_JUMP_TIME and can_jump:
			directional_force += DIRECTION.UP
			jump_time += state.get_step()
		
    # While on the ground
	if(grounded):
		can_jump = true
		jump_time = 0
		
func _on_groundSensor_body_entered( body ):
	if body.has_node("playerShape"):
		if body.get_name()!=get_name():
			grounded = true
	elif body.get_name()=="groundCollision":
		grounded = true

func _on_groundSensor_body_exited( body ):
	if body.has_node("playerShape"):
		if body.get_name()!=get_name():
			grounded = false
	elif body.get_name()=="groundCollision":
		grounded = false
 
#func _on_groundcollision_body_entered( body ):
##	if body.has_node("playerShape"):
##		body.get_node("playerShape").get_name()=="playerShape"
##		grounded = true
#
#
#func _on_groundcollision_body_exited( body ):
##	if body.has_node("playerShape"):
##		body.get_node("playerShape").get_name()=="playerShape"
##		grounded = false


sync func playAnimation(_string):
	animPlayer.play(_string)
	
sync func animSpeed(_speed):
	get_node("Sprite/AnimationPlayer").set_speed_scale(_speed)

func _input(event):
	if is_network_master() and alive:
		#if keyboard input
		if event.get_class()=="InputEventKey":
			
			# left or right keypressevent
			if event.is_action_pressed("ui_right"):
				keys[0]=true
				rpc("animSpeed",1.5)
#				rpc("playAnimation","trexAnimRun")
			elif event.is_action_pressed("ui_left"):
				rpc("animSpeed",0.5)
				keys[1]=true
#				rpc("playAnimation","trexAnimRun")
			
			# left or right keyreleaseevent
			if event.is_action_released("ui_right"):
				rpc("animSpeed",1)
				keys[0]=false
#				rpc("playAnimation","trexAnim")
			elif event.is_action_released("ui_left"):
				rpc("animSpeed",1)
				keys[1] = false
#				rpc("playAnimation","trexAnim")

			# Duck and Cover!
			if event.is_action_pressed("ui_down"):
				keys[3] = true
				rpc("playAnimation","trexAnimDuck")
			elif event.is_action_released("ui_down"):
				rpc("playAnimation","trexAnimRun")
				keys[3] = false
#				rpc("playAnimation","trexAnim")
			
			#jumping keyevents
			if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_select"):
				keys[2]=true
				if grounded or can_jump:
					if !soundPlayer.is_playing():
						if soundPlayer.get_stream() != jumpSound:
							soundPlayer.set_stream(jumpSound)
						soundPlayer.play(0.0)
			if event.is_action_released("ui_up") or event.is_action_released("ui_select"):
				keys[2]=false
				can_jump = false # Prevents the player from jumping more than once while in air
#				rset("slave_can_jump",can_jump)
	elif is_network_master() and !alive: # not alive
		keys = [false,false,false,false]
		can_jump = false
		
func _sound_finished():
	soundPlayer.stop()
	
sync func killed(_id):
	get_parent().get_node(str(_id)).get_node("playerShape").disabled=true
	get_parent().get_node(str(_id)).alive = false
	get_parent().get_node(str(_id)).can_jump = false
	get_parent().get_node(str(_id)).get_node("Sprite/AnimationPlayer").play("trexAnimKilled")
	print(_id, " hasbeen killed")

sync func RPCreanimate(_id, atPosition):
	
	var transMatrix = Transform2D(Vector2(),Vector2(), atPosition)
	print(_id,transMatrix, " hasbeen reanimated")
	get_parent().get_node(str(_id)).get_node("playerShape").disabled=false
	get_parent().get_node(str(_id)).get_node("playerShape").update()
#	get_parent().get_node(str(_id)).
	get_parent().get_node(str(_id)).can_jump = false
	get_parent().get_node(str(_id)).get_node("Sprite/AnimationPlayer").play("trexAnimRun")
#	get_parent().get_node(str(_id)).position = atPosition
	get_parent().get_node(str(_id)).slave_pos = transMatrix
	if is_network_master():
		playerColShape.disabled=false
		alive = true
		can_jump = false
		grounded = false
		position = atPosition
		slave_pos = transMatrix
		slave_motion = Vector2(0,0)
	get_parent().get_node(str(_id)).alive = true
	get_parent().get_node(str(_id)).reviving = true


func reanimate(atPosition):
	rpc("RPCreanimate", get_name(), atPosition)

func allPlayersKilled():
	for player in get_tree().get_nodes_in_group("players"):
		if player.alive: return false
	return true
	
sync func showGameOverScreen():
	get_tree().get_root().get_node("Control/game/GameOverScreen").set_visible(true)

func _on_player_body_shape_entered( body_id, body, body_shape, local_shape ):

	if(body.has_node("obstacleShape") or body.has_node("enemyShape")) and alive:
		soundPlayer.stream = killedSound
		soundPlayer.play(0.0)
		get_parent().get_parent().allDead = true
		if get_tree().is_network_server():
			rpc("killed", get_name())
			if allPlayersKilled():
				rpc("showGameOverScreen")



func _on_player_body_shape_exited( body_id, body, body_shape, local_shape ):
#	if body.get_node("playerShape").get_name()=="playerShape":
#		can_jump=false
	pass # replace with function body
