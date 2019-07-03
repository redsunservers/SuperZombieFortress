#define CONFIG_WEAPONS "configs/szf/weapons.cfg"

enum struct eConfigMelee
{
	int iIndex;
	int iIndexPrefab;
	int iIndexReplace;
	char sText[256];
	char sAttrib[256];
}

eConfigMelee g_eConfigMeleeDefault;
ArrayList g_aConfigMelee;

public void Config_InitTemplates()
{
	g_aConfigMelee = new ArrayList(sizeof(eConfigMelee));
}

public void Config_LoadTemplates()
{
	KeyValues kv = LoadFile(CONFIG_WEAPONS, "Weapons");
	
	if (kv == null) return;
	
	g_aConfigMelee.Clear();
	
	if (kv.JumpToKey("melee", false))
	{
		//Loop through each melees to add
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char sBuffer[256];
				kv.GetSectionName(sBuffer, sizeof(sBuffer));
				int iIndex = -1;
				
				//If default, store in global default varable instead of ArrayList
				if (StrEqual(sBuffer, "_global_"))
				{
					//We only care about attrib for default
					kv.GetString("attrib", sBuffer, sizeof(sBuffer));
					Format(g_eConfigMeleeDefault.sAttrib, sizeof(g_eConfigMeleeDefault.sAttrib), sBuffer);
				}
				else if (StringToIntEx(sBuffer, iIndex) == 0)
				{
					LogMessage("Invalid index \"%s\" at Weapons config melee secton", sBuffer);
				}
				else
				{
					//Load stuffs in index
					eConfigMelee eMelee;
					
					eMelee.iIndex = iIndex;
					eMelee.iIndexPrefab = kv.GetNum("prefab", -1);
					eMelee.iIndexReplace = kv.GetNum("weapon", -1);
					
					kv.GetString("text", sBuffer, sizeof(sBuffer));
					Format(eMelee.sText, sizeof(eMelee.sText), sBuffer);
					
					kv.GetString("attrib", sBuffer, sizeof(sBuffer));
					Format(eMelee.sAttrib, sizeof(eMelee.sAttrib), sBuffer);
					
					//Push all into arraylist
					g_aConfigMelee.PushArray(eMelee, sizeof(eMelee));
				}
			} 
			while (kv.GotoNextKey(false));
		}
		
		kv.GoBack();
	}
	
	delete kv;
}

public ArrayList Config_LoadWeaponData()
{
	StringMap rarity_map = new StringMap();
	rarity_map.SetValue("common", eWeaponsRarity_Common);
	rarity_map.SetValue("uncommon", eWeaponsRarity_Uncommon);
	rarity_map.SetValue("rare", eWeaponsRarity_Rare);
	rarity_map.SetValue("pickup", eWeaponsRarity_Pickup);
	
	KeyValues kv = LoadFile(CONFIG_WEAPONS, "Weapons");
	ArrayList array = new ArrayList(sizeof(eWeapon));
	int iLength;
	
	if (kv != null)
	{
		if (kv.JumpToKey("general", false))
		{
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					eWeapon wep;
					
					char sBuffer[256];
					kv.GetSectionName(sBuffer, sizeof(sBuffer));
					
					int index = StringToInt(sBuffer);
					
					wep.iIndex = index;
					
					kv.GetString("rarity", sBuffer, sizeof(sBuffer), "common");
					CStrToLower(sBuffer);
					
					rarity_map.GetValue(sBuffer, wep.Rarity);
					
					kv.GetString("model", wep.sModel, sizeof(wep.sModel));
					if (wep.sModel[0] == '\0') 
					{
						LogError("Weapon must have a model.");
						continue;
					}
					
					// Check if the model is already taken by another weapon
					eWeapon duplicate;
					for (int i = 0; i < iLength; i++) 
					{
						array.GetArray(i, duplicate);
						
						if (StrEqual(wep.sModel, duplicate.sModel))
						{
							LogError("%i: Model \"%s\" is already taken by weapon %i.", wep.iIndex, wep.sModel, duplicate.iIndex);
							continue;
						}
					}
					
					kv.GetString("text", wep.sText, sizeof(wep.sText));
					kv.GetString("attrib", wep.sAttribs, sizeof(wep.sAttribs));
					
					kv.GetString("callback", sBuffer, sizeof(sBuffer));
					wep.on_pickup = view_as<eWeapon_OnPickup>(GetFunctionByName(null, sBuffer));
					
					int color[4];
					kv.GetColor4("color", color);
					
					wep.iColor[0] = color[0];
					wep.iColor[1] = color[1];
					wep.iColor[2] = color[2];
					
					float flOffsetOrigin[3];
					float flOffsetAngles[3];
					kv.GetVector("offset_origin", flOffsetOrigin);
					kv.GetVector("offset_angles", flOffsetAngles);
					
					wep.flOffsetOrigin[0] = flOffsetOrigin[0];
					wep.flOffsetOrigin[1] = flOffsetOrigin[1];
					wep.flOffsetOrigin[2] = flOffsetOrigin[2];
					
					wep.flOffsetAngles[0] = flOffsetAngles[0];
					wep.flOffsetAngles[1] = flOffsetAngles[1];
					wep.flOffsetAngles[2] = flOffsetAngles[2];
					
					wep.flModelScale = kv.GetFloat("scale", 1.0);
					
					array.PushArray(wep);
					++iLength;
				} 
				while (kv.GotoNextKey(false));
			}
		}
	}
	
	delete kv;
	delete rarity_map;
	
	return array;
}

public StringMap Config_LoadWeaponReskinData()
{
	KeyValues kv = LoadFile(CONFIG_WEAPONS, "Weapons");
	StringMap stringmap = new StringMap();
	
	if (kv != null)
	{
		if (kv.JumpToKey("reskin", false))
		{
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char sBuffer[256];
					kv.GetSectionName(sBuffer, sizeof(sBuffer));
					int iIndex = StringToInt(sBuffer);
					kv.GetString(NULL_STRING, sBuffer, sizeof(sBuffer), "");
					
					stringmap.SetValue(sBuffer, iIndex);
				}
				while (kv.GotoNextKey(false));
			}
		}
	}
	
	delete kv;
	return stringmap;
}

public KeyValues LoadFile(const char[] sConfigFile, const char [] sConfigSection)
{
	char sConfigPath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), sConfigFile);
	if(!FileExists(sConfigPath))
	{
		LogMessage("Failed to load SZF config file (file missing): %s!", sConfigPath);
		return null;
	}
	
	KeyValues kv = new KeyValues(sConfigSection);
	kv.SetEscapeSequences(true);

	if(!kv.ImportFromFile(sConfigPath))
	{
		LogMessage("Failed to parse SZF config file: %s!", sConfigPath);
		delete kv;
		return null;
	}
	
	return kv;
}