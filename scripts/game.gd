extends Node2D

# Pixel Zombie LAN — prototype v0.2.0
# Host-authoritative 4-player survival over ENet/UDP on a local Wi-Fi network.

const PORT := 24567
const MAX_PLAYERS := 4
const PLAYER_SPEED := 150.0
const ZOMBIE_SPEED := 28.0
const SNAPSHOT_INTERVAL := 0.10 # 10 world snapshots/second
const INPUT_INTERVAL := 0.05    # 20 input updates/second
const SAVE_PATH := "user://world_save.json"

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
    world_seed = randi()
    ui_font = ThemeDB.fallback_font
    screen_size = get_viewport_rect().size
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    _spawn_local_player()

func _process(delta: float) -> void:
    screen_size = get_viewport_rect().size

    if is_host:
        input_vectors[1] = joystick_vector
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
    else:
        # Let the prototype be explored in offline mode before starting a LAN session.
        _move_offline_player(delta)

    _process_action_requests()
    queue_redraw()

func _is_connected_client() -> bool:
    return multiplayer.multiplayer_peer != null and not is_host and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _move_offline_player(delta: float) -> void:
    if not players.has(local_player_id):
        _spawn_local_player()
    var p: Dictionary = players[local_player_id]
    p["x"] = clampf(float(p.get("x", 480.0)) + joystick_vector.x * PLAYER_SPEED * delta, 18.0, 942.0)
    p["y"] = clampf(float(p.get("y", 270.0)) + joystick_vector.y * PLAYER_SPEED * delta, 18.0, 522.0)
    players[local_player_id] = p

func _process_action_requests() -> void:
    if fire_requested:
        fire_requested = false
        if is_host:
            _host_fire(1)
        elif _is_connected_client():
            rpc_id(1, "request_fire")
        else:
            ui_status = "Tap HOST to start a survival world"
    if heal_requested:
        heal_requested = false
        if is_host:
            _host_heal(1)
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
        var movement: Vector2 = input_vectors.get(id, Vector2.ZERO)
        if float(p.get("hp", 0.0)) > 0.0:
            p["x"] = clampf(float(p.get("x", 480.0)) + movement.x * PLAYER_SPEED * delta, 18.0, 942.0)
            p["y"] = clampf(float(p.get("y", 270.0)) + movement.y * PLAYER_SPEED * delta, 18.0, 522.0)
        players[id] = p

    if zombies.size() < 10 and randf() < delta * 0.65:
        zombies.append({
            "id": randi(),
            "x": randf_range(42.0, 918.0),
            "y": randf_range(42.0, 498.0),
            "hp": 3.0
        })

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
                z["x"] = float(z.x) + direction.x * ZOMBIE_SPEED * delta
                z["y"] = float(z.y) + direction.y * ZOMBIE_SPEED * delta
            else:
                target["hp"] = maxf(0.0, float(target.get("hp", 0.0)) - 8.0 * delta)
                players[target_id] = target
        zombies[zi] = z

func _spawn_local_player() -> void:
    var id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1
    local_player_id = id
    if not players.has(id):
        players[id] = _make_player(id)
    if not input_vectors.has(id):
        input_vectors[id] = Vector2.ZERO

func _make_player(id: int) -> Dictionary:
    var spawn := Vector2(480.0, 270.0) + Vector2(randf_range(-55.0, 55.0), randf_range(-55.0, 55.0))
    return {
        "x": spawn.x,
        "y": spawn.y,
        "hp": 100.0,
        "medkits": 2,
        "name": "P%d" % id
    }

func _player_color(id: int) -> Color:
    var colors := [Color("#75d8a0"), Color("#78b7ff"), Color("#ffc66d"), Color("#e994e8")]
    return colors[posmod(id - 1, colors.size())]

func _on_connected_to_server() -> void:
    local_player_id = multiplayer.get_unique_id()
    ui_status = "Connected — receiving world state..."

func _on_connection_failed() -> void:
    _reset_network_state()
    ui_status = "Connection failed — check host IP and hotspot isolation"

func _on_server_disconnected() -> void:
    _reset_network_state()
    ui_status = "Host disconnected — session ended"

func _on_peer_connected(id: int) -> void:
    if not is_host:
        return
    if players.size() >= MAX_PLAYERS:
        ui_status = "World full (maximum 4 players)"
        return
    players[id] = _make_player(id)
    input_vectors[id] = Vector2.ZERO
    rpc_id(id, "receive_initial_world", players, zombies, world_seed, world_time)
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
func receive_world(world_players: Dictionary, world_zombies: Array, time_value: float) -> void:
    target_players = world_players.duplicate(true)
    zombies.clear()
    for z in world_zombies:
        zombies.append(z.duplicate(true))
    world_time = time_value
    for id_variant in target_players.keys():
        var id := int(id_variant)
        if not players.has(id):
            players[id] = target_players[id].duplicate(true)

@rpc("authority", "call_remote", "reliable")
func receive_initial_world(world_players: Dictionary, world_zombies: Array, seed_value: int, time_value: float) -> void:
    players = world_players.duplicate(true)
    target_players = world_players.duplicate(true)
    zombies.clear()
    for z in world_zombies:
        zombies.append(z.duplicate(true))
    world_seed = seed_value
    world_time = time_value
    ui_status = "Connected — survive together!"

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
        players[id] = current
    for id_variant in players.keys().duplicate():
        if not target_players.has(id_variant):
            players.erase(id_variant)

func _broadcast_world() -> void:
    if not is_host or multiplayer.multiplayer_peer == null:
        return
    rpc("receive_world", players, zombies, world_time)

@rpc("any_peer", "call_remote", "reliable")
func request_fire() -> void:
    if not is_host:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if players.has(sender_id):
        _host_fire(sender_id)

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
    var player_pos := Vector2(float(p.x), float(p.y))
    var closest_index := -1
    var closest_distance := 110.0
    for zi in range(zombies.size()):
        var z: Dictionary = zombies[zi]
        var distance := player_pos.distance_to(Vector2(float(z.x), float(z.y)))
        if distance < closest_distance:
            closest_distance = distance
            closest_index = zi
    if closest_index >= 0:
        zombies[closest_index]["hp"] = float(zombies[closest_index].get("hp", 1.0)) - 1.0
        if float(zombies[closest_index]["hp"]) <= 0.0:
            zombies.remove_at(closest_index)
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
        "version": 1,
        "seed": world_seed,
        "time": world_time,
        "zombies": zombies
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        ui_status = "Save failed: cannot write world file"
        return
    file.store_string(JSON.stringify(data))
    file.close()
    if announce:
        ui_status = "World saved on host · IP %s" % _get_lan_ip_summary()

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
    zombies.clear()
    var saved_zombies = parsed.get("zombies", [])
    if typeof(saved_zombies) == TYPE_ARRAY:
        for z in saved_zombies:
            if typeof(z) == TYPE_DICTIONARY and z.has("x") and z.has("y"):
                zombies.append({
                    "id": int(z.get("id", randi())),
                    "x": clampf(float(z.get("x", 480.0)), 18.0, 942.0),
                    "y": clampf(float(z.get("y", 270.0)), 18.0, 522.0),
                    "hp": clampf(float(z.get("hp", 1.0)), 0.1, 3.0)
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
    local_player_id = 1
    players.clear()
    input_vectors.clear()
    target_players.clear()
    _load_world()
    if not FileAccess.file_exists(SAVE_PATH):
        seed(world_seed)
    players[1] = _make_player(1)
    input_vectors[1] = Vector2.ZERO
    snapshot_timer = 0.0
    last_save_time = world_time
    host_lan_ip = _get_lan_ip_summary()
    ui_status = "World running · share host IP below"

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
    host_ip = cleaned_ip
    players.clear()
    target_players.clear()
    zombies.clear()
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
        return "check Wi-Fi details"
    return candidates[0]

func _reset_network_state() -> void:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
    peer = null
    is_host = false
    players.clear()
    input_vectors.clear()
    target_players.clear()
    zombies.clear()
    local_player_id = 1
    _spawn_local_player()

func _leave_world() -> void:
    if is_host:
        _save_world(false)
    _reset_network_state()
    ui_status = "Disconnected"

func _draw() -> void:
    # Temporary hand-drawn pixel-like tiles; sprite sheets and collision maps are next phase.
    draw_rect(Rect2(Vector2.ZERO, screen_size), Color("#17251e"))
    for x in range(0, int(screen_size.x), 32):
        for y in range(0, int(screen_size.y), 32):
            var variation := (x * 17 + y * 29) % 5
            var tile_color := Color("#1c2c22") if variation < 3 else Color("#203126")
            draw_rect(Rect2(x, y, 30, 30), tile_color)
    # Main ruined road and dashed lane markings.
    draw_rect(Rect2(360, 0, 150, screen_size.y), Color("#303a38"))
    for y in range(0, int(screen_size.y), 50):
        draw_rect(Rect2(432, y, 5, 24), Color("#9d9b70"))

    # Simple cover/building blocks for an early survival-game feel.
    _draw_building(Vector2(80, 90), Vector2(110, 72), Color("#39483b"))
    _draw_building(Vector2(700, 110), Vector2(150, 86), Color("#3c4440"))
    _draw_building(Vector2(610, 380), Vector2(110, 65), Color("#37483e"))

    for id_variant in players.keys():
        var id := int(id_variant)
        var p: Dictionary = players[id]
        var pos := Vector2(float(p.get("x", 480.0)), float(p.get("y", 270.0)))
        var color := _player_color(id)
        draw_rect(Rect2(pos + Vector2(-7, -7), Vector2(14, 14)), Color("#111512"))
        draw_rect(Rect2(pos + Vector2(-5, -6), Vector2(10, 12)), color)
        draw_rect(Rect2(pos + Vector2(-3, -12), Vector2(6, 5)), Color("#edc9a0"))
        draw_string(ui_font, pos + Vector2(-12, -16), "P%s" % str(id), HORIZONTAL_ALIGNMENT_LEFT, 32, 12, Color.WHITE)
        draw_rect(Rect2(pos + Vector2(-13, 10), Vector2(26, 3)), Color("#3a2020"))
        draw_rect(Rect2(pos + Vector2(-13, 10), Vector2(26.0 * clampf(float(p.get("hp", 0.0)) / 100.0, 0.0, 1.0), 3)), Color("#68db78"))

    for z in zombies:
        var pos := Vector2(float(z.get("x", 0.0)), float(z.get("y", 0.0)))
        draw_rect(Rect2(pos + Vector2(-7, -7), Vector2(14, 14)), Color("#10130f"))
        draw_rect(Rect2(pos + Vector2(-5, -5), Vector2(10, 10)), Color("#b0c66b"))
        draw_rect(Rect2(pos + Vector2(-3, -2), Vector2(2, 2)), Color("#5e1f24"))
        draw_rect(Rect2(pos + Vector2(1, -2), Vector2(2, 2)), Color("#5e1f24"))
    _draw_hud()

func _draw_building(pos: Vector2, size: Vector2, body_color: Color) -> void:
    draw_rect(Rect2(pos + Vector2(5, 6), size), Color("#111713"))
    draw_rect(Rect2(pos, size), body_color)
    draw_rect(Rect2(pos + Vector2(8, 8), Vector2(size.x - 16, 5)), Color("#59655a"))
    draw_rect(Rect2(pos + Vector2(14, 22), Vector2(18, 19)), Color("#202c29"))
    draw_rect(Rect2(pos + Vector2(size.x - 34, 22), Vector2(18, 19)), Color("#202c29"))
    draw_rect(Rect2(pos + Vector2(size.x * 0.5 - 8, size.y - 22), Vector2(16, 22)), Color("#242a24"))

func _draw_hud() -> void:
    draw_rect(Rect2(12, 10, minf(screen_size.x - 24.0, 650.0), 74), Color(0.02, 0.04, 0.03, 0.90))
    draw_string(ui_font, Vector2(24, 32), "PIXEL ZOMBIE LAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e6f3d8"))
    draw_string(ui_font, Vector2(24, 55), ui_status, HORIZONTAL_ALIGNMENT_LEFT, minf(screen_size.x - 480.0, 480.0), 12, Color("#b8d4bd"))
    if is_host:
        draw_string(ui_font, Vector2(screen_size.x - 350.0, 43), "LAN IP: %s" % host_lan_ip, HORIZONTAL_ALIGNMENT_LEFT, 220.0, 12, Color("#f3d08a"))
        draw_string(ui_font, Vector2(screen_size.x - 350.0, 63), "HOST · %d/4 · UDP %d" % [players.size(), PORT], HORIZONTAL_ALIGNMENT_LEFT, 230.0, 12, Color("#f3d08a"))
    elif not host_ip.is_empty() and _is_connected_client():
        draw_string(ui_font, Vector2(screen_size.x - 350.0, 45), "HOST: %s:%d" % [host_ip, PORT], HORIZONTAL_ALIGNMENT_LEFT, 230.0, 12, Color("#a9c8f0"))
    draw_circle(joystick_origin, 52, Color(0.08, 0.12, 0.10, 0.75))
    draw_arc(joystick_origin, 52, 0, TAU, 32, Color("#8aa28f"), 2.0)
    draw_circle(joystick_origin + joystick_vector * 28.0, 20, Color("#c0d5c3"))
    _draw_button(Vector2(screen_size.x - 90.0, screen_size.y - 90.0), 36, "FIRE", Color("#9b5147"))
    _draw_button(Vector2(screen_size.x - 175.0, screen_size.y - 55.0), 25, "HEAL", Color("#527d58"))
    _draw_button(Vector2(92, 105), 28, "HOST", Color("#426b4c"))
    _draw_button(Vector2(175, 105), 28, "JOIN", Color("#45627c"))
    _draw_button(Vector2(260, 105), 28, "SAVE", Color("#8a7140"))
    _draw_button(Vector2(345, 105), 28, "LEAVE", Color("#71484a"))
    var local_p: Dictionary = players.get(local_player_id, {})
    draw_string(ui_font, Vector2(screen_size.x - 200.0, 22), "HP %d  MED %d" % [int(local_p.get("hp", 100)), int(local_p.get("medkits", 2))], HORIZONTAL_ALIGNMENT_LEFT, 190.0, 12, Color("#e6f3d8"))

func _draw_button(pos: Vector2, radius: float, label: String, color: Color) -> void:
    draw_circle(pos, radius, color)
    draw_arc(pos, radius, 0, TAU, 24, Color(0.85, 0.92, 0.85, 0.8), 2.0)
    draw_string(ui_font, pos + Vector2(-radius + 7.0, 5), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0 - 14.0, 11, Color.WHITE)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _touch_start(event.index, event.position)
        else:
            _touch_end(event.index)
    elif event is InputEventScreenDrag:
        if joystick_active and event.index == joystick_touch_id:
            joystick_vector = ((event.position - joystick_origin) / 48.0).limit_length(1.0)

func _touch_start(index: int, pos: Vector2) -> void:
    if pos.x < screen_size.x * 0.42 and pos.y > screen_size.y * 0.60 and not joystick_active:
        joystick_active = true
        joystick_touch_id = index
        joystick_vector = ((pos - joystick_origin) / 48.0).limit_length(1.0)
        return
    if pos.y < 145.0:
        if pos.x < 130.0:
            _start_host()
        elif pos.x < 215.0:
            _show_join_dialog()
        elif pos.x < 300.0:
            if is_host:
                _save_world()
            else:
                ui_status = "Only host can save world"
        elif pos.x < 390.0:
            _leave_world()
        return
    if pos.x > screen_size.x - 140.0 and pos.y > screen_size.y - 140.0:
        fire_requested = true
    elif pos.x > screen_size.x - 220.0 and pos.y > screen_size.y - 100.0:
        heal_requested = true

func _touch_end(index: int) -> void:
    if index == joystick_touch_id:
        joystick_active = false
        joystick_touch_id = -1
        joystick_vector = Vector2.ZERO

func _show_join_dialog() -> void:
    var dialog := ConfirmationDialog.new()
    dialog.title = "Join LAN world"
    dialog.dialog_text = "Enter the host phone's Wi-Fi IPv4 address. Port: %d" % PORT
    dialog.min_size = Vector2i(420, 180)
    var line := LineEdit.new()
    line.placeholder_text = "Enter the actual host IP, e.g. 192.168.43.1"
    line.text = host_ip
    line.clear_button_enabled = true
    line.position = Vector2(20, 82)
    line.size = Vector2(380, 34)
    dialog.add_child(line)
    dialog.confirmed.connect(func():
        host_ip = line.text.strip_edges()
        _join_host(host_ip)
    )
    add_child(dialog)
    dialog.popup_centered()
