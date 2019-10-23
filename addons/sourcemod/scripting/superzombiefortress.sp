#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf_econ_data>
#include <dhooks>
#include <morecolors>

#include "include/superzombiefortress.inc"

#pragma newdecls required

#define PLUGIN_VERSION "3.3.0"

#define TF_MAXPLAYERS		34	//32 clients + 1 for 0/world/console + 1 for replay/SourceTV

#define BACKSTABDURATION_FULL		5.5
#define BACKSTABDURATION_REDUCED	3.5
#define STUNNED_DAMAGE_CAP			10.0

#define DISTANCE_GOO		4.0
#define TIME_GOO			7.0
#define GOO_INCREASE_RATE	3

enum
{
	WeaponSlot_Primary = 0,
	WeaponSlot_Secondary,
	WeaponSlot_Melee,
	WeaponSlot_PDABuild,
	WeaponSlot_PDADisguise = 3,
	WeaponSlot_PDADestroy,
	WeaponSlot_InvisWatch = 4,
	WeaponSlot_BuilderEngie,
};

enum SZFRoundState
{
	SZFRoundState_Setup,
	SZFRoundState_Grace,
	SZFRoundState_Active,
	SZFRoundState_End,
};

enum Infected
{
	Infected_None,
	Infected_Tank,
	Infected_Boomer,
	Infected_Charger,
	Infected_Kingpin,
	Infected_Stalker,
	Infected_Hunter,
	Infected_Smoker,
}

enum struct GooInfo
{
	float vecOrigin[3];
	int iAttacker;
	int iGooId;
}

SZFRoundState g_nRoundState = SZFRoundState_Setup;

Infected g_nInfected[TF_MAXPLAYERS];
Infected g_nNextInfected[TF_MAXPLAYERS];

ArrayList g_aGoo;
int g_iGooId;

TFTeam TFTeam_Zombie = TFTeam_Blue;
TFTeam TFTeam_Survivor = TFTeam_Red;

Cookie g_cFirstTimeSurvivor;
Cookie g_cFirstTimeZombie;
Cookie g_cNoMusicForPlayer;
Cookie g_cForceZombieStart;

//Global State
bool g_bEnabled;
bool g_bNewRound;
bool g_bLastSurvivor;

float g_flSurvivorsLastDeath = 0.0;
int g_iSurvivorsKilledCounter;
int g_iZombiesKilledCounter;
int g_iZombiesKilledSpree;
int g_iZombiesKilledSurvivor[TF_MAXPLAYERS];

//Client State
int g_iMorale[TF_MAXPLAYERS];
int g_iHorde[TF_MAXPLAYERS];
int g_iCapturingPoint[TF_MAXPLAYERS];
int g_iRageTimer[TF_MAXPLAYERS];
bool g_iScreamerNearby[TF_MAXPLAYERS];

bool g_bStartedAsZombie[TF_MAXPLAYERS];
float g_flStopChatSpam[TF_MAXPLAYERS];
bool g_bWaitingForTeamSwitch[TF_MAXPLAYERS];

int g_iSprite; //Smoker beam

//Global Timer Handles
Handle g_hTimerMain;
Handle g_hTimerMoraleDecay;
Handle g_hTimerMainFast;
Handle g_hTimerMainSlow;
Handle g_hTimerHoarde;
Handle g_hTimerDataCollect;
Handle g_hTimerProgress;

//Cvar Handles
ConVar g_cvForceOn;
ConVar g_cvRatio;
ConVar g_cvSwapOnPayload;
ConVar g_cvSwapOnAttdef;
ConVar g_cvTankHealth;
ConVar g_cvTankHealthMin;
ConVar g_cvTankHealthMax;
ConVar g_cvTankTime;
ConVar g_cvFrenzyChance;
ConVar g_cvFrenzyTankChance;

float g_flZombieDamageScale = 1.0;

ArrayList g_aFastRespawn;

bool g_bBackstabbed[TF_MAXPLAYERS];

int g_iDamage[TF_MAXPLAYERS];
int g_iDamageTakenLife[TF_MAXPLAYERS];
int g_iDamageDealtLife[TF_MAXPLAYERS];

float g_flDamageDealtAgainstTank[TF_MAXPLAYERS];
float g_flTankLifetime[TF_MAXPLAYERS];
bool g_bTankRefreshed;

bool g_bFirstRound = true;

int g_iControlPointsInfo[20][2];
int g_iControlPoints;
bool g_bCapturingLastPoint;
int g_iCarryingItem[TF_MAXPLAYERS] = -1;

float g_flTimeProgress;

//ConVars
ConVar mp_autoteambalance;
ConVar mp_teams_unbalance_limit;
ConVar mp_waitingforplayers_time;
ConVar tf_weapon_criticals;
ConVar tf_obj_upgrade_per_hit;
ConVar tf_sentrygun_metal_per_shell;
ConVar tf_spy_invis_time;
ConVar tf_spy_invis_unstealth_time;
ConVar tf_spy_cloak_no_attack_time;

//Forwards
GlobalForward g_hForwardLastSurvivor;
GlobalForward g_hForwardBackstab;
GlobalForward g_hForwardTankSpawn;
GlobalForward g_hForwardTankDeath;
GlobalForward g_hForwardQuickSpawnAsSpecialInfected;
GlobalForward g_hForwardChargerHit;
GlobalForward g_hForwardHunterHit;
GlobalForward g_hForwardBoomerExplode;
GlobalForward g_hForwardWeaponPickup;
GlobalForward g_hForwardWeaponCallout;
GlobalForward g_hForwardClientName;
GlobalForward g_hForwardStartZombie;
GlobalForward g_hForwardAllowMusicPlay;

//SDK functions
Handle g_hHookGetMaxHealth;
Handle g_hSDKGetMaxHealth;
Handle g_hSDKGetMaxAmmo;
Handle g_hSDKEquipWearable;
Handle g_hSDKRemoveWearable;
Handle g_hSDKGetEquippedWearable;

float g_flTankCooldown;
float g_flRageCooldown;
float g_flRageRespawnStress;
float g_flInfectedCooldown[view_as<int>(Infected)];	//GameTime
int g_iInfectedCooldown[view_as<int>(Infected)];	//Client who started the cooldown
float g_flSelectSpecialCooldown;

bool g_bZombieRage;
int g_iZombieTank;
bool g_bZombieRageAllowRespawn;
int g_iGooMultiplier[TF_MAXPLAYERS];
bool g_bGooified[TF_MAXPLAYERS];
bool g_bHitOnce[TF_MAXPLAYERS];
bool g_bHopperIsUsingPounce[TF_MAXPLAYERS];
float g_flGooCooldown[TF_MAXPLAYERS];

bool g_bSpawnAsSpecialInfected[TF_MAXPLAYERS];
int g_iKillsThisLife[TF_MAXPLAYERS];
int g_iEyelanderHead[TF_MAXPLAYERS];
int g_iMaxHealth[TF_MAXPLAYERS];
int g_iSuperHealthSubtract[TF_MAXPLAYERS];
int g_iStartSurvivors;
bool g_bShouldBacteriaPlay[TF_MAXPLAYERS] = true;
bool g_bReplaceRageWithSpecialInfectedSpawn[TF_MAXPLAYERS];
int g_iSmokerBeamHits[TF_MAXPLAYERS];
int g_iSmokerBeamHitVictim[TF_MAXPLAYERS];
float g_flTimeStartAsZombie[TF_MAXPLAYERS];
bool g_bForceZombieStart[TF_MAXPLAYERS];

//Map overwrites
float g_flCapScale = -1.0;
bool g_bSurvival;
bool g_bNoMusic;
bool g_bNoDirectorTanks;
bool g_bNoDirectorRages;
bool g_bDirectorSpawnTeleport;

//Goo
char g_strSoundFleshHit[][128] =
{
	"physics/flesh/flesh_impact_bullet1.wav",
	"physics/flesh/flesh_impact_bullet2.wav",
	"physics/flesh/flesh_impact_bullet3.wav",
	"physics/flesh/flesh_impact_bullet4.wav",
	"physics/flesh/flesh_impact_bullet5.wav"
};

char g_strSoundCritHit[][128] =
{
	"player/crit_received1.wav",
	"player/crit_received2.wav",
	"player/crit_received3.wav"
};

#include "szf/weapons.sp"
#include "szf/classes.sp"
#include "szf/stocks.sp"
#include "szf/sound.sp"
#include "szf/pickupweapons.sp"
#include "szf/config.sp"

public Plugin myinfo =
{
	name = "Super Zombie Fortress",
	author = "42, Sasch, Benoist3012, Haxton Sale, Frosty Scales, MekuCube (original)",
	description = "Originally based off MekuCube's 1.05 version.",
	version = PLUGIN_VERSION,
	url = "https://github.com/redsunservers/SuperZombieFortress"
}

////////////////////////////////////////////////////////////
//
// Sourcemod Callbacks
//
////////////////////////////////////////////////////////////

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hForwardLastSurvivor = new GlobalForward("SZF_OnLastSurvivor", ET_Ignore, Param_Cell);
	g_hForwardBackstab = new GlobalForward("SZF_OnBackstab", ET_Ignore, Param_Cell, Param_Cell);
	g_hForwardTankSpawn = new GlobalForward("SZF_OnTankSpawn", ET_Ignore, Param_Cell);
	g_hForwardTankDeath = new GlobalForward("SZF_OnTankDeath", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hForwardQuickSpawnAsSpecialInfected = new GlobalForward("SZF_OnQuickSpawnAsSpecialInfected", ET_Ignore, Param_Cell);
	g_hForwardChargerHit = new GlobalForward("SZF_OnChargerHit", ET_Ignore, Param_Cell, Param_Cell);
	g_hForwardHunterHit = new GlobalForward("SZF_OnHunterHit", ET_Ignore, Param_Cell, Param_Cell);
	g_hForwardBoomerExplode = new GlobalForward("SZF_OnBoomerExplode", ET_Ignore, Param_Cell, Param_Array, Param_Cell);
	g_hForwardWeaponPickup = new GlobalForward("SZF_OnWeaponPickup", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hForwardWeaponCallout = new GlobalForward("SZF_OnWeaponCallout", ET_Ignore, Param_Cell);
	g_hForwardClientName = new GlobalForward("SZF_GetClientName", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	g_hForwardStartZombie = new GlobalForward("SZF_ShouldStartZombie", ET_Hook, Param_Cell);
	g_hForwardAllowMusicPlay = new GlobalForward("SZF_ShouldAllowMusicPlay", ET_Hook);
	
	CreateNative("SZF_GetSurvivorTeam", Native_GetSurvivorTeam);
	CreateNative("SZF_GetZombieTeam", Native_GetZombieTeam);
	CreateNative("SZF_GetLastSurvivor", Native_GetLastSurvivor);
	CreateNative("SZF_GetWeaponPickupCount", Native_GetWeaponPickupCount);
	CreateNative("SZF_GetWeaponRarePickupCount", Native_GetWeaponRarePickupCount);
	CreateNative("SZF_GetWeaponCalloutCount", Native_GetWeaponCalloutCount);
	
	RegPluginLibrary("superzombiefortress");
}

public void OnPluginStart()
{
	//Add server tag.
	AddServerTag("zf");
	AddServerTag("szf");
	
	//Initialize global state
	g_bFirstRound = true;
	g_bSurvival = false;
	g_bNoMusic = false;
	g_bNoDirectorTanks = false;
	g_bNoDirectorRages = false;
	g_bDirectorSpawnTeleport = false;
	g_bEnabled = false;
	g_bNewRound = true;
	g_bLastSurvivor = false;
	g_nRoundState = SZFRoundState_Setup;
	
	mp_autoteambalance = FindConVar("mp_autoteambalance");
	mp_teams_unbalance_limit = FindConVar("mp_teams_unbalance_limit");
	mp_waitingforplayers_time = FindConVar("mp_waitingforplayers_time");
	tf_weapon_criticals = FindConVar("tf_weapon_criticals");
	tf_obj_upgrade_per_hit = FindConVar("tf_obj_upgrade_per_hit");
	tf_sentrygun_metal_per_shell = FindConVar("tf_sentrygun_metal_per_shell");
	tf_spy_invis_time = FindConVar("tf_spy_invis_time");
	tf_spy_invis_unstealth_time = FindConVar("tf_spy_invis_unstealth_time");
	tf_spy_cloak_no_attack_time = FindConVar("tf_spy_cloak_no_attack_time");
	
	//Register cvars
	CreateConVar("sm_szf_version", PLUGIN_VERSION, "Current Zombie Fortress Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_cvForceOn = CreateConVar("sm_szf_force_on", "1", "<0/1> Activate SZF for non-SZF maps.", _, true, 0.0, true, 1.0);
	g_cvRatio = CreateConVar("sm_szf_ratio", "0.78", "<0.01-1.00> Percentage of players that start as survivors.", _, true, 0.01, true, 1.0);
	g_cvSwapOnPayload = CreateConVar("sm_szf_swaponpayload", "1", "<0/1> Swap teams on non-SZF payload maps.", _, true, 0.0, true, 1.0);
	g_cvSwapOnAttdef = CreateConVar("sms_szf_swaponattdef", "1", "<0/1> Swap teams on non-SZF attack/defend maps.", _, true, 0.0, true, 1.0);
	g_cvTankHealth = CreateConVar("sm_szf_tank_health", "400", "Amount of health the Tank gets per alive survivor", _, true, 10.0);
	g_cvTankHealthMin = CreateConVar("sm_szf_tank_health_min", "1000", "Minimum amount of health the Tank can spawn with", _, true, 0.0);
	g_cvTankHealthMax = CreateConVar("sm_szf_tank_health_max", "6000", "Maximum amount of health the Tank can spawn with", _, true, 0.0);
	g_cvTankTime = CreateConVar("sm_szf_tank_time", "30.0", "Adjusts the damage the Tank takes per second. If the value is 70.0, the Tank will take damage that will make him die (if unhurt by survivors) after 70 seconds. 0 to disable.", _, true, 0.0);
	g_cvFrenzyChance = CreateConVar("sm_szf_frenzy_chance", "0.0", "% Chance of a random frenzy", _, true, 0.0);
	g_cvFrenzyTankChance = CreateConVar("sm_szf_frenzy_tank", "0.0", "% Chance of a Tank appearing instead of a frenzy", _, true, 0.0);
	
	//Hook events
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_setup_finished", Event_SetupEnd);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("player_builtobject", Event_PlayerBuiltObject);
	HookEvent("teamplay_point_captured", Event_CPCapture);
	HookEvent("teamplay_point_startcapture", Event_CPCaptureStart);
	HookEvent("teamplay_broadcast_audio", Event_Broadcast, EventHookMode_Pre);

	//Hook Client Commands
	AddCommandListener(Command_JoinTeam, "jointeam");
	AddCommandListener(Command_JoinTeam, "spectate");
	AddCommandListener(Command_JoinTeam, "autoteam");
	AddCommandListener(Command_JoinClass, "joinclass");
	AddCommandListener(Command_VoiceMenu, "voicemenu");
	AddCommandListener(Command_Build, "build");

	RegServerCmd("szf_panic_event", Command_ZombieRage);
	RegServerCmd("szf_zombierage", Command_ZombieRage);

	RegServerCmd("szf_zombietank", Command_Tank);
	RegServerCmd("szf_tank", Command_Tank);

	//Hook Client Chat / Console Commands
	RegConsoleCmd("sm_zf", Command_MainMenu);
	RegConsoleCmd("sm_szf", Command_MainMenu);
	RegConsoleCmd("sm_music", Command_MusicToggle);

	RegAdminCmd("sm_tank", Admin_ZombieTank, ADMFLAG_CHANGEMAP, "(Try to) call a tank.");
	RegAdminCmd("sm_rage", Admin_ZombieRage, ADMFLAG_CHANGEMAP, "(Try to) call a frenzy.");
	RegAdminCmd("sm_boomer", Admin_ForceBoomer, ADMFLAG_CHANGEMAP, "Become a boomer on next respawn.");
	RegAdminCmd("sm_charger", Admin_ForceCharger, ADMFLAG_CHANGEMAP, "Become a charger on next respawn.");
	RegAdminCmd("sm_kingpin", Admin_ForceScreamer, ADMFLAG_CHANGEMAP, "Become a screamer on next respawn.");
	RegAdminCmd("sm_stalker", Admin_ForcePredator, ADMFLAG_CHANGEMAP, "Become a predator on next respawn.");
	RegAdminCmd("sm_hunter", Admin_ForceHopper, ADMFLAG_CHANGEMAP, "Become a hunter on next respawn.");
	RegAdminCmd("sm_smoker", Admin_ForceSmoker, ADMFLAG_CHANGEMAP, "Become a smoker on next respawn.");
	
	AddNormalSoundHook(SoundHook);
	
	g_cFirstTimeZombie = new Cookie("szf_firsttimezombie", "is this the flowey map?", CookieAccess_Protected);
	g_cFirstTimeSurvivor = new Cookie("szf_firsttimesurvivor2", "is this the flowey map?", CookieAccess_Protected);
	g_cNoMusicForPlayer = new Cookie("szf_musicpreference", "is this the flowey map?", CookieAccess_Protected);
	g_cForceZombieStart = new Cookie("szf_forcezombiestart", "is this the flowey map?", CookieAccess_Protected);
	
	SDK_Init();
	
	Config_InitTemplates();
	Config_LoadTemplates();
	
	Classes_Setup();
	Weapons_Setup();
	
	//Incase of late-load
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			OnClientPutInServer(iClient);
}

public void OnPluginEnd()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			EndSound(iClient);
}

public Action Command_Build(int iClient, const char[] sCommand, int iArgs)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (!iClient) return Plugin_Continue;
	
	//Get arguments
	char sObjectType[32];
	GetCmdArg(1, sObjectType, sizeof(sObjectType));
	TFObjectType nObjectType = view_as<TFObjectType>(StringToInt(sObjectType));
	
	//if not a sentry and is a zombie, then block building
	if (IsZombie(iClient) && nObjectType != TFObject_Sentry)
		return Plugin_Handled;
	
	//if not sentry or dispenser, then block building
	if (nObjectType != TFObject_Dispenser && nObjectType != TFObject_Sentry)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action Command_ZombieRage(int iArgs)
{
	char sDuration[256];
	GetCmdArgString(sDuration, sizeof(sDuration));
	float flDuration = StringToFloat(sDuration);
	
	ZombieRage(flDuration);
	
	return Plugin_Handled;
}

public Action Command_Tank(int iArgs)
{
	ZombieTank();
	
	return Plugin_Handled;
}

public Action Admin_ForceBoomer(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Boomer;
	
	return Plugin_Handled;
}

public Action Admin_ForceCharger(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Charger;
	
	return Plugin_Handled;
}

public Action Admin_ForceScreamer(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Kingpin;
	
	return Plugin_Handled;
}

public Action Admin_ForcePredator(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Stalker;
	
	return Plugin_Handled;
}

public Action Admin_ForceHopper(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Hunter;
	
	return Plugin_Handled;
}

public Action Admin_ForceSmoker(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Smoker;
	
	return Plugin_Handled;
}

public Action Admin_ZombieTank(int iClient, int iArgs)
{
	ZombieTank(iClient);
	return Plugin_Handled;
}

public Action Admin_ZombieRage(int iClient, int iArgs)
{
	ZombieRage();
	
	return Plugin_Handled;
}

public any Native_GetSurvivorTeam(Handle hPlugin, int iNumParams)
{
	return TFTeam_Survivor;
}

public any Native_GetZombieTeam(Handle hPlugin, int iNumParams)
{
	return TFTeam_Zombie;
}

public any Native_GetLastSurvivor(Handle hPlugin, int iNumParams)
{
	if (!g_bLastSurvivor)
		return 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidLivingSurvivor(iClient))
			return iClient;
	
	return 0;
}

public any Native_GetWeaponPickupCount(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client %d", iClient);
	if (!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	
	return GetCookie(iClient, g_cWeaponsPicked);
}

public any Native_GetWeaponRarePickupCount(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client %d", iClient);
	if (!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	
	return GetCookie(iClient, g_cWeaponsRarePicked);
}

public any Native_GetWeaponCalloutCount(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client %d", iClient);
	if (!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	
	return GetCookie(iClient, g_cWeaponsCalled);
}

public void OnClientCookiesCached(int iClient)
{
	char sValue[8];
	int iValue;
	
	GetClientCookie(iClient, g_cNoMusicForPlayer, sValue, sizeof(sValue));
	iValue = StringToInt(sValue);
	g_bNoMusicForClient[iClient] = view_as<bool>(iValue);
	
	GetClientCookie(iClient, g_cForceZombieStart, sValue, sizeof(sValue));
	iValue = StringToInt(sValue);
	g_bForceZombieStart[iClient] = view_as<bool>(iValue);
}

public void OnConfigsExecuted()
{
	if (IsMapSZF())
	{
		SZFEnable();
		GetMapSettings();
	}
	else
	{
		g_cvForceOn.BoolValue ? SZFEnable() : SZFDisable();
	}
	
	g_nRoundState = SZFRoundState_Setup;
}

public void OnMapEnd()
{
	//Close timer handles
	delete g_hTimerMain;
	delete g_hTimerMoraleDecay;
	delete g_hTimerMainSlow;
	delete g_hTimerMainFast;
	delete g_hTimerHoarde;
	
	g_nRoundState = SZFRoundState_End;
	SZFDisable();
	
	UnhookEntityOutput("logic_relay", "OnTrigger", OnRelayTrigger);
	UnhookEntityOutput("math_counter", "OutValue", OnCounterValue);
}

void GetMapSettings()
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "info_target")) != -1)
	{
		char sTargetName[64];
		GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
		if (StrContains(sTargetName, "szf_survivalmode", false) == 0) g_bSurvival = true;
		else if (StrContains(sTargetName, "szf_nomusic", false) == 0) g_bNoMusic = true;
		else if (StrContains(sTargetName, "szf_director_notank", false) == 0) g_bNoDirectorTanks = true;
		else if (StrContains(sTargetName, "szf_director_norage", false) == 0) g_bNoDirectorRages = true;
		else if (StrContains(sTargetName, "szf_director_spawnteleport", false) == 0) g_bDirectorSpawnTeleport = true;
	}
}

public void OnClientPutInServer(int iClient)
{
	CreateTimer(10.0, Timer_InitialHelp, iClient, TIMER_FLAG_NO_MAPCHANGE);
	
	DHookEntity(g_hHookGetMaxHealth, false, iClient);
	SDKHook(iClient, SDKHook_PreThinkPost, Client_OnPreThinkPost);
	SDKHook(iClient, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	
	g_iDamage[iClient] = GetAverageDamage();
}

public void OnClientDisconnect(int iClient)
{
	if (!g_bEnabled) return;
	
	RequestFrame(CheckZombieBypass, iClient);
	
	EndSound(iClient);
	DropCarryingItem(iClient);
	if (iClient == g_iZombieTank) g_iZombieTank = 0;
	
	g_bWaitingForTeamSwitch[iClient] = false;
	
	Weapons_ClientDisconnect(iClient);
}

////////////////////////////////////////////////////////////
//
// SDKHooks Callbacks
//
////////////////////////////////////////////////////////////

public void Client_OnPreThinkPost(int iClient)
{
	if (!g_bEnabled) return;
	
	if (IsValidLivingClient(iClient))
	{
		//Handle speed bonuses.
		if ((!TF2_IsPlayerInCondition(iClient, TFCond_Slowed) && !TF2_IsPlayerInCondition(iClient, TFCond_Dazed)) || g_bBackstabbed[iClient])
		{
			TFClassType nClass = TF2_GetPlayerClass(iClient);
			float flSpeed;
			
			if (IsZombie(iClient))
			{
				if (g_nInfected[iClient] == Infected_None)
				{
					flSpeed = GetInfectedSpeed(g_nInfected[iClient]);
					
					//Zombies: hoarde bonus to movement speed and ignite speed bonus
					flSpeed = GetZombieSpeed(nClass);
					
					//Movement speed increase
					flSpeed += fMin(GetZombieMaxSpree(nClass), GetZombieSpree(nClass) * g_iZombiesKilledSpree) + fMin(GetZombieMaxHorde(nClass), GetZombieHorde(nClass) * g_iHorde[iClient]);
					
					if (g_bZombieRage) flSpeed += 40.0; //Map-wide zombie enrage event
					if (TF2_IsPlayerInCondition(iClient, TFCond_OnFire)) flSpeed += 20.0; //On fire
					if (TF2_IsPlayerInCondition(iClient, TFCond_TeleportedGlow)) flSpeed += 20.0; //Kingpin effect
					if (GetClientHealth(iClient) > SDK_GetMaxHealth(iClient)) flSpeed += 20.0; //Has overheal due to normal rage
					
					//Movement speed decrease
					if (TF2_IsPlayerInCondition(iClient, TFCond_Jarated)) flSpeed -= 30.0; //Jarate'd by sniper
					if (GetClientHealth(iClient) < 50) flSpeed -= 50.0 - float(GetClientHealth(iClient)); //If under 50 health, tick away one speed per hp lost
				}
				else
				{
					flSpeed = GetInfectedSpeed(g_nInfected[iClient]);
					
					switch (g_nInfected[iClient])
					{
						//Tank: movement speed bonus based on damage taken and ignite speed bonus
						case Infected_Tank:
						{
							flSpeed = GetInfectedSpeed(Infected_Tank);

							//Reduce speed when tank deals damage to survivors 
							flSpeed -= fMin(60.0, (float(g_iDamageDealtLife[iClient]) / 10.0));

							//Reduce speed when tank takes damage from survivors 
							flSpeed -= fMin(80.0, (float(g_iDamageTakenLife[iClient]) / 10.0));

							if (TF2_IsPlayerInCondition(iClient, TFCond_OnFire)) flSpeed += 40.0; //On fire
							if (TF2_IsPlayerInCondition(iClient, TFCond_Jarated)) flSpeed -= 30.0; //Jarate'd by sniper
						}

						//Charger: like in l4d, his charge is fucking fast so we also have it here, WEEEEEEE
						case Infected_Charger:
						{
							if (TF2_IsPlayerInCondition(iClient, TFCond_Charging))
								flSpeed = 1200.0; //Original charge speed is 1000.0, will this black sorcery work?
						}

						//Cloaked: super speed if cloaked
						case Infected_Stalker:
						{
							if (TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
								flSpeed += 120.0;
						}
					}
				}
			}
			
			if (IsSurvivor(iClient))
			{
				if (TF2_IsPlayerInCondition(iClient, TFCond_Charging))
				{
					flSpeed = 600.0;
				}
				else
				{
					flSpeed = GetSurvivorSpeed(nClass) + GetClientBonusSpeed(iClient);
					
					//If under 50 health, tick away one speed per hp lost
					if (GetClientHealth(iClient) < 50)
					{
						flSpeed -= 50.0 - float(GetClientHealth(iClient));
					}
				}
				
				if (g_bBackstabbed[iClient])
				{
					flSpeed *= 0.66;
				}
				
				//very very very dirty fix for eyelander head
				int iHeads = GetEntProp(iClient, Prop_Send, "m_iDecapitations");
				if (nClass == TFClass_DemoMan && iHeads != g_iEyelanderHead[iClient])
				{
					SetEntProp(iClient, Prop_Send, "m_iDecapitations", g_iEyelanderHead[iClient]);
					
					//Recalculate player's speed
					TF2_AddCondition(iClient, TFCond_SpeedBuffAlly, 0.01);
				}
			}
			
			SetClientSpeed(iClient, flSpeed);
		}
		
		//Handle hunter-specific logic.
		if (IsZombie(iClient) && g_nInfected[iClient] == Infected_Hunter && g_bHopperIsUsingPounce[iClient])
		{
			if (GetEntityFlags(iClient) & FL_ONGROUND == FL_ONGROUND)
				g_bHopperIsUsingPounce[iClient] = false;
		}
	}
	
	UpdateClientCarrying(iClient);
}

public Action Client_OnTakeDamage(int iVictim, int &iAttacker, int &iInflicter, float &flDamage, int &iDamageType, int &iWeapon, float vecForce[3], float vecForcePos[3], int iDamageCustom)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (!CanRecieveDamage(iVictim)) return Plugin_Continue;
	
	bool bChanged = false;
	if (IsValidClient(iVictim) && IsValidClient(iAttacker))
	{
		g_bHitOnce[iVictim] = true;
		g_bHitOnce[iAttacker] = true;
		
		if (GetClientTeam(iVictim) != GetClientTeam(iAttacker))
			EndGracePeriod();
	}
	
	//Disable fall damage to tank
	if (g_nInfected[iVictim] == Infected_Tank && iDamageType & DMG_FALL)
	{
		flDamage = 0.0;
		bChanged = true;
	}
	
	if (iVictim != iAttacker)
	{
		if (IsValidLivingClient(iAttacker) && flDamage < 300.0)
		{
			//Damage scaling Zombies
			if (IsValidZombie(iAttacker))
			{
				flDamage = flDamage * g_flZombieDamageScale * 0.7; //Default: 0.7
			}
			
			//Damage scaling Survivors
			if (IsValidSurvivor(iAttacker) && !TF2_IsSentry(iInflicter))
			{
				float flMoraleBonus = fMin(GetMorale(iAttacker) * 0.005, 0.25); //50 morale: 0.25
				flDamage = flDamage / g_flZombieDamageScale * (1.1 + flMoraleBonus); //Default: 1.1
			}
			
			//If backstabbed
			if (g_bBackstabbed[iVictim])
			{
				if (flDamage > STUNNED_DAMAGE_CAP)
					flDamage = STUNNED_DAMAGE_CAP;
				
				iDamageType &= ~DMG_CRIT;
			}
			
			bChanged = true;
		}
		
		if (IsValidSurvivor(iVictim) && IsValidZombie(iAttacker))
		{
			SoundAttack(iVictim, iAttacker);
			
			if (TF2_GetPlayerClass(iVictim) == TFClass_Scout)
			{
				flDamage *= 0.825;
				bChanged = true;
			}
			
			if (TF2_IsPlayerInCondition(iAttacker, TFCond_CritCola)
				|| TF2_IsPlayerInCondition(iAttacker, TFCond_Buffed)
				|| TF2_IsPlayerInCondition(iAttacker, TFCond_CritHype))
			{
				//Reduce damage from crit amplifying items when active
				flDamage *= 0.85;
				bChanged = true;
			}
			
			//Taunt, backstabs and highly critical damage
			if (iDamageCustom == TF_CUSTOM_TAUNT_HIGH_NOON
				|| iDamageCustom == TF_CUSTOM_TAUNT_GRAND_SLAM
				|| iDamageCustom == TF_CUSTOM_BACKSTAB
				|| flDamage >= SDK_GetMaxHealth(iVictim) - 20)
			{
				if (!g_bBackstabbed[iVictim])
				{
					if (IsRazorbackActive(iVictim))
						return Plugin_Continue;
					
					if (g_nInfected[iAttacker] == Infected_Stalker)
						SetEntityHealth(iVictim, GetClientHealth(iVictim) - 50);
					else
						SetEntityHealth(iVictim, GetClientHealth(iVictim) - 20);
					
					AddMorale(iVictim, -5);
					SetBackstabState(iVictim, BACKSTABDURATION_FULL, 0.25);
					SetNextAttack(iAttacker, GetGameTime() + 1.25);
					
					Call_StartForward(g_hForwardBackstab);
					Call_PushCell(iVictim);
					Call_PushCell(iAttacker);
					Call_Finish();
					
					flDamage = 1.0;
					bChanged = true;
				}
				
				else
				{
					flDamage = STUNNED_DAMAGE_CAP;
					bChanged = true;
				}
			}
			
			if (g_nInfected[iAttacker] == Infected_Tank)
				EmitSoundToAll(g_sVoZombieTankAttack[GetRandomInt(0, sizeof(g_sVoZombieTankAttack)-1)], iAttacker, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
		
		if (IsValidZombie(iVictim))
		{
			// zero down physics force, disable physics force
			switch (TF2_GetPlayerClass(iVictim))
			{
				case TFClass_Soldier:
				{
					ScaleVector(vecForce, 0.0);
					iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
					bChanged = true;
				}
				// cap damage to 150
				case TFClass_Heavy:
				{
					if (flDamage > 150.0 && flDamage <= 500.0) flDamage = 150.0;
					ScaleVector(vecForce, 0.0);
					iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
					bChanged = true;
				}
			}
			
			//Disable physics force
			if (TF2_IsSentry(iInflicter))
				iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
			
			if (IsValidSurvivor(iAttacker))
			{
				//Kingpin takes 33% less damage from attacks
				if (g_nInfected[iVictim] == Infected_Kingpin)
				{
					flDamage *= 0.66;
					bChanged = true;
				}
				
				else if (g_nInfected[iVictim] == Infected_Tank)
				{
					//"SHOOT THAT TANK" voice call
					if (g_flDamageDealtAgainstTank[iAttacker] == 0)
					{
						char sPath[PLATFORM_MAX_PATH];
						switch (TF2_GetPlayerClass(iAttacker))
						{
							case TFClass_Soldier: Format(sPath, sizeof(sPath), g_sVoTankSoldier[GetRandomInt(0, sizeof(g_sVoTankSoldier)-1)]);
							case TFClass_Engineer: Format(sPath, sizeof(sPath), g_sVoTankEngineer[GetRandomInt(0, sizeof(g_sVoTankEngineer)-1)]);
							case TFClass_Medic: Format(sPath, sizeof(sPath), g_sVoTankMedic[GetRandomInt(0, sizeof(g_sVoTankMedic)-1)]);
						}
						
						if (sPath[0] != '\0')
							EmitSoundToAll(sPath, iAttacker, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
					}
					
					//Don't instantly kill the tank on a backstab
					if (iDamageCustom == TF_CUSTOM_BACKSTAB)
					{
						flDamage = g_iMaxHealth[iVictim]/11.0;
						iDamageType |= DMG_CRIT;
					}
					
					g_flDamageDealtAgainstTank[iAttacker] += flDamage;
					ScaleVector(vecForce, 0.0);
					iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
				}
				
				else if (TF2_IsPlayerInCondition(iVictim, TFCond_CritCola)
					|| TF2_IsPlayerInCondition(iVictim, TFCond_Buffed)
					|| TF2_IsPlayerInCondition(iVictim, TFCond_CritHype))
				{
					//Increase damage taken from crit amplifying items when active
					flDamage *= 1.1;
					bChanged = true;
				}
			}
		}
		
		//Check if tank takes damage from map deathpit, if so kill him
		if (g_nInfected[iVictim] == Infected_Tank && MaxClients < iAttacker)
		{
			char strAttacker[32];
			GetEdictClassname(iAttacker, strAttacker, sizeof(strAttacker));
			if (strcmp(strAttacker, "trigger_hurt") == 0 && flDamage >= 450.0)
				ForcePlayerSuicide(iVictim);
		}
	}
	
	if (bChanged) return Plugin_Changed;
	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Client Console / Chat Command Handlers
//
////////////////////////////////////////////////////////////

public Action Command_JoinTeam(int iClient, const char[] sCommand, int iArgs)
{
	char sArg[32];
	char sSurTeam[16];
	char sZomTeam[16];
	char sZomVgui[16];
	
	if (!g_bEnabled) return Plugin_Continue;
	if (iArgs < 1 && StrEqual(sCommand, "jointeam", false)) return Plugin_Handled;
	if (g_nRoundState < SZFRoundState_Grace) return Plugin_Continue;
	if (!IsClientInGame(iClient)) return Plugin_Continue;
	
	//Get command/arg on which team player joined
	if (StrEqual(sCommand, "jointeam", false)) //This is done because "jointeam spectate" should take priority over "spectate"
		GetCmdArg(1, sArg, sizeof(sArg));
	else if (StrEqual(sCommand, "spectate", false))
		strcopy(sArg, sizeof(sArg), "spectate");	
	else if (StrEqual(sCommand, "autoteam", false))
		strcopy(sArg, sizeof(sArg), "autoteam");		
	
	//Check if client is trying to skip playing as zombie by joining spectator
	if (StrEqual(sArg, "spectate", false))
		CheckZombieBypass(iClient);
	
	//Assign team-specific strings
	if (TFTeam_Zombie == TFTeam_Blue)
	{
		sSurTeam = "red";
		sZomTeam = "blue";
		sZomVgui = "class_blue";
	}
	else
	{
		sSurTeam = "blue";
		sZomTeam = "red";
		sZomVgui = "class_red";
	}
	
	if (g_nRoundState == SZFRoundState_Grace)
	{
		TFTeam nTeam = TF2_GetClientTeam(iClient);
		
		//If a client tries to join the infected team or a random team during grace period...
		if (StrEqual(sArg, sZomTeam, false) || StrEqual(sArg, "auto", false) || StrEqual(sArg, "autoteam", false))
		{
			//...as survivor, don't let them.
			if (nTeam == TFTeam_Survivor)
			{
				CPrintToChat(iClient, "{red}You can not switch to the opposing team during grace period.");
				return Plugin_Handled;
			}
			
			//...as a spectator who didn't start as an infected, set them as infected after grace period ends, after warning them.
			if (nTeam <= TFTeam_Spectator && !g_bStartedAsZombie[iClient])
			{
				if (!g_bWaitingForTeamSwitch[iClient])
				{
					if (nTeam == TFTeam_Unassigned) //If they're unassigned, let them spectate for now.
						TF2_ChangeClientTeam(iClient, TFTeam_Spectator);
					
					CPrintToChat(iClient, "{red}You will join the Infected team when grace period ends.");
					g_bWaitingForTeamSwitch[iClient] = true;
				}
				
				return Plugin_Handled;
			}	
		}
		//If client tries to spectate during grace period, make them
		//not be booted into the infected team if they tried to join
		//it before.
		else if (StrEqual(sArg, "spectate", false))
		{
			if (nTeam <= TFTeam_Spectator && g_bWaitingForTeamSwitch[iClient])
			{
				CPrintToChat(iClient, "{green}You will no longer automatically join the Infected team when grace period ends.");
				g_bWaitingForTeamSwitch[iClient] = false;
			}
			
			return Plugin_Continue;
		}
		
		//If client tries to join the survivor team during grace period, 
		//deny and set them as infected instead.
		else if (StrEqual(sArg, sSurTeam, false))
		{
			if (nTeam <= TFTeam_Spectator && !g_bWaitingForTeamSwitch[iClient])
			{
				//However, if they started as infected, they can spawn as infected again, normally.
				if (g_bStartedAsZombie[iClient])
				{
					TF2_ChangeClientTeam(iClient, TFTeam_Zombie);
					ShowVGUIPanel(iClient, sZomVgui);
				}
				else
				{
					if (nTeam == TFTeam_Unassigned) //If they're unassigned, let them spectate for now.
						TF2_ChangeClientTeam(iClient, TFTeam_Spectator);
					
					CPrintToChat(iClient, "{red}Can not join the Survivor team at this time. You will join the Infected team when grace period ends.");
					g_bWaitingForTeamSwitch[iClient] = true;
				}
			}
			
			return Plugin_Handled;
		}
		
		//Prevent joining any other team.
		else
			return Plugin_Handled;
	}
	
	else if (g_nRoundState > SZFRoundState_Grace)
	{
		//If client tries to join the survivor team or a random team
		//during an active round, place them on the zombie
		//team and present them with the zombie class select screen.
		if (StrEqual(sArg, sSurTeam, false) || StrEqual(sArg, "auto", false))
		{
			TF2_ChangeClientTeam(iClient, TFTeam_Zombie);
			ShowVGUIPanel(iClient, sZomVgui);
			return Plugin_Handled;
		}
		
		//If client tries to join the zombie team or spectator
		//during an active round, let them do so.
		else if (StrEqual(sArg, sZomTeam, false) || StrEqual(sArg, "spectate", false))
			return Plugin_Continue;
		
		//Prevent joining any other team.
		else
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Command_JoinClass(int iClient, const char[] sCommand, int iArgs)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (iArgs < 1) return Plugin_Handled;
	
	char sArg[32], sMsg[256];
	GetCmdArg(1, sArg, sizeof(sArg));
	
	if (IsZombie(iClient))
	{
		//Check if the player selected a valid zombie class
		if (IsValidZombieClass(TF2_GetClass(sArg)))
			return Plugin_Continue;
		
		//It's invalid, then display which classes the player can choose
		for (int i = 1; i < view_as<int>(TFClassType); i++)
		{
			if (IsValidZombieClass(view_as<TFClassType>(i)))
			{
				//Place a comma before if it's not the first one
				if (strlen(sMsg))
					Format(sMsg, sizeof(sMsg), "%s,", sMsg);
				
				TF2_GetClassName(sArg, sizeof(sArg), i);
				Format(sMsg, sizeof(sMsg), "%s %s", sMsg, sArg);
			}
		}
		
		CPrintToChat(iClient, "{red}Valid zombies:%s.", sMsg);
		return Plugin_Handled;
	}
	else if (IsSurvivor(iClient))
	{
		//Prevent survivors from switching classes during the round.
		if (g_nRoundState == SZFRoundState_Active)
		{
			CPrintToChat(iClient, "{red}Survivors can't change classes during a round.");
			return Plugin_Handled;
		}
		
		//Check if the player selected a valid survivor class
		if (IsValidSurvivorClass(TF2_GetClass(sArg)))
			return Plugin_Continue;
		
		//It's invalid, then display which classes the player can choose
		for (int i = 1; i < view_as<int>(TFClassType); i++)
		{
			if (IsValidSurvivorClass(view_as<TFClassType>(i)))
			{
				//Place a comma before if it's not the first one
				if (strlen(sMsg))
					Format(sMsg, sizeof(sMsg), "%s,", sMsg);
				
				TF2_GetClassName(sArg, sizeof(sArg), i);
				Format(sMsg, sizeof(sMsg), "%s %s", sMsg, sArg);
			}
		}
		
		CPrintToChat(iClient, "{red}Valid survivors:%s.", sMsg);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Command_VoiceMenu(int iClient, const char[] sCommand, int iArgs)
{
	if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Continue;
	
	if (!g_bEnabled) return Plugin_Continue;
	if (iArgs < 2) return Plugin_Handled;
	
	char sArg1[32];
	char sArg2[32];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	
	//Capture call for medic commands (represented by "voicemenu 0 0").
	//Activate zombie Rage ability (150% health), if possible. Rage
	//can't be activated below full health or if it's already active.
	//Rage recharges after 30 seconds.
	if (sArg1[0] == '0' && sArg2[0] == '0')
	{
		//If an item was succesfully grabbed
		if (AttemptGrabItem(iClient))
			return Plugin_Handled;
		
		if (IsSurvivor(iClient) && AttemptCarryItem(iClient))
			return Plugin_Handled;
		
		if (IsZombie(iClient) && !TF2_IsPlayerInCondition(iClient, TFCond_Taunting))
		{
			if (g_nRoundState == SZFRoundState_Active && g_bSpawnAsSpecialInfected[iClient] && g_bReplaceRageWithSpecialInfectedSpawn[iClient])
			{
				TF2_RespawnPlayer2(iClient);
				
				Call_StartForward(g_hForwardQuickSpawnAsSpecialInfected);
				Call_PushCell(iClient);
				Call_Finish();
				
				//Broadcast to team
				char sName[255];
				char sMessage[255];
				GetClientName2(iClient, sName, sizeof(sName));
				
				Format(sMessage, sizeof(sMessage), "(TEAM) %s\x01 : I have used my {limegreen}quick respawn into special infected\x01!", sName);
				for (int i = 1; i <= MaxClients; i++)
					if (IsValidClient(i) && GetClientTeam(i) == GetClientTeam(iClient))
						CPrintToChatEx(i, iClient, sMessage);
			}
			else if (g_iRageTimer[iClient] == 0)
			{
				switch (g_nInfected[iClient])
				{
					case Infected_None:
					{
						g_iRageTimer[iClient] = 31;
						DoGenericRage(iClient);
						EmitSoundToAll(g_sVoZombieCommonRage[GetRandomInt(0, sizeof(g_sVoZombieCommonRage)-1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
					}
					case Infected_Boomer:
					{
						if (g_nRoundState == SZFRoundState_Active)
						{
							DoBoomerExplosion(iClient, 600.0);
							EmitSoundToAll(g_sVoZombieBoomerExplode[GetRandomInt(0, sizeof(g_sVoZombieBoomerExplode)-1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
						}
					}
					case Infected_Charger:
					{
						g_iRageTimer[iClient] = 16;
						TF2_AddCondition(iClient, TFCond_Charging, 1.65);
						
						//Can sometimes charge for 0.1 sec, add push force
						float vecVel[3], vecAngles[3];
						GetClientEyeAngles(iClient, vecAngles);
						vecVel[0] = 450.0 * Cosine(DegToRad(vecAngles[1]));
						vecVel[1] = 450.0 * Sine(DegToRad(vecAngles[1]));
						TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVel);
						
						EmitSoundToAll(g_sVoZombieChargerCharge[GetRandomInt(0, sizeof(g_sVoZombieChargerCharge)-1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
					}
					case Infected_Kingpin:
					{
						g_iRageTimer[iClient] = 21;
						DoKingpinRage(iClient, 600.0);
						
						char sPath[64];
						Format(sPath, sizeof(sPath), "ambient/halloween/male_scream_%d.wav", GetRandomInt(15, 16));
						EmitSoundToAll(sPath, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
					}
					case Infected_Hunter:
					{
						g_iRageTimer[iClient] = 3;
						DoHunterJump(iClient);
						EmitSoundToAll(g_sVoZombieHunterLeap[GetRandomInt(0, sizeof(g_sVoZombieHunterLeap) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
					}
				}
			}
			else
			{
				ClientCommand(iClient, "voicemenu 2 5");
				PrintHintText(iClient, "Can't Activate Rage!");
			}
			
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action Command_MainMenu(int iClient, int iArgs)
{
	if (!g_bEnabled) return Plugin_Continue;
	Panel_PrintMain(iClient);

	return Plugin_Handled;
}

public void TF2_OnWaitingForPlayersStart()
{
	if (!g_bEnabled) return;

	g_nRoundState = SZFRoundState_Setup;
}

public void TF2_OnWaitingForPlayersEnd()
{
	if (!g_bEnabled) return;

	g_nRoundState = SZFRoundState_Grace;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled) return;
	if (g_nRoundState == SZFRoundState_Setup) return;
	
	DetermineControlPoints();
	
	g_bLastSurvivor = false;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_iDamage[iClient] = 0;
		g_iKillsThisLife[iClient] = 0;
		g_bSpawnAsSpecialInfected[iClient] = false;
		g_nInfected[iClient] = Infected_None;
		g_nNextInfected[iClient] = Infected_None;
		g_bReplaceRageWithSpecialInfectedSpawn[iClient] = false;
		g_iEyelanderHead[iClient] = 0;
		g_iMaxHealth[iClient] = -1;
		g_iSuperHealthSubtract[iClient] = 0;
		g_flTimeStartAsZombie[iClient] = 0.0;
	}
	
	for (int i = 0; i < view_as<int>(Infected); i++)
	{
		g_flInfectedCooldown[i] = 0.0;
		g_iInfectedCooldown[i] = 0;
	}
	
	g_iZombieTank = 0;
	RemoveAllGoo();
	
	g_nRoundState = SZFRoundState_Grace;
	
	CPrintToChatAll("{green}Grace period begun. Survivors can change classes.");
	
	//Assign players to zombie and survivor teams.
	if (g_bNewRound)
	{
		int[] iClients = new int[MaxClients];
		int iLength = 0;
		int iSurvivorCount;
		
		//Find all active players.
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			g_iZombiesKilledSurvivor[iClient] = 0;
			EndSound(iClient);
			
			if (IsClientInGame(iClient) && TF2_GetClientTeam(iClient) > TFTeam_Spectator)
			{
				iClients[iLength] = iClient;
				iLength++;
			}
		}
		
		//Randomize, sort players
		SortIntegers(iClients, iLength, Sort_Random);
		
		//Calculate team counts. At least one survivor must exist.
		iSurvivorCount = RoundToFloor(iLength * g_cvRatio.FloatValue);
		if (iSurvivorCount == 0 && iLength > 0)
			iSurvivorCount = 1;
		
		TFTeam[] nClientTeam = new TFTeam[MaxClients+1];
		g_iStartSurvivors = 0;
		
		//Check if we need to force players to survivor or zombie team
		for (int i = 0; i < iLength; i++)
		{
			int iClient = iClients[i];
			
			if (IsValidClient(iClient))
			{
				Action action = Plugin_Continue;
				Call_StartForward(g_hForwardStartZombie);
				Call_PushCell(iClient);
				Call_Finish(action);
				
				if (action == Plugin_Handled)
				{
					//Zombie
					SpawnClient(iClient, TFTeam_Zombie);
					nClientTeam[iClient] = TFTeam_Zombie;
					g_bStartedAsZombie[iClient] = true;
					g_flTimeStartAsZombie[iClient] = GetGameTime();
				}
				else if (g_bForceZombieStart[iClient] && !g_bFirstRound)
				{
					//If they attempted to skip playing as zombie last time, force him to be in zombie team
					CPrintToChat(iClient, "{red}You have been forcibly set to infected team due to attempting to skip playing as a infected.");
					g_bForceZombieStart[iClient] = false;
					SetClientCookie(iClient, g_cForceZombieStart, "0");
					
					//Zombie
					SpawnClient(iClient, TFTeam_Zombie);
					nClientTeam[iClient] = TFTeam_Zombie;
					g_bStartedAsZombie[iClient] = true;
					g_flTimeStartAsZombie[iClient] = GetGameTime();
				}
				else if (g_bStartedAsZombie[iClient])
				{
					//Players who started as zombie last time is forced to be survivors
					
					//Survivor
					SpawnClient(iClient, TFTeam_Survivor);
					nClientTeam[iClient] = TFTeam_Survivor;
					g_bStartedAsZombie[iClient] = false;
					g_iStartSurvivors++;
					iSurvivorCount--;
				}
			}
		}
		
		//From SortIntegers, we set the rest to survivors, then zombies
		for (int i = 0; i < iLength; i++)
		{
			int iClient = iClients[i];
			
			//Check if they have not already been assigned
			if (IsValidClient(iClient) && !(nClientTeam[iClient] == TFTeam_Zombie) && !(nClientTeam[iClient] == TFTeam_Survivor))
			{
				if (iSurvivorCount > 0)
				{
					//Survivor
					SpawnClient(iClient, TFTeam_Survivor);
					nClientTeam[iClient] = TFTeam_Survivor;
					g_bStartedAsZombie[iClient] = false;
					g_iStartSurvivors++;
					iSurvivorCount--;
				}
				else
				{
					//Zombie
					SpawnClient(iClient, TFTeam_Zombie);
					nClientTeam[iClient] = TFTeam_Zombie;
					g_bStartedAsZombie[iClient] = true;
					g_flTimeStartAsZombie[iClient] = GetGameTime();
				}
			}
		}
	}
	
	//Reset counters
	g_flCapScale = -1.0;
	g_flSurvivorsLastDeath = GetGameTime();
	g_iSurvivorsKilledCounter = 0;
	g_iZombiesKilledCounter = 0;
	g_iZombiesKilledSpree = 0;
	
	g_flTimeProgress = 0.0;
	g_hTimerProgress = null;
	
	//Handle grace period timers.
	CreateTimer(0.5, Timer_GraceStartPost, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(45.0, Timer_GraceEnd, TIMER_FLAG_NO_MAPCHANGE);
	
	SetGlow();
	UpdateZombieDamageScale();
}

public Action Event_SetupEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled) return;
	
	EndGracePeriod();
}

void EndGracePeriod()
{
	if (!g_bEnabled) return;
	if (g_nRoundState != SZFRoundState_Grace) return; //No point in ending grace period if it's not grace period it in the first place.
	
	g_nRoundState = SZFRoundState_Active;
	CPrintToChatAll("{orange}Grace period complete. Survivors can no longer change classes.");
	
	int iSurvivors = GetSurvivorCount();
	int iZombies = GetZombieCount();
	
	//If less than 15% of players are infected, set round start as imbalanced
	bool bImbalanced = (float(iZombies) / float(iSurvivors + iZombies) <= 0.15);
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			if (g_bWaitingForTeamSwitch[iClient])
				RequestFrame(Frame_PostGracePeriodSpawn, iClient); //A frame later so maps which have post-setup spawn points can adapt to these players
			
			//Give a buff to infected if the round is imbalanced
			if (bImbalanced)
			{
				if (IsZombie(iClient) && IsPlayerAlive(iClient))
				{
					SetEntityHealth(iClient, 450);
					g_bSpawnAsSpecialInfected[iClient] = true;
				}
				
				CPrintToChat(iClient, "%sInfected have received extra health and other benefits to ensure game balance at the start of the round.", (IsZombie(iClient)) ? "{green}" : "{red}");
			}
		}
	}
	
	g_flTimeProgress = 0.0;
	g_hTimerProgress = CreateTimer(6.0, Timer_Progress, _, TIMER_REPEAT);
	
	g_bFirstRound = false;
	g_flTankCooldown = GetGameTime() + 120.0 - fMin(0.0, (iSurvivors-12) * 3.0); //2 min cooldown before tank spawns will be considered
	g_flSelectSpecialCooldown = GetGameTime() + 120.0 - fMin(0.0, (iSurvivors-12) * 3.0); //2 min cooldown before select special will be considered
	g_flRageCooldown = GetGameTime() + 60.0 - fMin(0.0, (iSurvivors-12) * 1.5); //1 min cooldown before frenzy will be considered
	g_flSurvivorsLastDeath = GetGameTime();
}

public void Frame_PostGracePeriodSpawn(int iClient)
{
	TF2_ChangeClientTeam(iClient, TFTeam_Zombie);
	
	if (!IsPlayerAlive(iClient))
	{
		if (TFTeam_Zombie == TFTeam_Blue)
			ShowVGUIPanel(iClient, "class_blue");
		else
			ShowVGUIPanel(iClient, "class_red");
	}
	
	g_bWaitingForTeamSwitch[iClient] = false;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	//Prepare for a completely new round, if
	//+ Round was a full round (full_round flag is set), OR
	//+ Zombies are the winning team.
	TFTeam nTeam = view_as<TFTeam>(event.GetInt("team"));
	g_bNewRound = event.GetBool("full_round") || (nTeam == TFTeam_Zombie);
	g_nRoundState = SZFRoundState_End;
	
	if (nTeam == TFTeam_Zombie)
		PlaySoundAll(SoundMusic_ZombieWin);
	else if (nTeam == TFTeam_Survivor)
		PlaySoundAll(SoundMusic_SurvivorWin);
	
	SetGlow();
	UpdateZombieDamageScale();
	g_bTankRefreshed = false;
	
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled) return Plugin_Continue;
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	//Reset overlay
	ClientCommand(iClient, "r_screenoverlay\"\"");
	
	if (g_iMaxHealth[iClient] != -1)
	{
		//Make sure max health hook is reset properly
		g_iMaxHealth[iClient] = -1;
		TF2_RespawnPlayer2(iClient);
		return Plugin_Stop;
	}
	
	g_iEyelanderHead[iClient] = 0;
	g_iSuperHealthSubtract[iClient] = 0;
	g_bHitOnce[iClient] = false;
	g_bHopperIsUsingPounce[iClient] = false;
	g_bBackstabbed[iClient] = false;
	g_iKillsThisLife[iClient] = 0;
	g_iDamageTakenLife[iClient] = 0;
	g_iDamageDealtLife[iClient] = 0;
	
	DropCarryingItem(iClient, false);
	
	SetEntityRenderColor(iClient, 255, 255, 255, 255);
	SetEntityRenderMode(iClient, RENDER_NORMAL);
	
	if (g_nRoundState == SZFRoundState_Active)
	{
		if (g_iZombieTank > 0 && g_iZombieTank == iClient)
		{
			g_nInfected[iClient] = Infected_None;
			
			if (TF2_GetPlayerClass(iClient) != TFClass_Heavy)
			{
				TF2_SetPlayerClass(iClient, TFClass_Heavy, true, true);
				TF2_RespawnPlayer(iClient);
				return Plugin_Stop;
			}
			else
			{
				g_iZombieTank = 0;
				g_nInfected[iClient] = Infected_Tank;
				g_flTankLifetime[iClient] = GetGameTime();
				
				int iSurvivors = GetSurvivorCount();
				int iHealth = g_cvTankHealth.IntValue * iSurvivors;
				if (iHealth < g_cvTankHealthMin.IntValue) iHealth = g_cvTankHealthMin.IntValue;
				if (iHealth > g_cvTankHealthMax.IntValue) iHealth = g_cvTankHealthMax.IntValue;
				
				g_iMaxHealth[iClient] = iHealth;
				SetEntityHealth(iClient, iHealth);
				
				int iSubtract = 0;
				if (g_cvTankTime.FloatValue > 0.0)
				{
					iSubtract = RoundFloat(float(iHealth) / g_cvTankTime.FloatValue);
					if (iSubtract < 3) iSubtract = 3;
				}
				
				g_iSuperHealthSubtract[iClient] = iSubtract;
				TF2_AddCondition(iClient, TFCond_Kritzkrieged, TFCondDuration_Infinite);
				
				SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
				SetEntityRenderColor(iClient, GetInfectedColor(0, Infected_Tank), GetInfectedColor(1, Infected_Tank), GetInfectedColor(2, Infected_Tank), GetInfectedColor(3, Infected_Tank));
				
				EmitSoundToAll(g_sVoZombieTankOnFire[GetRandomInt(0, sizeof(g_sVoZombieTankOnFire)-1)]);
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						if (GetCookie(i, g_cFirstTimeSurvivor) < 2)
						{
							DataPack data;
							CreateDataTimer(0.5, Timer_DisplayTutorialMessage, data);
							data.WriteCell(i);
							data.WriteFloat(4.0);
							data.WriteString("Do not let the Tank get close to you, his attacks are very lethal.");
							
							CreateDataTimer(4.5, Timer_DisplayTutorialMessage, data);
							data.WriteCell(i);
							data.WriteFloat(4.0);
							data.WriteString("Run and shoot the Tank, it will slow the Tank down and kill it.");
							
							SetCookie(i, 2, g_cFirstTimeSurvivor);
						}
						
						CPrintToChat(i, "{red}Incoming TAAAAANK!");
						
						if (GetCurrentSound(i) != SoundMusic_LastStand || !IsMusicOverrideOn()) //lms current sound check seems not to work, may need to check it later
							PlaySound(i, SoundMusic_Tank);	
					}
					
					g_flDamageDealtAgainstTank[i] = 0.0;
				}
				
				Call_StartForward(g_hForwardTankSpawn);
				Call_PushCell(iClient);
				Call_Finish();
			}
		}
		else
		{			
			//If client got a force set as specific special infected, set as that infected
			if (g_nNextInfected[iClient] != Infected_None && g_nInfected[iClient] != Infected_Tank)
			{
				g_nInfected[iClient] = g_nNextInfected[iClient];
			}
			else if (g_bSpawnAsSpecialInfected[iClient] == true)
			{
				g_bSpawnAsSpecialInfected[iClient] = false;
				
				//Create list of all special infected to randomize, apart from tank and non-special infected
				int iLength = view_as<int>(Infected) - 2;
				Infected[] nSpecialInfected = new Infected[iLength];
				for (int i = 0; i < iLength; i++)
					nSpecialInfected[i] = view_as<Infected>(i + 2);
				
				//Randomize, sort list of special infected
				SortIntegers(view_as<int>(nSpecialInfected), iLength, Sort_Random);
				
				//Go through each special infected in the list and find the first one thats not in cooldown
				int i = 0;
				while (g_nInfected[iClient] == Infected_None && i < iLength)
				{
					if (IsValidInfected(nSpecialInfected[i]) && g_flInfectedCooldown[nSpecialInfected[i]] <= GetGameTime() - 12.0 && g_iInfectedCooldown[nSpecialInfected[i]] != iClient)
					{
						//We found it, set as that special infected
						g_nInfected[iClient] = nSpecialInfected[i];
					}
					
					i++;
				}
				
				//Check if player spawned using fast respawn
				if (g_bReplaceRageWithSpecialInfectedSpawn[iClient])
				{
					//Check if they did not become special infected because all is in cooldown
					if (g_nInfected[iClient] == Infected_None)
						CPrintToChat(iClient, "{red}All special infected seems to be in a cooldown...");
					
					g_bReplaceRageWithSpecialInfectedSpawn[iClient] = false;
				}
			}
			
			if (g_nInfected[iClient] != Infected_None && g_nInfected[iClient] != Infected_Tank && g_iInfectedCooldown[g_nInfected[iClient]] != iClient)
			{
				//Set new cooldown
				g_flInfectedCooldown[g_nInfected[iClient]] = GetGameTime();	//time for cooldown
				g_iInfectedCooldown[g_nInfected[iClient]] = iClient;			//client to prevent abuse to cycle through any infected
			}
			
			if (TF2_GetPlayerClass(iClient) != GetInfectedClass(g_nInfected[iClient]))
			{
				TF2_SetPlayerClass(iClient, GetInfectedClass(g_nInfected[iClient]), true, false);
				TF2_RespawnPlayer(iClient);
				return Plugin_Stop;
			}
			
			SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
			SetEntityRenderColor(iClient, GetInfectedColor(0, g_nInfected[iClient]), GetInfectedColor(1, g_nInfected[iClient]), GetInfectedColor(2, g_nInfected[iClient]), GetInfectedColor(3, g_nInfected[iClient]));
			
			char sMsg[256];
			GetInfectedMessage(sMsg, sizeof(sMsg), g_nInfected[iClient]);
			CPrintToChat(iClient, sMsg);
			
			if (g_bShouldBacteriaPlay[iClient])
			{
				EmitSoundToClient(iClient, g_sSoundSpawnInfected[g_nInfected[iClient]]);
				
				for (int i = 1; i <= MaxClients; i++)
					if (IsValidSurvivor(i))
						EmitSoundToClient(i, g_sSoundSpawnInfected[g_nInfected[iClient]]);
				
				g_bShouldBacteriaPlay[iClient] = false;
			}
		}
	}
	
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	
	ResetClientState(iClient);
	//1. Prevent players spawning on survivors if round has started.
	//       Prevent players spawning on survivors as an invalid class.
	//       Prevent players spawning on zombies as an invalid class.
	if (IsSurvivor(iClient))
	{
		if (g_nRoundState == SZFRoundState_Active)
		{
			SpawnClient(iClient, TFTeam_Zombie);
			return Plugin_Continue;
		}
		
		if (!IsValidSurvivorClass(nClass))
		{
			SpawnClient(iClient, TFTeam_Survivor);
			return Plugin_Continue;
		}
	}
	
	else if (IsZombie(iClient))
	{
		if (!IsValidZombieClass(nClass))
		{
			SpawnClient(iClient, TFTeam_Zombie);
			return Plugin_Continue;
		}
		
		if (g_nRoundState == SZFRoundState_Active)
			if (g_nInfected[iClient] != Infected_Tank && !PerformFastRespawn(iClient))
				TF2_AddCondition(iClient, TFCond_Ubercharged, 2.0);
		
		//Set zombie model / soul wearable
		ApplyVoodooCursedSoul(iClient);
	}
	
	//2. Handle valid, post spawn logic
	CreateTimer(0.1, Timer_PostSpawn, iClient, TIMER_FLAG_NO_MAPCHANGE);
	
	SetGlow();
	
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	int iKillers[2];
	int iVictim = GetClientOfUserId(event.GetInt("userid"));
	iKillers[0] = GetClientOfUserId(event.GetInt("attacker"));
	iKillers[1] = GetClientOfUserId(event.GetInt("assister"));
	
	ClientCommand(iVictim, "r_screenoverlay\"\"");
	
	DropCarryingItem(iVictim);
	
	//Handle bonuses
	if (IsValidZombie(iKillers[0]) && iKillers[0] != iVictim)
	{
		g_iKillsThisLife[iKillers[0]]++;
		
		//50%
		if (g_nNextInfected[iKillers[0]] == Infected_None && !GetRandomInt(0, 1) && g_nRoundState == SZFRoundState_Active)
			g_bSpawnAsSpecialInfected[iKillers[0]] = true;
		
		if (g_iKillsThisLife[iKillers[0]] == 3)
			TF2_AddCondition(iKillers[0], TFCond_DefenseBuffed, TFCondDuration_Infinite);
	}
	
	if (IsValidZombie(iKillers[1]) && iKillers[1] != iVictim)
	{
		//20%
		if (g_nNextInfected[iVictim] == Infected_None && !GetRandomInt(0, 4) && g_nRoundState == SZFRoundState_Active)
			g_bSpawnAsSpecialInfected[iKillers[1]] = true;
	}
	
	if (g_nInfected[iVictim] == Infected_Tank)
	{
		g_iDamage[iVictim] = GetAverageDamage();
		
		int iWinner = 0;
		float flHighest = 0.0;
		
		EmitSoundToAll(g_sVoZombieTankDeath[GetRandomInt(0, sizeof(g_sVoZombieTankDeath)-1)]);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			//If current music is tank, end it
			if (GetCurrentSound(i) == SoundMusic_Tank) EndSound(i);
			
			if (IsValidLivingSurvivor(i))
			{
				if (flHighest < g_flDamageDealtAgainstTank[i])
				{
					flHighest = g_flDamageDealtAgainstTank[i];
					iWinner = i;
				}
				
				AddMorale(i, 20);
			}
		}
		
		if (flHighest > 0.0)
		{
			SetHudTextParams(-1.0, 0.3, 8.0, 200, 255, 200, 128, 1);
			
			for (int i = 1; i <= MaxClients; i++)
				if (IsValidClient(i))
					ShowHudText(i, 5, "The Tank '%N' has died\nMost damage: %N (%d)", iVictim, iWinner, RoundFloat(flHighest));
		}
		
		if (g_iDamageDealtLife[iVictim] <= 50 && g_iDamageTakenLife[iVictim] <= 150 && !g_bTankRefreshed)
		{
			g_bTankRefreshed = true;
			g_nInfected[iVictim] = Infected_None;
			ZombieTank();
		}
		
		Call_StartForward(g_hForwardTankDeath);
		Call_PushCell(iVictim);
		Call_PushCell(iWinner);
		Call_PushCell(RoundFloat(flHighest));
		Call_Finish();
	}
	
	g_iEyelanderHead[iVictim] = 0;
	g_iMaxHealth[iVictim] = -1;
	g_bShouldBacteriaPlay[iVictim] = true;
	g_bReplaceRageWithSpecialInfectedSpawn[iVictim] = false;
	
	Infected g_nInfectedIndex = g_nInfected[iVictim];
	g_nInfected[iVictim] = Infected_None;
	
	//Handle zombie death logic, all round states.
	if (IsValidZombie(iVictim))
	{
		//10%
		if (IsValidSurvivor(iKillers[0]) && !GetRandomInt(0, 9) && g_nRoundState == SZFRoundState_Active)
			g_bSpawnAsSpecialInfected[iVictim] = true;
		
		//Boomer
		if (g_nInfectedIndex == Infected_Boomer)
			DoBoomerExplosion(iVictim, 400.0);
		
		//Set special infected state
		if (g_nNextInfected[iVictim] != Infected_None)
		{
			if (iVictim != g_iZombieTank) g_nInfected[iVictim] = g_nNextInfected[iVictim];
			g_nNextInfected[iVictim] = Infected_None;
		}
		
		//Remove dropped ammopacks from zombies.
		int iEntity = -1;
		while ((iEntity = FindEntityByClassname(iEntity, "tf_ammo_pack")) != -1)
			if (GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iVictim)
				AcceptEntityInput(iEntity, "Kill");
		
		//Zombie rage: instant respawn
		if (g_bZombieRage && g_nRoundState == SZFRoundState_Active)
		{
			float flTimer = 0.1;
			
			//Check if respawn stress reaches time limit, if so add cooldown/timer so we dont instant respawn too much zombies at once
			if (g_flRageRespawnStress > GetGameTime())
				flTimer += (g_flRageRespawnStress - GetGameTime()) * 1.2;
			
			g_flRageRespawnStress += 1.7;	//Add stress time 1.7 sec for every respawn zombies
			CreateTimer(flTimer, Timer_RespawnPlayer, iVictim);
		}
		
		//Check for spec bypass from AFK manager
		RequestFrame(Frame_CheckZombieBypass, iVictim);
	}
	
	//Instant respawn outside of the actual gameplay
	if (g_nRoundState != SZFRoundState_Active && g_nRoundState != SZFRoundState_End)
	{
		CreateTimer(0.1, Timer_RespawnPlayer, iVictim);
		return Plugin_Continue;
	}
	
	//Handle survivor death logic, active round only.
	if (IsValidSurvivor(iVictim))
	{
		//Black and white effect for death
		ClientCommand(iVictim, "r_screenoverlay\"debug/yuv\"");
		
		if (IsValidZombie(iKillers[0]))
		{
			g_flSurvivorsLastDeath = GetGameTime();
			g_iZombiesKilledSpree = max(RoundToNearest(float(g_iZombiesKilledSpree) / 2.0) - 8, 0);
			g_iSurvivorsKilledCounter++;
		}
		
		//reset backstab state
		g_bBackstabbed[iVictim] = false;
		
		//Set zombie time to iVictim as he started playing zombie
		g_flTimeStartAsZombie[iVictim] = GetGameTime();
		
		//Transfer player to zombie team.
		CreateTimer(6.0, Timer_Zombify, iVictim, TIMER_FLAG_NO_MAPCHANGE);
		//Check if he's the last
		CreateTimer(0.1, CheckLastPlayer);
		
		PlaySound(iVictim, SoundEvent_Dead, 3.0);
	}
	
	//Handle zombie death logic, active round only.
	else if (IsValidZombie(iVictim))
	{
		if (IsValidSurvivor(iKillers[0]))
		{
			g_iZombiesKilledSpree++;
			g_iZombiesKilledCounter++;
			g_iZombiesKilledSurvivor[iKillers[0]]++;
			
			//very very very dirty fix for eyelander head
			char sWeapon[128];
			event.GetString("weapon", sWeapon, sizeof(sWeapon));
			if (StrEqual(sWeapon, "sword")
				|| StrEqual(sWeapon, "headtaker")
				|| StrEqual(sWeapon, "nessieclub") )
			{
				g_iEyelanderHead[iKillers[0]]++;
			}
		}
		
		for (int i = 0; i < 2; i++)
		{
			if (IsValidLivingClient(iKillers[i]))
			{
				//Handle ammo kill bonuses.
				TF2_AddAmmo(iKillers[i], WeaponSlot_Primary, GetSurvivorAmmo(TF2_GetPlayerClass(iKillers[i])));
				
				//Handle morale bonuses.
				//+ Each kill adds morale.
				
				//Player gets more morale if low morale instead of high morale
				//Player gets more morale if high zombies, but dont give too much morale if already at high
				
				int iMorale = GetMorale(iKillers[i]);
				if (iMorale < 0) iMorale = 0;
				else if (iMorale > 100) iMorale = 100;
				float flPercentage = (float(GetZombieCount()) / (float(GetZombieCount()) + float(GetSurvivorCount())));
				int iBase;
				float flMultiplier;
				
				//Roll to get starting morale adds
				if (i == 0)	//Main killer
				{
					if (g_nInfectedIndex == Infected_None)
						iBase = GetRandomInt(6, 9);
					else
						iBase = GetRandomInt(10, 13);
				}
				else	//Assist kill
				{
					if (g_nInfectedIndex == Infected_None)
						iBase = GetRandomInt(2, 5);
					else
						iBase = GetRandomInt(6, 9);
				}
				
				//  0 morale   0% zombies -> 1.0
				//  0 morale 100% zombies -> 2.0
				
				// 50 morale   0% zombies -> 0.5
				// 50 morale 100% zombies -> 1.0
				
				//100 morale   0% zombies -> 0.0
				//100 morale 100% zombies -> 0.0
				flMultiplier = (1.0 - (float(iMorale) / 100.0)) * (flPercentage * 2.0);
				
				//Multiply base roll by multiplier
				iBase = RoundToNearest(float(iBase) * flMultiplier);
				AddMorale(iKillers[i], iBase);
				
				//+ Each kill grants a small health bonus and increases current crit bonus.
				int iHealth = GetClientHealth(iKillers[i]);
				int iMaxHealth = SDK_GetMaxHealth(iKillers[i]);
				if (iHealth < iMaxHealth)
				{
					iHealth += iMorale * 2;
					iHealth = min(iHealth, iMaxHealth);
					//SetEntityHealth(iKillers[i], iHealth);
				}
			}
		}
	}
	
	SetGlow();
	
	return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	int iVictim = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	int iDamageAmount = event.GetInt("damageamount");
	
	if (IsValidClient(iVictim) && IsValidClient(iAttacker) && iAttacker != iVictim)
	{
		g_iDamageTakenLife[iVictim] += iDamageAmount;
		g_iDamageDealtLife[iAttacker] += iDamageAmount;
		g_iDamage[iAttacker] += iDamageAmount;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerBuiltObject(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	int iEntity = event.GetInt("index");
	TFObjectType nObjectType = view_as<TFObjectType>(event.GetInt("object"));
	
	//1. Handle dispenser rules.
	//       Disable dispensers when they begin construction.
	//       Increase max health to 300 (default level 1 is 150).
	if (nObjectType == TFObject_Dispenser)
	{
		SetEntProp(iEntity, Prop_Send, "m_bDisabled", 1); //fuck you
		SetEntProp(iEntity, Prop_Send, "m_bCarried", 1); //die already
		SetEntProp(iEntity, Prop_Send, "m_iMaxHealth", 300);
		AcceptEntityInput(iEntity, "Disable"); //just stop doing that beam thing you cunt
	}
	
	return Plugin_Continue;
}

public Action Event_CPCapture(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iControlPoints <= 0) return;
	
	int iCaptureIndex = event.GetInt("cp");
	if (iCaptureIndex < 0) return;
	if (iCaptureIndex >= g_iControlPoints) return;
	
	for (int i = 0; i < g_iControlPoints; i++)
	{
		if (g_iControlPointsInfo[i][0] == iCaptureIndex)
			g_iControlPointsInfo[i][1] = 2;
	}
	
	//Control point capture: increase morale
	for (int iClient = 0; iClient < MaxClients; iClient++)
	{
		if (g_iCapturingPoint[iClient] == iCaptureIndex)
		{
			AddMorale(iClient, 20);
			g_iCapturingPoint[iClient] = -1;
		}
	}
	
	CheckRemainingCP();
}

public Action Event_CPCaptureStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iControlPoints <= 0) return;
	
	int iCaptureIndex = event.GetInt("cp");
	if (iCaptureIndex < 0) return;
	if (iCaptureIndex >= g_iControlPoints) return;
	
	for (int i = 0; i < g_iControlPoints; i++)
		if (g_iControlPointsInfo[i][0] == iCaptureIndex)
			g_iControlPointsInfo[i][1] = 1;
	
	CheckRemainingCP();
}

////////////////////////////////////////////////////////////
//
// Periodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action Timer_Main(Handle hTimer) //1 second
{
	if (!g_bEnabled) return;
	
	Handle_SurvivorAbilities();
	Handle_ZombieAbilities();
	UpdateZombieDamageScale();
	SoundTimer();
	
	if (g_bZombieRage)
		SetTeamRespawnTime(TFTeam_Zombie, 0.0);
	else
		SetTeamRespawnTime(TFTeam_Zombie, fMax(6.0, 12.0 / fMax(0.6, g_flZombieDamageScale) - g_iZombiesKilledSpree * 0.02));
	
	if (g_nRoundState == SZFRoundState_Active)
	{
		Handle_WinCondition();
		
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			//Alive infected
			if (IsValidLivingZombie(iClient))
			{
				//Tank
				if (g_nInfected[iClient] == Infected_Tank)
				{
					//Tank super health handler
					int iHealth = GetClientHealth(iClient);
					int iMaxHealth = SDK_GetMaxHealth(iClient);
					if (iHealth < iMaxHealth || g_flTankLifetime[iClient] < GetGameTime() - 15.0)
					{
						if (iHealth - g_iSuperHealthSubtract[iClient] > 0)
							SetEntityHealth(iClient, iHealth - g_iSuperHealthSubtract[iClient]);
						else
							ForcePlayerSuicide(iClient);
					}
					
					//Screen shake if tank is close by
					float vecPosClient[3];
					float vecPosTank[3];
					float flDistance;
					GetClientEyePosition(iClient, vecPosTank);
					
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i))
						{
							GetClientEyePosition(i, vecPosClient);
							flDistance = GetVectorDistance(vecPosTank, vecPosClient);
							flDistance /= 20.0;
							if (flDistance <= 50.0)
								Shake(i, fMin(50.0 - flDistance, 5.0), 1.2);
						}
					}
				}
				
				//Kingpin
				if (g_nInfected[iClient] == Infected_Kingpin)
				{
					TF2_AddCondition(iClient, TFCond_TeleportedGlow, 1.5);
					
					float flPosClient[3];
					float flPosScreamer[3];
					float flDistance;
					GetClientEyePosition(iClient, flPosScreamer);
					
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsValidLivingZombie(i))
						{
							GetClientEyePosition(i, flPosClient);
							flDistance = GetVectorDistance(flPosScreamer, flPosClient);
							if (flDistance <= 600.0)
							{
								TF2_AddCondition(i, TFCond_TeleportedGlow, 1.5);
								g_iScreamerNearby[i] = true;
							}
							else
							{
								g_iScreamerNearby[i] = false;
							}
						}
					}
				}
				
				//Stalker
				if (g_nInfected[iClient] == Infected_Stalker)
				{
					float vecPosClient[3];
					float vecPosPredator[3];
					float flDistance;
					bool bTooClose = false;
					GetClientEyePosition(iClient, vecPosPredator);
					
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsValidLivingSurvivor(i))
						{
							GetClientEyePosition(i, vecPosClient);
							flDistance = GetVectorDistance(vecPosPredator, vecPosClient);
							if (flDistance <= 250.0)
								bTooClose = true;
						}
					}
					
					if (!bTooClose && !TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
						TF2_AddCondition(iClient, TFCond_Cloaked, -1.0);
					else if (bTooClose && TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
						TF2_RemoveCondition(iClient, TFCond_Cloaked);
				}
				
				//If no special select cooldown is active and less than 2 people have been selected for the respawn into special infected
				//AND
				//damage scale is 120% and a dice roll is hit OR the damage scale is 160%
				if ( g_nRoundState == SZFRoundState_Active 
					&& g_flSelectSpecialCooldown <= GetGameTime() 
					&& GetReplaceRageWithSpecialInfectedSpawnCount() <= 2 
					&& g_iZombieTank != iClient
					&& g_nInfected[iClient] == Infected_None 
					&& g_nNextInfected[iClient] == Infected_None 
					&& g_bSpawnAsSpecialInfected[iClient] == false
					&& ( (g_flZombieDamageScale >= 1.0 
					&& !GetRandomInt(0, RoundToCeil(200 / g_flZombieDamageScale)))
					|| g_flZombieDamageScale >= 1.6 ) )
				{
					g_bSpawnAsSpecialInfected[iClient] = true;
					g_bReplaceRageWithSpecialInfectedSpawn[iClient] = true;
					g_flSelectSpecialCooldown = GetGameTime() + 20.0;
					CPrintToChat(iClient, "{green}You have been selected to become a Special Infected! {orange}Call 'MEDIC!' to respawn as one or become one on death.");
				}
			}
		}
	}
}

public Action Timer_MoraleDecay(Handle hTimer) //Timer scales based on how many zombies, slow if low zombies, fast if high zombies
{
	if (!g_bEnabled) return Plugin_Stop;
	
	AddMoraleAll(-1);
	
	float flTimer;
	if (GetZombieCount() + GetSurvivorCount() != 0)
	{
		float flPercentage = (float(GetZombieCount()) / float(GetZombieCount() + GetSurvivorCount()));
		flTimer = ((1.0 - flPercentage) * 5.0);	//Calculate timer to reduce morale, 5.0 sec if 0% zombies, min 0.5 sec if 90% zombies
		
		if (flTimer < 0.5)
			flTimer = 0.5;
	}
	else
		flTimer = 5.0;
	
	g_hTimerMoraleDecay = CreateTimer(flTimer, Timer_MoraleDecay);
	
	return Plugin_Continue;
}

public Action Timer_MainSlow(Handle hTimer) //4 mins
{
	if (!g_bEnabled) return Plugin_Stop;
	PrintInfoChat(0);
	
	return Plugin_Continue;
}

public Action Timer_MainFast(Handle hTimer)
{
	if (!g_bEnabled) return Plugin_Stop;
	GooDamageCheck();
	
	return Plugin_Continue;
}

public Action Timer_Hoarde(Handle hTimer) //5 seconds
{
	if (!g_bEnabled) return Plugin_Stop;
	Handle_HoardeBonus();
	
	return Plugin_Continue;
}

public Action Timer_Datacollect(Handle hTimer) //2 seconds
{
	if (!g_bEnabled) return Plugin_Stop;
	FastRespawnDataCollect();
	
	return Plugin_Continue;
}

public Action Timer_Progress(Handle hTimer) //6 seconds
{
	if (g_hTimerProgress != hTimer) return Plugin_Stop;
	if (!g_bEnabled) return Plugin_Stop;
	g_flTimeProgress += 0.01;
	
	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Aperiodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action Timer_GraceStartPost(Handle hTimer)
{
	//Disable all resupply cabinets.
	int iEntity = -1;
	while((iEntity = FindEntityByClassname(iEntity, "func_regenerate")) != -1)
		AcceptEntityInput(iEntity, "Disable");
	
	//Remove all dropped ammopacks.
	iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "tf_ammo_pack")) != -1)
		AcceptEntityInput(iEntity, "Kill");
	
	//Remove all ragdolls.
	iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "tf_ragdoll")) != -1)
		AcceptEntityInput(iEntity, "Kill");
	
	//Disable all payload cart dispensers.
	iEntity = -1;
	while((iEntity = FindEntityByClassname(iEntity, "mapobj_cart_dispenser")) != -1)
		SetEntProp(iEntity, Prop_Send, "m_bDisabled", 1);
	
	//Disable all respawn room visualizers (non-ZF maps only)
	if (!IsMapSZF())
	{
		char strParent[255];
		iEntity = -1;
		while((iEntity = FindEntityByClassname(iEntity, "func_respawnroomvisualizer")) != -1)
		{
			GetEntPropString(iEntity, Prop_Data, "respawnroomname", strParent, sizeof(strParent));
			if (!StrEqual(strParent, "ZombieSpawn", false))
				AcceptEntityInput(iEntity, "Disable");
		}
	}
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidSurvivor(iClient))
			PlaySound(iClient, SoundMusic_Prepare, 33.0);
}

public Action Timer_GraceEnd(Handle hTimer)
{
	EndGracePeriod();
	
	return Plugin_Continue;
}

public Action Timer_InitialHelp(Handle hTimer, int iClient)
{
	//Wait until client is in game before printing initial help text.
	if (IsClientInGame(iClient))
		PrintInfoChat(iClient);
	else
		CreateTimer(10.0, Timer_InitialHelp, iClient, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

public Action Timer_PostSpawn(Handle hTimer, int iClient)
{
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && GetClientTeam(iClient) > 1)
	{
		if (IsZombie(iClient))
		{
			HandleZombieLoadout(iClient);
			if (GetCookie(iClient, g_cFirstTimeZombie) < 1)
				InitiateZombieTutorial(iClient);
		}
		
		if (IsSurvivor(iClient))
		{
			HandleSurvivorLoadout(iClient);
			if (GetCookie(iClient, g_cFirstTimeSurvivor) < 1)
			{
				InitiateSurvivorTutorial(iClient);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_Zombify(Handle hTimer, int iClient)
{
	if (g_nRoundState != SZFRoundState_Active) return Plugin_Continue;
	if (IsValidClient(iClient))
	{
		CPrintToChat(iClient, "{red}You have perished and turned into a zombie...");
		SpawnClient(iClient, TFTeam_Zombie);
	}
	
	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Handling Functionality
//
////////////////////////////////////////////////////////////

public void OnGameFrame()
{
	if (!g_bEnabled) return;
	
	int iCount = GetSurvivorCount();
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && IsZombie(iClient))
		{
			if (g_nInfected[iClient] == Infected_Stalker)
			{
				TF2_SetCloakMeter(iClient, 100.0);
			}
			else if (g_nInfected[iClient] == Infected_Smoker)
			{
				//For visual purposes, really
				if (TF2_GetCloakMeter(iClient) > 1.0)
					TF2_SetCloakMeter(iClient, 1.0);
				
				if (TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
					TF2_RemoveCondition(iClient, TFCond_Cloaked);
			}
			else if (TF2_GetCloakMeter(iClient) > 60.0)
			{
				//Limit spy cloak to 60% of max.
				TF2_SetCloakMeter(iClient, 60.0);
			}
		}
		
		if (g_nRoundState == SZFRoundState_Active)
		{
			if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient) && iCount == 1)
			{
				if (GetActivePlayerCount() >= 6 && !TF2_IsPlayerInCondition(iClient, TFCond_Buffed))
					TF2_AddCondition(iClient, TFCond_Buffed, TFCondDuration_Infinite);
				
				if (GetActivePlayerCount() < 6 && TF2_IsPlayerInCondition(iClient, TFCond_Buffed))
					TF2_RemoveCondition(iClient, TFCond_Buffed);
			}
			
			//Charger's charge
			if (IsValidLivingZombie(iClient) && g_nInfected[iClient] == Infected_Charger && TF2_IsPlayerInCondition(iClient, TFCond_Charging))
			{
				float vecPosClient[3];
				float vecPosCharger[3];
				float flDistance;
				GetClientEyePosition(iClient, vecPosCharger);
				
				for (int iVictim = 1; iVictim <= MaxClients; iVictim++)
				{
					if (IsClientInGame(iVictim) && IsPlayerAlive(iVictim) && IsSurvivor(iVictim))
					{
						GetClientEyePosition(iVictim, vecPosClient);
						flDistance = GetVectorDistance(vecPosCharger, vecPosClient);
						if (flDistance <= 95.0)
						{
							if (!g_bBackstabbed[iVictim])
							{
								SetBackstabState(iVictim, BACKSTABDURATION_FULL, 0.8);
								SetNextAttack(iClient, GetGameTime() + 0.6);
								
								TF2_MakeBleed(iVictim, iClient, 2.0);
								DealDamage(iClient, iVictim, 30.0);
								
								char sPath[PLATFORM_MAX_PATH];
								Format(sPath, sizeof(sPath), "weapons/demo_charge_hit_flesh_range1.wav", GetRandomInt(1, 3));
								EmitSoundToAll(sPath, iClient);
								
								Call_StartForward(g_hForwardChargerHit);
								Call_PushCell(iClient);
								Call_PushCell(iVictim);
								Call_Finish();
							}
							
							TF2_RemoveCondition(iClient, TFCond_Charging);
							break; //Target found, break the loop.
						}
					}
				}
			}
			
			//Hopper's pounce
			if (IsValidLivingZombie(iClient) && g_nInfected[iClient] == Infected_Hunter && g_bHopperIsUsingPounce[iClient])
			{
				float vecPosClient[3];
				float flPosHopper[3];
				float flDistance;
				GetClientEyePosition(iClient, flPosHopper);
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i))
					{
						GetClientEyePosition(i, vecPosClient);
						flDistance = GetVectorDistance(flPosHopper, vecPosClient);
						if (flDistance <= 90.0)
						{
							if (!g_bBackstabbed[i])
							{
								SetEntityHealth(i, GetClientHealth(i) - 20);

								SetBackstabState(i, BACKSTABDURATION_FULL, 1.0);
								SetNextAttack(iClient, GetGameTime() + 0.6);

								//Teleport hunter inside the target
								GetClientAbsOrigin(i, vecPosClient);
								TeleportEntity(iClient, vecPosClient, NULL_VECTOR, NULL_VECTOR);
								//Dont allow hunter to move during lock
								TF2_StunPlayer(iClient, BACKSTABDURATION_FULL, 1.0, TF_STUNFLAG_SLOWDOWN, 0);
								
								Call_StartForward(g_hForwardHunterHit);
								Call_PushCell(iClient);
								Call_PushCell(i);
								Call_Finish();
							}
							
							g_iRageTimer[iClient] = 21;
							g_bHopperIsUsingPounce[iClient] = false;
							break; //Break the loop, since we found our target
						}
					}
				}
			}
		}
	}
}

void Handle_WinCondition()
{
	//1. Check for any survivors that are still alive.
	bool bFound = false;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
		{
			bFound = true;
			break;
		}
	}
	
	//2. If no survivors are alive and at least 1 zombie is playing,
	//       end round with zombie win.
	if (!bFound && (GetTeamClientCount(view_as<int>(TFTeam_Zombie)) > 0))
		TF2_EndRound(TFTeam_Zombie);
}

void Handle_SurvivorAbilities()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidLivingSurvivor(iClient))
		{
			//1. Survivor health regeneration.
			int iHealth = GetClientHealth(iClient);
			int iMaxHealth = SDK_GetMaxHealth(iClient);
			if (iHealth < iMaxHealth)
			{
				iHealth += GetSurvivorRegen(TF2_GetPlayerClass(iClient));

				if (TF2_GetPlayerClass(iClient) == TFClass_Medic && TF2_IsEquipped(iClient, 36)) iHealth--;
				iHealth += (!g_bSurvival) ? RoundToFloor(fMin(GetMorale(iClient) * 0.166, 4.0)) : 1;
				iHealth = min(iHealth, iMaxHealth);
				SetEntityHealth(iClient, iHealth);
			}
			
			//2. Handle survivor morale.
			if (g_iMorale[iClient] > 100) SetMorale(iClient, 100);
			int iMorale = GetMorale(iClient);
			//Decrement morale bonus over time
			
			//2.1. Show morale on HUD
			SetHudTextParams(0.18, 0.71, 1.0, 200 - (iMorale * 2), 255, 200 - (iMorale * 2), 255);
			ShowHudText(iClient, 3, "Morale: %d/100", iMorale);
			
			//2.2. Award buffs if high morale is detected
			if (iMorale > 50) TF2_AddCondition(iClient, TFCond_DefenseBuffed, 1.1); //50: defense buff
			
			//3. HUD stuff
			//3.1. Primary weapons
			SetHudTextParams(0.18, 0.84, 1.0, 200, 255, 200, 255);
			int iPrimary = GetPlayerWeaponSlot(iClient, WeaponSlot_Primary);
			if (iPrimary > MaxClients && IsValidEdict(iPrimary))
			{
				if (GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex") == 752)
				{
					float flFocus = GetEntPropFloat(iClient, Prop_Send, "m_flRageMeter");
					ShowHudText(iClient, 0, "Focus: %d/100", RoundToZero(flFocus));
				}
				else if (TF2_IsSlotClassname(iClient, WeaponSlot_Primary, "tf_weapon_particle_cannon"))
				{
					float flEnergy = GetEntPropFloat(iPrimary, Prop_Send, "m_flEnergy");
					ShowHudText(iClient, 0, "Mangler: %d\%", RoundFloat(flEnergy)*5);
				}
				else if (TF2_IsSlotClassname(iClient, WeaponSlot_Primary, "tf_weapon_drg_pomson"))
				{
					float flEnergy = GetEntPropFloat(iPrimary, Prop_Send, "m_flEnergy");
					ShowHudText(iClient, 0, "Pomson: %d\%", RoundFloat(flEnergy)*5);
				}
				else if (TF2_IsSlotClassname(iClient, WeaponSlot_Primary, "tf_weapon_sniperrifle_decap"))
				{
					int iHeads = GetEntProp(iClient, Prop_Send, "m_iDecapitations");
					ShowHudText(iClient, 0, "Heads: %d", iHeads);
				}
				else if (TF2_IsSlotClassname(iClient, WeaponSlot_Primary, "tf_weapon_sentry_revenge"))
				{
					int iCrits = GetEntProp(iClient, Prop_Send, "m_iRevengeCrits");
					ShowHudText(iClient, 0, "Crits: %d", iCrits);
				}
			}
			
			//3.2. Secondary weapons
			SetHudTextParams(0.18, 0.9, 1.0, 200, 255, 200, 255);
			int iSecondary = GetPlayerWeaponSlot(iClient, WeaponSlot_Secondary);
			if (iSecondary > MaxClients && IsValidEdict(iSecondary))
			{
				if (TF2_IsSlotClassname(iClient, WeaponSlot_Secondary, "tf_weapon_raygun"))
				{
					float flEnergy = GetEntPropFloat(iSecondary, Prop_Send, "m_flEnergy");
					ShowHudText(iClient, 5, "Bison: %d\%", RoundFloat(flEnergy)*5);
				}
				else if (TF2_IsSlotClassname(iClient, WeaponSlot_Secondary, "tf_weapon_buff_item"))
				{
					float flRage = GetEntPropFloat(iClient, Prop_Send, "m_flRageMeter");
					ShowHudText(iClient, 5, "Rage: %d/100", RoundToZero(flRage));
				}
				else if (TF2_IsSlotClassname(iClient, WeaponSlot_Secondary, "tf_weapon_jar_gas"))
				{
					float flMeter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1);
					ShowHudText(iClient, 5, "Gas: %d/100", RoundToZero(flMeter));
				}
				else if (TF2_IsSlotClassname(iClient, WeaponSlot_Secondary, "tf_weapon_charged_smg"))
				{
					float flRage = GetEntPropFloat(iSecondary, Prop_Send, "m_flMinicritCharge");
					ShowHudText(iClient, 5, "Crikey: %d/100", RoundToZero(flRage));
				}
			}

		}
	}
	
	//3. Handle sentry rules.
	//       + Mini and Norm sentry starts with 40 ammo and decays to 0, then self destructs.
	//       + No sentry can be upgraded.
	int iSentry = -1;
	while ((iSentry = FindEntityByClassname(iSentry, "obj_sentrygun")) != -1)
	{
		bool bBuilding = GetEntProp(iSentry, Prop_Send, "m_bBuilding") == 1;
		bool bPlacing = GetEntProp(iSentry, Prop_Send, "m_bPlacing") == 1;
		bool bCarried = GetEntProp(iSentry, Prop_Send, "m_bCarried") == 1;
		bool bInfAmmo = view_as<bool>(GetEntProp(iSentry, Prop_Data, "m_spawnflags") & 8);
		
		if (!bInfAmmo && !bBuilding && !bPlacing && !bCarried)
		{
			int iAmmo = GetEntProp(iSentry, Prop_Send, "m_iAmmoShells");
			if (iAmmo > 0)
			{
				iAmmo = min(40, (iAmmo - 1));
				SetEntProp(iSentry, Prop_Send, "m_iAmmoShells", iAmmo);
				SetEntProp(iSentry, Prop_Send, "m_iUpgradeMetal", 0);
			}
			else
			{
				SetVariantInt(GetEntProp(iSentry, Prop_Send, "m_iMaxHealth"));
				AcceptEntityInput(iSentry, "RemoveHealth");
			}
		}
		
		int iLevel = GetEntProp(iSentry, Prop_Send, "m_iHighestUpgradeLevel");
		if (!bInfAmmo && iLevel > 1)
		{
			SetVariantInt(GetEntProp(iSentry, Prop_Send, "m_iMaxHealth"));
			AcceptEntityInput(iSentry, "RemoveHealth");
		}
	}
}

void Handle_ZombieAbilities()
{
	TFClassType nClass;
	int iHealth;
	int iMaxHealth;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidLivingZombie(iClient) && g_nInfected[iClient] != Infected_Tank)
		{
			nClass = TF2_GetPlayerClass(iClient);
			iHealth = GetClientHealth(iClient);
			iMaxHealth = SDK_GetMaxHealth(iClient);
			
			//1. Handle zombie regeneration.
			//       Zombies regenerate health based on class and number of nearby
			//       zombies (hoarde bonus). Zombies decay health when overhealed.
			if (iHealth < iMaxHealth)
			{
				iHealth += g_nInfected[iClient] == Infected_None ? GetZombieRegen(nClass) : GetInfectedRegen(g_nInfected[iClient]);
				
				//Handle additional regeneration
				iHealth += 1 * g_iHorde[iClient]; //Horde bonus
				if (g_bZombieRage) iHealth += 3; //Zombie rage
				if (g_iScreamerNearby[iClient]) iHealth += 2; //Kingpin
				
				iHealth = min(iHealth, iMaxHealth);
				SetEntityHealth(iClient, iHealth);
			}
			else if (iHealth > iMaxHealth)
			{
				iHealth -= g_nInfected[iClient] == Infected_None ? GetZombieDegen(nClass) : GetInfectedDegen(g_nInfected[iClient]);
				iHealth = max(iHealth, iMaxHealth);
				SetEntityHealth(iClient, iHealth);
			}
			
			//2.1. Handle fast respawn into special infected HUD message
			if (g_nRoundState == SZFRoundState_Active && g_bReplaceRageWithSpecialInfectedSpawn[iClient])
			{
				PrintHintText(iClient, "Call 'MEDIC!' to respawn as a special infected!");
			}
			//2.2. Handle zombie rage timer
			//       Rage recharges every 20(special)/30(normal) seconds.
			else if (g_iRageTimer[iClient] > 0)
			{
				if (g_iRageTimer[iClient] == 1) PrintHintText(iClient, "Rage is ready!");
				if (g_iRageTimer[iClient] == 6) PrintHintText(iClient, "Rage is ready in 5 seconds!");
				if (g_iRageTimer[iClient] == 11) PrintHintText(iClient, "Rage is ready in 10 seconds!");
				if (g_iRageTimer[iClient] == 21) PrintHintText(iClient, "Rage is ready in 20 seconds!");
				if (g_iRageTimer[iClient] == 31) PrintHintText(iClient, "Rage is ready in 30 seconds!");
				
				g_iRageTimer[iClient]--;
			}
			
			//3. HUD for sandman
			SetHudTextParams(0.18, 0.9, 1.0, 200, 255, 200, 255);
			int iMelee = GetPlayerWeaponSlot(iClient, WeaponSlot_Melee);
			if (iMelee > MaxClients && IsValidEdict(iMelee))
			{
				if (TF2_IsSlotClassname(iClient, WeaponSlot_Melee, "tf_weapon_bat_wood"))
				{
					g_flGooCooldown[iClient] = GetEntPropFloat(iMelee, Prop_Send, "m_flEffectBarRegenTime");
					float fTime = g_flGooCooldown[iClient] - GetGameTime();
					if (fTime > 0.0)
						ShowHudText(iClient, 5, "Ball: %ds", RoundToZero(fTime));
				}
			}
		}
	}
}

void Handle_HoardeBonus()
{
	int iLength = 0;
	int[] iClients = new int[MaxClients];
	int[] iClientsHoardeId = new int[MaxClients];
	float vecClientsPos[TF_MAXPLAYERS][3];
	
	int[] iHoardeSize = new int[MaxClients];
	
	//1. Find all active zombie players.
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && IsZombie(iClient))
		{
			iClients[iLength] = iClient;
			iClientsHoardeId[iLength] = -1;
			GetClientAbsOrigin(iClient, vecClientsPos[iLength]);
			iLength++;
		}
	}
	
	//2. Calculate hoarde groups.
	//       A hoarde is defined as a single, contiguous group of valid zombie
	//       players. Distance calculation between zombie players serves as
	//       primary decision criteria.
	int iHoarde = 0;
	ArrayStack aStack = new ArrayStack();
	for (int i = 0; i < iLength; i++)
	{
		//2a. Create new hoarde group.
		if (iClientsHoardeId[i] == -1)
		{
			aStack.Push(i);
			iClientsHoardeId[i] = iHoarde;
			iHoardeSize[iHoarde] = 1;
		}
		
		//2b. Build current hoarde created in step 2a.
		//        Use a depth-first adjacency search.
		while (!aStack.Empty)
		{
			int iPop = aStack.Pop();
			for (int j = i+1; j < iLength; j++)
			{
				if (iClientsHoardeId[j] == -1)
				{
					if (GetVectorDistance(vecClientsPos[j], vecClientsPos[iPop], true) <= 200000)
					{
						aStack.Push(j);
						iClientsHoardeId[j] = iHoarde;
						iHoardeSize[iHoarde]++;
					}
				}
			}
		}
		
		iHoarde++;
	}
	
	delete aStack;
	
	//3. Set hoarde bonuses.
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		g_iHorde[iClient] = 0;
	for (int i = 0; i < iLength; i++)
		g_iHorde[iClients[i]] = iHoardeSize[iClientsHoardeId[i]] - 1;
}

////////////////////////////////////////////////////////////
//
// SZF Logic Functionality
//
////////////////////////////////////////////////////////////

void SZFEnable()
{
	g_bFirstRound = true;
	g_bSurvival = false;
	g_bNoMusic = false;
	g_bNoDirectorTanks = false;
	g_bNoDirectorRages = false;
	g_bDirectorSpawnTeleport = false;
	g_bEnabled = true;
	g_bNewRound = true;
	g_bLastSurvivor = false;
	
	g_flTimeProgress = 0.0;
	
	SetTeams();
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		ResetClientState(iClient);
	
	mp_autoteambalance.SetBool(false);
	mp_teams_unbalance_limit.SetBool(false);
	mp_waitingforplayers_time.SetInt(70);
	tf_weapon_criticals.SetBool(false);
	tf_obj_upgrade_per_hit.SetInt(0);
	tf_sentrygun_metal_per_shell.SetInt(201);
	tf_spy_invis_time.SetFloat(0.5);
	tf_spy_invis_unstealth_time.SetFloat(0.75);
	tf_spy_cloak_no_attack_time.SetFloat(1.0);
	
	mp_autoteambalance.AddChangeHook(OnConvarChanged);
	mp_teams_unbalance_limit.AddChangeHook(OnConvarChanged);
	mp_waitingforplayers_time.AddChangeHook(OnConvarChanged);
	tf_weapon_criticals.AddChangeHook(OnConvarChanged);
	tf_obj_upgrade_per_hit.AddChangeHook(OnConvarChanged);
	tf_sentrygun_metal_per_shell.AddChangeHook(OnConvarChanged);
	tf_spy_invis_time.AddChangeHook(OnConvarChanged);
	tf_spy_invis_unstealth_time.AddChangeHook(OnConvarChanged);
	tf_spy_cloak_no_attack_time.AddChangeHook(OnConvarChanged);
	
	//[Re]Enable periodic timers.
	delete g_hTimerMain;
	g_hTimerMain = CreateTimer(1.0, Timer_Main, _, TIMER_REPEAT);
	
	delete g_hTimerMoraleDecay;
	g_hTimerMoraleDecay = CreateTimer(1.0, Timer_MoraleDecay);	//Timer inside will call itself for loops
	
	delete g_hTimerMainSlow;
	g_hTimerMainSlow = CreateTimer(240.0, Timer_MainSlow, _, TIMER_REPEAT);
	
	delete g_hTimerMainFast;
	g_hTimerMainFast = CreateTimer(0.5, Timer_MainFast, _, TIMER_REPEAT);
	
	delete g_hTimerHoarde;
	g_hTimerHoarde = CreateTimer(5.0, Timer_Hoarde, _, TIMER_REPEAT);
	
	delete g_hTimerDataCollect;
	g_hTimerDataCollect = CreateTimer(2.0, Timer_Datacollect, _, TIMER_REPEAT);
}

void SZFDisable()
{
	g_bFirstRound = false;
	g_bSurvival = false;
	g_bNoMusic = false;
	g_bNoDirectorTanks = false;
	g_bNoDirectorRages = false;
	g_bDirectorSpawnTeleport = false;
	g_bEnabled = false;
	g_bNewRound = true;
	g_bLastSurvivor = false;
	
	g_flTimeProgress = 0.0;
	
	for (int iClient = 0; iClient <= MaxClients; iClient++)
		ResetClientState(iClient);
	
	mp_autoteambalance.RemoveChangeHook(OnConvarChanged);
	mp_teams_unbalance_limit.RemoveChangeHook(OnConvarChanged);
	mp_waitingforplayers_time.RemoveChangeHook(OnConvarChanged);
	tf_weapon_criticals.RemoveChangeHook(OnConvarChanged);
	tf_obj_upgrade_per_hit.RemoveChangeHook(OnConvarChanged);
	tf_sentrygun_metal_per_shell.RemoveChangeHook(OnConvarChanged);
	tf_spy_invis_time.RemoveChangeHook(OnConvarChanged);
	tf_spy_invis_unstealth_time.RemoveChangeHook(OnConvarChanged);
	tf_spy_cloak_no_attack_time.RemoveChangeHook(OnConvarChanged);
	
	mp_autoteambalance.RestoreDefault();
	mp_teams_unbalance_limit.RestoreDefault();
	mp_waitingforplayers_time.RestoreDefault();
	tf_weapon_criticals.RestoreDefault();
	tf_obj_upgrade_per_hit.RestoreDefault();
	tf_sentrygun_metal_per_shell.RestoreDefault();
	tf_spy_invis_time.RestoreDefault();
	tf_spy_invis_unstealth_time.RestoreDefault();
	tf_spy_cloak_no_attack_time.RestoreDefault();
	
	//Disable periodic timers.
	delete g_hTimerMain;
	delete g_hTimerMoraleDecay;
	delete g_hTimerMainSlow;
	delete g_hTimerHoarde;
	delete g_hTimerDataCollect;
	delete g_hTimerProgress;
	
	//Enable resupply lockers.
	int iEntity = -1;
	while((iEntity = FindEntityByClassname(iEntity, "func_regenerate")) != -1)
		AcceptEntityInput(iEntity, "Enable");
}

void SetTeams()
{
	//Determine team roles.
	//+ By default, survivors are RED and zombies are BLU.
	TFTeam_Survivor = TFTeam_Red;
	TFTeam_Zombie = TFTeam_Blue;
	
	//Determine whether to swap teams on payload maps.
	//+ For "pl_" prefixed maps, swap teams if sm_zf_swaponpayload is set.
	if (IsMapPL())
	{
		if (g_cvSwapOnPayload.BoolValue)
		{
			TFTeam_Survivor = TFTeam_Blue;
			TFTeam_Zombie = TFTeam_Red;
		}
	}
	
	//Determine whether to swap teams on attack / defend maps.
	//+ For "cp_" prefixed maps with all RED control points, swap teams if sm_zf_swaponattdef is set.
	if (IsMapCP())
	{
		if (g_cvSwapOnAttdef.BoolValue)
		{
			bool bAttDef = true;
			int iEntity = -1;
			while((iEntity = FindEntityByClassname(iEntity, "team_control_point")) != -1)
			{
				if (GetEntProp(iEntity, Prop_Send, "m_iTeamNum") != view_as<int>(TFTeam_Red))
				{
					bAttDef = false;
					break;
				}
			}
			
			if (bAttDef)
			{
				TFTeam_Survivor = TFTeam_Blue;
				TFTeam_Zombie = TFTeam_Red;
			}
		}
	}
}

public void OnConvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	float flValue = StringToFloat(newValue);
	
	if (convar == mp_autoteambalance && flValue != 0.0) mp_autoteambalance.SetBool(false);
	else if (convar == mp_teams_unbalance_limit && flValue != 0.0) mp_teams_unbalance_limit.SetBool(false);
	else if (convar == mp_waitingforplayers_time && flValue != 70.0) mp_waitingforplayers_time.SetInt(70);
	else if (convar == tf_weapon_criticals && flValue != 0.0) tf_weapon_criticals.SetBool(false);
	else if (convar == tf_obj_upgrade_per_hit && flValue != 0.0) tf_obj_upgrade_per_hit.SetInt(0);
	else if (convar == tf_sentrygun_metal_per_shell && flValue != 201.0) tf_sentrygun_metal_per_shell.SetInt(201);
	else if (convar == tf_spy_invis_time && flValue != 0.5) tf_spy_invis_time.SetFloat(0.5);
	else if (convar == tf_spy_invis_unstealth_time && flValue != 0.75) tf_spy_invis_unstealth_time.SetFloat(0.75);
	else if (convar == tf_spy_cloak_no_attack_time && flValue != 1.0) tf_spy_cloak_no_attack_time.SetFloat(1.0);
}

////////////////////////////////////////////////////////////
//
// Utility Functionality
//
////////////////////////////////////////////////////////////

void ResetClientState(int iClient)
{
	g_iMorale[iClient] = 0;
	g_iHorde[iClient] = 0;
	g_iCapturingPoint[iClient] = -1;
	g_iScreamerNearby[iClient] = false;
	g_iRageTimer[iClient] = 0;
}

////////////////////////////////////////////////////////////
//
// Help Functionality
//
////////////////////////////////////////////////////////////

public void PrintInfoChat(int iClient)
{
	char sMessage[256];
	Format(sMessage, sizeof(sMessage), "{lightsalmon}Welcome to Super Zombie Fortress.\nYou can open the instruction menu using {limegreen}/szf{lightsalmon}.");
	
	if (iClient == 0)
		CPrintToChatAll(sMessage);
	else
		CPrintToChat(iClient, sMessage);
}

//Main.Help Menu
public void Panel_PrintMain(int iClient)
{
	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "Super Zombie Fortress - %s", PLUGIN_VERSION);
	
	Panel panel = new Panel();
	panel.SetTitle(sBuffer);
	panel.DrawItem(" Overview");
	panel.DrawItem(" Team: Survivors");
	panel.DrawItem(" Team: Infected");
	panel.DrawItem(" Classes: Survivors");
	panel.DrawItem(" Classes: Infected");
	panel.DrawItem(" Classes: Infected (Special)");
	panel.DrawItem("Exit");
	panel.Send(iClient, Panel_HandleHelp, 30);
	delete panel;
}

public int Panel_HandleHelp(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1: Panel_PrintOverview(param1);
			case 2: Panel_PrintTeam(param1, TFTeam_Survivor);
			case 3: Panel_PrintTeam(param1, TFTeam_Zombie);
			case 4: Panel_PrintSurClass(param1);
			case 5: Panel_PrintZomClass(param1);
			case 6: Panel_PrintZomSpecial(param1);
			default: return;
		}
	}
}

//Main.Help.Overview Menus
public void Panel_PrintOverview(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Overview");
	panel.DrawText("-------------------------------------------");
	panel.DrawText("Survivors must survive the endless hoarde of Infected.");
	panel.DrawText("When a Survivor dies, they join the Zombie team and play as a Zombie.");
	panel.DrawText("Zombies need to work together to take down the survivors.");
	panel.DrawText("Survivor gain access to morale and weapon pickups, while zombies gain access to special infected.");
	panel.DrawText("-------------------------------------------");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Panel_HandleOverview, 10);
	delete panel;
}

public int Panel_HandleOverview(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1: Panel_PrintMain(param1);
			default: return;
		}
	}
}

//Main.Help.Team Menus
public void Panel_PrintTeam(int iClient, TFTeam nTeam)
{
	Panel panel = new Panel();
	if (nTeam == TFTeam_Survivor)
	{
		panel.SetTitle("Survivors");
		panel.DrawText("-------------------------------------------");
		panel.DrawText("Survivors consist of Soldiers, Pyros, Demoman, Medics, Engineers and Snipers.");
		panel.DrawText("Survivors gain regeneration and a small bonus to their damage based on Morale.");
		panel.DrawText("Morale is gained by doing objectives and killing infected but is also lost over time and by negative events.");
		panel.DrawText("Survivors only start with a melee weapon and pick up weapons (using CALL 'MEDIC!', 'mouse1' or 'mouse2') as they progress through the map.");
		panel.DrawText("-------------------------------------------");
	}
	else if (nTeam == TFTeam_Zombie)
	{
		panel.SetTitle("Infected");
		panel.DrawText("-------------------------------------------");
		panel.DrawText("Infected consist of Scouts, Heavies and Spies.");
		panel.DrawText("Infected gain bonuses when sticking together as a hoarde and can enrage which boost health or activate special abilities as special infected.");
		panel.DrawText("Enrage is used by calling for a 'medic' and has a cooldown after use.");
		panel.DrawText("Upon killing a survivor, you may be given the option to respawn as a special infected using .");
		panel.DrawText("-------------------------------------------");
	}
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Panel_HandleTeam, 30);
	delete panel;
}

public int Panel_HandleTeam(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1: Panel_PrintMain(param1);
			default: return;
		}
	}
}

//Main.Help.Class Menus
public void Panel_PrintSurClass(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Survivor Classes");
	
	char sClass[32];
	for (int i = 1; i < view_as<int>(TFClassType); i++)
	{
		if (IsValidSurvivorClass(view_as<TFClassType>(i)))
		{
			TF2_GetClassName(sClass, sizeof(sClass), i);
			Format(sClass, sizeof(sClass), " %s", sClass);
			panel.DrawItem(sClass);
		}
	}
	
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Panel_HandleSurClass, 10);
	delete panel;
}

public int Panel_HandleSurClass(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == GetSurvivorClassCount()+1)
			Panel_PrintMain(param1);

		if (param2 <= GetSurvivorClassCount() && param2 > 0)
		{
			TFClassType aClasses[10];
			int i2;
			for (int i = 1; i < view_as<int>(TFClassType); i++)
			{
				if (IsValidSurvivorClass(view_as<TFClassType>(i)))
					aClasses[i2++] = view_as<TFClassType>(i);
			}
			
			Panel_PrintSurInfo(param1, aClasses[param2]);
		}
	}
}

public void Panel_PrintZomClass(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Zombie Classes");
	
	char sClass[32];
	for (int i = 1; i < view_as<int>(TFClassType); i++)
	{
		if (IsValidZombieClass(view_as<TFClassType>(i)))
		{
			TF2_GetClassName(sClass, sizeof(sClass), i);
			Format(sClass, sizeof(sClass), " %s", sClass);
			panel.DrawItem(sClass);
		}
	}
	
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Panel_HandleZomClass, 10);
	delete panel;
}

public int Panel_HandleZomClass(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == GetZombieClassCount()+1)
			Panel_PrintMain(param1);

		if (param2 <= GetZombieClassCount() && param2 > 0)
		{
			TFClassType aClasses[10];
			int i2;
			for (int i = 1; i < view_as<int>(TFClassType); i++)
			{
				if (IsValidZombieClass(view_as<TFClassType>(i)))
					aClasses[i2++] = view_as<TFClassType>(i);
			}
			
			Panel_PrintZomInfo(param1, aClasses[param2]);
		}
	}
}

public int Panel_PrintZomSpecial(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Special Infected");
	
	char sInfected[64], sClass[32];
	for (int i = 1; i < view_as<int>(Infected); i++)
	{
		if (IsValidInfected(view_as<Infected>(i)))
		{
			GetInfectedName(sInfected, sizeof(sInfected), i);
			TF2_GetClassName(sClass, sizeof(sClass), i);
			Format(sInfected, sizeof(sInfected), " %s (%s)", sInfected, sClass);
			panel.DrawItem(sClass);
		}
	}
	
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Panel_HandleZomSpecial, 10);
	delete panel;
}

public int Panel_HandleZomSpecial(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == GetInfectedCount()+1)
			Panel_PrintMain(param1);

		if (param2 <= GetInfectedCount() && param2 > 0)
		{
			Infected aClasses[9];
			int i2;
			for (int i = 1; i < view_as<int>(Infected); i++)
			{
				if (IsValidInfected(view_as<Infected>(i)))
					aClasses[i2++] = view_as<Infected>(i);
			}
			
			Panel_PrintSpecial(param1, aClasses[param2]);
		}
	}
}

public void Panel_PrintSurInfo(int iClient, TFClassType nClass)
{
	Panel panel = new Panel();
	
	char sClass[256];
	TF2_GetClassName(sClass, sizeof(sClass), view_as<int>(nClass));
	panel.SetTitle(sClass);
	panel.DrawText("-------------------------------------------");
	
	//If they can gain/lose ammo on kill
	if (GetSurvivorAmmo(nClass))
	{
		Format(sClass, sizeof(sClass), "%s %d primary ammo per kill%s.", GetSurvivorAmmo(nClass) > 0 ? "Gains" : "Loses", GetSurvivorAmmo(nClass), GetSurvivorAmmo(nClass) > 0 ? ", this can go beyond the usual maximum capacity of your weapon" : "");
		panel.DrawText(sClass);
	}
	
	//If their speed has been modified
	if (GetSurvivorSpeed(nClass) != TF2_GetClassSpeed(nClass))
	{
		Format(sClass, sizeof(sClass), "Movement speed %s to %d (from %d).", GetSurvivorSpeed(nClass) > TF2_GetClassSpeed(nClass) ? "increased" : "lowered", RoundFloat(GetSurvivorSpeed(nClass)), TF2_GetClassSpeed(nClass));
		panel.DrawText(sClass);
	}
	
	switch (nClass)
	{
		case TFClass_Pyro:
		{
			panel.DrawText("Burning zombies move faster.");
			panel.DrawText("Flamethrower ammo limited to 100.");
		}
		case TFClass_Heavy:
		{
			panel.DrawText("Minigun ammo limited to 100.");
		}
		case TFClass_Engineer:
		{
			panel.DrawText("Buildables cannot be upgraded.");
			panel.DrawText("Can only build sentries and dispensers.");
			panel.DrawText("Sentry ammo is limited, decays and cannot be replenished.");
			panel.DrawText("Dispensers act as walls, with higher health than usual but no ammo replenishment.");
		}
		case TFClass_Medic:
		{
			panel.DrawText("Overheal limited to 25%% of maximum health but sticks for a longer duration.");
		}
		case TFClass_Sniper:
		{
			panel.DrawText("SMG doesn't have to reload.");
			panel.DrawText("Jarate slows down Infected.");
		}
		case TFClass_Spy:
		{
			panel.DrawText("Can't use cloak watches but can use disguises.");
		}
	}
	
	panel.DrawText("-------------------------------------------");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Panel_HandleClass, 30);
	delete panel;
}

public void Panel_PrintZomInfo(int iClient, TFClassType nClass)
{
	Panel panel = new Panel();
	
	char sClass[32];
	TF2_GetClassName(sClass, sizeof(sClass), view_as<int>(nClass));
	panel.SetTitle(sClass);
	panel.DrawText("-------------------------------------------");
	
	//If their speed has been modified
	if (GetZombieSpeed(nClass) != TF2_GetClassSpeed(nClass))
	{
		Format(sClass, sizeof(sClass), "Movement speed %s to %d (from %d).", GetZombieSpeed(nClass) > TF2_GetClassSpeed(nClass) ? "increased" : "lowered", RoundFloat(GetZombieSpeed(nClass)), TF2_GetClassSpeed(nClass));
		panel.DrawText(sClass);
	}
	
	switch (nClass)
	{
		case TFClass_Scout:
		{
			if (GetZombieIndex(nClass) == 44) panel.DrawText("Balls fired from the Sandman do not stun, it emits a toxic gas that damages Survivors who stand on it instead.");
		}
		case TFClass_Soldier:
		{
			panel.DrawText("Suffers less knockback from attackers.");
			panel.DrawText("Benefits less from movement speed and health regeneration bonuses while in a horde.");
		}
		case TFClass_Pyro, TFClass_DemoMan:
		{
			panel.DrawText("Benefits less from movement speed and health regeneration bonuses while in a horde.");
		}
		case TFClass_Heavy:
		{
			panel.DrawText("Blocks fatal attacks, reducing damage to 150.");
			panel.DrawText("Suffers less knockback from attacks.");
			panel.DrawText("Benefits less from movement speed and health regeneration bonuses while in a horde.");
		}
		case TFClass_Engineer:
		{
			panel.DrawText("Buildables cannot be upgraded.");
			panel.DrawText("Can only build sentries.");
			panel.DrawText("Sentry ammo is limited, decays and cannot be replenished.");
		}
		case TFClass_Medic:
		{
			panel.DrawText("Benefits less from health regeneration bonuses while in a horde.");
		}
		case TFClass_Spy:
		{
			panel.DrawText("Backstabs put the victim into a 'scared' state, slowing and disabling weapon usage for 5.5 seconds.");
			panel.DrawText("Survivors may become a bit resistant to backstabs, reducing the duration, to ensure game balance.");
		}
	}
	
	panel.DrawText("-------------------------------------------");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Panel_HandleClass, 30);
	delete panel;
}

public void Panel_PrintSpecial(int iClient, Infected nInfected)
{
	Panel panel = new Panel();
	
	char sInfected[64], sClass[32];
	GetInfectedName(sInfected, sizeof(sInfected), view_as<int>(nInfected));
	TF2_GetClassName(sClass, sizeof(sClass), view_as<int>(GetInfectedClass(nInfected)));
	Format(sInfected, sizeof(sInfected), "%s (%s)", sInfected, sClass);
	panel.SetTitle(sInfected);
	panel.DrawText("-------------------------------------------");
	
	switch (nInfected)
	{
		case Infected_Tank:
		{
			panel.DrawText("As one of the strongest and brutal infected he has the ability to quickly take down an unsuspecting team of survivors.");
			panel.DrawText("- The Tank has a lot of health which he eventually loses after a while.");
			panel.DrawText("- The Tank starts of fast but is slowed down if damaged by the survivors.");
			panel.DrawText("- The Tank spawns if certain conditions are met.");
		}
		case Infected_Boomer:
		{
			panel.DrawText("He is gross, he is dirty and is not afraid to share this with any unlucky survivors.");
			panel.DrawText("- Upon raging the Boomer explodes, covering survivors close to him in Jarate.");
			panel.DrawText("- On death, the killer and the assister of the killer will be coated in Jarate for a short duration.");
		}
		case Infected_Charger:
		{
			panel.DrawText("His inner rage and insanity has caused him to lose any care for how he uses his body, as long as he can take somebody with it.");
			panel.DrawText("- Using rage to charge the Charger is able to disable a survivor for a short period, damaging based on the victim's health.");
		}
		case Infected_Kingpin:
		{
			panel.DrawText("The Kingpin is the director of the pack, he makes sure that the Zombies give their fullest in taking down the survivors.");
			panel.DrawText("- Using rage, the Kingpin will rally up the Zombies with an ear-piercing yell, increasing the overall power of the zombies.");
			panel.DrawText("- The Kingpin motivates zombies by standing near them, increasing their efficiency.");
			panel.DrawText("- The Kingpin is slower, but takes less damage from attacks.");
		}
		case Infected_Stalker:
		{
			panel.DrawText("The Stalker is elusive, being able to get close to survivors and back away in the blink of an eye.");
			panel.DrawText("- The Stalker is always cloaked if not close to any survivor.");
			panel.DrawText("- Backstabs deal 50 health damage to a survivor, making it 2.5x stronger than a normal backstab.");
		}
		case Infected_Hunter:
		{
			panel.DrawText("The Hunter is a fast being, being very agile they can easily reach beyond the level's obstacles and be hard to get rid off during hectic combat.");
			panel.DrawText("- Using rage, the Hunter will perform a swift leap which can pounce enemies when making physical contact while leaping.");
			panel.DrawText("- Upon pounce, you will be 'stuck' inside the enemy, making you a very dangerous encounter to face when the opponent is alone.");
		}
		case Infected_Smoker:
		{
			panel.DrawText("The Smoker relies on his toxic beam which damages survivors can pulls them towards the Smoker.");
			panel.DrawText("- The pull power grows stronger the less health the victim has.");
			panel.DrawText("- Cannot use rage.");
		}
	}
	
	panel.DrawText("-------------------------------------------");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Panel_HandleClass, 30);
	delete panel;
}

public int Panel_HandleClass(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1: Panel_PrintMain(param1);
			default: return;
		}
	}
}

void SetGlow()
{
	int iCount = GetSurvivorCount();
	int iGlow = 0;
	int iGlow2;
	
	if (iCount >= 1 && iCount <= 3)
		iGlow = 1;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsPlayerAlive(iClient))
		{
			iGlow2 = iGlow;
			
			//Non-Survivors cannot glow by default
			if (!IsSurvivor(iClient)) iGlow2 = 0;
			
			//Kingpin or Tank
			if (IsZombie(iClient) && (g_nInfected[iClient] == Infected_Tank || g_nInfected[iClient] == Infected_Kingpin)) iGlow2 = 1;
			
			//Survivor with lower than 30 health or backstabbed
			if (IsSurvivor(iClient))
			{
				if (GetClientHealth(iClient) <= 30) iGlow2 = 1;
				if (g_bBackstabbed[iClient]) iGlow2 = 1;
			}
			
			SetEntProp(iClient, Prop_Send, "m_bGlowEnabled", iGlow2);
		}
	}
}

public void Frame_CheckZombieBypass(int iClient)
{
	if (GetClientTeam(iClient) <= 1)
		CheckZombieBypass(iClient);
}

void CheckZombieBypass(int iClient)
{
	int iSurvivors = GetSurvivorCount();
	int iZombies = GetZombieCount();
	
	//5 Checks
	if ((g_flTimeStartAsZombie[iClient] != 0.0)						//Check if client is currently playing as zombie (if it 0.0, it means he have not played as zombie yet this round)
		&& (g_flTimeStartAsZombie[iClient] > GetGameTime() - 90.0)	//Check if client have been playing zombie less than 90 seconds
		&& (float(iZombies) / float(iSurvivors + iZombies) <= 0.6)	//Check if less than 60% of players is zombie
		&& (!g_bFirstRound)											//Check if it not first round
		&& (g_nRoundState != SZFRoundState_End))								//Check if round did not end or map changing
	{
		g_bForceZombieStart[iClient] = true;
		SetClientCookie(iClient, g_cForceZombieStart, "1");
	}
}

stock int GetConnectingCount()
{
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientAuthorized(iClient))
			iCount++;
	
	return iCount;
}

stock int GetPlayerCount()
{
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient) && (TF2_GetClientTeam(iClient) > TFTeam_Spectator))
			iCount++;
	
	return iCount;
}

stock int GetSurvivorCount()
{
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidLivingSurvivor(iClient))
			iCount++;
	
	return iCount;
}

stock int GetZombieCount()
{
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient))
			iCount++;
	
	return iCount;
}

stock int GetReplaceRageWithSpecialInfectedSpawnCount()
{
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient) && g_bReplaceRageWithSpecialInfectedSpawn[iClient])
			iCount++;
	
	return iCount;
}

void UpdateZombieDamageScale()
{
	g_flZombieDamageScale = 1.0;
	
	if (g_iStartSurvivors <= 0) return;
	if (!g_bEnabled) return;
	if (g_nRoundState != SZFRoundState_Active) return;
	
	int iSurvivors = GetSurvivorCount();
	if (iSurvivors < 1) iSurvivors = 1; //Division by 0 error
	
	int iZombies = GetZombieCount();
	if (iZombies < 1) iZombies = 1; //Division by 0 error
	
	float flProgress = -1.0;
	
	//Check if it been force set
	if (0.0 <= g_flCapScale <= 1.0)
	{
		flProgress = g_flCapScale;
	}
	else
	{
		//iCurrentCP: +1 if CP currently capping, +2 if CP capped
		int iCurrentCP = 0;
		int iMaxCP = g_iControlPoints * 2;
		
		for (int i = 0; i < g_iControlPoints; i++)
			iCurrentCP += g_iControlPointsInfo[i][1];
		
		//If there atleast 1 CP, set progress by amount of CP capped
		if (iMaxCP > 0)
			flProgress = float(iCurrentCP) / float(iMaxCP);
		
		//If the map is too big for the amount of CPs, progress incerases with time
		if (g_flTimeProgress > flProgress)
		{
			//Failsafe : Cannot exceed current CP (and a half)
			float flProgressMax = (float(iCurrentCP)+1.0) / float(iMaxCP);
			
			//Cannot go above 1.0
			if (flProgressMax > 1.0)
				flProgressMax = 1.0;
			
			if (g_flTimeProgress > flProgressMax)
				flProgress = flProgressMax;
			else
				flProgress = g_flTimeProgress;
		}
	}
	
	//If progress found, calculate by amount of survivors and zombies
	if (0.0 <= flProgress <= 1.0)
	{
		float flExpectedPrecentage = (flProgress * 0.6) + 0.2;
		float flZombiePrecentage = float(iZombies) / float(iSurvivors + iZombies);
		g_flZombieDamageScale += (flExpectedPrecentage - flZombiePrecentage) * 0.7;
	}
	
	//Get the amount of zombies killed since last survivor death
	g_flZombieDamageScale += fMin(0.3, g_iZombiesKilledSpree * 0.003);
	
	//Get total amount of zombies killed
	g_flZombieDamageScale += fMin(0.2, g_iZombiesKilledCounter * 0.0005);
	
	//Zombie rage increases damage
	if (g_bZombieRage)
	{
		g_flZombieDamageScale += 0.1;
		if (g_flZombieDamageScale < 1.1)
			g_flZombieDamageScale = 1.1;
	}
	
	//In survival, zombie to survivor ratio is also taken to calculate damage.
	if (g_bSurvival) g_flZombieDamageScale += fMax(0.0, (iSurvivors / iZombies / 30) + 0.08); //28-4 = +0.213, 16-16 = +0.113
	
	//If the last point is being captured, set the damage scale to 110% if lower than 110%
	if (g_bCapturingLastPoint && g_flZombieDamageScale < 1.1 && !g_bSurvival) g_flZombieDamageScale = 1.1;
	
	//Post-calculation
	if (g_flZombieDamageScale < 1.0) g_flZombieDamageScale *= g_flZombieDamageScale;
	if (g_flZombieDamageScale < 0.33) g_flZombieDamageScale = 0.33;
	if (g_flZombieDamageScale > 3.0) g_flZombieDamageScale = 3.0;
	
	//Debugs
	//PrintToConsoleAll("[Debug] Zombie dmg scale: %.2f | progress %.2f | killspree %d | time since last death %.2f", g_flZombieDamageScale, flProgress, g_iZombiesKilledSpree, GetGameTime() - g_flSurvivorsLastDeath);
	
	//Not survival, no rage and no active tank
	if (!g_bSurvival && !g_bZombieRage && g_iZombieTank <= 0 && !ZombiesHaveTank())
	{
		//Tank cooldown is active
		if (GetGameTime() > g_flTankCooldown)
		{
			//In order:
			//The damage scale is above 170%
			//The damage scale is above 120% and the total amount of zombies killed since a survivor died exceeds 20
			//None of the survivors died in the past 120 seconds
			if ((g_flZombieDamageScale >= 1.7)
			|| (g_flZombieDamageScale >= 1.2 && g_iZombiesKilledSpree >= 20)
			|| (g_flSurvivorsLastDeath < GetGameTime() - 120.0) )
			{
				ZombieTank();
			}
		}
		//If a random frenzy chance was triggered, determine whether to frenzy or if to trigger a tank
		else if (GetGameTime() > g_flRageCooldown)
		{
			//In order:
			//The damage scale is above 120%
			//The damage scale is above 80% and the total amount of zombies killed since a survivor died exceeds 12
			//The frenzy chance rng is triggered
			//None of the survivors died in the past 60 seconds
			if ( g_flZombieDamageScale >= 1.2
			|| (g_flZombieDamageScale >= 0.8 && g_iZombiesKilledSpree >= 12)
			|| GetRandomInt(0, 100) <= g_cvFrenzyChance.IntValue
			|| (g_flSurvivorsLastDeath < GetGameTime() - 60.0) )
			{
				//If zombie damage scale is high and the frenzy chance for tank is triggered
				if (GetRandomInt(0, 100) <= g_cvFrenzyTankChance.IntValue && g_flZombieDamageScale >= 1.2)	//convar right now is at 0%
					ZombieTank();
				else
					ZombieRage();
			}
		}
	}
}

public Action Timer_RespawnPlayer(Handle hTimer, any iClient)
{
	if (IsClientInGame(iClient) && !IsPlayerAlive(iClient))
		TF2_RespawnPlayer2(iClient);
}

public Action CheckLastPlayer(Handle hTimer)
{
	int iCount = GetSurvivorCount();
	if (iCount == 1 && !g_bLastSurvivor)
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsValidLivingSurvivor(iClient))
			{
				SetEntityHealth(iClient, 400);
				g_bLastSurvivor = true;
				SetMorale(iClient, 100);
				
				char sName[255];
				GetClientName2(iClient, sName, sizeof(sName));
				CPrintToChatAllEx(iClient, "%s{green} is the last survivor!", sName);
				
				PlaySoundAll(SoundMusic_LastStand);
				
				Call_StartForward(g_hForwardLastSurvivor);
				Call_PushCell(iClient);
				Call_Finish();
			}
		}
	}
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	SoundPrecache();
	DetermineControlPoints();
	Weapons_Precache();
	PrecacheZombieSouls();
	
	PrecacheParticle("spell_cast_wheel_blue");
	
	//Goo
	PrecacheParticle("asplode_hoodoo_green");
	AddFileToDownloadsTable("materials/left4fortress/goo.vmt");
	
	//Boomer
	PrecacheParticle("asplode_hoodoo_debris");
	PrecacheParticle("asplode_hoodoo_dust");
	
	//Map pickup
	PrecacheSound("ui/item_paint_can_pickup.wav");
	
	//Kingpin scream
	PrecacheSound("ambient/halloween/male_scream_15.wav");
	PrecacheSound("ambient/halloween/male_scream_16.wav");
	
	//Hopper scream
	PrecacheSound("ambient/halloween/male_scream_18.wav");
	PrecacheSound("ambient/halloween/male_scream_19.wav");
	
	//Charger ka-klunk
	PrecacheSound("weapons/demo_charge_hit_flesh_range1.wav");
	
	//Smoker beam
	g_iSprite = PrecacheModel("materials/sprites/laser.vmt");
	
	for (int i = 0; i < sizeof(g_strSoundFleshHit); i++)
		PrecacheSound(g_strSoundFleshHit[i]);
	
	for (int i = 0; i < sizeof(g_strSoundCritHit); i++)
		PrecacheSound(g_strSoundCritHit[i]);
	
	HookEntityOutput("logic_relay", "OnTrigger", OnRelayTrigger);
	HookEntityOutput("math_counter", "OutValue", OnCounterValue);
}

public Action OnRelayTrigger(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{
	char sTargetName[255];
	GetEntPropString(iCaller, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
	
	if (StrEqual("szf_panic_event", sTargetName)) ZombieRage(_, true);
	else if (StrEqual("szf_zombierage", sTargetName)) ZombieRage(_, true);
	else if (StrEqual("szf_zombietank", sTargetName)) ZombieTank();
	else if (StrEqual("szf_tank", sTargetName)) ZombieTank();
}

public Action OnCounterValue(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{
	char sTargetName[128];
	GetEntPropString(iCaller, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
	
	if (StrEqual(sTargetName, "szf_cp_override", false)
		|| StrEqual(sTargetName, "szf_progress_override", false)
		|| StrEqual(sTargetName, "szf_cp_scale", false)
		|| StrEqual(sTargetName, "szf_progress_scale", false) )
	{
		static int iOffset = -1;
		iOffset = FindDataMapInfo(iCaller, "m_OutValue");
		g_flCapScale = GetEntDataFloat(iCaller, iOffset);
	}
}

int ZombieRage(float flDuration = 20.0, bool bIgnoreDirector = false)
{
	if (g_nRoundState != SZFRoundState_Active) return;
	if (g_bZombieRage) return;
	if (ZombiesHaveTank()) return;
	if (g_bNoDirectorRages && !bIgnoreDirector) return;
	
	g_bZombieRage = true;
	
	g_flRageRespawnStress = GetGameTime();	//Set initial respawn stress
	g_bZombieRageAllowRespawn = true;
	if (flDuration < 20.0) g_bZombieRageAllowRespawn = false;
	
	CreateTimer(flDuration, Timer_StopZombieRage);
	
	if (flDuration >= 20.0)
	{
		PlaySoundAll(SoundEvent_Incoming, 6.0);
		
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsClientInGame(iClient))
			{
				CPrintToChat(iClient, "%sZombies are frenzied: they respawn faster and are more powerful!", (IsZombie(iClient)) ? "{green}" : "{red}");
				
				if (IsZombie(iClient) && !IsPlayerAlive(iClient))
				{
					TF2_RespawnPlayer2(iClient);
					g_flRageRespawnStress += 1.7;	//Add stress time 1.7 sec for every respawn zombies
				}
				else if (IsSurvivor(iClient) && IsPlayerAlive(iClient))
				{
					//Zombies are enraged, reduce morale
					int iMorale = GetMorale(iClient);
					iMorale = RoundToNearest(float(iMorale) * 0.5);	//Half current morale
					iMorale -= 15;	//Remove 15 extra morale
					if (iMorale < 0) iMorale = 0;
					SetMorale(iClient, iMorale);
				}
			}
		}
	}
	
	g_flRageCooldown = GetGameTime() + flDuration + 40.0;
}

public Action Timer_StopZombieRage(Handle hTimer)
{
	g_bZombieRage = false;
	UpdateZombieDamageScale();
	
	if (g_nRoundState == SZFRoundState_Active)
		for (int iClient = 1; iClient <= MaxClients; iClient++)
			if (IsClientInGame(iClient))
				CPrintToChat(iClient, "%sZombies are resting...", (IsZombie(iClient)) ? "{red}" : "{green}");
}

int FastRespawnNearby(int iClient, float flDistance, bool bMustBeInvisible = true)
{
	if (g_aFastRespawn == null) return -1;
	
	ArrayList aTombola = new ArrayList();
	
	float vecPosClient[3];
	float vecPosEntry[3];
	float vecPosEntry2[3];
	float flEntryDistance;
	GetClientAbsOrigin(iClient, vecPosClient);
	
	int iLength = g_aFastRespawn.Length;
	for (int i = 0; i < iLength; i++)
	{
		g_aFastRespawn.GetArray(i, vecPosEntry);
		vecPosEntry2[0] = vecPosEntry[0];
		vecPosEntry2[1] = vecPosEntry[1];
		vecPosEntry2[2] = vecPosEntry[2] += 90.0;
		
		bool bAllow = true;
		
		flEntryDistance = GetVectorDistance(vecPosClient, vecPosEntry);
		flEntryDistance /= 50.0;
		
		if (flEntryDistance > flDistance)
			bAllow = false;
		
		//Check if survivors can see it
		if (bMustBeInvisible && bAllow)
		{
			for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
			{
				if (IsValidLivingSurvivor(iSurvivor))
				{
					if (PointsAtTarget(vecPosEntry, iSurvivor)) bAllow = false;
					if (PointsAtTarget(vecPosEntry2, iSurvivor)) bAllow = false;
				}
			}
		}
		
		if (bAllow)
			aTombola.Push(i);
	}

	if (aTombola.Length > 0)
	{
		int iRandom = GetRandomInt(0, aTombola.Length-1);
		int iResult = aTombola.Get(iRandom);
		
		delete aTombola;
		return iResult;
	}
	
	delete aTombola;
	return -1;
}

bool PerformFastRespawn(int iClient)
{
	if (!(g_bDirectorSpawnTeleport) && (!g_bZombieRage || !g_bZombieRageAllowRespawn))
		return false;
	
	//First let's find a target
	ArrayList aTombola = new ArrayList();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
			aTombola.Push(i);
	}
	
	if (aTombola.Length <= 0)
	{
		delete aTombola;
		return false;
	}
	
	int iTarget = aTombola.Get(GetRandomInt(0, aTombola.Length-1));
	delete aTombola;
	
	int iResult = FastRespawnNearby(iTarget, 7.0);
	if (iResult < 0) return false;
	
	float vecPosSpawn[3];
	float vecPosTarget[3];
	float vecAngle[3];
	g_aFastRespawn.GetArray(iResult, vecPosSpawn);
	GetClientAbsOrigin(iTarget, vecPosTarget);
	VectorTowards(vecPosSpawn, vecPosTarget, vecAngle);
	
	TeleportEntity(iClient, vecPosSpawn, vecAngle, NULL_VECTOR);
	return true;
}

void FastRespawnDataCollect()
{
	if (g_aFastRespawn == null)
		g_aFastRespawn = new ArrayList(3);
	
	g_aFastRespawn.Clear(); //Clear before adding new stuffs
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidLivingClient(iClient)
			&& FastRespawnNearby(iClient, 1.0, false) < 0
			&& !(GetEntityFlags(iClient) & FL_DUCKING)
			&& GetEntityFlags(iClient) & FL_ONGROUND)
		{
			float vecPos[3];
			GetClientAbsOrigin(iClient, vecPos);
			g_aFastRespawn.PushArray(vecPos);
		}
	}
}

stock void VectorTowards(float vecOrigin[3], float vecTarget[3], float vecAngle[3])
{
	float vecResults[3];
	MakeVectorFromPoints(vecOrigin, vecTarget, vecResults);
	GetVectorAngles(vecResults, vecAngle);
}

stock bool PointsAtTarget(float vecPos[3], any iTarget)
{
	float vecTargetPos[3];
	GetClientEyePosition(iTarget, vecTargetPos);
	
	Handle hTrace = TR_TraceRayFilterEx(vecPos, vecTargetPos, MASK_VISIBLE, RayType_EndPoint, Trace_DontHitOtherEntities, iTarget);
	
	int iHit = -1;
	if (TR_DidHit(hTrace))
		iHit = TR_GetEntityIndex(hTrace);
	
	delete hTrace;
	return (iHit == iTarget);
}

public bool Trace_DontHitOtherEntities(int iEntity, int iMask, any iData)
{
	if (iEntity == iData) return true;
	if (iEntity > 0) return false;
	return true;
}

public bool Trace_DontHitEntity(int iEntity, int iMask, any iData)
{
	if (iEntity == iData) return false;
	return true;
}

stock bool CanRecieveDamage(int iClient)
{
	if (iClient <= 0) return true;
	if (!IsClientInGame(iClient)) return true;
	if (TF2_IsPlayerInCondition(iClient, TFCond_Ubercharged)) return false;
	if (TF2_IsPlayerInCondition(iClient, TFCond_Bonked)) return false;
	
	return true;
}

stock int GetClientPointVisible(int iClient, float flDistance = 100.0)
{
	float vecOrigin[3], vecAngles[3], vecEndOrigin[3];
	GetClientEyePosition(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngles);
	
	Handle hTrace = TR_TraceRayFilterEx(vecOrigin, vecAngles, MASK_ALL, RayType_Infinite, Trace_DontHitEntity, iClient);
	TR_GetEndPosition(vecEndOrigin, hTrace);
	
	int iReturn = -1;
	int iHit = TR_GetEntityIndex(hTrace);
	
	if (TR_DidHit(hTrace) && iHit != iClient && GetVectorDistance(vecOrigin, vecEndOrigin) < flDistance)
		iReturn = iHit;
	
	delete hTrace;
	return iReturn;
}

stock bool ObstactleBetweenEntities(int iEntity1, int iEntity2)
{
	float vecOrigin1[3];
	float vecOrigin2[3];
	
	if (IsValidClient(iEntity1))
		GetClientEyePosition(iEntity1, vecOrigin1);
	else
		GetEntPropVector(iEntity1, Prop_Send, "m_vecOrigin", vecOrigin1);
	
	GetEntPropVector(iEntity2, Prop_Send, "m_vecOrigin", vecOrigin2);
	
	Handle hTrace = TR_TraceRayFilterEx(vecOrigin1, vecOrigin2, MASK_ALL, RayType_EndPoint, Trace_DontHitEntity, iEntity1);
	
	bool bHit = TR_DidHit(hTrace);
	int iHit = TR_GetEntityIndex(hTrace);
	delete hTrace;
	
	if (!bHit) return true;
	if (iHit != iEntity2) return true;
	
	return false;
}

void HandleSurvivorLoadout(int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient)) return;
	
	//Remove primary weapon
	TF2_RemoveWeaponSlot(iClient, WeaponSlot_Primary);
	
	//Remove secondary weapon and wearables
	int iEntity = GetPlayerWeaponSlot(iClient, WeaponSlot_Secondary);
	if (iEntity > 0 && IsValidEdict(iEntity)) TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
	RemoveWearableWeapons(iClient);
	
	//Remove invis watch
	if (TF2_GetPlayerClass(iClient) == TFClass_Spy)
	{
		iEntity = GetPlayerWeaponSlot(iClient, WeaponSlot_InvisWatch);
		if (iEntity > 0 && IsValidEdict(iEntity)) TF2_RemoveWeaponSlot(iClient, WeaponSlot_InvisWatch);
	}
	
	iEntity = GetPlayerWeaponSlot(iClient, WeaponSlot_Melee);
	if (iEntity > MaxClients && IsValidEdict(iEntity))
	{
		//Get default attrib from config to apply all melee weapons
		char sAttribs[32][32];
		int iCount = ExplodeString(g_ConfigMeleeDefault.sAttrib, " ; ", sAttribs, 32, 32);
		if (iCount > 1)
			for (int i = 0; i < iCount; i+= 2)
				TF2Attrib_SetByDefIndex(iEntity, StringToInt(sAttribs[i]), StringToFloat(sAttribs[i+1]));
		
		//Get attrib from index to apply
		int iIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
		
		int iLength = g_aConfigMelee.Length;
		for (int i = 0; i < iLength; i++)
		{
			ConfigMelee Melee;
			g_aConfigMelee.GetArray(i, Melee, sizeof(Melee));
			
			if (Melee.iIndex == iIndex)
			{
				//If have prefab, use said index instead
				if (Melee.iIndexPrefab >= 0)
				{
					int iPrefab = Melee.iIndexPrefab;
					for (int j = 0; j < iLength; j++)
					{
						g_aConfigMelee.GetArray(j, Melee, sizeof(Melee));
						if (Melee.iIndex == iPrefab)
							break;
					}
				}
				
				//See if there weapon to replace
				if (Melee.iIndexReplace >= 0)
				{
					iIndex = Melee.iIndexReplace;
					TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Melee);
					iEntity = TF2_CreateAndEquipWeapon(iClient, iIndex);
					
					//Re-apply global attrib
					for (int j = 0; j < iCount; j+= 2)
						TF2Attrib_SetByDefIndex(iEntity, StringToInt(sAttribs[j]), StringToFloat(sAttribs[j+1]));
				}
				
				//Print text with cooldown to prevent spam
				if (g_flStopChatSpam[iClient] < GetGameTime() && !StrEqual(Melee.sText, ""))
				{
					CPrintToChat(iClient, Melee.sText);
					g_flStopChatSpam[iClient] = GetGameTime() + 1.0;
				}
				
				//Apply attribute
				iCount = ExplodeString(Melee.sAttrib, " ; ", sAttribs, 32, 32);
				if (iCount > 1)
					for (int j = 0; j < iCount; j+= 2)
						TF2Attrib_SetByDefIndex(iEntity, StringToInt(sAttribs[j]), StringToFloat(sAttribs[j+1]));
				
				break;
			}
		}
		
		//This will refresh health max calculation and other attributes
		TF2Attrib_ClearCache(iEntity);
	}
	else
	{
		//No melee, okay.. weird
		TF2_RespawnPlayer2(iClient);
	}
	
	//Prevent Survivors with voodoo-cursed souls
	SetEntProp(iClient, Prop_Send, "m_bForcedSkin", 0);
	SetEntProp(iClient, Prop_Send, "m_nForcedSkin", 0);
	
	SetValidSlot(iClient);
}

void HandleZombieLoadout(int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient)) return;
	
	TF2_RemoveWeaponSlot(iClient, WeaponSlot_Primary);
	TF2_RemoveWeaponSlot(iClient, WeaponSlot_Melee);
	
	int iMelee;
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	
	if (g_nInfected[iClient] == Infected_None)
	{
		switch (nClass)
		{
			case TFClass_Scout:
			{
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_PDADisguise);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_InvisWatch);
				if (!TF2_IsSlotClassname(iClient, 1, "tf_weapon_lunchbox_drink"))
					TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
			}
			
			case TFClass_Soldier:
			{
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_PDADisguise);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_InvisWatch);
				if (!TF2_IsSlotClassname(iClient, 1, "tf_weapon_buff_item"))
					TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
			}
			
			case TFClass_DemoMan:
			{
				RemoveWearableWeapons(iClient);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_PDADisguise);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_InvisWatch);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
			}
			
			case TFClass_Heavy:
			{
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_PDADisguise);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_InvisWatch);
				if (!TF2_IsSlotClassname(iClient, 1, "tf_weapon_lunchbox"))
					TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
			}
			
			case TFClass_Engineer:
			{
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
			}
			
			case TFClass_Spy:
			{
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_PDADisguise);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_InvisWatch);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
				TF2_CreateAndEquipWeapon(iClient, 30); //Cloak
			}
			
			default:
			{
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_PDADisguise);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_InvisWatch);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
			}
		}
		
		iMelee = TF2_CreateAndEquipWeapon(iClient, GetZombieIndex(nClass));
		if (IsValidEntity(iMelee))
		{
			SetZomAttribs(iMelee, nClass);
			if (GetZombieIndex(nClass) == 44) //Sandman
			{
				//Set Sandman ball in cooldown if spammed
				if (g_flGooCooldown[iClient] > GetGameTime())
				{
					int iAmmoType = GetEntProp(iMelee, Prop_Send, "m_iPrimaryAmmoType");
					if (iAmmoType > -1)
						SetEntProp(iClient, Prop_Send, "m_iAmmo", 0, _, iAmmoType);
					
					SetEntPropFloat(iMelee, Prop_Send, "m_flEffectBarRegenTime", g_flGooCooldown[iClient]);
				}
			}
		}
	}
	else
	{
		switch (nClass)
		{
			case TFClass_Soldier, TFClass_DemoMan, TFClass_Sniper:
			{
				RemoveWearableWeapons(iClient);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_PDADisguise);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_InvisWatch);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
			}
			
			case TFClass_Heavy:
			{
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_PDADisguise);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_InvisWatch);
				if (!TF2_IsSlotClassname(iClient, 1, "tf_weapon_lunchbox"))
					TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
			}
			
			case TFClass_Engineer:
			{
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
			}
			
			case TFClass_Spy:
			{
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_PDADisguise);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_InvisWatch);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
				
				if (g_nInfected[iClient] != Infected_Smoker)
					TF2_CreateAndEquipWeapon(iClient, 30); //Cloak
			}
			
			default:
			{
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_PDADisguise);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_InvisWatch);
				TF2_RemoveWeaponSlot(iClient, WeaponSlot_Secondary);
			}
		}
		
		iMelee = TF2_CreateAndEquipWeapon(iClient, GetInfectedIndex(g_nInfected[iClient]));
		if (IsValidEntity(iMelee))
			SetInfAttribs(iMelee, g_nInfected[iClient]);
	}
	
	//Set slot to melee
	if (iMelee > MaxClients && IsValidEdict(iMelee))
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iMelee);
	
	//Set health back to what it should be after modifying weapons
	SetEntityHealth(iClient, SDK_GetMaxHealth(iClient));
	
	//Reset custom models
	SetVariantString("");
	AcceptEntityInput(iClient, "SetCustomModel");
}

void SetZomAttribs(int iMelee, TFClassType nClass)
{
	char sAttrib[256], sAttribs[32][32];
	if (!GetZombieAttribs(sAttrib, sizeof(sAttrib), nClass))
		return;
	
	int iCount = ExplodeString(sAttrib, ";", sAttribs, 32, 32);
	if (iCount % 2)
		--iCount;
	
	if (iCount <= 0)
		return;
	
	for (int i = 0; i < iCount; i += 2)
	{
		int iAttrib = StringToInt(sAttribs[i]);
		if (iAttrib)
			TF2Attrib_SetByDefIndex(iMelee, iAttrib, StringToFloat(sAttribs[i+1]));
	}
}

void SetInfAttribs(int iMelee, Infected nInfected)
{
	char sAttrib[256], sAttribs[32][32];
	if (!GetInfectedAttribs(sAttrib, sizeof(sAttrib), nInfected))
		return;
	
	int iCount = ExplodeString(sAttrib, ";", sAttribs, 32, 32);
	if (iCount % 2)
		--iCount;
	
	if (iCount <= 0)
		return;
	
	for (int i = 0; i < iCount; i += 2)
	{
		int iAttrib = StringToInt(sAttribs[i]);
		if (iAttrib)
			TF2Attrib_SetByDefIndex(iMelee, iAttrib, StringToFloat(sAttribs[i+1]));
	}
}

void SetValidSlot(int iClient)
{
	int iOld = GetEntProp(iClient, Prop_Send, "m_hActiveWeapon");
	if (iOld > 0) return;
	
	int iSlot;
	int iEntity;
	for (iSlot = 0; iSlot <= 5; iSlot++)
	{
		iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (iEntity > 0 && IsValidEdict(iEntity))
		{
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iEntity);
			return;
		}
	}
}

void SpitterGoo(int iClient, int iAttacker = 0, float flDuration = TIME_GOO)
{
	if (g_nRoundState != SZFRoundState_Active) return;
	
	if (g_aGoo == null)
		g_aGoo = new ArrayList(sizeof(GooInfo));
	
	float vecOrigin[3];
	float vecAngles[3];
	GetClientEyePosition(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngles);
	
	g_iGooId++;
	
	GooInfo gooStruct;
	gooStruct.vecOrigin = vecOrigin;
	gooStruct.iAttacker = iAttacker;
	gooStruct.iGooId = g_iGooId;
	g_aGoo.PushArray(gooStruct);
	
	ShowParticle("asplode_hoodoo_dust", TIME_GOO, vecOrigin, vecAngles);
	ShowParticle("asplode_hoodoo_green", TIME_GOO, vecOrigin, vecAngles);
	
	CreateTimer(flDuration, Timer_GooExpire, g_iGooId);
	CreateTimer(1.0, Timer_GooEffect, g_iGooId, TIMER_REPEAT);
}

void GooDamageCheck()
{
	bool[] bWasGooified = new bool[MaxClients+1];
	
	int iClient;
	for (iClient = 1; iClient <= MaxClients; iClient++)
	{
		bWasGooified[iClient] = g_bGooified[iClient];
		g_bGooified[iClient] = false;
	}
	
	if (g_aGoo != null)
	{
		int iLength = g_aGoo.Length;
		for (int i = 0; i < iLength; i++)
		{
			GooInfo gooStruct;
			g_aGoo.GetArray(i, gooStruct);
			
			if (!IsValidClient(gooStruct.iAttacker))
				continue;
			
			for (iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (IsValidLivingSurvivor(iClient) && !g_bGooified[iClient] && CanRecieveDamage(iClient) && !g_bBackstabbed[iClient])
				{
					float vecPosClient[3];
					GetClientEyePosition(iClient, vecPosClient);
					float flDistance = GetVectorDistance(gooStruct.vecOrigin, vecPosClient) / 50.0;
					if (flDistance <= DISTANCE_GOO)
					{
						//Deal damage
						g_iGooMultiplier[iClient] += GOO_INCREASE_RATE;
						float fPercentageDistance = (DISTANCE_GOO-flDistance) / DISTANCE_GOO;
						if (fPercentageDistance < 0.5) fPercentageDistance = 0.5;
						float flDamage = float(g_iGooMultiplier[iClient])/float(GOO_INCREASE_RATE) * fPercentageDistance;
						if (flDamage < 1.0) flDamage = 1.0;
						if (flDamage > 4.0 && g_iCapturingPoint[iClient] != -1) flDamage = 4.0;	//If client is capturing point, add hardmax 4 dmg
						DealDamage(gooStruct.iAttacker, iClient, flDamage);
						g_bGooified[iClient] = true;
						
						if (flDamage >= 7.0)
						{
							int iRandom = GetRandomInt(0, sizeof(g_strSoundCritHit)-1);
							EmitSoundToClient(iClient, g_strSoundCritHit[iRandom], _, SNDLEVEL_AIRCRAFT);
						}
						else
						{
							int iRandom = GetRandomInt(0, sizeof(g_strSoundFleshHit)-1);
							EmitSoundToClient(iClient, g_strSoundFleshHit[iRandom], _, SNDLEVEL_AIRCRAFT);
						}
					}
				}
			}
		}
	}
	
	for (iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			if (IsValidLivingClient(iClient) && !g_bGooified[iClient] && g_iGooMultiplier[iClient] > 0)
				g_iGooMultiplier[iClient]--;
			
			//ScreenFade(iClient, red, green, blue, alpha, delay, type)
			if (!bWasGooified[iClient] && g_bGooified[iClient] && IsPlayerAlive(iClient))
			{
				//Fade screen slightly green
				ClientCommand(iClient, "r_screenoverlay\"left4fortress/goo\"");
				PlaySound(iClient, SoundEvent_Drown);
			}
			
			if (bWasGooified[iClient] && !g_bGooified[iClient])
			{
				//Fade screen slightly green
				ClientCommand(iClient, "r_screenoverlay\"\"");
				if (GetCurrentSound(iClient) == SoundEvent_Drown)
					EndSound(iClient);
			}
		}
	}
}

public Action Timer_GooExpire(Handle hTimer, int iGoo)
{
	if (g_aGoo == null)
		return;
	
	int iLength = g_aGoo.Length;
	for (int i = 0; i < iLength; i++)
	{
		GooInfo gooStruct;
		g_aGoo.GetArray(i, gooStruct);
		
		if (gooStruct.iGooId == iGoo)
		{
			g_aGoo.Erase(i);
			return;
		}
	}
}

void RemoveAllGoo()
{
	if (g_aGoo == null)
		return;
	
	g_aGoo.Clear();
}

public Action Timer_GooEffect(Handle hTimer, int iGoo)
{
	if (g_aGoo == null)
		return Plugin_Stop;
	
	int iLength = g_aGoo.Length;
	for (int i = 0; i < iLength; i++)
	{
		GooInfo gooStruct;
		g_aGoo.GetArray(i, gooStruct);
		
		if (gooStruct.iGooId == iGoo)
		{
			ShowParticle("asplode_hoodoo_green", TIME_GOO, gooStruct.vecOrigin);
			return Plugin_Continue;
		}
	}
	
	return Plugin_Stop;
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrContains(sClassname, "item_healthkit") != -1
	|| StrContains(sClassname, "item_ammopack") != -1
	|| StrEqual(sClassname, "tf_ammo_pack"))
	{
		SDKHook(iEntity, SDKHook_StartTouch, OnPickup);
		SDKHook(iEntity, SDKHook_Touch, OnPickup);
	}
	
	if (StrEqual(sClassname, "item_healthkit_medium"))
	{
		SDKHook(iEntity, SDKHook_Touch, BlockTouch);
		CreateTimer(3.0, Timer_EnableSandvichTouch, EntIndexToEntRef(iEntity));
	}
	else if (StrEqual(sClassname, "item_healthkit_small"))
	{
		SDKHook(iEntity, SDKHook_Touch, OnBananaTouch);
	}
	else if (StrEqual(sClassname, "trigger_capture_area"))
	{
		SDKHook(iEntity, SDKHook_StartTouch, OnCaptureStartTouch);
		SDKHook(iEntity, SDKHook_EndTouch, OnCaptureEndTouch);
	}
	else if (StrEqual(sClassname, "trigger_multiple"))
	{
		char sName[128];
		GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
		
		if (strcmp(sName, "szf_goo_defense", false) == 0)
		{
			SDKHook(iEntity, SDKHook_StartTouch, OnTriggerGooDefenseStart);
			SDKHook(iEntity, SDKHook_EndTouch, OnTriggerGooDefenseEnd);
		}
	}
	else if (StrEqual(sClassname, "tf_projectile_stun_ball"))
	{
		SDKHook(iEntity, SDKHook_StartTouch, BallStartTouch);
		SDKHook(iEntity, SDKHook_Touch, BallTouch);
	}
	else if (StrEqual(sClassname, "tf_dropped_weapon"))
	{
		AcceptEntityInput(iEntity, "kill");
	}
}

public Action OnCaptureStartTouch(int iEntity, int iClient)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "trigger_capture_area")) return Plugin_Continue;
	
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
	{
		char sTriggerName[128];
		GetEntPropString(iEntity, Prop_Data, "m_iszCapPointName", sTriggerName, sizeof(sTriggerName));	//Get trigger cap name
		
		int i = -1;
		while ((i = FindEntityByClassname2(i, "team_control_point")) != -1)	//find team_control_point
		{
			char sPointName[128];
			GetEntPropString(i, Prop_Data, "m_iName", sPointName, sizeof(sPointName));
			if (strcmp(sPointName, sTriggerName, false) == 0)	//Check if trigger cap is the same as team_control_point
			{
				int iIndex = GetEntProp(i, Prop_Data, "m_iPointIndex");	//Get his index
				
				for (int j = 0; j < g_iControlPoints; j++)
					if (g_iControlPointsInfo[j][0] == iIndex && g_iControlPointsInfo[j][1] != 2)	//Check if that capture have not already been captured
						g_iCapturingPoint[iClient] = iIndex;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action OnCaptureEndTouch(int iEntity, int iClient)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "trigger_capture_area")) return Plugin_Continue;
	
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
		g_iCapturingPoint[iClient] = -1;
	
	return Plugin_Continue;
}

public Action OnTriggerGooDefenseStart(int iEntity, int iClient)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "trigger_multiple")) return Plugin_Continue;
	
	char sName[128];
	GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
	if (strcmp(sName, "szf_goo_defense", false) != 0) return Plugin_Continue;
	
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
		g_iCapturingPoint[iClient] = -2;
	
	return Plugin_Continue;
}

public Action OnTriggerGooDefenseEnd(int iEntity, int iClient)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "trigger_multiple")) return Plugin_Continue;
	
	char sName[128];
	GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
	if (strcmp(sName, "szf_goo_defense", false) != 0) return Plugin_Continue;
	
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
		g_iCapturingPoint[iClient] = -1;
	
	return Plugin_Continue;
}

public Action BallStartTouch(int iEntity, int iOther)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "tf_projectile_stun_ball")) return Plugin_Continue;
	
	if (IsValidClient(iOther) && IsPlayerAlive(iOther) && IsSurvivor(iOther))
	{
		int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
		SDKUnhook(iEntity, SDKHook_StartTouch, BallStartTouch);
		SpitterGoo(iOther, iOwner);
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action BallTouch(int iEntity, int iOther)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "tf_projectile_stun_ball")) return Plugin_Continue;
	
	if (iOther > 0 && iOther <= MaxClients && IsClientInGame(iOther) && IsPlayerAlive(iOther) && IsSurvivor(iOther))
	{
		SDKUnhook(iEntity, SDKHook_StartTouch, BallStartTouch);
		SDKUnhook(iEntity, SDKHook_Touch, BallTouch);
		AcceptEntityInput(iEntity, "kill");
	}
	
	return Plugin_Stop;
}

public Action Timer_EnableSandvichTouch(Handle hTimer, int iRef)
{
	int iEntity = EntRefToEntIndex(iRef);
	if (!IsValidEntity(iEntity)) return;
	
	SDKUnhook(iEntity, SDKHook_Touch, BlockTouch);
	SDKHook(iEntity, SDKHook_Touch, OnSandvichTouch);
}

public Action BlockTouch(int iEntity, int iClient)
{
	return Plugin_Handled;
}

public Action OnSandvichTouch(int iEntity, int iClient)
{
	int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
	int iToucher = iClient;
	
	//Check if both owner and toucher is valid
	if (!IsValidClient(iOwner) || !IsValidClient(iToucher)) return Plugin_Continue;
	
	//Dont allow owner and tank collect sandvich
	if (iOwner == iToucher || g_nInfected[iToucher] == Infected_Tank) return Plugin_Handled;
	
	if (GetClientTeam(iToucher) != GetClientTeam(iOwner))
	{
		//Disable Sandvich and kill it
		SetEntProp(iEntity, Prop_Data, "m_bDisabled", 1);
		AcceptEntityInput(iEntity, "Kill");
		
		DealDamage(iOwner, iToucher, 55.0);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action OnBananaTouch(int iEntity, int iClient)
{
	int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
	int iToucher = iClient;
	
	//Check if both owner and toucher is valid
	if (!IsValidClient(iOwner) || !IsValidClient(iToucher)) return Plugin_Continue;
	
	//Dont allow tank to collect health
	if (g_nInfected[iToucher] == Infected_Tank) return Plugin_Handled;
	
	if (GetClientTeam(iToucher) != GetClientTeam(iOwner))
	{
		//Disable Sandvich and kill it
		SetEntProp(iEntity, Prop_Data, "m_bDisabled", 1);
		AcceptEntityInput(iEntity, "Kill");
		
		DealDamage(iOwner, iToucher, 30.0);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

stock int ShowParticle(char[] sParticle, float flDuration, float vecPos[3], float vecAngles[3] = NULL_VECTOR)
{
	int iParticle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(iParticle))
	{
		TeleportEntity(iParticle, vecPos, vecAngles, NULL_VECTOR);
		DispatchKeyValue(iParticle, "effect_name", sParticle);
		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "start");
		CreateTimer(flDuration, Timer_RemoveParticle, iParticle);
	}
	else
	{
		LogError("ShowParticle: could not create info_particle_system");
		return -1;
	}
	
	return iParticle;
}

stock void PrecacheParticle(char[] sParticleName)
{
	if (IsValidEntity(0))
	{
		int iParticle = CreateEntityByName("info_particle_system");
		if (IsValidEdict(iParticle))
		{
			char sName[32];
			GetEntPropString(0, Prop_Data, "m_iName", sName, sizeof(sName));
			DispatchKeyValue(iParticle, "targetname", "tf2particle");
			DispatchKeyValue(iParticle, "parentname", sName);
			DispatchKeyValue(iParticle, "effect_name", sParticleName);
			DispatchSpawn(iParticle);
			SetVariantString(sName);
			AcceptEntityInput(iParticle, "SetParent", 0, iParticle, 0);
			ActivateEntity(iParticle);
			AcceptEntityInput(iParticle, "start");
			CreateTimer(0.01, Timer_RemoveParticle, iParticle);
		}
	}
}

public Action Timer_RemoveParticle(Handle hTimer, int iParticle)
{
	if (iParticle >= 0 && IsValidEntity(iParticle))
	{
		char sClassname[32];
		GetEdictClassname(iParticle, sClassname, sizeof(sClassname));
		if (StrEqual(sClassname, "info_particle_system", false))
		{
			AcceptEntityInput(iParticle, "stop");
			AcceptEntityInput(iParticle, "Kill");
			iParticle = -1;
		}
	}
}

int GetMostDamageZom()
{
	ArrayList aClients = new ArrayList();
	int iHighest = 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient))
			if (g_iDamage[iClient] > iHighest) iHighest = g_iDamage[iClient];
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient) && g_iDamage[iClient] >= iHighest)
			aClients.Push(iClient);
	
	if (aClients.Length <= 0)
	{
		delete aClients;
		return 0;
	}
	
	int iClient = aClients.Get(GetRandomInt(0, aClients.Length-1));
	delete aClients;
	return iClient;
}

bool ZombiesHaveTank()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidLivingZombie(iClient) && g_nInfected[iClient] == Infected_Tank)
			return true;
	
	return false;
}

void ZombieTank(int iCaller = 0)
{
	if (!g_bEnabled) return;
	if (g_nRoundState != SZFRoundState_Active) return;
	if (iCaller <= 0 && g_bNoDirectorTanks) return;
	
	if (ZombiesHaveTank())
	{
		if (IsValidClient(iCaller)) CPrintToChat(iCaller, "{red}Zombies already have a tank.");
		return;
	}
	else if (g_iZombieTank > 0)
	{
		if (IsValidClient(iCaller)) CPrintToChat(iCaller, "{red}A zombie tank is already on the way.");
		return;
	}
	else if (g_bZombieRage)
	{
		if (IsValidClient(iCaller)) CPrintToChat(iCaller, "{red}Zombies are frenzied, tanks cannot spawn during frenzy.");
		return;
	}
	
	if (IsValidZombie(iCaller))
		g_iZombieTank = iCaller;
	else
		g_iZombieTank = GetMostDamageZom();
	
	if (g_iZombieTank <= 0)
		return;
	
	char sName[255];
	GetClientName2(g_iZombieTank, sName, sizeof(sName));
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient))
			CPrintToChatEx(iClient, g_iZombieTank, "%s {green}was chosen to become the TANK!", sName);
	
	if (IsValidClient(iCaller))
		CPrintToChat(iCaller, "{green}Called tank.");
	
	g_bReplaceRageWithSpecialInfectedSpawn[g_iZombieTank] = false;
	g_flTankCooldown = GetGameTime() + 120.0; //Set new cooldown
	SetMoraleAll(0); //Tank spawn, reset morale
}

stock int FindEntityByClassname2(int startEnt, const char[] classname)
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, classname);
}

stock bool IsRazorbackActive(int iClient)
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable_razorback")) != -1)
		if (IsClassname(iEntity, "tf_wearable_razorback") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient && GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 57)
			return GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", TFWeaponSlot_Secondary) >= 100.0;
	
	return false;
}

void RemoveWearableWeapons(int iClient)
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable_demoshield")) != -1)
		if (IsClassname(iEntity, "tf_wearable_demoshield") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient)
			RemoveEdict(iEntity);
	
	while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable")) != -1)
	{
		if (IsClassname(iEntity, "tf_wearable") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			int iIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
			if (iIndex == 57		//Razrorback
				|| iIndex == 231	//Darwin's Danger Shield
				|| iIndex == 642	//Cozy Camper
				|| iIndex == 133	//Gunboats
				|| iIndex == 444	//Mantreads
				|| iIndex == 405	//Ali Baba's Wee Booties
				|| iIndex == 608)	//The Bootlegger
			{
				RemoveEdict(iEntity);
			}
		}
	}
}

stock bool RemoveSecondaryWearable(int iClient)
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable")) != -1)
	{
		if (IsClassname(iEntity, "tf_wearable") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			RemoveEdict(iEntity);
			return true;
		}
	}
	
	return false;
}

int GetAverageDamage()
{
	int iTotalDamage = 0;
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			iTotalDamage += g_iDamage[i];
			iCount++;
		}
	}
	
	return RoundFloat(float(iTotalDamage) / float(iCount));
}

int GetActivePlayerCount()
{
	int i = 0;
	for (int j = 1; j <= MaxClients; j++)
		if (IsValidLivingClient(j)) i++;
	
	return i;
}

void DetermineControlPoints()
{
	g_bCapturingLastPoint = false;
	g_iControlPoints = 0;
	
	for (int i = 0; i < sizeof(g_iControlPointsInfo); i++)
		g_iControlPointsInfo[i][0] = -1;
	
	int iMaster = -1;
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "team_control_point_master")) != -1)
		if (IsClassname(iEntity, "team_control_point_master"))
			iMaster = iEntity;
	
	if (iMaster <= 0)
		return;
	
	iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "team_control_point")) != -1)
	{
		if (IsClassname(iEntity, "team_control_point") && g_iControlPoints < sizeof(g_iControlPointsInfo))
		{
			int iIndex = GetEntProp(iEntity, Prop_Data, "m_iPointIndex");
			g_iControlPointsInfo[g_iControlPoints][0] = iIndex;
			g_iControlPointsInfo[g_iControlPoints][1] = 0;
			g_iControlPoints++;
		}
	}
	
	CheckRemainingCP();
}

void CheckRemainingCP()
{
	g_bCapturingLastPoint = false;
	if (g_iControlPoints <= 0) return;
	
	int iCaptureCount = 0;
	int iCapturing = 0;
	for (int i = 0; i < g_iControlPoints; i++)
	{
		if (g_iControlPointsInfo[i][1] >= 2) iCaptureCount++;
		if (g_iControlPointsInfo[i][1] == 1) iCapturing++;
	}
	
	if (iCaptureCount == g_iControlPoints-1 && iCapturing > 0)
	{
		g_bCapturingLastPoint = true;
		PlaySoundAll(SoundMusic_LastStand);
		if (!g_bSurvival && g_flZombieDamageScale >= 1.6)
			ZombieTank();
	}
}

bool AttemptCarryItem(int iClient)
{
	if (DropCarryingItem(iClient)) return true;
	
	int iTarget = GetClientPointVisible(iClient);
	if (iTarget <= 0 || !(IsClassname(iTarget, "prop_physics") || IsClassname(iTarget, "prop_physics_override")))
		return false;
	
	char sName[255];
	GetEntPropString(iTarget, Prop_Data, "m_iName", sName, sizeof(sName));
	if (!(StrContains(sName, "szf_carry", false) != -1 || StrEqual(sName, "gascan", false) || StrContains(sName, "szf_pick", false) != -1)) return false;
	
	g_iCarryingItem[iClient] = iTarget;
	SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 0);
	AcceptEntityInput(iTarget, "DisableMotion");
	SetEntProp(iTarget, Prop_Send, "m_nSolidType", 0);
	
	EmitSoundToClient(iClient, "ui/item_paint_can_pickup.wav");
	PrintHintText(iClient, "Call 'MEDIC!' to drop your item!\nYou can attack while wielding an item.");
	AcceptEntityInput(iTarget, "FireUser1", iClient, iClient);
	
	char sPath[PLATFORM_MAX_PATH];
	switch (TF2_GetPlayerClass(iClient))
	{
		case TFClass_Scout: Format(sPath, sizeof(sPath), g_sVoCarryScout[GetRandomInt(0, sizeof(g_sVoCarryScout)-1)]);
		case TFClass_Soldier: Format(sPath, sizeof(sPath), g_sVoCarrySoldier[GetRandomInt(0, sizeof(g_sVoCarrySoldier)-1)]);
		case TFClass_Pyro: Format(sPath, sizeof(sPath), g_sVoCarryPyro[GetRandomInt(0, sizeof(g_sVoCarryPyro)-1)]);
		case TFClass_DemoMan: Format(sPath, sizeof(sPath), g_sVoCarryDemoman[GetRandomInt(0, sizeof(g_sVoCarryDemoman)-1)]);
		case TFClass_Heavy: Format(sPath, sizeof(sPath), g_sVoCarryHeavy[GetRandomInt(0, sizeof(g_sVoCarryHeavy)-1)]);
		case TFClass_Engineer: Format(sPath, sizeof(sPath), g_sVoCarryEngineer[GetRandomInt(0, sizeof(g_sVoCarryEngineer)-1)]);
		case TFClass_Medic: Format(sPath, sizeof(sPath), g_sVoCarryMedic[GetRandomInt(0, sizeof(g_sVoCarryMedic)-1)]);
		case TFClass_Sniper: Format(sPath, sizeof(sPath), g_sVoCarrySniper[GetRandomInt(0, sizeof(g_sVoCarrySniper)-1)]);
		case TFClass_Spy: Format(sPath, sizeof(sPath), g_sVoCarrySpy[GetRandomInt(0, sizeof(g_sVoCarrySpy)-1)]);
	}
	
	EmitSoundToAll(sPath, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	return true;
}

void UpdateClientCarrying(int iClient)
{
	int iTarget = g_iCarryingItem[iClient];
	if (iTarget <= 0) return;
	if (!(IsClassname(iTarget, "prop_physics") || IsClassname(iTarget, "prop_physics_override")))
	{
		DropCarryingItem(iClient);
		return;
	}
	
	char sName[255];
	GetEntPropString(iTarget, Prop_Data, "m_iName", sName, sizeof(sName));
	if (!(StrContains(sName, "szf_carry", false) != -1 || StrEqual(sName, "gascan", false) || StrContains(sName, "szf_pick", false) != -1)) return;
	
	float vecOrigin[3];
	float vecAngles[3];
	float vecDistance[3];
	GetClientEyePosition(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngles);
	
	vecOrigin[2] -= 20.0;
	
	vecAngles[0] = 5.0;
	vecAngles[2] += 35.0;
	
	AnglesToVelocity(vecAngles, vecDistance, 60.0);
	AddVectors(vecOrigin, vecDistance, vecOrigin);
	TeleportEntity(iTarget, vecOrigin, vecAngles, NULL_VECTOR);
}

bool DropCarryingItem(int iClient, bool bDrop = true)
{
	int iTarget = g_iCarryingItem[iClient];
	if (iTarget <= 0) return false;
	
	g_iCarryingItem[iClient] = -1;
	SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 1);
	
	if (!(IsClassname(iTarget, "prop_physics") || IsClassname(iTarget, "prop_physics_override")))
		return true;
	
	SetEntProp(iTarget, Prop_Send, "m_nSolidType", 6);
	AcceptEntityInput(iTarget, "EnableMotion");
	AcceptEntityInput(iTarget, "FireUser2", iClient, iClient);
	
	if (bDrop)
	{
		float vecOrigin[3];
		GetClientEyePosition(iClient, vecOrigin);
		
		if (!IsEntityStuck(iTarget) && !ObstactleBetweenEntities(iClient, iTarget))
		{
			vecOrigin[0] += 20.0;
			vecOrigin[2] -= 30.0;
		}
		
		TeleportEntity(iTarget, vecOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	
	return true;
}

stock void AnglesToVelocity(float vecAngle[3], float vecVelocity[3], float flSpeed = 1.0)
{
	vecVelocity[0] = Cosine(DegToRad(vecAngle[1]));
	vecVelocity[1] = Sine(DegToRad(vecAngle[1]));
	vecVelocity[2] = Sine(DegToRad(vecAngle[0])) * -1.0;
	
	NormalizeVector(vecVelocity, vecVelocity);
	
	ScaleVector(vecVelocity, flSpeed);
}

stock bool IsEntityStuck(int iEntity)
{
	float vecMin[3];
	float vecMax[3];
	float vecOrigin[3];
	
	GetEntPropVector(iEntity, Prop_Send, "m_vecMins", vecMin);
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", vecMax);
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, Trace_DontHitEntity, iEntity);
	return (TR_DidHit());
}

public Action SoundHook(int iClients[64], int &iLength, char sSound[PLATFORM_MAX_PATH], int &iClient, int &iChannel, float &flVolume, int &iLevel, int &iPitch, int &iFlags)
{
	if (!IsValidClient(iClient))
		return Plugin_Continue;
	
	if (StrContains(sSound, "vo/", false) != -1 && IsZombie(iClient))
	{
		if (StrContains(sSound, "zombie_vo/", false) != -1)
			return Plugin_Continue; //So rage sounds (for normal & most special infected alike) don't get blocked
		
		switch (g_nInfected[iClient])
		{
			//Normal infected & kingpin(pitch only)
			case Infected_None, Infected_Kingpin:
			{
				if (StrContains(sSound, "_pain", false) != -1)
				{
					if (GetClientHealth(iClient) < 50 || StrContains(sSound, "crticial", false) != -1)  //The typo is intended because that's how the soundfiles are named
						EmitSoundToAll(g_sVoZombieCommonDeath[GetRandomInt(0, sizeof(g_sVoZombieCommonDeath) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
					else
						EmitSoundToAll(g_sVoZombieCommonPain[GetRandomInt(0, sizeof(g_sVoZombieCommonPain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}
				else if (StrContains(sSound, "_laugh", false) != -1 || StrContains(sSound, "_no", false) != -1 || StrContains(sSound, "_yes", false) != -1)
				{
					EmitSoundToAll(g_sVoZombieCommonMumbling[GetRandomInt(0, sizeof(g_sVoZombieCommonMumbling) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}
				else if (StrContains(sSound, "_go", false) != -1 || StrContains(sSound, "_jarate", false) != -1)
				{
					EmitSoundToAll(g_sVoZombieCommonShoved[GetRandomInt(0, sizeof(g_sVoZombieCommonShoved) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}
				else
				{
					EmitSoundToAll(g_sVoZombieCommonDefault[GetRandomInt(0, sizeof(g_sVoZombieCommonDefault) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}
				
				if (g_nInfected[iClient] == Infected_Kingpin)
					iPitch = 80;
			}
			
			//Tank
			case Infected_Tank:
			{
				if (StrContains(sSound, "_pain", false) != -1)
				{
					if (TF2_IsPlayerInCondition(iClient, TFCond_OnFire))
						EmitSoundToAll(g_sVoZombieTankOnFire[GetRandomInt(0, sizeof(g_sVoZombieTankOnFire) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
					else
						EmitSoundToAll(g_sVoZombieTankPain[GetRandomInt(0, sizeof(g_sVoZombieTankPain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}
				else
				{
					EmitSoundToAll(g_sVoZombieTankDefault[GetRandomInt(0, sizeof(g_sVoZombieTankDefault) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}
			}
			
			//Charger
			case Infected_Charger:
			{
				if (StrContains(sSound, "_pain", false) != -1)
					EmitSoundToAll(g_sVoZombieChargerPain[GetRandomInt(0, sizeof(g_sVoZombieChargerPain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				else
					EmitSoundToAll(g_sVoZombieChargerDefault[GetRandomInt(0, sizeof(g_sVoZombieChargerDefault) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
			
			//Hunter
			case Infected_Hunter:
			{
				if (StrContains(sSound, "_pain", false) != -1)
					EmitSoundToAll(g_sVoZombieHunterPain[GetRandomInt(0, sizeof(g_sVoZombieHunterPain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				else
					EmitSoundToAll(g_sVoZombieHunterDefault[GetRandomInt(0, sizeof(g_sVoZombieHunterDefault) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
			
			//Boomer
			case Infected_Boomer:
			{
				if (StrContains(sSound, "_pain", false) != -1)
					EmitSoundToAll(g_sVoZombieBoomerPain[GetRandomInt(0, sizeof(g_sVoZombieBoomerPain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				else
					EmitSoundToAll(g_sVoZombieBoomerDefault[GetRandomInt(0, sizeof(g_sVoZombieBoomerPain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
			
			//Smoker
			case Infected_Smoker:
			{
				if (StrContains(sSound, "_pain", false) != -1)
					EmitSoundToAll(g_sVoZombieSmokerPain[GetRandomInt(0, sizeof(g_sVoZombieSmokerPain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				else
					EmitSoundToAll(g_sVoZombieSmokerDefault[GetRandomInt(0, sizeof(g_sVoZombieSmokerDefault) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
		}
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

stock bool IsClassname(int iEntity, char[] sClassname)
{
	if (iEntity <= 0) return false;
	if (!IsValidEdict(iEntity)) return false;
	
	char sClassname2[32];
	GetEdictClassname(iEntity, sClassname2, sizeof(sClassname2));
	if (StrEqual(sClassname, sClassname2, false)) return true;
	
	return false;
}

stock int FindChargerTarge(int iClient)
{
	int iEntity = MaxClients+1;
	while((iEntity = FindEntityByClassname2(iEntity, "tf_wearable_demoshield")) != -1)
	{
		int iIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
		if (iIndex == 406 && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient && !GetEntProp(iEntity, Prop_Send, "m_bDisguiseWearable"))
			return iEntity;
	}
	
	return -1;
}

public Action Event_Broadcast(Event event, const char[] name, bool dontBroadcast)
{
	char sSound[20];
	event.GetString("sound", sSound, sizeof(sSound));
	
	if (!strcmp(sSound, "Game.YourTeamWon", false) || !strcmp(sSound, "Game.YourTeamLost", false))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

void SetNextAttack(int iClient, float flDuration = 0.0, bool bMeleeOnly = true)
{
	if (!IsValidClient(iClient)) return;
	
	//Primary, secondary and melee
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_Melee; iSlot++)
	{
		if (bMeleeOnly && iSlot < WeaponSlot_Melee)
			continue;
		
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon > MaxClients && IsValidEntity(iWeapon))
		{
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", flDuration);
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", flDuration);
		}
	}
}

public Action OnPickup(int iEntity, int iClient)
{
	//If picker is a zombie and entity has no owner (sandvich)
	if (IsValidZombie(iClient) && GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity") == -1)
	{
		char sClassname[32];
		GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
		if (StrContains(sClassname, "item_ammopack") != -1
		|| StrContains(sClassname, "item_healthkit") != -1
		|| StrEqual(sClassname, "tf_ammo_pack"))
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

stock void InitiateSurvivorTutorial(int iClient)
{
	DataPack data;
	CreateDataTimer(1.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Welcome to Super Zombie Fortress!");
	
	CreateDataTimer(6.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("You are currently playing as a Survivor.");
	
	CreateDataTimer(11.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("As a Survivor, your goal is to complete the map objective.");
	
	CreateDataTimer(16.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("You may have noticed you do not have any weapons.");
	
	CreateDataTimer(21.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("You can pick up weapons by calling for medic or attacking it.");
	
	CreateDataTimer(26.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("There are normal infected but also special infected, so watch out for those!");
	
	CreateDataTimer(31.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("You can check out more information by typing '/szf' into the chat.");
	
	CreateDataTimer(36.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Enjoy the round and good luck out there!");
	
	SetCookie(iClient, 1, g_cFirstTimeSurvivor);
}

stock void InitiateZombieTutorial(int iClient)
{
	DataPack data;
	CreateDataTimer(1.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Welcome to Super Zombie Fortress!");
	
	CreateDataTimer(6.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("You are currently playing as a Zombie.");
	
	CreateDataTimer(11.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("As a Zombie, your goal is to kill the Survivors.");
	
	CreateDataTimer(16.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("You and your teammates may be selected to become special infected later on.");
	
	CreateDataTimer(21.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("In addition, a tank may be spawned later in the round.");
	
	CreateDataTimer(26.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("You can check out more information by typing '/szf' into the chat.");
	
	CreateDataTimer(31.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Enjoy the round and get them!");
	
	SetCookie(iClient, 1, g_cFirstTimeZombie);
}

public Action Timer_DisplayTutorialMessage(Handle hTimer, DataPack data)
{
	char sDisplay[255];
	data.Reset();
	
	int iClient = data.ReadCell();
	float flDuration = data.ReadFloat();
	data.ReadString(sDisplay, sizeof(sDisplay));
	
	if (!IsValidClient(iClient)) return;
	
	SetHudTextParams(-1.0, 0.32, flDuration, 100, 100, 255, 128);
	ShowHudText(iClient, 4, sDisplay);
}

//Zombie Rages
public void DoGenericRage(int iClient)
{
	int iHealth = GetClientHealth(iClient);
	SetEntityHealth(iClient, RoundToCeil(iHealth * 1.5));
	
	float vecClientPos[3];
	GetClientEyePosition(iClient, vecClientPos);
	vecClientPos[2] -= 60.0; //Wheel goes down or smth, so thats why i did that i guess
	
	ShowParticle("spell_cast_wheel_blue", 4.0, vecClientPos);
	PrintHintText(iClient, "Rage Activated!");
}

public void DoBoomerExplosion(int iClient, float flRadius)
{
	//No need to set rage cooldown: he's fucking dead LMAO
	float vecClientPos[3];
	float vecSurvivorPos[3];
	GetClientEyePosition(iClient, vecClientPos);
	
	ShowParticle("asplode_hoodoo_debris", 6.0, vecClientPos);
	ShowParticle("asplode_hoodoo_dust", 6.0, vecClientPos);
	
	int[] iClientsTemp = new int[MaxClients];
	int iCount = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
		{
			GetClientEyePosition(i, vecSurvivorPos);
			float flDistance = GetVectorDistance(vecClientPos, vecSurvivorPos);
			if (flDistance <= flRadius)
			{
				float flDuration = 12.0 - (flDistance * 0.01);
				TF2_AddCondition(i, TFCond_Jarated, flDuration);
				PlaySound(i, SoundEvent_Jarate, flDuration);
				
				iClientsTemp[iCount] = i;
				iCount++;
			}
		}
	}
	
	int iClients[MAXPLAYERS];
	for (int i = 0; i < iCount; i++)
		iClients[i] = iClientsTemp[i];
	
	Call_StartForward(g_hForwardBoomerExplode);
	Call_PushCell(iClient);
	Call_PushArray(iClients, MAXPLAYERS);
	Call_PushCell(iCount);
	Call_Finish();
	
	if (IsPlayerAlive(iClient))
		FakeClientCommandEx(iClient, "explode");
}

public void DoKingpinRage(int iClient, float flRadius)
{
	float vecPosScreamer[3]; //Fun fact: this is based on l4d's scrapped "screamer" special infected, which "buffed" zombies with its presence
	float vecPosZombie[3];
	GetClientEyePosition(iClient, vecPosScreamer);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsZombie(i))
		{
			GetClientEyePosition(i, vecPosZombie);
			float flDistance = GetVectorDistance(vecPosScreamer, vecPosZombie);
			if (flDistance <= flRadius)
			{
				TF2_AddCondition(i, TFCond_DefenseBuffed, 7.0 - flDistance / 120.0);
				Shake(i, 3.0, 3.0);
			}
		}
	}
}

public void DoHunterJump(int iClient)
{
	char sPath[64];
	Format(sPath, sizeof(sPath), "ambient/halloween/male_scream_%d.wav", GetRandomInt(18, 19));
	EmitSoundToAll(sPath, iClient, SNDLEVEL_AIRCRAFT);
	
	CreateTimer(0.3, Timer_SetHunterJump, iClient);
	
	float vecVelocity[3];
	float vecEyeAngles[3];
	
	GetClientEyeAngles(iClient, vecEyeAngles);
	
	vecVelocity[0] = Cosine(DegToRad(vecEyeAngles[0])) * Cosine(DegToRad(vecEyeAngles[1])) * 920;
	vecVelocity[1] = Cosine(DegToRad(vecEyeAngles[0])) * Sine(DegToRad(vecEyeAngles[1])) * 920;
	vecVelocity[2] = 460.0;
	
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	if (IsValidLivingZombie(iClient))
	{
		//Smoker
		if (g_nInfected[iClient] == Infected_Smoker)
		{
			if (iButtons & IN_ATTACK2 && (GetEntityFlags(iClient) & FL_ONGROUND == FL_ONGROUND))
			{
				SetEntityMoveType(iClient, MOVETYPE_NONE);
				DoSmokerBeam(iClient);
				iButtons &= ~IN_ATTACK2;
			}
			else if (GetEntityMoveType(iClient) == MOVETYPE_NONE)
			{
				g_iSmokerBeamHits[iClient] = 0;
				g_iSmokerBeamHitVictim[iClient] = 0;
				SetEntityMoveType(iClient, MOVETYPE_WALK);
			}
		}
		
		//Stalker
		if (g_nInfected[iClient] == Infected_Stalker)
		{
			//To prevent fuckery with cloaking
			if (iButtons & IN_ATTACK2)
				iButtons &= ~IN_ATTACK2;
		}
	}
	
	//If an item was succesfully grabbed
	if ((iButtons & IN_ATTACK || iButtons & IN_ATTACK2) && AttemptGrabItem(iClient))
	{
		//Block the primary or secondary attack
		iButtons &= ~IN_ATTACK;
		iButtons &= ~IN_ATTACK2;
	}
	
	return Plugin_Continue;
}

public void DoSmokerBeam(int iClient)
{
	float vecOrigin[3], vecAngles[3], vecEndOrigin[3], vecHitPos[3];
	GetClientEyePosition(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngles);
	
	Handle hTrace = TR_TraceRayFilterEx(vecOrigin, vecAngles, MASK_ALL, RayType_Infinite, Trace_DontHitEntity, iClient);
	TR_GetEndPosition(vecEndOrigin, hTrace);
	
	//750 in L4D2, scaled to TF2 player hull sizing (32hu -> 48hu)
	if (GetVectorDistance(vecOrigin, vecEndOrigin) > 1150.0)
	{
		delete hTrace;
		return;
	}
	
	//Smoker's tongue beam
	//Beam that gets sent to all other clients
	TE_SetupBeamPoints(vecOrigin, vecEndOrigin, g_iSprite, 0, 0, 0, 0.08, 5.0, 5.0, 10, 0.0, { 255, 255, 255, 255 }, 0);
	int iTotal = 0;
	int[] iClients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && i != iClient)
			iClients[iTotal++] = i;
	
	TE_Send(iClients, iTotal);
	
	//Send a different beam to smoker
	float vecNewOrigin[3];
	vecNewOrigin[0] = vecOrigin[0];
	vecNewOrigin[1] = vecOrigin[1];
	vecNewOrigin[2] = vecOrigin[2] - 7.0;
	TE_SetupBeamPoints(vecNewOrigin, vecEndOrigin, g_iSprite, 0, 0, 0, 0.08, 2.0, 5.0, 10, 0.0, { 255, 255, 255, 255 }, 0);
	TE_SendToClient(iClient);
	
	int iHit = TR_GetEntityIndex(hTrace);
	
	if (TR_DidHit(hTrace) && IsValidLivingSurvivor(iHit) && !TF2_IsPlayerInCondition(iHit, TFCond_Dazed))
	{
		//Calculate pull velocity towards Smoker
		if (!g_bBackstabbed[iClient])
		{
			float vecVelocity[3];
			GetClientAbsOrigin(iHit, vecHitPos);
			MakeVectorFromPoints(vecOrigin, vecHitPos, vecVelocity);
			NormalizeVector(vecVelocity, vecVelocity);
			ScaleVector(vecVelocity, fMin(-450.0 + GetClientHealth(iHit), -10.0) );
			TeleportEntity(iHit, NULL_VECTOR, NULL_VECTOR, vecVelocity);
		}
		
		//If target changed, change stored target AND reset beam hit count
		if (g_iSmokerBeamHitVictim[iClient] != iHit)
		{
			g_iSmokerBeamHitVictim[iClient] = iHit;
			g_iSmokerBeamHits[iClient] = 0;
		}
		
		//Increase count and if it reaches a threshold, apply damage
		g_iSmokerBeamHits[iClient]++;
		if (g_iSmokerBeamHits[iClient] == 5)
		{
			DealDamage(iClient, iHit, 2.0); //Do damage
			g_iSmokerBeamHits[iClient] = 0;
		}
		
		Shake(iHit, 4.0, 0.2); //Shake effect
	}
	
	delete hTrace;
}


public Action Timer_SetHunterJump(Handle timer, any iClient)
{
	if (IsValidLivingZombie(iClient))
		g_bHopperIsUsingPounce[iClient] = true;
	
	return Plugin_Continue;
}

void SDK_Init()
{
	Handle hGameData = LoadGameConfigFile("sdkhooks.games");
	if (hGameData == null) SetFailState("Could not find sdkhooks.games gamedata!");
	
	//This function is used to control player's max health
	int iOffset = GameConfGetOffset(hGameData, "GetMaxHealth");
	g_hHookGetMaxHealth = DHookCreate(iOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, Client_GetMaxHealth);
	if (g_hHookGetMaxHealth == null) LogMessage("Failed to create hook: CTFPlayer::GetMaxHealth!");
	
	//This function is used to retreive player's max health
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxHealth = EndPrepSDKCall();
	if (g_hSDKGetMaxHealth == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxHealth!");
	
	delete hGameData;
	
	hGameData = LoadGameConfigFile("szf");
	
	//This function is used to get weapon max ammo
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxAmmo = EndPrepSDKCall();
	if (g_hSDKGetMaxAmmo == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo!");
	
	//This function is used to equip wearables 
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKEquipWearable = EndPrepSDKCall();
	if (g_hSDKEquipWearable == null)
		LogMessage("Failed to create call: CBasePlayer::EquipWearable!");
	
	//This function is used to remove a player wearable properly
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBasePlayer::RemoveWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKRemoveWearable = EndPrepSDKCall();
	if (g_hSDKRemoveWearable == null)
		LogMessage("Failed to create call: CBasePlayer::RemoveWearable!");
	
	//This function is used to get wearable equipped in loadout slots
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKGetEquippedWearable = EndPrepSDKCall();
	if (g_hSDKGetEquippedWearable == null)
		LogMessage("Failed to create call: CTFPlayer::GetEquippedWearableForLoadoutSlot!");
	
	delete hGameData;
}

public MRESReturn Client_GetMaxHealth(int iClient, Handle hReturn)
{
	if (g_iMaxHealth[iClient] > 0)
	{
		DHookSetReturn(hReturn, g_iMaxHealth[iClient]);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

stock int SDK_GetMaxHealth(int iClient)
{
	if (g_hSDKGetMaxHealth != null)
		return SDKCall(g_hSDKGetMaxHealth, iClient);
	
	return 0;
}

stock int SDK_GetMaxAmmo(int iClient, int iSlot)
{
	if (g_hSDKGetMaxAmmo != null)
		return SDKCall(g_hSDKGetMaxAmmo, iClient, iSlot, -1);
	
	return -1;
}

stock void SDK_EquipWearable(int iClient, int iWearable)
{
	if (g_hSDKEquipWearable != null)
		SDKCall(g_hSDKEquipWearable, iClient, iWearable);
}
stock void SDK_RemoveWearable(int iClient, int iWearable)
{
	if (g_hSDKRemoveWearable != null)
		SDKCall(g_hSDKRemoveWearable, iClient, iWearable);
}
stock int SDK_GetEquippedWearable(int iClient, int iSlot)
{
	if (g_hSDKGetEquippedWearable != null)
		return SDKCall(g_hSDKGetEquippedWearable, iClient, iSlot);
	
	return -1;
}

stock void SetBackstabState(int iClient, float flDuration = BACKSTABDURATION_FULL, float flSlowdown = 0.5)
{
	if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
	{
		int iSurvivors = GetSurvivorCount();
		int iZombies = GetZombieCount();
		
		//Reduce backstab duration if:
		//3 or less survivors are left while there are 12 or more zombies
		//There are 24 or more zombies
		//Zombie damage scale is 50% or lower
		//Victim has the defense buff
		if ( flDuration > BACKSTABDURATION_REDUCED && (
				( iSurvivors <= 3 && iZombies >= 12 )
				|| iZombies >= 24
				|| g_flZombieDamageScale <= 0.5
				|| TF2_IsPlayerInCondition(iClient, TFCond_DefenseBuffed) ) )
		{
			flDuration = BACKSTABDURATION_REDUCED;
		}
		
		TF2_StunPlayer(iClient, flDuration, flSlowdown, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_SLOWDOWN, 0);
		g_bBackstabbed[iClient] = true;
		ClientCommand(iClient, "r_screenoverlay\"debug/yuv\"");
		PlaySound(iClient, SoundEvent_NearDeath, flDuration);
		CreateTimer(flDuration, RemoveBackstab, iClient); //Removes overlay and backstate state
	}
}

public Action RemoveBackstab(Handle hTimer, int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient)) return;
	g_bBackstabbed[iClient] = false;
	ClientCommand(iClient, "r_screenoverlay\"\"");
}

stock void AddMorale(int iClient, int iAmount)
{
	g_iMorale[iClient] = g_iMorale[iClient] + iAmount;
	
	if (g_iMorale[iClient] > 100) g_iMorale[iClient] = 100;
	if (g_iMorale[iClient] < 0) g_iMorale[iClient] = 0;
}

stock void AddMoraleAll(int iAmount)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidLivingSurvivor(iClient))
			AddMorale(iClient, iAmount);
}

stock void SetMorale(int iClient, int iAmount)
{
	g_iMorale[iClient] = iAmount;
}

stock void SetMoraleAll(int iAmount)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidLivingSurvivor(iClient))
			SetMorale(iClient, iAmount);
}

stock int GetMorale(int iClient)
{
	return g_iMorale[iClient];
}
