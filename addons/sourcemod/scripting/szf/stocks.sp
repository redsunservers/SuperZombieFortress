#define PLUGIN_VERSION "3.0.2"

// Soldier
#define ZFWEAP_ESCAPEPLAN 775

// Demoman
#define ZFWEAP_EYELANDER 132
#define ZFWEAP_SKULLCUTTER 172
#define ZFWEAP_PERSIAN 404
#define ZFWEAP_HHHHEADTAKER 266
#define ZFWEAP_GOLFCLUB 482
#define ZFWEAP_FESTIVELANDER 1082

// Heavy
#define ZFWEAP_GRU 239


// Medic
#define ZFWEAP_OVERDOSE 412

// Pyro
#define ZFWEAP_POWERJACK 214

// Required for TF2_FlagWeaponNoDrop
#define FLAG_DONT_DROP_WEAPON 				0x23E173A2
#define OFFSET_DONT_DROP					36

//
// Offsets
//
static int oActiveWeapon;
static int oCloakMeter;
static int oResAmmo[3];
static int oClipAmmo;

//
// ZF Class Objects
//
TFClassType[] ZF_SURVIVORS = {
	TFClass_Sniper, TFClass_Soldier, TFClass_DemoMan, TFClass_Medic, TFClass_Pyro, TFClass_Engineer };
TFClassType[] ZF_ZOMBIES = {
	TFClass_Scout, TFClass_Heavy, TFClass_Spy};

static const ZF_VALIDSURVIVOR[10] = {0,0,1,1,1,1,0,1,0,1};
static const int ZF_VALIDZOMBIE[10]	 = {0,1,0,0,0,0,1,0,1,0};

//
// ZF Team / Round State
//
enum ZFRoundState
{
	RoundInit1,
	RoundInit2,
	RoundGrace,
	RoundActive,
	RoundPost
};
static ZFRoundState zf_roundState = RoundInit1;
int zf_zomTeam = INT(TFTeam_Blue);
int zf_surTeam = INT(TFTeam_Red);

//
// Zombie Soul related indexes
//
int iZombieSoulIndex[10];
#define SKIN_ZOMBIE			5
#define SKIN_ZOMBIE_SPY		SKIN_ZOMBIE + 18

char cClassNames[10][16] = { "", "scout", "sniper", "soldier", "demo", "medic", "heavy", "pyro", "spy", "engineer" };

////////////////////////////////////////////////////////////
//
// Util Init
//
////////////////////////////////////////////////////////////
stock void utilBaseInit()
{
	//
	// Initialize offsets.
	//
	oActiveWeapon = FindSendPropInfo("CTFPlayer", "m_hActiveWeapon");
	oCloakMeter	 = FindSendPropInfo("CTFPlayer", "m_flCloakMeter");
	oResAmmo[0]	 = FindSendPropInfo("CTFPlayer", "m_iAmmo") + 4;
	oResAmmo[1]	 = FindSendPropInfo("CTFPlayer", "m_iAmmo") + 8;
	oResAmmo[2]	 = FindSendPropInfo("CTFPlayer", "m_iAmmo") + 12;
	oClipAmmo = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
}

////////////////////////////////////////////////////////////
//
// Math Utils
//
////////////////////////////////////////////////////////////
stock int max(int a, int b) { return (a > b) ? a : b; }
stock int min(int a, int b) { return (a < b) ? a : b; }
stock float fMax(float a, float b) { return (a > b) ? a : b; }
stock float fMin(float a, float b) { return (a < b) ? a : b; }

////////////////////////////////////////////////////////////
//
// ZF Team Utils
//
////////////////////////////////////////////////////////////
stock int zomTeam()
{ return zf_zomTeam; }
stock int surTeam()
{ return zf_surTeam; }
stock int setZomTeam(int team)
{ zf_zomTeam = team; }
stock int setSurTeam(int team)
{ zf_surTeam = team; }
stock int IsZombie(int client)
{ return (GetClientTeam(client) == zf_zomTeam); }
stock int IsSurvivor(int client)
{ return (GetClientTeam(client) == zf_surTeam); }

////////////////////////////////////////////////////////////
//
// Client Validity Utils
//
////////////////////////////////////////////////////////////
stock bool IsValidClient(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client); }
stock bool IsValidSurvivor(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsSurvivor(client); }
stock bool IsValidZombie(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsZombie(client); }
stock bool IsValidLivingClient(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsPlayerAlive(client); }
stock bool IsValidLivingSurvivor(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsPlayerAlive(client) && IsSurvivor(client); }
stock bool IsValidLivingZombie(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsPlayerAlive(client) && IsZombie(client); }
stock bool IsValidLivingPlayer(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsPlayerAlive(client) && (IsZombie(client) || IsSurvivor(client)); }

////////////////////////////////////////////////////////////
//
// ZF Class Utils
//
////////////////////////////////////////////////////////////
stock bool IsValidZombieClass(TFClassType class)
{ return (ZF_VALIDZOMBIE[class] == 1); }
stock bool IsValidSurvivorClass(TFClassType class)
{ return (ZF_VALIDSURVIVOR[class] == 1); }
stock TFClassType GetRandomZombieClass()
{ return ZF_ZOMBIES[GetRandomInt(0,2)]; }
stock TFClassType GetRandomSurvivorClass()
{ return ZF_SURVIVORS[GetRandomInt(0,5)]; }

stock bool isEngineer(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Engineer); }
stock bool isHeavy(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Heavy); }
stock bool isMedic(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Medic); }
stock bool isPyro(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Pyro); }
stock bool isScout(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Scout); }
stock bool isSpy(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Spy); }

////////////////////////////////////////////////////////////
//
// Map Utils
//
////////////////////////////////////////////////////////////
stock bool mapIsZF()
{
	char mapname[4];
	GetCurrentMap(mapname, sizeof(mapname));
	if (strncmp(mapname, "zf", 2, false) == 0) return true;
	if (strncmp(mapname, "szf", 3, false) == 0) return true;
	return false;
}

stock bool mapIsPL()
{
	char mapname[4];
	GetCurrentMap(mapname, sizeof(mapname));
	return strncmp(mapname, "pl_", 3, false) == 0;
}

stock bool mapIsCP()
{
	char mapname[4];
	GetCurrentMap(mapname, sizeof(mapname));
	return strncmp(mapname, "cp_", 3, false) == 0;
}

////////////////////////////////////////////////////////////
//
// Round Utils
//
////////////////////////////////////////////////////////////
stock void setRoundState(ZFRoundState _state)
{ zf_roundState = _state; }

stock ZFRoundState roundState()
{ return zf_roundState; }

stock void endRound(int winningTeam)
{
	int index = FindEntityByClassname(-1, "team_control_point_master");
	if(index == -1)
	{
		index = CreateEntityByName("team_control_point_master");
		DispatchSpawn(index);
	}

	if(index == -1)
	{
		LogError("[ZF] Can't create 'team_control_point_master,' can't end round!");
	}
	else
	{
		AcceptEntityInput(index, "Enable");
		SetVariantInt(winningTeam);
		AcceptEntityInput(index, "SetWinner");
	}
}

////////////////////////////////////////////////////////////
//
// Weapon State Utils
//
////////////////////////////////////////////////////////////
stock int activeWeapon(int client)
{ return GetEntDataEnt2(client, oActiveWeapon); }

stock int activeWeaponId(int client)
{
	int iWeapon = activeWeapon(client);
	return (iWeapon > MaxClients) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") : -1;
}

stock int slotWeaponId(int client, int slot)
{
	int iWeapon = GetPlayerWeaponSlot(client, slot);
	return (iWeapon > MaxClients) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") : -1;
}

stock int activeWeaponSlot(int client)
{
	int iWeapon = activeWeapon(client);
	if (iWeapon > MaxClients)
	{
		for (int i = 0; i < 5; i++)
		{
			if (GetPlayerWeaponSlot(client, i) == iWeapon)
			{
				return i;
			}
		}
	}
	return -1;
}

stock bool isEquipped(int client, int weaponId)
{
	for (int i = 0; i < 5; i++)
	{
		if (slotWeaponId(client, i) == weaponId)
		{
			return true;
		}
	}
	return false;
}

stock bool isWielding(int client, int weaponId)
{ return (activeWeaponId(client) == weaponId); }

stock bool isWieldingMelee(int client)
{ return (activeWeaponSlot(client) == 2); }

stock bool isSlotClassname(int iClient, int iSlot, char[] strClassname)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (iWeapon > MaxClients && IsValidEdict(iWeapon))
	{
		char strClassname2[32];
		GetEdictClassname(iWeapon, strClassname2, sizeof(strClassname2));
		if (StrEqual(strClassname, strClassname2, false)) return true;
	}
	return false;
}

////////////////////////////////////////////////////////////
//
// Attribute / Flags Utils (Simple)
//
////////////////////////////////////////////////////////////
stock void addCondKritz(int client, float duration)
{ TF2_AddCondition(client, TFCond_Kritzkrieged, duration); }
stock void remCondKritz(int client)
{ TF2_RemoveCondition(client, TFCond_Kritzkrieged); }

stock bool isSlowed(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Slowed); }
stock bool isKritzed(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged); }
stock bool isBonked(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Bonked); }
stock bool isDazed(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Dazed); }
stock bool isCharging(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Charging); }
stock bool isBeingHealed(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Healing); }
stock bool isCloaked(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Cloaked); }
stock bool isUbered(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Ubercharged); }
stock bool isOnFire(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_OnFire); }
stock bool isFirstBlood(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_CritOnFirstBlood); }

stock bool isGrounded(int client)
{ return (GetEntityFlags(client) & (FL_ONGROUND | FL_INWATER)) != 0; }
stock bool isCrouching(int client)
{ return (GetEntityFlags(client) & FL_DUCKING) != 0; }


////////////////////////////////////////////////////////////
//
// Speed Utils
//
////////////////////////////////////////////////////////////
stock void setClientSpeed(int client, float speed)
{
	// m_flMaxSpeed appears to be reset/recalculated when:
	// + after switching weapons and before next prethinkpost
	// + (soldier holding equalizer) every 17-19 frames
	SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", speed);
}

stock float clientBaseSpeed(int client)
{
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Soldier: return 240.0;	// Default 240.0
		case TFClass_DemoMan: return 280.0;	// Default 280.0
		case TFClass_Medic: return 300.0; // Default 320.0 <Slowed>
		case TFClass_Pyro: return 280.0; // Default 300.0 <Slowed>
		case TFClass_Engineer: return 300.0; // Default 300.0
		case TFClass_Sniper: return 300.0; // Default 300.0
		case TFClass_Scout: return 330.0; // Default 400.0 <Slowed>
		case TFClass_Spy: return 280.0;	// Default 320.0 <Slowed>
		case TFClass_Heavy: return 230.0; // Default 230.0
	}

	return 0.0;
}

stock float clientBonusSpeed(int client)
{
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:
		{
			if (TF2_IsPlayerInCondition(client, TFCond_CritCola))
			{
				//return 40.0;
				return 20.0;
			}
		}

		//
		// Handle soldier bonuses
		// + Wielding Equalizer
		//
		case TFClass_Soldier:
		{
			if (isWielding(client, ZFWEAP_ESCAPEPLAN))
			{
				int curH = GetClientHealth(client);
				if(curH > 160)	return 0.0;
				if(curH > 120)	return 24.0;
				if(curH > 80)	return 48.0;
				if(curH > 40)	return 96.0;
				if(curH > 0)	return 144.0;
			}
		}

		case TFClass_Pyro:
		{
			if (isWielding(client, ZFWEAP_POWERJACK))
			{
				return 36.0;
			}
		}

		//
		// Handle demoman bonuses
		// + Headcount from all swords but Skullcutter and Persuader
		// + Wielding Skullcutter
		//
		case TFClass_DemoMan:
		{
			if (isSlotClassname(client, 2, "tf_weapon_sword")
				&& !isEquipped(client, ZFWEAP_SKULLCUTTER)
				&& !isEquipped(client, ZFWEAP_PERSIAN))
			{
				int heads = GetEntProp(client, Prop_Send, "m_iDecapitations");
				return -40.0 + min(heads, 4) * 10.0;
			}

			else if (isEquipped(client, ZFWEAP_SKULLCUTTER))
			{
				return -42.0;
			}
		}
		
		//
		// Handle medic bonuses
		// + Wielding the Overdose
		//
		case TFClass_Medic:
		{
			// Overdose
			if (isWielding(client, ZFWEAP_OVERDOSE))
			{
				int iMedigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
				if (iMedigun > MaxClients && IsValidEdict(iMedigun))
				{
					return GetEntPropFloat(iMedigun, Prop_Send, "m_flChargeLevel") * 36;
				}
			}
		}



		//
		// Handle heavy bonuses
		// + Wielding GRU
		// + Affected by Steak or similar
		//
		case TFClass_Heavy:
		{
			if (isWielding(client, ZFWEAP_GRU))
			{
				return 70.0;
			}

			else if (TF2_IsPlayerInCondition(client, TFCond_CritCola))
			{
				//return 40.0;
				return 20.0;
			}
		}
	}

	return 0.0;
}

////////////////////////////////////////////////////////////
//
// Entity Name Utils
//
////////////////////////////////////////////////////////////
stock bool entClassnameContains(int ent, const char[] strRefClassname)
{
	if(IsValidEdict(ent) && IsValidEntity(ent))
	{
		char strName[32];
		GetEdictClassname(ent, strName, sizeof(strName));
		return (StrContains(strName, strRefClassname, false) != -1);
	}
	return false;
}

////////////////////////////////////////////////////////////
//
// Glow Utils
//
////////////////////////////////////////////////////////////
stock void setGlow(int client, bool glowEnabled)
{
	SetEntProp(client, Prop_Send, "m_bGlowEnabled", (glowEnabled ? 1 : 0));
}

////////////////////////////////////////////////////////////
//
// Sentry Utils
//
////////////////////////////////////////////////////////////
stock bool entIsSentry(int ent)
{ return entClassnameContains(ent, "obj_sentrygun"); }

////////////////////////////////////////////////////////////
//
// Cloak Utils
// + Range 0.0 to 100.0
//
////////////////////////////////////////////////////////////
stock float getCloak(int client)
{
	if(isSpy(client))
	{
		return GetEntDataFloat(client, oCloakMeter);
	}
	return 0.0;
}

stock void setCloak(int client, float cloakPct)
{
	if(isSpy(client))
	{
		SetEntDataFloat(client, oCloakMeter, cloakPct, true);
	}
}

////////////////////////////////////////////////////////////
//
// Uber Utils
// + Range 0.0 to 1.0
//
////////////////////////////////////////////////////////////
stock void addUber(int client, float uberPct)
{
	int weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon > MaxClients && isMedic(client))
	{
		float curPct = GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel");
		SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", fMin((curPct + uberPct), 1.0));
	}
}

stock void subUber(int client, float uberPct)
{
	int weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon > MaxClients && isMedic(client))
	{
		float curPct = GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel");
		SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", fMax((curPct - uberPct), 0.0));
	}
}

////////////////////////////////////////////////////////////
//
// Metal Add/Sub Utils
//
////////////////////////////////////////////////////////////
stock void addMetalPct(int client, float metalPct, float metalLimitPct = 1.0)
{
	if(isEngineer(client))
	{
		int curMetal = getMetal(client);
		int maxMetal = 200;
		int metal = RoundToCeil(maxMetal * metalPct);
		setMetal(client, min((curMetal + metal), RoundToCeil(maxMetal * metalLimitPct)));
	}
}

stock void subMetalPct(int client, float metalPct)
{
	if(isEngineer(client))
	{
		int curMetal = getMetal(client);
		int maxMetal = 200;
		int metal = RoundToCeil(maxMetal * metalPct);
		subMetal(client, max((curMetal - metal), 0));
	}
}

stock void addMetal(int client, int metal)
{
	if(isEngineer(client))
	{
		int curMetal = getMetal(client);
		setMetal(client, min((curMetal + metal), 200));
	}
}

stock void subMetal(int client, int metal)
{
	if(isEngineer(client))
	{
		int curMetal = getMetal(client);
		setMetal(client, max((curMetal - metal), 0));
	}
}

////////////////////////////////////////////////////////////
//
// Metal Get/Set Utils
//
////////////////////////////////////////////////////////////
stock int getMetal(int client)
{ return GetEntData(client, oResAmmo[2]); }

stock void setMetal(int client, int metal)
{ SetEntData(client, oResAmmo[2], min(metal, 255), true); }

////////////////////////////////////////////////////////////
//
// Ammo Add/Sub Utils
//
////////////////////////////////////////////////////////////

//
// Clip Ammo Utils
//
stock int getClipAmmo(int client, int slot)
{
	int iWeapon = GetPlayerWeaponSlot(client, slot);
	return (iWeapon > MaxClients) ? GetEntData(iWeapon, oClipAmmo) : 0;
}

stock void setClipAmmo(int client, int slot, int ammo)
{
	int iWeapon = GetPlayerWeaponSlot(client, slot);
	if (iWeapon > MaxClients) SetEntData(iWeapon, oClipAmmo, min(ammo, 255), true);
}

stock void addClipAmmo(int client, int slot, int ammo)
{
	int curAmmo = getClipAmmo(client, slot);
	int newAmmo = curAmmo + ammo;
	setClipAmmo(client, slot, newAmmo);
}

stock void subClipAmmo(int client, int slot, int ammo)
{
	int curAmmo = getClipAmmo(client, slot);
	setClipAmmo(client, slot, max((curAmmo - ammo), 0));
}

//
// Reserve Ammo Utils
//
stock int getResAmmo(int iClient, int slot)
{
	return GetEntData(iClient, oResAmmo[slot]);
	
	/*
	int iWeapon = GetPlayerWeaponSlot(iClient, slot);
	if (iWeapon > 0)
	{
		int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
		return GetEntProp(iClient, Prop_Send, "m_iAmmo", iAmmoType);
	}
	return 0;
	*/
}

stock void setResAmmo(int iClient, int slot, int ammo)
{
	SetEntData(iClient, oResAmmo[slot], min(ammo, 255), true);
	
	/*
	int iWeapon = GetPlayerWeaponSlot(iClient, slot);
	if (iWeapon > 0)
	{
		int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
		SetEntProp(iClient, Prop_Send, "m_iAmmo", ammo, _, iAmmoType);
	}
	*/
}

stock void addResAmmo(int client, int slot, int ammo)
{
	int curAmmo = getResAmmo(client, slot);
	int newAmmo = curAmmo + ammo;
	setResAmmo(client, slot, newAmmo);
}

stock void subResAmmo(int client, int slot, int ammo)
{
	int curAmmo = getResAmmo(client, slot);
	setResAmmo(client, slot, max((curAmmo - ammo), 0));
}

////////////////////////////////////////////////////////////
//
// Spawn Utils
//
////////////////////////////////////////////////////////////
stock void SpawnClient(int client, int nextClientTeam)
{
	// 1. Prevent players from spawning if they're on an invalid team.
	//		Prevent players from spawning as an invalid class.
	if (IsClientInGame(client) && (IsSurvivor(client) || IsZombie(client)))
	{
		TFClassType nextClientClass = TF2_GetPlayerClass(client);
		if (nextClientTeam == zomTeam() && !IsValidZombieClass(nextClientClass))
		{
			nextClientClass = GetRandomZombieClass();
		}
		if (nextClientTeam == surTeam() && !IsValidSurvivorClass(nextClientClass))
		{
			nextClientClass = GetRandomSurvivorClass();
		}

		// Use of m_lifeState here prevents:
		// 1. "[Player] Suicided" messages.
		// 2. Adding a death to player stats.
		TF2_RemoveAllWeapons(client);
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		TF2_SetPlayerClass(client, nextClientClass, false, true);
		ChangeClientTeam(client, nextClientTeam);
		SetEntProp(client, Prop_Send, "m_lifeState", 0);
		TF2_RespawnPlayer(client);
	}
}

stock void setTeamRespawnTime(int team, float time)
{
	int index = FindEntityByClassname(-1, "tf_gamerules");
	if(index != -1)
	{
		SetVariantFloat(time/2.0);
		if(team == INT(TFTeam_Blue))
			AcceptEntityInput(index, "SetBlueTeamRespawnWaveTime", -1, -1, 0);
		if(team == INT(TFTeam_Red))
			AcceptEntityInput(index, "SetRedTeamRespawnWaveTime", -1, -1, 0);
	}
}

////////////////////////////////////////////////////////////
//
// Damage Utils
//
////////////////////////////////////////////////////////////
stock void DealDamage(int iVictim, int iDamage, int iAttacker = 0, int iDmgType = DMG_GENERIC, char[] strWeapon = "")
{
	if (!IsValidClient(iAttacker)) iAttacker = 0;
	if (IsValidClient(iVictim) && iDamage > 0)
	{
		char strDamage[16];
		IntToString(iDamage, strDamage, 16);
		char strDamageType[32];
		IntToString(iDmgType, strDamageType, 32);
		int iHurt = CreateEntityByName("point_hurt");
		if (iHurt > 0 && IsValidEdict(iHurt))
		{
			DispatchKeyValue(iVictim, "targetname", "infectious_hurtme");
			DispatchKeyValue(iHurt, "DamageTarget", "infectious_hurtme");
			DispatchKeyValue(iHurt, "Damage", strDamage);
			DispatchKeyValue(iHurt, "DamageType", strDamageType);
			if (!StrEqual(strWeapon, "")) DispatchKeyValue(iHurt, "classname", strWeapon);
			DispatchSpawn(iHurt);
			AcceptEntityInput(iHurt, "Hurt", iAttacker);
			DispatchKeyValue(iHurt, "classname", "point_hurt");
			DispatchKeyValue(iVictim, "targetname", "infectious_donthurtme");
			RemoveEdict(iHurt);
		}
	}
}

////////////////////////////////////////////////////////////
//
// Weapon Utils
//
////////////////////////////////////////////////////////////

stock int TF2_CreateAndEquipWeapon(int iClient, int iIndex)
{
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), TF2_GetPlayerClass(iClient));
	
	int iWeapon = CreateEntityByName(sClassname);
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		// Allow quality / level override by updating through the offset.
		char netClass[64];
		GetEntityNetClass(iWeapon, netClass, sizeof(netClass));
		SetEntData(iWeapon, FindSendPropInfo(netClass, "m_iEntityQuality"), 6);
		SetEntData(iWeapon, FindSendPropInfo(netClass, "m_iEntityLevel"), 1);
		
		SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", 6);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		
		DispatchSpawn(iWeapon);
		
		if (StrContains(sClassname, "tf_wearable") == 0)
			SDK_EquipWearable(iClient, iWeapon);
		else
			EquipPlayerWeapon(iClient, iWeapon);
	}
	
	return iWeapon;
}

//Taken from STT
stock void TF2_FlagWeaponDontDrop(int iWeapon, bool visibleHack = true)
{
	int itemOffset = GetEntSendPropOffs(iWeapon, "m_Item", true);
	if (itemOffset <= 0) return;

	Address weaponAddress = GetEntityAddress(iWeapon);
	if (weaponAddress == Address_Null) return;

	Address addr = view_as<Address>((view_as<int>(weaponAddress)) + itemOffset + OFFSET_DONT_DROP); // Going to hijack CEconItemView::m_iInventoryPosition.
	//Need to build later on an anti weapon drop, using OnEntityCreated or something...

	StoreToAddress(addr, FLAG_DONT_DROP_WEAPON, NumberType_Int32);
	if (visibleHack) SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", 1);
}

////////////////////////////////////////////////////////////
//
// Cookie Utils
//
////////////////////////////////////////////////////////////

stock int GetCookie(int client, Handle cookie)
{
	if (!IsClientConnected(client) || !AreClientCookiesCached(client)) return 0;

	char strPoints[MAX_DIGITS];
	GetClientCookie(client, cookie, strPoints, sizeof(strPoints));
	return StringToInt(strPoints);
}

stock void AddToCookie(int client, int add, Handle cookie)
{
	if (!IsClientConnected(client) || !AreClientCookiesCached(client)) return;

	char strPoints[MAX_DIGITS];
	GetClientCookie(client, cookie, strPoints, sizeof(strPoints));

	int toAdd = add + StringToInt(strPoints);

	char strPoints2[MAX_DIGITS];
	IntToString(toAdd, strPoints2, sizeof(strPoints2));
	SetClientCookie(client, cookie, strPoints2);
}

stock void SetCookie(int client, int set, Handle cookie)
{
	if (!IsClientConnected(client) || !AreClientCookiesCached(client)) return;

	char strPoints2[MAX_DIGITS];
	IntToString(set, strPoints2, sizeof(strPoints2));
	SetClientCookie(client, cookie, strPoints2);
}

/******************************************************************************************************/

stock void GetClientName2(int iClient, char[] sName, int iLength)
{
	Call_StartForward(g_hForwardClientName);
	Call_PushCell(iClient);
	Call_PushStringEx(sName, iLength, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(iLength);
	Call_Finish();
	
	//If name still empty or could not be found, use default name and team color instead
	if (StrEqual(sName, ""))
	{
		GetClientName(iClient, sName, iLength);
		Format(sName, iLength, "{teamcolor}%s", sName);
	}
}

stock void AddModelToDownload(char[] strModel)
{
	char strPath[256];
	char ModelExtensions[][] = {
		".mdl",
		".dx80.vtx",
		".dx90.vtx",
		".sw.vtx",
		".vvd",
		".phy"
	};

	for (int iExt = 0; iExt < sizeof(ModelExtensions); iExt++)
	{
		Format(strPath, sizeof(strPath), "models/%s%s", strModel, ModelExtensions[iExt]);
		AddFileToDownloadsTable(strPath);
	}
}

stock int FindEntityByTargetname(const char[] targetname, const char[] classname)
{
	char namebuf[32];
	int index = -1;
	namebuf[0] = '\0';

	while(strcmp(namebuf, targetname) != 0
		&& (index = FindEntityByClassname(index, classname)) != -1)
		GetEntPropString(index, Prop_Data, "m_iName", namebuf, sizeof(namebuf));

	return(index);
}

stock void Shake(int iClient, float flAmplitude, float flDuration)
{
	BfWrite hShake = view_as<BfWrite>(StartMessageOne("Shake", iClient));
	hShake.WriteByte(0); // 0x0000 = start shake
	hShake.WriteFloat(flAmplitude);
	hShake.WriteFloat(1.0);
	hShake.WriteFloat(flDuration);
	EndMessage();
}

stock void SpawnPickup(int iClient, const char[] strClassname)
{
	float PlayerPosition[3];
	GetClientAbsOrigin(iClient, PlayerPosition);
	PlayerPosition[2] += 16.0;
	int iEntity = CreateEntityByName(strClassname);
	DispatchKeyValue(iEntity, "OnPlayerTouch", "!self,Kill,,0,-1");
	if (DispatchSpawn(iEntity))
	{
		SetEntProp(iEntity, Prop_Send, "m_iTeamNum", 0, 4);
		TeleportEntity(iEntity, PlayerPosition, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(0.15, TimerKillEntity, iEntity);
	}
}

public Action TimerKillEntity(Handle hTimer, int iEntity)
{
	if (IsValidEntity(iEntity))
	{
		AcceptEntityInput(iEntity, "Kill");
	}
}

/******************************************************************************************************/

stock int PrecacheZombieSouls()
{
	char cPath[64];
	// loops through all class types available
	for (int i = 1; i <= 9; i++)
	{
		Format(cPath, sizeof(cPath), "models/player/items/%s/%s_zombie.mdl", cClassNames[i], cClassNames[i]);
		iZombieSoulIndex[i] = PrecacheModel(cPath);
	}
}

stock void ApplyVoodooCursedSoul(int iClient)
{
	if (!bTF2Items || TF2_IsPlayerInCondition(iClient, TFCond_HalloweenGhostMode)) return;

	TF2_CreateAndEquipFakeModel(iClient, view_as<int>(TF2_GetPlayerClass(iClient)));

	SetEntProp(iClient, Prop_Send, "m_bForcedSkin", true);
	SetEntProp(iClient, Prop_Send, "m_nForcedSkin", (isSpy(iClient)) ? SKIN_ZOMBIE_SPY : SKIN_ZOMBIE);
}

stock int TF2_CreateAndEquipFakeModel(int iClient, int iModelIndex)
{
	#if defined _tf2items_included // This requires TF2items to be included
	Handle hWearable = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if (hWearable == INVALID_HANDLE) return -1;

	TF2Items_SetClassname(hWearable, "tf_wearable");
	TF2Items_SetItemIndex(hWearable, 5023);
	TF2Items_SetLevel(hWearable, 50);
	TF2Items_SetQuality(hWearable, 6);

	int iWearable = TF2Items_GiveNamedItem(iClient, hWearable);
	delete hWearable;
	if (IsValidEdict(iWearable))
	{
		SetEntProp(iWearable, Prop_Send, "m_bValidatedAttachedEntity", true);
		if (g_hSDKEquipWearable != INVALID_HANDLE)
		{
			SDKCall(g_hSDKEquipWearable, iClient, iWearable);
			SetEntProp(iWearable, Prop_Send, "m_bValidatedAttachedEntity", true);
			SetEntProp(iWearable, Prop_Send, "m_nModelIndexOverrides", iModelIndex);
			return iWearable;
		}
	}
	#endif

	return -1;
}
