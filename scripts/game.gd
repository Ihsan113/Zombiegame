extends Node2D

# Pixel Zombie LAN — wave defense prototype v0.4.21
# Host-authoritative 4-player survival over ENet/UDP on a local Wi-Fi network.

const PORT := 24567
const MAX_PLAYERS := 4
const PLAYER_SPEED := 150.0
const ZOMBIE_SPEED := 28.0
const ZOMBIE_ATTACK_RANGE := 45.0
const ZOMBIE_KIND_BOSS := 4
const BOSS_ATTACK_SLASH := 0
const BOSS_ATTACK_SLAM := 1
const BOSS_ATTACK_LUNGE := 2
const BOSS_ATTACK_FRAME_COUNT := 5
const BOSS_ATTACK_FRAME_WIDTH := 336.0
const BOSS_ATTACK_FRAME_HEIGHT := 226.0
const BOSS_ATTACK_BASELINE_Y := 214.0
const BOSS_SLASH_REACH := 76.0
const BOSS_SLAM_RADIUS := 104.0
const BOSS_LUNGE_REACH := 62.0
const BOSS_LUNGE_SPEED := 165.0
const ZOMBIE_MAX_HP := [3.0, 4.0, 7.0, 3.5, 100.0]
const WAVE_ZOMBIE_COUNT := 25
const WAVE_ZOMBIES_PER_LEVEL := 5
const BOSS_BASE_HP := 100.0
const BOSS_HP_PER_TIER := 35.0
const WAVE_BASE_DURATION := 90.0
const SHOT_RANGE_MAX := 560.0
const SHOT_LANE_TOLERANCE := 25.0
const FIRE_REPEAT_INTERVAL := 0.30 # Default sidearm interval; equipped weapons supply their own cadence.
const WEAPON_SIDEARM := 0
const WEAPON_SMG := 1
const WEAPON_SHOTGUN := 2
const WEAPON_RIFLE := 3
const WEAPON_SNIPER := 4
const WEAPON_ROCKET := 5
const WEAPON_SLOT_EMPTY := 255
const WEAPON_COUNT := 6
const SHOTGUN_PELLET_OFFSETS: Array[float] = [-13.0, -6.5, 0.0, 6.5, 13.0]
const ARENA_TOP_RATIO := 0.520
const ARENA_BOTTOM_RATIO := 0.865
const ARENA_TOP_CLEARANCE := 22.0 # Clamp character ground point just inside the asphalt below the curb.
const ARENA_BOTTOM_CLEARANCE := 40.0
const GRENADE_BLAST_RADIUS := 112.0
const GRENADE_DAMAGE := 5.0
const GRENADE_EXPLOSION_EFFECT_DURATION := 1.65
const AIRDROP_LAND_LIFETIME := 28.0 # Extra time to reach the crate on mobile; unclaimed loot then fades out.
const AIRDROP_DESPAWN_EFFECT_DURATION := 1.15
const AIRDROP_LANDING_EFFECT_DURATION := 2.0
const PLAYER_DEATH_FADE_DURATION := 1.25
const PLAYER_REMAINS_FADE_START := 11.0
const PLAYER_REMAINS_FADE_END := 14.0
const GRENADE_MAX_CARRY := 5
const GRENADE_MIN_RANGE_RATIO := 0.065
const GRENADE_MAX_RANGE_RATIO := 0.30
const WALL_PLACE_RANGE_RATIO := 0.145
# The barricade stands ACROSS the lane and faces the zombies (they walk in from the sides), so the art is
# a 3/4 view with its long axis receding into the screen and the A-frame profile toward the viewer
# (assets/barricade_detail.png, 232x340 px master, rendered from a 3D model). The sprite is drawn into a 60.0x88.0 rect whose top-left
# is BARRICADE_RECT_OFFSET relative to the wall position; the centre of its four foot pads lies 26 px
# below that position (survivor feet are ~27 px below theirs). BARRICADE_FEET are the pad bottoms
# relative to the wall position (far-left, far-right, near-left, near-right); shadows are anchored to them.
const BARRICADE_RECT_OFFSET := Vector2(-29.9, -39.3)
const BARRICADE_RECT_SIZE := Vector2(60.0, 88.0)
const BARRICADE_JOIN_GAP := 4.0 # Only a small visual gap is needed; older 132 px spacing left barricades disconnected.
const BARRICADE_VERTICAL_SPACING := 60.0 # Tighter top/bottom rows; depth sorting lets the lower barricade overlap the upper sprite naturally.
const BARRICADE_FEET: Array[Vector2] = [Vector2(-23.1, 15.3), Vector2(-1.5, 8.2), Vector2(1.5, 43.8), Vector2(23.1, 36.7)]
const BARRICADE_FOOT_RX: Array[float] = [9.0, 8.0, 10.0, 9.0]
const BARRICADE_SHADOW_OFFSET := Vector2(-21.0, 6.0) # sun sits low behind the skyline, shadows fall toward the camera
const BARRICADE_TINT := Color(0.92, 0.89, 0.87, 1.0) # pulls the sprite into the dusk palette of the road
const WALL_MIN_PLAYER_DISTANCE := 82.0
const MEDKIT_MAX_CARRY := 5
const WALL_KIT_MAX_CARRY := 5
const TURRET_KIT_MAX_CARRY := 2
const MAX_BARRICADES := 8
const MAX_TURRETS := 4
const TURRET_MAX_HP := 180.0
const TURRET_RANGE := 270.0
const TURRET_PLACE_RANGE_RATIO := 0.22
const TURRET_MIN_PLAYER_DISTANCE := 48.0
const TURRET_BASE_SPACING := 54.0
const TURRET_WALL_SPACING := 44.0
const TURRET_AGGRO_RADIUS := 132.0
const TURRET_ATTACK_RANGE := 46.0
const TURRET_DAMAGE := 1.35
const TURRET_FIRE_INTERVAL := 0.20
const TURRET_TURN_SPEED := 3.8
const WALL_ATTACK_RANGE := 50.0
const WALL_LANE_TOLERANCE := 46.0
const SNAPSHOT_INTERVAL := 0.0166 # 60 compact snapshots/second at most (one UDP datagram each, ~11 KB/s total).
const INPUT_INTERVAL := 0.0166   # 60 movement-command packets/second at most (also keeps Wi-Fi radios awake).
const SNAP_MAGIC := 0xB7
const POS_SCALE := 8.0            # wire positions are uint16 in 1/8 px units
const NO_SOURCE := 255
const LOOT_KINDS := ["grenade", "wall", "medkit", "weapon", "ammo", "turret"]
const MAX_SNAPSHOT_BYTES := 1180  # stays below the ENet fragment size so a snapshot is never split
const SNAPSHOT_HEADER_BYTES := 31
const PLAYER_RECORD_BYTES := 30
const ZOMBIE_RECORD_BYTES := 13
const WALL_RECORD_BYTES := 10
const TURRET_RECORD_BYTES := 8
const DROP_RECORD_BYTES := 27
const NADE_RECORD_BYTES := 21
const EFFECT_RECORD_BYTES := 16
const MAX_ZOMBIES_PER_SNAPSHOT := 40
const MAX_AIRDROPS_PER_SNAPSHOT := 4
const MAX_GRENADES_PER_SNAPSHOT := 8
const MAX_EFFECTS_PER_SNAPSHOT := 24
const EFFECT_REDUNDANCY_MS := 220
const SNAPSHOT_BUFFER_MAX := 40
const INTERP_DELAY_MIN := 0.050
const INTERP_DELAY_MAX := 0.30
const INTERP_ADAPT_RATE := 0.10
const EXTRAPOLATE_MAX := 0.12
const TELEPORT_DISTANCE := 150.0
const CLOCK_DRIFT_RATE := 0.002
const JITTER_SMOOTHING := 0.08
const COMMAND_BYTES := 8
const COMMAND_MAX_PER_PACKET := 8
const COMMAND_HISTORY_MAX := 240
const COMMAND_DT_UNIT := 0.0001
const COMMAND_MAX_DT := 0.1
const COMMAND_BUDGET_START := 0.25
const COMMAND_BUDGET_MAX := 0.4
const COMMAND_BUDGET_RATE := 1.12
const COMMAND_STALE_MS := 250
const PRED_SNAP_DISTANCE := 90.0
const PRED_DEADZONE := 0.35
const PRED_CORRECTION_RATE := 10.0
# Host-side smooth view of remote survivors (what the host DRAWS; gameplay keeps the exact position).
const HOST_VIEW_DELAY_MIN := 0.030
const HOST_VIEW_DELAY_MAX := 0.200
const HOST_VIEW_DELAY_PAD := 0.012
const HOST_VIEW_EXTRAPOLATE_MAX := 0.10
const HOST_VIEW_SNAP_DISTANCE := 70.0
const HOST_VIEW_RESYNC_S := 0.25
const HOST_VIEW_PLL_GAIN := 2.0
const HOST_VIEW_PLL_MAX := 0.10
const HOST_VIEW_OFFSET_LEAK := 0.01
const HOST_VIEW_JITTER_DECAY := 0.97
const HOST_VIEW_SAMPLES_MAX := 90
const FIRE_COOLDOWN_MS := 280
const FIRE_REMOTE_TOLERANCE_MS := 220 # host accepts slightly early remote shots to absorb Wi-Fi jitter
const ENET_THROTTLE_INTERVAL_MS := 1000
const ENET_THROTTLE_ACCEL := 32
const ENET_THROTTLE_DECEL := 0
const SHOW_NET_STATS := true
const SAVE_PATH := "user://world_save.json"

var screen_mode := "home" # home, help, lobby, game, pause, game_over
var is_offline := false
var button_rects: Dictionary = {}
var sprite_atlas: Texture2D
var background_texture: Texture2D
var grenade_texture: Texture2D
var grenade_explosion_texture: Texture2D
var barricade_texture: Texture2D
var airdrop_crate_texture: Texture2D
var parachute_texture: Texture2D
var airdrop_landing_texture: Texture2D
var boss_texture: Texture2D
var boss_attack_textures: Array[Texture2D] = []
var weapon_icon_textures: Dictionary = {}
var active_projectiles: Array[Dictionary] = []
var combat_effects: Array[Dictionary] = []
# Local-only presentation state. Kept out of snapshots so v0.4.11 LAN packet layout stays unchanged.
var player_death_visuals: Dictionary = {}
var wave_number := 1
var wave_total := WAVE_ZOMBIE_COUNT
var wave_spawned := 0
var wave_kills := 0
var wave_spawn_timer := 0.9
var wave_break_timer := 0.0
var wave_time_remaining := WAVE_BASE_DURATION
var wave_timed_out := false
var game_over := false

var peer: ENetMultiplayerPeer
var players: Dictionary = {}
var input_vectors: Dictionary = {}
var zombies: Array[Dictionary] = []
var airdrops: Array[Dictionary] = []
var barricades: Array[Dictionary] = []
var turrets: Array[Dictionary] = []
var turret_sequence := 1
var active_grenades: Array[Dictionary] = []
const AIRDROP_FIRST_DELAY := 10.0
const AIRDROP_INTERVAL_MIN := 24.0
const AIRDROP_INTERVAL_MAX := 34.0
const AIRDROP_FULL_RETRY := 4.0
var airdrop_spawn_timer := AIRDROP_FIRST_DELAY
var airdrop_sequence := 1
var world_seed: int = 0
var world_time := 0.0
var local_player_id := 1
var is_host := false
var host_ip := ""
var host_lan_ip := "unknown"
var joystick_origin := Vector2(110, 420)
var joystick_vector := Vector2.ZERO
var joystick_active := false
var joystick_touch_id := -1
var fire_requested := false
var fire_held := false
var fire_touch_id := -1
var fire_repeat_timer := 0.0
var heal_requested := false
var grenade_requested := false
var build_requested := false
var grenade_aim_active := false
var grenade_aim_range_ratio := 0.18
var grenade_aim_touch_id := -1
var grenade_aim_target_position := Vector2(620.0, 350.0)
var wall_place_active := false
var wall_preview_position := Vector2(480.0, 350.0)
var wall_place_touch_id := -1
var turret_place_active := false
var turret_preview_position := Vector2(480.0, 350.0)
var turret_place_touch_id := -1
var turret_requested := false
var aim_marker_enabled := true
var client_input_timer := 0.0
var snapshot_seq := 0
var effect_seq := 0
var cmd_last_seq: Dictionary = {}
var cmd_budget: Dictionary = {}
var cmd_last_ms: Dictionary = {}
var host_track: Dictionary = {}
var host_view: Dictionary = {}
var snap_buffer: Array[Dictionary] = []
var pending_effects: Array = []
var pending_sfx: Array = []
var seen_effects: Dictionary = {}
var zombie_cache: Dictionary = {}
var clock_offset_ms := 0.0
var clock_ready := false
var jitter_ms := 0.0
var interp_delay := 0.10
var last_snapshot_seq := -1
var render_time := 0.0
var render_starved := false
var host_world_w := 960.0
var host_world_h := 540.0
var pred_pos := Vector2.ZERO
var pred_corr := Vector2.ZERO
var pred_ready := false
var pred_error_px := 0.0
var pred_unacked: Array = []
var cmd_seq := 0
var cmd_open_qx := 0
var cmd_open_qy := 0
var cmd_open_dt := 0.0
var local_face := 1.0
var local_walking := false
var local_hp := 100.0
var local_shoot_timer := 0.0
var local_fire_ms := 0
var stat_timer := 0.0
var stat_snaps := 0
var stat_lost := 0
var stat_bytes := 0
var stat_bad := 0
var net_snaps_per_s := 0.0
var net_kbps := 0.0
var net_loss_pct := 0.0
var net_rtt_ms := -1
var snapshot_timer := 0.0
var fire_cooldowns: Dictionary = {}
var heal_cooldowns: Dictionary = {}
var grenade_cooldowns: Dictionary = {}
var build_cooldowns: Dictionary = {}
var ui_status := "Offline — tap HOST or JOIN"
var ui_font: Font
var screen_size := Vector2(960, 540)
var last_save_time := 0.0
var animation_clock := 0.0
var sfx_players: Dictionary = {}
var sfx_last_played: Dictionary = {}
var music_player: AudioStreamPlayer

func _ready() -> void:
    randomize()
    # Landscape is configured in project.godot and export_presets.cfg before startup.
    # Do not force runtime rotation here: Android can otherwise start with a stale portrait viewport.
    screen_mode = "home"
    world_seed = randi()
    ui_font = ThemeDB.fallback_font
    _setup_sfx()
    _setup_music()
    var control_settings := ConfigFile.new()
    if control_settings.load("user://settings.cfg") == OK:
        aim_marker_enabled = bool(control_settings.get_value("controls", "aim_marker_enabled", true))
    if ui_font == null:
        push_warning("Pixel Zombie LAN: theme fallback font was not available at startup.")
    # Prefer detailed raster assets. Draw functions retain a visible fallback if a texture is missing.
    sprite_atlas = load("res://assets/sprite_atlas_player_clean.png") as Texture2D
    if sprite_atlas == null:
        sprite_atlas = load("res://assets/sprite_atlas.png") as Texture2D
    if sprite_atlas == null:
        sprite_atlas = load("res://assets/sprite_atlas.svg") as Texture2D
    background_texture = load("res://assets/arena_bg.jpg") as Texture2D
    if background_texture == null:
        background_texture = load("res://assets/arena_bg.svg") as Texture2D
    grenade_texture = load("res://assets/grenade_detail.svg") as Texture2D
    # Runtime uses the pre-rendered transparent PNG for predictable Android import; the SVG stays as editable source.
    grenade_explosion_texture = load("res://assets/grenade_explosion_asset.png") as Texture2D
    if grenade_explosion_texture == null:
        grenade_explosion_texture = load("res://assets/grenade_explosion_asset.svg") as Texture2D
    barricade_texture = load("res://assets/barricade_detail.png") as Texture2D
    if barricade_texture == null:
        barricade_texture = load("res://assets/barricade_detail.svg") as Texture2D
    airdrop_crate_texture = load("res://assets/airdrop_crate_generated.png") as Texture2D
    if airdrop_crate_texture == null:
        airdrop_crate_texture = load("res://assets/airdrop_crate_detail.svg") as Texture2D
    parachute_texture = load("res://assets/airdrop_parachute_generated.png") as Texture2D
    if parachute_texture == null:
        parachute_texture = load("res://assets/parachute_detail.svg") as Texture2D
    airdrop_landing_texture = load("res://assets/airdrop_landing_dust_generated.png") as Texture2D
    boss_texture = load("res://assets/boss_brute.png") as Texture2D
    boss_attack_textures.clear()
    for attack_path in [
        "res://assets/boss_attack_slash_sheet.png",
        "res://assets/boss_attack_slam_sheet.png",
        "res://assets/boss_attack_lunge_sheet.png"
    ]:
        boss_attack_textures.append(load(attack_path) as Texture2D)
    weapon_icon_textures.clear()
    weapon_icon_textures[WEAPON_SMG] = load("res://assets/weapons/smg.png") as Texture2D
    weapon_icon_textures[WEAPON_SHOTGUN] = load("res://assets/weapons/shotgun.png") as Texture2D
    weapon_icon_textures[WEAPON_RIFLE] = load("res://assets/weapons/rifle.png") as Texture2D
    weapon_icon_textures[WEAPON_SNIPER] = load("res://assets/weapons/sniper.png") as Texture2D
    weapon_icon_textures[WEAPON_ROCKET] = load("res://assets/weapons/rocket.png") as Texture2D
    if sprite_atlas == null:
        push_warning("Pixel Zombie LAN: neither PNG nor SVG sprite atlas loaded; simple fallback characters will be drawn.")
    if background_texture == null:
        push_warning("Pixel Zombie LAN: neither JPG nor SVG background loaded; procedural fallback background will be drawn.")
    screen_size = get_viewport_rect().size
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
    screen_size = get_viewport_rect().size
    animation_clock += delta
    _sync_music_state()

    if screen_mode == "game":
        if is_host:
            input_vectors[local_player_id] = joystick_vector
            _host_simulate(minf(delta, 0.1))
            snapshot_timer += delta
            if snapshot_timer >= SNAPSHOT_INTERVAL - delta * 0.5:
                snapshot_timer -= SNAPSHOT_INTERVAL
                if snapshot_timer > SNAPSHOT_INTERVAL or snapshot_timer < -SNAPSHOT_INTERVAL:
                    snapshot_timer = 0.0
                _broadcast_world()
        elif _is_connected_client():
            _client_network_tick(delta)

        _process_action_requests(delta)
    elif (screen_mode == "pause" or screen_mode == "game_over") and _is_connected_client():
        _client_update_render(delta)
        _tick_client_effects(delta)
    if _is_connected_client():
        _update_net_stats(delta)
    _update_player_death_visuals(delta)
    queue_redraw()

func _setup_sfx() -> void:
    # Literal resource paths are intentional: Godot's exporter and CI can verify every sound.
    var clips := [
        {"id": "shot", "path": "res://assets/audio/shot.wav"},
        {"id": "hit", "path": "res://assets/audio/hit.wav"},
        {"id": "attack", "path": "res://assets/audio/attack.wav"},
        {"id": "death", "path": "res://assets/audio/death.wav"},
        {"id": "heal", "path": "res://assets/audio/heal.wav"},
        {"id": "wave_clear", "path": "res://assets/audio/wave_clear.wav"},
        {"id": "wave_start", "path": "res://assets/audio/wave_start.wav"},
        {"id": "game_over", "path": "res://assets/audio/game_over.wav"},
        {"id": "grenade_throw", "path": "res://assets/audio/grenade_throw.wav"},
        {"id": "explosion", "path": "res://assets/audio/explosion.wav"},
        {"id": "airdrop", "path": "res://assets/audio/airdrop.wav"},
        {"id": "wall_build", "path": "res://assets/audio/wall_build.wav"},
        {"id": "wall_break", "path": "res://assets/audio/wall_break.wav"},
        {"id": "pickup", "path": "res://assets/audio/pickup.wav"},
        {"id": "boss_roar", "path": "res://assets/audio/boss_roar.wav"},
        {"id": "boss_attack", "path": "res://assets/audio/boss_attack.wav"},
        {"id": "airdrop_incoming", "path": "res://assets/audio/airdrop_incoming.wav"}
    ]
    for clip_data in clips:
        var clip: String = str(clip_data.get("id", ""))
        var stream := load(str(clip_data.get("path", ""))) as AudioStream
        if stream == null:
            push_warning("Pixel Zombie LAN: optional sound '%s' could not be loaded." % clip)
            continue
        var player := AudioStreamPlayer.new()
        player.name = "SFX_" + clip
        player.stream = stream
        player.volume_db = _sfx_volume_db(clip)
        add_child(player)
        sfx_players[clip] = player

func _setup_music() -> void:
    # Prefer the atmospheric loop supplied for v0.4.20. Keep the existing WAV as a safe fallback
    # so a failed MP3 import never leaves gameplay silent.
    var music_stream: AudioStream = null
    var mp3_stream := load("res://assets/audio/gameplay_tension_ambience.mp3") as AudioStreamMP3
    if mp3_stream != null:
        mp3_stream.loop = true
        music_stream = mp3_stream
    else:
        var fallback_stream := load("res://assets/audio/combat_ambience_loop.wav") as AudioStreamWAV
        if fallback_stream != null:
            fallback_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
            music_stream = fallback_stream
    if music_stream == null:
        push_warning("Pixel Zombie LAN: gameplay music could not be loaded; continuing without music.")
        return
    music_player = AudioStreamPlayer.new()
    music_player.name = "GameplayMusic"
    music_player.stream = music_stream
    # Keep the atmospheric drone underneath gunfire, hits, and boss cues.
    music_player.volume_db = -20.0
    add_child(music_player)

func _sync_music_state() -> void:
    if music_player == null or music_player.stream == null:
        return
    if screen_mode == "game":
        music_player.stream_paused = false
        if not music_player.playing:
            music_player.play()
    elif screen_mode == "pause":
        if music_player.playing:
            music_player.stream_paused = true
    else:
        music_player.stream_paused = false
        if music_player.playing:
            music_player.stop()

func _sfx_volume_db(clip: String) -> float:
    match clip:
        "shot":
            return -11.0
        "hit":
            return -7.0
        "attack":
            return -8.0
        "death":
            return -6.0
        "heal":
            return -8.0
        "wave_clear":
            return -7.0
        "wave_start":
            return -9.0
        "game_over":
            return -5.0
        "explosion":
            return -4.0
        "grenade_throw":
            return -8.0
        "airdrop":
            return -7.0
        "wall_build":
            return -7.0
        "wall_break":
            return -5.0
        "pickup":
            return -8.0
        "boss_roar":
            return -4.0
        "boss_attack":
            return -5.0
        "airdrop_incoming":
            return -10.0
        _:
            return -8.0

func _play_sfx(clip: String) -> void:
    if not sfx_players.has(clip):
        return
    var player: AudioStreamPlayer = sfx_players[clip]
    if player == null or player.stream == null:
        return
    var now := Time.get_ticks_msec()
    var min_gap := 55 if clip == "shot" else (75 if clip == "hit" else (170 if clip == "attack" else (4200 if clip == "boss_roar" else 0)))
    if min_gap > 0 and now - int(sfx_last_played.get(clip, 0)) < min_gap:
        return
    sfx_last_played[clip] = now
    player.stop()
    player.play()

func _emit_sfx(clip: String, skip_peer: int = 0) -> void:
    _play_sfx(clip)
    # Offline/headless tests can instantiate the scene before a MultiplayerAPI is bound.
    # Never dereference Node.multiplayer until its API and peer have both been verified.
    if not is_host or is_offline or not is_inside_tree():
        return
    var peer_api: MultiplayerAPI = get_multiplayer()
    if peer_api == null or peer_api.multiplayer_peer == null:
        return
    var stamp := Time.get_ticks_msec() & 0xFFFFFFFF
    for peer_id in peer_api.get_peers():
        if int(peer_id) == skip_peer:
            continue # the shooter already played its own shot locally
        rpc_id(int(peer_id), "receive_sfx_event", clip, stamp)

@rpc("authority", "call_remote", "unreliable")
func receive_sfx_event(clip: String, host_ms: int) -> void:
    if not clock_ready:
        _play_sfx(clip)
        return
    # Play on the interpolated render timeline so sound lines up with what is on screen.
    pending_sfx.append({"clip": clip, "t": float(host_ms) / 1000.0})
    if pending_sfx.size() > 48:
        pending_sfx.pop_front()

func _is_connected_client() -> bool:
    if not is_inside_tree():
        return false
    var peer_api: MultiplayerAPI = get_multiplayer()
    return peer_api != null and peer_api.multiplayer_peer != null and not is_host and peer_api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _arena_top() -> float:
    return screen_size.y * ARENA_TOP_RATIO

func _arena_bottom() -> float:
    return screen_size.y * ARENA_BOTTOM_RATIO

func _control_scale() -> float:
    return clampf(screen_size.y / 540.0, 0.88, 1.12)

func _joystick_radius() -> float:
    return 48.0 * _control_scale()

func _request_fire_once() -> void:
    if is_host:
        _host_fire(local_player_id)
    elif _is_connected_client():
        if _predict_local_fire():
            rpc_id(1, "request_fire")
    else:
        ui_status = "Tap HOST to start a survival world"

func _current_fire_interval_seconds() -> float:
    var p: Dictionary = players.get(local_player_id, {})
    var profile := _weapon_profile(_active_weapon_id(p))
    return maxf(0.07, float(profile.get("interval_ms", FIRE_COOLDOWN_MS)) / 1000.0)

func _process_action_requests(delta: float) -> void:
    if fire_requested:
        fire_requested = false
        _request_fire_once()
        fire_repeat_timer = _current_fire_interval_seconds()
    elif fire_held:
        fire_repeat_timer -= delta
        if fire_repeat_timer <= 0.0:
            _request_fire_once()
            fire_repeat_timer = _current_fire_interval_seconds()
    else:
        fire_repeat_timer = 0.0

    if heal_requested:
        heal_requested = false
        if is_host:
            _host_heal(local_player_id)
        elif _is_connected_client():
            rpc_id(1, "request_heal")
        else:
            ui_status = "Healing is available during a world session"

    if grenade_requested:
        grenade_requested = false
        var safe_target_x_ratio: float = clampf(grenade_aim_target_position.x / maxf(1.0, screen_size.x), 0.0, 1.0)
        var safe_target_y_ratio: float = clampf(grenade_aim_target_position.y / maxf(1.0, screen_size.y), 0.0, 1.0)
        grenade_aim_active = false
        grenade_aim_touch_id = -1
        if is_host:
            _host_throw_grenade(local_player_id, safe_target_x_ratio, safe_target_y_ratio)
        elif _is_connected_client():
            rpc_id(1, "request_grenade", safe_target_x_ratio, safe_target_y_ratio)
        else:
            ui_status = "Grenades are available during a world session"

    if build_requested:
        build_requested = false
        var x_ratio: float = clampf(wall_preview_position.x / maxf(1.0, screen_size.x), 0.0, 1.0)
        var y_ratio: float = clampf(wall_preview_position.y / maxf(1.0, screen_size.y), 0.0, 1.0)
        wall_place_active = false
        wall_place_touch_id = -1
        if is_host:
            _host_build_wall(local_player_id, x_ratio, y_ratio)
        elif _is_connected_client():
            rpc_id(1, "request_build_wall", x_ratio, y_ratio)
        else:
            ui_status = "Barricades are available during a world session"

    if turret_requested:
        turret_requested = false
        var turret_x_ratio: float = clampf(turret_preview_position.x / maxf(1.0, screen_size.x), 0.0, 1.0)
        var turret_y_ratio: float = clampf(turret_preview_position.y / maxf(1.0, screen_size.y), 0.0, 1.0)
        turret_place_active = false
        turret_place_touch_id = -1
        if is_host:
            _host_build_turret(local_player_id, turret_x_ratio, turret_y_ratio)
        elif _is_connected_client():
            rpc_id(1, "request_build_turret", turret_x_ratio, turret_y_ratio)
        else:
            ui_status = "Auto turrets are available during a world session"

func _host_simulate(delta: float) -> void:
    world_time += delta

    # Host owns movement state. The host's own survivor follows its joystick; remote survivors are
    # moved by their sequence-numbered command stream (see submit_input), never by a claimed position.
    var sim_now_ms := Time.get_ticks_msec()
    for id_variant in players.keys():
        var id := int(id_variant)
        var p: Dictionary = players[id]
        var alive := float(p.get("hp", 0.0)) > 0.0
        if id == local_player_id:
            var movement: Vector2 = input_vectors.get(id, Vector2.ZERO).limit_length(1.0)
            if alive:
                p["x"] = clampf(float(p.get("x", screen_size.x * 0.5)) + movement.x * PLAYER_SPEED * delta, 30.0, maxf(31.0, screen_size.x - 30.0))
                p["y"] = clampf(float(p.get("y", screen_size.y * 0.68)) + movement.y * PLAYER_SPEED * delta, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
                # Side-view shooter: keep left/right facing for perfectly horizontal shots.
                if absf(movement.x) > 0.14:
                    p["face_x"] = -1.0 if movement.x < 0.0 else 1.0
            p["walking"] = alive and movement.length() > 0.12
        else:
            cmd_budget[id] = minf(COMMAND_BUDGET_MAX, float(cmd_budget.get(id, COMMAND_BUDGET_START)) + delta * COMMAND_BUDGET_RATE)
            if not alive or sim_now_ms - int(cmd_last_ms.get(id, sim_now_ms)) > COMMAND_STALE_MS:
                p["walking"] = false
        p["shoot_timer"] = maxf(0.0, float(p.get("shoot_timer", 0.0)) - delta)
        p["hurt_timer"] = maxf(0.0, float(p.get("hurt_timer", 0.0)) - delta)
        var reload_before := float(p.get("reload_timer", 0.0))
        var reload_after := maxf(0.0, reload_before - delta)
        p["reload_timer"] = reload_after
        if reload_before > 0.0 and reload_after <= 0.0:
            _finish_weapon_reload(p)
        players[id] = p
    _update_host_view()

    for effect_index in range(combat_effects.size() - 1, -1, -1):
        var active_effect: Dictionary = combat_effects[effect_index]
        active_effect["ttl"] = float(active_effect.get("ttl", 0.0)) - delta
        if float(active_effect["ttl"]) <= 0.0:
            combat_effects.remove_at(effect_index)
        else:
            combat_effects[effect_index] = active_effect

    # Every wave has its own 90s (then progressively shorter) clock. Overtime keeps the wave alive
    # and visibly raises pressure instead of silently skipping enemies when the clock expires.
    if wave_break_timer > 0.0:
        wave_break_timer = maxf(0.0, wave_break_timer - delta)
        if wave_break_timer <= 0.0:
            wave_number += 1
            wave_total = _zombie_count_for_wave(wave_number)
            wave_spawned = 0
            wave_kills = 0
            wave_spawn_timer = 1.0
            wave_time_remaining = _wave_duration_for(wave_number)
            wave_timed_out = false
            if wave_number % 10 == 0:
                ui_status = "BOSS WAVE %d — THE BRUTE IS COMING!" % wave_number
            else:
                ui_status = "Wave %d incoming — %d infected detected" % [wave_number, wave_total]
            _emit_sfx("wave_start")
    else:
        if not wave_timed_out:
            wave_time_remaining = maxf(0.0, wave_time_remaining - delta)
            if wave_time_remaining <= 0.0:
                wave_timed_out = true
                ui_status = "Wave %d overtime — clear the remaining horde!" % wave_number
                _emit_sfx("wave_start")
        wave_spawn_timer = maxf(0.0, wave_spawn_timer - delta)
        var alive_limit := mini(14, 6 + wave_number)
        if wave_spawned < wave_total and wave_spawn_timer <= 0.0 and zombies.size() < alive_limit:
            _spawn_wave_zombie()
            wave_spawned += 1
            wave_spawn_timer = maxf(0.28, 0.80 - float(mini(wave_number, 14)) * 0.025)


    for zi in range(zombies.size()):
        var z: Dictionary = zombies[zi]
        var zombie_pos := Vector2(float(z.get("x", 480.0)), float(z.get("y", 270.0)))
        var target_id := -1
        var nearest_distance := INF
        var attack_timer := maxf(0.0, float(z.get("attack_timer", 0.0)) - delta)
        var attack_cooldown := maxf(0.0, float(z.get("attack_cooldown", 0.0)) - delta)
        var attack_type := clampi(int(z.get("attack_type", BOSS_ATTACK_SLASH)), BOSS_ATTACK_SLASH, BOSS_ATTACK_LUNGE)
        var attack_hit_applied := bool(z.get("attack_hit_applied", false))
        z["hit_timer"] = maxf(0.0, float(z.get("hit_timer", 0.0)) - delta)
        z["attacking"] = false
        z["walking"] = false

        for id_variant in players.keys():
            var id := int(id_variant)
            var p: Dictionary = players[id]
            if float(p.get("hp", 0.0)) <= 0.0:
                continue
            var distance := zombie_pos.distance_to(Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))))
            if distance < nearest_distance:
                nearest_distance = distance
                target_id = id

        var turret_target_index := -1
        var nearest_turret_distance: float = INF
        for turret_index in range(turrets.size()):
            var nearby_turret: Dictionary = turrets[turret_index]
            var nearby_turret_pos := Vector2(float(nearby_turret.get("x", 0.0)), float(nearby_turret.get("y", 0.0)))
            var turret_distance := zombie_pos.distance_to(nearby_turret_pos)
            if turret_distance <= TURRET_AGGRO_RADIUS and turret_distance < nearest_turret_distance:
                nearest_turret_distance = turret_distance
                turret_target_index = turret_index

        # Turrets are destructible defenses. An infected turns on the nearest turret only when
        # it is a more immediate obstacle than a survivor, so the squad can still kite enemies.
        if turret_target_index >= 0 and (target_id == -1 or nearest_turret_distance < nearest_distance):
            var turret_target: Dictionary = turrets[turret_target_index]
            var turret_pos := Vector2(float(turret_target.get("x", 0.0)), float(turret_target.get("y", 0.0)))
            var turret_direction := (turret_pos - zombie_pos).normalized()
            var turret_kind := clampi(int(z.get("kind", 0)), 0, ZOMBIE_KIND_BOSS)
            var turret_boss := turret_kind == ZOMBIE_KIND_BOSS
            var turret_speed_scale: float = 0.54 if turret_boss else (0.68 if turret_kind == 2 else (1.25 if turret_kind == 3 else 1.0))
            if wave_timed_out:
                turret_speed_scale *= 1.18
            z["face_x"] = -1.0 if turret_direction.x < 0.0 else 1.0
            if nearest_turret_distance > TURRET_ATTACK_RANGE:
                z["walking"] = true
                attack_timer = 0.0
                attack_hit_applied = false
                z["x"] = clampf(zombie_pos.x + turret_direction.x * ZOMBIE_SPEED * turret_speed_scale * delta, 30.0, maxf(31.0, screen_size.x - 30.0))
                z["y"] = clampf(zombie_pos.y + turret_direction.y * ZOMBIE_SPEED * turret_speed_scale * delta, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
            elif turret_boss:
                z["walking"] = false
                if attack_timer <= 0.0 and attack_cooldown <= 0.0:
                    attack_type = _choose_boss_attack(nearest_turret_distance, false)
                    attack_timer = _boss_attack_duration(attack_type)
                    attack_cooldown = _boss_attack_cooldown(attack_type)
                    attack_hit_applied = false
                    z["attack_type"] = attack_type
                    _emit_sfx("boss_roar")
                z["attacking"] = attack_timer > 0.0
                if attack_timer > 0.0:
                    var turret_attack_progress := clampf(1.0 - attack_timer / _boss_attack_duration(attack_type), 0.0, 1.0)
                    if not attack_hit_applied and turret_attack_progress >= _boss_attack_hit_progress(attack_type):
                        var brute_damage: float = 38.0 if attack_type == BOSS_ATTACK_SLAM else 27.0
                        turret_target["hp"] = float(turret_target.get("hp", TURRET_MAX_HP)) - brute_damage
                        _add_combat_effect(9 if attack_type == BOSS_ATTACK_SLAM else 5, turret_pos + Vector2(0.0, 1.0), turret_pos + Vector2(0.0, 1.0), 0.48)
                        attack_hit_applied = true
                        _emit_sfx("boss_attack")
                        if float(turret_target.get("hp", 0.0)) <= 0.0:
                            _add_combat_effect(9, turret_pos, turret_pos, 0.65)
                            turrets.remove_at(turret_target_index)
                            _emit_sfx("wall_break")
                            ui_status = "AUTO TURRET DESTROYED BY BRUTE"
                        else:
                            turrets[turret_target_index] = turret_target
            else:
                z["walking"] = false
                z["attacking"] = true
                attack_timer = 0.36
                if attack_cooldown <= 0.0:
                    var turret_damage: float = 14.0 if turret_kind == 2 else (6.0 if turret_kind == 3 else 8.0)
                    turret_target["hp"] = float(turret_target.get("hp", TURRET_MAX_HP)) - turret_damage
                    attack_cooldown = 0.92 if turret_kind == 2 else (0.56 if turret_kind == 3 else 0.74)
                    _add_combat_effect(5, zombie_pos + Vector2(float(z.get("face_x", 1.0)) * 14.0, -3.0), turret_pos, 0.22)
                    _emit_sfx("attack")
                    if float(turret_target.get("hp", 0.0)) <= 0.0:
                        _add_combat_effect(9, turret_pos, turret_pos, 0.55)
                        turrets.remove_at(turret_target_index)
                        _emit_sfx("wall_break")
                        ui_status = "AUTO TURRET DESTROYED BY HORDE"
                    else:
                        turrets[turret_target_index] = turret_target
            z["attack_timer"] = attack_timer
            z["attack_cooldown"] = attack_cooldown
            z["attack_type"] = attack_type
            z["attack_hit_applied"] = attack_hit_applied
            zombies[zi] = z
            continue

        if target_id != -1:
            var target: Dictionary = players[target_id]
            var target_pos := Vector2(float(target.get("x", 0.0)), float(target.get("y", 0.0)))
            var blocking_wall_index := _find_blocking_barricade(zombie_pos, target_pos)
            var zombie_kind := clampi(int(z.get("kind", 0)), 0, ZOMBIE_MAX_HP.size() - 1)
            var is_boss := zombie_kind == ZOMBIE_KIND_BOSS
            var speed_scale := 0.54 if is_boss else (0.68 if zombie_kind == 2 else (1.25 if zombie_kind == 3 else 1.0))
            if wave_timed_out:
                speed_scale *= 1.18

            if blocking_wall_index >= 0:
                var wall: Dictionary = barricades[blocking_wall_index]
                var wall_pos := Vector2(float(wall.get("x", zombie_pos.x)), float(wall.get("y", zombie_pos.y)))
                var dx_to_wall := wall_pos.x - zombie_pos.x
                z["face_x"] = -1.0 if dx_to_wall < 0.0 else 1.0
                if absf(dx_to_wall) > WALL_ATTACK_RANGE:
                    z["walking"] = true
                    attack_timer = 0.0
                    if is_boss:
                        attack_hit_applied = false
                    var wall_direction := (wall_pos - zombie_pos).normalized()
                    var proposed_x := float(z.get("x", zombie_pos.x)) + wall_direction.x * ZOMBIE_SPEED * speed_scale * delta
                    if dx_to_wall > 0.0:
                        proposed_x = minf(proposed_x, wall_pos.x - WALL_ATTACK_RANGE * 0.82)
                    else:
                        proposed_x = maxf(proposed_x, wall_pos.x + WALL_ATTACK_RANGE * 0.82)
                    z["x"] = clampf(proposed_x, 30.0, maxf(31.0, screen_size.x - 30.0))
                    z["y"] = clampf(float(z.get("y", zombie_pos.y)) + wall_direction.y * ZOMBIE_SPEED * speed_scale * delta, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
                elif is_boss:
                    z["walking"] = false
                    if attack_timer <= 0.0 and attack_cooldown <= 0.0:
                        attack_type = _choose_boss_attack(0.0, true)
                        attack_timer = _boss_attack_duration(attack_type)
                        attack_cooldown = _boss_attack_cooldown(attack_type)
                        attack_hit_applied = false
                        z["attack_type"] = attack_type
                        _emit_sfx("boss_roar")
                    z["attacking"] = attack_timer > 0.0
                    if attack_timer > 0.0:
                        var wall_attack_progress := clampf(1.0 - attack_timer / _boss_attack_duration(attack_type), 0.0, 1.0)
                        if not attack_hit_applied and wall_attack_progress >= _boss_attack_hit_progress(attack_type):
                            var boss_wall_damage := 34.0 if attack_type == BOSS_ATTACK_SLAM else 25.0
                            wall["hp"] = float(wall.get("hp", 80.0)) - boss_wall_damage
                            var wall_hit_pos := wall_pos + Vector2(0.0, 8.0)
                            if attack_type == BOSS_ATTACK_SLAM:
                                _add_combat_effect(9, wall_hit_pos + Vector2(0.0, 15.0), wall_hit_pos + Vector2(0.0, 15.0), 0.58)
                            else:
                                _add_combat_effect(5, zombie_pos + Vector2(float(z.get("face_x", 1.0)) * 19.0, -5.0), wall_hit_pos, 0.26)
                            attack_hit_applied = true
                            _emit_sfx("boss_attack")
                            if float(wall.get("hp", 0.0)) <= 0.0:
                                barricades.remove_at(blocking_wall_index)
                                _emit_sfx("wall_break")
                                ui_status = "BARRICADE DESTROYED — rebuild from a supply drop"
                            else:
                                barricades[blocking_wall_index] = wall
                else:
                    # Keep the familiar short attack cadence for ordinary infected.
                    z["walking"] = false
                    z["attacking"] = true
                    attack_timer = 0.38
                    if attack_cooldown <= 0.0:
                        var wall_damage := 13.0 if zombie_kind == 2 else (6.0 if zombie_kind == 3 else (8.0 if zombie_kind == 1 else 8.0))
                        wall["hp"] = float(wall.get("hp", 80.0)) - wall_damage
                        attack_cooldown = 0.92 if zombie_kind == 2 else (0.56 if zombie_kind == 3 else 0.74)
                        _add_combat_effect(5, zombie_pos + Vector2(float(z.get("face_x", 1.0)) * 14.0, -3.0), wall_pos, 0.20)
                        _emit_sfx("attack")
                        if float(wall.get("hp", 0.0)) <= 0.0:
                            barricades.remove_at(blocking_wall_index)
                            _emit_sfx("wall_break")
                            ui_status = "BARRICADE DESTROYED — rebuild from a supply drop"
                        else:
                            barricades[blocking_wall_index] = wall
            else:
                var delta_to_target := target_pos - zombie_pos
                var direction := delta_to_target.normalized()
                if absf(direction.x) > 0.08:
                    z["face_x"] = -1.0 if direction.x < 0.0 else 1.0

                var zombie_attack_range := 112.0 if is_boss else ZOMBIE_ATTACK_RANGE
                if nearest_distance > zombie_attack_range:
                    z["walking"] = true
                    attack_timer = 0.0
                    if is_boss:
                        attack_hit_applied = false
                    z["x"] = clampf(float(z.get("x", zombie_pos.x)) + direction.x * ZOMBIE_SPEED * speed_scale * delta, 30.0, maxf(31.0, screen_size.x - 30.0))
                    z["y"] = clampf(float(z.get("y", zombie_pos.y)) + direction.y * ZOMBIE_SPEED * speed_scale * delta, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
                elif is_boss:
                    z["walking"] = false
                    if attack_timer <= 0.0 and attack_cooldown <= 0.0:
                        attack_type = _choose_boss_attack(nearest_distance, false)
                        attack_timer = _boss_attack_duration(attack_type)
                        attack_cooldown = _boss_attack_cooldown(attack_type)
                        attack_hit_applied = false
                        z["attack_type"] = attack_type
                        _emit_sfx("boss_roar")
                    z["attacking"] = attack_timer > 0.0
                    if attack_timer > 0.0:
                        var attack_progress := clampf(1.0 - attack_timer / _boss_attack_duration(attack_type), 0.0, 1.0)
                        if attack_type == BOSS_ATTACK_LUNGE and attack_progress < _boss_attack_hit_progress(attack_type):
                            var lunge_player: Dictionary = players.get(target_id, {})
                            var lunge_target_pos := Vector2(float(lunge_player.get("x", target_pos.x)), float(lunge_player.get("y", target_pos.y)))
                            var current_boss_pos := Vector2(float(z.get("x", zombie_pos.x)), float(z.get("y", zombie_pos.y)))
                            var lunge_vector := lunge_target_pos - current_boss_pos
                            var lunge_distance := lunge_vector.length()
                            var lunge_step := minf(BOSS_LUNGE_SPEED * delta, maxf(0.0, lunge_distance - 34.0))
                            if lunge_distance > 0.001 and lunge_step > 0.0:
                                var lunge_move := lunge_vector / lunge_distance * lunge_step
                                z["x"] = clampf(current_boss_pos.x + lunge_move.x, 30.0, maxf(31.0, screen_size.x - 30.0))
                                z["y"] = clampf(current_boss_pos.y + lunge_move.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
                        if not attack_hit_applied and attack_progress >= _boss_attack_hit_progress(attack_type):
                            attack_hit_applied = true
                            var boss_impact_pos := Vector2(float(z.get("x", zombie_pos.x)), float(z.get("y", zombie_pos.y)))
                            if attack_type == BOSS_ATTACK_SLAM:
                                _add_combat_effect(9, boss_impact_pos + Vector2(0.0, 28.0), boss_impact_pos + Vector2(0.0, 28.0), 0.62)
                                for player_variant in players.keys():
                                    var slam_id := int(player_variant)
                                    var slam_target: Dictionary = players[slam_id]
                                    if float(slam_target.get("hp", 0.0)) <= 0.0:
                                        continue
                                    var slam_target_pos := Vector2(float(slam_target.get("x", 0.0)), float(slam_target.get("y", 0.0)))
                                    if boss_impact_pos.distance_to(slam_target_pos) <= BOSS_SLAM_RADIUS:
                                        slam_target["hp"] = maxf(0.0, float(slam_target.get("hp", 0.0)) - 24.0)
                                        slam_target["hurt_timer"] = 0.42
                                        players[slam_id] = slam_target
                                        _add_combat_effect(2, slam_target_pos + Vector2(0.0, -7.0), slam_target_pos + Vector2(0.0, -7.0), 0.24)
                                _emit_sfx("boss_attack")
                            else:
                                var impact_target: Dictionary = players.get(target_id, {})
                                if not impact_target.is_empty() and float(impact_target.get("hp", 0.0)) > 0.0:
                                    var impact_target_pos := Vector2(float(impact_target.get("x", target_pos.x)), float(impact_target.get("y", target_pos.y)))
                                    var impact_distance := boss_impact_pos.distance_to(impact_target_pos)
                                    var impact_reach := BOSS_LUNGE_REACH if attack_type == BOSS_ATTACK_LUNGE else BOSS_SLASH_REACH
                                    if impact_distance <= impact_reach:
                                        var boss_damage := 22.0 if attack_type == BOSS_ATTACK_LUNGE else 18.0
                                        impact_target["hp"] = maxf(0.0, float(impact_target.get("hp", 0.0)) - boss_damage)
                                        impact_target["hurt_timer"] = 0.38
                                        players[target_id] = impact_target
                                        _add_combat_effect(5, boss_impact_pos + Vector2(float(z.get("face_x", 1.0)) * 20.0, -7.0), impact_target_pos + Vector2(0.0, -7.0), 0.27)
                                    else:
                                        var miss_dir := -1.0 if float(z.get("face_x", 1.0)) < 0.0 else 1.0
                                        _add_combat_effect(5, boss_impact_pos + Vector2(miss_dir * 18.0, -8.0), boss_impact_pos + Vector2(miss_dir * 60.0, -7.0), 0.18)
                                _emit_sfx("boss_attack")
                else:
                    z["walking"] = false
                    z["attacking"] = attack_timer > 0.0
                    if attack_cooldown <= 0.0:
                        var damage := 8.0 if zombie_kind == 2 else (4.5 if zombie_kind == 3 else (6.0 if zombie_kind == 1 else 6.0))
                        var cooldown := 0.92 if zombie_kind == 2 else (0.56 if zombie_kind == 3 else 0.74)
                        target["hp"] = maxf(0.0, float(target.get("hp", 0.0)) - damage)
                        target["hurt_timer"] = 0.34
                        players[target_id] = target
                        attack_cooldown = cooldown
                        attack_timer = 0.38
                        z["attacking"] = true
                        _add_combat_effect(5, zombie_pos + Vector2(float(z.get("face_x", 1.0)) * 14.0, -3.0), target_pos + Vector2(0.0, -7.0), 0.20)
                        _emit_sfx("attack")

        z["attack_timer"] = attack_timer
        z["attack_cooldown"] = attack_cooldown
        z["attack_type"] = attack_type
        z["attack_hit_applied"] = attack_hit_applied
        zombies[zi] = z

    _update_turrets(delta)
    _update_grenades(delta)
    _update_projectiles(delta)
    _update_airdrops(delta)

    if _all_players_eliminated():
        if not game_over:
            game_over = true
            screen_mode = "game_over"
            fire_held = false
            fire_requested = false
            grenade_requested = false
            build_requested = false
            joystick_active = false
            joystick_vector = Vector2.ZERO
            ui_status = "SQUAD ELIMINATED — restart or return to safehouse"
            _emit_sfx("game_over")
            if not is_offline and multiplayer.multiplayer_peer != null:
                rpc("receive_game_over_snapshot", _encode_snapshot())
            _broadcast_world()
        return

    if wave_break_timer <= 0.0 and wave_spawned >= wave_total and zombies.is_empty():
        wave_break_timer = 4.0
        wave_time_remaining = 0.0
        wave_timed_out = false
        ui_status = "WAVE %d CLEAR — next wave in 4 seconds" % wave_number
        _emit_sfx("wave_clear")

func _wave_duration_for(number: int) -> float:
    return maxf(55.0, WAVE_BASE_DURATION - float(maxi(0, number - 1)) * 3.0)

func _zombie_count_for_wave(number: int) -> int:
    # Start at 25, add five infected every wave, and cap to the byte-sized LAN counter.
    return clampi(WAVE_ZOMBIE_COUNT + maxi(0, number - 1) * WAVE_ZOMBIES_PER_LEVEL, WAVE_ZOMBIE_COUNT, 255)

func _boss_hp_for_wave(number: int) -> float:
    var boss_tier := maxi(1, floori(float(maxi(1, number)) / 10.0))
    return BOSS_BASE_HP + float(boss_tier - 1) * BOSS_HP_PER_TIER

func _boss_attack_duration(attack_type: int) -> float:
    match clampi(attack_type, BOSS_ATTACK_SLASH, BOSS_ATTACK_LUNGE):
        BOSS_ATTACK_SLAM:
            return 1.10
        BOSS_ATTACK_LUNGE:
            return 0.88
        _:
            return 0.82

func _boss_attack_cooldown(attack_type: int) -> float:
    match clampi(attack_type, BOSS_ATTACK_SLASH, BOSS_ATTACK_LUNGE):
        BOSS_ATTACK_SLAM:
            return 1.72
        BOSS_ATTACK_LUNGE:
            return 1.48
        _:
            return 1.34

func _boss_attack_hit_progress(attack_type: int) -> float:
    match clampi(attack_type, BOSS_ATTACK_SLASH, BOSS_ATTACK_LUNGE):
        BOSS_ATTACK_SLAM:
            return 0.68
        BOSS_ATTACK_LUNGE:
            return 0.60
        _:
            return 0.57

func _choose_boss_attack(distance: float, against_wall: bool) -> int:
    if against_wall:
        return BOSS_ATTACK_SLAM if randi_range(0, 99) < 38 else BOSS_ATTACK_SLASH
    # Far targets trigger the readable, telegraphed lunge rather than a short-range swipe.
    if distance > 76.0:
        return BOSS_ATTACK_LUNGE
    var roll := randi_range(0, 99)
    if roll < 52:
        return BOSS_ATTACK_SLASH
    if roll < 78:
        return BOSS_ATTACK_SLAM
    return BOSS_ATTACK_LUNGE

func _boss_attack_frame(attack_type: int, progress: float) -> int:
    var t := clampf(progress, 0.0, 1.0)
    match clampi(attack_type, BOSS_ATTACK_SLASH, BOSS_ATTACK_LUNGE):
        BOSS_ATTACK_SLAM:
            if t < 0.22: return 0
            if t < 0.42: return 1
            if t < 0.62: return 2
            if t < 0.82: return 3
            return 4
        BOSS_ATTACK_LUNGE:
            if t < 0.20: return 0
            if t < 0.40: return 1
            if t < 0.61: return 2
            if t < 0.82: return 3
            return 4
        _:
            if t < 0.20: return 0
            if t < 0.42: return 1
            if t < 0.64: return 2
            if t < 0.84: return 3
            return 4

func _zombie_max_hp_for(kind: int, for_wave: int = -1) -> float:
    if kind == ZOMBIE_KIND_BOSS:
        return _boss_hp_for_wave(wave_number if for_wave < 1 else for_wave)
    return float(ZOMBIE_MAX_HP[clampi(kind, 0, ZOMBIE_KIND_BOSS - 1)])

func _all_players_eliminated() -> bool:
    if players.is_empty():
        return false
    for id_variant in players.keys():
        if float(players[id_variant].get("hp", 0.0)) > 0.0:
            return false
    return true

func _spawn_wave_zombie() -> void:
    var zombie_kind := 0
    if wave_number % 10 == 0 and wave_spawned == 0:
        # One oversized, durable brute is included in the wave's displayed total.
        zombie_kind = ZOMBIE_KIND_BOSS
    else:
        var kind_roll := randi_range(0, 99)
        if wave_number >= 2 and kind_roll < 10:
            zombie_kind = 2 # Heavy
        elif kind_roll < 31:
            zombie_kind = 3 # Runner
        elif kind_roll < 57:
            zombie_kind = 1 # Worker
    var zombie_hp := _zombie_max_hp_for(zombie_kind, wave_number)
    var spawn_left := randf() < 0.5
    var spawn_y := randf_range(_arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - 50.0)
    var spawn_x := 34.0 if spawn_left else screen_size.x - 34.0
    zombies.append({
        "id": randi(),
        "kind": zombie_kind,
        "x": spawn_x,
        "y": spawn_y,
        "face_x": 1.0 if spawn_left else -1.0,
        "hp": zombie_hp,
        "max_hp": zombie_hp,
        "walking": false,
        "attacking": false,
        "attack_timer": 0.0,
        "attack_cooldown": randf_range(0.12, 0.50),
        "attack_type": BOSS_ATTACK_SLASH,
        "attack_hit_applied": false,
        "hit_timer": 0.0
    })
    if zombie_kind == ZOMBIE_KIND_BOSS:
        ui_status = "BOSS ARRIVAL — BRUTE ROARS!"
        _emit_sfx("boss_roar")

func _spawn_local_player() -> void:
    var id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1
    local_player_id = id
    if not players.has(id):
        players[id] = _make_player(id)
    if not input_vectors.has(id):
        input_vectors[id] = Vector2.ZERO

func _make_player(id: int) -> Dictionary:
    var spawn := Vector2(screen_size.x * 0.5, screen_size.y * 0.70) + Vector2(randf_range(-55.0, 55.0), randf_range(-18.0, 18.0))
    return {
        "x": spawn.x,
        "y": spawn.y,
        "hp": 100.0,
        "medkits": 2,
        "ammo": -1,
        "grenades": 3,
        "wall_kits": 2,
        "turret_kits": 0,
        "active_slot": 0,
        "slot1_type": -1,
        "slot1_mag": 0,
        "slot1_reserve": 0,
        "slot2_type": -1,
        "slot2_mag": 0,
        "slot2_reserve": 0,
        "reload_timer": 0.0,
        "face_x": 1.0,
        "name": "P%d" % id,
        "walking": false,
        "shoot_timer": 0.0,
        "hurt_timer": 0.0
    }

func _player_color(id: int) -> Color:
    var colors := [Color("#75d8a0"), Color("#78b7ff"), Color("#ffc66d"), Color("#e994e8")]
    return colors[posmod(id - 1, colors.size())]

func _on_connected_to_server() -> void:
    local_player_id = multiplayer.get_unique_id()
    screen_mode = "lobby"
    ui_status = "Connected — receiving world state..."
    _tune_enet_peer(1)

func _on_connection_failed() -> void:
    _reset_network_state()
    screen_mode = "lobby"
    ui_status = "Connection failed — verify host IP and hotspot settings"

func _on_server_disconnected() -> void:
    _reset_network_state()
    screen_mode = "lobby"
    ui_status = "Host disconnected — session ended"

func _on_peer_connected(id: int) -> void:
    if not is_host:
        return
    if players.size() >= MAX_PLAYERS:
        ui_status = "World full (maximum 4 players)"
        return
    players[id] = _make_player(id)
    input_vectors[id] = Vector2.ZERO
    cmd_last_seq[id] = 0
    cmd_budget[id] = COMMAND_BUDGET_START
    cmd_last_ms.erase(id)
    host_track.erase(id)
    host_view.erase(id)
    _tune_enet_peer(id)
    rpc_id(id, "receive_initial_world", _encode_snapshot())
    if screen_mode == "game":
        rpc_id(id, "begin_game_remote")
    elif screen_mode == "game_over":
        rpc_id(id, "begin_game_over_remote")
    _broadcast_world()
    ui_status = "Player joined · %d/%d" % [players.size(), MAX_PLAYERS]

func _on_peer_disconnected(id: int) -> void:
    players.erase(id)
    input_vectors.erase(id)
    fire_cooldowns.erase(id)
    heal_cooldowns.erase(id)
    cmd_last_seq.erase(id)
    cmd_budget.erase(id)
    cmd_last_ms.erase(id)
    host_track.erase(id)
    host_view.erase(id)
    if is_host:
        _broadcast_world()
    ui_status = "Player %d disconnected · %d/%d" % [id, players.size(), MAX_PLAYERS]

# ---------------------------------------------------------------------------
# LAN networking (v0.4.9+)
#   Host -> client : compact binary snapshots, always a single datagram (<= MAX_SNAPSHOT_BYTES).
#   Client -> host : sequence-numbered movement commands (redundantly resent) for reconciliation.
#   Client view    : snapshot interpolation buffer, local prediction, local fire feedback.
# ---------------------------------------------------------------------------

func _qpos(value: float) -> int:
    return clampi(roundi(value * POS_SCALE), 0, 65535)

func _qcenti(value: float) -> int:
    return clampi(roundi(value * 100.0), 0, 255)

func _encode_snapshot() -> PackedByteArray:
    var sp := StreamPeerBuffer.new()
    var now_ms := Time.get_ticks_msec()
    snapshot_seq += 1
    var flags := 0
    if game_over:
        flags |= 1
    if wave_timed_out:
        flags |= 2
    sp.put_u8(SNAP_MAGIC)
    sp.put_u8(flags)
    sp.put_u32(snapshot_seq & 0xFFFFFFFF)
    sp.put_u32(now_ms & 0xFFFFFFFF)
    sp.put_u16(clampi(roundi(screen_size.x), 1, 65535))
    sp.put_u16(clampi(roundi(screen_size.y), 1, 65535))
    sp.put_float(world_time)
    sp.put_u16(clampi(wave_number, 0, 65535))
    sp.put_u8(clampi(wave_spawned, 0, 255))
    sp.put_u8(clampi(wave_kills, 0, 255))
    sp.put_u8(clampi(wave_total, 0, 255))
    sp.put_float(wave_break_timer)
    sp.put_float(wave_time_remaining)

    var pids: Array = players.keys()
    var pcount := mini(pids.size(), MAX_PLAYERS)
    sp.put_u8(pcount)
    for i in range(pcount):
        var pid := int(pids[i])
        var p: Dictionary = players[pid]
        var pflags := 0
        if float(p.get("face_x", 1.0)) < 0.0:
            pflags |= 1
        if bool(p.get("walking", false)):
            pflags |= 2
        sp.put_u32(pid & 0xFFFFFFFF)
        sp.put_u16(_qpos(float(p.get("x", 0.0))))
        sp.put_u16(_qpos(float(p.get("y", 0.0))))
        sp.put_u8(clampi(roundi(float(p.get("hp", 0.0)) * 2.0), 0, 255))
        sp.put_u8(pflags)
        sp.put_u8(clampi(int(p.get("medkits", 0)), 0, 255))
        sp.put_u8(clampi(int(p.get("grenades", 0)), 0, 255))
        sp.put_u8(clampi(int(p.get("wall_kits", 0)), 0, 255))
        sp.put_u8(clampi(int(p.get("turret_kits", 0)), 0, 255))
        sp.put_u8(_qcenti(float(p.get("shoot_timer", 0.0))))
        sp.put_u8(_qcenti(float(p.get("hurt_timer", 0.0))))
        sp.put_u8(clampi(int(p.get("active_slot", 0)), 0, 2))
        var slot1_type := int(p.get("slot1_type", -1))
        var slot2_type := int(p.get("slot2_type", -1))
        sp.put_u8(slot1_type if slot1_type >= WEAPON_SMG and slot1_type <= WEAPON_ROCKET else WEAPON_SLOT_EMPTY)
        sp.put_u8(clampi(int(p.get("slot1_mag", 0)), 0, 255))
        sp.put_u16(clampi(int(p.get("slot1_reserve", 0)), 0, 65535))
        sp.put_u8(slot2_type if slot2_type >= WEAPON_SMG and slot2_type <= WEAPON_ROCKET else WEAPON_SLOT_EMPTY)
        sp.put_u8(clampi(int(p.get("slot2_mag", 0)), 0, 255))
        sp.put_u16(clampi(int(p.get("slot2_reserve", 0)), 0, 65535))
        sp.put_u8(_qcenti(float(p.get("reload_timer", 0.0))))
        sp.put_u32(int(cmd_last_seq.get(pid, 0)) & 0xFFFFFFFF)

    var zcount := mini(zombies.size(), MAX_ZOMBIES_PER_SNAPSHOT)
    sp.put_u8(zcount)
    for i in range(zcount):
        var z: Dictionary = zombies[i]
        var zflags := 0
        if float(z.get("face_x", 1.0)) < 0.0:
            zflags |= 1
        if bool(z.get("walking", false)):
            zflags |= 2
        if bool(z.get("attacking", false)):
            zflags |= 4
        sp.put_u32(int(z.get("id", 0)) & 0xFFFFFFFF)
        var zombie_kind := clampi(int(z.get("kind", 0)), 0, ZOMBIE_KIND_BOSS)
        if zombie_kind == ZOMBIE_KIND_BOSS:
            zflags |= clampi(int(z.get("attack_type", BOSS_ATTACK_SLASH)), BOSS_ATTACK_SLASH, BOSS_ATTACK_LUNGE) << 3
        sp.put_u8(zombie_kind)
        sp.put_u16(_qpos(float(z.get("x", 0.0))))
        sp.put_u16(_qpos(float(z.get("y", 0.0))))
        var zombie_hp := float(z.get("hp", 0.0))
        var zombie_max_hp := maxf(1.0, float(z.get("max_hp", _zombie_max_hp_for(zombie_kind))))
        var hp_wire := roundi(clampf(zombie_hp / zombie_max_hp, 0.0, 1.0) * 255.0) if zombie_kind == ZOMBIE_KIND_BOSS else roundi(zombie_hp * 20.0)
        sp.put_u8(clampi(hp_wire, 0, 255))
        sp.put_u8(zflags)
        sp.put_u8(_qcenti(float(z.get("attack_timer", 0.0))))
        sp.put_u8(_qcenti(float(z.get("hit_timer", 0.0))))

    var wcount := mini(barricades.size(), MAX_BARRICADES)
    sp.put_u8(wcount)
    for i in range(wcount):
        var wall: Dictionary = barricades[i]
        sp.put_u32(int(wall.get("id", 0)) & 0xFFFFFFFF)
        sp.put_u16(_qpos(float(wall.get("x", 0.0))))
        sp.put_u16(_qpos(float(wall.get("y", 0.0))))
        sp.put_u8(clampi(roundi(float(wall.get("hp", 0.0))), 0, 255))
        sp.put_u8(clampi(roundi(float(wall.get("max_hp", 125.0))), 1, 255))

    var tcount := mini(turrets.size(), MAX_TURRETS)
    sp.put_u8(tcount)
    for i in range(tcount):
        var turret: Dictionary = turrets[i]
        sp.put_u16(int(turret.get("id", 0)) & 0xFFFF)
        sp.put_u16(_qpos(float(turret.get("x", 0.0))))
        sp.put_u16(_qpos(float(turret.get("y", 0.0))))
        sp.put_u8(clampi(roundi(float(turret.get("hp", TURRET_MAX_HP))), 0, 255))
        var wire_angle: float = wrapf(float(turret.get("angle", 0.0)), -PI, PI)
        sp.put_u8(clampi(roundi((wire_angle + PI) / TAU * 255.0), 0, 255))

    var dcount := mini(airdrops.size(), MAX_AIRDROPS_PER_SNAPSHOT)
    sp.put_u8(dcount)
    for i in range(dcount):
        var drop: Dictionary = airdrops[i]
        var drop_kind := str(drop.get("loot_kind", "grenade"))
        var loot_index := maxi(0, LOOT_KINDS.find(drop_kind))
        var quantity_wire := clampi(int(drop.get("quantity", 1)), 0, 255)
        if drop_kind == "weapon" or drop_kind == "ammo":
            quantity_wire = clampi(int(drop.get("weapon_id", quantity_wire)), WEAPON_SMG, WEAPON_ROCKET)
        sp.put_u32(int(drop.get("id", 0)) & 0xFFFFFFFF)
        sp.put_u16(_qpos(float(drop.get("x", 0.0))))
        sp.put_u16(_qpos(float(drop.get("y", 0.0))))
        sp.put_u16(_qpos(float(drop.get("start_y", 0.0))))
        sp.put_u16(_qpos(float(drop.get("land_y", 0.0))))
        sp.put_float(float(drop.get("elapsed", 0.0)))
        sp.put_float(float(drop.get("fall_duration", 2.6)))
        sp.put_float(float(drop.get("despawn_timer", AIRDROP_LAND_LIFETIME)))
        sp.put_u8(1 if bool(drop.get("landed", false)) else 0)
        sp.put_u8(loot_index)
        sp.put_u8(quantity_wire)

    var gcount := mini(active_grenades.size(), MAX_GRENADES_PER_SNAPSHOT)
    sp.put_u8(gcount)
    for i in range(gcount):
        var grenade: Dictionary = active_grenades[i]
        sp.put_u32(int(grenade.get("id", 0)) & 0xFFFFFFFF)
        sp.put_u16(_qpos(float(grenade.get("start_x", 0.0))))
        sp.put_u16(_qpos(float(grenade.get("start_y", 0.0))))
        sp.put_u16(_qpos(float(grenade.get("target_x", 0.0))))
        sp.put_u16(_qpos(float(grenade.get("target_y", 0.0))))
        sp.put_float(float(grenade.get("elapsed", 0.0)))
        sp.put_float(float(grenade.get("travel_time", 0.46)))
        sp.put_u8(clampi(roundi(float(grenade.get("flight_height", 72.0))), 0, 255))

    # Effects are carried redundantly for EFFECT_REDUNDANCY_MS so a single lost datagram never
    # drops a muzzle flash or explosion; the client de-duplicates them by effect id.
    var fx_budget := maxi(0, int((MAX_SNAPSHOT_BYTES - sp.get_position() - 1) / EFFECT_RECORD_BYTES))
    fx_budget = mini(fx_budget, MAX_EFFECTS_PER_SNAPSHOT)
    var fx_list: Array[Dictionary] = []
    for index in range(combat_effects.size() - 1, -1, -1):
        if fx_list.size() >= fx_budget:
            break
        var effect: Dictionary = combat_effects[index]
        if now_ms - int(effect.get("born_ms", now_ms)) <= EFFECT_REDUNDANCY_MS:
            fx_list.append(effect)
    sp.put_u8(fx_list.size())
    for effect in fx_list:
        var src_index := NO_SOURCE
        var src_id := int(effect.get("src", 0))
        if src_id != 0:
            var found := pids.find(src_id)
            if found >= 0 and found < pcount:
                src_index = found
        sp.put_u16(int(effect.get("eid", 0)) & 0xFFFF)
        sp.put_u8(clampi(int(effect.get("kind", 0)), 0, 255))
        sp.put_u16(_qpos(float(effect.get("x", 0.0))))
        sp.put_u16(_qpos(float(effect.get("y", 0.0))))
        sp.put_u16(_qpos(float(effect.get("x2", 0.0))))
        sp.put_u16(_qpos(float(effect.get("y2", 0.0))))
        sp.put_u8(_qcenti(float(effect.get("ttl", 0.0))))
        sp.put_u8(_qcenti(float(effect.get("life", 0.0))))
        sp.put_u8(src_index)
        sp.put_u16(clampi(now_ms - int(effect.get("born_ms", now_ms)), 0, 65535))
    return sp.data_array

func _decode_snapshot(buf: PackedByteArray) -> Dictionary:
    if buf.size() < SNAPSHOT_HEADER_BYTES:
        return {}
    var sp := StreamPeerBuffer.new()
    sp.data_array = buf
    if sp.get_u8() != SNAP_MAGIC:
        return {}
    var snap: Dictionary = {}
    var flags := sp.get_u8()
    snap["game_over"] = (flags & 1) != 0
    snap["timed_out"] = (flags & 2) != 0
    snap["seq"] = sp.get_u32()
    var host_ms := sp.get_u32()
    snap["host_ms"] = host_ms
    snap["t"] = float(host_ms) / 1000.0
    snap["w"] = float(sp.get_u16())
    snap["h"] = float(sp.get_u16())
    snap["world_time"] = sp.get_float()
    snap["wave"] = sp.get_u16()
    snap["spawned"] = sp.get_u8()
    snap["kills"] = sp.get_u8()
    snap["total"] = sp.get_u8()
    snap["break_t"] = sp.get_float()
    snap["wave_left"] = sp.get_float()

    var pcount := sp.get_u8()
    if sp.get_available_bytes() < pcount * PLAYER_RECORD_BYTES + 1:
        return {}
    var pids: Array[int] = []
    var pmap: Dictionary = {}
    for i in range(pcount):
        var pid := sp.get_u32()
        var px := float(sp.get_u16()) / POS_SCALE
        var py := float(sp.get_u16()) / POS_SCALE
        var php := float(sp.get_u8()) * 0.5
        var pflags := sp.get_u8()
        var pmed := sp.get_u8()
        var pgren := sp.get_u8()
        var pwall := sp.get_u8()
        var pturret := sp.get_u8()
        var pshoot := float(sp.get_u8()) * 0.01
        var phurt := float(sp.get_u8()) * 0.01
        var active_slot := clampi(sp.get_u8(), 0, 2)
        var slot1_type_wire := sp.get_u8()
        var slot1_type := slot1_type_wire if slot1_type_wire >= WEAPON_SMG and slot1_type_wire <= WEAPON_ROCKET else -1
        var slot1_mag := sp.get_u8()
        var slot1_reserve := sp.get_u16()
        var slot2_type_wire := sp.get_u8()
        var slot2_type := slot2_type_wire if slot2_type_wire >= WEAPON_SMG and slot2_type_wire <= WEAPON_ROCKET else -1
        var slot2_mag := sp.get_u8()
        var slot2_reserve := sp.get_u16()
        var reload_timer := float(sp.get_u8()) * 0.01
        var pack := sp.get_u32()
        pids.append(pid)
        pmap[pid] = {"x": px, "y": py, "hp": php, "fl": pflags, "med": pmed, "gren": pgren, "wall": pwall, "turret": pturret, "shoot": pshoot, "hurt": phurt, "active_slot": active_slot, "slot1_type": slot1_type, "slot1_mag": slot1_mag, "slot1_reserve": slot1_reserve, "slot2_type": slot2_type, "slot2_mag": slot2_mag, "slot2_reserve": slot2_reserve, "reload_timer": reload_timer, "ack": pack}
    snap["pids"] = pids
    snap["players"] = pmap

    var zcount := sp.get_u8()
    if sp.get_available_bytes() < zcount * ZOMBIE_RECORD_BYTES + 1:
        return {}
    var zids: Array[int] = []
    var zmap: Dictionary = {}
    for i in range(zcount):
        var zid := sp.get_u32()
        var zkind := clampi(sp.get_u8(), 0, ZOMBIE_KIND_BOSS)
        var zx := float(sp.get_u16()) / POS_SCALE
        var zy := float(sp.get_u16()) / POS_SCALE
        var zhp_wire := sp.get_u8()
        var zhp := float(zhp_wire) / 255.0 * _boss_hp_for_wave(int(snap["wave"])) if zkind == ZOMBIE_KIND_BOSS else float(zhp_wire) / 20.0
        var zflags := sp.get_u8()
        var zattack := float(sp.get_u8()) * 0.01
        var zhit := float(sp.get_u8()) * 0.01
        var zattack_type := clampi((zflags >> 3) & 0x03, BOSS_ATTACK_SLASH, BOSS_ATTACK_LUNGE)
        zids.append(zid)
        zmap[zid] = {"x": zx, "y": zy, "kind": zkind, "hp": zhp, "fl": zflags, "atk": zattack, "hit": zhit, "attack_type": zattack_type}
    snap["zids"] = zids
    snap["zombies"] = zmap

    var wcount := sp.get_u8()
    if sp.get_available_bytes() < wcount * WALL_RECORD_BYTES + 1:
        return {}
    var walls: Array[Dictionary] = []
    for i in range(wcount):
        var wid := sp.get_u32()
        var wx := float(sp.get_u16()) / POS_SCALE
        var wy := float(sp.get_u16()) / POS_SCALE
        var whp := float(sp.get_u8())
        var wmax := float(sp.get_u8())
        walls.append({"id": wid, "x": wx, "y": wy, "hp": whp, "max_hp": wmax})
    snap["walls"] = walls

    var tcount := sp.get_u8()
    if tcount > MAX_TURRETS or sp.get_available_bytes() < tcount * TURRET_RECORD_BYTES + 1:
        return {}
    var decoded_turrets: Array[Dictionary] = []
    for i in range(tcount):
        var tid := sp.get_u16()
        var tx := float(sp.get_u16()) / POS_SCALE
        var ty := float(sp.get_u16()) / POS_SCALE
        var thp := float(sp.get_u8())
        var tangle := float(sp.get_u8()) / 255.0 * TAU - PI
        decoded_turrets.append({"id": tid, "x": tx, "y": ty, "hp": thp, "max_hp": TURRET_MAX_HP, "angle": tangle})
    snap["turrets"] = decoded_turrets

    var dcount := sp.get_u8()
    if sp.get_available_bytes() < dcount * DROP_RECORD_BYTES + 1:
        return {}
    var drops: Array[Dictionary] = []
    for i in range(dcount):
        var did := sp.get_u32()
        var dx := float(sp.get_u16()) / POS_SCALE
        var dy := float(sp.get_u16()) / POS_SCALE
        var dstart := float(sp.get_u16()) / POS_SCALE
        var dland := float(sp.get_u16()) / POS_SCALE
        var delapsed := sp.get_float()
        var dfall := sp.get_float()
        var ddespawn := sp.get_float()
        var dlanded := sp.get_u8() != 0
        var dloot := sp.get_u8()
        var dqty := maxi(1, sp.get_u8())
        var decoded_kind: String = LOOT_KINDS[clampi(dloot, 0, LOOT_KINDS.size() - 1)]
        var decoded_quantity := 1 if decoded_kind == "weapon" or decoded_kind == "ammo" else dqty
        var decoded_weapon := dqty if decoded_kind == "weapon" or decoded_kind == "ammo" else 0
        drops.append({"id": did, "x": dx, "y": dy, "start_y": dstart, "land_y": dland, "elapsed": delapsed, "fall_duration": dfall, "despawn_timer": ddespawn, "landed": dlanded, "loot_kind": decoded_kind, "quantity": decoded_quantity, "weapon_id": decoded_weapon})
    snap["drops"] = drops

    var gcount := sp.get_u8()
    if sp.get_available_bytes() < gcount * NADE_RECORD_BYTES + 1:
        return {}
    var nades: Array[Dictionary] = []
    for i in range(gcount):
        var gid := sp.get_u32()
        var gsx := float(sp.get_u16()) / POS_SCALE
        var gsy := float(sp.get_u16()) / POS_SCALE
        var gtx := float(sp.get_u16()) / POS_SCALE
        var gty := float(sp.get_u16()) / POS_SCALE
        var gelapsed := sp.get_float()
        var gtravel := sp.get_float()
        var gheight := float(sp.get_u8())
        nades.append({"id": gid, "start_x": gsx, "start_y": gsy, "target_x": gtx, "target_y": gty, "elapsed": gelapsed, "travel_time": gtravel, "flight_height": gheight})
    snap["nades"] = nades

    var fcount := sp.get_u8()
    if sp.get_available_bytes() < fcount * EFFECT_RECORD_BYTES:
        return {}
    var effects: Array[Dictionary] = []
    for i in range(fcount):
        var eid := sp.get_u16()
        var ekind := sp.get_u8()
        var ex := float(sp.get_u16()) / POS_SCALE
        var ey := float(sp.get_u16()) / POS_SCALE
        var ex2 := float(sp.get_u16()) / POS_SCALE
        var ey2 := float(sp.get_u16()) / POS_SCALE
        var ettl := float(sp.get_u8()) * 0.01
        var elife := float(sp.get_u8()) * 0.01
        var esrc := sp.get_u8()
        var eage := float(sp.get_u16()) * 0.001
        var src_id := 0
        if esrc != NO_SOURCE and esrc < pids.size():
            src_id = pids[esrc]
        effects.append({"eid": eid, "kind": ekind, "x": ex, "y": ey, "x2": ex2, "y2": ey2, "ttl": ettl, "life": elife, "src": src_id, "age": eage})
    snap["fx"] = effects
    return snap

# --- host: remote movement commands ----------------------------------------

func _clamp_to_lane(pos: Vector2, world_w: float, world_h: float) -> Vector2:
    return Vector2(
        clampf(pos.x, 30.0, maxf(31.0, world_w - 30.0)),
        clampf(pos.y, world_h * ARENA_TOP_RATIO + ARENA_TOP_CLEARANCE, world_h * ARENA_BOTTOM_RATIO - ARENA_BOTTOM_CLEARANCE)
    )

func _command_vector(qx: int, qy: int) -> Vector2:
    return (Vector2(float(qx), float(qy)) / 127.0).limit_length(1.0)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(packed: PackedByteArray) -> void:
    if not is_host or packed.size() < 1:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if not players.has(sender_id):
        return
    var sp := StreamPeerBuffer.new()
    sp.data_array = packed
    var count := mini(sp.get_u8(), COMMAND_MAX_PER_PACKET)
    if sp.get_available_bytes() < count * COMMAND_BYTES:
        return
    var last_seq := int(cmd_last_seq.get(sender_id, 0))
    var budget := float(cmd_budget.get(sender_id, COMMAND_BUDGET_START))
    var p: Dictionary = players[sender_id]
    var alive := float(p.get("hp", 0.0)) > 0.0
    var applied := false
    var track: Dictionary = _host_track_get(sender_id, p)
    var vt_before := float(track["vt"])
    for i in range(count):
        var seq := sp.get_u32()
        var qx := sp.get_8()
        var qy := sp.get_8()
        var dt := float(sp.get_u16()) * COMMAND_DT_UNIT
        if seq <= last_seq:
            continue
        last_seq = seq
        applied = true
        # Time budget: a client may only spend as much movement time as real time has passed,
        # so inflated dt values can never become a speed hack.
        var use := minf(minf(dt, COMMAND_MAX_DT), budget)
        budget -= use
        var move := _command_vector(qx, qy)
        if alive:
            if use > 0.0:
                var next_pos := _clamp_to_lane(Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68))) + move * PLAYER_SPEED * use, screen_size.x, screen_size.y)
                p["x"] = next_pos.x
                p["y"] = next_pos.y
            if absf(move.x) > 0.14:
                p["face_x"] = -1.0 if move.x < 0.0 else 1.0
            p["walking"] = move.length() > 0.12
        if use > 0.0:
            _host_track_push(track, use, p)
    if applied:
        _host_track_arrival(track, vt_before)
        cmd_last_seq[sender_id] = last_seq
        cmd_budget[sender_id] = maxf(0.0, budget)
        cmd_last_ms[sender_id] = Time.get_ticks_msec()
        players[sender_id] = p

# --- host: smooth view of remote survivors ----------------------------------
# A remote survivor only moves when a command packet arrives (about every second frame, unevenly when
# Wi-Fi jitters), so drawing players[id] directly looks like a staircase on the host. The host therefore
# keeps a short track of (virtual time, position) per remote survivor. Virtual time is the running sum
# of command durations, i.e. the client's own clock, so network jitter cancels out; the host draws the
# track slightly in the past (jitter-adaptive). Zombies, hits and snapshots keep using the exact position.

func _host_track_get(id: int, p: Dictionary) -> Dictionary:
    if not host_track.has(id):
        host_track[id] = {
            "s": [Vector3(0.0, float(p.get("x", 0.0)), float(p.get("y", 0.0)))],
            "vt": 0.0, "off": 0.0, "ready": false, "rt": 0.0, "rt_ready": false,
            "jit": 0.0, "span": INPUT_INTERVAL, "last_s": 0.0,
        }
    return host_track[id]

func _host_track_push(track: Dictionary, use: float, p: Dictionary) -> void:
    track["vt"] = float(track["vt"]) + use
    var samples: Array = track["s"]
    samples.append(Vector3(float(track["vt"]), float(p.get("x", 0.0)), float(p.get("y", 0.0))))
    while samples.size() > HOST_VIEW_SAMPLES_MAX:
        samples.pop_front()

func _host_track_arrival(track: Dictionary, vt_before: float) -> void:
    var now_s := float(Time.get_ticks_usec()) / 1000000.0
    var vt_end := float(track["vt"])
    var off_i := now_s - vt_end
    if not bool(track["ready"]):
        track["off"] = off_i
        track["ready"] = true
    elif off_i < float(track["off"]):
        track["off"] = off_i
    else:
        track["off"] = float(track["off"]) + (off_i - float(track["off"])) * HOST_VIEW_OFFSET_LEAK
    var excess := maxf(0.0, off_i - float(track["off"]))
    track["jit"] = maxf(excess, float(track["jit"]) * HOST_VIEW_JITTER_DECAY)
    var span := vt_end - vt_before
    if span > 0.0:
        track["span"] = lerpf(float(track["span"]), clampf(span, 0.005, 0.12), 0.1)

func _update_host_view() -> void:
    var now_s := float(Time.get_ticks_usec()) / 1000000.0
    var now_ms := Time.get_ticks_msec()
    for id_variant in players.keys():
        var id := int(id_variant)
        if id == local_player_id:
            continue
        var p: Dictionary = players[id]
        var auth := Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
        var alive := float(p.get("hp", 0.0)) > 0.0
        if not host_track.has(id):
            host_view[id] = auth
            continue
        var track: Dictionary = host_track[id]
        var frame_dt := clampf(now_s - float(track["last_s"]), 0.0, 0.25)
        track["last_s"] = now_s
        if not alive or not bool(track["ready"]) or now_ms - int(cmd_last_ms.get(id, 0)) > COMMAND_STALE_MS:
            host_view[id] = auth
            track["rt_ready"] = false
            continue
        var delay := clampf(float(track["span"]) + float(track["jit"]) + HOST_VIEW_DELAY_PAD, HOST_VIEW_DELAY_MIN, HOST_VIEW_DELAY_MAX)
        var target_rt := now_s - float(track["off"]) - delay
        if not bool(track["rt_ready"]) or absf(target_rt - float(track["rt"])) > HOST_VIEW_RESYNC_S:
            track["rt"] = target_rt
            track["rt_ready"] = true
        else:
            var err := target_rt - float(track["rt"])
            track["rt"] = float(track["rt"]) + frame_dt * (1.0 + clampf(err * HOST_VIEW_PLL_GAIN, -HOST_VIEW_PLL_MAX, HOST_VIEW_PLL_MAX))
        var rt := float(track["rt"])
        var samples: Array = track["s"]
        while samples.size() > 2:
            var second: Vector3 = samples[1]
            if second.x > rt:
                break
            samples.pop_front()
        var count := samples.size()
        var last: Vector3 = samples[count - 1]
        var view := Vector2(last.y, last.z)
        if count >= 2 and rt < last.x:
            var a: Vector3 = samples[0]
            var b: Vector3 = samples[1]
            var seg := b.x - a.x
            if rt <= a.x or seg <= 0.00001:
                view = Vector2(a.y, a.z)
            else:
                var f := clampf((rt - a.x) / seg, 0.0, 1.0)
                view = Vector2(lerpf(a.y, b.y, f), lerpf(a.z, b.z, f))
        elif count >= 2:
            # Track ran dry (loss burst): coast on the last segment's velocity, then hold.
            var prev: Vector3 = samples[count - 2]
            var last_seg := last.x - prev.x
            if last_seg > 0.0005:
                var ahead := minf(rt - last.x, HOST_VIEW_EXTRAPOLATE_MAX)
                view += Vector2(last.y - prev.y, last.z - prev.z) / last_seg * ahead
        if view.distance_to(auth) > HOST_VIEW_SNAP_DISTANCE:
            view = auth
            track["s"] = [Vector3(float(track["vt"]), auth.x, auth.y)]
            track["rt_ready"] = false
        host_view[id] = view

func _player_draw_pos(id: int, p: Dictionary) -> Vector2:
    if is_host and id != local_player_id and screen_mode == "game" and not game_over and host_view.has(id):
        return host_view[id]
    return Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))

# --- client: receive and ingest ---------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered")
func receive_world(buf: PackedByteArray) -> void:
    _ingest_snapshot(buf, 0)

@rpc("authority", "call_remote", "reliable")
func receive_initial_world(buf: PackedByteArray) -> void:
    _ingest_snapshot(buf, 1)
    ui_status = "Connected — survive together!"
    if game_over:
        screen_mode = "game_over"

@rpc("authority", "call_remote", "reliable")
func begin_game_remote() -> void:
    game_over = false
    screen_mode = "game"
    ui_status = "Survive together!"
    _reset_client_interpolation()

@rpc("authority", "call_remote", "reliable")
func receive_game_over_snapshot(buf: PackedByteArray) -> void:
    _ingest_snapshot(buf, 2)
    game_over = true
    screen_mode = "game_over"
    fire_held = false
    fire_requested = false
    fire_repeat_timer = 0.0
    _cancel_targeting_modes()
    joystick_active = false
    joystick_vector = Vector2.ZERO
    ui_status = "SQUAD ELIMINATED"

func _reset_client_interpolation() -> void:
    snap_buffer.clear()
    pending_effects.clear()
    pending_sfx.clear()
    seen_effects.clear()
    zombie_cache.clear()
    clock_ready = false
    last_snapshot_seq = -1
    pred_ready = false
    pred_unacked.clear()
    pred_corr = Vector2.ZERO
    cmd_open_dt = 0.0
    local_shoot_timer = 0.0

func _ingest_snapshot(buf: PackedByteArray, mode: int) -> void:
    # mode 0: periodic (unreliable) · 1: initial world (reliable) · 2: game over (reliable)
    if is_host:
        return
    var snap := _decode_snapshot(buf)
    if snap.is_empty():
        stat_bad += 1
        return
    var now_ms := Time.get_ticks_msec()
    var seq := int(snap["seq"])
    if mode == 1:
        _reset_client_interpolation()
    elif mode == 0 and seq <= last_snapshot_seq:
        return
    if mode != 2:
        if last_snapshot_seq >= 0 and seq > last_snapshot_seq + 1 and seq - last_snapshot_seq < 1000 and mode == 0:
            stat_lost += seq - last_snapshot_seq - 1
        last_snapshot_seq = seq
        # Clock alignment: the minimum observed (receive - host) offset is the best-case path;
        # anything above it counts as jitter and widens the interpolation delay.
        var sample := float(now_ms) - float(int(snap["host_ms"]))
        if not clock_ready or mode == 1:
            clock_offset_ms = sample
            clock_ready = true
            jitter_ms = 0.0
        else:
            var deviation := sample - clock_offset_ms
            if deviation < 0.0:
                clock_offset_ms = sample
                deviation = 0.0
            else:
                clock_offset_ms += deviation * CLOCK_DRIFT_RATE
            jitter_ms += (deviation - jitter_ms) * JITTER_SMOOTHING
        snap["recv"] = now_ms
        snap_buffer.append(snap)
        while snap_buffer.size() > SNAPSHOT_BUFFER_MAX:
            snap_buffer.pop_front()
    stat_snaps += 1
    stat_bytes += buf.size()

    var was_game_over := game_over
    host_world_w = maxf(1.0, float(snap["w"]))
    host_world_h = maxf(1.0, float(snap["h"]))
    world_time = float(snap["world_time"])
    wave_number = maxi(1, int(snap["wave"]))
    wave_spawned = maxi(0, int(snap["spawned"]))
    wave_kills = maxi(0, int(snap["kills"]))
    wave_total = maxi(1, int(snap["total"]))
    wave_break_timer = maxf(0.0, float(snap["break_t"]))
    wave_time_remaining = maxf(0.0, float(snap["wave_left"]))
    wave_timed_out = bool(snap["timed_out"])
    game_over = bool(snap["game_over"])
    if mode == 0:
        if game_over:
            screen_mode = "game_over"
            fire_held = false
            fire_requested = false
            joystick_vector = Vector2.ZERO
        elif was_game_over and screen_mode == "game_over":
            screen_mode = "game"

    var snap_players: Dictionary = snap["players"]
    if snap_players.has(local_player_id):
        var mine: Dictionary = snap_players[local_player_id]
        local_hp = float(mine["hp"])
        if mode != 2:
            _reconcile_local(mine)

    # Effects: schedule on the host timeline so they line up with interpolated entities.
    var host_t := float(snap["t"])
    for effect in snap["fx"]:
        var eid := int(effect["eid"])
        if seen_effects.has(eid):
            continue
        seen_effects[eid] = now_ms
        var kind := int(effect["kind"])
        if (kind == 0 or kind == 1) and int(effect["src"]) == local_player_id:
            continue # predicted locally the instant the player pressed FIRE
        var scheduled: Dictionary = effect.duplicate()
        scheduled["start"] = host_t - float(effect["age"])
        pending_effects.append(scheduled)
    if pending_effects.size() > 96:
        pending_effects = pending_effects.slice(pending_effects.size() - 96)
    if screen_mode != "game":
        _client_update_render(0.0)

# --- client: prediction + reconciliation ------------------------------------

func _local_alive() -> bool:
    return local_hp > 0.0

func _step_command(pos: Vector2, qx: int, qy: int, dt: float) -> Vector2:
    if dt <= 0.0 or not _local_alive():
        return pos
    return _clamp_to_lane(pos + _command_vector(qx, qy) * PLAYER_SPEED * dt, host_world_w, host_world_h)

func _predict_local_player(delta: float) -> void:
    if not pred_ready or game_over or screen_mode != "game":
        return
    var qx := clampi(roundi(joystick_vector.x * 127.0), -127, 127)
    var qy := clampi(roundi(joystick_vector.y * 127.0), -127, 127)
    if not _local_alive():
        qx = 0
        qy = 0
    var move := _command_vector(qx, qy)
    if qx != 0 or qy != 0:
        pred_pos = _clamp_to_lane(pred_pos + move * PLAYER_SPEED * delta, host_world_w, host_world_h)
    if absf(move.x) > 0.14:
        local_face = -1.0 if move.x < 0.0 else 1.0
    local_walking = move.length() > 0.12
    if qx != cmd_open_qx or qy != cmd_open_qy or cmd_open_dt >= COMMAND_MAX_DT:
        _close_open_command()
        cmd_open_qx = qx
        cmd_open_qy = qy
    cmd_open_dt += delta
    # Bleed any host correction in smoothly instead of teleporting the character.
    if pred_corr != Vector2.ZERO:
        var step := pred_corr * minf(1.0, delta * PRED_CORRECTION_RATE)
        pred_pos += step
        pred_corr -= step
        if pred_corr.length() < 0.05:
            pred_corr = Vector2.ZERO
    local_shoot_timer = maxf(0.0, local_shoot_timer - delta)

func _close_open_command() -> void:
    var dtq := clampi(roundi(cmd_open_dt / COMMAND_DT_UNIT), 0, 65535)
    if dtq > 0:
        cmd_seq += 1
        pred_unacked.append({"seq": cmd_seq, "qx": cmd_open_qx, "qy": cmd_open_qy, "dtq": dtq})
        while pred_unacked.size() > COMMAND_HISTORY_MAX:
            pred_unacked.pop_front()
    cmd_open_dt = 0.0

func _send_input_commands() -> void:
    _close_open_command()
    var start := maxi(0, pred_unacked.size() - COMMAND_MAX_PER_PACKET)
    var sp := StreamPeerBuffer.new()
    sp.put_u8(pred_unacked.size() - start)
    for i in range(start, pred_unacked.size()):
        var command: Dictionary = pred_unacked[i]
        sp.put_u32(int(command["seq"]) & 0xFFFFFFFF)
        sp.put_8(int(command["qx"]))
        sp.put_8(int(command["qy"]))
        sp.put_u16(int(command["dtq"]))
    rpc_id(1, "submit_input", sp.data_array)

func _reconcile_local(rec: Dictionary) -> void:
    var host_pos := Vector2(float(rec["x"]), float(rec["y"]))
    var ack := int(rec["ack"])
    while not pred_unacked.is_empty() and int(pred_unacked[0]["seq"]) <= ack:
        pred_unacked.pop_front()
    if not pred_ready:
        pred_pos = host_pos
        pred_corr = Vector2.ZERO
        pred_ready = true
        return
    # Authoritative position + every command the host has not acknowledged yet.
    var replay := host_pos
    for command in pred_unacked:
        replay = _step_command(replay, int(command["qx"]), int(command["qy"]), float(int(command["dtq"])) * COMMAND_DT_UNIT)
    replay = _step_command(replay, cmd_open_qx, cmd_open_qy, cmd_open_dt)
    var error := replay - pred_pos
    pred_error_px = error.length()
    if pred_error_px > PRED_SNAP_DISTANCE:
        pred_pos = replay
        pred_corr = Vector2.ZERO
    elif pred_error_px < PRED_DEADZONE:
        pred_corr = Vector2.ZERO
    else:
        pred_corr = error

# --- client: local fire feedback --------------------------------------------

func _push_local_effect(kind: int, start_pos: Vector2, end_pos: Vector2, lifetime: float) -> void:
    combat_effects.append({"kind": kind, "x": start_pos.x, "y": start_pos.y, "x2": end_pos.x, "y2": end_pos.y, "ttl": lifetime, "life": lifetime})
    if combat_effects.size() > 48:
        combat_effects.pop_front()

func _predict_local_fire() -> bool:
    var now := Time.get_ticks_msec()
    if not players.has(local_player_id):
        return false
    var p: Dictionary = players[local_player_id]
    if float(p.get("hp", 0.0)) <= 0.0 or float(p.get("reload_timer", 0.0)) > 0.0:
        return false
    var weapon_id := _active_weapon_id(p)
    var active_slot := clampi(int(p.get("active_slot", 0)), 0, 2)
    var profile := _weapon_profile(weapon_id)
    var shot_interval_ms := int(profile.get("interval_ms", FIRE_COOLDOWN_MS))
    if now - local_fire_ms < shot_interval_ms:
        return false
    if weapon_id != WEAPON_SIDEARM and _slot_mag(p, active_slot) <= 0:
        # Send the input so the host can start a reload or switch to the infinite sidearm.
        local_fire_ms = now
        if _slot_reserve(p, active_slot) > 0:
            return true
        weapon_id = WEAPON_SIDEARM
        profile = _weapon_profile(WEAPON_SIDEARM)
    local_fire_ms = now
    local_shoot_timer = 0.19 if weapon_id == WEAPON_SIDEARM else (0.22 if weapon_id == WEAPON_SNIPER else 0.14)
    _play_sfx("shot")
    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))
    var facing := Vector2.LEFT if local_face < 0.0 else Vector2.RIGHT
    var muzzle := player_pos + facing * 24.0 + Vector2(0.0, 7.0)
    var max_range := minf(float(profile.get("range", SHOT_RANGE_MAX)), screen_size.x * 0.90)
    var closest_projection := max_range
    for zombie in zombies:
        var offset := Vector2(float(zombie.get("x", 0.0)), float(zombie.get("y", 0.0))) - player_pos
        var projection := offset.dot(facing)
        if projection > 16.0 and projection <= closest_projection and absf(offset.y) <= float(profile.get("lane", SHOT_LANE_TOLERANCE)):
            closest_projection = projection
    var tracer_end := player_pos + facing * closest_projection + Vector2(0.0, 7.0)
    _push_local_effect(0, muzzle, muzzle, 0.13 if weapon_id != WEAPON_SNIPER else 0.22)
    if weapon_id == WEAPON_SHOTGUN:
        for spread in SHOTGUN_PELLET_OFFSETS:
            var pellet_end := tracer_end + Vector2(0.0, spread)
            _push_local_effect(10, muzzle + Vector2(0.0, spread * 0.35), pellet_end, 0.14)
    elif weapon_id == WEAPON_ROCKET:
        var travel_time := clampf(player_pos.distance_to(tracer_end) / 920.0, 0.16, 0.44)
        _push_local_effect(12, muzzle, tracer_end, travel_time)
    else:
        _push_local_effect(int(profile.get("effect", 1)), muzzle, tracer_end, 0.12 if weapon_id == WEAPON_SMG else (0.22 if weapon_id == WEAPON_SNIPER else 0.16))
    return true

# --- client: render-state construction --------------------------------------

func _target_interp_delay() -> float:
    return clampf(SNAPSHOT_INTERVAL * 2.0 + jitter_ms * 0.002 + 0.015, INTERP_DELAY_MIN, INTERP_DELAY_MAX)

func _find_record(records: Array, record_id: int, fallback: Dictionary) -> Dictionary:
    for record in records:
        if int(record["id"]) == record_id:
            return record
    return fallback

func _client_update_render(delta: float) -> void:
    if snap_buffer.is_empty():
        return
    var now_ms := Time.get_ticks_msec()
    interp_delay = move_toward(interp_delay, _target_interp_delay(), delta * INTERP_ADAPT_RATE)
    var render_t := (float(now_ms) - clock_offset_ms) / 1000.0 - interp_delay
    var newest: Dictionary = snap_buffer[snap_buffer.size() - 1]
    var from_snap: Dictionary = snap_buffer[0]
    var to_snap: Dictionary = snap_buffer[0]
    var alpha := 0.0
    var starved := false
    var older_index := -1
    for i in range(snap_buffer.size() - 1, -1, -1):
        if float(snap_buffer[i]["t"]) <= render_t:
            older_index = i
            break
    if older_index >= 0:
        if older_index == snap_buffer.size() - 1:
            # Snapshot starvation: extrapolate briefly from the two newest snapshots.
            starved = true
            to_snap = snap_buffer[older_index]
            if older_index > 0:
                from_snap = snap_buffer[older_index - 1]
                var span := maxf(0.001, float(to_snap["t"]) - float(from_snap["t"]))
                alpha = 1.0 + minf(render_t - float(to_snap["t"]), EXTRAPOLATE_MAX) / span
            else:
                from_snap = to_snap
        else:
            from_snap = snap_buffer[older_index]
            to_snap = snap_buffer[older_index + 1]
            alpha = clampf((render_t - float(from_snap["t"])) / maxf(0.001, float(to_snap["t"]) - float(from_snap["t"])), 0.0, 1.0)
    render_starved = starved
    render_time = render_t
    var sx := screen_size.x / host_world_w
    var sy := screen_size.y / host_world_h

    # Survivors
    var to_players: Dictionary = to_snap["players"]
    var from_players: Dictionary = from_snap["players"]
    var newest_players: Dictionary = newest["players"]
    for id_variant in to_players.keys():
        var id := int(id_variant)
        var rec: Dictionary = to_players[id]
        var older: Dictionary = from_players.get(id, rec)
        var pos := Vector2(lerpf(float(older["x"]), float(rec["x"]), alpha), lerpf(float(older["y"]), float(rec["y"]), alpha))
        if Vector2(float(older["x"]), float(older["y"])).distance_to(Vector2(float(rec["x"]), float(rec["y"]))) > TELEPORT_DISTANCE:
            pos = Vector2(float(rec["x"]), float(rec["y"]))
        var stats: Dictionary = rec
        var shown: Dictionary = players.get(id, {})
        var face_left := (int(rec["fl"]) & 1) != 0
        var walking := (int(rec["fl"]) & 2) != 0
        var shoot_timer := float(rec["shoot"])
        if id == local_player_id:
            if newest_players.has(id):
                stats = newest_players[id]
            if pred_ready:
                pos = pred_pos
            face_left = local_face < 0.0
            walking = local_walking and _local_alive()
            shoot_timer = maxf(local_shoot_timer, float(stats["shoot"]))
        shown["x"] = pos.x * sx
        shown["y"] = pos.y * sy
        shown["hp"] = float(stats["hp"])
        shown["medkits"] = int(stats["med"])
        shown["ammo"] = -1
        shown["grenades"] = int(stats["gren"])
        shown["wall_kits"] = int(stats["wall"])
        shown["turret_kits"] = int(stats.get("turret", 0))
        shown["active_slot"] = int(stats.get("active_slot", 0))
        shown["slot1_type"] = int(stats.get("slot1_type", -1))
        shown["slot1_mag"] = int(stats.get("slot1_mag", 0))
        shown["slot1_reserve"] = int(stats.get("slot1_reserve", 0))
        shown["slot2_type"] = int(stats.get("slot2_type", -1))
        shown["slot2_mag"] = int(stats.get("slot2_mag", 0))
        shown["slot2_reserve"] = int(stats.get("slot2_reserve", 0))
        shown["reload_timer"] = float(stats.get("reload_timer", 0.0))
        shown["face_x"] = -1.0 if face_left else 1.0
        shown["walking"] = walking
        shown["shoot_timer"] = shoot_timer
        shown["hurt_timer"] = float(stats["hurt"])
        players[id] = shown
    for id_variant in players.keys().duplicate():
        if not newest_players.has(id_variant):
            players.erase(id_variant)

    # Zombies
    var to_zombies: Dictionary = to_snap["zombies"]
    var from_zombies: Dictionary = from_snap["zombies"]
    zombies.clear()
    for zid_variant in to_snap["zids"]:
        var zid := int(zid_variant)
        zombies.append(_build_zombie(zid, to_zombies[zid], from_zombies.get(zid, to_zombies[zid]), alpha, sx, sy))
    if not starved and alpha < 0.5:
        # A zombie that died inside this interval lingers until the interval is half over.
        for zid_variant in from_snap["zids"]:
            var gone_id := int(zid_variant)
            if not to_zombies.has(gone_id):
                zombies.append(_build_zombie(gone_id, from_zombies[gone_id], from_zombies[gone_id], 0.0, sx, sy))
    if zombie_cache.size() > zombies.size() + 24:
        var kept: Dictionary = {}
        for zombie in zombies:
            kept[int(zombie["id"])] = zombie
        zombie_cache = kept

    # Barricades, supply drops and grenades
    barricades.clear()
    for wall in to_snap["walls"]:
        barricades.append({"id": int(wall["id"]), "x": float(wall["x"]) * sx, "y": float(wall["y"]) * sy, "hp": float(wall["hp"]), "max_hp": float(wall["max_hp"])})
    turrets.clear()
    var from_turrets: Array = from_snap.get("turrets", [])
    for turret_record in to_snap.get("turrets", []):
        var prior_turret: Dictionary = _find_record(from_turrets, int(turret_record.get("id", 0)), turret_record)
        var turret_pos := Vector2(
            lerpf(float(prior_turret.get("x", turret_record["x"])), float(turret_record["x"]), alpha) * sx,
            lerpf(float(prior_turret.get("y", turret_record["y"])), float(turret_record["y"]), alpha) * sy
        )
        var prior_angle: float = float(prior_turret.get("angle", turret_record.get("angle", 0.0)))
        var angle_step: float = wrapf(float(turret_record.get("angle", 0.0)) - prior_angle, -PI, PI)
        turrets.append({"id": int(turret_record["id"]), "x": turret_pos.x, "y": turret_pos.y, "hp": float(turret_record["hp"]), "max_hp": float(turret_record.get("max_hp", TURRET_MAX_HP)), "angle": prior_angle + angle_step * alpha, "flash_timer": 0.0})
    airdrops.clear()
    var from_drops: Array = from_snap["drops"]
    for drop in to_snap["drops"]:
        var older_drop: Dictionary = _find_record(from_drops, int(drop["id"]), drop)
        var drop_elapsed := lerpf(float(older_drop["elapsed"]), float(drop["elapsed"]), alpha)
        var landed := bool(drop["landed"])
        var drop_y := float(drop["land_y"])
        if not landed:
            drop_y = lerpf(float(drop["start_y"]), float(drop["land_y"]), clampf(drop_elapsed / maxf(0.1, float(drop["fall_duration"])), 0.0, 1.0))
        airdrops.append({"id": int(drop["id"]), "x": float(drop["x"]) * sx, "y": drop_y * sy, "start_y": float(drop["start_y"]) * sy, "land_y": float(drop["land_y"]) * sy, "elapsed": drop_elapsed, "fall_duration": float(drop["fall_duration"]), "despawn_timer": float(drop["despawn_timer"]), "landed": landed, "loot_kind": str(drop["loot_kind"]), "quantity": int(drop["quantity"]), "weapon_id": int(drop.get("weapon_id", WEAPON_SMG))})
    active_grenades.clear()
    var from_nades: Array = from_snap["nades"]
    for nade in to_snap["nades"]:
        var older_nade: Dictionary = _find_record(from_nades, int(nade["id"]), nade)
        var nade_elapsed := lerpf(float(older_nade["elapsed"]), float(nade["elapsed"]), alpha)
        var travel := maxf(0.05, float(nade["travel_time"]))
        var progress := clampf(nade_elapsed / travel, 0.0, 1.0)
        var launch := Vector2(float(nade["start_x"]) * sx, float(nade["start_y"]) * sy)
        var landing := Vector2(float(nade["target_x"]) * sx, float(nade["target_y"]) * sy)
        var ground := launch.lerp(landing, progress)
        active_grenades.append({"id": int(nade["id"]), "start_x": launch.x, "start_y": launch.y, "target_x": landing.x, "target_y": landing.y, "x": ground.x, "y": ground.y, "elapsed": nade_elapsed, "travel_time": travel, "flight_height": float(nade["flight_height"]), "fuse": 0.0})

    # Scheduled effects and sounds fire when the render clock reaches their host timestamp.
    for index in range(pending_effects.size() - 1, -1, -1):
        var scheduled: Dictionary = pending_effects[index]
        var start_t := float(scheduled["start"])
        if render_t - start_t > 2.0:
            pending_effects.remove_at(index)
        elif render_t >= start_t:
            pending_effects.remove_at(index)
            var life := maxf(0.01, float(scheduled["life"]))
            var remaining := life - (render_t - start_t)
            if remaining > 0.0:
                combat_effects.append({"eid": int(scheduled.get("eid", 0)), "kind": int(scheduled["kind"]), "x": float(scheduled["x"]) * sx, "y": float(scheduled["y"]) * sy, "x2": float(scheduled["x2"]) * sx, "y2": float(scheduled["y2"]) * sy, "ttl": remaining, "life": life})
    if combat_effects.size() > 48:
        combat_effects = combat_effects.slice(combat_effects.size() - 48)
    for index in range(pending_sfx.size() - 1, -1, -1):
        var cue: Dictionary = pending_sfx[index]
        var cue_t := float(cue["t"])
        if render_t - cue_t > 1.0:
            pending_sfx.remove_at(index)
        elif render_t >= cue_t:
            pending_sfx.remove_at(index)
            _play_sfx(str(cue["clip"]))

func _build_zombie(zid: int, rec: Dictionary, older: Dictionary, alpha: float, sx: float, sy: float) -> Dictionary:
    var pos := Vector2(lerpf(float(older["x"]), float(rec["x"]), alpha), lerpf(float(older["y"]), float(rec["y"]), alpha))
    if Vector2(float(older["x"]), float(older["y"])).distance_to(Vector2(float(rec["x"]), float(rec["y"]))) > TELEPORT_DISTANCE:
        pos = Vector2(float(rec["x"]), float(rec["y"]))
    var kind := clampi(int(rec["kind"]), 0, ZOMBIE_MAX_HP.size() - 1)
    var flags := int(rec["fl"])
    var shown: Dictionary = zombie_cache.get(zid, {})
    shown["id"] = zid
    shown["kind"] = kind
    shown["x"] = pos.x * sx
    shown["y"] = pos.y * sy
    shown["face_x"] = -1.0 if (flags & 1) != 0 else 1.0
    shown["hp"] = float(rec["hp"])
    shown["max_hp"] = _zombie_max_hp_for(kind, wave_number)
    shown["walking"] = (flags & 2) != 0
    shown["attacking"] = (flags & 4) != 0
    shown["attack_timer"] = float(rec["atk"])
    shown["attack_type"] = clampi(int(rec.get("attack_type", (flags >> 3) & 0x03)), BOSS_ATTACK_SLASH, BOSS_ATTACK_LUNGE)
    shown["hit_timer"] = float(rec["hit"])
    zombie_cache[zid] = shown
    return shown

func _tick_client_effects(delta: float) -> void:
    for effect_index in range(combat_effects.size() - 1, -1, -1):
        var effect: Dictionary = combat_effects[effect_index]
        effect["ttl"] = maxf(0.0, float(effect.get("ttl", 0.0)) - delta)
        if float(effect["ttl"]) <= 0.0:
            combat_effects.remove_at(effect_index)
        else:
            combat_effects[effect_index] = effect

func _client_network_tick(delta: float) -> void:
    _predict_local_player(delta)
    client_input_timer += delta
    if client_input_timer >= INPUT_INTERVAL - delta * 0.5:
        client_input_timer -= INPUT_INTERVAL
        if client_input_timer > INPUT_INTERVAL or client_input_timer < -INPUT_INTERVAL:
            client_input_timer = 0.0
        if pred_ready:
            _send_input_commands()
    _client_update_render(delta)
    _tick_client_effects(delta)

func _update_net_stats(delta: float) -> void:
    stat_timer += delta
    if stat_timer < 1.0:
        return
    var total := float(stat_snaps + stat_lost)
    net_snaps_per_s = float(stat_snaps) / stat_timer
    net_kbps = float(stat_bytes) / stat_timer / 1024.0
    net_loss_pct = 100.0 * float(stat_lost) / maxf(1.0, total)
    stat_snaps = 0
    stat_lost = 0
    stat_bytes = 0
    stat_timer = 0.0
    net_rtt_ms = -1
    if peer != null and not is_host:
        var remote: ENetPacketPeer = peer.get_peer(1)
        if remote != null:
            net_rtt_ms = int(remote.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
    # forget old effect ids
    var now_ms := Time.get_ticks_msec()
    for eid in seen_effects.keys():
        if now_ms - int(seen_effects[eid]) > 3000:
            seen_effects.erase(eid)

func _tune_enet_peer(remote_id: int) -> void:
    # Keep ENet from silently dropping unreliable snapshots when Wi-Fi RTT spikes.
    if peer == null:
        return
    var remote: ENetPacketPeer = peer.get_peer(remote_id)
    if remote != null:
        remote.throttle_configure(ENET_THROTTLE_INTERVAL_MS, ENET_THROTTLE_ACCEL, ENET_THROTTLE_DECEL)

func _broadcast_world() -> void:
    if not is_host or is_offline or multiplayer.multiplayer_peer == null:
        return
    if multiplayer.get_peers().is_empty():
        return
    rpc("receive_world", _encode_snapshot())

@rpc("authority", "call_remote", "reliable")
func begin_game_over_remote() -> void:
    game_over = true
    screen_mode = "game_over"
    fire_held = false
    fire_requested = false
    fire_repeat_timer = 0.0
    _cancel_targeting_modes()
    joystick_active = false
    joystick_vector = Vector2.ZERO
    ui_status = "SQUAD ELIMINATED"

func _begin_game() -> void:
    if not is_host:
        ui_status = "Only the host can start the world."
        return
    screen_mode = "game"
    ui_status = "Survive together!"
    snapshot_timer = 0.0
    if not is_offline and multiplayer.multiplayer_peer != null:
        rpc("begin_game_remote")

func _start_offline(load_saved: bool = false) -> void:
    if load_saved and not FileAccess.file_exists(SAVE_PATH):
        ui_status = "No saved run found — use NEW SOLO RUN first"
        return
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
    peer = null
    is_host = true
    is_offline = true
    local_player_id = 1
    players.clear()
    player_death_visuals.clear()
    input_vectors.clear()
    cmd_last_seq.clear()
    cmd_budget.clear()
    cmd_last_ms.clear()
    host_track.clear()
    host_view.clear()
    zombies.clear()
    airdrops.clear()
    barricades.clear()
    turrets.clear()
    active_grenades.clear()
    active_projectiles.clear()
    airdrop_spawn_timer = AIRDROP_FIRST_DELAY
    airdrop_sequence = 1
    combat_effects.clear()
    fire_cooldowns.clear()
    heal_cooldowns.clear()
    grenade_cooldowns.clear()
    build_cooldowns.clear()
    turret_sequence = 1
    wave_number = 1
    wave_total = _zombie_count_for_wave(wave_number)
    wave_spawned = 0
    wave_kills = 0
    wave_spawn_timer = 0.9
    wave_break_timer = 0.0
    wave_time_remaining = _wave_duration_for(1)
    wave_timed_out = false
    game_over = false
    world_time = 0.0
    world_seed = randi()
    seed(world_seed)
    if load_saved:
        if FileAccess.file_exists(SAVE_PATH):
            _load_world()
    players[1] = _make_player(1)
    input_vectors[1] = Vector2.ZERO
    screen_mode = "game"
    ui_status = "Offline survival — world saves on this phone"
    last_save_time = world_time
    snapshot_timer = 0.0

@rpc("any_peer", "call_remote", "reliable", 1)
func request_fire() -> void:
    if not is_host:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if players.has(sender_id):
        _host_fire(sender_id)

func _add_combat_effect(kind: int, start_pos: Vector2, end_pos: Vector2, lifetime: float, src_id: int = 0) -> void:
    effect_seq += 1
    combat_effects.append({
        "eid": effect_seq & 0xFFFF,
        "born_ms": Time.get_ticks_msec(),
        "src": src_id,
        "kind": kind,
        "x": start_pos.x,
        "y": start_pos.y,
        "x2": end_pos.x,
        "y2": end_pos.y,
        "ttl": lifetime,
        "life": lifetime
    })
    if combat_effects.size() > 36:
        combat_effects.pop_front()

func _weapon_profile(weapon_id: int) -> Dictionary:
    match clampi(weapon_id, WEAPON_SIDEARM, WEAPON_ROCKET):
        WEAPON_SMG:
            return {"name": "SMG", "damage": 1.0, "range": 450.0, "lane": 25.0, "interval_ms": 110, "mag_size": 30, "reserve_cap": 180, "spawn_reserve": 90, "ammo_pack": 45, "reload_time": 1.15, "radius": 0.0, "effect": 14}
        WEAPON_SHOTGUN:
            return {"name": "SHOTGUN", "damage": 1.15, "range": 245.0, "lane": 10.0, "interval_ms": 720, "mag_size": 6, "reserve_cap": 36, "spawn_reserve": 18, "ammo_pack": 12, "reload_time": 1.45, "radius": 0.0, "effect": 10}
        WEAPON_RIFLE:
            return {"name": "RENBO LMG", "damage": 1.55, "range": 535.0, "lane": 22.0, "interval_ms": 135, "mag_size": 45, "reserve_cap": 225, "spawn_reserve": 135, "ammo_pack": 60, "reload_time": 1.55, "radius": 0.0, "effect": 13}
        WEAPON_SNIPER:
            return {"name": "SNIPER", "damage": 7.0, "range": 760.0, "lane": 13.0, "interval_ms": 900, "mag_size": 5, "reserve_cap": 30, "spawn_reserve": 10, "ammo_pack": 5, "reload_time": 1.85, "radius": 0.0, "effect": 11}
        WEAPON_ROCKET:
            return {"name": "ROCKET", "damage": 8.0, "range": 520.0, "lane": 28.0, "interval_ms": 1000, "mag_size": 1, "reserve_cap": 12, "spawn_reserve": 3, "ammo_pack": 2, "reload_time": 1.75, "radius": 86.0, "effect": 12}
        _:
            return {"name": "SIDEARM", "damage": 1.0, "range": SHOT_RANGE_MAX, "lane": SHOT_LANE_TOLERANCE, "interval_ms": FIRE_COOLDOWN_MS, "mag_size": -1, "reserve_cap": 0, "spawn_reserve": 0, "ammo_pack": 0, "reload_time": 0.0, "radius": 0.0, "effect": 1}

func _weapon_name(weapon_id: int) -> String:
    return str(_weapon_profile(weapon_id).get("name", "SIDEARM"))

func _active_weapon_id(p: Dictionary) -> int:
    var slot := clampi(int(p.get("active_slot", 0)), 0, 2)
    if slot == 1:
        var first := int(p.get("slot1_type", -1))
        return first if first >= WEAPON_SMG and first <= WEAPON_ROCKET else WEAPON_SIDEARM
    if slot == 2:
        var second := int(p.get("slot2_type", -1))
        return second if second >= WEAPON_SMG and second <= WEAPON_ROCKET else WEAPON_SIDEARM
    return WEAPON_SIDEARM

func _slot_type(p: Dictionary, slot: int) -> int:
    if slot == 1:
        return int(p.get("slot1_type", -1))
    if slot == 2:
        return int(p.get("slot2_type", -1))
    return WEAPON_SIDEARM

func _slot_mag(p: Dictionary, slot: int) -> int:
    return maxi(0, int(p.get("slot1_mag" if slot == 1 else "slot2_mag", 0))) if slot > 0 else -1

func _slot_reserve(p: Dictionary, slot: int) -> int:
    return maxi(0, int(p.get("slot1_reserve" if slot == 1 else "slot2_reserve", 0))) if slot > 0 else 0

func _set_slot_ammo(p: Dictionary, slot: int, mag: int, reserve: int) -> void:
    if slot == 1:
        p["slot1_mag"] = maxi(0, mag)
        p["slot1_reserve"] = maxi(0, reserve)
    elif slot == 2:
        p["slot2_mag"] = maxi(0, mag)
        p["slot2_reserve"] = maxi(0, reserve)

func _find_weapon_slot(p: Dictionary, weapon_id: int) -> int:
    if int(p.get("slot1_type", -1)) == weapon_id:
        return 1
    if int(p.get("slot2_type", -1)) == weapon_id:
        return 2
    return 0

func _can_collect_ammo(p: Dictionary, weapon_id: int) -> bool:
    var slot := _find_weapon_slot(p, weapon_id)
    if slot <= 0:
        return false
    var profile := _weapon_profile(weapon_id)
    return _slot_reserve(p, slot) < int(profile["reserve_cap"]) or _slot_mag(p, slot) < int(profile["mag_size"])

func _start_weapon_reload(p: Dictionary, slot: int) -> void:
    if slot < 1 or slot > 2:
        return
    var weapon_id := _slot_type(p, slot)
    var profile := _weapon_profile(weapon_id)
    if weapon_id < WEAPON_SMG or _slot_mag(p, slot) >= int(profile["mag_size"]) or _slot_reserve(p, slot) <= 0:
        return
    p["reload_timer"] = float(profile["reload_time"])
    ui_status = "RELOADING %s" % _weapon_name(weapon_id)

func _finish_weapon_reload(p: Dictionary) -> void:
    var slot := clampi(int(p.get("active_slot", 0)), 0, 2)
    var weapon_id := _slot_type(p, slot)
    if slot < 1 or slot > 2 or weapon_id < WEAPON_SMG:
        p["reload_timer"] = 0.0
        return
    var profile := _weapon_profile(weapon_id)
    var missing := maxi(0, int(profile["mag_size"]) - _slot_mag(p, slot))
    var taken := mini(missing, _slot_reserve(p, slot))
    _set_slot_ammo(p, slot, _slot_mag(p, slot) + taken, _slot_reserve(p, slot) - taken)
    p["reload_timer"] = 0.0

func _request_weapon_switch(slot: int) -> void:
    if is_host:
        _host_switch_weapon(local_player_id, slot)
    elif _is_connected_client():
        rpc_id(1, "request_switch_weapon", clampi(slot, 0, 2))
    else:
        ui_status = "Pick up a weapon during a world session"

@rpc("any_peer", "call_remote", "reliable", 1)
func request_switch_weapon(slot: int) -> void:
    if not is_host:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if players.has(sender_id):
        _host_switch_weapon(sender_id, slot)

func _host_switch_weapon(id: int, slot: int) -> void:
    if game_over or not players.has(id):
        return
    slot = clampi(slot, 0, 2)
    var p: Dictionary = players[id]
    if float(p.get("hp", 0.0)) <= 0.0:
        return
    if slot > 0 and _slot_type(p, slot) < WEAPON_SMG:
        ui_status = "WEAPON SLOT EMPTY"
        return
    if int(p.get("active_slot", 0)) == slot:
        return
    p["active_slot"] = slot
    p["reload_timer"] = 0.0 # Switching cancels the in-progress reload; the empty magazine remains empty.
    players[id] = p
    var weapon_id := _active_weapon_id(p)
    ui_status = "WEAPON: %s%s" % [_weapon_name(weapon_id), " · INFINITE AMMO" if weapon_id == WEAPON_SIDEARM else " · %d/%d" % [_slot_mag(p, slot), _slot_reserve(p, slot)]]

func _give_weapon(p: Dictionary, weapon_id: int) -> int:
    weapon_id = clampi(weapon_id, WEAPON_SMG, WEAPON_ROCKET)
    var profile := _weapon_profile(weapon_id)
    var slot := _find_weapon_slot(p, weapon_id)
    if slot > 0:
        _set_slot_ammo(p, slot, int(profile["mag_size"]), int(profile["reserve_cap"]))
        p["active_slot"] = slot
        p["reload_timer"] = 0.0
        return slot
    slot = 1 if int(p.get("slot1_type", -1)) < WEAPON_SMG else (2 if int(p.get("slot2_type", -1)) < WEAPON_SMG else 2)
    var replaced_type := _slot_type(p, slot)
    p["slot%d_type" % slot] = weapon_id
    _set_slot_ammo(p, slot, int(profile["mag_size"]), int(profile["spawn_reserve"]))
    p["active_slot"] = slot
    p["reload_timer"] = 0.0
    if replaced_type >= WEAPON_SMG and replaced_type != weapon_id:
        ui_status = "SWAPPED %s → %s" % [_weapon_name(replaced_type), _weapon_name(weapon_id)]
    return slot

func _apply_weapon_damage(index: int, damage: float, impact_pos: Vector2) -> void:
    if index < 0 or index >= zombies.size():
        return
    var zombie: Dictionary = zombies[index]
    zombie["hit_timer"] = 0.16
    zombie["walking"] = false
    zombie["hp"] = float(zombie.get("hp", 1.0)) - damage
    _add_combat_effect(2, impact_pos, impact_pos, 0.18)
    _emit_sfx("hit")
    if float(zombie["hp"]) <= 0.0:
        _add_combat_effect(4, impact_pos, impact_pos, 0.30)
        _emit_sfx("death")
        wave_kills = mini(wave_total, wave_kills + 1)
        zombies.remove_at(index)
    else:
        zombies[index] = zombie

func _host_fire(id: int) -> void:
    if game_over or not players.has(id):
        return
    var p: Dictionary = players[id]
    if float(p.get("hp", 0.0)) <= 0.0:
        return
    var weapon_id := _active_weapon_id(p)
    var active_slot := clampi(int(p.get("active_slot", 0)), 0, 2)
    if float(p.get("reload_timer", 0.0)) > 0.0:
        return
    if weapon_id != WEAPON_SIDEARM and _slot_mag(p, active_slot) <= 0:
        if _slot_reserve(p, active_slot) > 0:
            _start_weapon_reload(p, active_slot)
            players[id] = p
            return
        p["active_slot"] = 0
        p["reload_timer"] = 0.0
        weapon_id = WEAPON_SIDEARM
        active_slot = 0
        ui_status = "AMMO EMPTY — SWITCHED TO SIDEARM"
    var profile := _weapon_profile(weapon_id)
    var now := Time.get_ticks_msec()
    var shot_delay := int(profile["interval_ms"])
    var cooldown_ms := shot_delay if id == local_player_id else maxi(70, shot_delay - mini(60, shot_delay / 4))
    if now - int(fire_cooldowns.get(id, 0)) < cooldown_ms:
        players[id] = p
        return
    fire_cooldowns[id] = now
    p["ammo"] = -1
    p["shoot_timer"] = 0.19 if weapon_id == WEAPON_SIDEARM else 0.14
    if weapon_id != WEAPON_SIDEARM:
        _set_slot_ammo(p, active_slot, _slot_mag(p, active_slot) - 1, _slot_reserve(p, active_slot))
    players[id] = p
    _emit_sfx("shot", id)

    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.5)))
    var facing := Vector2.LEFT if float(p.get("face_x", 1.0)) < 0.0 else Vector2.RIGHT
    var muzzle := player_pos + facing * 24.0 + Vector2(0.0, 7.0)
    var shot_range := minf(float(profile["range"]), screen_size.x * 0.90)
    var closest_index := -1
    var closest_projection := shot_range
    var target_pos := player_pos + facing * shot_range
    if weapon_id == WEAPON_SHOTGUN:
        _add_combat_effect(0, muzzle, muzzle, 0.18, id)
        var pellet_hits: Dictionary = {}
        var pellet_impact: Dictionary = {}
        for spread in SHOTGUN_PELLET_OFFSETS:
            var pellet_index := -1
            var pellet_projection := shot_range
            for zi in range(zombies.size()):
                var zombie: Dictionary = zombies[zi]
                var zombie_pos := Vector2(float(zombie.get("x", 0.0)), float(zombie.get("y", 0.0)))
                var offset := zombie_pos - player_pos
                var projection := offset.dot(facing)
                if projection > 16.0 and projection <= pellet_projection and absf(offset.y - spread) <= float(profile["lane"]) * 0.75:
                    pellet_projection = projection
                    pellet_index = zi
            var pellet_end := player_pos + facing * pellet_projection + Vector2(0.0, -5.0 + spread)
            _add_combat_effect(10, muzzle + Vector2(0.0, spread * 0.35), pellet_end, 0.14, id)
            if pellet_index >= 0:
                pellet_hits[pellet_index] = int(pellet_hits.get(pellet_index, 0)) + 1
                var hit_zombie: Dictionary = zombies[pellet_index]
                pellet_impact[pellet_index] = Vector2(float(hit_zombie.get("x", pellet_end.x)), float(hit_zombie.get("y", pellet_end.y)))
        var hit_indices: Array = pellet_hits.keys()
        hit_indices.sort()
        hit_indices.reverse()
        for hit_index_value in hit_indices:
            var hit_index := int(hit_index_value)
            var hit_count := int(pellet_hits[hit_index])
            _apply_weapon_damage(hit_index, float(profile["damage"]) * float(hit_count), pellet_impact[hit_index])
    else:
        for zi in range(zombies.size()):
            var zombie: Dictionary = zombies[zi]
            var zombie_pos := Vector2(float(zombie.get("x", 0.0)), float(zombie.get("y", 0.0)))
            var offset := zombie_pos - player_pos
            var projection := offset.dot(facing)
            if projection > 16.0 and projection <= closest_projection and absf(offset.y) <= float(profile["lane"]):
                closest_projection = projection
                closest_index = zi
        if closest_index >= 0:
            var closest_zombie: Dictionary = zombies[closest_index]
            target_pos = Vector2(float(closest_zombie.get("x", target_pos.x)), float(closest_zombie.get("y", player_pos.y)))
        else:
            target_pos = player_pos + facing * shot_range
        var tracer_end := Vector2(target_pos.x, player_pos.y + 7.0)
        _add_combat_effect(0, muzzle, muzzle, 0.13 if weapon_id != WEAPON_SNIPER else 0.22, id)
        if weapon_id == WEAPON_ROCKET:
            var travel_time := clampf(player_pos.distance_to(target_pos) / 920.0, 0.16, 0.44)
            _add_combat_effect(12, muzzle, tracer_end, travel_time, id)
            active_projectiles.append({"kind": "rocket", "owner_id": id, "target": target_pos, "timer": travel_time, "damage": float(profile["damage"]), "radius": float(profile["radius"])})
        else:
            _add_combat_effect(int(profile["effect"]), muzzle, tracer_end, 0.12 if weapon_id == WEAPON_SMG else (0.22 if weapon_id == WEAPON_SNIPER else 0.16), id)
            if closest_index >= 0:
                _add_combat_effect(2, target_pos, target_pos, 0.18)
                _add_combat_effect(3, target_pos, Vector2(target_pos.x, player_pos.y + 7.0), 0.26)
                _apply_weapon_damage(closest_index, float(profile["damage"]), target_pos)
    if weapon_id != WEAPON_SIDEARM and _slot_mag(p, active_slot) <= 0 and _slot_reserve(p, active_slot) > 0:
        _start_weapon_reload(p, active_slot)
    elif weapon_id != WEAPON_SIDEARM and _slot_mag(p, active_slot) <= 0 and _slot_reserve(p, active_slot) <= 0:
        p["active_slot"] = 0
        p["reload_timer"] = 0.0
        ui_status = "AMMO EMPTY — SIDEARM READY"
    players[id] = p

func _update_projectiles(delta: float) -> void:
    for projectile_index in range(active_projectiles.size() - 1, -1, -1):
        var projectile: Dictionary = active_projectiles[projectile_index]
        var timer := float(projectile.get("timer", 0.0)) - delta
        projectile["timer"] = timer
        if timer > 0.0:
            active_projectiles[projectile_index] = projectile
            continue
        var blast_pos: Vector2 = projectile.get("target", Vector2.ZERO)
        var blast_radius := float(projectile.get("radius", 86.0))
        _add_combat_effect(6, blast_pos, blast_pos, 1.1)
        _emit_sfx("explosion")
        for zombie_index in range(zombies.size() - 1, -1, -1):
            var zombie: Dictionary = zombies[zombie_index]
            var zombie_pos := Vector2(float(zombie.get("x", 0.0)), float(zombie.get("y", 0.0)))
            var distance := zombie_pos.distance_to(blast_pos)
            if distance > blast_radius:
                continue
            var falloff := clampf(1.0 - 0.35 * distance / maxf(1.0, blast_radius), 0.55, 1.0)
            zombie["hp"] = float(zombie.get("hp", 1.0)) - float(projectile.get("damage", 8.0)) * falloff
            zombie["hit_timer"] = 0.28
            _add_combat_effect(2, zombie_pos, zombie_pos, 0.2)
            if float(zombie["hp"]) <= 0.0:
                _add_combat_effect(4, zombie_pos, zombie_pos, 0.32)
                wave_kills = mini(wave_total, wave_kills + 1)
                zombies.remove_at(zombie_index)
                _emit_sfx("death")
            else:
                zombies[zombie_index] = zombie
        active_projectiles.remove_at(projectile_index)

@rpc("any_peer", "call_remote", "reliable")
func request_heal() -> void:
    if not is_host:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if players.has(sender_id):
        _host_heal(sender_id)

@rpc("any_peer", "call_remote", "reliable")
func request_grenade(target_x_ratio: float, target_y_ratio: float) -> void:
    if not is_host:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if players.has(sender_id):
        _host_throw_grenade(sender_id, target_x_ratio, target_y_ratio)

@rpc("any_peer", "call_remote", "reliable")
func request_build_wall(x_ratio: float, y_ratio: float) -> void:
    if not is_host:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if players.has(sender_id):
        _host_build_wall(sender_id, x_ratio, y_ratio)

@rpc("any_peer", "call_remote", "reliable")
func request_build_turret(x_ratio: float, y_ratio: float) -> void:
    if not is_host:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if players.has(sender_id):
        _host_build_turret(sender_id, x_ratio, y_ratio)

func _host_heal(id: int) -> void:
    if game_over or not players.has(id):
        return
    var now := Time.get_ticks_msec()
    if now - int(heal_cooldowns.get(id, 0)) < 500:
        return
    var p: Dictionary = players[id]
    if float(p.get("hp", 0.0)) <= 0.0 or int(p.get("medkits", 0)) <= 0 or float(p.get("hp", 0.0)) >= 100.0:
        ui_status = "No medkits or HP is already full"
        return
    heal_cooldowns[id] = now
    p["hp"] = minf(100.0, float(p.get("hp", 0.0)) + 35.0)
    p["medkits"] = int(p.get("medkits", 0)) - 1
    players[id] = p
    _emit_sfx("heal")
    _broadcast_world()

func _host_throw_grenade(id: int, target_x_ratio: float, target_y_ratio: float) -> void:
    if game_over or not players.has(id):
        return
    var now := Time.get_ticks_msec()
    if now - int(grenade_cooldowns.get(id, 0)) < 320:
        return
    var p: Dictionary = players[id]
    if float(p.get("hp", 0.0)) <= 0.0:
        return
    var count := int(p.get("grenades", 0))
    if count <= 0:
        ui_status = "No grenades — collect a supply drop"
        return

    var origin := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))
    var facing := -1.0 if float(p.get("face_x", 1.0)) < 0.0 else 1.0
    var min_distance: float = screen_size.x * GRENADE_MIN_RANGE_RATIO
    var max_distance: float = screen_size.x * GRENADE_MAX_RANGE_RATIO
    var target := Vector2(
        clampf(target_x_ratio * screen_size.x, 30.0, maxf(31.0, screen_size.x - 30.0)),
        clampf(target_y_ratio * screen_size.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    var aim_vector: Vector2 = target - origin
    if aim_vector.length() < 1.0:
        aim_vector = Vector2(facing, 0.0)
    var throw_direction: Vector2 = aim_vector.normalized()
    var requested_distance: float = clampf(aim_vector.length(), min_distance, max_distance)
    target = origin + throw_direction * requested_distance
    target = Vector2(
        clampf(target.x, 30.0, maxf(31.0, screen_size.x - 30.0)),
        clampf(target.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    var range_pixels: float = origin.distance_to(target)
    var travel_time: float = lerpf(0.38, 0.82, clampf(range_pixels / maxf(1.0, max_distance), 0.0, 1.0))
    var launch_pos: Vector2 = origin + throw_direction * 18.0 + Vector2(0.0, -9.0)
    p["grenades"] = count - 1
    p["ammo"] = -1
    players[id] = p
    grenade_cooldowns[id] = now
    active_grenades.append({
        "id": randi(),
        "owner_id": id,
        "start_x": launch_pos.x,
        "start_y": launch_pos.y,
        "target_x": target.x,
        "target_y": target.y,
        "x": launch_pos.x,
        "y": launch_pos.y,
        "elapsed": 0.0,
        "travel_time": travel_time,
        "flight_height": clampf(range_pixels * 0.30, 44.0, 116.0),
        "fuse": travel_time + 0.42
    })
    _emit_sfx("grenade_throw")
    ui_status = "GRENADE OUT — range %.1f m" % (range_pixels / 45.0)
    _broadcast_world()

func _host_build_wall(id: int, x_ratio: float, y_ratio: float) -> void:
    if game_over or not players.has(id):
        return
    var now := Time.get_ticks_msec()
    if now - int(build_cooldowns.get(id, 0)) < 420:
        return
    var p: Dictionary = players[id]
    if float(p.get("hp", 0.0)) <= 0.0:
        ui_status = "Cannot build while eliminated"
        return
    if barricades.size() >= MAX_BARRICADES:
        ui_status = "Barricade limit reached — let the horde destroy one first"
        return
    if int(p.get("wall_kits", 0)) <= 0:
        ui_status = "No wall kits — find a supply drop"
        return
    var wall_pos := Vector2(
        clampf(x_ratio * screen_size.x, 44.0, maxf(45.0, screen_size.x - 44.0)),
        clampf(y_ratio * screen_size.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    if not _wall_placement_is_valid(id, wall_pos):
        ui_status = "Invalid wall spot — move it closer to the squad and away from other walls"
        return
    p["wall_kits"] = int(p.get("wall_kits", 0)) - 1
    p["ammo"] = -1
    players[id] = p
    build_cooldowns[id] = now
    barricades.append({"id": randi(), "x": wall_pos.x, "y": wall_pos.y, "hp": 125.0, "max_hp": 125.0, "owner_id": id})
    _emit_sfx("wall_build")
    ui_status = "BARRICADE DEPLOYED — zombies must break through it"
    _broadcast_world()

func _wall_placement_is_valid(id: int, wall_pos: Vector2) -> bool:
    if not players.has(id):
        return false
    var p: Dictionary = players[id]
    if float(p.get("hp", 0.0)) <= 0.0 or int(p.get("wall_kits", 0)) <= 0:
        return false
    if barricades.size() >= MAX_BARRICADES:
        return false
    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))
    if player_pos.distance_to(wall_pos) < WALL_MIN_PLAYER_DISTANCE:
        return false
    if player_pos.distance_to(wall_pos) > screen_size.x * WALL_PLACE_RANGE_RATIO:
        return false
    if wall_pos.y < _arena_top() + ARENA_TOP_CLEARANCE or wall_pos.y > _arena_bottom() - ARENA_BOTTOM_CLEARANCE:
        return false
    for existing in barricades:
        var existing_pos := Vector2(float(existing.get("x", 0.0)), float(existing.get("y", 0.0)))
        var separation_x: float = absf(existing_pos.x - wall_pos.x)
        var separation_y: float = absf(existing_pos.y - wall_pos.y)
        # Test actual row spacing: horizontal neighbours keep a 4 px join gap, while the
        # lower row can overlap the upper sprite by depth and render naturally in front.
        if separation_x < BARRICADE_RECT_SIZE.x + BARRICADE_JOIN_GAP and separation_y < BARRICADE_VERTICAL_SPACING:
            return false
    return true

func _next_turret_id() -> int:
    var candidate: int = posmod(turret_sequence, 65535) + 1
    var attempts := 0
    while attempts < 65535:
        var occupied := false
        for turret in turrets:
            if int(turret.get("id", -1)) == candidate:
                occupied = true
                break
        if not occupied:
            turret_sequence = posmod(candidate, 65535) + 1
            return candidate
        candidate = posmod(candidate, 65535) + 1
        attempts += 1
    return randi() & 0xFFFF

func _turret_placement_is_valid(id: int, turret_pos: Vector2) -> bool:
    if not players.has(id) or turrets.size() >= MAX_TURRETS:
        return false
    var p: Dictionary = players[id]
    if float(p.get("hp", 0.0)) <= 0.0 or int(p.get("turret_kits", 0)) <= 0:
        return false
    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))
    var placement_distance := player_pos.distance_to(turret_pos)
    if placement_distance < TURRET_MIN_PLAYER_DISTANCE or placement_distance > screen_size.x * TURRET_PLACE_RANGE_RATIO:
        return false
    if turret_pos.x < 35.0 or turret_pos.x > screen_size.x - 35.0:
        return false
    if turret_pos.y < _arena_top() + ARENA_TOP_CLEARANCE or turret_pos.y > _arena_bottom() - ARENA_BOTTOM_CLEARANCE:
        return false
    for turret in turrets:
        var other_pos := Vector2(float(turret.get("x", 0.0)), float(turret.get("y", 0.0)))
        if turret_pos.distance_to(other_pos) < TURRET_BASE_SPACING:
            return false
    for wall in barricades:
        var wall_pos := Vector2(float(wall.get("x", 0.0)), float(wall.get("y", 0.0)))
        if turret_pos.distance_to(wall_pos) < TURRET_WALL_SPACING:
            return false
    return true

func _host_build_turret(id: int, x_ratio: float, y_ratio: float) -> void:
    if game_over or not players.has(id):
        return
    var now := Time.get_ticks_msec()
    if now - int(build_cooldowns.get(id, 0)) < 520:
        return
    var p: Dictionary = players[id]
    var turret_pos := Vector2(
        clampf(x_ratio * screen_size.x, 35.0, maxf(36.0, screen_size.x - 35.0)),
        clampf(y_ratio * screen_size.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    if not _turret_placement_is_valid(id, turret_pos):
        if int(p.get("turret_kits", 0)) <= 0:
            ui_status = "NO TURRET KIT — secure an airdrop"
        elif turrets.size() >= MAX_TURRETS:
            ui_status = "TURRET LIMIT REACHED — only four can be deployed"
        else:
            ui_status = "INVALID TURRET SPOT — keep the circle clear and in range"
        return
    p["turret_kits"] = maxi(0, int(p.get("turret_kits", 0)) - 1)
    players[id] = p
    build_cooldowns[id] = now
    var turret_id := _next_turret_id()
    turrets.append({"id": turret_id, "x": turret_pos.x, "y": turret_pos.y, "hp": TURRET_MAX_HP, "max_hp": TURRET_MAX_HP, "angle": 0.0, "fire_timer": 0.25, "flash_timer": 0.0, "owner_id": id})
    _emit_sfx("wall_build")
    ui_status = "AUTO TURRET DEPLOYED • RANGE 270 • ZOMBIES CAN DESTROY IT"
    _broadcast_world()

func _set_turret_preview_from_pointer(pointer_pos: Vector2) -> void:
    if not players.has(local_player_id):
        return
    var p: Dictionary = players[local_player_id]
    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))
    var desired := Vector2(
        clampf(pointer_pos.x, 35.0, maxf(36.0, screen_size.x - 35.0)),
        clampf(pointer_pos.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    var from_player := desired - player_pos
    var max_distance: float = screen_size.x * TURRET_PLACE_RANGE_RATIO
    if from_player.length() > max_distance:
        desired = player_pos + from_player.normalized() * max_distance
    turret_preview_position = Vector2(
        clampf(desired.x, 35.0, maxf(36.0, screen_size.x - 35.0)),
        clampf(desired.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )

func _begin_turret_placement(touch_id: int = -1) -> void:
    var p: Dictionary = players.get(local_player_id, {})
    if p.is_empty() or int(p.get("turret_kits", 0)) <= 0:
        ui_status = "NO TURRET KIT — collect the marked airdrop"
        return
    if turrets.size() >= MAX_TURRETS:
        ui_status = "TURRET LIMIT REACHED — only four can be deployed"
        return
    grenade_aim_active = false
    grenade_aim_touch_id = -1
    grenade_requested = false
    wall_place_active = false
    wall_place_touch_id = -1
    build_requested = false
    turret_requested = false
    turret_place_active = true
    turret_place_touch_id = touch_id
    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))
    var face: float = -1.0 if float(p.get("face_x", 1.0)) < 0.0 else 1.0
    turret_preview_position = Vector2(
        clampf(player_pos.x + face * 88.0, 35.0, maxf(36.0, screen_size.x - 35.0)),
        clampf(player_pos.y + 6.0, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    ui_status = "HOLD & DRAG TURRET • GREEN CIRCLE VALID • RELEASE TO DEPLOY"

func _draw_turret_placement_preview() -> void:
    var valid: bool = _turret_placement_is_valid(local_player_id, turret_preview_position)
    var radius := TURRET_RANGE
    if not is_host:
        radius *= screen_size.x / maxf(1.0, host_world_w)
    var fill := Color(0.36, 0.80, 0.40, 0.10) if valid else Color(0.92, 0.30, 0.22, 0.10)
    var line_color := Color("#92d578", 0.84) if valid else Color("#e46e58", 0.92)
    var ring_points := PackedVector2Array()
    for point_index in range(48):
        var angle := TAU * float(point_index) / 48.0
        ring_points.append(turret_preview_position + Vector2(cos(angle), sin(angle)) * radius)
    draw_colored_polygon(ring_points, fill)
    draw_arc(turret_preview_position, radius, 0.0, TAU, 80, line_color, 1.5, true)
    draw_arc(turret_preview_position, 28.0, 0.0, TAU, 32, Color(line_color.r, line_color.g, line_color.b, 0.55), 1.0, true)
    _draw_turret_entity({"id": -1, "x": turret_preview_position.x, "y": turret_preview_position.y, "hp": TURRET_MAX_HP, "max_hp": TURRET_MAX_HP, "angle": 0.0, "flash_timer": 0.0}, true, valid)
    var note := "RANGE 270  •  RELEASE TO DEPLOY" if valid else "BLOCKED / OUT OF RANGE"
    draw_rect(Rect2(turret_preview_position.x - 93.0, turret_preview_position.y - 70.0, 186.0, 17.0), Color(0.008, 0.012, 0.014, 0.82))
    draw_string(ui_font, Vector2(turret_preview_position.x - 90.0, turret_preview_position.y - 58.0), note, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 9, line_color)

func _draw_turret_entity(turret: Dictionary, is_preview: bool = false, is_valid: bool = true) -> void:
    var pos := Vector2(float(turret.get("x", 0.0)), float(turret.get("y", 0.0)))
    var max_hp := maxf(1.0, float(turret.get("max_hp", TURRET_MAX_HP)))
    var hp_ratio := clampf(float(turret.get("hp", max_hp)) / max_hp, 0.0, 1.0)
    var alpha := 0.48 if is_preview else 1.0
    var steel := Color("#4d5148", alpha)
    var dark := Color("#1c2423", alpha)
    var edge := Color("#8c8d79", alpha)
    var bronze := Color("#7e6547", alpha)
    if is_preview and not is_valid:
        steel = steel.lerp(Color("#8b3439", alpha), 0.48)
        edge = edge.lerp(Color("#e35a55", alpha), 0.62)
    draw_ellipse_shadow(pos + Vector2(0.0, 30.0), 29.0, 6.0, 0.40 * alpha)
    # Tripod feet and hinged support legs.
    for foot in [Vector2(-24.0, 28.0), Vector2(24.0, 28.0), Vector2(0.0, 32.0)]:
        var knee := Vector2(0.0, -1.0).lerp(foot, 0.57) + Vector2(0.0, 4.0)
        draw_line(pos + Vector2(0.0, 2.0), pos + knee, dark, 7.0, true)
        draw_line(pos + Vector2(0.0, 2.0), pos + knee, steel, 4.0, true)
        draw_line(pos + knee, pos + foot, dark, 6.0, true)
        draw_line(pos + knee, pos + foot, edge, 3.0, true)
        draw_circle(pos + knee, 3.2, dark)
        draw_circle(pos + knee, 1.5, bronze)
        draw_rect(Rect2(pos + foot - Vector2(5.0, 1.5), Vector2(10.0, 3.0)), dark)
        draw_rect(Rect2(pos + foot - Vector2(4.0, 1.0), Vector2(8.0, 1.0)), bronze)
    draw_rect(Rect2(pos + Vector2(-9.0, -7.0), Vector2(18.0, 20.0)), dark)
    draw_rect(Rect2(pos + Vector2(-7.0, -7.0), Vector2(14.0, 17.0)), steel)
    draw_rect(Rect2(pos + Vector2(-4.0, -4.0), Vector2(8.0, 4.0)), bronze)
    var pivot := pos + Vector2(0.0, -24.0)
    var raw_angle: float = float(turret.get("angle", 0.0))
    var flip_x: float = -1.0 if cos(raw_angle) < 0.0 else 1.0
    var draw_angle: float = wrapf(raw_angle - PI, -PI, PI) if flip_x < 0.0 else raw_angle
    draw_set_transform(pivot, draw_angle, Vector2(flip_x, 1.0))
    draw_rect(Rect2(-14.0, -8.0, 31.0, 15.0), dark)
    draw_rect(Rect2(-12.0, -7.0, 26.0, 12.0), steel)
    draw_rect(Rect2(-9.0, -10.0, 15.0, 4.0), edge)
    draw_rect(Rect2(-4.0, -12.0, 9.0, 4.0), bronze)
    # Brief recoil retracts the barrel slightly on each synchronized shot.
    var firing_flash: float = clampf(float(turret.get("flash_timer", 0.0)) / 0.075, 0.0, 1.0)
    var barrel_kick: float = firing_flash * 2.2
    draw_rect(Rect2(8.0 - barrel_kick, -3.0, 27.0, 5.0), dark)
    draw_rect(Rect2(11.0 - barrel_kick, -2.0, 24.0, 3.0), edge)
    draw_rect(Rect2(17.0 - barrel_kick, -5.0, 11.0, 9.0), bronze)
    draw_rect(Rect2(31.0 - barrel_kick, -2.0, 4.0, 3.0), dark)
    if firing_flash > 0.01:
        draw_colored_polygon(PackedVector2Array([Vector2(36.0, 0.0), Vector2(44.0, -5.0), Vector2(41.0, 0.0), Vector2(44.0, 5.0)]), Color("#ffc86b", alpha * firing_flash))
        draw_circle(Vector2(37.0, 0.0), 2.5 * firing_flash, Color("#fff0ac", alpha * firing_flash))
    draw_circle(Vector2(-5.0, -1.0), 3.5, dark)
    draw_circle(Vector2(-5.0, -1.0), 1.8, bronze)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    if not is_preview:
        var hp_rect := Rect2(pos.x - 23.0, pos.y - 53.0, 46.0, 4.0)
        draw_rect(Rect2(hp_rect.position - Vector2(1.0, 1.0), hp_rect.size + Vector2(2.0, 2.0)), Color(0.01, 0.012, 0.014, 0.90))
        draw_rect(hp_rect, Color("#402a26"))
        draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * hp_ratio, hp_rect.size.y)), Color("#8ec477") if hp_ratio > 0.4 else Color("#d35d4c"))
        if hp_ratio < 0.32:
            var smoke_offset: float = sin(animation_clock * 7.0 + float(int(turret.get("id", 0)))) * 2.0
            draw_circle(pos + Vector2(-7.0, -38.0 + smoke_offset), 2.4, Color(0.16, 0.17, 0.15, 0.50))
            draw_circle(pos + Vector2(1.0, -42.0 - smoke_offset), 3.0, Color(0.20, 0.19, 0.17, 0.34))

func _update_turrets(delta: float) -> void:
    for turret_index in range(turrets.size() - 1, -1, -1):
        var turret: Dictionary = turrets[turret_index]
        turret["fire_timer"] = maxf(0.0, float(turret.get("fire_timer", 0.0)) - delta)
        turret["flash_timer"] = maxf(0.0, float(turret.get("flash_timer", 0.0)) - delta)
        var turret_pos := Vector2(float(turret.get("x", 0.0)), float(turret.get("y", 0.0)))
        var target_index := -1
        var nearest_distance: float = TURRET_RANGE
        for zombie_index in range(zombies.size()):
            var zombie: Dictionary = zombies[zombie_index]
            var zombie_pos := Vector2(float(zombie.get("x", 0.0)), float(zombie.get("y", 0.0)))
            var distance := turret_pos.distance_to(zombie_pos)
            if distance < nearest_distance:
                nearest_distance = distance
                target_index = zombie_index
        var desired_angle: float = sin(world_time * 0.63 + float(int(turret.get("id", 0)))) * 0.10
        var target_pos := turret_pos + Vector2.RIGHT * TURRET_RANGE
        if target_index >= 0:
            target_pos = Vector2(float(zombies[target_index].get("x", 0.0)), float(zombies[target_index].get("y", 0.0)) - 11.0)
            desired_angle = (target_pos - (turret_pos + Vector2(0.0, -24.0))).angle()
        var current_angle: float = float(turret.get("angle", 0.0))
        var angle_delta: float = wrapf(desired_angle - current_angle, -PI, PI)
        current_angle += clampf(angle_delta, -TURRET_TURN_SPEED * delta, TURRET_TURN_SPEED * delta)
        turret["angle"] = wrapf(current_angle, -PI, PI)
        if target_index >= 0 and absf(angle_delta) < 0.30 and float(turret.get("fire_timer", 0.0)) <= 0.0:
            var target: Dictionary = zombies[target_index]
            target["hp"] = float(target.get("hp", 1.0)) - TURRET_DAMAGE
            target["hit_timer"] = 0.10
            zombies[target_index] = target
            var muzzle := turret_pos + Vector2(0.0, -24.0) + Vector2(cos(current_angle), sin(current_angle)) * 37.0
            _add_combat_effect(14, muzzle, target_pos, 0.12)
            turret["fire_timer"] = TURRET_FIRE_INTERVAL
            turret["flash_timer"] = 0.075
            if float(target.get("hp", 0.0)) <= 0.0:
                _add_combat_effect(4, target_pos, target_pos, 0.32)
                zombies.remove_at(target_index)
                wave_kills = mini(wave_total, wave_kills + 1)
                _emit_sfx("death")
        turrets[turret_index] = turret

func _snap_wall_preview_to_neighbour(desired: Vector2, player_pos: Vector2) -> Vector2:
    # Snap horizontal chains to the 4 px visual join gap and vertical rows to a much tighter
    # 60 px lane step. Lower rows are depth-sorted in front, so their sprite can naturally
    # overlap the upper row without looking like two isolated walls.
    var best_position := desired
    var best_error := 46.0
    var snap_spacing: float = BARRICADE_RECT_SIZE.x + BARRICADE_JOIN_GAP
    var vertical_spacing: float = BARRICADE_VERTICAL_SPACING
    var max_distance: float = screen_size.x * WALL_PLACE_RANGE_RATIO
    for existing in barricades:
        var existing_pos := Vector2(float(existing.get("x", 0.0)), float(existing.get("y", 0.0)))
        var delta_to_desired := desired - existing_pos

        # Horizontal neighbour: inherit the exact lane depth.
        if absf(delta_to_desired.y) <= 44.0 and absf(delta_to_desired.x) >= 38.0 and absf(delta_to_desired.x) <= 112.0:
            var side_x := -1.0 if delta_to_desired.x < 0.0 else 1.0
            var horizontal_candidate := Vector2(existing_pos.x + side_x * snap_spacing, existing_pos.y)
            horizontal_candidate.x = clampf(horizontal_candidate.x, 44.0, maxf(45.0, screen_size.x - 44.0))
            horizontal_candidate.y = clampf(horizontal_candidate.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
            var horizontal_error: float = desired.distance_to(horizontal_candidate)
            if horizontal_error < best_error and player_pos.distance_to(horizontal_candidate) >= WALL_MIN_PLAYER_DISTANCE and player_pos.distance_to(horizontal_candidate) <= max_distance:
                best_position = horizontal_candidate
                best_error = horizontal_error

        # Vertical neighbour: align x with a nearby barricade and reduce the old oversized row gap.
        if absf(delta_to_desired.x) <= 48.0 and absf(delta_to_desired.y) >= 24.0 and absf(delta_to_desired.y) <= vertical_spacing * 2.0:
            var side_y := -1.0 if delta_to_desired.y < 0.0 else 1.0
            var vertical_candidate := Vector2(existing_pos.x, existing_pos.y + side_y * vertical_spacing)
            vertical_candidate.x = clampf(vertical_candidate.x, 44.0, maxf(45.0, screen_size.x - 44.0))
            vertical_candidate.y = clampf(vertical_candidate.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
            var vertical_error: float = desired.distance_to(vertical_candidate)
            if vertical_error < best_error and player_pos.distance_to(vertical_candidate) >= WALL_MIN_PLAYER_DISTANCE and player_pos.distance_to(vertical_candidate) <= max_distance:
                best_position = vertical_candidate
                best_error = vertical_error
    return best_position

func _set_wall_preview_from_pointer(pointer_pos: Vector2) -> void:
    if not players.has(local_player_id):
        return
    var p: Dictionary = players[local_player_id]
    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))
    var desired := Vector2(
        clampf(pointer_pos.x, 44.0, maxf(45.0, screen_size.x - 44.0)),
        clampf(pointer_pos.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    var offset := desired - player_pos
    var max_distance: float = screen_size.x * WALL_PLACE_RANGE_RATIO
    if offset.length() > max_distance:
        desired = player_pos + offset.normalized() * max_distance
    var clamped_desired := Vector2(
        clampf(desired.x, 44.0, maxf(45.0, screen_size.x - 44.0)),
        clampf(desired.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    wall_preview_position = _snap_wall_preview_to_neighbour(clamped_desired, player_pos)

func _begin_grenade_aim(touch_id: int = -1) -> void:
    var p: Dictionary = players.get(local_player_id, {})
    if p.is_empty() or int(p.get("grenades", 0)) <= 0:
        ui_status = "No grenades — collect a supply drop"
        return
    wall_place_active = false
    wall_place_touch_id = -1
    build_requested = false
    turret_place_active = false
    turret_place_touch_id = -1
    turret_requested = false
    grenade_requested = false
    grenade_aim_active = true
    grenade_aim_touch_id = touch_id
    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))
    var face := -1.0 if float(p.get("face_x", 1.0)) < 0.0 else 1.0
    grenade_aim_target_position = Vector2(
        clampf(player_pos.x + face * _grenade_range_pixels(), 30.0, maxf(31.0, screen_size.x - 30.0)),
        clampf(player_pos.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    ui_status = "HOLD & DRAG GREN • RELEASE TO THROW"

func _update_grenade_target_from_pointer(pointer_pos: Vector2) -> void:
    if not players.has(local_player_id):
        return
    var p: Dictionary = players[local_player_id]
    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))
    var pointer_target := Vector2(
        clampf(pointer_pos.x, 30.0, maxf(31.0, screen_size.x - 30.0)),
        clampf(pointer_pos.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    var aim_vector: Vector2 = pointer_target - player_pos
    var min_distance: float = screen_size.x * GRENADE_MIN_RANGE_RATIO
    var max_distance: float = screen_size.x * GRENADE_MAX_RANGE_RATIO
    var facing := -1.0 if float(p.get("face_x", 1.0)) < 0.0 else 1.0
    if aim_vector.length() < 1.0:
        aim_vector = Vector2(facing, 0.0)
    var aim_direction: Vector2 = aim_vector.normalized()
    var aim_distance: float = clampf(aim_vector.length(), min_distance, max_distance)
    grenade_aim_target_position = player_pos + aim_direction * aim_distance
    grenade_aim_target_position = Vector2(
        clampf(grenade_aim_target_position.x, 30.0, maxf(31.0, screen_size.x - 30.0)),
        clampf(grenade_aim_target_position.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    grenade_aim_range_ratio = clampf(player_pos.distance_to(grenade_aim_target_position) / maxf(1.0, screen_size.x), GRENADE_MIN_RANGE_RATIO, GRENADE_MAX_RANGE_RATIO)

func _begin_wall_placement(touch_id: int = -1) -> void:
    grenade_aim_active = false
    grenade_aim_touch_id = -1
    grenade_requested = false
    turret_place_active = false
    turret_place_touch_id = -1
    turret_requested = false
    wall_place_active = true
    wall_place_touch_id = touch_id
    build_requested = false
    if players.has(local_player_id):
        var p: Dictionary = players[local_player_id]
        var face := -1.0 if float(p.get("face_x", 1.0)) < 0.0 else 1.0
        wall_preview_position = Vector2(
            clampf(float(p.get("x", screen_size.x * 0.5)) + face * 78.0, 44.0, maxf(45.0, screen_size.x - 44.0)),
            clampf(float(p.get("y", screen_size.y * 0.68)), _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
        )
    ui_status = "HOLD & DRAG WALL • RELEASE TO DEPLOY"

func _cancel_targeting_modes() -> void:
    grenade_aim_active = false
    grenade_aim_touch_id = -1
    wall_place_active = false
    wall_place_touch_id = -1
    turret_place_active = false
    turret_place_touch_id = -1
    turret_requested = false
    grenade_requested = false
    build_requested = false

func _find_blocking_barricade(zombie_pos: Vector2, target_pos: Vector2) -> int:
    var travel_sign := signf(target_pos.x - zombie_pos.x)
    if absf(travel_sign) < 0.1:
        return -1
    var selected_index := -1
    var selected_distance := INF
    for wall_index in range(barricades.size()):
        var wall: Dictionary = barricades[wall_index]
        var wall_pos := Vector2(float(wall.get("x", 0.0)), float(wall.get("y", 0.0)))
        var dx := wall_pos.x - zombie_pos.x
        if absf(dx) < 1.0 or signf(dx) != travel_sign:
            continue
        if absf(dx) >= absf(target_pos.x - zombie_pos.x):
            continue
        if absf(wall_pos.y - zombie_pos.y) > WALL_LANE_TOLERANCE:
            continue
        if absf(dx) < selected_distance:
            selected_distance = absf(dx)
            selected_index = wall_index
    return selected_index

func _spawn_airdrop() -> void:
    var loot_roll := randi_range(0, 99)
    var loot_kind := "grenade"
    var quantity := randi_range(1, 2)
    var weapon_id := 0
    var squad_has_turret := not turrets.is_empty()
    for player_variant in players.keys():
        if int(players[int(player_variant)].get("turret_kits", 0)) > 0:
            squad_has_turret = true
    if (airdrop_sequence % 4 == 0 and not squad_has_turret) or loot_roll >= 96:
        loot_kind = "turret"
        quantity = 1
    elif loot_roll >= 88:
        var owned_weapon_types: Array[int] = []
        for player_variant in players.keys():
            var owned_player: Dictionary = players[int(player_variant)]
            for slot_index in [1, 2]:
                var owned_type := _slot_type(owned_player, slot_index)
                if owned_type >= WEAPON_SMG and owned_type <= WEAPON_ROCKET and _can_collect_ammo(owned_player, owned_type) and not owned_weapon_types.has(owned_type):
                    owned_weapon_types.append(owned_type)
        if owned_weapon_types.is_empty():
            # Avoid unusable ammo in a solo run where no limited-ammo gun has been found yet.
            loot_kind = "weapon"
            weapon_id = randi_range(WEAPON_SMG, WEAPON_ROCKET)
        else:
            loot_kind = "ammo"
            weapon_id = owned_weapon_types[randi_range(0, owned_weapon_types.size() - 1)]
        quantity = 1
    elif loot_roll >= 64:
        loot_kind = "weapon"
        weapon_id = randi_range(WEAPON_SMG, WEAPON_ROCKET)
        quantity = 1
    elif loot_roll >= 58:
        loot_kind = "medkit"
        quantity = 1
    elif loot_roll >= 40:
        loot_kind = "wall"
        quantity = randi_range(1, 2)
    var start_x := randf_range(58.0, maxf(59.0, screen_size.x - 58.0))
    var drop_y := randf_range(_arena_top() + 65.0, _arena_bottom() - 48.0)
    airdrops.append({
        "id": airdrop_sequence,
        "x": start_x,
        "y": _arena_top() - 18.0,
        "start_y": _arena_top() - 18.0,
        "land_y": drop_y,
        "elapsed": 0.0,
        "fall_duration": 2.6,
        "despawn_timer": AIRDROP_LAND_LIFETIME,
        "landed": false,
        "loot_kind": loot_kind,
        "quantity": quantity,
        "weapon_id": weapon_id
    })
    airdrop_sequence += 1
    ui_status = "SUPPLY DROP INCOMING — weapon, compatible ammo, or field supplies"
    _emit_sfx("airdrop_incoming")

func _grant_airdrop_loot(id: int, drop: Dictionary) -> void:
    if not players.has(id):
        return
    var p: Dictionary = players[id]
    var kind := str(drop.get("loot_kind", "grenade"))
    var quantity := maxi(1, int(drop.get("quantity", 1)))
    match kind:
        "grenade":
            var before_grenades := int(p.get("grenades", 0))
            p["grenades"] = mini(GRENADE_MAX_CARRY, before_grenades + quantity)
            var received_grenades := int(p["grenades"]) - before_grenades
            if received_grenades == 0:
                var old_medkits := int(p.get("medkits", 0))
                if old_medkits < MEDKIT_MAX_CARRY:
                    p["medkits"] = old_medkits + 1
                    ui_status = "Grenade pouch full — converted cache to +1 medkit"
                else:
                    p["hp"] = minf(100.0, float(p.get("hp", 100.0)) + 25.0)
                    ui_status = "Supply pouch full — +25 emergency HP"
            else:
                ui_status = "SUPPLY LOOT: +%d grenade(s)" % received_grenades
        "wall":
            var before_walls := int(p.get("wall_kits", 0))
            p["wall_kits"] = mini(WALL_KIT_MAX_CARRY, before_walls + quantity)
            var received_walls := int(p["wall_kits"]) - before_walls
            if received_walls == 0:
                var old_medkits := int(p.get("medkits", 0))
                if old_medkits < MEDKIT_MAX_CARRY:
                    p["medkits"] = old_medkits + 1
                    ui_status = "Wall kit capacity reached — converted cache to +1 medkit"
                else:
                    p["hp"] = minf(100.0, float(p.get("hp", 100.0)) + 25.0)
                    ui_status = "Supply pouch full — +25 emergency HP"
            else:
                ui_status = "SUPPLY LOOT: +%d wall kit(s)" % received_walls
        "medkit":
            var before_medkits := int(p.get("medkits", 2))
            p["medkits"] = mini(MEDKIT_MAX_CARRY, before_medkits + quantity)
            var received_medkits := int(p["medkits"]) - before_medkits
            if received_medkits == 0:
                var healed := minf(25.0, 100.0 - float(p.get("hp", 100.0)))
                p["hp"] = minf(100.0, float(p.get("hp", 100.0)) + 25.0)
                ui_status = "MEDKIT CAPACITY FULL — emergency +%.0f HP" % healed
            else:
                ui_status = "SUPPLY LOOT: +%d medkit(s)" % received_medkits
        "weapon":
            var weapon_drop_id := clampi(int(drop.get("weapon_id", WEAPON_SMG)), WEAPON_SMG, WEAPON_ROCKET)
            _give_weapon(p, weapon_drop_id)
            var active_weapon := _active_weapon_id(p)
            ui_status = "AIRDROP: %s · %d/%d" % [_weapon_name(active_weapon), _slot_mag(p, int(p.get("active_slot", 0))), _slot_reserve(p, int(p.get("active_slot", 0)))]
        "turret":
            var before_turrets := int(p.get("turret_kits", 0))
            p["turret_kits"] = mini(TURRET_KIT_MAX_CARRY, before_turrets + quantity)
            var received_turrets := int(p["turret_kits"]) - before_turrets
            if received_turrets > 0:
                ui_status = "SUPPLY LOOT: +%d AUTO TURRET KIT • HOLD & DRAG TUR" % received_turrets
            else:
                p["wall_kits"] = mini(WALL_KIT_MAX_CARRY, int(p.get("wall_kits", 0)) + 1)
                ui_status = "TURRET KIT CAPACITY FULL — converted to +1 wall kit"
        "ammo":
            var ammo_weapon_id := clampi(int(drop.get("weapon_id", WEAPON_SMG)), WEAPON_SMG, WEAPON_ROCKET)
            var ammo_slot := _find_weapon_slot(p, ammo_weapon_id)
            if ammo_slot <= 0:
                # A compatible-ammo drop is not consumed unless a squad member owns that weapon.
                ui_status = "AMMO CACHE: NEED %s" % _weapon_name(ammo_weapon_id)
                players[id] = p
                return
            var ammo_profile := _weapon_profile(ammo_weapon_id)
            var before_reserve := _slot_reserve(p, ammo_slot)
            var current_mag := _slot_mag(p, ammo_slot)
            var ammo_pack := int(ammo_profile["ammo_pack"])
            var received_reserve := mini(ammo_pack, maxi(0, int(ammo_profile["reserve_cap"]) - before_reserve))
            var leftover_pack := ammo_pack - received_reserve
            var received_magazine := mini(leftover_pack, maxi(0, int(ammo_profile["mag_size"]) - current_mag))
            _set_slot_ammo(p, ammo_slot, current_mag + received_magazine, before_reserve + received_reserve)
            if received_reserve > 0 or received_magazine > 0:
                p["active_slot"] = ammo_slot
                if received_reserve > 0 and received_magazine > 0:
                    ui_status = "AMMO CACHE: %s +%d reserve / +%d mag" % [_weapon_name(ammo_weapon_id), received_reserve, received_magazine]
                elif received_reserve > 0:
                    ui_status = "AMMO CACHE: %s +%d reserve" % [_weapon_name(ammo_weapon_id), received_reserve]
                else:
                    ui_status = "AMMO CACHE: %s +%d mag" % [_weapon_name(ammo_weapon_id), received_magazine]
            else:
                ui_status = "%s AMMO FULL" % _weapon_name(ammo_weapon_id)
    players[id] = p
    _emit_sfx("pickup")

func _update_airdrops(delta: float) -> void:
    airdrop_spawn_timer = maxf(0.0, airdrop_spawn_timer - delta)
    if airdrop_spawn_timer <= 0.0:
        if airdrops.size() < 2:
            _spawn_airdrop()
            airdrop_spawn_timer = randf_range(AIRDROP_INTERVAL_MIN, AIRDROP_INTERVAL_MAX)
        else:
            # Retry soon once a slot becomes available instead of silently losing an interval.
            airdrop_spawn_timer = AIRDROP_FULL_RETRY
    for drop_index in range(airdrops.size() - 1, -1, -1):
        var drop: Dictionary = airdrops[drop_index]
        var picked_up := false
        if not bool(drop.get("landed", false)):
            var elapsed := float(drop.get("elapsed", 0.0)) + delta
            var fall_duration := maxf(0.1, float(drop.get("fall_duration", 2.6)))
            var progress := clampf(elapsed / fall_duration, 0.0, 1.0)
            drop["elapsed"] = elapsed
            drop["y"] = lerpf(float(drop.get("start_y", _arena_top() - 18.0)), float(drop.get("land_y", _arena_top() + 70.0)), progress)
            if progress >= 1.0:
                drop["landed"] = true
                drop["y"] = float(drop.get("land_y", _arena_top() + 70.0))
                var landing_ground := Vector2(float(drop.get("x", 0.0)), float(drop["y"]) + 35.0)
                _add_combat_effect(8, landing_ground, landing_ground, AIRDROP_LANDING_EFFECT_DURATION)
                _emit_sfx("airdrop")
                ui_status = "SUPPLY DROP LANDED — smoke marking the cache"
        else:
            drop["despawn_timer"] = float(drop.get("despawn_timer", AIRDROP_LAND_LIFETIME)) - delta
            if float(drop["despawn_timer"]) <= 0.0:
                # The host removes the unclaimed crate and broadcasts a small dust/smoke puff.
                # Drop expiry is authoritative; clients only render the synchronized effect.
                var expired_pos := Vector2(float(drop.get("x", 0.0)), float(drop.get("y", 0.0)) + 35.0)
                _add_combat_effect(8, expired_pos, expired_pos, AIRDROP_DESPAWN_EFFECT_DURATION)
                airdrops.remove_at(drop_index)
                continue
            var drop_pos := Vector2(float(drop.get("x", 0.0)), float(drop.get("y", 0.0)))
            for id_variant in players.keys():
                var id := int(id_variant)
                var p: Dictionary = players[id]
                if float(p.get("hp", 0.0)) <= 0.0:
                    continue
                var player_pos := Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
                if player_pos.distance_to(drop_pos) <= 42.0:
                    var drop_kind := str(drop.get("loot_kind", "grenade"))
                    if drop_kind == "ammo" and not _can_collect_ammo(p, int(drop.get("weapon_id", WEAPON_SMG))):
                        continue # Wrong weapon or both reserve and magazine are already full: leave the cache in the world.
                    _grant_airdrop_loot(id, drop)
                    _add_combat_effect(7, drop_pos + Vector2(0.0, 35.0), drop_pos + Vector2(0.0, 35.0), 0.36)
                    airdrops.remove_at(drop_index)
                    picked_up = true
                    break
        if not picked_up:
            airdrops[drop_index] = drop

func _update_grenades(delta: float) -> void:
    for grenade_index in range(active_grenades.size() - 1, -1, -1):
        var grenade: Dictionary = active_grenades[grenade_index]
        var elapsed := float(grenade.get("elapsed", 0.0)) + delta
        var travel_time := maxf(0.05, float(grenade.get("travel_time", 0.46)))
        var progress := clampf(elapsed / travel_time, 0.0, 1.0)
        grenade["elapsed"] = elapsed
        grenade["x"] = lerpf(float(grenade.get("start_x", 0.0)), float(grenade.get("target_x", 0.0)), progress)
        grenade["y"] = lerpf(float(grenade.get("start_y", 0.0)), float(grenade.get("target_y", 0.0)), progress)
        grenade["fuse"] = float(grenade.get("fuse", 1.02)) - delta
        if float(grenade["fuse"]) <= 0.0:
            var blast_pos := Vector2(float(grenade.get("x", 0.0)), float(grenade.get("y", 0.0)))
            _add_combat_effect(6, blast_pos, blast_pos, GRENADE_EXPLOSION_EFFECT_DURATION)
            _emit_sfx("explosion")
            for zombie_index in range(zombies.size() - 1, -1, -1):
                var zombie: Dictionary = zombies[zombie_index]
                var zombie_pos := Vector2(float(zombie.get("x", 0.0)), float(zombie.get("y", 0.0)))
                if zombie_pos.distance_to(blast_pos) > GRENADE_BLAST_RADIUS:
                    continue
                zombie["hp"] = float(zombie.get("hp", 1.0)) - GRENADE_DAMAGE
                zombie["hit_timer"] = 0.28
                _add_combat_effect(2, zombie_pos, zombie_pos, 0.20)
                if float(zombie["hp"]) <= 0.0:
                    _add_combat_effect(4, zombie_pos, zombie_pos, 0.32)
                    wave_kills = mini(wave_total, wave_kills + 1)
                    zombies.remove_at(zombie_index)
                    _emit_sfx("death")
                else:
                    zombies[zombie_index] = zombie
            active_grenades.remove_at(grenade_index)
        else:
            active_grenades[grenade_index] = grenade

@rpc("any_peer", "call_remote", "reliable")
func request_restart() -> void:
    if not is_host or not game_over:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if players.has(sender_id):
        _restart_run()

func _restart_run() -> void:
    if not is_host:
        ui_status = "Only the host can restart this run."
        return
    player_death_visuals.clear()
    zombies.clear()
    airdrops.clear()
    barricades.clear()
    turrets.clear()
    active_grenades.clear()
    active_projectiles.clear()
    combat_effects.clear()
    input_vectors.clear()
    fire_cooldowns.clear()
    heal_cooldowns.clear()
    grenade_cooldowns.clear()
    build_cooldowns.clear()
    turret_sequence = 1
    airdrop_spawn_timer = AIRDROP_FIRST_DELAY
    airdrop_sequence = 1
    world_time = 0.0
    world_seed = randi()
    seed(world_seed)
    wave_number = 1
    wave_total = _zombie_count_for_wave(wave_number)
    wave_spawned = 0
    wave_kills = 0
    wave_spawn_timer = 1.1
    wave_break_timer = 0.0
    wave_time_remaining = _wave_duration_for(1)
    wave_timed_out = false
    game_over = false
    for id_variant in players.keys():
        var id := int(id_variant)
        var p: Dictionary = players[id]
        var spawn := Vector2(screen_size.x * 0.5, screen_size.y * 0.70) + Vector2(randf_range(-42.0, 42.0), randf_range(-12.0, 12.0))
        p["x"] = clampf(spawn.x, 35.0, maxf(36.0, screen_size.x - 35.0))
        p["y"] = clampf(spawn.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
        p["hp"] = 100.0
        p["medkits"] = 2
        p["ammo"] = -1
        p["grenades"] = 3
        p["wall_kits"] = 2
        p["turret_kits"] = 0
        p["active_slot"] = 0
        p["slot1_type"] = -1
        p["slot1_mag"] = 0
        p["slot1_reserve"] = 0
        p["slot2_type"] = -1
        p["slot2_mag"] = 0
        p["slot2_reserve"] = 0
        p["reload_timer"] = 0.0
        p["walking"] = false
        p["shoot_timer"] = 0.0
        p["hurt_timer"] = 0.0
        p["face_x"] = 1.0
        players[id] = p
        input_vectors[id] = Vector2.ZERO
    screen_mode = "game"
    ui_status = "Fresh run — Wave 01. The squad is back on its feet."
    fire_held = false
    fire_requested = false
    fire_touch_id = -1
    fire_repeat_timer = 0.0
    _cancel_targeting_modes()
    joystick_active = false
    joystick_touch_id = -1
    joystick_vector = Vector2.ZERO
    snapshot_timer = 0.0
    if not is_offline and multiplayer.multiplayer_peer != null:
        rpc("begin_game_remote")
    _broadcast_world()

func _save_world(announce: bool = true) -> void:
    if not is_host:
        return
    var data := {
        "version": 6,
        "seed": world_seed,
        "time": world_time,
        "wave_number": wave_number,
        "wave_total": wave_total,
        "wave_spawned": wave_spawned,
        "wave_kills": wave_kills,
        "wave_spawn_timer": wave_spawn_timer,
        "wave_break_timer": wave_break_timer,
        "wave_time_remaining": wave_time_remaining,
        "wave_timed_out": wave_timed_out,
        "airdrop_spawn_timer": airdrop_spawn_timer,
        "zombies": zombies,
        "airdrops": airdrops,
        "barricades": barricades,
        "turrets": turrets
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        ui_status = "Save failed: cannot write world file"
        return
    file.store_string(JSON.stringify(data))
    file.close()
    if announce:
        ui_status = "Offline world saved on this phone" if is_offline else "World saved on host · IP %s" % _get_lan_ip_summary()

func _load_world() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        ui_status = "Save file could not be opened; starting new world"
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        ui_status = "Save file invalid; starting new world"
        return
    var saved_version := int(parsed.get("version", 0))
    world_seed = int(parsed.get("seed", randi()))
    seed(world_seed)
    world_time = maxf(0.0, float(parsed.get("time", 0.0)))
    wave_number = maxi(1, int(parsed.get("wave_number", 1)))
    # Recalculate the total from the current wave so older saves cannot keep the legacy fixed-25 horde.
    wave_total = _zombie_count_for_wave(wave_number)
    wave_spawned = clampi(int(parsed.get("wave_spawned", 0)), 0, wave_total)
    wave_kills = clampi(int(parsed.get("wave_kills", 0)), 0, wave_total)
    wave_spawn_timer = maxf(0.0, float(parsed.get("wave_spawn_timer", 0.9)))
    wave_break_timer = maxf(0.0, float(parsed.get("wave_break_timer", 0.0)))
    wave_time_remaining = maxf(0.0, float(parsed.get("wave_time_remaining", _wave_duration_for(wave_number))))
    wave_timed_out = bool(parsed.get("wave_timed_out", false))
    game_over = false
    airdrop_spawn_timer = maxf(2.0, float(parsed.get("airdrop_spawn_timer", AIRDROP_FIRST_DELAY)))
    zombies.clear()
    airdrops.clear()
    barricades.clear()
    turrets.clear()
    active_grenades.clear()
    active_projectiles.clear()
    var saved_zombies = parsed.get("zombies", [])
    if typeof(saved_zombies) == TYPE_ARRAY:
        for z in saved_zombies:
            if typeof(z) == TYPE_DICTIONARY and z.has("x") and z.has("y"):
                var kind := clampi(int(z.get("kind", 0)), 0, ZOMBIE_MAX_HP.size() - 1)
                var max_hp := maxf(1.0, float(z.get("max_hp", _zombie_max_hp_for(kind, wave_number))))
                zombies.append({
                    "id": int(z.get("id", randi())),
                    "kind": kind,
                    "x": clampf(float(z.get("x", screen_size.x * 0.5)), 30.0, maxf(31.0, screen_size.x - 30.0)),
                    "y": clampf(float(z.get("y", screen_size.y * 0.70)), _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE),
                    "face_x": -1.0 if float(z.get("face_x", -1.0)) < 0.0 else 1.0,
                    "hp": clampf(float(z.get("hp", max_hp)), 0.1, max_hp),
                    "max_hp": max_hp,
                    "walking": false,
                    "attacking": false,
                    "attack_timer": 0.0,
                    "attack_cooldown": randf_range(0.12, 0.50),
                    "attack_type": clampi(int(z.get("attack_type", BOSS_ATTACK_SLASH)), BOSS_ATTACK_SLASH, BOSS_ATTACK_LUNGE),
                    "attack_hit_applied": false,
                    "hit_timer": 0.0
                })
    var saved_drops = parsed.get("airdrops", [])
    if typeof(saved_drops) == TYPE_ARRAY:
        for drop in saved_drops:
            if typeof(drop) == TYPE_DICTIONARY and drop.has("x") and drop.has("y"):
                airdrops.append({
                    "id": int(drop.get("id", randi())),
                    "x": clampf(float(drop.get("x", screen_size.x * 0.5)), 40.0, maxf(41.0, screen_size.x - 40.0)),
                    "y": clampf(float(drop.get("y", screen_size.y * 0.7)), _arena_top() - 20.0, _arena_bottom() - ARENA_BOTTOM_CLEARANCE),
                    "start_y": float(drop.get("start_y", _arena_top() - 18.0)),
                    "land_y": clampf(float(drop.get("land_y", screen_size.y * 0.7)), _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE),
                    "elapsed": maxf(0.0, float(drop.get("elapsed", 0.0))),
                    "fall_duration": maxf(0.1, float(drop.get("fall_duration", 2.6))),
                    "despawn_timer": clampf(float(drop.get("despawn_timer", AIRDROP_LAND_LIFETIME)), 0.0, AIRDROP_LAND_LIFETIME),
                    "landed": bool(drop.get("landed", false)),
                    "loot_kind": "grenade" if saved_version < 4 and str(drop.get("loot_kind", "grenade")) == "ammo" else str(drop.get("loot_kind", "grenade")),
                    "quantity": 1 if saved_version < 4 and str(drop.get("loot_kind", "grenade")) == "ammo" else maxi(1, int(drop.get("quantity", 1))),
                    "weapon_id": clampi(int(drop.get("weapon_id", WEAPON_SMG)), WEAPON_SMG, WEAPON_ROCKET)
                })
    var saved_walls = parsed.get("barricades", [])
    if typeof(saved_walls) == TYPE_ARRAY:
        for wall in saved_walls:
            if typeof(wall) == TYPE_DICTIONARY and wall.has("x") and wall.has("y"):
                barricades.append({
                    "id": int(wall.get("id", randi())),
                    "x": clampf(float(wall.get("x", screen_size.x * 0.5)), 42.0, maxf(43.0, screen_size.x - 42.0)),
                    "y": clampf(float(wall.get("y", screen_size.y * 0.7)), _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE),
                    "hp": clampf(float(wall.get("hp", 90.0)), 1.0, 90.0),
                    "max_hp": maxf(1.0, float(wall.get("max_hp", 90.0))),
                    "owner_id": int(wall.get("owner_id", 1))
                })
    var saved_turrets = parsed.get("turrets", [])
    if typeof(saved_turrets) == TYPE_ARRAY:
        for turret in saved_turrets:
            if typeof(turret) == TYPE_DICTIONARY and turret.has("x") and turret.has("y") and turrets.size() < MAX_TURRETS:
                turrets.append({
                    "id": int(turret.get("id", _next_turret_id())) & 0xFFFF,
                    "x": clampf(float(turret.get("x", screen_size.x * 0.5)), 35.0, maxf(36.0, screen_size.x - 35.0)),
                    "y": clampf(float(turret.get("y", screen_size.y * 0.7)), _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE),
                    "hp": clampf(float(turret.get("hp", TURRET_MAX_HP)), 1.0, TURRET_MAX_HP),
                    "max_hp": TURRET_MAX_HP,
                    "angle": float(turret.get("angle", 0.0)),
                    "fire_timer": 0.2,
                    "flash_timer": 0.0,
                    "owner_id": int(turret.get("owner_id", 1))
                })
    players.clear()
    input_vectors.clear()

func _start_host() -> void:
    if is_host:
        ui_status = "Already hosting on UDP %d" % PORT
        return
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
    peer = ENetMultiplayerPeer.new()
    var error_code := peer.create_server(PORT, MAX_PLAYERS - 1)
    if error_code != OK:
        ui_status = "Host failed: %s" % error_string(error_code)
        return
    # Godot 4.7 exposes compression through the underlying ENetConnection, not ENetMultiplayerPeer.
    peer.host.compress(ENetConnection.COMPRESS_FASTLZ)
    multiplayer.multiplayer_peer = peer
    is_host = true
    is_offline = false
    local_player_id = 1
    _cancel_targeting_modes()
    screen_mode = "lobby"
    players.clear()
    player_death_visuals.clear()
    input_vectors.clear()
    cmd_last_seq.clear()
    cmd_budget.clear()
    cmd_last_ms.clear()
    host_track.clear()
    host_view.clear()
    zombies.clear()
    airdrops.clear()
    barricades.clear()
    turrets.clear()
    active_grenades.clear()
    active_projectiles.clear()
    airdrop_spawn_timer = AIRDROP_FIRST_DELAY
    airdrop_sequence = 1
    combat_effects.clear()
    fire_cooldowns.clear()
    heal_cooldowns.clear()
    grenade_cooldowns.clear()
    build_cooldowns.clear()
    turret_sequence = 1
    wave_number = 1
    wave_total = _zombie_count_for_wave(wave_number)
    wave_spawned = 0
    wave_kills = 0
    wave_spawn_timer = 0.9
    wave_break_timer = 0.0
    wave_time_remaining = _wave_duration_for(1)
    wave_timed_out = false
    game_over = false
    world_time = 0.0
    world_seed = randi()
    seed(world_seed)
    players[1] = _make_player(1)
    input_vectors[1] = Vector2.ZERO
    snapshot_timer = 0.0
    last_save_time = world_time
    host_lan_ip = _get_lan_ip_summary()
    ui_status = "World created — share your Wi-Fi IP with friends"

func _join_host(ip: String) -> void:
    var cleaned_ip := ip.strip_edges()
    if not _is_valid_ipv4(cleaned_ip):
        ui_status = "Invalid IPv4 address — enter host Wi-Fi IP"
        return
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
    peer = ENetMultiplayerPeer.new()
    var error_code := peer.create_client(cleaned_ip, PORT)
    if error_code != OK:
        ui_status = "Join failed: %s" % error_string(error_code)
        return
    # Keep client compression identical to the host before multiplayer starts polling it.
    peer.host.compress(ENetConnection.COMPRESS_FASTLZ)
    multiplayer.multiplayer_peer = peer
    is_host = false
    is_offline = false
    _cancel_targeting_modes()
    screen_mode = "lobby"
    host_ip = cleaned_ip
    cmd_seq = 0
    cmd_open_qx = 0
    cmd_open_qy = 0
    _reset_client_interpolation()
    players.clear()
    player_death_visuals.clear()
    zombies.clear()
    combat_effects.clear()
    input_vectors.clear()
    ui_status = "Connecting to %s:%d ..." % [cleaned_ip, PORT]

func _is_valid_ipv4(value: String) -> bool:
    var parts := value.split(".")
    if parts.size() != 4:
        return false
    for part in parts:
        if not part.is_valid_int():
            return false
        var number := int(part)
        if number < 0 or number > 255:
            return false
    return true

func _get_lan_ip_summary() -> String:
    var candidates: Array[String] = []
    for address in IP.get_local_addresses():
        if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254.") and not candidates.has(address):
            candidates.append(address)
    if candidates.is_empty():
        return "unknown"
    candidates.sort()
    # Prefer an Android hotspot address over a VPN/mobile alias when possible.
    for address in candidates:
        if address.begins_with("192.168."):
            return address
    for address in candidates:
        if address.begins_with("172."):
            var pieces := address.split(".")
            if pieces.size() > 1 and int(pieces[1]) >= 16 and int(pieces[1]) <= 31:
                return address
    for address in candidates:
        if address.begins_with("10."):
            return address
    return candidates[0]

func _reset_network_state() -> void:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
    peer = null
    is_host = false
    is_offline = false
    fire_held = false
    fire_touch_id = -1
    fire_requested = false
    grenade_requested = false
    build_requested = false
    fire_repeat_timer = 0.0
    _cancel_targeting_modes()
    players.clear()
    player_death_visuals.clear()
    input_vectors.clear()
    cmd_last_seq.clear()
    cmd_budget.clear()
    cmd_last_ms.clear()
    host_track.clear()
    host_view.clear()
    zombies.clear()
    airdrops.clear()
    barricades.clear()
    turrets.clear()
    active_grenades.clear()
    active_projectiles.clear()
    airdrop_spawn_timer = AIRDROP_FIRST_DELAY
    airdrop_sequence = 1
    combat_effects.clear()
    fire_cooldowns.clear()
    heal_cooldowns.clear()
    grenade_cooldowns.clear()
    build_cooldowns.clear()
    wave_number = 1
    wave_total = _zombie_count_for_wave(wave_number)
    wave_spawned = 0
    wave_kills = 0
    wave_spawn_timer = 0.9
    wave_break_timer = 0.0
    wave_time_remaining = _wave_duration_for(1)
    wave_timed_out = false
    game_over = false
    world_time = 0.0
    snapshot_timer = 0.0
    client_input_timer = 0.0
    heal_requested = false
    joystick_vector = Vector2.ZERO
    joystick_active = false
    joystick_touch_id = -1
    local_player_id = 1
    cmd_seq = 0
    cmd_open_qx = 0
    cmd_open_qy = 0
    cmd_last_seq.clear()
    cmd_budget.clear()
    cmd_last_ms.clear()
    host_track.clear()
    host_view.clear()
    _reset_client_interpolation()

func _leave_world() -> void:
    # Leaving is not an implicit save. New games start empty; Continue Saved Run is explicit.
    _reset_network_state()
    screen_mode = "lobby"
    ui_status = "Disconnected"

func _draw() -> void:
    button_rects.clear()
    screen_size = get_viewport_rect().size
    # Opaque safety underlay; the home/world renderers draw over it below.
    draw_rect(Rect2(Vector2.ZERO, screen_size), Color("#18251f"))
    if ui_font == null:
        ui_font = ThemeDB.fallback_font
    if screen_mode == "home":
        _draw_home()
    elif screen_mode == "lobby":
        _draw_lobby()
    elif screen_mode == "help":
        _draw_help()
    elif screen_mode == "pause":
        _draw_game_world()
        _draw_pause_menu()
    elif screen_mode == "game_over":
        _draw_game_world()
        _draw_game_over_menu()
    else:
        _draw_game_world()

func _draw_apocalypse_backdrop(darkened: bool = false) -> void:
    var w := screen_size.x
    var h := screen_size.y
    if background_texture != null:
        draw_texture_rect(background_texture, Rect2(0, 0, w, h), false, Color.WHITE)
    else:
        draw_rect(Rect2(0, 0, w, h), Color("#17222b"))
        draw_rect(Rect2(0, h * 0.54, w, h * 0.46), Color("#202322"))
    # A cool night grade and subtle blood-red edge tint make every menu feel cohesive.
    if darkened:
        draw_rect(Rect2(0, 0, w, h), Color(0.012, 0.022, 0.034, 0.48))
        draw_rect(Rect2(0, 0, w * 0.16, h), Color(0.16, 0.012, 0.025, 0.12))
        draw_rect(Rect2(w * 0.84, 0, w * 0.16, h), Color(0.16, 0.012, 0.025, 0.12))
    draw_rect(Rect2(0, 0, w, 3), Color("#a83d43"))
    draw_rect(Rect2(0, h - 3, w, 3), Color(0.01, 0.015, 0.02, 0.78))

func _draw_home() -> void:
    _draw_apocalypse_backdrop(true)
    var w := screen_size.x
    var h := screen_size.y
    var left_w := w * 0.57

    # Mission dossier header and title hierarchy.
    draw_rect(Rect2(28, 26, 6, 66), Color("#c74449"))
    draw_string(ui_font, Vector2(45, 43), "DANZKU ORIGINAL  /  OUTBREAK DIVISION", HORIZONTAL_ALIGNMENT_LEFT, left_w - 70, 11, Color("#d0c4b7"))
    draw_string(ui_font, Vector2(45, 60), "CASE FILE 07     •     QUARANTINE ACTIVE", HORIZONTAL_ALIGNMENT_LEFT, left_w - 70, 9, Color("#b86b6b"))

    _draw_title_text(Vector2(42, h * 0.31), "PIXEL", 36, Color("#f2eee4"))
    _draw_title_text(Vector2(42, h * 0.415), "ZOMBIE", 51, Color("#cf4b4e"))
    draw_string(ui_font, Vector2(46, h * 0.475), "SURVIVAL PROTOCOL  //  NIGHT SHIFT", HORIZONTAL_ALIGNMENT_LEFT, left_w - 80, 13, Color("#e1c58e"))
    draw_rect(Rect2(46, h * 0.50, minf(290.0, left_w - 90.0), 2), Color("#9c4547"))
    draw_string(ui_font, Vector2(46, h * 0.545), "THE CITY FELL. HOLD THE LINE.", HORIZONTAL_ALIGNMENT_LEFT, left_w - 80, 13, Color("#e4e1d7"))
    draw_string(ui_font, Vector2(46, h * 0.58), "SCAVENGE  •  RELOAD  •  SURVIVE TOGETHER", HORIZONTAL_ALIGNMENT_LEFT, left_w - 80, 10, Color("#aeb9b1"))

    # Four survivors are staged together with restrained team-color ground rings.
    var party_y := h * 0.765
    var party_x := [w * 0.105, w * 0.19, w * 0.275, w * 0.36]
    var party_offsets := [0.0, 5.0, -2.0, 4.0]
    var party_scales := [1.0, 0.91, 1.02, 0.91]
    for i in range(4):
        var center := Vector2(float(party_x[i]), party_y + float(party_offsets[i]))
        draw_arc(center + Vector2(0, 27), 20.0 * float(party_scales[i]), 0, TAU, 32, _player_color(i + 1), 2.0)
        draw_circle(center + Vector2(0, 27), 16.0 * float(party_scales[i]), Color(0.015, 0.02, 0.02, 0.58))
        _draw_survivor(center, _player_color(i + 1), float(party_scales[i]))
    draw_rect(Rect2(42, h - 37, left_w - 72, 22), Color(0.015, 0.025, 0.03, 0.75))
    draw_rect(Rect2(42, h - 37, 3, 22), Color("#a83d43"))
    draw_string(ui_font, Vector2(54, h - 22), "LOCAL CO-OP  /  4 SURVIVORS  /  NO INTERNET", HORIZONTAL_ALIGNMENT_LEFT, left_w - 100, 10, Color("#c8d0c8"))

    # A compact, balanced safehouse panel with uniform interaction targets.
    var card_w := minf(392.0, w * 0.405)
    var card_x := w - card_w - 28.0
    var card_y := 35.0
    var card_h := h - 70.0
    _draw_panel(Rect2(card_x, card_y, card_w, card_h), "SAFEHOUSE TERMINAL", "PROTOCOL 04  /  STAY ALIVE")
    var bx := card_x + 20.0
    var bw := card_w - 40.0
    _draw_ui_button("home_lan", Rect2(bx, card_y + 78.0, bw, 54.0), "MULTIPLAYER LAN", "HOST OR JOIN UP TO FOUR SURVIVORS", Color("#d64e51"), true)
    _draw_ui_button("home_solo", Rect2(bx, card_y + 140.0, bw, 52.0), "NEW SOLO RUN", "START WITH A CLEAN ARENA", Color("#c18a55"), false)
    var save_available := FileAccess.file_exists(SAVE_PATH)
    var continue_subtitle := "RESUME THE MANUALLY SAVED RUN" if save_available else "NO SAVED RUN — START SOLO FIRST"
    _draw_ui_button("home_continue", Rect2(bx, card_y + 200.0, bw, 50.0), "CONTINUE SAVED", continue_subtitle, Color("#8ca17f"), false)
    _draw_ui_button("home_controls", Rect2(bx, card_y + 258.0, bw, 46.0), "FIELD MANUAL", "MOVE  /  FIRE  /  HEAL  /  SAVE", Color("#9cae91"), false)

    var signal_rect := Rect2(bx, card_y + 312.0, bw, 35.0)
    draw_rect(signal_rect, Color(0.12, 0.045, 0.05, 0.88))
    draw_rect(Rect2(signal_rect.position, Vector2(3, signal_rect.size.y)), Color("#9e4146"))
    draw_circle(Vector2(signal_rect.position.x + 17, signal_rect.position.y + 21), 4.0, Color("#dc685b"))
    draw_string(ui_font, Vector2(signal_rect.position.x + 29, signal_rect.position.y + 25), "LOCAL SIGNAL ONLY  /  UDP %d" % PORT, HORIZONTAL_ALIGNMENT_LEFT, bw - 40, 10, Color("#d4c5bb"))
    draw_string(ui_font, Vector2(bx, card_y + card_h - 17.0), "BUILD 0.4.13  /  EARLY ACCESS", HORIZONTAL_ALIGNMENT_LEFT, bw, 10, Color("#9caaa0"))

func _draw_help() -> void:
    _draw_apocalypse_backdrop(true)
    var w := screen_size.x
    var h := screen_size.y
    _draw_ui_button("help_back", Rect2(30, 22, 110, 36), "‹  BACK", "", Color("#86958a"), false)
    _draw_title_text(Vector2(40, 88), "FIELD MANUAL", 31, Color("#f0ead8"))
    draw_string(ui_font, Vector2(42, 111), "THE BASICS YOU NEED TO MAKE IT THROUGH THE NIGHT", HORIZONTAL_ALIGNMENT_LEFT, w - 84, 11, Color("#b4c7b6"))
    var panel := Rect2(34, 135, w - 68, h - 174)
    _draw_panel(panel, "SURVIVAL CONTROLS", "KEEP YOUR CREW ALIVE AFTER DARK.")
    var gap := 14.0
    var col_w := (panel.size.x - 52.0 - gap * 2.0) / 3.0
    var card_y := panel.position.y + 82.0
    var card_h := 150.0
    var cards := [
        {"title": "01  MOVE", "body": "Use the left\nvirtual analog to\nwalk around the city.", "color": Color("#a9b77f")},
        {"title": "02  FIGHT", "body": "Default sidearm has infinite ammo.\nAirdrops can grant limited-ammo guns.\nTap the 0/1/2 slots to switch weapons.", "color": Color("#cc5151")},
        {"title": "03  HEAL", "body": "HEAL consumes one\nmedkit and restores\nhealth when needed.", "color": Color("#c19a68")}
    ]
    for i in range(cards.size()):
        var cx := panel.position.x + 20.0 + i * (col_w + gap)
        var card_rect := Rect2(cx, card_y, col_w, card_h)
        draw_rect(card_rect, Color(0.035, 0.045, 0.048, 0.97))
        draw_rect(card_rect, Color("#3e4543"), false, 1.0)
        draw_rect(Rect2(cx, card_y, col_w, 4), cards[i].color)
        draw_string(ui_font, Vector2(cx + 15, card_y + 34), cards[i].title, HORIZONTAL_ALIGNMENT_LEFT, col_w - 30, 15, Color("#f0eedf"))
        draw_string(ui_font, Vector2(cx + 15, card_y + 65), cards[i].body, HORIZONTAL_ALIGNMENT_LEFT, col_w - 26, 12, Color("#bac8bc"))
    var lan_y := card_y + card_h + 22.0
    draw_rect(Rect2(panel.position.x + 20, lan_y, panel.size.x - 40, 1), Color("#43594d"))
    draw_string(ui_font, Vector2(panel.position.x + 22, lan_y + 23), "LAN CO-OP", HORIZONTAL_ALIGNMENT_LEFT, 110, 12, Color("#e0c68c"))
    draw_string(ui_font, Vector2(panel.position.x + 122, lan_y + 23), "One phone creates a world; up to three friends join using the same hotspot and host IP.", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 160, 11, Color("#b4c7b6"))

func _draw_lobby() -> void:
    _draw_apocalypse_backdrop(true)
    var w := screen_size.x
    var h := screen_size.y
    _draw_ui_button("lobby_back", Rect2(28, 20, 104, 36), "‹  HOME", "", Color("#86958a"), false)
    _draw_title_text(Vector2(34, 88), "SAFEHOUSE LOBBY", 29, Color("#f0ead8"))
    draw_string(ui_font, Vector2(36, 109), "FOUR SURVIVORS. ONE LAST STAND. NO INTERNET.", HORIZONTAL_ALIGNMENT_LEFT, w * 0.54, 11, Color("#b4c7b6"))

    var left_x := 30.0
    var left_w := w * 0.56
    var panel_y := 132.0
    var panel_h := h - 164.0
    _draw_panel(Rect2(left_x, panel_y, left_w, panel_h), "SURVIVOR SQUAD", "%d / %d PLAYERS CONNECTED" % [players.size(), MAX_PLAYERS])
    var roster_keys: Array = players.keys()
    roster_keys.sort()
    var slot_w := (left_w - 56.0) * 0.5
    for slot in range(MAX_PLAYERS):
        var col := slot % 2
        var row := int(slot / 2)
        var slot_rect := Rect2(left_x + 20.0 + col * (slot_w + 12.0), panel_y + 82.0 + row * 91.0, slot_w, 76.0)
        var occupied := slot < roster_keys.size()
        if occupied:
            var pid := int(roster_keys[slot])
            var p: Dictionary = players[pid]
            var accent := _player_color(pid)
            draw_rect(slot_rect, Color(0.06, 0.10, 0.09, 0.94))
            draw_rect(Rect2(slot_rect.position, Vector2(4, slot_rect.size.y)), accent)
            _draw_survivor(Vector2(slot_rect.position.x + 33, slot_rect.position.y + 38), accent, 0.53)
            draw_string(ui_font, Vector2(slot_rect.position.x + 61, slot_rect.position.y + 27), "HOST / YOU" if pid == 1 and is_host else ("YOU" if pid == local_player_id else "SURVIVOR %d" % (slot + 1)), HORIZONTAL_ALIGNMENT_LEFT, slot_w - 70, 13, Color("#f0eedf"))
            draw_string(ui_font, Vector2(slot_rect.position.x + 61, slot_rect.position.y + 47), "HP %d  ·  MED %d" % [int(p.get("hp", 100)), int(p.get("medkits", 2))], HORIZONTAL_ALIGNMENT_LEFT, slot_w - 70, 10, Color("#a9c6ae"))
            draw_string(ui_font, Vector2(slot_rect.position.x + 61, slot_rect.position.y + 63), "READY" if screen_mode == "lobby" else "IN GAME", HORIZONTAL_ALIGNMENT_LEFT, slot_w - 70, 9, Color("#8fc98c"))
        else:
            draw_rect(slot_rect, Color("#4b5b52"), false, 1.0)
            draw_string(ui_font, slot_rect.position + Vector2(16, 31), "+", HORIZONTAL_ALIGNMENT_LEFT, 24, 23, Color("#788e7d"))
            draw_string(ui_font, slot_rect.position + Vector2(43, 28), "WAITING FOR PLAYER", HORIZONTAL_ALIGNMENT_LEFT, slot_w - 53, 11, Color("#819188"))
            draw_string(ui_font, slot_rect.position + Vector2(43, 47), "Share the host IP to join", HORIZONTAL_ALIGNMENT_LEFT, slot_w - 53, 9, Color("#66766c"))
    draw_string(ui_font, Vector2(left_x + 22, panel_y + panel_h - 12), "TIP: ALL PHONES MUST JOIN THE SAME HOTSPOT", HORIZONTAL_ALIGNMENT_LEFT, left_w - 40, 10, Color("#b8c2b8"))

    var right_x := left_x + left_w + 16.0
    var right_w := w - right_x - 30.0
    _draw_panel(Rect2(right_x, panel_y, right_w, panel_h), "SESSION CONTROL", "LOCAL WI-FI / UDP %d" % PORT)
    var rx := right_x + 18.0
    var rbw := right_w - 36.0
    if not is_host and not _is_connected_client():
        _draw_ui_button("lobby_host", Rect2(rx, panel_y + 82, rbw, 60), "CREATE WORLD", "THIS PHONE BECOMES THE HOST", Color("#cc4c50"), true)
        _draw_ui_button("lobby_join", Rect2(rx, panel_y + 154, rbw, 60), "JOIN WORLD", "ENTER THE HOST'S WI-FI IP", Color("#c18a55"), false)
        draw_string(ui_font, Vector2(rx, panel_y + 247), "No online account needed.\nOnly the host needs to create a world.", HORIZONTAL_ALIGNMENT_LEFT, rbw, 11, Color("#a8b7ac"))
    elif is_host:
        draw_string(ui_font, Vector2(rx, panel_y + 79), "HOST ADDRESS", HORIZONTAL_ALIGNMENT_LEFT, rbw, 10, Color("#a4b8a8"))
        draw_string(ui_font, Vector2(rx, panel_y + 109), host_lan_ip, HORIZONTAL_ALIGNMENT_LEFT, rbw, 21, Color("#f1d38b"))
        draw_string(ui_font, Vector2(rx, panel_y + 130), "Tell friends to enter this IP.", HORIZONTAL_ALIGNMENT_LEFT, rbw, 10, Color("#a8b7ac"))
        _draw_ui_button("lobby_copy", Rect2(rx, panel_y + 146, rbw, 43), "COPY HOST IP", "", Color("#c18a55"), false)
        _draw_ui_button("lobby_start", Rect2(rx, panel_y + 198, rbw, 54), "START SURVIVAL", "BEGIN THE ZOMBIE WAVE", Color("#cc4c50"), true)
        _draw_ui_button("lobby_save", Rect2(rx, panel_y + 261, rbw, 42), "SAVE WORLD", "", Color("#c18a55"), false)
    else:
        draw_string(ui_font, Vector2(rx, panel_y + 84), "CONNECTED", HORIZONTAL_ALIGNMENT_LEFT, rbw, 17, Color("#91bd79"))
        draw_string(ui_font, Vector2(rx, panel_y + 111), "Host: %s" % host_ip, HORIZONTAL_ALIGNMENT_LEFT, rbw, 11, Color("#c6d3c8"))
        draw_string(ui_font, Vector2(rx, panel_y + 145), "Waiting for the host to\nstart the survival world...", HORIZONTAL_ALIGNMENT_LEFT, rbw, 12, Color("#a8b7ac"))
    _draw_ui_button("lobby_leave", Rect2(rx, panel_y + panel_h - 55, rbw, 38), "LEAVE LOBBY", "", Color("#b94a50"), false)
    draw_string(ui_font, Vector2(36, h - 12), ui_status, HORIZONTAL_ALIGNMENT_LEFT, w - 72, 10, Color("#e0d7bf"))

func _update_player_death_visuals(delta: float) -> void:
    # This is presentation-only: it records when this device first sees HP reach zero.
    # No fields are added to the compact LAN snapshots, protecting v0.4.11 networking.
    for id_variant in players.keys():
        var id := int(id_variant)
        var p: Dictionary = players[id]
        if float(p.get("hp", 0.0)) <= 0.0:
            if not player_death_visuals.has(id):
                var death_pos := _player_draw_pos(id, p)
                player_death_visuals[id] = {
                    "age": 0.0,
                    "x": death_pos.x,
                    "y": death_pos.y,
                    "face_left": float(p.get("face_x", 1.0)) < 0.0
                }
            else:
                var death_state: Dictionary = player_death_visuals[id]
                death_state["age"] = minf(PLAYER_REMAINS_FADE_END + 1.0, float(death_state.get("age", 0.0)) + clampf(delta, 0.0, 0.1))
                player_death_visuals[id] = death_state
        else:
            player_death_visuals.erase(id)
    for id_variant in player_death_visuals.keys():
        if not players.has(int(id_variant)):
            player_death_visuals.erase(id_variant)

func _draw_player_death_remains(pos: Vector2, id: int, age: float, facing_left: bool) -> void:
    var phase := float(id) * 1.37
    if age < PLAYER_DEATH_FADE_DURATION:
        var t := clampf(age / PLAYER_DEATH_FADE_DURATION, 0.0, 1.0)
        var opacity: float = pow(1.0 - t, 1.25)
        var collapse_pos := pos + Vector2(0.0, t * 8.0)
        draw_ellipse_shadow(pos + Vector2(0.0, 28.0), 10.0 + 6.0 * t, 3.2 + t * 1.4, 0.28 * opacity)
        # Fading embers and dust break up the survivor silhouette before the bones appear.
        for particle_index in range(7):
            var seed_angle := TAU * float(particle_index) / 7.0 + phase * 0.21
            var travel := 8.0 + float((particle_index * 5) % 11) * t
            var particle_pos := collapse_pos + Vector2(cos(seed_angle) * travel, -sin(t * PI * 0.72) * (5.0 + float(particle_index % 3) * 5.0) - t * (6.0 + float(particle_index % 4) * 3.0))
            var particle_alpha := opacity * (0.45 + 0.4 * absf(sin(seed_angle)))
            draw_circle(particle_pos, 1.0 + float(particle_index % 2) * 0.55, Color(0.61, 0.57, 0.48, particle_alpha))
        _draw_atlas_character(collapse_pos, _player_sprite_index(id), false, 1.0 - t * 0.16, facing_left, false, false, false, false, phase, opacity)
        return

    var remains_fade: float = 1.0
    if age > PLAYER_REMAINS_FADE_START:
        remains_fade = clampf((PLAYER_REMAINS_FADE_END - age) / maxf(0.01, PLAYER_REMAINS_FADE_END - PLAYER_REMAINS_FADE_START), 0.0, 1.0)
    if remains_fade <= 0.0:
        return
    var reveal: float = clampf((age - PLAYER_DEATH_FADE_DURATION) / 0.48, 0.0, 1.0)
    var bone_alpha: float = remains_fade * reveal
    _draw_death_bones(pos, facing_left, bone_alpha, age)

func _draw_bone_segment(start: Vector2, finish: Vector2, width: float, alpha: float) -> void:
    if alpha <= 0.01:
        return
    draw_line(start, finish, Color(0.055, 0.045, 0.039, alpha), width + 2.2, true)
    draw_line(start, finish, Color(0.76, 0.70, 0.56, alpha), width, true)
    draw_line(start + Vector2(0.0, -0.55), finish + Vector2(0.0, -0.55), Color(0.95, 0.87, 0.70, alpha * 0.52), maxf(0.7, width * 0.24), true)

func _draw_death_bones(pos: Vector2, facing_left: bool, alpha: float, age: float) -> void:
    var face_sign := -1.0 if facing_left else 1.0
    var base := pos + Vector2(0.0, 16.0)
    draw_ellipse_shadow(base + Vector2(0.0, 4.0), 19.0, 4.1, 0.22 * alpha)
    # The remains lie flat on the road: skull, rib cage, spine, pelvis and separated long bones.
    var skull := base + Vector2(15.0 * face_sign, -3.0)
    draw_circle(skull + Vector2(0.0, 0.6), 5.0, Color(0.045, 0.035, 0.032, alpha))
    draw_circle(skull, 4.25, Color(0.79, 0.73, 0.61, alpha))
    draw_circle(skull + Vector2(1.0 * face_sign, 0.6), 1.2, Color(0.16, 0.13, 0.11, alpha))
    draw_circle(skull + Vector2(-1.8 * face_sign, -0.6), 0.9, Color(0.16, 0.13, 0.11, alpha))
    _draw_bone_segment(skull + Vector2(-2.3 * face_sign, 2.2), skull + Vector2(2.1 * face_sign, 2.7), 1.6, alpha)

    var neck := base + Vector2(9.0 * face_sign, -1.0)
    var shoulder := base + Vector2(5.0 * face_sign, 0.0)
    var spine_mid := base + Vector2(0.0, 2.0)
    var pelvis := base + Vector2(-7.0 * face_sign, 4.0)
    _draw_bone_segment(neck, shoulder, 2.2, alpha)
    _draw_bone_segment(shoulder, spine_mid, 2.0, alpha)
    _draw_bone_segment(spine_mid, pelvis, 2.1, alpha)
    for rib_index in range(4):
        var rib_y := -1.0 + float(rib_index) * 2.4
        var rib_a := base + Vector2(6.0 * face_sign, rib_y)
        var rib_b := base + Vector2(1.0 * face_sign, rib_y + 2.5)
        var rib_c := base + Vector2(-3.0 * face_sign, rib_y + 1.9)
        _draw_bone_segment(rib_a, rib_b, 1.25, alpha)
        _draw_bone_segment(rib_b, rib_c, 1.25, alpha)
    _draw_bone_segment(base + Vector2(-10.0 * face_sign, 2.0), pelvis, 1.8, alpha)
    _draw_bone_segment(base + Vector2(-10.0 * face_sign, 2.0), base + Vector2(-4.0 * face_sign, 7.0), 1.8, alpha)

    # Arms sit unevenly beside the ribs, rather than being a rigid symmetrical stick figure.
    var elbow_a := base + Vector2(0.0 * face_sign, -5.0)
    var wrist_a := base + Vector2(-4.5 * face_sign, -8.0)
    var elbow_b := base + Vector2(2.5 * face_sign, 6.0)
    var wrist_b := base + Vector2(8.0 * face_sign, 7.5)
    _draw_bone_segment(shoulder + Vector2(0.0, -1.0), elbow_a, 1.8, alpha)
    _draw_bone_segment(elbow_a, wrist_a, 1.6, alpha)
    _draw_bone_segment(shoulder + Vector2(-1.0 * face_sign, 2.0), elbow_b, 1.7, alpha)
    _draw_bone_segment(elbow_b, wrist_b, 1.5, alpha)
    draw_circle(elbow_a, 1.7, Color(0.82, 0.75, 0.62, alpha))
    draw_circle(elbow_b, 1.7, Color(0.82, 0.75, 0.62, alpha))

    # Legs trail back from the pelvis with a slight offset, giving the body a fallen pose.
    var knee_a := base + Vector2(-13.0 * face_sign, 0.0)
    var ankle_a := base + Vector2(-20.0 * face_sign, 3.0)
    var knee_b := base + Vector2(-10.0 * face_sign, 9.0)
    var ankle_b := base + Vector2(-18.0 * face_sign, 12.0)
    _draw_bone_segment(pelvis + Vector2(-1.0 * face_sign, 1.0), knee_a, 2.4, alpha)
    _draw_bone_segment(knee_a, ankle_a, 1.9, alpha)
    _draw_bone_segment(pelvis + Vector2(-2.0 * face_sign, 3.0), knee_b, 2.2, alpha)
    _draw_bone_segment(knee_b, ankle_b, 1.8, alpha)
    draw_circle(knee_a, 2.0, Color(0.82, 0.75, 0.62, alpha))
    draw_circle(knee_b, 2.0, Color(0.82, 0.75, 0.62, alpha))

    # A couple of tiny bone chips drift out during the first second after the collapse.
    var fragment_alpha: float = alpha * clampf(1.0 - (age - PLAYER_DEATH_FADE_DURATION) / 2.2, 0.0, 1.0)
    for fragment_index in range(3):
        var fragment_pos := base + Vector2((float(fragment_index) - 1.0) * 13.0 * face_sign, -5.0 - float(fragment_index % 2) * 4.0)
        draw_line(fragment_pos, fragment_pos + Vector2(3.5 * face_sign, 1.2), Color(0.82, 0.75, 0.62, fragment_alpha), 1.5, true)

func _draw_game_world() -> void:
    var w := screen_size.x
    var h := screen_size.y
    if background_texture != null:
        draw_texture_rect(background_texture, Rect2(0, 0, w, h), false, Color.WHITE)
    else:
        draw_rect(Rect2(0, 0, w, h), Color("#1b2930"))
    draw_rect(Rect2(0, 0, w, h), Color(0.012, 0.024, 0.038, 0.16))

    # Top gameplay edge follows the original sidewalk-to-asphalt join; no artificial line is drawn.
    var lane_bottom := _arena_bottom()
    var cover_y := lane_bottom - 22.0
    var cover_positions: Array[float] = [w * 0.105, w * 0.79]
    for cover_x_value in cover_positions:
        var cover_x: float = float(cover_x_value)
        var cover_w: float = 45.0
        draw_rect(Rect2(cover_x, cover_y + 3.0, cover_w, 13), Color(0.015, 0.02, 0.02, 0.42))
        draw_rect(Rect2(cover_x, cover_y, cover_w, 13), Color("#424a46"))
        draw_rect(Rect2(cover_x, cover_y, cover_w, 3), Color("#899087"))
        for stripe in range(3):
            var sx: float = cover_x + 7.0 + float(stripe) * 14.0
            draw_line(Vector2(sx, cover_y + 4.0), Vector2(sx + 5.0, cover_y + 11.0), Color("#b59b62"), 2.0, true)
        draw_rect(Rect2(cover_x, cover_y, cover_w, 13), Color("#171f20"), false, 1.0)

    _draw_airdrop_dust_effects()
    var render_entries: Array[Dictionary] = []
    for id_variant in players.keys():
        var pid := int(id_variant)
        render_entries.append({"y": _player_draw_pos(pid, players[pid]).y, "type": "player", "id": pid})
    for zi in range(zombies.size()):
        render_entries.append({"y": float(zombies[zi].get("y", h * 0.68)), "type": "zombie", "index": zi})
    for wi in range(barricades.size()):
        render_entries.append({"y": float(barricades[wi].get("y", h * 0.68)) + 2.0, "type": "barricade", "index": wi})
    for ti in range(turrets.size()):
        render_entries.append({"y": float(turrets[ti].get("y", h * 0.68)) + 6.0, "type": "turret", "index": ti})
    for di in range(airdrops.size()):
        render_entries.append({"y": float(airdrops[di].get("y", h * 0.68)) + 35.0, "type": "airdrop", "index": di})
    for gi in range(active_grenades.size()):
        render_entries.append({"y": float(active_grenades[gi].get("y", h * 0.68)), "type": "grenade", "index": gi})
    render_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.y) < float(b.y))

    for entry in render_entries:
        var pos: Vector2
        var entry_type := str(entry.get("type", "zombie"))
        if entry_type == "player":
            var id := int(entry.id)
            var p: Dictionary = players[id]
            pos = _player_draw_pos(id, p)
            if float(p.get("hp", 0.0)) <= 0.0 and player_death_visuals.has(id):
                var death_state: Dictionary = player_death_visuals[id]
                var death_pos := Vector2(float(death_state.get("x", pos.x)), float(death_state.get("y", pos.y)))
                _draw_player_death_remains(death_pos, id, float(death_state.get("age", 0.0)), bool(death_state.get("face_left", false)))
                continue
            var moving := bool(p.get("walking", false))
            var shooting := float(p.get("shoot_timer", 0.0)) > 0.02
            var hurt := float(p.get("hurt_timer", 0.0)) > 0.02
            var phase := float(id) * 1.37
            var visual_pos := _character_visual_position(pos, false, float(p.get("face_x", 1.0)) < 0.0, moving, false, shooting, phase, hurt)
            draw_circle(pos + Vector2(0, 27), 10.0, Color(0.005, 0.01, 0.012, 0.34))
            var team_color := _player_color(id)
            draw_arc(pos + Vector2(0, 28), 13.0, 0, TAU, 28, Color(team_color.r, team_color.g, team_color.b, 0.48), 1.5)
            if moving:
                _draw_footstep_dust(pos, phase, false)
            _draw_atlas_character(pos, _player_sprite_index(id), false, 1.0, float(p.get("face_x", 1.0)) < 0.0, moving, false, hurt, shooting, phase)
            _draw_player_weapon(pos, p)
            var label := _player_label(id)
            var label_pos := visual_pos + Vector2(-22, -43)
            draw_rect(Rect2(label_pos.x - 1, label_pos.y - 12, 44, 16), Color(0.01, 0.015, 0.02, 0.74))
            draw_string(ui_font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, 42, 10, _player_color(id))
            var player_hp := clampf(float(p.get("hp", 0.0)) / 100.0, 0.0, 1.0)
            var player_bar := Rect2(visual_pos + Vector2(-17, 32), Vector2(34, 5))
            draw_rect(Rect2(player_bar.position - Vector2(1, 1), player_bar.size + Vector2(2, 2)), Color("#141819"))
            draw_rect(player_bar, Color("#472628"))
            var player_hp_color := Color("#b94346") if player_hp <= 0.30 else (Color("#d39a50") if player_hp <= 0.58 else Color("#86b76b"))
            draw_rect(Rect2(player_bar.position, Vector2(player_bar.size.x * player_hp, player_bar.size.y)), player_hp_color)
        elif entry_type == "zombie":
            var z: Dictionary = zombies[int(entry.index)]
            pos = Vector2(float(z.get("x", 0.0)), float(z.get("y", h * 0.68)))
            var zombie_kind := clampi(int(z.get("kind", 0)), 0, ZOMBIE_KIND_BOSS)
            var boss := zombie_kind == ZOMBIE_KIND_BOSS
            var heavy := zombie_kind == 2 or boss
            var moving := bool(z.get("walking", false))
            var attack_timer_value := float(z.get("attack_timer", 0.0))
            var attacking := bool(z.get("attacking", false)) and attack_timer_value > 0.02
            var hurt := float(z.get("hit_timer", 0.0)) > 0.02
            var facing_left := float(z.get("face_x", -1.0)) < 0.0
            var phase := float(int(z.get("id", int(entry.index))) % 47) * 0.29 + float(zombie_kind) * 0.8
            var visual_pos := _character_visual_position(pos, true, facing_left, moving, attacking, false, phase, hurt)
            if boss:
                draw_ellipse_shadow(pos + Vector2(0.0, 29.0), 24.0, 6.0, 0.36)
            else:
                draw_circle(pos + Vector2(0, 28), 11.0 if heavy else 8.5, Color(0.005, 0.008, 0.01, 0.34))
            if moving:
                _draw_footstep_dust(pos, phase, true)
            if boss:
                _draw_boss_zombie(visual_pos, facing_left, moving, attacking, hurt, phase, attack_timer_value, int(z.get("attack_type", BOSS_ATTACK_SLASH)))
            else:
                _draw_atlas_character(pos, zombie_kind, true, 1.0, facing_left, moving, attacking, hurt, false, phase)
            if attacking and not boss:
                _draw_zombie_attack_swipe(visual_pos, facing_left, attack_timer_value)
            _draw_zombie_health(z, visual_pos)
        elif entry_type == "barricade":
            var wall: Dictionary = barricades[int(entry.index)]
            pos = Vector2(float(wall.get("x", 0.0)), float(wall.get("y", h * 0.68)))
            _draw_barricade(wall, pos)
        elif entry_type == "turret":
            var turret: Dictionary = turrets[int(entry.index)]
            pos = Vector2(float(turret.get("x", 0.0)), float(turret.get("y", h * 0.68)))
            _draw_turret_entity(turret)
        elif entry_type == "airdrop":
            var drop: Dictionary = airdrops[int(entry.index)]
            pos = Vector2(float(drop.get("x", 0.0)), float(drop.get("y", h * 0.68)))
            _draw_airdrop(drop, pos)
        elif entry_type == "grenade":
            var grenade: Dictionary = active_grenades[int(entry.index)]
            pos = Vector2(float(grenade.get("x", 0.0)), float(grenade.get("y", h * 0.68)))
            var travel_time: float = maxf(0.05, float(grenade.get("travel_time", 0.46)))
            var render_elapsed: float = float(grenade.get("elapsed", 0.0))
            var flight_progress := clampf(render_elapsed / travel_time, 0.0, 1.0)
            var flight_height: float = float(grenade.get("flight_height", 72.0))
            var launch_pos := Vector2(float(grenade.get("start_x", pos.x)), float(grenade.get("start_y", pos.y)))
            var target_pos := Vector2(float(grenade.get("target_x", pos.x)), float(grenade.get("target_y", pos.y)))
            var grenade_ground_pos := pos
            if _is_connected_client():
                grenade_ground_pos = launch_pos.lerp(target_pos, flight_progress)
            var grenade_visual_pos := grenade_ground_pos + Vector2(0.0, -sin(flight_progress * PI) * flight_height)
            var travel_dir: Vector2 = (target_pos - launch_pos).normalized()
            if travel_dir.length_squared() < 0.01:
                travel_dir = Vector2.RIGHT
            # Shadow stays on the pavement. Tiny particles follow the throw direction; no
            # line is drawn from the ground to the airborne sprite, which looked like a pole.
            draw_ellipse_shadow(grenade_ground_pos + Vector2(0.0, 5.0), 7.0, 2.6, 0.36)
            var spark_alpha: float = 0.42 * (1.0 - flight_progress)
            draw_circle(grenade_visual_pos - travel_dir * 5.0, 1.6, Color(0.92, 0.78, 0.48, spark_alpha))
            draw_circle(grenade_visual_pos - travel_dir * 9.0, 1.0, Color(0.79, 0.70, 0.48, spark_alpha * 0.72))
            if grenade_texture != null:
                draw_set_transform(grenade_visual_pos, sin(animation_clock * 14.0 + float(int(grenade.get("id", 0)) % 7)) * 0.12, Vector2.ONE)
                draw_texture_rect(grenade_texture, Rect2(-8.0, -11.0, 16.0, 22.0), false, Color.WHITE)
                draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
            else:
                draw_circle(grenade_visual_pos, 5.5, Color("#455244"))
                draw_arc(grenade_visual_pos, 5.5, 0, TAU, 16, Color("#c7b77e"), 1.2)

    if grenade_aim_active:
        _draw_grenade_aim_preview()
    if wall_place_active:
        _draw_wall_placement_preview()
    if turret_place_active:
        _draw_turret_placement_preview()
    if screen_mode == "game" and aim_marker_enabled:
        _draw_aim_direction_marker()
    _draw_combat_effects()
    _draw_game_hud()

func _draw_barricade(wall: Dictionary, pos: Vector2) -> void:
    var max_hp := maxf(1.0, float(wall.get("max_hp", 125.0)))
    var hp := clampf(float(wall.get("hp", max_hp)) / max_hp, 0.0, 1.0)
    # The position is the character-style center/ground lane coordinate. Keep the feet
    # aligned with the survivor foot line instead of leaving a gap below the sprite.
    var wall_rect := Rect2(pos + BARRICADE_RECT_OFFSET, BARRICADE_RECT_SIZE)
    _draw_barricade_grounding(pos, 1.0)
    if barricade_texture != null:
        # Damage darkens and reddens the wood instead of drawing cracks at fixed (now wrong) spots.
        var damage_tint := BARRICADE_TINT.lerp(Color(0.62, 0.46, 0.42, 1.0), 1.0 - hp)
        draw_texture_rect(barricade_texture, wall_rect, false, damage_tint)
    else:
        # A-frame fallback with broad hazard beam, sloped legs and visible floor contact.
        draw_line(pos + Vector2(-49.0, -22.0), pos + Vector2(-39.0, 33.0), Color("#554739"), 10.0, true)
        draw_line(pos + Vector2(49.0, -22.0), pos + Vector2(39.0, 33.0), Color("#554739"), 10.0, true)
        draw_line(pos + Vector2(-28.0, 6.0), pos + Vector2(28.0, 25.0), Color("#6e5741"), 7.0, true)
        draw_rect(Rect2(pos.x - 56.0, pos.y - 29.0, 112.0, 24.0), Color("#343d3b"))
        for stripe_index in range(7):
            var stripe_x: float = pos.x - 50.0 + float(stripe_index) * 16.0
            draw_line(Vector2(stripe_x, pos.y - 27.0), Vector2(stripe_x + 10.0, pos.y - 7.0), Color("#cfac62"), 5.0, true)
        draw_rect(Rect2(pos.x - 56.0, pos.y - 29.0, 112.0, 24.0), Color("#1b2221"), false, 2.0)
    var hp_bar := Rect2(pos.x - 27.0, wall_rect.position.y - 9.0, 54.0, 4.5)
    draw_rect(Rect2(hp_bar.position - Vector2(1.0, 1.0), hp_bar.size + Vector2(2.0, 2.0)), Color(0.01, 0.015, 0.016, 0.88))
    draw_rect(hp_bar, Color("#302627"))
    draw_rect(Rect2(hp_bar.position, Vector2(hp_bar.size.x * hp, hp_bar.size.y)), Color("#8bb66b") if hp > 0.45 else Color("#d4514b"))

func _draw_barricade_grounding(pos: Vector2, strength: float) -> void:
    # 1) soft cast shadow: hull of the foot pads and the same pads pushed along the light direction
    var hull_source := PackedVector2Array()
    var centroid := Vector2.ZERO
    for foot in BARRICADE_FEET:
        var foot_pos: Vector2 = pos + foot
        hull_source.append(foot_pos)
        hull_source.append(foot_pos + BARRICADE_SHADOW_OFFSET)
        centroid += foot_pos + BARRICADE_SHADOW_OFFSET * 0.5
    centroid /= float(BARRICADE_FEET.size())
    var hull := Geometry2D.convex_hull(hull_source)
    if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
        hull.remove_at(hull.size() - 1)
    if hull.size() >= 3:
        var layers: Array[Vector2] = [Vector2(1.22, 0.14), Vector2(1.11, 0.19), Vector2(1.0, 0.27)]
        for layer in layers:
            var scaled := PackedVector2Array()
            for point in hull:
                scaled.append(centroid + (point - centroid) * layer.x)
            draw_colored_polygon(scaled, Color(0.005, 0.008, 0.008, layer.y * strength))
    # 2) tight contact shadow + wide soft occlusion under every foot pad (sprite is drawn over the top half)
    for i in range(BARRICADE_FEET.size()):
        var foot_pos: Vector2 = pos + BARRICADE_FEET[i] + Vector2(0.0, -0.8)
        var rx: float = BARRICADE_FOOT_RX[i]
        draw_ellipse_shadow(foot_pos + Vector2(0.0, 0.6), rx * 1.55, 4.6, 0.22 * strength)
        draw_ellipse_shadow(foot_pos, rx * 1.05, 3.0, 0.62 * strength)

func draw_ellipse_shadow(center: Vector2, radius_x: float, radius_y: float, alpha: float) -> void:
    var points := PackedVector2Array()
    for i in range(20):
        var angle := TAU * float(i) / 20.0
        points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
    draw_colored_polygon(points, Color(0.005, 0.008, 0.008, alpha))

func _draw_airdrop(drop: Dictionary, pos: Vector2) -> void:
    var landed := bool(drop.get("landed", false))
    var crate_width := 48.0
    var crate_height := crate_width * (float(airdrop_crate_texture.get_height()) / maxf(1.0, float(airdrop_crate_texture.get_width()))) if airdrop_crate_texture != null else 44.0
    var crate_ground_y := pos.y + 35.0 # Match the survivor foot line so the supply does not float above the road.
    var crate_rect := Rect2(Vector2(pos.x - crate_width * 0.5, crate_ground_y - crate_height), Vector2(crate_width, crate_height))

    if not landed:
        # A single canopy texture is used (the previous PNG was an entire spritesheet, so both
        # half-canopies were visibly clipped). Ropes attach to the actual lower edge of the canopy.
        var canopy_pos := pos + Vector2(0.0, -66.0)
        var chute_size := Vector2(96.0, 96.0 / maxf(1.0, float(parachute_texture.get_width()) / maxf(1.0, float(parachute_texture.get_height())))) if parachute_texture != null else Vector2(96.0, 42.0)
        if parachute_texture != null:
            draw_texture_rect(parachute_texture, Rect2(canopy_pos - chute_size * 0.5, chute_size), false, Color(0.94, 0.93, 0.87, 1.0))
        else:
            draw_colored_polygon(PackedVector2Array([canopy_pos + Vector2(-42, 9), canopy_pos + Vector2(-36, -9), canopy_pos + Vector2(-19, -23), canopy_pos + Vector2(0, -28), canopy_pos + Vector2(19, -23), canopy_pos + Vector2(36, -9), canopy_pos + Vector2(42, 9)]), Color("#9c9b82"))
            draw_arc(canopy_pos + Vector2(0, 9), 42.0, PI, TAU, 24, Color("#c5bda0"), 2.0)
        var sling_y := crate_rect.position.y + 2.0
        draw_line(canopy_pos + Vector2(-31.0, 12.0), Vector2(pos.x - 12.0, sling_y), Color(0.36, 0.35, 0.29, 0.96), 1.5, true)
        draw_line(canopy_pos + Vector2(-16.0, 17.0), Vector2(pos.x - 5.0, sling_y), Color(0.70, 0.65, 0.52, 0.94), 1.2, true)
        draw_line(canopy_pos + Vector2(16.0, 17.0), Vector2(pos.x + 5.0, sling_y), Color(0.70, 0.65, 0.52, 0.94), 1.2, true)
        draw_line(canopy_pos + Vector2(31.0, 12.0), Vector2(pos.x + 12.0, sling_y), Color(0.36, 0.35, 0.29, 0.96), 1.5, true)
    else:
        # Flattened contact shadow is aligned to the crate's real bottom edge.
        draw_ellipse_shadow(Vector2(pos.x, crate_ground_y + 0.8), 25.0, 5.2, 0.46)

    if airdrop_crate_texture != null:
        draw_texture_rect(airdrop_crate_texture, crate_rect, false, Color(0.94, 0.91, 0.84, 1.0))
    else:
        draw_rect(crate_rect, Color("#414238"))
        draw_rect(Rect2(crate_rect.position, Vector2(crate_rect.size.x, 4.0)), Color("#837557"))
        draw_rect(crate_rect, Color("#242b25"), false, 2.0)
        draw_line(Vector2(crate_rect.position.x + 4.0, crate_rect.position.y + 4.0), Vector2(crate_rect.end.x - 4.0, crate_rect.end.y - 4.0), Color("#99784d"), 2.0, true)

    var loot_kind := str(drop.get("loot_kind", "grenade"))
    var loot_quantity := maxi(1, int(drop.get("quantity", 1)))
    var loot_tag: String = "SUPPLY DROP"
    var loot_color := Color("#d0c4a0")
    if landed:
        match loot_kind:
            "grenade":
                loot_tag = "GREN +%d" % loot_quantity
                loot_color = Color("#c6ae79")
            "wall":
                loot_tag = "WALL +%d" % loot_quantity
                loot_color = Color("#b9a98a")
            "medkit":
                loot_tag = "MEDKIT +%d" % loot_quantity
                loot_color = Color("#c97868")
            "weapon":
                loot_tag = "%s DROP" % _weapon_name(int(drop.get("weapon_id", WEAPON_SMG)))
                loot_color = Color("#e4bd66")
            "ammo":
                loot_tag = "%s AMMO" % _weapon_name(int(drop.get("weapon_id", WEAPON_SMG)))
                loot_color = Color("#9fd0dc")
            "turret":
                loot_tag = "AUTO TURRET +1"
                loot_color = Color("#d2b57a")

    if landed:
        var remaining := clampf(float(drop.get("despawn_timer", AIRDROP_LAND_LIFETIME)), 0.0, AIRDROP_LAND_LIFETIME)
        var warning := remaining <= 6.0
        var pulse: float = (0.72 + 0.28 * absf(sin(animation_clock * 6.5))) if warning else 1.0
        var label_text := "%s / %02ds" % [loot_tag, ceili(remaining)]
        var label_rect := Rect2(pos.x - 45.0, crate_rect.position.y - 16.0, 90.0, 12.0)
        var tag_color := Color(0.90, 0.30, 0.23, pulse) if warning else loot_color
        draw_rect(label_rect, Color(0.012, 0.016, 0.017, 0.86))
        draw_rect(Rect2(label_rect.position, Vector2(2.0, label_rect.size.y - 1.0)), tag_color)
        draw_string(ui_font, Vector2(label_rect.position.x + 4.0, label_rect.position.y + 8.7), label_text, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x - 8.0, 7, tag_color)
        var progress_width := (label_rect.size.x - 2.0) * remaining / AIRDROP_LAND_LIFETIME
        draw_rect(Rect2(label_rect.position.x + 2.0, label_rect.end.y - 1.5, label_rect.size.x - 4.0, 1.5), Color(0.18, 0.20, 0.18, 0.85))
        if progress_width > 0.0:
            draw_rect(Rect2(label_rect.position.x + 2.0, label_rect.end.y - 1.5, minf(label_rect.size.x - 4.0, progress_width), 1.5), tag_color)
        if warning:
            draw_rect(crate_rect, Color(0.95, 0.24, 0.16, 0.08 * pulse))

func _draw_airdrop_dust_effects() -> void:
    # Landing/expiry dust is rendered before entities so the plume naturally curls behind the crate.
    for effect in combat_effects:
        if int(effect.get("kind", 0)) != 8:
            continue
        var ground_pos := Vector2(float(effect.get("x", 0.0)), float(effect.get("y", 0.0)))
        var life := maxf(0.01, float(effect.get("life", AIRDROP_DESPAWN_EFFECT_DURATION)))
        var ttl := clampf(float(effect.get("ttl", 0.0)), 0.0, life)
        var progress := clampf(1.0 - ttl / life, 0.0, 1.0)
        var alpha := clampf(ttl / life, 0.0, 1.0)
        draw_ellipse_shadow(ground_pos + Vector2(0.0, 1.0), 14.0 + progress * 18.0, 3.0 + progress * 3.0, 0.20 * alpha)
        if airdrop_landing_texture != null:
            var dust_width := 88.0 * (0.80 + progress * 0.35)
            var dust_height := dust_width * float(airdrop_landing_texture.get_height()) / maxf(1.0, float(airdrop_landing_texture.get_width()))
            var dust_rect := Rect2(Vector2(ground_pos.x - dust_width * 0.5, ground_pos.y - dust_height * 0.88), Vector2(dust_width, dust_height))
            draw_texture_rect(airdrop_landing_texture, dust_rect, false, Color(1.0, 1.0, 1.0, alpha * 0.66))
        for puff_index in range(6):
            var puff_side := -1.0 if puff_index % 2 == 0 else 1.0
            var puff_offset := Vector2(puff_side * (8.0 + progress * (8.0 + float(puff_index % 3) * 3.0)), -progress * (2.0 + float(puff_index % 3) * 2.0))
            var puff_radius := (2.0 + float(puff_index % 3) * 1.2) * (0.75 + progress * 0.4)
            draw_circle(ground_pos + puff_offset + Vector2(0.0, 1.2), puff_radius + 0.8, Color(0.025, 0.028, 0.027, alpha * 0.27))
            draw_circle(ground_pos + puff_offset, puff_radius, Color(0.38, 0.35, 0.29, alpha * 0.36))

func _grenade_range_pixels() -> float:
    return screen_size.x * clampf(grenade_aim_range_ratio, GRENADE_MIN_RANGE_RATIO, GRENADE_MAX_RANGE_RATIO)

func _draw_grenade_aim_preview() -> void:
    if not players.has(local_player_id):
        return
    var p: Dictionary = players[local_player_id]
    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))
    var target: Vector2 = grenade_aim_target_position
    target = Vector2(
        clampf(target.x, 30.0, maxf(31.0, screen_size.x - 30.0)),
        clampf(target.y, _arena_top() + ARENA_TOP_CLEARANCE, _arena_bottom() - ARENA_BOTTOM_CLEARANCE)
    )
    var launch_direction: Vector2 = (target - player_pos).normalized()
    if launch_direction.length_squared() < 0.01:
        launch_direction = Vector2(-1.0 if float(p.get("face_x", 1.0)) < 0.0 else 1.0, 0.0)
    var origin: Vector2 = player_pos + launch_direction * 18.0 + Vector2(0.0, -9.0)
    var throw_distance: float = origin.distance_to(target)
    var arc_height: float = clampf(throw_distance * 0.30, 34.0, 116.0)
    var previous: Vector2 = origin
    for point_index in range(1, 31):
        var t: float = float(point_index) / 30.0
        var point: Vector2 = origin.lerp(target, t) + Vector2(0.0, -sin(PI * t) * arc_height)
        if point_index % 2 == 0:
            draw_line(previous, point, Color(0.01, 0.01, 0.01, 0.55), 4.0, true)
            draw_line(previous, point, Color("#e7d19b", 0.92), 2.0, true)
        previous = point
    draw_ellipse_shadow(target + Vector2(0.0, 5.0), 21.0, 7.0, 0.42)
    draw_circle(target, 11.0, Color(0.01, 0.015, 0.018, 0.58))
    draw_arc(target, 17.0, 0.0, TAU, 36, Color("#e7d19b"), 2.0)
    draw_arc(target, 9.0, 0.0, TAU, 28, Color("#c74649"), 2.0)
    draw_line(target + Vector2(-25.0, 0.0), target + Vector2(-11.0, 0.0), Color("#f0d9a7"), 1.5, true)
    draw_line(target + Vector2(11.0, 0.0), target + Vector2(25.0, 0.0), Color("#f0d9a7"), 1.5, true)
    draw_line(target + Vector2(0.0, -25.0), target + Vector2(0.0, -11.0), Color("#f0d9a7"), 1.5, true)
    draw_line(target + Vector2(0.0, 11.0), target + Vector2(0.0, 25.0), Color("#f0d9a7"), 1.5, true)
    var distance_text := "RELEASE • %.1f m" % (player_pos.distance_to(target) / 45.0)
    var label_pos: Vector2 = target + Vector2(0.0, -31.0)
    var label_rect := Rect2(label_pos.x - 55.0, label_pos.y - 15.0, 110.0, 17.0)
    draw_rect(Rect2(label_rect.position + Vector2(1.0, 2.0), label_rect.size), Color(0.0, 0.0, 0.0, 0.28))
    draw_rect(label_rect, Color(0.01, 0.015, 0.018, 0.90))
    draw_rect(Rect2(label_rect.position, Vector2(2.0, label_rect.size.y)), Color("#d6ae64"))
    draw_string(ui_font, Vector2(label_rect.position.x + 5.0, label_rect.position.y + 11.5), distance_text, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x - 10.0, 8, Color("#f4dca7"))

func _draw_wall_placement_preview() -> void:
    var valid := _wall_placement_is_valid(local_player_id, wall_preview_position)
    var preview_rect := Rect2(wall_preview_position + BARRICADE_RECT_OFFSET, BARRICADE_RECT_SIZE)
    var ghost_color := Color(0.73, 1.0, 0.68, 0.73) if valid else Color(1.0, 0.34, 0.34, 0.70)
    _draw_barricade_grounding(wall_preview_position, 0.7)
    if barricade_texture != null:
        draw_texture_rect(barricade_texture, preview_rect, false, ghost_color)
    else:
        draw_rect(preview_rect, ghost_color)
        draw_rect(preview_rect, Color.WHITE, false, 2.0)
    var placement_color := Color("#91d77e") if valid else Color("#ed6262")
    # Flattened ring lying on the road around the barricade footprint (matches the lane perspective).
    draw_set_transform(wall_preview_position + Vector2(0.0, 26.0), 0.0, Vector2(1.0, 0.42))
    draw_arc(Vector2.ZERO, 54.0, 0.0, TAU, 48, Color(placement_color.r, placement_color.g, placement_color.b, 0.85), 3.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    var preview_label := "RELEASE TO DEPLOY" if valid else "MOVE / BLOCKED"
    var label_rect := Rect2(wall_preview_position.x - 66.0, preview_rect.position.y - 20.0, 132.0, 16.0)
    draw_rect(label_rect, Color(0.01, 0.015, 0.018, 0.88))
    draw_rect(Rect2(label_rect.position, Vector2(2.0, label_rect.size.y)), placement_color)
    draw_string(ui_font, Vector2(label_rect.position.x + 4.0, label_rect.position.y + 11.5), preview_label, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x - 8.0, 8, placement_color)

func _draw_weapon_slots(p: Dictionary, control_scale: float) -> void:
    var slot_w := 54.0 * control_scale
    var slot_h := 43.0 * control_scale
    var gap := 4.0 * control_scale
    var total_w := slot_w * 3.0 + gap * 2.0
    var start_x := (screen_size.x - total_w) * 0.5
    var y := screen_size.y - 53.0 * control_scale
    var active_slot := clampi(int(p.get("active_slot", 0)), 0, 2)
    for slot in range(3):
        var rect := Rect2(start_x + float(slot) * (slot_w + gap), y, slot_w, slot_h)
        var weapon_id := WEAPON_SIDEARM if slot == 0 else _slot_type(p, slot)
        var selected := slot == active_slot
        button_rects["game_weapon_%d" % slot] = rect
        draw_rect(Rect2(rect.position + Vector2(1.5, 2.0), rect.size), Color(0.0, 0.0, 0.0, 0.35))
        draw_rect(rect, Color(0.015, 0.025, 0.029, 0.94 if selected else 0.82))
        var edge_color := Color("#e6b75b") if selected else Color("#67716a")
        draw_rect(rect, edge_color, false, 1.7 if selected else 1.0)
        if weapon_id < WEAPON_SMG:
            if slot == 0:
                draw_line(rect.position + Vector2(10.0, 17.0), rect.position + Vector2(43.0, 17.0), Color("#c1c8bd"), 3.0, true)
                draw_line(rect.position + Vector2(22.0, 17.0), rect.position + Vector2(18.0, 25.0), Color("#7c847a"), 3.0, true)
                draw_string(ui_font, rect.position + Vector2(4.0, slot_h - 5.0), "0 SIDEARM", HORIZONTAL_ALIGNMENT_CENTER, slot_w - 8.0, 7, edge_color)
            else:
                draw_string(ui_font, rect.position + Vector2(3.0, slot_h * 0.6), "EMPTY", HORIZONTAL_ALIGNMENT_CENTER, slot_w - 6.0, 8, Color("#818981"))
                draw_string(ui_font, rect.position + Vector2(3.0, slot_h - 5.0), str(slot), HORIZONTAL_ALIGNMENT_CENTER, slot_w - 6.0, 7, Color("#a9b2aa"))
            continue
        var texture: Texture2D = weapon_icon_textures.get(weapon_id) as Texture2D
        if texture != null:
            var icon_rect := Rect2(rect.position + Vector2(5.0, 3.0), Vector2(slot_w - 10.0, 21.0 * control_scale))
            var icon_fit := minf(icon_rect.size.x / maxf(1.0, float(texture.get_width())), icon_rect.size.y / maxf(1.0, float(texture.get_height())))
            var icon_size := Vector2(float(texture.get_width()) * icon_fit, float(texture.get_height()) * icon_fit)
            var fitted := Rect2(icon_rect.position + (icon_rect.size - icon_size) * 0.5, icon_size)
            draw_texture_rect(texture, fitted, false, Color.WHITE)
        var mag := _slot_mag(p, slot)
        var reserve := _slot_reserve(p, slot)
        var caption := "%s %d/%d" % [str(slot), mag, reserve]
        draw_string(ui_font, rect.position + Vector2(2.0, slot_h - 5.0), caption, HORIZONTAL_ALIGNMENT_CENTER, slot_w - 4.0, 7, edge_color)

func _draw_player_weapon(pos: Vector2, p: Dictionary) -> void:
    var weapon_id := _active_weapon_id(p)
    var facing_left := float(p.get("face_x", 1.0)) < 0.0
    var facing_sign := -1.0 if facing_left else 1.0
    var phase := float(p.get("id", local_player_id)) * 1.37
    var moving := bool(p.get("walking", false))
    var gait := sin(animation_clock * 14.0 + phase) if moving else sin(animation_clock * 2.2 + phase) * 0.22
    var bob := gait * (1.2 if moving else 0.35)
    var shoot_timer := float(p.get("shoot_timer", 0.0))
    var recoil := clampf(shoot_timer / 0.19, 0.0, 1.0)
    var weapon_y := 8.0 + bob - recoil * 1.0

    # Weapon sprites are long side-on illustrations. Fit them compactly and anchor their muzzle
    # to the same ~24 px firing origin used by the actual gameplay ray, instead of floating far
    # outside the survivor's hands. Each weapon has its own trigger and foregrip position.
    var draw_w := 34.0
    var grip_ratio := 0.54
    var support_ratio := 0.74
    match weapon_id:
        WEAPON_SIDEARM:
            draw_w = 18.0
            grip_ratio = 0.25
            support_ratio = 0.74
        WEAPON_SMG:
            draw_w = 34.0
            grip_ratio = 0.55
            support_ratio = 0.76
        WEAPON_SHOTGUN:
            draw_w = 36.0
            grip_ratio = 0.19
            support_ratio = 0.61
        WEAPON_RIFLE:
            draw_w = 38.0
            grip_ratio = 0.49
            support_ratio = 0.71
        WEAPON_SNIPER:
            draw_w = 43.0
            grip_ratio = 0.38
            support_ratio = 0.72
        WEAPON_ROCKET:
            draw_w = 38.0
            grip_ratio = 0.57
            support_ratio = 0.77

    var recoil_shift := recoil * 1.8
    var weapon_center := pos + Vector2(facing_sign * (24.0 - draw_w * 0.5 - recoil_shift), weapon_y)
    var grip_x := 24.0 - draw_w * (1.0 - grip_ratio) - recoil_shift
    var support_x := 24.0 - draw_w * (1.0 - support_ratio) - recoil_shift
    var grip_y := weapon_y + 1.0
    var support_y := weapon_y + 0.5
    var grip := pos + Vector2(facing_sign * grip_x, grip_y + bob * 0.18)
    var support_hand := pos + Vector2(facing_sign * support_x, support_y + bob * 0.16)

    # Back arm goes behind the gun; this visually connects the shoulder to the fore-end.
    var rear_shoulder := pos + Vector2(facing_sign * 1.5, -17.0 + bob)
    _draw_weapon_arm_segment(rear_shoulder, support_hand, Color("#4c5148"), false)

    if weapon_id == WEAPON_SIDEARM:
        # Compact pistol with a forward muzzle and a separate angled grip.
        var pistol_muzzle := pos + Vector2(facing_sign * (24.0 - recoil_shift), weapon_y - 1.0)
        var pistol_rear := pos + Vector2(facing_sign * (7.0 - recoil_shift), weapon_y - 1.0)
        draw_line(pistol_rear, pistol_muzzle, Color("#202521"), 5.0, true)
        draw_line(pistol_rear + Vector2(0.0, -0.5), pistol_muzzle + Vector2(0.0, -0.5), Color("#9ba49b"), 1.4, true)
        draw_line(pos + Vector2(facing_sign * (grip_x + 2.0), weapon_y + 1.0), pos + Vector2(facing_sign * (grip_x + 0.5), weapon_y + 7.0), Color("#242923"), 4.0, true)
        draw_line(pos + Vector2(facing_sign * (grip_x + 2.0), weapon_y + 1.0), pos + Vector2(facing_sign * (grip_x + 0.5), weapon_y + 6.0), Color("#8b765e"), 1.6, true)
    else:
        var texture: Texture2D = weapon_icon_textures.get(weapon_id) as Texture2D
        if texture != null:
            var ratio := float(texture.get_width()) / maxf(1.0, float(texture.get_height()))
            var draw_h := draw_w / maxf(1.0, ratio)
            var pos_rect := Rect2(weapon_center - Vector2(draw_w * 0.5, draw_h * 0.5), Vector2(draw_w, draw_h))
            if facing_left:
                draw_set_transform(pos_rect.position + Vector2(draw_w, 0.0), 0.0, Vector2(-1.0, 1.0))
                draw_texture_rect(texture, Rect2(Vector2.ZERO, pos_rect.size), false, Color.WHITE)
                draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
            else:
                draw_texture_rect(texture, pos_rect, false, Color.WHITE)

    # Front arm and hand sit over the trigger/handle, making the weapon feel held rather than pasted on.
    var front_shoulder := pos + Vector2(facing_sign * 5.0, -13.0 + bob)
    _draw_weapon_arm_segment(front_shoulder, grip, Color("#5b5c4c"), true)
    draw_circle(grip, 2.3, Color("#a97550"))
    draw_circle(grip + Vector2(facing_sign * 0.5, -0.6), 1.1, Color("#d6a06e"))
    draw_circle(support_hand, 2.0, Color("#916747"))

    if recoil > 0.12:
        var muzzle := pos + Vector2(facing_sign * (24.0 - recoil_shift), weapon_y - 1.0)
        var strength := clampf(recoil * 1.2, 0.0, 1.0)
        draw_circle(muzzle, 3.0 * strength, Color(1.0, 0.35, 0.06, 0.80 * strength))
        draw_line(muzzle, muzzle + Vector2(facing_sign * 6.0, -1.0), Color(1.0, 0.82, 0.31, 0.95 * strength), 1.8, true)
        draw_line(muzzle + Vector2(0.0, -1.0), muzzle + Vector2(facing_sign * 3.5, -4.0), Color(1.0, 0.55, 0.15, 0.85 * strength), 1.1, true)
        draw_line(muzzle + Vector2(0.0, 1.0), muzzle + Vector2(facing_sign * 3.5, 3.0), Color(1.0, 0.68, 0.22, 0.85 * strength), 1.0, true)

func _draw_weapon_arm_segment(start: Vector2, finish: Vector2, sleeve_color: Color, include_hand: bool = true) -> void:
    # Pixel-friendly outlined forearm with a short skin-toned section near the grip.
    draw_line(start, finish, Color("#252a27"), 5.2, true)
    var skin_start := start.lerp(finish, 0.70)
    draw_line(start, finish, sleeve_color, 3.7, true)
    if include_hand:
        draw_line(skin_start, finish, Color("#8e6348"), 2.8, true)
        draw_line(skin_start + Vector2(0.0, -0.6), finish + Vector2(0.0, -0.6), Color("#c08a5b"), 1.0, true)
        draw_circle(finish, 2.1, Color("#a97550"))

func _draw_aim_direction_marker() -> void:
    # Visual-only aim aid. Actual firing remains host-authoritative and uses the same horizontal lane.
    if not players.has(local_player_id):
        return
    var p: Dictionary = players[local_player_id]
    if float(p.get("hp", 0.0)) <= 0.0:
        return
    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.68)))
    var facing := Vector2.LEFT if float(p.get("face_x", 1.0)) < 0.0 else Vector2.RIGHT
    var weapon_id := _active_weapon_id(p)
    var profile := _weapon_profile(weapon_id)
    var max_range: float = minf(float(profile.get("range", SHOT_RANGE_MAX)), screen_size.x * 0.90)
    var projection_limit := max_range
    var has_target := false
    for zombie in zombies:
        var zombie_pos := Vector2(float(zombie.get("x", 0.0)), float(zombie.get("y", 0.0)))
        var offset := zombie_pos - player_pos
        var projection := offset.dot(facing)
        if projection > 16.0 and projection <= projection_limit and absf(offset.y) <= float(profile.get("lane", SHOT_LANE_TOLERANCE)):
            projection_limit = projection
            has_target = true
    var muzzle := player_pos + facing * 24.0 + Vector2(0.0, 7.0)
    var marker_x := clampf(player_pos.x + facing.x * projection_limit, 8.0, maxf(8.0, screen_size.x - 8.0))
    var marker_pos := Vector2(marker_x, player_pos.y + 7.0)
    var marker_color := Color("#b5df91") if has_target else Color("#d5c79a")
    var available_distance := maxf(0.0, (marker_pos.x - muzzle.x) * facing.x)

    # Light dashed lane guide helps players see exactly which left/right direction FIRE will use.
    var dash := 0.0
    while dash < available_distance - 7.0:
        var seg_start := muzzle + Vector2(facing.x * dash, 0.0)
        var seg_end := muzzle + Vector2(facing.x * minf(dash + 4.0, available_distance - 5.0), 0.0)
        draw_line(seg_start, seg_end, Color(marker_color.r, marker_color.g, marker_color.b, 0.34), 1.0, true)
        dash += 10.0

    # Small chevron near the player gives a clear direction cue even when the range marker is off-screen.
    var cue := muzzle + facing * 14.0
    draw_line(cue + Vector2(-facing.x * 4.0, -3.0), cue + Vector2(0.0, 0.0), Color(marker_color.r, marker_color.g, marker_color.b, 0.88), 1.5, true)
    draw_line(cue + Vector2(0.0, 0.0), cue + Vector2(-facing.x * 4.0, 3.0), Color(marker_color.r, marker_color.g, marker_color.b, 0.88), 1.5, true)

    # Bracket reticle: green means a zombie is currently inside this weapon's effective firing lane.
    var radius := 7.0 if has_target else 6.0
    draw_arc(marker_pos, radius, 0.0, TAU, 24, Color(marker_color.r, marker_color.g, marker_color.b, 0.90), 1.2)
    var tick := 3.0
    draw_line(marker_pos + Vector2(-radius - tick, 0.0), marker_pos + Vector2(-radius + 1.0, 0.0), marker_color, 1.2, true)
    draw_line(marker_pos + Vector2(radius - 1.0, 0.0), marker_pos + Vector2(radius + tick, 0.0), marker_color, 1.2, true)
    draw_line(marker_pos + Vector2(0.0, -radius - tick), marker_pos + Vector2(0.0, -radius + 1.0), marker_color, 1.2, true)
    draw_line(marker_pos + Vector2(0.0, radius - 1.0), marker_pos + Vector2(0.0, radius + tick), marker_color, 1.2, true)
    draw_circle(marker_pos, 1.2, Color(marker_color.r, marker_color.g, marker_color.b, 0.95))

func _draw_game_hud() -> void:
    var w := screen_size.x
    var h := screen_size.y
    var local_p: Dictionary = players.get(local_player_id, {})

    var left_rect := Rect2(14, 12, minf(355.0, w * 0.39), 61.0)
    draw_rect(Rect2(left_rect.position + Vector2(3, 4), left_rect.size), Color(0.0, 0.0, 0.0, 0.42))
    draw_rect(left_rect, Color(0.015, 0.025, 0.03, 0.94))
    draw_rect(Rect2(left_rect.position, Vector2(4, left_rect.size.y)), Color("#c84a4e"))
    draw_rect(Rect2(left_rect.position.x + 4, left_rect.position.y, left_rect.size.x - 4, 2), Color("#7f3438"))
    draw_string(ui_font, Vector2(29, 34), "PIXEL ZOMBIE  /  OUTBREAK", HORIZONTAL_ALIGNMENT_LEFT, left_rect.size.x - 26, 14, Color("#f0e9df"))
    var mode_label := "SOLO" if is_offline else ("HOST" if is_host else ("LAN CLIENT" if _is_connected_client() else "OFFLINE"))
    draw_string(ui_font, Vector2(29, 55), "%s  •  SQUAD %d/4  •  ZOMBIES %d" % [mode_label, players.size(), zombies.size()], HORIZONTAL_ALIGNMENT_LEFT, left_rect.size.x - 26, 9, Color("#b7c1bd"))

    var wave_w := 166.0
    var wave_x := w * 0.5 - wave_w * 0.5
    wave_x = clampf(wave_x, left_rect.position.x + left_rect.size.x + 10.0, w - 294.0)
    draw_rect(Rect2(wave_x + 3, 15, wave_w, 62), Color(0.0, 0.0, 0.0, 0.34))
    draw_rect(Rect2(wave_x, 12, wave_w, 61), Color(0.015, 0.025, 0.03, 0.95))
    draw_rect(Rect2(wave_x, 12, wave_w, 3), Color("#cf4b50"))
    var wave_title := "BOSS WAVE %02d" % wave_number if wave_number % 10 == 0 else "WAVE %02d" % wave_number
    var wave_title_color := Color("#ed8171") if wave_number % 10 == 0 else Color("#f0d08d")
    draw_string(ui_font, Vector2(wave_x + 12, 31), wave_title, HORIZONTAL_ALIGNMENT_LEFT, wave_w - 24, 15 if wave_number % 10 != 0 else 13, wave_title_color)
    draw_string(ui_font, Vector2(wave_x + 12, 43), "ELIMINATED  %02d / %02d" % [wave_kills, wave_total], HORIZONTAL_ALIGNMENT_LEFT, wave_w - 24, 8, Color("#c9d0c7"))
    var wave_seconds := ceili(wave_time_remaining)
    var wave_minutes := int(wave_seconds / 60)
    var wave_clock_text := "OVERTIME" if wave_timed_out else ("CLEAR IN %02d" % ceili(wave_break_timer) if wave_break_timer > 0.0 else "TIME  %02d:%02d" % [wave_minutes, wave_seconds % 60])
    var clock_color := Color("#e66b61") if wave_timed_out else Color("#c5cbbd")
    draw_string(ui_font, Vector2(wave_x + 12, 55), wave_clock_text, HORIZONTAL_ALIGNMENT_LEFT, wave_w - 24, 9, clock_color)
    var progress_rect := Rect2(wave_x + 12, 64, wave_w - 24, 4)
    draw_rect(progress_rect, Color("#343a39"))
    draw_rect(Rect2(progress_rect.position, Vector2(progress_rect.size.x * clampf(float(wave_kills) / float(maxi(1, wave_total)), 0.0, 1.0), progress_rect.size.y)), Color("#bf4449"))
    if wave_break_timer > 0.0:
        var break_rect := Rect2(w * 0.5 - 125, 78, 250, 28)
        draw_rect(break_rect, Color(0.015, 0.02, 0.022, 0.91))
        draw_rect(Rect2(break_rect.position, Vector2(3, break_rect.size.y)), Color("#cf4b50"))
        draw_string(ui_font, Vector2(break_rect.position.x + 10, 97), "WAVE CLEAR  •  NEXT IN %d" % ceili(wave_break_timer), HORIZONTAL_ALIGNMENT_CENTER, break_rect.size.x - 18, 12, Color("#f1d89c"))

    var hp := clampi(int(local_p.get("hp", 100)), 0, 100)
    var medkits := int(local_p.get("medkits", 2))
    var grenades := int(local_p.get("grenades", 3))
    var wall_kits := int(local_p.get("wall_kits", 2))
    var turret_kits := int(local_p.get("turret_kits", 0))
    var health_rect := Rect2(w - 274.0, 12, 239.0, 61.0)
    draw_rect(Rect2(health_rect.position + Vector2(3, 4), health_rect.size), Color(0.0, 0.0, 0.0, 0.40))
    draw_rect(health_rect, Color(0.015, 0.025, 0.03, 0.94))
    draw_rect(Rect2(health_rect.position.x, health_rect.position.y, health_rect.size.x, 2), Color("#6f3439"))
    var hp_color := Color("#bd4147") if hp <= 30 else (Color("#d2a052") if hp <= 58 else Color("#8bc26d"))
    draw_string(ui_font, Vector2(w - 260, 31), "VITALS  %d%%" % hp, HORIZONTAL_ALIGNMENT_LEFT, 215, 12, Color("#f0e9df"))
    var hp_rect := Rect2(w - 260, 37, 211.0, 6.0)
    draw_rect(hp_rect, Color("#45292b"))
    draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * float(hp) / 100.0, hp_rect.size.y)), hp_color)
    var active_weapon := _active_weapon_id(local_p)
    var ammo_text := "AMMO ∞" if active_weapon == WEAPON_SIDEARM else "AMMO %d/%d" % [_slot_mag(local_p, int(local_p.get("active_slot", 0))), _slot_reserve(local_p, int(local_p.get("active_slot", 0)))]
    if float(local_p.get("reload_timer", 0.0)) > 0.0:
        ammo_text = "RELOAD %.1fs" % float(local_p.get("reload_timer", 0.0))
    draw_string(ui_font, Vector2(w - 260, 62), "%s • G%d M%d W%d T%d" % [ammo_text, grenades, medkits, wall_kits, turret_kits], HORIZONTAL_ALIGNMENT_LEFT, 219, 7, Color("#d5c7a9"))

    var control_scale := _control_scale()
    var joystick_radius := _joystick_radius()
    joystick_origin = Vector2(maxf(joystick_radius + 24.0, w * 0.092), h - 91.0 * control_scale)
    draw_circle(joystick_origin + Vector2(2, 4), joystick_radius + 2, Color(0.0, 0.0, 0.0, 0.46))
    draw_circle(joystick_origin, joystick_radius, Color(0.012, 0.025, 0.027, 0.78))
    draw_arc(joystick_origin, joystick_radius, 0, TAU, 36, Color("#9ba8a0"), 2.0)
    draw_arc(joystick_origin, joystick_radius - 7.0, 0, TAU, 36, Color(0.63, 0.22, 0.25, 0.42), 1.0)
    draw_colored_polygon(PackedVector2Array([joystick_origin + Vector2(0, -joystick_radius + 10), joystick_origin + Vector2(-5, -joystick_radius + 18), joystick_origin + Vector2(5, -joystick_radius + 18)]), Color("#c3c8bc"))
    draw_circle(joystick_origin + joystick_vector * (joystick_radius * 0.53), 17.0 * control_scale, Color(0.78, 0.83, 0.77, 0.96))
    draw_arc(joystick_origin + joystick_vector * (joystick_radius * 0.53), 17.0 * control_scale, 0, TAU, 28, Color("#26312e"), 1.5)
    draw_string(ui_font, Vector2(joystick_origin.x - 26, joystick_origin.y + joystick_radius + 18), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 52, 9, Color("#d1d5cb"))

    var fire_pos := Vector2(w - 77.0 * control_scale, h - 89.0 * control_scale)
    var heal_pos := Vector2(w - 171.0 * control_scale, h - 61.0 * control_scale)
    var grenade_pos := Vector2(w - 173.0 * control_scale, h - 137.0 * control_scale)
    var wall_pos := Vector2(w - 82.0 * control_scale, h - 177.0 * control_scale)
    var turret_pos := Vector2(w - 82.0 * control_scale, h - 239.0 * control_scale)
    _draw_action_button("game_fire", fire_pos, 41.0 * control_scale, "FIRE", Color("#b83f45"))
    _draw_action_button("game_heal", heal_pos, 31.0 * control_scale, "HEAL", Color("#647d57"))
    var grenade_label := "DRAG" if grenade_aim_active else "GREN %d" % grenades
    var wall_label := "DRAG" if wall_place_active else "WALL %d" % wall_kits
    _draw_action_button("game_grenade", grenade_pos, 29.0 * control_scale, grenade_label, Color("#d0a14b") if grenade_aim_active else Color("#8b7850"))
    _draw_action_button("game_build", wall_pos, 29.0 * control_scale, wall_label, Color("#8bb775") if wall_place_active else Color("#69756b"))
    var turret_label := "DRAG" if turret_place_active else "TUR %d" % turret_kits
    _draw_action_button("game_turret", turret_pos, 27.0 * control_scale, turret_label, Color("#d0ac62") if turret_place_active else Color("#66745d"))
    _draw_weapon_slots(local_p, control_scale)
    _draw_ui_button("game_aim_toggle", Rect2(w * 0.66 - 43.0 * control_scale, 112.0 * control_scale, 86.0 * control_scale, 34.0 * control_scale), "AIM", "ON" if aim_marker_enabled else "OFF", Color("#8bb775") if aim_marker_enabled else Color("#7b8584"), false)
    _draw_ui_button("game_pause", Rect2(w - 65.0, 72.0, 49.0, 41.0), "Ⅱ", "", Color("#c19a68"), false)
    if SHOW_NET_STATS and _is_connected_client():
        _draw_net_stats()

func _draw_net_stats() -> void:
    var rtt_text := "%d ms" % net_rtt_ms if net_rtt_ms >= 0 else "--"
    var hold_text := "  HOLD" if render_starved else ""
    var stats_text := "NET  RTT %s  ·  LOSS %.1f%%  ·  %.0f snap/s  ·  %.1f KB/s  ·  BUF %d ms  ·  ERR %.1f px%s" % [rtt_text, net_loss_pct, net_snaps_per_s, net_kbps, int(interp_delay * 1000.0), pred_error_px, hold_text]
    var box := Rect2(screen_size.x * 0.5 - 215.0, screen_size.y - 20.0, 430.0, 15.0)
    draw_rect(box, Color(0.0, 0.0, 0.0, 0.38))
    draw_string(ui_font, Vector2(box.position.x + 6.0, box.position.y + 11.0), stats_text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 12.0, 9, Color(0.72, 0.86, 0.74, 0.9))

func _draw_pause_menu() -> void:
    var w := screen_size.x
    var h := screen_size.y
    draw_rect(Rect2(0, 0, w, h), Color(0.005, 0.008, 0.014, 0.76))
    draw_rect(Rect2(0, 0, w, 4), Color("#c64b50"))
    var panel_w := minf(400.0, w * 0.68)
    var panel_h := minf(370.0, h - 36.0)
    var panel := Rect2((w - panel_w) * 0.5, (h - panel_h) * 0.5, panel_w, panel_h)
    _draw_panel(panel, "PAUSED  /  SAFEHOUSE", "CATCH YOUR BREATH. THE HORDE WILL RETURN.")
    var x := panel.position.x + 24.0
    var bw := panel.size.x - 48.0
    _draw_ui_button("pause_resume", Rect2(x, panel.position.y + 88.0, bw, 55.0), "RESUME SURVIVAL", "BACK TO THE DEFENSE LANE", Color("#cc4b50"), true)
    _draw_ui_button("pause_save", Rect2(x, panel.position.y + 156.0, bw, 49.0), "SAVE WORLD", "HOST ONLY", Color("#c18a55"), false)
    _draw_ui_button("pause_home", Rect2(x, panel.position.y + 218.0, bw, 49.0), "ABANDON SESSION", "RETURN TO SAFEHOUSE", Color("#b94a50"), false)
    draw_string(ui_font, Vector2(x, panel.position.y + panel.size.y - 20.0), ui_status, HORIZONTAL_ALIGNMENT_LEFT, bw, 9, Color("#b9c0b8"))

func _draw_game_over_menu() -> void:
    var w := screen_size.x
    var h := screen_size.y
    draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.015, 0.005, 0.012, 0.76))
    draw_rect(Rect2(0, 0, w, 5), Color("#d84b52"))
    var panel_w := minf(440.0, w * 0.72)
    var panel_h := minf(286.0, h - 34.0)
    var panel := Rect2((w - panel_w) * 0.5, (h - panel_h) * 0.5, panel_w, panel_h)
    _draw_panel(panel, "SQUAD ELIMINATED", "THE HORDE OVERRAN YOUR DEFENSE LINE.")
    draw_string(ui_font, Vector2(panel.position.x + 25, panel.position.y + 91), "WAVE %02d  •  ELIMINATED %02d / %02d" % [wave_number, wave_kills, wave_total], HORIZONTAL_ALIGNMENT_LEFT, panel_w - 50, 12, Color("#e0c89c"))
    draw_string(ui_font, Vector2(panel.position.x + 25, panel.position.y + 113), "ZOMBIES STILL ACTIVE: %d" % zombies.size(), HORIZONTAL_ALIGNMENT_LEFT, panel_w - 50, 10, Color("#bac3bd"))
    var button_x := panel.position.x + 24.0
    var button_w := panel_w - 48.0
    _draw_ui_button("gameover_restart", Rect2(button_x, panel.position.y + 138.0, button_w, 48.0), "RESTART RUN", "RESET WAVE, HEALTH AND ZOMBIES", Color("#c84a4e"), true)
    _draw_ui_button("gameover_home", Rect2(button_x, panel.position.y + 197.0, button_w, 43.0), "RETURN TO SAFEHOUSE", "LEAVE THIS SESSION", Color("#9aa78d"), false)
    if not is_host:
        draw_string(ui_font, Vector2(button_x, panel.position.y + panel.size.y - 8.0), "RESTART REQUEST GOES TO HOST", HORIZONTAL_ALIGNMENT_CENTER, button_w, 8, Color("#c3a08f"))

func _draw_panel(rect: Rect2, heading: String, subtitle: String) -> void:
    draw_rect(Rect2(rect.position + Vector2(6, 7), rect.size), Color(0.0, 0.0, 0.0, 0.46))
    draw_rect(rect, Color("#11191c"))
    draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), Color("#b7454a"))
    draw_rect(Rect2(rect.position.x + 4, rect.position.y + 4, rect.size.x - 8, rect.size.y - 8), Color("#202a2b"), false, 1.0)
    draw_rect(Rect2(rect.position.x + 18, rect.position.y + 15, 4, 26), Color("#c34a4f"))
    draw_string(ui_font, rect.position + Vector2(32, 31), heading, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 58, 15, Color("#f0e9df"))
    if not subtitle.is_empty():
        draw_string(ui_font, rect.position + Vector2(32, 51), subtitle, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 58, 9, Color("#c09b8e"))
    draw_rect(Rect2(rect.position.x + 20, rect.position.y + 62, rect.size.x - 40, 1), Color("#41484a"))
    draw_rect(Rect2(rect.position.x + rect.size.x - 24, rect.position.y + 20, 5, 5), Color("#c34a4f"))

func _draw_ui_button(id: String, rect: Rect2, title: String, subtitle: String, accent: Color, primary: bool) -> void:
    button_rects[id] = rect
    draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0.0, 0.0, 0.0, 0.38))
    var base := Color("#3a191d") if primary else Color("#182225")
    draw_rect(rect, base)
    draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), accent)
    draw_rect(Rect2(rect.position.x + 4, rect.position.y, rect.size.x - 4, 2), Color(accent.r, accent.g, accent.b, 0.45))
    draw_rect(Rect2(rect.position, rect.size), Color("#754044") if primary else Color("#3e4c4e"), false, 1.0)
    # Small indicator on the right is a visual cue, not an extra hit target.
    var indicator_x := rect.position.x + rect.size.x - 18.0
    draw_rect(Rect2(indicator_x, rect.position.y + rect.size.y * 0.5 - 3.0, 6.0, 6.0), accent)
    var title_y := rect.position.y + (rect.size.y * 0.5 + 4.0 if subtitle.is_empty() else rect.size.y * 0.5 - 2.0)
    draw_string(ui_font, Vector2(rect.position.x + 16, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 38, 13 if primary else 12, Color("#f2ece3"))
    if not subtitle.is_empty():
        draw_string(ui_font, Vector2(rect.position.x + 16, title_y + 17), subtitle, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 38, 9, Color("#c0c3bb"))

func _draw_action_button(id: String, pos: Vector2, radius: float, label: String, color: Color) -> void:
    var rect := Rect2(pos - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
    button_rects[id] = rect
    var is_pressed := id == "game_fire" and fire_held
    draw_circle(pos + Vector2(2, 4), radius + 2.0, Color(0.0, 0.0, 0.0, 0.48))
    draw_circle(pos, radius + 2.0, Color("#101719"))
    if is_pressed:
        draw_circle(pos, radius + 8.0, Color(0.92, 0.18, 0.19, 0.20))
    draw_circle(pos, radius, color.lightened(0.17) if is_pressed else color)
    draw_arc(pos, radius, 0, TAU, 40, Color("#ead8c9") if is_pressed else Color("#bbb8a7"), 2.0)
    draw_arc(pos, radius - 5.0, 0, TAU, 40, Color(0.18, 0.04, 0.05, 0.70), 1.0)
    if id == "game_fire":
        for i in range(3):
            var casing := Rect2(pos.x - 12.0 + float(i) * 8.0, pos.y - 13.0, 4.0, 11.0)
            draw_rect(casing, Color("#f4d29a"))
            draw_rect(Rect2(casing.position.x, casing.position.y, casing.size.x, 3.0), Color("#fff0cb"))
        draw_string(ui_font, pos + Vector2(-radius + 2.0, 22.0), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0 - 4.0, 11, Color.WHITE)
    elif id == "game_heal":
        draw_rect(Rect2(pos.x - 3.5, pos.y - 11.0, 7.0, 22.0), Color("#eff1df"))
        draw_rect(Rect2(pos.x - 11.0, pos.y - 3.5, 22.0, 7.0), Color("#eff1df"))
        draw_string(ui_font, pos + Vector2(-radius + 2.0, radius * 0.62), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0 - 4.0, 9, Color.WHITE)
    elif id == "game_grenade":
        if grenade_texture != null:
            draw_texture_rect(grenade_texture, Rect2(pos.x - 10.0, pos.y - 17.0, 20.0, 24.0), false, Color.WHITE)
        else:
            draw_circle(pos + Vector2(0, -4), 8.0, Color("#252a21"))
            draw_arc(pos + Vector2(0, -4), 8.0, 0, TAU, 20, Color("#d4bc81"), 1.5)
        draw_string(ui_font, pos + Vector2(-radius + 1.0, radius * 0.67), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0 - 2.0, 8, Color.WHITE)
    elif id == "game_turret":
        draw_line(pos + Vector2(-12.0, 7.0), pos + Vector2(-7.0, -2.0), Color("#28312d"), 4.0, true)
        draw_line(pos + Vector2(-7.0, -2.0), pos + Vector2(0.0, 7.0), Color("#9fa18a"), 3.0, true)
        draw_line(pos + Vector2(0.0, 7.0), pos + Vector2(12.0, 7.0), Color("#28312d"), 4.0, true)
        draw_rect(Rect2(pos.x - 10.0, pos.y - 10.0, 19.0, 11.0), Color("#252d2a"))
        draw_rect(Rect2(pos.x - 8.0, pos.y - 8.0, 15.0, 7.0), Color("#89907a"))
        draw_line(pos + Vector2(3.0, -5.0), pos + Vector2(15.0, -5.0), Color("#252d2a"), 4.0, true)
        draw_line(pos + Vector2(4.0, -5.0), pos + Vector2(15.0, -5.0), Color("#b1a47b"), 1.5, true)
        draw_string(ui_font, pos + Vector2(-radius + 1.0, radius * 0.67), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0 - 2.0, 8, Color.WHITE)
    else:
        if barricade_texture != null:
            draw_texture_rect(barricade_texture, Rect2(pos.x - 10.2, pos.y - 19.0, 20.5, 30.0), false, Color.WHITE)
        else:
            for plank_index in range(3):
                var plank_x: float = pos.x - 12.0 + float(plank_index) * 9.0
                draw_rect(Rect2(plank_x, pos.y - 12.0, 6.0, 22.0), Color("#c5b58d"))
        draw_string(ui_font, pos + Vector2(-radius + 1.0, radius * 0.67), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0 - 2.0, 8, Color.WHITE)

func _draw_title_text(pos: Vector2, label: String, size: int, color: Color) -> void:
    draw_string(ui_font, pos + Vector2(3, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.0, 0.0, 0.75))
    draw_string(ui_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _player_sprite_index(id: int) -> int:
    return posmod(id - 1, 4)

func _character_visual_position(pos: Vector2, zombie: bool, facing_left: bool, moving: bool, attacking: bool, shooting: bool, phase: float, hurt: bool = false) -> Vector2:
    var cadence := animation_clock * (14.0 if moving else 2.35) + phase
    var bob_amount := 2.9 if moving else 0.55
    var bob := sin(cadence) * bob_amount
    if moving:
        bob -= absf(sin(cadence * 0.5)) * 1.0
    var facing_sign := -1.0 if facing_left else 1.0
    var lunge := 0.0
    if zombie and attacking:
        lunge = 3.0 + 3.6 * sin(animation_clock * 21.0 + phase)
    elif shooting:
        lunge = -2.0
    var hurt_shake := -facing_sign * 1.8 * sin(animation_clock * 54.0) if hurt else 0.0
    var stride_sway := sin(cadence) * 0.85 if moving else 0.0
    return pos + Vector2(facing_sign * lunge + hurt_shake + stride_sway, bob)

func _draw_boss_zombie(pos: Vector2, facing_left: bool, moving: bool, attacking: bool, hurt: bool, phase: float, attack_timer: float = 0.0, attack_type: int = BOSS_ATTACK_SLASH) -> void:
    if boss_texture == null:
        _draw_atlas_character(pos, 2, true, 1.48, facing_left, moving, attacking, hurt, false, phase)
        return
    attack_type = clampi(attack_type, BOSS_ATTACK_SLASH, BOSS_ATTACK_LUNGE)
    var duration := _boss_attack_duration(attack_type)
    var attack_progress := clampf(1.0 - attack_timer / duration, 0.0, 1.0) if attacking else 0.0
    var cadence := animation_clock * (10.5 if moving else 2.2) + phase
    var gait := sin(cadence)
    var facing_sign := -1.0 if facing_left else 1.0
    var rotation := gait * (0.043 if moving else 0.004)
    var sx := 1.0 + gait * (0.017 if moving else 0.002)
    var sy := 1.0 - gait * (0.021 if moving else 0.003)
    var visual_pos := pos + Vector2(gait * (2.2 if moving else 0.0), -absf(sin(cadence * 0.5)) * (1.7 if moving else 0.0))
    var pulse := 0.5 + 0.5 * sin(animation_clock * 5.2 + phase)
    draw_circle(pos + Vector2(0.0, -5.0), 31.0 + pulse * 4.0, Color(0.92, 0.035, 0.055, 0.045 + pulse * 0.035))
    if moving:
        draw_arc(pos + Vector2(0.0, 29.0), 26.0 + pulse * 2.0, 0.0, TAU, 28, Color(0.91, 0.10, 0.12, 0.18), 1.2)
    if attacking:
        match attack_type:
            BOSS_ATTACK_SLASH:
                rotation -= facing_sign * (0.018 + 0.052 * sin(attack_progress * PI))
                sx += 0.018 * sin(attack_progress * PI)
            BOSS_ATTACK_SLAM:
                rotation += facing_sign * (0.025 if attack_progress < 0.42 else -0.035)
                sy += 0.035 * sin(attack_progress * PI)
            BOSS_ATTACK_LUNGE:
                rotation -= facing_sign * 0.052
                sx += 0.035 * sin(attack_progress * PI)
                sy -= 0.012 * sin(attack_progress * PI)
    var tint := Color.WHITE
    if hurt and int(animation_clock * 32.0) % 2 == 0:
        tint = Color(1.0, 0.60, 0.56, 1.0)
    var flip_x := -sx if facing_left else sx
    draw_set_transform(visual_pos, rotation, Vector2(flip_x, sy))

    var frame_texture: Texture2D = null
    var frame_index := 0
    if attacking and boss_attack_textures.size() > attack_type:
        frame_texture = boss_attack_textures[attack_type]
        frame_index = _boss_attack_frame(attack_type, attack_progress)
    if frame_texture != null:
        var frame_width := BOSS_ATTACK_FRAME_WIDTH
        var frame_height := BOSS_ATTACK_FRAME_HEIGHT
        var drawn_height := 92.0
        var drawn_width := drawn_height * frame_width / frame_height
        var drawn_top := 33.0 - drawn_height * BOSS_ATTACK_BASELINE_Y / frame_height
        var dest := Rect2(Vector2(-drawn_width * 0.5, drawn_top), Vector2(drawn_width, drawn_height))
        var source := Rect2(float(frame_index) * frame_width, 0.0, frame_width, frame_height)
        draw_texture_rect_region(frame_texture, dest, source, tint, false, true)
    else:
        var boss_width := 92.0
        var boss_size := Vector2(boss_width, boss_width * float(boss_texture.get_height()) / maxf(1.0, float(boss_texture.get_width())))
        draw_texture_rect(boss_texture, Rect2(Vector2(-boss_size.x * 0.5, -boss_size.y + 33.0), boss_size), false, tint)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_atlas_character(pos: Vector2, kind: int, zombie: bool, scale_value: float = 1.0, facing_left: bool = false, moving: bool = false, attacking: bool = false, hurt: bool = false, shooting: bool = false, phase: float = 0.0, opacity: float = 1.0) -> void:
    var visual_alpha := clampf(opacity, 0.0, 1.0)
    if sprite_atlas == null:
        var fallback_pos := _character_visual_position(pos, zombie, facing_left, moving, attacking, shooting, phase, hurt)
        var fallback_color := Color("#ac4b4d") if hurt else _player_color(kind + 1)
        fallback_color.a = visual_alpha
        var stride := sin(animation_clock * 14.0 + phase) * (2.0 if moving else 0.0)
        draw_rect(Rect2(fallback_pos + Vector2(-8.0, -9.0 + stride), Vector2(16.0, 18.0)), fallback_color)
        return
    # The atlas contains one pose per character; animate the lower-body layer around the hips
    # while retaining the original clean pixel silhouette for idle/attack poses.
    var svg_layout := sprite_atlas.get_height() >= 240
    var cell_width := 80 if svg_layout else 64
    var source_y := 80 if zombie else 0
    var source_x := clampi(kind, 0, 3) * cell_width
    var size := Vector2(58.0, 70.0) * scale_value
    if zombie and kind == 2:
        size = Vector2(64.0, 70.0) * scale_value

    var cadence := animation_clock * (14.0 if moving else 2.35) + phase
    var gait := sin(cadence)
    var facing_sign := -1.0 if facing_left else 1.0
    var visual_pos := _character_visual_position(pos, zombie, facing_left, moving, attacking, shooting, phase, hurt)
    var rotation := gait * (0.041 if moving else 0.009)
    var scale_x := 1.0 + gait * (0.018 if moving else 0.003)
    var scale_y := 1.0 - absf(gait) * (0.022 if moving else 0.004)
    if zombie and attacking:
        rotation = -facing_sign * 0.09 + sin(animation_clock * 21.0 + phase) * 0.028
        scale_x += 0.045 * sin(animation_clock * 21.0 + phase)
        scale_y -= 0.024 * sin(animation_clock * 21.0 + phase)
    elif shooting:
        rotation -= facing_sign * (0.055 + clampf(sin(animation_clock * 34.0 + phase), 0.0, 1.0) * 0.012)
        scale_y += 0.018
    var tint := Color(1.0, 1.0, 1.0, visual_alpha)
    if hurt and int(animation_clock * 32.0) % 2 == 0:
        tint = Color(1.0, 0.57, 0.54, visual_alpha)

    var flip_x := -scale_x if facing_left else scale_x
    if moving and not attacking:
        var upper_source_height := 53.0
        var lower_source_y := 48.0
        var lower_source_height := 80.0 - lower_source_y
        var pivot_y := -size.y * 0.5 + lower_source_y * size.y / 80.0
        var upper_source := Rect2(source_x, source_y, cell_width, upper_source_height)
        var upper_dest := Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y * upper_source_height / 80.0)
        draw_set_transform(visual_pos, rotation, Vector2(flip_x, scale_y))
        draw_texture_rect_region(sprite_atlas, upper_dest, upper_source, tint, false, true)

        var lower_source := Rect2(source_x, source_y + lower_source_y, cell_width, lower_source_height)
        var lower_height := size.y * lower_source_height / 80.0
        var leg_angle := -gait * (0.19 if zombie else 0.155)
        var leg_shift_x := gait * (2.6 if zombie else 2.2)
        var foot_lift := absf(gait) * (1.1 if zombie else 0.85)
        var lower_dest := Rect2(-size.x * 0.5, 0.0, size.x, lower_height)
        draw_set_transform(visual_pos + Vector2(leg_shift_x, pivot_y + foot_lift), rotation + leg_angle, Vector2(flip_x, scale_y))
        draw_texture_rect_region(sprite_atlas, lower_dest, lower_source, tint, false, true)
    else:
        draw_set_transform(visual_pos, rotation, Vector2(flip_x, scale_y))
        var dest := Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y)
        var source_rect := Rect2(source_x, source_y, cell_width, 80)
        draw_texture_rect_region(sprite_atlas, dest, source_rect, tint, false, true)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_footstep_dust(pos: Vector2, phase: float, zombie: bool) -> void:
    var cadence := animation_clock * 14.0 + phase
    var step := sin(cadence)
    var fade := 0.12 + 0.17 * absf(cos(cadence))
    var color := Color(0.48, 0.58, 0.44, fade) if zombie else Color(0.67, 0.63, 0.53, fade * 0.72)
    draw_circle(pos + Vector2(-8.0 + step * 5.5, 29.0), 2.2 + absf(step) * 1.2, color)
    draw_circle(pos + Vector2(7.0 - step * 4.5, 30.0), 1.7 + absf(step) * 0.8, Color(color.r, color.g, color.b, fade * 0.72))

func _draw_zombie_attack_swipe(pos: Vector2, facing_left: bool, attack_timer: float) -> void:
    var phase := clampf(1.0 - attack_timer / 0.38, 0.0, 1.0)
    var envelope := sin(phase * PI)
    if envelope <= 0.03:
        return
    var dir := -1.0 if facing_left else 1.0
    var base := pos + Vector2(dir * 18.0, -5.0)
    for slash_index in range(3):
        var vertical := float(slash_index - 1) * 5.0
        var start := base + Vector2(dir * -2.0, vertical - 5.0)
        var finish := base + Vector2(dir * (8.0 + float(slash_index) * 2.0), vertical + 5.0)
        draw_line(start, finish, Color(0.58, 0.10, 0.14, envelope * 0.72), 2.4, true)
        draw_line(start + Vector2(0.0, -1.0), finish + Vector2(0.0, -1.0), Color(0.95, 0.44, 0.36, envelope * 0.55), 1.0, true)

func _draw_survivor(pos: Vector2, color: Color, scale_value: float) -> void:
    var sprite_index := 0
    for i in range(4):
        if color == _player_color(i + 1):
            sprite_index = i
            break
    _draw_atlas_character(pos, sprite_index, false, 0.65 * scale_value)

func _draw_zombie_health(zombie: Dictionary, pos: Vector2) -> void:
    var kind := clampi(int(zombie.get("kind", 0)), 0, ZOMBIE_KIND_BOSS)
    var default_max_hp := _zombie_max_hp_for(kind, wave_number)
    var max_hp := maxf(1.0, float(zombie.get("max_hp", default_max_hp)))
    var hp := clampf(float(zombie.get("hp", max_hp)) / max_hp, 0.0, 1.0)
    var is_boss := kind == ZOMBIE_KIND_BOSS
    var bar_width := 72.0 if is_boss else (44.0 if kind == 2 else 38.0)
    var bar_y := pos.y - 64.0 if is_boss else pos.y - 44.0
    var bar_rect := Rect2(pos.x - bar_width * 0.5, bar_y, bar_width, 6.0)
    if is_boss:
        draw_string(ui_font, Vector2(pos.x - 22.0, pos.y - 67.0), "BOSS", HORIZONTAL_ALIGNMENT_CENTER, 44.0, 8, Color("#f0c677"))
    draw_rect(Rect2(bar_rect.position - Vector2(2, 2), bar_rect.size + Vector2(4, 4)), Color(0.01, 0.012, 0.014, 0.90))
    draw_rect(bar_rect, Color("#4c2025"))
    var health_color := Color("#d0aa61") if hp > 0.55 else (Color("#d46a4f") if hp > 0.25 else Color("#dc414a"))
    draw_rect(Rect2(bar_rect.position + Vector2(1, 1), Vector2(maxf(0.0, (bar_width - 2.0) * hp), 4.0)), health_color)
    draw_rect(bar_rect, Color("#e0c79b") if is_boss else Color("#c7b6a7"), false, 1.0)

func _draw_combat_effects() -> void:
    for effect in combat_effects:
        var kind := clampi(int(effect.get("kind", 0)), 0, 14)
        if kind == 8:
            continue
        var start_pos := Vector2(float(effect.get("x", 0.0)), float(effect.get("y", 0.0)))
        var end_pos := Vector2(float(effect.get("x2", start_pos.x)), float(effect.get("y2", start_pos.y)))
        var life := maxf(0.01, float(effect.get("life", 0.18)))
        var ttl := clampf(float(effect.get("ttl", 0.0)), 0.0, life)
        var progress := clampf(1.0 - ttl / life, 0.0, 1.0)
        var alpha := clampf(ttl / minf(0.20, life), 0.0, 1.0)

        if kind == 10:
            var pellet_dir := (end_pos - start_pos).normalized()
            if pellet_dir.length_squared() < 0.01:
                pellet_dir = Vector2.RIGHT
            var pellet_pos := start_pos.lerp(end_pos, progress)
            draw_line(pellet_pos - pellet_dir * 8.0, pellet_pos + pellet_dir * 2.0, Color(1.0, 0.78, 0.43, alpha * 0.9), 1.7, true)
            draw_circle(pellet_pos, 1.4, Color(1.0, 0.92, 0.67, alpha))
        elif kind == 11:
            var scope_dir := (end_pos - start_pos).normalized()
            if scope_dir.length_squared() < 0.01:
                scope_dir = Vector2.RIGHT
            var scope_end := start_pos.lerp(end_pos, progress)
            draw_line(start_pos, scope_end, Color(1.0, 0.83, 0.56, alpha * 0.26), 1.0, true)
            draw_line(scope_end - scope_dir * 10.0, scope_end + scope_dir * 3.0, Color(1.0, 0.95, 0.77, alpha), 2.2, true)
            draw_circle(scope_end, 1.8, Color(1.0, 0.96, 0.79, alpha))
        elif kind == 12:
            var rocket_dir := (end_pos - start_pos).normalized()
            if rocket_dir.length_squared() < 0.01:
                rocket_dir = Vector2.RIGHT
            var rocket_pos := start_pos.lerp(end_pos, progress)
            draw_line(start_pos, rocket_pos, Color(0.94, 0.44, 0.17, alpha * 0.4), 2.0, true)
            draw_line(rocket_pos - rocket_dir * 13.0, rocket_pos - rocket_dir * 5.0, Color(0.92, 0.43, 0.16, alpha), 3.0, true)
            draw_line(rocket_pos - rocket_dir * 9.0 + Vector2(0.0, -2.0), rocket_pos - rocket_dir * 2.0 + Vector2(0.0, -2.0), Color(1.0, 0.82, 0.43, alpha * 0.9), 1.2, true)
            draw_circle(rocket_pos, 2.7, Color(0.52, 0.53, 0.43, alpha))
            for smoke_index in range(3):
                var smoke_pos := rocket_pos - rocket_dir * (7.0 + float(smoke_index) * 4.0) + Vector2(0.0, sin(progress * 28.0 + float(smoke_index)) * 2.0)
                draw_circle(smoke_pos, 1.7 + float(smoke_index) * 0.45, Color(0.28, 0.28, 0.24, alpha * (0.62 - float(smoke_index) * 0.12)))
        elif kind == 13:
            var rifle_dir := (end_pos - start_pos).normalized()
            if rifle_dir.length_squared() < 0.01:
                rifle_dir = Vector2.RIGHT
            var rifle_pos := start_pos.lerp(end_pos, progress)
            draw_line(start_pos, rifle_pos, Color(1.0, 0.61, 0.22, alpha * 0.24), 2.0, true)
            draw_line(rifle_pos - rifle_dir * 7.0, rifle_pos + rifle_dir * 1.5, Color(1.0, 0.86, 0.53, alpha), 2.0, true)
        elif kind == 14:
            var smg_dir := (end_pos - start_pos).normalized()
            if smg_dir.length_squared() < 0.01:
                smg_dir = Vector2.RIGHT
            var smg_pos := start_pos.lerp(end_pos, progress)
            draw_line(smg_pos - smg_dir * 4.0, smg_pos, Color(1.0, 0.64, 0.24, alpha), 1.0, true)
            draw_circle(smg_pos, 1.2, Color(1.0, 0.85, 0.48, alpha))
        elif kind == 1:
            # Move actual atlas ammunition across the lane with only a short tracer.
            var bullet_dir := (end_pos - start_pos).normalized()
            if bullet_dir.length_squared() < 0.01:
                bullet_dir = Vector2.RIGHT
            var bullet_pos := start_pos.lerp(end_pos, progress)
            if sprite_atlas != null:
                var bullet_rect := Rect2(bullet_pos - Vector2(11.0, 7.0), Vector2(22.0, 14.0))
                draw_texture_rect_region(sprite_atlas, bullet_rect, Rect2(32, 160, 32, 32), Color(1, 1, 1, alpha), false, true)
            else:
                draw_circle(bullet_pos, 2.2, Color(1.0, 0.87, 0.45, alpha))
            draw_line(bullet_pos - bullet_dir * 5.0, bullet_pos - bullet_dir * 2.0, Color(1.0, 0.52, 0.17, alpha * 0.8), 1.5, true)
        elif kind == 5:
            # Host-synchronized claw slash: short, three-pronged streak instead of a huge flash.
            var slash_dir := -1.0 if end_pos.x < start_pos.x else 1.0
            var slash_len := 8.0 + 15.0 * progress
            for slash_index in range(3):
                var offset_y := float(slash_index - 1) * 5.0
                var slash_start := start_pos + Vector2(slash_dir * float(slash_index) * 2.0, offset_y - 4.0)
                var slash_end := end_pos + Vector2(-slash_dir * slash_len, offset_y + 4.0)
                draw_line(slash_start, slash_end, Color(0.72, 0.12, 0.15, alpha * 0.82), 2.2, true)
                draw_line(slash_start + Vector2(0, -1), slash_end + Vector2(0, -1), Color(0.98, 0.47, 0.39, alpha * 0.62), 1.0, true)
        elif kind == 6:
            # A short white-hot flash, a ground-hugging pressure ring, ballistic debris,
            # orange embers and a rising smoke column. All particles are deterministic per effect id.
            var blast_seed := int(effect.get("eid", 0))
            var flash := clampf(1.0 - progress / 0.11, 0.0, 1.0)
            var fire_fade := clampf(1.0 - progress / 0.36, 0.0, 1.0)
            var ring_progress := clampf(progress / 0.78, 0.0, 1.0)
            var ring_alpha := clampf(1.0 - progress / 0.84, 0.0, 1.0)
            var blast_radius: float = 8.0 + 96.0 * ring_progress

            # Blast soot is grounded on the pavement, with an elliptical shock front.
            draw_ellipse_shadow(start_pos + Vector2(0.0, 7.0), 14.0 + 49.0 * ring_progress, 3.4 + 6.4 * ring_progress, 0.22 * (1.0 - progress * 0.55))
            draw_set_transform(start_pos + Vector2(0.0, 6.0), 0.0, Vector2(1.0, 0.28))
            draw_arc(Vector2.ZERO, blast_radius, 0.0, TAU, 52, Color(0.86, 0.43, 0.25, ring_alpha * 0.48), 1.6 * ring_alpha + 0.25)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

            # Use a dedicated transparent blast asset for textured flame/smoke detail.
            # Scale swells quickly, then the artwork fades while the independently animated
            # sparks, debris, shock ring and residual smoke continue through the effect lifetime.
            if grenade_explosion_texture != null:
                var asset_growth := 0.72 + 0.32 * clampf(progress / 0.20, 0.0, 1.0)
                var asset_fade := clampf(1.0 - progress / 1.08, 0.0, 1.0)
                var asset_ratio := float(grenade_explosion_texture.get_width()) / maxf(1.0, float(grenade_explosion_texture.get_height()))
                var asset_width := 214.0 * asset_growth
                var asset_size := Vector2(asset_width, asset_width / maxf(1.0, asset_ratio))
                var asset_rect := Rect2(Vector2(start_pos.x - asset_size.x * 0.5, start_pos.y - asset_size.y + 10.0), asset_size)
                draw_texture_rect(grenade_explosion_texture, asset_rect, false, Color(0.97, 0.95, 0.90, asset_fade * 0.95))
            else:
                # Procedural emergency fallback if the optional texture cannot be imported.
                if flash > 0.01:
                    draw_circle(start_pos + Vector2(0.0, -4.0), 18.0 + 34.0 * flash, Color(1.0, 0.88, 0.65, flash * 0.82))
                    draw_circle(start_pos + Vector2(0.0, -5.0), 12.0 + 24.0 * flash, Color(1.0, 0.46, 0.12, flash * 0.90))
                    draw_circle(start_pos + Vector2(-1.0, -6.0), 6.0 + 15.0 * flash, Color(1.0, 0.96, 0.78, flash * 0.92))
                if fire_fade > 0.01:
                    var fire_radius: float = 29.0 * pow(fire_fade, 1.25) + 1.0
                    draw_circle(start_pos + Vector2(0.0, -3.0), fire_radius, Color(0.77, 0.12, 0.045, fire_fade * 0.78))
                    draw_circle(start_pos + Vector2(-2.0, -6.0), fire_radius * 0.68, Color(1.0, 0.42, 0.09, fire_fade * 0.88))
                    draw_circle(start_pos + Vector2(-3.0, -8.0), fire_radius * 0.32, Color(1.0, 0.82, 0.37, fire_fade * 0.90))

            # Hot fragments shoot outward first, then fall back toward the street.
            var ember_progress := clampf(progress / 0.78, 0.0, 1.0)
            for spark_index in range(12):
                var spark_angle := TAU * float(spark_index) / 12.0 + float(blast_seed % 17) * 0.13
                var spark_dir := Vector2(cos(spark_angle), sin(spark_angle))
                var spark_distance: float = (18.0 + float((spark_index * 7 + blast_seed) % 17) * 2.2) * ember_progress
                var spark_height: float = sin(ember_progress * PI) * (9.0 + float(spark_index % 5) * 5.0)
                var spark_pos: Vector2 = start_pos + Vector2(spark_dir.x * spark_distance, spark_dir.y * spark_distance * 0.45 - spark_height + ember_progress * ember_progress * 13.0)
                var spark_alpha := clampf(1.0 - progress / 0.88, 0.0, 1.0)
                var spark_len: float = (3.5 + float((spark_index * 3) % 6)) * spark_alpha
                draw_line(spark_pos - spark_dir * spark_len, spark_pos, Color(1.0, 0.74, 0.35, spark_alpha * 0.90), 1.5, true)
                draw_circle(spark_pos, 1.0 + float(spark_index % 3) * 0.35, Color(1.0, 0.88, 0.60, spark_alpha))

            # Dark stone/metal chips follow separate shallow arcs; deterministic motion avoids jitter on clients.
            var debris_progress := clampf(progress / 0.98, 0.0, 1.0)
            var debris_alpha := clampf(1.0 - progress / 1.02, 0.0, 1.0)
            for debris_index in range(9):
                var debris_angle := TAU * float(debris_index) / 9.0 + float((blast_seed % 11)) * 0.19
                var debris_dir := Vector2(cos(debris_angle), sin(debris_angle))
                var debris_distance: float = (24.0 + float((debris_index * 11 + blast_seed) % 31) * 1.65) * debris_progress
                var debris_arc: float = sin(debris_progress * PI) * (13.0 + float(debris_index % 4) * 5.0)
                var debris_pos: Vector2 = start_pos + Vector2(debris_dir.x * debris_distance, debris_dir.y * debris_distance * 0.48 - debris_arc + debris_progress * debris_progress * 22.0)
                var chip_size: float = 1.6 + float(debris_index % 3) * 0.75
                draw_line(debris_pos - debris_dir * 3.0, debris_pos, Color(0.10, 0.095, 0.085, debris_alpha * 0.78), 2.2, true)
                draw_set_transform(debris_pos, debris_angle + float(debris_index) * 0.7, Vector2.ONE)
                draw_rect(Rect2(-chip_size, -chip_size * 0.55, chip_size * 2.0, chip_size * 1.1), Color(0.20, 0.19, 0.17, debris_alpha * 0.94))
                draw_rect(Rect2(-chip_size, -chip_size * 0.55, chip_size * 2.0, chip_size * 1.1), Color(0.63, 0.54, 0.41, debris_alpha * 0.72), false, 0.7)
                draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

            # The plume comes after the fireball: heavy dark smoke at the core, warmer dust at the edges.
            var smoke_rise := clampf((progress - 0.07) / 0.93, 0.0, 1.0)
            var smoke_alpha := clampf((progress - 0.06) / 0.20, 0.0, 1.0) * clampf(1.0 - maxf(0.0, progress - 0.28) / 0.78, 0.0, 1.0) * 0.34
            for smoke_index in range(8):
                var smoke_angle := TAU * float(smoke_index) / 8.0 + float(blast_seed % 13) * 0.17
                var smoke_spread: float = 4.0 + smoke_rise * (9.0 + float(smoke_index % 4) * 5.0)
                var smoke_pos: Vector2 = start_pos + Vector2(cos(smoke_angle) * smoke_spread, -smoke_rise * (12.0 + float(smoke_index % 5) * 9.0) + sin(smoke_angle) * 4.0)
                var smoke_radius: float = 3.5 + smoke_rise * (5.0 + float(smoke_index % 4) * 2.2)
                var smoke_color := Color(0.16, 0.15, 0.14, smoke_alpha * (0.74 + float(smoke_index % 3) * 0.09))
                draw_circle(smoke_pos + Vector2(1.2, 1.8), smoke_radius + 1.5, Color(0.045, 0.045, 0.043, smoke_alpha * 0.76))
                draw_circle(smoke_pos, smoke_radius, smoke_color)
                if smoke_index % 3 == 0:
                    draw_circle(smoke_pos + Vector2(-2.0, -2.2), smoke_radius * 0.55, Color(0.34, 0.29, 0.23, smoke_alpha * 0.44))
        elif kind == 7:
            var pickup_radius := 8.0 + progress * 25.0
            draw_arc(start_pos, pickup_radius, 0, TAU, 24, Color(0.78, 0.89, 0.56, alpha), 2.0)
            draw_circle(start_pos, 3.0 + (1.0 - progress) * 4.0, Color(0.9, 0.96, 0.69, alpha))
        elif kind == 9:
            # Heavy Brute impact: a pavement-hugging pressure ring with dust and loose debris.
            var ring_t := clampf(progress / 0.76, 0.0, 1.0)
            var ring_radius := 12.0 + 76.0 * ring_t
            var ring_alpha := clampf(1.0 - progress / 0.82, 0.0, 1.0)
            draw_ellipse_shadow(start_pos + Vector2(0.0, 4.0), 18.0 + 42.0 * ring_t, 4.0 + 5.0 * ring_t, 0.30 * ring_alpha)
            draw_set_transform(start_pos + Vector2(0.0, 3.0), 0.0, Vector2(1.0, 0.24))
            draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(0.88, 0.64, 0.39, ring_alpha * 0.74), 2.1 * ring_alpha + 0.35)
            draw_arc(Vector2.ZERO, ring_radius * 0.72, 0.0, TAU, 40, Color(0.47, 0.41, 0.32, ring_alpha * 0.42), 1.3 * ring_alpha + 0.25)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
            for debris_index in range(9):
                var debris_angle := TAU * float(debris_index) / 9.0 + float(int(effect.get("eid", 0)) % 7) * 0.17
                var debris_dir := Vector2(cos(debris_angle), sin(debris_angle))
                var debris_dist := (13.0 + float((debris_index * 7) % 19) * 2.2) * ring_t
                var debris_arc := sin(ring_t * PI) * (7.0 + float(debris_index % 4) * 3.0)
                var debris_pos := start_pos + Vector2(debris_dir.x * debris_dist, debris_dir.y * debris_dist * 0.42 - debris_arc + ring_t * ring_t * 8.0)
                var chip_size := (1.0 + float(debris_index % 3) * 0.65) * ring_alpha
                draw_line(debris_pos - debris_dir * 3.5, debris_pos, Color(0.42, 0.36, 0.28, ring_alpha * 0.88), 1.5, true)
                draw_circle(debris_pos, chip_size, Color(0.67, 0.58, 0.43, ring_alpha * 0.84))
            for dust_index in range(7):
                var dust_side := -1.0 if dust_index % 2 == 0 else 1.0
                var dust_x := dust_side * (9.0 + float(dust_index) * 6.0) * ring_t
                var dust_y := -ring_t * (2.0 + float(dust_index % 3) * 3.0)
                var dust_radius := (2.5 + float(dust_index % 3) * 1.5) * ring_alpha
                draw_circle(start_pos + Vector2(dust_x, dust_y), dust_radius, Color(0.48, 0.43, 0.34, ring_alpha * 0.48))
        elif sprite_atlas != null:
            var source_x := kind * 32
            var effect_size := Vector2(24, 24) if kind == 0 or kind == 2 or kind == 3 else Vector2(27, 27)
            if kind == 4:
                effect_size = Vector2(30, 30)
            var fx_alpha := minf(1.0, alpha * 1.25)
            draw_texture_rect_region(sprite_atlas, Rect2(start_pos - effect_size * 0.5, effect_size), Rect2(source_x, 160, 32, 32), Color(1, 1, 1, fx_alpha), false, true)

func _player_label(id: int) -> String:
    var ids: Array = players.keys()
    ids.sort()
    var index := ids.find(id)
    return "P%d" % (index + 1 if index >= 0 else 1)

func _handle_ui_button(id: String) -> void:
    if id.begins_with("game_weapon_"):
        var selected_slot := clampi(int(id.trim_prefix("game_weapon_")), 0, 2)
        _request_weapon_switch(selected_slot)
        return
    match id:
        "home_lan":
            screen_mode = "lobby"
            ui_status = "Create a world or join a friend on the same hotspot."
        "home_solo":
            _start_offline(false)
        "home_continue":
            _start_offline(true)
        "home_controls":
            screen_mode = "help"
        "help_back":
            screen_mode = "home"
        "lobby_back":
            if is_host or _is_connected_client():
                _leave_world()
            screen_mode = "home"
        "lobby_host":
            _start_host()
        "lobby_join":
            _show_join_dialog()
        "lobby_start":
            _begin_game()
        "lobby_copy":
            if not host_lan_ip.is_empty() and host_lan_ip != "unknown":
                DisplayServer.clipboard_set(host_lan_ip)
                ui_status = "Host IP copied: %s" % host_lan_ip
        "lobby_save":
            _save_world()
        "lobby_leave":
            _leave_world()
            ui_status = "Lobby disconnected"
        "game_aim_toggle":
            aim_marker_enabled = not aim_marker_enabled
            var control_settings := ConfigFile.new()
            control_settings.load("user://settings.cfg")
            control_settings.set_value("controls", "aim_marker_enabled", aim_marker_enabled)
            control_settings.save("user://settings.cfg")
            ui_status = "AIM ASSIST MARKER %s" % ("ON" if aim_marker_enabled else "OFF")
        "game_pause":
            screen_mode = "pause"
            joystick_vector = Vector2.ZERO
            joystick_active = false
            fire_held = false
            fire_touch_id = -1
            fire_repeat_timer = 0.0
            grenade_requested = false
            build_requested = false
            _cancel_targeting_modes()
        "game_fire":
            fire_requested = true
        "game_heal":
            heal_requested = true
        "game_grenade":
            if grenade_aim_active:
                grenade_requested = true
            else:
                _begin_grenade_aim()
        "game_build":
            if wall_place_active:
                build_requested = true
            else:
                _begin_wall_placement()
        "game_turret":
            if turret_place_active:
                turret_requested = true
            else:
                _begin_turret_placement()
        "pause_resume":
            screen_mode = "game"
        "pause_save":
            if is_host:
                _save_world()
            else:
                ui_status = "Only the host can save the world."
        "pause_home":
            _leave_world()
            screen_mode = "home"
        "gameover_restart":
            if is_host:
                _restart_run()
            elif _is_connected_client():
                rpc_id(1, "request_restart")
                ui_status = "Restart requested — waiting for the host"
            else:
                ui_status = "Start a new run from the safehouse"
        "gameover_home":
            _leave_world()
            screen_mode = "home"

func _handle_press(pos: Vector2, touch_id: int = -1) -> bool:
    for id in button_rects.keys():
        var rect: Rect2 = button_rects[id]
        if rect.has_point(pos):
            if str(id) == "game_fire" and screen_mode == "game":
                fire_held = true
                fire_touch_id = touch_id
            _handle_ui_button(str(id))
            return true
    return false

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _touch_start(event.index, event.position)
        else:
            _touch_end(event.index)
    elif event is InputEventScreenDrag:
        if joystick_active and event.index == joystick_touch_id:
            joystick_vector = ((event.position - joystick_origin) / _joystick_radius()).limit_length(1.0)
        elif event.index == grenade_aim_touch_id and grenade_aim_active:
            _update_grenade_target_from_pointer(event.position)
        elif event.index == wall_place_touch_id and wall_place_active:
            _set_wall_preview_from_pointer(event.position)
        elif event.index == turret_place_touch_id and turret_place_active:
            _set_turret_preview_from_pointer(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _touch_start(-2, event.position)
        else:
            _touch_end(-2)
    elif event is InputEventMouseMotion:
        if joystick_active and joystick_touch_id == -2:
            joystick_vector = ((event.position - joystick_origin) / _joystick_radius()).limit_length(1.0)
        elif grenade_aim_touch_id == -2 and grenade_aim_active:
            _update_grenade_target_from_pointer(event.position)
        elif wall_place_touch_id == -2 and wall_place_active:
            _set_wall_preview_from_pointer(event.position)
        elif turret_place_touch_id == -2 and turret_place_active:
            _set_turret_preview_from_pointer(event.position)

func _touch_start(index: int, pos: Vector2) -> void:
    if screen_mode == "game":
        var grenade_rect: Rect2 = button_rects.get("game_grenade", Rect2())
        if grenade_rect.has_point(pos):
            _begin_grenade_aim(index)
            return
        var wall_rect: Rect2 = button_rects.get("game_build", Rect2())
        if wall_rect.has_point(pos):
            _begin_wall_placement(index)
            return
        var turret_rect: Rect2 = button_rects.get("game_turret", Rect2())
        if turret_rect.has_point(pos):
            _begin_turret_placement(index)
            return
    if _handle_press(pos, index):
        return
    if screen_mode != "game":
        return
    # Keep compatibility with a second pointer adjusting a placement preview when needed.
    if wall_place_active and wall_place_touch_id < 0 and pos.y >= _arena_top() - 5.0 and pos.y <= _arena_bottom() + 8.0:
        wall_place_touch_id = index
        _set_wall_preview_from_pointer(pos)
        return
    if grenade_aim_active and grenade_aim_touch_id < 0 and pos.y >= _arena_top() - 5.0 and pos.y <= _arena_bottom() + 8.0:
        grenade_aim_touch_id = index
        _update_grenade_target_from_pointer(pos)
        return
    if turret_place_active and turret_place_touch_id < 0 and pos.y >= _arena_top() - 5.0 and pos.y <= _arena_bottom() + 8.0:
        turret_place_touch_id = index
        _set_turret_preview_from_pointer(pos)
        return
    if pos.x < screen_size.x * 0.40 and pos.y > screen_size.y * 0.57 and not joystick_active:
        joystick_active = true
        joystick_touch_id = index
        joystick_vector = ((pos - joystick_origin) / _joystick_radius()).limit_length(1.0)

func _touch_end(index: int) -> void:
    if index == grenade_aim_touch_id:
        grenade_aim_touch_id = -1
        if grenade_aim_active:
            grenade_requested = true
    if index == wall_place_touch_id:
        wall_place_touch_id = -1
        if wall_place_active:
            build_requested = true
    if index == turret_place_touch_id:
        turret_place_touch_id = -1
        if turret_place_active:
            turret_requested = true
    if index == fire_touch_id:
        fire_held = false
        fire_touch_id = -1
        fire_repeat_timer = 0.0
    if index == joystick_touch_id:
        joystick_active = false
        joystick_touch_id = -1
        joystick_vector = Vector2.ZERO

func _show_join_dialog() -> void:
    var dialog := ConfirmationDialog.new()
    dialog.title = "Join LAN World"
    dialog.dialog_text = "Enter the host phone's Wi-Fi IPv4 address. Port: %d" % PORT
    dialog.min_size = Vector2i(440, 200)
    var line := LineEdit.new()
    line.placeholder_text = "Host IP, e.g. 192.168.43.1"
    line.text = host_ip
    line.clear_button_enabled = true
    line.position = Vector2(20, 82)
    line.size = Vector2(395, 38)
    dialog.add_child(line)
    dialog.confirmed.connect(func():
        host_ip = line.text.strip_edges()
        _join_host(host_ip)
    )
    dialog.canceled.connect(func():
        dialog.queue_free()
    )
    add_child(dialog)
    dialog.popup_centered()

