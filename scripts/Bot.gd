extends CharacterBody2D

var health = 100
const SPEED = 120.0
const MAX_AMO = 15
var amo = 15
var is_reloading = false 

@onready var player = get_node("../Player")
@onready var muzzle_flash = $MuzzleFlash
@onready var animated_sprite = $AnimatedSprite2D
@onready var shoot_sound = $ShootSound

# DEFINUJEME HRANICE (Prostor)
const DIST_ATTACK = 100.0   # Pod tuto vzdálenost začne cukat/uhýbat
const DIST_CHASE = 180.0    # Znovu tě začne honit, až když mu utečeš
# Pomocná proměnná pro stav bota
var current_state = "CHASING"
var random_dir = Vector2.ZERO
var change_dir_timer = 0.0
const SPREAD = 5
# --- PRO ZBRANĚ A STŘELBU ---
var fire_rate = 0.4        # Bot vystřelí jednou za 0.4 vteřiny
var shoot_timer = 0.0      # Časovač pro střelbu
const BOT_DAMAGE = 20      # Kolik damage dá bot hráči, když ho trefí
const RELOAD_TIME = 1.5

func _physics_process(delta):
	if player:
		# 1. ROTACE BOTA
		look_at(player.global_position)
		
		var distance = global_position.distance_to(player.global_position)
		var direction = Vector2.ZERO
		
		# --- STAVOVÁ LOGIKA (HYSTEREZE) ---
		if current_state == "CHASING":
			if distance < DIST_ATTACK:
				current_state = "EVADING"
				random_dir = Vector2.LEFT.rotated(randf_range(0, TAU))
				change_dir_timer = 0.0
			else:
				direction = (player.global_position - global_position).normalized()
				
		elif current_state == "EVADING":
			if distance > DIST_CHASE:
				current_state = "CHASING"
			else:
				change_dir_timer += delta
				if change_dir_timer > 0.3:
					random_dir = Vector2.LEFT.rotated(randf_range(0, TAU))
					change_dir_timer = 0.0
				
				direction = random_dir
		
		# --- OPRAVENÁ LOGIKA ANIMACÍ BOTA ---
		if is_reloading:
			if animated_sprite.animation != "Reload":
				animated_sprite.play("Reload")
		elif direction == Vector2.ZERO:
			animated_sprite.play("Standing")
		else:
			animated_sprite.play("Machine")
		
		# Pohyb bota (při přebíjení se zastaví)
		velocity = direction * (0.0 if is_reloading else SPEED)
		move_and_slide()
		
		# --- LOGIKA STŘELBY BOTA ---
		shoot_timer += delta
		if shoot_timer >= fire_rate + randf_range(-0.08, 0.08):
			# Střílíme jen když nepřebíjí a je blízko
			if distance < 500.0 and not is_reloading:
				bot_shoot()
				shoot_timer = 0.0

# Upravená funkce reload
func start_reload():
	is_reloading = true
	print("Bot začal přebíjet...")
	
	await get_tree().create_timer(RELOAD_TIME).timeout
	
	amo = MAX_AMO
	is_reloading = false
	print("Bot má přebito!")

# Funkce, která řeší samotný výstřel bota na hráče
func bot_shoot():
	if is_reloading:
		return

	# Pokud nemá náboje, spustíme přebíjení a hned vyskočíme
	if amo <= 0: 
		start_reload()
		return
		
	# Samotný výstřel
	amo -= 1
	shoot_sound.pitch_scale = randf_range(0.9, 1.1)
	shoot_sound.play()
	# Efekt záblesku
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

# Funkce zásahu bota
func take_damage(amount):
	health -= amount
	print("Bot dostal zásah! Aktuální HP bota: ", health)
	
	# Pokud botovi klesne HP při zásahu, aktualizujeme UI (styl CS)
	var ui = get_node_or_null("../UI")
	
	if health <= 0:
		print("Bot byl eliminován!")
		if ui:
			ui.update_teams(1, 0) # Counter (boti) klesne na 0
		queue_free()
