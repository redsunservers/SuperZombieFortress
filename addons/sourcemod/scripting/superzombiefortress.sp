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

#define PLUGIN_VERSION				"4.7.0"
#define PLUGIN_VERSION_REVISION		"manual"

#define MAX_CONTROL_POINTS	8

#define ATTRIB_VISION		406

#define SECONDS_PER_MINUTE	60
#define SECONDS_PER_HOUR	3600
#define SECONDS_PER_DAY		86400
#define SECONDS_PER_MONTH	2629743

// Also used in the item schema to define vision filter or vision mode opt in
#define TF_VISION_FILTER_NONE		0
#define TF_VISION_FILTER_PYRO		(1<<0)	// 1
#define TF_VISION_FILTER_HALLOWEEN	(1<<1)	// 2
#define TF_VISION_FILTER_ROME		(1<<2)	// 4

// settings for m_takedamage
#define DAMAGE_NO				0
#define DAMAGE_EVENTS_ONLY		1		// Call damage functions, but don't modify health
#define DAMAGE_YES				2
#define DAMAGE_AIM				3

// Phys prop spawnflags
#define SF_PHYSPROP_START_ASLEEP				0x000001
#define SF_PHYSPROP_DONT_TAKE_PHYSICS_DAMAGE	0x000002		// this prop can't be damaged by physics collisions
#define SF_PHYSPROP_DEBRIS						0x000004
#define SF_PHYSPROP_MOTIONDISABLED				0x000008		// motion disabled at startup (flag only valid in spawn - motion can be enabled via input)
#define SF_PHYSPROP_TOUCH						0x000010		// can be 'crashed through' by running player (plate glass)
#define SF_PHYSPROP_PRESSURE					0x000020		// can be broken by a player standing on it
#define SF_PHYSPROP_ENABLE_ON_PHYSCANNON		0x000040		// enable motion only if the player grabs it with the physcannon
#define SF_PHYSPROP_NO_ROTORWASH_PUSH			0x000080		// The rotorwash doesn't push these
#define SF_PHYSPROP_ENABLE_PICKUP_OUTPUT		0x000100		// If set, allow the player to +USE this for the purposes of generating an output
#define SF_PHYSPROP_PREVENT_PICKUP				0x000200		// If set, prevent +USE/Physcannon pickup of this prop
#define SF_PHYSPROP_PREVENT_PLAYER_TOUCH_ENABLE	0x000400		// If set, the player will not cause the object to enable its motion when bumped into
#define SF_PHYSPROP_HAS_ATTACHED_RAGDOLLS		0x000800		// Need to remove attached ragdolls on enable motion/etc
#define SF_PHYSPROP_FORCE_TOUCH_TRIGGERS		0x001000		// Override normal debris behavior and respond to triggers anyway
#define SF_PHYSPROP_FORCE_SERVER_SIDE			0x002000		// Force multiplayer physics object to be serverside
#define SF_PHYSPROP_RADIUS_PICKUP				0x004000		// For Xbox, makes small objects easier to pick up by allowing them to be found 
#define SF_PHYSPROP_ALWAYS_PICK_UP				0x100000		// Physcannon can always pick this up, no matter what mass or constraints may apply.
#define SF_PHYSPROP_NO_COLLISIONS				0x200000		// Don't enable collisions on spawn
#define SF_PHYSPROP_IS_GIB						0x400000		// Limit # of active gibs

#define DMG_MELEE	(DMG_BLAST_SURFACE)

enum
{
	COLLISION_GROUP_NONE  = 0,
	COLLISION_GROUP_DEBRIS,			// Collides with nothing but world and static stuff
	COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
	COLLISION_GROUP_INTERACTIVE_DEBRIS,	// Collides with everything except other interactive debris or debris
	COLLISION_GROUP_INTERACTIVE,	// Collides with everything except interactive debris or debris
	COLLISION_GROUP_PLAYER,
	COLLISION_GROUP_BREAKABLE_GLASS,
	COLLISION_GROUP_VEHICLE,
	COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as Collision_Group_Player, for
										// TF2, this filters out other players and CBaseObjects
	COLLISION_GROUP_NPC,			// Generic NPC group
	COLLISION_GROUP_IN_VEHICLE,		// for any entity inside a vehicle
	COLLISION_GROUP_WEAPON,			// for any weapons that need collision detection
	COLLISION_GROUP_VEHICLE_CLIP,	// vehicle clip brush to restrict vehicle movement
	COLLISION_GROUP_PROJECTILE,		// Projectiles!
	COLLISION_GROUP_DOOR_BLOCKER,	// Blocks entities not permitted to get near moving doors
	COLLISION_GROUP_PASSABLE_DOOR,	// Doors that the player shouldn't collide with
	COLLISION_GROUP_DISSOLVING,		// Things that are dissolving are in this group
	COLLISION_GROUP_PUSHAWAY,		// Nonsolid on client and server, pushaway in player code

	COLLISION_GROUP_NPC_ACTOR,		// Used so NPCs in scripts ignore the player.
	COLLISION_GROUP_NPC_SCRIPTED,	// USed for NPCs in scripts that should not collide with each other

	LAST_SHARED_COLLISION_GROUP
};

enum
{
	VISION_MODE_NONE = 0,
	VISION_MODE_PYRO,
	VISION_MODE_HALLOWEEN,
	VISION_MODE_ROME,

	MAX_VISION_MODES
};

enum
{
	MELEE_NOCRIT = 0,
	MELEE_MINICRIT = 1,
	MELEE_CRIT = 2,
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

enum SolidType_t
{
	SOLID_NONE			= 0,	// no solid model
	SOLID_BSP			= 1,	// a BSP tree
	SOLID_BBOX			= 2,	// an AABB
	SOLID_OBB			= 3,	// an OBB (not implemented yet)
	SOLID_OBB_YAW		= 4,	// an OBB, constrained so that it can only yaw
	SOLID_CUSTOM		= 5,	// Always call into the entity for tests
	SOLID_VPHYSICS		= 6,	// solid vphysics object, get vcollide from the model and collide with that
	SOLID_LAST,
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

	Infected_Count
}

enum struct WeaponClasses
{
	int iIndex;
	char sAttribs[256];
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
	float flHorde;
	float flMaxHorde;
	bool bGlow;
	bool bThirdperson;
	int iColor[4];
	char sMessage[64];
	char sMenu[64];
	char sWorldModel[PLATFORM_MAX_PATH];
	char sViewModel[PLATFORM_MAX_PATH];
	bool bViewModelAnim;
	char sSoundSpawn[PLATFORM_MAX_PATH];
	int iRageCooldown;
	Function callback_spawn;
	Function callback_rage;
	Function callback_think;
	Function callback_touch;
	Function callback_damage;
	Function callback_attack;
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
	
	bool GetWeaponFromIndex(int iIndex, WeaponClasses buffer)
	{
		int iPos;
		WeaponClasses weapon;
		while (this.GetWeapon(iPos, weapon))
		{
			if (weapon.iIndex != iIndex)
				continue;
			
			buffer = weapon;
			return true;
		}
		
		return false;
	}
	bool GetWeaponSlot(int iSlot, WeaponClasses buffer)
	{
		if (!this.aWeapons)
			return false;
		
		// Get one of the weapon in slot by random
		WeaponClasses[] weapons = new WeaponClasses[this.aWeapons.Length];
		int iCount;
		
		int iPos;
		WeaponClasses weapon;
		while (this.GetWeapon(iPos, weapon))
		{
			if (TF2Econ_GetItemDefaultLoadoutSlot(weapon.iIndex) == iSlot)
				weapons[iCount++] = weapon;
		}
		
		if (iCount == 0)
			return false;
		
		buffer = weapons[GetRandomInt(0, iCount - 1)];
		return true;
	}
	
	int GetWeaponSlotIndex(int iSlot)
	{
		WeaponClasses weapon;
		if (!this.GetWeaponSlot(iSlot, weapon))
			return -1;
		
		return weapon.iIndex;
	}
	
	bool HasWeaponIndex(int iIndex)
	{
		int iPos;
		WeaponClasses weapon;
		while (this.GetWeapon(iPos, weapon))
		{
			if (weapon.iIndex == iIndex)
				return true;
		}
		
		return false;
	}
}

ClientClasses g_ClientClasses[MAXPLAYERS + 1];

SZFRoundState g_nRoundState = SZFRoundState_Setup;

Infected g_nInfected[MAXPLAYERS + 1];
Infected g_nNextInfected[MAXPLAYERS + 1];

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

char g_sClassNames[view_as<int>(TFClass_Engineer) + 1][] = {
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

char g_sInfectedNames[view_as<int>(Infected_Count)][] = {
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
Cookie g_cSoundPreference;
Cookie g_cForceZombieStartMapName;
Cookie g_cForceZombieStartTimestamp;

//Global State
bool g_bEnabled;
bool g_bNewFullRound;
bool g_bLastSurvivor;
bool g_bTF2Items;
bool g_bGiveNamedItemSkip;

ArrayList g_aSurvivorDeathTimes;
int g_iZombiesKilledSpree;

int g_iRoundTimestamp;

//Client State
int g_iHorde[MAXPLAYERS + 1];
int g_iCapturingPoint[MAXPLAYERS + 1];
int g_iRageTimer[MAXPLAYERS + 1];

float g_flStopChatSpam[MAXPLAYERS + 1];
bool g_bWaitingForTeamSwitch[MAXPLAYERS + 1];

StringMap g_mRoundPlayedAsZombie;
int g_iRoundPlayedCount;

//Global Timer Handles
Handle g_hTimerMain;
Handle g_hTimerMainSlow;
Handle g_hTimerHoarde;
Handle g_hTimerDataCollect;
Handle g_hTimerProgress;

//Cvar Handles
ConVar g_cvForceOn;
ConVar g_cvDebug;
ConVar g_cvRatio;
ConVar g_cvTankHealth;
ConVar g_cvTankHealthMin;
ConVar g_cvTankHealthMax;
ConVar g_cvTankTime;
ConVar g_cvTankStab;
ConVar g_cvTankDebrisLifetime;
ConVar g_cvSpecialInfectedInterval;
ConVar g_cvJockeyMovementVictim;
ConVar g_cvJockeyMovementAttacker;
ConVar g_cvFrenzyTankChance;
ConVar g_cvStunImmunity;
ConVar g_cvLastStandKingRuneDuration;
ConVar g_cvLastStandDefenseDuration;
ConVar g_cvDispenserAmmoCooldown;
ConVar g_cvDispenserHealRate;
ConVar g_cvBannerRequirement;
ConVar g_cvMeleeIgnoreTeammates;
ConVar g_cvPunishAvoidingPlayers;

enum struct ConVarEvent
{
	ConVar cvCooldown;
	ConVar cvSurvivorDeathInterval;		// Seconds interval to consider for survivor deaths
	ConVar cvSurvivorDeathThreshold;	// Min threshold for % of survivors died within interval
	ConVar cvKillSpree;					// Killing spree requirement since last survivor death, multiplied by % of zombies in playerbase
	ConVar cvChance;					// % Chance to randomly trigger it
	
	float flCooldown;
	
	void SetCooldown()
	{
		this.flCooldown = GetGameTime();
	}
	
	bool CanDoEvent()
	{
		float flGameTime = GetGameTime();
		if (this.flCooldown + this.cvCooldown.FloatValue > flGameTime)
			return false;
		
		// Random chance
		if (GetRandomFloat(0.0, 1.0) < this.cvChance.FloatValue)
		{
			CPrintToChatDebug("Triggered event from random chance (%.2f%%)", this.cvChance.FloatValue * 100.0);
			return true;
		}
		
		// Check if there too few survivor deaths within timeframe
		
		float flTotal;
		float flInterval = this.cvSurvivorDeathInterval.FloatValue;
		int iLength = g_aSurvivorDeathTimes.Length;
		for (int i = 0; i < iLength; i++)
		{
			float flDeath = g_aSurvivorDeathTimes.Get(i);
			if (flDeath + flInterval < flGameTime)
				continue;
			
			// from 1.0 to 0.0, value fades down
			flTotal += 1.0 - ((flGameTime - flDeath) / flInterval);
		}
		
		int iSurvivors = GetSurvivorCount();
		int iZombies = GetZombieCount();
		
		// Counting both dead and alive survivors
		float flThreshold = (iSurvivors + iLength) * this.cvSurvivorDeathThreshold.FloatValue;
		if (flTotal < flThreshold)
		{
			CPrintToChatDebug("Triggered event from few survivor deaths (%.2f deaths < threshold %.2f)", flTotal, flThreshold);
			return true;
		}
		
		// Check if there too many zombie kills since last survivor death
		
		float flPercentage = float(iZombies) / float(iSurvivors + iZombies);
		if (g_iZombiesKilledSpree >= this.cvKillSpree.FloatValue * flPercentage)
		{
			CPrintToChatDebug("Triggered event from killing spree (%d killed >= threshold %.2f)", g_iZombiesKilledSpree, this.cvKillSpree.FloatValue * flPercentage);
			return true;
		}
		
		return false;
	}
}

ConVarEvent g_FrenzyEvent;
ConVarEvent g_TankEvent;

float g_flZombieDamageScale = 1.0;

ArrayList g_aFastRespawn;

int g_iDamageZombie[MAXPLAYERS + 1];
int g_iDamageTakenLife[MAXPLAYERS + 1];
int g_iDamageDealtLife[MAXPLAYERS + 1];

float g_flDamageDealtAgainstTank[MAXPLAYERS + 1];
bool g_bTankRefreshed;

int g_iControlPointsInfo[MAX_CONTROL_POINTS][2];
int g_iControlPoints;
bool g_bCapturingLastPoint;
int g_iCarryingItem[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

float g_flTimeProgress;

float g_flRageRespawnStress;
float g_flInfectedInterval;
float g_flInfectedCooldown[view_as<int>(Infected_Count)];	//GameTime
int g_iInfectedCooldown[view_as<int>(Infected_Count)];	//Client who started the cooldown

int g_iTanksSpawned;
bool g_bZombieRage;

bool g_bSpawnAsSpecialInfected[MAXPLAYERS + 1];
int g_iKillsThisLife[MAXPLAYERS + 1];
int g_iMaxHealth[MAXPLAYERS + 1];
bool g_bShouldBacteriaPlay[MAXPLAYERS + 1] = {true, ...};
float g_flTimeStartAsZombie[MAXPLAYERS + 1];
float g_flBannerMeter[MAXPLAYERS + 1];

char g_sForceZombieStartMapName[MAXPLAYERS + 1][64];
int g_iForceZombieStartTimestamp[MAXPLAYERS + 1];

//Map overwrites
int g_iMaxRareWeapons;
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

//SDK offsets
int g_iOffsetItemDefinitionIndex;

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
#include "szf/stun.sp"
#include "szf/viewmodel.sp"

public Plugin myinfo =
{
	name = "Super Zombie Fortress",
	author = "42, Alex Turtle, Batfoxkid, Haxton Sale, Mikusch, sasch, wo, MekuCube (original)",
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
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	//Add server tag.
	AddServerTag("zf");
	AddServerTag("szf");
	
	LoadTranslations("superzombiefortress.phrases");
	
	//Initialize global state
	g_bSurvival = false;
	g_bNoMusic = false;
	g_bNoDirectorTanks = false;
	g_bNoDirectorRages = false;
	g_bDirectorSpawnTeleport = false;
	g_iMaxRareWeapons = MAX_RARE;
	g_bEnabled = false;
	g_bNewFullRound = true;
	g_bLastSurvivor = false;
	g_aSurvivorDeathTimes = new ArrayList();
	
	g_cFirstTimeZombie = new Cookie("szf_firsttimezombie", "Whether this player is playing as Infected for the first time.", CookieAccess_Protected);
	g_cFirstTimeSurvivor = new Cookie("szf_firsttimesurvivor2", "Whether this player is playing as a Survivor for the first time.", CookieAccess_Protected);
	g_cSoundPreference = new Cookie("szf_musicpreference", "Player's sound preference.", CookieAccess_Protected);
	
	g_cForceZombieStartTimestamp = new Cookie("szf_forcezombiestart_timestamp", "Timestamp of when the player was detected skipping playing on the Infected team.", CookieAccess_Protected);
	g_cForceZombieStartMapName = new Cookie("szf_forcezombiestart_mapname", "Name of the map that the player was detected skipping playing on the Infected team on.", CookieAccess_Protected);
	
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
	
	g_iOffsetItemDefinitionIndex = hSZF.GetOffset("CEconItemView::m_iItemDefinitionIndex");
	
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
		if (g_bEnabled)
			for (int iClient = 1; iClient <= MaxClients; iClient++)
				if (IsClientInGame(iClient))
					DHook_HookGiveNamedItem(iClient);
	}
}

public void OnPluginEnd()
{
	if (g_bEnabled)
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsClientInGame(iClient))
			{
				Sound_EndMusic(iClient);
				SetEntProp(iClient, Prop_Send, "m_nModelIndexOverrides", 0, _, VISION_MODE_ROME);
			}
		}
		
		SZFDisable();
		
		if (GameRules_GetRoundState() >= RoundState_Preround)	//Must check if round on-going, otherwise possible crash
			TF2_EndRound(TFTeam_Zombie);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sValue[32];
	int iValue;
	
	g_cSoundPreference.Get(iClient, sValue, sizeof(sValue));
	Sound_UpdateClientSetting(iClient, view_as<SoundSetting>(StringToInt(sValue)));
	
	g_cForceZombieStartTimestamp.Get(iClient, sValue, sizeof(sValue));
	iValue = StringToInt(sValue);
	g_iForceZombieStartTimestamp[iClient] = iValue;
	
	g_cForceZombieStartMapName.Get(iClient, g_sForceZombieStartMapName[iClient], sizeof(g_sForceZombieStartMapName[]));
}

public void OnConfigsExecuted()
{
	if (IsMapSZF() || g_cvForceOn.BoolValue)
	{
		SZFEnable();
		GetMapSettings();
	}
}

public void OnMapStart()
{
	g_iRoundTimestamp = GetTime();
}

public void OnMapEnd()
{
	if (!g_bEnabled)
		return;
	
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
		{
			g_bSurvival = true;
		}
		else if (StrContains(sTargetName, "szf_nomusic", false) == 0)
		{
			g_bNoMusic = true;
		}
		else if (StrContains(sTargetName, "szf_director_notank", false) == 0)
		{
			g_bNoDirectorTanks = true;
		}
		else if (StrContains(sTargetName, "szf_director_norage", false) == 0)
		{
			g_bNoDirectorRages = true;
		}
		else if (StrContains(sTargetName, "szf_director_spawnteleport", false) == 0)
		{
			g_bDirectorSpawnTeleport = true;
		}
		else if (StrContains(sTargetName, "szf_rarecap_", false) == 0)
		{
			ReplaceString(sTargetName, sizeof(sTargetName), "szf_rarecap_", "", false);
			if(StringToIntEx(sTargetName, g_iMaxRareWeapons) == 0)
				g_iMaxRareWeapons = MAX_RARE;
		}
	}
}

public void OnClientPutInServer(int iClient)
{
	g_iDamageZombie[iClient] = 0;
	g_flTimeStartAsZombie[iClient] = 0.0;
	g_bWaitingForTeamSwitch[iClient] = false;
	
	if (AreClientCookiesCached(iClient))
		OnClientCookiesCached(iClient);
	
	if (!g_bEnabled)
		return;
	
	CreateTimer(10.0, Timer_InitialHelp, iClient, TIMER_FLAG_NO_MAPCHANGE);
	
	DHook_HookGiveNamedItem(iClient);
	SDKHook_HookClient(iClient);
}

public void OnClientDisconnect(int iClient)
{
	DHook_UnhookGiveNamedItem(iClient);
	
	if (!g_bEnabled)
		return;
	
	CheckZombieBypass(iClient);
	
	Sound_EndMusic(iClient);
	DropCarryingItem(iClient);
	CheckLastSurvivor(iClient);
	
	Weapons_ClientDisconnect(iClient);
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (!g_bEnabled)
		return;
	
	DHook_OnEntityCreated(iEntity, sClassname);
	SDKHook_OnEntityCreated(iEntity, sClassname);
	
	if (StrEqual(sClassname, "tf_dropped_weapon") || StrEqual(sClassname, "item_powerup_rune"))	//Never allow dropped weapon and rune dropped from survivors
		RemoveEntity(iEntity);
}

public void OnEntityDestroyed(int iEntity)
{
	if (!g_bEnabled || iEntity == INVALID_ENT_REFERENCE)
		return;
	
	char sClassname[256];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
	if (StrEqual(sClassname, "tf_gas_manager"))
	{
		// Gas manager don't call EndTouch on delete, we'll have to manually call it
		
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (!IsValidLivingSurvivor(iClient))
				continue;
			
			float vecOrigin[3], vecMins[3], vecMaxs[3];
			GetClientAbsOrigin(iClient, vecOrigin);
			GetClientMins(iClient, vecMins);
			GetClientMaxs(iClient, vecMaxs);
			
			TR_ClipRayHullToEntity(vecOrigin, vecOrigin, vecMins, vecMaxs, MASK_PLAYERSOLID, iEntity);
			if (TR_DidHit())
				GasManager_EndTouch(iEntity, iClient);
		}
	}
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
			case TFCond_Disguising:
			{
				// Prevent able to disguise as spy, can't show zombie model of it
				while (view_as<TFClassType>(GetEntProp(iClient, Prop_Send, "m_nDesiredDisguiseClass")) == TFClass_Spy)
					SetEntProp(iClient, Prop_Send, "m_nDesiredDisguiseClass", GetRandomInt(view_as<int>(TFClass_Scout), view_as<int>(TFClass_Engineer)));
			}
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
	if (!g_bEnabled)
		return;
	
	SDKCall_SetSpeed(iClient);
	
	if (nCond == TFCond_Taunting)
		ViewModel_UpdateClient(iClient);	// taunting removes EF_NODRAW from weapon, readd it back
	else if (nCond == TFCond_Disguised)
		SetEntProp(iClient, Prop_Send, "m_nModelIndexOverrides", 0, _, VISION_MODE_ROME);	//Reset disguise model
}

public Action TF2_OnIsHolidayActive(TFHoliday nHoliday, bool &bResult)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	//Force enable a holiday to allow zombie voodoo soul to work
	//Shouldnt touch any other holidays as it may affect unneeded changes
	if (nHoliday == TFHoliday_HalloweenOrFullMoon)
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
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && g_bWaitingForTeamSwitch[iClient])
		{
			RequestFrame(Frame_PostGracePeriodSpawn, iClient); //A frame later so maps which have post-setup spawn points can adapt to these players
		}
	}
	
	g_flTimeProgress = 0.0;
	g_hTimerProgress = CreateTimer(6.0, Timer_Progress, _, TIMER_REPEAT);
	
	g_FrenzyEvent.SetCooldown();
	g_TankEvent.SetCooldown();
	g_flInfectedInterval = GetGameTime();
	g_aSurvivorDeathTimes.Clear();
}

public void Frame_PostGracePeriodSpawn(int iClient)
{
	if (!g_bEnabled)
		return;
	
	TF2_ChangeClientTeam(iClient, TFTeam_Zombie);
	
	if (!IsPlayerAlive(iClient))
	{
		if (TFTeam_Zombie == TFTeam_Blue)
			ShowVGUIPanel(iClient, "class_blue");
		else
			ShowVGUIPanel(iClient, "class_red");
	}
	
	g_bWaitingForTeamSwitch[iClient] = false;
	SetClientStartedAsZombie(iClient);	// Client pretty much will play a whole round as zombie
}

////////////////////////////////////////////////////////////
//
// Periodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action Timer_Main(Handle hTimer) //1 second
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	Handle_SurvivorAbilities();
	Handle_ZombieAbilities();
	UpdateZombieDamageScale();
	Sound_Timer();
	
	if (g_bZombieRage)
		SetTeamRespawnTime(TFTeam_Zombie, 0.0);
	else
		SetTeamRespawnTime(TFTeam_Zombie, fMax(6.0, 12.0 / fMax(0.6, g_flZombieDamageScale)));
	
	if (g_nRoundState == SZFRoundState_Active)
		Handle_WinCondition();
	
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
	
	//If the round is part of a multi-staged map, and that round is after the first one, play a saferoom theme.
	if (g_bNewFullRound)
		Sound_PlayMusicToTeam(TFTeam_Survivor, "start");
	else
		Sound_PlayMusicToTeam(TFTeam_Survivor, "saferoom");
	
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
	
	if (IsValidClient(iClient) && !IsPlayerAlive(iClient))
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
	
	if (g_nRoundState == SZFRoundState_Active)
	{
		int iCount = GetSurvivorCount();
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			//Last man gets minicrit boost if 6 players ingame
			if (iCount == 1 && IsValidLivingSurvivor(iClient) && GetActivePlayerCount() >= 6)
				TF2_AddCondition(iClient, TFCond_Buffed, 0.05);
		}
		
		float flInterval = g_cvSpecialInfectedInterval.FloatValue;
		if (flInterval >= 0.0 && g_flInfectedInterval + flInterval <= GetGameTime())
		{
			// Collect list of possible clients to choose
			int iClients[MAXPLAYERS];
			int iZombieCount;
			for (int iClient = 1; iClient <= MaxClients; iClient++)
				if (IsValidZombie(iClient) && g_nInfected[iClient] == Infected_None && g_nNextInfected[iClient] == Infected_None)
					iClients[iZombieCount++] = iClient;
			
			if (iZombieCount > 0)
			{
				int iClient = iClients[GetRandomInt(0, iZombieCount - 1)];
				g_bSpawnAsSpecialInfected[iClient] = true;
				g_flInfectedInterval = GetGameTime();
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
			int iMaxHealth = SDKCall_GetMaxHealth(iClient);
			int iRegen = g_ClientClasses[iClient].iRegen;
			
			if (iHealth < iMaxHealth && (iRegen < 0 || !TF2_IsPlayerInCondition(iClient, TFCond_Bleeding)))	// No regen while in spitter bleed
			{
				iRegen = min(iRegen, iMaxHealth - iHealth);
				SetEntityHealth(iClient, iHealth + iRegen);
				
				Event event = CreateEvent("player_healonhit", true);
				event.SetInt("amount", iRegen);
				event.SetInt("entindex", iClient);
				event.FireToClient(iClient);
				event.Cancel();
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
	int iHealth;
	int iMaxHealth;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidLivingZombie(iClient))
		{
			iHealth = GetClientHealth(iClient);
			iMaxHealth = SDKCall_GetMaxHealth(iClient);
			
			//1. Handle zombie regeneration.
			//       Zombies regenerate health based on class and number of nearby
			//       zombies (hoarde bonus). Zombies decay health when overhealed.
			if (iHealth < iMaxHealth && g_nInfected[iClient] != Infected_Tank)
			{
				int iRegen = g_ClientClasses[iClient].iRegen;
				
				//Handle additional regeneration
				iRegen += g_iHorde[iClient]; //Horde bonus
				
				if (g_bZombieRage)
					iRegen += 3; //Zombie rage
				
				if (TF2_IsPlayerInCondition(iClient, TFCond_TeleportedGlow))
					iRegen += 2; //Screamer
				
				iRegen = min(iRegen, iMaxHealth - iHealth);
				SetEntityHealth(iClient, iHealth + iRegen);
				
				Event event = CreateEvent("player_healonhit", true);
				event.SetInt("amount", iRegen);
				event.SetInt("entindex", iClient);
				event.FireToClient(iClient);
				event.Cancel();
			}
			else if (iHealth > iMaxHealth)
			{
				int iDegen = g_ClientClasses[iClient].iDegen;
				iDegen = max(iDegen, iMaxHealth - iHealth);
				SetEntityHealth(iClient, iHealth - iDegen);
			}
			
			//2.1. Handle zombie rage timer
			//       Rage recharges every 20(special)/30(normal) seconds.
			if (g_iRageTimer[iClient] > 0)
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
	float vecClientsPos[MAXPLAYERS][3];
	
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
	g_bSurvival = false;
	g_bNoMusic = false;
	g_bNoDirectorTanks = false;
	g_bNoDirectorRages = false;
	g_bDirectorSpawnTeleport = false;
	g_iMaxRareWeapons = MAX_RARE;
	g_bEnabled = true;
	g_bNewFullRound = true;
	g_bLastSurvivor = false;
	
	g_flTimeProgress = 0.0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		ResetClientState(iClient);
		
		if (IsClientInGame(iClient))
		{
			DHook_HookGiveNamedItem(iClient);
			SDKHook_HookClient(iClient);
		}
	}
	
	ConVar_Enable();
	DHook_Enable();
	
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
	
	if (GameRules_GetRoundState() < RoundState_Preround)
	{
		g_nRoundState = SZFRoundState_Setup;
	}
	else	//Plugin late-load while already midgame, restart round
	{
		TF2_EndRound(TFTeam_Zombie);
		g_nRoundState = SZFRoundState_End;
	}
	
	AddNormalSoundHook(SoundHook);
	
	HookEntityOutput("logic_relay", "OnTrigger", OnRelayTrigger);
	HookEntityOutput("math_counter", "OutValue", OnCounterValue);
	
	//[Re]Enable periodic timers.
	delete g_hTimerMain;
	g_hTimerMain = CreateTimer(1.0, Timer_Main, _, TIMER_REPEAT);
	
	delete g_hTimerMainSlow;
	g_hTimerMainSlow = CreateTimer(240.0, Timer_MainSlow, _, TIMER_REPEAT);
	
	delete g_hTimerHoarde;
	g_hTimerHoarde = CreateTimer(5.0, Timer_Hoarde, _, TIMER_REPEAT);
	
	delete g_hTimerDataCollect;
	g_hTimerDataCollect = CreateTimer(2.0, Timer_Datacollect, _, TIMER_REPEAT);
}

void SZFDisable()
{
	g_bSurvival = false;
	g_bNoMusic = false;
	g_bNoDirectorTanks = false;
	g_bNoDirectorRages = false;
	g_bDirectorSpawnTeleport = false;
	g_iMaxRareWeapons = MAX_RARE;
	g_bEnabled = false;
	g_bNewFullRound = true;
	g_bLastSurvivor = false;
	
	g_flTimeProgress = 0.0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		ResetClientState(iClient);
		DHook_UnhookGiveNamedItem(iClient);
		
		if (IsClientInGame(iClient))
			SDKHook_UnhookClient(iClient);
	}
	
	ConVar_Disable();
	DHook_Disable();
	
	RemoveNormalSoundHook(SoundHook);
	
	UnhookEntityOutput("logic_relay", "OnTrigger", OnRelayTrigger);
	UnhookEntityOutput("math_counter", "OutValue", OnCounterValue);
	
	//Disable periodic timers.
	delete g_hTimerMain;
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
	g_iHorde[iClient] = 0;
	g_iCapturingPoint[iClient] = -1;
	g_iRageTimer[iClient] = 0;
}

void PrintInfoChat(int iClient)
{
	if (iClient == 0)
		CPrintToChatAll("%t", "Welcome", "{lightsalmon}", "{limegreen}", "{lightsalmon}");
	else
		CPrintToChat(iClient, "%t", "Welcome", "{lightsalmon}", "{limegreen}", "{lightsalmon}");
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
				else if (Stun_IsPlayerStunned(iClient))
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

void Frame_CheckZombieBypass(int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		CheckZombieBypass(iClient);
}

void CheckZombieBypass(int iClient)
{
	if (!g_cvPunishAvoidingPlayers.BoolValue)
		return;
	
	int iSurvivors = GetSurvivorCount();
	int iZombies = GetZombieCount();
	
	//4 Checks
	if ((g_flTimeStartAsZombie[iClient] != 0.0)						//Check if client is currently playing as zombie (if it 0.0, it means he have not played as zombie yet this round)
		&& (g_flTimeStartAsZombie[iClient] > GetGameTime() - 60.0)	//Check if client have been playing zombie less than 60 seconds
		&& (float(iZombies) / float(iSurvivors + iZombies) <= 0.5)	//Check if less than 50% of players is zombie
		&& (g_nRoundState != SZFRoundState_End))								//Check if round did not end or map changing
	{
		g_iForceZombieStartTimestamp[iClient] = GetTime();
		GetCurrentMapDisplayName(g_sForceZombieStartMapName[iClient], sizeof(g_sForceZombieStartMapName[]));
		
		char sAuthId[64];
		GetClientAuthId(iClient, AuthId_Steam2, sAuthId, sizeof(sAuthId));
		
		ArrayStack aStack = new ArrayStack(64);
		aStack.PushString(sAuthId);
		RequestFrame(Frame_SetForceZombieStart, aStack);
	}
}

void Frame_SetForceZombieStart(ArrayStack aStack)
{
	char sAuthId[64];
	aStack.PopString(sAuthId, sizeof(sAuthId));
	delete aStack;
	
	// Check that round is still ongoing, client may've force disconnected from mapchange
	if (g_nRoundState == SZFRoundState_Setup || g_nRoundState == SZFRoundState_End)
		return;
	
	char sBuffer[128];
	FormatEx(sBuffer, sizeof(sBuffer), "%d", GetTime()); // Doesn't need to be the same timestamp as the one assigned for the client ent index, just roughly matching is good enough
	
	g_cForceZombieStartTimestamp.SetByAuthId(sAuthId, sBuffer);
	
	GetCurrentMapDisplayName(sBuffer, sizeof(sBuffer));
	g_cForceZombieStartMapName.SetByAuthId(sAuthId, sBuffer);
}

int GetRoundPlayedAsZombie(int iClient)
{
	if (!g_mRoundPlayedAsZombie)
		return 0;
	
	char sSteamId[64];
	if (IsFakeClient(iClient))
		IntToString(GetClientUserId(iClient), sSteamId, sizeof(sSteamId));
	else
		GetClientAuthId(iClient, AuthId_SteamID64, sSteamId, sizeof(sSteamId));
	
	int iValue;
	g_mRoundPlayedAsZombie.GetValue(sSteamId, iValue);
	return iValue;
}

void SetClientStartedAsZombie(int iClient)
{
	if (!g_mRoundPlayedAsZombie)
		g_mRoundPlayedAsZombie = new StringMap();
	
	char sSteamId[64];
	if (IsFakeClient(iClient))
		IntToString(GetClientUserId(iClient), sSteamId, sizeof(sSteamId));
	else
		GetClientAuthId(iClient, AuthId_SteamID64, sSteamId, sizeof(sSteamId));
	
	g_mRoundPlayedAsZombie.SetValue(sSteamId, g_iRoundPlayedCount);
}

bool ClientStartedAsZombie(int iClient)
{
	return GetRoundPlayedAsZombie(iClient) == g_iRoundPlayedCount;
}

int Sort_LastPlayedZombie(int iClient1, int iClient2, const int[] iClients, Handle hData)
{
	int iRound1 = GetRoundPlayedAsZombie(iClient1);
	int iRound2 = GetRoundPlayedAsZombie(iClient2);
	
	if (iRound1 > iRound2)
		return -1;
	else if (iRound1 < iRound2)
		return 1;
	else
		return 0;
}

void UpdateZombieDamageScale()
{
	g_flZombieDamageScale = 1.0;
	
	if (!g_bEnabled || g_nRoundState != SZFRoundState_Active)
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
	else if (g_bSurvival)
	{
		int iTimer = FindEntityByClassname(INVALID_ENT_REFERENCE, "team_round_timer");
		if (iTimer != INVALID_ENT_REFERENCE)
		{
			float flTimerInitialLength = float(GetEntProp(iTimer, Prop_Send, "m_nTimerInitialLength"));
			float flTimerEndTime = GetEntPropFloat(iTimer, Prop_Send, "m_flTimerEndTime");
			float flGameTime = GetGameTime();
			if (flGameTime > flTimerEndTime)
			{
				flProgress = 1.0;
			}
			else
			{
				float flTimeLeft = flTimerEndTime - flGameTime;
				flProgress = 1.0 - (flTimeLeft / flTimerInitialLength);
				if (flProgress < 0.0)
					flProgress = 0.0;
			}
		}
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
	
	//If progress found, calculate add progress to damage scale
	if (0.0 <= flProgress <= 1.0)
		g_flZombieDamageScale += flProgress;
	
	//Lower damage scale as there are less survivors
	float flSurvivorPercentage = float(iSurvivors) / float(iSurvivors + iZombies);
	g_flZombieDamageScale = (g_flZombieDamageScale * flSurvivorPercentage * 0.6) + 0.5;
	
	//Zombie rage increases damage
	if (g_bZombieRage)
		g_flZombieDamageScale += 0.15;
	
	//If the last point is being captured, increase damage scale if lower than 100%
	if (g_bCapturingLastPoint && g_flZombieDamageScale < 1.0 && !g_bSurvival)
		g_flZombieDamageScale += (1.0 - g_flZombieDamageScale) * 0.5;
	
	//Post-calculation
	if (g_flZombieDamageScale < 1.0)
		g_flZombieDamageScale = Pow(g_flZombieDamageScale, 3.0);
	
	if (g_flZombieDamageScale < 0.2)
		g_flZombieDamageScale = 0.2;
	
	if (g_flZombieDamageScale > 3.0)
		g_flZombieDamageScale = 3.0;
	
	//Not survival, no rage and no active tank
	if (!g_bSurvival && !g_bZombieRage && !ZombiesTankComing() && !ZombiesHaveTank())
	{
		if (g_TankEvent.CanDoEvent())
		{
			ZombieTank();
		}
		else if (g_FrenzyEvent.CanDoEvent())
		{
			if (GetRandomFloat(0.0, 1.0) < g_cvFrenzyTankChance.IntValue)
				ZombieTank();
			else
				ZombieRage();
		}
	}
}

public Action Timer_RespawnPlayer(Handle hTimer, int iClient)
{
	if (IsClientInGame(iClient) && !IsPlayerAlive(iClient))
		TF2_RespawnPlayer2(iClient);
	
	return Plugin_Continue;
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
	
	TF2_AddCondition(iLastSurvivor, TFCond_KingRune, g_cvLastStandKingRuneDuration.FloatValue);
	TF2_AddCondition(iLastSurvivor, TFCond_DefenseBuffNoCritBlock, g_cvLastStandDefenseDuration.FloatValue);
	SetEntityHealth(iLastSurvivor, SDKCall_GetMaxHealth(iLastSurvivor));
	
	g_bLastSurvivor = true;
	
	char sName[256];
	GetClientName2(iLastSurvivor, sName, sizeof(sName));
	CPrintToChatAllEx(iLastSurvivor, "%t", "Survivor_Last", sName, "{green}");
	
	Sound_PlayMusicToAll("laststand");
	
	FireRelay("FireUser1", "szf_laststand", _, iLastSurvivor);
	
	Forward_OnLastSurvivor(iLastSurvivor);
}

public Action OnRelayTrigger(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{
	char sTargetName[255];
	GetEntPropString(iCaller, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
	
	if (StrEqual("szf_panic_event", sTargetName))
	{
		ZombieRage(_, true);
	}
	else if (StrContains(sTargetName, "szf_zombierage") == 0)
	{
		ReplaceString(sTargetName, sizeof(sTargetName), "szf_zombierage_", "");
		float time = StringToFloat(sTargetName);
		if(time > 0)
		{
			ZombieRage(time, true);
		}
		else
		{
			ZombieRage(_, true);
		}
	}
	else if (StrEqual("szf_zombietank", sTargetName) || StrEqual("szf_tank", sTargetName))
	{
		ZombieTank(iCaller);
	}
	else if (StrEqual("szf_laststand", sTargetName))
	{
		Sound_PlayMusicToAll("laststand");
	}
	
	return Plugin_Continue;
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
	
	return Plugin_Continue;
}

void ZombieRage(float flDuration = 20.0, bool bIgnoreDirector = false)
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
	
	float flGameTime = GetGameTime();
	g_flRageRespawnStress = flGameTime;	//Set initial respawn stress
	
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
					TF2_RespawnPlayer2(iClient);
			}
		}
	}
	
	g_FrenzyEvent.SetCooldown();
	
	FireRelay("FireUser1", "szf_zombierage", "szf_panic_event");
}

public Action Timer_StopZombieRage(Handle hTimer)
{
	g_bZombieRage = false;
	UpdateZombieDamageScale();
	
	if (g_nRoundState == SZFRoundState_Active)
		for (int iClient = 1; iClient <= MaxClients; iClient++)
			if (IsClientInGame(iClient))
				CPrintToChat(iClient, "%t", "Frenzy_End", (IsZombie(iClient)) ? "{red}" : "{green}");
	
	FireRelay("FireUser2", "szf_zombierage", "szf_panic_event");
	
	return Plugin_Continue;
}

int FastRespawnNearby(int iClient, float flDistance, bool bMustBeInvisible = true)
{
	if (g_aFastRespawn == null)
		return -1;
	
	ArrayList aTombola = new ArrayList();
	
	float vecPosClient[3];
	float vecPosEntry[3];
	float vecPosEntry2[3];
	GetClientAbsOrigin(iClient, vecPosClient);
	
	int iLength = g_aFastRespawn.Length;
	for (int i = 0; i < iLength; i++)
	{
		g_aFastRespawn.GetArray(i, vecPosEntry);
		vecPosEntry2[0] = vecPosEntry[0];
		vecPosEntry2[1] = vecPosEntry[1];
		vecPosEntry2[2] = vecPosEntry[2] += 90.0;
		
		bool bAllow = true;
		
		float flEntryDistance = GetVectorDistance(vecPosClient, vecPosEntry);
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
	if (!g_bDirectorSpawnTeleport && !g_bZombieRage)
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
	
	int iResult = FastRespawnNearby(iTarget, 1000.0);
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
	
	// Delete any positions too far away from any clients, clear up space
	for (int i = g_aFastRespawn.Length - 1; i >= 0; i--)
	{
		float vecPos[3];
		g_aFastRespawn.GetArray(i, vecPos);
		
		bool bDelete = true;
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (!IsValidLivingClient(iClient))
				continue;
			
			if (DistanceFromEntityToPoint(iClient, vecPos) > 1250.0)
				continue;
			
			bDelete = false;
			break;
		}
		
		if (bDelete)
			g_aFastRespawn.Erase(i);
	}
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidLivingClient(iClient)
			&& FastRespawnNearby(iClient, 100.0, false) < 0
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
	ViewModel_RemoveWearable(iClient);
	
	for (int iSlot = WeaponSlot_Melee; iSlot <= WeaponSlot_InvisWatch; iSlot++)
	{
		int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (iEntity > MaxClients)
		{
			//Get attrib from index to apply
			int iIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
			
			ConfigMelee melee;
			if (Config_GetMeleeByDefIndex(iIndex, melee))
			{
				//If have prefab, use said index instead
				if (melee.iIndexPrefab >= 0)
					Config_GetMeleeByDefIndex(melee.iIndexPrefab, melee);
				
				//See if there weapon to replace
				if (melee.iIndexReplace >= 0)
				{
					iIndex = melee.iIndexReplace;
					TF2_RemoveWeaponSlot(iClient, iSlot);
					iEntity = TF2_CreateAndEquipWeapon(iClient, iIndex);
				}
				
				//Print text with cooldown to prevent spam
				float flGameTime = GetGameTime();
				if (g_flStopChatSpam[iClient] < flGameTime && melee.sText[0])
				{
					CPrintToChat(iClient, "%t", melee.sText);
					g_flStopChatSpam[iClient] = flGameTime + 1.0;
				}
					
				//Apply attribute
				TF2_WeaponApplyAttribute(iEntity, melee.sAttrib);
			}
			
			//This will refresh health max calculation and other attributes
			TF2Attrib_ClearCache(iEntity);
		}
	}
	
	//Remove rome vision
	int iWearable = INVALID_ENT_REFERENCE;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) != INVALID_ENT_REFERENCE)
	{
		if (GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == iClient || GetEntPropEnt(iWearable, Prop_Send, "moveparent") == iClient)
			if (0 <= GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex") < 0xFFFF)
				RemoveWeaponVision(iWearable, TF_VISION_FILTER_ROME);
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
	
	//Give out zombie weapons if don't have one
	for (int iSlot = WeaponSlot_Primary; iSlot < WeaponSlot_BuilderEngie; iSlot++)	// Ideally should also check toolbox slot, but ermmmm lets not do that
	{
		int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
		if (iWeapon != INVALID_ENT_REFERENCE)
		{
			WeaponClasses weapon;
			if (!g_ClientClasses[iClient].GetWeaponFromIndex(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"), weapon))
				continue;	// how could this happen?
			
			TF2_WeaponApplyAttribute(iWeapon, weapon.sAttribs);
			continue;
		}
		
		WeaponClasses weapon;
		if (!g_ClientClasses[iClient].GetWeaponSlot(iSlot, weapon))	// picks one of the available weapon in slot at random
			continue;
		
		TF2_CreateAndEquipWeapon(iClient, weapon.iIndex, weapon.sAttribs);
	}
	
	ViewModel_UpdateClient(iClient);
	
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
	
	if (g_ClientClasses[iClient].bThirdperson)
		RequestFrame(SetThirdperson, GetClientSerial(iClient));
	
	//Reset metal for TF2 to give back correct amount from attribs
	TF2_SetMetal(iClient, 0);
	
	//Set active wepaon slot to melee
	int iMelee = TF2_GetItemInSlot(iClient, WeaponSlot_Melee);
	if (iMelee > MaxClients)
	{
		TF2_SwitchActiveWeapon(iClient, iMelee);
		if (g_ClientClasses[iClient].bViewModelAnim)	// needed for some reason for custom anims
			ViewModel_SetAnimation(iClient, "ACT_FISTS_VM_DRAW");
		
		AddWeaponVision(iMelee, TF_VISION_FILTER_HALLOWEEN);	//Allow see Voodoo souls
		AddWeaponVision(iMelee, TF_VISION_FILTER_ROME);			//Allow see spy's custom model disguise detour fix
	}
}

void OnClientDisguise(int iClient)
{
	if (view_as<TFTeam>(GetEntProp(iClient, Prop_Send, "m_nDisguiseTeam")) != TFTeam_Zombie)
		return;	// only zombies are zombies, duh
	
	TFClassType nClass = view_as<TFClassType>(GetEntProp(iClient, Prop_Send, "m_nDisguiseClass"));
	if (nClass == TFClass_Unknown)
		return;
	
	if (nClass == TFClass_Spy)
	{
		// You're not supposed to be here
		TF2_RemovePlayerDisguise(iClient);
		return;
	}
	
	int iIndex = -1;
	
	int iOffset = FindSendPropInfo("CTFPlayer", "m_iDisguiseHealth") - 4;	// m_hDisguiseTarget
	int iTarget = GetEntDataEnt2(iClient, iOffset);
	if (0 < iTarget <= MaxClients && TF2_GetPlayerClass(iTarget) == nClass)
	{
		// We are disgusing as someone, do they have custom model?
		if (g_ClientClasses[iTarget].sWorldModel[0])
			SetEntProp(iClient, Prop_Send, "m_nModelIndexOverrides", PrecacheModel(g_ClientClasses[iTarget].sWorldModel), _, VISION_MODE_ROME);
		
		iIndex = g_ClientClasses[iTarget].GetWeaponSlotIndex(WeaponSlot_Melee);
	}
	else
	{
		// Make sure all wearables is removed, can happen when no disguise target
		int iWearable = INVALID_ENT_REFERENCE;
		while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) > MaxClients)
			if (GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == iClient && GetEntProp(iWearable, Prop_Send, "m_bDisguiseWearable"))
				TF2_RemoveWearable(iClient, iWearable);
		
		// Should be disguising as default class, give zombie weapon and cosmetics
		iWearable = CreateVoodooWearable(iClient, nClass);
		SetEntProp(iWearable, Prop_Send, "m_bDisguiseWearable", true);	// Must be set before equip
		TF2_EquipWeapon(iClient, iWearable);
		
		SetEntProp(iClient, Prop_Send, "m_nDisguiseSkinOverride", 1);
		
		iIndex = GetZombieMeleeIndex(nClass);
	}
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hDisguiseWeapon");
	if (iWeapon != INVALID_ENT_REFERENCE && GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") != iIndex)
	{
		RemoveEntity(iWeapon);
		iWeapon = INVALID_ENT_REFERENCE;
	}
	
	if (iWeapon == INVALID_ENT_REFERENCE)
	{
		iWeapon = TF2_CreateWeapon(iClient, iIndex);	// dont want to actually equip it
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwner", iClient);
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", iClient);
		
		SetEntityMoveType(iWeapon, MOVETYPE_NONE);
		SetEntProp(iWeapon, Prop_Send, "m_fEffects", GetEntProp(iWeapon, Prop_Send, "m_fEffects")|EF_BONEMERGE);
		SetVariantString("!activator");
		AcceptEntityInput(iWeapon, "SetParent", iClient);
		
		SetEntProp(iWeapon, Prop_Send, "m_iState", 2);	// WEAPON_IS_ACTIVE
		SetEntProp(iWeapon, Prop_Send, "m_bDisguiseWeapon", true);
		
		SetEntPropEnt(iClient, Prop_Send, "m_hDisguiseWeapon", iWeapon);
		
		// There is CTFWeaponBase::DisguiseWeaponThink not checked, do we need it?
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
	
	if (iCaller == -1 && g_bNoDirectorTanks)
		return;
	
	int iClient;
	if (IsValidZombie(iCaller))
		iClient = iCaller;
	else
		iClient = GetMostDamageZom();
	
	if (iClient <= 0)
		return;
	
	char sName[256];
	GetClientName2(iClient, sName, sizeof(sName));
	
	for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
		if (IsValidZombie(iTarget))
			CPrintToChatEx(iTarget, iClient, "%t", "Tank_Chosen", sName, "{green}");
	
	if (IsValidClient(iCaller))
		CPrintToChat(iCaller, "%t", "Tank_Called", "{green}");
	
	g_nNextInfected[iClient] = Infected_Tank;
	g_TankEvent.SetCooldown();
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
		
		FireRelay("FireUser2", "szf_laststand");
		
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
	
	g_iCarryingItem[iClient] = EntIndexToEntRef(iTarget);
	AcceptEntityInput(iTarget, "DisableMotion");
	SetEntProp(iTarget, Prop_Send, "m_nSolidType", SOLID_NONE);
	
	EmitSoundToClient(iClient, "ui/item_paint_can_pickup.wav");
	PrintHintText(iClient, "%t", "Carry_Pickup");
	AcceptEntityInput(iTarget, "FireUser1", iClient, iClient);
	
	SetVariantString("TLK_PLAYER_MOVEUP");
	AcceptEntityInput(iClient, "SpeakResponseConcept");
	
	return true;
}

void UpdateClientCarrying(int iClient)
{
	if (!IsValidEntity(g_iCarryingItem[iClient]))
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
	TeleportEntity(g_iCarryingItem[iClient], vecOrigin, vecAngles, NULL_VECTOR);
}

bool DropCarryingItem(int iClient, bool bDrop = true)
{
	if (!IsValidEntity(g_iCarryingItem[iClient]))
		return false;
	
	SetEntProp(g_iCarryingItem[iClient], Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
	AcceptEntityInput(g_iCarryingItem[iClient], "EnableMotion");
	AcceptEntityInput(g_iCarryingItem[iClient], "FireUser2", iClient, iClient);
	
	if (bDrop)
	{
		float vecOrigin[3];
		GetClientEyePosition(iClient, vecOrigin);
		
		if (!IsEntityStuck(g_iCarryingItem[iClient]) && !ObstactleBetweenEntities(iClient, g_iCarryingItem[iClient]))
		{
			vecOrigin[0] += 20.0;
			vecOrigin[2] -= 30.0;
		}
		
		TeleportEntity(g_iCarryingItem[iClient], vecOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	
	g_iCarryingItem[iClient] = INVALID_ENT_REFERENCE;
	return true;
}

Action SoundHook(int iClients[MAXPLAYERS], int &iNumClients, char sSound[PLATFORM_MAX_PATH], int &iClient, int &iChannel, float &flVolume, int &iLevel, int &iPitch, int &iFlags, char sSoundEntry[PLATFORM_MAX_PATH], int &iSeed)
{
	Action action = Plugin_Continue;
	if (StrContains(sSound, "vo/", false) != -1)
	{
		//Don't play any sounds to stunned players
		for (int i = iNumClients - 1; i >= 0; i--)
		{
			if (Stun_IsPlayerStunned(iClients[i]))
			{
				for (int j = i; j < iNumClients; j++)
					iClients[j] = iClients[j+1];
				
				iNumClients--;
				action = Plugin_Changed;
			}
		}
	}
	
	if (!IsValidClient(iClient))
		return action;
	
	if (StrContains(sSound, "vo/", false) != -1 && IsZombie(iClient))
	{
		if (StrContains(sSound, "zombie_vo/", false) != -1)
			return action; //So rage sounds (for normal & most special infected alike) don't get blocked
		
		if (StrContains(sSound, "_pain", false) != -1)
		{
			if (GetClientHealth(iClient) < 50 || StrContains(sSound, "crticial", false) != -1)  //The typo is intended because that's how the soundfiles are named
				if (Sound_GetInfectedVo(g_nInfected[iClient], SoundVo_Death, sSound, sizeof(sSound)))
					return Plugin_Changed;
			
			if (TF2_IsPlayerInCondition(iClient, TFCond_OnFire))
				if (Sound_GetInfectedVo(g_nInfected[iClient], SoundVo_Fire, sSound, sizeof(sSound)))
					return Plugin_Changed;
			
			if (Sound_GetInfectedVo(g_nInfected[iClient], SoundVo_Pain, sSound, sizeof(sSound)))
				return Plugin_Changed;
		}
		else if (StrContains(sSound, "_laugh", false) != -1 || StrContains(sSound, "_no", false) != -1 || StrContains(sSound, "_yes", false) != -1)
		{
			if (Sound_GetInfectedVo(g_nInfected[iClient], SoundVo_Mumbling, sSound, sizeof(sSound)))
				return Plugin_Changed;
		}
		else if (StrContains(sSound, "_go", false) != -1 || StrContains(sSound, "_jarate", false) != -1)
		{
			if (Sound_GetInfectedVo(g_nInfected[iClient], SoundVo_Shoved, sSound, sizeof(sSound)))
				return Plugin_Changed;
		}
		
		//Play default vo for whatever infected
		if (Sound_GetInfectedVo(g_nInfected[iClient], SoundVo_Default, sSound, sizeof(sSound)))
			return Plugin_Changed;
		
		//If sound still not found, try normal infected
		Sound_GetInfectedVo(Infected_None, SoundVo_Default, sSound, sizeof(sSound));
		return Plugin_Changed;
	}
	
	return action;
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
		return Plugin_Continue;
	
	SetHudTextParams(-1.0, 0.32, flDuration, 100, 100, 255, 128);
	ShowHudText(iClient, 4, "%t", sDisplay);
	
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
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

Action OnGiveNamedItem(int iClient, int iIndex)
{
	if (g_bGiveNamedItemSkip || TF2_IsPlayerInCondition(iClient, TFCond_Disguised))
		return Plugin_Continue;
	
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	TFTeam iTeam = TF2_GetClientTeam(iClient);
	int iSlot = TF2_GetItemSlot(iIndex, iClass);
	
	Action iAction = Plugin_Continue;
	if (iTeam == TFTeam_Survivor)
	{
		if (iSlot < WeaponSlot_Melee)
		{
			iAction = Plugin_Handled;
		}
		else if (GetClassVoodooItemDefIndex(iClass) == iIndex)
		{
			//Survivors are not zombies
			iAction = Plugin_Handled;
		}
	}
	else if (iTeam == TFTeam_Zombie)
	{
		if (g_nInfected[iClient] != Infected_None)
		{
			// Special infected don't get to keep its own weapons
			iAction = Plugin_Handled;
		}
		else if (iSlot <= WeaponSlot_BuilderEngie)
		{
			// Only allow weapon if its listed in config
			if (!g_ClientClasses[iClient].HasWeaponIndex(iIndex) && !g_ClientClasses[iClient].HasWeaponIndex(Config_GetOriginalItemDefIndex(iIndex)))
				iAction = Plugin_Handled;
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
	if (!g_bEnabled)
		return Plugin_Continue;
	
	return OnGiveNamedItem(iClient, iIndex);
}


bool GetVaguePeriodOfTimeFromTimestamp(char[] sBuffer, int iLength, int iTimestamp, int iClient = LANG_SERVER)
{
	int iTimePeriod = GetTime() - iTimestamp;
	if (iTimePeriod < 0)
		return false;
	
	if (iTimePeriod / SECONDS_PER_MONTH > 1)
	{
		int iMonths = iTimePeriod / SECONDS_PER_MONTH;
		FormatEx(sBuffer, iLength, "%T", "Time_MonthsAgo", iClient, iMonths);
	}
	else if (iTimePeriod / SECONDS_PER_DAY > 1)
	{
		int iDays = iTimePeriod / SECONDS_PER_DAY;
		FormatEx(sBuffer, iLength, "%T", "Time_DaysAgo", iClient, iDays);
	}
	else if (iTimePeriod / SECONDS_PER_HOUR > 1)
	{
		int iHours = iTimePeriod / SECONDS_PER_HOUR;
		FormatEx(sBuffer, iLength, "%T", "Time_HoursAgo", iClient, iHours);
	}
	else if (iTimePeriod / SECONDS_PER_MINUTE > 0)
	{
		int iMinutes = iTimePeriod / SECONDS_PER_MINUTE;
		
		if (iMinutes == 1)
			FormatEx(sBuffer, iLength, "%T", "Time_MinuteAgo", iClient, iMinutes);
		else
			FormatEx(sBuffer, iLength, "%T", "Time_MinutesAgo", iClient, iMinutes);
	}
	else
	{
		FormatEx(sBuffer, iLength, "%T", "Time_LessThanAMinuteAgo", iClient);
	}
	
	return true;
}