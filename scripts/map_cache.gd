class_name MapsCache
extends Node

const CACHE_FILE_PATH = "user://cache.json"

const MTIME_KEY = "mtime"
const VERSION_KEY = "version"
const CACHE_KEY = "cache"

# This version field is used to check if the cache file is outdated with the code
# Increment whenever the cache structure changes
const VERSION = 1

var _cache:Dictionary = {
}

func set_map_data(map_file:String, data:Dictionary):
	_cache[CACHE_KEY][map_file] = data
	_cache[CACHE_KEY][map_file][MTIME_KEY] = FileAccess.get_modified_time(map_file)
	

func get_map_data(map_file:String) -> Dictionary:
	if _cache[CACHE_KEY].keys().has(map_file):
		var mtime = _cache[CACHE_KEY][map_file][MTIME_KEY]
		if FileAccess.get_modified_time(map_file) == mtime:
			return _cache[CACHE_KEY][map_file]
	
	return {}

func load_cache():
	var file = FileAccess.open(CACHE_FILE_PATH, FileAccess.READ)
	if file:
		var test_json_conv = JSON.new()
		test_json_conv.parse(file.get_as_text())
		var res = test_json_conv.get_data()
		if res is Dictionary and res.keys().has(VERSION_KEY):
			if res[VERSION_KEY] == VERSION:
				_cache = res
				return
		file.close()
	_cache = {
		VERSION_KEY: VERSION,
		CACHE_KEY: {}
	}

func save_cache():
	var file = FileAccess.open(CACHE_FILE_PATH, FileAccess.WRITE)
	if file:
		var cache_json_string = JSON.stringify(_cache, "\t", true)
		file.store_string(cache_json_string)
		file.close()
	else:
		printerr("Failed to create or open cache file.")
