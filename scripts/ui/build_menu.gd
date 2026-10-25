# scripts/ui/build_menu.gd
extends Panel

# A dynamically populated, categorized build menu.

@onready var tab_container = $TabContainer

func _ready():
    # Defer population to the next frame to ensure autoloads are ready.
    call_deferred("populate_build_menu")

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
        buildings.sort_custom(func(a, b): return a.display_name < b.display_name)

        for building_def in buildings:
            var button = Button.new()
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
            icon_rect.custom_minimum_size = Vector2(200, 90)
            icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
            if not building_def.icon_path.is_empty():
                var sprite = Sprite2D.new()
                sprite.texture = load(building_def.icon_path)
                var ground = BuildingVisuals.configure(sprite, building_def)
                sprite.position += Vector2(100, 85) - ground
                icon_rect.add_child(sprite)
            container.add_child(icon_rect)

            # Create a Label for the building name
            var label = Label.new()
            label.text = building_def.display_name
            if SaveManager.current_save.player_state.mayor_level < building_def.playable_level:
                label.text += "\nLocked: Level %d" % building_def.playable_level
                button.disabled = true
            label.text += "\n%d×%d tiles · %ds construction\n%d supported view(s)" % [building_def.width, building_def.height, building_def.build_time_seconds, BuildingVisuals.orientations(building_def).size()]
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
    # In a full implementation, we would check prerequisites and costs here.
    # For now, we'll assume the player can afford it and emit the signal directly.
    #
    # Example of a future check:
    # if EconomyManager.can_afford(building_def.cost):
    #     EventBus.building_selected_for_placement.emit(building_def)
    #     self.hide() # Hide menu after selection
    # else:
    #     # Show "not enough resources" UI feedback.
    #     print("Cannot afford building: " + building_def.display_name)
    
    EventBus.building_selected_for_placement.emit(building_def)
    self.hide()
