extends CanvasLayer

@onready var coin_icon: TextureRect = $MarginContainer/PanelContainer/HBoxContainer/CoinIcon
@onready var coin_label: Label = $MarginContainer/PanelContainer/HBoxContainer/CoinLabel

func _ready() -> void:
	# Initial clear state, will be updated by Level
	update_coins(0, 0)
	setup_coin_icon()

func setup_coin_icon() -> void:
	var path = "res://sprites.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(json_text)
			if parsed is Dictionary and parsed.has("coin"):
				var coin_config = parsed["coin"]
				if coin_config.has("static"):
					var static_data = coin_config["static"]
					var file_name = static_data.get("file", "")
					var frames = static_data.get("frames", [])
					if file_name != "" and not frames.is_empty():
						var tex_path = "res://assets/images/" + file_name
						var texture = load(tex_path)
						if texture:
							var atlas_tex = AtlasTexture.new()
							atlas_tex.atlas = texture
							var rect_arr = frames[0]
							if rect_arr is Array and rect_arr.size() == 4:
								atlas_tex.region = Rect2(rect_arr[0], rect_arr[1], rect_arr[2], rect_arr[3])
								coin_icon.texture = atlas_tex
							else:
								push_error("Неверный формат кадра static в sprites.json")
						else:
							push_error("Не удалось загрузить текстуру: " + tex_path)
				else:
					push_error("Ключ static не найден в coin секции sprites.json")
			else:
				push_error("Неверный формат sprites.json")
		else:
			push_error("Не удалось открыть sprites.json")
	else:
		push_error("Файл sprites.json не найден")

func update_coins(collected: int, total: int) -> void:
	if coin_label:
		coin_label.text = "%d / %d" % [collected, total]
