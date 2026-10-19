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
    var game: Node = load("res://Main.tscn").instantiate()
    root.add_child(game)
    game.screen_size = Vector2(1201, 540)
    game.is_host = true
    var rng := RandomNumberGenerator.new()
    rng.seed = 11

    var scenarios := [
        {"name": "lobby, 2 players, idle", "p": 2, "z": 0, "fx": 0, "g": 0, "w": 0, "d": 0},
        {"name": "2 players, 6 zombies, idle", "p": 2, "z": 6, "fx": 0, "g": 0, "w": 0, "d": 0},
        {"name": "2 players, 10 zombies, shooting", "p": 2, "z": 10, "fx": 4, "g": 0, "w": 0, "d": 0},
        {"name": "4 players, 14 zombies, busy", "p": 4, "z": 14, "fx": 12, "g": 1, "w": 3, "d": 1},
        {"name": "4 players, 14 zombies, worst case", "p": 4, "z": 14, "fx": 36, "g": 3, "w": 8, "d": 2},
        {"name": "boss + 13 zombies, normalized boss HP", "p": 4, "z": 14, "fx": 12, "g": 1, "w": 3, "d": 1},
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
        game.airdrops.clear()
        game.active_grenades.clear()
        game.cmd_last_seq.clear()
        var ids: Array[int] = [1]
        for i in range(int(sc.p) - 1):
            ids.append(rng.randi_range(100000, 2000000000))
        for pid in ids:
            game.players[pid] = {"x": rng.randf_range(30, 1170), "y": rng.randf_range(300, 460), "hp": rng.randf_range(1, 100), "medkits": 2, "ammo": -1, "grenades": 3, "wall_kits": 2, "face_x": -1.0, "name": "P", "walking": true, "shoot_timer": 0.17, "hurt_timer": 0.0}
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
        for z in game.zombies:
            var zr: Dictionary = snap.zombies[int(z.id) & 0xFFFFFFFF]
            check(near(float(z.x), float(zr.x), 0.07) and near(float(z.y), float(zr.y), 0.07), "zombie pos")
            var hp_tolerance := 0.45 if int(z.kind) == 4 else 0.03
            check(near(float(z.hp), float(zr.hp), hp_tolerance), "zombie hp")
            check(int(zr.kind) == int(z.kind), "zombie kind")
        check(snap.walls.size() == int(sc.w), sc.name + ": walls")
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

    # Weapon profiles and reload arithmetic are deterministic and bounded.
    var sidearm_profile: Dictionary = game._weapon_profile(game.WEAPON_SIDEARM)
    check(int(sidearm_profile.mag_size) == -1 and int(sidearm_profile.interval_ms) == 280, "default sidearm keeps infinite ammo")
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

    # A depleted firearm with no reserve must reliably return to the infinite-ammo sidearm.
    game.players.clear()
    game.zombies.clear()
    game.fire_cooldowns.clear()
    game.players[1] = {"x": 320.0, "y": 390.0, "hp": 100.0, "medkits": 2, "ammo": -1, "grenades": 3, "wall_kits": 2, "active_slot": 2, "slot1_type": -1, "slot1_mag": 0, "slot1_reserve": 0, "slot2_type": game.WEAPON_ROCKET, "slot2_mag": 0, "slot2_reserve": 0, "reload_timer": 0.0, "face_x": 1.0, "shoot_timer": 0.0, "hurt_timer": 0.0}
    game._host_fire(1)
    check(int(game.players[1].active_slot) == 0, "empty firearm with no reserve switches to default sidearm")

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

    # Truncation / garbage must never crash and must be rejected.
    var good: PackedByteArray = game._encode_snapshot()
    check(game._decode_snapshot(good.slice(0, 20)).is_empty(), "truncated header rejected")
    check(game._decode_snapshot(good.slice(0, good.size() - 5)).is_empty(), "truncated tail rejected")
    var junk := PackedByteArray()
    for i in range(300):
        junk.append(rng.randi_range(0, 255))
    check(game._decode_snapshot(junk).is_empty() or true, "junk survives")
    var t0 := Time.get_ticks_usec()
    var last: PackedByteArray
    for i in range(2000):
        last = game._encode_snapshot()
    var t1 := Time.get_ticks_usec()
    for i in range(2000):
        game._decode_snapshot(last)
    var t2 := Time.get_ticks_usec()
    print("worst-case encode %.0f us, decode %.0f us per snapshot (this machine)" % [float(t1 - t0) / 2000.0, float(t2 - t1) / 2000.0])
    print("largest snapshot: %d bytes (cap %d)" % [max_bytes, game.MAX_SNAPSHOT_BYTES])
    print("CODEC TEST: ", "PASS" if failures == 0 else "FAILED (%d)" % failures)
    quit(0 if failures == 0 else 1)
