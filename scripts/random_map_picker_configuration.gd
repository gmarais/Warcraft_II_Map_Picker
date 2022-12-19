# **************************************************************************** #
#                                                                              #
#                                                   :::::::::::::::::          #
#    random_map_picker_configuration.gd            ::+::+::+::+::+::           #
#                                                 +      :+:      +            #
#    By: gmarais <gmarais@noreply.github.com>           +:+    +       +       #
#                                                      +#+    +#+     +#+      #
#    Created: 2022/12/17 09:38:37 by gmarais          #+#    #+ +#   #+ +#     #
#    Updated: 2022/12/17 09:38:40 by gmarais       #######  ##   ## ##   ##    #
#                                                                              #
# **************************************************************************** #
class_name RMP_Config
extends Node

const CONFIG_FILE_PATH = "res://config.cfg"
const SECRET_MAP_DEFAULT_FILENAME = "Secret path not configured."
const MAP_DIRECTORY_DEFAULT_PATH = "Maps directory not selected."

var _config_file = ConfigFile.new()

var secret_file_path:String = SECRET_MAP_DEFAULT_FILENAME
var root_maps_directory_path:String = MAP_DIRECTORY_DEFAULT_PATH setget set_root_maps_directory_path
var ignored_directory_names:PoolStringArray = PoolStringArray() setget set_ignored_directory_names
var water_land_treshold:float = 0.5
var cramped_open_treshold:float = 0.5
var directories_config_changed = false


func set_root_maps_directory_path(value):
	root_maps_directory_path = value
	self.directories_config_changed = true


func set_ignored_directory_names(value):
	ignored_directory_names = value
	self.directories_config_changed = true


func load_configuration() -> int:
	var err = self._config_file.load(CONFIG_FILE_PATH)
	if err == OK:
		self.root_maps_directory_path = self._config_file.get_value("Directories", "root_maps_directory_path")
		self.ignored_directory_names = self._config_file.get_value("Directories", "ignored_directory_names")
		self.secret_file_path = self._config_file.get_value("Directories", "secret_file_path")
		self.water_land_treshold = self._config_file.get_value("Thresholds", "water_land_treshold")
		self.cramped_open_treshold = self._config_file.get_value("Thresholds", "cramped_open_treshold")
		self.directories_config_changed = true
	return err


func save_configuration() -> int:
	self._config_file.set_value("Directories", "root_maps_directory_path", self.root_maps_directory_path)
	self._config_file.set_value("Directories", "ignored_directory_names", self.ignored_directory_names)
	self._config_file.set_value("Thresholds", "water_land_treshold", self.water_land_treshold)
	self._config_file.set_value("Thresholds", "cramped_open_treshold", self.cramped_open_treshold)
	self._config_file.set_value("Directories", "secret_file_path", self.secret_file_path)
	var err = self._config_file.save(CONFIG_FILE_PATH)
	return err
