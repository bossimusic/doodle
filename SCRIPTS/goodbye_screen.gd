extends CanvasLayer

@onready var bg: ColorRect = $BG
@onready var label: Label = $Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_goodbye() -> void:
	visible = true
	bg.modulate.a = 0.0
	label.visible_ratio = 0.0
	var tw := create_tween()
	tw.tween_property(bg, "modulate:a", 1.0, 0.6)
	await tw.finished
	tw = create_tween()
	tw.tween_property(label, "visible_ratio", 1.0, 0.6)
	await tw.finished
	await get_tree().create_timer(1.2).timeout
	GameState._quit()
