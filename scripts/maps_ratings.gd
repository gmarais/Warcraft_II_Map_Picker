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
# warning-ignore:return_value_discarded
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
	var file = File.new()
	if file.open(RATINGS_FILE_PATH, File.READ) == OK:
		var res = JSON.parse(file.get_as_text())
		if res.result is Dictionary:
			self._maps_ratings = res.result
	file.close()


func save_maps_ratings():
	var file = File.new()
	if file.file_exists(RATINGS_FILE_PATH):
		var dir = Directory.new()
		dir.remove(RATINGS_FILE_PATH)
	if file.open(RATINGS_FILE_PATH, File.WRITE) == OK:
		var ratings_json_string = JSON.print(self._maps_ratings, "\t", true)
		file.store_string(ratings_json_string)
	else:
		printerr("Failed to create or open maps ratings file.")
	file.close()
