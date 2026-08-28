extends Node

# --- SFX PRELOADS ---
var build_sound = preload("res://GridWorks Major Project 2026/Scripts/Bluezone_BC0301_tiny_gears_small_mechanism_click_003.wav")
var demolish_sound = preload("res://GridWorks Major Project 2026/Scripts/Bluezone_BC0301_tiny_gears_small_mechanism_click_003.wav")
var click_sound = preload("res://GridWorks Major Project 2026/Scripts/Bluezone_BC0302_industrial_lever_switch_small_003.wav")
var craft_sound = preload("res://GridWorks Major Project 2026/Scripts/Bluezone_BC0301_tiny_gears_small_mechanism_click_complex_011.wav")

# --- MUSIC PLAYLIST ---
var playlist: Array[AudioStream] = [
	preload("res://Equatorial Complex.mp3"),
	preload("res://Half Mystery.mp3"),
	preload("res://Beauty Flow.mp3")
]

var music_player: AudioStreamPlayer
var current_track_index: int = 0

# --- GLOBAL VOLUME TRACKERS ---
var current_music_volume: float = 1.0
var current_sfx_volume: float = 1.0

# --- NEW: DEDICATED CONFIG FILE ---
var config = ConfigFile.new()
const SETTINGS_PATH = "user://settings.cfg"

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -12.0
	music_player.bus = "Music"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS 
	add_child(music_player)
	
	music_player.finished.connect(_play_next_track)
	playlist.shuffle()
	_play_next_track()
	
	# Instantly load independent settings on boot
	load_settings()

func _play_next_track() -> void:
	if playlist.is_empty():
		return
	music_player.stream = playlist[current_track_index]
	music_player.play()
	current_track_index = (current_track_index + 1) % playlist.size()

# --- SAFE VOLUME SETTERS ---
func set_music_volume(linear_val: float) -> void:
	current_music_volume = linear_val
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))

func set_sfx_volume(linear_val: float) -> void:
	current_sfx_volume = linear_val
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))

# --- NEW: INDEPENDENT SETTINGS SAVER ---
func save_settings() -> void:
	config.set_value("audio", "music", current_music_volume)
	config.set_value("audio", "sfx", current_sfx_volume)
	config.save(SETTINGS_PATH)

func load_settings() -> void:
	if config.load(SETTINGS_PATH) == OK:
		set_music_volume(config.get_value("audio", "music", 1.0))
		set_sfx_volume(config.get_value("audio", "sfx", 1.0))
	else:
		set_music_volume(1.0)
		set_sfx_volume(1.0)

# --- DYNAMIC SFX PLAYER ---
func play_sound(stream: AudioStream, volume: float = 0.0) -> void:
	if stream == null: 
		return
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	player.bus = "SFX"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
