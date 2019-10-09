#pragma semicolon 1

//
// Includes
//
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

#define PLUGIN_VERSION "3.1.7"

#define INT(%0)		view_as<int>(%0)

#define MAX_DIGITS 	12 // 10 + \0 for IntToString. And negative signs.

#define GOO_INCREASE_RATE		3

Handle cookieFirstTimeSurvivor;
Handle cookieFirstTimeZombie;
Handle cookieNoMusicForPlayer;
Handle cookieForceZombieStart;

// Global State
bool zf_bEnabled;
bool zf_bNewRound;
int zf_lastSurvivor;

float zf_spawnSurvivorsLastDeath = 0.0;
int zf_spawnSurvivorsKilledCounter;
int zf_spawnZombiesKilledCounter;
int zf_spawnZombiesKilledSpree;
int zf_spawnZombiesKilledSurvivor[MAXPLAYERS+1] = 0;

// Client State
int zf_survivorMorale[MAXPLAYERS+1];
int zf_hordeBonus[MAXPLAYERS+1];
int zf_CapturingPoint[MAXPLAYERS+1];
int zf_rageTimer[MAXPLAYERS+1];
bool zf_screamerNearby[MAXPLAYERS+1] = false;

bool g_bStartedAsZombie[MAXPLAYERS+1];
float g_flStopChatSpam[MAXPLAYERS+1] = 0.0;
bool g_bWaitingForTeamSwitch[MAXPLAYERS+1] = false;

int g_iSprite; // Smoker beam

// Global Timer Handles
Handle zf_tMain;
Handle zf_tMoraleDecay;
Handle zf_tMainFast;
Handle zf_tMainSlow;
Handle zf_tHoarde;
Handle zf_tDataCollect;
Handle zf_tTimeProgress;

// Cvar Handles
Handle zf_cvForceOn;
Handle zf_cvRatio;
Handle zf_cvSwapOnPayload;
Handle zf_cvSwapOnAttdef;
Handle zf_cvTankHealth;
Handle zf_cvTankHealthMin;
Handle zf_cvTankHealthMax;
Handle zf_cvTankTime;
Handle zf_cvFrenzyChance;
Handle zf_cvFrenzyTankChance;

float g_fZombieDamageScale = 1.0;

//int g_StartTime = 0;
//int g_AdditionalTime = 0;

ArrayList g_aFastRespawnArray;

bool g_bBackstabbed[MAXPLAYERS+1] = false;
#define BACKSTABDURATION_FULL		5.5
#define BACKSTABDURATION_REDUCED	3.5

int g_iDamage[MAXPLAYERS+1] = 0;
int g_iDamageTakenLife[MAXPLAYERS+1] = 0;
int g_iDamageDealtLife[MAXPLAYERS+1] = 0;

float g_fDamageDealtAgainstTank[MAXPLAYERS+1] = 0.0;
float g_flTankLifetime[MAXPLAYERS+1] = 0.0;
bool g_bTankRefreshed = false;

bool g_bRoundActive = false;
bool g_bFirstRound = true;

int g_iControlPointsInfo[20][2];
int g_iControlPoints = 0;
bool g_bCapturingLastPoint = false;
int g_iCarryingItem[MAXPLAYERS+1] = -1;

float g_fTimeProgress = 0.0;

#define DISTANCE_GOO            4.0
#define TIME_GOO                7.0

#define INFECTED_NONE		0
#define INFECTED_MAX		7
// ---------------------------------------
#define INFECTED_TANK		1 // tank
#define INFECTED_BOOMER		2 // boomer
#define INFECTED_CHARGER	3 // charger
#define INFECTED_KINGPIN	4 // 'screamer'
#define INFECTED_STALKER	5 // 'jockey'
#define INFECTED_HUNTER		6 // hunter
#define INFECTED_SMOKER		7 // smoker

#define OBJECT_ID_DISPENSER		0

#define STUNNED_DAMAGE_CAP		10.0

#define ATTRIB_DRAIN_HEALTH 			855
#define ATTRIB_HEALTH_PENALTY 			125
#define ATTRIB_DMG_BONUS_VS_BUILDINGS 	137
#define ATTRIB_MAXAMMO_INCREASE 		76

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
Handle g_hForwardLastSurvivor;
Handle g_hForwardBackstab;
Handle g_hForwardTankSpawn;
Handle g_hForwardTankDeath;
Handle g_hForwardQuickSpawnAsSpecialInfected;
Handle g_hForwardChargerHit;
Handle g_hForwardHunterHit;
Handle g_hForwardBoomerExplode;
Handle g_hForwardWeaponPickup;
Handle g_hForwardWeaponCallout;
Handle g_hForwardClientName;
Handle g_hForwardStartZombie;
Handle g_hForwardAllowMusicPlay;

//SDK functions
Handle g_hHookGetMaxHealth = null;
Handle g_hSDKGetMaxHealth = null;
Handle g_hSDKGetMaxAmmo = null;
Handle g_hSDKEquipWearable = null;
Handle g_hSDKRemoveWearable = null;
Handle g_hSDKGetEquippedWearable = null;

float g_flTankCooldown = 0.0;
float g_flRageCooldown = 0.0;
float g_flRageRespawnStress = 0.0;
float g_flInfectedCooldown[INFECTED_MAX+1] = 0.0;	//GameTime
int g_iInfectedCooldown[INFECTED_MAX+1];			//Client who started the cooldown
float g_flSelectSpecialCooldown = 0.0;

Handle g_hGoo = INVALID_HANDLE;

bool g_bZombieRage = false;
int g_iZombieTank = 0;
bool g_bZombieRageAllowRespawn = false;
int g_iGooId = 0;
int g_iGooMultiplier[MAXPLAYERS+1] = 0;
bool g_bGooified[MAXPLAYERS+1] = false;
bool g_bHitOnce[MAXPLAYERS+1] = false;
bool g_bHopperIsUsingPounce[MAXPLAYERS+1] = false;
float g_flGooCooldown[MAXPLAYERS+1] = 0.0;

bool g_bSpawnAsSpecialInfected[MAXPLAYERS+1] = false;
int g_iSpecialInfected[MAXPLAYERS+1] = 0;
int g_iNextSpecialInfected[MAXPLAYERS+1] = 0;
int g_iKillsThisLife[MAXPLAYERS+1] = 0;
int g_iEyelanderHead[MAXPLAYERS+1] = 0;
int g_iMaxHealth[MAXPLAYERS+1] = -1;
int g_iSuperHealthSubtract[MAXPLAYERS+1] = 0;
int g_iStartSurvivors = 0;
bool g_ShouldBacteriaPlay[MAXPLAYERS+1] = true;
bool g_bReplaceRageWithSpecialInfectedSpawn[MAXPLAYERS+1] = false;
int g_iSmokerBeamHits[MAXPLAYERS+1] = 0;
int g_iSmokerBeamHitVictim[MAXPLAYERS+1] = 0;
float g_flTimeStartAsZombie[MAXPLAYERS+1] = 0.0;
bool g_bForceZombieStart[MAXPLAYERS+1] = false;

// Map overwrites
float g_flCapScale = -1.0;
bool g_bSurvival = false;
bool g_bNoMusic = false;
bool g_bNoDirectorTanks = false;
bool g_bNoDirectorRages = false;
bool g_bDirectorSpawnTeleport = false;

// Goo
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
#include "szf/stocks.sp"
#include "szf/sound.sp"
#include "szf/pickupweapons.sp"
#include "szf/config.sp"

//
// Plugin Information
//
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
	g_hForwardLastSurvivor = CreateGlobalForward("SZF_OnLastSurvivor", ET_Ignore, Param_Cell);
	g_hForwardBackstab = CreateGlobalForward("SZF_OnBackstab", ET_Ignore, Param_Cell, Param_Cell);
	g_hForwardTankSpawn = CreateGlobalForward("SZF_OnTankSpawn", ET_Ignore, Param_Cell);
	g_hForwardTankDeath = CreateGlobalForward("SZF_OnTankDeath", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hForwardQuickSpawnAsSpecialInfected = CreateGlobalForward("SZF_OnQuickSpawnAsSpecialInfected", ET_Ignore, Param_Cell);
	g_hForwardChargerHit = CreateGlobalForward("SZF_OnChargerHit", ET_Ignore, Param_Cell, Param_Cell);
	g_hForwardHunterHit = CreateGlobalForward("SZF_OnHunterHit", ET_Ignore, Param_Cell, Param_Cell);
	g_hForwardBoomerExplode = CreateGlobalForward("SZF_OnBoomerExplode", ET_Ignore, Param_Cell, Param_Array, Param_Cell);
	g_hForwardWeaponPickup = CreateGlobalForward("SZF_OnWeaponPickup", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hForwardWeaponCallout = CreateGlobalForward("SZF_OnWeaponCallout", ET_Ignore, Param_Cell);
	g_hForwardClientName = CreateGlobalForward("SZF_GetClientName", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	g_hForwardStartZombie = CreateGlobalForward("SZF_ShouldStartZombie", ET_Hook, Param_Cell);
	g_hForwardAllowMusicPlay = CreateGlobalForward("SZF_ShouldAllowMusicPlay", ET_Hook);
	
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
	// Add server tag.
	AddServerTag("zf");
	AddServerTag("szf");
	
	// Initialize global state
	g_bFirstRound = true;
	g_bSurvival = false;
	g_bNoMusic = false;
	g_bNoDirectorTanks = false;
	g_bNoDirectorRages = false;
	g_bDirectorSpawnTeleport = false;
	zf_bEnabled = false;
	zf_bNewRound = true;
	zf_lastSurvivor = false;
	setRoundState(RoundInit1);

	// Initialize timer handles
	zf_tMain = INVALID_HANDLE;
	zf_tMoraleDecay = INVALID_HANDLE;
	zf_tMainSlow = INVALID_HANDLE;
	zf_tMainFast = INVALID_HANDLE;
	zf_tHoarde = INVALID_HANDLE;

	// Initialize other packages
	utilBaseInit();

	mp_autoteambalance = FindConVar("mp_autoteambalance");
	mp_teams_unbalance_limit = FindConVar("mp_teams_unbalance_limit");
	mp_waitingforplayers_time = FindConVar("mp_waitingforplayers_time");
	tf_weapon_criticals = FindConVar("tf_weapon_criticals");
	tf_obj_upgrade_per_hit = FindConVar("tf_obj_upgrade_per_hit");
	tf_sentrygun_metal_per_shell = FindConVar("tf_sentrygun_metal_per_shell");
	tf_spy_invis_time = FindConVar("tf_spy_invis_time");
	tf_spy_invis_unstealth_time = FindConVar("tf_spy_invis_unstealth_time");
	tf_spy_cloak_no_attack_time = FindConVar("tf_spy_cloak_no_attack_time");
	
	// Register cvars
	CreateConVar("sm_szf_version", PLUGIN_VERSION, "Current Zombie Fortress Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	zf_cvForceOn = CreateConVar("sm_szf_force_on", "1", "<0/1> Activate ZF for non-ZF maps.", _, true, 0.0, true, 1.0);
	zf_cvRatio = CreateConVar("sm_szf_ratio", "0.78", "<0.01-1.00> Percentage of players that start as survivors.", _, true, 0.01, true, 1.0);
	zf_cvSwapOnPayload = CreateConVar("sm_szf_swaponpayload", "1", "<0/1> Swap teams on non-ZF payload maps.", _, true, 0.0, true, 1.0);
	zf_cvSwapOnAttdef = CreateConVar("sms_zf_swaponattdef", "1", "<0/1> Swap teams on non-ZF attack/defend maps.", _, true, 0.0, true, 1.0);
	zf_cvTankHealth = CreateConVar("sm_szf_tank_health", "400", "Amount of health the Tank gets per alive survivor", _, true, 10.0);
	zf_cvTankHealthMin = CreateConVar("sm_szf_tank_health_min", "1000", "Minimum amount of health the Tank can spawn with", _, true, 0.0);
	zf_cvTankHealthMax = CreateConVar("sm_szf_tank_health_max", "6000", "Maximum amount of health the Tank can spawn with", _, true, 0.0);
	zf_cvTankTime = CreateConVar("sm_szf_tank_time", "30.0", "Adjusts the damage the Tank takes per second. If the value is 70.0, the Tank will take damage that will make him die (if unhurt by survivors) after 70 seconds. 0 to disable.", _, true, 0.0);
	zf_cvFrenzyChance = CreateConVar("sm_szf_frenzy_chance", "0.0", "% Chance of a random frenzy", _, true, 0.0);
	zf_cvFrenzyTankChance = CreateConVar("sm_szf_frenzy_tank", "0.0", "% Chance of a Tank appearing instead of a frenzy", _, true, 0.0);

	// Hook events
	HookEvent("teamplay_round_start", event_RoundStart);
	HookEvent("teamplay_setup_finished", event_SetupEnd);
	HookEvent("teamplay_round_win", event_RoundEnd);
	//HookEvent("teamplay_timer_time_added", EventTimeAdded);
	HookEvent("player_spawn", event_PlayerSpawn);
	HookEvent("player_death", event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", event_PlayerHurt, EventHookMode_Pre);

	HookEvent("player_builtobject", event_PlayerBuiltObject);
	HookEvent("teamplay_point_captured", event_CPCapture);
	HookEvent("teamplay_point_startcapture", event_CPCaptureStart);

	HookEvent("teamplay_broadcast_audio", OnBroadCast, EventHookMode_Pre);

	// Hook Client Commands
	AddCommandListener(hook_JoinTeam, "jointeam");
	AddCommandListener(hook_JoinTeam, "spectate");
	AddCommandListener(hook_JoinTeam, "autoteam");
	AddCommandListener(hook_JoinClass, "joinclass");
	AddCommandListener(hook_VoiceMenu, "voicemenu");
	AddCommandListener(hook_Build, "build");

	RegServerCmd("szf_panic_event", Server_ZombieRage);
	RegServerCmd("szf_zombierage", Server_ZombieRage);

	RegServerCmd("szf_zombietank", Server_Tank);
	RegServerCmd("szf_tank", Server_Tank);

	// Hook Client Chat / Console Commands
	RegConsoleCmd("sm_zf", cmd_zfMenu);
	RegConsoleCmd("sm_szf", cmd_zfMenu);
	RegConsoleCmd("sm_music", MusicToggle);

	RegAdminCmd("sm_tank", Admin_ZombieTank, ADMFLAG_CHANGEMAP, "(Try to) call a tank.");
	RegAdminCmd("sm_rage", Admin_ZombieRage, ADMFLAG_CHANGEMAP, "(Try to) call a frenzy.");
	RegAdminCmd("sm_boomer", Admin_ForceBoomer, ADMFLAG_CHANGEMAP, "Become a boomer on next respawn.");
	RegAdminCmd("sm_charger", Admin_ForceCharger, ADMFLAG_CHANGEMAP, "Become a charger on next respawn.");
	RegAdminCmd("sm_kingpin", Admin_ForceScreamer, ADMFLAG_CHANGEMAP, "Become a screamer on next respawn.");
	RegAdminCmd("sm_stalker", Admin_ForcePredator, ADMFLAG_CHANGEMAP, "Become a predator on next respawn.");
	RegAdminCmd("sm_hunter", Admin_ForceHopper, ADMFLAG_CHANGEMAP, "Become a hunter on next respawn.");
	RegAdminCmd("sm_smoker", Admin_ForceSmoker, ADMFLAG_CHANGEMAP, "Become a smoker on next respawn.");
	
	AddNormalSoundHook(SoundHook);

	cookieFirstTimeZombie = RegClientCookie("szf_firsttimezombie", "is this the flowey map?", CookieAccess_Protected);
	cookieFirstTimeSurvivor = RegClientCookie("szf_firsttimesurvivor2", "is this the flowey map?", CookieAccess_Protected);
	cookieNoMusicForPlayer = RegClientCookie("szf_musicpreference", "is this the flowey map?", CookieAccess_Protected);
	cookieForceZombieStart = RegClientCookie("szf_forcezombiestart", "is this the flowey map?", CookieAccess_Protected);

	SDK_Init();
	
	Config_InitTemplates();
	Config_LoadTemplates();
	
	Weapons_Setup();
	
	//Incase of late-load
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public Action hook_Build(int client, const char[] command, int argc)
{
	if (!client) return Plugin_Continue;

	// Get arguments
	char sObjectMode[32];
	GetCmdArg(1, sObjectMode, sizeof(sObjectMode));

	int iObjectType = StringToInt(sObjectMode);

	// if not sentry or dispenser, then block building
	if (iObjectType != 0 && iObjectType != 2) return Plugin_Handled;

	return Plugin_Continue;
}

public Action Server_ZombieRage(int iArgs)
{
	char duration[256];

	GetCmdArgString(duration, sizeof(duration));
	float flDuration = StringToFloat(duration);

	ZombieRage(flDuration);

	return Plugin_Handled;
}

public Action Server_Tank(int iArgs)
{
	ZombieTank();
	return Plugin_Handled;
}

public Action Admin_ForceBoomer(int iClient, int iArgs)
{
	if (IsZombie(iClient))
	{
		g_iNextSpecialInfected[iClient] = INFECTED_BOOMER;
	}

	return Plugin_Handled;
}

public Action Admin_ForceCharger(int iClient, int iArgs)
{
	if (IsZombie(iClient))
	{
		g_iNextSpecialInfected[iClient] = INFECTED_CHARGER;
	}

	return Plugin_Handled;
}

public Action Admin_ForceScreamer(int iClient, int iArgs)
{
	if (IsZombie(iClient))
	{
		g_iNextSpecialInfected[iClient] = INFECTED_KINGPIN;
	}

	return Plugin_Handled;
}

public Action Admin_ForcePredator(int iClient, int iArgs)
{
	if (IsZombie(iClient))
	{
		g_iNextSpecialInfected[iClient] = INFECTED_STALKER;
	}

	return Plugin_Handled;
}

public Action Admin_ForceHopper(int iClient, int iArgs)
{
	if (IsZombie(iClient))
	{
		g_iNextSpecialInfected[iClient] = INFECTED_HUNTER;
	}

	return Plugin_Handled;
}

public Action Admin_ForceSmoker(int iClient, int iArgs)
{
	if (IsZombie(iClient))
	{
		g_iNextSpecialInfected[iClient] = INFECTED_SMOKER;
	}

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

public any Native_GetSurvivorTeam(Handle plugin, int numParams)
{
	return view_as<TFTeam>(zf_surTeam);
}

public any Native_GetZombieTeam(Handle plugin, int numParams)
{
	return view_as<TFTeam>(zf_zomTeam);
}

public any Native_GetLastSurvivor(Handle plugin, int numParams)
{
	if (!zf_lastSurvivor) return 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidLivingSurvivor(iClient))
			return iClient;
	
	return 0;
}

public any Native_GetWeaponPickupCount(Handle plugin, int numParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client %d", iClient);
	if (!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	
	return GetCookie(iClient, weaponsPicked);
}

public any Native_GetWeaponRarePickupCount(Handle plugin, int numParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client %d", iClient);
	if (!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	
	return GetCookie(iClient, weaponsRarePicked);
}

public any Native_GetWeaponCalloutCount(Handle plugin, int numParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client %d", iClient);
	if (!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	
	return GetCookie(iClient, weaponsCalled);
}

public void OnClientCookiesCached(int iClient)
{
	char cValue[8];
	int iValue;
	
	GetClientCookie(iClient, cookieNoMusicForPlayer, cValue, sizeof(cValue));
	iValue = StringToInt(cValue);
	g_bNoMusicForClient[iClient] = view_as<bool>(iValue);
	
	GetClientCookie(iClient, cookieForceZombieStart, cValue, sizeof(cValue));
	iValue = StringToInt(cValue);
	g_bForceZombieStart[iClient] = view_as<bool>(iValue);
}

public void OnConfigsExecuted()
{
	if (mapIsZF())
	{
		zfEnable();
		GetMapSettings();
	}
	else
	{
		GetConVarBool(zf_cvForceOn) ? zfEnable() : zfDisable();
	}
	
	setRoundState(RoundInit1);
}

public void OnMapEnd()
{
	// Close timer handles
	delete zf_tMain;
	delete zf_tMoraleDecay;
	delete zf_tMainSlow;
	delete zf_tMainFast;
	delete zf_tHoarde;
	
	setRoundState(RoundPost);
	g_bRoundActive = false;
	zfDisable();

	UnhookEntityOutput("logic_relay", "OnTrigger", OnRelayTrigger);
	UnhookEntityOutput("math_counter", "OutValue", OnCounterValue);
}

void GetMapSettings()
{
	int i = -1;
	char name[64];
	while ((i = FindEntityByClassname2(i, "info_target")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (strcmp(name, "szf_survivalmode", false) == 0) g_bSurvival = true;
		if (strcmp(name, "szf_nomusic", false) == 0) g_bNoMusic = true;
		if (strcmp(name, "szf_director_notank", false) == 0) g_bNoDirectorTanks = true;
		if (strcmp(name, "szf_director_norage", false) == 0) g_bNoDirectorRages = true;
		if (strcmp(name, "szf_director_spawnteleport", false) == 0) g_bDirectorSpawnTeleport = true;
	}
}

public void OnClientPutInServer(int client)
{
	CreateTimer(10.0, timer_initialHelp, client, TIMER_FLAG_NO_MAPCHANGE);

	DHookEntity(g_hHookGetMaxHealth, false, client);
	SDKHook(client, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	g_iDamage[client] = GetAverageDamage();
}

public void OnClientDisconnect(int client)
{
	if (!zf_bEnabled) return;
	
	RequestFrame(CheckZombieBypass, client);
	
	EndSound(client);
	DropCarryingItem(client);
	if (client == g_iZombieTank) g_iZombieTank = 0;
	
	if (g_bWaitingForTeamSwitch[client]) 
		g_bWaitingForTeamSwitch[client] = false;
	
	Weapons_ClientDisconnect(client);
}

public void OnGameFrame()
{
	if (!zf_bEnabled) return;
	handle_gameFrameLogic();
}

////////////////////////////////////////////////////////////
//
// SDKHooks Callbacks
//
////////////////////////////////////////////////////////////

public void OnPreThinkPost(int client)
{
	if (!zf_bEnabled) return;

	if (IsValidLivingClient(client))
	{
		//
		// Handle speed bonuses.
		//
		if ((!isSlowed(client) && !isDazed(client)) || g_bBackstabbed[client])
		{
			float speed = clientBaseSpeed(client) + clientBonusSpeed(client);
			TFClassType clientClass = TF2_GetPlayerClass(client);
			
			if (IsZombie(client))
			{
				// non-tanks: hoarde bonus to movement speed and ignite speed bonus
				if (g_iSpecialInfected[client] == INFECTED_NONE)
				{
					// movement speed increase
					switch(clientClass)
					{
						case TFClass_Scout: speed += fMin(20.0, 1.0 * zf_spawnZombiesKilledSpree) + fMin(20.0, 2.0 * zf_hordeBonus[client]);
						case TFClass_Heavy: speed += fMin(10.0, 0.8 * zf_spawnZombiesKilledSpree) + fMin(10.0, 1.2 * zf_hordeBonus[client]);
						case TFClass_Spy:   speed += fMin(20.0, 1.0 * zf_spawnZombiesKilledSpree) + fMin(20.0, 2.0 * zf_hordeBonus[client]);
					}

					if (g_bZombieRage) speed += 40.0; // map-wide zombie enrage event
					if (TF2_IsPlayerInCondition(client, TFCond_OnFire)) speed += 20.0; // on fire
					if (TF2_IsPlayerInCondition(client, TFCond_TeleportedGlow)) speed += 20.0; // kingpin effect
					if (GetClientHealth(client) > SDK_GetMaxHealth(client)) speed += 20.0; // has overheal due to normal rage

					// movement speed decrease
					if (TF2_IsPlayerInCondition(client, TFCond_Jarated)) speed -= 30.0; // jarate'd by sniper
					if (GetClientHealth(client) < 50) speed -= 50.0 - GetClientHealth(client); // if under 50 health, tick away one speed per hp lost
				}

				// tank: movement speed bonus based on damage taken and ignite speed bonus
				else if (g_iSpecialInfected[client] == INFECTED_TANK)
				{
					speed = 400.0;
					
					// reduce speed when tank deals damage to survivors 
					speed -= fMin(60.0, (float(g_iDamageDealtLife[client]) / 10.0));
					
					// reduce speed when tank takes damage from survivors 
					speed -= fMin(80.0, (float(g_iDamageTakenLife[client]) / 10.0));

					if (TF2_IsPlayerInCondition(client, TFCond_OnFire)) speed += 40.0; // on fire

					if (TF2_IsPlayerInCondition(client, TFCond_Jarated)) speed -= 30.0; // jarate'd by sniper
				}

				// charger: like in l4d, his charge is fucking fast so we also have it here, WEEEEEEE
				else if (g_iSpecialInfected[client] == INFECTED_CHARGER && isCharging(client))
				{
					speed = 1200.0; // original charge speed is 1000.0, will this black sorcery work?
				}

				// screamer: speed nerf
				else if (g_iSpecialInfected[client] == INFECTED_KINGPIN)
				{
					speed -= 100.0;
				}

				// hunter: speed buff
				else if (g_iSpecialInfected[client] == INFECTED_HUNTER)
				{
					speed += 40.0;
				}

				// predator: super speed if cloaked
				else if (g_iSpecialInfected[client] == INFECTED_STALKER && TF2_IsPlayerInCondition(client, TFCond_Cloaked))
				{
					speed += 120.0;
				}
			}


			if (IsSurvivor(client))
			{
				// if under 50 health, tick away one speed per hp lost
				if (GetClientHealth(client) < 50)
				{
					speed -= 50.0 - GetClientHealth(client);
				}

				if (isCharging(client))
				{
					speed = 600.0;
				}

				if (g_bBackstabbed[client])
				{
					speed *= 0.66;
				}
				
				// very very very dirty fix for eyelander head
				int iHeads = GetEntProp(client, Prop_Send, "m_iDecapitations");
				if (clientClass == TFClass_DemoMan && iHeads != g_iEyelanderHead[client])
				{
					SetEntProp(client, Prop_Send, "m_iDecapitations", g_iEyelanderHead[client]);
					
					//Recalculate player's speed
					TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
				}
			}

			setClientSpeed(client, speed);
		}

		//
		// Handle hunter-specific logic.
		//
		if (IsZombie(client) && g_iSpecialInfected[client] == INFECTED_HUNTER && g_bHopperIsUsingPounce[client])
		{
			if (GetEntityFlags(client) & FL_ONGROUND == FL_ONGROUND)
			{
				g_bHopperIsUsingPounce[client] = false;
			}
		}

	}

	UpdateClientCarrying(client);
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflicter, float &fDamage, int &iDamagetype, int &iWeapon, float fForce[3], float fForcePos[3], int iDamageCustom)
{
	if (!zf_bEnabled) return Plugin_Continue;
	if (!CanRecieveDamage(iVictim)) return Plugin_Continue;

	bool bChanged = false;
	if (IsValidClient(iVictim) && IsValidClient(iAttacker))
	{
		g_bHitOnce[iVictim] = true;
		g_bHitOnce[iAttacker] = true;
		if (GetClientTeam(iVictim) != GetClientTeam(iAttacker))
		{
			EndGracePeriod();
		}
	}
	
	// disable fall damage to tank
	if (g_iSpecialInfected[iVictim] == INFECTED_TANK && iDamagetype & DMG_FALL)
	{
		fDamage = 0.0;
		bChanged = true;
	}
	
	if (iVictim != iAttacker)
	{
		if (IsValidLivingClient(iAttacker) && fDamage < 300.0)
		{
			// Damage scaling Zombies
			if (IsValidZombie(iAttacker))
			{
				fDamage = fDamage * g_fZombieDamageScale * 0.7; // default: 0.7
			}
			// Damage scaling Survivors
			if (IsValidSurvivor(iAttacker) && !entIsSentry(iInflicter))
			{
				float flMoraleBonus = fMin(GetMorale(iAttacker) * 0.005, 0.25); // 50 morale: 0.25
				fDamage = fDamage / g_fZombieDamageScale * (1.1 + flMoraleBonus); // default: 1.1
			}
			// If backstabbed
			if (g_bBackstabbed[iVictim])
			{
				if (fDamage > STUNNED_DAMAGE_CAP)
					fDamage = STUNNED_DAMAGE_CAP;
					
				iDamagetype &= ~DMG_CRIT;
				iDamageCustom = 0;
			}

			bChanged = true;
		}

		if (IsValidSurvivor(iVictim) && IsValidZombie(iAttacker))
		{
			SoundAttack(iVictim, iAttacker);
			
			if (TF2_GetPlayerClass(iVictim) == TFClass_Scout)
			{
				fDamage *= 0.825;
				bChanged = true;
			}

			if (TF2_IsPlayerInCondition(iAttacker, TFCond_CritCola)
				|| TF2_IsPlayerInCondition(iAttacker, TFCond_Buffed)
				|| TF2_IsPlayerInCondition(iAttacker, TFCond_CritHype))
			{
				// reduce damage from crit amplifying items when active
				fDamage *= 0.85;
				bChanged = true;
			}

			// taunt, backstabs and highly critical damage
			if (iDamageCustom == TF_CUSTOM_TAUNT_HIGH_NOON
				|| iDamageCustom == TF_CUSTOM_TAUNT_GRAND_SLAM
				|| iDamageCustom == TF_CUSTOM_BACKSTAB
				|| fDamage >= SDK_GetMaxHealth(iVictim) - 20)
			{
				if (!g_bBackstabbed[iVictim])
				{
					if (IsRazorbackActive(iVictim)) return Plugin_Continue;

					if (g_iSpecialInfected[iAttacker] == INFECTED_STALKER)
					{
						SetEntityHealth(iVictim, GetClientHealth(iVictim) - 50);
					}
					else
					{
						SetEntityHealth(iVictim, GetClientHealth(iVictim) - 20);
					}

					AddMorale(iVictim, -5);
					SetBackstabState(iVictim, BACKSTABDURATION_FULL, 0.25);
					SetNextAttack(iAttacker, GetGameTime() + 1.25);
					
					Call_StartForward(g_hForwardBackstab);
					Call_PushCell(iVictim);
					Call_PushCell(iAttacker);
					Call_Finish();
					
					fDamage = 1.0;
					bChanged = true;
				}

				else
				{
					fDamage = STUNNED_DAMAGE_CAP;
					iDamageCustom = 0;
					bChanged = true;
				}
			}

			if (g_iSpecialInfected[iAttacker] == INFECTED_TANK)
			{
				EmitSoundToAll(g_strZombieVO_Tank_Attack[GetRandomInt(0, sizeof(g_strZombieVO_Tank_Attack) - 1)], iAttacker, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
		}

		if (IsValidZombie(iVictim))
		{
			// cap damage to 150, zero down physics force, disable physics force
			if (TF2_GetPlayerClass(iVictim) == TFClass_Heavy)
			{
				if (fDamage > 150.0 && fDamage <= 500.0) fDamage = 150.0;
				ScaleVector(fForce, 0.0);
				iDamagetype |= DMG_PREVENT_PHYSICS_FORCE;
				bChanged = true;
			}

			// disable physics force
			if (entIsSentry(iInflicter))
			{
				iDamagetype |= DMG_PREVENT_PHYSICS_FORCE;
			}
			
			if (IsValidSurvivor(iAttacker))
			{
				// kingpin takes 33% less damage from attacks
				if (g_iSpecialInfected[iVictim] == INFECTED_KINGPIN)
				{
					fDamage *= 0.66;
					bChanged = true;
				}

				else if (g_iSpecialInfected[iVictim] == INFECTED_TANK)
				{
					// "SHOOT THAT TANK" voice call
					if (g_fDamageDealtAgainstTank[iAttacker] == 0)
					{
						// VOCALS ARE PRECACHED IN PICKUPWEAPONS.SP
						if (TF2_GetPlayerClass(iAttacker) == TFClass_Soldier)
						{
							int iRandom = GetRandomInt(0, sizeof(g_strTankATK_Soldier)-1);
							EmitSoundToAll(g_strTankATK_Soldier[iRandom], iAttacker, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
						}

						if (TF2_GetPlayerClass(iAttacker) == TFClass_Engineer)
						{
							int iRandom = GetRandomInt(0, sizeof(g_strTankATK_Engineer)-1);
							EmitSoundToAll(g_strTankATK_Engineer[iRandom], iAttacker, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
						}

						if (TF2_GetPlayerClass(iAttacker) == TFClass_Medic)
						{
							int iRandom = GetRandomInt(0, sizeof(g_strTankATK_Medic)-1);
							EmitSoundToAll(g_strTankATK_Medic[iRandom], iAttacker, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
						}
					}

					g_fDamageDealtAgainstTank[iAttacker] += fDamage;
					ScaleVector(fForce, 0.0);
					iDamagetype |= DMG_PREVENT_PHYSICS_FORCE;
				}

				else if (TF2_IsPlayerInCondition(iVictim, TFCond_CritCola)
					|| TF2_IsPlayerInCondition(iVictim, TFCond_Buffed)
					|| TF2_IsPlayerInCondition(iVictim, TFCond_CritHype))
				{
					// increase damage taken from crit amplifying items when active
					fDamage *= 1.1;
					bChanged = true;
				}
			}
		}
		
		// Check if tank takes damage from map deathpit, if so kill him
		if (g_iSpecialInfected[iVictim] == INFECTED_TANK && MaxClients < iAttacker)
		{
			char strAttacker[32];
			GetEdictClassname(iAttacker, strAttacker, sizeof(strAttacker));
			if (strcmp(strAttacker, "trigger_hurt") == 0 && fDamage >= 450.0)
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
public Action hook_JoinTeam(int client, const char[] command, int argc)
{
	char cmd1[32];
	char sSurTeam[16];
	char sZomTeam[16];
	char sZomVgui[16];

	if (!zf_bEnabled) return Plugin_Continue;
	if (argc < 1 && StrEqual(command, "jointeam", false)) return Plugin_Handled;
	if (roundState() < RoundGrace) return Plugin_Continue;
	if (!IsClientInGame(client)) return Plugin_Continue;
	
	//Get command/arg on which team player joined
	if (StrEqual(command, "jointeam", false)) // this is done because "jointeam spectate" should take priority over "spectate"
		GetCmdArg(1, cmd1, sizeof(cmd1));
	else if (StrEqual(command, "spectate", false))
		strcopy(cmd1, sizeof(cmd1), "spectate");	
	else if (StrEqual(command, "autoteam", false))
		strcopy(cmd1, sizeof(cmd1), "autoteam");		
	
	//Check if client is trying to skip playing as zombie by joining spectator
	if (StrEqual(cmd1, "spectate", false))
		CheckZombieBypass(client);
			
	// Assign team-specific strings
	if (zomTeam() == INT(TFTeam_Blue))
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

	if (roundState() == RoundGrace)
	{
		int iTeam = GetClientTeam(client);
	
		// If a client tries to join the infected team or a random team during grace period...
		if (StrEqual(cmd1, sZomTeam, false) || StrEqual(cmd1, "auto", false) || StrEqual(cmd1, "autoteam", false))
		{
			// ...as survivor, don't let them.
			if (iTeam == surTeam())
			{
				CPrintToChat(client, "{red}You can not switch to the opposing team during grace period.");
				return Plugin_Handled;
			}
			// ...as a spectator who didn't start as an infected, set them as infected after grace period ends, after warning them.
			if (iTeam <= 1 && !g_bStartedAsZombie[client])
			{
				if (!g_bWaitingForTeamSwitch[client])
				{
					if (iTeam == INT(TFTeam_Unassigned)) // If they're unassigned, let them spectate for now.
						ChangeClientTeam(client, INT(TFTeam_Spectator));
						
					CPrintToChat(client, "{red}You will join the Infected team when grace period ends.");
					g_bWaitingForTeamSwitch[client] = true;
				}
				return Plugin_Handled;
			}	
		}
		// If client tries to spectate during grace period, make them
		// not be booted into the infected team if they tried to join
		// it before.
		else if (StrEqual(cmd1, "spectate", false))
		{
			if (iTeam <= 1 && g_bWaitingForTeamSwitch[client])
			{					
				CPrintToChat(client, "{green}You will no longer automatically join the Infected team when grace period ends.");
				g_bWaitingForTeamSwitch[client] = false;
			}
			return Plugin_Continue;
		}
		
		// If client tries to join the survivor team during grace period, 
		// deny and set them as infected instead.
		else if (StrEqual(cmd1, sSurTeam, false))
		{
			if (iTeam <= 1 && !g_bWaitingForTeamSwitch[client])
			{
				// However, if they started as infected, they can spawn as infected again, normally.
				if (g_bStartedAsZombie[client])
				{
					ChangeClientTeam(client, zomTeam());
					ShowVGUIPanel(client, sZomVgui);
				}
				else
				{
					if (iTeam == INT(TFTeam_Unassigned)) // If they're unassigned, let them spectate for now.
						ChangeClientTeam(client, INT(TFTeam_Spectator));
						
					CPrintToChat(client, "{red}Can not join the Survivor team at this time. You will join the Infected team when grace period ends.");
					g_bWaitingForTeamSwitch[client] = true;
				}
			}
			return Plugin_Handled;
		}
		
		// Prevent joining any other team.
		else
			return Plugin_Handled;
	}
	
	else if (roundState() > RoundGrace)
	{
		// If client tries to join the survivor team or a random team
		// during an active round, place them on the zombie
		// team and present them with the zombie class select screen.
		if (StrEqual(cmd1, sSurTeam, false) || StrEqual(cmd1, "auto", false))
		{
			ChangeClientTeam(client, zomTeam());
			ShowVGUIPanel(client, sZomVgui);
			return Plugin_Handled;
		}
		
		// If client tries to join the zombie team or spectator
		// during an active round, let them do so.
		else if (StrEqual(cmd1, sZomTeam, false) || StrEqual(cmd1, "spectate", false))
			return Plugin_Continue;
		
		// Prevent joining any other team.
		else
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action hook_JoinClass(int client, const char[] command, int argc)
{
	char cmd1[32];

	if (!zf_bEnabled) return Plugin_Continue;
	if (argc < 1) return Plugin_Handled;

	GetCmdArg(1, cmd1, sizeof(cmd1));

	if (IsZombie(client))
	{
		// If an invalid zombie class is selected, print a message and
		// accept joinclass command. ZF spawn logic will correct this
		// issue when the player spawns.
		if (!(StrEqual(cmd1, "scout", false) || StrEqual(cmd1, "spy", false)    ||  StrEqual(cmd1, "heavyweapons", false)))
		{
			CPrintToChat(client, "{red}Valid zombies: Scout, Heavy and Spy");
		}
	}

	else if (IsSurvivor(client))
	{
		// Prevent survivors from switching classes during the round.
		if (roundState() == RoundActive)
		{
			CPrintToChat(client, "{red}Survivors can't change classes during a round.");
			return Plugin_Handled;
		}
		// If an invalid survivor class is selected, print a message
		// and accept the joincalss command. ZF spawn logic will
		// correct this issue when the player spawns.
		else if (!(StrEqual(cmd1, "soldier", false) ||
			StrEqual(cmd1, "pyro", false) ||
			StrEqual(cmd1, "demoman", false) ||
			StrEqual(cmd1, "engineer", false) ||
			StrEqual(cmd1, "medic", false) ||
			StrEqual(cmd1, "sniper", false)))
		{
			CPrintToChat(client, "{red}Valid survivors: Soldier, Pyro, Demo, Engineer, Medic and Sniper.");
		}
	}

	return Plugin_Continue;
}

public Action hook_VoiceMenu(int client, const char[] command, int argc)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	char cmd1[32];
	char cmd2[32];

	if (!zf_bEnabled) return Plugin_Continue;
	if (argc < 2) return Plugin_Handled;

	GetCmdArg(1, cmd1, sizeof(cmd1));
	GetCmdArg(2, cmd2, sizeof(cmd2));

	// Capture call for medic commands (represented by "voicemenu 0 0").
	// Activate zombie Rage ability (150% health), if possible. Rage
	// can't be activated below full health or if it's already active.
	// Rage recharges after 30 seconds.
	if (StrEqual(cmd1, "0") && StrEqual(cmd2, "0"))
	{
		if (IsSurvivor(client) && AttemptCarryItem(client))
		{
			return Plugin_Handled;
		}

		// no need to else if since above will end the code execution if carry is succesful
		if (IsZombie(client) && !TF2_IsPlayerInCondition(client, TFCond_Taunting))
		{
			if (g_bRoundActive && g_bSpawnAsSpecialInfected[client] && g_bReplaceRageWithSpecialInfectedSpawn[client])
			{
				TF2_RespawnPlayer(client);
				
				Call_StartForward(g_hForwardQuickSpawnAsSpecialInfected);
				Call_PushCell(client);
				Call_Finish();
				
				// broadcast to team
				char strName[255];
				char strMessage[255];
				GetClientName2(client, strName, sizeof(strName));
				
				Format(strMessage, sizeof(strMessage), "(TEAM) %s\x01 : I have used my {limegreen}quick respawn into special infected\x01!", strName);
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i) && GetClientTeam(i) == GetClientTeam(client))
					{
						CPrintToChatEx(i, client, strMessage);
					}
				}
			}

			else if (zf_rageTimer[client] == 0)
			{
				if (g_iSpecialInfected[client] == INFECTED_NONE)
				{
					zf_rageTimer[client] = 31;
					DoGenericRage(client);
					
					EmitSoundToAll(g_strZombieVO_Common_Rage[GetRandomInt(0, sizeof(g_strZombieVO_Common_Rage) - 1)], client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}
				if (g_iSpecialInfected[client] == INFECTED_BOOMER && g_bRoundActive)
				{
					DoBoomerExplosion(client, 600.0);

					EmitSoundToAll(g_strZombieVO_Boomer_Explode[GetRandomInt(0, sizeof(g_strZombieVO_Boomer_Explode) - 1)], client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}

				if (g_iSpecialInfected[client] == INFECTED_CHARGER)
				{
					zf_rageTimer[client] = 16;
					TF2_AddCondition(client, TFCond_Charging, 1.65);
					
					float vecVel[3], vecAngles[3];
					GetClientEyeAngles(client, vecAngles);
					vecVel[0] = 450.0 * Cosine(DegToRad(vecAngles[1]));
					vecVel[1] = 450.0 * Sine(DegToRad(vecAngles[1]));
					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVel);
					
					EmitSoundToAll(g_strZombieVO_Charger_Charge[GetRandomInt(0, sizeof(g_strZombieVO_Charger_Charge) - 1)], client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}

				if (g_iSpecialInfected[client] == INFECTED_KINGPIN)
				{
					zf_rageTimer[client] = 21;
					DoKingpinRage(client, 600.0);

					char strPath[64];
					Format(strPath, sizeof(strPath), "ambient/halloween/male_scream_%i.wav", GetRandomInt(15, 16));
					EmitSoundToAll(strPath, client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}

				if (g_iSpecialInfected[client] == INFECTED_HUNTER)
				{
					zf_rageTimer[client] = 3;
					DoHunterJump(client);

					EmitSoundToAll(g_strZombieVO_Hunter_Leap[GetRandomInt(0, sizeof(g_strZombieVO_Hunter_Leap) - 1)], client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}
			}

			else
			{
				ClientCommand(client, "voicemenu 2 5");
				PrintHintText(client, "Can't Activate Rage!");
			}

			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action cmd_zfMenu(int iClient, int iArgs)
{
	if (!zf_bEnabled) return Plugin_Continue;
	panel_PrintMain(iClient);

	return Plugin_Handled;
}

//
// Round Start Event
//
public Action event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;

	DetermineControlPoints();

	zf_lastSurvivor = false;

	int players[MAXPLAYERS+1] = -1;
	int playerCount;
	int surCount;

	//g_StartTime = GetTime();
	//g_AdditionalTime = 0;

	int i;
	for (i = 1; i <= MaxClients; i++)
	{
		g_iDamage[i] = 0;
		g_iKillsThisLife[i] = 0;
		g_bSpawnAsSpecialInfected[i] = false;
		g_iSpecialInfected[i] = INFECTED_NONE;
		g_iNextSpecialInfected[i] = INFECTED_NONE;
		g_bReplaceRageWithSpecialInfectedSpawn[i] = false;
		g_iEyelanderHead[i] = 0;
		g_iMaxHealth[i] = -1;
		g_iSuperHealthSubtract[i] = 0;
		g_flTimeStartAsZombie[i] = 0.0;
	}
	
	for (i = 0; i <= INFECTED_MAX; i++)
	{
		g_flInfectedCooldown[i] = 0.0;
		g_iInfectedCooldown[i] = 0;
	}
	
	g_iZombieTank = 0;
	RemoveAllGoo();

	//
	// Handle round state.
	// + "teamplay_round_start" event is fired twice on new map loads.
	//
	if (roundState() == RoundInit1)
	{
		setRoundState(RoundInit2);
		return Plugin_Continue;
	}
	else
	{
		setRoundState(RoundGrace);
		CPrintToChatAll("{green}Grace period begun. Survivors can change classes.");
	}

	//
	// Assign players to zombie and survivor teams.
	//
	if (zf_bNewRound)
	{
		// Find all active players.
		playerCount = 0;
		for(i = 1; i <= MaxClients; i++)
		{
			zf_spawnZombiesKilledSurvivor[i] = 0;
			EndSound(i);

			if (IsClientInGame(i) && GetClientTeam(i) > 1)
			{
				players[playerCount] = i;
				playerCount++;
			}
		}

		// Randomize, sort players
		SortIntegers(players, playerCount, Sort_Random);
		// NOTE: As of SM 1.3.1, SortIntegers w/ Sort_Random doesn't
		//             sort the first element of the array. Temp fix below.
		int idx = GetRandomInt(0,playerCount-1);
		int temp = players[idx];
		players[idx] = players[0];
		players[0] = temp;

		// Calculate team counts. At least one survivor must exist.
		surCount = RoundToFloor(playerCount*GetConVarFloat(zf_cvRatio));
		if (surCount == 0 && playerCount > 0)
		{
			surCount = 1;
		}
		
		int iClientTeam[MAXPLAYERS+1] = 0;
		g_iStartSurvivors = 0;
		
		// Check if we need to force players to survivor or zombie team
		for (i = 0; i < playerCount; i++)
		{
			int iClient = players[i];
			
			if (IsValidClient(iClient))
			{
				Action action = Plugin_Continue;
				Call_StartForward(g_hForwardStartZombie);
				Call_PushCell(iClient);
				Call_Finish(action);
				
				if (action == Plugin_Handled)
				{
					//Zombie
					SpawnClient(iClient, zomTeam());
					iClientTeam[iClient] = zomTeam();
					g_bStartedAsZombie[iClient] = true;
					g_flTimeStartAsZombie[iClient] = GetGameTime();
				}
				else if (g_bForceZombieStart[iClient] && !g_bFirstRound)
				{
					//If they attempted to skip playing as zombie last time, force him to be in zombie team
					CPrintToChat(iClient, "{red}You have been forcibly set to infected team due to attempting to skip playing as a infected.");
					g_bForceZombieStart[iClient] = false;
					SetClientCookie(iClient, cookieForceZombieStart, "0");
					
					//Zombie
					SpawnClient(iClient, zomTeam());
					iClientTeam[iClient] = zomTeam();
					g_bStartedAsZombie[iClient] = true;
					g_flTimeStartAsZombie[iClient] = GetGameTime();
				}
				else if (g_bStartedAsZombie[iClient])
				{
					//Players who started as zombie last time is forced to be survivors
					
					//Survivor
					SpawnClient(iClient, surTeam());
					iClientTeam[iClient] = surTeam();
					g_bStartedAsZombie[iClient] = false;
					g_iStartSurvivors++;
					surCount--;
				}
			}
		}
		
		// From SortIntegers, we set the rest to survivors, then zombies
		for (i = 0; i < playerCount; i++)
		{
			int iClient = players[i];
			
			//Check if they have not already been assigned
			if (IsValidClient(iClient) && !(iClientTeam[iClient] == zomTeam()) && !(iClientTeam[iClient] == surTeam()))
			{
				if (surCount > 0)
				{
					//Survivor
					SpawnClient(iClient, surTeam());
					iClientTeam[iClient] = surTeam();
					g_bStartedAsZombie[iClient] = false;
					g_iStartSurvivors++;
					surCount--;
				}
				else
				{
					//Zombie
					SpawnClient(iClient, zomTeam());
					iClientTeam[iClient] = zomTeam();
					g_bStartedAsZombie[iClient] = true;
					g_flTimeStartAsZombie[iClient] = GetGameTime();
				}
			}
		}
	}

	// Reset counters
	g_flCapScale = -1.0;
	zf_spawnSurvivorsLastDeath = GetGameTime();
	zf_spawnSurvivorsKilledCounter = 0;
	zf_spawnZombiesKilledCounter = 0;
	zf_spawnZombiesKilledSpree = 0;

	g_fTimeProgress = 0.0;
	zf_tTimeProgress = null;

	// Handle grace period timers.
	CreateTimer(0.5, timer_graceStartPost, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(45.0, timer_graceEnd, TIMER_FLAG_NO_MAPCHANGE);

	SetGlow();
	UpdateZombieDamageScale();

	return Plugin_Continue;
}

//
// Setup End Event
//
public Action event_SetupEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;

	EndGracePeriod();

	//g_StartTime = GetTime();
	//g_AdditionalTime = 0;
	g_bRoundActive = true;

	return Plugin_Continue;
}

void EndGracePeriod()
{
	if (!zf_bEnabled) return;

	if (roundState() == RoundActive) return;
	if (roundState() == RoundPost) return;

	setRoundState(RoundActive);
	CPrintToChatAll("{orange}Grace period complete. Survivors can no longer change classes.");

	int iSurvivors = GetSurvivorCount();
	int iZombies = GetZombieCount();

	//If less than 15% of players are infected, set round start as imbalanced
	bool bImbalanced = (float(iZombies) / float(iSurvivors + iZombies) <= 0.15);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (g_bWaitingForTeamSwitch[i])
				RequestFrame(Frame_PostGracePeriodSpawn, i); // A frame later so maps which have post-setup spawn points can adapt to these players
		
			// Give a buff to infected if the round is imbalanced
			if (bImbalanced)
			{
				if (IsZombie(i) && IsPlayerAlive(i))
				{
					SetEntityHealth(i, 450);
					//TF2_AddCondition(i, TFCond_DefenseBuffed, -1.0);
					g_bSpawnAsSpecialInfected[i] = true;
				}
				CPrintToChat(i, "%sInfected have received extra health and other benefits to ensure game balance at the start of the round.", (IsZombie(i)) ? "{green}" : "{red}");
			}
		}
	}

	g_fTimeProgress = 0.0;
	zf_tTimeProgress = CreateTimer(6.0, timer_progress, _, TIMER_REPEAT);

	g_bFirstRound = false;
	g_flTankCooldown = GetGameTime() + 120.0 - fMin(0.0, (iSurvivors-12) * 3.0); // 2 min cooldown before tank spawns will be considered
	g_flSelectSpecialCooldown = GetGameTime() + 120.0 - fMin(0.0, (iSurvivors-12) * 3.0); // 2 min cooldown before select special will be considered
	g_flRageCooldown = GetGameTime() + 60.0 - fMin(0.0, (iSurvivors-12) * 1.5); // 1 min cooldown before frenzy will be considered
	zf_spawnSurvivorsLastDeath = GetGameTime();
}

public void Frame_PostGracePeriodSpawn(int iClient)
{
	ChangeClientTeam(iClient, zomTeam());
	
	if (!IsPlayerAlive(iClient))
	{
		if (zomTeam() == INT(TFTeam_Blue))
			ShowVGUIPanel(iClient, "class_blue");
		else
			ShowVGUIPanel(iClient, "class_red");
	}
						
	g_bWaitingForTeamSwitch[iClient] = false;
}

//
// Round End Event
//
public Action event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;

	//
	// Prepare for a completely new round, if
	// + Round was a full round (full_round flag is set), OR
	// + Zombies are the winning team.
	//
	zf_bNewRound = GetEventBool(event, "full_round") || (event.GetInt("team") == zomTeam());
	setRoundState(RoundPost);
	
	if (event.GetInt("team") == zomTeam()) 
		PlaySoundAll(SOUND_MUSIC_ZOMBIEWIN);
	
	else if (event.GetInt("team") == surTeam())
		PlaySoundAll(SOUND_MUSIC_SURVIVORWIN);
	
	SetGlow();
	UpdateZombieDamageScale();
	g_bRoundActive = false;
	g_bTankRefreshed = false;

	return Plugin_Continue;
}

//
// Player Spawn Event
//
public Action event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	// reset overlay
	ClientCommand(client, "r_screenoverlay\"\"");

	if (g_iMaxHealth[client] != -1)
	{
		//Make sure max health hook is reset properly
		g_iMaxHealth[client] = -1;
		TF2_RespawnPlayer(client);
		return Plugin_Stop;
	}

	g_iEyelanderHead[client] = 0;
	g_iSuperHealthSubtract[client] = 0;
	g_bHitOnce[client] = false;
	g_bHopperIsUsingPounce[client] = false;
	g_bBackstabbed[client] = false;
	g_iKillsThisLife[client] = 0;
	g_iDamageTakenLife[client] = 0;
	g_iDamageDealtLife[client] = 0;

	DropCarryingItem(client, false);

	SetEntityRenderColor(client, 255, 255, 255, 255);
	SetEntityRenderMode(client, RENDER_NORMAL);

	if (roundState() == RoundActive)
	{
		if (g_iZombieTank > 0 && g_iZombieTank == client)
		{
			g_iSpecialInfected[client] = INFECTED_NONE;

			if (TF2_GetPlayerClass(client) != TFClass_Heavy)
			{
				TF2_SetPlayerClass(client, TFClass_Heavy, true, true);
				TF2_RespawnPlayer(client);
				return Plugin_Stop;
			}
			else
			{
				g_iZombieTank = 0;
				g_iSpecialInfected[client] = INFECTED_TANK;
				g_flTankLifetime[client] = GetGameTime();

				int iSurvivors = GetSurvivorCount();
				int iHealth = GetConVarInt(zf_cvTankHealth) * iSurvivors;
				if (iHealth < GetConVarInt(zf_cvTankHealthMin)) iHealth = GetConVarInt(zf_cvTankHealthMin);
				if (iHealth > GetConVarInt(zf_cvTankHealthMax)) iHealth = GetConVarInt(zf_cvTankHealthMax);
				
				g_iMaxHealth[client] = iHealth;
				SetEntityHealth(client, iHealth);
				
				int iSubtract = 0;
				if (GetConVarFloat(zf_cvTankTime) > 0.0)
				{
					iSubtract = RoundFloat(float(iHealth) / GetConVarFloat(zf_cvTankTime));
					if (iSubtract < 3) iSubtract = 3;
				}

				g_iSuperHealthSubtract[client] = iSubtract;
				TF2_AddCondition(client, TFCond_Kritzkrieged, 999.0);

				SetEntityRenderMode(client, RENDER_TRANSCOLOR);
				SetEntityRenderColor(client, 0, 255, 0, 255);
				//PerformFastRespawn2(client);
				
				EmitSoundToAll(g_strZombieVO_Tank_OnFire[GetRandomInt(0, sizeof(g_strZombieVO_Tank_OnFire) - 1)]);
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						if (GetCookie(i, cookieFirstTimeSurvivor) < 2)
						{
							DataPack hPack1 = new DataPack();
							CreateDataTimer(0.5, DisplayTutorialMessage, hPack1);
							hPack1.WriteCell(i);
							hPack1.WriteFloat(4.0);
							hPack1.WriteString("Do not let the Tank get close to you, his attacks are very lethal.");

							DataPack hPack2 = new DataPack();
							CreateDataTimer(4.5, DisplayTutorialMessage, hPack2);
							hPack2.WriteCell(i);
							hPack2.WriteFloat(4.0);
							hPack2.WriteString("Run and shoot the Tank, it will slow the Tank down and kill it.");

							SetCookie(i, 2, cookieFirstTimeSurvivor);
						}

						CPrintToChat(i, "{red}Incoming TAAAAANK!");
						
						if (GetCurrentSound(i) != SOUND_MUSIC_LASTSTAND || !IsMusicOverrideOn()) // lms current sound check seems not to work, may need to check it later
						{
							PlaySound(i, SOUND_MUSIC_TANK);	
						}
					}

					g_fDamageDealtAgainstTank[i] = 0.0;
				}
				
				Call_StartForward(g_hForwardTankSpawn);
				Call_PushCell(client);
				Call_Finish();
			}
		}

		else
		{			
			//If client got a force set as specific special infected, set as that infected
			if (g_iNextSpecialInfected[client] != INFECTED_NONE && g_iSpecialInfected[client] != INFECTED_TANK)
			{
				g_iSpecialInfected[client] = g_iNextSpecialInfected[client];
			}
			else if (g_bSpawnAsSpecialInfected[client] == true)
			{
				g_bSpawnAsSpecialInfected[client] = false;
				
				//Create list of all special infected to randomize, apart from tank and non-special infected
				int iSpecialInfected[INFECTED_MAX-1];
				for (int i = 0; i < sizeof(iSpecialInfected); i++)
					iSpecialInfected[i] = i + 2;
				
				// Randomize, sort list of special infected
				SortIntegers(iSpecialInfected, sizeof(iSpecialInfected), Sort_Random);
				
				//Go through each special infected in the list and find the first one thats not in cooldown
				int i = 0;
				while (g_iSpecialInfected[client] == INFECTED_NONE && i < sizeof(iSpecialInfected))
				{
					if (g_flInfectedCooldown[iSpecialInfected[i]] <= GetGameTime() - 12.0 && g_iInfectedCooldown[iSpecialInfected[i]] != client)
					{
						//We found it, set as that special infected
						g_iSpecialInfected[client] = iSpecialInfected[i];
					}
					
					i++;
				}
				
				//Check if player spawned using fast respawn
				if (g_bReplaceRageWithSpecialInfectedSpawn[client])
				{
					//Check if they did not become special infected because all is in cooldown
					if (g_iSpecialInfected[client] == INFECTED_NONE)
						CPrintToChat(client, "{red}All special infected seems to be in a cooldown...");
					
					g_bReplaceRageWithSpecialInfectedSpawn[client] = false;
				}
			}
						
			if (g_iSpecialInfected[client] != INFECTED_NONE && g_iSpecialInfected[client] != INFECTED_TANK && g_iInfectedCooldown[g_iSpecialInfected[client]] != client)
			{
				//Set new cooldown
				g_flInfectedCooldown[g_iSpecialInfected[client]] = GetGameTime();	//time for cooldown
				g_iInfectedCooldown[g_iSpecialInfected[client]] = client;			//client to prevent abuse to cycle through any infected
			}
			
			if (g_iSpecialInfected[client] == INFECTED_BOOMER
				|| g_iSpecialInfected[client] == INFECTED_CHARGER)
			{
				if (TF2_GetPlayerClass(client) != TFClass_Heavy)
				{
					TF2_SetPlayerClass(client, TFClass_Heavy, true, true);
					TF2_RespawnPlayer(client);
					return Plugin_Stop;
				}

				SetEntityRenderMode(client, RENDER_TRANSCOLOR);
				// boomer
				if (g_iSpecialInfected[client] == INFECTED_BOOMER)
				{
					SetEntityRenderColor(client, 255, 255, 0, 255);
					CPrintToChat(client, "{green}YOU ARE A BOOMER:\n{orange}- Call 'MEDIC!' to EXPLODE and JARATE nearby enemies!\n- You also explode upon dying, coating the killer and assister in JARATE.");
				}
				// charger
				if (g_iSpecialInfected[client] == INFECTED_CHARGER)
				{
					SetEntityRenderColor(client, 255, 0, 0, 255);
					CPrintToChat(client, "{green}YOU ARE A CHARGER:\n{orange}- Call 'MEDIC!' to CHARGE! {yellow}(16 second cooldown)");
				}
			}


			if (g_iSpecialInfected[client] == INFECTED_KINGPIN
				|| g_iSpecialInfected[client] == INFECTED_HUNTER)
			{
				if (TF2_GetPlayerClass(client) != TFClass_Scout)
				{
					TF2_SetPlayerClass(client, TFClass_Scout, true, true);
					TF2_RespawnPlayer(client);
					return Plugin_Stop;
				}

				SetEntityRenderMode(client, RENDER_TRANSCOLOR);
				// hunter
				if (g_iSpecialInfected[client] == INFECTED_HUNTER)
				{
					SetEntityRenderColor(client, 255, 0, 0, 255);
					CPrintToChat(client, "{green}YOU ARE A HUNTER:\n{orange}- Call 'MEDIC!' to LEAP and POUNCE ENEMY SURVIVORS! {yellow}(3 on miss & 21 on hit second cooldown)");
				}
				// kingpin
				if (g_iSpecialInfected[client] == INFECTED_KINGPIN)
				{
					SetEntityRenderColor(client, 150, 0, 255, 255);
					CPrintToChat(client, "{green}YOU ARE A KINGPIN:\n{orange}- Call 'MEDIC!' to RALLY ALLIED ZOMBIES! {yellow}(21 second cooldown){orange}\n- Zombies standing near you are more powerful.");
				}
			}

			if (g_iSpecialInfected[client] == INFECTED_STALKER
				|| g_iSpecialInfected[client] == INFECTED_SMOKER)
			{
				if (TF2_GetPlayerClass(client) != TFClass_Spy)
				{
					TF2_SetPlayerClass(client, TFClass_Spy, true, true);
					TF2_RespawnPlayer(client);
					return Plugin_Stop;
				}

				SetEntityRenderMode(client, RENDER_TRANSCOLOR);
				// stalker
				if (g_iSpecialInfected[client] == INFECTED_STALKER)
				{
					SetEntityRenderColor(client, 50, 50, 50, 155);
					CPrintToChat(client, "{green}YOU ARE A STALKER:\n{orange}- If not close to any survivors, you will be cloaked and gain super speed!\n- Your backstabs do more damage.");
				}
				// smoker
				if (g_iSpecialInfected[client] == INFECTED_SMOKER)
				{
					SetEntityRenderColor(client, 255, 0, 0, 255);
					CPrintToChat(client, "{green}YOU ARE A SMOKER:\n{orange}- Right click to fire a beam to enemy players and pull them towards you! {yellow}(no cooldown)");
				}
			}

			if (g_ShouldBacteriaPlay[client])
			{
				EmitSoundToClient(client, g_strSoundSpawnInfected[g_iSpecialInfected[client]]);
				
				for (int i = 1; i <= MaxClients; i++)
					if (IsValidSurvivor(i))
						EmitSoundToClient(i, g_strSoundSpawnInfected[g_iSpecialInfected[client]]);
				
				g_ShouldBacteriaPlay[client] = false;
			}
		}
	}

	TFClassType clientClass = TF2_GetPlayerClass(client);

	resetClientState(client);
	// 1. Prevent players spawning on survivors if round has started.
	//        Prevent players spawning on survivors as an invalid class.
	//        Prevent players spawning on zombies as an invalid class.
	if (IsSurvivor(client))
	{
		if (roundState() == RoundActive)
		{
			SpawnClient(client, zomTeam());
			return Plugin_Continue;
		}

		if (!IsValidSurvivorClass(clientClass))
		{
			SpawnClient(client, surTeam());
			return Plugin_Continue;
		}
	}

	else if (IsZombie(client))
	{
		if (!IsValidZombieClass(clientClass))
		{
			SpawnClient(client, zomTeam());
			return Plugin_Continue;
		}

		if (roundState() == RoundActive)
		{
			if (g_iSpecialInfected[client] != INFECTED_TANK && !PerformFastRespawn(client))
			{
				TF2_AddCondition(client, TFCond_Ubercharged, 2.0);
			}
		}
		
		// Set zombie model / soul wearable
		ApplyVoodooCursedSoul(client);
	}
	
	// 2. Handle valid, post spawn logic
	CreateTimer(0.1, timer_postSpawn, client, TIMER_FLAG_NO_MAPCHANGE);
	
	/*
	// 2. Strip/Update player weapons
	if (IsZombie(client))
	{
		HandleZombieLoadout(client);
		if (GetCookie(client, cookieFirstTimeZombie) < 1)
		{
			InitiateZombieTutorial(client);
		}
	}
	else if (IsSurvivor(client))
	{
		HandleSurvivorLoadout(client);
		if (GetCookie(client, cookieFirstTimeSurvivor) < 1)
		{
			InitiateSurvivorTutorial(client);
		}
	}
	*/
	
	SetGlow();
	//UpdateZombieDamageScale();
	//TankCanReplace(client);
	//HandleClientInventory(client);
	
	return Plugin_Continue;
}

//
// Player Death Event
//
public Action event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;

	int killers[2];
	int victim = GetClientOfUserId(event.GetInt("userid"));
	killers[0] = GetClientOfUserId(event.GetInt("attacker"));
	killers[1] = GetClientOfUserId(event.GetInt("assister"));

	ClientCommand(victim, "r_screenoverlay\"\"");

	DropCarryingItem(victim);

	// handle bonuses
	if (IsValidZombie(killers[0]) && killers[0] != victim)
	{
		g_iKillsThisLife[killers[0]]++;
		// 50%
		if (g_iNextSpecialInfected[killers[0]] == INFECTED_NONE && !GetRandomInt(0, 1) && g_bRoundActive == true)
		{
			g_bSpawnAsSpecialInfected[killers[0]] = true;
			
			//if (g_iSpecialInfected[killers[0]] == INFECTED_NONE) g_bReplaceRageWithSpecialInfectedSpawn[killers[0]] = true;
		}

		if (g_iKillsThisLife[killers[0]] == 3)
		{
			TF2_AddCondition(killers[0], TFCond_DefenseBuffed, TFCondDuration_Infinite);
			// TF2_AddCondition(killers[0], TFCond_Buffed, TFCondDuration_Infinite);
		}
	}

	if (IsValidZombie(killers[1]) && killers[1] != victim)
	{
		// 20%
		if (g_iNextSpecialInfected[victim] == INFECTED_NONE && !GetRandomInt(0, 4) && g_bRoundActive == true)
		{
			g_bSpawnAsSpecialInfected[killers[1]] = true;
		}
	}

	if (g_iSpecialInfected[victim] == INFECTED_TANK)
	{
		g_iDamage[victim] = GetAverageDamage();
		
		int iWinner = 0;
		float fHighest = 0.0;
				
		EmitSoundToAll(g_strZombieVO_Tank_Death[GetRandomInt(0, sizeof(g_strZombieVO_Tank_Death) - 1)]);
				
		for (int i = 1; i <= MaxClients; i++)
		{
			//If current music is tank, end it
			if (GetCurrentSound(i) == SOUND_MUSIC_TANK) EndSound(i);
			
			if (IsValidLivingSurvivor(i))
			{
				if (fHighest < g_fDamageDealtAgainstTank[i])
				{
					fHighest = g_fDamageDealtAgainstTank[i];
					iWinner = i;
				}

				AddMorale(i, 20);
			}
		}

		if (fHighest > 0.0)
		{
			SetHudTextParams(-1.0, 0.3, 8.0, 200, 255, 200, 128, 1);

			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i))
				{
					ShowHudText(i, 5, "The Tank '%N' has died\nMost damage: %N (%d)", victim, iWinner, RoundFloat(fHighest));
				}
			}
		}

		if (g_iDamageDealtLife[victim] <= 50 && g_iDamageTakenLife[victim] <= 150 && !g_bTankRefreshed)
		{
			g_bTankRefreshed = true;
			g_iSpecialInfected[victim] = INFECTED_NONE;
			ZombieTank();
		}
		
		Call_StartForward(g_hForwardTankDeath);
		Call_PushCell(victim);
		Call_PushCell(iWinner);
		Call_PushCell(RoundFloat(fHighest));
		Call_Finish();
	}

	g_iEyelanderHead[victim] = 0;
	g_iMaxHealth[victim] = -1;
	g_ShouldBacteriaPlay[victim] = true;
	g_bReplaceRageWithSpecialInfectedSpawn[victim] = false;
	int g_iSpecialInfectedIndex = g_iSpecialInfected[victim];
	g_iSpecialInfected[victim] = INFECTED_NONE;

	// Handle zombie death logic, all round states.
	if (IsValidZombie(victim))
	{
		// 10%
		if (IsValidSurvivor(killers[0]) && !GetRandomInt(0, 9) && g_bRoundActive == true)
		{
			g_bSpawnAsSpecialInfected[victim] = true;
		}
		
		// boomer
		if (g_iSpecialInfectedIndex == INFECTED_BOOMER)
		{
			DoBoomerExplosion(victim, 400.0);
		}
		
		// set special infected state
		if (g_iNextSpecialInfected[victim] != INFECTED_NONE)
		{
			if (victim != g_iZombieTank) g_iSpecialInfected[victim] = g_iNextSpecialInfected[victim];
			g_iNextSpecialInfected[victim] = INFECTED_NONE;
		}
		
		// Remove dropped ammopacks from zombies.
		int index = -1;
		while ((index = FindEntityByClassname(index, "tf_ammo_pack")) != -1)
		{
			if (GetEntPropEnt(index, Prop_Send, "m_hOwnerEntity") == victim)
			{
				AcceptEntityInput(index, "Kill");
			}
		}

		// zombie rage: instant respawn
		if (g_bZombieRage && roundState() == RoundActive)
		{
			float flTimer = 0.1;
			
			//Check if respawn stress reaches time limit, if so add cooldown/timer so we dont instant respawn too much zombies at once
			if (g_flRageRespawnStress > GetGameTime())
				flTimer += (g_flRageRespawnStress - GetGameTime()) * 1.2;
			
			g_flRageRespawnStress += 1.7;	//Add stress time 1.7 sec for every respawn zombies
			CreateTimer(flTimer, RespawnPlayer, victim);
		}
		
		//Check for spec bypass from AFK manager
		RequestFrame(Frame_CheckZombieBypass, victim);
	}

	// Instant respawn outside of the actual gameplay
	if (roundState() != RoundActive && roundState() != RoundPost)
	{
		CreateTimer(0.1, RespawnPlayer, victim);
		return Plugin_Continue;
	}

	// Handle survivor death logic, active round only.
	if (IsValidSurvivor(victim))
	{
		// black and white effect for death
		ClientCommand(victim, "r_screenoverlay\"debug/yuv\"");

		if (IsValidZombie(killers[0]))
		{
			zf_spawnSurvivorsLastDeath = GetGameTime();
			zf_spawnZombiesKilledSpree = max(RoundToNearest(float(zf_spawnZombiesKilledSpree) / 2.0) - 8, 0);
			zf_spawnSurvivorsKilledCounter++;
		}

		// reset backstab state
		g_bBackstabbed[victim] = false;
		
		// Set zombie time to victim as he started playing zombie
		g_flTimeStartAsZombie[victim] = GetGameTime();
		
		// Transfer player to zombie team.
		CreateTimer(6.0, timer_zombify, victim, TIMER_FLAG_NO_MAPCHANGE);
		// check if he's the last
		CreateTimer(0.1, CheckLastPlayer);
		
		PlaySound(victim, SOUND_EVENT_DEAD, 3.0);
		
		// survivor death: reduce morale
		// AddMoraleAll(-25);
	}

	// Handle zombie death logic, active round only.
	else if (IsValidZombie(victim))
	{
		if (IsValidSurvivor(killers[0]))
		{
			zf_spawnZombiesKilledSpree++;
			zf_spawnZombiesKilledCounter++;
			zf_spawnZombiesKilledSurvivor[killers[0]]++;
			
			// very very very dirty fix for eyelander head
			char sWeapon[128];
			event.GetString("weapon", sWeapon, sizeof(sWeapon));
			if (StrEqual(sWeapon, "sword")
				|| StrEqual(sWeapon, "headtaker")
				|| StrEqual(sWeapon, "nessieclub") )
			{
				g_iEyelanderHead[killers[0]]++;
			}
		}

		for (int i = 0; i < 2; i++)
		{
			if (IsValidLivingClient(killers[i]))
			{
				// Handle ammo kill bonuses.
				// + Soldiers receive 2 rockets per kill.
				// + Demomen receive 1 pipe per kill.
				// + Snipers receive 2 ammo per kill.
				TFClassType killerClass = TF2_GetPlayerClass(killers[i]);
				switch (killerClass)
				{
					case TFClass_Soldier: addResAmmo(killers[i], 0, 2);
					case TFClass_DemoMan: addResAmmo(killers[i], 0, 1);
					case TFClass_Sniper:  addResAmmo(killers[i], 0, 2);
				}

				// Handle morale bonuses.
				// + Each kill adds morale.
				
				// Player gets more morale if low morale instead of high morale
				// Player gets more morale if high zombies, but dont give too much morale if already at high
				
				int iMorale = GetMorale(killers[i]);
				if (iMorale < 0) iMorale = 0;
				else if (iMorale > 100) iMorale = 100;
				float flPercentage = (float(GetZombieCount()) / (float(GetZombieCount()) + float(GetSurvivorCount())));
				int iBase;
				float flMultiplier;
				
				//Roll to get starting morale adds
				if (i == 0)	//Main killer
				{
					if (g_iSpecialInfectedIndex == INFECTED_NONE)
						iBase = GetRandomInt(6, 9);
					else
						iBase = GetRandomInt(10, 13);
				}
				else	//Assist kill
				{
					if (g_iSpecialInfectedIndex == INFECTED_NONE)
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
				AddMorale(killers[i], iBase);
				
				// + Each kill grants a small health bonus and increases current crit bonus.
				int curH = GetClientHealth(killers[i]);
				int maxH = SDK_GetMaxHealth(killers[i]);
				if (curH < maxH)
				{
					curH += iMorale * 2;
					curH = min(curH, maxH);
					//SetEntityHealth(killers[i], curH);
				}

			} // if
		} // for
	} // if

	SetGlow();
	//UpdateZombieDamageScale();

	return Plugin_Continue;
}

//
// Player Hurt Event
//
public Action event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;

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

//
// Object Built Event
//
public Action event_PlayerBuiltObject(Event event, const char[] name, bool dontBroadcast)
{
    if (!zf_bEnabled) return Plugin_Continue;

    int iIndex = GetEventInt(event, "index");
    int iObject = GetEventInt(event, "object");

    // 1. Handle dispenser rules.
    //        Disable dispensers when they begin construction.
    //        Increase max health to 300 (default level 1 is 150).
    if (iObject == OBJECT_ID_DISPENSER)
    {
		SetEntProp(iIndex, Prop_Send, "m_bDisabled", 1); // fuck you
		SetEntProp(iIndex, Prop_Send, "m_bCarried", 1); // die already
		SetEntProp(iIndex, Prop_Send, "m_iMaxHealth", 300);
		AcceptEntityInput(iIndex, "Disable"); // just stop doing that beam thing you cunt
    }

    return Plugin_Continue;
}

public Action event_CPCapture(Handle hEvent, const char[] strName, bool bHide)
{
	if (g_iControlPoints <= 0) return;

	//LogMessage("Captured CP");

	int iCaptureIndex = GetEventInt(hEvent, "cp");
	if (iCaptureIndex < 0) return;
	if (iCaptureIndex >= g_iControlPoints) return;

	for (int i = 0; i < g_iControlPoints; i++)
	{
		if (g_iControlPointsInfo[i][0] == iCaptureIndex)
		{
			g_iControlPointsInfo[i][1] = 2;
		}
	}

	// control point capture: increase morale
	for (int i = 0; i < MaxClients; i++)
	{
		if (zf_CapturingPoint[i] == iCaptureIndex)
		{
			AddMorale(i, 20);
			zf_CapturingPoint[i] = -1;
		}
	}

	CheckRemainingCP();
}

public Action event_CPCaptureStart(Handle hEvent, const char[] strName, bool bHide)
{
	if (g_iControlPoints <= 0) return;

	int iCaptureIndex = GetEventInt(hEvent, "cp");
	//LogMessage("Began capturing CP #%d / (total %d)", iCaptureIndex, g_iControlPoints);
	if (iCaptureIndex < 0) return;
	if (iCaptureIndex >= g_iControlPoints) return;

	for (int i = 0; i < g_iControlPoints; i++)
	{
		if (g_iControlPointsInfo[i][0] == iCaptureIndex)
		{
			g_iControlPointsInfo[i][1] = 1;
			//LogMessage("Set capture status on %d to 1", i);
		}
	}

	//LogMessage("Done with capturing CP event");

	CheckRemainingCP();
}

////////////////////////////////////////////////////////////
//
// Periodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action timer_main(Handle timer) // 1Hz
{
	if (!zf_bEnabled) return Plugin_Continue;
	
	handle_survivorAbilities();
	handle_zombieAbilities();
	UpdateZombieDamageScale();
	SoundTimer();
	
	if (g_bZombieRage)
	{
		setTeamRespawnTime(zomTeam(), 0.0);
	}

	else
	{
		setTeamRespawnTime(zomTeam(), fMax(6.0, 12.0 / fMax(0.6, g_fZombieDamageScale) - zf_spawnZombiesKilledSpree * 0.02));
	}
	
	if (roundState() == RoundActive)
	{
		handle_winCondition();

		for (int i = 1; i <= MaxClients; i++)
		{
			// alive infected
			if (IsValidLivingZombie(i))
			{
				// tank
				if (g_iSpecialInfected[i] == INFECTED_TANK)
				{
					// tank super health handler
					int iHealth = GetClientHealth(i);
					int iMaxHealth = SDK_GetMaxHealth(i);
					if (iHealth < iMaxHealth || g_flTankLifetime[i] < GetGameTime() - 15.0)
					{
						if (iHealth - g_iSuperHealthSubtract[i] > 0)
							SetEntityHealth(i, iHealth - g_iSuperHealthSubtract[i]);
						else
							ForcePlayerSuicide(i);
					}
					
					// screen shake if tank is close by
					float flPosClient[3];
					float flPosTank[3];
					float flDistance;
					GetClientEyePosition(i, flPosTank);

					for (int z = 1; z <= MaxClients; z++)
					{
						if (IsClientInGame(z) && IsPlayerAlive(z) && IsSurvivor(z))
						{
							GetClientEyePosition(z, flPosClient);
							flDistance = GetVectorDistance(flPosTank, flPosClient);
							flDistance /= 20.0;
							if (flDistance <= 50.0)
							{
								Shake(z, fMin(50.0 - flDistance, 5.0), 1.2);
							}
						}
					}
				}

				// kingpin
				if (g_iSpecialInfected[i] == INFECTED_KINGPIN)
				{
					TF2_AddCondition(i, TFCond_TeleportedGlow, 1.5);

					float flPosClient[3];
					float flPosScreamer[3];
					float flDistance;
					GetClientEyePosition(i, flPosScreamer);

					for (int z = 1; z <= MaxClients; z++)
					{
						if (IsValidLivingZombie(z))
						{
							GetClientEyePosition(z, flPosClient);
							flDistance = GetVectorDistance(flPosScreamer, flPosClient);
							if (flDistance <= 600.0)
							{
								TF2_AddCondition(z, TFCond_TeleportedGlow, 1.5);
								zf_screamerNearby[z] = true;
							}

							else
							{
								zf_screamerNearby[z] = false;
							}
						}
					}
				}

				// stalker
				if (g_iSpecialInfected[i] == INFECTED_STALKER)
				{
					float flPosClient[3];
					float flPosPredator[3];
					float flDistance;
					bool bTooClose = false;
					GetClientEyePosition(i, flPosPredator);

					for (int z = 1; z <= MaxClients; z++)
					{
						if (IsValidLivingSurvivor(z))
						{
							GetClientEyePosition(z, flPosClient);
							flDistance = GetVectorDistance(flPosPredator, flPosClient);
							if (flDistance <= 250.0)
							{
								bTooClose = true;
							}
						}
					}

					if (!bTooClose && !TF2_IsPlayerInCondition(i, TFCond_Cloaked))
					{
						TF2_AddCondition(i, TFCond_Cloaked, -1.0);
					}

					else if (bTooClose && TF2_IsPlayerInCondition(i, TFCond_Cloaked))
					{
						TF2_RemoveCondition(i, TFCond_Cloaked);
					}
				}

				// if no special select cooldown is active and less than 2 people have been selected for the respawn into special infected
				// AND
				// damage scale is 120% and a dice roll is hit OR the damage scale is 160%
				if ( g_bRoundActive 
					&& g_flSelectSpecialCooldown <= GetGameTime() 
					&& GetReplaceRageWithSpecialInfectedSpawnCount() <= 2 
					&& g_iZombieTank != i
					&& g_iSpecialInfected[i] == INFECTED_NONE 
					&& g_iNextSpecialInfected[i] == INFECTED_NONE 
					&& g_bSpawnAsSpecialInfected[i] == false
					&& ( (g_fZombieDamageScale >= 1.0 
					&& !GetRandomInt(0, RoundToCeil(200 / g_fZombieDamageScale)))
					|| g_fZombieDamageScale >= 1.6 ) )
				{
					g_bSpawnAsSpecialInfected[i] = true;
					g_bReplaceRageWithSpecialInfectedSpawn[i] = true;
					g_flSelectSpecialCooldown = GetGameTime() + 20.0;
					CPrintToChat(i, "{green}You have been selected to become a Special Infected! {orange}Call 'MEDIC!' to respawn as one or become one on death.");
				}

			}
		}
	}

	return Plugin_Continue;
}

public Action timer_moraleDecay(Handle timer) // timer scales based on how many zombies, slow if low zombies, fast if high zombies
{
	if (!zf_bEnabled) return Plugin_Stop;
	
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
	
	
	zf_tMoraleDecay = CreateTimer(flTimer, timer_moraleDecay);
	
	return Plugin_Continue;
}

public Action timer_mainSlow(Handle timer) // 4 min
{
	if (!zf_bEnabled) return Plugin_Stop;
	help_printZFInfoChat(0);

	return Plugin_Continue;
}

public Action timer_mainFast(Handle timer)
{
	if (!zf_bEnabled) return Plugin_Stop;
	GooDamageCheck();

	return Plugin_Continue;
}

public Action timer_hoarde(Handle timer) // 1/5th Hz
{
	if (!zf_bEnabled) return Plugin_Stop;
	handle_hoardeBonus();

	return Plugin_Continue;
}

public Action timer_datacollect(Handle timer) // 1/5th Hz
{
	if (!zf_bEnabled) return Plugin_Stop;
	FastRespawnDataCollect();

	return Plugin_Continue;
}

public Action timer_progress(Handle timer) // 6 sec
{
	if (zf_tTimeProgress != timer) return Plugin_Stop;
	if (!zf_bEnabled) return Plugin_Stop;
	g_fTimeProgress += 0.01;

	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Aperiodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action timer_graceStartPost(Handle timer)
{
	// Disable all resupply cabinets.
	int index = -1;
	while((index = FindEntityByClassname(index, "func_regenerate")) != -1)
		AcceptEntityInput(index, "Disable");

	// Remove all dropped ammopacks.
	index = -1;
	while ((index = FindEntityByClassname(index, "tf_ammo_pack")) != -1)
			AcceptEntityInput(index, "Kill");

	// Remove all ragdolls.
	index = -1;
	while ((index = FindEntityByClassname(index, "tf_ragdoll")) != -1)
			AcceptEntityInput(index, "Kill");

	// Disable all payload cart dispensers.
	index = -1;
	while((index = FindEntityByClassname(index, "mapobj_cart_dispenser")) != -1)
		SetEntProp(index, Prop_Send, "m_bDisabled", 1);

	// Disable all respawn room visualizers (non-ZF maps only)
	if (!mapIsZF())
	{
		char strParent[255];
		index = -1;
		while((index = FindEntityByClassname(index, "func_respawnroomvisualizer")) != -1)
		{
			GetEntPropString(index, Prop_Data, "respawnroomname", strParent, sizeof(strParent));
			if (!StrEqual(strParent, "ZombieSpawn", false))
			{
				AcceptEntityInput(index, "Disable");
			}
		}
	}
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidSurvivor(i))
			PlaySound(i, SOUND_MUSIC_PREPARE, 33.0);
	
	return Plugin_Continue;
}

public Action timer_graceEnd(Handle timer)
{
	EndGracePeriod();

	return Plugin_Continue;
}

public Action timer_initialHelp(Handle timer, any client)
{
	// Wait until client is in game before printing initial help text.
	if (IsClientInGame(client))
	{
		help_printZFInfoChat(client);
	}
	else
	{
		CreateTimer(10.0, timer_initialHelp, client, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action timer_postSpawn(Handle timer, any client)
{
	if (IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) > 1)
	{
		//HandleClientInventory(client);
		if (IsZombie(client))
		{
			HandleZombieLoadout(client);
			if (GetCookie(client, cookieFirstTimeZombie) < 1)
			{
				InitiateZombieTutorial(client);
			}
		}

		if (IsSurvivor(client))
		{
			HandleSurvivorLoadout(client);
			if (GetCookie(client, cookieFirstTimeSurvivor) < 1)
			{
				InitiateSurvivorTutorial(client);
			}
		}
	}

	return Plugin_Continue;
}

public Action timer_zombify(Handle timer, any client)
{
	if (roundState() != RoundActive) return Plugin_Continue;
	if (IsValidClient(client))
	{
		CPrintToChat(client, "{red}You have perished and turned into a zombie...");
		SpawnClient(client, zomTeam());
	}

	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Handling Functionality
//
////////////////////////////////////////////////////////////
void handle_gameFrameLogic()
{
	int iCount = GetSurvivorCount();
	// 1. Limit spy cloak to 60% of max.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsZombie(i))
		{
			if (g_iSpecialInfected[i] == INFECTED_STALKER)
			{
				setCloak(i, 100.0);
			}

			else if (g_iSpecialInfected[i] == INFECTED_SMOKER)
			{
				// for visual purposes, really
				if (getCloak(i) > 1.0)
				{
					setCloak(i, 1.0);
				}

				if (TF2_IsPlayerInCondition(i, TFCond_Cloaked))
				{
					TF2_RemoveCondition(i, TFCond_Cloaked);
				}
			}

			else if (getCloak(i) > 60.0)
			{
				setCloak(i, 60.0);
			}
		}

		if (roundState() == RoundActive)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && IsSurvivor(i) && iCount == 1)
			{
				if (GetActivePlayerCount() >= 6 && !TF2_IsPlayerInCondition(i, TFCond_Buffed))
				{
					TF2_AddCondition(i, TFCond_Buffed, -1.0);
				}
				if (GetActivePlayerCount() < 6 && TF2_IsPlayerInCondition(i, TFCond_Buffed))
				{
					TF2_RemoveCondition(i, TFCond_Buffed);
				}
			}

			// charger's charge
			if (IsValidLivingZombie(i) && g_iSpecialInfected[i] == INFECTED_CHARGER && isCharging(i))
			{
				float flPosClient[3];
				float flPosCharger[3];
				float flDistance;
				GetClientEyePosition(i, flPosCharger);

				for (int iVictim = 1; iVictim <= MaxClients; iVictim++)
				{
					if (IsClientInGame(iVictim) && IsPlayerAlive(iVictim) && IsSurvivor(iVictim))
					{
						GetClientEyePosition(iVictim, flPosClient);
						flDistance = GetVectorDistance(flPosCharger, flPosClient);
						if (flDistance <= 95.0)
						{
							if (!g_bBackstabbed[iVictim])
							{
								SetBackstabState(iVictim, BACKSTABDURATION_FULL, 0.8);
								SetNextAttack(i, GetGameTime() + 0.6);
								
								TF2_MakeBleed(iVictim, i, 2.0);
								DealDamage(i, iVictim, 30.0);

								char strPath[PLATFORM_MAX_PATH];
								Format(strPath, sizeof(strPath), "weapons/demo_charge_hit_flesh_range1.wav", GetRandomInt(1, 3));
								EmitSoundToAll(strPath, i);
								
								Call_StartForward(g_hForwardChargerHit);
								Call_PushCell(i);
								Call_PushCell(iVictim);
								Call_Finish();
							}

							TF2_RemoveCondition(i, TFCond_Charging);
							break; // target found, break the loop.
						}
					}
				}
			}

			// hopper's pounce
			if (IsValidLivingZombie(i) && g_iSpecialInfected[i] == INFECTED_HUNTER && g_bHopperIsUsingPounce[i])
			{
				float flPosClient[3];
				float flPosHopper[3];
				float flDistance;
				GetClientEyePosition(i, flPosHopper);

				for (int z = 1; z <= MaxClients; z++)
				{
					if (IsClientInGame(z) && IsPlayerAlive(z) && IsSurvivor(z))
					{
						GetClientEyePosition(z, flPosClient);
						flDistance = GetVectorDistance(flPosHopper, flPosClient);
						if (flDistance <= 90.0)
						{
							if (!g_bBackstabbed[z])
							{
								SetEntityHealth(z, GetClientHealth(z) - 20);

								SetBackstabState(z, BACKSTABDURATION_FULL, 1.0);
								SetNextAttack(i, GetGameTime() + 0.6);

								// teleport hunter inside the target
								GetClientAbsOrigin(z, flPosClient);
								TeleportEntity(i, flPosClient, NULL_VECTOR, NULL_VECTOR);
								// dont allow hunter to move during lock
								TF2_StunPlayer(i, BACKSTABDURATION_FULL, 1.0, TF_STUNFLAG_SLOWDOWN, 0);
								
								Call_StartForward(g_hForwardHunterHit);
								Call_PushCell(i);
								Call_PushCell(z);
								Call_Finish();
							}
							
							zf_rageTimer[i] = 21;
							g_bHopperIsUsingPounce[i] = false;
							break; // break the loop, since we found our target
						}
					}
				}
			}
		}
	}
}

void handle_winCondition()
{
	// 1. Check for any survivors that are still alive.
	bool anySurvivorAlive = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i))
		{
			anySurvivorAlive = true;
			break;
		}
	}

	// 2. If no survivors are alive and at least 1 zombie is playing,
	//        end round with zombie win.
	if (!anySurvivorAlive && (GetTeamClientCount(zomTeam()) > 0))
	{
		endRound(zomTeam());
	}
}

void handle_survivorAbilities()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
		{
			// 1. Survivor health regeneration.
			int curH = GetClientHealth(i);
			int maxH = SDK_GetMaxHealth(i);
			if (curH < maxH)
			{
				// balance regen for medics and non-medics
				switch (TF2_GetPlayerClass(i))
				{
					// default values: blutsauger = 1-4, default = 2-5
					case TFClass_Medic: curH -= (isEquipped(i, 36)) ? 1 : 2;
					default: curH += 2;
				}

				curH += (!g_bSurvival) ? RoundToFloor(fMin(GetMorale(i) * 0.166, 4.0)) : 1;
				curH = min(curH, maxH);
				SetEntityHealth(i, curH);
			}

			// 2. Handle survivor morale.
			if (zf_survivorMorale[i] > 100) SetMorale(i, 100);
			//zf_survivorMorale[i] = max(0, zf_survivorMorale[i] - 1);
			int iMorale = GetMorale(i);
			// decrement morale bonus over time

			// 2.1. Show morale on HUD
			SetHudTextParams(0.18, 0.71, 1.0, 200 - (iMorale * 2), 255, 200 - (iMorale * 2), 255);
			ShowHudText(i, 3, "Morale: %d/100", iMorale);

			// 2.2. Award buffs if high morale is detected
			if (iMorale > 50) TF2_AddCondition(i, TFCond_DefenseBuffed, 1.1); // 50: defense buff

			// 3. HUD stuff
			// 3.1. Primary weapons
			SetHudTextParams(0.18, 0.84, 1.0, 200, 255, 200, 255);
			int iPrimary = GetPlayerWeaponSlot(i, 0);
			if (iPrimary > MaxClients && IsValidEdict(iPrimary))
			{
				if (GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex") == 752)
				{
					float fFocus = GetEntPropFloat(i, Prop_Send, "m_flRageMeter");
					ShowHudText(i, 0, "Focus: %d/100", RoundToZero(fFocus));
				}

				if (isSlotClassname(i, 0, "tf_weapon_particle_cannon"))
				{
					float fEnergy = GetEntPropFloat(iPrimary, Prop_Send, "m_flEnergy");
					ShowHudText(i, 0, "Mangler: %d\%", RoundFloat(fEnergy)*5);
				}

				if (isSlotClassname(i, 0, "tf_weapon_drg_pomson"))
				{
					float fEnergy = GetEntPropFloat(iPrimary, Prop_Send, "m_flEnergy");
					ShowHudText(i, 0, "Pomson: %d\%", RoundFloat(fEnergy)*5);
				}

				if (isSlotClassname(i, 0, "tf_weapon_sniperrifle_decap"))
				{
					int iHeads = GetEntProp(i, Prop_Send, "m_iDecapitations");
					ShowHudText(i, 0, "Heads: %d", iHeads);
				}

				if (isSlotClassname(i, 0, "tf_weapon_sentry_revenge"))
				{
					int iCrits = GetEntProp(i, Prop_Send, "m_iRevengeCrits");
					ShowHudText(i, 0, "Crits: %d", iCrits);
				}
			}

			// 3.2. Secondary weapons
			SetHudTextParams(0.18, 0.9, 1.0, 200, 255, 200, 255);
			int iSecondary = GetPlayerWeaponSlot(i, 1);
			if (iSecondary > MaxClients && IsValidEdict(iSecondary))
			{
				if (isSlotClassname(i, 1, "tf_weapon_raygun"))
				{
					float fEnergy = GetEntPropFloat(iSecondary, Prop_Send, "m_flEnergy");
					ShowHudText(i, 5, "Bison: %d\%", RoundFloat(fEnergy)*5);
				}

				if (isSlotClassname(i, 1, "tf_weapon_buff_item"))
				{
					float fRage = GetEntPropFloat(i, Prop_Send, "m_flRageMeter");
					ShowHudText(i, 5, "Rage: %d/100", RoundToZero(fRage));
				}
				
				if (isSlotClassname(i, 1, "tf_weapon_jar_gas"))
				{
					float flMeter = GetEntPropFloat(i, Prop_Send, "m_flItemChargeMeter", 1);
					ShowHudText(i, 5, "Gas: %d/100", RoundToZero(flMeter));
				}

				if (isSlotClassname(i, 1, "tf_weapon_charged_smg"))
				{
					float fRage = GetEntPropFloat(iSecondary, Prop_Send, "m_flMinicritCharge");
					ShowHudText(i, 5, "Crikey: %d/100", RoundToZero(fRage));
				}
			}

		}
	}

	// 3. Handle sentry rules.
	//        + Mini and Norm sentry starts with 40 ammo and decays to 0, then self destructs.
	//        + No sentry can be upgraded.
	int index = -1;
	while ((index = FindEntityByClassname(index, "obj_sentrygun")) != -1)
	{
		//int iOwner = GetEntPropEnt(index, Prop_Data, "m_hOwnerEntity");
		bool sentBuilding = GetEntProp(index, Prop_Send, "m_bBuilding") == 1;
		bool sentPlacing = GetEntProp(index, Prop_Send, "m_bPlacing") == 1;
		bool sentCarried = GetEntProp(index, Prop_Send, "m_bCarried") == 1;
		bool sentInfAmmo = view_as<bool>(GetEntProp(index, Prop_Data, "m_spawnflags") & 8);
		// bool sentIsMini = GetEntProp(index, Prop_Send, "m_bMiniBuilding") == 1;

		if (!sentInfAmmo && !sentBuilding && !sentPlacing && !sentCarried)
		{
			int sentAmmo = GetEntProp(index, Prop_Send, "m_iAmmoShells");
			if (sentAmmo > 0)
			{
				sentAmmo = min(40, (sentAmmo - 1));
				SetEntProp(index, Prop_Send, "m_iAmmoShells", sentAmmo);
				SetEntProp(index, Prop_Send, "m_iUpgradeMetal", 0);
			}
			else
			{
				SetVariantInt(GetEntProp(index, Prop_Send, "m_iMaxHealth"));
				AcceptEntityInput(index, "RemoveHealth");
			}
		}

		int sentLevel = GetEntProp(index, Prop_Send, "m_iHighestUpgradeLevel");
		if (!sentInfAmmo && sentLevel > 1)
		{
			SetVariantInt(GetEntProp(index, Prop_Send, "m_iMaxHealth"));
			AcceptEntityInput(index, "RemoveHealth");
		}
	}
}

void handle_zombieAbilities()
{
	TFClassType clientClass;
	int curH;
	int maxH;
	int bonus;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingZombie(i) && g_iSpecialInfected[i] != INFECTED_TANK)
		{
			clientClass = TF2_GetPlayerClass(i);
			curH = GetClientHealth(i);
			maxH = SDK_GetMaxHealth(i);

			// 1. Handle zombie regeneration.
			//        Zombies regenerate health based on class and number of nearby
			//        zombies (hoarde bonus). Zombies decay health when overhealed.
			bonus = 0;
			if (curH < maxH)
			{
				switch(clientClass)
				{
					case TFClass_Scout: bonus = 2;
					case TFClass_Heavy: bonus = 1;
					case TFClass_Spy:   bonus = 2;
				}

				// handle additional regeneration
				bonus += 1 * zf_hordeBonus[i]; // horde bonus
				if (g_bZombieRage) bonus += 3; // zombie rage
				if (zf_screamerNearby[i]) bonus += 2; // kingpin

				curH += bonus;
				curH = min(curH, maxH);
				SetEntityHealth(i, curH);
			}
			else if (curH > maxH)
			{
				switch(clientClass)
				{
					case TFClass_Scout: bonus = -3;
					case TFClass_Heavy: bonus = -6;
					case TFClass_Spy:   bonus = -3;
				}
				curH += bonus;
				curH = max(curH, maxH);
				SetEntityHealth(i, curH);
			}

			// 2.1. Handle fast respawn into special infected HUD message
			if (g_bRoundActive && g_bReplaceRageWithSpecialInfectedSpawn[i])
			{
				PrintHintText(i, "Call 'MEDIC!' to respawn as a special infected!");
			}
			// 2.2. Handle zombie rage timer
			//        Rage recharges every 20(special)/30(normal) seconds.
			else if (zf_rageTimer[i] > 0)
			{
				if (zf_rageTimer[i] == 1) PrintHintText(i, "Rage is ready!");
				if (zf_rageTimer[i] == 6) PrintHintText(i, "Rage is ready in 5 seconds!");
				if (zf_rageTimer[i] == 11) PrintHintText(i, "Rage is ready in 10 seconds!");
				if (zf_rageTimer[i] == 21) PrintHintText(i, "Rage is ready in 20 seconds!");
				if (zf_rageTimer[i] == 31) PrintHintText(i, "Rage is ready in 30 seconds!");

				zf_rageTimer[i]--;
			}
			
			// 3. HUD for sandman
			SetHudTextParams(0.18, 0.9, 1.0, 200, 255, 200, 255);
			int iMelee = GetPlayerWeaponSlot(i, TFWeaponSlot_Melee);
			if (iMelee > MaxClients && IsValidEdict(iMelee))
			{
				if (isSlotClassname(i, TFWeaponSlot_Melee, "tf_weapon_bat_wood"))
				{
					g_flGooCooldown[i] = GetEntPropFloat(iMelee, Prop_Send, "m_flEffectBarRegenTime");
					float fTime = g_flGooCooldown[i] - GetGameTime();
					if (fTime > 0.0)
						ShowHudText(i, 5, "Ball: %ds", RoundToZero(fTime));
				}
			}
		} //if
	} //for
}

void handle_hoardeBonus()
{
	int playerCount;
	int player[MAXPLAYERS];
	int playerHoardeId[MAXPLAYERS];
	float playerPos[MAXPLAYERS][3];

	int hoardeSize[MAXPLAYERS];

	int curPlayer;
	int curHoarde;
	Handle hStack;

	// 1. Find all active zombie players.
	playerCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsZombie(i))
		{
			player[playerCount] = i;
			playerHoardeId[playerCount] = -1;
			GetClientAbsOrigin(i, playerPos[playerCount]);
			playerCount++;
		}
	}

	// 2. Calculate hoarde groups.
	//        A hoarde is defined as a single, contiguous group of valid zombie
	//        players. Distance calculation between zombie players serves as
	//        primary decision criteria.
	curHoarde = 0;
	hStack = CreateStack();
	for (int i = 0; i < playerCount; i++)
	{
		// 2a. Create new hoarde group.
		if (playerHoardeId[i] == -1)
		{
			PushStackCell(hStack, i);
			playerHoardeId[i] = curHoarde;
			hoardeSize[curHoarde] = 1;
		}

		// 2b. Build current hoarde created in step 2a.
		//         Use a depth-first adjacency search.
		while(PopStackCell(hStack, curPlayer))
		{
			for (int j = i+1; j < playerCount; j++)
			{
				if (playerHoardeId[j] == -1)
				{
					if (GetVectorDistance(playerPos[j], playerPos[curPlayer], true) <= 200000)
					{
						PushStackCell(hStack, j);
						playerHoardeId[j] = curHoarde;
						hoardeSize[curHoarde]++;
					}
				}
			}
		}
		curHoarde++;
	}

	// 3. Set hoarde bonuses.
	for (int i = 1; i <= MaxClients; i++)
		zf_hordeBonus[i] = 0;
	for (int i = 0; i < playerCount; i++)
		zf_hordeBonus[player[i]] = hoardeSize[playerHoardeId[i]] - 1;

	delete hStack;
}

////////////////////////////////////////////////////////////
//
// ZF Logic Functionality
//
////////////////////////////////////////////////////////////
void zfEnable()
{
	g_bFirstRound = true;
	g_bSurvival = false;
	g_bNoMusic = false;
	g_bNoDirectorTanks = false;
	g_bNoDirectorRages = false;
	g_bDirectorSpawnTeleport = false;
	zf_bEnabled = true;
	zf_bNewRound = true;
	zf_lastSurvivor = false;
	
	g_fTimeProgress = 0.0;
	
	setRoundState(RoundInit2);

	zfSetTeams();

	for (int i = 1; i <= MaxClients; i++)
		resetClientState(i);

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
	
	// [Re]Enable periodic timers.
	delete zf_tMain;
	zf_tMain = CreateTimer(1.0, timer_main, _, TIMER_REPEAT);
	
	delete zf_tMoraleDecay;
	zf_tMoraleDecay = CreateTimer(1.0, timer_moraleDecay);	//Timer inside will call itself for loops
	
	delete zf_tMainSlow;
	zf_tMainSlow = CreateTimer(240.0, timer_mainSlow, _, TIMER_REPEAT);

	delete zf_tMainFast;
	zf_tMainFast = CreateTimer(0.5, timer_mainFast, _, TIMER_REPEAT);

	delete zf_tHoarde;
	zf_tHoarde = CreateTimer(5.0, timer_hoarde, _, TIMER_REPEAT);

	delete zf_tDataCollect;
	zf_tDataCollect = CreateTimer(2.0, timer_datacollect, _, TIMER_REPEAT);
}

void zfDisable()
{
	g_bFirstRound = false;
	g_bSurvival = false;
	g_bNoMusic = false;
	g_bNoDirectorTanks = false;
	g_bNoDirectorRages = false;
	g_bDirectorSpawnTeleport = false;
	zf_bEnabled = false;
	zf_bNewRound = true;
	zf_lastSurvivor = false;
	
	g_fTimeProgress = 0.0;
	
	setRoundState(RoundInit2);

	for (int i = 0; i <= MAXPLAYERS; i++)
		resetClientState(i);

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
	
	// Disable periodic timers.

	delete zf_tMain;
	delete zf_tMoraleDecay;
	delete zf_tMainSlow;
	delete zf_tHoarde;
	delete zf_tDataCollect;
	delete zf_tTimeProgress;

	// Enable resupply lockers.
	int index = -1;
	while((index = FindEntityByClassname(index, "func_regenerate")) != -1)
		AcceptEntityInput(index, "Enable");
}

void zfSetTeams()
{
	//
	// Determine team roles.
	// + By default, survivors are RED and zombies are BLU.
	//
	int survivorTeam = INT(TFTeam_Red);
	int zombieTeam = INT(TFTeam_Blue);

	//
	// Determine whether to swap teams on payload maps.
	// + For "pl_" prefixed maps, swap teams if sm_zf_swaponpayload is set.
	//
	if (mapIsPL())
	{
		if (GetConVarBool(zf_cvSwapOnPayload))
		{
			survivorTeam = INT(TFTeam_Blue);
			zombieTeam = INT(TFTeam_Red);
		}
	}

	//
	// Determine whether to swap teams on attack / defend maps.
	// + For "cp_" prefixed maps with all RED control points, swap teams if sm_zf_swaponattdef is set.
	//
	if (mapIsCP())
	{
		if (GetConVarBool(zf_cvSwapOnAttdef))
		{
			bool isAttdef = true;
			int index = -1;
			while((index = FindEntityByClassname(index, "team_control_point")) != -1)
			{
				if (GetEntProp(index, Prop_Send, "m_iTeamNum") != INT(TFTeam_Red))
				{
					isAttdef = false;
					break;
				}
			}

			if (isAttdef)
			{
				survivorTeam = INT(TFTeam_Blue);
				zombieTeam = INT(TFTeam_Red);
			}
		}
	}

	// Set team roles.
	setSurTeam(survivorTeam);
	setZomTeam(zombieTeam);
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
void resetClientState(int client)
{
	zf_survivorMorale[client] = 0;
	zf_hordeBonus[client] = 0;
	zf_CapturingPoint[client] = -1;
	zf_screamerNearby[client] = false;
	zf_rageTimer[client] = 0;
}

////////////////////////////////////////////////////////////
//
// Help Functionality
//
////////////////////////////////////////////////////////////
public void help_printZFInfoChat(int client)
{
	char strMessage[256];
	Format(strMessage, sizeof(strMessage), "{lightsalmon}Welcome to Super Zombie Fortress.\nYou can open the instruction menu using {limegreen}/szf{lightsalmon}.");

	if (client == 0)
	{
		CPrintToChatAll(strMessage);
	}
	else
	{
		CPrintToChat(client, strMessage);
	}
}

//
// Main.Help Menu
//
public void panel_PrintMain(int client)
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
	panel.Send(client, panel_HandleHelp, 30);
	delete panel;
}

public int panel_HandleHelp(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintOverview(param1);
			case 2: panel_PrintTeam(param1, INT(surTeam()));
			case 3: panel_PrintTeam(param1, INT(zomTeam()));
			case 4: panel_PrintSurClass(param1);
			case 5: panel_PrintZomClass(param1);
			case 6: panel_PrintZomSpecial(param1);
			default: return;
		}
	}
}

//
// Main.Help.Overview Menus
//
public void panel_PrintOverview(int client)
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
	panel.Send(client, panel_HandleOverview, 10);
	delete panel;
}

public int panel_HandleOverview(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintMain(param1);
			default: return;
		}
	}
}

//
// Main.Help.Team Menus
//
public void panel_PrintTeam(int client, int team)
{
	Panel panel = new Panel();
	if (team == INT(surTeam()))
	{
		panel.SetTitle("Survivors");
		panel.DrawText("-------------------------------------------");
		panel.DrawText("Survivors consist of Soldiers, Pyros, Demoman, Medics, Engineers and Snipers.");
		panel.DrawText("Survivors gain regeneration and a small bonus to their damage based on Morale.");
		panel.DrawText("Morale is gained by doing objectives and killing infected but is also lost over time and by negative events.");
		panel.DrawText("Survivors only start with a melee weapon and pick up weapons (using CALL 'MEDIC!', 'mouse1' or 'mouse2') as they progress through the map.");
		panel.DrawText("-------------------------------------------");
	}
	else if (team == INT(zomTeam()))
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
	panel.Send(client, panel_HandleTeam, 30);
	delete panel;
}

public int panel_HandleTeam(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintMain(param1);
			default: return;
		}
	}
}

//
// Main.Help.Class Menus
//
public void panel_PrintSurClass(int client)
{
	Panel panel = new Panel();
	panel.SetTitle("Survivor Classes");
	panel.DrawItem(" Soldier");
	panel.DrawItem(" Pyro");
	panel.DrawItem(" Demoman");
	panel.DrawItem(" Medic");
	panel.DrawItem(" Engineer");
	panel.DrawItem(" Sniper");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(client, panel_HandleSurClass, 10);
	delete panel;
}

public int panel_HandleSurClass(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintClass(param1, TFClass_Soldier);
			case 2: panel_PrintClass(param1, TFClass_Pyro);
			case 3: panel_PrintClass(param1, TFClass_DemoMan);
			case 4: panel_PrintClass(param1, TFClass_Medic);
			case 5: panel_PrintClass(param1, TFClass_Engineer);
			case 6: panel_PrintClass(param1, TFClass_Sniper);
			case 7: panel_PrintMain(param1);
			default: return;
		}
	}
}

public void panel_PrintZomClass(int client)
{
	Panel panel = new Panel();
	panel.SetTitle("Zombie Classes");
	panel.DrawItem(" Scout");
	panel.DrawItem(" Heavy");
	panel.DrawItem(" Spy");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(client, panel_HandleZomClass, 10);
	delete panel;
}

public int panel_HandleZomClass(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintClass(param1, TFClass_Scout);
			case 2: panel_PrintClass(param1, TFClass_Heavy);
			case 3: panel_PrintClass(param1, TFClass_Spy);
			case 4: panel_PrintMain(param1);
			default: return;
		}
	}
}

public void panel_PrintClass(int client, TFClassType class)
{
	Panel panel = new Panel();
	switch(class)
	{
		case TFClass_Soldier:
		{
			panel.SetTitle("Soldier");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Gains 2 rockets per kill, this can go beyond the usual maximum capacity of your weapon.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Pyro:
		{
			panel.SetTitle("Pyro");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Burning zombies move faster.");
			panel.DrawText("Flamethrower ammo limited to 120.");
			panel.DrawText("Movement speed lowered to 250 (from 300).");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_DemoMan:
		{
			panel.SetTitle("Demoman");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Gains 1 pipe per kill, this can go beyond the usual maximum capacity of your weapon.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Engineer:
		{
			panel.SetTitle("Engineer");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Buildables cannot be upgraded.");
			panel.DrawText("Can only build sentries and dispensers.");
			panel.DrawText("Sentry ammo is limited, decays and cannot be replenished.");
			panel.DrawText("Dispensers act as walls, with higher health than usual but no ammo replenishment.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Medic:
		{
			panel.SetTitle("Medic");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Overheal limited to 25pct of maximum health but sticks for a longer duration.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Sniper:
		{
			panel.SetTitle("Sniper");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Gains 2 primary ammo per kill, this can go beyond the usual maximum capacity of your weapon.");
			panel.DrawText("SMG doesn't have to reload.");
			panel.DrawText("Jarate slows down Infected.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Scout:
		{
			panel.SetTitle("Scout");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Uses the Sandman.");
			panel.DrawText("Balls fired from the Sandman do not stun, it emits a toxic gas that damages Survivors who stand on it instead.");
			panel.DrawText("Movement speed lowered to 330 (from 400).");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Heavy:
		{
			panel.SetTitle("Heavy");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Uses the Fists.");
			panel.DrawText("Blocks fatal attacks, reducing damage to 150.");
			panel.DrawText("Suffers less knockback from attacks.");
			panel.DrawText("Benefits less from movement speed and health regeneration bonuses while in a horde.");
			panel.DrawText("-------------------------------------------");
		}
		case TFClass_Spy:
		{
			panel.SetTitle("Spy");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Backstabs put the victim into a 'scared' state, slowing and disabling weapon usage for 5.5 seconds.");
			panel.DrawText("Survivors may become a bit resistant to backstabs, reducing the duration, to ensure game balance.");
			panel.DrawText("-------------------------------------------");
		}
		default:
		{
			panel.SetTitle("Spectator");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("Is immune from the Zombie infection.");
			panel.DrawText("Is truly neutral, not siding with any team.");
			panel.DrawText("-------------------------------------------");
		}
	}
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(client, panel_HandleClass, 30);
	delete panel;
}

public int panel_HandleClass(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintMain(param1);
			default: return;
		}
	}
}

public int panel_PrintZomSpecial(int client)
{
	Panel panel = new Panel();
	panel.SetTitle("Special Infected");
	panel.DrawItem(" Tank (Heavy)");
	panel.DrawItem(" Boomer (Heavy)");
	panel.DrawItem(" Charger (Heavy)");
	panel.DrawItem(" Kingpin (Scout)");
	panel.DrawItem(" Stalker (Spy)");
	panel.DrawItem(" Hunter (Scout)");
	panel.DrawItem(" Smoker (Spy)");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(client, panel_HandleZomSpecial, 10);
	delete panel;
}

public int panel_HandleZomSpecial(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintSpecial(param1, INFECTED_TANK);
			case 2: panel_PrintSpecial(param1, INFECTED_BOOMER);
			case 3: panel_PrintSpecial(param1, INFECTED_CHARGER);
			case 4: panel_PrintSpecial(param1, INFECTED_KINGPIN);
			case 5: panel_PrintSpecial(param1, INFECTED_STALKER);
			case 6: panel_PrintSpecial(param1, INFECTED_HUNTER);
			case 7: panel_PrintSpecial(param1, INFECTED_SMOKER);
			case 8: panel_PrintMain(param1);
			default: return;
		}
	}
}

public void panel_PrintSpecial(int client, int class)
{
	Panel panel = new Panel();
	switch(class)
	{
		case INFECTED_TANK:
		{
			panel.SetTitle("Tank");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("As one of the strongest and brutal infected he has the ability to quickly take down an unsuspecting team of survivors.");
			panel.DrawText("- The Tank has a lot of health which he eventually loses after a while.");
			panel.DrawText("- The Tank starts of fast but is slowed down if damaged by the survivors.");
			panel.DrawText("- The Tank spawns if certain conditions are met.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_BOOMER:
		{
			panel.SetTitle("Boomer");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("He is gross, he is dirty and is not afraid to share this with any unlucky survivors.");
			panel.DrawText("- Upon raging the Boomer explodes, covering survivors close to him in Jarate.");
			panel.DrawText("- On death, the killer and the assister of the killer will be coated in Jarate for a short duration.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_CHARGER:
		{
			panel.SetTitle("Charger");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("His inner rage and insanity has caused him to lose any care for how he uses his body, as long as he can take somebody with it.");
			panel.DrawText("- Using rage to charge the Charger is able to disable a survivor for a short period, damaging based on the victim's health.");
			panel.DrawText("- The Charger wears the Fists of Steel.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_KINGPIN:
		{
			panel.SetTitle("Kingpin");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("The Kingpin is the director of the pack, he makes sure that the Zombies give their fullest in taking down the survivors.");
			panel.DrawText("- Using rage, the Kingpin will rally up the Zombies with an ear-piercing yell, increasing the overall power of the zombies.");
			panel.DrawText("- The Kingpin motivates zombies by standing near them, increasing their efficiency.");
			panel.DrawText("- The Kingpin is slower than a infected Scout, but takes less damage from attacks.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_STALKER:
		{
			panel.SetTitle("Stalker");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("The Stalker is elusive, being able to get close to survivors and back away in the blink of an eye.");
			panel.DrawText("- The Stalker is always cloaked if not close to any survivor.");
			panel.DrawText("- Backstabs deal 50 health damage to a survivor, making it 2.5x stronger than a normal backstab.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_HUNTER:
		{
			panel.SetTitle("Hunter");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("The Hunter is a fast being, being very agile they can easily reach beyond the level's obstacles and be hard to get rid off during hectic combat.");
			panel.DrawText("- Using rage, the Hunter will perform a swift leap which can pounce enemies when making physical contact while leaping.");
			panel.DrawText("- Upon pounce, you will be 'stuck' inside the enemy, making you a very dangerous encounter to face when the opponent is alone.");
			panel.DrawText("-------------------------------------------");
		}
		case INFECTED_SMOKER:
		{
			panel.SetTitle("Smoker");
			panel.DrawText("-------------------------------------------");
			panel.DrawText("The Smoker relies on his toxic beam which damages survivors can pulls them towards the Smoker.");
			panel.DrawText("- The pull power grows stronger the less health the victim has.");
			panel.DrawText("- Cannot use cloak.");
			panel.DrawText("- Cannot use rage.");
			panel.DrawText("-------------------------------------------");
		}
	}
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(client, panel_HandleSpecial, 30);
	delete panel;
}

public int panel_HandleSpecial(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintZomSpecial(param1);
			default: return;
		}
	}
}

void SetGlow()
{
	int iCount = GetSurvivorCount();
	int iGlow = 0;
	int iGlow2;

	if (iCount >= 1 && iCount <= 3) iGlow = 1;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			iGlow2 = iGlow;

			// Non-Survivors cannot glow by default
			if (!IsSurvivor(i)) iGlow2 = 0;

			// Kingpin or Tank
			if (IsZombie(i) && (g_iSpecialInfected[i] == INFECTED_TANK || g_iSpecialInfected[i] == INFECTED_KINGPIN)) iGlow2 = 1;

			// Survivor with lower than 30 health or backstabbed
			if (IsSurvivor(i))
			{
				if (GetClientHealth(i) <= 30) iGlow2 = 1;
				if (g_bBackstabbed[i]) iGlow2 = 1;
			}

			SetEntProp(i, Prop_Send, "m_bGlowEnabled", iGlow2);
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
		&& (roundState() != RoundPost))								//Check if round did not end or map changing
	{
		g_bForceZombieStart[iClient] = true;
		SetClientCookie(iClient, cookieForceZombieStart, "1");
	}
}

stock int GetConnectingCount()
{
	int playerCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientAuthorized(i))
		{
			playerCount++;
		}
	}
	return playerCount;
}

stock int GetPlayerCount()
{
	int playerCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (GetClientTeam(i) > 1))
		{
			playerCount++;
		}
	}
	return playerCount;
}

stock int GetSurvivorCount()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
		{
			iCount++;
		}
	}
	return iCount;
}

stock int GetZombieCount()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidZombie(i))
		{
			iCount++;
		}
	}
	return iCount;
}

stock int GetReplaceRageWithSpecialInfectedSpawnCount()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidZombie(i) && g_bReplaceRageWithSpecialInfectedSpawn[i])
		{
			iCount++;
		}
	}
	return iCount;
}

void UpdateZombieDamageScale()
{
	g_fZombieDamageScale = 1.0;

	if (g_iStartSurvivors <= 0) return;
	if (!zf_bEnabled) return;
	if (roundState() != RoundActive) return;

	int iSurvivors = GetSurvivorCount();
	if (iSurvivors < 1) iSurvivors = 1; // division by 0 error

	int iZombies = GetZombieCount();
	if (iZombies < 1) iZombies = 1; // division by 0 error
	
	float flProgress = -1.0;
	
	//Check if it been force set
	if (0.0 <= g_flCapScale <= 1.0)
	{
		flProgress = g_flCapScale;
	}
	else
	{
		// iCurrentCP: +1 if CP currently capping, +2 if CP capped
		int iCurrentCP = 0;
		int iMaxCP = g_iControlPoints * 2;
	
		for (int i = 0; i < g_iControlPoints; i++)
			iCurrentCP += g_iControlPointsInfo[i][1];
		
		// If there atleast 1 CP, set progress by amount of CP capped
		if (iMaxCP > 0)
			flProgress = float(iCurrentCP) / float(iMaxCP);
			
		//If the map is too big for the amount of CPs, progress incerases with time
		if(g_fTimeProgress > flProgress)
		{
			//Failsafe : Cannot exceed current CP (and a half)
			float flProgressMax = (float(iCurrentCP)+1.0) / float(iMaxCP);
			
			//Cannot go above 1.0
			if (flProgressMax > 1.0)
				flProgressMax = 1.0;
			
			if (g_fTimeProgress > flProgressMax)
				flProgress = flProgressMax;
			else
				flProgress = g_fTimeProgress;
		}
		
	}

	//If progress found, calculate by amount of survivors and zombies
	if (0.0 <= flProgress <= 1.0)
	{
		float flExpectedPrecentage = (flProgress * 0.6) + 0.2;
		float flZombiePrecentage = float(iZombies) / float(iSurvivors + iZombies);
		g_fZombieDamageScale += (flExpectedPrecentage - flZombiePrecentage) * 0.7;
	}
	
	// Get the amount of zombies killed since last survivor death
	g_fZombieDamageScale += fMin(0.3, zf_spawnZombiesKilledSpree * 0.003);
	
	// Get total amount of zombies killed
	g_fZombieDamageScale += fMin(0.2, zf_spawnZombiesKilledCounter * 0.0005);
	
	// Zombie rage increases damage
	if (g_bZombieRage)
	{
		g_fZombieDamageScale += 0.1;
		if (g_fZombieDamageScale < 1.1)
			g_fZombieDamageScale = 1.1;
	}
	
	// In survival, zombie to survivor ratio is also taken to calculate damage.
	if (g_bSurvival) g_fZombieDamageScale += fMax(0.0, (iSurvivors / iZombies / 30) + 0.08); // 28-4 = +0.213, 16-16 = +0.113

	// If the last point is being captured, set the damage scale to 110% if lower than 110%
	if (g_bCapturingLastPoint && g_fZombieDamageScale < 1.1 && !g_bSurvival) g_fZombieDamageScale = 1.1;

	// Post-calculation
	if (g_fZombieDamageScale < 1.0) g_fZombieDamageScale *= g_fZombieDamageScale;
	if (g_fZombieDamageScale < 0.33) g_fZombieDamageScale = 0.33;
	if (g_fZombieDamageScale > 3.0) g_fZombieDamageScale = 3.0;
	
	// Debugs
	//PrintToConsoleAll("[Debug] Zombie dmg scale: %.2f | progress %.2f | killspree %d | time since last death %.2f", g_fZombieDamageScale, flProgress, zf_spawnZombiesKilledSpree, GetGameTime() - zf_spawnSurvivorsLastDeath);
	
	// not survival, no rage and no active tank
	if (!g_bSurvival && !g_bZombieRage && g_iZombieTank <= 0 && !ZombiesHaveTank())
	{
		// tank cooldown is active
		if (GetGameTime() > g_flTankCooldown)
		{
			// in order:
			// the damage scale is above 170%
			// the damage scale is above 120% and the total amount of zombies killed since a survivor died exceeds 20
			// none of the survivors died in the past 120 seconds
			if ((g_fZombieDamageScale >= 1.7)
			|| (g_fZombieDamageScale >= 1.2 && zf_spawnZombiesKilledSpree >= 20)
			|| (zf_spawnSurvivorsLastDeath < GetGameTime() - 120.0) )
			{
				ZombieTank();
			}
		}

		// if a random frenzy chance was triggered, determine whether to frenzy or if to trigger a tank
		else if (GetGameTime() > g_flRageCooldown)
		{
			// in order:
			// the damage scale is above 120%
			// the damage scale is above 80% and the total amount of zombies killed since a survivor died exceeds 12
			// the frenzy chance rng is triggered
			// none of the survivors died in the past 60 seconds
			if ( g_fZombieDamageScale >= 1.2
			|| (g_fZombieDamageScale >= 0.8 && zf_spawnZombiesKilledSpree >= 12)
			|| GetRandomInt(0, 100) <= GetConVarInt(zf_cvFrenzyChance)	//convar right now is at 0%
			|| (zf_spawnSurvivorsLastDeath < GetGameTime() - 60.0) )
			{
				// if zombie damage scale is high and the frenzy chance for tank is triggered
				if (GetRandomInt(0, 100) <= GetConVarInt(zf_cvFrenzyTankChance) && g_fZombieDamageScale >= 1.2)	//convar right now is at 0%
				{
					ZombieTank();
				}
				else
				{
					ZombieRage();
				}
			}
		}
	}
}

public Action RespawnPlayer(Handle hTimer, any iClient)
{
	if (IsClientInGame(iClient) && !IsPlayerAlive(iClient))
		TF2_RespawnPlayer(iClient);
}

public Action CheckLastPlayer(Handle hTimer)
{
	int iCount = GetSurvivorCount();
	if (iCount == 1 && !zf_lastSurvivor)
	{
		for (int iLoop = 1; iLoop <= MaxClients; iLoop++)
		{
			if (IsValidLivingSurvivor(iLoop))
			{
				SetEntityHealth(iLoop, 400);
				zf_lastSurvivor = true;
				SetMorale(iLoop, 100);

				char strName[255];
				GetClientName2(iLoop, strName, sizeof(strName));

				CPrintToChatAllEx(iLoop, "%s{green} is the last survivor!", strName);
				
				PlaySoundAll(SOUND_MUSIC_LASTSTAND);
				
				Call_StartForward(g_hForwardLastSurvivor);
				Call_PushCell(iLoop);
				Call_Finish();
			}
		}
	}
	return Plugin_Handled;
}
/*
public Action EventTimeAdded(Event event, const char[] name, bool dontBroadcast)
{
	int iAddedTime = event.GetInt("seconds_added");
	g_AdditionalTime = g_AdditionalTime + iAddedTime;

	if ( GetGameTime() > g_flTankCooldown || !GetRandomInt( 0, RoundToCeil(50.0 / g_fZombieDamageScale)) ) )
	{
		ZombieTank();
	}
}

stock int GetSecondsLeft()
{
	//Get round time that the round started with
	int ent = FindEntityByClassname(MaxClients+1, "team_round_timer");

	if (!IsValidEntity(ent))
	{
		return -1;
	}

	float RoundStartLength = GetEntPropFloat(ent, Prop_Send, "m_flTimeRemaining");
	int iRoundStartLength = RoundToZero(RoundStartLength);
	int TimeBuffer = iRoundStartLength + g_AdditionalTime;

	if (g_StartTime <= 0) return TimeBuffer;

	int SecElapsed = GetTime() - g_StartTime;

	int iTimeLeft = TimeBuffer-SecElapsed;
	if (iTimeLeft < 0) iTimeLeft = 0;
	if (iTimeLeft > TimeBuffer) iTimeLeft = TimeBuffer;

	return iTimeLeft;
}

stock float GetTimePercentage()
{
	//Alright bitch, play tiemz ovar
	if (g_StartTime <= 0) return 0.0;
	int SecElapsed = GetTime() - g_StartTime;
	//CPrintToChatAll("%i Seconds have elapsed since the round started", SecElapsed)

	//Get round time that the round started with
	int ent = FindEntityByClassname(MaxClients+1, "team_round_timer");
	if (ent == -1) return 0.0;

	float RoundStartLength = GetEntPropFloat(ent, Prop_Send, "m_flTimeRemaining");
	//CPrintToChatAll("Float:RoundStartLength == %f", RoundStartLength)
	int iRoundStartLength = RoundToZero(RoundStartLength);

	//g_AdditionalTime = time added this round
	//CPrintToChatAll("TimeAdded This Round: %i", g_AdditionalTime)

	int TimeBuffer = iRoundStartLength + g_AdditionalTime;
	//new TimeLeft = TimeBuffer - SecElapsed;

	float TimePercentage = float(SecElapsed) / float(TimeBuffer);
	//CPrintToChatAll("TimeLeft Sec: %i", TimeLeft)

	if (TimePercentage < 0.0) TimePercentage = 0.0;
	if (TimePercentage > 1.0) TimePercentage = 1.0;

	return TimePercentage;
}
*/
public void OnMapStart()
{
	SoundPrecache();
	DetermineControlPoints();
	Weapons_Precache();
	PrecacheZombieSouls();

	PrecacheParticle("spell_cast_wheel_blue");

	// Goo
	PrecacheParticle("asplode_hoodoo_green");
	AddFileToDownloadsTable("materials/left4fortress/goo.vmt");

	// Boomer
	PrecacheParticle("asplode_hoodoo_debris");
	PrecacheParticle("asplode_hoodoo_dust");

	//PrecacheParticle("bombinomicon_vortex");

	// map pickup
	PrecacheSound("ui/item_paint_can_pickup.wav");

	// kingpin scream
	PrecacheSound("ambient/halloween/male_scream_15.wav");
	PrecacheSound("ambient/halloween/male_scream_16.wav");

	// hopper scream
	PrecacheSound("ambient/halloween/male_scream_18.wav");
	PrecacheSound("ambient/halloween/male_scream_19.wav");

	// charger ka-klunk
	PrecacheSound("weapons/demo_charge_hit_flesh_range1.wav");

	// smoker beam
	g_iSprite = PrecacheModel("materials/sprites/laser.vmt");

	int i;
	for (i = 0; i < sizeof(g_strSoundFleshHit); i++)
	{
		PrecacheSound(g_strSoundFleshHit[i]);
	}

	for (i = 0; i < sizeof(g_strSoundCritHit); i++)
	{
		PrecacheSound(g_strSoundCritHit[i]);
	}

	HookEntityOutput("logic_relay", "OnTrigger", OnRelayTrigger);
	HookEntityOutput("math_counter", "OutValue", OnCounterValue);
}

public Action OnRelayTrigger(const char[] output, int caller, int activator, float delay)
{
	char strRelay[255];
	GetEntPropString(caller, Prop_Data, "m_iName", strRelay, sizeof(strRelay));

	if (StrEqual("szf_panic_event", strRelay)) ZombieRage(_, true);
	else if (StrEqual("szf_zombierage", strRelay)) ZombieRage(_, true);
	else if (StrEqual("szf_zombietank", strRelay)) ZombieTank();
	else if (StrEqual("szf_tank", strRelay)) ZombieTank();
}

public Action OnCounterValue(const char[] output, int caller, int activator, float delay)
{
	char strName[128];
	GetEntPropString(caller, Prop_Data, "m_iName", strName, sizeof(strName));
	
	if (StrEqual(strName, "szf_cp_override", false)
		|| StrEqual(strName, "szf_progress_override", false)
		|| StrEqual(strName, "szf_cp_scale", false)
		|| StrEqual(strName, "szf_progress_scale", false) )
	{
		static int iOffset = -1;
		iOffset = FindDataMapInfo(caller, "m_OutValue");
		g_flCapScale = GetEntDataFloat(caller, iOffset);
	}
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)) EndSound(i);
	}
}

int ZombieRage(float flDuration = 20.0, bool bIgnoreDirector = false)
{
	if (roundState() != RoundActive) return;
	if (g_bZombieRage) return;
	if (ZombiesHaveTank()) return;
	if (g_bNoDirectorRages && !bIgnoreDirector) return;

	g_bZombieRage = true;
	
	g_flRageRespawnStress = GetGameTime();	//Set initial respawn stress
	g_bZombieRageAllowRespawn = true;
	if (flDuration < 20.0) g_bZombieRageAllowRespawn = false;

	CreateTimer(flDuration, StopZombieRage);

	//CPrintToChatAll("Zombie rage");

	if (flDuration >= 20.0)
	{
		PlaySoundAll(SOUND_EVENT_INCOMING, 6.0);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				CPrintToChat(i, "%sZombies are frenzied: they respawn faster and are more powerful!", (IsZombie(i)) ? "{green}" : "{red}");
				
				if (IsZombie(i) && !IsPlayerAlive(i))
				{
					TF2_RespawnPlayer(i);
					g_flRageRespawnStress += 1.7;	//Add stress time 1.7 sec for every respawn zombies
				}
				else if (IsSurvivor(i) && IsPlayerAlive(i))
				{
					// zombies are enraged, reduce morale
					int iMorale = GetMorale(i);
					iMorale = RoundToNearest(float(iMorale) * 0.5);	//Half current morale
					iMorale -= 15;	//Remove 15 extra morale
					if (iMorale < 0) iMorale = 0;
					SetMorale(i, iMorale);
				}
			}
		}
	}

	g_flRageCooldown = GetGameTime() + flDuration + 40.0;
}

public Action StopZombieRage(Handle hTimer)
{
	g_bZombieRage = false;
	UpdateZombieDamageScale();

	if (roundState() == RoundActive)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				CPrintToChat(i, "%sZombies are resting...", (IsZombie(i)) ? "{red}" : "{green}");
			}
		}
	}
}

int FastRespawnNearby(int iClient, float fDistance, bool bMustBeInvisible = true)
{
	if (g_aFastRespawnArray == null) return -1;

	Handle hTombola = CreateArray();

	float fPosClient[3];
	float fPosEntry[3];
	float fPosEntry2[3];
	float fEntryDistance;
	GetClientAbsOrigin(iClient, fPosClient);
	
	int iLength = g_aFastRespawnArray.Length;
	for (int i = 0; i < iLength; i++)
	{
		g_aFastRespawnArray.GetArray(i, fPosEntry);
		fPosEntry2[0] = fPosEntry[0];
		fPosEntry2[1] = fPosEntry[1];
		fPosEntry2[2] = fPosEntry[2] += 90.0;

		bool bAllow = true;

		fEntryDistance = GetVectorDistance(fPosClient, fPosEntry);
		fEntryDistance /= 50.0;
		
		if (fEntryDistance > fDistance) bAllow = false;

		// check if survivors can see it
		if (bMustBeInvisible && bAllow)
		{
			for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
			{
				if (IsValidLivingSurvivor(iSurvivor))
				{
					if (PointsAtTarget(fPosEntry, iSurvivor)) bAllow = false;
					if (PointsAtTarget(fPosEntry2, iSurvivor)) bAllow = false;
				}
			}
		}

		if (bAllow)
		{
			PushArrayCell(hTombola, i);
		}
	}

	if (GetArraySize(hTombola) > 0)
	{
		int iRandom = GetRandomInt(0, GetArraySize(hTombola)-1);
		int iResult = GetArrayCell(hTombola, iRandom);
		delete hTombola;
		return iResult;
	}
	else
	{
		delete hTombola;
	}
	return -1;
}

bool PerformFastRespawn(int iClient)
{
	if (!(g_bDirectorSpawnTeleport) && (!g_bZombieRage || !g_bZombieRageAllowRespawn))
		return false;
	
	// first let's find a target
	Handle hTombola = CreateArray();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i)) PushArrayCell(hTombola, i);
	}

	if (GetArraySize(hTombola) <= 0)
	{
		delete hTombola;
		return false;
	}

	int iTarget = GetArrayCell(hTombola, GetRandomInt(0, GetArraySize(hTombola)-1));
	delete hTombola;

	int iResult = FastRespawnNearby(iTarget, 7.0);
	if (iResult < 0) return false;

	float fPosSpawn[3];
	float fPosTarget[3];
	float fAngle[3];
	g_aFastRespawnArray.GetArray(iResult, fPosSpawn);
	GetClientAbsOrigin(iTarget, fPosTarget);
	VectorTowards(fPosSpawn, fPosTarget, fAngle);

	TeleportEntity(iClient, fPosSpawn, fAngle, NULL_VECTOR);
	return true;
}

void FastRespawnDataCollect()
{
	if (g_aFastRespawnArray == null)
		g_aFastRespawnArray = new ArrayList(3);

	float fPos[3];
	
	g_aFastRespawnArray.Clear(); // cancer everywhere
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsValidLivingPlayer(iClient) && FastRespawnNearby(iClient, 1.0, false) < 0 && !(GetEntityFlags(iClient) & FL_DUCKING == FL_DUCKING) && (GetEntityFlags(iClient) & FL_ONGROUND == FL_ONGROUND))
		{
			GetClientAbsOrigin(iClient, fPos);
			g_aFastRespawnArray.PushArray(fPos);
		}
	}
}

stock void VectorTowards(float vOrigin[3], float vTarget[3], float vAngle[3])
{
	float vResults[3];

	MakeVectorFromPoints(vOrigin, vTarget, vResults);
	GetVectorAngles(vResults, vAngle);
}

stock bool PointsAtTarget(float fBeginPos[3], any iTarget)
{
	float fTargetPos[3];
	GetClientEyePosition(iTarget, fTargetPos);

	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(fBeginPos, fTargetPos, MASK_VISIBLE, RayType_EndPoint, TraceDontHitOtherEntities, iTarget);

	int iHit = -1;
	if (TR_DidHit(hTrace)) iHit = TR_GetEntityIndex(hTrace);

	delete hTrace;
	return (iHit == iTarget);
}

public bool TraceDontHitOtherEntities(int iEntity, int iMask, any iData)
{
	if (iEntity == iData)  return true;
	if (iEntity > 0) return false;
	return true;
}

public bool TraceDontHitEntity(int iEntity, int iMask, any iData)
{
	if (iEntity == iData)  return false;
	return true;
}

stock bool CanRecieveDamage(int iClient)
{
	if (iClient <= 0) return true;
	if (!IsClientInGame(iClient)) return true;
	if (isUbered(iClient)) return false;
	if (isBonked(iClient)) return false;

	return true;
}

stock int GetClientPointVisible(int iClient, float flDistance = 100.0)
{
	float vOrigin[3], vAngles[3], vEndOrigin[3];
	GetClientEyePosition(iClient, vOrigin);
	GetClientEyeAngles(iClient, vAngles);

	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_ALL, RayType_Infinite, TraceDontHitEntity, iClient);
	TR_GetEndPosition(vEndOrigin, hTrace);

	int iReturn = -1;
	int iHit = TR_GetEntityIndex(hTrace);

	if (TR_DidHit(hTrace) && iHit != iClient && GetVectorDistance(vOrigin, vEndOrigin) < flDistance)
	{
		iReturn = iHit;
	}
	
	delete hTrace;

	return iReturn;
}

stock bool ObstactleBetweenEntities(int iEntity1, int iEntity2)
{
	float vOrigin1[3];
	float vOrigin2[3];

	if (IsValidClient(iEntity1)) GetClientEyePosition(iEntity1, vOrigin1);
	else GetEntPropVector(iEntity1, Prop_Send, "m_vecOrigin", vOrigin1);
	GetEntPropVector(iEntity2, Prop_Send, "m_vecOrigin", vOrigin2);

	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(vOrigin1, vOrigin2, MASK_ALL, RayType_EndPoint, TraceDontHitEntity, iEntity1);

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
	
	// remove primary weapon
	TF2_RemoveWeaponSlot(iClient, 0);

	// remove secondary weapon and wearables
	int iEntity = GetPlayerWeaponSlot(iClient, 1);
	if (iEntity > 0 && IsValidEdict(iEntity)) TF2_RemoveWeaponSlot(iClient, 1);
	RemoveWearableWeapons(iClient);

	iEntity = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	if (iEntity > MaxClients && IsValidEdict(iEntity))
	{
		//Get default attrib from config to apply all melee weapons
		char atts[32][32];
		int iCount = ExplodeString(g_eConfigMeleeDefault.sAttrib, " ; ", atts, 32, 32);
		if (iCount > 1)
			for (int i = 0; i < iCount; i+= 2)
				TF2Attrib_SetByDefIndex(iEntity, StringToInt(atts[i]), StringToFloat(atts[i+1]));
		
		//Get attrib from index to apply
		int iIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
		
		int iLength = g_aConfigMelee.Length;
		for (int i = 0; i < iLength; i++)
		{
			eConfigMelee eMelee;
			g_aConfigMelee.GetArray(i, eMelee, sizeof(eMelee));
			
			if (eMelee.iIndex == iIndex)
			{
				//If have prefab, use said index instead
				if (eMelee.iIndexPrefab >= 0)
				{
					int iPrefab = eMelee.iIndexPrefab;
					for (int j = 0; j < iLength; j++)
					{
						g_aConfigMelee.GetArray(j, eMelee, sizeof(eMelee));
						if (eMelee.iIndex == iPrefab)
							break;
					}
				}
				
				//See if there weapon to replace
				if (eMelee.iIndexReplace >= 0)
				{
					iIndex = eMelee.iIndexReplace;
					TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Melee);
					iEntity = TF2_CreateAndEquipWeapon(iClient, iIndex);
					
					//Re-apply global attrib
					for (int j = 0; j < iCount; j+= 2)
						TF2Attrib_SetByDefIndex(iEntity, StringToInt(atts[j]), StringToFloat(atts[j+1]));
				}
				
				//Print text with cooldown to prevent spam
				if (g_flStopChatSpam[iClient] < GetGameTime() && !StrEqual(eMelee.sText, ""))
				{
					CPrintToChat(iClient, eMelee.sText);
					g_flStopChatSpam[iClient] = GetGameTime() + 1.0;
				}
				
				//Apply attribute
				iCount = ExplodeString(eMelee.sAttrib, " ; ", atts, 32, 32);
				if (iCount > 1)
					for (int j = 0; j < iCount; j+= 2)
						TF2Attrib_SetByDefIndex(iEntity, StringToInt(atts[j]), StringToFloat(atts[j+1]));
				
				break;
			}
		}

		// This will refresh health max calculation and other attributes
		TF2Attrib_ClearCache(iEntity);
	}
	else
	{
		// no melee, okay.. weird
		TF2_RespawnPlayer(iClient);
	}
	
	// Prevent Survivors with voodoo-cursed souls
	SetEntProp(iClient, Prop_Send, "m_bForcedSkin", 0);
	SetEntProp(iClient, Prop_Send, "m_nForcedSkin", 0);

	SetValidSlot(iClient);
}

void HandleZombieLoadout(int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient)) return;

	TF2_RemoveWeaponSlot(iClient, 0);
	TF2_RemoveWeaponSlot(iClient, 2);
	TF2_RemoveWeaponSlot(iClient, 3);
	TF2_RemoveWeaponSlot(iClient, 4);

	if (TF2_GetPlayerClass(iClient) == TFClass_Scout)
	{
		if (g_iSpecialInfected[iClient] != INFECTED_NONE || !isSlotClassname(iClient, 1, "tf_weapon_lunchbox_drink"))
		{
			TF2_RemoveWeaponSlot(iClient, 1);
		}

		int iItem = 44; // Sandman
		if (g_iSpecialInfected[iClient] == INFECTED_HUNTER) 	iItem = 572; // Unarmed Combat
		if (g_iSpecialInfected[iClient] == INFECTED_KINGPIN) 	iItem = 939; // Bat Outta Hell
		
		int iMelee = TF2_CreateAndEquipWeapon(iClient, iItem);
		
		if (IsValidEntity(iMelee) && iItem == 44)
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

	if (TF2_GetPlayerClass(iClient) == TFClass_Heavy)
	{
		if (!isSlotClassname(iClient, 1, "tf_weapon_lunchbox"))
		{
			TF2_RemoveWeaponSlot(iClient, 1);
		}

		int iItem = 5; // Fists
		if (g_iSpecialInfected[iClient] == INFECTED_BOOMER) 	iItem = 331; // Fists of Steel
		if (g_iSpecialInfected[iClient] == INFECTED_CHARGER) 	iItem = 587; // Apoco-Fists

		TF2_CreateAndEquipWeapon(iClient, iItem);
	}


	if (TF2_GetPlayerClass(iClient) == TFClass_Spy)
	{
		TF2_RemoveWeaponSlot(iClient, 1);
		TF2_CreateAndEquipWeapon(iClient, 30); // Cloak
		
		int iItem = 4; // Knife
		if (g_iSpecialInfected[iClient] == INFECTED_STALKER) 	iItem = 574; // Wanga Prick
		if (g_iSpecialInfected[iClient] == INFECTED_SMOKER) 	iItem = 356; // Kunai
		
		int iMelee = TF2_CreateAndEquipWeapon(iClient, iItem);
		
		if (IsValidEntity(iMelee) && iItem == 574)
		{
			TF2Attrib_SetByName(iMelee, "disguise on backstab", 0.0);
		}
	}

	// Set slot to melee
	int iEntity = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	if (iEntity > MaxClients && IsValidEdict(iEntity))
	{
		if (TF2_GetPlayerClass(iClient) == TFClass_Scout && g_iSpecialInfected[iClient] == INFECTED_NONE)
		{
			//Remove Sandman's 15 hp penalty
			//TF2Attrib_RemoveByName(iEntity, "max health additive penalty");	//this doesnt work, thanks tf2attribute
			TF2Attrib_SetByName(iEntity, "max health additive penalty", 0.0);
			TF2Attrib_ClearCache(iEntity);
		}
		
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iEntity);
	}

	//Set health back to what it should be after modifying weapons
	SetEntityHealth(iClient, SDK_GetMaxHealth(iClient));

	// reset custom models
	SetVariantString("");
	AcceptEntityInput(iClient, "SetCustomModel");

	//SetValidSlot(iClient);
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
	if (roundState() != RoundActive) return;
	//CPrintToChatAll("Spitter goo at %N!", iClient);

	if (g_hGoo == INVALID_HANDLE) g_hGoo = CreateArray(5);

	float fClientPos[3];
	float fClientEye[3];
	GetClientEyePosition(iClient, fClientPos);
	GetClientEyeAngles(iClient, fClientEye);

	g_iGooId++;
	int iEntry[5];
	iEntry[0] = RoundFloat(fClientPos[0]);
	iEntry[1] = RoundFloat(fClientPos[1]);
	iEntry[2] = RoundFloat(fClientPos[2]);
	iEntry[3] = iAttacker;
	iEntry[4] = g_iGooId;
	PushArrayArray(g_hGoo, iEntry);

	ShowParticle("asplode_hoodoo_dust", TIME_GOO, fClientPos, fClientEye);
	ShowParticle("asplode_hoodoo_green", TIME_GOO, fClientPos, fClientEye);

	CreateTimer(flDuration, GooExpire, g_iGooId);
	CreateTimer(1.0, GooEffect, g_iGooId, TIMER_REPEAT);
}

void GooDamageCheck()
{
	float fPosGoo[3];
	int iEntry[5];
	float fPosClient[3];
	float fDistance;
	int iAttacker;

	bool bWasGooified[MAXPLAYERS+1];

	int iClient;
	for (iClient = 1; iClient <= MaxClients; iClient++)
	{
		bWasGooified[iClient] = g_bGooified[iClient];
		g_bGooified[iClient] = false;
	}

	if (g_hGoo != INVALID_HANDLE)
	{
		for (int i = 0; i < GetArraySize(g_hGoo); i++)
		{
			GetArrayArray(g_hGoo, i, iEntry);
			fPosGoo[0] = float(iEntry[0]);
			fPosGoo[1] = float(iEntry[1]);
			fPosGoo[2] = float(iEntry[2]);
			
			iAttacker = iEntry[3];
			if (!IsValidClient(iAttacker))
				continue;
			
			for (iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (IsValidLivingSurvivor(iClient) && !g_bGooified[iClient] && CanRecieveDamage(iClient) && !g_bBackstabbed[iClient])
				{
					GetClientEyePosition(iClient, fPosClient);
					fDistance = GetVectorDistance(fPosGoo, fPosClient) / 50.0;
					if (fDistance <= DISTANCE_GOO)
					{
						// deal damage
						g_iGooMultiplier[iClient] += GOO_INCREASE_RATE;
						float fPercentageDistance = (DISTANCE_GOO-fDistance) / DISTANCE_GOO;
						if (fPercentageDistance < 0.5) fPercentageDistance = 0.5;
						float fDamage = float(g_iGooMultiplier[iClient])/float(GOO_INCREASE_RATE) * fPercentageDistance;
						if (fDamage < 1.0) fDamage = 1.0;
						if (fDamage > 4.0 && zf_CapturingPoint[iClient] != -1) fDamage = 4.0;	//If client is capturing point, add hardmax 4 dmg
						DealDamage(iAttacker, iClient, fDamage);
						g_bGooified[iClient] = true;

						if (fDamage >= 7.0)
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
			if (IsValidLivingPlayer(iClient) && !g_bGooified[iClient] && g_iGooMultiplier[iClient] > 0)
			{
				g_iGooMultiplier[iClient]--;
			}

			//ScreenFade(client, red, green, blue, alpha, delay, type)
			if (!bWasGooified[iClient] && g_bGooified[iClient] && IsPlayerAlive(iClient))
			{
				// fade screen slightly green
				ClientCommand(iClient, "r_screenoverlay\"left4fortress/goo\"");
				PlaySound(iClient, SOUND_EVENT_DROWN);
				//CPrintToChat(iClient, "You got goo'd!");
			}
			if (bWasGooified[iClient] && !g_bGooified[iClient])
			{
				// fade screen slightly green
				ClientCommand(iClient, "r_screenoverlay\"\"");
				if (GetCurrentSound(iClient) == SOUND_EVENT_DROWN)
					EndSound(iClient);
				//CPrintToChat(iClient, "You are no longer goo'd!");
			}
		}
	}
}

public Action GooExpire(Handle hTimer, any iGoo)
{
	if (g_hGoo == null) return Plugin_Handled;

	int iEntry[5];
	int iEntryId;
	for (int i = 0; i < GetArraySize(g_hGoo); i++)
	{
		GetArrayArray(g_hGoo, i, iEntry);
		iEntryId = iEntry[4];
		if (iEntryId == iGoo)
		{
			RemoveFromArray(g_hGoo, i);
		}
	}

	return Plugin_Handled;
}

void RemoveAllGoo()
{
	if (g_hGoo == INVALID_HANDLE) return;

	ClearArray(g_hGoo);
}

public Action GooEffect(Handle hTimer, any iGoo)
{
	if (g_hGoo == INVALID_HANDLE) return Plugin_Stop;

	int iEntry[5];
	float fPos[3];
	int iEntryId;
	for (int i = 0; i < GetArraySize(g_hGoo); i++)
	{
		GetArrayArray(g_hGoo, i, iEntry);
		iEntryId = iEntry[4];
		fPos[0] = float(iEntry[0]);
		fPos[1] = float(iEntry[1]);
		fPos[2] = float(iEntry[2]);
		if (iEntryId == iGoo)
		{
			ShowParticle("asplode_hoodoo_green", TIME_GOO, fPos);
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}

public void OnEntityCreated(int iEntity, const char[] strClassname)
{
	if (StrContains(strClassname, "item_healthkit") != -1
	|| StrContains(strClassname, "item_ammopack") != -1
	|| StrEqual(strClassname, "tf_ammo_pack"))
	{
		SDKHook(iEntity, SDKHook_StartTouch, OnPickup);
		SDKHook(iEntity, SDKHook_Touch, OnPickup);
	}
	
	if (StrEqual(strClassname, "item_healthkit_medium"))
	{
		SDKHook(iEntity, SDKHook_Touch, BlockTouch);
		CreateTimer(3.0, Timer_EnableSandvichTouch, EntIndexToEntRef(iEntity));
	}
	else if (StrEqual(strClassname, "item_healthkit_small"))
	{
		SDKHook(iEntity, SDKHook_Touch, OnBananaTouch);
	}
	else if (StrEqual(strClassname, "trigger_capture_area"))
	{
		SDKHook(iEntity, SDKHook_StartTouch, OnCaptureStartTouch);
		SDKHook(iEntity, SDKHook_EndTouch, OnCaptureEndTouch);
	}
	else if (StrEqual(strClassname, "trigger_multiple"))
	{
		char sName[128];
		GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
		if (strcmp(sName, "szf_goo_defense", false) == 0)
		{
			SDKHook(iEntity, SDKHook_StartTouch, OnTriggerGooDefenseStart);
			SDKHook(iEntity, SDKHook_EndTouch, OnTriggerGooDefenseEnd);
		}
	}
	else if (StrEqual(strClassname, "tf_projectile_stun_ball"))
	{
		SDKHook(iEntity, SDKHook_StartTouch, BallStartTouch);
		SDKHook(iEntity, SDKHook_Touch, BallTouch);
	}
	else if (StrEqual(strClassname, "tf_dropped_weapon"))
	{
		AcceptEntityInput(iEntity, "kill");
	}
}

public Action OnCaptureStartTouch(int iEntity, int iClient)
{
	if (!zf_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "trigger_capture_area")) return Plugin_Continue;
	
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
	{
		char strTriggerName[128];
		GetEntPropString(iEntity, Prop_Data, "m_iszCapPointName", strTriggerName, sizeof(strTriggerName));	//Get trigger cap name
		
		int i = -1;
		while ((i = FindEntityByClassname2(i, "team_control_point")) != -1)	//find team_control_point
		{
			char strPointName[128];
			GetEntPropString(i, Prop_Data, "m_iName", strPointName, sizeof(strPointName));
			if (strcmp(strPointName, strTriggerName, false) == 0)	//Check if trigger cap is the same as team_control_point
			{
				int iIndex = GetEntProp(i, Prop_Data, "m_iPointIndex");	//Get his index
				
				for (int j = 0; j < g_iControlPoints; j++)
				{
					if (g_iControlPointsInfo[j][0] == iIndex && g_iControlPointsInfo[j][1] != 2)	//Check if that capture have not already been captured
					{
						zf_CapturingPoint[iClient] = iIndex;
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action OnCaptureEndTouch(int iEntity, int iClient)
{
	if (!zf_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "trigger_capture_area")) return Plugin_Continue;
	
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
	{
		zf_CapturingPoint[iClient] = -1;
	}
	
	return Plugin_Continue;
}

public Action OnTriggerGooDefenseStart(int iEntity, int iClient)
{
	if (!zf_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "trigger_multiple")) return Plugin_Continue;
	
	char sName[128];
	GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
	if (strcmp(sName, "szf_goo_defense", false) != 0) return Plugin_Continue;
	
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
	{
		zf_CapturingPoint[iClient] = -2;
	}
	
	return Plugin_Continue;
}

public Action OnTriggerGooDefenseEnd(int iEntity, int iClient)
{
	if (!zf_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "trigger_multiple")) return Plugin_Continue;
	
	char sName[128];
	GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
	if (strcmp(sName, "szf_goo_defense", false) != 0) return Plugin_Continue;
	
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
	{
		zf_CapturingPoint[iClient] = -1;
	}
	
	return Plugin_Continue;
}

public Action BallStartTouch(int iEntity, int iOther)
{
	if (!zf_bEnabled) return Plugin_Continue;
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
	if (!zf_bEnabled) return Plugin_Continue;
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

	// check if both owner and toucher is valid
	if (!IsValidClient(iOwner) || !IsValidClient(iToucher)) return Plugin_Continue;
	
	// dont allow owner and tank collect sandvich
	if (iOwner == iToucher || g_iSpecialInfected[iToucher] == INFECTED_TANK) return Plugin_Handled;
	
	if (GetClientTeam(iToucher) != GetClientTeam(iOwner))
	{
		// Disable Sandvich and kill it
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

	// check if both owner and toucher is valid
	if (!IsValidClient(iOwner) || !IsValidClient(iToucher)) return Plugin_Continue;
	
	// dont allow tank to collect health
	if (g_iSpecialInfected[iToucher] == INFECTED_TANK) return Plugin_Handled;
	
	if (GetClientTeam(iToucher) != GetClientTeam(iOwner))
	{
		// Disable Sandvich and kill it
		SetEntProp(iEntity, Prop_Data, "m_bDisabled", 1);
		AcceptEntityInput(iEntity, "Kill");

		DealDamage(iOwner, iToucher, 30.0);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

stock int ShowParticle(char[] particlename, float time, float pos[3], float ang[3]=NULL_VECTOR)
{
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, RemoveParticle, particle);
	}

	else
	{
		LogError("ShowParticle: could not create info_particle_system");
		return -1;
	}

	return particle;
}

stock void PrecacheParticle(char[] strName)
{
	if (IsValidEntity(0))
	{
		int iParticle = CreateEntityByName("info_particle_system");
		if (IsValidEdict(iParticle))
		{
			char tName[32];
			GetEntPropString(0, Prop_Data, "m_iName", tName, sizeof(tName));
			DispatchKeyValue(iParticle, "targetname", "tf2particle");
			DispatchKeyValue(iParticle, "parentname", tName);
			DispatchKeyValue(iParticle, "effect_name", strName);
			DispatchSpawn(iParticle);
			SetVariantString(tName);
			AcceptEntityInput(iParticle, "SetParent", 0, iParticle, 0);
			ActivateEntity(iParticle);
			AcceptEntityInput(iParticle, "start");
			CreateTimer(0.01, RemoveParticle, iParticle);
		}
	}
}

public Action RemoveParticle( Handle timer, any particle )
{
	if (particle >= 0 && IsValidEntity(particle))
	{
		char classname[32];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "Kill");
			particle = -1;
		}
	}
}

int GetMostDamageZom()
{
	Handle hArray = CreateArray();
	int i;
	int iHighest = 0;

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsValidZombie(i))
		{
			if (g_iDamage[i] > iHighest) iHighest = g_iDamage[i];
		}
	}

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsValidZombie(i) && g_iDamage[i] >= iHighest)
		{
			PushArrayCell(hArray, i);
		}
	}

	if (GetArraySize(hArray) <= 0)
	{
		delete hArray;
		return 0;
	}

	int iClient = GetArrayCell(hArray, GetRandomInt(0, GetArraySize(hArray)-1));
	delete hArray;
	return iClient;
}

bool ZombiesHaveTank()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingZombie(i) && g_iSpecialInfected[i] == INFECTED_TANK) return true;
	}
	return false;
}

void ZombieTank(int iCaller = 0)
{
	if (!zf_bEnabled) return;
	if (roundState() != RoundActive) return;
	if (iCaller <= 0 && g_bNoDirectorTanks) return;

	if (ZombiesHaveTank())
	{
		if (IsValidClient(iCaller)) CPrintToChat(iCaller, "{red}Zombies already have a tank.");
		return;
	}
	if (g_iZombieTank > 0)
	{
		if (IsValidClient(iCaller)) CPrintToChat(iCaller, "{red}A zombie tank is already on the way.");
		return;
	}
	if (g_bZombieRage)
	{
		if (IsValidClient(iCaller)) CPrintToChat(iCaller, "{red}Zombies are frenzied, tanks cannot spawn during frenzy.");
		return;
	}
	
	if (IsValidZombie(iCaller))
		g_iZombieTank = iCaller;
	else
		g_iZombieTank = GetMostDamageZom();
	
	if (g_iZombieTank <= 0) return;
	
	char strName[255];
	GetClientName2(g_iZombieTank, strName, sizeof(strName));
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidZombie(i))
			CPrintToChatEx(i, g_iZombieTank, "%s {green}was chosen to become the TANK!", strName);

	if (IsValidClient(iCaller))
	{
		CPrintToChat(iCaller, "{green}Called tank.");
	}

	g_bReplaceRageWithSpecialInfectedSpawn[g_iZombieTank] = false;
	g_flTankCooldown = GetGameTime() + 120.0; // set new cooldown
	SetMoraleAll(0); // tank spawn, reset morale
}
/*
bool TankCanReplace(int iClient)
{
	if (g_iZombieTank <= 0) return false;
	if (g_iZombieTank == iClient) return false;
	if (g_iSpecialInfected[iClient] != INFECTED_NONE) return false;
	if (TF2_GetPlayerClass(iClient) != TF2_GetPlayerClass(g_iZombieTank)) return false;

	int iHealth = GetClientHealth(g_iZombieTank);
	float fPos[3];
	float fAng[3];
	float fVel[3];

	GetClientAbsOrigin(g_iZombieTank, fPos);
	GetClientAbsAngles(g_iZombieTank, fVel);
	GetEntPropVector(g_iZombieTank, Prop_Data, "m_vecVelocity", fVel);
	SetEntityHealth(iClient, iHealth);
	TeleportEntity(iClient, fPos, fAng, fVel);

	TF2_RespawnPlayer(g_iZombieTank);

	return true;
}
*/
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
	{
		if (IsClassname(iEntity, "tf_wearable_demoshield") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			RemoveEdict(iEntity);
		}
	}

	while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable")) != -1)
	{
		if (IsClassname(iEntity, "tf_wearable") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient &&
			(GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 57			//Razrorback
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 231		//Darwin's Danger Shield
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 642		//Cozy Camper
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 133		//Gunboats
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 444		//Mantreads
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 405		//Ali Baba's Wee Booties
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 608))	//The Bootlegger
		{
			RemoveEdict(iEntity);
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
	{
		if (IsValidLivingPlayer(j)) i++;
	}
	return i;
}

void DetermineControlPoints()
{
	g_bCapturingLastPoint = false;
	g_iControlPoints = 0;

	for (int i = 0; i < sizeof(g_iControlPointsInfo); i++)
	{
		g_iControlPointsInfo[i][0] = -1;
	}

	//LogMessage("SZF: Calculating cps...");

	int iMaster = -1;

	int iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "team_control_point_master")) != -1) {
		if (IsClassname(iEntity, "team_control_point_master")) {
			iMaster = iEntity;
		}
	}

	if (iMaster <= 0)
	{
		//LogMessage("No master found");
		return;
	}

	iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "team_control_point")) != -1)
	{
		if (IsClassname(iEntity, "team_control_point") && g_iControlPoints < sizeof(g_iControlPointsInfo))
		{
			int iIndex = GetEntProp(iEntity, Prop_Data, "m_iPointIndex");
			g_iControlPointsInfo[g_iControlPoints][0] = iIndex;
			g_iControlPointsInfo[g_iControlPoints][1] = 0;
			g_iControlPoints++;

			//LogMessage("Found CP with index %d", iIndex);
		}
	}

	//LogMessage("Found a total of %d cps", g_iControlPoints);

	CheckRemainingCP();
}

void CheckRemainingCP()
{
	g_bCapturingLastPoint = false;
	if (g_iControlPoints <= 0) return;

	//LogMessage("Checking remaining CP");

	int iCaptureCount = 0;
	int iCapturing = 0;
	for (int i = 0; i < g_iControlPoints; i++)
	{
		if (g_iControlPointsInfo[i][1] >= 2) iCaptureCount++;
		if (g_iControlPointsInfo[i][1] == 1) iCapturing++;
	}

	//LogMessage("Capture count: %d, Max CPs: %d, Capturing: %d", iCaptureCount, g_iControlPoints, iCapturing);

	if (iCaptureCount == g_iControlPoints-1 && iCapturing > 0)
	{
		g_bCapturingLastPoint = true;
		PlaySoundAll(SOUND_MUSIC_LASTSTAND);
		if (!g_bSurvival && g_fZombieDamageScale >= 1.6) ZombieTank();
	}
}

bool AttemptCarryItem(int iClient)
{
	if (DropCarryingItem(iClient)) return true;

	int iTarget = GetClientPointVisible(iClient);

	char strClassname[255];
	if (iTarget > 0) GetEdictClassname(iTarget, strClassname, sizeof(strClassname));
	if (iTarget <= 0 || !(IsClassname(iTarget, "prop_physics") || IsClassname(iTarget, "prop_physics_override"))) return false;

	char strName[255];
	GetEntPropString(iTarget, Prop_Data, "m_iName", strName, sizeof(strName));
	if (!(StrContains(strName, "szf_carry", false) != -1 || StrEqual(strName, "gascan", false) || StrContains(strName, "szf_pick", false) != -1)) return false;

	g_iCarryingItem[iClient] = iTarget;
	SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 0);
	//CPrintToChat(iClient, "Picked up gas can %d", iTarget);
	AcceptEntityInput(iTarget, "DisableMotion");
	//CPrintToChat(iClient, "m_usSolidFlags: %d", GetEntProp(iTarget, Prop_Send, "m_usSolidFlags"));
	SetEntProp(iTarget, Prop_Send, "m_nSolidType", 0);

	EmitSoundToClient(iClient, "ui/item_paint_can_pickup.wav");
	PrintHintText(iClient, "Call 'MEDIC!' to drop your item!\nYou can attack while wielding an item.");
	AcceptEntityInput(iTarget, "FireUser1", iClient, iClient);
	
	// VOCALS ARE PRECACHED IN PICKUPWEAPONS.SP
	if (TF2_GetPlayerClass(iClient) == TFClass_Soldier)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_Soldier)-1);
		EmitSoundToAll(g_strCarryVO_Soldier[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (TF2_GetPlayerClass(iClient) == TFClass_Pyro)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_Pyro)-1);
		EmitSoundToAll(g_strCarryVO_Pyro[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (TF2_GetPlayerClass(iClient) == TFClass_DemoMan)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_DemoMan)-1);
		EmitSoundToAll(g_strCarryVO_DemoMan[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (TF2_GetPlayerClass(iClient) == TFClass_Engineer)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_Engineer)-1);
		EmitSoundToAll(g_strCarryVO_Engineer[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (TF2_GetPlayerClass(iClient) == TFClass_Medic)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_Medic)-1);
		EmitSoundToAll(g_strCarryVO_Medic[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (TF2_GetPlayerClass(iClient) == TFClass_Sniper)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_Sniper)-1);
		EmitSoundToAll(g_strCarryVO_Sniper[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	return true;
}

void UpdateClientCarrying(int iClient)
{
	int iTarget = g_iCarryingItem[iClient];

	//PrintCenterText(iClient, "Teleporting gas can (%d)", iTarget);

	if (iTarget <= 0) return;
	if (!(IsClassname(iTarget, "prop_physics") || IsClassname(iTarget, "prop_physics_override")))
	{
		DropCarryingItem(iClient);
		return;
	}

	//PrintCenterText(iClient, "Teleporting gas can 1");

	char strName[255];
	GetEntPropString(iTarget, Prop_Data, "m_iName", strName, sizeof(strName));
	if (!(StrContains(strName, "szf_carry", false) != -1 || StrEqual(strName, "gascan", false) || StrContains(strName, "szf_pick", false) != -1)) return;

	float vOrigin[3];
	float vAngles[3];
	float vDistance[3];
	float vEmpty[3];
	GetClientEyePosition(iClient, vOrigin);
	GetClientEyeAngles(iClient, vAngles);
	vAngles[0] = 5.0;

	vOrigin[2] -= 20.0;

	vAngles[2] += 35.0;
	AnglesToVelocity(vAngles, vDistance, 60.0);
	AddVectors(vOrigin, vDistance, vOrigin);
	TeleportEntity(iTarget, vOrigin, vAngles, vEmpty);

	//PrintCenterText(iClient, "Teleporting gas can");
}

bool DropCarryingItem(int iClient, bool bDrop = true)
{
	int iTarget = g_iCarryingItem[iClient];
	if (iTarget <= 0) return false;

	g_iCarryingItem[iClient] = -1;
	SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 1);

	if (!(IsClassname(iTarget, "prop_physics") || IsClassname(iTarget, "prop_physics_override"))) return true;

	//CPrintToChat(iClient, "Dropped gas can");
	SetEntProp(iTarget, Prop_Send, "m_nSolidType", 6);
	AcceptEntityInput(iTarget, "EnableMotion");
	AcceptEntityInput(iTarget, "FireUser2", iClient, iClient);

	if (bDrop)
	{
		float vOrigin[3];
		GetClientEyePosition(iClient, vOrigin);

		if (!IsEntityStuck(iTarget) && !ObstactleBetweenEntities(iClient, iTarget))
		{
			vOrigin[0] += 20.0;
			vOrigin[2] -= 30.0;
		}

		TeleportEntity(iTarget, vOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	return true;
}

stock void AnglesToVelocity(float fAngle[3], float fVelocity[3], float fSpeed = 1.0)
{
	fVelocity[0] = Cosine(DegToRad(fAngle[1]));
	fVelocity[1] = Sine(DegToRad(fAngle[1]));
	fVelocity[2] = Sine(DegToRad(fAngle[0])) * -1.0;

	NormalizeVector(fVelocity, fVelocity);

	ScaleVector(fVelocity, fSpeed);
}

stock bool IsEntityStuck(int iEntity)
{
	float vecMin[3];
	float vecMax[3];
	float vecOrigin[3];

	GetEntPropVector(iEntity, Prop_Send, "m_vecMins", vecMin);
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", vecMax);
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);

	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceDontHitEntity, iEntity);
	return (TR_DidHit());
}

public Action SoundHook(int clients[64], int &numClients, char sound[PLATFORM_MAX_PATH], int &Ent, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	int iClient = Ent;

	if (!IsValidClient(iClient))
	{
		return Plugin_Continue;
	}
	
	if (StrContains(sound, "vo/", false) != -1 && IsZombie(iClient))
	{
		if (StrContains(sound, "zombie_vo/", false) != -1) return Plugin_Continue; // so rage sounds (for normal & most special infected alike) don't get blocked
		
		// normal infected & kingpin(pitch only)
		if (g_iSpecialInfected[iClient] == INFECTED_NONE || g_iSpecialInfected[iClient] == INFECTED_KINGPIN)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				if (GetClientHealth(iClient) < 50 || StrContains(sound, "crticial", false) != -1)  // the typo is intended because that's how the soundfiles are named
				{
					EmitSoundToAll(g_strZombieVO_Common_Death[GetRandomInt(0, sizeof(g_strZombieVO_Common_Death) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}

				else
				{
					EmitSoundToAll(g_strZombieVO_Common_Pain[GetRandomInt(0, sizeof(g_strZombieVO_Common_Pain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}
			}

			else if (StrContains(sound, "_laugh", false) != -1 || StrContains(sound, "_no", false) != -1 || StrContains(sound, "_yes", false) != -1)
			{
				EmitSoundToAll(g_strZombieVO_Common_Mumbling[GetRandomInt(0, sizeof(g_strZombieVO_Common_Mumbling) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}

			else if (StrContains(sound, "_go", false) != -1 || StrContains(sound, "_jarate", false) != -1)
			{
				EmitSoundToAll(g_strZombieVO_Common_Shoved[GetRandomInt(0, sizeof(g_strZombieVO_Common_Shoved) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}

			else
			{
				EmitSoundToAll(g_strZombieVO_Common_Default[GetRandomInt(0, sizeof(g_strZombieVO_Common_Default) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}

			if (g_iSpecialInfected[iClient] == INFECTED_KINGPIN) pitch = 80;
		}


		// tank
		if (g_iSpecialInfected[iClient] == INFECTED_TANK)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				if (TF2_IsPlayerInCondition(iClient, TFCond_OnFire))
				{
					EmitSoundToAll(g_strZombieVO_Tank_OnFire[GetRandomInt(0, sizeof(g_strZombieVO_Tank_OnFire) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}

				else
				{
					EmitSoundToAll(g_strZombieVO_Tank_Pain[GetRandomInt(0, sizeof(g_strZombieVO_Tank_Pain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}
			}

			else
			{
				EmitSoundToAll(g_strZombieVO_Tank_Default[GetRandomInt(0, sizeof(g_strZombieVO_Tank_Default) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
		}

		// charger
		if (g_iSpecialInfected[iClient] == INFECTED_CHARGER)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				EmitSoundToAll(g_strZombieVO_Charger_Pain[GetRandomInt(0, sizeof(g_strZombieVO_Charger_Pain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}

			else
			{
				EmitSoundToAll(g_strZombieVO_Charger_Default[GetRandomInt(0, sizeof(g_strZombieVO_Charger_Default) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
		}

		// hunter
		if (g_iSpecialInfected[iClient] == INFECTED_HUNTER)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				EmitSoundToAll(g_strZombieVO_Hunter_Pain[GetRandomInt(0, sizeof(g_strZombieVO_Hunter_Pain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}

			else
			{
				EmitSoundToAll(g_strZombieVO_Hunter_Default[GetRandomInt(0, sizeof(g_strZombieVO_Hunter_Default) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
		}

		// boomer
		if (g_iSpecialInfected[iClient] == INFECTED_BOOMER)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				EmitSoundToAll(g_strZombieVO_Boomer_Pain[GetRandomInt(0, sizeof(g_strZombieVO_Boomer_Pain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}

			else
			{
				EmitSoundToAll(g_strZombieVO_Boomer_Default[GetRandomInt(0, sizeof(g_strZombieVO_Boomer_Pain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
		}

		// smoker
		if (g_iSpecialInfected[iClient] == INFECTED_SMOKER)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				EmitSoundToAll(g_strZombieVO_Smoker_Pain[GetRandomInt(0, sizeof(g_strZombieVO_Smoker_Pain) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}

			else
			{
				EmitSoundToAll(g_strZombieVO_Smoker_Default[GetRandomInt(0, sizeof(g_strZombieVO_Smoker_Default) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
		}

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

stock bool IsClassname(int iEntity, char[] strClassname)
{
	if (iEntity <= 0) return false;
	if (!IsValidEdict(iEntity)) return false;

	char strClassname2[32];
	GetEdictClassname(iEntity, strClassname2, sizeof(strClassname2));
	if (StrEqual(strClassname, strClassname2, false)) return true;

	return false;
}

stock int FindChargerTarge(int client)
{
	int edict = MaxClients+1;
	while((edict = FindEntityByClassname2(edict, "tf_wearable_demoshield")) != -1)
	{
		int idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
		if (idx == 406 && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
		{
			return edict;
		}
	}
	return -1;
}

public Action OnBroadCast(Handle event, const char[] name, bool dontBroadcast)
{
	char sound[20];
	GetEventString(event, "sound", sound, sizeof(sound));
	
	if (!strcmp(sound, "Game.YourTeamWon", false)) return Plugin_Handled;
	else if (!strcmp(sound, "Game.YourTeamLost", false)) return Plugin_Handled;
	
	return Plugin_Continue;
}

void SetNextAttack(int iClient, float flDuration = 0.0, bool bMeleeOnly = true)
{
	if (!IsValidClient(iClient)) return;

	int iWeapon;
	float flNextAttack = flDuration;

	// primary, secondary and melee
	for (int i = 0; i <= 2; i++)
	{
		if (bMeleeOnly && i < 2) continue;
		iWeapon = GetPlayerWeaponSlot(iClient, i);

		if (iWeapon > MaxClients && IsValidEntity(iWeapon))
		{
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", flNextAttack);
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", flNextAttack);
		}
	}
}

public Action OnPickup(int iEntity, int iClient)
{
	// if picker is a zombie and entity has no owner (sandvich)
	if (IsValidZombie(iClient) && GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity") == -1)
	{
		char strClassname[32];
		GetEntityClassname(iEntity, strClassname, sizeof(strClassname));
		if (StrContains(strClassname, "item_ammopack") != -1
		|| StrContains(strClassname, "item_healthkit") != -1
		|| StrEqual(strClassname, "tf_ammo_pack"))
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

stock void InitiateSurvivorTutorial(int iClient)
{
	DataPack hPack1 = new DataPack();
	CreateDataTimer(1.0, DisplayTutorialMessage, hPack1);
	hPack1.WriteCell(iClient);
	hPack1.WriteFloat(5.0);
	hPack1.WriteString("Welcome to Super Zombie Fortress!");

	DataPack hPack2 = new DataPack();
	CreateDataTimer(6.0, DisplayTutorialMessage, hPack2);
	hPack2.WriteCell(iClient);
	hPack2.WriteFloat(5.0);
	hPack2.WriteString("You are currently playing as a Survivor.");

	DataPack hPack3 = new DataPack();
	CreateDataTimer(11.0, DisplayTutorialMessage, hPack3);
	hPack3.WriteCell(iClient);
	hPack3.WriteFloat(5.0);
	hPack3.WriteString("As a Survivor, your goal is to complete the map objective.");

	DataPack hPack4 = new DataPack();
	CreateDataTimer(16.0, DisplayTutorialMessage, hPack4);
	hPack4.WriteCell(iClient);
	hPack4.WriteFloat(5.0);
	hPack4.WriteString("You may have noticed you do not have any weapons.");

	DataPack hPack5 = new DataPack();
	CreateDataTimer(21.0, DisplayTutorialMessage, hPack5);
	hPack5.WriteCell(iClient);
	hPack5.WriteFloat(5.0);
	hPack5.WriteString("You can pick up weapons by calling for medic or attacking it.");

	DataPack hPack6 = new DataPack();
	CreateDataTimer(26.0, DisplayTutorialMessage, hPack6);
	hPack6.WriteCell(iClient);
	hPack6.WriteFloat(5.0);
	hPack6.WriteString("There are normal infected but also special infected, so watch out for those!");

	DataPack hPack7 = new DataPack();
	CreateDataTimer(31.0, DisplayTutorialMessage, hPack7);
	hPack7.WriteCell(iClient);
	hPack7.WriteFloat(5.0);
	hPack7.WriteString("You can check out more information by typing '/szf' into the chat.");

	DataPack hPack8 = new DataPack();
	CreateDataTimer(36.0, DisplayTutorialMessage, hPack8);
	hPack8.WriteCell(iClient);
	hPack8.WriteFloat(5.0);
	hPack8.WriteString("Enjoy the round and good luck out there!");

	SetCookie(iClient, 1, cookieFirstTimeSurvivor);
}

stock void InitiateZombieTutorial(int iClient)
{
	DataPack hPack1 = new DataPack();
	CreateDataTimer(1.0, DisplayTutorialMessage, hPack1);
	hPack1.WriteCell(iClient);
	hPack1.WriteFloat(5.0);
	hPack1.WriteString("Welcome to Super Zombie Fortress!");

	DataPack hPack2 = new DataPack();
	CreateDataTimer(6.0, DisplayTutorialMessage, hPack2);
	hPack2.WriteCell(iClient);
	hPack2.WriteFloat(5.0);
	hPack2.WriteString("You are currently playing as a Zombie.");

	DataPack hPack3 = new DataPack();
	CreateDataTimer(11.0, DisplayTutorialMessage, hPack3);
	hPack3.WriteCell(iClient);
	hPack3.WriteFloat(5.0);
	hPack3.WriteString("As a Zombie, your goal is to kill the Survivors.");

	DataPack hPack4 = new DataPack();
	CreateDataTimer(16.0, DisplayTutorialMessage, hPack4);
	hPack4.WriteCell(iClient);
	hPack4.WriteFloat(5.0);
	hPack4.WriteString("You and your teammates may be selected to become special infected later on.");

	DataPack hPack5 = new DataPack();
	CreateDataTimer(21.0, DisplayTutorialMessage, hPack5);
	hPack5.WriteCell(iClient);
	hPack5.WriteFloat(5.0);
	hPack5.WriteString("In addition, a tank may be spawned later in the round.");

	DataPack hPack6 = new DataPack();
	CreateDataTimer(26.0, DisplayTutorialMessage, hPack6);
	hPack6.WriteCell(iClient);
	hPack6.WriteFloat(5.0);
	hPack6.WriteString("You can check out more information by typing '/szf' into the chat.");

	DataPack hPack7 = new DataPack();
	CreateDataTimer(31.0, DisplayTutorialMessage, hPack7);
	hPack7.WriteCell(iClient);
	hPack7.WriteFloat(5.0);
	hPack7.WriteString("Enjoy the round and get them!");

	SetCookie(iClient, 1, cookieFirstTimeZombie);
}

public Action DisplayTutorialMessage(Handle hTimer, DataPack iData)
{
	char strDisplay[255];
	iData.Reset();

	int iClient = iData.ReadCell();
	float flDuration = iData.ReadFloat();
	iData.ReadString(strDisplay, sizeof(strDisplay));

	if (!IsValidClient(iClient)) return;

	SetHudTextParams(-1.0, 0.32, flDuration, 100, 100, 255, 128);
	ShowHudText(iClient, 4, strDisplay);
}

// Zombie Rages
public void DoGenericRage(int iClient)
{
	int curH = GetClientHealth(iClient);
	SetEntityHealth(iClient, RoundToCeil(curH * 1.5));

	//ClientCommand(iClient, "voicemenu 2 1");

	float fClientPos[3];
	GetClientEyePosition(iClient, fClientPos);
	fClientPos[2] -= 60.0; // wheel goes down or smth, so thats why i did that i guess

	ShowParticle("spell_cast_wheel_blue", 4.0, fClientPos);
	PrintHintText(iClient, "Rage Activated!");
}

public void DoBoomerExplosion(int iClient, float flRadius)
{
	// no need to set rage cooldown: he's fucking dead LMAO
	float flClientPos[3];
	float flSurvivorPos[3];
	GetClientEyePosition(iClient, flClientPos);

	ShowParticle("asplode_hoodoo_debris", 6.0, flClientPos);
	ShowParticle("asplode_hoodoo_dust", 6.0, flClientPos);

	int iClientsTemp[MAXPLAYERS];
	int iCount = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
		{
			GetClientEyePosition(i, flSurvivorPos);
			float fDistance = GetVectorDistance(flClientPos, flSurvivorPos);
			if (fDistance <= flRadius)
			{
				float flDuration = 12.0 - (fDistance * 0.01);
				TF2_AddCondition(i, TFCond_Jarated, flDuration);
				PlaySound(i, SOUND_EVENT_JARATE, flDuration);
				
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

	if (IsPlayerAlive(iClient)) FakeClientCommandEx(iClient, "explode");
}

public void DoKingpinRage(int iClient, float flRadius)
{
	float flPosScreamer[3]; // fun fact: this is based on l4d's scrapped "screamer" special infected, which "buffed" zombies with its presence
	float flPosZombie[3];
	float flDistance;
	GetClientEyePosition(iClient, flPosScreamer);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsZombie(i))
		{
			GetClientEyePosition(i, flPosZombie);
			flDistance = GetVectorDistance(flPosScreamer, flPosZombie);
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
	char strPath[64];
	Format(strPath, sizeof(strPath), "ambient/halloween/male_scream_%i.wav", GetRandomInt(18, 19));
	EmitSoundToAll(strPath, iClient, SNDLEVEL_AIRCRAFT);

	//g_bHopperIsUsingPounce[iClient] = true;
	CreateTimer(0.3, SetHunterJump, iClient);

	float flVelocity[3];
	float flEyeAngles[3];

	GetClientEyeAngles(iClient, flEyeAngles);

	flVelocity[0] = Cosine(DegToRad(flEyeAngles[0])) * Cosine(DegToRad(flEyeAngles[1])) * 920;
	flVelocity[1] = Cosine(DegToRad(flEyeAngles[0])) * Sine(DegToRad(flEyeAngles[1])) * 920;
	flVelocity[2] = 460.0;

	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, flVelocity);
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	if (IsValidLivingZombie(iClient))
	{
		// smoker
		if (g_iSpecialInfected[iClient] == INFECTED_SMOKER)
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

		// stalker
		if (g_iSpecialInfected[iClient] == INFECTED_STALKER)
		{
			// to prevent fuckery with cloaking
			if (iButtons & IN_ATTACK2)
			{
				iButtons &= ~IN_ATTACK2;
			}
		}
	}
	
	// if an item was succesfully grabbed
	if ((iButtons & IN_ATTACK || iButtons & IN_ATTACK2) && AttemptGrabItem(iClient))
	{
		// block the primary or secondary attack
		iButtons &= ~IN_ATTACK;
		iButtons &= ~IN_ATTACK2;
	}

	return Plugin_Continue;
}

public void DoSmokerBeam(int iClient)
{
	float vOrigin[3], vAngles[3], vEndOrigin[3], vHitPos[3];
	GetClientEyePosition(iClient, vOrigin);
	GetClientEyeAngles(iClient, vAngles);

	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_ALL, RayType_Infinite, TraceDontHitEntity, iClient);
	TR_GetEndPosition(vEndOrigin, hTrace);

	// 750 in L4D2, scaled to TF2 player hull sizing (32hu -> 48hu)
	if (GetVectorDistance(vOrigin, vEndOrigin) > 1150.0) return;
	
	// Smoker's tongue beam
	// Beam that gets sent to all other clients
	TE_SetupBeamPoints(vOrigin, vEndOrigin, g_iSprite, 0, 0, 0, 0.08, 5.0, 5.0, 10, 0.0, { 255, 255, 255, 255 }, 0);
	int iTotal = 0;
	int[] iClients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && i != iClient)
		{
			iClients[iTotal++] = i;
		}
	}
	TE_Send(iClients, iTotal);
	
	// Send a different beam to smoker
	float newOrigin[3];
	newOrigin[0] = vOrigin[0];
	newOrigin[1] = vOrigin[1];
	newOrigin[2] = vOrigin[2] - 7.0;
	TE_SetupBeamPoints(newOrigin, vEndOrigin, g_iSprite, 0, 0, 0, 0.08, 2.0, 5.0, 10, 0.0, { 255, 255, 255, 255 }, 0);
	TE_SendToClient(iClient);

	int iHit = TR_GetEntityIndex(hTrace);

	if (	TR_DidHit(hTrace)
			&& IsValidLivingSurvivor(iHit) 
			&& !TF2_IsPlayerInCondition(iHit, TFCond_Dazed)		)
	{
		// calculate pull velocity towards Smoker
		if (!g_bBackstabbed[iClient])
		{
			float vVelocity[3];
			GetClientAbsOrigin(iHit, vHitPos);
			MakeVectorFromPoints(vOrigin, vHitPos, vVelocity);
			NormalizeVector(vVelocity, vVelocity);
			ScaleVector(vVelocity, fMin(-450.0 + GetClientHealth(iHit), -10.0) );
			TeleportEntity(iHit, NULL_VECTOR, NULL_VECTOR, vVelocity);
		}

		// if target changed, change stored target AND reset beam hit count
		if (g_iSmokerBeamHitVictim[iClient] != iHit)
		{
			g_iSmokerBeamHitVictim[iClient] = iHit;
			g_iSmokerBeamHits[iClient] = 0;
		}

		// increase count and if it reaches a threshold, apply damage
		g_iSmokerBeamHits[iClient]++;
		if (g_iSmokerBeamHits[iClient] == 5)
		{
			DealDamage(iClient, iHit, 2.0); // do damage
			g_iSmokerBeamHits[iClient] = 0;
		}

		Shake(iHit, 4.0, 0.2); // shake effect
	}

	delete view_as<Handle>(hTrace);
}


public Action SetHunterJump(Handle timer, any iClient)
{
	if (IsValidLivingZombie(iClient))
	{
		g_bHopperIsUsingPounce[iClient] = true;
	}

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
	if(g_hSDKGetMaxHealth == null)
	{
		LogMessage("Failed to create call: CTFPlayer::GetMaxHealth!");
	}

	delete hGameData;
	
	hGameData = LoadGameConfigFile("szf");

	//This function is used to get weapon max ammo
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxAmmo = EndPrepSDKCall();
	if(g_hSDKGetMaxAmmo == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo!");
	
	// This function is used to equip wearables 
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKEquipWearable = EndPrepSDKCall();
	if (g_hSDKEquipWearable == null)
		LogMessage("Failed to create call: CBasePlayer::EquipWearable!");

	// This function is used to remove a player wearable properly
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBasePlayer::RemoveWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKRemoveWearable = EndPrepSDKCall();
	if (g_hSDKRemoveWearable == null)
		LogMessage("Failed to create call: CBasePlayer::RemoveWearable!");

	// This function is used to get wearable equipped in loadout slots
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
	if (g_hSDKGetMaxHealth != INVALID_HANDLE) return SDKCall(g_hSDKGetMaxHealth, iClient);
	return 0;
}

stock int SDK_GetMaxAmmo(int iClient, int iSlot)
{
	if(g_hSDKGetMaxAmmo != null)
		return SDKCall(g_hSDKGetMaxAmmo, iClient, iSlot, -1);
	return -1;
}

stock void SDK_EquipWearable(int client, int iWearable)
{
	if (g_hSDKEquipWearable != null)
		SDKCall(g_hSDKEquipWearable, client, iWearable);
}
stock void SDK_RemoveWearable(int client, int iWearable)
{
	if (g_hSDKRemoveWearable != null)
		SDKCall(g_hSDKRemoveWearable, client, iWearable);
}
stock int SDK_GetEquippedWearable(int client, int iSlot)
{
	if (g_hSDKGetEquippedWearable != null)
		return SDKCall(g_hSDKGetEquippedWearable, client, iSlot);
	
	return -1;
}

stock void SetBackstabState(int iClient, float flDuration = BACKSTABDURATION_FULL, float flSlowdown = 0.5)
{
	if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
	{
		int iSurvivors = GetSurvivorCount();
		int iZombies = GetZombieCount();

		// reduce backstab duration if:
		// 3 or less survivors are left while there are 12 or more zombies
		// there are 24 or more zombies
		// zombie damage scale is 50% or lower
		// victim has the defense buff
		if ( flDuration > BACKSTABDURATION_REDUCED && (
				( iSurvivors <= 3 && iZombies >= 12 )
				|| iZombies >= 24
				|| g_fZombieDamageScale <= 0.5
				|| TF2_IsPlayerInCondition(iClient, TFCond_DefenseBuffed) ) )
		{
			flDuration = BACKSTABDURATION_REDUCED;
		}

		TF2_StunPlayer(iClient, flDuration, flSlowdown, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_SLOWDOWN, 0);
		g_bBackstabbed[iClient] = true;
		ClientCommand(iClient, "r_screenoverlay\"debug/yuv\"");
		PlaySound(iClient, SOUND_EVENT_NEARDEATH, flDuration);
		CreateTimer(flDuration, RemoveBackstab, iClient); // removes overlay and backstate state
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
	zf_survivorMorale[iClient] = zf_survivorMorale[iClient] + iAmount;
	
	if (zf_survivorMorale[iClient] > 100) zf_survivorMorale[iClient] = 100;
	if (zf_survivorMorale[iClient] < 0) zf_survivorMorale[iClient] = 0;
}

stock void AddMoraleAll(int iAmount)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i))
		{
			AddMorale(i, iAmount);
		}
	}
}

stock void SetMorale(int iClient, int iAmount)
{
	zf_survivorMorale[iClient] = iAmount;
}

stock void SetMoraleAll(int iAmount)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i))
		{
			SetMorale(i, iAmount);
		}
	}
}

stock int GetMorale(int iClient)
{
	return zf_survivorMorale[iClient];
}
