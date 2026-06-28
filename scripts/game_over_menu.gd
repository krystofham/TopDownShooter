extends CanvasLayer

func _ready():
	# Když se menu objeví, chceme, aby se hra zapauzovala
	process_mode = PROCESS_MODE_ALWAYS # Menu poběží i při pauze
	get_tree().paused = true
	
	# Zviditelníme myš, pokud jsi ji měl ve hře schovanou nebo změněnou
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_restart_button_pressed():
	get_tree().paused = false # Odpauzujeme hru
	get_tree().reload_current_scene() # Znovu načteme aktuální scénu (restart)

func _on_quit_button_pressed():
	get_tree().quit() # Zavře hru
