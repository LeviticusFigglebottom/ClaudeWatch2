class_name HeroPicker
## Team-composition-aware hero selection for bots.

## Multipliers on a hero's draw weight, applied once per matching teammate or enemy. A hero with
## three synergies is roughly six times as likely as an unrelated one, which reads as a team that
## drafts around its picks without every match producing the same five heroes.
const SYNERGY_WEIGHT := 1.8
const COUNTER_WEIGHT := 1.45

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
	# Weighted choice, not argmax. Synergy and counters bias the draw; they no longer decide it.
	#
	# The old scoring added a flat bonus per synergy against a small random term, so once the first
	# hero on a team was locked the rest of the comp followed almost deterministically: across 160
	# measured matches Cairn played alongside Lumen in 96% of its games, Kiln drew Suture in 82% and
	# Ballast drew Cadence in 73%. That made per-hero win rate useless as a balance signal, because
	# it measured the comp the picker always built rather than the hero, and it left Rook picked 7
	# times in 56 matches. Real teams do not converge on one optimal comp every game either.
	var enemy_team := RF.enemy_team(team)
	var enemy_heroes: Array[StringName] = []
	for other: PlayerState in server.team_players(enemy_team):
		if other.hero_id != &"": enemy_heroes.append(other.hero_id)
	var weights: Array[float] = []
	var total := 0.0
	for h: HeroData in candidates:
		var w := 1.0
		for t: StringName in taken:
			if h.synergies.has(t): w *= SYNERGY_WEIGHT
		for e: StringName in enemy_heroes:
			if h.counters.has(e): w *= COUNTER_WEIGHT
			if h.countered_by.has(e): w /= COUNTER_WEIGHT
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i].id
	return candidates[candidates.size() - 1].id
