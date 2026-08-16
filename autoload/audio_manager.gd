extends Node
## Synthesized 8-bit sound effects (all sounds are generated at runtime,
## original waveforms — no third-party audio assets).

const MIX_RATE := 22050
const PLAYER_COUNT := 8

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_player := 0
var _noise_seed := 12345


func _ready() -> void:
	for index: int in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_players.append(player)
	_build_sounds()
	SettingsManager.changed.connect(_on_settings_changed)


func play(sound: String) -> void:
	if not SettingsManager.sfx_enabled or not _streams.has(sound):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[sound]
	player.volume_db = linear_to_db(maxf(SettingsManager.sfx_volume, 0.001))
	player.play()


func _on_settings_changed() -> void:
	# Nothing to do per-frame; volume is applied at play time.
	pass


func _build_sounds() -> void:
	_streams["jump"] = _square(220.0, 460.0, 0.16, 0.35)
	_streams["stomp"] = _noise_burst(0.14, 0.5) 
	_streams["coin"] = _two_tone(988.0, 1319.0, 0.09, 0.4)
	_streams["bump"] = _square(170.0, 120.0, 0.09, 0.45)
	_streams["brick"] = _noise_burst(0.18, 0.6)
	_streams["mushroom"] = _arpeggio([523.0, 659.0, 784.0, 1047.0], 0.09, 0.4)
	_streams["grow"] = _square(300.0, 920.0, 0.38, 0.35)
	_streams["power"] = _arpeggio([659.0, 784.0, 988.0, 1319.0], 0.08, 0.42)
	_streams["shrink"] = _square(620.0, 190.0, 0.32, 0.35)
	_streams["hurt"] = _square(420.0, 110.0, 0.28, 0.4)
	_streams["attack"] = _square(520.0, 980.0, 0.12, 0.32)
	_streams["spring"] = _square(150.0, 520.0, 0.22, 0.4)
	_streams["checkpoint"] = _two_tone(660.0, 880.0, 0.14, 0.4)
	_streams["flag"] = _arpeggio([523.0, 659.0, 784.0, 1047.0], 0.13, 0.42)
	_streams["death"] = _square(500.0, 70.0, 0.65, 0.4)
	_streams["land"] = _noise_burst(0.08, 0.3)
	_streams["ui"] = _square(880.0, 880.0, 0.07, 0.35)
	_streams["pipe"] = _square(310.0, 92.0, 0.3, 0.34)
	_streams["secret"] = _arpeggio([392.0, 523.0, 659.0, 784.0, 1047.0], 0.075, 0.36)


func _square(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for index: int in count:
		var t := float(index) / float(count)
		var freq := lerpf(freq_start, freq_end, t)
		phase += freq / MIX_RATE
		var wave := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		var env := 1.0
		if t < 0.05:
			env = t / 0.05
		elif t > 0.72:
			env = 1.0 - (t - 0.72) / 0.28
		var sample := int(clampf(wave * env * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, sample)
	return _make_stream(data)


func _two_tone(first: float, second: float, duration: float, volume: float) -> AudioStreamWAV:
	var count := int(duration * 2.0 * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for index: int in count:
		var t := float(index) / float(count)
		var freq := first if t < 0.5 else second
		phase += freq / MIX_RATE
		var wave := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		var local_t := fmod(t * 2.0, 1.0)
		var env := 1.0
		if local_t < 0.08:
			env = local_t / 0.08
		elif local_t > 0.7:
			env = 1.0 - (local_t - 0.7) / 0.3
		var sample := int(clampf(wave * env * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, sample)
	return _make_stream(data)


func _arpeggio(notes: Array, step: float, volume: float) -> AudioStreamWAV:
	var total := notes.size() * step
	var count := int(total * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for index: int in count:
		var t := float(index) / float(count) * total
		var note_index := mini(int(t / step), notes.size() - 1)
		var freq := float(notes[note_index])
		phase += freq / MIX_RATE
		var wave := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		var local_t := fmod(t, step) / step
		var env := 1.0
		if local_t < 0.1:
			env = local_t / 0.1
		elif local_t > 0.6:
			env = 1.0 - (local_t - 0.6) / 0.4
		var sample := int(clampf(wave * env * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, sample)
	return _make_stream(data)


func _noise_burst(duration: float, volume: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index: int in count:
		var t := float(index) / float(count)
		_noise_seed = (_noise_seed * 1103515245 + 12345) & 0x7FFFFFFF
		var wave := (float(_noise_seed % 20001) / 10000.0) - 1.0
		var env := 1.0
		if t < 0.03:
			env = t / 0.03
		elif t > 0.6:
			env = 1.0 - (t - 0.6) / 0.4
		var sample := int(clampf(wave * env * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, sample)
	return _make_stream(data)


func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
