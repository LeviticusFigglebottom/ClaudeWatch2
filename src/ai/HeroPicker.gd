class_name HeroPicker
## Team-composition-aware hero selection for bots.

static func pick(server: GameServer, team: int, ps: PlayerState, rng: RandomNumberGenerator) -> StringName:
	var taken: Array[StringName] = []
	var role_counts := [0, 0, 0]
	for other: PlayerState in server.team_players(team):
		if other != ps and other.hero_id != &"":
			taken.append(other.hero_id)
			var h := Registry.hero(other.hero_id)
			if h: role_counts[h.role] += 1
	# Which roles still have room (1/2/2)?
	var open_roles: Array[int] = []
	for r in 3:
		if role_counts[r] < RF.ROLE_LIMIT[r]:
			open_roles.append(r)
	if open_roles.is_empty():
		open_roles = [RF.Role.STRIKER]
	# Priority: a bulwark first, then conduits, then strikers (teams without sustain lose).
	var role := open_roles[0]
	if open_roles.has(RF.Role.BULWARK): role = RF.Role.BULWARK
	elif open_roles.has(RF.Role.CONDUIT) and role_counts[RF.Role.CONDUIT] < role_counts[RF.Role.STRIKER]: role = RF.Role.CONDUIT
	elif open_roles.has(RF.Role.STRIKER): role = RF.Role.STRIKER
	var candidates: Array[HeroData] = []
	for h: HeroData in Registry.heroes_by_role(role):
		if not taken.has(h.id) or server.config.allow_hero_duplicates:
			candidates.append(h)
	if candidates.is_empty():
		for h: HeroData in Registry.heroes.values():
			if not taken.has(h.id): candidates.append(h)
	if candidates.is_empty():
		return Registry.hero_ids()[0]
	# Score: synergy with teammates, counter to enemy comp, small random.
	var enemy_team := RF.enemy_team(team)
	var enemy_heroes: Array[StringName] = []
	for other: PlayerState in server.team_players(enemy_team):
		if other.hero_id != &"": enemy_heroes.append(other.hero_id)
	var best: HeroData = null
	var best_score := -INF
	for h: HeroData in candidates:
		var s := rng.randf() * 1.5
		for t: StringName in taken:
			if h.synergies.has(t): s += 1.0
		for e: StringName in enemy_heroes:
			if h.counters.has(e): s += 0.8
			if h.countered_by.has(e): s -= 0.6
		if s > best_score:
			best_score = s; best = h
	return best.id
