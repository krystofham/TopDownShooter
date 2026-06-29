extends Node

# --- PARAMETRY AKTUÁLNÍHO ZÁPASU (V PAMĚTI) ---
var match_max_rounds: int = 15
var current_game_mode: String = "casual"
var map_scene_path: String = ""

# --- STATISTIKY ZÁPASU (SČÍTAJÍ SE PŘES VŠECHNA KOLA) ---
var player_match_kills: int = 0
var player_match_deaths: int = 0
var score_team_a: int = 0 # Tým hráče
var score_team_b: int = 0 # Tým botů
var current_round_number: int = 1

# Volá se z ModeManageru před spuštěním samotné hry
func init_match(max_rounds: int, mode: String, map_path: String):
	match_max_rounds = max_rounds
	current_game_mode = mode
	map_scene_path = map_path
	
	# Resetování všech statistik na nulu pro nový zápas
	player_match_kills = 0
	player_match_deaths = 0
	score_team_a = 0
	score_team_b = 0
	current_round_number = 1
	
	print("GameManager: Zápas inicializován. Mód: ", current_game_mode, ", Kola: ", match_max_rounds)
	
	# Načtení Map Menu / Loading scény (případně rovnou mapy)
	# Prozatím načteme rovnou mapu přes cestu, kterou jsme dostali
	get_tree().change_scene_to_file(map_scene_path)

# --- REŽIE JEDNOTLIVÝCH KOL ---

# Tuto funkci zavolá Round Menu na konci každého kola
func register_round_results(round_won: bool, round_kills: int, player_died: bool):
	# Přičtení statistik z odehraného kola do celkových statistik zápasu
	player_match_kills += round_kills
	if player_died:
		player_match_deaths += 1
		
	# Přičtení bodu vítěznému týmu
	if round_won:
		score_team_a += 1
		print("Kolo vyhrál Hráč. Stav zápasu: ", score_team_a, ":", score_team_b)
	else:
		score_team_b += 1
		print("Kolo vyhráli Boti. Stav zápasu: ", score_team_a, ":", score_team_b)
		
	# Výpočet podmínky pro absolutní vítězství v zápase (např. v Casualu stačí 8 bodů z 15)
	var win_condition = (match_max_rounds / 2) + 1
	
	if score_team_a >= win_condition:
		print("GameManager: Hráčův tým vyhrál zápas!")
		send_results_to_mode_manager(true)
		return
	elif score_team_b >= win_condition:
		print("GameManager: Tým botů vyhrál zápas!")
		send_results_to_mode_manager(false)
		return
		
	current_round_number += 1
	print("GameManager: Přechod na kolo číslo: ", current_round_number)
	# UI.show_message("STISKNĚTE ENTER PRO DALŠÍ KOLO")
	get_tree().paused = true
	while not Input.is_action_just_pressed("ui_accept"):
		await get_tree().process_frame
	get_tree().paused = false
	get_tree().reload_current_scene()

func send_results_to_mode_manager(victory: bool):
	print("GameManager: Zápas skončil. Posílám finální data do ModeManageru.")
	
	if has_node("/root/ModeManager"):
		ModeManager.process_match_end(victory, player_match_kills, player_match_deaths)
	else:
		print("CHYBA: ModeManager nenalezen! Návrat do menu.")
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
