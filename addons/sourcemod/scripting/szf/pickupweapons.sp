#define PICKUP_COOLDOWN 	1.5
#define MAX_RARE			15

#define ENT_ONPICKUP	"FireUser1"
#define ENT_ONKILL		"FireUser2"

enum eWeaponsType
{
	eWeaponsType_Invalid,
	eWeaponsType_Static,
	eWeaponsType_Default,
	eWeaponsType_Spawn,
	eWeaponsType_Rare,
	eWeaponsType_RareSpawn,
	eWeaponsType_StaticSpawn,
	eWeaponsType_DefaultNoPickup,
};

//TODO convert this to enum struct once server use 1.10
enum eWeapons
{
	iWeaponsIndex,
	eWeaponsRarity:nWeaponsRarity,
	String:sWeaponsModel[256],
	String:sWeaponsName[256],
}

enum eWeaponsReskin
{
	iWeaponsReskinIndex,
	String:sWeaponsReskinModel[256],
}

#include "szf/weapons.sp"

ArrayList g_aWeaponsRarity[eWeaponsRarity];

bool g_bCanPickup[MAXPLAYERS+1] = false;
bool g_bTriggerEntity[2048] = true;
float g_fLastCallout[MAXPLAYERS+1] = 0.0;

// Cookies
Handle weaponsPicked;
Handle weaponsRarePicked;
Handle weaponsCalled;

public void Weapons_Setup()
{
	AddCommandListener(EventVoiceMenu, "voicemenu");
	HookEvent("teamplay_round_start", EventStart);
	HookEvent("player_spawn", EventReset);
	HookEvent("player_death", EventReset);

	weaponsPicked = RegClientCookie("weaponspicked", "is this the flowey map?", CookieAccess_Protected);
	weaponsRarePicked = RegClientCookie("weaponsrarepicked", "is this the flowey map?", CookieAccess_Protected);
	weaponsCalled = RegClientCookie("weaponscalled", "is this the flowey map?", CookieAccess_Protected);
	
	//Create lists to seperate between rarity
	for (int i = 0; i < INT(eWeaponsRarity); i++)
		g_aWeaponsRarity[i] = new ArrayList();
	
	for (int i = 0; i < sizeof(g_nWeapons); i++)
	{
		eWeaponsRarity nRarity = g_nWeapons[i][nWeaponsRarity];
		int iIndex = g_nWeapons[i][iWeaponsIndex];
		g_aWeaponsRarity[nRarity].Push(iIndex);
	}
}

public void Weapons_ClientDisconnect(int iClient)
{
	g_bCanPickup[iClient] = true;
	g_fLastCallout[iClient] = 0.0;
}

public void Weapons_Precache()
{
	SoundPrecache();
	
	for (int i = 0; i < sizeof(g_nWeapons); i++)
		PrecacheModel(g_nWeapons[i][sWeaponsModel]);
	
	PrecacheSound("ui/item_heavy_gun_pickup.wav");
	PrecacheSound("ui/item_heavy_gun_drop.wav");
}

public Action EventStart(Event event, const char[] name, bool dontBroadcast)
{
	int iEntity = -1;
	int iRare = 0;
	
	int iCommon = INT(eWeaponsRarity_Common);
	int iUncommon = INT(eWeaponsRarity_Uncommon);
	ArrayList aWeaponsCommon = g_aWeaponsRarity[iCommon].Clone();
	
	while ((iEntity = FindEntityByClassname2(iEntity, "prop_dynamic")) != -1)
	{
		// if weapon
		if (GetWeaponType(iEntity) != eWeaponsType_Invalid)
		{
			// spawn weapon
			if (GetWeaponType(iEntity) == eWeaponsType_Spawn)
			{
				if (aWeaponsCommon.Length > 0)
				{
					//Make sure every spawn weapons is different
					int iRandom = GetRandomInt(0, aWeaponsCommon.Length - 1);
					int iIndex = aWeaponsCommon.Get(iRandom);
					
					for (int i = 0; i < sizeof(g_nWeapons); i++)
					{
						if (g_nWeapons[i][iWeaponsIndex] == iIndex)
						{
							SetWeaponModel(iEntity, g_nWeapons[i][sWeaponsModel]);
							aWeaponsCommon.Erase(iRandom);
							break;
						}
					}
				}
				else
				{
					//If we already went through every spawn weapons, no point having rest of it
					AcceptEntityInput(iEntity, "Kill");
					continue;
				}
			}
			
			// rare weapon
			else if (GetWeaponType(iEntity) == eWeaponsType_Rare)
			{
				// if rare weapon cap is unreached, make it a "rare" weapon
				if (iRare < MAX_RARE)
				{
					SetRandomWeapon(iEntity, eWeaponsRarity_Rare);
					iRare++;
				}

				// else make it a uncommon weapon
				else
				{
					SetRandomWeapon(iEntity, eWeaponsRarity_Uncommon);
				}
			}

			// rare weapon that doesnt dissapear and is not affected by max rare cap
			else if (GetWeaponType(iEntity) == eWeaponsType_RareSpawn)
			{
				SetRandomWeapon(iEntity, eWeaponsRarity_Rare);
			}

			// else if not a spawn weapon
			else if (GetWeaponType(iEntity) == eWeaponsType_Default
			|| GetWeaponType(iEntity) == eWeaponsType_DefaultNoPickup)
			{
				// if rare weapon cap is unreached and a dice roll is met, make it a "rare" weapon
				if (iRare < MAX_RARE && !GetRandomInt(0, 5))
				{
					SetRandomWeapon(iEntity, eWeaponsRarity_Rare);
					iRare++;
				}

				// pick-ups
				else if (!GetRandomInt(0, 9) && GetWeaponType(iEntity) != eWeaponsType_DefaultNoPickup)
				{
					SetRandomPickup(iEntity);
				}

				// else make it either common or uncommon weapon
				else
				{
					if (GetRandomInt(0, g_aWeaponsRarity[iCommon].Length+g_aWeaponsRarity[iUncommon].Length) < g_aWeaponsRarity[iCommon].Length)
						SetRandomWeapon(iEntity, eWeaponsRarity_Common);
					else
						SetRandomWeapon(iEntity, eWeaponsRarity_Uncommon);
				}
			}
			
			// static weapon
			else if (GetWeaponType(iEntity) == eWeaponsType_Static
			|| GetWeaponType(iEntity) == eWeaponsType_StaticSpawn)
			{
				for (int i = 0; i < sizeof(g_nWeaponsReskin); i++)
				{
					char strModel[256];
					GetEntityModel(iEntity, strModel, sizeof(strModel));
					
					// check if there reskin weapons to replace
					if (StrEqual(g_nWeaponsReskin[i][sWeaponsReskinModel], strModel))
					{
						//Find same index to replace
						for (int j = 0; j < sizeof(g_nWeapons); j++)
						{
							if (g_nWeapons[j][iWeaponsIndex] == g_nWeaponsReskin[i][iWeaponsReskinIndex])
							{
								SetWeaponModel(iEntity, g_nWeapons[j][sWeaponsModel]);
								break;
							}
						}
					}
				}
			}

			AcceptEntityInput(iEntity, "DisableShadow");
			AcceptEntityInput(iEntity, "EnableCollision");

			// relocate weapon to higher height, looks much better
			float flPosition[3];
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flPosition);
			flPosition[2] += 0.8;
			TeleportEntity(iEntity, flPosition, NULL_VECTOR, NULL_VECTOR);

			g_bTriggerEntity[iEntity] = true; // indicate reset of the OnUser triggers
		}
	}
	
	delete aWeaponsCommon;
}

public Action EventReset(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidClient(iClient))
	{
		g_bCanPickup[iClient] = true;
		g_fLastCallout[iClient] = 0.0;
	}
}

public Action EventVoiceMenu(int iClient, const char[] command, int argc)
{
	if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Continue;
	
	char cmd1[32], cmd2[32];
	GetCmdArg(1, cmd1, sizeof(cmd1));
	GetCmdArg(2, cmd2, sizeof(cmd2));

	if(StrEqual(cmd1, "0") && StrEqual(cmd2, "0"))
	{
		// if an item was succesfully grabbed
		if (AttemptGrabItem(iClient))
		{
			return Plugin_Handled;
		}

		return Plugin_Continue;
	}

	return Plugin_Continue;
}

bool AttemptGrabItem(int iClient)
{	
	if (!IsSurvivor(iClient)) return false;
	if (!g_bCanPickup[iClient]) return false;
	
	int iTarget = GetClientPointVisible(iClient);

	if (iTarget <= 0 || !IsClassname(iTarget, "prop_dynamic") || GetWeaponType(iTarget) == eWeaponsType_Invalid)
	{
		return false;
	}
	
	char strModel[256];
	GetEntityModel(iTarget, strModel, sizeof(strModel));

	// Pick-ups
	if (StrEqual(strModel, "models/items/ammopack_large.mdl") || StrEqual(strModel, "models/items/medkit_large.mdl"))
	{
		SpawnPickup(iClient, StrEqual(strModel, "models/items/ammopack_large.mdl") ? "item_ammopack_full" : "item_healthkit_full");
		EmitSoundToClient(iClient, "ui/item_heavy_gun_pickup.wav"); // TODO: CHANGE SOUND
		AcceptEntityInput(iTarget, ENT_ONKILL, iClient, iClient);
		AcceptEntityInput(iTarget, "Kill");
		return true;
	}
	//Temporary Powerups
	if (StrEqual(strModel, "models/weapons/c_models/c_energy_drink/c_energy_drink.mdl"))
	{
		TF2_AddCondition(iClient,TFCond.TFCOND_DefenseBuffed,30.0);
		TF2_AddCondition(iClient,TFCond.TFCOND_DefenseBuffNoCritBlock,30.0);
		EmitSoundToClient(iClient, "ui/item_heavy_gun_pickup.wav"); // TODO: CHANGE SOUND
		AcceptEntityInput(iTarget, ENT_ONKILL, iClient, iClient);
		AcceptEntityInput(iTarget, "Kill");
		return true;
	}
	
	//Find index from model
	int iIndex = -1;
	eWeaponsRarity nRarity;
	char sName[256];
	for (int i = 0; i < sizeof(g_nWeapons); i++)
	{
		if (StrEqual(g_nWeapons[i][sWeaponsModel], strModel))
		{
			iIndex = g_nWeapons[i][iWeaponsIndex];
			nRarity = g_nWeapons[i][nWeaponsRarity];
			Format(sName, sizeof(sName), g_nWeapons[i][sWeaponsName]);
			break;
		}
	}
	
	if (iIndex > -1)
	{
		char strPlayer[128];
		GetClientName2(iClient, strPlayer, sizeof(strPlayer));

		if (StrEqual(sName, ""))
			TF2Econ_GetItemName(iIndex, sName, sizeof(sName));
		ReplaceString(sName, sizeof(sName), "The", "", true);
		TrimString(sName);
		
		if (iIndex == 9)	//Shotgun
		{
			switch (TF2_GetPlayerClass(iClient))
			{
				case TFClass_Soldier: iIndex = 10;
				case TFClass_Pyro: iIndex = 12;
				case TFClass_Engineer: iIndex = 9;
			}
		}
		
		int iSlot = TF2Econ_GetItemSlot(iIndex, TF2_GetPlayerClass(iClient));
		if (iSlot >= 0)
		{
			if (nRarity == eWeaponsRarity_Rare)
			{
				char strResult[255];
				Format(strResult, sizeof(strResult), "(TEAM) %s\x01 : I have picked up a {limegreen}%s\x01!", strPlayer, sName);
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidSurvivor(i))
					{
						CPrintToChatEx(i, iClient, strResult);
					}
				}

				AddToCookie(iClient, 1, weaponsRarePicked);
				int RareWeaponsPicked = GetCookie(iClient, weaponsRarePicked);

				if (RareWeaponsPicked <= 1)
				{
					DataPack hPack1 = new DataPack();
					CreateDataTimer(0.5, DisplayTutorialMessage, hPack1);
					hPack1.WriteCell(iClient);
					hPack1.WriteFloat(2.0);
					hPack1.WriteString("You have picked up a very effective weapon.");

					DataPack hPack2 = new DataPack();
					CreateDataTimer(2.5, DisplayTutorialMessage, hPack2);
					hPack2.WriteCell(iClient);
					hPack2.WriteFloat(3.0);
					hPack2.WriteString("Some weapons have a lower chance of appearing, like this one.");
				}
			}

			PickupWeapon(iClient, iIndex, iTarget);
			
			return true;
		}
		else if (nRarity == eWeaponsRarity_Rare && g_fLastCallout[iClient] + 5.0 < GetGameTime())
		{
			char strResult[255];
			Format(strResult, sizeof(strResult), "(TEAM) %s\x01 : {limegreen}%s \x01here!", strPlayer, sName);
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidSurvivor(i))
				{
					CPrintToChatEx(i, iClient, strResult);
				}
			}

			AddToCookie(iClient, 1, weaponsCalled);
			int WeaponsCalled = GetCookie(iClient, weaponsCalled);
			if (WeaponsCalled <= 1)
			{
				DataPack hPack1 = new DataPack();
				CreateDataTimer(0.5, DisplayTutorialMessage, hPack1);
				hPack1.WriteCell(iClient);
				hPack1.WriteFloat(4.0);
				hPack1.WriteString("Calling out specific weapons allows other teammates to pick up the weapon.");
			}
			
			g_fLastCallout[iClient] = GetGameTime();
			
			Call_StartForward(g_hForwardWeaponCallout);
			Call_PushCell(iClient);
			Call_Finish();
		}
	}

	return false;
}

public void PickupWeapon(int iClient, int iIndex, int iTarget)
{
	EmitSoundToClient(iClient, "ui/item_heavy_gun_pickup.wav");

	g_bCanPickup[iClient] = false;
	CreateTimer(PICKUP_COOLDOWN, ResetPickup, iClient);

	if (TF2_GetPlayerClass(iClient) == TFClass_Soldier)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strWeaponVO_Soldier)-1);
		EmitSoundToAll(g_strWeaponVO_Soldier[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (TF2_GetPlayerClass(iClient) == TFClass_Pyro)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strWeaponVO_Pyro)-1);
		EmitSoundToAll(g_strWeaponVO_Pyro[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (TF2_GetPlayerClass(iClient) == TFClass_DemoMan)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strWeaponVO_DemoMan)-1);
		EmitSoundToAll(g_strWeaponVO_DemoMan[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (TF2_GetPlayerClass(iClient) == TFClass_Engineer)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strWeaponVO_Engineer)-1);
		EmitSoundToAll(g_strWeaponVO_Engineer[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (TF2_GetPlayerClass(iClient) == TFClass_Medic)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strWeaponVO_Medic)-1);
		EmitSoundToAll(g_strWeaponVO_Medic[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (TF2_GetPlayerClass(iClient) == TFClass_Sniper)
	{
		int iRandom = GetRandomInt(0, sizeof(g_strWeaponVO_Sniper)-1);
		EmitSoundToAll(g_strWeaponVO_Sniper[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	int iSlot = TF2Econ_GetItemSlot(iIndex, TF2_GetPlayerClass(iClient));

	if (GetWeaponType(iTarget) != eWeaponsType_Spawn
	&& GetWeaponType(iTarget) != eWeaponsType_RareSpawn
	&& GetWeaponType(iTarget) != eWeaponsType_StaticSpawn)
	{
		char sModel[256]; // weapon model path

		int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (!IsValidEdict(iEntity))
		{
			//If weapon not found in slot, check if it a wearable
			int iWearable = SDK_GetEquippedWearable(iClient, iSlot);
			if (iWearable > MaxClients)
				iEntity = iWearable;
		}
		
		if (iEntity > MaxClients && IsValidEdict(iEntity))
		{
			int iOldIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
			if (iOldIndex == 9 || iOldIndex == 10 || iOldIndex == 12)	//Shotgun
				iOldIndex = 9;
			
			for (int i = 0; i < sizeof(g_nWeapons); i++)
			{
				if (g_nWeapons[i][iWeaponsIndex] == iOldIndex)
				{
					Format(sModel, sizeof(sModel), g_nWeapons[i][sWeaponsModel]);
					break;
				}
			}
		}
		
		if (strlen(sModel) > 0)
		{
			EmitSoundToClient(iClient, "ui/item_heavy_gun_drop.wav");
			SetWeaponModel(iTarget, sModel);
		}

		else
		{
			AcceptEntityInput(iTarget, ENT_ONKILL, iClient, iClient);
			AcceptEntityInput(iTarget, "Kill");
		}
	}

	// remove sniper scope and slowdown cond if have one, otherwise it can cause client crashes
	if (TF2_IsPlayerInCondition(iClient, TFCond_Zoomed))
	{
		TF2_RemoveCondition(iClient, TFCond_Zoomed);
		TF2_RemoveCondition(iClient, TFCond_Slowed);
	}

	// force crit reset
	int iRevengeCrits = GetEntProp(iClient, Prop_Send, "m_iRevengeCrits");
	if (iRevengeCrits > 0)
	{
		SetEntProp(iClient, Prop_Send, "m_iRevengeCrits", 0);
		TF2_RemoveCondition(iClient, TFCond_Kritzkrieged);
	}
	
	//If player already have item in his inv, remove it before we generate new weapon for him, otherwise some weapons can glich out...
	int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
	if (iEntity > MaxClients && IsValidEdict(iEntity))
		TF2_RemoveWeaponSlot(iClient, iSlot);
		
	//Remove wearable if have one
	int iWearable = SDK_GetEquippedWearable(iClient, iSlot);
	if (iWearable > MaxClients)
	{
		SDK_RemoveWearable(iClient, iWearable);
		AcceptEntityInput(iWearable, "Kill");
	}
	
	// generate and equip weapon
	int iWeapon = TF2_CreateAndEquipWeapon(iClient, iIndex);
	
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
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
			//We want to set gas passer ammo empty, because thats how normal gas passer works
			int iMaxAmmo;
			if (iIndex == 1180)
			{
				iMaxAmmo = 0;
				SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
			}
			else
			{
				iMaxAmmo = SDK_GetMaxAmmo(iClient, iAmmoType);
			}
			
			SetEntProp(iClient, Prop_Send, "m_iAmmo", iMaxAmmo, _, iAmmoType);
		}
	}
	
	// add weapon pickup to player as cookie
	AddToCookie(iClient, 1, weaponsPicked);
	int WeaponsPicked = GetCookie(iClient, weaponsPicked);
	if (WeaponsPicked <= 1)
	{
		DataPack hPack1 = new DataPack();
		CreateDataTimer(0.5, DisplayTutorialMessage, hPack1);
		hPack1.WriteCell(iClient);
		hPack1.WriteFloat(2.5);
		hPack1.WriteString("You have picked up a weapon.");

		DataPack hPack2 = new DataPack();
		CreateDataTimer(3.0, DisplayTutorialMessage, hPack2);
		hPack2.WriteCell(iClient);
		hPack2.WriteFloat(3.5);
		hPack2.WriteString("Finding weapons is crucial to ensure survival.");
	}

	// trigger ENT_ONPICKUP
	if (g_bTriggerEntity[iTarget])
	{
		AcceptEntityInput(iTarget, ENT_ONPICKUP, iClient, iClient);
		g_bTriggerEntity[iTarget] = false;
	}
	
	eWeaponsRarity nRarity = eWeaponsRarity_Common;
	for (int i = 0; i < sizeof(g_nWeapons); i++)
	{
		if (g_nWeapons[i][iWeaponsIndex] == iIndex)
		{
			nRarity = g_nWeapons[i][nWeaponsRarity];
			break;
		}
	}
	
	Call_StartForward(g_hForwardWeaponPickup);
	Call_PushCell(iClient);
	Call_PushCell(iWeapon);
	Call_PushCell(nRarity);
	Call_Finish();
}

public Action ResetPickup(Handle timer, any iClient)
{
	if (IsValidClient(iClient))
	{
		g_bCanPickup[iClient] = true;
	}
}

stock eWeaponsType GetWeaponType(int iEntity)
{
	char strName[255];
	GetEntPropString(iEntity, Prop_Data, "m_iName", strName, sizeof(strName));

	// strcontains versus strequals on 2048 entities obviously shows strcontains as the winner
	if (StrContains(strName, "szf_weapon_spawn", false) == 0) return eWeaponsType_Spawn; // spawn: dont expire on pickup
	else if (StrContains(strName, "szf_weapon_rare_spawn", false) == 0) return eWeaponsType_RareSpawn; // guaranteed rare and non-expiring
	else if (StrContains(strName, "szf_weapon_rare", false) == 0) return eWeaponsType_Rare; // guaranteed rare
	else if (StrContains(strName, "szf_weapon_static_spawn", false) == 0) return eWeaponsType_StaticSpawn; // static: don't change model and non-expiring
	else if (StrContains(strName, "szf_weapon_static", false) == 0) return eWeaponsType_Static; // static: don't change model
	else if (StrContains(strName, "szf_weapon_nopickup", false) == 0) return eWeaponsType_DefaultNoPickup; // no pickup: this weapon can never become a pickup
	else if (StrContains(strName, "szf_weapon", false) != -1) return eWeaponsType_Default; // normal

	return eWeaponsType_Invalid;
}

stock void SwitchToSlot(int iClient, int iSlot)
{
	if (GetPlayerWeaponSlot(iClient, iSlot) > 0)
	{
		EquipPlayerWeapon(iClient, weapon);
	}
}

stock void SetRandomPickup(int iEntity)
{
	// reset angle
	float flAngles[3];
	flAngles[0] = 0.0;
	flAngles[1] = 0.0;
	flAngles[2] = 0.0;
	// set model
	SetRandomWeapon(iEntity, eWeaponsRarity_Pickup);
	TeleportEntity(iEntity, NULL_VECTOR, flAngles, NULL_VECTOR);
	GetEntityModel(iTarget, strModel, sizeof(strModel));
	// Ammo/Health Pick-ups
	if (StrEqual(strModel, "models/items/ammopack_large.mdl") || StrEqual(strModel, "models/items/medkit_large.mdl"))
	{
		// set color
		SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iEntity, 150, 255, 150, 255);
	}
	// energy-drink Pick-ups
	if (StrEqual(strModel, "models/weapons/c_models/c_energy_drink/c_energy_drink.mdl"))
	{
		// set size
		SetEntPropFloat(iEntity,Prop_Data,"m_flModelScale", 1.5);
	}
}

stock void SetRandomWeapon(int iEntity, eWeaponsRarity nRarity)
{
	int iRandom = GetRandomInt(0, g_aWeaponsRarity[INT(nRarity)].Length - 1);
	int iIndex = g_aWeaponsRarity[INT(nRarity)].Get(iRandom);
	
	for (int i = 0; i < sizeof(g_nWeapons); i++)
	{
		if (g_nWeapons[i][iWeaponsIndex] == iIndex)
		{
			SetWeaponModel(iEntity, g_nWeapons[i][sWeaponsModel]);
			return;
		}
	}
}

stock void SetWeaponModel(int iEntity, char[] strModel)
{
	char strOldModel[256];
	GetEntityModel(iEntity, strOldModel, sizeof(strOldModel));
	
	// Because sniper wearable have a really offplace origin prop, we have to move entity to a more reasonable spot
	
	if (StrEqual(strOldModel, "models/player/items/sniper/knife_shield.mdl")
		|| StrEqual(strOldModel, "models/player/items/sniper/xms_sniper_commandobackpack.mdl") )
	{
		float vecOrigin[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);
		
		float vecAngles[3];
		GetEntPropVector(iEntity, Prop_Send, "m_angRotation", vecAngles);
		
		float vecDirection[3];
		GetAngleVectors(vecAngles, vecDirection, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(vecDirection, 64.0);
		
		vecOrigin[0] += vecDirection[1] * Sine(DegToRad(vecAngles[2]));
		vecOrigin[1] -= vecDirection[0] * Sine(DegToRad(vecAngles[2]));
		vecOrigin[2] += 64.0 * Cosine(DegToRad(vecAngles[2]));
		
		TeleportEntity(iEntity, vecOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	
	SetEntityModel(iEntity, strModel);
	
	if (StrEqual(strModel, "models/player/items/sniper/knife_shield.mdl")
		|| StrEqual(strModel, "models/player/items/sniper/xms_sniper_commandobackpack.mdl") )
	{
		float vecOrigin[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);
		
		float vecAngles[3];
		GetEntPropVector(iEntity, Prop_Send, "m_angRotation", vecAngles);

		float vecDirection[3];
		GetAngleVectors(vecAngles, vecDirection, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(vecDirection, 64.0);

		vecOrigin[0] -= vecDirection[1] * Sine(DegToRad(vecAngles[2]));
		vecOrigin[1] += vecDirection[0] * Sine(DegToRad(vecAngles[2]));
		vecOrigin[2] -= 64.0 * Cosine(DegToRad(vecAngles[2]));

		TeleportEntity(iEntity, vecOrigin, NULL_VECTOR, NULL_VECTOR);
	}
}

// Grabs the entity model by looking in the precache database of the server
stock void GetEntityModel(int iEntity, char[] strModel, int iMaxSize, char[] strPropName = "m_nModelIndex")
{
	int iIndex = GetEntProp(iEntity, Prop_Send, strPropName);
	GetModelPath(iIndex, strModel, iMaxSize);
}

stock void GetModelPath(int iIndex, char[] strModel, int iMaxSize)
{
	int iTable = FindStringTable("modelprecache");
	ReadStringTable(iTable, iIndex, strModel, iMaxSize);
}