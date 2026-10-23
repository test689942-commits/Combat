--// Grips \\--

local RIGHT_HAND_C0 = CFrame.new(-0.230697632, -1.13454056, 0.00231933594)
local LEFT_HAND_C0 = CFrame.new(0.230697632, -1.13454056, 0.00231933594)
local NO_OFFSET = CFrame.new()

local DUAL_BLADE_GRIPS = table.freeze({
	table.freeze({GripPart = "Right Arm"; AnchorName = "RightGrip"; JointName = "Handle"; HandleName = "HandleR"; PartName = "Handle"; GripC0 = RIGHT_HAND_C0; GripC1 = NO_OFFSET});
	table.freeze({GripPart = "Left Arm"; AnchorName = "LeftGrip"; JointName = "Handle"; HandleName = "HandleL"; PartName = "Handle"; GripC0 = LEFT_HAND_C0; GripC1 = NO_OFFSET});
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
		SlashEffects = table.freeze({"2slash", "2slash", "2slash", "2slash", "2slash"});
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

	["Mortal Blade"] = table.freeze({
		Category = "Katana";
		DisplayName = "Mortal Blade";
		Order = 6;
		Model = "Mortal Blade";
		Range = 8.25;
		SlashEffects = table.freeze({"1slash", "1slash", "1slash", "1slash", "1slash"});
	});

	["Dual KT"] = table.freeze({
		Category = "DualKatana";
		DisplayName = "Dual Katana";
		Order = 7;
		Model = "Dual KT";
		Range = 8;
		Grips = DUAL_BLADE_GRIPS;
	});

	["Steel Dagger"] = table.freeze({
		Category = "Dagger";
		DisplayName = "Steel Dagger";
		Order = 8;
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
		Order = 9;
		Model = "Steel Spear";
		Range = 9;
	});

	["Steel Scythe"] = table.freeze({
		Category = "Scythe";
		DisplayName = "Steel Scythe";
		Order = 10;
		Model = "Steel Scythe";
		Range = 8.25;
	});
})
