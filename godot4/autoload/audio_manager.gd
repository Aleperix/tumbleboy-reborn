extends Node
# AudioManager — música y efectos de sonido con carga perezosa
# (no precargamos todo para cuidar la RAM en cajas modestas).
# Port de templates/godot3 a Godot 4: AudioStreamOGGVorbis -> AudioStreamOggVorbis,
# connect(self, "finished", player, "queue_free") -> finished.connect(queue_free).

var music_player: AudioStreamPlayer
var music_cache: Dictionary = {}
var sfx_cache: Dictionary = {}
var current_music: String = ""

func _init():
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -2.0
	add_child(music_player)

func _load_stream(path: String) -> AudioStream:
	if music_cache.has(path):
		return music_cache[path]
	var stream: AudioStream = load(path)
	if stream != null:
		music_cache[path] = stream
	return stream

func play_music(path: String, loops: bool = true):
	if current_music == path and music_player.playing:
		return
	stop_music()
	if path == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = loops
		if loops:
			stream.loop_offset = 0.0
	music_player.stream = stream
	music_player.play()
	current_music = path

func stop_music():
	music_player.stop()
	current_music = ""

func play_sfx(path: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream
	if sfx_cache.has(path):
		stream = sfx_cache[path]
	else:
		stream = load(path)
		if stream == null:
			return
		sfx_cache[path] = stream
	var player := AudioStreamPlayer.new()
	player.stream = stream
	if stream is AudioStreamOggVorbis:
		stream.loop = false
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func clear_sfx():
	for child in get_children():
		if child != music_player and child is AudioStreamPlayer:
			child.queue_free()
