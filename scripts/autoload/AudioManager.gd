extends Node
## Manages sound effects, music, and phonics audio playback.

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

func play_sfx(stream: AudioStream) -> void:
	for player in _sfx_pool:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	# All busy — skip this sound rather than interrupting

func play_music(stream: AudioStream, fade_in := 1.0) -> void:
	if _music_player.playing:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -40.0, fade_in)
		tween.tween_callback(func() -> void:
			_music_player.stream = stream
			_music_player.volume_db = 0.0
			_music_player.play()
		)
	else:
		_music_player.stream = stream
		_music_player.play()

func stop_music(fade_out := 1.0) -> void:
	if _music_player.playing:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -40.0, fade_out)
		tween.tween_callback(_music_player.stop)

func play_letter_sound(_letter: String) -> void:
	# Future: load phonics audio from assets/audio/phonics/{letter}.ogg
	# For now, this is a placeholder
	pass
