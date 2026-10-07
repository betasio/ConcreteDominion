extends Node

var failures: PackedStringArray = []
var loaded_count := 0


func _ready() -> void:
	_scan_directory("res://scripts")
	_scan_directory("res://scenes")
	_scan_directory("res://data")
	_finish()


func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		_fail("Could not open directory: %s" % path)
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue

		var full_path := path.path_join(entry)
		if dir.current_is_dir():
			_scan_directory(full_path)
		elif _should_load(entry):
			_load_resource(full_path)

		entry = dir.get_next()
	dir.list_dir_end()


func _should_load(file_name: String) -> bool:
	return (
		file_name.ends_with(".gd")
		or file_name.ends_with(".tscn")
		or file_name.ends_with(".tres")
	)


func _load_resource(path: String) -> void:
	if not ResourceLoader.exists(path):
		_fail("ResourceLoader does not recognize: %s" % path)
		return

	var resource := load(path)
	if resource == null:
		_fail("Could not load resource: %s" % path)
		return

	loaded_count += 1


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[RESOURCE AUDIT] %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("[RESOURCE AUDIT] PASS — loaded %d scripts/scenes/data resources." % loaded_count)
		get_tree().quit(0)
	else:
		print("[RESOURCE AUDIT] FAIL — %d issue(s)." % failures.size())
		get_tree().quit(1)
