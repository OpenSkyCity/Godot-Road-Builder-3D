extends Spatial


var _drag_start: RoadIntersection
var _drag_end: RoadIntersection
var _drag_current: RoadIntersection
var _is_dragging: bool

var _continue_dragging = true

var _cache_previous_segment: RoadSegmentBase
var _enabled: bool

var local_road_network: RoadNetwork
var global_road_network: RoadNetwork

var snapped_intersection: RoadIntersection
var snapped_segment: RoadSegmentBase

var _start_segment: RoadSegmentBase
var _end_segment: RoadSegmentBase

var road_net_info: RoadNetworkInfo setget set_road_net_info

func _input(event: InputEvent):
	if !_enabled:
		return
	$ImmediateGeometry.clear()
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == BUTTON_LEFT:
			if !_is_dragging:
				update_network_snapping(event)
				setup_dragging(event)
			elif _is_dragging:
				update_network_snapping(event)
				stop_dragging(event)
		elif event.pressed and event.button_index == BUTTON_RIGHT:
			if _is_dragging:
				cancel_dragging(event)
	if event is InputEventMouseMotion:
		update_network_snapping(event)
		continue_dragging(event)
		if not is_instance_valid(_drag_start):
			$RoadMesh.show()
			move_mesh(event)
		else:
			$RoadMesh.hide()

func cancel_dragging(_event: InputEvent):
	_drag_start = null
	_drag_current = null
	_drag_end = null
	_is_dragging = false
	_start_segment = null
	_end_segment = null
	if _cache_previous_segment:
		local_road_network.delete_segment(_cache_previous_segment)
		_cache_previous_segment.free()
	_cache_previous_segment = null
	local_road_network.update()
	print("cancelled")

func setup_dragging(event: InputEventMouseButton):
	_drag_start = _get_start_position(event)
	_drag_start.set_meta("_auto_delete", false)
	_start_segment = snapped_segment
	_is_dragging = true
	_drag_current = null
	print("started")

func stop_dragging(event: InputEventMouseButton):
	if !is_instance_valid(_drag_start):
		return
	_drag_end = _get_end_position(event)
	_end_segment = snapped_segment
	_is_dragging = false
	
	var inter = global_road_network.get_closest_point_to(_drag_start.position, 1)
	if not inter:
		inter = _drag_start.duplicate()
	_drag_end = snap_intersection(inter, _drag_end.duplicate())
	var inter2 = global_road_network.get_closest_point_to(_drag_end.position, 1)
	prints("intersection 2 end", inter2)
	if not inter2:
		inter2 = _drag_end.duplicate()
	
	if _start_segment:
		print("Splitting start segment")
		print("Start segment ROAD NET: ", _start_segment.road_network)
		_start_segment.split_at_position(inter)
	if _end_segment:
		_end_segment.split_at_position(inter2)
	
	var segment = RoadSegmentLinear.new(inter, inter2, road_net_info, RoadSegmentLinear.FORWARD)
	segment = global_road_network.create_segment(segment)
	global_road_network.update()
	print("stopped")
	if is_instance_valid(_cache_previous_segment):
		local_road_network.delete_segment(_cache_previous_segment)
		_cache_previous_segment.free()
		_cache_previous_segment = null
	local_road_network.update()
	_start_segment = null
	_end_segment = null
	if _continue_dragging:
		_drag_start = _drag_end
		_drag_end = null
		_is_dragging = true
	else:
		_drag_start = null
		_drag_end = null
	
func continue_dragging(event: InputEventMouseMotion):
	var previous_drag_current
	var previous_cache_segment
	if is_instance_valid(_drag_start):
		previous_drag_current = _drag_current
		previous_cache_segment = _cache_previous_segment
		_drag_current = _get_current_position(event)
		var _global_drag_start = global_road_network.get_closest_point_to(_drag_start.position)
		_drag_current = snap_intersection(
			_global_drag_start if _global_drag_start else _drag_start,
			_drag_current
			)
		if snapped_intersection:
			_drag_current = snapped_intersection.duplicate()
			print(_drag_current)
		
	if is_instance_valid(previous_cache_segment):
		print(_cache_previous_segment)
		local_road_network.delete_segment(previous_cache_segment)
		previous_cache_segment.free()
		previous_cache_segment = null
		
	if is_instance_valid(_drag_start) and _drag_start.distance_to(_drag_current) > 1:
		_cache_previous_segment = RoadSegmentLinear.new(_drag_start.duplicate(), _drag_current, road_net_info, RoadSegmentLinear.FORWARD)
		_cache_previous_segment = local_road_network.create_segment(_cache_previous_segment)

	local_road_network.update()
		
#	if is_instance_valid(previous_drag_current):
#		previous_drag_current.free()

func set_enabled(value: bool):
	_enabled = value

func _cast_ray_to(position: Vector2):
	var camera = get_viewport().get_camera()
	var from = camera.project_ray_origin(position)
	var to = from + camera.project_ray_normal(position) * camera.far
	return get_world().direct_space_state.intersect_ray(from, to).get("position", Vector3(NAN, NAN, NAN))

func is_vec_nan(vec) -> bool:
	if typeof(vec) == TYPE_VECTOR3:
		return is_nan(vec.x) and is_nan(vec.y) and is_nan(vec.z)
	if typeof(vec) == TYPE_VECTOR2:
		return is_nan(vec.x) and is_nan(vec.y)
	if typeof(vec) == TYPE_REAL:
		return is_nan(vec)
	return false

func _ready():
	self.road_net_info = RoadNetworkInfoRegister.find("*two_lane*")[0]

func move_mesh(event: InputEventMouseMotion):
	_drag_current = _get_current_position(event)
	if is_instance_valid(_drag_current):
		$RoadMesh.global_transform.origin = _drag_current.position

func _get_start_position(event: InputEventMouseButton):
	var position = _cast_ray_to(event.position)
	if snapped_intersection:
		return snapped_intersection.duplicate()
	elif snapped_segment:
		_start_segment = snapped_segment
		return RoadIntersection.new(_start_segment.project_point(position), road_net_info)
	else:
		return RoadIntersection.new(position, road_net_info)

func update_network_snapping(event: InputEventMouse):
	var position = _cast_ray_to(event.position)
	snapped_intersection = null
	snapped_segment = null
	var intersection = global_road_network.get_closest_point_to(position, road_net_info.intersection_length*2)
	if intersection:
		snapped_intersection = intersection
		return
	var segment = global_road_network.get_closest_segment_to(position, road_net_info.segment_width/2)
	if segment:
		snapped_segment = segment
		return

func snap_intersection(base_global: RoadIntersection, position: RoadIntersection, length_snap_u: float = 5.0, angle_snap_deg: float = 45.0) -> RoadIntersection:

	var length = base_global.distance_to(position)
	var direction = base_global.direction_to(position)
	var final_length = length
	var final_direction
	if base_global.road_network in [null, local_road_network] and not _start_segment:
		# we are yet to add a new segment, only snap length
		var snapped_length = round(length / length_snap_u) * length_snap_u
		if abs(length-snapped_length) < 0.5 and length > road_net_info.segment_width:
			final_length = snapped_length
		DebugConsole.add_text("Current Seg Length: %s" % snapped_length)
		var new_position = RoadIntersection.new(base_global.position + direction * final_length, road_net_info)
		return new_position
	
	elif base_global.road_network in [null, local_road_network] and _start_segment:
		# we have a start segment, snap based on it.
		var snapped_length = round(length / length_snap_u) * length_snap_u
		if abs(length-snapped_length) < 0.5 and length > road_net_info.segment_width:
			final_length = snapped_length
		DebugConsole.add_text("Current Seg Length: %s" % final_length)
		
		var seg_dir = _start_segment.direction_from(RoadSegmentBase.DirectionFrom.START)
		var angle = seg_dir.signed_angle_to(direction, Vector3.UP)
		print(angle)
		var final_angle = -angle
		var snapped_angle = round(angle / deg2rad(angle_snap_deg)) * deg2rad(angle_snap_deg)
		if abs(angle-snapped_angle) < deg2rad(5):
			final_angle = -snapped_angle
		if seg_dir:
			final_angle += seg_dir.signed_angle_to(Vector3.RIGHT, Vector3.UP)
		final_direction = Vector3(cos(final_angle), 0, sin(final_angle))
		DebugConsole.add_text("Current Seg Direction: %s" % final_direction)
		var final_position = base_global.position + final_direction * final_length
		var new_position = RoadIntersection.new(final_position, road_net_info)
		return new_position
		
		
	elif base_global.road_network in [global_road_network] and not _start_segment:
		# we have already added segments and are extending it, snap length and relative angle
		var snapped_length = round(length / length_snap_u) * length_snap_u
		if abs(length-snapped_length) < 0.5 and length > road_net_info.segment_width:
			final_length = snapped_length
		DebugConsole.add_text("Current Seg Length: %s" % snapped_length)
		
		var shortest_angle = PI
		var segment_dir
		for other in base_global.connections:
			var segment: RoadSegmentBase = base_global.connections[other]
			var seg_dir = segment.direction_from_intersection(other)
			var angle = seg_dir.signed_angle_to(direction, Vector3.UP)
			if abs(angle) < shortest_angle:
				shortest_angle = angle
				segment_dir = seg_dir
		
		var final_angle = -shortest_angle
		var snapped_angle = round(shortest_angle / deg2rad(angle_snap_deg)) * deg2rad(angle_snap_deg)
		DebugConsole.add_text("Snapped Angle: %s Tolerance: %s" % [rad2deg(snapped_angle), (angle_snap_deg/4.0) ])
		if abs(shortest_angle-snapped_angle) < deg2rad(5):
			final_angle = -snapped_angle
		if segment_dir:
			final_angle += segment_dir.signed_angle_to(Vector3.RIGHT, Vector3.UP)
		DebugConsole.add_text("Current Seg Angle: %s" % rad2deg(shortest_angle))
		final_direction = Vector3(cos(final_angle), 0, sin(final_angle))
		var final_position = base_global.position + final_direction * final_length
		var new_position = RoadIntersection.new(final_position, road_net_info)
		return new_position
	return position


# DrawingUtils.draw_line($ImmediateGeometry, base_global.position, base_global.position + -seg_dir * 10, Color.aqua)
# DrawingUtils.draw_empty_circle($ImmediateGeometry, base_global.position, 0.5, Color.aqua)
# DrawingUtils.draw_empty_circle($ImmediateGeometry, base_global.position + -seg_dir * 10, 0.5, Color.aqua)

func _get_end_position(event: InputEventMouseButton):
	var position = _cast_ray_to(event.position)
	if snapped_intersection:
		return snapped_intersection.duplicate()
	elif snapped_segment:
		_end_segment = snapped_segment
		return RoadIntersection.new(_end_segment.project_point(position), road_net_info)
	else:
		return RoadIntersection.new(position, road_net_info)

func _get_current_position(event: InputEventMouseMotion):
	var position = _cast_ray_to(event.position)
	var intersection = null
	if snapped_intersection:
		intersection = snapped_intersection.duplicate()
	elif snapped_segment:
		intersection = RoadIntersection.new(snapped_segment.project_point(position), road_net_info)
	else:
		intersection = RoadIntersection.new(position, road_net_info)
	if is_instance_valid(intersection) and is_vec_nan(intersection.position):
		return null
	return intersection

func _physics_process(_delta):
	DebugConsole.add_text("RoadToolStraight: Snapping Intersection %s" % snapped_intersection)
	DebugConsole.add_text("RoadToolStraight: Snapping Segment %s" % snapped_segment)
	DebugConsole.add_text("RoadToolStraight: Start Segment %s" % _start_segment)
	DebugConsole.add_text("RoadToolStraight: End Segment %s" % _end_segment)

#	snapped_intersection = global_road_network.get_closest_point_to(_cast_ray_to(get_viewport().get_mouse_position()))
#	snapped_segment = global_road_network.get_closest_segment_to(_cast_ray_to(get_viewport().get_mouse_position()))

func set_road_net_info(net_info: RoadNetworkInfo):
	road_net_info = net_info
	($RoadMesh.mesh as CylinderMesh).top_radius = net_info.segment_width/2
	($RoadMesh.mesh as CylinderMesh).bottom_radius = net_info.segment_width/2
