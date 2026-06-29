extends CharacterBody2D

const SPEED = 200.0
const FIRE_RATE = [0.07, 0.2]
const GUN_ROTATION = [8, 10]
const DMG = [10, 20]
const MAX_AMO = [20, 10]
const MUZZLE_FLASH_TIME = 0.03
var health = 100
var amo = [20, 10]
var is_reloading = false
var guns = ["primary", "secondary"]
var active_gun = "primary"
var active_amo = 20
var rounds = 3
var can_shoot = true
# Odkazy na uzly
@onready var gun_ray = $GunRay
@onready var muzzle_flash = $MuzzleFlash
@onready var animated_sprite = $AnimatedSprite2D
@onready var shoot_sound = $ShootSound
@onready var laser_line = $Line2D
@onready var ui = get_node("../UI") 

signal request_action(action_name)

func _ready():
	gun_ray.target_position = Vector2(1000.0, 0.0)
	if ui:
		ui.update_amo(amo, MAX_AMO, active_gun)
const GAME_OVER_MENU_SCENE = preload("res://scenes/game_over_menu.tscn")

func safe_get_tree():
	if is_inside_tree():
		return get_tree()
	return null

func _physics_process(delta):
	# 1. Pohyb hráče
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")    
	velocity = input_dir.normalized() * SPEED
	move_and_slide()
	
	# 2. Animace pohybu a přebíjení
	_handle_animations(input_dir)
	look_at(get_global_mouse_position())
	# 3. Míření ke kurzoru
	gun_ray.rotation = lerp(gun_ray.rotation, 0.0, 15 * delta)
	# 4. Vstupy (Střelba, Přebíjení, Přepínání)
	if Input.is_action_pressed("shoot") and can_shoot and not is_reloading:
		_handle_shooting()
		
	if Input.is_action_just_pressed("reload"):
		_handle_manual_reload()
		
	if Input.is_action_just_pressed("switch"):
		_handle_weapon_switch()
func _apply_recoil():
	var index = 0 if active_gun == "primary" else 1
	gun_ray.rotation = deg_to_rad(randf_range(GUN_ROTATION[index]*-1, GUN_ROTATION[index]))# Pomocná funkce pro animace
func _handle_animations(input_dir: Vector2):
	if is_reloading:
		if animated_sprite.animation != "Reload":
			animated_sprite.play("Reload")
	elif not input_dir:
		animated_sprite.play("Standing")
	else:
		if animated_sprite.animation != active_gun:
			animated_sprite.play(active_gun)

# Profesionální zpracování střelby a recoilu
func _handle_shooting():
	if active_amo <= 0:
		var inverse_index = 1 if active_gun == "primary" else 0
		if amo[inverse_index] < 2:
			reload() 
			return
		else:
			_handle_weapon_switch()

	# Spustíme samotný výstřel (odečtení nábojů, zvuk, raycast)
	shoot()
	
	# Aplikace Recoilu (posun myši)
	_apply_recoil()
	# Aktivace cooldownu zbraně
	_start_fire_cooldown()


# Časovač mezi výstřely
func _start_fire_cooldown():
	can_shoot = false
	var index = 0 if active_gun == "primary" else 1
	var tree = safe_get_tree()
	if tree:
		tree.create_timer(FIRE_RATE[index]).timeout.connect(func(): can_shoot = true)

func _handle_manual_reload():
	var index = 0 if active_gun == "primary" else 1
	if not is_reloading and active_amo < MAX_AMO[index]:
		reload()

func _handle_weapon_switch():
	if active_gun == "primary":
		active_gun = "secondary"
		active_amo = amo[1]
	else:
		active_gun = "primary"
		active_amo = amo[0]
		
	if animated_sprite.animation != active_gun:
		animated_sprite.play(active_gun)
	if ui:
		ui.update_amo(amo, MAX_AMO, active_gun)

func reload():
	if is_reloading: return
	var gun = active_gun
	is_reloading = true
	var index = 0 if gun == "primary" else 1
	var tree = safe_get_tree()
	if tree:
		await tree.create_timer(2.0).timeout
	
	amo[index] = MAX_AMO[index]
	if active_gun == gun:
		active_amo = amo[index]
	is_reloading = false
	if ui:
		ui.update_amo(amo, MAX_AMO, active_gun)

func shoot():
	active_amo -= 1
	var index = 0 if active_gun == "primary" else 1
	amo[index] = active_amo
	shoot_sound.pitch_scale = randf_range(0.9, 1.1)
	shoot_sound.play()
	if ui:
		ui.update_amo(amo, MAX_AMO, active_gun)
	
	muzzle_flash.visible = true
	var tree = safe_get_tree()
	if tree:
		tree.create_timer(MUZZLE_FLASH_TIME).timeout.connect(func(): muzzle_flash.visible = false)
	laser_line.clear_points()
	laser_line.add_point(Vector2.ZERO)
	if gun_ray.is_colliding():
		var hit_object = gun_ray.get_collider()
		print(hit_object)
		if hit_object and hit_object.has_method("take_damage"):
			hit_object.take_damage(DMG[index])
		var local_hit_pos = to_local(gun_ray.get_collision_point())
		laser_line.add_point(local_hit_pos)
	else:
		var max_laser_length = Vector2(1000.0, 0.0).rotated(gun_ray.rotation)
		laser_line.add_point(max_laser_length)
	if not is_inside_tree():
		return
	tree = safe_get_tree()
	if tree:
		tree.create_timer(MUZZLE_FLASH_TIME).timeout.connect(func(): laser_line.clear_points())

func take_damage(amount):
	health -= amount
	print("Dostal jsi zásah od bota! Tvoje aktuální HP: ", health)
	if ui:
		ui.update_health(health)
	if health <= 0:
		if ui:
			ui.update_teams(0, 1)
		round_over()
func round_over():
	emit_signal("request_action", "player_dead")
