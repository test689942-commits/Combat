return table.freeze({
	["Dash1"] = "rbxassetid://1201103356";
	["Dash2"] = "rbxassetid://8475493570";

	Gui = table.freeze({
		["New Area"] = "rbxassetid://96480143599028";
	});

	Dragon = table.freeze({
		Roar = "rbxassetid://76821048166110";
		Whoosh = "rbxasset://sounds/swordlunge.wav";
		Slash = "rbxasset://sounds/swordslash.wav";
		Stomp = "rbxassetid://88866275260992";
		Rumble = "rbxasset://sounds/bass.wav";
		Impact = "rbxasset://sounds/collide.wav";
		Explosion = "rbxasset://sounds/impact_explosion_03.mp3";
		Gust = "rbxasset://sounds/action_swim.mp3";
		Flame = "rbxasset://sounds/Rocket whoosh 01.wav";
		Launch = "rbxasset://sounds/Launching rocket.wav";
		Projectile = "rbxasset://sounds/Rocket shot.wav";
		Snap = "rbxasset://sounds/snap.mp3";
		Grunt = "rbxasset://sounds/uuhhh.mp3";
	});

	Pools = table.freeze({
		Swings = table.freeze({
			Light = table.freeze({
				"rbxassetid://15423983331";
				"rbxassetid://15423984720";
				"rbxassetid://15423985833";
				"rbxassetid://15166713232";
			});
			Medium = table.freeze({
				"rbxassetid://15389432406";
				"rbxassetid://15389434582";
				"rbxassetid://15389436610";
			});
			Heavy = table.freeze({
				"rbxassetid://115568900071576";
				--[[
				"rbxassetid://15423932355";
				"rbxassetid://15423933426";
				"rbxassetid://15423935983";
				"rbxassetid://15423937308";
				]]
			});
			Fists = table.freeze({
				"rbxassetid://15166713232";
				"rbxassetid://15166709578";
				"rbxassetid://15166714319";
			});
			Spear = table.freeze({
				"rbxassetid://16928456202";
				"rbxassetid://16928441764";
				"rbxassetid://16928441984";
			});
		});

		Hits = table.freeze({
			Blade = table.freeze({
				table.freeze({Id = "rbxassetid://16302465188"; Volume = 0.35});
			});
			Blunt = table.freeze({
				table.freeze({Id = "rbxassetid://15895795139"; Volume = 0.35});
			});
			Scythe = table.freeze({
				"rbxassetid://16302453361";
			});
			Fists = table.freeze({
				"rbxassetid://16845879752";
				"rbxassetid://16845881932";
				"rbxassetid://16845885644";
				"rbxassetid://16845891045";
			});
		});

		Equips = table.freeze({
			Sword = table.freeze({
				"rbxassetid://9119747270";
				"rbxassetid://211134014";
			});
			Sheath = table.freeze({
				"rbxassetid://15390190958";
				"rbxassetid://8786849224";
			});
			Blunt = table.freeze({
				"rbxassetid://3834495137";
			});
		});

		Blocks = table.freeze({
			"rbxassetid://6330969397";
			"rbxassetid://6331329239";
		});
	});

	Combat = table.freeze({
		Punch = table.freeze({
			["Perfect Block"] = table.freeze({Pool = "Pools.Blocks"});
			Punch1 = table.freeze({Pool = "Pools.Hits.Fists"});
			Punch2 = table.freeze({Pool = "Pools.Hits.Fists"});
			Punch3 = table.freeze({Pool = "Pools.Hits.Fists"});
			Punch4 = table.freeze({Pool = "Pools.Hits.Fists"});
			Punch5 = table.freeze({Pool = "Pools.Hits.Fists"});
			Swing = table.freeze({Pool = "Pools.Swings.Fists"});
			["Block hit"] = table.freeze({Pool = "Pools.Blocks"});
			["Block Break"] = "rbxassetid://8400292687";
		});
		Slam = "rbxassetid://5522448086";
		Slam2 = "rbxassetid://6435892716";
		Jump = "rbxassetid://9114890978";
		Jump2 = "rbxassetid://6776044661";
		Jump3 = "rbxassetid://9117406165";
	});

	Weapons = table.freeze({
		Fists = table.freeze({
			Swing = table.freeze({Pool = "Pools.Swings.Fists"});
			Hit = table.freeze({Pool = "Pools.Hits.Fists"});
		});

		Greatsword = table.freeze({
			Swing = table.freeze({Pool = "Pools.Swings.Heavy"; PlaybackSpeed = 1});
			Hit = table.freeze({Pool = "Pools.Hits.Blade"; PlaybackSpeed = 1});
			Equip = table.freeze({Pool = "Pools.Equips.Sword"; PlaybackSpeed = 1});
		});

		Longsword = table.freeze({
			Swing = table.freeze({Pool = "Pools.Swings.Medium"; PlaybackSpeed = 1.2});
			Hit = table.freeze({Pool = "Pools.Hits.Blade"; PlaybackSpeed = 1.1});
			Equip = table.freeze({Pool = "Pools.Equips.Sword"; PlaybackSpeed = 1.1});
		});

		Staff = table.freeze({
			Swing = table.freeze({Pool = "Pools.Swings.Light"; PlaybackSpeed = 1.1});
			Hit = table.freeze({Pool = "Pools.Hits.Blunt"; PlaybackSpeed = 1.2});
			Equip = table.freeze({Pool = "Pools.Equips.Blunt"; PlaybackSpeed = 1.2});
		});

		Axe = table.freeze({
			Swing = table.freeze({Pool = "Pools.Swings.Heavy"; PlaybackSpeed = 1.1});
			Hit = table.freeze({Pool = "Pools.Hits.Blade"; PlaybackSpeed = 0.85});
			Equip = table.freeze({Pool = "Pools.Equips.Sword"; PlaybackSpeed = 0.95});
		});

		Katana = table.freeze({
			Swing = table.freeze({Pool = "Pools.Swings.Light"; PlaybackSpeed = 1.35});
			Hit = table.freeze({Pool = "Pools.Hits.Blade"; PlaybackSpeed = 1.2});
			Equip = table.freeze({Pool = "Pools.Equips.Sheath"; PlaybackSpeed = 1.2});
		});

		DualKatana = table.freeze({
			Swing = table.freeze({Pool = "Pools.Swings.Light"; PlaybackSpeed = 1.4});
			Hit = table.freeze({Pool = "Pools.Hits.Blade"; PlaybackSpeed = 1.25});
			Equip = table.freeze({Pool = "Pools.Equips.Sheath"; PlaybackSpeed = 1.25});
		});

		Dagger = table.freeze({
			Swing = table.freeze({Pool = "Pools.Swings.Fists"; PlaybackSpeed = 1.55});
			Hit = table.freeze({Pool = "Pools.Hits.Blade"; PlaybackSpeed = 1.35});
			Equip = table.freeze({Pool = "Pools.Equips.Sheath"; PlaybackSpeed = 1.4});
		});

		MinuteDagger = table.freeze({
			Swing = table.freeze({Pool = "Pools.Swings.Fists"; PlaybackSpeed = 1.55});
			Hit = table.freeze({Pool = "Pools.Hits.Blade"; PlaybackSpeed = 1.35});
			Equip = table.freeze({Pool = "Pools.Equips.Sheath"; PlaybackSpeed = 1.4});
		});

		Spear = table.freeze({
			Swing = table.freeze({Pool = "Pools.Swings.Spear"; PlaybackSpeed = 1});
			Hit = table.freeze({Pool = "Pools.Hits.Blade"; PlaybackSpeed = 1});
			Equip = table.freeze({Pool = "Pools.Equips.Sword"; PlaybackSpeed = 1});
		});

		Scythe = table.freeze({
			Swing = table.freeze({Pool = "Pools.Swings.Heavy"; PlaybackSpeed = 1});
			Hit = table.freeze({Pool = "Pools.Hits.Scythe"; PlaybackSpeed = 0.95});
			Equip = table.freeze({Pool = "Pools.Equips.Sword"; PlaybackSpeed = 0.95});
		});
	});

	Moves = table.freeze({
		GroundSlam = "rbxassetid://8588542238";

		Rage = table.freeze({
			Windup = "rbxassetid://16825482090";
			Scream = table.freeze({Id = "rbxassetid://6824039583"; Volume = 0.8});
		});

		DaggerThrow = table.freeze({
			Throw = table.freeze({Pool = "Pools.Swings.Light"; PlaybackSpeed = 1.3});
			Hit = table.freeze({Pool = "Pools.Hits.Blade"});
		});

		Cut = table.freeze({
			Slash = table.freeze({Pool = "Pools.Swings.Light"});
			Impact = table.freeze({Pool = "Pools.Hits.Blade"});
		});

		DaggerDance = table.freeze({
			Slash = table.freeze({Pool = "Pools.Swings.Light"; PlaybackSpeed = 1.35});
			Impact = table.freeze({Pool = "Pools.Hits.Blade"});
		});

		Thrust = table.freeze({
			Slash = table.freeze({Pool = "Pools.Swings.Heavy"; PlaybackSpeed = 1.1});
			Impact = table.freeze({Pool = "Pools.Hits.Blade"; PlaybackSpeed = 0.85});
		});

		Spin = table.freeze({
			Slash = table.freeze({Pool = "Pools.Swings.Heavy"; PlaybackSpeed = 1.1});
			Impact = table.freeze({Pool = "Pools.Hits.Blade"; PlaybackSpeed = 0.85});
		});


		Leap = table.freeze({
			Takeoff = "rbxassetid://1598682218";
			Land = "rbxassetid://5522448086";
		});
	});
});
