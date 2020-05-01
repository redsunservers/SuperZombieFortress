enum SoundType
{
	SoundType_None,
	SoundType_Quiet,
	SoundType_Attack,
	SoundType_Event,
	SoundType_Music,
};

enum Sound
{
	Sound_None,
	
	SoundQuiet_Min,
	SoundQuiet_Slow,
	SoundQuiet_Medium,
	SoundQuiet_Fast,
	SoundQuiet_Rabies,
	SoundQuiet_Max,
	
	SoundAttack_Min,
	SoundAttack_Drums,
	SoundAttack_SlayerMild,
	SoundAttack_Slayer,
	SoundAttack_Trumpet,
	SoundAttack_Snare,
	SoundAttack_Banjo,
	SoundAttack_Max,
	
	SoundEvent_Min,
	SoundEvent_Dead,
	SoundEvent_Incoming,
	SoundEvent_Drown,
	SoundEvent_NearDeath,
	SoundEvent_Jarate,
	SoundEvent_Max,
	
	SoundMusic_Min,
	SoundMusic_Prepare,
	SoundMusic_Tank,
	SoundMusic_LastStand,
	SoundMusic_ZombieWin,
	SoundMusic_SurvivorWin,
	SoundMusic_Max,
	
	Sound_Max
};

char g_sSound[TF_MAXPLAYERS][PLATFORM_MAX_PATH];
Sound g_nSound[TF_MAXPLAYERS];
bool g_bNoMusicForClient[TF_MAXPLAYERS];

/* QUIET SOUNDS */

char g_sSoundHeartSlow[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/heartbeat_slow.mp3"
};

char g_sSoundHeartMedium[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/heartbeat_medium.mp3"
};

char g_sSoundHeartFast[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/heartbeat_fast.mp3"
};

char g_sSoundRabies[][PLATFORM_MAX_PATH] =
{
	"left4fortress/rabies01.mp3",
	"left4fortress/rabies02.mp3",
	"left4fortress/rabies03.mp3",
	"left4fortress/rabies04.mp3"
};

/* ZOMBIE ATTACK SOUNDS */

char g_sSoundDrums[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/drums01.mp3",
	"left4fortress/zombat/drums02.mp3",
	"left4fortress/zombat/drums03.mp3",
	"left4fortress/zombat/drums04.mp3",
	"left4fortress/zombat/drums05.mp3"
};

char g_sSoundSlayerMild[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/slayer_violin01.mp3",
	"left4fortress/zombat/slayer_violin02.mp3",
	"left4fortress/zombat/slayer_violin03.mp3"
};

char g_sSoundSlayer[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/slayer01.mp3"
};

char g_sSoundTrumpet[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/trumpet01.mp3",
	"left4fortress/zombat/trumpet02.mp3",
	"left4fortress/zombat/trumpet03.mp3",
	"left4fortress/zombat/trumpet04.mp3",
	"left4fortress/zombat/trumpet05.mp3",
	"left4fortress/zombat/trumpet06.mp3"
};

char g_sSoundSnare[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/snare01.mp3",
	"left4fortress/zombat/snare02.mp3"
};

char g_sSoundBanjo[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/banjo01.mp3",
	"left4fortress/zombat/banjo02.mp3",
	"left4fortress/zombat/banjo03.mp3",
	"left4fortress/zombat/banjo04.mp3",
	"left4fortress/zombat/banjo05.mp3",
	"left4fortress/zombat/banjo06.mp3",
	"left4fortress/zombat/banjo07.mp3"
};

/* ZOMBIE EVENTS SOUND */

//Zombie killed survivor
char g_sSoundDead[][PLATFORM_MAX_PATH] =
{
	"left4fortress/theend.mp3"
};

//Frenzy
char g_sSoundIncoming[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zincoming_mob.mp3"
};

//Goo
char g_sSoundDrown[][PLATFORM_MAX_PATH] =
{
	"left4fortress/drowning.mp3"
};

//Backstab
char g_sSoundNearDeath[][PLATFORM_MAX_PATH] =
{
	"left4fortress/iamsocold.mp3"
};

//Boomer Jarate
char g_sSoundJarate[][PLATFORM_MAX_PATH] =
{
	"left4fortress/jarate.mp3"
};

/* MUSIC */

char g_sSoundPrepare[][PLATFORM_MAX_PATH] =
{
	"left4fortress/prepare01.mp3",
	"left4fortress/prepare02.mp3",
	"left4fortress/prepare_rain.mp3"
};

char g_sSoundTank[][PLATFORM_MAX_PATH] =
{
	"left4fortress/drumandbasstank.mp3",
	"left4fortress/metaltank.mp3",
	"left4fortress/monsoontank.mp3",
	"left4fortress/onebadtank.mp3",
	"left4fortress/sundownertank.mp3"
};

char g_sSoundLastStand[][PLATFORM_MAX_PATH] =
{
	"left4fortress/skinonourteeth.mp3"
};

char g_sSoundZombieWin[][PLATFORM_MAX_PATH] =
{
	"left4fortress/death.mp3"
};

char g_sSoundSurivourWin[][PLATFORM_MAX_PATH] =
{
	"left4fortress/we_survived.mp3"
};

/* OTHER SOUNDS */

//Special infected spawned
char g_sSoundSpawnInfected[][PLATFORM_MAX_PATH] =
{
	"misc/null.wav",						//no special infected
	"misc/null.wav",						//tank
	"left4fortress/boomerbacterias.mp3",	//boomer
	"left4fortress/chargerbacterias.mp3",	//charger
	"misc/null.wav",						//kingpin, used to use smoker's bacteria (need new sound for kingpin)
	"left4fortress/jockeybacterias.mp3",	//stalker
	"left4fortress/hunterbacterias.mp3",	//hunter
	"left4fortress/smokerbacterias.mp3"		//smoker
};

/* VO */

/* Scout */
char g_sVoCarryScout[][PLATFORM_MAX_PATH] =
{
	"scout_autocappedcontrolpoint01.mp3",
	"scout_autocappedcontrolpoint03.mp3",
	"scout_autocappedcontrolpoint04.mp3",
	"scout_go02.mp3"
};

char g_sVoWeaponScout[][PLATFORM_MAX_PATH] =
{
	"scout_mvm_loot_common03.mp3",
	"scout_mvm_loot_common04.mp3",
	"scout_mvm_loot_rare01.mp3",
	"scout_mvm_loot_rare02.mp3"
};


/* Soldier */
char g_sVoCarrySoldier[][PLATFORM_MAX_PATH] =
{
	"vo/soldier_autocappedcontrolpoint01.mp3",
	"vo/soldier_positivevocalization01.mp3",
	"vo/soldier_positivevocalization02.mp3",
	"vo/soldier_positivevocalization03.mp3",
	"vo/soldier_PickAxeTaunt01.mp3",
	"vo/soldier_PickAxeTaunt02.mp3",
	"vo/soldier_PickAxeTaunt03.mp3",
	"vo/soldier_PickAxeTaunt04.mp3",
	"vo/soldier_PickAxeTaunt05.mp3",
	"vo/soldier_laughevil01.mp3",
	"vo/soldier_laughevil03.mp3",
	"vo/soldier_go01.mp3",
	"vo/soldier_go02.mp3",
	"vo/soldier_battlecry02.mp3",
	"vo/soldier_battlecry06.mp3"
};

char g_sVoWeaponSoldier[][PLATFORM_MAX_PATH] =
{
	"vo/soldier_mvm_loot_common01.mp3",
	"vo/soldier_mvm_loot_common02.mp3",
	"vo/soldier_mvm_loot_common03.mp3",
	"vo/soldier_mvm_loot_rare01.mp3",
	"vo/soldier_mvm_loot_rare02.mp3",
	"vo/soldier_mvm_loot_rare03.mp3",
	"vo/soldier_mvm_loot_rare04.mp3"
};

char g_sVoTankSoldier[][PLATFORM_MAX_PATH] =
{
	"vo/soldier_mvm_tank_shooting01.mp3",
	"vo/soldier_mvm_tank_shooting02.mp3"
};


/* Pyro */
char g_sVoCarryPyro[][PLATFORM_MAX_PATH] =
{
	"vo/pyro_autocappedcontrolpoint01.mp3",
	"vo/pyro_autocappedintelligence01.mp3",
	"vo/pyro_go01.mp3",
	"vo/pyro_goodjob01.mp3",
	"vo/pyro_laughevil02.mp3",
	"vo/pyro_laughevil03.mp3",
	"vo/pyro_moveup01.mp3"
};

char g_sVoWeaponPyro[][PLATFORM_MAX_PATH] =
{
	"vo/pyro_battlecry01.mp3",
	"vo/pyro_battlecry02.mp3",
	"vo/pyro_positivevocalization01.mp3"
};


/* Demoman -- does not have tank lines */
char g_sVoCarryDemoman[][PLATFORM_MAX_PATH] =
{
	"vo/demoman_go01.mp3",
	"vo/demoman_go02.mp3",
	"vo/demoman_go03.mp3",
	"vo/demoman_helpmecapture02.mp3",
	"vo/demoman_helpmecapture03.mp3",
	"vo/demoman_laughevil01.mp3",
	"vo/demoman_laughevil03.mp3",
	"vo/demoman_laughevil05.mp3",
	"vo/demoman_laughshort02.mp3",
	"vo/demoman_laughshort04.mp3",
	"vo/demoman_laughshort06.mp3",
	"vo/demoman_gibberish02.mp3",
	"vo/demoman_gibberish08.mp3",
	"vo/demoman_gibberish13.mp3"
};

char g_sVoWeaponDemoman[][PLATFORM_MAX_PATH] =
{
	"vo/demoman_mvm_loot_common01.mp3",
	"vo/demoman_mvm_loot_common02.mp3",
	"vo/demoman_mvm_loot_common03.mp3",
	"vo/demoman_mvm_loot_common04.mp3",
	"vo/demoman_mvm_loot_godlike01.mp3",
	"vo/demoman_mvm_loot_rare01.mp3",
	"vo/demoman_mvm_loot_rare02.mp3"
};


/* Heavy */
char g_sVoCarryHeavy[][PLATFORM_MAX_PATH] =
{
	"heavy_autocappedintelligence01.mp3",
	"heavy_go02.mp3",
	"heavy_go03.mp3"
};

char g_sVoWeaponHeavy[][PLATFORM_MAX_PATH] =
{
	"heavy_mvm_get_upgrade04.mp3",
	"heavy_mvm_loot_common01.mp3",
	"heavy_mvm_loot_common02.mp3",
	"heavy_mvm_loot_godlike02.mp3",
	"heavy_specialweapon05.mp3",
	"heavy_specialweapon09.mp3"
};

char g_sVoTankHeavy[][PLATFORM_MAX_PATH] =
{
	"heavy_mvm_tank_alert01.mp3",
	"heavy_mvm_tank_alert02.mp3",
	"heavy_mvm_tank_alert03.mp3"
};

/* Engineer */
char g_sVoCarryEngineer[][PLATFORM_MAX_PATH] =
{
	"vo/engineer_autocappedcontrolpoint01.mp3",
	"vo/engineer_autocappedcontrolpoint02.mp3",
	"vo/engineer_autocappedintelligence01.mp3",
	"vo/engineer_autocappedintelligence02.mp3",
	"vo/engineer_autocappedintelligence03.mp3",
	"vo/engineer_cheers04.mp3",
	"vo/engineer_laughevil01.mp3",
	"vo/engineer_laughevil04.mp3",
	"vo/engineer_laughevil06.mp3"
};

char g_sVoWeaponEngineer[][PLATFORM_MAX_PATH] =
{
	"vo/engineer_mvm_loot_common01.mp3",
	"vo/engineer_mvm_loot_common02.mp3",
	"vo/engineer_mvm_loot_godlike01.mp3",
	"vo/engineer_mvm_loot_godlike02.mp3",
	"vo/engineer_mvm_loot_godlike03.mp3",
	"vo/engineer_mvm_loot_rare01.mp3",
	"vo/engineer_mvm_loot_rare02.mp3",
	"vo/engineer_mvm_loot_rare03.mp3",
	"vo/engineer_mvm_loot_rare04.mp3"
};

char g_sVoTankEngineer[][PLATFORM_MAX_PATH] =
{
	"vo/engineer_mvm_tank_shooting01.mp3",
	"vo/engineer_meleedare01.mp3"
};


/* Medic */
char g_sVoCarryMedic[][PLATFORM_MAX_PATH] =
{
	"vo/medic_go01.mp3",
	"vo/medic_go05.mp3",
	"vo/medic_goodjob02.mp3",
	"vo/medic_laughevil01.mp3",
	"vo/medic_laughevil03.mp3",
	"vo/medic_positivevocalization03.mp3",
	"vo/medic_specialcompleted04.mp3",
	"vo/medic_specialcompleted07.mp3",
	"vo/medic_yes03.mp3"
};

char g_sVoWeaponMedic[][PLATFORM_MAX_PATH] =
{
	"vo/medic_mvm_loot_common01.mp3",
	"vo/medic_mvm_loot_common02.mp3",
	"vo/medic_mvm_loot_common03.mp3",
	"vo/medic_mvm_loot_rare02.mp3",
	"vo/medic_mvm_loot_godlike01.mp3",
	"vo/medic_mvm_loot_godlike02.mp3",
	"vo/medic_mvm_loot_godlike03.mp3",
	"vo/medic_specialcompleted02.mp3",
	"vo/medic_specialcompleted03.mp3"
};

char g_sVoTankMedic[][PLATFORM_MAX_PATH] =
{
	"vo/medic_mvm_tank_shooting01.mp3",
	"vo/medic_mvm_tank_shooting02.mp3"
};


/* Sniper -- does not have tank lines */
char g_sVoCarrySniper[][PLATFORM_MAX_PATH] =
{
	"vo/sniper_autocappedcontrolpoint01.mp3",
	"vo/sniper_autocappedcontrolpoint02.mp3",
	"vo/sniper_autocappedcontrolpoint03.mp3",
	"vo/sniper_autocappedintelligence01.mp3",
	"vo/sniper_autocappedintelligence02.mp3",
	"vo/sniper_autocappedintelligence04.mp3",
	"vo/sniper_autocappedintelligence05.mp3",
	"vo/sniper_award01.mp3",
	"vo/sniper_award06.mp3",
	"vo/sniper_award07.mp3",
	"vo/sniper_award08.mp3",
	"vo/sniper_award11.mp3",
	"vo/sniper_award12.mp3",
	"vo/sniper_award13.mp3",
	"vo/sniper_battlecry02.mp3",
	"vo/sniper_go03.mp3",
	"vo/sniper_helpmecapture01.mp3",
	"vo/sniper_laughevil01.mp3",
	"vo/sniper_laughevil02.mp3",
	"vo/sniper_moveup01.mp3",
	"vo/sniper_specialweapon02.mp3",
	"vo/sniper_specialweapon05.mp3",
	"vo/sniper_specialweapon07.mp3",
	"vo/sniper_specialweapon09.mp3"
};

char g_sVoWeaponSniper[][PLATFORM_MAX_PATH] =
{
	"vo/sniper_specialweapon01.mp3",
	"vo/sniper_specialweapon02.mp3",
	"vo/sniper_specialweapon03.mp3",
	"vo/sniper_specialweapon04.mp3",
	"vo/sniper_specialweapon05.mp3",
	"vo/sniper_specialweapon06.mp3",
	"vo/sniper_specialweapon07.mp3",
	"vo/sniper_specialweapon08.mp3",
	"vo/sniper_specialweapon09.mp3"
};


/* Spy */
char g_sVoCarrySpy[][PLATFORM_MAX_PATH] =
{
	"spy_autocappedcontrolpoint03.mp3",
	"spy_go01.mp3",
	"spy_go02.mp3"
};

char g_sVoWeaponSpy[][PLATFORM_MAX_PATH] =
{
	"spy_mvm_loot_common01.mp3"
};

/* Common Infected */
char g_sVoZombieCommonDefault[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/idle_breath_01.mp3",
	"left4fortress/zombie_vo/idle_breath_02.mp3",
	"left4fortress/zombie_vo/idle_breath_03.mp3",
	"left4fortress/zombie_vo/idle_breath_04.mp3"
};

char g_sVoZombieCommonPain[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/been_shot_12.mp3",
	"left4fortress/zombie_vo/been_shot_13.mp3",
	"left4fortress/zombie_vo/been_shot_14.mp3",
	"left4fortress/zombie_vo/been_shot_18.mp3",
	"left4fortress/zombie_vo/been_shot_19.mp3",
	"left4fortress/zombie_vo/been_shot_20.mp3",
	"left4fortress/zombie_vo/been_shot_21.mp3",
	"left4fortress/zombie_vo/been_shot_22.mp3",
	"left4fortress/zombie_vo/been_shot_24.mp3"
};

char g_sVoZombieCommonRage[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/rage_at_victim21.mp3",
	"left4fortress/zombie_vo/rage_at_victim22.mp3",
	"left4fortress/zombie_vo/rage_at_victim25.mp3",
	"left4fortress/zombie_vo/rage_at_victim26.mp3"
};

char g_sVoZombieCommonMumbling[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/mumbling01.mp3",
	"left4fortress/zombie_vo/mumbling02.mp3",
	"left4fortress/zombie_vo/mumbling03.mp3",
	"left4fortress/zombie_vo/mumbling04.mp3",
	"left4fortress/zombie_vo/mumbling05.mp3",
	"left4fortress/zombie_vo/mumbling06.mp3",
	"left4fortress/zombie_vo/mumbling07.mp3",
	"left4fortress/zombie_vo/mumbling08.mp3"
};

char g_sVoZombieCommonShoved[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/shoved_1.mp3",
	"left4fortress/zombie_vo/shoved_2.mp3",
	"left4fortress/zombie_vo/shoved_3.mp3",
	"left4fortress/zombie_vo/shoved_4.mp3"
};

char g_sVoZombieCommonDeath[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/death_22.mp3",
	"left4fortress/zombie_vo/death_23.mp3",
	"left4fortress/zombie_vo/death_24.mp3",
	"left4fortress/zombie_vo/death_25.mp3",
	"left4fortress/zombie_vo/death_26.mp3",
	"left4fortress/zombie_vo/death_27.mp3",
	"left4fortress/zombie_vo/death_28.mp3",
	"left4fortress/zombie_vo/death_29.mp3"
};

/* Boomer */
char g_sVoZombieBoomerDefault[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/male_boomer_lurk_02.mp3",
	"left4fortress/zombie_vo/male_boomer_lurk_03.mp3",
	"left4fortress/zombie_vo/male_boomer_lurk_04.mp3",
};

char g_sVoZombieBoomerPain[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/male_boomer_pain_1.mp3",
	"left4fortress/zombie_vo/male_boomer_pain_2.mp3",
	"left4fortress/zombie_vo/male_boomer_pain_3.mp3"
};

char g_sVoZombieBoomerExplode[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/male_boomer_disruptvomit_05.mp3",
	"left4fortress/zombie_vo/male_boomer_disruptvomit_06.mp3",
	"left4fortress/zombie_vo/male_boomer_disruptvomit_07.mp3"
};

/* Charger */
char g_sVoZombieChargerDefault[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/charger_spotprey_01.mp3",
	"left4fortress/zombie_vo/charger_spotprey_02.mp3",
	"left4fortress/zombie_vo/charger_spotprey_03.mp3"
};

char g_sVoZombieChargerPain[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/charger_pain_01.mp3",
	"left4fortress/zombie_vo/charger_pain_02.mp3",
	"left4fortress/zombie_vo/charger_pain_03.mp3"
};

char g_sVoZombieChargerCharge[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/charger_charge_01.mp3",
	"left4fortress/zombie_vo/charger_charge_02.mp3"
};

/* Hunter */
char g_sVoZombieHunterDefault[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/hunter_stalk_04.mp3",
	"left4fortress/zombie_vo/hunter_stalk_05.mp3",
	"left4fortress/zombie_vo/hunter_stalk_06.mp3"
};

char g_sVoZombieHunterPain[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/hunter_pain_12.mp3",
	"left4fortress/zombie_vo/hunter_pain_13.mp3",
	"left4fortress/zombie_vo/hunter_pain_14.mp3"
};

char g_sVoZombieHunterLeap[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/hunter_attackmix_01.mp3",
	"left4fortress/zombie_vo/hunter_attackmix_02.mp3",
	"left4fortress/zombie_vo/hunter_attackmix_03.mp3"
};

/* Smoker */
char g_sVoZombieSmokerDefault[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/smoker_lurk_11.mp3",
	"left4fortress/zombie_vo/smoker_lurk_12.mp3",
	"left4fortress/zombie_vo/smoker_lurk_13.mp3"
};

char g_sVoZombieSmokerPain[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/smoker_pain_02.mp3",
	"left4fortress/zombie_vo/smoker_pain_03.mp3",
	"left4fortress/zombie_vo/smoker_pain_04.mp3"
};

/* Tank */
char g_sVoZombieTankDefault[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/tank_voice_01.mp3",
	"left4fortress/zombie_vo/tank_voice_02.mp3",
	"left4fortress/zombie_vo/tank_voice_03.mp3",
	"left4fortress/zombie_vo/tank_voice_04.mp3"
};

char g_sVoZombieTankPain[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/tank_pain_01.mp3",
	"left4fortress/zombie_vo/tank_pain_02.mp3",
	"left4fortress/zombie_vo/tank_pain_03.mp3",
	"left4fortress/zombie_vo/tank_pain_04.mp3"
};

char g_sVoZombieTankOnFire[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/tank_fire_02.mp3",
	"left4fortress/zombie_vo/tank_fire_03.mp3",
	"left4fortress/zombie_vo/tank_fire_04.mp3",
	"left4fortress/zombie_vo/tank_fire_05.mp3"
};

char g_sVoZombieTankAttack[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/tank_attack_01.mp3",
	"left4fortress/zombie_vo/tank_attack_02.mp3",
	"left4fortress/zombie_vo/tank_attack_03.mp3",
	"left4fortress/zombie_vo/tank_attack_04.mp3"
};

char g_sVoZombieTankDeath[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombie_vo/tank_death_01.mp3",
	"left4fortress/zombie_vo/tank_death_02.mp3",
	"left4fortress/zombie_vo/tank_death_03.mp3",
	"left4fortress/zombie_vo/tank_death_04.mp3"
};

void SoundPrecache()
{	
	//For left4fortress sounds, we need to use both precache and add to download table to each sounds
	for (int i = 0; i < sizeof(g_sSoundHeartSlow); i++) PrecacheSound2(g_sSoundHeartSlow[i]);
	for (int i = 0; i < sizeof(g_sSoundHeartMedium); i++) PrecacheSound2(g_sSoundHeartMedium[i]);
	for (int i = 0; i < sizeof(g_sSoundHeartFast); i++) PrecacheSound2(g_sSoundHeartFast[i]);
	for (int i = 0; i < sizeof(g_sSoundRabies); i++) PrecacheSound2(g_sSoundRabies[i]);
	
	for (int i = 0; i < sizeof(g_sSoundDrums); i++) PrecacheSound2(g_sSoundDrums[i]);
	for (int i = 0; i < sizeof(g_sSoundSlayerMild); i++) PrecacheSound2(g_sSoundSlayerMild[i]);
	for (int i = 0; i < sizeof(g_sSoundSlayer); i++) PrecacheSound2(g_sSoundSlayer[i]);
	for (int i = 0; i < sizeof(g_sSoundTrumpet); i++) PrecacheSound2(g_sSoundTrumpet[i]);
	for (int i = 0; i < sizeof(g_sSoundSnare); i++) PrecacheSound2(g_sSoundSnare[i]);
	for (int i = 0; i < sizeof(g_sSoundBanjo); i++) PrecacheSound2(g_sSoundBanjo[i]);
	
	for (int i = 0; i < sizeof(g_sSoundDead); i++) PrecacheSound2(g_sSoundDead[i]);
	for (int i = 0; i < sizeof(g_sSoundIncoming); i++) PrecacheSound2(g_sSoundIncoming[i]);
	for (int i = 0; i < sizeof(g_sSoundDrown); i++) PrecacheSound2(g_sSoundDrown[i]);
	for (int i = 0; i < sizeof(g_sSoundNearDeath); i++) PrecacheSound2(g_sSoundNearDeath[i]);
	for (int i = 0; i < sizeof(g_sSoundJarate); i++) PrecacheSound2(g_sSoundJarate[i]);
	
	for (int i = 0; i < sizeof(g_sSoundPrepare); i++) PrecacheSound2(g_sSoundPrepare[i]);
	for (int i = 0; i < sizeof(g_sSoundTank); i++) PrecacheSound2(g_sSoundTank[i]);
	for (int i = 0; i < sizeof(g_sSoundLastStand); i++) PrecacheSound2(g_sSoundLastStand[i]);
	for (int i = 0; i < sizeof(g_sSoundZombieWin); i++) PrecacheSound2(g_sSoundZombieWin[i]);
	for (int i = 0; i < sizeof(g_sSoundSurivourWin); i++) PrecacheSound2(g_sSoundSurivourWin[i]);
	
	for (int i = 0; i < sizeof(g_sSoundSpawnInfected); i++) PrecacheSound2(g_sSoundSpawnInfected[i]);
	
	//---//
	
	for (int i = 0; i < sizeof(g_sVoCarrySoldier); i++) PrecacheSound(g_sVoCarrySoldier[i]);
	for (int i = 0; i < sizeof(g_sVoWeaponSoldier); i++) PrecacheSound(g_sVoWeaponSoldier[i]);
	for (int i = 0; i < sizeof(g_sVoTankSoldier); i++) PrecacheSound(g_sVoTankSoldier[i]);
	
	for (int i = 0; i < sizeof(g_sVoCarryPyro); i++) PrecacheSound(g_sVoCarryPyro[i]);
	for (int i = 0; i < sizeof(g_sVoWeaponPyro); i++) PrecacheSound(g_sVoWeaponPyro[i]);
	
	for (int i = 0; i < sizeof(g_sVoCarryDemoman); i++) PrecacheSound(g_sVoCarryDemoman[i]);
	for (int i = 0; i < sizeof(g_sVoWeaponDemoman); i++) PrecacheSound(g_sVoCarryDemoman[i]);
	
	for (int i = 0; i < sizeof(g_sVoCarryEngineer); i++) PrecacheSound(g_sVoCarryEngineer[i]);
	for (int i = 0; i < sizeof(g_sVoWeaponEngineer); i++) PrecacheSound(g_sVoWeaponEngineer[i]);
	for (int i = 0; i < sizeof(g_sVoTankEngineer); i++) PrecacheSound(g_sVoTankEngineer[i]);
	
	for (int i = 0; i < sizeof(g_sVoCarryMedic); i++) PrecacheSound(g_sVoCarryMedic[i]);
	for (int i = 0; i < sizeof(g_sVoWeaponMedic); i++) PrecacheSound(g_sVoWeaponMedic[i]);
	for (int i = 0; i < sizeof(g_sVoTankMedic); i++) PrecacheSound(g_sVoTankMedic[i]);
	
	for (int i = 0; i < sizeof(g_sVoCarrySniper); i++) PrecacheSound(g_sVoCarrySniper[i]);
	for (int i = 0; i < sizeof(g_sVoWeaponSniper); i++) PrecacheSound(g_sVoWeaponSniper[i]);
	
	//---//
	
	for (int i = 0; i < sizeof(g_sVoZombieCommonDefault); i++) PrecacheSound2(g_sVoZombieCommonDefault[i]);
	for (int i = 0; i < sizeof(g_sVoZombieCommonPain); i++) PrecacheSound2(g_sVoZombieCommonPain[i]);
	for (int i = 0; i < sizeof(g_sVoZombieCommonRage); i++) PrecacheSound2(g_sVoZombieCommonRage[i]);
	for (int i = 0; i < sizeof(g_sVoZombieCommonMumbling); i++) PrecacheSound2(g_sVoZombieCommonMumbling[i]);
	for (int i = 0; i < sizeof(g_sVoZombieCommonShoved); i++) PrecacheSound2(g_sVoZombieCommonShoved[i]);
	for (int i = 0; i < sizeof(g_sVoZombieCommonDeath); i++) PrecacheSound2(g_sVoZombieCommonDeath[i]);
	
	for (int i = 0; i < sizeof(g_sVoZombieBoomerDefault); i++) PrecacheSound2(g_sVoZombieBoomerDefault[i]);
	for (int i = 0; i < sizeof(g_sVoZombieBoomerPain); i++) PrecacheSound2(g_sVoZombieBoomerPain[i]);
	for (int i = 0; i < sizeof(g_sVoZombieBoomerExplode); i++) PrecacheSound2(g_sVoZombieBoomerExplode[i]);
	
	for (int i = 0; i < sizeof(g_sVoZombieChargerDefault); i++) PrecacheSound2(g_sVoZombieChargerDefault[i]);
	for (int i = 0; i < sizeof(g_sVoZombieChargerPain); i++) PrecacheSound2(g_sVoZombieChargerPain[i]);
	for (int i = 0; i < sizeof(g_sVoZombieChargerCharge); i++) PrecacheSound2(g_sVoZombieChargerCharge[i]);
	
	for (int i = 0; i < sizeof(g_sVoZombieHunterDefault); i++) PrecacheSound2(g_sVoZombieHunterDefault[i]);
	for (int i = 0; i < sizeof(g_sVoZombieHunterPain); i++) PrecacheSound2(g_sVoZombieHunterPain[i]);
	for (int i = 0; i < sizeof(g_sVoZombieHunterLeap); i++) PrecacheSound2(g_sVoZombieHunterLeap[i]);
	
	for (int i = 0; i < sizeof(g_sVoZombieSmokerDefault); i++) PrecacheSound2(g_sVoZombieSmokerDefault[i]);
	for (int i = 0; i < sizeof(g_sVoZombieSmokerPain); i++) PrecacheSound2(g_sVoZombieSmokerPain[i]);
	
	for (int i = 0; i < sizeof(g_sVoZombieTankDefault); i++) PrecacheSound2(g_sVoZombieTankDefault[i]);
	for (int i = 0; i < sizeof(g_sVoZombieTankPain); i++) PrecacheSound2(g_sVoZombieTankPain[i]);
	for (int i = 0; i < sizeof(g_sVoZombieTankOnFire); i++) PrecacheSound2(g_sVoZombieTankOnFire[i]);
	for (int i = 0; i < sizeof(g_sVoZombieTankAttack); i++) PrecacheSound2(g_sVoZombieTankAttack[i]);
	for (int i = 0; i < sizeof(g_sVoZombieTankDeath); i++) PrecacheSound2(g_sVoZombieTankDeath[i]);
}

stock void PrecacheSound2(const char[] sSoundPath)
{
	if (strcmp(sSoundPath, "") == 0) return;
	
	PrecacheSound(sSoundPath, true);
	char s[PLATFORM_MAX_PATH];
	Format(s, sizeof(s), "sound/%s", sSoundPath);
	AddFileToDownloadsTable(s);
}

void PlaySoundAll(Sound nSound, float flTimer = 0.0)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			PlaySound(iClient, nSound, flTimer);
}

void PlaySound(int iClient, Sound nSound, float flTimer = 0.0)
{
	//Check if there music override first
	if (IsMusicOverrideOn()) return;
	if (g_bNoMusicForClient[iClient]) return;
	
	//We need to check if we are allowed to override current sound from the sound we going to use
	SoundType nType = GetSoundType(nSound);
	Sound nCurrentSound = GetCurrentSound(iClient);
	SoundType nCurrentType = GetSoundType(nCurrentSound);
	
	//If we want to play sound thats already playing, no point replaying it again
	if (nSound == nCurrentSound) return;
	
	//If the sound we want to play is greater or the same to current sound from enum SoundType, then we are allowed to override sound, otherwise return
	if (nType < nCurrentType) return;
	
	//End current sound before we start new sound
	EndSound(iClient);
	
	//Get sound we want to play
	char sPath[PLATFORM_MAX_PATH];
	GetRandomSound(nSound, sPath, sizeof(sPath));
	
	//Play sound to client
	if (IsClientInGame(iClient))
	{
		EmitSoundToClient(iClient, sPath);
		
		//Set sound global variables as that sound
		strcopy(g_sSound[iClient], sizeof(g_sSound), sPath);
		g_nSound[iClient] = nSound;
		
		//if timer specified, create timer to end sound
		if (flTimer > 0.0)
		{
			DataPack data;
			CreateDataTimer(flTimer, Timer_EndSound, data);
			data.WriteCell(iClient);
			data.WriteCell(nSound);
		}
	}
}

void SoundAttack(int iVictim, int iAttacker)
{
	TFClassType iClass = TF2_GetPlayerClass(iAttacker);
	bool bDramatic = (g_bBackstabbed[iVictim] || GetClientHealth(iVictim) <= 50);
	Sound nSound = Sound_None;
	float flDuration = 0.0;
	
	switch (iClass)
	{
		case TFClass_Scout, TFClass_Medic, TFClass_Sniper:
		{
			if (bDramatic)
			{
				nSound = SoundAttack_Drums;
				flDuration = 5.74;
			}
			else
			{
				nSound = SoundAttack_Trumpet;
				flDuration = 0.80;
			}
		}
		
		case TFClass_Soldier, TFClass_DemoMan, TFClass_Heavy:
		{
			if (bDramatic)
			{
				nSound = SoundAttack_Banjo;
				flDuration = 5.74;
			}
			else
			{
				nSound = SoundAttack_Snare;
				flDuration = 5.74;
			}
		}
		
		case TFClass_Pyro, TFClass_Engineer, TFClass_Spy:
		{
			if (bDramatic)
			{
				nSound = SoundAttack_SlayerMild;
				flDuration = 2.90;
			}
			else
			{
				nSound = SoundAttack_Slayer;
				flDuration = 5.74;
			}
		}
	}
	
	if (nSound == Sound_None) return;
	
	//Play sound to all nearby players
	float vecVictimOrigin[3], vecOrigin[3]; 
	GetClientAbsOrigin(iVictim, vecVictimOrigin);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
		{
			SoundType nCurrentSound = GetSoundType(GetCurrentSound(i));
			GetClientAbsOrigin(i, vecOrigin);
			if (GetVectorDistance(vecOrigin, vecVictimOrigin) <= 128.0	//Is survivor nearby victim
				&& nCurrentSound != SoundType_Attack)	//Is his current sound type not attack, so we dont override it as it would create spam
			{
				PlaySound(i, nSound, flDuration);
			}
		}
	}
}

void SoundTimer()	//This timer fires every 1 second from timer_main
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		Sound nCurrentSound = GetCurrentSound(iClient);
		SoundType nCurrentSoundType = GetSoundType(nCurrentSound);
		if (IsValidSurvivor(iClient))	//Zombies is already spooky enough, dont need to give him more spooky sounds
		{
			if (nCurrentSoundType == SoundType_None || (nCurrentSoundType == SoundType_Quiet && nCurrentSound != SoundQuiet_Rabies))
			{
				//We find nearest zombie to do heartbeat
				float flNearestDistance = 9999.0;
				float flDistance;
				
				float vecClientOrigin[3], vecOrigin[3]; 
				GetClientAbsOrigin(iClient, vecClientOrigin);
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidLivingZombie(i) && TF2_GetPlayerClass(i) != TFClass_Spy)	//Check if it a zombie and not spy, spy being sneaky boi
					{
						GetClientAbsOrigin(i, vecOrigin);
						flDistance = GetVectorDistance(vecClientOrigin, vecOrigin);
						if (flDistance < flNearestDistance)
							flNearestDistance = flDistance;
					}
				}
				
				//heartbeat based on how close zombie is
				Sound nSound;
				float flDuration;
				if (flNearestDistance <= 192.0)
				{
					nSound = SoundQuiet_Fast;
					flDuration = 0.9;
				}
				else if (flNearestDistance <= 384.0)
				{
					nSound = SoundQuiet_Medium;
					flDuration = 2.9;
				}
				else if (flNearestDistance <= 576.0)
				{
					nSound = SoundQuiet_Slow;
					flDuration = 5.9;
				}
				else	//No zombies nearby, lets play rabies instead
				{
					nSound = SoundQuiet_Rabies;
					flDuration = 39.9;
				}
				
				//If current sound is the same, no point playing it again
				if (nSound != nCurrentSound)
					PlaySound(iClient, nSound, flDuration);
			}
		}
	}
}

public Action Timer_EndSound(Handle timer, DataPack pack)
{
	pack.Reset();
	int iClient = pack.ReadCell();
	Sound nSound = pack.ReadCell();
	
	//Check if client current sound is still the same as specified in timer
	if (GetCurrentSound(iClient) == nSound)
		EndSound(iClient);
}

void EndSound(int iClient)
{
	//If there currently no sound on, no point doing it
	if (GetCurrentSound(iClient) == Sound_None) return;
	
	//End whatever current music from g_sSound to all clients
	if (IsClientInGame(iClient))
		StopSound(iClient, SNDCHAN_AUTO, g_sSound[iClient]);
	
	//Reset global variables
	strcopy(g_sSound[iClient], sizeof(g_sSound), "misc/null.wav"); //Having nothing here gives an "empty soundpath is not precached" warning to the server every time a music sound stops for each client
	g_nSound[iClient] = Sound_None;
}

void GetRandomSound(Sound nSound, char sPath[PLATFORM_MAX_PATH], int iLength)
{
	strcopy(sPath, iLength, "misc/null.wav"); //Having nothing here doesn't seem to matter, but let's keep it consistent
	
	switch (nSound)
	{
		case SoundQuiet_Slow:			strcopy(sPath, iLength, g_sSoundHeartSlow[GetRandomInt(0, sizeof(g_sSoundHeartSlow)-1)]);
		case SoundQuiet_Medium:			strcopy(sPath, iLength, g_sSoundHeartMedium[GetRandomInt(0, sizeof(g_sSoundHeartMedium)-1)]);
		case SoundQuiet_Fast:			strcopy(sPath, iLength, g_sSoundHeartFast[GetRandomInt(0, sizeof(g_sSoundHeartFast)-1)]);
		case SoundQuiet_Rabies:			strcopy(sPath, iLength, g_sSoundRabies[GetRandomInt(0, sizeof(g_sSoundRabies)-1)]);
		
		case SoundAttack_Drums:			strcopy(sPath, iLength, g_sSoundDrums[GetRandomInt(0, sizeof(g_sSoundDrums)-1)]);
		case SoundAttack_SlayerMild:	strcopy(sPath, iLength, g_sSoundSlayerMild[GetRandomInt(0, sizeof(g_sSoundSlayerMild)-1)]);
		case SoundAttack_Slayer:		strcopy(sPath, iLength, g_sSoundSlayer[GetRandomInt(0, sizeof(g_sSoundSlayer)-1)]);
		case SoundAttack_Trumpet:		strcopy(sPath, iLength, g_sSoundTrumpet[GetRandomInt(0, sizeof(g_sSoundTrumpet)-1)]);
		case SoundAttack_Snare:			strcopy(sPath, iLength, g_sSoundSnare[GetRandomInt(0, sizeof(g_sSoundSnare)-1)]);
		case SoundAttack_Banjo:			strcopy(sPath, iLength, g_sSoundBanjo[GetRandomInt(0, sizeof(g_sSoundBanjo)-1)]);
		
		case SoundEvent_Dead:			strcopy(sPath, iLength, g_sSoundDead[GetRandomInt(0, sizeof(g_sSoundDead)-1)]);
		case SoundEvent_Incoming:		strcopy(sPath, iLength, g_sSoundIncoming[GetRandomInt(0, sizeof(g_sSoundIncoming)-1)]);
		case SoundEvent_Drown:			strcopy(sPath, iLength, g_sSoundDrown[GetRandomInt(0, sizeof(g_sSoundDrown)-1)]);
		case SoundEvent_NearDeath:		strcopy(sPath, iLength, g_sSoundNearDeath[GetRandomInt(0, sizeof(g_sSoundNearDeath)-1)]);
		case SoundEvent_Jarate:			strcopy(sPath, iLength, g_sSoundJarate[GetRandomInt(0, sizeof(g_sSoundJarate)-1)]);
		
		case SoundMusic_Prepare:		strcopy(sPath, iLength, g_sSoundPrepare[GetRandomInt(0, sizeof(g_sSoundPrepare)-1)]);
		case SoundMusic_Tank:			strcopy(sPath, iLength, g_sSoundTank[GetRandomInt(0, sizeof(g_sSoundTank)-1)]);
		case SoundMusic_LastStand:		strcopy(sPath, iLength, g_sSoundLastStand[GetRandomInt(0, sizeof(g_sSoundLastStand)-1)]);
		case SoundMusic_ZombieWin:		strcopy(sPath, iLength, g_sSoundZombieWin[GetRandomInt(0, sizeof(g_sSoundZombieWin)-1)]);
		case SoundMusic_SurvivorWin:	strcopy(sPath, iLength, g_sSoundSurivourWin[GetRandomInt(0, sizeof(g_sSoundSurivourWin)-1)]);
	}
}

Sound GetCurrentSound(int iClient)
{
	return g_nSound[iClient];
}

SoundType GetSoundType(Sound nSound)
{
	if (nSound == Sound_None) return SoundType_None;
	else if (SoundQuiet_Min <= nSound <= SoundQuiet_Max) return SoundType_Quiet;
	else if (SoundAttack_Min <= nSound <= SoundAttack_Max) return SoundType_Attack;
	else if (SoundEvent_Min <= nSound <= SoundEvent_Max) return SoundType_Event;
	else if (SoundMusic_Min <= nSound <= SoundMusic_Max) return SoundType_Music;
	
	//Would be really strange if we reach that part
	return SoundType_None;
}

bool IsMusicOverrideOn()
{
	Action action = Forward_ShouldAllowMusicPlay();
	
	if (action == Plugin_Handled) return true;
	if (g_bNoMusic) return true;
	return false;
}

public Action Command_MusicToggle(int iClient, int iArgs)
{
	if (IsValidClient(iClient))
	{
		char sPreference[32];
		
		if (g_bNoMusicForClient[iClient])
		{
			g_bNoMusicForClient[iClient] = false;
			CPrintToChat(iClient, "{limegreen}Music has been enabled.");
		}
		else if (!g_bNoMusicForClient[iClient])
		{
			g_bNoMusicForClient[iClient] = true;
			CPrintToChat(iClient, "{limegreen}Music has been disabled.");
		}
		
		Format(sPreference, sizeof(sPreference), "%d", g_bNoMusicForClient[iClient]);
		SetClientCookie(iClient, g_cNoMusicForPlayer, sPreference);
	}
	
	return Plugin_Handled;
}
