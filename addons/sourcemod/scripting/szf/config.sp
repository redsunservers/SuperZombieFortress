#define CONFIG_WEAPONS "configs/szf/weapons.cfg"
#define CONFIG_CLASSES "configs/szf/classes.cfg"

enum struct ConfigMelee
{
	int iIndex;
	int iIndexPrefab;
	int iIndexReplace;
	char sText[256];
	char sAttrib[256];
}

ConfigMelee g_ConfigMeleeDefault;
ArrayList g_aConfigMelee;

void Config_InitTemplates()
{
	g_aConfigMelee = new ArrayList(sizeof(ConfigMelee));
}

void Config_LoadTemplates()
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
					Format(g_ConfigMeleeDefault.sAttrib, sizeof(g_ConfigMeleeDefault.sAttrib), sBuffer);
				}
				else if (StringToIntEx(sBuffer, iIndex) == 0)
				{
					LogMessage("Invalid index \"%s\" at Weapons config melee secton", sBuffer);
				}
				else
				{
					//Load stuffs in index
					ConfigMelee Melee;
					
					Melee.iIndex = iIndex;
					Melee.iIndexPrefab = kv.GetNum("prefab", -1);
					Melee.iIndexReplace = kv.GetNum("weapon", -1);
					
					kv.GetString("text", sBuffer, sizeof(sBuffer));
					Format(Melee.sText, sizeof(Melee.sText), sBuffer);
					
					kv.GetString("attrib", sBuffer, sizeof(sBuffer));
					Format(Melee.sAttrib, sizeof(Melee.sAttrib), sBuffer);
					
					//Push all into arraylist
					g_aConfigMelee.PushArray(Melee);
				}
			} 
			while (kv.GotoNextKey(false));
		}
		
		kv.GoBack();
	}
	
	delete kv;
}

ArrayList Config_LoadWeaponData()
{
	KeyValues kv = LoadFile(CONFIG_WEAPONS, "Weapons");
	if (kv == null) return null;
	
	static StringMap mRarity;
	if (mRarity == null)
	{
		mRarity = new StringMap();
		mRarity.SetValue("common", eWeaponsRarity_Common);
		mRarity.SetValue("uncommon", eWeaponsRarity_Uncommon);
		mRarity.SetValue("rare", eWeaponsRarity_Rare);
		mRarity.SetValue("pickup", eWeaponsRarity_Pickup);
	}
	
	ArrayList aWeapons = new ArrayList(sizeof(Weapon));
	int iLength = 0;
	
	if (kv.JumpToKey("general", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				Weapon wep;
				
				char sBuffer[256];
				kv.GetSectionName(sBuffer, sizeof(sBuffer));
				
				wep.iIndex = StringToInt(sBuffer);
				
				kv.GetString("rarity", sBuffer, sizeof(sBuffer), "common");
				CStrToLower(sBuffer);
				
				mRarity.GetValue(sBuffer, wep.nRarity);
				
				kv.GetString("model", wep.sModel, sizeof(wep.sModel));
				if (wep.sModel[0] == '\0') 
				{
					LogError("Weapon must have a model.");
					continue;
				}

				//Skip weapon if their class isn't enabled
				if (kv.GetNum("class") > 0 && kv.GetNum("class") < 10 && !IsValidSurvivorClass(view_as<TFClassType>(kv.GetNum("class"))))
					continue;
				
				//Check if the model is already taken by another weapon
				Weapon duplicate;
				for (int i = 0; i < iLength; i++) 
				{
					aWeapons.GetArray(i, duplicate);
					
					if (StrEqual(wep.sModel, duplicate.sModel))
					{
						LogError("%i: Model \"%s\" is already taken by weapon %i.", wep.iIndex, wep.sModel, duplicate.iIndex);
						continue;
					}
				}
				
				kv.GetString("text", wep.sText, sizeof(wep.sText));
				kv.GetString("attrib", wep.sAttribs, sizeof(wep.sAttribs));
				kv.GetString("sound", wep.sSound, sizeof(wep.sSound));
				
				kv.GetString("callback", sBuffer, sizeof(sBuffer));
				wep.callback = view_as<Weapon_OnPickup>(GetFunctionByName(null, sBuffer));
				
				int iColor[4];
				kv.GetColor4("color", iColor);
				
				wep.iColor[0] = iColor[0];
				wep.iColor[1] = iColor[1];
				wep.iColor[2] = iColor[2];
				
				kv.GetVector("offset_origin", wep.vecOrigin);
				kv.GetVector("offset_angles", wep.vecAngles);
				
				aWeapons.PushArray(wep);
				iLength++;
			} 
			while (kv.GotoNextKey(false));
		}
	}
	
	delete kv;
	return aWeapons;
}

StringMap Config_LoadWeaponReskinData()
{
	KeyValues kv = LoadFile(CONFIG_WEAPONS, "Weapons");
	if (kv == null) return null;
	
	StringMap mReskin = new StringMap();
	
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
				
				mReskin.SetValue(sBuffer, iIndex);
			}
			while (kv.GotoNextKey(false));
		}
	}
	
	delete kv;
	return mReskin;
}

ArrayList Config_LoadSurvivorClasses()
{
	KeyValues kv = LoadFile(CONFIG_CLASSES, "Classes");
	if (kv == null) return null;
	
	ArrayList aClasses = new ArrayList(sizeof(SurvivorClasses));
	int iLength = 0;
	
	if (kv.JumpToKey("survivors", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				SurvivorClasses sur;
				
				char sBuffer2[32], sBuffer[256];
				kv.GetSectionName(sBuffer, sizeof(sBuffer));
				
				for (int i = 0; i < view_as<int>(TFClassType); i++)
				{
					TF2_GetClassFile(sBuffer2, sizeof(sBuffer2), i);
					if (StrEqual(sBuffer2, sBuffer))
					{
						sur.nClass = view_as<TFClassType>(i);
						break;
					}
					else if (i == view_as<int>(TFClassType)-1)
					{
						sur.nClass = TFClass_Unknown;
						LogError("Invalid survivor class '%s'.", sBuffer);
					}
				}
				
				//Check if the class is already defined
				SurvivorClasses duplicate;
				for (int i = 0; i < iLength; i++) 
				{
					aClasses.GetArray(i, duplicate);
					
					if (sur.nClass == duplicate.nClass)
					{
						LogError("Survivor class '%s' is already defined.", sur.nClass);
						break;
					}
				}
				
				sur.bEnabled = view_as<bool>(kv.GetNum("enable", 1));
				sur.flSpeed = kv.GetFloat("speed", float(TF2_GetClassSpeed(sur.nClass)));
				sur.iRegen = kv.GetNum("regen", 2);
				sur.iAmmo = kv.GetNum("ammo");
				
				aClasses.PushArray(sur);
				iLength++;
			} 
			while (kv.GotoNextKey(false));
		}
	}
	
	delete kv;
	return aClasses;
}

ArrayList Config_LoadZombieClasses()
{
	KeyValues kv = LoadFile(CONFIG_CLASSES, "Classes");
	if (kv == null) return null;
	
	ArrayList aClasses = new ArrayList(sizeof(ZombieClasses));
	int iLength = 0;
	
	if (kv.JumpToKey("zombies", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				ZombieClasses zom;
				
				char sBuffer2[32], sBuffer[256];
				kv.GetSectionName(sBuffer, sizeof(sBuffer));
				
				for (int i = 0; i < view_as<int>(TFClassType); i++)
				{
					TF2_GetClassFile(sBuffer2, sizeof(sBuffer2), i);
					if (StrEqual(sBuffer2, sBuffer))
					{
						zom.nClass = view_as<TFClassType>(i);
						break;
					}
					else if (i == view_as<int>(TFClassType)-1)
					{
						zom.nClass = TFClass_Unknown;
						LogError("Invalid zombie class '%s'.", sBuffer);
					}
				}
				
				//Check if the class is already defined
				ZombieClasses duplicate;
				for (int i = 0; i < iLength; i++) 
				{
					aClasses.GetArray(i, duplicate);
					
					if (zom.nClass == duplicate.nClass)
					{
						LogError("Zombie class '%s' is already defined.", zom.nClass);
						break;
					}
				}
				
				zom.bEnabled = view_as<bool>(kv.GetNum("enable", 1));
				zom.flSpeed = kv.GetFloat("speed", float(TF2_GetClassSpeed(zom.nClass)));
				zom.iRegen = kv.GetNum("regen", 2);
				zom.iDegen = kv.GetNum("degen", 3);
				zom.iIndex = kv.GetNum("index");
				kv.GetString("attrib", zom.sAttribs, sizeof(zom.sAttribs));
				
				aClasses.PushArray(zom);
				iLength++;
			} 
			while (kv.GotoNextKey(false));
		}
	}
	
	delete kv;
	return aClasses;
}

KeyValues LoadFile(const char[] sConfigFile, const char [] sConfigSection)
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
