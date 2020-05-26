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

#undef REQUIRE_EXTENSIONS
#tryinclude <tf2items>
#define REQUIRE_EXTENSIONS

#pragma newdecls required

#include "include/superzombiefortress.inc"

#define PLUGIN_VERSION				"4.0.0"
#define PLUGIN_VERSION_REVISION		"manual"

#define TF_MAXPLAYERS		34	//32 clients + 1 for 0/world/console + 1 for replay/SourceTV

#define BACKSTABDURATION_FULL		5.5
#define BACKSTABDURATION_REDUCED	3.5
#define STUNNED_DAMAGE_CAP			10.0

#define ATTRIB_VISION		406

// Also used in the item schema to define vision filter or vision mode opt in
#define TF_VISION_FILTER_NONE		0
#define TF_VISION_FILTER_PYRO		(1<<0)	// 1
#define TF_VISION_FILTER_HALLOWEEN	(1<<1)	// 2
#define TF_VISION_FILTER_ROME		(1<<2)	// 4

enum
{
	VISION_MODE_NONE = 0,
	VISION_MODE_PYRO,
	VISION_MODE_HALLOWEEN,
	VISION_MODE_ROME,

	MAX_VISION_MODES
};

// entity effects
enum
{
	EF_BONEMERGE			= 0x001,	// Performs bone merge on client side
	EF_BRIGHTLIGHT 			= 0x002,	// DLIGHT centered at entity origin
	EF_DIMLIGHT 			= 0x004,	// player flashlight
	EF_NOINTERP				= 0x008,	// don't interpolate the next frame
	EF_NOSHADOW				= 0x010,	// Don't cast no shadow
	EF_NODRAW				= 0x020,	// don't draw entity
	EF_NORECEIVESHADOW		= 0x040,	// Don't receive no shadow
	EF_BONEMERGE_FASTCULL	= 0x080,	// For use with EF_BONEMERGE. If this is set, then it places this ent's origin at its
										// parent and uses the parent's bbox + the max extents of the aiment.
										// Otherwise, it sets up the parent's bones every frame to figure out where to place
										// the aiment, which is inefficient because it'll setup the parent's bones even if
										// the parent is not in the PVS.
	EF_ITEM_BLINK			= 0x100,	// blink an item so that the user notices it.
	EF_PARENT_ANIMATES		= 0x200,	// always assume that the parent entity is animating
	EF_MAX_BITS = 10
};

// Spectator Movement modes
enum
{
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_POI,		// PASSTIME point of interest - game objective, big fight, anything interesting; added in the middle of the enum due to tons of hard-coded "<ROAMING" enum compares
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES,
};

enum PlayerAnimEvent_t
{
	PLAYERANIMEVENT_ATTACK_PRIMARY,
	PLAYERANIMEVENT_ATTACK_SECONDARY,
	PLAYERANIMEVENT_ATTACK_GRENADE,
	PLAYERANIMEVENT_RELOAD,
	PLAYERANIMEVENT_RELOAD_LOOP,
	PLAYERANIMEVENT_RELOAD_END,
	PLAYERANIMEVENT_JUMP,
	PLAYERANIMEVENT_SWIM,
	PLAYERANIMEVENT_DIE,
	PLAYERANIMEVENT_FLINCH_CHEST,
	PLAYERANIMEVENT_FLINCH_HEAD,
	PLAYERANIMEVENT_FLINCH_LEFTARM,
	PLAYERANIMEVENT_FLINCH_RIGHTARM,
	PLAYERANIMEVENT_FLINCH_LEFTLEG,
	PLAYERANIMEVENT_FLINCH_RIGHTLEG,
	PLAYERANIMEVENT_DOUBLEJUMP,

	// Cancel.
	PLAYERANIMEVENT_CANCEL,
	PLAYERANIMEVENT_SPAWN,

	// Snap to current yaw exactly
	PLAYERANIMEVENT_SNAP_YAW,

	PLAYERANIMEVENT_CUSTOM,				// Used to play specific activities
	PLAYERANIMEVENT_CUSTOM_GESTURE,
	PLAYERANIMEVENT_CUSTOM_SEQUENCE,	// Used to play specific sequences
	PLAYERANIMEVENT_CUSTOM_GESTURE_SEQUENCE,

	// TF Specific. Here until there's a derived game solution to this.
	PLAYERANIMEVENT_ATTACK_PRE,
	PLAYERANIMEVENT_ATTACK_POST,
	PLAYERANIMEVENT_GRENADE1_DRAW,
	PLAYERANIMEVENT_GRENADE2_DRAW,
	PLAYERANIMEVENT_GRENADE1_THROW,
	PLAYERANIMEVENT_GRENADE2_THROW,
	PLAYERANIMEVENT_VOICE_COMMAND_GESTURE,
	PLAYERANIMEVENT_DOUBLEJUMP_CROUCH,
	PLAYERANIMEVENT_STUN_BEGIN,
	PLAYERANIMEVENT_STUN_MIDDLE,
	PLAYERANIMEVENT_STUN_END,
	PLAYERANIMEVENT_PASSTIME_THROW_BEGIN,
	PLAYERANIMEVENT_PASSTIME_THROW_MIDDLE,
	PLAYERANIMEVENT_PASSTIME_THROW_END,
	PLAYERANIMEVENT_PASSTIME_THROW_CANCEL,

	PLAYERANIMEVENT_ATTACK_PRIMARY_SUPER,

	PLAYERANIMEVENT_COUNT
};

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
	Infected_Unknown = -1,
	Infected_None,
	Infected_Tank,
	Infected_Boomer,
	Infected_Charger,
	Infected_Screamer,
	Infected_Stalker,
	Infected_Hunter,
	Infected_Smoker,
	Infected_Spitter,
	Infected_Jockey,
}

enum struct WeaponClasses
{
	int iIndex;
	char sClassname[256];
	char sAttribs[256];
	int iWeaponId;
	char sLogName[64];
	char sIconName[64];
}

enum struct ClientClasses
{
	//Survivor, Zombie and Infected
	bool bEnabled;
	int iHealth;
	int iRegen;
	
	//Survivor
	int iAmmo;
	
	//Zombie and Infected
	int iDegen;
	ArrayList aWeapons;
	float flSpree;
	float flHorde;
	float flMaxSpree;
	float flMaxHorde;
	float flMoraleValue;
	bool bGlow;
	bool bThirdperson;
	int iColor[4];
	char sMessage[64];
	char sMenu[64];
	char sWorldModel[PLATFORM_MAX_PATH];
	char sViewModel[PLATFORM_MAX_PATH];
	float vecViewModelAngles[3];
	float flViewModelHeight;
	char sSoundSpawn[PLATFORM_MAX_PATH];
	int iRageCooldown;
	Function callback_spawn;
	Function callback_rage;
	Function callback_think;
	Function callback_touch;
	Function callback_anim;
	Function callback_death;
	
	//Infected
	TFClassType iInfectedClass;
	
	bool GetWeapon(int &iPos, WeaponClasses weapon)
	{
		if (!this.aWeapons || iPos < 0 || iPos >= this.aWeapons.Length)
			return false;
		
		this.aWeapons.GetArray(iPos, weapon);
		
		iPos++;
		return true;
	}
}

ClientClasses g_ClientClasses[TF_MAXPLAYERS];

SZFRoundState g_nRoundState = SZFRoundState_Setup;

Infected g_nInfected[TF_MAXPLAYERS];
Infected g_nNextInfected[TF_MAXPLAYERS];

TFTeam TFTeam_Zombie = TFTeam_Blue;
TFTeam TFTeam_Survivor = TFTeam_Red;

TFClassType g_iClassDisplay[] = {
	TFClass_Unknown,
	TFClass_Scout,
	TFClass_Soldier,
	TFClass_Pyro,
	TFClass_DemoMan,
	TFClass_Heavy,
	TFClass_Engineer,
	TFClass_Medic,
	TFClass_Sniper,
	TFClass_Spy,
};

char g_sClassNames[view_as<int>(TFClassType)][] = {
	"",
	"Scout",
	"Sniper",
	"Soldier",
	"Demoman",
	"Medic",
	"Heavy",
	"Pyro",
	"Spy",
	"Engineer",
};

char g_sInfectedNames[view_as<int>(Infected)][] = {
	"None",
	"Tank",
	"Boomer",
	"Charger",
	"Screamer",
	"Stalker",
	"Hunter",
	"Smoker",
	"Spitter",
	"Jockey",
};

Cookie g_cFirstTimeSurvivor;
Cookie g_cFirstTimeZombie;
Cookie g_cNoMusicForPlayer;
Cookie g_cForceZombieStart;

//Global State
bool g_bEnabled;
bool g_bNewRound;
bool g_bFirstRound = true;
bool g_bLastSurvivor;
bool g_bTF2Items;
bool g_bGiveNamedItemSkip;

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

bool g_bStartedAsZombie[TF_MAXPLAYERS];
float g_flStopChatSpam[TF_MAXPLAYERS];
bool g_bWaitingForTeamSwitch[TF_MAXPLAYERS];

int g_iSprite; //Smoker beam

//Global Timer Handles
Handle g_hTimerMain;
Handle g_hTimerMoraleDecay;
Handle g_hTimerMainSlow;
Handle g_hTimerHoarde;
Handle g_hTimerDataCollect;
Handle g_hTimerProgress;

//Cvar Handles
ConVar g_cvForceOn;
ConVar g_cvRatio;
ConVar g_cvTankHealth;
ConVar g_cvTankHealthMin;
ConVar g_cvTankHealthMax;
ConVar g_cvTankTime;
ConVar g_cvFrenzyChance;
ConVar g_cvFrenzyTankChance;

float g_flZombieDamageScale = 1.0;

ArrayList g_aFastRespawn;

bool g_bBackstabbed[TF_MAXPLAYERS];

int g_iDamageZombie[TF_MAXPLAYERS];
int g_iDamageTakenLife[TF_MAXPLAYERS];
int g_iDamageDealtLife[TF_MAXPLAYERS];

float g_flDamageDealtAgainstTank[TF_MAXPLAYERS];
bool g_bTankRefreshed;

int g_iControlPointsInfo[20][2];
int g_iControlPoints;
bool g_bCapturingLastPoint;
int g_iCarryingItem[TF_MAXPLAYERS] = -1;

float g_flTimeProgress;

float g_flTankCooldown;
float g_flRageCooldown;
float g_flRageRespawnStress;
float g_flInfectedCooldown[view_as<int>(Infected)];	//GameTime
int g_iInfectedCooldown[view_as<int>(Infected)];	//Client who started the cooldown
float g_flSelectSpecialCooldown;
int g_iStartSurvivors;

bool g_bZombieRage;
bool g_bZombieRageAllowRespawn;

bool g_bSpawnAsSpecialInfected[TF_MAXPLAYERS];
int g_iKillsThisLife[TF_MAXPLAYERS];
int g_iMaxHealth[TF_MAXPLAYERS];
bool g_bShouldBacteriaPlay[TF_MAXPLAYERS] = true;
bool g_bReplaceRageWithSpecialInfectedSpawn[TF_MAXPLAYERS];
float g_flTimeStartAsZombie[TF_MAXPLAYERS];
bool g_bForceZombieStart[TF_MAXPLAYERS];

//Map overwrites
float g_flCapScale = -1.0;
bool g_bSurvival;
bool g_bNoMusic;
bool g_bNoDirectorTanks;
bool g_bNoDirectorRages;
bool g_bDirectorSpawnTeleport;

//Cookies
Cookie g_cWeaponsPicked;
Cookie g_cWeaponsRarePicked;
Cookie g_cWeaponsCalled;

#include "szf/weapons.sp"
#include "szf/sound.sp"

#include "szf/classes.sp"
#include "szf/command.sp"
#include "szf/config.sp"
#include "szf/console.sp"
#include "szf/convar.sp"
#include "szf/dhook.sp"
#include "szf/event.sp"
#include "szf/forward.sp"
#include "szf/infected.sp"
#include "szf/menu.sp"
#include "szf/native.sp"
#include "szf/pickupweapons.sp"
#include "szf/sdkcall.sp"
#include "szf/sdkhook.sp"
#include "szf/stocks.sp"
#include "szf/viewmodel.sp"

public Plugin myinfo =
{
	name = "Super Zombie Fortress",
	author = "42, Sasch, Benoist3012, Haxton Sale, Frosty Scales, MekuCube (original)",
	description = "Originally based off MekuCube's 1.05 version.",
	version = PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION,
	url = "https://github.com/redsunservers/SuperZombieFortress"
}

////////////////////////////////////////////////////////////
//
// Sourcemod Callbacks
//
////////////////////////////////////////////////////////////

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	Forward_AskLoad();
	Native_AskLoad();
	
	RegPluginLibrary("superzombiefortress");
}

public void OnPluginStart()
{
	//Add server tag.
	AddServerTag("zf");
	AddServerTag("szf");
	
	LoadTranslations("superzombiefortress.phrases");
	
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
	
	AddNormalSoundHook(SoundHook);
	
	HookEntityOutput("logic_relay", "OnTrigger", OnRelayTrigger);
	HookEntityOutput("math_counter", "OutValue", OnCounterValue);
	
	g_cFirstTimeZombie = new Cookie("szf_firsttimezombie", "is this the flowey map?", CookieAccess_Protected);
	g_cFirstTimeSurvivor = new Cookie("szf_firsttimesurvivor2", "is this the flowey map?", CookieAccess_Protected);
	g_cNoMusicForPlayer = new Cookie("szf_musicpreference", "is this the flowey map?", CookieAccess_Protected);
	g_cForceZombieStart = new Cookie("szf_forcezombiestart", "is this the flowey map?", CookieAccess_Protected);
	
	g_bTF2Items = LibraryExists("TF2Items");
	
	GameData hSDKHooks = new GameData("sdkhooks.games");
	if (!hSDKHooks)
		SetFailState("Could not find sdkhooks.games gamedata!");
	
	GameData hTF2 = new GameData("sm-tf2.games");
	if (!hTF2)
		SetFailState("Could not find sm-tf2.games gamedata!");
	
	GameData hSZF = new GameData("szf");
	if (!hSZF)
		SetFailState("Could not find szf gamedata!");
	
	DHook_Init(hSZF);
	SDKCall_Init(hSDKHooks, hTF2, hSZF);
	
	delete hSDKHooks;
	delete hTF2;
	delete hSZF;
	
	Command_Init();
	Config_Init();
	Console_Init();
	ConVar_Init();
	Event_Init();
	Weapons_Init();
	
	//Incase of late-load
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			OnClientPutInServer(iClient);
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "TF2Items"))
	{
		g_bTF2Items = true;
		
		//We cant allow TF2Items load while GiveNamedItem already hooked due to crash
		if (DHook_IsGiveNamedItemActive())
			SetFailState("Do not load TF2Items midgame while Super Zombie Fortress is already loaded!");
	}
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "TF2Items"))
	{
		g_bTF2Items = false;
		
		//TF2Items unloaded with GiveNamedItem unhooked, we can now safely hook GiveNamedItem ourself
		for (int iClient = 1; iClient <= MaxClients; iClient++)
			if (IsClientInGame(iClient))
				DHook_HookGiveNamedItem(iClient);
	}
}

public void OnPluginEnd()
{
	TF2_EndRound(TFTeam_Zombie);
	SZFDisable();
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
			Sound_EndMusic(iClient);
	}
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
}

public void OnMapEnd()
{
	g_nRoundState = SZFRoundState_End;
	SZFDisable();
}

void GetMapSettings()
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "info_target")) != -1)
	{
		char sTargetName[64];
		GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
		
		if (StrContains(sTargetName, "szf_survivalmode", false) == 0)
			g_bSurvival = true;
		else if (StrContains(sTargetName, "szf_nomusic", false) == 0)
			g_bNoMusic = true;
		else if (StrContains(sTargetName, "szf_director_notank", false) == 0)
			g_bNoDirectorTanks = true;
		else if (StrContains(sTargetName, "szf_director_norage", false) == 0)
			g_bNoDirectorRages = true;
		else if (StrContains(sTargetName, "szf_director_spawnteleport", false) == 0)
			g_bDirectorSpawnTeleport = true;
	}
}

public void OnClientPutInServer(int iClient)
{
	CreateTimer(10.0, Timer_InitialHelp, iClient, TIMER_FLAG_NO_MAPCHANGE);
	
	DHook_HookGiveNamedItem(iClient);
	SDKHook_HookClient(iClient);
	
	g_iDamageZombie[iClient] = 0;
}

public void OnClientDisconnect(int iClient)
{
	DHook_UnhookGiveNamedItem(iClient);
	
	if (!g_bEnabled)
		return;
	
	RequestFrame(CheckZombieBypass, iClient);
	
	Sound_EndMusic(iClient);
	DropCarryingItem(iClient);
	CheckLastSurvivor(iClient);
	
	g_bWaitingForTeamSwitch[iClient] = false;
	
	Weapons_ClientDisconnect(iClient);
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrContains(sClassname, "item_healthkit") == 0 || StrContains(sClassname, "item_ammopack") == 0 || StrEqual(sClassname, "tf_ammo_pack"))
		SDKHook_HookPickup(iEntity);
	else if (StrEqual(sClassname, "tf_gas_manager"))
		SDKHook_HookGasManager(iEntity);
	else if (StrEqual(sClassname, "trigger_capture_area"))
		SDKHook_HookCaptureArea(iEntity);
	else if (StrEqual(sClassname, "tf_dropped_weapon") || StrEqual(sClassname, "item_powerup_rune"))	//Never allow dropped weapon and rune dropped from survivors
		RemoveEntity(iEntity);
}

public void TF2_OnWaitingForPlayersStart()
{
	if (!g_bEnabled)
		return;

	g_nRoundState = SZFRoundState_Setup;
}

public void TF2_OnWaitingForPlayersEnd()
{
	if (!g_bEnabled)
		return;

	g_nRoundState = SZFRoundState_Grace;
}

public void TF2_OnConditionAdded(int iClient, TFCond nCond)
{
	if (!g_bEnabled)
		return;
	
	SDKCall_SetSpeed(iClient);
	
	if (IsSurvivor(iClient))
	{
		switch (nCond)
		{
			case TFCond_Gas:
			{
				//Dont give gas cond from spitter
				TF2_RemoveCondition(iClient, TFCond_Gas);
			}
		}
	}
	else if (IsZombie(iClient))
	{
		switch (nCond)
		{
			case TFCond_Taunting:
			{
				//Prevents tank from getting stunned by Holiday Punch and disallows taunt kills
				if (g_nInfected[iClient] == Infected_Tank && g_nRoundState == SZFRoundState_Active)
					TF2_RemoveCondition(iClient, nCond);
			}
		}
	}
}

public void TF2_OnConditionRemoved(int iClient, TFCond nCond)
{
	SDKCall_SetSpeed(iClient);
}

public Action TF2_OnIsHolidayActive(TFHoliday nHoliday, bool &bResult)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	//Force enable full moon to allow zombie voodoo soul to work
	//Shouldnt use TFHoliday_Halloween because of souls and halloween taunt
	if (nHoliday == TFHoliday_FullMoon || nHoliday == TFHoliday_HalloweenOrFullMoon || nHoliday == TFHoliday_HalloweenOrFullMoonOrValentines)
	{
		bResult = true;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

void EndGracePeriod()
{
	if (!g_bEnabled)
		return;
	
	if (g_nRoundState != SZFRoundState_Grace)
		return; //No point in ending grace period if it's not grace period it in the first place.
	
	g_nRoundState = SZFRoundState_Active;
	CPrintToChatAll("%t", "Grace_End", "{orange}");
	
	//Disable func_respawnroom so clients dont accidentally respawn and join zombie
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "func_respawnroom")) != -1)
	{
		if (view_as<TFTeam>(GetEntProp(iEntity, Prop_Send, "m_iTeamNum")) == TFTeam_Survivor)
			RemoveEntity(iEntity);
	}
	
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
				
				CPrintToChat(iClient, "%t", "Grace_InfectedBoost", (IsZombie(iClient)) ? "{green}" : "{red}");
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

////////////////////////////////////////////////////////////
//
// Periodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action Timer_Main(Handle hTimer) //1 second
{
	if (!g_bEnabled)
		return;
	
	Handle_SurvivorAbilities();
	Handle_ZombieAbilities();
	UpdateZombieDamageScale();
	Sound_Timer();
	
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
				//If no special select cooldown is active and less than 2 people have been selected for the respawn into special infected
				//AND
				//damage scale is 120% and a dice roll is hit OR the damage scale is 160%
				if ( g_nRoundState == SZFRoundState_Active 
					&& g_flSelectSpecialCooldown <= GetGameTime() 
					&& GetReplaceRageWithSpecialInfectedSpawnCount() <= 2 
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
					CPrintToChat(iClient, "%t", "Infected_SelectedRespawn", "{green}", "{orange}");
				}
			}
		}
	}
}

public Action Timer_MoraleDecay(Handle hTimer) //Timer scales based on how many zombies, slow if low zombies, fast if high zombies
{
	if (!g_bEnabled)
		return Plugin_Stop;
	
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
	if (!g_bEnabled)
		return Plugin_Stop;
	
	PrintInfoChat(0);
	
	return Plugin_Continue;
}

public Action Timer_Hoarde(Handle hTimer) //5 seconds
{
	if (!g_bEnabled)
		return Plugin_Stop;
	
	Handle_HoardeBonus();
	
	return Plugin_Continue;
}

public Action Timer_Datacollect(Handle hTimer) //2 seconds
{
	if (!g_bEnabled)
		return Plugin_Stop;
	
	FastRespawnDataCollect();
	
	return Plugin_Continue;
}

public Action Timer_Progress(Handle hTimer) //6 seconds
{
	if (g_hTimerProgress != hTimer)
		return Plugin_Stop;
	
	if (!g_bEnabled)
		return Plugin_Stop;
	
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
		RemoveEntity(iEntity);
	
	//Remove all ragdolls.
	iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "tf_ragdoll")) != -1)
		RemoveEntity(iEntity);
	
	//Disable all payload cart dispensers.
	iEntity = -1;
	while((iEntity = FindEntityByClassname(iEntity, "mapobj_cart_dispenser")) != -1)
		SetEntProp(iEntity, Prop_Send, "m_bDisabled", 1);
	
	Sound_PlayMusicToTeam(TFTeam_Survivor, "start");
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

public Action Timer_Zombify(Handle hTimer, int iClient)
{
	if (g_nRoundState != SZFRoundState_Active)
		return Plugin_Continue;
	
	if (IsValidClient(iClient))
	{
		CPrintToChat(iClient, "%t", "Infected_Zombify", "{red}");
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
	if (!g_bEnabled)
		return;
	
	int iCount = GetSurvivorCount();
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_nRoundState == SZFRoundState_Active)
		{
			//Last man gets minicrit boost if 6 players ingame
			if (iCount == 1 && IsValidLivingSurvivor(iClient) && GetActivePlayerCount() >= 6)
				TF2_AddCondition(iClient, TFCond_Buffed, 0.05);
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
			int iMaxHealth = SDKCall_GetMaxHealth(iClient);
			if (iHealth < iMaxHealth)
			{
				iHealth += g_ClientClasses[iClient].iRegen;
				
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
			if (iMorale > 50)	//50: defense buff
				TF2_AddCondition(iClient, TFCond_DefenseBuffed, 1.1);
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
	int iHealth;
	int iMaxHealth;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidLivingZombie(iClient) && g_nInfected[iClient] != Infected_Tank)
		{
			iHealth = GetClientHealth(iClient);
			iMaxHealth = SDKCall_GetMaxHealth(iClient);
			
			//1. Handle zombie regeneration.
			//       Zombies regenerate health based on class and number of nearby
			//       zombies (hoarde bonus). Zombies decay health when overhealed.
			if (iHealth < iMaxHealth)
			{
				iHealth += g_ClientClasses[iClient].iRegen;
				
				//Handle additional regeneration
				iHealth += 1 * g_iHorde[iClient]; //Horde bonus
				
				if (g_bZombieRage)
					iHealth += 3; //Zombie rage
				
				if (TF2_IsPlayerInCondition(iClient, TFCond_TeleportedGlow))
					iHealth += 2; //Screamer
				
				iHealth = min(iHealth, iMaxHealth);
				SetEntityHealth(iClient, iHealth);
			}
			else if (iHealth > iMaxHealth)
			{
				iHealth -= g_ClientClasses[iClient].iDegen;
				iHealth = max(iHealth, iMaxHealth);
				SetEntityHealth(iClient, iHealth);
			}
			
			//2.1. Handle fast respawn into special infected HUD message
			if (g_nRoundState == SZFRoundState_Active && g_bReplaceRageWithSpecialInfectedSpawn[iClient])
			{
				PrintHintText(iClient, "%t", "Infected_CallMedic");
			}
			//2.2. Handle zombie rage timer
			//       Rage recharges every 20(special)/30(normal) seconds.
			else if (g_iRageTimer[iClient] > 0)
			{
				if (g_iRageTimer[iClient] == 1) PrintHintText(iClient, "%t", "Infected_RageReady");
				if (g_iRageTimer[iClient] == 6) PrintHintText(iClient, "%t", "Infected_RageReadyInSec", 5);
				if (g_iRageTimer[iClient] == 11) PrintHintText(iClient, "%t", "Infected_RageReadyInSec", 10);
				if (g_iRageTimer[iClient] == 21) PrintHintText(iClient, "%t", "Infected_RageReadyInSec", 20);
				if (g_iRageTimer[iClient] == 31) PrintHintText(iClient, "%t", "Infected_RageReadyInSec", 30);
				
				g_iRageTimer[iClient]--;
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
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		ResetClientState(iClient);
	
	ConVar_Enable();
	
	//[Re]Enable periodic timers.
	delete g_hTimerMain;
	g_hTimerMain = CreateTimer(1.0, Timer_Main, _, TIMER_REPEAT);
	
	delete g_hTimerMoraleDecay;
	g_hTimerMoraleDecay = CreateTimer(1.0, Timer_MoraleDecay);	//Timer inside will call itself for loops
	
	delete g_hTimerMainSlow;
	g_hTimerMainSlow = CreateTimer(240.0, Timer_MainSlow, _, TIMER_REPEAT);
	
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
	
	ConVar_Disable();
	
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

void ResetClientState(int iClient)
{
	g_iMorale[iClient] = 0;
	g_iHorde[iClient] = 0;
	g_iCapturingPoint[iClient] = -1;
	g_iRageTimer[iClient] = 0;
}

void PrintInfoChat(int iClient)
{
	char sMessage[256];
	Format(sMessage, sizeof(sMessage), "%t", "Welcome", "{lightsalmon}", "{limegreen}", "{lightsalmon}");
	
	if (iClient == 0)
		CPrintToChatAll(sMessage);
	else
		CPrintToChat(iClient, sMessage);
}

void SetGlow()
{
	int iCount = GetSurvivorCount();
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidLivingClient(iClient))
		{
			bool bGlow = false;
			
			if (IsSurvivor(iClient))
			{
				if (1 <= iCount <= 3)
					bGlow = true;
				else if (GetClientHealth(iClient) <= 30)
					bGlow = true;
				else if (g_bBackstabbed[iClient])
					bGlow = true;
			}
			else if (g_ClientClasses[iClient].bGlow)
			{
				bGlow = true;
			}
			
			SetEntProp(iClient, Prop_Send, "m_bGlowEnabled", bGlow);
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

void UpdateZombieDamageScale()
{
	g_flZombieDamageScale = 1.0;
	
	if (g_iStartSurvivors <= 0 || !g_bEnabled || g_nRoundState != SZFRoundState_Active)
		return;
	
	int iSurvivors = GetSurvivorCount();
	if (iSurvivors < 1)
		iSurvivors = 1; //Division by 0 error
	
	int iZombies = GetZombieCount();
	if (iZombies < 1)
		iZombies = 1; //Division by 0 error
	
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
	if (g_bSurvival)
		g_flZombieDamageScale += fMax(0.0, (iSurvivors / iZombies / 30) + 0.08); //28-4 = +0.213, 16-16 = +0.113
	
	//If the last point is being captured, set the damage scale to 110% if lower than 110%
	if (g_bCapturingLastPoint && g_flZombieDamageScale < 1.1 && !g_bSurvival)
		g_flZombieDamageScale = 1.1;
	
	//Post-calculation
	if (g_flZombieDamageScale < 1.0)
		g_flZombieDamageScale *= g_flZombieDamageScale;
	
	if (g_flZombieDamageScale < 0.33)
		g_flZombieDamageScale = 0.33;
	
	if (g_flZombieDamageScale > 3.0)
		g_flZombieDamageScale = 3.0;
	
	//Not survival, no rage and no active tank
	if (!g_bSurvival && !g_bZombieRage && !ZombiesTankComing() && !ZombiesHaveTank())
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

public Action Timer_RespawnPlayer(Handle hTimer, int iClient)
{
	if (IsClientInGame(iClient) && !IsPlayerAlive(iClient))
		TF2_RespawnPlayer2(iClient);
}

void CheckLastSurvivor(int iIgnoredClient = 0)
{
	if (g_bLastSurvivor)
		return;
	
	int iLastSurvivor;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (iClient != iIgnoredClient && IsValidLivingSurvivor(iClient))
		{
			if (iLastSurvivor)	//More than 1 survivors
				return;
			
			iLastSurvivor = iClient;
		}
	}
	
	if (!iLastSurvivor)
		return;
	
	TF2_AddCondition(iLastSurvivor, TFCond_KingRune, TFCondDuration_Infinite);
	SetEntityHealth(iLastSurvivor, SDKCall_GetMaxHealth(iLastSurvivor));
	
	g_bLastSurvivor = true;
	SetMorale(iLastSurvivor, 100);
	
	char sName[255];
	GetClientName2(iLastSurvivor, sName, sizeof(sName));
	CPrintToChatAllEx(iLastSurvivor, "%t", "Survivor_Last", sName, "{green}");
	
	Sound_PlayMusicToAll("laststand");
	
	Forward_OnLastSurvivor(iLastSurvivor);
}

public void OnMapStart()
{
	Config_Refresh();
	Classes_Refresh();
	Sound_Refresh();
	Weapons_Refresh();
	
	DetermineControlPoints();
	PrecacheZombieSouls();
	
	PrecacheParticle("spell_cast_wheel_blue");
	
	//Boomer
	PrecacheParticle("asplode_hoodoo_debris");
	PrecacheParticle("asplode_hoodoo_dust");
	
	//Map pickup
	PrecacheSound("ui/item_paint_can_pickup.wav");
	
	//Screamer scream
	PrecacheSound("ambient/halloween/male_scream_15.wav");
	PrecacheSound("ambient/halloween/male_scream_16.wav");
	
	//Hopper scream
	PrecacheSound("ambient/halloween/male_scream_18.wav");
	PrecacheSound("ambient/halloween/male_scream_19.wav");
	
	//Charger ka-klunk
	PrecacheSound("weapons/demo_charge_hit_flesh_range1.wav");
	
	//Smoker beam
	g_iSprite = PrecacheModel("materials/sprites/laser.vmt");
	
	DHook_HookGamerules();
	
	if (GameRules_GetRoundState() < RoundState_Preround)
		g_nRoundState = SZFRoundState_Setup;
	else	//Plugin late-load while already midgame, skip setup time
		g_nRoundState = SZFRoundState_Grace;
}

public Action OnRelayTrigger(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{
	char sTargetName[255];
	GetEntPropString(iCaller, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
	
	if(StrEqual("szf_panic_event", sTargetName))
		ZombieRage(_, true);
	else if (StrEqual("szf_zombierage", sTargetName))
		ZombieRage(_, true);
	else if (StrEqual("szf_zombietank", sTargetName))
		ZombieTank(iCaller);
	else if (StrEqual("szf_tank", sTargetName))
		ZombieTank(iCaller);
	else if (StrEqual("szf_laststand", sTargetName))
		PlaySoundAll(SoundMusic_LastStand);
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
	if (g_nRoundState != SZFRoundState_Active)
		return;
	
	if (g_bZombieRage)
		return;
	
	if (ZombiesHaveTank())
		return;
	
	if (g_bNoDirectorRages && !bIgnoreDirector)
		return;
	
	g_bZombieRage = true;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient))
			SDKCall_SetSpeed(iClient);
	
	g_flRageRespawnStress = GetGameTime();	//Set initial respawn stress
	g_bZombieRageAllowRespawn = true;
	
	if (flDuration < 20.0)
		g_bZombieRageAllowRespawn = false;
	
	CreateTimer(flDuration, Timer_StopZombieRage);
	
	if (flDuration >= 20.0)
	{
		Sound_PlayMusicToAll("frenzy");
		
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsClientInGame(iClient))
			{
				CPrintToChat(iClient, "%t", "Frenzy_Start", (IsZombie(iClient)) ? "{green}" : "{red}");
				
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
					
					if (iMorale < 0)
						iMorale = 0;
					
					SetMorale(iClient, iMorale);
				}
			}
		}
	}
	
	g_flRageCooldown = GetGameTime() + flDuration + 40.0;
	
	char sTargetName[255];
	int iEntity = MaxClients+1;
	while ((iEntity = FindEntityByClassname2(iEntity, "logic_relay")) != -1)
	{
		GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
		if (StrEqual("szf_zombierage", sTargetName) || StrEqual("szf_panic_event", sTargetName))
			AcceptEntityInput(iEntity, "FireUser1");
	}
}

public Action Timer_StopZombieRage(Handle hTimer)
{
	g_bZombieRage = false;
	UpdateZombieDamageScale();
	
	if (g_nRoundState == SZFRoundState_Active)
		for (int iClient = 1; iClient <= MaxClients; iClient++)
			if (IsClientInGame(iClient))
				CPrintToChat(iClient, "%t", "Frenzy_End", (IsZombie(iClient)) ? "{red}" : "{green}");
	
	char sTargetName[255];
	int iEntity = MaxClients+1;
	while ((iEntity = FindEntityByClassname2(iEntity, "logic_relay")) != -1)
	{
		GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
		if (StrEqual("szf_zombierage", sTargetName) || StrEqual("szf_panic_event", sTargetName))
			AcceptEntityInput(iEntity, "FireUser2");
	}
}

int FastRespawnNearby(int iClient, float flDistance, bool bMustBeInvisible = true)
{
	if (g_aFastRespawn == null)
		return -1;
	
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
					if (PointsAtTarget(vecPosEntry, iSurvivor) || PointsAtTarget(vecPosEntry2, iSurvivor))
						bAllow = false;
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
	if (iResult < 0)
		return false;
	
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

void HandleSurvivorLoadout(int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
		return;
	
	CheckClientWeapons(iClient);
	
	for (int iSlot = WeaponSlot_Melee; iSlot <= WeaponSlot_InvisWatch; iSlot++)
	{
		int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (iEntity > MaxClients)
		{
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
						TF2_RemoveWeaponSlot(iClient, iSlot);
						iEntity = TF2_CreateAndEquipWeapon(iClient, iIndex);
					}
					
					//Print text with cooldown to prevent spam
					if (g_flStopChatSpam[iClient] < GetGameTime() && !StrEqual(Melee.sText, ""))
					{
						CPrintToChat(iClient, "%t", Melee.sText);
						g_flStopChatSpam[iClient] = GetGameTime() + 1.0;
					}
					
					//Apply attribute
					char sAttribs[32][32];
					int iCount = ExplodeString(Melee.sAttrib, " ; ", sAttribs, sizeof(sAttribs), sizeof(sAttribs));
					if (iCount > 1)
						for (int j = 0; j < iCount; j+= 2)
							TF2Attrib_SetByDefIndex(iEntity, StringToInt(sAttribs[j]), StringToFloat(sAttribs[j+1]));
					
					break;
				}
			}
			
			//This will refresh health max calculation and other attributes
			TF2Attrib_ClearCache(iEntity);
		}
	}
	
	int iMelee = TF2_GetItemInSlot(iClient, WeaponSlot_Melee);
	if (iMelee > MaxClients)
	{
		AddWeaponVision(iMelee, TF_VISION_FILTER_HALLOWEEN);	//Give halloween vision
		TF2_SwitchActiveWeapon(iClient, iMelee);
	}
	
	//Reset custom models
	SetVariantString("");
	AcceptEntityInput(iClient, "SetCustomModel");
	
	//Prevent Survivors with voodoo-cursed souls
	SetEntProp(iClient, Prop_Send, "m_bForcedSkin", 0);
	SetEntProp(iClient, Prop_Send, "m_nForcedSkin", 0);
}

void HandleZombieLoadout(int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
		return;
	
	CheckClientWeapons(iClient);
	
	int iPos;
	WeaponClasses weapon;
	while (g_ClientClasses[iClient].GetWeapon(iPos, weapon))
		TF2_CreateAndEquipWeapon(iClient, weapon.iIndex, weapon.sClassname, weapon.sAttribs);
	
	if (g_ClientClasses[iClient].sWorldModel[0])
	{
		SetVariantString(g_ClientClasses[iClient].sWorldModel);
		AcceptEntityInput(iClient, "SetCustomModel");
		SetEntProp(iClient, Prop_Send, "m_bUseClassAnimations", true);
		
		//Clear voodoo-cursed soul skin
		SetEntProp(iClient, Prop_Send, "m_bForcedSkin", 0);
		SetEntProp(iClient, Prop_Send, "m_nForcedSkin", 0);
	}
	else
	{
		ApplyVoodooCursedSoul(iClient);
	}
	
	ViewModel_Destroy(iClient);
	
	if (g_ClientClasses[iClient].sViewModel[0])
		ViewModel_Create(iClient, g_ClientClasses[iClient].sViewModel, g_ClientClasses[iClient].vecViewModelAngles, g_ClientClasses[iClient].flViewModelHeight);
	
	if (g_ClientClasses[iClient].bThirdperson)
	{
		SetEntProp(GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"), Prop_Send, "m_fEffects", EF_NODRAW);
		RequestFrame(SetThirdperson, GetClientSerial(iClient));
	}
	
	//Reset metal for TF2 to give back correct amount from attribs
	TF2_SetMetal(iClient, 0);
	
	//Set active wepaon slot to melee
	int iMelee = TF2_GetItemInSlot(iClient, WeaponSlot_Melee);
	if (iMelee > MaxClients)
	{
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iMelee);
		AddWeaponVision(iMelee, TF_VISION_FILTER_HALLOWEEN);	//Allow see Voodoo souls
		AddWeaponVision(iMelee, TF_VISION_FILTER_ROME);			//Allow see spy's custom model disguise detour fix
	}
}

public void SetThirdperson(int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (IsValidLivingClient(iClient))
	{
		SetVariantInt(1);
		AcceptEntityInput(iClient, "SetForcedTauntCam");
	}
}

int GetMostDamageZom()
{
	ArrayList aClients = new ArrayList();
	int iHighest = 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient) && g_nNextInfected[iClient] != Infected_Tank && g_nInfected[iClient] != Infected_Tank && g_iDamageZombie[iClient] > iHighest)
			iHighest = g_iDamageZombie[iClient];
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient) && g_nNextInfected[iClient] != Infected_Tank && g_nInfected[iClient] != Infected_Tank && g_iDamageZombie[iClient] >= iHighest)
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

bool ZombiesHaveTank(int iIgnore = 0)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (iClient != iIgnore && IsValidLivingZombie(iClient) && g_nInfected[iClient] == Infected_Tank)
			return true;
	
	return false;
}

bool ZombiesTankComing()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient) && g_nNextInfected[iClient] == Infected_Tank)
			return true;
	
	return false;
}

void ZombieTank(int iCaller = -1)
{
	if (!g_bEnabled)
		return;
	
	if (g_nRoundState != SZFRoundState_Active)
		return;
	
	if (iCaller != -1 && g_bNoDirectorTanks)
		return;
	
	int iClient;
	if (IsValidZombie(iCaller))
		iClient = iCaller;
	else
		iClient = GetMostDamageZom();
	
	if (iClient <= 0)
		return;
	
	char sName[255];
	GetClientName2(iClient, sName, sizeof(sName));
	
	for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
		if (IsValidZombie(iTarget))
			CPrintToChatEx(iTarget, iClient, "%t", "Tank_Chosen", sName, "{green}");
	
	if (IsValidClient(iCaller))
		CPrintToChat(iCaller, "%t", "Tank_Called", "{green}");
	
	g_bReplaceRageWithSpecialInfectedSpawn[iClient] = false;
	g_nNextInfected[iClient] = Infected_Tank;
	g_flTankCooldown = GetGameTime() + 120.0; //Set new cooldown
	SetMoraleAll(0); //Tank spawn, reset morale
}

void DetermineControlPoints()
{
	g_bCapturingLastPoint = false;
	g_iControlPoints = 0;
	
	for (int i = 0; i < sizeof(g_iControlPointsInfo); i++)
		g_iControlPointsInfo[i][0] = -1;
	
	int iMaster = -1;
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "team_control_point_master")) != -1)
		iMaster = iEntity;
	
	if (iMaster <= 0)
		return;
	
	iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "team_control_point")) != -1)
	{
		if (g_iControlPoints < sizeof(g_iControlPointsInfo))
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
	
	if (g_iControlPoints <= 0)
		return;
	
	int iCaptureCount = 0;
	int iCapturing = 0;
	for (int i = 0; i < g_iControlPoints; i++)
	{
		if (g_iControlPointsInfo[i][1] >= 2)
			iCaptureCount++;
		
		if (g_iControlPointsInfo[i][1] == 1)
			iCapturing++;
	}
	
	if (iCaptureCount == g_iControlPoints-1 && iCapturing > 0)
	{
		g_bCapturingLastPoint = true;
		Sound_PlayMusicToAll("laststand");
		
		char sTargetName[255];
		int iEntity = MaxClients+1;
		while ((iEntity = FindEntityByClassname2(iEntity, "logic_relay")) != -1)
		{
			GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
			if (StrEqual("szf_laststand", sTargetName))
				AcceptEntityInput(iEntity, "FireUser2");
		}
		
		if (!g_bSurvival && g_flZombieDamageScale >= 1.6)
			ZombieTank();
	}
}

bool AttemptCarryItem(int iClient)
{
	if (DropCarryingItem(iClient))
		return true;
	
	int iTarget = GetClientPointVisible(iClient);
	if (iTarget <= 0 || !(IsClassname(iTarget, "prop_physics") || IsClassname(iTarget, "prop_physics_override")))
		return false;
	
	char sName[255];
	GetEntPropString(iTarget, Prop_Data, "m_iName", sName, sizeof(sName));
	if (!(StrContains(sName, "szf_carry", false) != -1 || StrEqual(sName, "gascan", false) || StrContains(sName, "szf_pick", false) != -1))
		return false;
	
	g_iCarryingItem[iClient] = iTarget;
	SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 0);
	AcceptEntityInput(iTarget, "DisableMotion");
	SetEntProp(iTarget, Prop_Send, "m_nSolidType", 0);
	
	EmitSoundToClient(iClient, "ui/item_paint_can_pickup.wav");
	PrintHintText(iClient, "%t", "Carry_Pickup");
	AcceptEntityInput(iTarget, "FireUser1", iClient, iClient);
	
	SetVariantString("TLK_PLAYER_MOVEUP");
	AcceptEntityInput(iClient, "SpeakResponseConcept");
	
	return true;
}

void UpdateClientCarrying(int iClient)
{
	int iTarget = g_iCarryingItem[iClient];
	if (iTarget <= 0)
		return;
	
	if (!(IsClassname(iTarget, "prop_physics") || IsClassname(iTarget, "prop_physics_override")))
	{
		DropCarryingItem(iClient);
		return;
	}
	
	char sName[255];
	GetEntPropString(iTarget, Prop_Data, "m_iName", sName, sizeof(sName));
	if (!(StrContains(sName, "szf_carry", false) != -1 || StrEqual(sName, "gascan", false) || StrContains(sName, "szf_pick", false) != -1))
		return;
	
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
	if (iTarget <= 0)
		return false;
	
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

public Action SoundHook(int iClients[64], int &iLength, char sSound[PLATFORM_MAX_PATH], int &iClient, int &iChannel, float &flVolume, int &iLevel, int &iPitch, int &iFlags)
{
	if (!IsValidClient(iClient))
		return Plugin_Continue;
	
	if (StrContains(sSound, "vo/", false) != -1 && IsZombie(iClient))
	{
		if (StrContains(sSound, "zombie_vo/", false) != -1)
			return Plugin_Continue; //So rage sounds (for normal & most special infected alike) don't get blocked
		
		if (StrContains(sSound, "_pain", false) != -1)
		{
			if (GetClientHealth(iClient) < 50 || StrContains(sSound, "crticial", false) != -1)  //The typo is intended because that's how the soundfiles are named
				if (Sound_PlayInfectedVo(iClient, g_nInfected[iClient], SoundVo_Death))
					return Plugin_Handled;
			
			if (TF2_IsPlayerInCondition(iClient, TFCond_OnFire))
				if (Sound_PlayInfectedVo(iClient, g_nInfected[iClient], SoundVo_Fire))
					return Plugin_Handled;
			
			if (Sound_PlayInfectedVo(iClient, g_nInfected[iClient], SoundVo_Pain))
				return Plugin_Handled;
		}
		else if (StrContains(sSound, "_laugh", false) != -1 || StrContains(sSound, "_no", false) != -1 || StrContains(sSound, "_yes", false) != -1)
		{
			if (Sound_PlayInfectedVo(iClient, g_nInfected[iClient], SoundVo_Mumbling))
				return Plugin_Handled;
		}
		else if (StrContains(sSound, "_go", false) != -1 || StrContains(sSound, "_jarate", false) != -1)
		{
			if (Sound_PlayInfectedVo(iClient, g_nInfected[iClient], SoundVo_Shoved))
				return Plugin_Handled;
		}
		
		//Play default vo for whatever infected
		if (Sound_PlayInfectedVo(iClient, g_nInfected[iClient], SoundVo_Default))
			return Plugin_Handled;
		
		//If sound still not found, try normal infected
		Sound_PlayInfectedVo(iClient, Infected_None, SoundVo_Default);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

void SetNextAttack(int iClient, float flDuration = 0.0, bool bMeleeOnly = true)
{
	if (!IsValidClient(iClient))
		return;
	
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

void InitiateSurvivorTutorial(int iClient)
{
	DataPack data;
	CreateDataTimer(1.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_SurvivorStart1");
	
	CreateDataTimer(6.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_SurvivorStart2");
	
	CreateDataTimer(11.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_SurvivorStart3");
	
	CreateDataTimer(16.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_SurvivorStart4");
	
	CreateDataTimer(21.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_SurvivorStart5");
	
	CreateDataTimer(26.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_SurvivorStart6");
	
	CreateDataTimer(31.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_SurvivorStart7");
	
	CreateDataTimer(36.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_SurvivorStart8");
	
	SetCookie(iClient, 1, g_cFirstTimeSurvivor);
}

void InitiateZombieTutorial(int iClient)
{
	DataPack data;
	CreateDataTimer(1.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_ZombieStart1");
	
	CreateDataTimer(6.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_ZombieStart2");
	
	CreateDataTimer(11.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_ZombieStart3");
	
	CreateDataTimer(16.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_ZombieStart4");
	
	CreateDataTimer(21.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_ZombieStart5");
	
	CreateDataTimer(26.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_ZombieStart6");
	
	CreateDataTimer(31.0, Timer_DisplayTutorialMessage, data);
	data.WriteCell(iClient);
	data.WriteFloat(5.0);
	data.WriteString("Tutorial_ZombieStart7");
	
	SetCookie(iClient, 1, g_cFirstTimeZombie);
}

public Action Timer_DisplayTutorialMessage(Handle hTimer, DataPack data)
{
	char sDisplay[255];
	data.Reset();
	
	int iClient = data.ReadCell();
	float flDuration = data.ReadFloat();
	data.ReadString(sDisplay, sizeof(sDisplay));
	
	if (!IsValidClient(iClient))
		return;
	
	SetHudTextParams(-1.0, 0.32, flDuration, 100, 100, 255, 128);
	ShowHudText(iClient, 4, "%t", sDisplay);
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	if (IsValidLivingZombie(iClient))
	{
		if (g_ClientClasses[iClient].callback_think != INVALID_FUNCTION)
		{
			Call_StartFunction(null, g_ClientClasses[iClient].callback_think);
			Call_PushCell(iClient);
			Call_PushCellRef(iButtons);
			Call_Finish();
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

void SetBackstabState(int iClient, float flDuration = BACKSTABDURATION_FULL, float flSlowdown = 0.5)
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
		Sound_PlayMusicToClient(iClient, "backstab", flDuration);
		CreateTimer(flDuration, RemoveBackstab, iClient); //Removes overlay and backstate state
	}
}

public Action RemoveBackstab(Handle hTimer, int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
		return;
	
	g_bBackstabbed[iClient] = false;
	ClientCommand(iClient, "r_screenoverlay\"\"");
	
	TF2_RemoveCondition(iClient, TFCond_Dazed);
}

Action OnGiveNamedItem(int iClient, const char[] sClassname, int iIndex)
{
	if (g_bGiveNamedItemSkip || TF2_IsPlayerInCondition(iClient, TFCond_Disguised))
		return Plugin_Continue;
	
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	TFTeam iTeam = TF2_GetClientTeam(iClient);
	int iSlot = TF2_GetItemSlot(iIndex, iClass);
	
	Action iAction = Plugin_Continue;
	if (iTeam == TFTeam_Survivor)
	{
		float flVal;
		
		if (iSlot < WeaponSlot_Melee)
		{
			iAction = Plugin_Handled;
		}
		else if (GetClassVoodooItemDefIndex(iClass) == iIndex)
		{
			//Survivors are not zombies
			iAction = Plugin_Handled;
		}
		else if (TF2_DefIndexFindAttribute(iIndex, ATTRIB_VISION, flVal) && RoundToNearest(flVal) & TF_VISION_FILTER_ROME)
		{
			//Rome vision is used for zombie custom model disguise detour fix, dont give vision to survivor
			iAction = Plugin_Handled;
		}
	}
	else if (iTeam == TFTeam_Zombie)
	{
		if (iSlot == WeaponSlot_Primary || iSlot == WeaponSlot_Melee)
		{
			iAction = Plugin_Handled;
		}
		else if (iSlot <= WeaponSlot_BuilderEngie)
		{
			if (g_nInfected[iClient] != Infected_None)
			{
				iAction = Plugin_Handled;
			}
			else
			{
				switch (iClass)
				{
					case TFClass_Scout:
					{
						//Block all secondary weapons that are not drinks
						if (StrContains(sClassname, "tf_weapon_lunchbox_drink") == -1)
							iAction = Plugin_Handled;
					}
					case TFClass_Soldier:
					{
						//Block all secondary weapons that are not banners
						if (StrContains(sClassname, "tf_weapon_buff_item") == -1)
							iAction = Plugin_Handled;
					}
					case TFClass_Heavy:
					{
						//Block all secondary weapons that are not food
						if (StrContains(sClassname, "tf_weapon_lunchbox") == -1)
							iAction = Plugin_Handled;
					}
					case TFClass_Engineer:
					{
						//Block all weapons that are not PDA and toolbox
						if (iSlot <= WeaponSlot_Melee)
							iAction = Plugin_Handled;
					}
					case TFClass_Sniper:
					{
						//Block all secondary weapons that are not wearables
						if (StrContains(sClassname, "tf_wearable") == -1)
							iAction = Plugin_Handled;
					}
					default:
					{
						//Block literally everything else
						iAction = Plugin_Handled;
					}
				}
			}
		}
		else if (iSlot > WeaponSlot_BuilderEngie)
		{
			if (g_ClientClasses[iClient].sWorldModel[0])
			{
				//Block cosmetic if have custom model
				iAction = Plugin_Handled;
			}
			else if (TF2Econ_GetItemEquipRegionMask(GetClassVoodooItemDefIndex(iClass)) & TF2Econ_GetItemEquipRegionMask(iIndex))
			{
				//Cosmetic is conflicting voodoo model
				iAction = Plugin_Handled;
			}
		}
	}
	
	return iAction;
}

public Action TF2Items_OnGiveNamedItem(int iClient, char[] sClassname, int iIndex, Handle& hItem)
{
	return OnGiveNamedItem(iClient, sClassname, iIndex);
}
