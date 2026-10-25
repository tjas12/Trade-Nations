extends Panel

var market_box: VBoxContainer
var expansion_box: VBoxContainer
var _status: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -240
	offset_top = -190
	offset_right = 240
	offset_bottom = 190
	market_box = VBoxContainer.new()
	market_box.position = Vector2(20, 16)
	market_box.size = Vector2(440, 320)
	add_child(market_box)
	var title := Label.new()
	title.text = "Town Market · Local sales"
	market_box.add_child(title)
	for key in DataManager.rules.market:
		var resource := int(key)
		var row := HBoxContainer.new()
		market_box.add_child(row)
		var label := Label.new()
		label.text = "%s · %d Gold each" % [DataManager.get_resource_definition(resource).display_name, DataManager.rules.market[key]]
		label.custom_minimum_size.x = 220
		row.add_child(label)
		var quantity := SpinBox.new()
		quantity.min_value = 1
		quantity.max_value = 100
		row.add_child(quantity)
		var sell := Button.new()
		sell.text = "Sell"
		sell.pressed.connect(func(): _sell(resource, int(quantity.value)))
		row.add_child(sell)
	var buy_food := Button.new()
	buy_food.text = "Buy 1 Wheat · %d Gold (food reserve)" % DataManager.rules.market_buy["40"]
	buy_food.pressed.connect(func():
		_status.text = "Bought 1 Wheat." if SocialManager.buy_from_market(40, 1) else "Need more Gold or free Wheat storage."
	)
	market_box.add_child(buy_food)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	market_box.add_child(_status)
	expansion_box = VBoxContainer.new()
	expansion_box.position = Vector2(20, 16)
	expansion_box.size = Vector2(440, 310)
	add_child(expansion_box)
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expansion_box.add_child(info)
	var buy := Button.new()
	buy.text = "Purchase expansion"
	buy.pressed.connect(func():
		var message := expand()
		info.text = message
		EventBus.town_notice.emit(message)
	)
	expansion_box.add_child(buy)
	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(190, 335)
	close.pressed.connect(hide)
	add_child(close)
	hide()

func open_market() -> void:
	market_box.show()
	expansion_box.hide()
	_status.text = "Cookies arrive directly in town storage. Collect raw harvests or assign haulers."
	show()

func open_expansion() -> void:
	market_box.hide()
	expansion_box.show()
	var rule: Dictionary = DataManager.rules.expansion
	var size: int = SaveManager.current_save.player_state.active_land_size
	expansion_box.get_child(0).text = "Town expansion\n%d×%d → %d×%d tiles\nCost: %d Gold + %d Wood · Level %d\nOne expansion is available in this first playable." % [size, size, size + rule.increase, size + rule.increase, rule.gold, rule.wood, rule.level]
	show()

func _sell(resource: int, quantity: int) -> void:
	_status.text = "Sold %d %s." % [quantity, DataManager.get_resource_definition(resource).display_name] if sell_goods(resource, quantity) else "Not enough goods to sell that quantity."
	EventBus.town_notice.emit(_status.text)

static func sell_goods(resource: int, quantity: int) -> bool:
	return SocialManager.sell_to_market(resource, quantity)

static func expand() -> String:
	return SocialManager.expand_town()
