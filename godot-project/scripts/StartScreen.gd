extends Control

@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var player_name_input: LineEdit = $VBoxContainer/NameInput
@onready var leaderboard_container: VBoxContainer = $VBoxContainer/Leaderboard

func _ready():
	# Initialize immediately to 0 and visible
	if high_score_label:
		high_score_label.text = "High Score: 0"
		high_score_label.visible = true
	# Request stored data via Global (Global will post a request in its _ready())
	# Listen for a custom signal from the root (Main will call update_ui_from_storage)
	get_tree().get_root().connect("applaa_data_loaded", Callable(self, "_on_applaa_data_loaded"))

func _on_Start_pressed():
	# prefill player name
	var name = player_name_input.text.strip_edges()
	if name == "":
		name = "Player"
	# Pass player name via SceneTree metadata for use in gameplay
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	get_tree().current_scene.set_meta("player_name", name)

func _on_Close_pressed():
	get_tree().quit()

# Called by top-level message listener when data arrives
func _on_applaa_data_loaded(data):
	if not data:
		return
	var high = int(data.get("highScore", 0))
	high_score_label.text = "High Score: %d" % high
	# Fill lastPlayerName
	var last = str(data.get("lastPlayerName", ""))
	if last != "":
		player_name_input.text = last
	# Update leaderboard if scores exist
	if data.has("scores"):
		leaderboard_container.clear()
		var scores = data.scores
		for i in range(min(5, scores.size())):
			var s = scores[i]
			var lb = Label.new()
			lb.text = "%d. %s - %s" % [i + 1, str(s.playerName), str(s.score)]
			leaderboard_container.add_child(lb)