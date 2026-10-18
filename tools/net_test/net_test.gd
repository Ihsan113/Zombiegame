extends SceneTree

# Drives one real game instance (host or client) with scripted input and logs what it sees.
# args (after --): role=host|client  out=/path.csv  dur=seconds  ip=127.0.0.1

var game: Node
var role := "host"
var out: FileAccess
var duration := 25.0
var run_time := 0.0
var started := false
var ideal := Vector2.ZERO
var ideal_ready := false
var fire_timer := 0.0
var stat_timer := 0.0
var wait_time := 0.0
var last_frame := 0.0
var join_ip := ""
var booted := false
var died := false
var size_logged := false
var win_size := Vector2i.ZERO
var cheat_seq := 1000000
var cheat_timer := 0.0

func _initialize() -> void:
    Engine.max_fps = 60
    var ip := "127.0.0.1"
    var out_path := "/tmp/net_test.csv"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("role="):
            role = arg.substr(5)
        elif arg.begins_with("out="):
            out_path = arg.substr(4)
        elif arg.begins_with("dur="):
            duration = float(arg.substr(4))
        elif arg.begins_with("win="):
            var parts := arg.substr(4).split("x")
            win_size = Vector2i(int(parts[0]), int(parts[1]))
        elif arg.begins_with("ip="):
            ip = arg.substr(3)
    out = FileAccess.open(out_path, FileAccess.WRITE)
    game = load("res://Main.tscn").instantiate()
    root.add_child(game)
    join_ip = ip

func _script_vector(offset: float) -> Vector2:
    var phase := fmod(run_time + offset, 6.0)
    if phase < 2.5:
        return Vector2(1.0, 0.35)
    if phase < 3.0:
        return Vector2.ZERO
    if phase < 5.5:
        return Vector2(-1.0, -0.35)
    return Vector2.ZERO

func _process(delta: float) -> bool:
    var now := Time.get_unix_time_from_system()
    if not booted:
        booted = true
        if win_size != Vector2i.ZERO:
            root.size = win_size
        if role == "host":
            game._start_host()
        else:
            game._join_host(join_ip)
        return false
    wait_time += delta
    if not started:
        if role == "host":
            if game.players.size() >= 2 and wait_time > 1.0:
                game._begin_game()
                started = true
        else:
            if game.screen_mode == "game" and game.players.has(game.local_player_id):
                started = true
        if wait_time > 20.0 and not started:
            out.store_line("ERR,never_started")
            out.close()
            return true
        return false
    run_time += delta
    if not size_logged and run_time > 1.0:
        size_logged = true
        out.store_line("W,%.4f,%d,%d" % [now, int(game.screen_size.x), int(game.screen_size.y)])
    # scripted input
    if role != "cheat":
        game.joystick_vector = _script_vector(0.0 if role == "host" else 1.7)
    fire_timer += delta
    if role != "cheat" and fire_timer >= (0.9 if role == "host" else 0.55):
        fire_timer = 0.0
        game.fire_requested = true

    if role == "cheat":
        cheat_timer += delta
        if cheat_timer >= 0.033:
            cheat_timer = 0.0
            cheat_seq += 1
            var sp := StreamPeerBuffer.new()
            sp.put_u8(1)
            sp.put_u32(cheat_seq)
            var dirx := 127 if fmod(run_time, 4.0) < 2.0 else -127
            sp.put_8(dirx)
            sp.put_8(0)
            sp.put_u16(1000) # claims 0.1 s of movement every 33 ms of real time
            game.rpc_id(1, "submit_input", sp.data_array)
    if role == "host":
        for pid in game.players.keys():
            var p: Dictionary = game.players[pid]
            out.store_line("H,%.4f,%d,%.3f,%.3f" % [now, pid, float(p.x), float(p.y)])
        for z in game.zombies:
            out.store_line("Z,%.4f,%d,%.3f,%.3f" % [now, int(z.id), float(z.x), float(z.y)])
    else:
        var me: int = game.local_player_id
        if game.players.has(me):
            var lp: Dictionary = game.players[me]
            if float(lp.hp) <= 0.0 and not died:
                died = true
                out.store_line("D,%.4f" % now)
            if not ideal_ready:
                ideal = Vector2(float(lp.x), float(lp.y))
                ideal_ready = true
            var v: Vector2 = game.joystick_vector.limit_length(1.0)
            ideal += v * 150.0 * delta
            var w: float = game.screen_size.x
            var h: float = game.screen_size.y
            ideal.x = clampf(ideal.x, 30.0, w - 30.0)
            ideal.y = clampf(ideal.y, h * 0.52 + 22.0, h * 0.865 - 40.0)
            out.store_line("I,%.4f,%.3f,%.3f" % [now, ideal.x, ideal.y])
        for pid in game.players.keys():
            var p: Dictionary = game.players[pid]
            out.store_line("C,%.4f,%d,%.3f,%.3f" % [now, pid, float(p.x), float(p.y)])
        for z in game.zombies:
            out.store_line("Y,%.4f,%d,%.3f,%.3f" % [now, int(z.id), float(z.x), float(z.y)])
        var n1 := 0
        var n0 := 0
        for e in game.combat_effects:
            if int(e.kind) == 1:
                n1 += 1
            elif int(e.kind) == 0:
                n0 += 1
        out.store_line("E,%.4f,%d,%d" % [now, n1, n0])
        stat_timer += delta
        if stat_timer >= 1.0:
            stat_timer = 0.0
            var bytes := 0
            if game.peer != null and game.peer.host != null:
                bytes = int(game.peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA))
            var perr = game.get("pred_error_px")
            var rtt = game.get("net_rtt_ms")
            out.store_line("S,%.4f,%d,%s,%s" % [now, bytes, str(perr), str(rtt)])
    out.flush()
    if run_time >= duration:
        out.close()
        return true
    return false
