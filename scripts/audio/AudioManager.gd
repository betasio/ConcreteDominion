class_name AudioManager
extends Node

var _player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _catalog: PresentationCatalog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)

	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = 22050.0
	_generator.buffer_length = 0.25
	_player.stream = _generator


func setup(root: Node, presentation_catalog: PresentationCatalog = null) -> void:
	_catalog = presentation_catalog
	_connect_buttons_recursive(root)
	get_tree().node_added.connect(_on_node_added)


func play_ui_click() -> void:
	_play_asset_or_tone("ui_click", 620.0, 0.045, 0.08)


func play_reward() -> void:
	_play_asset_or_tone("reward", 920.0, 0.10, 0.11)


func play_raid_result(victory: bool) -> void:
	_play_asset_or_tone("raid_victory" if victory else "raid_defeat", 760.0 if victory else 220.0, 0.16, 0.14)


func _on_node_added(node: Node) -> void:
	if node is Button:
		call_deferred("_connect_button", node)


func _connect_buttons_recursive(node: Node) -> void:
	if node is Button:
		_connect_button(node)
	for child in node.get_children():
		_connect_buttons_recursive(child)


func _connect_button(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	var callback := Callable(self, "play_ui_click")
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _play_asset_or_tone(key: String, frequency: float, duration: float, amplitude: float) -> void:
	if _catalog != null:
		var stream := _catalog.get_audio(key)
		if stream != null:
			_player.stop()
			_player.stream = stream
			_player.play()
			return
	if _player.stream != _generator:
		_player.stream = _generator
	_play_tone(frequency, duration, amplitude)


func _play_tone(frequency: float, duration: float, amplitude: float) -> void:
	if _player == null:
		return

	_player.stop()
	_player.play()

	var playback := _player.get_stream_playback()
	if not playback is AudioStreamGeneratorPlayback:
		return

	var generator_playback := playback as AudioStreamGeneratorPlayback
	var frame_count := floori(_generator.mix_rate * duration)

	for i in range(frame_count):
		var phase := TAU * frequency * float(i) / _generator.mix_rate
		var envelope := 1.0 - float(i) / maxf(1.0, float(frame_count))
		var sample := sin(phase) * amplitude * envelope
		generator_playback.push_frame(Vector2(sample, sample))
