extends CharacterBody2D

var health = 100
const SPEED = 120.0
const MAX_AMO = 15
var amo = 15
var is_reloading = false 
var player_spotted = false

@onready var player = get_node("../Player")
@onready var muzzle_flash = $MuzzleFlash
@onready var animated_sprite = $AnimatedSprite2D
@onready var shoot_sound = $ShootSound
@onready var nav_agent = $NavigationAgent2D

signal request_action(action_name)

const DIST_ATTACK = 100.0  
const DIST_CHASE = 180.0
var current_state = "CHASING"

var random_dir = Vector2.ZERO
var change_dir_timer = 0.0
const SPREAD = 5
var fire_rate = 0.4      
var shoot_timer = 0.0      
const BOT_DAMAGE = 15
const RELOAD_TIME = 1.5
var last_seen_player
var patrol_dir = Vector2.RIGHT.rotated(randf_range(0, TAU)).normalized()
func _ready():
	await get_tree().physics_frame
	if player:
		nav_agent.target_position = player.global_position
func can_see_player() -> bool:
	if not player:
		return false
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self] 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider == player:
			return true
			
	return false

func update_state():
	var bomb_planted = false
	var distance = global_position.distance_to(player.global_position)
	var bot_visible = can_see_player()
	
	if bot_visible:
		if current_state == "PATROLLING":
			current_state = "CHASING"
		
		if current_state == "EVADING":
			if distance > DIST_CHASE:
				current_state = "CHASING"
		else:
			if distance < DIST_ATTACK:
				current_state = "EVADING"
	else:
		current_state = "PATROLLING"
		
	if bomb_planted:
		current_state = "DETONATING"
		
func _physics_process(delta):
	if player:
		update_state()
		var distance = global_position.distance_to(player.global_position)
		var direction = Vector2.ZERO
		
		if current_state == "CHASING":
			look_at(player.global_position)
			last_seen_player = player.global_position
			nav_agent.target_position = player.global_position
			
			var next_path_position = nav_agent.get_next_path_position()
			direction = (next_path_position - global_position).normalized()
			
		elif current_state == "EVADING":
			change_dir_timer += delta
			if change_dir_timer > 0.5:
				random_dir = (self.global_position - player.global_position).normalized().rotated(randf_range(PI/-6, PI/6))
				change_dir_timer = 0.0
			else:
				random_dir = (self.global_position - player.global_position).normalized()
			
			direction = random_dir
			
		elif current_state == "PATROLLING":
			var found = false
			if last_seen_player:
				if global_position.distance_to(last_seen_player) < 50:
					last_seen_player = null
				else: 
					nav_agent.target_position = last_seen_player
					found = true
			
			if not found:
				change_dir_timer += delta
				if change_dir_timer > 1.5 or nav_agent.is_navigation_finished():
					change_dir_timer = 0.0
					patrol_dir = patrol_dir.rotated(randf_range(PI/-4, PI/4)).normalized()
					var target_position = global_position + patrol_dir * 250.0
					nav_agent.target_position = target_position
					
			var next_path_position = nav_agent.get_next_path_position()
			direction = (next_path_position - global_position).normalized()
			
			if direction != Vector2.ZERO:
				look_at(global_position + direction) 
				
		elif current_state == "DETONATING":
			pass
				
		if is_reloading:
			if animated_sprite.animation != "Reload":
				animated_sprite.play("Reload")
		elif direction == Vector2.ZERO:
			animated_sprite.play("Standing")
		else:
			animated_sprite.play("Machine")
		
		velocity = direction * (0.0 if is_reloading else SPEED)
		move_and_slide()
		
		shoot_timer += delta
		if shoot_timer >= fire_rate + randf_range(-0.08, 0.08):
			if distance < 500.0 and not is_reloading and can_see_player():
				bot_shoot()
				shoot_timer = 0.0

func start_reload():
	is_reloading = true
	await get_tree().create_timer(RELOAD_TIME).timeout
	amo = MAX_AMO
	is_reloading = false

func bot_shoot():
	if is_reloading:
		return

	if amo <= 0: 
		start_reload()
		return
		
	amo -= 1
	shoot_sound.pitch_scale = randf_range(0.9, 1.1)
	shoot_sound.play()
	
	muzzle_flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func(): muzzle_flash.visible = false)
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + (player.global_position - global_position).rotated(deg_to_rad(randf_range(-1*SPREAD, SPREAD))))   
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_object = result.collider
		if hit_object == player:
			if player.has_method("take_damage"):
				player.take_damage(BOT_DAMAGE)

func take_damage(amount):
	health -= amount
	var ui = get_node_or_null("../UI")
	
	if health <= 0:
		emit_signal("request_action", "ter_dead")
		queue_free()
