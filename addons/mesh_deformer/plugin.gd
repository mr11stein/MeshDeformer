@tool
class_name MeshDeformerPlugin extends EditorPlugin

var mesh_deformer:MeshDeformer
var edited_point_idx = -1
var wip_active = false

func _make_visible(visible):
	pass

func _edit(object) -> void:
	mesh_deformer = object
	update_overlays()

func _process(delta):
	update_overlays()

func _handles(object) -> bool:
	return object is MeshDeformer

func _notification(what):
	if NOTIFICATION_APPLICATION_FOCUS_OUT == what:
		if wip_active: _end_wip_deformer_point()

func _enter_tree():
	add_custom_type("MeshDeformer", "Node2D", preload("Nodes/MeshDeformer.gd"), preload("Nodes/MeshDeformer.svg"))
	pass

func _forward_canvas_gui_input(event):
#	if(not mesh_deformer.target): return false
	if not is_instance_valid(mesh_deformer.target):
		return false

	if event is InputEventMouseButton:
		if not wip_active and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			var tolerance = get_editor_interface().get_editor_settings().get("editors/polygon_editor/point_grab_radius")
			var mouse = mesh_deformer.target.get_local_mouse_position()
			var deformer_point_idx = 0
			for point in mesh_deformer.points:
				if(mouse.distance_to(point) <= tolerance):
					_start_wip_deformer_point(deformer_point_idx)	
					return true
				deformer_point_idx+=1
			if _is_inside_mesh_deformer(mesh_deformer.target.get_local_mouse_position()):
				print("is inside")
				return true
		if wip_active and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
			_end_wip_deformer_point()
			return true

	if event is InputEventMouseMotion:
		if(wip_active):
			var mouse = mesh_deformer.target.get_local_mouse_position()
			_move_wip_deformer_point(mouse)
			return true

	return false

func _start_wip_deformer_point(index_of_edited_point: int):
	wip_active = true
	edited_point_idx = index_of_edited_point
	get_undo_redo().create_action("Deformer points changed")
	var undo_copy = mesh_deformer.points.duplicate()
	get_undo_redo().add_undo_property(mesh_deformer, "points", undo_copy)
	var edit_copy = mesh_deformer.points.duplicate()
	mesh_deformer.set_points(edit_copy)

func _move_wip_deformer_point(new_position: Vector2):
	mesh_deformer.points[edited_point_idx] = new_position
	update_overlays() 

func _end_wip_deformer_point():
	get_undo_redo().add_do_property(mesh_deformer, "points", mesh_deformer.points.duplicate())
	mesh_deformer.notify_property_list_changed()
	get_undo_redo().commit_action()
	wip_active = false

func _is_inside_mesh_deformer(mouse: Vector2):
	var n_points = mesh_deformer._n_points
	for x in range(mesh_deformer.divisions.x):
		for y in range(mesh_deformer.divisions.y):
			var upper_left = mesh_deformer.points[x + y*n_points.x]
			var upper_right = mesh_deformer.points[x + 1 + y*n_points.x]
			var lower_left = mesh_deformer.points[x + (y+1)*n_points.x]
			var lower_right = mesh_deformer.points[x+1 + (y+1)*n_points.x]
			var point = Vector2i(mouse.x,mouse.y)
			if (_is_point_in_triangle(point, upper_left, upper_right, lower_left) or
				_is_point_in_triangle(point,upper_right, lower_left, lower_right)):
				return true
	return false

func _sign (p1: Vector2i, p2:Vector2i, p3:Vector2i) ->int:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)

func _is_point_in_triangle(point:Vector2i, p1:Vector2i, p2: Vector2i, p3:Vector2i) -> bool:
	var d1 = _sign(point, p1, p2)
	var d2 = _sign(point, p2, p3)
	var d3 = _sign(point, p3, p1)

	var has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)

	return not (has_neg and has_pos)

func _forward_canvas_draw_over_viewport(overlay: Control):
	if not mesh_deformer.target:
		return
	var bounds = mesh_deformer._get_bounds()

	var xform =   mesh_deformer.target.get_viewport_transform() * mesh_deformer.target.get_global_transform() 
	var step_pixel = bounds.size/mesh_deformer.divisions
	for point in mesh_deformer.points:
		overlay.draw_circle(xform * point, 2, Color.GRAY)
	for x in range(mesh_deformer._n_points.x):
		for y in range(mesh_deformer._n_points.y):
			if x < mesh_deformer.divisions.x :
				var point = mesh_deformer.points[y*mesh_deformer._n_points.x + x]
				var next_point_right = mesh_deformer.points[(y*mesh_deformer._n_points.x) + x+1]
				overlay.draw_line(xform * point, xform * next_point_right, Color.GRAY)
			if y < mesh_deformer.divisions.y :
				var point = mesh_deformer.points[y*mesh_deformer._n_points.x + x]
				var next_point_downwards = mesh_deformer.points[(y+1)*mesh_deformer._n_points.x + x]
				overlay.draw_line(xform * point, xform * next_point_downwards, Color.GRAY)
	pass

func _exit_tree():
	pass
