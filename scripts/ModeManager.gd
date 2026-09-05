extends Node

var username: String = "Krystof"
var elo: int = 1000
var player_rank: String = "Silver II"
var rank_asset_path: String = "res://assets/ranks/silver2.png"

var current_mode: String = "casual"
const CONFIG_FILE_PATH = "user://savegame.cfg"


var bot_speed: float = 120.0
var bot_dist_attack: float = 100.0
var bot_dist_chase: float = 180.0
var bot_spread: float = 5.0
var bot_fire_rate: float = 0.4
var bot_damage: int = 15
var bot_reload_time: float = 1.5
var bot_change_dir_time: float = 0.2

func update_bot_difficulty():

	# Ranked = hráčovo ELO
	# Casual = Silver 2/3 baseline
	var effective_elo = elo if current_mode == "ranked" else 650

	var clamped_elo = clampi(effective_elo, 0, 2000)

	# 0.0 = ELO 0
	# 1.0 = ELO 2000
	var t = float(clamped_elo) / 2000.0

	# Silnější baseline + pomalejší růst na vysokém ELO.
	# Díky tomu jsou boti lepší při stejném ELO/ranku.
	var factor = pow(t, 0.72)

	bot_speed = lerp(115.0, 175.0, factor)
	bot_spread = lerp(7.0, 0.8, factor)
	bot_damage = int(lerp(14.0, 24.0, factor))
	bot_fire_rate = lerp(0.42, 0.12, factor)
	bot_reload_time = lerp(1.35, 0.45, factor)
	bot_dist_attack = lerp(105.0, 65.0, factor)
	bot_dist_chase = lerp(190.0, 260.0, factor)
	bot_change_dir_time = lerp(0.30, 0.08, factor)
	print(
		"--- BOT DIFFICULTY ELO ",
		clamped_elo,
		" | Factor: ",
		snapped(factor, 0.01),
        " ---"
	)

	print(
		"Speed: ", snapped(bot_speed, 0.01),
		" | Spread: ", snapped(bot_spread, 0.01),
		" | FireRate: ", snapped(bot_fire_rate, 0.01),
		" | Damage: ", bot_damage,
		" | Reload: ", snapped(bot_reload_time, 0.01)
	)

func _ready():
	# Hned při zapnutí hry načteme data z disku
	load_system_config()
	calculate_rank()
	update_bot_difficulty()

# --- UKLÁDÁNÍ A NAČÍTÁNÍ (ZÁPIS NA DISK JEN KDYŽ JE TO NUTNÉ) ---

func load_system_config():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILE_PATH)
	
	if err == OK:
		username = config.get_value("Player", "username", "Krystof")
		elo = config.get_value("Player", "elo", 1000)
		print("Data uspesne nactena z disku. ELO: ", elo)
	else:
		print("Zadny ukladaci soubor nenalezen, pouzivam vychozi hodnoty.")
		# Pokud soubor neexistuje, vytvoříme ho s výchozími daty
		save_system_config()

func save_system_config():
	var config = ConfigFile.new()
	config.set_value("Player", "username", username)
	config.set_value("Player", "elo", elo)
	
	var err = config.save(CONFIG_FILE_PATH)
	if err == OK:
		print("Data byla uspesne zapsana na disk.")
	else:
		print("Chyba pri zapisu na disk! Kod chyby: ", err)


const RANKS = [
	# --- BRONZE ---
	{"max_elo": 99, "title": "Bronze 1", "asset": "res://assets/Ranks/Bronze/Bronze1.png"},
	{"max_elo": 199, "title": "Bronze 2", "asset": "res://assets/Ranks/Bronze/Bronze2.png"},
	{"max_elo": 299, "title": "Bronze 3", "asset": "res://assets/Ranks/Bronze/Bronze3.png"},
	{"max_elo": 399, "title": "Bronze 4", "asset": "res://assets/Ranks/Bronze/Bronze4.png"},
	{"max_elo": 499, "title": "Bronze PUSH", "asset": "res://assets/Ranks/Bronze/BronzePUSH.png"},

	# --- SILVER ---
	{"max_elo": 599, "title": "Silver 1", "asset": "res://assets/Ranks/Silver/Silver1.png"},
	{"max_elo": 699, "title": "Silver 2", "asset": "res://assets/Ranks/Silver/Silver2.png"},
	{"max_elo": 799, "title": "Silver 3", "asset": "res://assets/Ranks/Silver/Silver3.png"},
	{"max_elo": 899, "title": "Silver 4", "asset": "res://assets/Ranks/Silver/Silver4.png"},
	{"max_elo": 999, "title": "Silver PUSH", "asset": "res://assets/Ranks/Silver/SilverPUSH.png"},

	# --- GOLD ---
	{"max_elo": 1099, "title": "Gold 1", "asset": "res://assets/Ranks/Gold/Gold1.png"},
	{"max_elo": 1199, "title": "Gold 2", "asset": "res://assets/Ranks/Gold/Gold2.png"},
	{"max_elo": 1299, "title": "Gold 3", "asset": "res://assets/Ranks/Gold/Gold3.png"},
	{"max_elo": 1399, "title": "Gold 4", "asset": "res://assets/Ranks/Gold/Gold4.png"},
	{"max_elo": 1499, "title": "Gold PUSH", "asset": "res://assets/Ranks/Gold/GoldPUSH.png"},

	{"max_elo": 1599, "title": "Champ 1", "asset": "res://assets/Ranks/Champ/Champ1.png"},
	{"max_elo": 1699, "title": "Champ 2", "asset": "res://assets/Ranks/Champ/Champ2.png"},
	{"max_elo": 1799, "title": "Champ 3", "asset": "res://assets/Ranks/Champ/Champ3.png"},
	{"max_elo": 1899, "title": "Champ 4", "asset": "res://assets/Ranks/Champ/Champ4.png"},
	{"max_elo": 99999, "title": "Champ 5", "asset": "res://assets/Ranks/Champ/Champ5.png"}
]

func calculate_rank():
	for rank_data in RANKS:
		if elo <= rank_data["max_elo"]:
			player_rank = rank_data["title"]
			rank_asset_path = rank_data["asset"]
			break

func start_match(mode: String, map_path: String):
	current_mode = mode
	print("ModeManager: Startuju mod: ", current_mode)
	update_bot_difficulty()
	if has_node("/root/GameManager"):
		if current_mode == "ranked":
			get_node("/root/GameManager").init_match(24, current_mode, map_path)
		else:
			get_node("/root/GameManager").init_match(15, current_mode, map_path)
	else:
		print("CHYBA: GameManager Autoload neni zaregistrovany!")

func process_match_end(victory: bool, final_kills: int, final_deaths: int):
	print("ModeManager: Zapas skoncil. Zpracovavam vysledky...")
	
	if current_mode == "ranked":
		var elo_change = 0
		if victory:
			elo_change += 25
		else:
			elo_change -= 20
		
		elo_change += (final_kills - final_deaths) * 2 
		
		elo += elo_change
		print("Zmena ELO: ", elo_change, ". Nove celkove ELO: ", elo)
		
		# Aktualizujeme textový rank a hned zapišeme změny na disk
		calculate_rank()
		save_system_config()
	else:
		print("Byl to Casual, ELO se nemeni.")
		
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn") 
