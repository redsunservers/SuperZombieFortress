#define PICKUP_COOLDOWN 	2.0

#define ENT_ONPICKUP	"FireUser1"
#define ENT_ONKILL		"FireUser2"

enum WeaponType
{
	WeaponType_Invalid,
	WeaponType_Static,
	WeaponType_Default,
	WeaponType_Spawn,
	WeaponType_Rare,
	WeaponType_RareSpawn,
	WeaponType_StaticSpawn,
	WeaponType_DefaultNoPickup,
	WeaponType_Common,
	WeaponType_Uncommon,
	WeaponType_UncommonSpawn,
	WeaponType_Powerup,
	WeaponType_Dropped,
};

#define WEAPON_EXTRA_HEIGHT				50.0
#define WEAPON_POWERUP_NAME				"szf_weapon_powerup"

static bool g_bSpawningExtraWeapon;
static bool g_bCanPickup[MAXPLAYERS] = {false, ...};
static bool g_bTriggerEntity[2048] = {true, ...};
static float g_flWeaponCallout[2048][MAXPLAYERS];
static int g_iAvailableRareCount;
static ArrayList g_aWeaponsCommon;
static ArrayList g_aWeaponsUncommon;
static ArrayList g_aWeaponsRares;
static ArrayList g_aWeaponsSpawn;

void Weapons_Init()
{
	HookEvent("teamplay_round_start", Event_WeaponsRoundStart);
	HookEvent("player_spawn", Event_ResetPickup);
	HookEvent("player_death", Event_ResetPickup);

	g_cWeaponsPicked = new Cookie("weaponspicked", "The amount of picked up weapons", CookieAccess_Protected);
	g_cWeaponsRarePicked = new Cookie("weaponsrarepicked", "The amount of picked up rare weapons", CookieAccess_Protected);
	g_cWeaponsCalled = new Cookie("weaponscalled", "The amount of called out weapons", CookieAccess_Protected);
}

void Weapons_ClientDisconnect(int iClient)
{
	g_bCanPickup[iClient] = true;
}

public Action Event_WeaponsRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	int iEntity = -1;
	g_iAvailableRareCount = g_iMaxRareWeapons;
	
	DroppedWeapon_Reset();
	
	delete g_aWeaponsCommon;
	delete g_aWeaponsUncommon;
	delete g_aWeaponsRares;
	delete g_aWeaponsSpawn;
	
	g_aWeaponsCommon = GetAllWeaponsWithRarity(WeaponRarity_Common, _, _, true);
	g_aWeaponsUncommon = GetAllWeaponsWithRarity(WeaponRarity_Uncommon, _, _, true);
	g_aWeaponsRares = GetAllWeaponsWithRarity(WeaponRarity_Rare, _, _, true);
	g_aWeaponsSpawn = new ArrayList();
	
	// Loop through spawn weapons first to fill up spawn array
	ArrayList aSpawns = new ArrayList();
	ArrayList aNonSpawns = new ArrayList();
	
	while ((iEntity = FindEntityByClassname(iEntity, "prop_dynamic")) != INVALID_ENT_REFERENCE)
	{
		if (IsSpawnWeapon(iEntity))
			aSpawns.Push(iEntity);
		else
			aNonSpawns.Push(iEntity);
	}
	
	aSpawns.Sort(Sort_Random, Sort_Integer);
	aNonSpawns.Sort(Sort_Random, Sort_Integer);
	
	Weapons_ApplySpawnGuarantees(aSpawns);
	
	for (int i = 0; i < aSpawns.Length; i++)
		SetWeapon(aSpawns.Get(i));
	
	for (int i = 0; i < aNonSpawns.Length; i++)
		SetWeapon(aNonSpawns.Get(i));
	
	delete aSpawns;
	delete aNonSpawns;
	
	return Plugin_Continue;
}

public void SetWeapon(int iEntity)
{
	WeaponType nWeaponType = GetWeaponType(iEntity);
	bool bValid = true;
	
	switch (nWeaponType)
	{
		case WeaponType_Spawn:
		{
			bValid = SetUniqueWeapon(iEntity, g_aWeaponsCommon, WeaponRarity_Common);
		}
		case WeaponType_Rare:
		{
			//If rare weapon cap is unreached, make it a "rare" weapon
			if (g_iAvailableRareCount > 0 && CanSetUniqueWeapon(iEntity, g_aWeaponsRares))
			{
				bValid = SetUniqueWeapon(iEntity, g_aWeaponsRares, WeaponRarity_Rare);
				
				g_iAvailableRareCount--;
			}
			//Else make it a uncommon weapon
			else
			{
				bValid = SetRandomWeapon(iEntity, WeaponRarity_Uncommon);
			}
		}
		case WeaponType_RareSpawn:
		{
			bValid = SetUniqueWeapon(iEntity, g_aWeaponsRares, WeaponRarity_Rare);
		}
		case WeaponType_UncommonSpawn:
		{
			bValid = SetUniqueWeapon(iEntity, g_aWeaponsUncommon, WeaponRarity_Uncommon);
		}
		case WeaponType_Common:
		{
			bValid = SetRandomWeapon(iEntity, WeaponRarity_Common);
		}
		case WeaponType_Uncommon:
		{
			bValid = SetRandomWeapon(iEntity, WeaponRarity_Uncommon);
		}
		case WeaponType_Default, WeaponType_DefaultNoPickup:
		{
			//If rare weapon cap is unreached and a dice roll is met, make it a "rare" weapon
			if (g_iAvailableRareCount > 0 && GetRandomFloat(0.0, 1.0) < MapConfig_GetRareWeaponChance() && CanSetUniqueWeapon(iEntity, g_aWeaponsRares))
			{
				bValid = SetUniqueWeapon(iEntity, g_aWeaponsRares, WeaponRarity_Rare);
				g_iAvailableRareCount--;
			}
			//Else make it either common or uncommon weapon
			else
			{
				ArrayList aList = GetAllCommonAndUncommonWeapons(g_aWeaponsSpawn, GetWeaponClassFilter(iEntity));
				if (aList.Length == 0)
				{
					// No weapons from given rarity and class, ignore class filter
					delete aList;
					aList = GetAllCommonAndUncommonWeapons(g_aWeaponsSpawn);
				}
				
				if (aList.Length == 0)
				{
					delete aList;
					RemoveEntity(iEntity);
					return;
				}
				
				Weapon wep;
				aList.GetArray(GetRandomInt(0, aList.Length - 1), wep);
				delete aList;
				
				SetWeaponModel(iEntity, wep);
			}
		}
		case WeaponType_Powerup:
		{
			bValid = SetRandomPickup(iEntity);
		}
		case WeaponType_Static, WeaponType_StaticSpawn:
		{
			//Check if there reskin weapons to replace
			char sModel[256];
			GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
			int iIndex = GetReskinIndex(sModel);
			
			if (iIndex >= 0)
				Weapons_ReplaceEntityModel(iEntity, iIndex);
		}
		default:	//Not a SZF weapon
		{
			return;
		}
	}
	
	if (!bValid)
		return;
	
	Weapons_SetupProp(iEntity);
	
	if (g_bSpawningExtraWeapon)
		return;
	
	if (nWeaponType == WeaponType_Default && GetRandomFloat(0.0, 1.0) < g_cvWeaponPickupChance.FloatValue)
		SpawnExtraPowerup(iEntity, WEAPON_EXTRA_HEIGHT);
}

void Weapons_SetupProp(int iEntity)
{
	SetEntProp(iEntity, Prop_Send, "m_nSolidType", SOLID_OBB);
	SetEntityCollisionGroup(iEntity, COLLISION_GROUP_DEBRIS_TRIGGER);
	AcceptEntityInput(iEntity, "DisableShadow");
	AcceptEntityInput(iEntity, "EnableCollision");
	
	g_bTriggerEntity[iEntity] = true; //Indicate reset of the OnUser triggers
}

bool Weapons_IsSpawningExtra()
{
	return g_bSpawningExtraWeapon;
}

void Weapons_ApplySpawnGuarantees(ArrayList aSpawns)
{
	ArrayList aGroups = Weapons_GetSpawnGroups();
	aGroups.Sort(Sort_Random, Sort_String);
	
	int iGroupCount = aGroups.Length;
	for (int i = 0; i < iGroupCount; i++)
	{
		char sGroup[32];
		aGroups.GetString(i, sGroup, sizeof(sGroup));
		
		ArrayList aMembers = Weapons_GetSpawnGroupMembers(sGroup);
		bool bPlaced = false;
		
		for (int iPass = 0; iPass < 2 && !bPlaced; iPass++)
		{
			for (int j = 0; j < aMembers.Length && !bPlaced; j++)
			{
				Weapon wep;
				aMembers.GetArray(j, wep);
				
				for (int k = 0; k < aSpawns.Length; k++)
				{
					int iEntity = aSpawns.Get(k);
					if (!Weapons_CanGuaranteeAtSpot(iEntity, wep, iPass == 0))
						continue;
					
					SetWeaponModel(iEntity, wep);
					Weapons_SetupProp(iEntity);
					
					Weapons_RemoveFromPools(wep.iIndex);
					g_aWeaponsSpawn.Push(wep.iIndex);
					
					aSpawns.Erase(k);
					bPlaced = true;
					break;
				}
			}
		}
		
		delete aMembers;
	}
	
	delete aGroups;
}

bool Weapons_CanGuaranteeAtSpot(int iEntity, Weapon wep, bool bMatchRarity)
{
	WeaponType nWeaponType = GetWeaponType(iEntity);
	if (nWeaponType != WeaponType_Spawn && nWeaponType != WeaponType_UncommonSpawn)
		return false;
	
	if (bMatchRarity)
	{
		if (nWeaponType == WeaponType_Spawn && wep.nRarity != WeaponRarity_Common)
			return false;
		
		if (nWeaponType == WeaponType_UncommonSpawn && wep.nRarity != WeaponRarity_Uncommon)
			return false;
	}
	
	TFClassType nClassFilter = GetWeaponClassFilter(iEntity);
	if (nClassFilter != TFClass_Unknown && TF2_GetItemSlot(wep.iIndex, nClassFilter) < 0)
		return false;
	
	return true;
}

void Weapons_RemoveFromPools(int iIndex)
{
	ArrayList aPools[3];
	aPools[0] = g_aWeaponsCommon;
	aPools[1] = g_aWeaponsUncommon;
	aPools[2] = g_aWeaponsRares;
	
	for (int i = 0; i < sizeof(aPools); i++)
	{
		if (!aPools[i])
			continue;
		
		int iPos = aPools[i].FindValue(iIndex, 0);
		if (iPos != -1)
			aPools[i].Erase(iPos);
	}
}

void SpawnExtraPowerup(int iEntity, float flHeight)
{
	ArrayList aList = GetAllWeaponsWithRarity(WeaponRarity_Pickup);
	if (aList.Length > 0)
	{
		Weapon wep;
		aList.GetArray(GetRandomInt(0, aList.Length - 1), wep);
		Weapons_CreateExtraProp(iEntity, wep, flHeight, WEAPON_POWERUP_NAME, true);
	}
	
	delete aList;
}

int Weapons_CreateExtraProp(int iSource, Weapon wep, float flHeight, const char[] sTargetName = "", bool bResetAngles = false)
{
	float vecOrigin[3], vecAngles[3];
	GetEntPropVector(iSource, Prop_Send, "m_vecOrigin", vecOrigin);
	GetEntPropVector(iSource, Prop_Send, "m_angRotation", vecAngles);
	
	Weapon source;
	if (GetWeaponFromEntity(source, iSource))
	{
		float vecOffset[3];
		RotateVector(source.vecOriginOffset, vecAngles, vecOffset);
		AddVectors(vecOrigin, vecOffset, vecOrigin);
		SubtractVectors(vecAngles, source.vecAnglesOffset, vecAngles);
	}
	
	vecOrigin[2] += flHeight;
	
	if (bResetAngles)
	{
		vecAngles[0] = 0.0;
		vecAngles[1] = 0.0;
		vecAngles[2] = 0.0;
	}
	
	char sName[256];
	if (sTargetName[0])
		strcopy(sName, sizeof(sName), sTargetName);
	else
		GetEntPropString(iSource, Prop_Data, "m_iName", sName, sizeof(sName));
	
	int iProp = CreateEntityByName("prop_dynamic");
	if (iProp == INVALID_ENT_REFERENCE)
		return INVALID_ENT_REFERENCE;
	
	DispatchKeyValue(iProp, "targetname", sName);
	DispatchKeyValue(iProp, "model", wep.sModel);
	DispatchKeyValue(iProp, "solid", "2");
	DispatchKeyValueVector(iProp, "origin", vecOrigin);
	DispatchKeyValueVector(iProp, "angles", vecAngles);
	
	g_bSpawningExtraWeapon = true;
	DispatchSpawn(iProp);
	g_bSpawningExtraWeapon = false;
	
	SetEntProp(iProp, Prop_Send, "m_nSkin", 99);
	SetWeaponModel(iProp, wep);
	Weapons_SetupProp(iProp);
	
	return iProp;
}

public Action Event_ResetPickup(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsValidClient(iClient))
		g_bCanPickup[iClient] = true;
	
	return Plugin_Continue;
}

bool SetUniqueWeapon(int iEntity, ArrayList &aWeapons, WeaponRarity iWepRarity)
{
	TFClassType nClassFilter = GetWeaponClassFilter(iEntity);
	bool bSpawnSpot = IsSpawnWeapon(iEntity);
	
	if (nClassFilter == TFClass_Unknown && bSpawnSpot)
		aWeapons.SortCustom(Sort_SpawnWeapons);	// Priorise whoever class with fewest spawn weapons
	else
		aWeapons.Sort(Sort_Random, Sort_Integer);
	
	int iLength = aWeapons.Length;
	for (int i = 0; i < iLength; i++)
	{
		Weapon wep;
		aWeapons.GetArray(i, wep);
		
		if (wep.bSpawnOnly && !bSpawnSpot)
			continue;
		
		if (nClassFilter != TFClass_Unknown && TF2_GetItemSlot(wep.iIndex, nClassFilter) < 0)
			continue;
		
		//This weapon is no longer in the pool
		aWeapons.Erase(i);
		g_aWeaponsSpawn.Push(wep.iIndex);
		
		SetWeaponModel(iEntity, wep);
		return true;
	}
	
	if (nClassFilter == TFClass_Unknown)
	{
		// No more unique weapons to pick, delete it
		RemoveEntity(iEntity);
		return false;
	}
	
	if (iWepRarity == WeaponRarity_Rare && !Weapons_ClassHasRarity(nClassFilter, WeaponRarity_Rare, bSpawnSpot))
		return SetRandomWeapon(iEntity, WeaponRarity_Uncommon, bSpawnSpot);
	
	return SetRandomWeapon(iEntity, iWepRarity, bSpawnSpot);
}

bool Weapons_ClassHasRarity(TFClassType nClass, WeaponRarity nRarity, bool bIncludeSpawnOnly)
{
	ArrayList aList = GetAllWeaponsWithRarity(nRarity, _, nClass, bIncludeSpawnOnly);
	bool bFound = aList.Length > 0;
	delete aList;
	return bFound;
}

bool CanSetUniqueWeapon(int iEntity, ArrayList aWeapons)
{
	if (GetWeaponClassFilter(iEntity) != TFClass_Unknown)
		return true;
	
	bool bSpawnSpot = IsSpawnWeapon(iEntity);
	int iLength = aWeapons.Length;
	for (int i = 0; i < iLength; i++)
	{
		Weapon wep;
		aWeapons.GetArray(i, wep);
		
		if (!wep.bSpawnOnly || bSpawnSpot)
			return true;
	}
	
	return false;
}

int Sort_SpawnWeapons(int iIndex1, int iIndex2, Handle hArray, Handle hData)
{
	int iIndex[2];
	iIndex[0] = GetArrayCell(hArray, iIndex1);
	iIndex[1] = GetArrayCell(hArray, iIndex2);
	
	int iMinCount[2] = {999, 999};
	
	for (TFClassType nClass = TFClass_Scout; nClass <= TFClass_Engineer; nClass++)
	{
		for (int i = 0; i < sizeof(iIndex); i++)
		{
			if (TF2_GetItemSlot(iIndex[i], nClass) == -1)
				continue;
			
			// Count up how many spawn weapons this class currently have
			int iCount;
			for (int j = 0; j < g_aWeaponsSpawn.Length; j++)
				if (TF2_GetItemSlot(g_aWeaponsSpawn.Get(j), nClass) != -1)
					iCount++;
			
			if (iMinCount[i] > iCount)
				iMinCount[i] = iCount;
		}
	}
	
	if (iMinCount[0] < iMinCount[1])
		return -1;
	else if (iMinCount[0] > iMinCount[1])
		return 1;
	else
		return 0;
}

bool AttemptGrabItem(int iClient)
{	
	if (!IsSurvivor(iClient) || !IsPlayerAlive(iClient) || !g_bCanPickup[iClient] || TF2_IsPlayerInCondition(iClient, TFCond_Taunting))
		return false;
	
	int iTarget = GetClientPointVisible(iClient);
	
	if (0 < iTarget <= MaxClients)
		return false;
	
	if (iTarget <= 0 || !IsWeaponPropClassname(iTarget) || GetWeaponType(iTarget) == WeaponType_Invalid)
		iTarget = DroppedWeapon_FindAimTarget(iClient);
	
	if (iTarget <= 0 || GetWeaponType(iTarget) == WeaponType_Invalid)
		return false;
	
	Weapon wep;
	if (!GetWeaponFromEntity(wep, iTarget))
		return false;
	
	bool bAllowPickup = true;
	if (wep.pickupCallback != INVALID_FUNCTION)
	{
		Call_StartFunction(null, wep.pickupCallback);
		Call_PushCell(iClient);
		Call_Finish(bAllowPickup);
	}
	
	WeaponRarity nRarity = wep.nRarity;
	Action action = Forward_OnWeaponPickupPre(iClient, iTarget, nRarity);
	if (action == Plugin_Handled)
	{
		bAllowPickup = false;
	}
	else if (action == Plugin_Stop)
	{
		return false;
	}
	
	if (nRarity == WeaponRarity_Pickup)
	{
		if (!bAllowPickup)
			return false;
		
		if (wep.sSound[0] != '\0')
			EmitSoundToClient(iClient, wep.sSound);
		
		AcceptEntityInput(iTarget, ENT_ONKILL, iClient, iClient);
		RemoveEntity(iTarget);
		
		return true;
	}
	
	int iIndex = wep.iIndex;
	
	if (iIndex > -1)
	{
		char sClient[256];
		GetClientName2(iClient, sClient, sizeof(sClient));
		
		int iSlot = TF2_GetItemSlot(iIndex, TF2_GetPlayerClass(iClient));
		if (iSlot >= 0 && bAllowPickup)
		{
			if (nRarity == WeaponRarity_Rare)
			{
				char sName[256];
				TF2Econ_GetLocalizedItemName(iIndex, sName, sizeof(sName));
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidLivingSurvivor(i))
					{
						char sBuffer[256];
						Format(sBuffer, sizeof(sBuffer), "%T", "Weapon_Pickup", i, "{limegreen}", "{param3}", "\x01");
						CPrintToChatTranslation(i, iClient, sBuffer, true, .sParam3 = sName);
					}
				}
				
				AddToCookie(iClient, 1, g_cWeaponsRarePicked);
				if (GetCookie(iClient, g_cWeaponsRarePicked) <= 1)
				{
					DataPack data;
					CreateDataTimer(0.5, Timer_DisplayTutorialMessage, data);
					data.WriteCell(iClient);
					data.WriteFloat(2.0);
					data.WriteString("Tutorial_PickupRare1");
					
					CreateDataTimer(2.5, Timer_DisplayTutorialMessage, data);
					data.WriteCell(iClient);
					data.WriteFloat(3.0);
					data.WriteString("Tutorial_PickupRare2");
				}
			}
			
			PickupWeapon(iClient, wep, iTarget);
			
			return true;
		}
		else if (nRarity == WeaponRarity_Rare || !IsSpawnWeapon(iTarget))
		{
			CalloutWeapon(iClient, iTarget, false);
		}
	}
	
	return false;
}

void CalloutWeapon(int iClient, int iTarget, bool bOnlyGlow)
{
	g_flWeaponCallout[iTarget][iClient] = GetGameTime();
	
	if (GetWeaponGlowEnt(iTarget) != INVALID_ENT_REFERENCE)	//Glow already here, don't announce again
		return;
	
	//Create glow outline
	int iProp = CreateBonemerge(iTarget);
	SetEntProp(iProp, Prop_Send, "m_bGlowEnabled", true);
	SDKHook(iProp, SDKHook_SetTransmit, Weapon_SetTransmit);
	
	if (bOnlyGlow)
		return;
	
	Weapon wep;
	if (!GetWeaponFromEntity(wep, iTarget))
		return;
	
	//If rare, show in chat to everyone in team
	if (wep.nRarity == WeaponRarity_Rare)
	{
		char sName[255];
		TF2Econ_GetLocalizedItemName(wep.iIndex, sName, sizeof(sName));
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsValidLivingSurvivor(i))
				continue;
			
			char sBuffer[256];
			Format(sBuffer, sizeof(sBuffer), "%T", "Weapon_Callout", i, "{limegreen}", "{param3}", "\x01");
			CPrintToChatTranslation(i, iClient, sBuffer, true, .sParam3 = sName);
		}
	}
	
	AddToCookie(iClient, 1, g_cWeaponsCalled);
	if (GetCookie(iClient, g_cWeaponsCalled) <= 1)
	{
		DataPack data;
		CreateDataTimer(0.5, Timer_DisplayTutorialMessage, data);
		data.WriteCell(iClient);
		data.WriteFloat(4.0);
		data.WriteString("Tutorial_Callout1");
	}
	
	Forward_OnWeaponCallout(iClient, iTarget, wep.nRarity);
}

void PickupWeapon(int iClient, Weapon wep, int iTarget)
{
	if (wep.sSound[0] == '\0')
		EmitSoundToClient(iClient, "ui/item_heavy_gun_pickup.wav");
	else
		EmitSoundToClient(iClient, wep.sSound);
	
	g_bCanPickup[iClient] = false;
	CreateTimer(PICKUP_COOLDOWN, Timer_ResetPickup, iClient);
	
	SetVariantString("randomnum:100");
	AcceptEntityInput(iClient, "AddContext");
	
	switch (wep.nRarity)
	{
		case WeaponRarity_Common: SetVariantString("TLK_MVM_LOOT_COMMON");
		case WeaponRarity_Uncommon: SetVariantString("TLK_MVM_LOOT_RARE");
		case WeaponRarity_Rare: SetVariantString("TLK_MVM_LOOT_ULTRARARE");
	}
	
	AcceptEntityInput(iClient, "SpeakResponseConcept");
	AcceptEntityInput(iClient, "ClearContext");
	
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	int iSlot = TF2_GetItemSlot(wep.iIndex, iClass);
	
	if (!IsSpawnWeapon(iTarget))
	{
		Weapon oldwep;
		bool bKillEntity = true;
		
		int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (!IsValidEntity(iEntity))
			iEntity = SDKCall_GetEquippedWearable(iClient, iSlot); //If weapon not found in slot, check if it a wearable
		
		if (IsValidEntity(iEntity))
		{
			int iOldIndex = Config_GetOriginalItemDefIndex(GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex"));
			
			if (GetWeaponFromIndex(oldwep, iOldIndex) && oldwep.iIndex >= 0)
			{
				EmitSoundToClient(iClient, "ui/item_heavy_gun_drop.wav");
				
				if (DroppedWeapon_IsPhysics(iTarget))
				{
					int iDrop = DroppedWeapon_Replace(iTarget, oldwep);
					if (iDrop != INVALID_ENT_REFERENCE)
						CalloutWeapon(iClient, iDrop, true);
				}
				else
				{
					SetWeaponModel(iTarget, oldwep);
					
					//Kill the weapon glow with its model if it had one.
					int iGlow = GetWeaponGlowEnt(iTarget);
					if (iGlow != INVALID_ENT_REFERENCE)
						RemoveEntity(iGlow);
					
					RareOutline_Update(iTarget, oldwep);
					
					//Callout under a new weapon model
					CalloutWeapon(iClient, iTarget, true);
					
					bKillEntity = false;
				}
			}
		}
		
		if (bKillEntity)
		{
			AcceptEntityInput(iTarget, ENT_ONKILL, iClient, iClient);
			RareOutline_Remove(iTarget);
			RemoveEntity(iTarget);
		}
	}

	//Remove sniper scope and slowdown cond if have one, otherwise can cause client crashes
	if (TF2_IsPlayerInCondition(iClient, TFCond_Zoomed))
	{
		TF2_RemoveCondition(iClient, TFCond_Zoomed);
		TF2_RemoveCondition(iClient, TFCond_Slowed);
	}

	//Force crit reset
	int iRevengeCrits = GetEntProp(iClient, Prop_Send, "m_iRevengeCrits");
	if (iRevengeCrits > 0)
	{
		SetEntProp(iClient, Prop_Send, "m_iRevengeCrits", 0);
		TF2_RemoveCondition(iClient, TFCond_Kritzkrieged);
	}
	
	//If player already have item in his inv, remove it before we generate new weapon for him
	TF2_RemoveItemInSlot(iClient, iSlot);
	
	//Generate and equip weapon, allowing reskins
	int iWeapon = TF2_CreateAndEquipWeapon(iClient, wep.iIndex, wep.attribs, true);
	
	char sClassname[256];
	TF2Econ_GetItemClassName(wep.iIndex, sClassname, sizeof(sClassname));
	if (StrContains(sClassname, "tf_wearable") == 0) 
	{ 
		if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") <= MaxClients)
		{
			//Looks like player's active weapon got replaced into wearable, fix that by using melee
			int iMelee = GetPlayerWeaponSlot(iClient, WeaponSlot_Melee);
			if (iMelee > MaxClients)
				TF2_SwitchActiveWeapon(iClient, iMelee);
		}
	}
	else 
	{
		int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmoType > -1)
		{
			//Reset ammo before GivePlayerAmmo gives back properly
			SetEntProp(iClient, Prop_Send, "m_iAmmo", 0, _, iAmmoType);
			GivePlayerAmmo(iClient, 9999, iAmmoType, true);
		}
		
		TF2_SwitchActiveWeapon(iClient, iWeapon);
	}
	
	//Reset meter to default value
	SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", SDKCall_GetDefaultItemChargeMeterValue(iWeapon), iSlot);
	
	//Call client to reset HUD meter
	CreateTimer(0.1, Timer_UpdateClientHud, GetClientSerial(iClient));
	
	//Add weapon pickup to player as cookie
	AddToCookie(iClient, 1, g_cWeaponsPicked);
	if (GetCookie(iClient, g_cWeaponsPicked) <= 1)
	{
		DataPack data;
		CreateDataTimer(0.5, Timer_DisplayTutorialMessage, data);
		data.WriteCell(iClient);
		data.WriteFloat(2.5);
		data.WriteString("Tutorial_PickupCommon1");
		
		CreateDataTimer(3.0, Timer_DisplayTutorialMessage, data);
		data.WriteCell(iClient);
		data.WriteFloat(3.5);
		data.WriteString("Tutorial_PickupCommon2");
	}
	
	//Trigger ENT_ONPICKUP
	if (g_bTriggerEntity[iTarget])
	{
		AcceptEntityInput(iTarget, ENT_ONPICKUP, iClient, iClient);
		g_bTriggerEntity[iTarget] = false;
	}
	
	Forward_OnWeaponPickup(iClient, iWeapon, wep.nRarity);
}

public Action Timer_ResetPickup(Handle timer, any iClient)
{
	if (IsValidClient(iClient))
		g_bCanPickup[iClient] = true;
	
	return Plugin_Continue;
}

WeaponType GetWeaponType(int iEntity)
{
	char sName[255];
	GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
	
	//Strcontains versus strequals on 2048 entities obviously shows strcontains as the winner
	if (StrContains(sName, "szf_weapon_spawn", false) == 0)
		return WeaponType_Spawn; //Spawn: dont expire on pickup
	else if (StrContains(sName, "szf_weapon_rare_spawn", false) == 0)
		return WeaponType_RareSpawn; //Guaranteed rare and non-expiring
	else if (StrContains(sName, "szf_weapon_rare", false) == 0)
		return WeaponType_Rare; //Guaranteed rare
	else if (StrContains(sName, "szf_weapon_static_spawn", false) == 0)
		return WeaponType_StaticSpawn; //Static: don't change model and non-expiring
	else if (StrContains(sName, "szf_weapon_static", false) == 0)
		return WeaponType_Static; //Static: don't change model
	else if (StrContains(sName, "szf_weapon_nopickup", false) == 0)
		return WeaponType_DefaultNoPickup; //No pickup: this weapon can never become a pickup
	else if (StrContains(sName, "szf_weapon_common", false) == 0)
		return WeaponType_Common; //Guaranteed common
	else if (StrContains(sName, "szf_weapon_uncommon_spawn", false) == 0)
		return WeaponType_UncommonSpawn; //Guaranteed uncommon and non-expiring
	else if (StrContains(sName, "szf_weapon_uncommon", false) == 0)
		return WeaponType_Uncommon; //Guaranteed uncommon
	else if (StrContains(sName, WEAPON_POWERUP_NAME, false) == 0)
		return WeaponType_Powerup;
	else if (StrContains(sName, DROPPED_WEAPON_NAME, false) == 0)
		return WeaponType_Dropped;
	else if (StrContains(sName, "szf_weapon", false) != -1)
		return WeaponType_Default; //Normal
	
	return WeaponType_Invalid;
}

TFClassType GetWeaponClassFilter(int iEntity)
{
	char sName[255];
	GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
	
	for (int i = 1; i < sizeof(g_sClassNames); i++)
		if (StrContains(sName, g_sClassNames[i], false) != -1)
			return view_as<TFClassType>(i);

	return TFClass_Unknown;
}

bool IsWeaponPropClassname(int iEntity)
{
	return IsClassname(iEntity, "prop_dynamic") || IsClassname(iEntity, "prop_physics");
}

bool IsSpawnWeapon(int iEntity)
{
	WeaponType nWeaponType = GetWeaponType(iEntity);
	if (nWeaponType == WeaponType_Spawn || nWeaponType == WeaponType_RareSpawn || nWeaponType == WeaponType_StaticSpawn || nWeaponType == WeaponType_UncommonSpawn)
		return true;
	else
		return false;
}

bool SetRandomPickup(int iEntity)
{
	//Reset angle
	float vecAngles[3];
	
	TeleportEntity(iEntity, NULL_VECTOR, vecAngles, NULL_VECTOR);
	return SetRandomWeapon(iEntity, WeaponRarity_Pickup);
}

bool SetRandomWeapon(int iEntity, WeaponRarity nRarity, bool bIncludeSpawnOnly = false)
{
	//Check if the weapon has a filter
	TFClassType nClassFilter = GetWeaponClassFilter(iEntity);
	ArrayList aList = GetAllWeaponsWithRarity(nRarity, g_aWeaponsSpawn, nClassFilter, bIncludeSpawnOnly);
	
	if (aList.Length == 0)
	{
		//No weapons from given rarity and class, ignore class filter
		delete aList;
		aList = GetAllWeaponsWithRarity(nRarity, g_aWeaponsSpawn, _, bIncludeSpawnOnly);
	}
	
	if (aList.Length == 0)
	{
		delete aList;
		RemoveEntity(iEntity);
		return false;
	}
	
	int iRandom = GetRandomInt(0, aList.Length - 1);
	
	Weapon wep;
	aList.GetArray(iRandom, wep);
	
	SetWeaponModel(iEntity, wep);
	
	delete aList;
	return true;
}

void SetWeaponModel(int iEntity, Weapon wep)
{
	Weapon oldWep;
	GetWeaponFromEntity(oldWep, iEntity);
	
	if (wep.spawnCallback != INVALID_FUNCTION)
	{
		Call_StartFunction(null, wep.spawnCallback);
		Call_PushCell(iEntity);
		Call_Finish();
	}
	
	float flOldScale = oldWep.flScale ? oldWep.flScale : 1.0;
	
	SetEntityModel(iEntity, wep.sModel);
	SetEntProp(iEntity, Prop_Send, "m_nSkin", wep.iSkin);
	SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 1.0 / flOldScale * wep.flScale);
	
	if (wep.iColor[0] + wep.iColor[1] + wep.iColor[2] > 0)
	{
		SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iEntity, wep.iColor[0], wep.iColor[1], wep.iColor[2], 255);
	}
	
	int iChild = GetChildEntity(iEntity, "prop_dynamic");
	if (wep.sModelAttach[0] && iChild == INVALID_ENT_REFERENCE)
	{
		iChild = CreateEntityByName("prop_dynamic");
		SetEntityModel(iChild, wep.sModelAttach);
		SetEntProp(iChild, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW|EF_NOINTERP);
		
		SetEntityCollisionGroup(iChild, COLLISION_GROUP_NONE);
		
		DispatchSpawn(iChild);
		
		SetVariantString("!activator");
		AcceptEntityInput(iChild, "SetParent", iEntity);
	}
	else if (wep.sModelAttach[0])
	{
		SetEntityModel(iChild, wep.sModelAttach);
	}
	else if (iChild != INVALID_ENT_REFERENCE)
	{
		RemoveEntity(iChild);
	}
	
	//Update model origin and angles from weapon offset and const
	
	float vecOrigin[3], vecAngles[3], vecOffset[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);
	GetEntPropVector(iEntity, Prop_Send, "m_angRotation", vecAngles);
	
	RotateVector(oldWep.vecOriginOffset, vecAngles, vecOffset);
	AddVectors(vecOrigin, vecOffset, vecOrigin);
	
	SubtractVectors(vecAngles, oldWep.vecAnglesOffset, vecAngles);
	
	//No easy way to revert const from old weapon :(
	for (int i = 0; i < 3; i++)
	{
		if (wep.bAnglesConst[i])
			vecAngles[i] = wep.vecAnglesConst[i];
	}
	
	AddVectors(vecAngles, wep.vecAnglesOffset, vecAngles);
	
	RotateVector(wep.vecOriginOffset, vecAngles, vecOffset);
	SubtractVectors(vecOrigin, vecOffset, vecOrigin);
	
	TeleportEntity(iEntity, vecOrigin, vecAngles, NULL_VECTOR);
}

int GetWeaponGlowEnt(int iEntity)
{
	int iGlow = INVALID_ENT_REFERENCE;
	while ((iGlow = FindEntityByClassname(iGlow, "tf_taunt_prop")) != INVALID_ENT_REFERENCE)
	{
		if (GetEntPropEnt(iGlow, Prop_Data, "m_hEffectEntity") == iEntity && !RareOutline_IsOutline(iGlow))
			return iGlow;
	}
	
	return INVALID_ENT_REFERENCE;
}

public Action Weapon_SetTransmit(int iGlow, int iClient)
{
	const float flTimeExpire = 10.0;
	
	int iWeapon = GetEntPropEnt(iGlow, Prop_Data, "m_hEffectEntity");
	if (iWeapon == INVALID_ENT_REFERENCE)
	{
		//wat
		RemoveEntity(iGlow);
		return Plugin_Handled;
	}
	
	//Has it been recently called?
	bool bGlow;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_flWeaponCallout[iWeapon][i] > GetGameTime() - flTimeExpire)
		{
			bGlow = true;
			break;
		}
	}
	
	if (!bGlow)
	{
		//No, time expired, delet the glow
		RemoveEntity(iGlow);
		return Plugin_Handled;
	}
	
	if (!IsValidLivingSurvivor(iClient))
		return Plugin_Handled;
	
	//Did client recently called this weapon?
	if (g_flWeaponCallout[iWeapon][iClient] > GetGameTime() - flTimeExpire)
		return Plugin_Continue;
	
	//Can client pickup this weapon?
	Weapon wep;
	GetWeaponFromEntity(wep, iWeapon);
	if (TF2_GetItemSlot(wep.iIndex, TF2_GetPlayerClass(iClient)) >= 0)
		return Plugin_Continue;
	
	return Plugin_Handled;
}
