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

# Списки кадров для анимации из player_alt.png (сетка 180x360, Hframes=10, Vframes=3)
const IDLE_FRAMES = [0, 1]
const RUN_FRAMES = [2, 3, 4, 5, 6]
const JUMP_FRAME = 10
const PEAK_FRAME = 11
const FALL_FRAME = 12

# Координаты региона для трехтайлового приземления
# Левый верхний угол ячейки R1 C3 в сетке 180x360: X = 3 * 180 = 540, Y = 1 * 360 = 360
# Ширина 3 тайла = 540, Высота 1 тайл = 360
const LAND_REGION_RECT = Rect2(540, 360, 540, 360)

# Таймер анимации в коде
var anim_timer: float = 0.0
var anim_frame_index: int = 0
const ANIM_SPEED: float = 0.12

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
			sprite.region_enabled = false

	# 3. Обработка прыжка
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		is_landing = false
		sprite.region_enabled = false
		
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

func update_animations(delta: float, direction: float) -> void:
	anim_timer += delta
	if anim_timer >= ANIM_SPEED:
		anim_timer = 0.0
		anim_frame_index += 1

	# Если проигрывается анимация приземления
	if is_landing:
		sprite.region_enabled = true
		sprite.region_rect = LAND_REGION_RECT
		return
	
	# Стандартные анимации
	sprite.region_enabled = false
	if is_on_floor():
		if abs(velocity.x) > 10.0:
			# Анимация бега
			var frame_idx = anim_frame_index % RUN_FRAMES.size()
			sprite.frame = RUN_FRAMES[frame_idx]
		else:
			# Анимация покоя (Idle)
			var frame_idx = anim_frame_index % IDLE_FRAMES.size()
			sprite.frame = IDLE_FRAMES[frame_idx]
	else:
		# Анимация в воздухе в зависимости от вертикальной скорости
		if velocity.y < -150.0:
			sprite.frame = JUMP_FRAME
		elif velocity.y > 150.0:
			sprite.frame = FALL_FRAME
		else:
			sprite.frame = PEAK_FRAME
