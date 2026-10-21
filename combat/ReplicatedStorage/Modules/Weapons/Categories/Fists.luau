--// Modules \\--

local Moves = require(script.Parent.Parent.Parent:WaitForChild("Moves"))

--// Variables \\--

local CombatInfo = Moves.Combat
local MaxCombo = CombatInfo.MaxCombo

local combo = {}

--// Combo \\--

for count = 1, MaxCombo do
	local isFinisher = count == MaxCombo
	local knockback = nil

	if isFinisher then
		knockback = table.freeze({
			Force = CombatInfo.Punch.FinisherKnockback;
			Duration = CombatInfo.Punch.FinisherKnockbackDuration;
			Lift = 0;
		})
	end

	combo[count] = table.freeze({
		Damage = CombatInfo.Punch.Damage;
		Stun = CombatInfo.Punch.Stun;
		Speed = 1;
		HitboxDelay = CombatInfo.HitboxDelay;
		ImpactTime = CombatInfo.HitboxDelay;
		ActionTime = 0.6;
		Cooldown = if isFinisher then CombatInfo.FinisherCooldown else CombatInfo.PunchCooldown;
		SwingSounds = table.freeze({"Swing"});
		SwingSoundTime = 0;
		HitSounds = table.freeze({"Hit"});
		HitEffect = if isFinisher then "Finisher" else "Hit";
		Knockback = knockback;
	})
end

--// Category \\--

return table.freeze({
	AttackName = "Punch";
	AllowUpperCut = true;
	Interruptible = false;
	MaxCombo = MaxCombo;
	ComboWindow = CombatInfo.ComboWindow;
	EffectFolder = "Fists";

	Hitbox = table.freeze({
		Offset = CombatInfo.HitboxOffset;
		Size = Vector3.new(CombatInfo.HitboxSize, CombatInfo.HitboxSize, CombatInfo.HitboxSize);
	});

	Combo = table.freeze(combo);
})
