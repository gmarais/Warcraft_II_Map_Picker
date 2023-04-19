extends TextureRect


var tween:Tween

func reset_transform_instant():
	var rect = $"%MinimapBackground".get_global_rect()
	self.set_global_position(rect.position)
	self.set_size(rect.size)

func reset_transform():
	if tween:
		tween.kill()
	tween = create_tween().set_parallel(true)
	var rect = $"%MinimapBackground".get_global_rect()
	tween.tween_property($"%Minimap", "global_position", rect.position, 0.1)
	tween.tween_property($"%Minimap", "size", rect.size, 0.1)

func expand_minimap():
	if tween:
		tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property($"%Minimap", "global_position", Vector2(0,0), 0.1)
	tween.tween_property($"%Minimap", "size", self.get_parent().size, 0.1)

func toggle_texture_size():
	if self.get_global_rect() != $"%MinimapBackground".get_global_rect():
		reset_transform()
	else:
		expand_minimap()

func _input(event):
	if self.visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if self.get_global_rect().has_point(event.position):
			self.toggle_texture_size()
