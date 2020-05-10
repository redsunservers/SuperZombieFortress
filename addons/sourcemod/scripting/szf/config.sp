#define CONFIG_WEAPONS       "configs/szf/weapons.cfg"
#define CONFIG_CLASSES       "configs/szf/classes.cfg"
#define CONFIG_RESKINS       "configs/szf/reskins.cfg"

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
StringMap g_mConfigReskins;

void Config_Init()
{
	g_aConfigMelee = new ArrayList(sizeof(ConfigMelee));
}

void Config_Refresh()
{
	KeyValues kv = Config_LoadFile(CONFIG_WEAPONS, "Weapons");
	if (kv == null)
		return;
	
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
	
	g_mConfigReskins = Config_LoadReskins();
}

ArrayList Config_LoadWeaponData()
{
	KeyValues kv = Config_LoadFile(CONFIG_WEAPONS, "Weapons");
	if (kv == null)
		return null;
	
	static StringMap mRarity;
	if (mRarity == null)
	{
		mRarity = new StringMap();
		mRarity.SetValue("common", WeaponRarity_Common);
		mRarity.SetValue("uncommon", WeaponRarity_Uncommon);
		mRarity.SetValue("rare", WeaponRarity_Rare);
		mRarity.SetValue("pickup", WeaponRarity_Pickup);
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

				if (wep.iIndex > -1)
				{
					//Skip weapon if weapon is not for any class enabled
					bool bFound = false;
					for (TFClassType iClass = TFClass_Scout; iClass <= TFClass_Engineer; iClass++)
					{
						if (IsValidSurvivorClass(iClass) && TF2Econ_GetItemSlot(wep.iIndex, iClass) >= 0)
						{
							bFound = true;
							break;
						}
					}
					
					if (!bFound)
						continue;
				}
				
				wep.iSkin = kv.GetNum("skin");
				
				//Check if the model is already taken by another weapon
				Weapon duplicate;
				for (int i = 0; i < iLength; i++) 
				{
					aWeapons.GetArray(i, duplicate);
					
					if (StrEqual(wep.sModel, duplicate.sModel) && wep.iSkin == duplicate.iSkin)
					{
						LogError("%i: Model \"%s\" with skin \"%d\" is already taken by weapon %i.", wep.iIndex, wep.sModel, wep.iSkin, duplicate.iIndex);
						continue;
					}
				}
				
				kv.GetString("text", wep.sText, sizeof(wep.sText));
				kv.GetString("attrib", wep.sAttribs, sizeof(wep.sAttribs));
				kv.GetString("sound", wep.sSound, sizeof(wep.sSound));
				
				//Exceptions for specific classes
				char sClassName[16];
				if (kv.GotoFirstSubKey(false))
				{
					do
					{
						kv.GetSectionName(sClassName, sizeof(sClassName));
						
						TFClassType iClass = TF2_GetClass(sClassName);
						
						char sClassAttribs[256];
						kv.GetString("attrib", sClassAttribs, sizeof(sClassAttribs));
						
						wep.aClassSpecific[iClass] = new ArrayList(256);
						wep.aClassSpecific[iClass].PushString(sClassAttribs);
						
					}
					while(kv.GotoNextKey(false));
					kv.GoBack();
				}
				
				
				kv.GetString("callback", sBuffer, sizeof(sBuffer));
				wep.callback = view_as<Weapon_OnPickup>(GetFunctionByName(null, sBuffer));
				
				int iColor[4];
				kv.GetColor4("color", iColor);
				
				wep.iColor[0] = iColor[0];
				wep.iColor[1] = iColor[1];
				wep.iColor[2] = iColor[2];
				
				wep.flHeightOffset = kv.GetFloat("height_offset");
				kv.GetVector("angles_offset", wep.vecAnglesOffset);
				
				char sAnglesOffset[3][12];
				kv.GetString("angles_const", sBuffer, sizeof(sBuffer));
				int iCount = ExplodeString(sBuffer, " ", sAnglesOffset, sizeof(sAnglesOffset), sizeof(sAnglesOffset[]));
				if (iCount == 3)
				{
					for (int i = 0; i < 3; i++)
					{
						if (sAnglesOffset[i][0] != '~')
						{
							wep.vecAnglesConst[i] = StringToFloat(sAnglesOffset[i]);
							wep.bAnglesConst[i] = true;
						}
					}
				}
				
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
	KeyValues kv = Config_LoadFile(CONFIG_WEAPONS, "Weapons");
	if (kv == null)
		return null;
	
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
	KeyValues kv = Config_LoadFile(CONFIG_CLASSES, "Classes");
	if (kv == null)
		return null;
	
	ArrayList aClasses = new ArrayList(sizeof(SurvivorClasses));
	int iLength = 0;
	
	if (kv.JumpToKey("survivors", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				SurvivorClasses sur;
				
				char sBuffer[256];
				kv.GetSectionName(sBuffer, sizeof(sBuffer));
				
				sur.iClass = TF2_GetClass(sBuffer);
				if (sur.iClass == TFClass_Unknown)
					LogError("Invalid survivor class '%s'.", sBuffer);
				
				//Check if the class is already defined
				SurvivorClasses duplicate;
				for (int i = 0; i < iLength; i++) 
				{
					aClasses.GetArray(i, duplicate);
					
					if (sur.iClass == duplicate.iClass)
					{
						LogError("Survivor class '%s' is already defined.", sur.iClass);
						break;
					}
				}
				
				sur.bEnabled = view_as<bool>(kv.GetNum("enable", 1));
				sur.flSpeed = kv.GetFloat("speed", TF2_GetClassSpeed(sur.iClass));
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
	KeyValues kv = Config_LoadFile(CONFIG_CLASSES, "Classes");
	if (kv == null)
		return null;
	
	ArrayList aClasses = new ArrayList(sizeof(ZombieClasses));
	int iLength = 0;
	
	if (kv.JumpToKey("zombies", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				ZombieClasses zom;
				
				char sBuffer[256];
				kv.GetSectionName(sBuffer, sizeof(sBuffer));
				
				zom.iClass = TF2_GetClass(sBuffer);
				if (zom.iClass == TFClass_Unknown)
					LogError("Invalid zombie class '%s'.", sBuffer);
				
				//Check if the class is already defined
				ZombieClasses duplicate;
				for (int i = 0; i < iLength; i++) 
				{
					aClasses.GetArray(i, duplicate);
					
					if (zom.iClass == duplicate.iClass)
					{
						LogError("Zombie class '%s' is already defined.", zom.iClass);
						break;
					}
				}
				
				zom.bEnabled = view_as<bool>(kv.GetNum("enable", 1));
				zom.iHealth = kv.GetNum("health", 0);
				zom.flSpeed = kv.GetFloat("speed", TF2_GetClassSpeed(zom.iClass));
				zom.iRegen = kv.GetNum("regen", 2);
				zom.iDegen = kv.GetNum("degen", 3);
				zom.flSpree = kv.GetFloat("spree", 1.0);
				zom.flHorde = kv.GetFloat("horde", 2.0);
				zom.flMaxSpree = kv.GetFloat("maxspree", 20.0);
				zom.flMaxHorde = kv.GetFloat("maxhorde", 20.0);
				zom.aWeapons = Config_GetWeaponClasses(kv);
				
				aClasses.PushArray(zom);
				iLength++;
			} 
			while (kv.GotoNextKey(false));
		}
	}
	
	delete kv;
	return aClasses;
}

ArrayList Config_LoadInfectedClasses()
{
	KeyValues kv = Config_LoadFile(CONFIG_CLASSES, "Classes");
	if (kv == null)
		return null;
	
	ArrayList aClasses = new ArrayList(sizeof(InfectedClasses));
	int iLength = 0;
	
	if (kv.JumpToKey("infected", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				InfectedClasses inf;
				
				char sBuffer[256], sBuffer2[32];
				kv.GetSectionName(sBuffer, sizeof(sBuffer));
				
				for (int i = 0; i < view_as<int>(Infected); i++)
				{
					GetInfectedName(sBuffer2, sizeof(sBuffer2), i);
					if (StrEqual(sBuffer2, sBuffer, false))
					{
						inf.nInfected = view_as<Infected>(i);
						break;
					}
					else if (i == view_as<int>(Infected)-1)
					{
						inf.nInfected = Infected_None;
						LogError("Invalid special infected '%s'.", sBuffer);
					}
				}
				
				//Check if special infected is already defined
				InfectedClasses duplicate;
				for (int i = 0; i < iLength; i++) 
				{
					aClasses.GetArray(i, duplicate);
					
					if (inf.nInfected == duplicate.nInfected)
					{
						LogError("Special infected '%s' is already defined.", inf.nInfected);
						break;
					}
				}
				
				if (inf.nInfected != Infected_None)
				{
					kv.GetString("class", sBuffer2, sizeof(sBuffer2));
					inf.iInfectedClass = TF2_GetClass(sBuffer2);
					if (inf.iInfectedClass == TFClass_Unknown)
					{
						LogError("Invalid special infected class '%s'.", sBuffer);
						inf.iInfectedClass = TFClass_Heavy;
					}
				}
				
				inf.bEnabled = !!kv.GetNum("enable", true);
				inf.iHealth = kv.GetNum("health", 0);
				inf.flSpeed = kv.GetFloat("speed", 0.0);
				inf.bGlow = !!kv.GetNum("glow", false);
				inf.iRegen = kv.GetNum("regen", 2);
				inf.iDegen = kv.GetNum("degen", 3);
				
				kv.GetString("color", sBuffer, sizeof(sBuffer));
				if (sBuffer[0])
					kv.GetColor4("color", inf.iColor);
				else
					inf.iColor = { 255, 255, 255, 255 };
				
				kv.GetString("message", inf.sMessage, sizeof(inf.sMessage));
				kv.GetString("model", inf.sModel, sizeof(inf.sModel));
				kv.GetString("sound_spawn", inf.sSoundSpawn, sizeof(inf.sSoundSpawn));
				inf.iRageCooldown = kv.GetNum("ragecooldown", 0);
				inf.callback_spawn = Config_GetFunction(kv, "callback_spawn");
				inf.callback_rage = Config_GetFunction(kv, "callback_rage");
				inf.callback_think = Config_GetFunction(kv, "callback_think");
				inf.callback_anim = Config_GetFunction(kv, "callback_anim");
				inf.callback_death = Config_GetFunction(kv, "callback_death");
				inf.aWeapons = Config_GetWeaponClasses(kv);
				
				aClasses.PushArray(inf);
				iLength++;
			} 
			while (kv.GotoNextKey(false));
		}
	}
	
	delete kv;
	return aClasses;
}

ArrayList Config_GetWeaponClasses(KeyValues kv)
{
	ArrayList aWeapons = new ArrayList(sizeof(WeaponClasses));
	
	if (kv.GotoFirstSubKey(false))	//Find weapons
	{
		do
		{
			char sSubkey[256];
			kv.GetSectionName(sSubkey, sizeof(sSubkey));
			if (StrEqual(sSubkey, "weapon"))
			{
				WeaponClasses weapon;
				weapon.iIndex = kv.GetNum("index", 5);
				kv.GetString("classname", weapon.sClassname, sizeof(weapon.sClassname));
				kv.GetString("attrib", weapon.sAttribs, sizeof(weapon.sAttribs));
				weapon.iWeaponId = kv.GetNum("index");
				kv.GetString("logname", weapon.sLogName, sizeof(weapon.sLogName));
				kv.GetString("iconname", weapon.sIconName, sizeof(weapon.sIconName));
				
				aWeapons.PushArray(weapon);
			}
		}
		while(kv.GotoNextKey(false));
		kv.GoBack();
	}
	
	return aWeapons;
}

StringMap Config_LoadReskins()
{
	KeyValues kv = Config_LoadFile(CONFIG_RESKINS, "Reskins");
	if (kv == null)
		return null;
	
	StringMap mReskins = new StringMap();
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char sName[256];
			kv.GetSectionName(sName, sizeof(sName));
			int iOrigIndex = StringToInt(sName);
			
			char sValue[512];
			kv.GetString(NULL_STRING, sValue, sizeof(sValue));
			
			char sValueExploded[64][8];
			int iCount = ExplodeString(sValue, " ", sValueExploded, sizeof(sValueExploded), sizeof(sValueExploded[]));
			
			for (int i = 0; i < iCount; i++)
				mReskins.SetValue(sValueExploded[i], iOrigIndex);
		}
		while (kv.GotoNextKey(false));
	}
	
	delete kv;
	return mReskins;
}

KeyValues Config_LoadFile(const char[] sConfigFile, const char [] sConfigSection)
{
	char sConfigPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), sConfigFile);
	if (!FileExists(sConfigPath))
	{
		LogMessage("Failed to load SZF config file (file missing): %s!", sConfigPath);
		return null;
	}
	
	KeyValues kv = new KeyValues(sConfigSection);
	kv.SetEscapeSequences(true);
	
	if (!kv.ImportFromFile(sConfigPath))
	{
		LogMessage("Failed to parse SZF config file: %s!", sConfigPath);
		delete kv;
		return null;
	}
	
	return kv;
}

Function Config_GetFunction(KeyValues kv, const char[] sKey)
{
	char sBuffer[64];
	kv.GetString(sKey, sBuffer, sizeof(sBuffer));
	if (!sBuffer[0])
		return INVALID_FUNCTION;
	
	Function func = GetFunctionByName(null, sBuffer);
	if (func == INVALID_FUNCTION)
		LogError("Unable to find function '%s' in config", sBuffer);
	
	return func;
}