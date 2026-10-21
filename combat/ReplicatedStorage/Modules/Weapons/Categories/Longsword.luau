--// Modules \--

local Combo = require(script.Parent.Parent:WaitForChild("Combo"))

--// Variables \\--

local HIT_LEAD = 0.05
local TRAIL_LEAD = 0.3
local TRAIL_TAIL = 0.15
local SWING_SOUND_LEAD = 0.2
local MIN_ACTION_PADDING = 0.1
local SWING_WALK_SPEED = 7

local SWING_SOUNDS = table.freeze({"Swing"})
local HIT_SOUNDS = table.freeze({"Hit"})

local LIGHT_KNOCKBACK = table.freeze({Force = 13; Duration = 0.15; Lift = 0})
local FINISHER_KNOCKBACK = table.freeze({Force = 90; Duration = 0.3; Lift = 13})

--// Combo \\--

local buildHit = Combo.CreateBuilder(table.freeze({
	HitLead = HIT_LEAD;
	TrailLead = TRAIL_LEAD;
	TrailTail = TRAIL_TAIL;
	SwingSoundLead = SWING_SOUND_LEAD;
	WalkSpeed = SWING_WALK_SPEED;
	MinActionPadding = MIN_ACTION_PADDING;
}))

local combo = table.freeze({
	buildHit({
		Impact = 0.5; Length = 0.7; Speed = 1; Damage = 10; Stun = 0.5; Recovery = 0.15;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.22; Victim = 0.28; Duration = 0.18});
		HitStop = 0.06;
	});
	buildHit({
		Impact = 0.5; Length = 0.7; Speed = 1; Damage = 11; Stun = 0.5; Recovery = 0.15;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.25; Victim = 0.3; Duration = 0.18});
		HitStop = 0.06;
	});
	buildHit({
		Impact = 0.5; Length = 0.7; Speed = 1; Damage = 12; Stun = 0.55; Recovery = 0.15;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.28; Victim = 0.32; Duration = 0.2});
		HitStop = 0.07;
	});
	buildHit({
		Impact = 0.5; Length = 0.7; Speed = 1; Damage = 13; Stun = 0.6; Recovery = 0.18;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.32; Victim = 0.36; Duration = 0.2});
		HitStop = 0.07;
	});
	buildHit({
		Impact = 0.5; Length = 0.7; Speed = 0.95; Damage = 23; Stun = 1.25; Recovery = 0.65;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Finisher";
		Knockback = FINISHER_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.95; Victim = 1.15; Duration = 0.4});
		HitStop = 0.13;
		FovKick = 6;
		Shockwave = true;
	});
})

--// Category \\--

return table.freeze({
	AttackName = "Slash";
	AllowUpperCut = true;
	Interruptible = true;
	MaxCombo = 5;
	ComboWindow = 2;
	EffectFolder = "GreatSword";
	SwingPriority = Enum.AnimationPriority.Action2;

	Combo = combo;
})
