extends Node
## AudioSynth (autoload): 100% Zero-Asset Procedural Audio Engine for AQUASTASIS.
## Synthesizes ambient deep-ocean drones, tactical sonar pings, bubble pops,
## terminal clicks, DEFCON crisis sirens, and ecosystem heartbeats using
## Godot 4's AudioStreamGenerator (zero external audio files).

const SAMPLE_RATE := 22050.0

var _player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback

var is_muted: bool = false
var master_volume: float = 0.65
var ambient_enabled: bool = true

# Ambient drone state
var _drone_phase: float = 0.0
var _lfo_phase: float = 0.0

# Active sound voices
var _sonar_time: float = -1.0
var _sonar_timer: float = 0.0
var _click_time: float = -1.0
var _bubble_time: float = -1.0
var _bubble_is_science: bool = true
var _chord_time: float = -1.0
var _chord_freqs: Array[float] = [261.63, 329.63, 392.0] # C major

# Warning states
var siren_active: bool = false
var _siren_time: float = 0.0
var heartbeat_active: bool = false
var _heartbeat_time: float = 0.0
var _heartbeat_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Run even when simulation is paused
	_init_audio_pipeline()


func _init_audio_pipeline() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SAMPLE_RATE
	_generator.buffer_length = 0.12

	_player = AudioStreamPlayer.new()
	_player.stream = _generator
	_player.bus = &"Master"
	add_child(_player)

	# Start playback
	_player.play()
	_playback = _player.get_stream_playback()


func _process(delta: float) -> void:
	if _playback == null or is_muted or master_volume <= 0.001:
		return

	# Sonar auto-pulse every 9 seconds
	if ambient_enabled:
		_sonar_timer += delta
		if _sonar_timer >= 9.0:
			_sonar_timer = 0.0
			play_sonar()

	# Heartbeat rhythm timer when sea health is in critical state
	if heartbeat_active:
		_heartbeat_timer += delta
		if _heartbeat_timer >= 1.2:
			_heartbeat_timer = 0.0
			_heartbeat_time = 0.0

	var frames_needed: int = _playback.get_frames_available()
	if frames_needed <= 0:
		return

	var dt: float = 1.0 / SAMPLE_RATE
	for i in range(frames_needed):
		var sample: float = 0.0

		# 1. Ambient Deep Ocean Drone (45-55 Hz slowly modulated sine)
		if ambient_enabled:
			_lfo_phase += 0.12 * TAU * dt
			if _lfo_phase > TAU:
				_lfo_phase -= TAU
			var drone_freq: float = 48.0 + sin(_lfo_phase) * 6.0
			_drone_phase += drone_freq * TAU * dt
			if _drone_phase > TAU:
				_drone_phase -= TAU
			sample += sin(_drone_phase) * 0.07

		# 2. Sonar Ping (750 Hz decaying sine with echo)
		if _sonar_time >= 0.0:
			_sonar_time += dt
			if _sonar_time < 2.0:
				var amp1: float = exp(-4.5 * _sonar_time) * 0.18
				sample += sin(750.0 * TAU * _sonar_time) * amp1
				# Secondary echo after 0.28s
				if _sonar_time > 0.28:
					var te: float = _sonar_time - 0.28
					var amp2: float = exp(-5.0 * te) * 0.08
					sample += sin(746.0 * TAU * te) * amp2
			else:
				_sonar_time = -1.0

		# 3. Terminal Mechanical Click
		if _click_time >= 0.0:
			_click_time += dt
			if _click_time < 0.025:
				var amp_c: float = (1.0 - (_click_time / 0.025)) * 0.16
				sample += sin(1250.0 * TAU * _click_time) * amp_c
			else:
				_click_time = -1.0

		# 4. Bubble Pop SFX (Upward pitch chirp)
		if _bubble_time >= 0.0:
			_bubble_time += dt
			if _bubble_time < 0.065:
				var frac: float = _bubble_time / 0.065
				var freq_b: float = lerpf(380.0, 950.0 if _bubble_is_science else 650.0, frac)
				var amp_b: float = sin(frac * PI) * 0.22
				sample += sin(freq_b * TAU * _bubble_time) * amp_b
			else:
				_bubble_time = -1.0

		# 5. DEFCON Siren (Dual tone 880 / 440 Hz alternating)
		if siren_active:
			_siren_time += dt
			var s_phase: float = fmod(_siren_time, 0.7)
			var s_freq: float = 880.0 if s_phase < 0.35 else 587.3
			sample += sin(s_freq * TAU * _siren_time) * 0.12

		# 6. Ecosystem Heartbeat ("lub-dub" thumps)
		if _heartbeat_time >= 0.0:
			_heartbeat_time += dt
			if _heartbeat_time < 0.14:
				# First thump "lub" (52 Hz)
				var h_frac1: float = _heartbeat_time / 0.14
				sample += sin(52.0 * TAU * _heartbeat_time) * (sin(h_frac1 * PI) * 0.25)
			elif _heartbeat_time >= 0.22 and _heartbeat_time < 0.34:
				# Second thump "dub" (68 Hz)
				var h_frac2: float = (_heartbeat_time - 0.22) / 0.12
				sample += sin(68.0 * TAU * (_heartbeat_time - 0.22)) * (sin(h_frac2 * PI) * 0.20)
			elif _heartbeat_time >= 0.34 and not heartbeat_active:
				_heartbeat_time = -1.0

		# 7. Triumphant Triad Chime (Policy adoption / Summit victory)
		if _chord_time >= 0.0:
			_chord_time += dt
			if _chord_time < 0.6:
				var c_amp: float = exp(-3.5 * _chord_time) * 0.10
				for cf in _chord_freqs:
					sample += sin(cf * TAU * _chord_time) * c_amp
			else:
				_chord_time = -1.0

		sample = clampf(sample * master_volume, -1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))


# --- Public Triggers ---

func play_click() -> void:
	if is_muted:
		return
	_click_time = 0.0


func play_bubble(is_science: bool = true) -> void:
	if is_muted:
		return
	_bubble_is_science = is_science
	_bubble_time = 0.0


func play_sonar() -> void:
	if is_muted:
		return
	_sonar_time = 0.0


func play_policy_adopt() -> void:
	if is_muted:
		return
	_chord_freqs = [261.63, 329.63, 392.0, 523.25] # C major chord
	_chord_time = 0.0


func play_cured() -> void:
	if is_muted:
		return
	_chord_freqs = [349.23, 440.0, 523.25] # F major triumphant
	_chord_time = 0.0


func play_alarm() -> void:
	if is_muted:
		return
	siren_active = true
	var timer := get_tree().create_timer(1.8)
	timer.timeout.connect(func(): siren_active = false)


func set_siren(active: bool) -> void:
	siren_active = active


func set_heartbeat(active: bool) -> void:
	heartbeat_active = active


func toggle_mute() -> bool:
	is_muted = not is_muted
	return is_muted


func set_muted(val: bool) -> void:
	is_muted = val
