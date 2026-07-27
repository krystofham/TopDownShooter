extends CanvasLayer

@onready var health_bar = $HUD/HealthBar
@onready var amo_label = $HUD/AmoLabel
@onready var time_label = $HUD/TimeLabel
@onready var score_label = $HUD/ScoreLabel
const GAME_OVER_MENU_SCENE = preload("res://scenes/game_over_menu.tscn")

var time_elapsed = 100.0

func _ready():
	health_bar.max_value = 100
	health_bar.value = 100
	GameManager.score_changed.connect(update_score)
	update_score(GameManager.score_team_a, GameManager.score_team_b)
	update_amo([20, 10], [20, 10], "primary") # Hned na startu ukážeme plný zásobník

func _process(delta):
	# Počítání času hry (odpočítávání dolů z 100)
	time_elapsed -= delta
	
	# Ošetření, aby čas nešel do mínusu
	if time_elapsed < 0:
		time_elapsed = 0.0
		
	update_time_display()

# Funkce, kterou budeme volat z hráče při změně HP
func update_health(new_hp: int):
	health_bar.value = new_hp

# Funkce, kterou budeme volat z hráče při střelbě/přebíjení
func update_amo(amo: Array, max_amo: Array, active_gun: String):
	var index = 0
	if active_gun != "primary": index = 1
	if amo_label != null:
		amo_label.text = str(amo[index]) + " / " + str(max_amo[index])

# Pomocná funkce pro formátování času na MM:SS
func update_time_display():
	var minutes = int(time_elapsed) / 60
	var seconds = int(time_elapsed) % 60
	time_label.text = "ČAS: %02d:%02d" % [minutes, seconds]
	if minutes == 0 and seconds == 0:
		game_over()

func update_score(counter_score: int, terr_score: int):
	score_label.text = "Counter: " + str(counter_score) + " | Terrorist: " + str(terr_score)
func game_over():
	var game_over_instance = GAME_OVER_MENU_SCENE.instantiate()
	get_tree().current_scene.add_child(game_over_instance)
	queue_free()
