extends CharacterBody2D

var health = 120
var SPEED = 120.0
const MAX_AMO = 15
var amo = 15
var is_reloading = false 
var is_playing_footstep = false

@onready var enemy = get_node("../Player")
@onready var muzzle_flash = $MuzzleFlash
@onready var animated_sprite = $AnimatedSprite2D
@onready var shoot_sound = $ShootSound
@onready var nav_agent = $NavigationAgent2D
@onready var walk_sound = $Walk
@onready var spawn_zone = get_node("../TerSpawn")

signal request_action(action_name)

var DIST_ATTACK = 100.0  
var DIST_CHASE = 180.0
var current_state = "CHASING"

var random_dir = Vector2.ZERO
var change_dir_timer = 0.5
var SPREAD = 5
var fire_rate = 0.4      
var shoot_timer = 0.5    
var BOT_DAMAGE = 15
var RELOAD_TIME = 1.5
var last_seen_enemy
var patrol_dir = Vector2.RIGHT.rotated(randf_range(0, TAU)).normalized()

# --- Reference na hráče, kvůli rychlejšímu seskupení po jeho smrti ---
@onready var player_node = get_node_or_null("../Player")
var REGROUP_SPEED_MULT = 1.6

# --- Omezení frekvence přepočtu cíle navigace (méně "cukání" a chození sem a tam) ---
var target_update_timer = 0.0
var TARGET_UPDATE_INTERVAL = 0.2
var last_target_pos = Vector2.INF

func is_position_far_enough(pos: Vector2, min_dist: float) -> bool:
	var other_bots = get_tree().get_nodes_in_group("enemies")
	
	for bot in other_bots:
		if bot == self: 
			continue 
		if bot.global_position.distance_to(pos) < min_dist:
			return false

	return true
func apply_rank_difficulty():
	if has_node("/root/ModeManager"):
		var manager = get_node("/root/ModeManager")
		SPEED = manager.bot_speed * 1.1
		DIST_ATTACK = manager.bot_dist_attack * 0.9
		DIST_CHASE = manager.bot_dist_chase* 1.1
		SPREAD = manager.bot_spread* 0.9
		fire_rate = manager.bot_fire_rate
		BOT_DAMAGE = manager.bot_damage* 1.1
		RELOAD_TIME = manager.bot_reload_time* 0.9
	else:
		print("ModeManager nenalezen, bot běží na defaultu.")
func _ready():
	apply_rank_difficulty()
	await get_tree().physics_frame
	
	var random_pos = get_random_position_in_zone()
	var max_attempts = 15 # Maximální počet pokusů pro nalezení místa, aby se hra nezasekla v nekonečné smyčce
	var min_distance_between_bots = 80.0
	for attempt in range(max_attempts):
		var potential_pos = get_random_position_in_zone()
		if potential_pos == Vector2.ZERO:
			break
			
		if is_position_far_enough(potential_pos, min_distance_between_bots):
			random_pos = potential_pos
			break # Našli jsme dobré místo, ukončíme hledání
			
	# Záložní plán: pokud nenašel ideální volné místo po X pokusech, vezme jakékoliv náhodné v zóně
	if random_pos == Vector2.ZERO:
		random_pos = get_random_position_in_zone()
	if random_pos != Vector2.ZERO:
		nav_agent.target_position = random_pos
		global_position = random_pos

	# Lepší chování NavigationAgentu - méně "kmitání" po cestě
	nav_agent.path_desired_distance = 16.0
	nav_agent.target_desired_distance = 16.0
	nav_agent.avoidance_enabled = true


func get_random_position_in_zone() -> Vector2:
	if not spawn_zone:
		print("Varování: Není nastavena žádná spawn_zone!")
		return Vector2.ZERO
		
	var shape_node = spawn_zone.get_node("CollisionShape2D") as CollisionShape2D
	if not shape_node or not shape_node.shape is RectangleShape2D:
		print("Chyba: Zóna musí mít RectangleShape2D!")
		return Vector2.ZERO
		
	var rect_shape = shape_node.shape as RectangleShape2D
	var extents = rect_shape.size / 2
	
	# Vygenerujeme náhodné X a Y v rozsahu od -extents do +extents
	var random_x = randf_range(-extents.x, extents.x)
	var random_y = randf_range(-extents.y, extents.y)
	
	# Přičteme globální pozici zóny, aby to fungovalo kdekoli na mapě
	var local_random_pos = Vector2(random_x, random_y)
	return shape_node.global_position + local_random_pos

func can_see_enemy(enemy) -> bool:
	if not enemy:
		return false
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, enemy.global_position)
	query.exclude = [self] 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider == enemy:
			return true
			
	return false

func update_state():
	var bomb_planted = false
	var distance = global_position.distance_to(enemy.global_position)
	var bot_visible = can_see_enemy(enemy)
	
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
func _play_footstep_asynch():
	is_playing_footstep = true
	walk_sound.play()
	await walk_sound.finished
	is_playing_footstep = false
func find_enemy():
	# Projde všechny protivníky (hráč i coop boti) a vybere nejbližšího VIDITELNÉHO,
	# jinak alespoň nejbližšího celkově. Díky tomu se bot nezasekne jen na hráči,
	# pokud je po cestě blíž nebo lépe viditelný jiný cíl.
	var other_enemies = get_tree().get_nodes_in_group("coop")
	var closest_dist = INF
	var closest_enemy = null
	var closest_visible_dist = INF
	var closest_visible_enemy = null

	for e in other_enemies:
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_to(e.global_position)
		if d < closest_dist:
			closest_dist = d
			closest_enemy = e
		if d < closest_visible_dist and can_see_enemy(e):
			closest_visible_dist = d
			closest_visible_enemy = e

	if closest_visible_enemy:
		enemy = closest_visible_enemy
	elif closest_enemy:
		enemy = closest_enemy


func try_regroup_with_allies(delta) -> bool:
	# Když hráč zemře, boti (tým "enemies") se rychleji seskupí u sebe navzájem,
	# místo aby dál bezcílně pochodovali po mapě. Použije se jen když hráč
	# neexistuje/je mrtvý a bot zrovna nikoho jiného nepronásleduje.
	if is_instance_valid(player_node):
		return false

	var allies = get_tree().get_nodes_in_group("coop")
	var nearest_ally = null
	var nearest_dist = INF
	for a in allies:
		if a == self or not is_instance_valid(a):
			continue
		var d = global_position.distance_to(a.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_ally = a

	if nearest_ally == null or nearest_dist < 60.0:
		return false

	nav_agent.target_position = nearest_ally.global_position
	var next_path_position = nav_agent.get_next_path_position()
	var direction = (next_path_position - global_position).normalized()
	if direction != Vector2.ZERO:
		look_at(nearest_ally.global_position)

	var target_velocity = direction * SPEED * REGROUP_SPEED_MULT
	velocity = velocity.lerp(target_velocity, clamp(delta * 8.0, 0.0, 1.0))
	move_and_slide()

	if velocity != Vector2.ZERO and not is_playing_footstep:
		_play_footstep_asynch()
	animated_sprite.play("Machine" if direction != Vector2.ZERO else "Standing")
	return true

func _physics_process(delta):
	if try_regroup_with_allies(delta):
		return

	find_enemy()
	if enemy:
		if velocity != Vector2.ZERO and not is_playing_footstep:
			_play_footstep_asynch()
		update_state()
		var distance = global_position.distance_to(enemy.global_position)
		var direction = Vector2.ZERO
		
		if current_state == "CHASING":
			look_at(enemy.global_position)
			last_seen_enemy = enemy.global_position

			# Cíl navigace se nepřepočítává úplně každý frame, ale jen když se
			# nepřítel posunul dostatečně nebo uplynul interval - to odstraňuje
			# neustálé mikro-přepočítávání cesty, které vypadá jako "chození sem a tam".
			target_update_timer += delta
			if target_update_timer >= TARGET_UPDATE_INTERVAL or last_target_pos.distance_to(enemy.global_position) > 30.0:
				nav_agent.target_position = enemy.global_position
				last_target_pos = enemy.global_position
				target_update_timer = 0.0

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
			if last_seen_enemy:
				if global_position.distance_to(last_seen_enemy) < 50:
					last_seen_enemy = null
				else: 
					nav_agent.target_position = last_seen_enemy
					found = true
			
			if not found:
				change_dir_timer += delta
				var max_patrol_time = (get_node("/root/ModeManager").bot_change_dir_time * 3.0) if has_node("/root/ModeManager") else 2.5
				if change_dir_timer > max_patrol_time or nav_agent.is_navigation_finished():
					change_dir_timer = 0.0
					# Menší náhodná odchylka a delší úsek = plynulejší patrolování,
					# místo neustálého otáčení a chození sem a tam.
					patrol_dir = patrol_dir.rotated(randf_range(PI/-8, PI/8)).normalized()
					var target_position = global_position + patrol_dir * 350.0
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
		
		var target_velocity = direction * (0.0 if is_reloading else SPEED)
		velocity = velocity.lerp(target_velocity, clamp(delta * 8.0, 0.0, 1.0))
		move_and_slide()
		
		shoot_timer += delta
		if shoot_timer >= fire_rate + randf_range(-0.08, 0.08):
			if distance < 500.0 and not is_reloading and can_see_enemy(enemy):
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
	shoot_sound.volume_db = randf_range(0.9, 1.1)
	shoot_sound.play()

	# Bot se při výstřelu vždy natočí přesně tam, kam střílí.
	look_at(enemy.global_position)
	
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
	# var ui = get_node_or_null("../UI")
	
	if health <= 0:
		emit_signal("request_action", "ter_dead")
		queue_free()
