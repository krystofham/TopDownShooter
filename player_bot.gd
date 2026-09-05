extends CharacterBody2D

var health = 200
var SPEED = 120.0
const MAX_AMO = 15
var amo = 15
var is_reloading = false 
var player_spotted = false
var is_playing_footstep = false

@onready var muzzle_flash = $MuzzleFlash
@onready var animated_sprite = $AnimatedSprite2D
@onready var shoot_sound = $ShootSound
@onready var nav_agent = $NavigationAgent2D
@onready var walk_sound = $Walk
@onready var spawn_zone = get_node("../CounterSpawn")


signal request_action(action_name)

var DIST_ATTACK = 100.0  
var DIST_CHASE = 180.0
var current_state = "CHASING"
var enemy
var random_dir = Vector2.ZERO
var change_dir_timer = 0.2
var SPREAD = 5
var fire_rate = 0.4      
var shoot_timer = 0.2    
var BOT_DAMAGE = 15
var RELOAD_TIME = 1.5
var last_seen_player
var patrol_dir = Vector2.RIGHT.rotated(randf_range(0, TAU)).normalized()


### Používá coop nodes in group
func is_position_far_enough(pos: Vector2, min_dist: float) -> bool:
	var other_bots = get_tree().get_nodes_in_group("coop")
	for bot in other_bots:
		if bot == self: 
			continue 
		if bot.global_position.distance_to(pos) < min_dist:
			return false
	return true
	
func apply_rank_difficulty():
	if has_node("/root/ModeManager"):
		var manager = get_node("/root/ModeManager")
		SPEED = manager.bot_speed
		DIST_ATTACK = manager.bot_dist_attack
		DIST_CHASE = manager.bot_dist_chase
		SPREAD = manager.bot_spread
		fire_rate = manager.bot_fire_rate
		BOT_DAMAGE = manager.bot_damage
		RELOAD_TIME = manager.bot_reload_time

func _ready():
	apply_rank_difficulty()
	await get_tree().physics_frame
	
	var random_pos = get_random_position_in_zone()
	var max_attempts = 15
	var min_distance_between_bots = 80.0
	for attempt in range(max_attempts):
		var potential_pos = get_random_position_in_zone()
		if potential_pos == Vector2.ZERO:
			break
		if is_position_far_enough(potential_pos, min_distance_between_bots):
			random_pos = potential_pos
			break

	if random_pos == Vector2.ZERO:
		random_pos = get_random_position_in_zone()

	var enemies_group = get_tree().get_nodes_in_group("enemies")
	if enemies_group.is_empty():
		return

	var random_enemy_bot = enemies_group.pick_random()
	if random_pos != Vector2.ZERO:
		nav_agent.target_position = random_pos
		global_position = random_pos

	nav_agent.target_position = random_enemy_bot.global_position


func get_random_position_in_zone() -> Vector2:
	if not spawn_zone:
		return Vector2.ZERO
		
	var shape_node = spawn_zone.get_node("CollisionShape2D") as CollisionShape2D
	if not shape_node or not shape_node.shape is RectangleShape2D:
		return Vector2.ZERO
		
	var rect_shape = shape_node.shape as RectangleShape2D
	var extents = rect_shape.size / 2
	
	var random_x = randf_range(-extents.x, extents.x)
	var random_y = randf_range(-extents.y, extents.y)
	
	var local_random_pos = Vector2(random_x, random_y)
	return shape_node.global_position + local_random_pos

### Funkce která se liší zásadně od BOTA.
func can_see_enemies(closest_enemy) -> bool:
	if not is_instance_valid(closest_enemy):
		return false
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, closest_enemy.global_position)
	query.exclude = [self] 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider == closest_enemy:
			return true
	return false

func get_closest_enemy(enemies, position):
	var distance = INF
	var closest_enemy
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var new_dist = position.distance_to(enemy.global_position)
		if new_dist < distance:
			distance = new_dist
			closest_enemy = enemy
	return closest_enemy

func update_state():
	var bomb_planted = false
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var closest_enemy = get_closest_enemy(enemies, position)
	if not closest_enemy:
		return
	enemy = closest_enemy
	var distance = global_position.distance_to(enemy.global_position)
	var enemy_visible = can_see_enemies(enemy)

	var old_state = current_state

	if enemy_visible:
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

func _play_footstep_asynch():
	is_playing_footstep = true
	walk_sound.play()
	await walk_sound.finished
	is_playing_footstep = false

func can_see_enemy(enemy_check) -> bool:
	if not enemy_check or not is_instance_valid(enemy_check):
		return false
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, enemy_check.global_position)
	query.exclude = [self] 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider == enemy_check:
			return true
	return false

func _physics_process(delta):


	if not is_instance_valid(enemy) or enemy == null:
		enemy = null
		var other_bots = get_tree().get_nodes_in_group("enemies")
		var dist = INF
		for e in other_bots:
			if not is_instance_valid(e):
				continue
			if self.position.distance_to(e.position) < dist:
				enemy = e
				dist = self.position.distance_to(e.position)
			if can_see_enemy(e):
				enemy = e
				break

		if !enemy:
			return
	else:
		if velocity != Vector2.ZERO and not is_playing_footstep:
			_play_footstep_asynch()
		update_state()
		var distance = global_position.distance_to(enemy.global_position)
		var direction = Vector2.ZERO
		if current_state == "CHASING":
			look_at(enemy.global_position)
			last_seen_player = enemy.global_position
			nav_agent.target_position = enemy.global_position			
			var next_path_position = nav_agent.get_next_path_position()
			direction = (next_path_position - global_position).normalized()
			
		elif current_state == "EVADING":
			change_dir_timer += delta
			var max_evade_time = get_node("/root/ModeManager").bot_change_dir_time if has_node("/root/ModeManager") else 0.5
			if change_dir_timer > max_evade_time:
				random_dir = (self.global_position - enemy.global_position).normalized().rotated(randf_range(PI/-6, PI/6))
				change_dir_timer = 0.0
			else:
				random_dir = (self.global_position - enemy.global_position).normalized()
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
				var max_patrol_time = (get_node("/root/ModeManager").bot_change_dir_time * 3.0) if has_node("/root/ModeManager") else 1.5
				if change_dir_timer > max_patrol_time or nav_agent.is_navigation_finished():
					change_dir_timer = 0.0
					patrol_dir = patrol_dir.rotated(randf_range(PI/-4, PI/4)).normalized()
					var target_position = global_position + patrol_dir * 250.0
					nav_agent.target_position = target_position
					
			var next_path_position = nav_agent.get_next_path_position()
			direction = (next_path_position - global_position).normalized()
			
			if direction != Vector2.ZERO:
				look_at(global_position + direction) 
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
			if distance < 500.0 and not is_reloading and can_see_enemies(enemy):
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
		
	if not is_instance_valid(enemy):
		return

	amo -= 1
	shoot_sound.pitch_scale = randf_range(0.9, 1.1)
	shoot_sound.volume_db = randf_range(0.9, 1.1)
	shoot_sound.play()
	
	muzzle_flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func(): muzzle_flash.visible = false)
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + (enemy.global_position - global_position).rotated(deg_to_rad(randf_range(-1*SPREAD, SPREAD))))   
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	if result:
		var hit_object = result.collider
		if hit_object == enemy:
			if enemy.has_method("take_damage"):
				enemy.take_damage(BOT_DAMAGE)

func take_damage(amount):
	health -= amount
	if health <= 0:
		emit_signal("request_action", "coop_dead")
		queue_free()
