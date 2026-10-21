--// Modules \\--

local Combo = require(script.Parent.Parent:WaitForChild("Combo"))

--// Variables \\--

local HIT_LEAD = 0.05
local TRAIL_LEAD = 0.3
local TRAIL_TAIL = 0.12
local SWING_SOUND_LEAD = 0.2
local MIN_ACTION_PADDING = 0.1
local MIN_COOLDOWN_RATIO = 0.9
local SWING_WALK_SPEED = 7

local SWING_SOUNDS = table.freeze({"Swing"})
local HIT_SOUNDS = table.freeze({"Hit"})

local LIGHT_KNOCKBACK = table.freeze({Force = 12; Duration = 0.15; Lift = 0})
local FINISHER_KNOCKBACK = table.freeze({Force = 80; Duration = 0.3; Lift = 12})

--// Combo \\--

local buildHit = Combo.CreateBuilder(table.freeze({
	HitLead = HIT_LEAD;
	TrailLead = TRAIL_LEAD;
	TrailTail = TRAIL_TAIL;
	SwingSoundLead = SWING_SOUND_LEAD;
	WalkSpeed = SWING_WALK_SPEED;
	MinActionPadding = MIN_ACTION_PADDING;
	MinCooldownRatio = MIN_COOLDOWN_RATIO;
}))

local combo = table.freeze({
	buildHit({
		Impact = 0.43; Length = 0.65; Speed = 1; Damage = 9; Stun = 0.45; Recovery = 0.1;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.2; Victim = 0.26; Duration = 0.18});
		HitStop = 0.05;
	});
	buildHit({
		Impact = 0.42; Length = 0.65; Speed = 1; Damage = 10; Stun = 0.5; Recovery = 0.1;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.22; Victim = 0.28; Duration = 0.18});
		HitStop = 0.06;
	});
	buildHit({
		Impact = 0.4; Length = 0.65; Speed = 1; Damage = 11; Stun = 0.5; Recovery = 0.12;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.25; Victim = 0.3; Duration = 0.2});
		HitStop = 0.06;
	});
	buildHit({
		Impact = 0.4; Length = 0.65; Speed = 1; Damage = 22; Stun = 1.1; Recovery = 0.55;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Finisher";
		Knockback = FINISHER_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.9; Victim = 1.1; Duration = 0.38});
		HitStop = 0.12;
		FovKick = 6;
		Shockwave = true;
	});
})

--// Category \\--

return table.freeze({
	AttackName = "Slash";
	AllowUpperCut = true;
	Interruptible = true;
	MaxCombo = 4;
	ComboWindow = 2;
	EffectFolder = "GreatSword";
	AnchorName = "RightGrip";
	SwingPriority = Enum.AnimationPriority.Action2;


	Combo = combo;
})
