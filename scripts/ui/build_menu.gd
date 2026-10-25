# scripts/ui/build_menu.gd
extends Panel

# A dynamically populated, categorized build menu.

var _population_queued := false

@onready var tab_container = $TabContainer

func _ready():
    # Defer population to the next frame to ensure autoloads are ready.
    _request_population()
    EventBus.level_up.connect(func(_level): _request_population())
    SaveManager.save_activated.connect(func(): _request_population())

# Fetches all building definitions from the DataManager, groups them by
# category, and creates a tab with buttons for each category.
func populate_build_menu():
    # Clear any existing tabs/buttons for dynamic reloading.
    for child in tab_container.get_children():
        tab_container.remove_child(child)
        child.queue_free()

    var buildings_by_category = {}
    var all_buildings = DataManager.get_all_building_definitions()

    for building_def in all_buildings:
        # Skip buildings with no category or that shouldn't be in the menu.
        if str(building_def.id) not in DataManager.rules.buildings:
            continue
        if not building_def or not "category" in building_def or building_def.category.is_empty():
            continue

        if not buildings_by_category.has(building_def.category):
            buildings_by_category[building_def.category] = []
        
        buildings_by_category[building_def.category].append(building_def)

    var sorted_categories = buildings_by_category.keys()
    sorted_categories.sort()

    for category in sorted_categories:
        var grid = GridContainer.new()
        grid.columns = 3
        grid.name = category
        
        var scroll = ScrollContainer.new()
        scroll.name = category
        scroll.add_child(grid)
        tab_container.add_child(scroll)
        tab_container.set_tab_title(tab_container.get_child_count() - 1, category)

        var buildings = buildings_by_category[category]
        buildings.sort_custom(func(a, b):
            if ProgressionManager.unlocked(a) != ProgressionManager.unlocked(b): return ProgressionManager.unlocked(a)
            return a.display_name < b.display_name
        )

        for building_def in buildings:
            var button = Button.new()
            button.set_meta("definition_id", building_def.id)
            button.custom_minimum_size = Vector2(240, 250)
            
            # Use a VBoxContainer inside the button to align icon and text
            var container = VBoxContainer.new()
            container.alignment = BoxContainer.ALIGNMENT_CENTER
            container.mouse_filter = Control.MOUSE_FILTER_PASS
            button.add_child(container)
            
            # Set anchors so the container fills the entire button area
            container.set_anchors_preset(Control.PRESET_FULL_RECT)
            container.grow_horizontal = Control.GROW_DIRECTION_BOTH
            container.grow_vertical = Control.GROW_DIRECTION_BOTH
            
            # Create a TextureRect for the building icon
            var icon_rect = Control.new()
            icon_rect.custom_minimum_size = Vector2(200, 70)
            icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
            if ResourceLoader.exists(building_def.icon_path):
                var sprite = Sprite2D.new()
                sprite.texture = load(building_def.icon_path)
                var ground = BuildingVisuals.configure(sprite, building_def)
                sprite.position += Vector2(100, 65) - ground
                icon_rect.add_child(sprite)
            container.add_child(icon_rect)

            # Create a Label for the building name
            var label = Label.new()
            label.text = building_def.display_name
            if not ProgressionManager.unlocked(building_def):
                label.text += "\nLocked: Level %d" % building_def.playable_level
                button.set_meta("locked", true)
            label.text += "\n%d×%d tiles · %ds construction" % [building_def.width, building_def.height, building_def.build_time_seconds]
            if building_def.house_capacity > 0: label.text += "\n%d residents%s" % [building_def.house_capacity, " · one starter per town" if building_def.id == 10012 else ""]
            for entry in building_def.cost.entries:
                var resource = DataManager.get_resource_definition(entry.resource_id)
                if resource:
                    label.text += "\n%d %s" % [entry.amount, resource.display_name]
            label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            label.mouse_filter = Control.MOUSE_FILTER_PASS
            
            container.add_child(label)
            
            button.pressed.connect(_on_building_button_pressed.bind(building_def))
            grid.add_child(button)

# Callback for when a building button is pressed.
# Emits a signal on the EventBus to notify the game to enter placement mode.
func _on_building_button_pressed(building_def):
    if not ProgressionManager.unlocked(building_def):
        EventBus.town_notice.emit("%s unlocks at level %d." % [building_def.display_name, building_def.playable_level])
        return
    EventBus.building_selected_for_placement.emit(building_def)
    self.hide()

func _request_population() -> void:
    if _population_queued: return
    _population_queued = true
    call_deferred("_populate_queued")

func _populate_queued() -> void:
    _population_queued = false
    populate_build_menu()
