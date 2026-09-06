extends Node2D
const GAME_OVER_MENU_SCENE = preload("res://scenes/game_over_menu.tscn")
signal counter_changed(counter_score: int, terr_score: int)
var counter =  5
var terrorist = 5
var kills = 0
var is_killed = false
func _ready():
	# Najdeme hráče a připojíme se k jeho signálu
	$Player.request_action.connect(_on_player_request_action)
	$Bot.request_action.connect(_on_bot_request_action)
	$Bot2.request_action.connect(_on_bot_request_action)
	$Bot5.request_action.connect(_on_bot_request_action)
	$Bot4.request_action.connect(_on_bot_request_action)
	$Bot3.request_action.connect(_on_bot_request_action)
	$playerBot.request_action.connect(_on_playerBot_request_action)
	$playerBot2.request_action.connect(_on_playerBot_request_action)
	$playerBot3.request_action.connect(_on_playerBot_request_action)
	$playerBot4.request_action.connect(_on_playerBot_request_action)
func _on_playerBot_request_action(action_name):
	if action_name == "coop_dead":
		entity_died(true, true)
func _on_player_request_action(action_name):
	if action_name == "player_dead":
		player_dead()
func player_dead():
	entity_died(true, true)
func _on_bot_request_action(action_name):
	if action_name == "ter_dead":
		ter_dead()
	
func ter_dead():
	entity_died(false, false)

func entity_died(is_counter, is_killed):
	if is_counter:
		counter -= 1
	else: 
		terrorist -=1
	print("counter: ", counter, " terrorist: ", terrorist)
	evaluate()
func i_killed():
	kills += 1
func evaluate():
	counter_changed.emit(counter, terrorist)
	if counter == 0:
		GameManager.register_round_results(false, kills, true)
	if terrorist == 0:
		GameManager.register_round_results(true, kills, false)
func game_over():
	var game_over_instance = GAME_OVER_MENU_SCENE.instantiate()
	get_tree().current_scene.add_child(game_over_instance)
	queue_free()
