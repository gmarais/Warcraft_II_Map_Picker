# **************************************************************************** #
#                                                                              #
#                                                   :::::::::::::::::          #
#    main.gd                                       ::+::+::+::+::+::           #
#                                                 +      :+:      +            #
#    By: gmarais <gmarais@noreply.github.com>           +:+    +       +       #
#                                                      +#+    +#+     +#+      #
#    Created: 2022/12/17 09:38:16 by gmarais          #+#    #+ +#   #+ +#     #
#    Updated: 2022/12/17 09:38:19 by gmarais       #######  ##   ## ##   ##    #
#                                                                              #
# **************************************************************************** #
class_name Main
extends Node


const SECRET_MAP_DESCRIPTION = "A random mysterious map."
const LIGHT_TEXT_REGIONS_OFF = Rect2(0,0,16,16)
const LIGHT_TEXT_REGIONS_ON = Rect2(16,0,16,16)

enum WATER_OR_LAND {
	BOTH = 0
	WATER = 1
	LAND = 2
}

enum CRAMPED_OR_OPEN {
	BOTH = 0
	CRAMPED = 1
	OPEN = 2
}

class StructMapInfos:
	var filename:String = ""
	var path:String = ""
	var number_of_players:int = 0
	var map_size:int = 0
	var computers:int = 0
	var rescuables:int  = 0
	var watchers:bool = false


var configuration = RMP_Config.new()
var filter_players_min:int = 2
var filter_players_max:int = 8
var filter_water_and_land:int = WATER_OR_LAND.BOTH
var filter_cramped_and_open:int = CRAMPED_OR_OPEN.BOTH
var filter_allow_daemon_watcher:bool = false
var filter_allow_custom_units:bool = false
var filter_allow_computers:bool = false
var filter_allow_rescues:bool = false
var filter_allow_restrictions:bool = false
var filter_remove_picked_from_pool:bool = true
var filter_secret_map:bool = false
var maps_dir:Directory = Directory.new()
var unsorted_maps = Array()
var filtered_maps_pool = Array()
var picked_maps_history = Array()
var loading_pud_done:int
var loading_pud_filename:String = ""
var loading_mutex:Mutex
var loading_thread:Thread


func _ready():
	randomize()
	self.loading_mutex = Mutex.new()
	self.loading_thread = Thread.new()
	set_physics_process(false)
	initialize_option_buttons()
	self.load_configuration()


func _physics_process(_delta):
	if self.loading_thread.is_alive() == false:
		self.loading_thread.wait_to_finish()
		set_physics_process(false)
		$UI/PanelLoading.hide()
		$UI/PanelMapPicker.show()
		self.configuration.directories_config_changed = false
	self.loading_mutex.lock()
	$"%LoadingPanelTextureProgress".value = self.loading_pud_done
	$"%LoadingStepLabel".text = self.loading_pud_filename
	self.loading_mutex.unlock()


func _exit_tree():
	if self.loading_thread.is_active():
		self.loading_thread.wait_to_finish()


func initialize_option_buttons():
	$"%CrampedFactorOptionButton".add_item("Both", CRAMPED_OR_OPEN.BOTH)
	$"%CrampedFactorOptionButton".add_item("Cramped", CRAMPED_OR_OPEN.CRAMPED)
	$"%CrampedFactorOptionButton".add_item("Open", CRAMPED_OR_OPEN.OPEN)
	$"%CrampedFactorOptionButton".select(self.filter_cramped_and_open)
	$"%WaterFactorOptionButton".add_item("Both", WATER_OR_LAND.BOTH)
	$"%WaterFactorOptionButton".add_item("Water", WATER_OR_LAND.WATER)
	$"%WaterFactorOptionButton".add_item("Land", WATER_OR_LAND.LAND)
	$"%WaterFactorOptionButton".select(self.filter_water_and_land)


func passes_water_or_land_filter(map:PUD) -> bool:
	if self.filter_water_and_land == WATER_OR_LAND.WATER:
		return map.water_factor >= self.configuration.water_land_treshold
	elif self.filter_water_and_land == WATER_OR_LAND.LAND:
		return map.water_factor < self.configuration.water_land_treshold
	else:
		return true


func passes_cramped_or_open_filter(map:PUD) -> bool:
	if self.filter_cramped_and_open == CRAMPED_OR_OPEN.CRAMPED:
		return map.cramped_factor >= self.configuration.cramped_open_treshold
	elif self.filter_cramped_and_open == CRAMPED_OR_OPEN.OPEN:
		return map.cramped_factor < self.configuration.cramped_open_treshold
	else:
		return true


func passes_players_number_filter(map:PUD) -> bool:
	if filter_allow_computers == false and map.computer_players > 0:
		return false
	if filter_allow_rescues == false and map.rescue_players > 0:
		return false
	var total_players = map.human_players + map.computer_players
	return total_players >= self.filter_players_min and total_players <= self.filter_players_max


func passes_custom_filter(map:PUD) -> bool:
	if !self.filter_allow_custom_units and not (map.uses_default_unit_data and map.uses_default_upgrade_data):
		return false
	if !self.filter_allow_restrictions and map.has_alow_section:
		return false
	if !self.filter_allow_daemon_watcher and map.red_player_is_daemon:
		return false
	return true


func passes_maps_history_filter(map:PUD) -> bool:
	if self.filter_remove_picked_from_pool and self.picked_maps_history.has(map):
		return false
	return true


func apply_filters():
	filtered_maps_pool.clear()
	for m in unsorted_maps:
		if self.passes_water_or_land_filter(m) \
		and self.passes_cramped_or_open_filter(m)\
		and self.passes_players_number_filter(m) \
		and self.passes_maps_history_filter(m) \
		and self.passes_custom_filter(m):
			filtered_maps_pool.append(m)


func load_configuration():
	var err = configuration.load_configuration()
	if err != OK:
		self.open_configuration_panel()
	else:
		self.open_map_picker()


func save_configuration():
	var err = configuration.save_configuration()
	if err != OK:
		printerr("Error while attempting to save to configuration file.")
	self.open_map_picker()


func open_configuration_panel():
	$UI/PanelLoading.hide()
	$UI/PanelMapPicker.hide()
	$UI/PanelConfigure.show()
	$"%WaterLandThresholdSlider".value = self.configuration.water_land_treshold
	$"%CrampedOpenThresholdSlider".value = self.configuration.cramped_open_treshold
	$"%CurrentMapsDirectoryLabel".text = self.configuration.root_maps_directory_path
	$"%CurrentSecretFilePathLabel".text = self.configuration.secret_file_path
	$"%FileExplorerDialog".current_dir = self.configuration.root_maps_directory_path
	for c in $"%IgnoredDirectoriesFlowContainer".get_children():
		c.queue_free()
	for s in self.configuration.ignored_directory_names:
		add_ignored_directory_checkbox(s)


func open_map_picker():
	$UI/PanelConfigure.hide()
	$UI/PanelMapPicker.hide()
	$UI/PanelLoading.show()
	if !self.configuration.directories_config_changed:
		$UI/PanelLoading.hide()
		$UI/PanelMapPicker.show()
		apply_filters()
		return
	self.unsorted_maps.clear()
	self.loading_pud_done = 0
	if self.maps_dir.open(self.configuration.root_maps_directory_path) == OK and self.maps_dir.list_dir_begin(true, true) == OK:
		scan_directory(self.maps_dir)
		$"%LoadingPanelTextureProgress".max_value = self.unsorted_maps.size()
		var err = loading_thread.start(self, "load_puds_thread")
		if err != OK:
			printerr("Error starting the loading thread.")
			open_configuration_panel()
			return
		set_physics_process(true)
	else:
		printerr("Could not open the Maps directory.")
		open_configuration_panel()


func load_puds_thread():
	print("loading thread started...")
	for m in unsorted_maps:
		self.loading_mutex.lock()
		self.loading_pud_filename = m.pud_filename
		self.loading_mutex.unlock()
		m.load_pud()
		self.loading_mutex.lock()
		self.loading_pud_done += 1
		self.loading_mutex.unlock()
	apply_filters()
	print("loading thread ended...")


func is_ignored_directory(directory:String):
	for d in self.configuration.ignored_directory_names:
		if directory.get_basename() == d:
			return true
	return false


func unsorted_maps_contains(map_filename:String) -> bool:
	for p in self.unsorted_maps:
		if map_filename == p.pud_filename:
			return true
	return false


func scan_directory(dir:Directory):
	var entry:String = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and is_ignored_directory(entry) == false:
			var sub_dir = Directory.new()
			if sub_dir.open(dir.get_current_dir() + "/" + entry) == OK and sub_dir.list_dir_begin(true, true) == OK:
				scan_directory(sub_dir)
			else:
				printerr("Unable to open: " + dir.get_current_dir() + "/" + entry)
		elif entry.ends_with(".pud") and unsorted_maps_contains(entry) == false:
			var new_pud = PUD.new()
			new_pud.pud_filename = entry
			new_pud.pud_file_path = dir.get_current_dir() + "/" + entry
			unsorted_maps.append(new_pud)
		entry = dir.get_next()


func add_ignored_directory_checkbox(ignored_directory):
	var new_checkbox = CheckBox.new()
	new_checkbox.text = ignored_directory
	new_checkbox.pressed = true
	new_checkbox.connect("pressed", self, "_on_ignored_directory_checkbox_pressed", [new_checkbox], CONNECT_ONESHOT)
	$"%IgnoredDirectoriesFlowContainer".add_child(new_checkbox)


func reset_map_display():
	$"%Minimap".texture = null
	$"%MapName".text = ""
	$"%Description".text = ""
	$"%PickedMapPathLabel".text = "No maps left, try different filters."
	$"%DaemonLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)
	$"%ComputersLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)
	$"%RescuesLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)
	$"%RestrictionsLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)
	$"%CustomUnitsLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)
	$"%DaemonLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)


func turn_on_lights_for_pud(picked_map:PUD):
	if !picked_map.uses_default_unit_data or !picked_map.uses_default_upgrade_data:
		$"%CustomUnitsLight".texture.set_region(LIGHT_TEXT_REGIONS_ON)
	if picked_map.red_player_is_daemon:
		$"%DaemonLight".texture.set_region(LIGHT_TEXT_REGIONS_ON)
	if picked_map.has_alow_section:
		$"%RestrictionsLight".texture.set_region(LIGHT_TEXT_REGIONS_ON)
	if picked_map.computer_players > 0:
		$"%ComputersLight".texture.set_region(LIGHT_TEXT_REGIONS_ON)
	if picked_map.rescue_players > 0:
		$"%RescuesLight".texture.set_region(LIGHT_TEXT_REGIONS_ON)

func tween_animate_minimap():
	$"%Minimap".rect_scale = Vector2(0.6, 0.6)
	var tween := create_tween()
# warning-ignore:return_value_discarded
	tween.tween_property($"%Minimap", "rect_scale", Vector2(1.025, 1.025), 0.05)
# warning-ignore:return_value_discarded
	tween.tween_property($"%Minimap", "rect_scale", Vector2(1.0, 1.0), 0.1)


func trim_maps_dir_from_path(path:String) -> String:
	var maps_dir_path = self.maps_dir.get_current_dir()
	if path.begins_with(maps_dir_path):
		return path.substr(maps_dir_path.length())
	else:
		return path

func _on_pick_map_button_pressed():
	reset_map_display()
	tween_animate_minimap()
	if filtered_maps_pool.empty():
		return
	var random_map:PUD = filtered_maps_pool[int(randf() * (filtered_maps_pool.size() - 1))]
	if self.filter_remove_picked_from_pool:
		if !self.picked_maps_history.has(random_map):
			self.picked_maps_history.append(random_map)
		self.filtered_maps_pool.remove(self.filtered_maps_pool.find(random_map))
	turn_on_lights_for_pud(random_map)
	if self.filter_secret_map == false:
		$"%Minimap".texture = random_map.create_minimap()
		$"%MapName".text = random_map.pud_filename
		$"%Description".text = random_map.description
		$"%PickedMapPathLabel".text = trim_maps_dir_from_path(random_map.pud_file_path)
	else:
		$"%Minimap".texture = load("res://images/secret_minimap_background.png")
		$"%MapName".text = self.configuration.secret_file_path.get_file()
		$"%Description".text = SECRET_MAP_DESCRIPTION
		if self.configuration.secret_file_path == self.configuration.SECRET_MAP_DEFAULT_FILENAME:
			return
		var secret_pud = PUD.new()
		secret_pud.pud_filename = self.configuration.secret_file_path.get_file()
		secret_pud.pud_file_path = self.configuration.secret_file_path
		var err = self.maps_dir.copy(random_map.pud_file_path, secret_pud.pud_file_path)
		if err != OK:
			printerr("Error while copying secret map file.")
			return
		if secret_pud.store_description(SECRET_MAP_DESCRIPTION) == false:
			printerr("Error when trying to store description.")
		$"%PickedMapPathLabel".text = trim_maps_dir_from_path(secret_pud.pud_file_path)


func _on_save_configuration_button_up():
	self.save_configuration()


func _on_select_secret_file_path_button_pressed():
	$"%FileExplorerDialog".mode = FileDialog.MODE_SAVE_FILE
	$"%FileExplorerDialog".filters = ["*.pud"]
	if !$"%FileExplorerDialog".is_connected("file_selected", self, "_on_file_explorer_secret_file_selected"):
# warning-ignore:return_value_discarded
		$"%FileExplorerDialog".connect("file_selected", self, "_on_file_explorer_secret_file_selected", [], CONNECT_ONESHOT)
	$"%FileExplorerDialog".show()


func _on_file_explorer_secret_file_selected(filepath):
	self.configuration.secret_file_path = filepath
	$"%CurrentSecretFilePathLabel".text = filepath


func _on_select_maps_directory_button_pressed():
	$"%FileExplorerDialog".mode = FileDialog.MODE_OPEN_DIR
	if !$"%FileExplorerDialog".is_connected("dir_selected", self, "_on_file_explorer_maps_dir_selected"):
# warning-ignore:return_value_discarded
		$"%FileExplorerDialog".connect("dir_selected", self, "_on_file_explorer_maps_dir_selected", [], CONNECT_ONESHOT)
	$"%FileExplorerDialog".show()


func _on_file_explorer_maps_dir_selected(dir):
	self.configuration.root_maps_directory_path = dir
	$"%CurrentMapsDirectoryLabel".text = dir


func _on_water_land_threshold_slider_drag_ended(value_changed):
	if value_changed:
		self.configuration.water_land_treshold = $"%WaterLandThresholdSlider".value
		


func _on_cramped_open_threshold_slider_drag_ended(value_changed):
	if value_changed:
		self.configuration.cramped_open_treshold = $"%CrampedOpenThresholdSlider".value


func _on_ignore_directory_entered(directory_to_ignore):
	$"%DirectoryToIgnoreLineEdit".text = ""
	if directory_to_ignore == "" or self.configuration.ignored_directory_names.has(directory_to_ignore):
		printerr("Empty directory name or directory is already ignored.")
		return
	var poolstringarray_tmp:PoolStringArray = self.configuration.ignored_directory_names
	poolstringarray_tmp.append(directory_to_ignore)
	self.configuration.ignored_directory_names = poolstringarray_tmp
	add_ignored_directory_checkbox(directory_to_ignore)


func _on_ignore_directory_button_pressed():
	var directory_to_ignore:String = $"%DirectoryToIgnoreLineEdit".text
	_on_ignore_directory_entered(directory_to_ignore)


func _on_ignored_directory_checkbox_pressed(pressed_checkbox:CheckBox):
	var directory_to_remove = pressed_checkbox.text
	pressed_checkbox.queue_free()
	if self.configuration.ignored_directory_names.has(directory_to_remove):
		var tmp_pool_string_array = PoolStringArray(self.configuration.ignored_directory_names)
		tmp_pool_string_array.remove(tmp_pool_string_array.find(directory_to_remove))
		self.configuration.ignored_directory_names = tmp_pool_string_array


func _on_reconfigure_button_pressed():
	self.open_configuration_panel()


func _on_custom_units_check_button_toggled(button_pressed):
	self.filter_allow_custom_units = button_pressed
	apply_filters()


func _on_allow_restrictions_check_button_toggled(button_pressed):
	self.filter_allow_restrictions = button_pressed
	apply_filters()


func _on_allow_computer_check_button_toggled(button_pressed):
	self.filter_allow_computers = button_pressed
	apply_filters()


func _on_allow_rescues_check_button_toggled(button_pressed):
	self.filter_allow_rescues = button_pressed
	apply_filters()


func _on_allow_daemon_watcher_check_button_toggled(button_pressed):
	self.filter_allow_daemon_watcher = button_pressed
	apply_filters()


func _on_remove_picked_check_button_toggled(button_pressed):
	self.filter_remove_picked_from_pool = button_pressed
	apply_filters()


func _on_min_players_spin_box_value_changed(value):
	self.filter_players_min = value
	if value > self.filter_players_max:
		$"%MaxPlayersSpinBox".value = value
	apply_filters()


func _on_max_players_spin_box_value_changed(value):
	self.filter_players_max = value
	if value < self.filter_players_min:
		$"%MinPlayersSpinBox".value = value
	apply_filters()


func _on_clear_pick_history_button_pressed():
	self.picked_maps_history.clear()
	apply_filters()


func _on_water_factor_option_button_item_selected(index):
	self.filter_water_and_land = index
	apply_filters()


func _on_cramped_factor_option_button_item_selected(index):
	self.filter_cramped_and_open = index
	apply_filters()


func _on_secret_map_check_button_toggled(button_pressed):
	self.filter_secret_map = button_pressed
