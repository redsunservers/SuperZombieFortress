//Scout
#define WEAPON_BFB 772

//Soldier
#define WEAPON_ESCAPEPLAN 775

//Pyro
#define WEAPON_POWERJACK 214

//Demoman
#define WEAPON_SKULLCUTTER 172
#define WEAPON_CLAIDHEAMHMOR 327
#define WEAPON_PERSIAN 404

//Heavy
#define WEAPON_GRU 239
#define WEAPON_FGRU 1084
#define WEAPON_BREADBITE 1110
#define WEAPON_EVICTIONNOTICE 426

//Medic
#define WEAPON_OVERDOSE 412

//Required for TF2_FlagWeaponNoDrop
#define FLAG_DONT_DROP_WEAPON 				0x23E173A2
#define OFFSET_DONT_DROP					36

//Zombie Soul related indexes
#define SKIN_ZOMBIE			5
#define SKIN_ZOMBIE_SPY		SKIN_ZOMBIE + 18

static char g_sClassFiles[view_as<int>(TFClassType)][16] = { "", "scout", "sniper", "soldier", "demo", "medic", "heavy", "pyro", "spy", "engineer" };
static int g_iVoodooIndex[view_as<int>(TFClassType)] =  {-1, 5617, 5625, 5618, 5620, 5622, 5619, 5624, 5623, 5616};
static int g_iZombieSoulIndex[view_as<int>(TFClassType)];

////////////////
// Math
////////////////

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

stock void VectorTowards(const float vecOrigin[3], const float vecTarget[3], float vecAngle[3])
{
	float vecResults[3];
	MakeVectorFromPoints(vecOrigin, vecTarget, vecResults);
	GetVectorAngles(vecResults, vecAngle);
}

stock void AnglesToVelocity(const float vecAngle[3], float vecVelocity[3], float flSpeed = 1.0)
{
	vecVelocity[0] = Cosine(DegToRad(vecAngle[1]));
	vecVelocity[1] = Sine(DegToRad(vecAngle[1]));
	vecVelocity[2] = Sine(DegToRad(vecAngle[0])) * -1.0;
	
	NormalizeVector(vecVelocity, vecVelocity);
	
	ScaleVector(vecVelocity, flSpeed);
}

////////////////
// SZF Team
////////////////

stock int IsZombie(int iClient)
{
	return TF2_GetClientTeam(iClient) == TFTeam_Zombie;
}

stock int IsSurvivor(int iClient)
{
	return TF2_GetClientTeam(iClient) == TFTeam_Survivor;
}

stock int GetZombieCount()
{
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient))
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

stock int GetActivePlayerCount()
{
	int i = 0;
	for (int j = 1; j <= MaxClients; j++)
		if (IsValidLivingClient(j)) i++;
	
	return i;
}

stock int GetReplaceRageWithSpecialInfectedSpawnCount()
{
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient) && g_bReplaceRageWithSpecialInfectedSpawn[iClient])
			iCount++;
	
	return iCount;
}

////////////////
// Models
////////////////

stock void AddModelToDownloadsTable(const char[] sModel)
{
	static const char sFileType[][] = {
		"dx80.vtx",
		"dx90.vtx",
		"mdl",
		"phy",
		"sw.vtx",
		"vvd",
	};
	
	char sRoot[PLATFORM_MAX_PATH];
	strcopy(sRoot, sizeof(sRoot), sModel);
	ReplaceString(sRoot, sizeof(sRoot), ".mdl", "");
	
	for (int i = 0; i < sizeof(sFileType); i++)
	{
		char sBuffer[PLATFORM_MAX_PATH];
		Format(sBuffer, sizeof(sBuffer), "%s.%s", sRoot, sFileType[i]);
		if (FileExists(sBuffer))
			AddFileToDownloadsTable(sBuffer);
	}
}

stock int PrecacheZombieSouls()
{
	char sPath[64];
	//Loops through all class types available
	for (int iClass = 1; iClass < view_as<int>(TFClassType); iClass++)
	{
		Format(sPath, sizeof(sPath), "models/player/items/%s/%s_zombie.mdl", g_sClassFiles[iClass], g_sClassFiles[iClass]);
		g_iZombieSoulIndex[iClass] = PrecacheModel(sPath);
	}
}

stock void ApplyVoodooCursedSoul(int iClient)
{
	if (TF2_IsPlayerInCondition(iClient, TFCond_HalloweenGhostMode))
		return;
	
	//Reset custom models
	SetVariantString("");
	AcceptEntityInput(iClient, "SetCustomModel");
	
	SetEntProp(iClient, Prop_Send, "m_bForcedSkin", true);
	SetEntProp(iClient, Prop_Send, "m_nForcedSkin", (TF2_GetPlayerClass(iClient) == TFClass_Spy) ? SKIN_ZOMBIE_SPY : SKIN_ZOMBIE);
	
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	int iWearable = TF2_CreateAndEquipWeapon(iClient, g_iVoodooIndex[view_as<int>(nClass)]);	//Not really a weapon, but still works
	if (IsValidEntity(iWearable))
		SetEntProp(iWearable, Prop_Send, "m_nModelIndexOverrides", g_iZombieSoulIndex[view_as<int>(nClass)]);
}

stock int GetClassVoodooItemDefIndex(TFClassType iClass)
{
	return g_iZombieSoulIndex[iClass];
}

////////////////
// SZF Class
////////////////

stock void TF2_GetClassName(char[] sBuffer, int iLength, int iClass)
{
	strcopy(sBuffer, iLength, g_sClassNames[iClass]);
}

stock void GetInfectedName(char[] sBuffer, int iLength, int iInfected)
{
	strcopy(sBuffer, iLength, g_sInfectedNames[iInfected]);
}

stock Infected GetInfected(const char[] sBuffer)
{
	for (int i; i < sizeof(g_sInfectedNames); i++)
		if (StrEqual(sBuffer, g_sInfectedNames[i], false))
			return view_as<Infected>(i);
	
	return Infected_Unknown;
}

////////////////
// Client Validity
////////////////

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

////////////////
// Morale
////////////////

stock void AddMorale(int iClient, int iAmount)
{
	g_iMorale[iClient] = g_iMorale[iClient] + iAmount;
	
	if (g_iMorale[iClient] > 100)
		g_iMorale[iClient] = 100;
	
	if (g_iMorale[iClient] < 0)
		g_iMorale[iClient] = 0;
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

////////////////
// Map
////////////////

stock bool IsMapSZF()
{
	char sMap[8];
	GetCurrentMap(sMap, sizeof(sMap));
	GetMapDisplayName(sMap, sMap, sizeof(sMap));
	
	if (StrContains(sMap, "zf_") == 0 || StrContains(sMap, "szf_") == 0)
		return true;
	
	return false;
}

////////////////
// Round
////////////////

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

////////////////
// Weapon State
////////////////

stock bool TF2_IsEquipped(int iClient, int iIndex)
{
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
		if (iWeapon > MaxClients && GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") == iIndex)
			return true;
	}
	
	return false;
}

stock bool TF2_IsWielding(int iClient, int iIndex)
{
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon > MaxClients)
		return GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") == iIndex;
	
	return false;
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

stock bool IsRazorbackActive(int iClient)
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "tf_wearable_razorback")) != -1)
		if (IsClassname(iEntity, "tf_wearable_razorback") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient && GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 57)
			return GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", TFWeaponSlot_Secondary) >= 100.0;
	
	return false;
}

stock int TF2_GetItemSlot(int iIndex, TFClassType iClass)
{
	int iSlot = TF2Econ_GetItemSlot(iIndex, iClass);
	if (iSlot >= 0)
	{
		// Econ reports wrong slots for Engineer and Spy
		switch (iClass)
		{
			case TFClass_Spy:
			{
				switch (iSlot)
				{
					case 1: iSlot = WeaponSlot_Primary; // Revolver
					case 4: iSlot = WeaponSlot_Secondary; // Sapper
					case 5: iSlot = WeaponSlot_PDADisguise; // Disguise Kit
					case 6: iSlot = WeaponSlot_InvisWatch; // Invis Watch
				}
			}
			
			case TFClass_Engineer:
			{
				switch (iSlot)
				{
					case 4: iSlot = WeaponSlot_BuilderEngie; // Toolbox
					case 5: iSlot = WeaponSlot_PDABuild; // Construction PDA
					case 6: iSlot = WeaponSlot_PDADestroy; // Destruction PDA
				}
			}
		}
	}
	
	return iSlot;
}

stock int TF2_GetItemInSlot(int iClient, int iSlot)
{
	int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
	if (iEntity > MaxClients)
		return iEntity;
	
	iEntity = SDKCall_GetEquippedWearable(iClient, iSlot);
	if (iEntity > MaxClients)
		return iEntity;
	
	return -1;
}

stock void TF2_RemoveItemInSlot(int iClient, int iSlot)
{
	int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
	if (iEntity > MaxClients)
		TF2_RemoveWeaponSlot(iClient, iSlot);
	
	int iWearable = SDKCall_GetEquippedWearable(iClient, iSlot);
	if (iWearable > MaxClients)
		TF2_RemoveWearable(iClient, iWearable);
}

////////////////
// Speed
////////////////

stock void SetClientSpeed(int iClient, float flSpeed)
{
	SetEntPropFloat(iClient, Prop_Data, "m_flMaxspeed", flSpeed);
}

stock float TF2_GetClassSpeed(TFClassType nClass)
{
	switch (nClass)
	{
		case TFClass_Scout: return 400.0;
		case TFClass_Soldier: return 240.0;
		case TFClass_Pyro: return 300.0;
		case TFClass_DemoMan: return 280.0;
		case TFClass_Heavy: return 230.0;
		case TFClass_Engineer: return 300.0;
		case TFClass_Medic: return 320.0;
		case TFClass_Sniper: return 300.0;
		case TFClass_Spy: return 320.0;
		default: return 0.0;
	}
}

stock float GetClientBonusSpeed(int iClient)
{
	switch (TF2_GetPlayerClass(iClient))
	{
		case TFClass_Scout:
		{
			if (TF2_IsEquipped(iClient, WEAPON_BFB))
				return 4.5*GetEntPropFloat(iClient, Prop_Send, "m_flHypeMeter");
			
			if (TF2_IsPlayerInCondition(iClient, TFCond_CritCola))
				return 20.0;
		}
		case TFClass_Soldier:
		{
			if (TF2_IsWielding(iClient, WEAPON_ESCAPEPLAN))
			{
				int iHealth = GetClientHealth(iClient);
				
				if (iHealth > 160)
					return 0.0;
				else if (iHealth > 120)
					return 24.0;
				else if (iHealth > 80)
					return 48.0;
				else if (iHealth > 40)
					return 96.0;
				else if (iHealth > 0)
					return 144.0;
			}
		}
		case TFClass_Pyro:
		{
			if (TF2_IsWielding(iClient, WEAPON_POWERJACK))
				return 36.0;
		}
		case TFClass_DemoMan:
		{
			//Eyelander
			if (TF2_IsSlotClassname(iClient, 2, "tf_weapon_sword")
				&& !TF2_IsEquipped(iClient, WEAPON_SKULLCUTTER)
				&& !TF2_IsEquipped(iClient, WEAPON_CLAIDHEAMHMOR)
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
		case TFClass_Heavy:
		{
			if (TF2_IsWielding(iClient, WEAPON_GRU)
				|| TF2_IsWielding(iClient, WEAPON_FGRU)
				|| TF2_IsWielding(iClient, WEAPON_BREADBITE))
			{
				return 70.0;
			}
			
			if (TF2_IsWielding(iClient, WEAPON_EVICTIONNOTICE))
				return 35.0;
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

////////////////
// Entity Name
////////////////

stock bool IsClassname(int iEntity, const char[] sClassname)
{
	if (iEntity > MaxClients)
	{
		char sClassname2[256];
		GetEntityClassname(iEntity, sClassname2, sizeof(sClassname2));
		return (StrEqual(sClassname2, sClassname));
	}
	
	return false;
}

////////////////
// Cloak
////////////////

stock float TF2_GetCloakMeter(int iClient)
{
	return GetEntPropFloat(iClient, Prop_Send, "m_flCloakMeter");
}

stock void TF2_SetCloakMeter(int iClient, float flCloak)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flCloakMeter", flCloak);
}

////////////////
// Ammo
////////////////

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

stock void TF2_SetMetal(int iClient, int iMetal)
{
	SetEntProp(iClient, Prop_Send, "m_iAmmo", iMetal, _, 3);
}

////////////////
// Spawn
////////////////

stock void SpawnClient(int iClient, TFTeam nTeam, bool bRespawn = true)
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
		SetEntProp(iClient, Prop_Send, "m_lifeState", 2);
		TF2_SetPlayerClass(iClient, nClass);
		TF2_ChangeClientTeam(iClient, nTeam);
		SetEntProp(iClient, Prop_Send, "m_lifeState", 0);
		
		Classes_SetClient(iClient);
		
		if (bRespawn)
			TF2_RespawnPlayer(iClient);
	}
}

stock void TF2_RespawnPlayer2(int iClient)
{
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	TFTeam nTeam = TF2_GetClientTeam(iClient);
	
	if (nTeam == TFTeam_Zombie && !IsValidZombieClass(nClass))
		TF2_SetPlayerClass(iClient, GetRandomZombieClass());
		
	if (nTeam == TFTeam_Survivor && !IsValidSurvivorClass(nClass))
		TF2_SetPlayerClass(iClient, GetRandomSurvivorClass());
	
	Classes_SetClient(iClient);
	
	TF2_RespawnPlayer(iClient);
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

////////////////
// Weapon
////////////////

stock int TF2_CreateAndEquipWeapon(int iClient, int iIndex, const char[] sClassname = "", const char[] sAttribs = "", const char[] sText = "")
{
	char sClassnameCopy[256];
	if (sClassname[0] == '\0')
	{
		TF2Econ_GetItemClassName(iIndex, sClassnameCopy, sizeof(sClassnameCopy));
		TF2Econ_TranslateWeaponEntForClass(sClassnameCopy, sizeof(sClassnameCopy), TF2_GetPlayerClass(iClient));
	}
	else
	{
		strcopy(sClassnameCopy, sizeof(sClassnameCopy), sClassname);
	}
	
	bool bSapper;
	if ((StrEqual(sClassnameCopy, "tf_weapon_builder") || StrEqual(sClassnameCopy, "tf_weapon_sapper")) && TF2_GetPlayerClass(iClient) == TFClass_Spy)
	{
		bSapper = true;
		
		//Apparently tf_weapon_sapper causes client crashes
		sClassnameCopy = "tf_weapon_builder";
	}
	
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	int iSlot = TF2_GetItemSlot(iIndex, iClass);
	Address pItem = SDKCall_GetLoadoutItem(iClient, iClass, iSlot);
	
	int iWeapon;
	if (pItem && GetOriginalItemDefIndex(LoadFromAddress(pItem+view_as<Address>(4), NumberType_Int16)) == iIndex)
	{
		iWeapon = SDKCall_GetBaseEntity(SDKCall_GiveNamedItem(iClient, sClassnameCopy, 0, pItem));
	}
	else
	{
		iWeapon = CreateEntityByName(sClassnameCopy);
		
		if (IsValidEntity(iWeapon))
		{
			SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
			SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
			SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", 0);
			SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		}
	}
	
	if (IsValidEntity(iWeapon))
	{
		if (bSapper)
		{
			SetEntProp(iWeapon, Prop_Send, "m_iObjectType", TFObject_Sapper);
			SetEntProp(iWeapon, Prop_Data, "m_iSubType", TFObject_Sapper);
		}
		
		//Attribute shittery inbound
		if (!StrEqual(sAttribs, ""))
		{
			char sAttribs2[32][32];
			int iCount = ExplodeString(sAttribs, " ; ", sAttribs2, 32, 32);
			if (iCount > 1)
				for (int i = 0; i < iCount; i+= 2)
					TF2Attrib_SetByDefIndex(iWeapon, StringToInt(sAttribs2[i]), StringToFloat(sAttribs2[i+1]));
		}
		
		if (g_flStopChatSpam[iClient] < GetGameTime() && !StrEqual(sText, ""))
		{
			CPrintToChat(iClient, sText);
			g_flStopChatSpam[iClient] = GetGameTime() + 1.0;
		}
		
		DispatchSpawn(iWeapon);
		SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		
		if (StrContains(sClassnameCopy, "tf_wearable") == 0)
			SDKCall_EquipWearable(iClient, iWeapon);
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

stock void CheckClientWeapons(int iClient)
{
	//Weapons
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon > MaxClients)
		{
			char sClassname[256];
			GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
			if (OnGiveNamedItem(iClient, sClassname, GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex")) >= Plugin_Handled)
				TF2_RemoveItemInSlot(iClient, iSlot);
		}
	}
	
	//Cosmetics
	int iWearable = MaxClients+1;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) > MaxClients)
	{
		if (GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == iClient || GetEntPropEnt(iWearable, Prop_Send, "moveparent") == iClient)
		{
			char sClassname[256];
			GetEntityClassname(iWearable, sClassname, sizeof(sClassname));
			if (OnGiveNamedItem(iClient, sClassname, GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex")) >= Plugin_Handled)
				TF2_RemoveWearable(iClient, iWearable);
		}
	}
}

stock int GetOriginalItemDefIndex(int iIndex)
{
	int iOrigIndex;
	
	char sIndex[8];
	IntToString(iIndex, sIndex, sizeof(sIndex));
	
	if (g_mConfigReskins.GetValue(sIndex, iOrigIndex))
		return iOrigIndex;
	else
		return iIndex;
}

////////////////
// Cookie
////////////////

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

////////////////
// Trace
////////////////

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
	
	if (!bHit || iHit != iEntity2)
		return true;
	
	return false;
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

public bool Trace_DontHitOtherEntities(int iEntity, int iMask, any iData)
{
	if (iEntity == iData)
		return true;
	
	if (iEntity > 0)
		return false;
	
	return true;
}

public bool Trace_DontHitEntity(int iEntity, int iMask, any iData)
{
	if (iEntity == iData)
		return false;
	
	return true;
}

////////////////
// Particles
////////////////

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
			RemoveEntity(iParticle);
			iParticle = -1;
		}
	}
}

/******************************************************************************************************/

stock void StrToLower(const char[] sInput, char[] sOutput, int iLength)
{
	iLength = strlen(sInput) > iLength ? iLength : strlen(sInput);
	for (int i = 0; i < iLength; i++)
		sOutput[i] = CharToLower(sInput[i]);
}

stock void GetClientName2(int iClient, char[] sName, int iLength)
{
	Forward_GetClientName(iClient, sName, iLength);
	
	//If name still empty or could not be found, use default name and team color instead
	if (sName[0] == '\0')
	{
		GetClientName(iClient, sName, iLength);
		Format(sName, iLength, "{teamcolor}%s", sName);
	}
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
		RemoveEntity(iEntity);
}

//Yoinked from https://github.com/DFS-Servers/Super-Zombie-Fortress/blob/master/addons/sourcemod/scripting/include/szf_util_base.inc
stock void CPrintToChatTranslation(int iClient, int iCaller, char[] sText, bool bTeam = false, const char[] sParam1="", const char[] sParam2="", const char[] sParam3="", const char[] sParam4="")
{
	if (bTeam && !IsValidClient(iCaller))
		return;
	
	char sName[80], sMessage[255];
	if (0 < iCaller <= MaxClients)
	{
		GetClientName2(iCaller, sName, sizeof(sName));
		if (bTeam)
			Format(sMessage, sizeof(sMessage), "\x01(TEAM) %s\x01 : %s", sName, sText);
		else
			Format(sMessage, sizeof(sMessage), "\x01%s\x01 : %s\x01", sName, sText);
	}
	
	ReplaceString(sMessage, sizeof(sMessage), "{param1}", "%s1");
	ReplaceString(sMessage, sizeof(sMessage), "{param2}", "%s2");
	ReplaceString(sMessage, sizeof(sMessage), "{param3}", "%s3");
	ReplaceString(sMessage, sizeof(sMessage), "{param4}", "%s4");
	CReplaceColorCodes(sMessage, iCaller, _, sizeof(sMessage));
	
	int iClients[1];
	iClients[0] = iClient;
	SayText2(iClients, 1, iClient, true, sMessage, sParam1, sParam2, sParam3, sParam4);
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

//SDKHooks_TakeDamage doesn't call OnTakeDamage, so we need to scale separately for 'indirect' damage
stock void DealDamage(int iAttacker, int iVictim, float flDamage)
{
	if (g_flZombieDamageScale < 1.0)
		flDamage *= g_flZombieDamageScale;
	
	if (g_bBackstabbed[iVictim] && flDamage > STUNNED_DAMAGE_CAP)
		flDamage = STUNNED_DAMAGE_CAP;
	
	SDKHooks_TakeDamage(iVictim, iAttacker, iAttacker, flDamage, DMG_PREVENT_PHYSICS_FORCE);
}

stock bool CanRecieveDamage(int iClient)
{
	if (iClient <= 0 || !IsClientInGame(iClient))
		return true;
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_Ubercharged))
		return false;
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_Bonked))
		return false;
	
	return true;
}