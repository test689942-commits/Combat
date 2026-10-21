--// Modules \\--

local Combo = require(script.Parent.Parent:WaitForChild("Combo"))

--// Variables \\--

local HIT_LEAD = 0.05
local TRAIL_LEAD = 0.25
local TRAIL_TAIL = 0.1
local SWING_SOUND_LEAD = 0.15
local MIN_ACTION_PADDING = 0.1
local MIN_COOLDOWN_RATIO = 0.9
local SWING_WALK_SPEED = 7

local SWING_SOUNDS = table.freeze({"Swing"})
local HIT_SOUNDS = table.freeze({"Hit"})

local LIGHT_KNOCKBACK = table.freeze({Force = 10; Duration = 0.15; Lift = 0})
local FINISHER_KNOCKBACK = table.freeze({Force = 85; Duration = 0.3; Lift = 12})

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
		Impact = 0.33; Length = 0.65; Speed = 1; Damage = 7; Stun = 0.4; Recovery = 0.08;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Lunge = table.freeze({Force = 14; Duration = 0.18; Lead = 0.2});
		Shake = table.freeze({Attacker = 0.15; Victim = 0.2; Duration = 0.14});
		HitStop = 0.04;
	});
	buildHit({
		Impact = 0.23; Length = 0.63; Speed = 1; Damage = 8; Stun = 0.4; Recovery = 0.08;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Lunge = table.freeze({Force = 14; Duration = 0.18; Lead = 0.184});
		Shake = table.freeze({Attacker = 0.17; Victim = 0.22; Duration = 0.14});
		HitStop = 0.04;
	});
	buildHit({
		Impact = 0.15; Length = 0.48; Speed = 1; Damage = 8; Stun = 0.4; Recovery = 0.08;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Lunge = table.freeze({Force = 14; Duration = 0.18; Lead = 0.12});
		Shake = table.freeze({Attacker = 0.17; Victim = 0.22; Duration = 0.14});
		HitStop = 0.04;
	});
	buildHit({
		Impact = 0.32; Length = 0.65; Speed = 1; Damage = 9; Stun = 0.45; Recovery = 0.12;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Hit";
		Knockback = LIGHT_KNOCKBACK;
		Lunge = table.freeze({Force = 16; Duration = 0.18; Lead = 0.22});
		Shake = table.freeze({Attacker = 0.2; Victim = 0.26; Duration = 0.16});
		HitStop = 0.05;
	});
	buildHit({
		Impact = 0.22; Length = 0.97; Speed = 1; Damage = 22; Stun = 1.2; Recovery = 0.6;
		SwingSounds = SWING_SOUNDS; HitSounds = HIT_SOUNDS; HitEffect = "Finisher";
		Knockback = FINISHER_KNOCKBACK;
		Lunge = table.freeze({Force = 30; Duration = 0.24; Lead = 0.176});
		Shake = table.freeze({Attacker = 0.9; Victim = 1.1; Duration = 0.4});
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
	MaxCombo = 5;
	ComboWindow = 2;
	EffectFolder = "GreatSword";
	SwingPriority = Enum.AnimationPriority.Action2;


	Combo = combo;
})
