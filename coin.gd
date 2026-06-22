extends Area2D

signal collected

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var sprite_config: Dictionary = {}
var current_action: String = ""
var _texture_cache: Dictionary = {}

var anim_timer: float = 0.0
var anim_frame_index: int = 0
var is_collected: bool = false

func _ready() -> void:
	load_sprite_config()
	# Start with rotation animation
	play_action("rotation", 0.0)
	body_entered.connect(_on_body_entered)

func load_sprite_config() -> void:
	var path = "res://sprites.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(json_text)
			if parsed is Dictionary and parsed.has("coin"):
				sprite_config = parsed["coin"]
			else:
				push_error("Неверный формат sprites.json")
		else:
			push_error("Не удалось открыть sprites.json")
	else:
		push_error("Файл sprites.json не найден")

func get_texture(file_name: String) -> Texture2D:
	if not _texture_cache.has(file_name):
		var path = "res://assets/images/" + file_name
		if ResourceLoader.exists(path):
			_texture_cache[file_name] = load(path)
		else:
			push_error("Текстура не найдена: " + path)
			_texture_cache[file_name] = null
	return _texture_cache[file_name]

func _process(delta: float) -> void:
	if is_collected:
		play_action("explosion", delta)
	else:
		play_action("rotation", delta)

func play_action(action_name: String, delta: float) -> void:
	if not sprite_config.has(action_name):
		return

	var action_data: Dictionary = sprite_config[action_name]
	
	if current_action != action_name:
		current_action = action_name
		anim_timer = 0.0
		anim_frame_index = 0

	var file_name: String = action_data.get("file", "")
	if file_name != "":
		var tex = get_texture(file_name)
		if tex and sprite.texture != tex:
			sprite.texture = tex

	sprite.region_enabled = true
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.frame = 0

	var frames: Array = action_data.get("frames", [])
	if frames.is_empty():
		return

	var spf = action_data.get("spf")
	var frame_delay: float = 0.12 # Default spf
	if spf != null:
		frame_delay = float(spf)

	anim_timer += delta
	if anim_timer >= frame_delay:
		anim_timer = 0.0
		anim_frame_index += 1
		if is_collected and anim_frame_index >= frames.size():
			sprite.visible = false
			if not audio_player.playing:
				queue_free()

	var current_frame_idx = anim_frame_index
	if not is_collected:
		current_frame_idx = anim_frame_index % frames.size()
	else:
		current_frame_idx = min(anim_frame_index, frames.size() - 1)

	var rect_arr = frames[current_frame_idx]
	if rect_arr is Array and rect_arr.size() == 4:
		sprite.region_rect = Rect2(rect_arr[0], rect_arr[1], rect_arr[2], rect_arr[3])

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	
	# Check if the body is the player
	if body.name == "Player" or body.has_method("load_sprite_config"):
		is_collected = true
		collision_shape.set_deferred("disabled", true)
		
		# Play audio
		if audio_player:
			audio_player.play()
		
		# Notify level/HUD
		collected.emit()
		var level = get_tree().current_scene
		if level and level.has_method("collect_coin"):
			level.collect_coin()

		# Safety check/cleanup on audio finish
		if audio_player:
			audio_player.finished.connect(func():
				if not sprite.visible or anim_frame_index >= sprite_config.get("explosion", {}).get("frames", []).size():
					queue_free()
			)
