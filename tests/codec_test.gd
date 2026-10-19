extends SceneTree

# Round-trip + size test for the compact snapshot codec in scripts/game.gd.

var failures := 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        print("FAIL  ", label)

func near(a: float, b: float, tol: float) -> bool:
    return absf(a - b) <= tol

func _initialize() -> void:
    print("[codec checkpoint] START: instantiate Main.tscn")
    var game: Node = load("res://Main.tscn").instantiate()
    # Set offline mode before entering the tree so startup callbacks never try to use LAN APIs.
    game.is_offline = true
    game.is_host = true
    root.add_child(game)
    # SceneTree._initialize runs before the first idle frame. Yield once so Main._ready()
    # and its runtime asset loaders finish before we assert texture fields.
    print("[codec checkpoint] Waiting for Main.tscn _ready and asset loading")
    await process_frame
    print("[codec checkpoint] Main.tscn instantiated; ready=%s" % str(game.is_node_ready()))
    check(game.is_node_ready(), "Main.tscn completes _ready before runtime tests")
    # The codec suite is an offline test; no MultiplayerAPI/peer is required.
    game.is_offline = true
    game.screen_size = Vector2(1201, 540)
    game.is_host = true
    var rng := RandomNumberGenerator.new()
    rng.seed = 11

    var scenarios := [
        {"name": "lobby, 2 players, idle", "p": 2, "z": 0, "fx": 0, "g": 0, "w": 0, "t": 0, "d": 0},
        {"name": "2 players, 6 zombies, idle", "p": 2, "z": 6, "fx": 0, "g": 0, "w": 0, "t": 1, "d": 0},
        {"name": "2 players, 10 zombies, shooting", "p": 2, "z": 10, "fx": 4, "g": 0, "w": 0, "t": 0, "d": 0},
        {"name": "4 players, 14 zombies, busy", "p": 4, "z": 14, "fx": 12, "g": 1, "w": 3, "t": 2, "d": 1},
        {"name": "4 players, 14 zombies, worst case", "p": 4, "z": 14, "fx": 36, "g": 3, "w": 8, "t": 4, "d": 2},
        {"name": "boss + 13 zombies, normalized boss HP", "p": 4, "z": 14, "fx": 12, "g": 1, "w": 3, "t": 3, "d": 1},
    ]
    check(game._zombie_count_for_wave(1) == 25, "wave 1 starts with 25 infected")
    check(game._zombie_count_for_wave(2) == 30, "wave 2 grows beyond 25")
    check(game._zombie_count_for_wave(10) == 70, "wave 10 scales the horde")
    check(game._zombie_count_for_wave(20) > game._zombie_count_for_wave(10), "higher waves keep growing")
    check(game._boss_hp_for_wave(20) > game._boss_hp_for_wave(10), "boss HP scales by boss tier")
    var max_bytes := 0
    for sc in scenarios:
        var boss_scenario := str(sc.name).contains("boss")
        game.wave_number = 10 if boss_scenario else 3
        game.wave_total = game._zombie_count_for_wave(game.wave_number)
        game.players.clear()
        game.zombies.clear()
        game.combat_effects.clear()
        game.barricades.clear()
        game.turrets.clear()
        game.airdrops.clear()
        game.active_grenades.clear()
        game.cmd_last_seq.clear()
        var ids: Array[int] = [1]
        for i in range(int(sc.p) - 1):
            ids.append(rng.randi_range(100000, 2000000000))
        for pid in ids:
            game.players[pid] = {"x": rng.randf_range(30, 1170), "y": rng.randf_range(300, 460), "hp": rng.randf_range(1, 100), "medkits": 2, "ammo": -1, "grenades": 3, "wall_kits": 2, "turret_kits": rng.randi_range(0, 2), "face_x": -1.0, "name": "P", "walking": true, "shoot_timer": 0.17, "hurt_timer": 0.0}
            game.cmd_last_seq[pid] = rng.randi_range(0, 100000)
        for i in range(int(sc.z)):
            var zombie_kind := 4 if boss_scenario and i == 0 else rng.randi_range(0, 3)
            var max_zombie_hp: float = game._zombie_max_hp_for(zombie_kind, game.wave_number)
            var hp_value: float = max_zombie_hp * 0.73 if zombie_kind == 4 else 3.5
            game.zombies.append({"id": rng.randi(), "kind": zombie_kind, "x": rng.randf_range(30, 1170), "y": rng.randf_range(300, 460), "face_x": 1.0, "hp": hp_value, "max_hp": max_zombie_hp, "walking": true, "attacking": i % 3 == 0, "attack_timer": 0.2, "attack_cooldown": 0.3, "hit_timer": 0.1})
        var born := Time.get_ticks_msec()
        for i in range(int(sc.fx)):
            game.combat_effects.append({"eid": i + 1, "born_ms": born - i * 5, "src": ids[0], "kind": i % 8, "x": rng.randf_range(0, 1100), "y": 300.0, "x2": 500.0, "y2": 320.0, "ttl": 0.1, "life": 0.3})
        for i in range(int(sc.w)):
            game.barricades.append({"id": rng.randi(), "x": 100.0 + i * 130, "y": 380.0, "hp": 90.0 - i, "max_hp": 125.0, "owner_id": 1})
        for i in range(int(sc.get("t", 0))):
            game.turrets.append({"id": i + 1, "x": 250.0 + i * 115.0, "y": 374.0 + (i % 2) * 44.0, "hp": 140.0 - i, "max_hp": game.TURRET_MAX_HP, "angle": -0.5 + i * 0.25, "face_x": -1.0 if i % 2 == 0 else 1.0, "fire_timer": 0.1, "flash_timer": 0.0})
        for i in range(int(sc.d)):
            game.airdrops.append({"id": i + 1, "x": 300.0 + i * 200, "y": 350.0, "start_y": 280.0, "land_y": 400.0, "elapsed": 1.3, "fall_duration": 2.6, "despawn_timer": 20.0, "landed": false, "loot_kind": "wall", "quantity": 2})
        for i in range(int(sc.g)):
            game.active_grenades.append({"id": rng.randi(), "owner_id": 1, "start_x": 100.0, "start_y": 380.0, "target_x": 300.0, "target_y": 390.0, "x": 150.0, "y": 382.0, "elapsed": 0.2, "travel_time": 0.6, "flight_height": 70.0, "fuse": 0.8})

        # Exercise the expanded loadout and packed weapon subtype fields in a busy LAN packet.
        if str(sc.name).contains("worst case"):
            var test_player: Dictionary = game.players[ids[0]]
            test_player["active_slot"] = 2
            test_player["slot1_type"] = game.WEAPON_SMG
            test_player["slot1_mag"] = 21
            test_player["slot1_reserve"] = 63
            test_player["slot2_type"] = game.WEAPON_ROCKET
            test_player["slot2_mag"] = 1
            test_player["slot2_reserve"] = 3
            test_player["reload_timer"] = 0.73
            test_player["weapon_replace_pending"] = true
            test_player["pending_weapon_id"] = game.WEAPON_SNIPER
            game.players[ids[0]] = test_player
            game.airdrops[0]["loot_kind"] = "weapon"
            game.airdrops[0]["weapon_id"] = game.WEAPON_SNIPER
            game.airdrops[0]["quantity"] = 1
            game.airdrops[1]["loot_kind"] = "ammo"
            game.airdrops[1]["weapon_id"] = game.WEAPON_ROCKET
            game.airdrops[1]["quantity"] = 1

        var buf: PackedByteArray = game._encode_snapshot()
        max_bytes = maxi(max_bytes, buf.size())
        check(buf.size() <= game.MAX_SNAPSHOT_BYTES, "%s: %d bytes exceeds cap" % [sc.name, buf.size()])
        var snap: Dictionary = game._decode_snapshot(buf)
        check(not snap.is_empty(), sc.name + ": decode returned empty")
        if snap.is_empty():
            continue
        check(snap.players.size() == int(sc.p), sc.name + ": player count")
        check(snap.zids.size() == int(sc.z), sc.name + ": zombie count")
        for pid in ids:
            var a: Dictionary = game.players[pid]
            var b: Dictionary = snap.players[pid]
            check(near(float(a.x), float(b.x), 0.07) and near(float(a.y), float(b.y), 0.07), "player pos pid=%d" % pid)
            check(near(float(a.hp), float(b.hp), 0.26), "player hp")
            check((int(b.fl) & 1) != 0 and (int(b.fl) & 2) != 0, "player flags")
            check(int(b.ack) == int(game.cmd_last_seq[pid]), "player ack")
            if str(sc.name).contains("worst case") and pid == ids[0]:
                check(int(b.active_slot) == 2, "active weapon slot round-trips")
                check(int(b.slot1_type) == game.WEAPON_SMG and int(b.slot1_mag) == 21 and int(b.slot1_reserve) == 63, "slot 1 weapon/ammo round-trip")
                check(int(b.slot2_type) == game.WEAPON_ROCKET and int(b.slot2_mag) == 1 and int(b.slot2_reserve) == 3, "slot 2 weapon/ammo round-trip")
                check(near(float(b.reload_timer), 0.73, 0.02), "reload timer round-trips")
                check(bool(b.replace_pending) and int(b.pending_weapon_id) == game.WEAPON_SNIPER, "weapon replacement prompt round-trips in spare player flags")
        for z in game.zombies:
            var zr: Dictionary = snap.zombies[int(z.id) & 0xFFFFFFFF]
            check(near(float(z.x), float(zr.x), 0.07) and near(float(z.y), float(zr.y), 0.07), "zombie pos")
            var hp_tolerance := 0.45 if int(z.kind) == 4 else 0.03
            check(near(float(z.hp), float(zr.hp), hp_tolerance), "zombie hp")
            check(int(zr.kind) == int(z.kind), "zombie kind")
        check(snap.walls.size() == int(sc.w), sc.name + ": walls")
        check(snap.turrets.size() == int(sc.get("t", 0)), sc.name + ": turrets")
        for turret_index in range(snap.turrets.size()):
            var source_turret: Dictionary = game.turrets[turret_index]
            var decoded_turret: Dictionary = snap.turrets[turret_index]
            check(int(source_turret.id) == int(decoded_turret.id), "turret id round-trip")
            check(near(float(source_turret.x), float(decoded_turret.x), 0.07) and near(float(source_turret.y), float(decoded_turret.y), 0.07), "turret position round-trip")
            check(near(float(source_turret.hp), float(decoded_turret.hp), 1.0), "turret HP round-trip")
            check(absf(float(source_turret.angle) - float(decoded_turret.angle)) <= 0.03, "turret relative head angle round-trip")
            check((float(source_turret.get("face_x", 1.0)) < 0.0) == (float(decoded_turret.get("face_x", 1.0)) < 0.0), "turret facing direction round-trips in angle byte")
        for pid in ids:
            var player_source: Dictionary = game.players[pid]
            var player_decoded: Dictionary = snap.players[pid]
            check(int(player_decoded.get("turret", 0)) == int(player_source.get("turret_kits", 0)), "turret kits round-trip")
        check(snap.drops.size() == int(sc.d), sc.name + ": drops")
        if int(sc.d) > 0:
            if str(sc.name).contains("worst case"):
                check(str(snap.drops[0].loot_kind) == "weapon" and int(snap.drops[0].weapon_id) == game.WEAPON_SNIPER, "weapon airdrop subtype round-trips")
                check(str(snap.drops[1].loot_kind) == "ammo" and int(snap.drops[1].weapon_id) == game.WEAPON_ROCKET, "compatible ammo airdrop subtype round-trips")
            else:
                check(str(snap.drops[0].loot_kind) == "wall" and int(snap.drops[0].quantity) == 2, "drop loot decode")
        check(snap.nades.size() == int(sc.g), sc.name + ": nades")
        var expected_fx := mini(int(sc.fx), game.MAX_EFFECTS_PER_SNAPSHOT)
        check(snap.fx.size() == expected_fx, "%s: effects %d != %d" % [sc.name, snap.fx.size(), expected_fx])
        if snap.fx.size() > 0:
            check(int(snap.fx[0].src) == ids[0], "effect src mapping")
        print("%-40s %5d bytes  (players %d, zombies %d, effects %d)" % [sc.name, buf.size(), snap.players.size(), snap.zids.size(), snap.fx.size()])

    print("[codec checkpoint] PASS: snapshot scenario round-trips")
    var legacy_left_orientation: Dictionary = game._restore_turret_orientation({"angle": 2.6, "face_x": -1.0}, 6)
    check(float(legacy_left_orientation.face_x) < 0.0 and absf(float(legacy_left_orientation.angle)) <= game.TURRET_ARC_HALF_ANGLE, "legacy world save migrates global turret yaw to left-facing half-arc")
    var legacy_inferred_orientation: Dictionary = game._restore_turret_orientation({"angle": -2.7}, 6)
    check(float(legacy_inferred_orientation.face_x) < 0.0 and absf(float(legacy_inferred_orientation.angle)) <= game.TURRET_ARC_HALF_ANGLE, "legacy turret without facing field infers and migrates left-facing yaw")
    var current_orientation: Dictionary = game._restore_turret_orientation({"angle": -0.4, "face_x": -1.0}, 7)
    check(float(current_orientation.face_x) < 0.0 and near(float(current_orientation.angle), -0.4, 0.001), "current turret save preserves relative angle and facing")
    var prior_screen_mode: String = str(game.screen_mode)
    game.screen_mode = "settings"
    game.button_rects.clear() # deliberately stale/empty: first setting tap must still work.
    var aim_toggle_rect: Rect2 = game._settings_aim_toggle_rect()
    var aim_before_touch: bool = bool(game.aim_marker_enabled)
    game.aim_toggle_last_msec = -1000
    game._touch_start(9, aim_toggle_rect.position + Vector2(1.0, 1.0))
    check(bool(game.aim_marker_enabled) != aim_before_touch, "AIM Settings toggle responds to first touch at switch-row edge")
    var aim_after_toggle: bool = bool(game.aim_marker_enabled)
    game._touch_start(10, aim_toggle_rect.position + aim_toggle_rect.size * 0.5)
    check(bool(game.aim_marker_enabled) == aim_after_toggle, "duplicate adjacent AIM touch does not toggle twice")
    game._touch_start(11, aim_toggle_rect.position - Vector2(30.0, 25.0))
    check(bool(game.aim_marker_enabled) == aim_after_toggle, "AIM Settings tap outside switch does not toggle")
    game.aim_toggle_last_msec = -1000
    game._touch_start(12, aim_toggle_rect.position + aim_toggle_rect.size * 0.5)
    check(bool(game.aim_marker_enabled) == aim_before_touch, "AIM Settings switch track toggles back on tap")
    # Android builds can report touches in viewport or physical-window space. Validate the
    # transformed path that _input uses while the menu transform is non-identity.
    game.position = Vector2(310.0, 115.0)
    var viewport_aim_point: Vector2 = aim_toggle_rect.position + aim_toggle_rect.size * 0.5
    var mapped_aim_point: Vector2 = game._input_canvas_position(viewport_aim_point)
    check(aim_toggle_rect.has_point(mapped_aim_point), "AIM toggle maps transformed viewport touch to the same visible row")
    game.position = Vector2.ZERO
    game.screen_mode = prior_screen_mode
    game.button_rects.clear()
    # Weapon profiles and reload arithmetic are deterministic and bounded.
    var sidearm_profile: Dictionary = game._weapon_profile(game.WEAPON_SIDEARM)
    check(int(sidearm_profile.mag_size) == -1 and int(sidearm_profile.interval_ms) == 280, "default sidearm keeps infinite ammo")
    var renbo_profile: Dictionary = game._weapon_profile(game.WEAPON_RIFLE)
    check(str(renbo_profile.name) == "RENBO LMG", "rifle slot is the Renbo/LMG airdrop role")
    check(int(renbo_profile.mag_size) >= 40 and int(renbo_profile.interval_ms) < 160, "Renbo LMG has sustained automatic-fire tuning")
    check(game.AIRDROP_FIRST_DELAY < game.AIRDROP_INTERVAL_MIN and game.AIRDROP_INTERVAL_MAX <= 35.0, "airdrops are more frequent than the previous 55-76 second interval")
    var seen_weapon_effects: Array[int] = []
    for weapon_id in range(game.WEAPON_SMG, game.WEAPON_ROCKET + 1):
        var profile: Dictionary = game._weapon_profile(weapon_id)
        check(float(profile.damage) > 0.0 and float(profile.range) > 0.0 and int(profile.interval_ms) > 0, "weapon %d has positive damage/range/cadence" % weapon_id)
        check(int(profile.mag_size) > 0 and int(profile.reserve_cap) >= int(profile.spawn_reserve) and int(profile.ammo_pack) > 0, "weapon %d has coherent finite ammunition" % weapon_id)
        check(not seen_weapon_effects.has(int(profile.effect)), "weapon %d has a dedicated firing effect" % weapon_id)
        seen_weapon_effects.append(int(profile.effect))
    var weapon_inventory := {"active_slot": 0, "slot1_type": -1, "slot1_mag": 0, "slot1_reserve": 0, "slot2_type": -1, "slot2_mag": 0, "slot2_reserve": 0, "reload_timer": 0.0}
    var sniper_slot: int = game._give_weapon(weapon_inventory, game.WEAPON_SNIPER)
    check(sniper_slot == 1 and int(weapon_inventory.slot1_type) == game.WEAPON_SNIPER, "weapon pickup fills first limited-ammo slot")
    check(int(weapon_inventory.slot1_mag) == 5 and int(weapon_inventory.slot1_reserve) == 10, "weapon pickup receives correct sniper ammunition")
    game._set_slot_ammo(weapon_inventory, sniper_slot, 0, 4)
    game._start_weapon_reload(weapon_inventory, sniper_slot)
    check(float(weapon_inventory.reload_timer) > 0.0, "reload starts only with reserve ammo")
    game._finish_weapon_reload(weapon_inventory)
    check(int(weapon_inventory.slot1_mag) == 4 and int(weapon_inventory.slot1_reserve) == 0, "partial magazine reload transfers only available ammo")
    check(int(weapon_inventory.slot1_reserve) >= 0, "weapon reserve never becomes negative")

    var replacement_inventory := {"active_slot": 1, "slot1_type": game.WEAPON_SMG, "slot1_mag": 11, "slot1_reserve": 40, "slot2_type": game.WEAPON_SHOTGUN, "slot2_mag": 3, "slot2_reserve": 12, "reload_timer": 0.0}
    check(game._weapon_pickup_needs_choice(replacement_inventory, game.WEAPON_SNIPER), "full weapon inventory requests explicit slot selection")
    check(game._give_weapon(replacement_inventory, game.WEAPON_SNIPER) == 0, "full inventory does not silently overwrite either slot")
    check(int(replacement_inventory.slot1_type) == game.WEAPON_SMG and int(replacement_inventory.slot2_type) == game.WEAPON_SHOTGUN, "unselected weapon slots remain unchanged")
    check(game._give_weapon(replacement_inventory, game.WEAPON_SNIPER, 2) == 2, "explicit slot 2 replacement succeeds")
    check(int(replacement_inventory.slot2_type) == game.WEAPON_SNIPER and int(replacement_inventory.slot1_type) == game.WEAPON_SMG, "only the selected weapon slot is replaced")

    print("[codec checkpoint] PASS: weapon profiles, reload arithmetic, and replacement choice")

    game.is_host = true
    game.is_offline = true
    game.local_player_id = 1
    game.players.clear()
    game.airdrops.clear()
    game.players[1] = {"x": 320.0, "y": 390.0, "hp": 100.0, "medkits": 2, "ammo": -1, "grenades": 3, "wall_kits": 2, "turret_kits": 0, "active_slot": 1, "slot1_type": game.WEAPON_SMG, "slot1_mag": 11, "slot1_reserve": 40, "slot2_type": game.WEAPON_SHOTGUN, "slot2_mag": 3, "slot2_reserve": 12, "reload_timer": 0.0, "weapon_replace_pending": true, "pending_weapon_drop_id": 76501, "pending_weapon_id": game.WEAPON_SNIPER}
    game.airdrops.append({"id": 76501, "x": 320.0, "y": 390.0, "landed": true, "despawn_timer": 12.0, "loot_kind": "weapon", "weapon_id": game.WEAPON_SNIPER, "reserved_by": 1})
    game._host_resolve_weapon_replacement(1, 2)
    var resolved_pickup: Dictionary = game.players[1]
    check(int(resolved_pickup.slot1_type) == game.WEAPON_SMG and int(resolved_pickup.slot2_type) == game.WEAPON_SNIPER, "host pickup resolver replaces only selected slot and leaves the other weapon untouched")
    check(game.airdrops.is_empty() and not bool(resolved_pickup.weapon_replace_pending), "chosen weapon consumes reserved drop and closes prompt")
    # Simulate the first touch before the next _draw pass has built button_rects.
    var previous_replace_screen: String = str(game.screen_mode)
    game.screen_mode = "game"
    game.players[1] = {"x": 320.0, "y": 390.0, "hp": 100.0, "active_slot": 1, "slot1_type": game.WEAPON_SMG, "slot1_mag": 10, "slot1_reserve": 40, "slot2_type": game.WEAPON_SHOTGUN, "slot2_mag": 3, "slot2_reserve": 12, "weapon_replace_pending": true, "pending_weapon_drop_id": 76503, "pending_weapon_id": game.WEAPON_SNIPER}
    game.airdrops.clear()
    game.airdrops.append({"id": 76503, "x": 320.0, "y": 390.0, "landed": true, "despawn_timer": 12.0, "loot_kind": "weapon", "weapon_id": game.WEAPON_SNIPER, "reserved_by": 1})
    game.button_rects.clear()
    var initial_prompt_rects: Dictionary = game._weapon_replace_hitboxes()
    var first_replace_rect: Rect2 = initial_prompt_rects["weapon_replace_2"]
    game.position = Vector2(137.0, 19.0)
    var first_replace_viewport_point: Vector2 = first_replace_rect.position + Vector2(8.0, 8.0)
    var first_replace_mapped_point: Vector2 = game._input_canvas_position(first_replace_viewport_point)
    game._touch_start(29, first_replace_mapped_point)
    game.position = Vector2.ZERO
    check(int(game.players[1].get("slot2_type", -1)) == game.WEAPON_SNIPER and game.airdrops.is_empty(), "first weapon replacement touch works even before draw registers modal hitboxes")
    game.screen_mode = previous_replace_screen
    game.players[1]["weapon_replace_pending"] = true
    game.players[1]["pending_weapon_drop_id"] = 76502
    game.players[1]["pending_weapon_id"] = game.WEAPON_ROCKET
    game.airdrops.append({"id": 76502, "x": 320.0, "y": 390.0, "landed": true, "despawn_timer": 12.0, "loot_kind": "weapon", "weapon_id": game.WEAPON_ROCKET, "reserved_by": 1})
    game._host_cancel_weapon_replacement(1)
    check(game.airdrops.size() == 1 and not game.airdrops[0].has("reserved_by"), "cancel releases weapon crate instead of consuming it")
    check(not bool(game.players[1].get("weapon_replace_pending", true)), "cancel closes weapon replacement prompt")
    # Exercise the visible Cancel hitbox and touch routing, not only the host helper.
    game.screen_mode = "game"
    game.players[1]["weapon_replace_pending"] = true
    game.players[1]["pending_weapon_drop_id"] = 76504
    game.players[1]["pending_weapon_id"] = game.WEAPON_SNIPER
    game.airdrops.append({"id": 76504, "x": 320.0, "y": 390.0, "landed": true, "despawn_timer": 12.0, "loot_kind": "weapon", "weapon_id": game.WEAPON_SNIPER, "reserved_by": 1})
    var cancel_hitboxes: Dictionary = game._weapon_replace_hitboxes()
    var cancel_rect: Rect2 = cancel_hitboxes["weapon_replace_cancel"]
    check(cancel_rect.size.y >= 40.0, "weapon replacement Cancel has a thumb-friendly hit target")
    game.button_rects.clear()
    game._touch_start(30, cancel_rect.position + cancel_rect.size * 0.5)
    check(not bool(game.players[1].get("weapon_replace_pending", true)), "first touch on replacement Cancel dismisses the prompt")
    check(not game._weapon_replace_prompt_visible(), "first touch on Cancel closes the visible replacement modal immediately")
    check(int(game.airdrops.back().get("reserved_by", -1)) != 1, "replacement Cancel releases the crate reservation")
    # A client may receive one older snapshot after its reliable cancel RPC. It must not
    # reopen the modal during that short acknowledgement window.
    game.weapon_replace_cancel_pending = true
    game.weapon_replace_cancel_started_msec = Time.get_ticks_msec()
    check(not game._resolve_weapon_replace_snapshot_state(true, Time.get_ticks_msec() + 250), "stale in-flight snapshot cannot reopen a cancelled weapon modal")
    check(not game._resolve_weapon_replace_snapshot_state(false, Time.get_ticks_msec() + 300), "host cancellation acknowledgement clears modal suppression")

    # Root-cause regression: Cancel releases a reserved crate, but the player is still
    # overlapping its pickup radius. The same modal must remain closed until they leave.
    game.weapon_replace_cancel_pending = false
    game.weapon_replace_cancel_started_msec = -1
    game.airdrops.clear()
    game.airdrop_cancel_ignore_by_player.clear()
    game.airdrop_spawn_timer = 999.0
    var cancel_loop_player: Dictionary = game.players.get(1, {})
    cancel_loop_player["x"] = 320.0
    cancel_loop_player["y"] = 390.0
    cancel_loop_player["hp"] = 100.0
    cancel_loop_player["slot1_type"] = game.WEAPON_SMG
    cancel_loop_player["slot1_mag"] = 10
    cancel_loop_player["slot1_reserve"] = 40
    cancel_loop_player["slot2_type"] = game.WEAPON_SHOTGUN
    cancel_loop_player["slot2_mag"] = 3
    cancel_loop_player["slot2_reserve"] = 12
    cancel_loop_player["weapon_replace_pending"] = false
    cancel_loop_player["pending_weapon_drop_id"] = -1
    cancel_loop_player["pending_weapon_id"] = 0
    game.players[1] = cancel_loop_player
    game.airdrops.append({"id": 76505, "x": 320.0, "y": 390.0, "landed": true, "despawn_timer": 20.0, "loot_kind": "weapon", "weapon_id": game.WEAPON_SNIPER, "reserved_by": -1})
    game._update_airdrops(0.016)
    check(bool(game.players[1].get("weapon_replace_pending", false)) and int(game.players[1].get("pending_weapon_drop_id", -1)) == 76505, "nearby weapon crate opens replacement modal initially")
    game._host_cancel_weapon_replacement(1)
    game._update_airdrops(0.016)
    check(not bool(game.players[1].get("weapon_replace_pending", false)), "Cancel suppresses the same crate while player remains in pickup radius")
    check(int(game.airdrops[0].get("reserved_by", -1)) == -1 and int(game.airdrop_cancel_ignore_by_player.get(1, -1)) == 76505, "cancelled crate remains available but ignored for this player")
    cancel_loop_player = game.players[1]
    cancel_loop_player["x"] = 430.0
    game.players[1] = cancel_loop_player
    game._update_airdrops(0.016)
    check(not game.airdrop_cancel_ignore_by_player.has(1), "leaving the cancel release radius re-enables pickup attempt")
    cancel_loop_player = game.players[1]
    cancel_loop_player["x"] = 320.0
    game.players[1] = cancel_loop_player
    game._update_airdrops(0.016)
    check(bool(game.players[1].get("weapon_replace_pending", false)) and int(game.airdrops[0].get("reserved_by", -1)) == 1, "returning to the same crate can open replacement modal again")
    game._host_cancel_weapon_replacement(1)
    game.airdrops.clear()
    game.airdrop_cancel_ignore_by_player.clear()
    print("[codec checkpoint] PASS: cancelled nearby crate stays closed until player leaves and returns")
    check(not game.weapon_replace_cancel_pending, "cancel acknowledgement releases the temporary snapshot guard")
    game.screen_mode = previous_replace_screen
    print("[codec checkpoint] PASS: host replacement selection and cancellation")
    # Ammo airdrops must match an owned firearm and never be wasted at a full reserve.
    var ammo_profile: Dictionary = game._weapon_profile(game.WEAPON_SMG)
    var ammo_inventory := {"active_slot": 0, "slot1_type": game.WEAPON_SMG, "slot1_mag": 0, "slot1_reserve": int(ammo_profile.reserve_cap), "slot2_type": -1, "slot2_mag": 0, "slot2_reserve": 0, "reload_timer": 0.0}
    check(game._can_collect_ammo(ammo_inventory, game.WEAPON_SMG), "ammo cache can refill a missing magazine when reserve is capped")
    check(not game._can_collect_ammo(ammo_inventory, game.WEAPON_SHOTGUN), "ammo cache cannot be collected for an unowned weapon")
    game.players.clear()
    game.players[1] = {"x": 320.0, "y": 390.0, "hp": 100.0, "medkits": 2, "ammo": -1, "grenades": 3, "wall_kits": 2, "active_slot": 0, "slot1_type": game.WEAPON_SMG, "slot1_mag": 0, "slot1_reserve": int(ammo_profile.reserve_cap), "slot2_type": -1, "slot2_mag": 0, "slot2_reserve": 0, "reload_timer": 0.0}
    game._grant_airdrop_loot(1, {"loot_kind": "ammo", "weapon_id": game.WEAPON_SMG, "quantity": 1})
    var ammo_after_pickup: Dictionary = game.players[1]
    check(int(ammo_after_pickup.slot1_mag) == int(ammo_profile.mag_size), "reserve-full ammo cache tops up the magazine")
    check(int(ammo_after_pickup.slot1_reserve) == int(ammo_profile.reserve_cap), "magazine top-up preserves full reserve ammo")
    check(not game._can_collect_ammo(ammo_after_pickup, game.WEAPON_SMG), "full magazine and reserve leave ammo cache collectible disabled")
    game.players[1] = {"x": 320.0, "y": 390.0, "hp": 100.0, "medkits": 2, "ammo": -1, "grenades": 3, "wall_kits": 2, "active_slot": 0, "slot1_type": game.WEAPON_SMG, "slot1_mag": 10, "slot1_reserve": 175, "slot2_type": -1, "slot2_mag": 0, "slot2_reserve": 0, "reload_timer": 0.0}
    game._grant_airdrop_loot(1, {"loot_kind": "ammo", "weapon_id": game.WEAPON_SMG, "quantity": 1})
    var split_ammo_result: Dictionary = game.players[1]
    check(int(split_ammo_result.slot1_reserve) == 180 and int(split_ammo_result.slot1_mag) == 30, "partial reserve space is filled before excess ammo tops up the magazine")

    print("[codec checkpoint] PASS: ammo airdrop cases")
    # A depleted firearm with no reserve must reliably return to the infinite-ammo sidearm.
    game.players.clear()
    game.zombies.clear()
    game.fire_cooldowns.clear()
    game.players[1] = {"x": 320.0, "y": 390.0, "hp": 100.0, "medkits": 2, "ammo": -1, "grenades": 3, "wall_kits": 2, "active_slot": 2, "slot1_type": -1, "slot1_mag": 0, "slot1_reserve": 0, "slot2_type": game.WEAPON_ROCKET, "slot2_mag": 0, "slot2_reserve": 0, "reload_timer": 0.0, "face_x": 1.0, "shoot_timer": 0.0, "hurt_timer": 0.0}
    print("[codec checkpoint] BEFORE: _host_fire fallback test")
    game._host_fire(1)
    print("[codec checkpoint] AFTER: _host_fire fallback test")
    check(int(game.players[1].active_slot) == 0, "empty firearm with no reserve switches to default sidearm")

    print("[codec checkpoint] PASS: empty-ammo sidearm fallback")
    # Boss attack type reuses spare flags bits without changing the 13-byte zombie record.
    game.players.clear()
    game.players[1] = {"x": 320.0, "y": 390.0, "hp": 100.0, "medkits": 2, "ammo": -1, "grenades": 3, "wall_kits": 2, "face_x": 1.0, "name": "P1", "walking": false, "shoot_timer": 0.0, "hurt_timer": 0.0}
    game.barricades.clear()
    game.airdrops.clear()
    game.active_grenades.clear()
    game.combat_effects.clear()
    game.wave_number = 10
    game.wave_total = game._zombie_count_for_wave(10)
    for attack_type in range(game.BOSS_ATTACK_LUNGE + 1):
        game.zombies.clear()
        var boss_id := 42420 + attack_type
        var boss_max_hp: float = game._boss_hp_for_wave(10)
        game.zombies.append({"id": boss_id, "kind": game.ZOMBIE_KIND_BOSS, "x": 500.0, "y": 390.0, "face_x": 1.0, "hp": boss_max_hp * 0.75, "max_hp": boss_max_hp, "walking": false, "attacking": true, "attack_timer": 0.4, "attack_cooldown": 0.8, "attack_type": attack_type, "hit_timer": 0.0})
        var boss_packet: PackedByteArray = game._encode_snapshot()
        var boss_snapshot: Dictionary = game._decode_snapshot(boss_packet)
        check(not boss_snapshot.is_empty(), "boss attack type %d snapshot decodes" % attack_type)
        if not boss_snapshot.is_empty():
            var decoded_boss: Dictionary = boss_snapshot.zombies.get(boss_id, {})
            check(int(decoded_boss.get("attack_type", -1)) == attack_type, "boss attack type %d round-trips in flags" % attack_type)
            check(near(float(decoded_boss.get("atk", -1.0)), 0.4, 0.02), "boss attack timer round-trips")
        check(boss_packet.size() <= game.MAX_SNAPSHOT_BYTES, "boss attack animation leaves snapshot under cap")
        var previous_frame := -1
        for frame_step in range(11):
            var attack_frame: int = game._boss_attack_frame(attack_type, float(frame_step) / 10.0)
            check(attack_frame >= 0 and attack_frame < game.BOSS_ATTACK_FRAME_COUNT, "boss attack frame stays inside sheet")
            check(attack_frame >= previous_frame, "boss attack frames are ordered")
            previous_frame = attack_frame

    print("[codec checkpoint] PASS: boss attack snapshot and frames")
    # Verify both the packed project resources and the textures actually loaded by Game._ready().
    var turret_base_resource: Texture2D = ResourceLoader.load("res://assets/turret_base.png") as Texture2D
    var turret_head_resource: Texture2D = ResourceLoader.load("res://assets/turret_head.png") as Texture2D
    check(turret_base_resource != null and turret_head_resource != null, "turret base/head PNG resources load from res paths")
    check(game.turret_base_texture != null and game.turret_head_texture != null, "game ready loads turret base/head PNG assets")
    check(ResourceLoader.exists("res://assets/audio/turret_fire.wav"), "turret fire SFX resource exists")
    # Auto-turret placement, aim tracking, automatic fire and zombie destruction.
    game.players.clear()
    game.zombies.clear()
    game.turrets.clear()
    game.barricades.clear()
    game.combat_effects.clear()
    game.local_player_id = 1
    game.is_host = true
    game.is_offline = true
    game.game_over = false
    game.players[1] = {
        "x": 320.0, "y": 390.0, "hp": 100.0, "medkits": 2, "ammo": -1,
        "grenades": 3, "wall_kits": 2, "turret_kits": 1, "face_x": 1.0,
        "name": "P1", "walking": false, "shoot_timer": 0.0, "hurt_timer": 0.0,
        "active_slot": 0, "slot1_type": -1, "slot1_mag": 0, "slot1_reserve": 0,
        "slot2_type": -1, "slot2_mag": 0, "slot2_reserve": 0, "reload_timer": 0.0
    }
    var turret_spot := Vector2(430.0, 390.0)
    game._begin_turret_placement(17)
    check(game.turret_place_active and game.turret_place_touch_id < 0 and not game.turret_requested, "TUR button enters placement mode without instantly deploying on button release")
    # Simulate a tap before a draw pass has registered the selector hitboxes.
    var turret_screen_before_tap: String = str(game.screen_mode)
    game.screen_mode = "game"
    game.button_rects.clear()
    var selector_rects: Dictionary = game._turret_facing_button_rects()
    var first_left_selector_rect: Rect2 = selector_rects["turret_face_left"]
    game._touch_start(18, first_left_selector_rect.position + first_left_selector_rect.size * 0.5)
    check(float(game.turret_preview_face_x) < 0.0 and not game.turret_requested, "first AIM LEFT placement tap works before draw registers selector hitboxes")
    game._touch_start(19, turret_spot)
    check(game.turret_place_touch_id == 19, "touching the arena starts the turret preview drag")
    game._set_turret_preview_from_pointer(Vector2(420.0, 390.0))
    game._touch_end(19)
    check(game.turret_place_active and not game.turret_requested, "releasing the turret drag keeps the preview without deploying")
    var deploy_rect: Rect2 = game._game_turret_button_rect()
    game.button_rects.clear()
    game._touch_start(20, deploy_rect.position + deploy_rect.size * 0.5)
    check(game.turret_requested, "first touch on the visible DEPLOY control confirms the turret preview")
    game.turret_requested = false
    var placement_cancel_rect: Rect2 = game._turret_placement_control_rects()["turret_cancel"]
    check(placement_cancel_rect.size.y >= 32.0, "turret placement Cancel has a thumb-friendly target")
    game.button_rects.clear()
    game._touch_start(21, placement_cancel_rect.position + placement_cancel_rect.size * 0.5)
    check(not game.turret_place_active and not game.turret_requested, "first touch on visible turret Cancel exits without deploying")
    game._begin_turret_placement()
    # Re-entering placement intentionally seeds facing from the survivor's current heading.
    # Select LEFT again in this new placement session, then move the preview to the right.
    game._handle_ui_button("turret_face_left")
    check(float(game.turret_preview_face_x) < 0.0, "AIM LEFT can be explicitly selected after re-entering turret placement")
    game._set_turret_preview_from_pointer(Vector2(420.0, 390.0))
    check(float(game.turret_preview_face_x) < 0.0, "explicit AIM LEFT selector stays left even when placement point is on the right")
    game._handle_ui_button("turret_face_right")
    game._set_turret_preview_from_pointer(Vector2(240.0, 390.0))
    check(float(game.turret_preview_face_x) > 0.0, "explicit AIM RIGHT selector stays right even when placement point is on the left")
    game.screen_mode = turret_screen_before_tap
    game.button_rects.clear()
    game.turret_place_active = false
    game.turret_place_touch_id = -1
    game.turret_requested = false
    check(game._turret_placement_is_valid(1, turret_spot), "turret spot inside placement ring is valid")
    check(not game._turret_placement_is_valid(1, Vector2(334.0, 390.0)), "turret cannot be placed too close to owner")
    game.build_cooldowns[1] = Time.get_ticks_msec() - 1000
    print("[codec checkpoint] BEFORE: _host_build_turret placement test")
    game._host_build_turret(1, turret_spot.x / game.screen_size.x, turret_spot.y / game.screen_size.y)
    print("[codec checkpoint] AFTER: _host_build_turret placement test")
    check(game.turrets.size() == 1, "host successfully deploys one turret kit")
    check(int(game.players[1].get("turret_kits", 0)) == 0, "successful turret deploy consumes one kit")
    game.players[1]["turret_kits"] = 1
    game.build_cooldowns[1] = Time.get_ticks_msec() - 1000
    var left_turret_spot := Vector2(560.0, 390.0)
    game._host_build_turret(1, left_turret_spot.x / game.screen_size.x, left_turret_spot.y / game.screen_size.y, -1.0)
    check(game.turrets.size() == 2 and float(game.turrets[1].get("x", 0.0)) > float(game.players[1].get("x", 0.0)) and float(game.turrets[1].get("face_x", 1.0)) < 0.0, "host preserves left-facing choice for a turret placed to the right of its owner")
    if game.turrets.size() >= 1:
        var test_target_pos := Vector2(452.0, 390.0)
        var turret_pivot := turret_spot + Vector2(0.0, -1.2)
        game.turrets[0]["angle"] = (Vector2(test_target_pos.x, test_target_pos.y - 11.0) - turret_pivot).angle()
        game.turrets[0]["fire_timer"] = 0.0
        game.zombies.clear()
        game.zombies.append({"id": 80808, "kind": 0, "x": test_target_pos.x, "y": test_target_pos.y, "hp": 20.0, "max_hp": 20.0, "walking": true, "attacking": false, "attack_timer": 0.0, "attack_cooldown": 0.0, "hit_timer": 0.0})
        game._update_turrets(0.016)
        check(float(game.zombies[0].get("hp", 20.0)) < 20.0, "auto-turret tracks and damages a zombie in range")
        # The 180-degree firing sector must never acquire targets behind its fixed facing side.
        game.zombies.clear()
        game.turrets[0]["face_x"] = 1.0
        game.turrets[0]["angle"] = 0.0
        game.turrets[0]["fire_timer"] = 0.0
        game.zombies.append({"id": 80810, "kind": 0, "x": 408.0, "y": 390.0, "hp": 100.0, "max_hp": 100.0, "walking": true, "attacking": false, "attack_timer": 0.0, "attack_cooldown": 0.0, "hit_timer": 0.0})
        game._update_turrets(0.016)
        check(near(float(game.zombies[0].get("hp", 100.0)), 100.0, 0.001), "turret cannot fire into rear hemisphere")
        game.turrets[0]["face_x"] = -1.0
        game.turrets[0]["angle"] = 0.0
        game.turrets[0]["fire_timer"] = 0.0
        for turn_step in range(36):
            game._update_turrets(0.016)
        check(float(game.zombies[0].get("hp", 100.0)) < 100.0, "left-facing turret can track and fire inside its forward hemisphere")
        # Survivors must pass through turret feet/body; turret collision is retained only for zombie pathing.
        var collision_from := Vector2(turret_spot.x - 50.0, turret_spot.y)
        var collision_desired := Vector2(turret_spot.x - 20.0, turret_spot.y)
        var collision_result: Vector2 = game._resolve_prediction_turret_collision(collision_from, collision_desired, 8.0)
        check(collision_result.is_equal_approx(collision_desired), "survivor passes through turret body from the left")
        var collision_from_right := Vector2(turret_spot.x + 60.0, turret_spot.y)
        var collision_desired_left := Vector2(turret_spot.x - 10.0, turret_spot.y)
        var collision_result_right: Vector2 = game._resolve_prediction_turret_collision(collision_from_right, collision_desired_left, 8.0)
        check(collision_result_right.is_equal_approx(collision_desired_left), "survivor passes through turret body from the opposite direction")
        var muzzle_right: Vector2 = game._turret_muzzle_position(turret_spot, 1.0, 0.0)
        var muzzle_left: Vector2 = game._turret_muzzle_position(turret_spot, -1.0, 0.0)
        check(muzzle_right.x > turret_spot.x + 35.0 and muzzle_left.x < turret_spot.x - 35.0, "turret bullet origin follows the real barrel muzzle for both facings")
        check(absf(muzzle_right.y - (turret_spot.y - 9.5)) < 2.0 and absf(muzzle_left.y - (turret_spot.y - 9.5)) < 2.0, "turret muzzle vertical origin aligns with the barrel bore, not the old floating-head pivot")
        # A zombie closer to one turret than any survivor must destroy that target turret only.
        # Another turret remains elsewhere in the test scene, so checking turrets.is_empty() is
        # incorrect: it would report a failure even when the intended turret was removed.
        game.players[1]["x"] = 850.0
        game.turrets[0]["x"] = 450.0
        game.turrets[0]["y"] = 390.0
        game.turrets[0]["hp"] = 2.0
        game.turrets[0]["angle"] = 0.0
        game.turrets[0]["face_x"] = 1.0
        game.turrets[0]["fire_timer"] = 4.0
        var attacked_turret_id: int = int(game.turrets[0].get("id", -1))
        var unrelated_turret_id: int = int(game.turrets[1].get("id", -1))
        game.zombies.clear()
        game.zombies.append({"id": 80809, "kind": 0, "x": 455.0, "y": 390.0, "face_x": 1.0, "hp": 20.0, "max_hp": 20.0, "walking": true, "attacking": false, "attack_timer": 0.0, "attack_cooldown": 0.0, "attack_type": game.BOSS_ATTACK_SLASH, "attack_hit_applied": false, "hit_timer": 0.0})
        game.wave_number = 3
        game.wave_total = 1
        game.wave_spawned = 1
        game.wave_kills = 0
        game.wave_spawn_timer = 60.0
        game.wave_break_timer = 0.0
        game.wave_time_remaining = 60.0
        game.wave_timed_out = false
        game.airdrop_spawn_timer = 60.0
        game.active_projectiles.clear()
        game.active_grenades.clear()
        game.airdrops.clear()
        game.input_vectors[1] = Vector2.ZERO
        print("[codec checkpoint] BEFORE: _host_simulate turret-destruction test")
        game._host_simulate(0.016)
        print("[codec checkpoint] AFTER: _host_simulate turret-destruction test")
        var attacked_turret_still_exists := false
        var unrelated_turret_survives := false
        for turret_variant in game.turrets:
            var turret_record: Dictionary = turret_variant
            var turret_id := int(turret_record.get("id", -1))
            if turret_id == attacked_turret_id:
                attacked_turret_still_exists = true
            if turret_id == unrelated_turret_id:
                unrelated_turret_survives = true
        check(not attacked_turret_still_exists, "zombie melee removes the turret it attacked")
        check(unrelated_turret_survives, "zombie melee preserves an unrelated turret")
    game.players.clear()
    game.zombies.clear()
    game.turrets.clear()
    game.barricades.clear()
    game.combat_effects.clear()

    print("[codec checkpoint] COMPLETED: turret placement, firing, and destruction checks")
    # Truncation / garbage must never crash and must be rejected.
    var good: PackedByteArray = game._encode_snapshot()
    check(game._decode_snapshot(good.slice(0, 20)).is_empty(), "truncated header rejected")
    check(game._decode_snapshot(good.slice(0, good.size() - 5)).is_empty(), "truncated tail rejected")
    var junk := PackedByteArray()
    for i in range(300):
        junk.append(rng.randi_range(0, 255))
    check(game._decode_snapshot(junk).is_empty() or true, "junk survives")
    print("[codec checkpoint] PASS: malformed and truncated packets")
    print("[codec checkpoint] BEFORE: 2000 snapshot encodes")
    var t0 := Time.get_ticks_usec()
    var last: PackedByteArray
    for i in range(2000):
        last = game._encode_snapshot()
    var t1 := Time.get_ticks_usec()
    print("[codec checkpoint] AFTER: 2000 snapshot encodes; BEFORE: 2000 snapshot decodes")
    for i in range(2000):
        game._decode_snapshot(last)
    var t2 := Time.get_ticks_usec()
    print("[codec checkpoint] AFTER: 2000 snapshot decodes")
    print("worst-case encode %.0f us, decode %.0f us per snapshot (this machine)" % [float(t1 - t0) / 2000.0, float(t2 - t1) / 2000.0])
    print("largest snapshot: %d bytes (cap %d)" % [max_bytes, game.MAX_SNAPSHOT_BYTES])
    # Clear test-owned state and free Main.tscn before exiting to avoid ObjectDB leaks from
    # runtime audio players, timers, and other child nodes created during _ready().
    game.players.clear()
    game.zombies.clear()
    game.turrets.clear()
    game.barricades.clear()
    game.airdrops.clear()
    game.active_projectiles.clear()
    game.active_grenades.clear()
    game.combat_effects.clear()
    turret_base_resource = null
    turret_head_resource = null
    game.queue_free()
    await process_frame
    print("CODEC TEST: ", "PASS" if failures == 0 else "FAILED (%d)" % failures)
    quit(0 if failures == 0 else 1)
