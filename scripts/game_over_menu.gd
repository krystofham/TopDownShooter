extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var restart_btn = get_node_or_null("ColorRect/VBoxContainer/RestartButton")
	var quit_btn = get_node_or_null("ColorRect/VBoxContainer/QuitButton")
	
	if restart_btn and not restart_btn.pressed.is_connected(_on_restart_button_pressed):
		restart_btn.pressed.connect(_on_restart_button_pressed)
		
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit_button_pressed):
		quit_btn.pressed.connect(_on_quit_button_pressed)

func _on_restart_button_pressed():
	print("Restartuji scénu...")
	get_tree().paused = false 
	get_tree().reload_current_scene() 

func _on_quit_button_pressed():
	print("Ukončuji hru z Game Over menu...")
	get_tree().quit()
