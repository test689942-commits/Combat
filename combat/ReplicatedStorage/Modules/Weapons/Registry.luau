--// Modules \\--

local Combo = require(script.Parent:WaitForChild("Combo"))

--// Grips \\--

local RIGHT_HAND_C0 = CFrame.new(-0.230697632, -1.13454056, 0.00231933594)
local LEFT_HAND_C0 = CFrame.new(0.230697632, -1.13454056, 0.00231933594)
local NO_OFFSET = CFrame.new()

local DUAL_BLADE_GRIPS = table.freeze({
	table.freeze({GripPart = "Right Arm"; AnchorName = "RightGrip"; JointName = "Handle"; HandleName = "HandleR"; PartName = "Handle"; GripC0 = RIGHT_HAND_C0; GripC1 = NO_OFFSET});
	table.freeze({GripPart = "Left Arm"; AnchorName = "LeftGrip"; JointName = "Handle"; HandleName = "HandleL"; PartName = "Handle"; GripC0 = LEFT_HAND_C0; GripC1 = NO_OFFSET});
})

--// DragonSlayer Combo (4 Swings, No Critical) \\--

local DRAGON_SLAYER_SWING_SOUNDS = table.freeze({"Swing"})
local DRAGON_SLAYER_HIT_SOUNDS = table.freeze({"Hit"})
local DRAGON_SLAYER_LIGHT_KNOCKBACK = table.freeze({Force = 14; Duration = 0.15; Lift = 0})
local DRAGON_SLAYER_FINISHER_KNOCKBACK = table.freeze({Force = 95; Duration = 0.3; Lift = 14})

local buildDragonSlayerHit = Combo.CreateBuilder(table.freeze({
	HitLead = 0.05;
	TrailLead = 0.35;
	TrailTail = 0.15;
	SwingSoundLead = 0.22;
	WalkSpeed = 6;
	ActionPadding = 0.3;
}))

local DRAGON_SLAYER_COMBO = table.freeze({
	buildDragonSlayerHit({
		Impact = 0.55; Speed = 1; Damage = 12; Stun = 0.6; Recovery = 0.25;
		SwingSounds = DRAGON_SLAYER_SWING_SOUNDS; HitSounds = DRAGON_SLAYER_HIT_SOUNDS; HitEffect = "Hit";
		Knockback = DRAGON_SLAYER_LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.28; Victim = 0.32; Duration = 0.2});
		HitStop = 0.07;
	});
	buildDragonSlayerHit({
		Impact = 0.75; Speed = 1; Damage = 13; Stun = 0.6; Recovery = 0.25;
		SwingSounds = DRAGON_SLAYER_SWING_SOUNDS; HitSounds = DRAGON_SLAYER_HIT_SOUNDS; HitEffect = "Hit";
		Knockback = DRAGON_SLAYER_LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.3; Victim = 0.35; Duration = 0.22});
		HitStop = 0.08;
	});
	buildDragonSlayerHit({
		Impact = 0.85; Speed = 1; Damage = 15; Stun = 0.65; Recovery = 0.3;
		SwingSounds = DRAGON_SLAYER_SWING_SOUNDS; HitSounds = DRAGON_SLAYER_HIT_SOUNDS; HitEffect = "Hit";
		Knockback = DRAGON_SLAYER_LIGHT_KNOCKBACK;
		Shake = table.freeze({Attacker = 0.35; Victim = 0.4; Duration = 0.24});
		HitStop = 0.08;
	});
	buildDragonSlayerHit({
		Impact = 0.85; Speed = 1; Damage = 24; Stun = 1.3; Recovery = 0.75;
		SwingSounds = DRAGON_SLAYER_SWING_SOUNDS; HitSounds = DRAGON_SLAYER_HIT_SOUNDS; HitEffect = "Finisher";
		Knockback = DRAGON_SLAYER_FINISHER_KNOCKBACK;
		Shake = table.freeze({Attacker = 1; Victim = 1.2; Duration = 0.4});
		HitStop = 0.14;
		FovKick = 7;
		Shockwave = true;
	});
})

--// Registry \\--

return table.freeze({
	GreatSword = table.freeze({
		Category = "Greatsword";
		DisplayName = "Great Sword";
		Order = 1;
		Model = "GreatSword";
		GripPart = "Right Arm";
		JointName = "Handle";
		GripC0 = CFrame.new(-0.230697632, -1.13454056, 0.00231933594);
		GripC1 = CFrame.new();
		Hitbox = table.freeze({Offset = 5; Size = Vector3.new(10, 6, 10)});
		RageStats = table.freeze({Attribute = "Rage"; DamageMultiplier = 1.5; SpeedMultiplier = 1.25});
		RageIdleAnimation = "DSIdle";
		Moves = table.freeze({"Rage", "Leap"});
		SlashEffects = table.freeze({"M1", "M2", "M3", "M4", "Crit_Slash"});
		CritSlashEffect = "Crit_Slash";
		SlashEvents = true;
	});

	DragonSlayer = table.freeze({
		Category = "Greatsword";
		DisplayName = "Dragon Slayer";
		Order = 2;
		Model = "DragonSlayer";
		GripPart = "Right Arm";
		JointName = "Handle";
		GripC0 = CFrame.new(-0.230697632, -1.13454056, 0.00231933594);
		GripC1 = CFrame.new();
		Hitbox = table.freeze({Offset = 5.5; Size = Vector3.new(10, 6, 11)});
		MaxCombo = 4;
		NoCritical = true;
		SwingPriority = Enum.AnimationPriority.Action4;
		Combo = DRAGON_SLAYER_COMBO;
		SlashEffects = table.freeze({
			"M1Swing",
			"M1Floor",
			"M2Swing",
			"M2Floor",
			"M3Swing",
			"M3Slam",
			"M3Floor",
			"M4Swing",
		});
		SlashMarkers = table.freeze({
			"M1Swing",
			"M1Floor",
			"M2Swing",
			"M2Floor",
			"M3Swing",
			"M3Slam",
			"M3Floor",
			"M4Swing",
		});
		SlashEvents = true;
	});

	Fists = table.freeze({
		Category = "Fists";
		DisplayName = "Fists";
		Order = 3;
		Moves = table.freeze({"GroundSlam", "FistBarrage", "DropKick"});
	});

	Staff = table.freeze({
		Category = "Staff";
		DisplayName = "Staff";
		Order = 4;
		Model = "BlueStaff";
		GripPart = "Right Arm";
		JointName = "Handle";
		GripC0 = CFrame.new(0.040802002, -1.06903172, 0.0548744202) * CFrame.Angles(0, 0, math.pi);
		GripC1 = CFrame.Angles(0, 0, math.pi);
		Hitbox = table.freeze({Offset = 5; Size = Vector3.new(9, 6, 9)});
	});

	LongSword = table.freeze({
		Category = "Longsword";
		DisplayName = "Long Sword";
		Order = 5;
		Model = "Long sword";
		GripPart = "Right Arm";
		JointName = "Handle";
		GripC0 = CFrame.new(-0.230697632, -1.13454056, 0.00231933594) * CFrame.Angles(0, math.pi, 0);
		GripC1 = CFrame.new();
		Hitbox = table.freeze({Offset = 5; Size = Vector3.new(9, 6, 9)});
		SlashEffects = table.freeze({"2slash", "2slash", "2slash", "2slash", "2slash"});
	});

	Axe = table.freeze({
		Category = "Axe";
		DisplayName = "Axe";
		Order = 6;
		Model = "Axe";
		GripPart = "Right Arm";
		JointName = "Handle";
		GripC0 = CFrame.new(0.0623931885, 0.958690643, 0.037612915);
		GripC1 = CFrame.new(0, 1.99999738, 0);
		Hitbox = table.freeze({Offset = 5; Size = Vector3.new(9, 6, 9)});
	});

	["Mortal Blade"] = table.freeze({
		Category = "Katana";
		DisplayName = "Mortal Blade";
		Order = 7;
		Model = "Mortal Blade";
		Range = 8.25;
		SlashEffects = table.freeze({"1slash", "1slash", "1slash", "1slash", "1slash"});
	});

	["Dual KT"] = table.freeze({
		Category = "DualKatana";
		DisplayName = "Dual Katana";
		Order = 8;
		Model = "Dual KT";
		Range = 8;
		Grips = DUAL_BLADE_GRIPS;
	});

	["Steel Dagger"] = table.freeze({
		Category = "Dagger";
		DisplayName = "Steel Dagger";
		Order = 9;
		Model = "Steel Dagger";
		Range = 5;
		Moves = table.freeze({"Cut", "DaggerThrow", "DaggerDance"});
		SlashEffects = table.freeze({"Dagger M1", "Dagger M2", "Dagger M3"});
		SlashMarkers = table.freeze({"Dagger M1", "Dagger M2", "Dagger M3"});
		SlashEvents = true;
	});

	["Steel Spear"] = table.freeze({
		Category = "Spear";
		DisplayName = "Steel Spear";
		Order = 10;
		Model = "Steel Spear";
		Range = 9;
	});

	["Steel Scythe"] = table.freeze({
		Category = "Scythe";
		DisplayName = "Steel Scythe";
		Order = 11;
		Model = "Steel Scythe";
		Range = 8.25;
	});
})
