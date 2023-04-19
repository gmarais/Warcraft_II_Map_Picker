# **************************************************************************** #
#                                                                              #
#                                                   :::::::::::::::::          #
#    pud.gd                                        ::+::+::+::+::+::           #
#                                                 +      :+:      +            #
#    By: gmarais <gmarais@noreply.github.com>           +:+    +       +       #
#                                                      +#+    +#+     +#+      #
#    Created: 2022/12/17 09:38:26 by gmarais          #+#    #+ +#   #+ +#     #
#    Updated: 2022/12/17 09:38:31 by gmarais       #######  ##   ## ##   ##    #
#                                                                              #
# **************************************************************************** #
class_name PUD
extends Node

var NORMAL_TYPE_BUFFER = PackedByteArray([87,65,82,50,32,77,65,80,0,0,10,255,231,147,151,177])

const PLAYER_COLOR = [
	Color("a40000"),
	Color("003cc0"),
	Color("2cb494"),
	Color("9848b0"),
	Color("f08414"),
	Color("28283c"),
	Color("e0e0e0"),
	Color("fcfc48"),
]

const TERRAIN_TYPE_COLOR = {
	WATER = [Color("0c4c80"), Color("043874"), Color("0c2430"), Color("28300c")],
	DARK_WATER = [Color("043470"), Color("002c64"), Color("10202c"), Color("141c08")],
	COAST = [Color("744404"), Color("4470a4"), Color("4c280c"), Color("603404")],
	DARK_COAST = [Color("603800"), Color("2c5c94"), Color("341404"), Color("542800")],
	GROUND = [Color("28540c"), Color("9494a0"), Color("804004"), Color("442c1c")],
	DARK_GROUND = [Color("244804"), Color("848498"), Color("703004"), Color("382418")],
	FOREST = [Color("143400"), Color("144848"), Color("1c2400"), Color("7c5840")],
	MOUNTAIN = [Color("505050"), Color("7c5448"), Color("382828"), Color("544444")],
	WALLS = [Color("646464"), Color("58607c"), Color("403430"), Color("786c68")],
	TRANSITION_FOREST = [Color("002c00"), Color("003c28"), Color("081800"), Color("6c4830")],
	TRANSITION_MOUNTAIN = [Color("3c3c3c"), Color("74483c"), Color("2c2020"), Color("483c38")],
	TRANSITION_COAST_WATER = [Color("246c94"), Color("185488"), Color("143844"), Color("344810")],
}

enum PUD_SYMBOLS {
	BYTE = 1,
	CHAR = 1,
	WORD = 2,
	LONG = 4,
}

# Anything else is PASSIVE_COMPUTER
enum PUD_OWNERSHIP {
	COMPUTER = 0x01,
	NOBODY = 0x03,
	COMPUTER2 = 0x04,
	HUMAN = 0x05,
	RESCUE_PASSIVE = 0x06,
	RESCUE_ACTIVE = 0x07,
}

const PUD_SECTIONS = {
	TYPE = "TYPE",
	VERSION = "VER ",
	DESCRIPTION = "DESC",
	OWNERSHIP = "OWNR",
	DIMENTIONS = "DIM ",
	UNITS_DATA = "UDTA",
	UPGRADES_DATA = "UGRD",
	RESTRICTIONS = "ALOW",
	TILES_MAP = "MTXM",
	UNITS = "UNIT",
	STARTING_GOLD = "SGLD",
	STARTING_LUMBER = "SLBR",
	STARTING_OIL = "SOIL",
	ERA = "ERA ",
	ERAX = "ERAX",
	RACES = "SIDE",
	AI_FOR_PLAYERS = "AIPL",
	MOVEMENT_MAP = "SQM ",
	ACTION_MAP = "REGM",
	SIGN = "SIGN"
}

class SectionInfo:
	var name:String
	var begin_position:int
	var length:int

var pud_filename:String
var pud_file_path:String
var description:String = ""
var human_players:int
var computer_players:int
var rescue_players:int
var map_size:int = 128
var uses_default_unit_data:bool = true
var uses_default_upgrade_data:bool = true
var has_alow_section:bool = false
var red_player_is_daemon:bool = false
var water_factor:float
var cramped_factor:float
var water_tiles_count:int
var blocking_tiles_count:int
var era:int = 0
var terrain_tiles_map:Array = Array()
var starting_position_colors:Dictionary = Dictionary()
var gold_mines:PackedVector2Array = PackedVector2Array()
var oil_patches:PackedVector2Array = PackedVector2Array()
var critters:PackedVector2Array = PackedVector2Array()


func store_description(new_description:String) -> bool:
	var buffer = new_description.to_ascii_buffer()
	var file = FileAccess.open(self.pud_file_path, FileAccess.READ_WRITE)
	if !file:
		return false
	var section_info:SectionInfo = get_next_section_info(file)
	while section_info != null:
		if section_info.name == PUD_SECTIONS.TYPE:
			file.seek(section_info.begin_position)
			file.store_buffer(NORMAL_TYPE_BUFFER)
		elif section_info.name == PUD_SECTIONS.DESCRIPTION:
			file.seek(section_info.begin_position)
			if buffer.size() > section_info.length:
				buffer.resize(section_info.length)
				buffer[section_info.length - 1] = 0
			file.store_buffer(buffer)
		elif section_info.name == PUD_SECTIONS.SIGN:
			file.store_32(0)
		file.seek(section_info.begin_position + section_info.length)
		section_info = get_next_section_info(file)
	file.close()
	return true


func create_minimap():
	var image:Image
	@warning_ignore("integer_division")
	var player_start_size = self.map_size / 32
	@warning_ignore("integer_division")
	var player_start_offset = player_start_size / 2
	image = Image.create(map_size, map_size, false, Image.FORMAT_RGB8)
	image.fill(Color.GREEN)
	for x in range(self.map_size):
		for y in range(self.map_size):
			var index = x + y * self.map_size
			var position = Vector2(x, y)
			if self.critters.has(position):
				image.set_pixel(x, y, Color.GRAY)
			elif self.gold_mines.has(position):
				image.fill_rect(Rect2(x, y, 3, 3), Color.GOLD)
			elif self.oil_patches.has(position):
				image.fill_rect(Rect2(x, y, 2, 2), Color.BLACK)
			elif self.starting_position_colors.keys().has(position):
				image.fill_rect(Rect2(x - player_start_offset, y - player_start_offset, player_start_size,  player_start_size), self.starting_position_colors[position])
			elif image.get_pixel(x, y) == Color.GREEN:
				image.set_pixel(x, y, self.terrain_tiles_map[index][self.era])
	var image_texture:ImageTexture
	image_texture = ImageTexture.create_from_image(image)
	return image_texture


func load_pud_file(map_filename:String, path:String) -> bool:
	self.pud_filename = map_filename
	self.pud_file_path = path
	return load_pud()


func load_pud() -> bool:
	var file = FileAccess.open(self.pud_file_path, FileAccess.READ)
	if !file:
		return false
	var section_info:SectionInfo = get_next_section_info(file)
	while section_info != null:
		match section_info.name:
			PUD_SECTIONS.TYPE:
				if section_info.length != 16 or is_wc2_type(file) == false:
					return false
			PUD_SECTIONS.DIMENTIONS:
				parse_dimentions(file)
			PUD_SECTIONS.UNITS:
				parse_units(file, section_info)
			PUD_SECTIONS.ERA:
				parse_era(file)
			PUD_SECTIONS.ERAX:
				parse_era(file)
			PUD_SECTIONS.TILES_MAP:
				parse_tiles_map(file, section_info)
			PUD_SECTIONS.OWNERSHIP:
				parse_ownerships(file)
			PUD_SECTIONS.DESCRIPTION:
				parse_description(file)
			PUD_SECTIONS.UNITS_DATA:
				parse_units_data(file)
			PUD_SECTIONS.UPGRADES_DATA:
				parse_upgrades_data(file)
			PUD_SECTIONS.RESTRICTIONS:
				self.has_alow_section = true
		file.seek(section_info.begin_position + section_info.length)
		section_info = get_next_section_info(file)
	file.close()
	self.water_factor = float(self.water_tiles_count) / float(self.terrain_tiles_map.size())
	self.cramped_factor = float(self.blocking_tiles_count + self.critters.size() + self.gold_mines.size() * 9) / float(self.terrain_tiles_map.size())
	return true


func get_next_section_info(file:FileAccess) -> SectionInfo:
	if file.get_length() - file.get_position() <= 8:
		return null
	var bytes_buffer:PackedByteArray
	bytes_buffer = file.get_buffer(4)
	var section_info = SectionInfo.new()
	section_info.name = bytes_buffer.get_string_from_ascii()
	section_info.length = file.get_32()
	section_info.begin_position = file.get_position()
	return section_info


func is_wc2_type(file:FileAccess) -> bool:
	var byte_buffer:PackedByteArray = file.get_buffer(8)
	var pud_type_string = byte_buffer.get_string_from_ascii()
	if pud_type_string == "WAR2 MAP":
		return true
	return false


func parse_dimentions(file:FileAccess):
	self.map_size = file.get_8()


func parse_description(file:FileAccess):
	var byte_buffer:PackedByteArray = file.get_buffer(32)
	self.description = byte_buffer.get_string_from_ascii()


func parse_units(file:FileAccess, section_info:SectionInfo):
	@warning_ignore("integer_division")
	var number_of_units_placed = section_info.length / 8
	var daemon_counter = 0
	var has_non_daemon_units = false
	for u in range(number_of_units_placed):
		file.seek(section_info.begin_position + 8 * u)
		var unit_position = Vector2(file.get_16(), file.get_16())
		var unit_type = file.get_8()
		var owning_player = file.get_8()
		if unit_type == 0x5c:
			self.gold_mines.append(unit_position)
		elif unit_type == 0x5d:
			self.oil_patches.append(unit_position)
		elif unit_type == 0x39:
			self.critters.append(unit_position)
		elif unit_type == 0x5e or unit_type == 0x5f:
			if owning_player < 8:
				self.starting_position_colors[unit_position] = PLAYER_COLOR[owning_player]
		elif unit_type == 0x38 and owning_player == 0:
			daemon_counter += 1
		elif !has_non_daemon_units and owning_player == 0:
			has_non_daemon_units = true
	if daemon_counter == 1 and !has_non_daemon_units:
		self.red_player_is_daemon = true


func parse_ownerships(file:FileAccess):
	for _p in range(15):
		var ownership_value = file.get_8()
		if ownership_value == PUD_OWNERSHIP.HUMAN:
			self.human_players += 1
		elif ownership_value == PUD_OWNERSHIP.RESCUE_PASSIVE or ownership_value == PUD_OWNERSHIP.RESCUE_ACTIVE:
			self.rescue_players += 1
		elif ownership_value == PUD_OWNERSHIP.COMPUTER or ownership_value == PUD_OWNERSHIP.COMPUTER2:
			self.computer_players += 1


func parse_units_data(file:FileAccess):
	var is_using_default = file.get_8()
	self.uses_default_unit_data = is_using_default != 0


func parse_upgrades_data(file:FileAccess):
	var is_using_default = file.get_8()
	self.uses_default_upgrade_data = is_using_default != 0


func parse_era(file):
	var value = file.get_8()
	if value < 4:
		self.era = value


func parse_tiles_map(file:FileAccess, section_info:SectionInfo):
	self.blocking_tiles_count = 0
	self.water_tiles_count = 0
	@warning_ignore("integer_division")
	var tiles_number = section_info.length / 2
	self.terrain_tiles_map.clear()
	for _t in range(tiles_number):
		var tile_type:int = file.get_8()
		var transition:int = file.get_8()
		if transition == 0x00:
			@warning_ignore("integer_division")
			tile_type = tile_type / 16
			match tile_type:
				0x1:
					self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.WATER)
					self.water_tiles_count += 1
				0x2:
					self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.DARK_WATER)
					self.water_tiles_count += 1
				0x3:
					self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.COAST)
				0x4:
					self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.DARK_COAST)
				0x5:
					self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.GROUND)
				0x6:
					self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.DARK_GROUND)
				0x7:
					self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.FOREST)
					self.blocking_tiles_count += 1
				0x8:
					self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.MOUNTAIN)
					self.blocking_tiles_count += 1
				_:
					self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.WALLS)
					self.blocking_tiles_count += 1
		elif transition == 0x09 or transition == 0x08:
			self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.WALLS)
			self.blocking_tiles_count += 1
		elif transition == 0x07:
			self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.TRANSITION_FOREST)
			self.blocking_tiles_count += 1
		elif transition == 0x06:
			self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.DARK_GROUND)
		elif transition == 0x05 or transition == 0x03:
			self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.COAST)
		elif transition == 0x02:
			self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.TRANSITION_COAST_WATER)
			self.blocking_tiles_count += 1
		elif transition == 0x04:
			self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.TRANSITION_MOUNTAIN)
			self.blocking_tiles_count += 1
		elif transition == 0x01:
			self.terrain_tiles_map.append(TERRAIN_TYPE_COLOR.DARK_WATER)
			self.water_tiles_count += 1

