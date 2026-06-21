extends CharacterBody2D

# Настройки физики движения
@export var speed: float = 400.0
@export var acceleration: float = 1800.0
@export var friction: float = 1400.0
@export var jump_velocity: float = -800.0

# Сила тяжести
var gravity: float = 2000.0

# Ссылки на дочерние ноды
@onready var sprite: Sprite2D = $Sprite2D
@onready var jump_sfx: AudioStreamPlayer2D = $JumpSFX

# Списки кадров для анимации из player.png (сетка 9x7)
const IDLE_FRAMES = [0, 1]
const RUN_FRAMES = [3, 4, 5, 6, 7, 9, 10]
const JUMP_FRAME = 23
const FALL_FRAME = 44

# Таймер анимации в коде для простоты
var anim_timer: float = 0.0
var anim_frame_index: int = 0
const ANIM_SPEED: float = 0.12 # Время между кадрами (120 мс)

func _physics_process(delta: float) -> void:
	# 1. Применение гравитации
	if not is_on_floor():
		velocity.y += gravity * delta
		# Ограничение максимальной скорости падения
		if velocity.y > 1000.0:
			velocity.y = 1000.0

	# 2. Обработка прыжка
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		if jump_sfx and jump_sfx.stream:
			jump_sfx.play()

	# 3. Горизонтальное движение и трение/ускорение
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		# Ускорение персонажа
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		# Поворот спрайта
		sprite.flip_h = direction < 0
	else:
		# Трение и замедление при отсутствии ввода
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()

	# 4. Проигрывание анимаций
	update_animations(delta, direction)

func update_animations(delta: float, direction: float) -> void:
	anim_timer += delta
	if anim_timer >= ANIM_SPEED:
		anim_timer = 0.0
		anim_frame_index += 1

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
		# Анимация в воздухе
		if velocity.y < 0:
			sprite.frame = JUMP_FRAME
		else:
			sprite.frame = FALL_FRAME
