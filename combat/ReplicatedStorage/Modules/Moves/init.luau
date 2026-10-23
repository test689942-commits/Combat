return table.freeze({
	
	--// Dash \\--

	Dash = table.freeze({
		DisplayName = "Dash";
		Cooldown = 1.4;
		Key = Enum.KeyCode.Q;
		RequiresFist = false;
		DefaultDirection = "Back";
		Speed = 60;
		Duration = 0.25;
		ComboSpeed = 40;
		ComboDuration = 0.15;
		AirSpeed = 65;
		Sounds = table.freeze({"Dash1", "Dash2"});

		Directions = table.freeze({
			table.freeze({Direction = "Forward", EntryName = "DashFront", DisplayName = "Dash Front", ModifierKey = Enum.KeyCode.W, Axis = "Look", Sign = 1, AirAngle = -180});
			table.freeze({Direction = "Left", EntryName = "DashLeft", DisplayName = "Dash Left", ModifierKey = Enum.KeyCode.A, Axis = "Right", Sign = -1, AirAngle = -90});
			table.freeze({Direction = "Right", EntryName = "DashRight", DisplayName = "Dash Right", ModifierKey = Enum.KeyCode.D, Axis = "Right", Sign = 1, AirAngle = 90});
			table.freeze({Direction = "Back", EntryName = "DashBack", DisplayName = "Dash Back", ModifierKey = Enum.KeyCode.S, Axis = "Look", Sign = -1, AirAngle = 0, Duration = 0.6});
		});
	});

	--// Ground Slam \\--

	GroundSlam = table.freeze({
		DisplayName = "Ground Slam";
		EntryName = "GroundSlam";
		Skill = true;
		Parryable = true;
		Order = 1;
		RequiresFist = true;
		Key = Enum.KeyCode.Z;
		Cooldown = 8;
		MaxHoldTime = 15;
		LockDuration = 1.2;
		ImpactDelay = 0.35;
		Radius = 17;
		VerticalReach = 12;
		Damage = 20;
		StunTime = 1.5;
		KnockbackForce = 45;
		KnockbackLift = 25;
		DropFromAirCombat = true;
		AirDropDelay = 1;
	});

	--// Fist Barrage \\--

	FistBarrage = table.freeze({
		DisplayName = "Fist Barrage";
		EntryName = "FistBarrage";
		Skill = true;
		Parryable = true;
		Order = 2;
		RequiresFist = true;
		Key = Enum.KeyCode.X;
		Cooldown = 0;
		LockDuration = 1.2;
		StartDelay = 0.1;
		HitCount = 8;
		HitInterval = 0.1;
		Damage = 2.5;
		StunTime = 0.3;
		HitboxOffset = 4.5;
		HitboxSize = Vector3.new(7, 6, 9);
		MaxTargetDistance = 12;
		EffectOffset = 1.5;
	});

	--//Rage \\--

	Rage = table.freeze({
		DisplayName = "Rage";
		EntryName = "Rage";
		Skill = true;
		Parryable = false;
		Order = 3;
		RequiresFist = false;
		Key = Enum.KeyCode.R;
		Cooldown = 30;
		Duration = 20;
		AttributeName = "Rage";
		LockDuration = 2.75;
		EffectDelay = 1.77;
		EffectPulses = 14;
		EffectInterval = 0.1;
		Radius = 20;
		VerticalReach = 10;
		StunTime = 3;
		EffectName = "Scream";
	});

	--// Leap \\--

	Leap = table.freeze({
		DisplayName = "Leap";
		EntryName = "Leap";
		Skill = true;
		Parryable = true;
		Order = 4;
		RequiresFist = false;
		Key = Enum.KeyCode.E;
		Cooldown = 0;
		Damage = 10;
		LockDuration = 2.23;
		LeapDuration = 0.7;
		MaxRange = 30;
		ArcHeight = 24;
		Radius = 14;
		VerticalReach = 10;
		StunTime = 1.5;
		KnockbackForce = 35;
		KnockbackLift = 20;
	});

	--// Cut \\--

	Cut = table.freeze({
		DisplayName = "Cut";
		EntryName = "Cut";
		Skill = true;
		Parryable = true;
		Order = 5;
		RequiresFist = false;
		Key = Enum.KeyCode.V;
		Cooldown = 10;
		LockDuration = 2.97;
		HitDelay = 1.95;
		EffectStart = 0.25;
		EffectDuration = 1.7;
		MoveSpeed = 45;
		TickDamage = 4;
		TickInterval = 0.3;
		TickStun = 0.5;
		EffectDistance = 2.5;
		Range = 14;
		Width = 8;
		Height = 8;
		Damage = 25;
		StunTime = 1.5;
		KnockbackForce = 30;
		KnockbackLift = 10;
	});

	--// DaggerThrow \\--

	DaggerThrow = table.freeze({
		DisplayName = "Throw";
		EntryName = "DaggerThrow";
		Skill = true;
		Parryable = true;
		Order = 6;
		RequiresFist = false;
		Key = Enum.KeyCode.G;
		Cooldown = 8;
		LockDuration = 1.15;
		ThrowDelay = 0.45;
		Speed = 120;
		MaxDistance = 80;
		HitRadius = 1.5;
		Damage = 30;
		StunTime = 1;
		KnockbackForce = 25;
		KnockbackLift = 8;
	});

	--// DaggerDance \\--

	DaggerDance = table.freeze({
		DisplayName = "Dagger Dance";
		EntryName = "DaggerDance";
		Skill = true;
		Parryable = true;
		Order = 7;
		RequiresFist = false;
		Key = Enum.KeyCode.B;
		Cooldown = 0;
		LockDuration = 2.6;
		PhaseWindow = 4;
		SlashDamage = 12;
		SlashStun = 0.8;
		TickDamage = 4;
		TickInterval = 0.07;
		TickStun = 0.45;
		Range = 12;
		Width = 8;
		Height = 8;
		HitboxSize = Vector3.new(8, 8, 12);
		HitboxOffset = -6;
	});

	--// Thrust (Axe Move 1 - yayy) \\--

	Thrust = table.freeze({
		DisplayName = "Thrust";
		EntryName = "Thrust";
		Skill = true;
		Parryable = true;
		Order = 8;
		RequiresFist = false;
		Key = Enum.KeyCode.C;
		Cooldown = 6;
		LockDuration = 2.2;
		PhaseWindow = 4;
		ThrustDamage = 12;
		ThrustStun = 0.75;
		SlashupDamage = 12;
		SlashupStun = 0.8;
		SlashLastDamage = 18;
		SlashLastStun = 1.2;
		KnockbackForce = 45;
		KnockbackLift = 15;
		Range = 12;
		Width = 9;
		Height = 8;
		HitboxSize = Vector3.new(9, 8, 12);
		HitboxOffset = -6;
	});

	--// Spin (Axe Move 2 - idk) \\--

	Spin = table.freeze({
		DisplayName = "Spin";
		EntryName = "Spin";
		Skill = true;
		Parryable = true;
		Order = 9;
		RequiresFist = false;
		Key = Enum.KeyCode.T;
		Cooldown = 8;
		LockDuration = 2.6;
		PhaseWindow = 4.5;
		ThrustDamage = 12;
		ThrustStun = 0.75;
		SpinDamage = 18;
		SpinStun = 1.2;
		KnockbackForce = 45;
		KnockbackLift = 14;
		Range = 12;
		Width = 12;
		Height = 8;
		HitboxSize = Vector3.new(12, 8, 12);
		HitboxOffset = -4;
	});


	--// Combat \\--

	Combat = table.freeze({
		DisplayName = "Combat";
		ToolName = "Combat";
		RequiresFist = false;
		MaxCombo = 5;
		PunchCooldown = 0.3;
		FinisherCooldown = 2;
		ComboWindow = 1;
		JumpLockTime = 1;
		HitboxDelay = 0.25;
		HitboxOffset = 3;
		HitboxSize = 6;

		Punch = table.freeze({
			Damage = 5;
			Stun = 0.4;
			FinisherKnockback = 75;
			FinisherKnockbackDuration = 0.25;
		});

		UpperCut = table.freeze({
			Key = Enum.KeyCode.Space;
			Damage = 5;
			AirTime = 3.5;
			AttackerStun = 0.25;
			LiftHeight = 17;
			LiftDelay = 0.55;
			WeaponHitDelay = 0.52;
			WeaponLiftDelay = 0.28;
		});

		DownSlam = table.freeze({
			Damage = 15;
			WindUp = 0.35;
			Stun = 1.5;
		});

		Block = table.freeze({
			Key = Enum.KeyCode.F;
			Health = 5;
			ParryWindow = 0.3;
			ParryStun = 2;
			BreakStun = 2;
		});

		Controls = table.freeze({
			table.freeze({EntryName = "Punch", DisplayName = "Punch", KeyLabel = "M1"});
			table.freeze({EntryName = "UpperCut", DisplayName = "Upper Cut", KeyLabel = "Space"});
			table.freeze({EntryName = "Block", DisplayName = "Block", KeyLabel = "F"});
		});
	});
});
