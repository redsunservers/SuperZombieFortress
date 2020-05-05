typedef Weapon_OnPickup = function bool (int client); //Return false to prevent client from picking up the item.

static ArrayList g_Weapons;
static ArrayList g_WepIndexesByRarity[view_as<int>(eWeaponsRarity)]; //Array indexes of g_Weapons array
static StringMap g_WeaponsReskin;

enum struct WeaponClassSpecific
{
	char sScoutAttribs[256];
	char sSoldierAttribs[256];
	char sPyroAttribs[256];
	char sDemomanAttribs[256];
	char sHeavyAttribs[256];
	char sEngineerAttribs[256];
	char sMedicAttribs[256];
	char sSniperAttribs[256];
	char sSpyAttribs[256];
}

enum struct Weapon
{
	int iIndex;
	eWeaponsRarity nRarity;
	char sModel[PLATFORM_MAX_PATH];
	char sSound[PLATFORM_MAX_PATH];
	char sText[256];
	char sAttribs[256];
	WeaponClassSpecific weaponClassSpecific;
	int iColor[3];
	float vecOrigin[3];
	float vecAngles[3];
	Weapon_OnPickup callback;
}

void Weapons_Refresh()
{
	delete g_Weapons;
	delete g_WeaponsReskin;
	
	g_Weapons = Config_LoadWeaponData();
	g_WeaponsReskin = Config_LoadWeaponReskinData();
	
	int iLength = g_Weapons.Length;
	for (int i = 0; i < view_as<int>(eWeaponsRarity); i++)
	{
		g_WepIndexesByRarity[i] = new ArrayList();
		
		for (int j = 0; j < iLength; j++)
		{
			Weapon wep;
			g_Weapons.GetArray(j, wep);
			
			if (wep.nRarity == view_as<eWeaponsRarity>(i))
				g_WepIndexesByRarity[i].Push(j);
		}
	}
	
	Weapons_Precache();
}

void Weapons_Precache()
{
	int iLength = g_Weapons.Length;
	for (int i = 0; i < iLength; i++)
	{
		Weapon wep;
		g_Weapons.GetArray(i, wep);
		
		PrecacheModel(wep.sModel);
		
		if (wep.sSound[0] != '\0')
			PrecacheSound(wep.sSound);
	}
	
	PrecacheSound("ui/item_heavy_gun_pickup.wav");
	PrecacheSound("ui/item_heavy_gun_drop.wav");
}

bool GetWeaponFromModel(Weapon buffer, char[] sModel)
{
	int iLength = g_Weapons.Length;
	for (int i = 0; i < iLength; i++) 
	{
		Weapon wep;
		g_Weapons.GetArray(i, wep);
		
		if (StrEqual(sModel, wep.sModel))
		{
			buffer = wep;
			return true;
		}
	}
	
	return false;
}

void GetWeaponFromIndex(Weapon buffer, int iIndex)
{
	int iLength = g_Weapons.Length;
	for (int i = 0; i < iLength; i++) 
	{
		Weapon wep;
		g_Weapons.GetArray(i, wep);
		
		if (iIndex == wep.iIndex)
		{
			buffer = wep;
			return;
		}
	}
}

ArrayList GetAllWeaponsWithRarity(eWeaponsRarity iRarity)
{
	ArrayList aList = new ArrayList(sizeof(Weapon));
	
	int iLength = GetRarityWeaponCount(iRarity);
	for (int i = 0; i < iLength; i++)
	{
		Weapon wep;
		g_Weapons.GetArray(g_WepIndexesByRarity[iRarity].Get(i), wep);
		
		aList.PushArray(wep);
	}
	
	return aList;
}

int GetRarityWeaponCount(eWeaponsRarity iRarity)
{
	return g_WepIndexesByRarity[iRarity].Length;
}

int GetReskinIndex(char[] sModel)
{
	int iIndex = -1;
	if (g_WeaponsReskin.GetValue(sModel, iIndex))
		return iIndex;
	
	return -1;
}

void Weapons_ReplaceEntityModel(int iEnt, int iIndex)
{
	int iLength = g_Weapons.Length;
	for (int i = 0; i < iLength; i++) 
	{
		Weapon wep;
		g_Weapons.GetArray(i, wep);
		
		if (iIndex == wep.iIndex)
		{
			SetWeaponModel(iEnt, wep);
			return;
		}
	}
}

// -----------------------------------------------------------
public bool Weapons_OnPickup_Health(int iClient)
{
	if (GetClientHealth(iClient) < SDKCall_GetMaxHealth(iClient))
	{
		SpawnPickup(iClient, "item_healthkit_full");
		return true;
	}
	
	return false;
}

public bool Weapons_OnPickup_Ammo(int iClient)
{
	SpawnPickup(iClient, "item_ammopack_full");
	
	return true;
}

public bool Weapons_OnPickup_Minicrits(int iClient)
{
	TF2_AddCondition(iClient, TFCond_Buffed, 30.0);
	
	return true;
}

public bool Weapons_OnPickup_Defense(int iClient)
{
	TF2_AddCondition(iClient, TFCond_DefenseBuffed, 30.0);
	
	return true;
}
