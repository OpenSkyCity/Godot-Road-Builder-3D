extends Spatial
export var building_net_np: NodePath
export var road_network_np: NodePath
onready var building_net: BuildingNetwork = get_node_or_null(building_net_np) as BuildingNetwork
onready var road_network: RoadNetwork = get_node_or_null(road_network_np) as RoadNetwork

var building_1 = BuildingType.new("test_id", "Test Name", load("res://models/house1/building1.tscn"), 2)
var building_2 = BuildingType.new("test_id2", "Test Name 2", load("res://models/house2/house2.tscn"), 2)

var buildings = [building_1, building_2]

func _ready():
	
	building_1.face_direction = Vector3(1, 0, 0)
	building_2.face_direction = Vector3.BACK

func _on_Timer_timeout():
	print("Trying to place a building")
	var segs = sample_random(road_network.get_all_segments(), 3)
	for seg in segs:
			
		var closest_point = (seg as RoadSegmentBase).get_point(randf())
		var dir = (seg as RoadSegmentBase).direction_from(0)
		
		var l_dir = Vector3(-dir.z, dir.y, dir.x)
		
		var lr_dir = l_dir if randi() % 2 == 0 else -l_dir
		prints(lr_dir, dir)
		
		var building = sample_random(buildings)[0]
		
		var point: Vector3 = closest_point + lr_dir * -((seg.road_network_info.segment_width + building.width)/2)
		
		var building_transform = Transform.IDENTITY
		building_transform = calculate_transform(point, closest_point, building_transform, building)
		building_net.try_place_building(building, building_transform)

func calculate_transform(point, closest_point, building_transform, selected_building):
	var new_building_transform = Transform.IDENTITY
	new_building_transform.origin = point
	
	var a = closest_point - point
	var b = selected_building.face_direction
	var angle_a = atan2(a.z, a.x)
	var angle_b = atan2(b.z, b.x)
	var angle = angle_b - angle_a
	
	new_building_transform.basis = new_building_transform.basis.rotated(Vector3.UP, angle)
	
#	var b_scale = selected_building.transform.basis.get_scale()
#	new_building_transform.basis = new_building_transform.basis.scaled(b_scale)
	return new_building_transform


static func sample_random(data: Array, size=1):
	var res = []
	if data.size() <= 0:
		return []
	for _i in size:
		data.shuffle()
		res.append(data[randi() % data.size()])
	return res

