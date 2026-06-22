extends Node2D

# Путь к файлу уровня
const LEVEL_FILE_PATH = "res://level_test.txt"

# Размеры ячеек
const TILE_SIZE = 180

# Переменные для хранения размеров карты
var map_cols: int = 0
var map_rows: int = 0

# Переменные для монет и HUD
var collected_coins: int = 0
var total_coins: int = 0
var hud: CanvasLayer = null

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var music_player: AudioStreamPlayer = $MusicPlayer

func _ready() -> void:
	# 1. Настройка тайлсета программно
	setup_tileset()

	# 2. Загрузка и парсинг уровня
	load_level()

	# 3. Инициализация HUD
	setup_hud()

	# 4. Запуск фоновой музыки
	if music_player:
		music_player.play()
		# Автоматически зацикливаем музыку при завершении
		music_player.finished.connect(func(): music_player.play())

func setup_tileset() -> void:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Добавляем физический слой (для обработки столкновений)
	tileset.add_physics_layer()

	# Создаем источник текстуры (Атлас)
	var atlas_source = TileSetAtlasSource.new()
	var texture = load("res://assets/images/tileset_grass.png")
	if texture:
		atlas_source.texture = texture
		atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		
		# Создаем тайл в координатах атласа R0 C0 (строка 0, колонка 0)
		atlas_source.create_tile(Vector2i(0, 0))
		
		# Сначала добавляем источник в тайлсет, чтобы связать с физическим слоем
		tileset.add_source(atlas_source, 0)
		
		# Настраиваем коллайдер для этого тайла
		var tile_data = atlas_source.get_tile_data(Vector2i(0, 0), 0)
		if tile_data:
			# Коллайдер только на видимую часть плитки (высота 117 пикселей от верха)
			# Относительно центра ячейки (90, 90): верх равен -90, низ равен -90 + 117 = +27
			var collision_points = PackedVector2Array([
				Vector2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0),
				Vector2(TILE_SIZE / 2.0, -TILE_SIZE / 2.0),
				Vector2(TILE_SIZE / 2.0, 27.0),
				Vector2(-TILE_SIZE / 2.0, 27.0)
			])
			tile_data.add_collision_polygon(0)
			tile_data.set_collision_polygon_points(0, 0, collision_points)
	
	tile_map_layer.tile_set = tileset

func load_level() -> void:
	if OS.has_feature("web"):
		load_level_from_web()
	else:
		load_level_from_local()

func load_level_from_local() -> void:
	var file = FileAccess.open(LEVEL_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Не удалось открыть файл уровня по пути: " + LEVEL_FILE_PATH)
		# Создаем дефолтную карту, если файл не найден
		load_default_level()
		return

	var text = file.get_as_text()
	file.close()
	parse_level_data(text)

func load_level_from_web() -> void:
	var url = "level_test.txt"
	if OS.has_feature("web"):
		var resolved = JavaScriptBridge.eval("new URL('level_test.txt', window.location.href).href")
		if resolved:
			url = resolved

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		http.queue_free()
		_on_web_level_loaded(result, response_code, headers, body)
	)
	var err = http.request(url)
	if err != OK:
		push_error("Ошибка инициализации HTTP-запроса уровня: " + str(err))
		http.queue_free()
		load_default_level()

func _on_web_level_loaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var text = body.get_string_from_utf8()
		parse_level_data(text)
	else:
		push_warning("Не удалось скачать уровень через HTTP. Результат: %d, Код: %d. Попытка загрузить из ресурсов..." % [result, response_code])
		if FileAccess.file_exists(LEVEL_FILE_PATH):
			var file = FileAccess.open(LEVEL_FILE_PATH, FileAccess.READ)
			if file:
				var text = file.get_as_text()
				file.close()
				parse_level_data(text)
				return
		push_error("Не удалось найти упакованный уровень. Переключение на дефолтную генерацию.")
		load_default_level()

func parse_level_data(level_text: String) -> void:
	var lines: Array[String] = []
	var raw_lines = level_text.split("\n")
	for raw_line in raw_lines:
		var line = raw_line.strip_edges()
		if line.length() > 0:
			lines.append(line)

	if lines.size() == 0:
		push_error("Данные уровня пусты!")
		load_default_level()
		return

	map_rows = lines.size()
	map_cols = lines[0].length()

	var player_spawn_pos = Vector2.ZERO
	var has_player = false

	# Сбрасываем счетчики монет при парсинге уровня
	collected_coins = 0
	total_coins = 0

	# Заполняем сетку
	for y in range(map_rows):
		var line = lines[y]
		for x in range(map_cols):
			if x >= line.length():
				continue
			var char = line[x]
			match char:
				'#':
					# Ставим тайл земли (source_id = 0, atlas_coords = Vector2i(0,0))
					tile_map_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
				'P':
					# Точка спавна игрока (центр ячейки)
					player_spawn_pos = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
					has_player = true
				'o':
					# Спавн монеты
					spawn_coin(Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0))

	# Создаем игрока и ставим его на позицию спавна
	if has_player:
		spawn_player(player_spawn_pos)

func load_default_level() -> void:
	# Простой резервный уровень в случае отсутствия файла
	map_rows = 5
	map_cols = 10
	for x in range(map_cols):
		tile_map_layer.set_cell(Vector2i(x, 4), 0, Vector2i(0, 0))
	spawn_player(Vector2(2 * TILE_SIZE + TILE_SIZE / 2.0, 3 * TILE_SIZE + TILE_SIZE / 2.0))

func spawn_player(pos: Vector2) -> void:
	var player_scene = load("res://player.tscn")
	if player_scene:
		var player = player_scene.instantiate()
		player.name = "Player"
		player.global_position = pos
		add_child(player)
	else:
		push_error("Не удалось загрузить player.tscn!")

func spawn_coin(pos: Vector2) -> void:
	var coin_scene = load("res://coin.tscn")
	if coin_scene:
		var coin = coin_scene.instantiate()
		coin.global_position = pos
		add_child(coin)
		total_coins += 1
	else:
		push_error("Не удалось загрузить coin.tscn!")

func setup_hud() -> void:
	var hud_scene = load("res://hud.tscn")
	if hud_scene:
		hud = hud_scene.instantiate()
		add_child(hud)
		hud.update_coins(collected_coins, total_coins)
	else:
		push_error("Не удалось загрузить hud.tscn!")

func collect_coin() -> void:
	collected_coins += 1
	if hud:
		hud.update_coins(collected_coins, total_coins)

func _physics_process(_delta: float) -> void:
	# Реализация бесшовного зацикливания (wrapping) слева и справа
	var player = get_node_or_null("Player")
	if player:
		var level_width = map_cols * TILE_SIZE
		if player.global_position.x < 0:
			player.global_position.x += level_width
			var camera = player.get_node_or_null("Camera2D")
			if camera:
				camera.align()
		elif player.global_position.x > level_width:
			player.global_position.x -= level_width
			var camera = player.get_node_or_null("Camera2D")
			if camera:
				camera.align()
