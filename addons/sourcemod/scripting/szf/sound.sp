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

char g_sSoundRabies[][PLATFORM_MAX_PATH] =
{
	"szf/music/contagion/l4d2_rabies_01.wav",
	"szf/music/contagion/l4d2_rabies_02.wav",
	"szf/music/contagion/l4d2_rabies_03.wav",
	"szf/music/contagion/l4d2_rabies_04.wav"
};

/* ZOMBIE ATTACK SOUNDS */

char g_sSoundDrums[][PLATFORM_MAX_PATH] =
{
	"szf/music/zombat/horde/drums01b.wav",
	"szf/music/zombat/horde/drums01c.wav",
	"szf/music/zombat/horde/drums01d.wav",
	"szf/music/zombat/horde/drums02c.wav",
	"szf/music/zombat/horde/drums02d.wav",
	"szf/music/zombat/horde/drums03a.wav",
	"szf/music/zombat/horde/drums03b.wav",
	"szf/music/zombat/horde/drums3c.wav",
	"szf/music/zombat/horde/drums3d.wav",
	"szf/music/zombat/horde/drums3f.wav",
	"szf/music/zombat/horde/drums5b.wav",
	"szf/music/zombat/horde/drums5c.wav",
	"szf/music/zombat/horde/drums5d.wav",
	"szf/music/zombat/horde/drums5e.wav",
	"szf/music/zombat/horde/drums7a.wav",
	"szf/music/zombat/horde/drums7b.wav",
	"szf/music/zombat/horde/drums7c.wav",
	"szf/music/zombat/horde/drums08a.wav",
	"szf/music/zombat/horde/drums08b.wav",
	"szf/music/zombat/horde/drums08e.wav",
	"szf/music/zombat/horde/drums08f.wav",
	"szf/music/zombat/horde/drums8b.wav",
	"szf/music/zombat/horde/drums8c.wav",
	"szf/music/zombat/horde/drums09c.wav",
	"szf/music/zombat/horde/drums09d.wav",
	"szf/music/zombat/horde/drums10b.wav",
	"szf/music/zombat/horde/drums10c.wav",
	"szf/music/zombat/horde/drums11c.wav",
	"szf/music/zombat/horde/drums11d.wav"
};

char g_sSoundSlayerMild[][PLATFORM_MAX_PATH] =
{
	"szf/music/zombat/slayer/fiddle/violin_slayer_01_01a.wav",
	"szf/music/zombat/slayer/fiddle/violin_slayer_01_01b.wav",
	"szf/music/zombat/slayer/fiddle/violin_slayer_01_01c.wav",
	"szf/music/zombat/slayer/fiddle/violin_slayer_01_01d.wav",
	"szf/music/zombat/slayer/fiddle/violin_slayer_02_01a.wav",
	"szf/music/zombat/slayer/fiddle/violin_slayer_02_01b.wav",
	"szf/music/zombat/slayer/fiddle/violin_slayer_02_01c.wav",
	"szf/music/zombat/slayer/fiddle/violin_slayer_02_01d.wav",
	"szf/music/zombat/slayer/fiddle/violin_slayer_02_01e.wav"
};

char g_sSoundSlayer[][PLATFORM_MAX_PATH] =
{
	"szf/music/zombat/slayer/lectric/slayer_01a.wav"
};

char g_sSoundTrumpet[][PLATFORM_MAX_PATH] =
{
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_01.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_02.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_03.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_04.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_05.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_06.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_07.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_08.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_09.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_10.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_11.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_12.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_13.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_14.wav",
	"szf/music/zombat/danger/trumpet/trumpet_danger_02_15.wav"
};

char g_sSoundSnare[][PLATFORM_MAX_PATH] =
{
	"szf/music/zombat/snare_horde_01_01a.wav",
	"szf/music/zombat/snare_horde_01_01b.wav"
};

char g_sSoundBanjo[][PLATFORM_MAX_PATH] =
{
	"szf/music/zombat/danger/banjo/banjo_01a_01.wav",
	"szf/music/zombat/danger/banjo/banjo_01a_02.wav",
	"szf/music/zombat/danger/banjo/banjo_01a_03.wav",
	"szf/music/zombat/danger/banjo/banjo_01a_04.wav",
	"szf/music/zombat/danger/banjo/banjo_01a_05.wav",
	"szf/music/zombat/danger/banjo/banjo_01a_06.wav",
	"szf/music/zombat/danger/banjo/banjo_01b_01.wav",
	"szf/music/zombat/danger/banjo/banjo_01b_03.wav",
	"szf/music/zombat/danger/banjo/banjo_01b_04.wav",
	"szf/music/zombat/danger/banjo/banjo_02_01.wav",
	"szf/music/zombat/danger/banjo/banjo_02_02.wav",
	"szf/music/zombat/danger/banjo/banjo_02_03.wav",
	"szf/music/zombat/danger/banjo/banjo_02_04.wav",
	"szf/music/zombat/danger/banjo/banjo_02_05.wav",
	"szf/music/zombat/danger/banjo/banjo_02_06.wav",
	"szf/music/zombat/danger/banjo/banjo_02_07.wav",
	"szf/music/zombat/danger/banjo/banjo_02_08.wav",
	"szf/music/zombat/danger/banjo/banjo_02_09.wav",
	"szf/music/zombat/danger/banjo/banjo_02_10.wav",
	"szf/music/zombat/danger/banjo/banjo_02_13.wav",
	"szf/music/zombat/danger/banjo/banjo_02_14.wav",
	"szf/music/zombat/danger/banjo/banjo_02_15.wav"
};

/* ZOMBIE EVENTS SOUND */

//Zombie killed survivor
char g_sSoundDead[][PLATFORM_MAX_PATH] =
{
	"szf/music/terror/theend.wav"
};

//Frenzy
char g_sSoundIncoming[][PLATFORM_MAX_PATH] =
{
	"szf/npc/mega_mob/mega_mob_incoming.wav"
};

//Backstab
char g_sSoundNearDeath[][PLATFORM_MAX_PATH] =
{
	"szf/music/terror/iamsocold.wav"
};

//Boomer Jarate
char g_sSoundJarate[][PLATFORM_MAX_PATH] =
{
	"szf/music/terror/pukricide.wav"
};

/* MUSIC */

char g_sSoundPrepare[][PLATFORM_MAX_PATH] =
{
	"szf/music/stmusic/deadeasy.wav",
	"szf/music/stmusic/deathisacarousel.wav",
	"szf/music/stmusic/diedonthebayou.wav",
	"szf/music/stmusic/osweetdeath.wav",
	"szf/music/stmusic/southofhuman.wav"
};

char g_sSoundTank[][PLATFORM_MAX_PATH] =
{
	"szf/music/tank/midnighttank.wav",
	"szf/music/tank/onebadtank.wav",
	"szf/music/tank/taank.wav"
};

char g_sSoundLastStand[][PLATFORM_MAX_PATH] =
{
	"szf/music/the_end/skinonourteeth.wav"
};

char g_sSoundZombieWin[][PLATFORM_MAX_PATH] =
{
	"szf/music/undeath/death.wav"
};

char g_sSoundSurivourWin[][PLATFORM_MAX_PATH] =
{
	"szf/music/safe/themonsterswithout.wav"
};


/* Common Infected */
char g_sVoZombieCommonDefault[][PLATFORM_MAX_PATH] =
{
	"szf/npc/infected/idle/breathing/idle_breath_01.wav",
	"szf/npc/infected/idle/breathing/idle_breath_02.wav",
	"szf/npc/infected/idle/breathing/idle_breath_03.wav",
	"szf/npc/infected/idle/breathing/idle_breath_04.wav"
};

char g_sVoZombieCommonPain[][PLATFORM_MAX_PATH] =
{
	"szf/npc/infected/action/been_shot/been_shot_12.wav",
	"szf/npc/infected/action/been_shot/been_shot_13.wav",
	"szf/npc/infected/action/been_shot/been_shot_14.wav",
	"szf/npc/infected/action/been_shot/been_shot_18.wav",
	"szf/npc/infected/action/been_shot/been_shot_19.wav",
	"szf/npc/infected/action/been_shot/been_shot_20.wav",
	"szf/npc/infected/action/been_shot/been_shot_21.wav",
	"szf/npc/infected/action/been_shot/been_shot_22.wav",
	"szf/npc/infected/action/been_shot/been_shot_24.wav"
};

char g_sVoZombieCommonRage[][PLATFORM_MAX_PATH] =
{
	"szf/npc/infected/action/rageat/rage_at_victim21.wav",
	"szf/npc/infected/action/rageat/rage_at_victim22.wav",
	"szf/npc/infected/action/rageat/rage_at_victim25.wav",
	"szf/npc/infected/action/rageat/rage_at_victim26.wav"
};

char g_sVoZombieCommonMumbling[][PLATFORM_MAX_PATH] =
{
	"szf/npc/infected/idle/mumbling/mumbling01.wav",
	"szf/npc/infected/idle/mumbling/mumbling02.wav",
	"szf/npc/infected/idle/mumbling/mumbling03.wav",
	"szf/npc/infected/idle/mumbling/mumbling04.wav",
	"szf/npc/infected/idle/mumbling/mumbling05.wav",
	"szf/npc/infected/idle/mumbling/mumbling06.wav",
	"szf/npc/infected/idle/mumbling/mumbling07.wav",
	"szf/npc/infected/idle/mumbling/mumbling08.wav"
};

char g_sVoZombieCommonShoved[][PLATFORM_MAX_PATH] =
{
	"szf/npc/infected/action/rage/shoved_1.wav",
	"szf/npc/infected/action/rage/shoved_2.wav",
	"szf/npc/infected/action/rage/shoved_3.wav",
	"szf/npc/infected/action/rage/shoved_4.wav"
};

char g_sVoZombieCommonDeath[][PLATFORM_MAX_PATH] =
{
	"szf/npc/infected/action/die/death_22.wav",
	"szf/npc/infected/action/die/death_23.wav",
	"szf/npc/infected/action/die/death_24.wav",
	"szf/npc/infected/action/die/death_25.wav",
	"szf/npc/infected/action/die/death_26.wav",
	"szf/npc/infected/action/die/death_27.wav",
	"szf/npc/infected/action/die/death_28.wav",
	"szf/npc/infected/action/die/death_29.wav"
};

/* Tank */
char g_sVoZombieTankDefault[][PLATFORM_MAX_PATH] =
{
	"szf/player/tank/voice/idle/tank_voice_01.wav",
	"szf/player/tank/voice/idle/tank_voice_02.wav",
	"szf/player/tank/voice/idle/tank_voice_03.wav",
	"szf/player/tank/voice/idle/tank_voice_04.wav"
};

char g_sVoZombieTankPain[][PLATFORM_MAX_PATH] =
{
	"szf/player/tank/voice/pain/tank_pain_01.wav",
	"szf/player/tank/voice/pain/tank_pain_02.wav",
	"szf/player/tank/voice/pain/tank_pain_03.wav",
	"szf/player/tank/voice/pain/tank_pain_04.wav"
};

char g_sVoZombieTankOnFire[][PLATFORM_MAX_PATH] =
{
	"szf/player/tank/voice/pain/tank_fire_02.wav",
	"szf/player/tank/voice/pain/tank_fire_03.wav",
	"szf/player/tank/voice/pain/tank_fire_04.wav",
	"szf/player/tank/voice/pain/tank_fire_05.wav"
};

char g_sVoZombieTankAttack[][PLATFORM_MAX_PATH] =
{
	"szf/player/tank/voice/attack/tank_attack_01.wav",
	"szf/player/tank/voice/attack/tank_attack_02.wav",
	"szf/player/tank/voice/attack/tank_attack_03.wav",
	"szf/player/tank/voice/attack/tank_attack_04.wav"
};

char g_sVoZombieTankDeath[][PLATFORM_MAX_PATH] =
{
	"szf/player/tank/voice/die/tank_death_01.wav",
	"szf/player/tank/voice/die/tank_death_02.wav",
	"szf/player/tank/voice/die/tank_death_03.wav",
	"szf/player/tank/voice/die/tank_death_04.wav"
};

/* Boomer */
char g_sVoZombieBoomerDefault[][PLATFORM_MAX_PATH] =
{
	"szf/player/boomer/voice/idle/male_boomer_lurk_02.wav",
	"szf/player/boomer/voice/idle/male_boomer_lurk_03.wav",
	"szf/player/boomer/voice/idle/male_boomer_lurk_04.wav",
};

char g_sVoZombieBoomerPain[][PLATFORM_MAX_PATH] =
{
	"szf/player/boomer/voice/pain/male_boomer_pain_1.wav",
	"szf/player/boomer/voice/pain/male_boomer_pain_2.wav",
	"szf/player/boomer/voice/pain/male_boomer_pain_3.wav"
};

char g_sVoZombieBoomerExplode[][PLATFORM_MAX_PATH] =
{
	"szf/player/boomer/voice/vomit/male_boomer_disruptvomit_05.wav",
	"szf/player/boomer/voice/vomit/male_boomer_disruptvomit_06.wav",
	"szf/player/boomer/voice/vomit/male_boomer_disruptvomit_07.wav"
};

/* Charger */
char g_sVoZombieChargerDefault[][PLATFORM_MAX_PATH] =
{
	"szf/player/charger/voice/idle/charger_spotprey_01.wav",
	"szf/player/charger/voice/idle/charger_spotprey_02.wav",
	"szf/player/charger/voice/idle/charger_spotprey_03.wav"
};

char g_sVoZombieChargerPain[][PLATFORM_MAX_PATH] =
{
	"szf/player/charger/voice/pain/charger_pain_01.wav",
	"szf/player/charger/voice/pain/charger_pain_02.wav",
	"szf/player/charger/voice/pain/charger_pain_03.wav"
};

char g_sVoZombieChargerCharge[][PLATFORM_MAX_PATH] =
{
	"szf/player/charger/voice/attack/charger_charge_01.wav",
	"szf/player/charger/voice/attack/charger_charge_02.wav"
};

/* Hunter */
char g_sVoZombieHunterDefault[][PLATFORM_MAX_PATH] =
{
	"szf/player/hunter/voice/idle/hunter_stalk_04.wav",
	"szf/player/hunter/voice/idle/hunter_stalk_05.wav",
	"szf/player/hunter/voice/idle/hunter_stalk_06.wav"
};

char g_sVoZombieHunterPain[][PLATFORM_MAX_PATH] =
{
	"szf/player/hunter/voice/pain/hunter_pain_12.wav",
	"szf/player/hunter/voice/pain/hunter_pain_13.wav",
	"szf/player/hunter/voice/pain/hunter_pain_14.wav"
};

char g_sVoZombieHunterLeap[][PLATFORM_MAX_PATH] =
{
	"szf/player/hunter/voice/attack/hunter_attackmix_01.wav",
	"szf/player/hunter/voice/attack/hunter_attackmix_02.wav",
	"szf/player/hunter/voice/attack/hunter_attackmix_03.wav"
};

/* Smoker */
char g_sVoZombieSmokerDefault[][PLATFORM_MAX_PATH] =
{
	"szf/player/smoker/voice/idle/smoker_lurk_11.wav",
	"szf/player/smoker/voice/idle/smoker_lurk_12.wav",
	"szf/player/smoker/voice/idle/smoker_lurk_13.wav"
};

char g_sVoZombieSmokerPain[][PLATFORM_MAX_PATH] =
{
	"szf/player/smoker/voice/pain/smoker_pain_02.wav",
	"szf/player/smoker/voice/pain/smoker_pain_03.wav",
	"szf/player/smoker/voice/pain/smoker_pain_04.wav"
};

/* Spitter */
char g_sVoZombieSpitterDefault[][PLATFORM_MAX_PATH] =
{
	"szf/player/spitter/voice/idle/spitter_lurk_02.wav",
	"szf/player/spitter/voice/idle/spitter_lurk_10.wav",
	"szf/player/spitter/voice/idle/spitter_lurk_12.wav"
};

char g_sVoZombieSpitterPain[][PLATFORM_MAX_PATH] =
{
	"szf/player/spitter/voice/pain/spitter_pain_01.wav",
	"szf/player/spitter/voice/pain/spitter_pain_02.wav",
	"szf/player/spitter/voice/pain/spitter_pain_03.wav"
};

/* Jockey */
char g_sVoZombieJockeyDefault[][PLATFORM_MAX_PATH] =
{
	"szf/player/jockey/voice/idle/jockey_lurk04.wav",
	"szf/player/jockey/voice/idle/jockey_lurk05.wav",
	"szf/player/jockey/voice/idle/jockey_lurk11.wav"
};

char g_sVoZombieJockeyPain[][PLATFORM_MAX_PATH] =
{
	"szf/player/jockey/voice/pain/jockey_pain01.wav",
	"szf/player/jockey/voice/pain/jockey_pain05.wav",
	"szf/player/jockey/voice/pain/jockey_pain06.wav"
};

void SoundPrecache()
{	
	//For sound/szf, we need to use both precache and add to download table to each sounds
	for (int i = 0; i < sizeof(g_sSoundRabies); i++) PrecacheSound2(g_sSoundRabies[i]);
	
	for (int i = 0; i < sizeof(g_sSoundDrums); i++) PrecacheSound2(g_sSoundDrums[i]);
	for (int i = 0; i < sizeof(g_sSoundSlayerMild); i++) PrecacheSound2(g_sSoundSlayerMild[i]);
	for (int i = 0; i < sizeof(g_sSoundSlayer); i++) PrecacheSound2(g_sSoundSlayer[i]);
	for (int i = 0; i < sizeof(g_sSoundTrumpet); i++) PrecacheSound2(g_sSoundTrumpet[i]);
	for (int i = 0; i < sizeof(g_sSoundSnare); i++) PrecacheSound2(g_sSoundSnare[i]);
	for (int i = 0; i < sizeof(g_sSoundBanjo); i++) PrecacheSound2(g_sSoundBanjo[i]);
	
	for (int i = 0; i < sizeof(g_sSoundDead); i++) PrecacheSound2(g_sSoundDead[i]);
	for (int i = 0; i < sizeof(g_sSoundIncoming); i++) PrecacheSound2(g_sSoundIncoming[i]);
	for (int i = 0; i < sizeof(g_sSoundNearDeath); i++) PrecacheSound2(g_sSoundNearDeath[i]);
	for (int i = 0; i < sizeof(g_sSoundJarate); i++) PrecacheSound2(g_sSoundJarate[i]);
	
	for (int i = 0; i < sizeof(g_sSoundPrepare); i++) PrecacheSound2(g_sSoundPrepare[i]);
	for (int i = 0; i < sizeof(g_sSoundTank); i++) PrecacheSound2(g_sSoundTank[i]);
	for (int i = 0; i < sizeof(g_sSoundLastStand); i++) PrecacheSound2(g_sSoundLastStand[i]);
	for (int i = 0; i < sizeof(g_sSoundZombieWin); i++) PrecacheSound2(g_sSoundZombieWin[i]);
	for (int i = 0; i < sizeof(g_sSoundSurivourWin); i++) PrecacheSound2(g_sSoundSurivourWin[i]);
	
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
	if (strcmp(sSoundPath, "") == 0)
		return;
	
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
	if (IsMusicOverrideOn() || g_bNoMusicForClient[iClient])
		return;
	
	//We need to check if we are allowed to override current sound from the sound we going to use
	SoundType nType = GetSoundType(nSound);
	Sound nCurrentSound = GetCurrentSound(iClient);
	SoundType nCurrentType = GetSoundType(nCurrentSound);
	
	//If we want to play sound thats already playing, no point replaying it again
	if (nSound == nCurrentSound)
		return;
	
	//If the sound we want to play is greater or the same to current sound from enum SoundType, then we are allowed to override sound, otherwise return
	if (nType < nCurrentType)
		return;
	
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
	
	if (nSound == Sound_None)
		return;
	
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
		//Zombies is already spooky enough, dont need to give him more spooky sounds
		if (IsValidSurvivor(iClient) && GetSoundType(GetCurrentSound(iClient)) == SoundType_None)
		{
			//No sound playing for survivors, lets play rabies
			PlaySound(iClient, SoundQuiet_Rabies, 39.9);
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

void GetRandomSound(Sound nSound, char[] sPath, int iLength)
{
	strcopy(sPath, iLength, "misc/null.wav"); //Having nothing here doesn't seem to matter, but let's keep it consistent
	
	switch (nSound)
	{
		case SoundQuiet_Rabies:			strcopy(sPath, iLength, g_sSoundRabies[GetRandomInt(0, sizeof(g_sSoundRabies)-1)]);
		
		case SoundAttack_Drums:			strcopy(sPath, iLength, g_sSoundDrums[GetRandomInt(0, sizeof(g_sSoundDrums)-1)]);
		case SoundAttack_SlayerMild:	strcopy(sPath, iLength, g_sSoundSlayerMild[GetRandomInt(0, sizeof(g_sSoundSlayerMild)-1)]);
		case SoundAttack_Slayer:		strcopy(sPath, iLength, g_sSoundSlayer[GetRandomInt(0, sizeof(g_sSoundSlayer)-1)]);
		case SoundAttack_Trumpet:		strcopy(sPath, iLength, g_sSoundTrumpet[GetRandomInt(0, sizeof(g_sSoundTrumpet)-1)]);
		case SoundAttack_Snare:			strcopy(sPath, iLength, g_sSoundSnare[GetRandomInt(0, sizeof(g_sSoundSnare)-1)]);
		case SoundAttack_Banjo:			strcopy(sPath, iLength, g_sSoundBanjo[GetRandomInt(0, sizeof(g_sSoundBanjo)-1)]);
		
		case SoundEvent_Dead:			strcopy(sPath, iLength, g_sSoundDead[GetRandomInt(0, sizeof(g_sSoundDead)-1)]);
		case SoundEvent_Incoming:		strcopy(sPath, iLength, g_sSoundIncoming[GetRandomInt(0, sizeof(g_sSoundIncoming)-1)]);
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
	if (nSound == Sound_None)
		return SoundType_None;
	else if (SoundQuiet_Min <= nSound <= SoundQuiet_Max)
		return SoundType_Quiet;
	else if (SoundAttack_Min <= nSound <= SoundAttack_Max)
		return SoundType_Attack;
	else if (SoundEvent_Min <= nSound <= SoundEvent_Max)
		return SoundType_Event;
	else if (SoundMusic_Min <= nSound <= SoundMusic_Max)
		return SoundType_Music;
	
	//Would be really strange if we reach that part
	return SoundType_None;
}

bool IsMusicOverrideOn()
{
	Action action = Forward_ShouldAllowMusicPlay();
	
	if (action == Plugin_Handled || g_bNoMusic)
		return true;
	
	return false;
}