//Soldier
#define WEAPON_ESCAPEPLAN 775

//Demoman
#define WEAPON_SKULLCUTTER 172
#define WEAPON_PERSIAN 404

//Medic
#define WEAPON_OVERDOSE 412

//Pyro
#define WEAPON_POWERJACK 214

//Required for TF2_FlagWeaponNoDrop
#define FLAG_DONT_DROP_WEAPON 				0x23E173A2
#define OFFSET_DONT_DROP					36

//ZF Class Objects
TFClassType[] g_nSurvivorClass = { TFClass_Sniper, TFClass_Soldier, TFClass_DemoMan, TFClass_Medic, TFClass_Pyro, TFClass_Engineer };
TFClassType[] g_nZombieClass = { TFClass_Scout, TFClass_Heavy, TFClass_Spy };

static const bool g_bValidSurvivor[view_as<int>(TFClassType)] = { false, false, true, true, true, true, false, true, false, true};
static const bool g_bValidZombie[view_as<int>(TFClassType)]	 = { false, true, false, false, false, false, true, false, true, false};

//Zombie Soul related indexes
#define SKIN_ZOMBIE			5
#define SKIN_ZOMBIE_SPY		SKIN_ZOMBIE + 18

char g_sClassNames[view_as<int>(TFClassType)][16] = { "", "scout", "sniper", "soldier", "demo", "medic", "heavy", "pyro", "spy", "engineer" };
int g_iVoodooIndex[view_as<int>(TFClassType)] =  {-1, 5617, 5625, 5618, 5620, 5622, 5619, 5624, 5623, 5616};
int g_iZombieSoulIndex[view_as<int>(TFClassType)];

////////////////////////////////////////////////////////////
//
// Math Utils
//
////////////////////////////////////////////////////////////

stock int max(int a, int b)
{
	return (a > b) ? a : b;
}

stock int min(int a, int b)
{
	return (a < b) ? a : b;
}

stock float fMax(float a, float b)
{
	return (a > b) ? a : b;
}

stock float fMin(float a, float b)
{
	return (a < b) ? a : b;
}

////////////////////////////////////////////////////////////
//
// SZF Team Utils
//
////////////////////////////////////////////////////////////

stock int IsZombie(int iClient)
{
	return TF2_GetClientTeam(iClient) == TFTeam_Zombie;
}

stock int IsSurvivor(int iClient)
{
	return TF2_GetClientTeam(iClient) == TFTeam_Survivor;
}

////////////////////////////////////////////////////////////
//
// Client Validity Utils
//
////////////////////////////////////////////////////////////

stock bool IsValidClient(int iClient)
{
	return 0 < iClient <= MaxClients && IsClientInGame(iClient) && !IsClientSourceTV(iClient) && !IsClientReplay(iClient);
}

stock bool IsValidSurvivor(int iClient)
{
	return IsValidClient(iClient) && IsSurvivor(iClient);
}

stock bool IsValidZombie(int iClient)
{
	return IsValidClient(iClient) && IsZombie(iClient);
}

stock bool IsValidLivingClient(int iClient)
{
	return IsValidClient(iClient) && IsPlayerAlive(iClient);
}

stock bool IsValidLivingSurvivor(int iClient)
{
	return IsValidSurvivor(iClient) && IsPlayerAlive(iClient);
}

stock bool IsValidLivingZombie(int iClient)
{
	return IsValidZombie(iClient) && IsPlayerAlive(iClient);
}

////////////////////////////////////////////////////////////
//
// SZF Class Utils
//
////////////////////////////////////////////////////////////

stock bool IsValidZombieClass(TFClassType nClass)
{
	return g_bValidZombie[nClass];
}

stock bool IsValidSurvivorClass(TFClassType nClass)
{
	return g_bValidSurvivor[nClass];
}

stock TFClassType GetRandomZombieClass()
{
	return g_nZombieClass[GetRandomInt(0, sizeof(g_nZombieClass)-1)];
}

stock TFClassType GetRandomSurvivorClass()
{
	return g_nSurvivorClass[GetRandomInt(0, sizeof(g_nSurvivorClass)-1)];
}

////////////////////////////////////////////////////////////
//
// Map Utils
//
////////////////////////////////////////////////////////////

stock bool IsMapSZF()
{
	char sMap[8];
	GetCurrentMap(sMap, sizeof(sMap));
	GetMapDisplayName(sMap, sMap, sizeof(sMap));
	if (StrContains(sMap, "zf_") == 0) return true;
	if (StrContains(sMap, "szf_") == 0) return true;
	return false;
}

////////////////////////////////////////////////////////////
//
// Round Utils
//
////////////////////////////////////////////////////////////

stock void TF2_EndRound(TFTeam nTeam)
{
	int iIndex = FindEntityByClassname(-1, "team_control_point_master");
	if (iIndex == -1)
	{
		iIndex = CreateEntityByName("team_control_point_master");
		DispatchSpawn(iIndex);
	}
	
	if (iIndex == -1)
	{
		LogError("[SZF] Can't create 'team_control_point_master,' can't end round!");
	}
	else
	{
		AcceptEntityInput(iIndex, "Enable");
		SetVariantInt(view_as<int>(nTeam));
		AcceptEntityInput(iIndex, "SetWinner");
	}
}

////////////////////////////////////////////////////////////
//
// Weapon State Utils
//
////////////////////////////////////////////////////////////

stock int TF2_GetActiveWeapon(int iClient)
{
	return GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}

stock int TF2_GetActiveWeaponIndex(int iClient)
{
	int iWeapon = TF2_GetActiveWeapon(iClient);
	if (iWeapon > MaxClients)
		return GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	
	return -1;
}

stock int TF2_GetSlotIndex(int iClient, int iSlot)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (iWeapon > MaxClients)
		return GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	
	return -1;
}

stock int TF2_GetActiveSlot(int iClient)
{
	int iWeapon = TF2_GetActiveWeapon(iClient);
	
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
		if (GetPlayerWeaponSlot(iClient, iSlot) == iWeapon)
			return iSlot;
	
	return -1;
}

stock bool TF2_IsEquipped(int iClient, int iIndex)
{
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
		if (TF2_GetSlotIndex(iClient, iSlot) == iIndex)
			return true;
	
	return false;
}

stock bool TF2_IsWielding(int iClient, int iIndex)
{
	return TF2_GetActiveWeaponIndex(iClient) == iIndex;
}

stock bool TF2_IsSlotClassname(int iClient, int iSlot, char[] sClassname)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (iWeapon > MaxClients && IsValidEdict(iWeapon))
	{
		char sClassname2[32];
		GetEdictClassname(iWeapon, sClassname2, sizeof(sClassname2));
		if (StrEqual(sClassname, sClassname2))
			return true;
	}
	
	return false;
}

////////////////////////////////////////////////////////////
//
// Speed Utils
//
////////////////////////////////////////////////////////////

stock void SetClientSpeed(int iClient, float flSpeed)
{
	// m_flMaxSpeed appears to be reset/recalculated when:
	// + after switching weapons and before next prethinkpost
	// + (soldier holding equalizer) every 17-19 frames
	SetEntPropFloat(iClient, Prop_Data, "m_flMaxspeed", flSpeed);
}

stock float GetClientBaseSpeed(int iClient)
{
	switch (TF2_GetPlayerClass(iClient))
	{
		case TFClass_Soldier: return 240.0;	//Default 240.0
		case TFClass_DemoMan: return 280.0;	//Default 280.0
		case TFClass_Medic: return 300.0; //Default 320.0 <Slowed>
		case TFClass_Pyro: return 280.0; //Default 300.0 <Slowed>
		case TFClass_Engineer: return 300.0; //Default 300.0
		case TFClass_Sniper: return 300.0; //Default 300.0
		case TFClass_Scout: return 330.0; //Default 400.0 <Slowed>
		case TFClass_Spy: return 280.0;	//Default 320.0 <Slowed>
		case TFClass_Heavy: return 230.0; //Default 230.0
	}
	
	return 0.0;
}

stock float GetClientBonusSpeed(int iClient)
{
	switch (TF2_GetPlayerClass(iClient))
	{
		case TFClass_Scout:
		{
			if (TF2_IsPlayerInCondition(iClient, TFCond_CritCola))
			{
				return 20.0;
			}
		}
		case TFClass_Soldier:
		{
			if (TF2_IsWielding(iClient, WEAPON_ESCAPEPLAN))
			{
				int iHealth = GetClientHealth(iClient);
				if (iHealth > 160) return 0.0;
				if (iHealth > 120) return 24.0;
				if (iHealth > 80) return 48.0;
				if (iHealth > 40) return 96.0;
				if (iHealth > 0) return 144.0;
			}
		}
		case TFClass_Pyro:
		{
			if (TF2_IsWielding(iClient, WEAPON_POWERJACK))
			{
				return 36.0;
			}
		}
		case TFClass_DemoMan:
		{
			//Eyelander
			if (TF2_IsSlotClassname(iClient, 2, "tf_weapon_sword")
				&& !TF2_IsEquipped(iClient, WEAPON_SKULLCUTTER)
				&& !TF2_IsEquipped(iClient, WEAPON_PERSIAN))
			{
				int iHeads = GetEntProp(iClient, Prop_Send, "m_iDecapitations");
				return -40.0 + min(iHeads, 4) * 10.0;
			}
			else if (TF2_IsEquipped(iClient, WEAPON_SKULLCUTTER))
			{
				return -42.0;
			}
		}
		case TFClass_Medic:
		{
			//Overdose
			if (TF2_IsWielding(iClient, WEAPON_OVERDOSE))
			{
				int iMedigun = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary);
				if (iMedigun > MaxClients && IsValidEdict(iMedigun))
					return GetEntPropFloat(iMedigun, Prop_Send, "m_flChargeLevel") * 36;
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

stock bool IsClassnameContains(int iEntity, const char[] sClassname)
{
	if (IsValidEdict(iEntity) && IsValidEntity(iEntity))
	{
		char sClassname2[32];
		GetEdictClassname(iEntity, sClassname2, sizeof(sClassname2));
		return (StrContains(sClassname2, sClassname, false) != -1);
	}
	
	return false;
}

stock bool TF2_IsSentry(int ent)
{
	return IsClassnameContains(ent, "obj_sentrygun");
}

////////////////////////////////////////////////////////////
//
// Glow Utils
//
////////////////////////////////////////////////////////////

stock void TF2_SetGlow(int iClient, bool bEnable)
{
	SetEntProp(iClient, Prop_Send, "m_bGlowEnabled", bEnable);
}

////////////////////////////////////////////////////////////
//
// Cloak Utils
// + Range 0.0 to 100.0
//
////////////////////////////////////////////////////////////

stock float TF2_GetCloakMeter(int iClient)
{
	if (TF2_GetPlayerClass(iClient) == TFClass_Spy)
		return GetEntPropFloat(iClient, Prop_Send, "m_flCloakMeter");
	
	return 0.0;
}

stock void TF2_SetCloakMeter(int iClient, float flCloak)
{
	if (TF2_GetPlayerClass(iClient) == TFClass_Spy)
		SetEntPropFloat(iClient, Prop_Send, "m_flCloakMeter", flCloak);
}

////////////////////////////////////////////////////////////
//
// Uber Utils
// + Range 0.0 to 1.0
//
////////////////////////////////////////////////////////////

stock void TF2_AddUber(int iClient, float flCharge)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, WeaponSlot_Secondary);
	if(iWeapon > MaxClients && TF2_GetPlayerClass(iClient) == TFClass_Medic)
	{
		flCharge += GetEntPropFloat(iWeapon, Prop_Send, "m_flChargeLevel");
		SetEntPropFloat(iWeapon, Prop_Send, "m_flChargeLevel", fMin(flCharge, 1.0));
	}
}

stock void TF2_RemoveUber(int iClient, float flCharge)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, WeaponSlot_Secondary);
	if(iWeapon > MaxClients && TF2_GetPlayerClass(iClient) == TFClass_Medic)
	{
		flCharge -= GetEntPropFloat(iWeapon, Prop_Send, "m_flChargeLevel");
		SetEntPropFloat(iWeapon, Prop_Send, "m_flChargeLevel", fMax(flCharge , 0.0));
	}
}

////////////////////////////////////////////////////////////
//
// Metal Utils
//
////////////////////////////////////////////////////////////

stock void TF2_AddMetal(int iClient, int iMetal)
{
	if (TF2_GetPlayerClass(iClient) == TFClass_Engineer)
	{
		iMetal += TF2_GetMetal(iClient);
		TF2_SetMetal(iClient, min(iMetal, 200));
	}
}

stock void TF2_RemoveMetal(int iClient, int iMetal)
{
	if (TF2_GetPlayerClass(iClient) == TFClass_Engineer)
	{
		iMetal -= TF2_GetMetal(iClient);
		TF2_SetMetal(iClient, max(iMetal, 0));
	}
}

stock int TF2_GetMetal(int iClient)
{
	return GetEntProp(iClient, Prop_Send, "m_iAmmo", _, 3);
}

stock void TF2_SetMetal(int iClient, int iMetal)
{
	SetEntProp(iClient, Prop_Send, "m_iAmmo", iMetal, _, 3);
}

////////////////////////////////////////////////////////////
//
// Ammo Add/Sub Utils
//
////////////////////////////////////////////////////////////

stock int TF2_GetClip(int iClient, int iSlot)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (iWeapon > MaxClients)
		return GetEntProp(iWeapon, Prop_Send, "m_iClip1");
	
	return 0;
}

stock void TF2_SetClip(int iClient, int iSlot, int iClip)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (iWeapon > MaxClients)
		SetEntProp(iWeapon, Prop_Send, "m_iClip1", iClip);
}

stock void TF2_AddClip(int iClient, int iSlot, int iClip)
{
	iClip += TF2_GetClip(iClient, iSlot);
	TF2_SetClip(iClient, iSlot, iClip);
}

stock void TF2_RemoveClip(int iClient, int iSlot, int iClip)
{
	iClip -= TF2_GetClip(iClient, iSlot);
	TF2_SetClip(iClient, iSlot, max(iClip, 0));
}

stock int TF2_GetAmmo(int iClient, int iSlot)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (iWeapon > MaxClients)
	{
		int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmoType > -1)
			return GetEntProp(iClient, Prop_Send, "m_iAmmo", _, iAmmoType);
	}
	
	return 0;
}

stock void TF2_SetAmmo(int iClient, int iSlot, int iAmmo)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (iWeapon > 0)
	{
		int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmoType > -1)
			SetEntProp(iClient, Prop_Send, "m_iAmmo", iAmmo, _, iAmmoType);
	}
}

stock void TF2_AddAmmo(int iClient, int iSlot, int iAmmo)
{
	iAmmo += TF2_GetAmmo(iClient, iSlot);
	TF2_SetAmmo(iClient, iSlot, iAmmo);
}

stock void TF2_RemoveAmmo(int iClient, int iSlot, int iAmmo)
{
	iAmmo -= TF2_GetAmmo(iClient, iSlot);
	TF2_SetAmmo(iClient, iSlot, max(iAmmo, 0));
}

////////////////////////////////////////////////////////////
//
// Spawn Utils
//
////////////////////////////////////////////////////////////

stock void SpawnClient(int iClient, TFTeam nTeam)
{
	//1. Prevent players from spawning if they're on an invalid team.
	//        Prevent players from spawning as an invalid class.
	if (IsClientInGame(iClient) && (IsSurvivor(iClient) || IsZombie(iClient)))
	{
		TFClassType nClass = TF2_GetPlayerClass(iClient);
		if (nTeam == TFTeam_Zombie && !IsValidZombieClass(nClass))
			nClass = GetRandomZombieClass();
		
		if (nTeam == TFTeam_Survivor && !IsValidSurvivorClass(nClass))
			nClass = GetRandomSurvivorClass();
		
		//Use of m_lifeState here prevents:
		//1. "[Player] Suicided" messages.
		//2. Adding a death to player stats.
		TF2_RemoveAllWeapons(iClient);
		SetEntProp(iClient, Prop_Send, "m_lifeState", 2);
		TF2_SetPlayerClass(iClient, nClass, false, true);
		TF2_ChangeClientTeam(iClient, nTeam);
		SetEntProp(iClient, Prop_Send, "m_lifeState", 0);
		TF2_RespawnPlayer(iClient);
	}
}

stock void SetTeamRespawnTime(TFTeam nTeam, float flTime)
{
	int iEntity = FindEntityByClassname(-1, "tf_gamerules");
	if (iEntity != -1)
	{
		SetVariantFloat(flTime/2.0);
		switch (nTeam)
		{
			case TFTeam_Blue: AcceptEntityInput(iEntity, "SetBlueTeamRespawnWaveTime", -1, -1, 0);
			case TFTeam_Red: AcceptEntityInput(iEntity, "SetRedTeamRespawnWaveTime", -1, -1, 0);
		}
	}
}

////////////////////////////////////////////////////////////
//
// Weapon Utils
//
////////////////////////////////////////////////////////////

stock int TF2_CreateAndEquipWeapon(int iClient, int iIndex, char[] sAttribs = "", char[] sText = "")
{
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), TF2_GetPlayerClass(iClient));
	
	int iWeapon = CreateEntityByName(sClassname);
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		//Allow quality / level override by updating through the offset.
		char netClass[64];
		GetEntityNetClass(iWeapon, netClass, sizeof(netClass));
		SetEntData(iWeapon, FindSendPropInfo(netClass, "m_iEntityQuality"), 6);
		SetEntData(iWeapon, FindSendPropInfo(netClass, "m_iEntityLevel"), 1);
		
		SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", 6);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		
		//Attribute shittery inbound
		if (!StrEqual(sAttribs, ""))
		{
			char atts[32][32];
			int iCount = ExplodeString(sAttribs, " ; ", atts, 32, 32);
			if (iCount > 1)
				for (int i = 0; i < iCount; i+= 2)
					TF2Attrib_SetByDefIndex(iWeapon, StringToInt(atts[i]), StringToFloat(atts[i+1]));
		}
		
		if (g_flStopChatSpam[iClient] < GetGameTime() && !StrEqual(sText, ""))
		{
			CPrintToChat(iClient, sText);
			g_flStopChatSpam[iClient] = GetGameTime() + 1.0;
		}
		
		DispatchSpawn(iWeapon);
		SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		
		if (StrContains(sClassname, "tf_wearable") == 0)
			SDK_EquipWearable(iClient, iWeapon);
		else
			EquipPlayerWeapon(iClient, iWeapon);
	}
	
	return iWeapon;
}

//Taken from STT
stock void TF2_FlagWeaponDontDrop(int iWeapon, bool bVisibleHack = true)
{
	int iOffset = GetEntSendPropOffs(iWeapon, "m_Item", true);
	if (iOffset <= 0)
		return;
	
	Address weaponAddress = GetEntityAddress(iWeapon);
	if (weaponAddress == Address_Null)
		return;
	
	Address addr = view_as<Address>((view_as<int>(weaponAddress)) + iOffset + OFFSET_DONT_DROP); //Going to hijack CEconItemView::m_iInventoryPosition.
	//Need to build later on an anti weapon drop, using OnEntityCreated or something...
	
	StoreToAddress(addr, FLAG_DONT_DROP_WEAPON, NumberType_Int32);
	if (bVisibleHack) SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", 1);
}

////////////////////////////////////////////////////////////
//
// Cookie Utils
//
////////////////////////////////////////////////////////////

stock int GetCookie(int iClient, Cookie cookie)
{
	if (!IsClientConnected(iClient) || !AreClientCookiesCached(iClient))
		return 0;
	
	char sValue[8];
	cookie.Get(iClient, sValue, sizeof(sValue));
	return StringToInt(sValue);
}

stock void AddToCookie(int iClient, int iAmount, Cookie cookie)
{
	if (!IsClientConnected(iClient) || !AreClientCookiesCached(iClient))
		return;
	
	char sValue[8];
	cookie.Get(iClient, sValue, sizeof(sValue));
	iAmount += StringToInt(sValue);
	IntToString(iAmount, sValue, sizeof(sValue));
	cookie.Set(iClient, sValue);
}

stock void SetCookie(int iClient, int iAmount, Cookie cookie)
{
	if (!IsClientConnected(iClient) || !AreClientCookiesCached(iClient))
		return;
	
	char sValue[8];
	IntToString(iAmount, sValue, sizeof(sValue));
	cookie.Set(iClient, sValue);
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
	if (sName[0] == '\0')
	{
		GetClientName(iClient, sName, iLength);
		Format(sName, iLength, "{teamcolor}%s", sName);
	}
}

stock void AddModelToDownload(char[] sModel)
{
	char sPath[256];
	const char sModelExtensions[][] = {
		".mdl",
		".dx80.vtx",
		".dx90.vtx",
		".sw.vtx",
		".vvd",
		".phy"
	};
	
	for (int iExt = 0; iExt < sizeof(sModelExtensions); iExt++)
	{
		Format(sPath, sizeof(sPath), "models/%s%s", sModel, sModelExtensions[iExt]);
		AddFileToDownloadsTable(sPath);
	}
}

stock int FindEntityByTargetname(const char[] sTargetName, const char[] sClassname)
{
	char sBuffer[32];
	int iEntity = -1;
	
	while(strcmp(sClassname, sTargetName) != 0 && (iEntity = FindEntityByClassname(iEntity, classname)) != -1)
		GetEntPropString(iEntity, Prop_Data, "m_iName", sBuffer, sizeof(sBuffer));
	
	return iEntity;
}

stock void Shake(int iClient, float flAmplitude, float flDuration)
{
	BfWrite bf = UserMessageToBfWrite(StartMessageOne("Shake", iClient));
	bf.WriteByte(0); //0x0000 = start shake
	bf.WriteFloat(flAmplitude);
	bf.WriteFloat(1.0);
	bf.WriteFloat(flDuration);
	EndMessage();
}

stock void SpawnPickup(int iClient, const char[] sClassname)
{
	float vecOrigin[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	vecOrigin[2] += 16.0;
	
	int iEntity = CreateEntityByName(sClassname);
	DispatchKeyValue(iEntity, "OnPlayerTouch", "!self,Kill,,0,-1");
	if (DispatchSpawn(iEntity))
	{
		SetEntProp(iEntity, Prop_Send, "m_iTeamNum", 0, 4);
		TeleportEntity(iEntity, vecOrigin, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(0.15, Timer_KillEntity, EntIndexToEntRef(iEntity));
	}
}

public Action Timer_KillEntity(Handle hTimer, int iRef)
{
	int iEntity = EntRefToEntIndex(iRef);
	if (IsValidEntity(iEntity))
		AcceptEntityInput(iEntity, "Kill");
}

//Yoinked from https://github.com/DFS-Servers/Super-Zombie-Fortress/blob/master/addons/sourcemod/scripting/include/szf_util_base.inc
stock void SZF_CPrintToChatAll(int iClient, char[] sText, bool bTeam = false, const char[] sParam1="", const char[] sParam2="", const char[] sParam3="", const char[] sParam4="")
{
	if (bTeam && !IsValidClient(iClient))
		return;
	
	char sName[80], sMessage[255];
	if (0 < iClient <= MaxClients)
	{
		GetClientName2(iClient, sName, sizeof(sName));
		if (bTeam)
			Format(sMessage, sizeof(sMessage), "\x01(TEAM) %s\x01 : %s", sName, sText);
		else
			Format(sMessage, sizeof(sMessage), "\x01%s\x01 : %s\x01", sName, sText);
	}
	
	ReplaceString(sMessage, sizeof(sMessage), "{param1}", "%s1");
	ReplaceString(sMessage, sizeof(sMessage), "{param2}", "%s2");
	ReplaceString(sMessage, sizeof(sMessage), "{param3}", "%s3");
	ReplaceString(sMessage, sizeof(sMessage), "{param4}", "%s4");
	CReplaceColorCodes(sMessage, iClient, _, sizeof(sMessage));
	
	int iClients[MAXPLAYERS+1], iLength;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || (bTeam &&  GetClientTeam(i) != GetClientTeam(iClient)))
			continue;
		
		iClients[iLength++] = i;
	}
	
	SayText2(iClients, iLength, iClient, true, sMessage, sParam1, sParam2, sParam3, sParam4);
}

stock void SayText2(int[] iClients, int iLength, int iEntity, bool bChat, const char[] sMessage, const char[] sParam1="", const char[] sParam2="", const char[] sParam3="", const char[] sParam4="")
{
	BfWrite bf = UserMessageToBfWrite(StartMessage("SayText2", iClients, iLength, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS)); 
	
	bf.WriteByte(iEntity);
	bf.WriteByte(true);
	
	bf.WriteString(sMessage); 
	
	bf.WriteString(sParam1); 
	bf.WriteString(sParam2); 
	bf.WriteString(sParam3);
	bf.WriteString(sParam4);
	
	EndMessage();
}

/******************************************************************************************************/

stock int PrecacheZombieSouls()
{
	char sPath[64];
	//Loops through all class types available
	for (int iClass = 1; iClass < view_as<int>(TFClassType); iClass++)
	{
		Format(sPath, sizeof(sPath), "models/player/items/%s/%s_zombie.mdl", g_sClassNames[iClass], g_sClassNames[iClass]);
		g_iZombieSoulIndex[iClass] = PrecacheModel(sPath);
	}
}

stock void ApplyVoodooCursedSoul(int iClient)
{
	if (TF2_IsPlayerInCondition(iClient, TFCond_HalloweenGhostMode))
		return;
	
	SetEntProp(iClient, Prop_Send, "m_bForcedSkin", true);
	SetEntProp(iClient, Prop_Send, "m_nForcedSkin", (TF2_GetPlayerClass(iClient) == TFClass_Spy) ? SKIN_ZOMBIE_SPY : SKIN_ZOMBIE);
	
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	int iWearable = TF2_CreateAndEquipWeapon(iClient, g_iVoodooIndex[view_as<int>(nClass)]);	//Not really a weapon, but still works
	if (IsValidEntity(iWearable))
		SetEntProp(iWearable, Prop_Send, "m_nModelIndexOverrides", g_iZombieSoulIndex[view_as<int>(nClass)]);
}

/******************************************************************************************************/

//SDKHooks_TakeDamage doesn't call OnTakeDamage, so we need to scale separately for 'indirect' damage
stock void DealDamage(int iAttacker, int iVictim, float flDamage)
{
	if (g_flZombieDamageScale < 1.0)
		flDamage *= g_flZombieDamageScale;
	
	if (g_bBackstabbed[iVictim] && flDamage > STUNNED_DAMAGE_CAP)
		flDamage = STUNNED_DAMAGE_CAP;
	
	SDKHooks_TakeDamage(iVictim, iAttacker, iAttacker, flDamage, DMG_PREVENT_PHYSICS_FORCE);
}