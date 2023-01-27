# **************************************************************************** #
#                                                                              #
#                                                   :::::::::::::::::          #
#    interractible_texture_progress.gd             ::+::+::+::+::+::           #
#                                                 +      :+:      +            #
#    By: gmarais <gmarais@noreply.github.com>           +:+    +       +       #
#                                                      +#+    +#+     +#+      #
#    Created: 2023/01/26 23:31:39 by gmarais          #+#    #+ +#   #+ +#     #
#    Updated: 2023/01/26 23:31:45 by gmarais       #######  ##   ## ##   ##    #
#                                                                              #
# **************************************************************************** #
class_name InterractibleHProgress

extends TextureProgress

signal progress_pressed(value)

var mouse_is_over = false

func _ready():
# warning-ignore:return_value_discarded
	self.connect("mouse_entered", self, "_on_mouse_entered")
# warning-ignore:return_value_discarded
	self.connect("mouse_exited", self, "_on_mouse_exited")

func _input(event):
	if mouse_is_over and event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.is_pressed():
		var mouse_relative_x_position = event.position.x - self.rect_global_position.x
		self.value = (float(mouse_relative_x_position) / float(self.rect_size.x)) * float(self.max_value)
		emit_signal("progress_pressed", self.value)

func _on_mouse_entered():
	mouse_is_over = true

func _on_mouse_exited():
	mouse_is_over = false
