extends Control

@onready var final_score_label: Label = $VBoxContainer/FinalScore
@onready var high_score_label: Label = $VBoxContainer/HighScore
@onready var name_input: LineEdit = $VBoxContainer/NameInput

func _ready():
	final_score_label.text = "Your Score: %d" % Global.score
	if Global.score > Global.high_score:
		high_score_label.text = "🎉 New High Score: %d" % Global.score
		Global.set_high_score(Global.score)
	else:
		high_score_label.text = "High Score: %d" % Global.high_score
	if Global.last_player_name != "":
		name_input.text = Global.last_player_name
	$VBoxContainer/Restart.pressed.connect(_on_restart)
	$VBoxContainer/MainMenu.pressed.connect(_on_main)
	$VBoxContainer/Close.pressed.connect(_on_close)

func _on_restart():
	Global.reset_score()
	get_tree().reload_current_scene()

func _on_main():
	Global.reset_score()
	get_tree().change_scene_to_file("res://scenes/StartScreen.tscn")

func _on_close():
	Global.save_score_to_storage(name_input.text.strip_edges(), Global.score)
	get_tree().quit()