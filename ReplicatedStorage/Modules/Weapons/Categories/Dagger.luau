--// Modules \\--

local Combo = require(script.Parent.Parent:WaitForChild("Combo"))

--// Variables \\--

local HIT_LEAD = 0.04
local TRAIL_LEAD = 0.2
local TRAIL_TAIL = 0.1
local SWING_SOUND_LEAD = 0.15
local MIN_ACTION_PADDING = 0.1
local MIN_COOLDOWN_RATIO = 0.9
local SWING_WALK_SPEED = 8

local SWING_SOUNDS = table.freeze({"Swing"})
local HIT_SOUNDS = table.freeze({"Hit"})

local LIGHT_KNOCKBACK = table.freeze({Force = 9; Duration = 0.15; Lift = 0})
local FINISHER_KNOCKBACK = table.freeze({Force = 70; Duration = 0.3; Lift = 10})

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
		Impact = 0.22; Length = 0.53; Speed = 1; Damage = 6; Stun = 0.4; Recovery = 0.08;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.15; Victim = 0.2; Duration = 0.14});
		HitStop = 0.04;
	});
	buildHit({
		Impact = 0.2; Length = 0.53; Speed = 1; Damage = 7; Stun = 0.4; Recovery = 0.08;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.15; Victim = 0.2; Duration = 0.14});
		HitStop = 0.04;
	});
	buildHit({
		Impact = 0.18; Length = 0.53; Speed = 1; Damage = 8; Stun = 0.45; Recovery = 0.1;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.18; Victim = 0.24; Duration = 0.15});
		HitStop = 0.05;
	});
	buildHit({
		Impact = 0.32; Length = 0.58; Speed = 1; Damage = 16; Stun = 1; Recovery = 0.45;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Finisher";
		Knockback = FINISHER_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.7; Victim = 0.9; Duration = 0.3});
		HitStop = 0.1;
		FovKick = 5;
		Shockwave = true;
	});
})

--// Category \\--

return table.freeze({
	AttackName = "Stab";
	AllowUpperCut = true;
	Interruptible = true;
	MaxCombo = 4;
	ComboWindow = 2;
	EffectFolder = "GreatSword";
	AnchorName = "RightGrip";
	SwingPriority = Enum.AnimationPriority.Action2;

	Moves = table.freeze({"DaggerDance"});

	Combo = combo;
})
