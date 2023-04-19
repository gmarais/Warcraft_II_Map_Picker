# **************************************************************************** #
#                                                                              #
#                                                   :::::::::::::::::          #
#    maps_ratings.gd                               ::+::+::+::+::+::           #
#                                                 +      :+:      +            #
#    By: gmarais <gmarais@noreply.github.com>           +:+    +       +       #
#                                                      +#+    +#+     +#+      #
#    Created: 2023/01/26 22:24:50 by gmarais          #+#    #+ +#   #+ +#     #
#    Updated: 2023/01/26 22:36:02 by gmarais       #######  ##   ## ##   ##    #
#                                                                              #
# **************************************************************************** #
class_name MapsRatings
extends Node

const RATINGS_FILE_PATH = "res://ratings.json"
const DEFAULT_RATING = 2

var _maps_ratings:Dictionary = {}


func set_map_rating(map_name:String, rating:int):
	if rating == DEFAULT_RATING:
		@warning_ignore("return_value_discarded")
		self._maps_ratings.erase(map_name)
	else:
		self._maps_ratings[map_name] = rating
	self.save_maps_ratings()


func get_map_rating(map_name:String) -> int:
	if self._maps_ratings.has(map_name):
		return int(self._maps_ratings[map_name])
	else:
		return DEFAULT_RATING


func load_maps_ratings():
	var file = FileAccess.open(RATINGS_FILE_PATH, FileAccess.READ)
	if file:
		var test_json_conv = JSON.new()
		test_json_conv.parse(file.get_as_text())
		var res = test_json_conv.get_data()
		if res is Dictionary:
			self._maps_ratings = res
	file.close()


func save_maps_ratings():
	if FileAccess.file_exists(RATINGS_FILE_PATH):
		DirAccess.remove_absolute(RATINGS_FILE_PATH)
	var file = FileAccess.open(RATINGS_FILE_PATH, FileAccess.WRITE)
	if file:
		var ratings_json_string = JSON.stringify(self._maps_ratings, "\t", true)
		file.store_string(ratings_json_string)
	else:
		printerr("Failed to create or open maps ratings file.")
	file.close()
