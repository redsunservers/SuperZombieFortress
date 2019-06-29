int g_nWeapons[][eWeapons] =
{
	{9, eWeaponsRarity_Common, "models/weapons/c_models/c_shotgun/c_shotgun.mdl", ""},							//Shotgun (Index 9 is for Engineer)
	{415, eWeaponsRarity_Common, "models/weapons/c_models/c_reserve_shooter/c_reserve_shooter.mdl", ""},		//Reserve Shooter
	{1153, eWeaponsRarity_Uncommon, "models/workshop/weapons/c_models/c_trenchgun/c_trenchgun.mdl", ""},		//Panic Attack
	
	{18, eWeaponsRarity_Rare, "models/weapons/c_models/c_rocketlauncher/c_rocketlauncher.mdl", "Rocket Launcher"},	//Rocket Launcher
	{127, eWeaponsRarity_Rare, "models/weapons/c_models/c_directhit/c_directhit.mdl", ""},						//Direct Hit
	{414, eWeaponsRarity_Rare, "models/weapons/c_models/c_liberty_launcher/c_liberty_launcher.mdl", ""},		//Liberty Launcher
	{441, eWeaponsRarity_Rare, "models/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl", ""},			//Cow Mangler
	{730, eWeaponsRarity_Rare, "models/weapons/c_models/c_dumpster_device/c_dumpster_device.mdl", ""},			//Beggar's Bazooka
	{1104, eWeaponsRarity_Rare, "models/workshop/weapons/c_models/c_atom_launcher/c_atom_launcher.mdl", ""},	//Air Strike
	{129, eWeaponsRarity_Common, "models/weapons/c_models/c_bugle/c_bugle.mdl", ""},							//Buff Banner
	{226, eWeaponsRarity_Common, "models/weapons/c_models/c_battalion_bugle/c_battalion_bugle.mdl", ""},		//Battalion's Backu
	{354, eWeaponsRarity_Rare, "models/weapons/c_models/c_shogun_warhorn/c_shogun_warhorn.mdl", ""},			//Concheror
	{442, eWeaponsRarity_Common, "models/weapons/c_models/c_drg_righteousbison/c_drg_righteousbison.mdl", ""},	//Righteous Bison
	
	{21, eWeaponsRarity_Rare, "models/weapons/c_models/c_flamethrower/c_flamethrower.mdl", "Flamethrower"},		//Flamethrower
	{40, eWeaponsRarity_Rare, "models/weapons/c_models/c_flamethrower/c_backburner.mdl", ""},					//Backburner
	{215, eWeaponsRarity_Rare, "models/weapons/c_models/c_degreaser/c_degreaser.mdl", ""},						//Degreaser
	{39, eWeaponsRarity_Common, "models/weapons/c_models/c_flaregun_pyro/c_flaregun_pyro.mdl", ""},				//Flare Gun
	{351, eWeaponsRarity_Common, "models/weapons/c_models/c_detonator/c_detonator.mdl", ""},					//Detonator
	{595, eWeaponsRarity_Common, "models/weapons/c_models/c_drg_manmelter/c_drg_manmelter.mdl", ""},			//Manmelter
	{740, eWeaponsRarity_Uncommon, "models/weapons/c_models/c_scorch_shot/c_scorch_shot.mdl", ""},				//Scorch Shot
	{1180, eWeaponsRarity_Common, "models/weapons/c_models/c_gascan/c_gascan.mdl", ""},							//Gas Passer
	
	{19, eWeaponsRarity_Uncommon, "models/weapons/c_models/c_grenadelauncher/c_grenadelauncher.mdl", ""},		//Grenade Launcher
	{308, eWeaponsRarity_Uncommon, "models/weapons/c_models/c_lochnload/c_lochnload.mdl", ""},					//Loch-n-Load
	{996, eWeaponsRarity_Rare, "models/weapons/c_models/c_demo_cannon/c_demo_cannon.mdl", ""},					//Loose Cannon
	{1151, eWeaponsRarity_Uncommon, "models/workshop/weapons/c_models/c_quadball/c_quadball.mdl", ""},			//Iron Bomber
	{20, eWeaponsRarity_Rare, "models/weapons/c_models/c_stickybomb_launcher/c_stickybomb_launcher.mdl", "Stickybomb Launcher"},	//Stickybomb Launcher
	{130, eWeaponsRarity_Rare, "models/weapons/c_models/c_scottish_resistance/c_scottish_resistance.mdl", ""},	//Scottish Resistance
	{1150, eWeaponsRarity_Rare, "models/workshop/weapons/c_models/c_kingmaker_sticky/c_kingmaker_sticky.mdl", ""},	//Quickiebomb Launcher
	{131, eWeaponsRarity_Common, "models/weapons/c_models/c_targe/c_targe.mdl", ""},							//Chargin Targe
//	{406, eWeaponsRarity_Common, "models/weapons/c_models/c_persian_shield/c_persian_shield.mdl", ""},			//Splendid Screen
	{1099, eWeaponsRarity_Common, "models/workshop/weapons/c_models/c_wheel_shield/c_wheel_shield.mdl", ""},	//Tide Turner
	
	{141, eWeaponsRarity_Rare, "models/weapons/c_models/c_frontierjustice/c_frontierjustice.mdl", ""},			//Frontier Justice
	{527, eWeaponsRarity_Rare, "models/weapons/c_models/c_dex_shotgun/c_dex_shotgun.mdl", ""},					//Widowmaker
	{588, eWeaponsRarity_Common, "models/weapons/c_models/c_drg_pomson/c_drg_pomson.mdl", ""},					//Pomson
	{997, eWeaponsRarity_Common, "models/weapons/c_models/c_tele_shotgun/c_tele_shotgun.mdl", ""},				//Rescue Ranger 
	{22, eWeaponsRarity_Common, "models/weapons/c_models/c_pistol/c_pistol.mdl", ""},							//Pistol
	{140, eWeaponsRarity_Common, "models/weapons/c_models/c_wrangler.mdl", ""},									//Wrangler
	
	{17, eWeaponsRarity_Common, "models/weapons/c_models/c_syringegun/c_syringegun.mdl", ""},					//Syringe Gun
	{36, eWeaponsRarity_Rare, "models/weapons/c_models/c_leechgun/c_leechgun.mdl", ""},							//Blutsauger
	{305, eWeaponsRarity_Rare, "models/weapons/c_models/c_crusaders_crossbow/c_crusaders_crossbow.mdl", ""},	//Crusader's Crossbow
	{412, eWeaponsRarity_Common, "models/weapons/c_models/c_proto_syringegun/c_proto_syringegun.mdl", ""},		//Overdose
	{29, eWeaponsRarity_Rare, "models/weapons/c_models/c_medigun/c_medigun.mdl", "Medigun"},					//Medigun
	{411, eWeaponsRarity_Rare, "models/weapons/c_models/c_proto_medigun/c_proto_medigun.mdl", ""},				//Quick-Fix
	{998, eWeaponsRarity_Rare, "models/weapons/c_models/c_medigun_defense/c_medigun_defense.mdl", ""},			//Vaccinator
	
	{14, eWeaponsRarity_Uncommon, "models/weapons/w_models/w_sniperrifle.mdl", ""},								//Sniper Rifle
	{56, eWeaponsRarity_Uncommon, "models/weapons/c_models/c_bow/c_bow.mdl", ""},								//Huntsman
	{230, eWeaponsRarity_Rare, "models/weapons/c_models/c_dartgun.mdl", ""},									//Sydney Sleeper
	{402, eWeaponsRarity_Rare, "models/weapons/c_models/c_bazaar_sniper/c_bazaar_sniper.mdl", ""},				//Bazaar Bargain
	{526, eWeaponsRarity_Rare, "models/weapons/c_models/c_dex_sniperrifle/c_dex_sniperrifle.mdl", ""},			//Machina
	{752, eWeaponsRarity_Common, "models/weapons/c_models/c_pro_rifle/c_pro_rifle.mdl", ""},					//Hitman Heatmaker
	{1098, eWeaponsRarity_Common, "models/weapons/c_models/c_tfc_sniperrifle/c_tfc_sniperrifle.mdl", ""},		//Classic
	{16, eWeaponsRarity_Common, "models/weapons/c_models/c_smg/c_smg.mdl", ""},									//SMG
	{751, eWeaponsRarity_Uncommon, "models/weapons/c_models/c_pro_smg/c_pro_smg.mdl", ""},						//Cleaner's Carbine
	{58, eWeaponsRarity_Common, "models/weapons/c_models/urinejar.mdl", ""},									//Jarate
	{57, eWeaponsRarity_Common, "models/player/items/sniper/knife_shield.mdl", ""},								//Razorback
	{642, eWeaponsRarity_Common, "models/player/items/sniper/xms_sniper_commandobackpack.mdl", ""},				//Cozy Camper
	
	{-1, eWeaponsRarity_Pickup, "models/items/ammopack_large.mdl"},
	{-1, eWeaponsRarity_Pickup, "models/items/medkit_large.mdl"},
};

//Static weapon models in map to replace what we actually wanted
int g_nWeaponsReskin[][eWeaponsReskin] =
{
	{18, "models/weapons/w_models/w_rocketlauncher.mdl"},
	{18, "models/weapons/c_models/c_bet_rocketlauncher/c_bet_rocketlauncher.mdl"},
	{29, "models/weapons/w_models/w_medigun.mdl"},
};