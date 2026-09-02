class_name BotSkillProfile
extends RefCounted
## Per-bot skill parameters. Tiers shift *distributions*, and each bot samples its own values so
## two Veteran bots don't play identically. All times in seconds, angles in degrees.

var tier: int = 2
var reaction_time: float = 0.28          # from noticing to starting to aim
var reaction_jitter: float = 0.08
var acquisition_time: float = 0.35       # time to settle on a target after reacting
var tracking_noise: float = 1.4          # degrees std of OU process
var tracking_smoothness: float = 8.0     # OU mean reversion rate
var flick_overshoot: float = 0.18        # fraction of the flick distance
var flick_speed: float = 720.0           # deg/s
var recoil_compensation: float = 0.65    # 0..1 how well recoil is countered
var pressure_penalty: float = 0.5        # aim noise mult increase under fire
var move_penalty: float = 0.35           # aim noise increase while moving fast
var headshot_intent: float = 0.35        # chance to aim for head vs center mass
var target_switch_delay: float = 0.4
var awareness: float = 0.6               # perception: peripheral notice chance per second
var hearing: float = 0.7                 # audio sensitivity
var memory_seconds: float = 6.0
var cooldown_discipline: float = 0.7     # chance to use an ability at the "right" time vs. late/early
var ult_discipline: float = 0.7
var overextend_bias: float = 0.3         # tendency to chase on a kill streak
var panic_threshold: float = 0.3         # hp fraction where panic behaviors start
var panic_chance: float = 0.4
var tunnel_vision: float = 0.3           # chance to ignore a new threat while focused
var positioning_iq: float = 0.6          # cover / high ground usage
var strafe_rhythm: float = 0.6           # 0 = predictable, 1 = varied
var patience: float = 0.5                # willingness to wait for team
var mistake_rate: float = 0.25           # global "human error" scale


static func for_tier(t: int, rng: RandomNumberGenerator) -> BotSkillProfile:
	var s := BotSkillProfile.new()
	s.tier = t
	var v := func(lo: float, hi: float) -> float: return rng.randf_range(lo, hi)
	match t:
		0:  # Recruit
			s.reaction_time = v.call(0.42, 0.6); s.reaction_jitter = 0.15
			s.acquisition_time = v.call(0.5, 0.8)
			s.tracking_noise = v.call(2.6, 3.8); s.tracking_smoothness = 5.0
			s.flick_overshoot = v.call(0.3, 0.45); s.flick_speed = 360.0
			s.recoil_compensation = v.call(0.2, 0.4)
			s.pressure_penalty = 0.9; s.move_penalty = 0.6
			s.headshot_intent = 0.1
			s.target_switch_delay = 0.9
			s.awareness = v.call(0.3, 0.45); s.hearing = 0.4; s.memory_seconds = 4.0
			s.cooldown_discipline = 0.35; s.ult_discipline = 0.35
			s.overextend_bias = 0.5; s.panic_threshold = 0.45; s.panic_chance = 0.7
			s.tunnel_vision = 0.6; s.positioning_iq = 0.3; s.strafe_rhythm = 0.3; s.patience = 0.3; s.mistake_rate = 0.5
		1:  # Regular
			s.reaction_time = v.call(0.3, 0.42); s.reaction_jitter = 0.1
			s.acquisition_time = v.call(0.35, 0.55)
			s.tracking_noise = v.call(1.8, 2.6); s.tracking_smoothness = 7.0
			s.flick_overshoot = v.call(0.2, 0.32); s.flick_speed = 520.0
			s.recoil_compensation = v.call(0.4, 0.6)
			s.pressure_penalty = 0.7; s.move_penalty = 0.45
			s.headshot_intent = 0.25
			s.target_switch_delay = 0.6
			s.awareness = v.call(0.45, 0.6); s.hearing = 0.6; s.memory_seconds = 5.0
			s.cooldown_discipline = 0.55; s.ult_discipline = 0.55
			s.overextend_bias = 0.4; s.panic_threshold = 0.35; s.panic_chance = 0.5
			s.tunnel_vision = 0.45; s.positioning_iq = 0.5; s.strafe_rhythm = 0.5; s.patience = 0.45; s.mistake_rate = 0.35
		2:  # Veteran
			s.reaction_time = v.call(0.22, 0.32); s.reaction_jitter = 0.07
			s.acquisition_time = v.call(0.25, 0.4)
			s.tracking_noise = v.call(1.1, 1.8); s.tracking_smoothness = 9.0
			s.flick_overshoot = v.call(0.12, 0.22); s.flick_speed = 700.0
			s.recoil_compensation = v.call(0.6, 0.78)
			s.pressure_penalty = 0.5; s.move_penalty = 0.35
			s.headshot_intent = 0.4
			s.target_switch_delay = 0.4
			s.awareness = v.call(0.6, 0.75); s.hearing = 0.75; s.memory_seconds = 6.5
			s.cooldown_discipline = 0.72; s.ult_discipline = 0.72
			s.overextend_bias = 0.3; s.panic_threshold = 0.28; s.panic_chance = 0.35
			s.tunnel_vision = 0.3; s.positioning_iq = 0.68; s.strafe_rhythm = 0.65; s.patience = 0.6; s.mistake_rate = 0.22
		_:  # Elite
			s.reaction_time = v.call(0.17, 0.24); s.reaction_jitter = 0.05
			s.acquisition_time = v.call(0.18, 0.28)
			s.tracking_noise = v.call(0.7, 1.2); s.tracking_smoothness = 12.0
			s.flick_overshoot = v.call(0.06, 0.14); s.flick_speed = 900.0
			s.recoil_compensation = v.call(0.78, 0.9)
			s.pressure_penalty = 0.35; s.move_penalty = 0.25
			s.headshot_intent = 0.55
			s.target_switch_delay = 0.25
			s.awareness = v.call(0.75, 0.9); s.hearing = 0.9; s.memory_seconds = 8.0
			s.cooldown_discipline = 0.88; s.ult_discipline = 0.88
			s.overextend_bias = 0.2; s.panic_threshold = 0.2; s.panic_chance = 0.2
			s.tunnel_vision = 0.18; s.positioning_iq = 0.85; s.strafe_rhythm = 0.85; s.patience = 0.75; s.mistake_rate = 0.12
	return s
