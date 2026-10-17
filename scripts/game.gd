extends Node2D

# Pixel Zombie LAN — wave defense prototype v0.3.9
# Host-authoritative 4-player survival over ENet/UDP on a local Wi-Fi network.

const PORT := 24567
const MAX_PLAYERS := 4
const PLAYER_SPEED := 150.0
const ZOMBIE_SPEED := 28.0
const ZOMBIE_MAX_HP := [3.0, 4.0, 7.0, 3.5]
const WAVE_ZOMBIE_COUNT := 25
const SHOT_RANGE_MAX := 560.0
const SHOT_LANE_TOLERANCE := 25.0
const FIRE_REPEAT_INTERVAL := 0.30
const ARENA_TOP_RATIO := 0.565
const ARENA_BOTTOM_RATIO := 0.92
const SNAPSHOT_INTERVAL := 0.10 # 10 world snapshots/second
const INPUT_INTERVAL := 0.05    # 20 input updates/second
const SAVE_PATH := "user://world_save.json"

var screen_mode := "home" # home, help, lobby, game, pause
var is_offline := false
var button_rects: Dictionary = {}
var sprite_atlas: Texture2D
var background_texture: Texture2D
var combat_effects: Array[Dictionary] = []
var wave_number := 1
var wave_total := WAVE_ZOMBIE_COUNT
var wave_spawned := 0
var wave_kills := 0
var wave_spawn_timer := 0.9
var wave_break_timer := 0.0

var peer: ENetMultiplayerPeer
var players: Dictionary = {}
var input_vectors: Dictionary = {}
var zombies: Array[Dictionary] = []
var target_players: Dictionary = {}
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
var client_input_timer := 0.0
var snapshot_timer := 0.0
var fire_cooldowns: Dictionary = {}
var heal_cooldowns: Dictionary = {}
var ui_status := "Offline — tap HOST or JOIN"
var ui_font: Font
var screen_size := Vector2(960, 540)
var last_save_time := 0.0

func _ready() -> void:
    randomize()
    # Landscape is configured in project.godot and export_presets.cfg before startup.
    # Do not force runtime rotation here: Android can otherwise start with a stale portrait viewport.
    screen_mode = "home"
    world_seed = randi()
    ui_font = ThemeDB.fallback_font
    if ui_font == null:
        push_warning("Pixel Zombie LAN: theme fallback font was not available at startup.")
    # Prefer detailed raster assets. Draw functions retain a visible fallback if a texture is missing.
    sprite_atlas = load("res://assets/sprite_atlas.png") as Texture2D
    if sprite_atlas == null:
        sprite_atlas = load("res://assets/sprite_atlas.svg") as Texture2D
    background_texture = load("res://assets/arena_bg.jpg") as Texture2D
    if background_texture == null:
        background_texture = load("res://assets/arena_bg.svg") as Texture2D
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

    if screen_mode == "game":
        if is_host:
            input_vectors[local_player_id] = joystick_vector
            _host_simulate(delta)
            snapshot_timer += delta
            if snapshot_timer >= SNAPSHOT_INTERVAL:
                snapshot_timer = 0.0
                _broadcast_world()
            if world_time - last_save_time >= 30.0:
                _save_world(false)
                last_save_time = world_time
        elif _is_connected_client():
            client_input_timer += delta
            if client_input_timer >= INPUT_INTERVAL:
                client_input_timer = 0.0
                rpc_id(1, "submit_input", joystick_vector)
            _interpolate_client_state(delta)

        _process_action_requests(delta)
    queue_redraw()

func _is_connected_client() -> bool:
    return multiplayer.multiplayer_peer != null and not is_host and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

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
        rpc_id(1, "request_fire")
    else:
        ui_status = "Tap HOST to start a survival world"

func _process_action_requests(delta: float) -> void:
    if fire_requested:
        fire_requested = false
        _request_fire_once()
        fire_repeat_timer = FIRE_REPEAT_INTERVAL
    elif fire_held:
        fire_repeat_timer -= delta
        if fire_repeat_timer <= 0.0:
            _request_fire_once()
            fire_repeat_timer = FIRE_REPEAT_INTERVAL
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

func _host_simulate(delta: float) -> void:
    world_time += delta

    # Host owns movement state: clients submit a direction, never a claimed position.
    for id_variant in players.keys():
        var id := int(id_variant)
        var p: Dictionary = players[id]
        var movement: Vector2 = input_vectors.get(id, Vector2.ZERO).limit_length(1.0)
        if float(p.get("hp", 0.0)) > 0.0:
            p["x"] = clampf(float(p.get("x", screen_size.x * 0.5)) + movement.x * PLAYER_SPEED * delta, 30.0, maxf(31.0, screen_size.x - 30.0))
            p["y"] = clampf(float(p.get("y", screen_size.y * 0.68)) + movement.y * PLAYER_SPEED * delta, _arena_top() + 30.0, _arena_bottom() - 30.0)
            # Side-view shooter: keep a left/right facing so shots travel on a straight horizontal lane.
            if absf(movement.x) > 0.14:
                p["face_x"] = -1.0 if movement.x < 0.0 else 1.0
        players[id] = p

    for effect_index in range(combat_effects.size() - 1, -1, -1):
        var active_effect: Dictionary = combat_effects[effect_index]
        active_effect["ttl"] = float(active_effect.get("ttl", 0.0)) - delta
        if float(active_effect["ttl"]) <= 0.0:
            combat_effects.remove_at(effect_index)
        else:
            combat_effects[effect_index] = active_effect

    # One wave contains 25 zombies. A short intermission starts only after all are defeated.
    if wave_break_timer > 0.0:
        wave_break_timer = maxf(0.0, wave_break_timer - delta)
        if wave_break_timer <= 0.0:
            wave_number += 1
            wave_total = WAVE_ZOMBIE_COUNT
            wave_spawned = 0
            wave_kills = 0
            wave_spawn_timer = 1.0
            ui_status = "Wave %d incoming — hold the middle!" % wave_number
    else:
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
        for id_variant in players.keys():
            var id := int(id_variant)
            var p: Dictionary = players[id]
            if float(p.get("hp", 0.0)) <= 0.0:
                continue
            var distance := zombie_pos.distance_to(Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))))
            if distance < nearest_distance:
                nearest_distance = distance
                target_id = id
        if target_id != -1:
            var target: Dictionary = players[target_id]
            if nearest_distance > 18.0:
                var direction := (Vector2(float(target.x), float(target.y)) - zombie_pos).normalized()
                var zombie_kind := clampi(int(z.get("kind", 0)), 0, ZOMBIE_MAX_HP.size() - 1)
                var speed_scale := 0.68 if zombie_kind == 2 else (1.25 if zombie_kind == 3 else 1.0)
                if absf(direction.x) > 0.08:
                    z["face_x"] = -1.0 if direction.x < 0.0 else 1.0
                z["x"] = clampf(float(z.x) + direction.x * ZOMBIE_SPEED * speed_scale * delta, 30.0, maxf(31.0, screen_size.x - 30.0))
                z["y"] = clampf(float(z.y) + direction.y * ZOMBIE_SPEED * speed_scale * delta, _arena_top() + 31.0, _arena_bottom() - 31.0)
            else:
                target["hp"] = maxf(0.0, float(target.get("hp", 0.0)) - 8.0 * delta)
                players[target_id] = target
        zombies[zi] = z

    if wave_break_timer <= 0.0 and wave_spawned >= wave_total and zombies.is_empty():
        wave_break_timer = 4.0
        ui_status = "WAVE %d CLEAR — next wave in 4 seconds" % wave_number

func _spawn_wave_zombie() -> void:
    var kind_roll := randi_range(0, 99)
    var zombie_kind := 0
    if wave_number >= 2 and kind_roll < 10:
        zombie_kind = 2 # Heavy
    elif kind_roll < 31:
        zombie_kind = 3 # Runner
    elif kind_roll < 57:
        zombie_kind = 1 # Worker
    var zombie_hp := float(ZOMBIE_MAX_HP[zombie_kind])
    var spawn_left := randf() < 0.5
    var spawn_y := randf_range(_arena_top() + 35.0, _arena_bottom() - 35.0)
    var spawn_x := 34.0 if spawn_left else screen_size.x - 34.0
    zombies.append({
        "id": randi(),
        "kind": zombie_kind,
        "x": spawn_x,
        "y": spawn_y,
        "face_x": 1.0 if spawn_left else -1.0,
        "hp": zombie_hp,
        "max_hp": zombie_hp
    })

func _spawn_local_player() -> void:
    var id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1
    local_player_id = id
    if not players.has(id):
        players[id] = _make_player(id)
    if not input_vectors.has(id):
        input_vectors[id] = Vector2.ZERO

func _make_player(id: int) -> Dictionary:
    var spawn := Vector2(screen_size.x * 0.5, screen_size.y * 0.68) + Vector2(randf_range(-55.0, 55.0), randf_range(-18.0, 18.0))
    return {
        "x": spawn.x,
        "y": spawn.y,
        "hp": 100.0,
        "medkits": 2,
        "face_x": 1.0,
        "name": "P%d" % id
    }

func _player_color(id: int) -> Color:
    var colors := [Color("#75d8a0"), Color("#78b7ff"), Color("#ffc66d"), Color("#e994e8")]
    return colors[posmod(id - 1, colors.size())]

func _on_connected_to_server() -> void:
    local_player_id = multiplayer.get_unique_id()
    screen_mode = "lobby"
    ui_status = "Connected — receiving world state..."

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
    rpc_id(id, "receive_initial_world", players, zombies, world_seed, world_time, combat_effects, wave_number, wave_spawned, wave_kills, wave_total, wave_spawn_timer, wave_break_timer)
    if screen_mode == "game":
        rpc_id(id, "begin_game_remote")
    _broadcast_world()
    ui_status = "Player joined · %d/%d" % [players.size(), MAX_PLAYERS]

func _on_peer_disconnected(id: int) -> void:
    players.erase(id)
    input_vectors.erase(id)
    fire_cooldowns.erase(id)
    heal_cooldowns.erase(id)
    if is_host:
        _broadcast_world()
    ui_status = "Player %d disconnected · %d/%d" % [id, players.size(), MAX_PLAYERS]

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(movement: Vector2) -> void:
    if not is_host:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if not players.has(sender_id):
        return
    # Clamp input vector on the host so client cannot request speed boosts.
    input_vectors[sender_id] = movement.limit_length(1.0)

@rpc("authority", "call_remote", "unreliable_ordered")
func receive_world(world_players: Dictionary, world_zombies: Array, time_value: float, incoming_effects: Array, incoming_wave: int, incoming_spawned: int, incoming_kills: int, incoming_total: int, incoming_break_timer: float) -> void:
    target_players = world_players.duplicate(true)
    zombies.clear()
    for z in world_zombies:
        zombies.append(z.duplicate(true))
    combat_effects.clear()
    for effect in incoming_effects:
        combat_effects.append(effect.duplicate(true))
    world_time = time_value
    wave_number = maxi(1, incoming_wave)
    wave_spawned = maxi(0, incoming_spawned)
    wave_kills = maxi(0, incoming_kills)
    wave_total = maxi(1, incoming_total)
    wave_break_timer = maxf(0.0, incoming_break_timer)
    for id_variant in target_players.keys():
        var id := int(id_variant)
        if not players.has(id):
            players[id] = target_players[id].duplicate(true)

@rpc("authority", "call_remote", "reliable")
func receive_initial_world(world_players: Dictionary, world_zombies: Array, seed_value: int, time_value: float, incoming_effects: Array, incoming_wave: int, incoming_spawned: int, incoming_kills: int, incoming_total: int, incoming_spawn_timer: float, incoming_break_timer: float) -> void:
    players = world_players.duplicate(true)
    target_players = world_players.duplicate(true)
    zombies.clear()
    for z in world_zombies:
        zombies.append(z.duplicate(true))
    combat_effects.clear()
    for effect in incoming_effects:
        combat_effects.append(effect.duplicate(true))
    world_seed = seed_value
    world_time = time_value
    wave_number = maxi(1, incoming_wave)
    wave_spawned = maxi(0, incoming_spawned)
    wave_kills = maxi(0, incoming_kills)
    wave_total = maxi(1, incoming_total)
    wave_spawn_timer = maxf(0.0, incoming_spawn_timer)
    wave_break_timer = maxf(0.0, incoming_break_timer)
    ui_status = "Connected — survive together!"

@rpc("authority", "call_remote", "reliable")
func begin_game_remote() -> void:
    screen_mode = "game"
    ui_status = "Survive together!"

func _begin_game() -> void:
    if not is_host:
        ui_status = "Only the host can start the world."
        return
    screen_mode = "game"
    ui_status = "Survive together!"
    snapshot_timer = 0.0
    if not is_offline and multiplayer.multiplayer_peer != null:
        rpc("begin_game_remote")

func _start_offline() -> void:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
    peer = null
    is_host = true
    is_offline = true
    local_player_id = 1
    players.clear()
    input_vectors.clear()
    target_players.clear()
    zombies.clear()
    combat_effects.clear()
    wave_number = 1
    wave_total = WAVE_ZOMBIE_COUNT
    wave_spawned = 0
    wave_kills = 0
    wave_spawn_timer = 0.9
    wave_break_timer = 0.0
    seed(world_seed)
    _load_world()
    players[1] = _make_player(1)
    input_vectors[1] = Vector2.ZERO
    screen_mode = "game"
    ui_status = "Offline survival — world saves on this phone"
    last_save_time = world_time
    snapshot_timer = 0.0

func _interpolate_client_state(delta: float) -> void:
    var weight := minf(1.0, delta * 15.0)
    for id_variant in target_players.keys():
        var id := int(id_variant)
        var target: Dictionary = target_players[id]
        if not players.has(id):
            players[id] = target.duplicate(true)
            continue
        var current: Dictionary = players[id]
        current["x"] = lerpf(float(current.get("x", target.get("x", 480.0))), float(target.get("x", 480.0)), weight)
        current["y"] = lerpf(float(current.get("y", target.get("y", 270.0))), float(target.get("y", 270.0)), weight)
        current["hp"] = target.get("hp", 100.0)
        current["medkits"] = target.get("medkits", 2)
        current["face_x"] = target.get("face_x", 1.0)
        players[id] = current
    for id_variant in players.keys().duplicate():
        if not target_players.has(id_variant):
            players.erase(id_variant)

func _broadcast_world() -> void:
    if not is_host or multiplayer.multiplayer_peer == null:
        return
    rpc("receive_world", players, zombies, world_time, combat_effects, wave_number, wave_spawned, wave_kills, wave_total, wave_break_timer)

@rpc("any_peer", "call_remote", "reliable")
func request_fire() -> void:
    if not is_host:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if players.has(sender_id):
        _host_fire(sender_id)

func _add_combat_effect(kind: int, start_pos: Vector2, end_pos: Vector2, lifetime: float) -> void:
    combat_effects.append({
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

func _host_fire(id: int) -> void:
    if not players.has(id):
        return
    var now := Time.get_ticks_msec()
    if now - int(fire_cooldowns.get(id, 0)) < 280:
        return
    fire_cooldowns[id] = now
    var p: Dictionary = players[id]
    if float(p.get("hp", 0.0)) <= 0.0:
        return

    # Straight horizontal shot: aim is fixed by the last left/right movement, never auto-aimed at a zombie.
    var player_pos := Vector2(float(p.get("x", screen_size.x * 0.5)), float(p.get("y", screen_size.y * 0.5)))
    var facing := Vector2.LEFT if float(p.get("face_x", 1.0)) < 0.0 else Vector2.RIGHT
    var muzzle := player_pos + facing * 24.0 + Vector2(0.0, -5.0)
    var shot_range := minf(SHOT_RANGE_MAX, screen_size.x * 0.78)
    var closest_index := -1
    var closest_projection := shot_range

    for zi in range(zombies.size()):
        var zombie: Dictionary = zombies[zi]
        var zombie_pos := Vector2(float(zombie.get("x", 0.0)), float(zombie.get("y", 0.0)))
        var offset := zombie_pos - player_pos
        var projection := offset.dot(facing)
        var lane_offset := absf(offset.y)
        if projection > 16.0 and projection <= closest_projection and lane_offset <= SHOT_LANE_TOLERANCE:
            closest_projection = projection
            closest_index = zi

    var tracer_end := player_pos + facing * closest_projection + Vector2(0.0, -5.0)
    _add_combat_effect(0, muzzle, muzzle, 0.15)
    _add_combat_effect(1, muzzle, tracer_end, 0.16)
    if closest_index >= 0:
        var zombie: Dictionary = zombies[closest_index]
        var impact_pos := Vector2(float(zombie.get("x", tracer_end.x)), player_pos.y - 5.0)
        _add_combat_effect(2, impact_pos, impact_pos, 0.18)
        _add_combat_effect(3, Vector2(float(zombie.get("x", tracer_end.x)), float(zombie.get("y", tracer_end.y))), impact_pos, 0.26)
        zombie["hp"] = float(zombie.get("hp", 1.0)) - 1.0
        if float(zombie["hp"]) <= 0.0:
            _add_combat_effect(4, impact_pos, impact_pos, 0.30)
            wave_kills = mini(wave_total, wave_kills + 1)
            zombies.remove_at(closest_index)
        else:
            zombies[closest_index] = zombie
    _broadcast_world()

@rpc("any_peer", "call_remote", "reliable")
func request_heal() -> void:
    if not is_host:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if players.has(sender_id):
        _host_heal(sender_id)

func _host_heal(id: int) -> void:
    if not players.has(id):
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
    _broadcast_world()

func _save_world(announce: bool = true) -> void:
    if not is_host:
        return
    var data := {
        "version": 2,
        "seed": world_seed,
        "time": world_time,
        "wave_number": wave_number,
        "wave_total": wave_total,
        "wave_spawned": wave_spawned,
        "wave_kills": wave_kills,
        "wave_spawn_timer": wave_spawn_timer,
        "wave_break_timer": wave_break_timer,
        "zombies": zombies
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
    world_seed = int(parsed.get("seed", randi()))
    seed(world_seed)
    world_time = maxf(0.0, float(parsed.get("time", 0.0)))
    wave_number = maxi(1, int(parsed.get("wave_number", 1)))
    wave_total = clampi(int(parsed.get("wave_total", WAVE_ZOMBIE_COUNT)), 1, 100)
    wave_spawned = clampi(int(parsed.get("wave_spawned", 0)), 0, wave_total)
    wave_kills = clampi(int(parsed.get("wave_kills", 0)), 0, wave_total)
    wave_spawn_timer = maxf(0.0, float(parsed.get("wave_spawn_timer", 0.9)))
    wave_break_timer = maxf(0.0, float(parsed.get("wave_break_timer", 0.0)))
    zombies.clear()
    var saved_zombies = parsed.get("zombies", [])
    if typeof(saved_zombies) == TYPE_ARRAY:
        for z in saved_zombies:
            if typeof(z) == TYPE_DICTIONARY and z.has("x") and z.has("y"):
                var kind := clampi(int(z.get("kind", 0)), 0, ZOMBIE_MAX_HP.size() - 1)
                var max_hp := maxf(1.0, float(z.get("max_hp", ZOMBIE_MAX_HP[kind])))
                zombies.append({
                    "id": int(z.get("id", randi())),
                    "kind": kind,
                    "x": clampf(float(z.get("x", screen_size.x * 0.5)), 30.0, maxf(31.0, screen_size.x - 30.0)),
                    "y": clampf(float(z.get("y", screen_size.y * 0.68)), _arena_top() + 31.0, _arena_bottom() - 31.0),
                    "hp": clampf(float(z.get("hp", max_hp)), 0.1, max_hp),
                    "max_hp": max_hp
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
    multiplayer.multiplayer_peer = peer
    is_host = true
    is_offline = false
    local_player_id = 1
    screen_mode = "lobby"
    players.clear()
    input_vectors.clear()
    target_players.clear()
    combat_effects.clear()
    wave_number = 1
    wave_total = WAVE_ZOMBIE_COUNT
    wave_spawned = 0
    wave_kills = 0
    wave_spawn_timer = 0.9
    wave_break_timer = 0.0
    _load_world()
    if not FileAccess.file_exists(SAVE_PATH):
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
    multiplayer.multiplayer_peer = peer
    is_host = false
    is_offline = false
    screen_mode = "lobby"
    host_ip = cleaned_ip
    players.clear()
    target_players.clear()
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
    fire_repeat_timer = 0.0
    players.clear()
    input_vectors.clear()
    target_players.clear()
    zombies.clear()
    combat_effects.clear()
    local_player_id = 1

func _leave_world() -> void:
    if is_host:
        _save_world(false)
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
    _draw_ui_button("home_lan", Rect2(bx, card_y + 83.0, bw, 66.0), "MULTIPLAYER LAN", "HOST OR JOIN UP TO FOUR SURVIVORS", Color("#d64e51"), true)
    _draw_ui_button("home_solo", Rect2(bx, card_y + 163.0, bw, 60.0), "SOLO SURVIVAL", "DEFEND THIS SAFEHOUSE OFFLINE", Color("#c18a55"), false)
    _draw_ui_button("home_controls", Rect2(bx, card_y + 236.0, bw, 54.0), "FIELD MANUAL", "MOVE  /  FIRE  /  HEAL  /  SAVE", Color("#9cae91"), false)

    var signal_rect := Rect2(bx, card_y + 316.0, bw, 42.0)
    draw_rect(signal_rect, Color(0.12, 0.045, 0.05, 0.88))
    draw_rect(Rect2(signal_rect.position, Vector2(3, signal_rect.size.y)), Color("#9e4146"))
    draw_circle(Vector2(signal_rect.position.x + 17, signal_rect.position.y + 21), 4.0, Color("#dc685b"))
    draw_string(ui_font, Vector2(signal_rect.position.x + 29, signal_rect.position.y + 25), "LOCAL SIGNAL ONLY  /  UDP %d" % PORT, HORIZONTAL_ALIGNMENT_LEFT, bw - 40, 10, Color("#d4c5bb"))
    draw_string(ui_font, Vector2(bx, card_y + card_h - 17.0), "BUILD 0.3.9  /  EARLY ACCESS", HORIZONTAL_ALIGNMENT_LEFT, bw, 10, Color("#9caaa0"))

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
        {"title": "02  FIGHT", "body": "Hold FIRE for bursts.\nShots travel straight left\nor right based on facing.", "color": Color("#cc5151")},
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

func _draw_game_world() -> void:
    var w := screen_size.x
    var h := screen_size.y
    if background_texture != null:
        draw_texture_rect(background_texture, Rect2(0, 0, w, h), false, Color.WHITE)
    else:
        draw_rect(Rect2(0, 0, w, h), Color("#1b2930"))

    # Night-grade the scene but keep sprite and projectile highlights readable.
    draw_rect(Rect2(0, 0, w, h), Color(0.012, 0.024, 0.038, 0.19))
    draw_rect(Rect2(0, h * 0.42, w, h * 0.12), Color(0.08, 0.018, 0.023, 0.10))

    var lane_top := _arena_top()
    var lane_bottom := _arena_bottom()
    draw_rect(Rect2(0, lane_top, w, lane_bottom - lane_top), Color(0.012, 0.018, 0.023, 0.18))
    draw_rect(Rect2(0, lane_top, w, 2), Color(0.78, 0.43, 0.30, 0.56))
    draw_rect(Rect2(0, lane_bottom - 2, w, 2), Color(0.025, 0.03, 0.03, 0.72))
    for x in range(22, int(w), 82):
        draw_rect(Rect2(x, lane_top + (lane_bottom - lane_top) * 0.51, 35, 3), Color(0.78, 0.67, 0.43, 0.70))

    # Grounded, low cover props at the lane edges; diagonal paint reads as hazard striping.
    var cover_y := lane_bottom - 22.0
    # Explicit float annotations avoid Variant inference errors in Godot 4.7.
    var cover_positions: Array[float] = [w * 0.105, w * 0.79]
    for cover_x_value in cover_positions:
        var cover_x: float = float(cover_x_value)
        var cover_w: float = 45.0
        draw_rect(Rect2(cover_x, cover_y + 3.0, cover_w, 13), Color(0.015, 0.02, 0.02, 0.52))
        draw_rect(Rect2(cover_x, cover_y, cover_w, 13), Color("#424a46"))
        draw_rect(Rect2(cover_x, cover_y, cover_w, 3), Color("#899087"))
        for stripe in range(3):
            var sx: float = cover_x + 7.0 + float(stripe) * 14.0
            draw_line(Vector2(sx, cover_y + 4.0), Vector2(sx + 5.0, cover_y + 11.0), Color("#b59b62"), 2.0, true)
        draw_rect(Rect2(cover_x, cover_y, cover_w, 13), Color("#171f20"), false, 1.0)

    # Y-sort survivor and enemies so overlaps look grounded and the art stays legible.
    var render_entries: Array[Dictionary] = []
    for id_variant in players.keys():
        var pid := int(id_variant)
        render_entries.append({"y": float(players[pid].get("y", h * 0.68)), "type": "player", "id": pid})
    for zi in range(zombies.size()):
        render_entries.append({"y": float(zombies[zi].get("y", h * 0.68)), "type": "zombie", "index": zi})
    render_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.y) < float(b.y))

    for entry in render_entries:
        var pos: Vector2
        if str(entry.type) == "player":
            var id := int(entry.id)
            var p: Dictionary = players[id]
            pos = Vector2(float(p.get("x", w * 0.5)), float(p.get("y", h * 0.68)))
            draw_circle(pos + Vector2(0, 27), 10.0, Color(0.005, 0.01, 0.012, 0.34))
            var team_color := _player_color(id)
            draw_arc(pos + Vector2(0, 28), 13.0, 0, TAU, 28, Color(team_color.r, team_color.g, team_color.b, 0.48), 1.5)
            _draw_atlas_character(pos, _player_sprite_index(id), false, 1.0, float(p.get("face_x", 1.0)) < 0.0)
            var label := _player_label(id)
            var label_pos := pos + Vector2(-22, -43)
            draw_rect(Rect2(label_pos.x - 1, label_pos.y - 12, 44, 16), Color(0.01, 0.015, 0.02, 0.74))
            draw_string(ui_font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, 42, 10, _player_color(id))
            var player_hp := clampf(float(p.get("hp", 0.0)) / 100.0, 0.0, 1.0)
            var player_bar := Rect2(pos + Vector2(-17, 32), Vector2(34, 5))
            draw_rect(Rect2(player_bar.position - Vector2(1, 1), player_bar.size + Vector2(2, 2)), Color("#141819"))
            draw_rect(player_bar, Color("#472628"))
            var player_hp_color := Color("#b94346") if player_hp <= 0.30 else (Color("#d39a50") if player_hp <= 0.58 else Color("#86b76b"))
            draw_rect(Rect2(player_bar.position, Vector2(player_bar.size.x * player_hp, player_bar.size.y)), player_hp_color)
        else:
            var z: Dictionary = zombies[int(entry.index)]
            pos = Vector2(float(z.get("x", 0.0)), float(z.get("y", h * 0.68)))
            var heavy := int(z.get("kind", 0)) == 2
            draw_circle(pos + Vector2(0, 28), 11.0 if heavy else 8.5, Color(0.005, 0.008, 0.01, 0.34))
            _draw_atlas_character(pos, clampi(int(z.get("kind", 0)), 0, 3), true, 1.0, float(z.get("face_x", -1.0)) < 0.0)
            _draw_zombie_health(z, pos)
    _draw_combat_effects()
    _draw_game_hud()

func _draw_game_hud() -> void:
    var w := screen_size.x
    var h := screen_size.y
    var local_p: Dictionary = players.get(local_player_id, {})

    # Three aligned information groups; each has a clear dark backing and red micro-accent.
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
    wave_x = clampf(wave_x, left_rect.position.x + left_rect.size.x + 10.0, w - 224.0)
    draw_rect(Rect2(wave_x + 3, 15, wave_w, 55), Color(0.0, 0.0, 0.0, 0.34))
    draw_rect(Rect2(wave_x, 12, wave_w, 54), Color(0.015, 0.025, 0.03, 0.95))
    draw_rect(Rect2(wave_x, 12, wave_w, 3), Color("#cf4b50"))
    draw_string(ui_font, Vector2(wave_x + 12, 33), "WAVE %02d" % wave_number, HORIZONTAL_ALIGNMENT_LEFT, wave_w - 24, 16, Color("#f0d08d"))
    draw_string(ui_font, Vector2(wave_x + 12, 48), "ELIMINATED  %02d / %02d" % [wave_kills, wave_total], HORIZONTAL_ALIGNMENT_LEFT, wave_w - 24, 9, Color("#c9d0c7"))
    var progress_rect := Rect2(wave_x + 12, 55, wave_w - 24, 4)
    draw_rect(progress_rect, Color("#343a39"))
    draw_rect(Rect2(progress_rect.position, Vector2(progress_rect.size.x * clampf(float(wave_kills) / float(maxi(1, wave_total)), 0.0, 1.0), progress_rect.size.y)), Color("#bf4449"))
    if wave_break_timer > 0.0:
        var break_rect := Rect2(w * 0.5 - 125, 78, 250, 28)
        draw_rect(break_rect, Color(0.015, 0.02, 0.022, 0.91))
        draw_rect(Rect2(break_rect.position, Vector2(3, break_rect.size.y)), Color("#cf4b50"))
        draw_string(ui_font, Vector2(break_rect.position.x + 10, 97), "WAVE CLEAR  •  NEXT IN %d" % ceili(wave_break_timer), HORIZONTAL_ALIGNMENT_CENTER, break_rect.size.x - 18, 12, Color("#f1d89c"))

    var hp := clampi(int(local_p.get("hp", 100)), 0, 100)
    var medkits := int(local_p.get("medkits", 2))
    var health_rect := Rect2(w - 211.0, 12, 176.0, 52.0)
    draw_rect(Rect2(health_rect.position + Vector2(3, 4), health_rect.size), Color(0.0, 0.0, 0.0, 0.40))
    draw_rect(health_rect, Color(0.015, 0.025, 0.03, 0.94))
    draw_rect(Rect2(health_rect.position.x, health_rect.position.y, health_rect.size.x, 2), Color("#6f3439"))
    var hp_color := Color("#bd4147") if hp <= 30 else (Color("#d2a052") if hp <= 58 else Color("#8bc26d"))
    draw_string(ui_font, Vector2(w - 198, 31), "VITALS  %d%%" % hp, HORIZONTAL_ALIGNMENT_LEFT, 151, 12, Color("#f0e9df"))
    var hp_rect := Rect2(w - 198, 37, 148.0, 6.0)
    draw_rect(hp_rect, Color("#45292b"))
    draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * float(hp) / 100.0, hp_rect.size.y)), hp_color)
    draw_string(ui_font, Vector2(w - 198, 55), "MEDKIT  %d" % medkits, HORIZONTAL_ALIGNMENT_LEFT, 150, 9, Color("#c2c7bd"))

    var control_scale := _control_scale()
    var joystick_radius := _joystick_radius()
    joystick_origin = Vector2(maxf(joystick_radius + 24.0, w * 0.092), h - 91.0 * control_scale)
    draw_circle(joystick_origin + Vector2(2, 4), joystick_radius + 2, Color(0.0, 0.0, 0.0, 0.46))
    draw_circle(joystick_origin, joystick_radius, Color(0.012, 0.025, 0.027, 0.78))
    draw_arc(joystick_origin, joystick_radius, 0, TAU, 36, Color("#9ba8a0"), 2.0)
    draw_arc(joystick_origin, joystick_radius - 7.0, 0, TAU, 36, Color(0.63, 0.22, 0.25, 0.42), 1.0)
    # Small directional marks make the analog affordance obvious even on dark maps.
    draw_colored_polygon(PackedVector2Array([joystick_origin + Vector2(0, -joystick_radius + 10), joystick_origin + Vector2(-5, -joystick_radius + 18), joystick_origin + Vector2(5, -joystick_radius + 18)]), Color("#c3c8bc"))
    draw_circle(joystick_origin + joystick_vector * (joystick_radius * 0.53), 17.0 * control_scale, Color(0.78, 0.83, 0.77, 0.96))
    draw_arc(joystick_origin + joystick_vector * (joystick_radius * 0.53), 17.0 * control_scale, 0, TAU, 28, Color("#26312e"), 1.5)
    draw_string(ui_font, Vector2(joystick_origin.x - 26, joystick_origin.y + joystick_radius + 18), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 52, 9, Color("#d1d5cb"))

    var fire_pos := Vector2(w - 77.0 * control_scale, h - 89.0 * control_scale)
    var heal_pos := Vector2(w - 171.0 * control_scale, h - 61.0 * control_scale)
    _draw_action_button("game_fire", fire_pos, 41.0 * control_scale, "FIRE", Color("#b83f45"))
    _draw_action_button("game_heal", heal_pos, 31.0 * control_scale, "HEAL", Color("#647d57"))
    _draw_ui_button("game_pause", Rect2(w - 65.0, 72.0, 49.0, 41.0), "Ⅱ", "", Color("#c19a68"), false)

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
        # Three cartridge marks make the primary action read as a shooter control.
        for i in range(3):
            var casing := Rect2(pos.x - 12.0 + float(i) * 8.0, pos.y - 13.0, 4.0, 11.0)
            draw_rect(casing, Color("#f4d29a"))
            draw_rect(Rect2(casing.position.x, casing.position.y, casing.size.x, 3.0), Color("#fff0cb"))
        draw_string(ui_font, pos + Vector2(-radius + 2.0, 22.0), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0 - 4.0, 11, Color.WHITE)
    else:
        draw_rect(Rect2(pos.x - 2.0, pos.y - 10.0, 4.0, 20.0), Color("#e9e8dc"))
        draw_rect(Rect2(pos.x - 10.0, pos.y - 2.0, 20.0, 4.0), Color("#e9e8dc"))
        draw_string(ui_font, pos + Vector2(-radius + 2.0, radius * 0.62), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0 - 4.0, 9, Color.WHITE)

func _draw_title_text(pos: Vector2, label: String, size: int, color: Color) -> void:
    draw_string(ui_font, pos + Vector2(3, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.0, 0.0, 0.75))
    draw_string(ui_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _player_sprite_index(id: int) -> int:
    return posmod(id - 1, 4)

func _draw_atlas_character(pos: Vector2, kind: int, zombie: bool, scale_value: float = 1.0, facing_left: bool = false) -> void:
    if sprite_atlas == null:
        draw_rect(Rect2(pos + Vector2(-8, -9), Vector2(16, 18)), _player_color(kind + 1))
        return
    # PNG atlas: 64x80 cells (320x192). SVG fallback: 80x80 cells (320x240).
    var svg_layout := sprite_atlas.get_height() >= 240
    var cell_width := 80 if svg_layout else 64
    var source_y := 80 if zombie else 0
    var source_x := clampi(kind, 0, 3) * cell_width
    var size := Vector2(58.0, 70.0) * scale_value
    if zombie and kind == 2:
        size = Vector2(64.0, 70.0) * scale_value
    var source_rect := Rect2(source_x, source_y, cell_width, 80)
    if facing_left:
        draw_set_transform(pos, 0.0, Vector2(-1.0, 1.0))
        draw_texture_rect_region(sprite_atlas, Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y), source_rect, Color.WHITE, false, true)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    else:
        draw_texture_rect_region(sprite_atlas, Rect2(pos - size * 0.5, size), source_rect, Color.WHITE, false, true)

func _draw_survivor(pos: Vector2, color: Color, scale_value: float) -> void:
    var sprite_index := 0
    for i in range(4):
        if color == _player_color(i + 1):
            sprite_index = i
            break
    _draw_atlas_character(pos, sprite_index, false, 0.65 * scale_value)

func _draw_zombie_health(zombie: Dictionary, pos: Vector2) -> void:
    var default_max_hp := float(ZOMBIE_MAX_HP[clampi(int(zombie.get("kind", 0)), 0, 3)])
    var max_hp := maxf(1.0, float(zombie.get("max_hp", default_max_hp)))
    var hp := clampf(float(zombie.get("hp", max_hp)) / max_hp, 0.0, 1.0)
    var bar_width := 38.0 if int(zombie.get("kind", 0)) != 2 else 44.0
    var bar_rect := Rect2(pos.x - bar_width * 0.5, pos.y - 44.0, bar_width, 6.0)
    draw_rect(Rect2(bar_rect.position - Vector2(2, 2), bar_rect.size + Vector2(4, 4)), Color(0.01, 0.012, 0.014, 0.86))
    draw_rect(bar_rect, Color("#4c2025"))
    var health_color := Color("#d0aa61") if hp > 0.55 else (Color("#d46a4f") if hp > 0.25 else Color("#dc414a"))
    draw_rect(Rect2(bar_rect.position + Vector2(1, 1), Vector2(maxf(0.0, (bar_width - 2.0) * hp), 4.0)), health_color)
    draw_rect(bar_rect, Color("#c7b6a7"), false, 1.0)

func _draw_combat_effects() -> void:
    for effect in combat_effects:
        var kind := clampi(int(effect.get("kind", 0)), 0, 4)
        var start_pos := Vector2(float(effect.get("x", 0.0)), float(effect.get("y", 0.0)))
        var end_pos := Vector2(float(effect.get("x2", start_pos.x)), float(effect.get("y2", start_pos.y)))
        var life := maxf(0.01, float(effect.get("life", 0.18)))
        var ttl := clampf(float(effect.get("ttl", 0.0)), 0.0, life)
        var progress := clampf(1.0 - ttl / life, 0.0, 1.0)
        var alpha := clampf(ttl / minf(0.20, life), 0.0, 1.0)

        if kind == 1:
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
    match id:
        "home_lan":
            screen_mode = "lobby"
            ui_status = "Create a world or join a friend on the same hotspot."
        "home_solo":
            _start_offline()
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
        "game_pause":
            screen_mode = "pause"
            joystick_vector = Vector2.ZERO
            joystick_active = false
            fire_held = false
            fire_touch_id = -1
            fire_repeat_timer = 0.0
        "game_fire":
            fire_requested = true
        "game_heal":
            heal_requested = true
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
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _touch_start(-2, event.position)
        else:
            _touch_end(-2)
    elif event is InputEventMouseMotion:
        if joystick_active and joystick_touch_id == -2:
            joystick_vector = ((event.position - joystick_origin) / _joystick_radius()).limit_length(1.0)

func _touch_start(index: int, pos: Vector2) -> void:
    if _handle_press(pos, index):
        return
    if screen_mode == "game" and pos.x < screen_size.x * 0.40 and pos.y > screen_size.y * 0.57 and not joystick_active:
        joystick_active = true
        joystick_touch_id = index
        joystick_vector = ((pos - joystick_origin) / _joystick_radius()).limit_length(1.0)

func _touch_end(index: int) -> void:
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

