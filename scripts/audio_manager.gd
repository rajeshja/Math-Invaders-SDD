## Central audio playback (Phase 10 FR9.5/FR9.6). Autoloaded as
## `AudioManager`; purely presentational - it never touches gameplay state.
##
## SFX: small round-robin pool of AudioStreamPlayers keyed by cue name, so
## overlapping cues (e.g. fire + hit) never cut each other off.
## Music: one looping AudioStreamPlayer started by Main.gd at session start
## and stopped on Game Over (FR9.6); the stream is force-configured to loop
## forward at runtime so the WAV's import settings can never silently break
## the loop, with a finished->replay fallback as a final safety net.
extends Node

const SFX_PATHS := {
	"fire": "res://assets/audio/sfx/fire.wav",
	"hit": "res://assets/audio/sfx/hit.wav",
	"miss": "res://assets/audio/sfx/miss.wav",
	"enemy_fire": "res://assets/audio/sfx/enemy_fire.wav",
	"player_hit": "res://assets/audio/sfx/player_hit.wav",
	"wave_complete": "res://assets/audio/sfx/wave_complete.wav",
	"level_complete": "res://assets/audio/sfx/level_complete.wav",
	"game_over": "res://assets/audio/sfx/game_over.wav",
	"tick": "res://assets/audio/sfx/tick.wav",
	"click": "res://assets/audio/sfx/click.wav",
	"hover": "res://assets/audio/sfx/hover.wav",
	"unlock": "res://assets/audio/sfx/unlock.wav",
	"paper": "res://assets/audio/sfx/paper.wav",
	"scroll_tick": "res://assets/audio/sfx/scroll_tick.wav",
}

const MUSIC_PATH := "res://assets/audio/music/gameplay_music.wav"
const SFX_POOL_SIZE := 8
const MUSIC_VOLUME_DB := -9.0

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _music: AudioStreamPlayer = null
var _music_stream: AudioStream = null


func _ready() -> void:
	for cue in SFX_PATHS:
		var path: String = SFX_PATHS[cue]
		if ResourceLoader.exists(path):
			_streams[cue] = load(path)
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	_music.finished.connect(_on_music_finished)


## Plays a named cue. Unknown names are ignored (missing-file safety).
func play_sfx(cue: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(cue)
	if stream == null:
		return
	var player := _next_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func play_music() -> void:
	if _music.playing:
		return
	if _music_stream == null and ResourceLoader.exists(MUSIC_PATH):
		_music_stream = load(MUSIC_PATH)
	if _music_stream == null:
		return
	_apply_loop(_music_stream)
	_music.stream = _music_stream
	_music.play()


func stop_music() -> void:
	_music.stop()


func is_music_playing() -> bool:
	return _music.playing


func _next_player() -> AudioStreamPlayer:
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	return player


## Configures forward looping on the WAV stream regardless of import
## metadata: 16-bit mono PCM frames = byte_size / 2.
func _apply_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2


## Fallback if the stream still reports an end (e.g. import replaced the
## resource with a non-looping variant).
func _on_music_finished() -> void:
	if _music.stream != null:
		_music.play()
