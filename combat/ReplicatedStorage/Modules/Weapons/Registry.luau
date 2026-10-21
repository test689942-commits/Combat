--// Grips \\--

local RIGHT_HAND_C0 = CFrame.new(-0.230697632, -1.13454056, 0.00231933594)
local LEFT_HAND_C0 = CFrame.new(0.230697632, -1.13454056, 0.00231933594)
local FIST_C0 = CFrame.new(0, -1, 0)
local NO_OFFSET = CFrame.new()

local DUAL_BLADE_GRIPS = table.freeze({
	table.freeze({GripPart = "Right Arm"; AnchorName = "RightGrip"; JointName = "Handle"; HandleName = "HandleR"; PartName = "Handle"; GripC0 = RIGHT_HAND_C0; GripC1 = NO_OFFSET});
	table.freeze({GripPart = "Left Arm"; AnchorName = "LeftGrip"; JointName = "Handle"; HandleName = "HandleL"; PartName = "Handle"; GripC0 = LEFT_HAND_C0; GripC1 = NO_OFFSET});
})

local GLOVE_GRIPS = table.freeze({
	table.freeze({GripPart = "Right Arm"; JointName = "HandleR"; HandleName = "HandleR"; GripC0 = FIST_C0; GripC1 = NO_OFFSET});
	table.freeze({GripPart = "Left Arm"; JointName = "HandleL"; HandleName = "HandleL"; GripC0 = FIST_C0; GripC1 = NO_OFFSET});
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
		NoLunge = true;
		RageStats = table.freeze({Attribute = "Rage"; DamageMultiplier = 1.5; SpeedMultiplier = 1.25});
		RageIdleAnimation = "DSIdle";
		Moves = table.freeze({"Rage", "Leap"});
		SlashEffects = table.freeze({"M1", "M2", "M3", "M4", "Crit_Slash"});
		CritSlashEffect = "Crit_Slash";
	});

	Fists = table.freeze({
		Category = "Fists";
		DisplayName = "Fists";
		Order = 2;
		Moves = table.freeze({"GroundSlam", "FistBarrage", "DropKick"});
	});

	Staff = table.freeze({
		Category = "Staff";
		DisplayName = "Staff";
		Order = 3;
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
		Order = 4;
		Model = "Long sword";
		GripPart = "Right Arm";
		JointName = "Handle";
		GripC0 = CFrame.new(-0.230697632, -1.13454056, 0.00231933594) * CFrame.Angles(0, math.pi, 0);
		GripC1 = CFrame.new();
		Hitbox = table.freeze({Offset = 5; Size = Vector3.new(9, 6, 9)});
	});

	Axe = table.freeze({
		Category = "Axe";
		DisplayName = "Axe";
		Order = 5;
		Model = "Axe";
		GripPart = "Right Arm";
		JointName = "Handle";
		GripC0 = CFrame.new(0.0623931885, 0.958690643, 0.037612915);
		GripC1 = CFrame.new(0, 1.99999738, 0);
		Hitbox = table.freeze({Offset = 5; Size = Vector3.new(9, 6, 9)});
	});

	["Steel Greatsword"] = table.freeze({Category = "Greatsword"; DisplayName = "Steel Greatsword"; Order = 6; Model = "Steel Greatsword"; Range = 8.25});
	["Nnoitras Blade"] = table.freeze({Category = "Greatsword"; DisplayName = "Nnoitras Blade"; Order = 7; Model = "Nnoitras Blade"; Range = 10});

	["Steel Longsword"] = table.freeze({Category = "Longsword"; DisplayName = "Steel Longsword"; Order = 8; Model = "Steel Longsword"; Range = 7; SlashEffects = table.freeze({"2slash", "2slash", "2slash", "2slash", "2slash"})});
	["Serpent's Fang"] = table.freeze({Category = "Longsword"; DisplayName = "Serpent's Fang"; Order = 9; Model = "Serpent's Fang"; Range = 9});
	["Crescent Blade"] = table.freeze({Category = "Longsword"; DisplayName = "Crescent Blade"; Order = 10; Model = "Crescent Blade"; Range = 9});
	Duskblade = table.freeze({Category = "Longsword"; DisplayName = "Duskblade"; Order = 11; Model = "Duskblade"; Range = 9});
	["Steel Mourn"] = table.freeze({Category = "Longsword"; DisplayName = "Steel Mourn"; Order = 12; Model = "Steel Mourn"; Range = 9});

	["Steel Katana"] = table.freeze({Category = "Katana"; DisplayName = "Steel Katana"; Order = 13; Model = "Steel Katana"; Range = 7.5});
	["Mortal Blade"] = table.freeze({Category = "Katana"; DisplayName = "Mortal Blade"; Order = 14; Model = "Mortal Blade"; Range = 8.25; SlashEffects = table.freeze({"1slash", "1slash", "1slash", "1slash", "1slash"})});

	["Dual KT"] = table.freeze({Category = "DualKatana"; DisplayName = "Dual Katana"; Order = 15; Model = "Dual KT"; Range = 8; Grips = DUAL_BLADE_GRIPS});

	["Steel Dagger"] = table.freeze({Category = "Dagger"; DisplayName = "Steel Dagger"; Order = 16; Model = "Steel Dagger"; Range = 5; Moves = table.freeze({"Cut", "DaggerThrow"})});
	["Steel Spear"] = table.freeze({Category = "Spear"; DisplayName = "Steel Spear"; Order = 17; Model = "Steel Spear"; Range = 9});

	["Steel Scythe"] = table.freeze({Category = "Scythe"; DisplayName = "Steel Scythe"; Order = 18; Model = "Steel Scythe"; Range = 8.25});
	["Nocturnal Edge"] = table.freeze({Category = "Scythe"; DisplayName = "Nocturnal Edge"; Order = 19; Model = "Nocturnal Edge"; Range = 10});

	Vylis = table.freeze({Category = "Fists"; DisplayName = "Vylis"; Order = 20; Model = "Vylis"; Range = 5.8; Grips = GLOVE_GRIPS});
	Wraps = table.freeze({Category = "Fists"; DisplayName = "Wraps"; Order = 21; Model = "Wraps"; Range = 5.8; Grips = GLOVE_GRIPS});
	["Steel Gauntlets"] = table.freeze({Category = "Fists"; DisplayName = "Steel Gauntlets"; Order = 22; Model = "Steel Gauntlets"; Range = 6.4; Grips = GLOVE_GRIPS});
})
