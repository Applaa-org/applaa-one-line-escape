extends Node

# Persistent global data
var score: int = 0
var high_score: int = 0
var last_player_name: String = ""
var game_id: String = "one_line_escape" # set a unique game id

signal score_changed(new_score: int)

func _ready():
	# Ensure high score UI starts at 0 before loading
	high_score = 0
	# Request stored data from Applaa (for web export)
	# This will trigger 'applaa-game-data-loaded' in the wrapper which should call apply_loaded_data via JavaScriptBridge or postMessage
	if Engine.has_singleton("JavaScriptBridge"):
		# Request load - will be handled by embed wrapper
		JavaScriptBridge.eval("window.parent.postMessage({ type: 'applaa-game-load-data', gameId: '%s' }, '*');" % game_id)

func add_score(points: int):
	score += points
	emit_signal("score_changed", score)

func reset_score():
	score = 0
	emit_signal("score_changed", score)

func set_high_score(value: int):
	high_score = value

# Called by external message listener (see Main.gd wrapper)
func apply_loaded_data(data: Dictionary) -> void:
	if data == null:
		return
	high_score = int(data.get("highScore", 0))
	last_player_name = str(data.get("lastPlayerName", ""))
	# If there are scores, optionally compute best
	if data.has("scores"):
		var scores = data.scores
		if scores.size() > 0:
			var best = 0
			for s in scores:
				if int(s.score) > best:
					best = int(s.score)
			high_score = best

func save_score_to_storage(player_name: String, final_score: int) -> void:
	# Save using Applaa messages via JavaScriptBridge for web exports
	last_player_name = player_name
	if Engine.has_singleton("JavaScriptBridge"):
		JavaScriptBridge.eval("""window.parent.postMessage({ type: 'applaa-game-save-score', gameId: '%s', playerName: '%s', score: %d }, '*');""" % [game_id, player_name.replace("'", "\\'"), final_score])