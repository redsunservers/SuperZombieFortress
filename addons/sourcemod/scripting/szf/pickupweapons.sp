#define PICKUP_COOLDOWN 	2.0
#define MAX_RARE			15

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
};

static bool g_bCanPickup[TF_MAXPLAYERS] = false;
static bool g_bTriggerEntity[2048] = true;
static float g_flLastCallout[TF_MAXPLAYERS] = 0.0;

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
	g_flLastCallout[iClient] = 0.0;
}

public Action Event_WeaponsRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	int iEntity = -1;
	int iRare;
	
	ArrayList aWeaponsCommon = GetAllWeaponsWithRarity(WeaponRarity_Common);
	
	while ((iEntity = FindEntityByClassname2(iEntity, "prop_dynamic")) != -1)
	{
		WeaponType nWeaponType = GetWeaponType(iEntity);
		
		switch (nWeaponType)
		{
			case WeaponType_Spawn:
			{
				if (aWeaponsCommon.Length > 0)
				{
					//Make sure every spawn weapons is different
					int iRandom = GetRandomInt(0, aWeaponsCommon.Length - 1);
					
					Weapon wep;
					aWeaponsCommon.GetArray(iRandom, wep);
					
					SetWeaponModel(iEntity, wep);
					aWeaponsCommon.Erase(iRandom);
				}
				else
				{
					//If we already went through every spawn weapons, no point having rest of it
					AcceptEntityInput(iEntity, "Kill");
					continue;
				}
			}
			case WeaponType_Rare:
			{
				//If rare weapon cap is unreached, make it a "rare" weapon
				if (iRare < MAX_RARE)
				{
					SetRandomWeapon(iEntity, WeaponRarity_Rare);
					iRare++;
				}
				//Else make it a uncommon weapon
				else
				{
					SetRandomWeapon(iEntity, WeaponRarity_Uncommon);
				}
			}
			case WeaponType_RareSpawn:
			{
				SetRandomWeapon(iEntity, WeaponRarity_Rare);
			}
			case WeaponType_Default, WeaponType_DefaultNoPickup:
			{
				//If rare weapon cap is unreached and a dice roll is met, make it a "rare" weapon
				if (iRare < MAX_RARE && !GetRandomInt(0, 5))
				{
					SetRandomWeapon(iEntity, WeaponRarity_Rare);
					iRare++;
				}
				//Pick-ups
				else if (!GetRandomInt(0, 9) && nWeaponType != WeaponType_DefaultNoPickup)
				{
					SetRandomPickup(iEntity);
				}
				//Else make it either common or uncommon weapon
				else
				{
					int iCommon = GetRarityWeaponCount(WeaponRarity_Common);
					int iUncommon = GetRarityWeaponCount(WeaponRarity_Uncommon);
					
					if (GetRandomInt(0, iCommon + iUncommon) < iCommon)
						SetRandomWeapon(iEntity, WeaponRarity_Common);
					else
						SetRandomWeapon(iEntity, WeaponRarity_Uncommon);
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
				continue;
			}
		}
		
		AcceptEntityInput(iEntity, "DisableShadow");
		AcceptEntityInput(iEntity, "EnableCollision");
		
		//Relocate weapon to higher height, looks much better
		float flPosition[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flPosition);
		flPosition[2] += 0.8;
		TeleportEntity(iEntity, flPosition, NULL_VECTOR, NULL_VECTOR);
		
		g_bTriggerEntity[iEntity] = true; //Indicate reset of the OnUser triggers
	}
	
	delete aWeaponsCommon;
}

public Action Event_ResetPickup(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsValidClient(iClient))
	{
		g_bCanPickup[iClient] = true;
		g_flLastCallout[iClient] = 0.0;
	}
}

bool AttemptGrabItem(int iClient)
{	
	if (!IsSurvivor(iClient) || !g_bCanPickup[iClient])
		return false;
	
	int iTarget = GetClientPointVisible(iClient);
	
	if (iTarget <= 0 || !IsClassname(iTarget, "prop_dynamic") || GetWeaponType(iTarget) == WeaponType_Invalid)
		return false;
	
	char sModel[256];
	GetEntityModel(iTarget, sModel, sizeof(sModel));
	
	Weapon wep;
	if (!GetWeaponFromModel(wep, sModel))
		return false;
	
	bool bAllowPickup = true;
	if (wep.callback != INVALID_FUNCTION)
	{
		Call_StartFunction(null, wep.callback);
		Call_PushCell(iClient);
		Call_Finish(bAllowPickup);
	}
	
	if (wep.nRarity == WeaponRarity_Pickup)
	{
		if (!bAllowPickup)
			return false;
		
		if (wep.sSound[0] != '\0')
			EmitSoundToClient(iClient, wep.sSound);
		
		AcceptEntityInput(iTarget, ENT_ONKILL, iClient, iClient);
		AcceptEntityInput(iTarget, "Kill");
		
		return true;
	}
	
	int iIndex = wep.iIndex;
	WeaponRarity nRarity = wep.nRarity;
	
	if (iIndex > -1)
	{
		char sClient[128];
		GetClientName2(iClient, sClient, sizeof(sClient));
		
		int iSlot = TF2_GetItemSlot(iIndex, TF2_GetPlayerClass(iClient));
		if (iSlot >= 0 && bAllowPickup)
		{
			if (nRarity == WeaponRarity_Rare)
			{
				char sName[255];
				TF2Econ_GetLocalizedItemName(iIndex, sName, sizeof(sName));
				SZF_CPrintToChatAll(iClient, "I have picked up a {limegreen}{param3}\x01!", true, .sParam3 = sName);
				
				AddToCookie(iClient, 1, g_cWeaponsRarePicked);
				if (GetCookie(iClient, g_cWeaponsRarePicked) <= 1)
				{
					DataPack data;
					CreateDataTimer(0.5, Timer_DisplayTutorialMessage, data);
					data.WriteCell(iClient);
					data.WriteFloat(2.0);
					data.WriteString("You have picked up a very effective weapon.");
					
					CreateDataTimer(2.5, Timer_DisplayTutorialMessage, data);
					data.WriteCell(iClient);
					data.WriteFloat(3.0);
					data.WriteString("Some weapons have a lower chance of appearing, like this one.");
				}
			}
			
			PickupWeapon(iClient, wep, iTarget);
			
			return true;
		}
		else if (nRarity == WeaponRarity_Rare && g_flLastCallout[iClient] + 5.0 < GetGameTime())
		{
			char sName[255];
			TF2Econ_GetLocalizedItemName(iIndex, sName, sizeof(sName));
			SZF_CPrintToChatAll(iClient, "{limegreen}{param3} \x01here!", true, .sParam3 = sName);
			
			AddToCookie(iClient, 1, g_cWeaponsCalled);
			if (GetCookie(iClient, g_cWeaponsCalled) <= 1)
			{
				DataPack data;
				CreateDataTimer(0.5, Timer_DisplayTutorialMessage, data);
				data.WriteCell(iClient);
				data.WriteFloat(4.0);
				data.WriteString("Calling out specific weapons allows other teammates to pick up the weapon.");
			}
			
			g_flLastCallout[iClient] = GetGameTime();
			
			Forward_OnWeaponCallout(iClient);
		}
	}
	
	return false;
}

void PickupWeapon(int iClient, Weapon wep, int iTarget)
{
	if (wep.sSound[0] == '\0')
		EmitSoundToClient(iClient, "ui/item_heavy_gun_pickup.wav");
	else
		EmitSoundToClient(iClient, wep.sSound);
	
	g_bCanPickup[iClient] = false;
	CreateTimer(PICKUP_COOLDOWN, Timer_ResetPickup, iClient);
	
	//Weapon pickup quote
	char sSound[PLATFORM_MAX_PATH];
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	
	switch (iClass)
	{
		case TFClass_Scout: Format(sSound, sizeof(sSound), g_sVoWeaponScout[GetRandomInt(0, sizeof(g_sVoWeaponScout)-1)]);
		case TFClass_Soldier: Format(sSound, sizeof(sSound), g_sVoWeaponSoldier[GetRandomInt(0, sizeof(g_sVoWeaponSoldier)-1)]);
		case TFClass_Pyro: Format(sSound, sizeof(sSound), g_sVoWeaponPyro[GetRandomInt(0, sizeof(g_sVoWeaponPyro)-1)]);
		case TFClass_DemoMan: Format(sSound, sizeof(sSound), g_sVoWeaponDemoman[GetRandomInt(0, sizeof(g_sVoWeaponDemoman)-1)]);
		case TFClass_Heavy: Format(sSound, sizeof(sSound), g_sVoWeaponHeavy[GetRandomInt(0, sizeof(g_sVoWeaponHeavy)-1)]);
		case TFClass_Engineer: Format(sSound, sizeof(sSound), g_sVoWeaponEngineer[GetRandomInt(0, sizeof(g_sVoWeaponEngineer)-1)]);
		case TFClass_Medic: Format(sSound, sizeof(sSound), g_sVoWeaponMedic[GetRandomInt(0, sizeof(g_sVoWeaponMedic)-1)]);
		case TFClass_Sniper: Format(sSound, sizeof(sSound), g_sVoWeaponSniper[GetRandomInt(0, sizeof(g_sVoWeaponSniper)-1)]);
		case TFClass_Spy: Format(sSound, sizeof(sSound), g_sVoWeaponSpy[GetRandomInt(0, sizeof(g_sVoWeaponSpy)-1)]);
	}
	
	EmitSoundToAll(sSound, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	
	int iSlot = TF2_GetItemSlot(wep.iIndex, iClass);
	WeaponType iWepType = GetWeaponType(iTarget);
	
	//TODO: Use a flag for spawn weapons instead?
	if (iWepType != WeaponType_Spawn && iWepType != WeaponType_RareSpawn && iWepType != WeaponType_StaticSpawn)
	{
		Weapon oldwep;
		
		int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (!IsValidEntity(iEntity))
			iEntity = SDKCall_GetEquippedWearable(iClient, iSlot); //If weapon not found in slot, check if it a wearable
		
		if (IsValidEntity(iEntity))
		{
			int iOldIndex = GetOriginalItemDefIndex(GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex"));
			GetWeaponFromIndex(oldwep, iOldIndex);
			
			if (oldwep.iIndex > 0)
			{
				EmitSoundToClient(iClient, "ui/item_heavy_gun_drop.wav");
				SetWeaponModel(iTarget, oldwep);
			}
			else
			{
				AcceptEntityInput(iTarget, ENT_ONKILL, iClient, iClient);
				AcceptEntityInput(iTarget, "Kill");
			}
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
	
	//Generate and equip weapon
	int iWeapon = TF2_CreateAndEquipWeapon(iClient, wep.iIndex, _, wep.sAttribs, wep.sText);
	
	char sClassname[256];
	TF2Econ_GetItemClassName(wep.iIndex, sClassname, sizeof(sClassname));
	if (StrContains(sClassname, "tf_wearable") == 0) 
	{ 
		if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") <= MaxClients)
		{
			//Looks like player's active weapon got replaced into wearable, fix that by using melee
			int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iMelee);
		}
	}
	else 
	{
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
		TF2_FlagWeaponDontDrop(iWeapon);
	}
	
	//Set ammo as weapon's max ammo
	if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))	//Wearables dont have ammo netprop
	{
		int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmoType > -1)
		{
			//We want to set gas passer's ammo to 0, because thats how normal gas passer works
			int iMaxAmmo;
			if (wep.iIndex == 1180)
			{
				iMaxAmmo = 0;
				SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
			}
			else
			{
				iMaxAmmo = SDKCall_GetMaxAmmo(iClient, iAmmoType);
			}
			
			SetEntProp(iClient, Prop_Send, "m_iAmmo", iMaxAmmo, _, iAmmoType);
		}
	}
	
	//Add weapon pickup to player as cookie
	AddToCookie(iClient, 1, g_cWeaponsPicked);
	if (GetCookie(iClient, g_cWeaponsPicked) <= 1)
	{
		DataPack data;
		CreateDataTimer(0.5, Timer_DisplayTutorialMessage, data);
		data.WriteCell(iClient);
		data.WriteFloat(2.5);
		data.WriteString("You have picked up a weapon.");
		
		CreateDataTimer(3.0, Timer_DisplayTutorialMessage, data);
		data.WriteCell(iClient);
		data.WriteFloat(3.5);
		data.WriteString("Finding weapons is crucial to ensure survival.");
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
	else if (StrContains(sName, "szf_weapon", false) != -1)
		return WeaponType_Default; //Normal
	
	return WeaponType_Invalid;
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
	ArrayList aList = GetAllWeaponsWithRarity(nRarity);
	int iRandom = GetRandomInt(0, aList.Length - 1);
	
	Weapon wep;
	aList.GetArray(iRandom, wep);
	
	SetWeaponModel(iEntity, wep);
	
	if (wep.iColor[0] + wep.iColor[1] + wep.iColor[2] > 0)
	{
		SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iEntity, wep.iColor[0], wep.iColor[1], wep.iColor[2], 255);
	}
	
	delete aList;
}

void SetWeaponModel(int iEntity, Weapon wep)
{
	char sOldModel[256];
	GetEntityModel(iEntity, sOldModel, sizeof(sOldModel));
	
	float vecOrigin[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);
	
	float vecAngles[3];
	GetEntPropVector(iEntity, Prop_Send, "m_angRotation", vecAngles);
	
	//Offsets (will only work for pickups for now)
	if (wep.nRarity == WeaponRarity_Pickup)
	{
		AddVectors(vecOrigin, wep.vecOrigin, vecOrigin);
		AddVectors(vecAngles, wep.vecAngles, vecAngles);
		
		TeleportEntity(iEntity, vecOrigin, vecAngles, NULL_VECTOR);
	}
	
	//Because sniper wearable have a really offplace origin prop, we have to move entity to a more reasonable spot
	if (StrEqual(sOldModel, "models/player/items/sniper/knife_shield.mdl")
		|| StrEqual(sOldModel, "models/player/items/sniper/xms_sniper_commandobackpack.mdl"))
	{
		float vecDirection[3];
		GetAngleVectors(vecAngles, vecDirection, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(vecDirection, 64.0);
		
		vecOrigin[0] += vecDirection[1] * Sine(DegToRad(vecAngles[2]));
		vecOrigin[1] -= vecDirection[0] * Sine(DegToRad(vecAngles[2]));
		vecOrigin[2] += 64.0 * Cosine(DegToRad(vecAngles[2]));
		
		TeleportEntity(iEntity, vecOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	
	SetEntityModel(iEntity, wep.sModel);
	
	if (StrEqual(wep.sModel, "models/player/items/sniper/knife_shield.mdl")
		|| StrEqual(wep.sModel, "models/player/items/sniper/xms_sniper_commandobackpack.mdl"))
	{
		float vecDirection[3];
		GetAngleVectors(vecAngles, vecDirection, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(vecDirection, 64.0);
		
		vecOrigin[0] -= vecDirection[1] * Sine(DegToRad(vecAngles[2]));
		vecOrigin[1] += vecDirection[0] * Sine(DegToRad(vecAngles[2]));
		vecOrigin[2] -= 64.0 * Cosine(DegToRad(vecAngles[2]));
		
		TeleportEntity(iEntity, vecOrigin, NULL_VECTOR, NULL_VECTOR);
	}
}

//Grabs the entity model by looking in the precache database of the server
void GetEntityModel(int iEntity, char[] sModel, int iMaxSize, char[] sPropName = "m_nModelIndex")
{
	int iIndex = GetEntProp(iEntity, Prop_Send, sPropName);
	GetModelPath(iIndex, sModel, iMaxSize);
}

void GetModelPath(int iIndex, char[] sModel, int iMaxSize)
{
	int iTable = FindStringTable("modelprecache");
	ReadStringTable(iTable, iIndex, sModel, iMaxSize);
}
