typedef Weapon_OnPickup = function bool (int client); //Return false to prevent client from picking up the item.

static ArrayList g_Weapons;
static ArrayList g_WepIndexesByRarity[view_as<int>(eWeaponsRarity)]; //Array indexes of g_Weapons array
static StringMap g_WeaponsReskin;

enum struct Weapon
{
	int iIndex;
	eWeaponsRarity nRarity;
	char sModel[PLATFORM_MAX_PATH];
	char sSound[PLATFORM_MAX_PATH];
	char sText[256];
	char sAttribs[256];
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

bool GetWeaponFromModel(Weapon buffer, char[] model)
{
	int iLength = g_Weapons.Length;
	for (int i = 0; i < iLength; i++) 
	{
		Weapon wep;
		g_Weapons.GetArray(i, wep);
		
		if (StrEqual(model, wep.sModel))
		{
			buffer = wep;
			return true;
		}
	}
	
	return false;
}

void GetWeaponFromIndex(Weapon buffer, int index)
{
	int iLength = g_Weapons.Length;
	for (int i = 0; i < iLength; i++) 
	{
		Weapon wep;
		g_Weapons.GetArray(i, wep);
		
		if (index == wep.iIndex)
		{
			buffer = wep;
			return;
		}
	}
}

ArrayList GetAllWeaponsWithRarity(eWeaponsRarity rarity)
{
	ArrayList aList = new ArrayList(sizeof(Weapon));
	
	int iLength = GetRarityWeaponCount(rarity);
	for (int i = 0; i < iLength; i++)
	{
		Weapon wep;
		g_Weapons.GetArray(g_WepIndexesByRarity[rarity].Get(i), wep);
		
		aList.PushArray(wep);
	}
	
	return aList;
}

int GetRarityWeaponCount(eWeaponsRarity rarity)
{
	return g_WepIndexesByRarity[rarity].Length;
}

int GetReskinIndex(char[] sModel)
{
	int iIndex = -1;
	if (g_WeaponsReskin.GetValue(sModel, iIndex))
		return iIndex;
	
	return -1;
}

void Weapons_ReplaceEntityModel(int ent, int index)
{
	int iLength = g_Weapons.Length;
	for (int i = 0; i < iLength; i++) 
	{
		Weapon wep;
		g_Weapons.GetArray(i, wep);
		
		if (index == wep.iIndex)
		{
			SetWeaponModel(ent, wep);
			return;
		}
	}
}

// -----------------------------------------------------------
public bool Weapons_OnPickup_Health(int client)
{
	if (GetClientHealth(client) < SDK_GetMaxHealth(client))
	{
		SpawnPickup(client, "item_healthkit_full");
		return true;
	}
	
	return false;
}

public bool Weapons_OnPickup_Ammo(int client)
{
	SpawnPickup(client, "item_ammopack_full");
	
	return true;
}

public bool Weapons_OnPickup_Minicrits(int client)
{
	TF2_AddCondition(client,TFCond_Buffed,30.0);
	
	return true;
}

public bool Weapons_OnPickup_Defense(int client)
{
	TF2_AddCondition(client,TFCond_DefenseBuffed,30.0);
	
	return true;
}
