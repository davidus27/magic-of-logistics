class_name NodeRef
extends RefCounted
## Resolves a NodePath export into a node, with a clear error when it is wrong.
##
## Scenes in this project reference each other through NodePath exports rather
## than node-typed exports. A node-typed `@export` is only filled in when the
## Godot editor writes the scene file: the editor stores extra state that a
## hand-authored .tscn does not have, so the same `NodePath("../World/Map")` line
## leaves a node-typed property null while a NodePath property resolves correctly.
##
## The editor still shows a node picker for a NodePath export, so nothing is lost
## in the inspector, and a wrong path now reports which node and which field.


static func get_required(owner: Node, path: NodePath, label: String) -> Node:
	if path.is_empty():
		push_error("%s: the %s path is not set." % [owner.get_path(), label])
		return null
	var node := owner.get_node_or_null(path)
	if node == null:
		push_error("%s: the %s path '%s' does not point at a node." % [
			owner.get_path(), label, path,
		])
	return node
