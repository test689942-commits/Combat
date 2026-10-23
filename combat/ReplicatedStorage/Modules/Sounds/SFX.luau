return table.freeze({
	["Dash1"] = "rbxassetid://1201103356";
	["Dash2"] = "rbxassetid://8475493570";
	["Slide"] = "rbxassetid://6429226498";

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
	Footsteps = table.freeze({
	["Bass"] = {
		"rbxassetid://84169700044924";
		"rbxassetid://121079295547006";
		"rbxassetid://118616720242265";
		"rbxassetid://131825532997563";
		"rbxassetid://105233797457161";
		"rbxassetid://108110162998260";
		"rbxassetid://138598038235403";
		"rbxassetid://133141073680273";
		"rbxassetid://113275740998105";
		"rbxassetid://95969783647753";
	};

	["Carpet"] = {
		"rbxassetid://123176295309235";
		"rbxassetid://126465176030503";
		"rbxassetid://122400079320585";
		"rbxassetid://91335877631335";
		"rbxassetid://75637925968773";
		"rbxassetid://93475469520073";
		"rbxassetid://133953996122581";
		"rbxassetid://113843541040585";
		"rbxassetid://86476591850051";
		"rbxassetid://113953309602077";
		"rbxassetid://90208693027680";
		"rbxassetid://70780732635994";
		"rbxassetid://102523565893193";
		"rbxassetid://137616710079446";
	};

	["Concrete"] = {
		"rbxassetid://101284876658887";
		"rbxassetid://101247478330127";
		"rbxassetid://120705147630308";
		"rbxassetid://129889636399399";
		"rbxassetid://115775737843306";
		"rbxassetid://98696830067003";
		"rbxassetid://80930047167918";
		"rbxassetid://82828676962670";
		"rbxassetid://99432603316540";
		"rbxassetid://92491687788060";
		"rbxassetid://136048011638074";
		"rbxassetid://112994787379060";
		"rbxassetid://138080968593496";
		"rbxassetid://71838267603162";
		"rbxassetid://104928745868454";
		"rbxassetid://108646977863528";
		"rbxassetid://118339765454217";
	};

	["Dirt"] = {
		"rbxassetid://123798827072782";
		"rbxassetid://107833076127183";
		"rbxassetid://106088162488581";
		"rbxassetid://109245029645099";
		"rbxassetid://118167400646225";
		"rbxassetid://114700209518076";
		"rbxassetid://119270953649200";
		"rbxassetid://126790894584349";
		"rbxassetid://111202515673869";
		"rbxassetid://80963820461537";
		"rbxassetid://83906009962731";
		"rbxassetid://85842562680861";
		"rbxassetid://71625940666570";
		"rbxassetid://74305509847124";
	};

	["Glass"] = {
		"rbxassetid://134799577256936";
		"rbxassetid://116600783062033";
		"rbxassetid://118882379273550";
		"rbxassetid://82944169749908";
		"rbxassetid://75909404980230";
		"rbxassetid://110941875866935";
		"rbxassetid://81737515603503";
		"rbxassetid://112882495849681";
	};

	["Grass"] = {
		"rbxassetid://134709638059291";
		"rbxassetid://114662696805731";
		"rbxassetid://124091073895415";
		"rbxassetid://139635028625316";
		"rbxassetid://115222981204501";
		"rbxassetid://81958919447932";
		"rbxassetid://94480124180090";
		"rbxassetid://128345734959383";
		"rbxassetid://126685608671342";
		"rbxassetid://74545940296195";
		"rbxassetid://96787016478582";
		"rbxassetid://82849305720764";
		"rbxassetid://139241384074774";
	};

	["Gravel"] = {
		"rbxassetid://133640129346274";
		"rbxassetid://127282537381344";
		"rbxassetid://112237008006242";
		"rbxassetid://96115516201016";
		"rbxassetid://108348457805373";
		"rbxassetid://114831370458750";
		"rbxassetid://128153325708786";
		"rbxassetid://120556192469363";
		"rbxassetid://138364268333882";
		"rbxassetid://122710369915504";
	};

	["Ladder"] = {
		"rbxassetid://103053044289371";
		"rbxassetid://140056095555698";
		"rbxassetid://130063925367575";
		"rbxassetid://121845154197289";
		"rbxassetid://71839982622360";
		"rbxassetid://90411046325164";
		"rbxassetid://78746760619129";
		"rbxassetid://98435939619883";
		"rbxassetid://72928148740627";
		"rbxassetid://102407390558142";
		"rbxassetid://81526727822998";
		"rbxassetid://109002983670758";
	};

	["Metal_Auto"] = {
		"rbxassetid://134797006388697";
		"rbxassetid://120345010350497";
		"rbxassetid://129921205378452";
		"rbxassetid://132619293504969";
		"rbxassetid://102704225822037";
		"rbxassetid://140063033617926";
	};

	["Metal_Chainlink"] = {
		"rbxassetid://73645968887155";
		"rbxassetid://88994755919542";
		"rbxassetid://73919383729822";
		"rbxassetid://102979140592439";
		"rbxassetid://70510669637819";
		"rbxassetid://129940476051320";
		"rbxassetid://125972200296345";
		"rbxassetid://94130249167246";
	};

	["Metal_Grate"] = {
		"rbxassetid://133146023210810";
		"rbxassetid://87634930360726";
		"rbxassetid://101930810393487";
		"rbxassetid://78132291187771";
		"rbxassetid://101942276681223";
		"rbxassetid://120080364858893";
		"rbxassetid://97414414968376";
		"rbxassetid://134648379381323";
		"rbxassetid://74098039870377";
		"rbxassetid://133132311336304";
		"rbxassetid://123263412348735";
		"rbxassetid://98899480570228";
		"rbxassetid://88092869389687";
		"rbxassetid://92957982448488";
	};

	["Metal_Solid"] = {
		"rbxassetid://81124290416956";
		"rbxassetid://130368186758431";
		"rbxassetid://85270623741783";
		"rbxassetid://126471517155445";
		"rbxassetid://86215137383897";
		"rbxassetid://128175349880740";
		"rbxassetid://116462155883409";
		"rbxassetid://115013255387989";
		"rbxassetid://97497939419939";
		"rbxassetid://83482809188175";
		"rbxassetid://110309540666863";
		"rbxassetid://126519830073661";
		"rbxassetid://81841660742337";
		"rbxassetid://77010790400869";
		"rbxassetid://120947152644648";
		"rbxassetid://85505813754020";
	};

	["Mud"] = {
		"rbxassetid://100617690536001";
		"rbxassetid://84794457572303";
		"rbxassetid://92122853765739";
		"rbxassetid://95914434892980";
		"rbxassetid://122359923919838";
		"rbxassetid://110383255305677";
		"rbxassetid://98473608588083";
		"rbxassetid://92548172873048";
		"rbxassetid://119999036359338";
	};

	["Rubber"] = {
		"rbxassetid://136531771128512";
		"rbxassetid://97869184549670";
		"rbxassetid://100597751235196";
		"rbxassetid://107947991329314";
		"rbxassetid://133782044166048";
		"rbxassetid://133513056595890";
		"rbxassetid://92736929210200";
		"rbxassetid://74298701852687";
	};

	["Sand"] = {
		"rbxassetid://138699551297759";
		"rbxassetid://139517385174629";
		"rbxassetid://133346286578844";
		"rbxassetid://127842832381583";
		"rbxassetid://139554495093794";
		"rbxassetid://113968564875155";
		"rbxassetid://113968564875155";
		"rbxassetid://71072433327900";
		"rbxassetid://84170933218955";
		"rbxassetid://90248390508573";
		"rbxassetid://78389804282716";
		"rbxassetid://97399318657722";
	};

	["Snow"] = {
		"rbxassetid://105780933477114";
		"rbxassetid://83995511596327";
		"rbxassetid://138064968919037";
		"rbxassetid://133024236831342";
		"rbxassetid://96076464232684";
		"rbxassetid://89060242460911";
		"rbxassetid://130998656364600";
		"rbxassetid://102219369860764";
		"rbxassetid://78903169353777";
		"rbxassetid://110080924808482";
		"rbxassetid://106883979282118";
		"rbxassetid://112379962745452";
	};

	["Tile"] = {
		"rbxassetid://100058593454268";
		"rbxassetid://80565144878805";
		"rbxassetid://131429020937254";
		"rbxassetid://119805126434651";
		"rbxassetid://80538702695498";
		"rbxassetid://79596395640873";
		"rbxassetid://137981888664054";
		"rbxassetid://111718963667062";
		"rbxassetid://93597800954628";
		"rbxassetid://119898366225926";
		"rbxassetid://110282373167474";
		"rbxassetid://73222737059018";
		"rbxassetid://99979994408097";
		"rbxassetid://91761266032398";
	};

	["Wood"] = {
		"rbxassetid://99372259988941";
		"rbxassetid://123501759212158";
		"rbxassetid://126007102114023";
		"rbxassetid://134937005466483";
		"rbxassetid://117336699317367";
		"rbxassetid://102587476356134";
		"rbxassetid://136083625541899";
		"rbxassetid://123935976203380";
		"rbxassetid://139564964994912";
		"rbxassetid://122458758657527";
		"rbxassetid://70570920576445";
		"rbxassetid://135830997344832";
		"rbxassetid://105179486585109";
		"rbxassetid://138491037669374";
		"rbxassetid://70413202489278";
	};

	["Jump"] = {
		"rbxasset://sounds/action_jump.mp3";
	};
});

});
