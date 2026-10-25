# scripts/ui/tutorial_popup.gd
extends Panel

@onready var objective_label: Label = $VBoxContainer/ObjectiveLabel
@onready var continue_button: Button = $VBoxContainer/ContinueButton

func _ready() -> void:
	continue_button.pressed.connect(hide)
	continue_button.hide()
	hide()

func show_objective(text: String) -> void:
	if objective_label.text == text: return
	objective_label.text = text
	show()
