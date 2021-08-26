extends Spatial
class_name RoadNetwork

signal graph_changed()

class RoadIntersection:
	var position: Vector3
	var connections: Array
	var length: float = 1
	
	var road_network: RoadNetwork
	
	var g_cost: float
	var h_cost: float
	var f_cost: float
	
	func _init(_position, _connections = []):
		self.position = _position
		self.connections = _connections
	
	func distance_to(to_intersection: RoadIntersection):
		return self.position.distance_to(to_intersection.position)
	
	func direction_to(to_intersection: RoadIntersection):
		return self.position.direction_to(to_intersection.position)
	
	func linear_interpolate(to_intersection: RoadIntersection, time):
		return self.position.linear_interpolate(to_intersection.position, time)
	
	func get_connected_nodes():
		var connected_nodes = []
		for connection in connections:
			connected_nodes.append(connection.end_position)
		return connected_nodes
	
	func angle_to(to_intersection: RoadIntersection):
		return self.position.angle_to(to_intersection.position)
	
class RoadSegment:
	var start_position: RoadIntersection
	var end_position: RoadIntersection
	var distance: float
	
	var road_network: RoadNetwork
	var width = 0.5
	
	func _init(_start_position: RoadIntersection, _end_position: RoadIntersection, _road_network: RoadNetwork):
		self.start_position = _start_position
		self.end_position = _end_position
		self.road_network = _road_network
		self.distance = start_position.distance_to(end_position)
	
	func distance_to(to_position: Vector3):
		var closest_point = project_point(to_position)
		return closest_point.distance_to(to_position)
	
	func distance_squared_to(to_position: Vector3):
		var closest_point = project_point(to_position)
		return closest_point.distance_squared_to(to_position)
	
	func direction_to(to_position: Vector3):
		var closest_point = project_point(to_position)
		return closest_point.direction_to(to_position)
	
	func project_point(to_position: Vector3):
		return Geometry.get_closest_point_to_segment(to_position, start_position.position, end_position.position)
	
	func get_points(spacing = 0.5, resolution = 1):
		var points = [start_position.position]
		var previous_point = start_position.position
		var distance_since_last_point = 0
		var division_amount = distance * resolution * 10
		var time = 0
		while time <= 1:
			time += 1/division_amount
			var point = start_position.linear_interpolate(end_position, time)
			distance_since_last_point += point.distance_to(previous_point)
			while distance_since_last_point >= spacing:
				var over_shoot_distance = distance_since_last_point - spacing
				var new_point = point + (previous_point - point).normalized() * over_shoot_distance
				points.append(new_point)
				distance_since_last_point = over_shoot_distance
				previous_point = new_point
			previous_point = point
		return points

var intersections: Array
var network: Dictionary

export var use_astar = false
var astar: AStar = AStar.new()

export var use_immediate_geo = true
export(NodePath) var immediate_geo_node
var immediate_geo: ImmediateGeometry

export var use_quad_tree = true

export(NodePath) var quad_tree_node_path
var quad_tree: QuadTreeNode

export var auto_clear_when_draw = true

var astar_intersection_map: Dictionary = {}

func _ready():
	if use_quad_tree:
		quad_tree = get_node(quad_tree_node_path)
	if use_immediate_geo:
		immediate_geo = get_node(immediate_geo_node)

func add_intersection(intersection: RoadIntersection, do_update: bool = true):
	if intersection.road_network == self:
		push_error("Intersection is already present.")
		return
	elif intersection.road_network:
		push_error("Intersection already in a network, remove it from the previous network and add it to this network.")
		return
	var _quad_tree_node = _create_quad_tree_node(intersection)
	if use_quad_tree:
		var qt_node = quad_tree.add_body(_quad_tree_node, _quad_tree_node.get_meta("_aabb"))
		intersection.set_meta("_qt_node", qt_node)
	intersections.append(intersection)
	intersection.road_network = self
#	print(_generate_id(intersection), "add")
	if use_astar:
		var _intersection_id = _generate_id(intersection)
		astar_intersection_map[_intersection_id] = intersection
		astar.add_point(_intersection_id, intersection.position)
	if do_update:
		emit_signal("graph_changed")

func remove_intersection(intersection: RoadIntersection, check_when_remove = false, do_update: bool = true):
	if !intersection.road_network:
		push_error("Intersection not in network.")
		return
	
	if intersection.road_network != self:
		push_error("Can't remove intersection, intersection is in different road network.")
		return
	
#	print(_generate_id(intersection), "remove")
	if intersection.connections:
		for connection in intersection.connections:
# warning-ignore:return_value_discarded
			if connection.end_position in intersections or !check_when_remove:
				disconnect_intersections(connection.start_position, connection.end_position, false)
	intersections.erase(intersection)
	intersection.road_network = null
	if use_quad_tree:
		if intersection.has_meta("_qt_node"):
			quad_tree.remove_body(intersection.get_meta("_qt_node"))
	if use_astar:
		var _intersection_id = _generate_id(intersection)
		if astar.has_point(_intersection_id):
			astar_intersection_map.erase(_intersection_id)
			astar.remove_point(_intersection_id)
	if do_update:
		emit_signal("graph_changed")
	
func disconnect_intersections(start_intersection: RoadIntersection, end_intersection: RoadIntersection, do_update: bool = true):
	if start_intersection.road_network != self:
		push_error("Can't connect, please add start_intersection to this road network.")
		return null
	if end_intersection.road_network != self:
		push_error("Can't connect, please add end_intersection to this road network.")
		return null
	if !are_intersections_connected(start_intersection, end_intersection):
		push_error("Intersections not connected, connect it before disconnecting.")
		return
	var segment = network[[start_intersection, end_intersection]]
	start_intersection.connections.erase(segment)
	end_intersection.connections.erase(segment)
	if use_astar:
		if astar.has_point(_generate_id(end_intersection)) and astar.has_point(_generate_id(end_intersection)):
			astar.disconnect_points(_generate_id(start_intersection), _generate_id(end_intersection))
	network.erase([start_intersection, end_intersection])
	if do_update:
		emit_signal("graph_changed")

func split_at_postion(segment: RoadSegment, _position: RoadIntersection):
	disconnect_intersections(segment.start_position, segment.end_position, false)
	var first_segment = connect_intersections(segment.start_position, _position, false)
	var second_segment = connect_intersections(_position, segment.end_position, false)
	return [first_segment, second_segment]

func are_intersections_connected(start_intersection, end_intersection):
	if start_intersection.road_network != self:
		push_error("Can't connect, please add start_intersection to this road network.")
		return
	if end_intersection.road_network != self:
		push_error("Can't connect, please add end_intersection to this road network.")
		return
	return network.has([start_intersection, end_intersection])
	
func connect_intersections(start_intersection, end_intersection, do_update: bool = true) -> RoadSegment:
	if start_intersection.road_network != self:
		push_error("Can't connect, please add start_intersection to this road network.")
		return null
	if end_intersection.road_network != self:
		push_error("Can't connect, please add end_intersection to this road network.")
		return null
	
	if are_intersections_connected(start_intersection, end_intersection):
		push_error("Intersections already connected, disconnect the intersection and reconnect again.")
	
	var segment =  RoadSegment.new(start_intersection, end_intersection, self)
	network[[start_intersection, end_intersection]] = segment
	start_intersection.connections.append(segment)
	end_intersection.connections.append(segment)
	if use_astar and _generate_id(start_intersection) != _generate_id(end_intersection):
		astar.connect_points(_generate_id(start_intersection), _generate_id(end_intersection))

	if do_update:
		emit_signal("graph_changed")
	return network[[start_intersection, end_intersection]]

func find_path(start_intersection, end_intersection):
	if use_astar:
		var shortest_path = astar.get_id_path(_generate_id(start_intersection), _generate_id(end_intersection))
		var intersection_path = []
		for point in shortest_path:
			intersection_path.append(astar_intersection_map[point])
		return intersection_path
	else:
		return []

func _generate_id(road_intersection: RoadIntersection):
	var _position: Vector3 = road_intersection.position
#	_position -= Vector3(-4096, -4096, -4096)
	return int((_position.x + _position.y + _position.z))

#	var visited = [end_intersection]
#	var segment
#	if longest_path:
#		segment = get_longest_known_segment_from(end_intersection, visited)
#	else:
#		segment = get_shortest_known_segment_from(end_intersection, visited)
#	visited.append(segment.start_position)
#	while segment != null:
#		if longest_path:
#			segment = get_longest_known_segment_from(segment.start_position, visited)
##			print(segment)
#		else:
#			segment = get_shortest_known_segment_from(segment.start_position, visited)
#		if segment:
#			visited.append(segment.start_position)
##			print(visited)
#			if segment.start_position == start_intersection:
#				print("found")
#				break
#
#	visited.invert()
#	return visited

func has_intersection(intersection):
	return intersection in intersections
	

func draw(line_color = Color.white, circle_color = Color.black):
	if auto_clear_when_draw:
		immediate_geo.clear()
	for intersection in intersections:
		DrawingUtils.draw_empty_circle(immediate_geo, intersection.position, 0.5, circle_color)
	
	immediate_geo.begin(Mesh.PRIMITIVE_LINES)
	for connection in network.values():
		DrawingUtils.draw_line(immediate_geo, connection.start_position.position, connection.end_position.position, line_color)
	immediate_geo.end()

func get_closest_node(to_position: Vector3, distance: float = 0.5):
	var snapped: RoadIntersection
	var mesh_inst = MeshInstance.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 10
	cylinder.bottom_radius = 10
	cylinder.height = 20
	mesh_inst.mesh = cylinder
	var aabb = mesh_inst.get_aabb()
	aabb.position.x += to_position.x
	aabb.position.z += to_position.z
	var query = quad_tree.query(aabb)
	for object in query:
		if abs(to_position.distance_to(object.translation)) < distance and object.has_meta("_intersection"):
			snapped = object.get_meta("_intersection")
	return snapped

func get_closest_segment(to_position: Vector3, distance: float = 1.5):
	var snapped_segment: RoadSegment
	for segment in network.values():
		var dist = segment.distance_to(to_position)
		if abs(dist) < distance:
			snapped_segment = segment
	return snapped_segment

func clear(do_update: bool = true):
	if use_astar:
		quad_tree.clear()
	if use_astar:
		astar.clear()
	network.clear()
	intersections.clear()
	if do_update:
		emit_signal("graph_changed")

func delete_connection(connection: RoadSegment, with_orpha_intersection: bool = true, do_update: bool = true):
	disconnect_intersections(connection.start_position, connection.end_position, false)
	if connection.start_position.connections.size() < 1:
		remove_intersection(connection.start_position, false, false)
	if connection.end_position.connections.size() < 1:
		remove_intersection(connection.end_position, false, false)
	if do_update:
		emit_signal("graph_changed")
	

#func _ready():
#	var intersect_1 = RoadIntersection.new(Vector3(2, 0, 3), [])
#	var intersect_2 = RoadIntersection.new(Vector3(6, 0, 5.3), [])
#	var intersect_3 = RoadIntersection.new(Vector3(5, 0, 3), [])
#	var intersect_4 = RoadIntersection.new(Vector3(3, 0, 8), [])
#	var intersect_5 = RoadIntersection.new(Vector3(6, 0, 8), [])
#	var intersect_6 = RoadIntersection.new(Vector3(3.3, 0, 5), [])
#
#	add_intersection(intersect_1)
#	add_intersection(intersect_2)
#	add_intersection(intersect_3)
#	add_intersection(intersect_4)
#	add_intersection(intersect_5)
#	add_intersection(intersect_6)
#
#	connect_intersections(intersect_1, intersect_2)
#	connect_intersections(intersect_2, intersect_3)
#	connect_intersections(intersect_1, intersect_4)
#	connect_intersections(intersect_3, intersect_5)
#	connect_intersections(intersect_4, intersect_5)
#	connect_intersections(intersect_5, intersect_6)
#	connect_intersections(intersect_3, intersect_6)
#
#	var shortest_path = find_path(intersect_1, intersect_6, true)
#
#	draw($ImmediateGeometry)
#
#	$ImmediateGeometry.begin(Mesh.PRIMITIVE_LINES)
#	var previous_point = null
#	for point in shortest_path:
#		if previous_point == null:
#			previous_point = point
#			continue
#		draw_line($ImmediateGeometry, previous_point.position, point.position, Color.red)
#		previous_point = point
#	$ImmediateGeometry.end()

func _create_quad_tree_node(intersection):
	var spatial = Spatial.new()
	spatial.translation = intersection.position
	spatial.set_meta("_intersection", intersection)
	spatial.set_meta("_aabb", _get_spatial_aabb(intersection.position))
	return spatial

func _get_spatial_aabb(intersection: Vector3):
	return AABB(
		(Vector3.ONE * -0.25)+intersection, 
		Vector3.ONE * 0.5
	)
