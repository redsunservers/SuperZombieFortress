enum
{
	SOUND_TYPE_NONE = 0,
	SOUND_TYPE_QUIET,
	SOUND_TYPE_ATTACK,
	SOUND_TYPE_EVENT,
	SOUND_TYPE_MUSIC
};

enum
{
	SOUND_NONE = 0,
	
	SOUND_QUIET_NONE,
	SOUND_QUIET_SLOW,
	SOUND_QUIET_MEDIUM,
	SOUND_QUIET_FAST,
	SOUND_QUIET_RABIES,
	SOUND_QUIET_MAX,
	
	SOUND_ATTACK_NONE,
	SOUND_ATTACK_DRUMS,
	SOUND_ATTACK_SLAYERMILD,
	SOUND_ATTACK_SLAYER,
	SOUND_ATTACK_TRUMPET,
	SOUND_ATTACK_SNARE,
	SOUND_ATTACK_BANJO,
	SOUND_ATTACK_MAX,
	
	SOUND_EVENT_NONE,
	SOUND_EVENT_DEAD,
	SOUND_EVENT_INCOMING,
	SOUND_EVENT_DROWN,
	SOUND_EVENT_NEARDEATH,
	SOUND_EVENT_NEARDEATH2,
	SOUND_EVENT_JARATE,
	SOUND_EVENT_MAX,
	
	SOUND_MUSIC_NONE,
	SOUND_MUSIC_PREPARE,
	SOUND_MUSIC_TANK,
	SOUND_MUSIC_LASTSTAND,
	SOUND_MUSIC_ZOMBIEWIN,
	SOUND_MUSIC_SURVIVORWIN,
	SOUND_MUSIC_MAX,
	
	SOUND_MAX
};

char g_sSound[MAXPLAYERS+1][PLATFORM_MAX_PATH];
int g_iSound[MAXPLAYERS+1];
Handle g_hSoundTimer[MAXPLAYERS+1] = INVALID_HANDLE;
bool g_bNoMusicForClient[MAXPLAYERS+1];

/* QUIET SOUNDS */

char g_strSoundHeartSlow[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/heartbeat_slow.mp3"
};

char g_strSoundHeartMedium[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/heartbeat_medium.mp3"
};

char g_strSoundHeartFast[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/heartbeat_fast.mp3"
};

char g_strSoundRabies[][PLATFORM_MAX_PATH] =
{
	"left4fortress/rabies01.mp3"
	,"left4fortress/rabies02.mp3"
	,"left4fortress/rabies03.mp3"
	,"left4fortress/rabies04.mp3"
};

/* ZOMBIE ATTACK SOUNDS */

char g_strSoundDrums[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/drums01.mp3"
	,"left4fortress/zombat/drums02.mp3"
	,"left4fortress/zombat/drums03.mp3"
	,"left4fortress/zombat/drums04.mp3"
	,"left4fortress/zombat/drums05.mp3"
};

char g_strSoundSlayerMild[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/slayer_violin01.mp3"
	,"left4fortress/zombat/slayer_violin02.mp3"
	,"left4fortress/zombat/slayer_violin03.mp3"
};

char g_strSoundSlayer[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/slayer01.mp3"
};

char g_strSoundTrumpet[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/trumpet01.mp3"
	,"left4fortress/zombat/trumpet02.mp3"
	,"left4fortress/zombat/trumpet03.mp3"
	,"left4fortress/zombat/trumpet04.mp3"
	,"left4fortress/zombat/trumpet05.mp3"
	,"left4fortress/zombat/trumpet06.mp3"
};

char g_strSoundSnare[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/snare01.mp3"
	,"left4fortress/zombat/snare02.mp3"
};

char g_strSoundBanjo[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zombat/banjo01.mp3"
	,"left4fortress/zombat/banjo02.mp3"
	,"left4fortress/zombat/banjo03.mp3"
	,"left4fortress/zombat/banjo04.mp3"
	,"left4fortress/zombat/banjo05.mp3"
	,"left4fortress/zombat/banjo06.mp3"
	,"left4fortress/zombat/banjo07.mp3"
};

/* ZOMBIE EVENTS SOUND */

//Zombie killed survivor
char g_strSoundDead[][PLATFORM_MAX_PATH] =
{
	"left4fortress/theend.mp3"
};

//Frenzy
char g_strSoundIncoming[][PLATFORM_MAX_PATH] =
{
	"left4fortress/zincoming_mob.mp3"
};

//Goo
char g_strSoundDrown[][PLATFORM_MAX_PATH] =
{
	"left4fortress/drowning.mp3"
};

//Backstab
char g_strSoundNearDeath[][PLATFORM_MAX_PATH] =
{
	"left4fortress/iamsocold.mp3"
};

/* Unused
char g_strSoundNearDeath2[][PLATFORM_MAX_PATH] =
{
	"left4fortress/youaresocold.mp3"
};
*/
//Boomer Jarate
char g_strSoundJarate[][PLATFORM_MAX_PATH] =
{
	"left4fortress/jarate.mp3"
};

/* MUSIC */

char g_strSoundPrepare[][PLATFORM_MAX_PATH] =
{
	"left4fortress/prepare01.mp3"
	,"left4fortress/prepare02.mp3"
	,"left4fortress/prepare_rain.mp3"
};

char g_strSoundTank[][PLATFORM_MAX_PATH] =
{
	"left4fortress/drumandbasstank.mp3"
	,"left4fortress/metaltank.mp3"
	,"left4fortress/monsoontank.mp3"
	,"left4fortress/onebadtank.mp3"
	,"left4fortress/sundownertank.mp3"
};

char g_strSoundLastStand[][PLATFORM_MAX_PATH] =
{
	"left4fortress/skinonourteeth.mp3"
};

char g_strSoundZombieWin[][PLATFORM_MAX_PATH] =
{
	"left4fortress/death.mp3"
};

char g_strSoundSurivourWin[][PLATFORM_MAX_PATH] =
{
	"left4fortress/we_survived.mp3"
};

/* OTHER SOUNDS */

//Special infected spawned
char g_strSoundSpawnInfected[][PLATFORM_MAX_PATH] =
{
	""										//no special infected
	,""										//tank
	,"left4fortress/boomerbacterias.mp3"	//boomer
	,"left4fortress/chargerbacterias.mp3"	//charger
	,""										//kingpin, used to use smoker's bacteria (need new sound for kingpin)
	,"left4fortress/jockeybacterias.mp3"	//stalker
	,"left4fortress/hunterbacterias.mp3"	//hunter
	,"left4fortress/smokerbacterias.mp3"	//smoker
};

/* SOLDIER */
char g_strCarryVO_Soldier[][PLATFORM_MAX_PATH] =
{
    "vo/soldier_autocappedcontrolpoint01.mp3"
	,"vo/soldier_positivevocalization01.mp3"
	,"vo/soldier_positivevocalization02.mp3"
    ,"vo/soldier_positivevocalization03.mp3"
	,"vo/soldier_PickAxeTaunt01.mp3"
    ,"vo/soldier_PickAxeTaunt02.mp3"
    ,"vo/soldier_PickAxeTaunt03.mp3"
    ,"vo/soldier_PickAxeTaunt04.mp3"
    ,"vo/soldier_PickAxeTaunt05.mp3"
    ,"vo/soldier_laughevil01.mp3"
    ,"vo/soldier_laughevil03.mp3"
    ,"vo/soldier_go01.mp3"
    ,"vo/soldier_go02.mp3"
    ,"vo/soldier_battlecry02.mp3"
    ,"vo/soldier_battlecry06.mp3"
};

char g_strWeaponVO_Soldier[][PLATFORM_MAX_PATH] =
{
    "vo/soldier_mvm_loot_common01.mp3"
	,"vo/soldier_mvm_loot_common02.mp3"
	,"vo/soldier_mvm_loot_common03.mp3"
	,"vo/soldier_mvm_loot_rare01.mp3"
	,"vo/soldier_mvm_loot_rare02.mp3"
    ,"vo/soldier_mvm_loot_rare03.mp3"
    ,"vo/soldier_mvm_loot_rare04.mp3"
};

char g_strTankATK_Soldier[][PLATFORM_MAX_PATH] =
{
    "vo/soldier_mvm_tank_shooting01.mp3"
    ,"vo/soldier_mvm_tank_shooting02.mp3"
};


/* PYRO */
char g_strCarryVO_Pyro[][PLATFORM_MAX_PATH] =
{
    "vo/pyro_autocappedcontrolpoint01.mp3"
	,"vo/pyro_autocappedintelligence01.mp3"
	,"vo/pyro_go01.mp3"
    ,"vo/pyro_goodjob01.mp3"
    ,"vo/pyro_laughevil02.mp3"
    ,"vo/pyro_laughevil03.mp3"
    ,"vo/pyro_moveup01.mp3"
};

char g_strWeaponVO_Pyro[][PLATFORM_MAX_PATH] =
{
    "vo/pyro_battlecry01.mp3"
    ,"vo/pyro_battlecry02.mp3"
	,"vo/pyro_positivevocalization01.mp3"
};


/* Demoman -- does not have tank lines */
char g_strCarryVO_DemoMan[][PLATFORM_MAX_PATH] =
{
    "vo/demoman_go01.mp3"
	,"vo/demoman_go02.mp3"
	,"vo/demoman_go03.mp3"
	,"vo/demoman_helpmecapture02.mp3"
    ,"vo/demoman_helpmecapture03.mp3"
    ,"vo/demoman_laughevil01.mp3"
    ,"vo/demoman_laughevil03.mp3"
    ,"vo/demoman_laughevil05.mp3"
    ,"vo/demoman_laughshort02.mp3"
    ,"vo/demoman_laughshort04.mp3"
    ,"vo/demoman_laughshort06.mp3"
    ,"vo/demoman_gibberish02.mp3"
	,"vo/demoman_gibberish08.mp3"
    ,"vo/demoman_gibberish13.mp3"
};

char g_strWeaponVO_DemoMan[][PLATFORM_MAX_PATH] =
{
    "vo/demoman_mvm_loot_common01.mp3"
    ,"vo/demoman_mvm_loot_common02.mp3"
    ,"vo/demoman_mvm_loot_common03.mp3"
    ,"vo/demoman_mvm_loot_common04.mp3"
    ,"vo/demoman_mvm_loot_godlike01.mp3"
    ,"vo/demoman_mvm_loot_rare01.mp3"
    ,"vo/demoman_mvm_loot_rare02.mp3"
};


/* Engineer */
char g_strCarryVO_Engineer[][PLATFORM_MAX_PATH] =
{
    "vo/engineer_autocappedcontrolpoint01.mp3"
	,"vo/engineer_autocappedcontrolpoint02.mp3"
    ,"vo/engineer_autocappedintelligence01.mp3"
    ,"vo/engineer_autocappedintelligence02.mp3"
    ,"vo/engineer_autocappedintelligence03.mp3"
    ,"vo/engineer_cheers04.mp3"
    ,"vo/engineer_laughevil01.mp3"
    ,"vo/engineer_laughevil04.mp3"
    ,"vo/engineer_laughevil06.mp3"
};

char g_strWeaponVO_Engineer[][PLATFORM_MAX_PATH] =
{
    "vo/engineer_mvm_loot_common01.mp3"
    ,"vo/engineer_mvm_loot_common02.mp3"
    ,"vo/engineer_mvm_loot_godlike01.mp3"
    ,"vo/engineer_mvm_loot_godlike02.mp3"
    ,"vo/engineer_mvm_loot_godlike03.mp3"
    ,"vo/engineer_mvm_loot_rare01.mp3"
    ,"vo/engineer_mvm_loot_rare02.mp3"
    ,"vo/engineer_mvm_loot_rare03.mp3"
    ,"vo/engineer_mvm_loot_rare04.mp3"
};

char g_strTankATK_Engineer[][PLATFORM_MAX_PATH] =
{
    "vo/engineer_mvm_tank_shooting01.mp3"
    ,"vo/engineer_meleedare01.mp3"
};



/* Medic */
char g_strCarryVO_Medic[][PLATFORM_MAX_PATH] =
{
    "vo/medic_go01.mp3"
    ,"vo/medic_go05.mp3"
    ,"vo/medic_goodjob02.mp3"
    ,"vo/medic_laughevil01.mp3"
    ,"vo/medic_laughevil03.mp3"
    ,"vo/medic_positivevocalization03.mp3"
    ,"vo/medic_specialcompleted04.mp3"
    ,"vo/medic_specialcompleted07.mp3"
    ,"vo/medic_yes03.mp3"
};

char g_strWeaponVO_Medic[][PLATFORM_MAX_PATH] =
{
    "vo/medic_mvm_loot_common01.mp3"
    ,"vo/medic_mvm_loot_common02.mp3"
    ,"vo/medic_mvm_loot_common03.mp3"
    ,"vo/medic_mvm_loot_rare02.mp3"
    ,"vo/medic_mvm_loot_godlike01.mp3"
    ,"vo/medic_mvm_loot_godlike02.mp3"
    ,"vo/medic_mvm_loot_godlike03.mp3"
    ,"vo/medic_specialcompleted02.mp3"
    ,"vo/medic_specialcompleted03.mp3"
};

char g_strTankATK_Medic[][PLATFORM_MAX_PATH] =
{
    "vo/medic_mvm_tank_shooting01.mp3"
    ,"vo/medic_mvm_tank_shooting02.mp3"
};


/* Sniper -- does not have tank lines */
char g_strCarryVO_Sniper[][PLATFORM_MAX_PATH] =
{
    "vo/sniper_autocappedcontrolpoint01.mp3"
    ,"vo/sniper_autocappedcontrolpoint02.mp3"
    ,"vo/sniper_autocappedcontrolpoint03.mp3"
    ,"vo/sniper_autocappedintelligence01.mp3"
    ,"vo/sniper_autocappedintelligence02.mp3"
    ,"vo/sniper_autocappedintelligence04.mp3"
    ,"vo/sniper_autocappedintelligence05.mp3"
    ,"vo/sniper_award01.mp3"
    ,"vo/sniper_award06.mp3"
    ,"vo/sniper_award07.mp3"
    ,"vo/sniper_award08.mp3"
    ,"vo/sniper_award11.mp3"
    ,"vo/sniper_award12.mp3"
    ,"vo/sniper_award13.mp3"
    ,"vo/sniper_battlecry02.mp3"
    ,"vo/sniper_go03.mp3"
    ,"vo/sniper_helpmecapture01.mp3"
    ,"vo/sniper_laughevil01.mp3"
    ,"vo/sniper_laughevil02.mp3"
    ,"vo/sniper_moveup01.mp3"
    ,"vo/sniper_specialweapon02.mp3"
    ,"vo/sniper_specialweapon05.mp3"
    ,"vo/sniper_specialweapon07.mp3"
    ,"vo/sniper_specialweapon09.mp3"
};

char g_strWeaponVO_Sniper[][PLATFORM_MAX_PATH] =
{
    "vo/sniper_specialweapon01.mp3"
    ,"vo/sniper_specialweapon02.mp3"
    ,"vo/sniper_specialweapon03.mp3"
    ,"vo/sniper_specialweapon04.mp3"
    ,"vo/sniper_specialweapon05.mp3"
    ,"vo/sniper_specialweapon06.mp3"
    ,"vo/sniper_specialweapon07.mp3"
    ,"vo/sniper_specialweapon08.mp3"
    ,"vo/sniper_specialweapon09.mp3"
};

char g_strZombieVO[][PLATFORM_MAX_PATH] =
{
    "been_shot_12"
    ,"been_shot_13"
    ,"been_shot_14"
    ,"been_shot_18"
    ,"been_shot_19"
    ,"been_shot_20"
    ,"been_shot_21"
    ,"been_shot_22"
    ,"been_shot_24"
    ,"charger_charge_01"
    ,"charger_charge_02"
    ,"charger_pain_01"
    ,"charger_pain_02"
    ,"charger_pain_03"
    ,"charger_spotprey_01"
    ,"charger_spotprey_02"
    ,"charger_spotprey_03"
    ,"death_22"
    ,"death_23"
    ,"death_24"
    ,"death_25"
    ,"death_26"
    ,"death_27"
    ,"death_28"
    ,"death_29"
    ,"hunter_attackmix_01"
    ,"hunter_attackmix_02"
    ,"hunter_attackmix_03"
    ,"hunter_pain_12"
    ,"hunter_pain_13"
    ,"hunter_pain_14"
    ,"hunter_stalk_04"
    ,"hunter_stalk_05"
    ,"hunter_stalk_06"
    ,"idle_breath_01"
    ,"idle_breath_02"
    ,"idle_breath_03"
    ,"idle_breath_04"
    ,"male_boomer_disruptvomit_05"
    ,"male_boomer_disruptvomit_06"
    ,"male_boomer_disruptvomit_07"
    ,"male_boomer_lurk_02"
    ,"male_boomer_lurk_03"
    ,"male_boomer_lurk_04"
    ,"male_boomer_pain_1"
    ,"male_boomer_pain_2"
    ,"male_boomer_pain_3"
    ,"mumbling01"
    ,"mumbling02"
    ,"mumbling03"
    ,"mumbling04"
    ,"mumbling05"
    ,"mumbling06"
    ,"mumbling07"
    ,"mumbling08"
    ,"rage_at_victim21"
    ,"rage_at_victim22"
    ,"rage_at_victim25"
    ,"rage_at_victim26"
    ,"shoved_1"
    ,"shoved_2"
    ,"shoved_3"
    ,"shoved_4"
    ,"smoker_lurk_11"
    ,"smoker_lurk_12"
    ,"smoker_lurk_13"
    ,"smoker_pain_02"
    ,"smoker_pain_03"
    ,"smoker_pain_04"
    ,"tank_attack_01"
    ,"tank_attack_02"
    ,"tank_attack_03"
    ,"tank_attack_04"
    ,"tank_death_01"
    ,"tank_death_02"
    ,"tank_death_03"
    ,"tank_death_04"
    ,"tank_fire_02"
    ,"tank_fire_03"
    ,"tank_fire_04"
    ,"tank_fire_05"
    ,"tank_pain_01"
    ,"tank_pain_02"
    ,"tank_pain_03"
    ,"tank_pain_04"
    ,"tank_voice_01"
    ,"tank_voice_02"
    ,"tank_voice_03"
    ,"tank_voice_04"
};

void SoundPrecache()
{    
    //For left4fortress sounds, we need to use both precache and add to download table to each sounds
	for (int i = 0; i < sizeof(g_strSoundHeartSlow); i++) PrecacheSound2(g_strSoundHeartSlow[i]);
	for (int i = 0; i < sizeof(g_strSoundHeartMedium); i++) PrecacheSound2(g_strSoundHeartMedium[i]);
	for (int i = 0; i < sizeof(g_strSoundHeartFast); i++) PrecacheSound2(g_strSoundHeartFast[i]);
	for (int i = 0; i < sizeof(g_strSoundRabies); i++) PrecacheSound2(g_strSoundRabies[i]);
	
	for (int i = 0; i < sizeof(g_strSoundDrums); i++) PrecacheSound2(g_strSoundDrums[i]);
	for (int i = 0; i < sizeof(g_strSoundSlayerMild); i++) PrecacheSound2(g_strSoundSlayerMild[i]);
	for (int i = 0; i < sizeof(g_strSoundSlayer); i++) PrecacheSound2(g_strSoundSlayer[i]);
	for (int i = 0; i < sizeof(g_strSoundTrumpet); i++) PrecacheSound2(g_strSoundTrumpet[i]);
	for (int i = 0; i < sizeof(g_strSoundSnare); i++) PrecacheSound2(g_strSoundSnare[i]);
	for (int i = 0; i < sizeof(g_strSoundBanjo); i++) PrecacheSound2(g_strSoundBanjo[i]);
	
	for (int i = 0; i < sizeof(g_strSoundDead); i++) PrecacheSound2(g_strSoundDead[i]);
	for (int i = 0; i < sizeof(g_strSoundIncoming); i++) PrecacheSound2(g_strSoundIncoming[i]);
	for (int i = 0; i < sizeof(g_strSoundDrown); i++) PrecacheSound2(g_strSoundDrown[i]);
	for (int i = 0; i < sizeof(g_strSoundNearDeath); i++) PrecacheSound2(g_strSoundNearDeath[i]);
	//for (int i = 0; i < sizeof(g_strSoundNearDeath2); i++) PrecacheSound2(g_strSoundNearDeath2[i]);
	for (int i = 0; i < sizeof(g_strSoundJarate); i++) PrecacheSound2(g_strSoundJarate[i]);
	
	for (int i = 0; i < sizeof(g_strSoundPrepare); i++) PrecacheSound2(g_strSoundPrepare[i]);
	for (int i = 0; i < sizeof(g_strSoundTank); i++) PrecacheSound2(g_strSoundTank[i]);
	for (int i = 0; i < sizeof(g_strSoundLastStand); i++) PrecacheSound2(g_strSoundLastStand[i]);
	for (int i = 0; i < sizeof(g_strSoundZombieWin); i++) PrecacheSound2(g_strSoundZombieWin[i]);
	for (int i = 0; i < sizeof(g_strSoundSurivourWin); i++) PrecacheSound2(g_strSoundSurivourWin[i]);
	
	for (int i = 0; i < sizeof(g_strSoundSpawnInfected); i++) PrecacheSound2(g_strSoundSpawnInfected[i]);
	
	//---//
	
	for (int i = 0; i < sizeof(g_strCarryVO_Soldier); i++) PrecacheSound(g_strCarryVO_Soldier[i]);
	for (int i = 0; i < sizeof(g_strWeaponVO_Soldier); i++) PrecacheSound(g_strWeaponVO_Soldier[i]);
	for (int i = 0; i < sizeof(g_strTankATK_Soldier); i++) PrecacheSound(g_strTankATK_Soldier[i]);
	
	for (int i = 0; i < sizeof(g_strCarryVO_Pyro); i++) PrecacheSound(g_strCarryVO_Pyro[i]);
	for (int i = 0; i < sizeof(g_strWeaponVO_Pyro); i++) PrecacheSound(g_strWeaponVO_Pyro[i]);
	
	for (int i = 0; i < sizeof(g_strCarryVO_DemoMan); i++) PrecacheSound(g_strCarryVO_DemoMan[i]);
	for (int i = 0; i < sizeof(g_strWeaponVO_DemoMan); i++) PrecacheSound(g_strWeaponVO_DemoMan[i]);
	
	for (int i = 0; i < sizeof(g_strCarryVO_Engineer); i++) PrecacheSound(g_strCarryVO_Engineer[i]);
	for (int i = 0; i < sizeof(g_strWeaponVO_Engineer); i++) PrecacheSound(g_strWeaponVO_Engineer[i]);
	for (int i = 0; i < sizeof(g_strTankATK_Engineer); i++) PrecacheSound(g_strTankATK_Engineer[i]);
	
	for (int i = 0; i < sizeof(g_strCarryVO_Medic); i++) PrecacheSound(g_strCarryVO_Medic[i]);
	for (int i = 0; i < sizeof(g_strWeaponVO_Medic); i++) PrecacheSound(g_strWeaponVO_Medic[i]);
	for (int i = 0; i < sizeof(g_strTankATK_Medic); i++) PrecacheSound(g_strTankATK_Medic[i]);
	
	for (int i = 0; i < sizeof(g_strCarryVO_Sniper); i++) PrecacheSound(g_strCarryVO_Sniper[i]);
	for (int i = 0; i < sizeof(g_strWeaponVO_Sniper); i++) PrecacheSound(g_strWeaponVO_Sniper[i]);
	
	for (int i = 0; i < sizeof(g_strZombieVO); i++)
    {
        char strPath[96];
        Format(strPath, sizeof(strPath), "left4fortress/zombie_vo/%s.mp3", g_strZombieVO[i]);
        PrecacheSound2(strPath);
    }
}

stock void PrecacheSound2(const char[] sSoundPath)
{
	if (strcmp(sSoundPath, "") == 0) return;
	
	PrecacheSound(sSoundPath, true);
	char s[PLATFORM_MAX_PATH];
	Format(s, sizeof(s), "sound/%s", sSoundPath);
	AddFileToDownloadsTable(s);
}

void PlaySoundAll(int iSound, float flTimer = 0.0)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			PlaySound(i, iSound, flTimer);
}

void PlaySound(int iClient, int iSound, float flTimer = 0.0)
{
	//Check if there music override first
	if (IsMusicOverrideOn()) return;
	if (g_bNoMusicForClient[iClient]) return;
	
	//We need to check if we are allowed to override current sound from the sound we going to use
	int iType = GetSoundType(iSound);
	int iCurrentSound = GetCurrentSound(iClient);
	int iCurrentType = GetSoundType(iCurrentSound);
	
	//If we want to play sound thats already playing, no point replaying it again
	if (iSound == iCurrentSound) return;
	
	//If the sound we want to play is greater or the same to current sound from enum SOUND_TYPE, then we are allowed to override sound, otherwise return
	if (iType < iCurrentType) return;
	
	//End current sound before we start new sound
	EndSound(iClient);
	
	//Get sound we want to play
	char strPath[PLATFORM_MAX_PATH];
	GetRandomSound(iSound, strPath, sizeof(strPath));
		
	//Play sound to client
	if (IsClientInGame(iClient))
	{
		EmitSoundToClient(iClient, strPath);
		
		//Set sound global variables as that sound
		strcopy(g_sSound[iClient], sizeof(g_sSound), strPath);
		g_iSound[iClient] = iSound;
		
		//if timer specified, create timer to end sound
		if (flTimer > 0.0)
		{
			if (g_hSoundTimer[iClient] != INVALID_HANDLE)
			{
				//Not sure if this is needed
				g_hSoundTimer[iClient] = INVALID_HANDLE;
			}
			
			DataPack pack;
			g_hSoundTimer[iClient] = CreateDataTimer(flTimer, Timer_EndSound, pack);
			pack.WriteCell(iClient);
			pack.WriteCell(iSound);
		}
	}
}

void SoundAttack(int iVictim, int iAttacker)
{
	TFClassType iClass = TF2_GetPlayerClass(iAttacker);
	bool bDramatic = (g_bBackstabbed[iVictim] || GetClientHealth(iVictim) <= 50);
	int iSound = SOUND_NONE;
	float flDuration = 0.0;
	
	if (iClass == TFClass_Scout)
	{
		if (bDramatic)
		{
			iSound = SOUND_ATTACK_DRUMS;
			flDuration = 5.74;
		}
		else
		{
			iSound = SOUND_ATTACK_TRUMPET;
			flDuration = 0.80;
		}
	}
	else if (iClass == TFClass_Heavy)
	{
		if (bDramatic)
		{
			iSound = SOUND_ATTACK_BANJO;
			flDuration = 5.74;
		}
		else
		{
			iSound = SOUND_ATTACK_SNARE;
			flDuration = 5.74;
		}
	}
	else if (iClass == TFClass_Spy)
	{
		if (bDramatic)
		{
			iSound = SOUND_ATTACK_SLAYERMILD;
			flDuration = 2.90;
		}
		else
		{
			iSound = SOUND_ATTACK_SLAYER;
			flDuration = 5.74;
		}
	}
	
	if (iSound == SOUND_NONE) return;
	
	//Play sound to all nearby players
	float vecVictimOrigin[3], vecOrigin[3]; 
	GetClientAbsOrigin(iVictim, vecVictimOrigin);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
		{
			int iCurrentSound = GetSoundType(GetCurrentSound(i));
			GetClientAbsOrigin(i, vecOrigin);
			if (GetVectorDistance(vecOrigin, vecVictimOrigin) <= 128.0	//Is survivor nearby victim
				&& iCurrentSound != SOUND_TYPE_ATTACK)	//Is his current sound type not attack, so we dont override it as it would create spam
			{
				PlaySound(i, iSound, flDuration);
			}
		}
	}
}

void SoundTimer()	//This timer fires every 1 second from timer_main
{
	for (int i = 1; i <= MaxClients; i++)
	{
		int iCurrentSound = GetCurrentSound(i);
		int iCurrentSoundType = GetSoundType(iCurrentSound);
		if (IsValidSurvivor(i))	//Zombies is already spooky enough, dont need to give him more spooky sounds
		{
			if (iCurrentSoundType == SOUND_TYPE_NONE || (iCurrentSoundType == SOUND_TYPE_QUIET && iCurrentSound != SOUND_QUIET_RABIES))
			{
				//We find nearest zombie to do heartbeat
				float flNearestDistance = 9999.0;
				float flDistance;
				
				float vecClientOrigin[3], vecOrigin[3]; 
				GetClientAbsOrigin(i, vecClientOrigin);
				
				for (int j = 1; j <= MaxClients; j++)
				{
					if (IsValidLivingZombie(j) && TF2_GetPlayerClass(j) != TFClass_Spy)	//Check if it a zombie and not spy, spy being sneaky boi
					{
						GetClientAbsOrigin(j, vecOrigin);
						flDistance = GetVectorDistance(vecClientOrigin, vecOrigin);
						if (flDistance < flNearestDistance)
							flNearestDistance = flDistance;
					}
				}
				
				//heartbeat based on how close zombie is
				int iSound;
				float flDuration;
				if (flNearestDistance <= 192.0)
				{
					iSound = SOUND_QUIET_FAST;
					flDuration = 0.9;
				}
				else if (flNearestDistance <= 384.0)
				{
					iSound = SOUND_QUIET_MEDIUM;
					flDuration = 2.9;
				}
				else if (flNearestDistance <= 576.0)
				{
					iSound = SOUND_QUIET_SLOW;
					flDuration = 5.9;
				}
				else	//No zombies nearby, lets play rabies instead
				{
					iSound = SOUND_QUIET_RABIES;
					flDuration = 39.9;
				}
				
				//If current sound is the same, no point playing it again
				if (iSound != iCurrentSound)
					PlaySound(i, iSound, flDuration);
			}
		}
	}
}

public Action Timer_EndSound(Handle timer, DataPack pack)
{
	pack.Reset();
	int iClient = pack.ReadCell();
	int iSound = pack.ReadCell();
	
	//Check if client current sound is still the same as specified in timer
	if (GetCurrentSound(iClient) == iSound)
		EndSound(iClient);
}

void EndSound(int iClient)
{
	//If there currently no sound on, no point doing it
	if (GetSoundType(iClient) == SOUND_TYPE_NONE) return;
	
	//End whatever current music from g_sSound to all clients
	if (IsClientInGame(iClient))
		StopSound(iClient, SNDCHAN_AUTO, g_sSound[iClient]);
	
	//Reset global variables
	strcopy(g_sSound[iClient], sizeof(g_sSound), "");
	g_iSound[iClient] = SOUND_NONE;
}

void GetRandomSound(int iSound, char strPath[PLATFORM_MAX_PATH], int iLength)
{
	strcopy(strPath, iLength, "");
	
	switch (iSound)
	{
		case SOUND_QUIET_SLOW:			strcopy(strPath, iLength, g_strSoundHeartSlow[GetRandomInt(0, sizeof(g_strSoundHeartSlow)-1)]);
		case SOUND_QUIET_MEDIUM:		strcopy(strPath, iLength, g_strSoundHeartMedium[GetRandomInt(0, sizeof(g_strSoundHeartMedium)-1)]);
		case SOUND_QUIET_FAST:			strcopy(strPath, iLength, g_strSoundHeartFast[GetRandomInt(0, sizeof(g_strSoundHeartFast)-1)]);
		case SOUND_QUIET_RABIES:		strcopy(strPath, iLength, g_strSoundRabies[GetRandomInt(0, sizeof(g_strSoundRabies)-1)]);
		
		case SOUND_ATTACK_DRUMS:		strcopy(strPath, iLength, g_strSoundDrums[GetRandomInt(0, sizeof(g_strSoundDrums)-1)]);
		case SOUND_ATTACK_SLAYERMILD:	strcopy(strPath, iLength, g_strSoundSlayerMild[GetRandomInt(0, sizeof(g_strSoundSlayerMild)-1)]);
		case SOUND_ATTACK_SLAYER:		strcopy(strPath, iLength, g_strSoundSlayer[GetRandomInt(0, sizeof(g_strSoundSlayer)-1)]);
		case SOUND_ATTACK_TRUMPET:		strcopy(strPath, iLength, g_strSoundTrumpet[GetRandomInt(0, sizeof(g_strSoundTrumpet)-1)]);
		case SOUND_ATTACK_SNARE:		strcopy(strPath, iLength, g_strSoundSnare[GetRandomInt(0, sizeof(g_strSoundSnare)-1)]);
		case SOUND_ATTACK_BANJO:		strcopy(strPath, iLength, g_strSoundBanjo[GetRandomInt(0, sizeof(g_strSoundBanjo)-1)]);
		
		case SOUND_EVENT_DEAD:			strcopy(strPath, iLength, g_strSoundDead[GetRandomInt(0, sizeof(g_strSoundDead)-1)]);
		case SOUND_EVENT_INCOMING:		strcopy(strPath, iLength, g_strSoundIncoming[GetRandomInt(0, sizeof(g_strSoundIncoming)-1)]);
		case SOUND_EVENT_DROWN:			strcopy(strPath, iLength, g_strSoundDrown[GetRandomInt(0, sizeof(g_strSoundDrown)-1)]);
		case SOUND_EVENT_NEARDEATH:		strcopy(strPath, iLength, g_strSoundNearDeath[GetRandomInt(0, sizeof(g_strSoundNearDeath)-1)]);
		//case SOUND_EVENT_NEARDEATH2:	strcopy(strPath, iLength, g_strSoundNearDeath2[GetRandomInt(0, sizeof(g_strSoundNearDeath2)-1)]);
		case SOUND_EVENT_JARATE:		strcopy(strPath, iLength, g_strSoundJarate[GetRandomInt(0, sizeof(g_strSoundJarate)-1)]);
		
		case SOUND_MUSIC_PREPARE:		strcopy(strPath, iLength, g_strSoundPrepare[GetRandomInt(0, sizeof(g_strSoundPrepare)-1)]);
		case SOUND_MUSIC_TANK:			strcopy(strPath, iLength, g_strSoundTank[GetRandomInt(0, sizeof(g_strSoundTank)-1)]);
		case SOUND_MUSIC_LASTSTAND:		strcopy(strPath, iLength, g_strSoundLastStand[GetRandomInt(0, sizeof(g_strSoundLastStand)-1)]);
		case SOUND_MUSIC_ZOMBIEWIN:		strcopy(strPath, iLength, g_strSoundZombieWin[GetRandomInt(0, sizeof(g_strSoundZombieWin)-1)]);
		case SOUND_MUSIC_SURVIVORWIN:	strcopy(strPath, iLength, g_strSoundSurivourWin[GetRandomInt(0, sizeof(g_strSoundSurivourWin)-1)]);
	}
}

int GetCurrentSound(int iClient)
{
	return g_iSound[iClient];
}

int GetSoundType(int iSound)
{
	if (iSound == SOUND_NONE) return SOUND_TYPE_NONE;
	else if (iSound >= SOUND_QUIET_NONE && iSound <= SOUND_QUIET_MAX) return SOUND_TYPE_QUIET;
	else if (iSound >= SOUND_ATTACK_NONE && iSound <= SOUND_ATTACK_MAX) return SOUND_TYPE_ATTACK;
	else if (iSound >= SOUND_EVENT_NONE && iSound <= SOUND_EVENT_MAX) return SOUND_TYPE_EVENT;
	else if (iSound >= SOUND_MUSIC_NONE && iSound <= SOUND_MUSIC_MAX) return SOUND_TYPE_MUSIC;
	
	//Would be really strange if we reach that part
	return -1;
}

bool IsMusicOverrideOn()
{
	Action action = Plugin_Continue;
	Call_StartForward(g_hForwardAllowMusicPlay);
	Call_Finish(action);
	
	if (action == Plugin_Handled) return true;
	if (g_bNoMusic) return true;
	return false;
}

public Action MusicToggle(int iClient, int iArgs)
{
	if (IsValidClient(iClient))
	{
		char cPreference[32];

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

		Format(cPreference, sizeof(cPreference), "%i", g_bNoMusicForClient[iClient]);
		SetClientCookie(iClient, cookieNoMusicForPlayer, cPreference);
	}

	return Plugin_Handled;
}