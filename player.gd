extends CharacterBody2D

# Настройки физики движения
@export var speed: float = 400.0
@export var acceleration: float = 1800.0
@export var friction: float = 1400.0
@export var jump_velocity: float = -1250.0
@export var running_jump_boost: float = 1.5

# Сила тяжести
var gravity: float = 2000.0

# Ссылки на дочерние ноды
@onready var sprite: Sprite2D = $Sprite2D
@onready var jump_sfx: AudioStreamPlayer2D = $JumpSFX

# Переменные для динамической анимации
var sprite_config: Dictionary = {}
var current_action: String = ""
var _texture_cache: Dictionary = {}

var anim_timer: float = 0.0
var anim_frame_index: int = 0

func _ready() -> void:
	load_sprite_config()

func load_sprite_config() -> void:
	var path = "res://sprites.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			
			var parsed = JSON.parse_string(json_text)
			if parsed is Dictionary and parsed.has("player"):
				sprite_config = parsed["player"]
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

# Состояние приземления
var is_landing: bool = false
var landing_timer: float = 0.0
const LANDING_DURATION: float = 0.20 # Длительность приземления (200 мс)

# Переменная для отслеживания состояния "в воздухе" в предыдущем кадре
var was_in_air: bool = false

# Состояние прыжка с разбега (дает повышенную горизонтальную скорость в воздухе)
var is_running_jump: bool = false

func _physics_process(delta: float) -> void:
	# 1. Применение гравитации
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y > 1000.0:
			velocity.y = 1000.0
		was_in_air = true
	else:
		# Обработка момента приземления на землю
		if was_in_air:
			is_landing = true
			landing_timer = LANDING_DURATION
			was_in_air = false
			is_running_jump = false # Сбрасываем прыжок с разбега при приземлении

	# 2. Обработка таймера приземления
	if is_landing:
		landing_timer -= delta
		if landing_timer <= 0.0:
			is_landing = false

	# 3. Обработка прыжка
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		is_landing = false
		
		# Если скорость бега перед прыжком была высокой (>70% от максимальной), прыгаем с разбега
		if abs(velocity.x) > speed * 0.7:
			is_running_jump = true
		else:
			is_running_jump = false
			
		if jump_sfx and jump_sfx.stream:
			jump_sfx.play()

	# 4. Горизонтальное движение и трение/ускорение
	var direction := Input.get_axis("move_left", "move_right")
	
	var current_speed = speed
	if is_landing:
		current_speed = speed * 0.4 # Замедляем игрока при приземлении
	elif not is_on_floor() and is_running_jump:
		current_speed = speed * running_jump_boost # Увеличиваем предел горизонтальной скорости в прыжке с разбега на 50%
		
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * current_speed, acceleration * delta)
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()

	# 5. Проигрывание анимаций
	update_animations(delta, direction)

func update_animations(delta: float, _direction: float) -> void:
	var action := ""
	if is_landing:
		action = "landing"
	elif is_on_floor():
		if abs(velocity.x) > 10.0:
			action = "running"
		else:
			action = "idle"
	else:
		if velocity.y < -150.0:
			action = "jumping_start"
		elif velocity.y > 150.0:
			action = "falling"
		else:
			action = "jumping_top_point"

	play_action(action, delta)

func play_action(action_name: String, delta: float) -> void:
	if not sprite_config.has(action_name):
		# Игнорируем экшены, не описанные для игрока в JSON, не падая с ошибкой
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
	var frame_delay: float = 0.12
	if spf != null:
		frame_delay = float(spf)

	anim_timer += delta
	if anim_timer >= frame_delay:
		anim_timer = 0.0
		anim_frame_index += 1

	var current_frame_idx = anim_frame_index % frames.size()
	var rect_arr = frames[current_frame_idx]
	if rect_arr is Array and rect_arr.size() == 4:
		sprite.region_rect = Rect2(rect_arr[0], rect_arr[1], rect_arr[2], rect_arr[3])
