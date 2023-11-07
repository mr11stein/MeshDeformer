@tool
class_name MeshDeformer extends Node2D
@export_group("Mesh")
@export var divisions:Vector2i = Vector2i(3,3) : get=get_divisions, set = set_divisions
@export var margin:int = 10: get=get_margin, set = set_margin
@export_group("Target")
@export var target: Polygon2D = null: get = get_target, set = set_target
@export_group("Points")
@export var points:PackedVector2Array : get = get_points, set = set_points

var _n_points:Vector2i:get=_get_n_points

#editor only
var _bezier_points:Array #array of arrays of [bezier_center, bezier_left, bezier_right]
var _bezier_divisions_width:int = 1
var _bezier_divisions_height:int = 1
@export var bezier_divisions:Vector2i = Vector2i(1,1) : get=get_bezier_divisions, set = set_bezier_divisions

var _skeleton:Skeleton2D
var _bones:Array

func _get_configuration_warnings():
	if not target:
		return ["No target polygon assigned"]
	return [] 

func _notification(what: int) -> void:
	if what == NOTIFICATION_POST_ENTER_TREE:
		if is_instance_valid(target): _build_skeleton()

func _exit_tree():
	if is_instance_valid(_skeleton): _skeleton.queue_free()
	pass
	
func _get_bounds() -> Rect2i:
	if not target: return Rect2i()
	
	var min_vertex = Vector2(2147483647, 2147483647)
	var max_vertex = Vector2(0, 0)
	for vertex in target.polygon:
		min_vertex.x = min(vertex.x, min_vertex.x)
		min_vertex.y = min(vertex.y, min_vertex.y)
		max_vertex.x = max(vertex.x, max_vertex.x)
		max_vertex.y = max(vertex.y, max_vertex.y)
	var margin_pixels = Vector2(2*margin,2*margin)
	var offset = Vector2(margin, margin)
	return Rect2(min_vertex-offset, max_vertex-min_vertex + margin_pixels)

func _build_skeleton():
	if not is_instance_valid(target):
		push_warning("No target set")
		return
	
	if not target.is_node_ready():
		await target.ready
	
	var bounds = _get_bounds()
	var divisions_size = bounds.size / divisions
	
	if is_instance_valid(_skeleton):
		_skeleton.queue_free()

	_skeleton = Skeleton2D.new()
	_skeleton.name = "%s_skeleton" % name 
	_bones.clear()
	target.add_child(_skeleton)
	#uncomment to make skeleton visible in the editor (for debugging)
	#_skeleton.owner = get_tree().get_edited_scene_root() 
	target.clear_bones()
	for y in range(_n_points.y):
		for x in range(_n_points.x):
			var bone = Bone2D.new()
			bone.set_autocalculate_length_and_angle(false)
			bone.set_length(1)
			bone.set_bone_angle(0)
			bone.position = points[y*_n_points.x+x]
			bone.rest = Transform2D(0, bone.position)
			bone.set_length(1)
			bone.hide()
			_bones.append(bone)
			bone.name = "%s_bone_%s_%s" % [name, x, y]
			_skeleton.add_child(bone)
			#uncomment to make bones visible in the editor (for debugging)
			#bone.owner = get_tree().get_edited_scene_root()
	_skeleton._update_bone_setup()
	target.set_skeleton(_skeleton.get_path())

	for bone in _bones:
		var weights = PackedFloat32Array()

		weights.resize(target.polygon.size())
		weights.fill(0)
		var vertex_idx = 0
		for vertex in target.polygon:
			#iterate every rectangle in the mesh (4 connected points)
			#and check if the vertex is inside and calc weights
			for mesh_rect_x in range(divisions.x):
				for mesh_rect_y in range(divisions.y):
					var left_upper = _bones[mesh_rect_x + 0 + mesh_rect_y * _n_points.x]
					var right_upper = _bones[mesh_rect_x + 1 + mesh_rect_y * _n_points.x]
					var left_lower = _bones[mesh_rect_x + 0 + (mesh_rect_y + 1) * _n_points.x]
					var right_lower = _bones[mesh_rect_x + 1 + (mesh_rect_y + 1) * _n_points.x]
					var rect = Rect2(left_upper.position, right_lower.position-left_upper.position)
					if rect.has_point(vertex):
						var distance_lu = left_upper.position.distance_to(vertex)
						var distance_ru = right_upper.position.distance_to(vertex)
						var distance_ll = left_lower.position.distance_to(vertex)
						var distance_rl = right_lower.position.distance_to(vertex)
						var distance_sum = distance_lu + distance_ru + distance_ll + distance_rl

						
						#calculate the weight to the vertice according to the distance from bone to vertex
						#take the distance of the opposing bone to get the correct numerator 
						#so the smaller the distance the bigger the influence
						if(bone == left_upper): weights[vertex_idx] = (distance_rl /distance_sum)
						if(bone == right_upper): weights[vertex_idx] = (distance_ll /distance_sum)
						if(bone == left_lower): weights[vertex_idx] = (distance_ru /distance_sum)
						if(bone == right_lower): weights[vertex_idx] = (distance_lu /distance_sum)
			vertex_idx += 1
		target.add_bone(bone.get_path(), weights)

func _create_points():
	if(not target):
		return
	points.clear()
	var bounds = _get_bounds() 
	var step = (bounds.size) /(divisions)
	var n_points = divisions + Vector2i(1,1)
	for y in range(n_points.y):
		for x in range(n_points.x):
			points.append(bounds.position + Vector2i(x,y) * step)
	_build_skeleton()

func _update_bones():
	if not is_instance_valid(_skeleton) or not is_instance_valid(target):
		return
	
	var idx = 0
	for point in points:
		_bones[idx].set_position(point)
		idx+=1
	_skeleton._update_transform()

#properties 
func get_target() -> Polygon2D:
	return target
func set_target(new_target: Polygon2D):
	target = new_target
	if is_instance_valid(target):
		if target.is_node_ready():
			_create_points()
		else:
			target.ready.connect(_create_points, CONNECT_ONE_SHOT | CONNECT_DEFERRED)

func get_divisions() ->Vector2i:
	return divisions
func set_divisions(val: Vector2i):
	val = val.clamp(Vector2i(1,1), val)
	divisions = val
	#TODO: scale old points
	_create_points()
	property_list_changed.emit()

func _get_n_points() -> Vector2i:
	return divisions + Vector2i(1,1)

func get_margin() ->int:
	return margin
func set_margin(new_margin: int):
	margin = new_margin
	_create_points()
	property_list_changed.emit()

func get_points() ->PackedVector2Array:
	return points
func set_points(new_points: PackedVector2Array):
	points = new_points
	_update_bones()

func get_bezier_divisions() ->Vector2i:
	return bezier_divisions
func set_bezier_divisions(val: Vector2i):
	val = val.clamp(Vector2i(1,1), val)
	bezier_divisions = val
	#TODO: scale old points
	_create_points()
	property_list_changed.emit()


func _process(delta):
	_update_bones()