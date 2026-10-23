return table.freeze({
	Movement = table.freeze({
		Forward = "rbxassetid://111077785875598";
		Back = "rbxassetid://101238079484980";
		Left = "rbxassetid://76238009484167";
		Right = "rbxassetid://115445652062764";
		Roll = "rbxassetid://114963664648176";
		Idle = "rbxassetid://139783125255456";
		walk = "rbxassetid://81874417224388";
		Sprint = "rbxassetid://70903321662399";
		jump = "rbxassetid://135702083168555";
		Fall = "rbxassetid://120908359783163";
		LeftRun = "rbxassetid://118914310248428";
		RightRun = "rbxassetid://92324260993876";
		Vault1 = "rbxassetid://111806598954502";
		Vault2 = "rbxassetid://87942706676175";
		LongJump = "rbxassetid://71457670921368";
		Sliding = "rbxassetid://134302481749326";
	});

	Shared = table.freeze({
		Punch = table.freeze({
			Punch1 = "rbxassetid://131985175663129";
			Punch2 = "rbxassetid://121603729341695";
			Punch3 = "rbxassetid://98116898772008";
			Punch4 = "rbxassetid://140218265622686";
			Punch5 = "rbxassetid://90828170591239";
			JumpUp = "rbxassetid://126284167208855";
		});

		Weapon = table.freeze({
			HitUp = "rbxassetid://90750579597199";
		});

		Block = table.freeze({
			Blocking = "rbxassetid://129637547540775";
			BlockHit = "rbxassetid://123845887158244";
			BlockBreak = "rbxassetid://104523635706504";
		});

		Stun = table.freeze({
			Hit1 = "rbxassetid://82541124340702";
			Hit2 = "rbxassetid://93856933557331";
			Hit3 = "rbxassetid://88489179667620";
			Hit4 = "rbxassetid://82541124340702";
			Hit5 = "rbxassetid://120237797972656";
			SlamStun = "rbxassetid://120237797972656";
		});

		Parry = table.freeze({
			Parry = "rbxassetid://140405501883652";
			Parried = "rbxassetid://116166740511239";
			BlockBreak = "rbxassetid://75295103009922";
		});

		Idle = table.freeze({
			Default = "rbxassetid://11361002294";
		});

		DownSlam = table.freeze({
			"rbxassetid://110883531326106";
			"rbxassetid://121297592006175";
		});

		Slam = table.freeze({
			M1Downslam = "rbxassetid://93691401634190";
		});
	});

	Weapons = table.freeze({
		--// Greatswords \\--

		GreatSword = table.freeze({
			Combat1 = "rbxassetid://115188779775067";
			Combat2 = "rbxassetid://77991701531557";
			Combat3 = "rbxassetid://74359229331028";
			Combat4 = "rbxassetid://123311420326858";
			Combat5 = "rbxassetid://98746439901076";
			Critical = "rbxassetid://0";
			Equip = "rbxassetid://98629484644888";
			Blocking = "rbxassetid://83625987534708";
			Idle = "rbxassetid://99524115688566";
			DSIdle = "rbxassetid://90519168297065";
			walk = "rbxassetid://76980887133888";
			run = "rbxassetid://101575350826559";
		});

		DragonSlayer = table.freeze({
			Combat1 = "rbxassetid://91138922124420";
			Combat2 = "rbxassetid://110429591388952";
			Combat3 = "rbxassetid://82396912225048";
			Combat4 = "rbxassetid://129650220050908";
			Combat5 = "rbxassetid://0";
			Critical = "rbxassetid://0";
			Equip = "rbxassetid://0";
			Blocking = "rbxassetid://83625987534708";
			Idle = "rbxassetid://0";
			walk = "rbxassetid://0";
			run = "rbxassetid://0";
		});

		--// Longswords \\--

		LongSword = table.freeze({
			Combat1 = "rbxassetid://104350674835028";
			Combat2 = "rbxassetid://136916892053502";
			Combat3 = "rbxassetid://137545625296970";
			Combat4 = "rbxassetid://72817778851446";
			Combat5 = "rbxassetid://129033506735142";
			Critical = "rbxassetid://79689855601446";
			Equip = "rbxassetid://84342583369737";
			Blocking = "rbxassetid://83625987534708";
			Idle = "rbxassetid://94310549255164";
			walk = "rbxassetid://122649312804233";
			run = "rbxassetid://113551530261645";
		});

		--// Staffs \\--

		Staff = table.freeze({
			Combat1 = "rbxassetid://96924845360176";
			Combat2 = "rbxassetid://89667499354648";
			Combat3 = "rbxassetid://88268634229680";
			Combat4 = "rbxassetid://76650381747244";
			Combat5 = "rbxassetid://97376090252044";
			Critical = "rbxassetid://102572344601898";
			Equip = "rbxassetid://81750054746559";
			Blocking = "rbxassetid://89104028125350";
			Idle = "rbxassetid://119186601575951";
			walk = "rbxassetid://0";
			run = "rbxassetid://0";
		});

		--// Axes \\--

		Axe = table.freeze({
			Combat1 = "rbxassetid://129282498788071";
			Combat2 = "rbxassetid://77175308045095";
			Combat3 = "rbxassetid://96905574685770";
			Combat4 = "rbxassetid://82245759195431";
			Combat5 = "rbxassetid://93194714579925";
			Critical = "rbxassetid://90750579597199";
			Equip = "rbxassetid://98629484644888";
			Blocking = "rbxassetid://83625987534708";
			Idle = "rbxassetid://129537870849720";
			walk = "rbxassetid://0";
			run = "rbxassetid://134059625100812";
		});

		--// Katanas \\--

		["Mortal Blade"] = table.freeze({
			Combat1 = "rbxassetid://112031708997344";
			Combat2 = "rbxassetid://134829246696146";
			Combat3 = "rbxassetid://113484150880019";
			Combat4 = "rbxassetid://133697597189292";
			Combat5 = "rbxassetid://0";
			Critical = "rbxassetid://0";
			Equip = "rbxassetid://0";
			Blocking = "rbxassetid://130271994451347";
			Idle = "rbxassetid://94310549255164";
			walk = "rbxassetid://104436812740050";
			run = "rbxassetid://113551530261645";
		});

		--// Dual Katanas \\--

		["Dual KT"] = table.freeze({
			Combat1 = "rbxassetid://106011325536629";
			Combat2 = "rbxassetid://129465527924449";
			Combat3 = "rbxassetid://78870204061895";
			Combat4 = "rbxassetid://77265847375944";
			Combat5 = "rbxassetid://128318354782081";
			Critical = "rbxassetid://0";
			Equip = "rbxassetid://0";
			Blocking = "rbxassetid://128060776570277";
			Idle = "rbxassetid://80205063570429";
			walk = "rbxassetid://117688040681782";
			run = "rbxassetid://93837310928313";
		});

		--// Daggers \\--

		["Steel Dagger"] = table.freeze({
			Combat1 = "rbxassetid://107638751688338";
			Combat2 = "rbxassetid://94814386269568";
			Combat3 = "rbxassetid://90783588792095";
			Combat4 = "rbxassetid://109851281341214";
			Combat5 = "rbxassetid://0";
			Critical = "rbxassetid://0";
			Equip = "rbxassetid://71218143930564";
			Blocking = "rbxassetid://130271994451347";
			Idle = "rbxassetid://91216548464847";
			walk = "rbxassetid://104436812740050";
			run = "rbxassetid://113551530261645";
		});

		--// Spears \\--

		["Steel Spear"] = table.freeze({
			Combat1 = "rbxassetid://76095760412882";
			Combat2 = "rbxassetid://114146575363599";
			Combat3 = "rbxassetid://134826435698505";
			Combat4 = "rbxassetid://100741713827688";
			Combat5 = "rbxassetid://0";
			Critical = "rbxassetid://0";
			Equip = "rbxassetid://130407541777231";
			Blocking = "rbxassetid://129305693033685";
			Idle = "rbxassetid://119186601575951";
			walk = "rbxassetid://87979502270630";
			run = "rbxassetid://138469876012300";
		});

		--// Scythes \\--

		["Steel Scythe"] = table.freeze({
			Combat1 = "rbxassetid://115900848366455";
			Combat2 = "rbxassetid://78529367124708";
			Combat3 = "rbxassetid://115900848366455";
			Combat4 = "rbxassetid://77314274708168";
			Combat5 = "rbxassetid://0";
			Critical = "rbxassetid://0";
			Equip = "rbxassetid://117585018448339";
			Blocking = "rbxassetid://83625987534708";
			Idle = "rbxassetid://129537870849720";
			walk = "rbxassetid://76980887133888";
			run = "rbxassetid://101575350826559";
		});

		--// Fists / Gauntlets \\--

		Fists = table.freeze({
			Combat1 = "rbxassetid://131985175663129";
			Combat2 = "rbxassetid://121603729341695";
			Combat3 = "rbxassetid://98116898772008";
			Combat4 = "rbxassetid://140218265622686";
			Combat5 = "rbxassetid://90828170591239";
			Critical = "rbxassetid://0";
			Equip = "rbxassetid://0";
			Blocking = "rbxassetid://129637547540775";
			Idle = "rbxassetid://11361002294";
			walk = "rbxassetid://0";
			run = "rbxassetid://0";
		});
	});

	Moves = table.freeze({
		GroundSlam = "rbxassetid://110883531326106";
		FistBarrage = "rbxassetid://123461980692619";
		Rage = "rbxassetid://128149826268230";
		Leap = "rbxassetid://103107472675002";
		Cut = "rbxassetid://129777736102447";
		DaggerThrow = "rbxassetid://106448451892609";
		DaggerDance = "rbxassetid://111287464837255";
		Thrust = "rbxassetid://86677978686885";
		Spin = "rbxassetid://102759962289170";
	});
});
