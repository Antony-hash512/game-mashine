extends CanvasLayer

@onready var coin_label: Label = $MarginContainer/PanelContainer/HBoxContainer/CoinLabel

func _ready() -> void:
	# Initial clear state, will be updated by Level
	update_coins(0, 0)

func update_coins(collected: int, total: int) -> void:
	if coin_label:
		coin_label.text = "%d / %d" % [collected, total]
