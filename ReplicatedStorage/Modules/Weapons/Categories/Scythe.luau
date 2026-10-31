--// Modules \\--

local Combo = require(script.Parent.Parent:WaitForChild("Combo"))

--// Variables \\--

local HIT_LEAD = 0.05
local TRAIL_LEAD = 0.35
local TRAIL_TAIL = 0.15
local SWING_SOUND_LEAD = 0.22
local MIN_ACTION_PADDING = 0.1
local MIN_COOLDOWN_RATIO = 0.9
local SWING_WALK_SPEED = 6

local SWING_SOUNDS = table.freeze({"Swing"})
local HIT_SOUNDS = table.freeze({"Hit"})

local LIGHT_KNOCKBACK = table.freeze({Force = 14; Duration = 0.15; Lift = 0})
local FINISHER_KNOCKBACK = table.freeze({Force = 95; Duration = 0.3; Lift = 14})

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
		Impact = 0.47; Length = 0.65; Speed = 1; Damage = 12; Stun = 0.55; Recovery = 0.15;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.25; Victim = 0.3; Duration = 0.2});
		HitStop = 0.07;
	});
	buildHit({
		Impact = 0.43; Length = 0.65; Speed = 1; Damage = 13; Stun = 0.55; Recovery = 0.15;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.28; Victim = 0.32; Duration = 0.2});
		HitStop = 0.07;
	});
	buildHit({
		Impact = 0.47; Length = 0.65; Speed = 1; Damage = 14; Stun = 0.6; Recovery = 0.18;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.3; Victim = 0.35; Duration = 0.22});
		HitStop = 0.08;
	});
	buildHit({
		Impact = 0.45; Length = 0.75; Speed = 1; Damage = 28; Stun = 1.3; Recovery = 0.6;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Finisher";
		Knockback = FINISHER_KNOCKBACK;
		Shake = table.freeze({Attacker = 1; Victim = 1.2; Duration = 0.4});
		HitStop = 0.14;
		FovKick = 7;
		Shockwave = true;
	});
})

--// Category \\--

return table.freeze({
	AttackName = "Reap";
	AllowUpperCut = true;
	Interruptible = true;
	MaxCombo = 4;
	ComboWindow = 2;
	EffectFolder = "GreatSword";
	AnchorName = "RightGrip";
	SwingPriority = Enum.AnimationPriority.Action2;

	Combo = combo;
})
