extends TextureRect


var tween:SceneTreeTween


func toggle_texture_size():
	if tween:
		tween.kill()
	tween = create_tween().set_parallel(true)
	var rect = $"%MinimapBackground".get_global_rect()
	if self.get_global_rect() != $"%MinimapBackground".get_global_rect():
		# warning-ignore:return_value_discarded
		tween.tween_property($"%Minimap", "rect_global_position", rect.position, 0.1)
		# warning-ignore:return_value_discarded
		tween.tween_property($"%Minimap", "rect_size", rect.size, 0.1)
	else:
		# warning-ignore:return_value_discarded
		tween.tween_property($"%Minimap", "rect_global_position", Vector2(0,0), 0.1)
		# warning-ignore:return_value_discarded
		tween.tween_property($"%Minimap", "rect_size", self.get_parent().rect_size, 0.1)


func _input(event):
	if self.visible and event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		if self.get_global_rect().has_point(event.position):
			self.toggle_texture_size()
