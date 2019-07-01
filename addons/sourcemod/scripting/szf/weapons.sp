enum eWeaponsReskin
{
	iWeaponsReskinIndex,
	String:sWeaponsReskinModel[256],
}

//Static weapon models in map to replace what we actually wanted
int g_nWeaponsReskin[][eWeaponsReskin] =
{
	{18, "models/weapons/w_models/w_rocketlauncher.mdl"},
	{18, "models/weapons/c_models/c_bet_rocketlauncher/c_bet_rocketlauncher.mdl"},
	{29, "models/weapons/w_models/w_medigun.mdl"},
};

// -----------------------------------------------------------
typedef eWeapon_OnPickup = function bool (int client); // Return true if the pickup should be destroyed

static ArrayList Weapons;
static ArrayList WepIndexesByRarity[eWeaponsRarity]; // Array indexes of Weapons array

enum struct eWeapon
{
	int iIndex;
	eWeaponsRarity Rarity;
	char sModel[PLATFORM_MAX_PATH];
	char sName[128];
	char sText[256];
	char sAttribs[256];
	int color[3];
	eWeapon_OnPickup on_pickup;
}

void Weapons_Init()
{
	Weapons = Config_LoadWeaponData();
	
	int len = Weapons.Length;
	for (int i = 0; i < INT(eWeaponsRarity); i++)
	{
		WepIndexesByRarity[i] = new ArrayList();
		
		for (int j = 0; j < len; j++)
		{
			eWeapon wep;
			Weapons.GetArray(j, wep);
			
			if (wep.Rarity == view_as<eWeaponsRarity>(i))
			{
				WepIndexesByRarity[i].Push(j);
			}
		}
	}
}

void Weapons_Precache()
{
	SoundPrecache();
	
	int len = Weapons.Length;
	for (int i = 0; i < len; i++)
	{
		eWeapon wep;
		Weapons.GetArray(i, wep);
		
		PrecacheModel(wep.sModel);
	}
	
	PrecacheSound("ui/item_heavy_gun_pickup.wav");
	PrecacheSound("ui/item_heavy_gun_drop.wav");
}

void GetWeaponFromModel(eWeapon buffer, char[] model)
{
	int len = Weapons.Length;
	for (int i = 0; i < len; i++) 
	{
		eWeapon wep;
		Weapons.GetArray(i, wep);
		
		if (StrEqual(model, wep.sModel))
		{
			buffer = wep;
			return;
		}
	}
}

void GetWeaponFromIndex(eWeapon buffer, int index)
{
	int len = Weapons.Length;
	for (int i = 0; i < len; i++) 
	{
		eWeapon wep;
		Weapons.GetArray(i, wep);
		
		if (index == wep.iIndex)
		{
			buffer = wep;
			return;
		}
	}
}

ArrayList GetAllWeaponsWithRarity(eWeaponsRarity rarity)
{
	ArrayList array = new ArrayList(sizeof(eWeapon));
	
	for (int i = 0; i < GetRarityWeaponCount(rarity); i++)
	{
		eWeapon wep;
		Weapons.GetArray(WepIndexesByRarity[rarity].Get(i), wep);
		
		array.PushArray(wep);
	}
	
	return array;
}

int GetRarityWeaponCount(eWeaponsRarity rarity)
{
	return WepIndexesByRarity[rarity].Length;
}

void Weapons_ReplaceEntityModel(int ent, int index)
{
	int len = Weapons.Length;
	for (int i = 0; i < len; i++) 
	{
		eWeapon wep;
		Weapons.GetArray(i, wep);
		
		if (index == wep.iIndex)
		{
			SetWeaponModel(ent, wep.sModel);
			return;
		}
	}
}

// -----------------------------------------------------------
public bool Weapons_OnPickup_Health(int client)
{
	SpawnPickup(client, "item_healthkit_full");
	EmitSoundToClient(client, "ui/item_heavy_gun_pickup.wav");
	
	return true;
}

public bool Weapons_OnPickup_Ammo(int client)
{
	SpawnPickup(client, "item_ammopack_full");
	EmitSoundToClient(client, "ui/item_heavy_gun_pickup.wav");
	
	return true;
}