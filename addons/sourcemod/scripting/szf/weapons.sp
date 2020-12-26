#define ENT_ONPICKUP	"FireUser1"
#define ENT_ONKILL		"FireUser2"

typedef Weapon_OnPickup = function bool (int client); //Return false to prevent client from picking up the item.
typedef Weapon_OnSpawn = function void (int entity);

static ArrayList g_Weapons;
static ArrayList g_WepIndexesByRarity[view_as<int>(WeaponRarity)]; //Array indexes of g_Weapons array
static StringMap g_WeaponsReskin;

enum struct Weapon
{
	int iIndex;
	WeaponRarity nRarity;
	char sModel[PLATFORM_MAX_PATH];
	int iSkin;
	char sSound[PLATFORM_MAX_PATH];
	char sAttribs[256];
	ArrayList aClassSpecific[view_as<int>(TFClassType)];
	int iColor[3];
	float flHeightOffset;
	float vecAnglesOffset[3];
	float vecAnglesConst[3];
	bool bAnglesConst[3];
	Weapon_OnPickup pickupCallback;
	Weapon_OnSpawn spawnCallback;
}

void Weapons_Refresh()
{
	if (g_Weapons)
	{
		int iLength = g_Weapons.Length;
		for (int i = 0; i < iLength; i++)
		{
			Weapon wep;
			g_Weapons.GetArray(i, wep);
			
			for (TFClassType iClass; iClass < TFClassType; iClass++)
				delete wep.aClassSpecific[iClass];
		}
		
		delete g_Weapons;
	}
	
	delete g_WeaponsReskin;
	
	for (int i = 0; i < sizeof(g_WepIndexesByRarity); i++)
		delete g_WepIndexesByRarity[i];
	
	g_Weapons = Config_LoadWeaponData();
	g_WeaponsReskin = Config_LoadWeaponReskinData();
	
	int iLength = g_Weapons.Length;
	for (int i = 0; i < view_as<int>(WeaponRarity); i++)
	{
		g_WepIndexesByRarity[i] = new ArrayList();
		
		for (int j = 0; j < iLength; j++)
		{
			Weapon wep;
			g_Weapons.GetArray(j, wep);
			
			if (wep.nRarity == view_as<WeaponRarity>(i))
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

bool GetWeaponFromEntity(Weapon buffer, int iEntity)
{
	char sModel[PLATFORM_MAX_PATH];
	GetEntityModel(iEntity, sModel, sizeof(sModel));
	int iSkin = GetEntProp(iEntity, Prop_Send, "m_nSkin");
	
	int iLength = g_Weapons.Length;
	for (int i = 0; i < iLength; i++) 
	{
		Weapon wep;
		g_Weapons.GetArray(i, wep);
		
		if (StrEqual(sModel, wep.sModel) && iSkin == wep.iSkin)
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

ArrayList GetAllWeaponsWithRarity(WeaponRarity iRarity)
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

int GetRarityWeaponCount(WeaponRarity iRarity)
{
	return g_WepIndexesByRarity[iRarity].Length;
}

int GetReskinIndex(char[] sModel)
{
	int iIndex = -1;
	
	g_WeaponsReskin.GetValue(sModel, iIndex);
	
	return iIndex;
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
public void Weapons_OnSpawn_Health(int iEntity)
{
	int iPickup = SpawnPickup(iEntity, "item_healthkit_full", false);
	
	SetVariantString("!activator");
	AcceptEntityInput(iPickup, "SetParent", iEntity);
	
	SetEntProp(iPickup, Prop_Send, "m_fEffects", EF_NODRAW);
	HookSingleEntityOutput(iPickup, "OnPlayerTouch", Weapons_PickupTouch, true);
}

public void Weapons_OnSpawn_Ammo(int iEntity)
{
	int iPickup = SpawnPickup(iEntity, "item_ammopack_full", false);
	
	SetVariantString("!activator");
	AcceptEntityInput(iPickup, "SetParent", iEntity);
	
	SetEntProp(iPickup, Prop_Send, "m_fEffects", EF_NODRAW);
	HookSingleEntityOutput(iPickup, "OnPlayerTouch", Weapons_PickupTouch, true);
}

public bool Weapons_OnPickup_Deny(int iClient)
{
	return false;
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

public Action Weapons_PickupTouch(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{
	int iParent = GetEntPropEnt(iCaller, Prop_Data, "m_pParent");
	if (iParent != -1)
	{
		AcceptEntityInput(iParent, ENT_ONKILL, iActivator, iActivator);
		RemoveEntity(iParent);
	}

	RemoveEntity(iCaller);
}