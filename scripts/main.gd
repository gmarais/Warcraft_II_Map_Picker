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
	BOTH = 0,
	WATER = 1,
	LAND = 2
}

enum CRAMPED_OR_OPEN {
	BOTH = 0,
	CRAMPED = 1,
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
var maps_ratings = MapsRatings.new()
var filter_players_min:int = 2
var filter_players_max:int = 8
var filter_water_and_land:int = WATER_OR_LAND.BOTH
var filter_cramped_and_open:int = CRAMPED_OR_OPEN.BOTH
var filter_daemon_watcher:bool = false
var filter_allow_custom_units:bool = false
var filter_allow_computers:bool = false
var filter_allow_rescues:bool = false
var filter_allow_restrictions:bool = false
var filter_min_rating = 2
var filter_remove_picked_from_pool:bool = true
var filter_secret_map:bool = false
var maps_dir:DirAccess
var unsorted_maps = Array()
var filtered_maps_pool = Array()
var picked_maps_history = Array()
var loading_pud_done:int
var loading_pud_filename:String = ""
var loading_mutex:Mutex
var loading_thread:Thread
var currently_picked_map:PUD = null


func _ready():
	randomize()
	self.loading_mutex = Mutex.new()
	self.loading_thread = Thread.new()
	set_physics_process(false)
	initialize_option_buttons()
	self.load_picked_maps_history()
	self.maps_ratings.load_maps_ratings()
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
	if self.loading_thread.is_alive():
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
	if !self.filter_daemon_watcher and map.red_player_is_daemon:
		return false
	if self.filter_daemon_watcher and !map.red_player_is_daemon:
		return false
	return true


func passes_maps_history_filter(map:PUD) -> bool:
	if self.picked_maps_history.has(map.pud_filename):
		return false
	return true


func passes_maps_rating_filter(map:PUD) -> bool:
	if self.maps_ratings.get_map_rating(map.pud_filename) < self.filter_min_rating:
		return false
	return true


func apply_filters():
	filtered_maps_pool.clear()
	for m in unsorted_maps:
		if self.passes_water_or_land_filter(m) \
		and self.passes_cramped_or_open_filter(m)\
		and self.passes_players_number_filter(m) \
		and self.passes_maps_history_filter(m) \
		and self.passes_custom_filter(m) \
		and self.passes_maps_rating_filter(m):
			filtered_maps_pool.append(m)


func load_picked_maps_history():
	if FileAccess.file_exists(configuration.CONFIG_FILE_PATH.get_base_dir() + "picked_maps_history.txt"):
		var maps_history_file_content = FileAccess.get_file_as_string(configuration.CONFIG_FILE_PATH.get_base_dir() + "picked_maps_history.txt")
		self.picked_maps_history = JSON.parse_string(maps_history_file_content)


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
	self.maps_dir = DirAccess.open(self.configuration.root_maps_directory_path)
	self.maps_dir.include_navigational = false
	if self.maps_dir:
		scan_directory(self.maps_dir)
		$"%LoadingPanelTextureProgress".max_value = self.unsorted_maps.size()
		var err = loading_thread.start(Callable(self,"load_puds_thread"))
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


func find_map_in_unsorted_maps(map_name:String) -> PUD:
	for p in self.unsorted_maps:
		if p.pud_filename.to_lower().contains(map_name) == true:
			return p
	return null


func unsorted_maps_contains(map_filename:String) -> bool:
	for p in self.unsorted_maps:
		if map_filename == p.pud_filename:
			return true
	return false


func scan_directory(dir:DirAccess):
	if dir.list_dir_begin() != OK:
		return
	var entry:String = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and is_ignored_directory(entry) == false:
			var sub_dir = DirAccess.open(dir.get_current_dir() + "/" + entry)
			if sub_dir:
				scan_directory(sub_dir)
			else:
				printerr("Unable to open: " + dir.get_current_dir() + "/" + entry)
		elif entry.ends_with(".pud") and unsorted_maps_contains(entry) == false and (dir.get_current_dir() + "/" + entry) != self.configuration.secret_file_path:
			var new_pud = PUD.new()
			new_pud.pud_filename = entry
			new_pud.pud_file_path = dir.get_current_dir() + "/" + entry
			unsorted_maps.append(new_pud)
		entry = dir.get_next()
	dir.list_dir_end()


func deep_search_for_map(dir:DirAccess, map_name:String):
	var map_pud = null
	if dir.list_dir_begin() != OK:
		return map_pud
	var entry:String = dir.get_next()
	while !map_pud and entry != "":
		if dir.current_is_dir():
			var sub_dir = DirAccess.open(dir.get_current_dir() + "/" + entry)
			if sub_dir:
				map_pud = deep_search_for_map(sub_dir, map_name)
			else:
				printerr("Unable to open: " + dir.get_current_dir() + "/" + entry)
		elif entry.ends_with(".pud") and entry.to_lower().contains(map_name) and (dir.get_current_dir() + "/" + entry) != self.configuration.secret_file_path:
			map_pud = PUD.new()
			map_pud.pud_filename = entry
			map_pud.pud_file_path = dir.get_current_dir() + "/" + entry
			map_pud.load_pud()
		entry = dir.get_next()
	dir.list_dir_end()
	return map_pud


func search_ignored_directories_for_map(dir:DirAccess, map_name:String):
	var dirs = dir.get_directories()
	var map_pud = null
	for dirname in dirs:
		var sub_dir = DirAccess.open(dir.get_current_dir() + "/" + dirname)
		if sub_dir:
			if is_ignored_directory(dirname):
				map_pud = deep_search_for_map(sub_dir, map_name)
			else:
				map_pud = search_ignored_directories_for_map(sub_dir, map_name)
			if map_pud:
				return map_pud
	return map_pud

func add_ignored_directory_checkbox(ignored_directory):
	var new_checkbox = CheckBox.new()
	new_checkbox.text = ignored_directory
	new_checkbox.button_pressed = true
	new_checkbox.connect("pressed",Callable(self,"_on_ignored_directory_checkbox_pressed").bind(new_checkbox),CONNECT_ONE_SHOT)
	$"%IgnoredDirectoriesFlowContainer".add_child(new_checkbox)


func reset_map_display():
	$"%Minimap".reset_transform_instant()
	$"%Minimap".texture = null
	$"%MapName".text = ""
	$"%Description".text = ""
	$"%PickedMapPathLabel".text = "No map found, try different filters."
	$"%DaemonLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)
	$"%ComputersLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)
	$"%RescuesLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)
	$"%RestrictionsLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)
	$"%CustomUnitsLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)
	$"%DaemonLight".texture.set_region(LIGHT_TEXT_REGIONS_OFF)
	$"%MapStarsTextureProgress".hide()


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
	$"%Minimap".scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.tween_property($"%Minimap", "scale", Vector2(1.025, 1.025), 0.05)
	tween.tween_property($"%Minimap", "scale", Vector2(1.0, 1.0), 0.1)


func trim_maps_dir_from_path(path:String) -> String:
	var maps_dir_path = self.maps_dir.get_current_dir()
	if path.begins_with(maps_dir_path):
		return path.substr(maps_dir_path.length())
	else:
		return path


func save_picked_maps_history():
	var f = FileAccess.open(configuration.CONFIG_FILE_PATH.get_base_dir() + "picked_maps_history.txt", FileAccess.WRITE_READ)
	f.store_string(JSON.stringify(self.picked_maps_history))
	f.close()


func save_picked_map_name_file(pud:PUD):
	var f = FileAccess.open(configuration.CONFIG_FILE_PATH.get_base_dir() + "last_picked_map.txt", FileAccess.WRITE_READ)
	f.store_line(pud.pud_filename)
	f.close()


func select_map(seleted_map):
	self.currently_picked_map = seleted_map
	turn_on_lights_for_pud(seleted_map)
	if self.filter_secret_map == false:
		$"%Minimap".texture = seleted_map.create_minimap()
		$"%Minimap".texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		$"%MapName".text = seleted_map.pud_filename
		$"%MapStarsTextureProgress".show()
		$"%MapStarsTextureProgress".value = self.maps_ratings.get_map_rating(seleted_map.pud_filename)
		$"%Description".text = seleted_map.description
		$"%PickedMapPathLabel".text = trim_maps_dir_from_path(seleted_map.pud_file_path)
		save_picked_map_name_file(seleted_map)
	else:
		$"%MapName".text = self.configuration.secret_file_path.get_file()
		if self.configuration.secret_file_path == self.configuration.SECRET_MAP_DEFAULT_FILENAME:
			printerr("Error secret file path not configured.")
			return
		$"%Minimap".texture = load("res://images/secret_minimap_background.png")
		$"%Minimap".texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		$"%Description".text = SECRET_MAP_DESCRIPTION
		var secret_pud = PUD.new()
		secret_pud.pud_filename = self.configuration.secret_file_path.get_file()
		secret_pud.pud_file_path = self.configuration.secret_file_path
		var err = self.maps_dir.copy(seleted_map.pud_file_path, secret_pud.pud_file_path)
		if err != OK:
			printerr("Error while copying secret map file.")
			return
		if secret_pud.store_description(SECRET_MAP_DESCRIPTION) == false:
			printerr("Error when trying to store description.")
		$"%PickedMapPathLabel".text = trim_maps_dir_from_path(secret_pud.pud_file_path)
		save_picked_map_name_file(secret_pud)

func _on_pick_map_button_pressed():
	$"%PickNextMapButton".release_focus()
	reset_map_display()
	tween_animate_minimap()
	if self.currently_picked_map and self.filter_remove_picked_from_pool:
		if !self.picked_maps_history.has(self.currently_picked_map.pud_filename):
			self.picked_maps_history.append(self.currently_picked_map.pud_filename)
			save_picked_maps_history()
		if self.filtered_maps_pool.has(self.currently_picked_map):
			self.filtered_maps_pool.erase(self.currently_picked_map)
	if filtered_maps_pool.is_empty():
		self.currently_picked_map = null
		return
	var random_map:PUD = filtered_maps_pool[int(randf() * filtered_maps_pool.size())]
	select_map(random_map)

func _on_save_configuration_button_up():
	self.save_configuration()


func _on_select_secret_file_path_button_pressed():
	$"%FileExplorerDialog".file_mode = FileDialog.FILE_MODE_SAVE_FILE
	$"%FileExplorerDialog".filters = ["*.pud"]
	if !$"%FileExplorerDialog".is_connected("file_selected",Callable(self,"_on_file_explorer_secret_file_selected")):
		$"%FileExplorerDialog".connect("file_selected",Callable(self,"_on_file_explorer_secret_file_selected").bind(),CONNECT_ONE_SHOT)
	$"%FileExplorerDialog".show()


func _on_file_explorer_secret_file_selected(filepath):
	self.configuration.secret_file_path = filepath
	$"%CurrentSecretFilePathLabel".text = filepath


func _on_select_maps_directory_button_pressed():
	$"%FileExplorerDialog".file_mode = FileDialog.FILE_MODE_OPEN_DIR
	if !$"%FileExplorerDialog".is_connected("dir_selected",Callable(self,"_on_file_explorer_maps_dir_selected")):
		$"%FileExplorerDialog".connect("dir_selected",Callable(self,"_on_file_explorer_maps_dir_selected").bind(),CONNECT_ONE_SHOT)
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
	var poolstringarray_tmp:PackedStringArray = self.configuration.ignored_directory_names
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
		var tmp_pool_string_array = PackedStringArray(self.configuration.ignored_directory_names)
		tmp_pool_string_array.erase(directory_to_remove)
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
	self.filter_daemon_watcher = button_pressed
	apply_filters()


func _on_remove_picked_check_button_toggled(button_pressed):
	self.filter_remove_picked_from_pool = button_pressed


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
	save_picked_maps_history()
	apply_filters()


func _on_water_factor_option_button_item_selected(index):
	self.filter_water_and_land = index
	apply_filters()


func _on_cramped_factor_option_button_item_selected(index):
	self.filter_cramped_and_open = index
	apply_filters()


func _on_min_stars_pressed(value):
	self.filter_min_rating = value
	apply_filters()


func _on_secret_map_check_button_toggled(button_pressed):
	self.filter_secret_map = button_pressed


func _on_map_stars_pressed(value):
	self.maps_ratings.set_map_rating($"%MapName".text, value)


func _on_map_name_text_submitted(new_text:String):
	$"%MapName".release_focus()
	reset_map_display()
	tween_animate_minimap()
	if self.currently_picked_map and self.filter_remove_picked_from_pool:
		if !self.picked_maps_history.has(self.currently_picked_map.pud_filename):
			self.picked_maps_history.append(self.currently_picked_map.pud_filename)
			save_picked_maps_history()
		if self.filtered_maps_pool.has(self.currently_picked_map):
			self.filtered_maps_pool.erase(self.currently_picked_map)
	if new_text == "":
		return
	var map_name = new_text.get_basename().to_lower()
	var map_pud = find_map_in_unsorted_maps(map_name)
	if !map_pud:
		map_pud = search_ignored_directories_for_map(self.maps_dir, map_name)
	if map_pud:
		select_map(map_pud)
	
