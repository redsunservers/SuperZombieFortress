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
};

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
	
	delete g_aWeaponsCommon;
	delete g_aWeaponsUncommon;
	delete g_aWeaponsRares;
	delete g_aWeaponsSpawn;
	
	g_aWeaponsCommon = GetAllWeaponsWithRarity(WeaponRarity_Common);
	g_aWeaponsUncommon = GetAllWeaponsWithRarity(WeaponRarity_Uncommon);
	g_aWeaponsRares = GetAllWeaponsWithRarity(WeaponRarity_Rare);
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
		
	switch (nWeaponType)
	{
		case WeaponType_Spawn:
		{
			SetUniqueWeapon(iEntity, g_aWeaponsCommon, WeaponRarity_Common);
		}
		case WeaponType_Rare:
		{
			//If rare weapon cap is unreached, make it a "rare" weapon
			if (g_iAvailableRareCount > 0)
			{
				SetUniqueWeapon(iEntity, g_aWeaponsRares, WeaponRarity_Rare);
				
				g_iAvailableRareCount--;
			}
			//Else make it a uncommon weapon
			else
			{
				SetRandomWeapon(iEntity, WeaponRarity_Uncommon);
			}
		}
		case WeaponType_RareSpawn:
		{
			SetUniqueWeapon(iEntity, g_aWeaponsRares, WeaponRarity_Rare);
		}
		case WeaponType_UncommonSpawn:
		{
			SetUniqueWeapon(iEntity, g_aWeaponsUncommon, WeaponRarity_Uncommon);
		}
		case WeaponType_Common:
		{
			SetRandomWeapon(iEntity, WeaponRarity_Common);
		}
		case WeaponType_Uncommon:
		{
			SetRandomWeapon(iEntity, WeaponRarity_Uncommon);
		}
		case WeaponType_Default, WeaponType_DefaultNoPickup:
		{
			//If rare weapon cap is unreached and a dice roll is met, make it a "rare" weapon
			if (g_iAvailableRareCount > 0 && GetRandomFloat(0.0, 1.0) < g_cvWeaponRareChance.FloatValue)
			{
				SetUniqueWeapon(iEntity, g_aWeaponsRares, WeaponRarity_Rare);
				g_iAvailableRareCount--;
			}
			//Pick-ups
			else if (nWeaponType != WeaponType_DefaultNoPickup && GetRandomFloat(0.0, 1.0) < g_cvWeaponPickupChance.FloatValue)
			{
				SetRandomPickup(iEntity);
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
				
				Weapon wep;
				aList.GetArray(GetRandomInt(0, aList.Length - 1), wep);
				delete aList;
				
				SetWeaponModel(iEntity, wep);
			}
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
	
	SetEntProp(iEntity, Prop_Send, "m_nSolidType", SOLID_OBB);
	SetEntityCollisionGroup(iEntity, COLLISION_GROUP_DEBRIS_TRIGGER);
	AcceptEntityInput(iEntity, "DisableShadow");
	AcceptEntityInput(iEntity, "EnableCollision");
	
	g_bTriggerEntity[iEntity] = true; //Indicate reset of the OnUser triggers
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

void SetUniqueWeapon(int iEntity, ArrayList &aWeapons, WeaponRarity iWepRarity)
{
	Weapon wep;
	TFClassType nClassFilter = GetWeaponClassFilter(iEntity);
	
	if (aWeapons.Length == 0)
	{
		// No more unique weapons to pick, delete it
		RemoveEntity(iEntity);
		return;
	}
	
	if (nClassFilter == TFClass_Unknown)
	{
		if (IsSpawnWeapon(iEntity))
			aWeapons.SortCustom(Sort_SpawnWeapons);	// Priorise whoever class with fewest spawn weapons
		else
			aWeapons.Sort(Sort_Random, Sort_Integer);	// No class filter
		
		aWeapons.GetArray(0, wep);
		SetWeaponModel(iEntity, wep);
		
		//This weapon is no longer in the pool
		aWeapons.Erase(0);
		g_aWeaponsSpawn.Push(wep.iIndex);
	}
	else
	{
		// Filter specific class
		aWeapons.Sort(Sort_Random, Sort_Integer);
		
		for (int i = 0; i < aWeapons.Length; i++)
		{
			aWeapons.GetArray(i, wep);
			int iSlot = TF2_GetItemSlot(wep.iIndex, nClassFilter);
			if (iSlot >= 0)
			{
				//This weapon is no longer in the pool in the global array
				aWeapons.Erase(i);
				g_aWeaponsSpawn.Push(wep.iIndex);
				
				SetWeaponModel(iEntity, wep);
				return;
			}
		}
		
		//If array empty, pick a random weapon
		SetRandomWeapon(iEntity, iWepRarity);
	}
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
	if (!IsSurvivor(iClient) || !g_bCanPickup[iClient] || TF2_IsPlayerInCondition(iClient, TFCond_Taunting))
		return false;
	
	int iTarget = GetClientPointVisible(iClient);
	
	if (iTarget <= 0 || !IsClassname(iTarget, "prop_dynamic") || GetWeaponType(iTarget) == WeaponType_Invalid)
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
			GetWeaponFromIndex(oldwep, iOldIndex);
			
			if (oldwep.iIndex >= 0)
			{
				EmitSoundToClient(iClient, "ui/item_heavy_gun_drop.wav");
				SetWeaponModel(iTarget, oldwep);
				
				//Kill the weapon glow with its model if it had one.
				int iGlow = GetWeaponGlowEnt(iTarget);
				if (iGlow != INVALID_ENT_REFERENCE)
					RemoveEntity(iGlow);
				
				//Callout under a new weapon model
				CalloutWeapon(iClient, iTarget, true);
				
				bKillEntity = false;
			}
		}
		
		if (bKillEntity)
		{
			AcceptEntityInput(iTarget, ENT_ONKILL, iClient, iClient);
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

bool IsSpawnWeapon(int iEntity)
{
	WeaponType nWeaponType = GetWeaponType(iEntity);
	if (nWeaponType == WeaponType_Spawn || nWeaponType == WeaponType_RareSpawn || nWeaponType == WeaponType_StaticSpawn || nWeaponType == WeaponType_UncommonSpawn)
		return true;
	else
		return false;
}

void SetRandomPickup(int iEntity)
{
	//Reset angle
	float vecAngles[3];
	
	TeleportEntity(iEntity, NULL_VECTOR, vecAngles, NULL_VECTOR);
	SetRandomWeapon(iEntity, WeaponRarity_Pickup);
}

void SetRandomWeapon(int iEntity, WeaponRarity nRarity)
{
	//Check if the weapon has a filter
	TFClassType nClassFilter = GetWeaponClassFilter(iEntity);
	ArrayList aList = GetAllWeaponsWithRarity(nRarity, g_aWeaponsSpawn, nClassFilter);
	
	if (aList.Length == 0)
	{
		//No weapons from given rarity and class, ignore class filter
		delete aList;
		aList = GetAllWeaponsWithRarity(nRarity, g_aWeaponsSpawn);
	}
	
	int iRandom = GetRandomInt(0, aList.Length - 1);
	
	Weapon wep;
	aList.GetArray(iRandom, wep);
	
	SetWeaponModel(iEntity, wep);
	
	delete aList;
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
		if (GetEntPropEnt(iGlow, Prop_Data, "m_hEffectEntity") == iEntity)
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
