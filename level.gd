extends Node2D

# Путь к файлу уровня
const LEVEL_FILE_PATH = "res://level_test.txt"

# Размеры ячеек
const TILE_SIZE = 180

# Переменные для хранения размеров карты
var map_cols: int = 0
var map_rows: int = 0

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var music_player: AudioStreamPlayer = $MusicPlayer

func _ready() -> void:
	# 1. Настройка тайлсета программно
	setup_tileset()

	# 2. Загрузка и парсинг уровня
	load_level()

	# 3. Запуск фоновой музыки
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
	var file = FileAccess.open(LEVEL_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Не удалось открыть файл уровня по пути: " + LEVEL_FILE_PATH)
		# Создаем дефолтную карту, если файл не найден
		load_default_level()
		return

	var lines: Array[String] = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.length() > 0:
			lines.append(line)
	file.close()

	map_rows = lines.size()
	map_cols = lines[0].length()

	var player_spawn_pos = Vector2.ZERO
	var has_player = false

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
