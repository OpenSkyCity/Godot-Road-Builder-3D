extends Spatial
class_name BuildingNetwork

export var quad_tree_node_path: NodePath
export var buildings_path: NodePath

signal buildings_changed

signal building_added
signal building_removed

export var min_vector = Vector3(-128, -64, -128)

var quadtree_node: QuadTreeNode
var buildings_node: Spatial

var building_id_map: Dictionary

func _ready():
	if quad_tree_node_path:
		quadtree_node = get_node(quad_tree_node_path)
	if buildings_path:
		buildings_node = get_node(buildings_path)
		
func create_building(building_type: BuildingType, transform_matrix: Transform, _building: BuildingInstance = null):
	var building = _building if _building else building_type.instance_at(transform_matrix)
	var building_aabb = building.get_aabb()
	
	var building_id = building.get_id(min_vector)
	building_id_map[building_id] = building
	
	buildings_node.add_child(building)
	building_aabb = AABBUtils.transform_aabb(transform_matrix, building_aabb)
	var qt_node = Spatial.new()
	qt_node.name = "QuadTree - Building %s" % building.position
	qt_node.set_meta('_building_inst', building)
	qt_node.set_meta('_aabb', building_aabb)
	quadtree_node.add_body(qt_node)
	building.set_meta("_qt_build", qt_node)
	emit_signal("building_added", building)
	return building

func try_place_building(building_type: BuildingType, at_transform_matrix: Transform):
	var building = building_type.instance_at(at_transform_matrix)
	var building_aabb = building.get_aabb()
	building_aabb = AABBUtils.transform_aabb(at_transform_matrix, building_aabb)	
	var res = quadtree_node.query(building_aabb)
	if !res:
		return create_building(building_type, at_transform_matrix, building)
	return null

func delete_building(building: BuildingInstance):
	var building_id = building.get_id(min_vector)
	building_id_map.erase(building_id)
	building.remove_child(building)
	var qt_node = building.get_meta('_qt_build')
	quadtree_node.remove_body(qt_node)
