#define CONFIG_WEAPONS       "configs/szf/weapons.cfg"
#define CONFIG_RESKINS       "configs/szf/reskins.cfg"
#define CONFIG_DEBRIS        "configs/szf/debris.cfg"

enum struct ConfigMelee
{
	int iIndex;
	int iIndexPrefab;
	int iIndexReplace;
	char sText[256];
	char sAttrib[256];
}

enum struct Debris
{
	char sModel[PLATFORM_MAX_PATH];
	float flScale;
	float vecOffset[3];
	float vecAngle[3];
	char sIconName[64];
	float flChance;
}

static ArrayList g_aConfigMelee;
static StringMap g_mConfigReskins;
static ArrayList g_aConfigDebris;

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
				
				if (StringToIntEx(sBuffer, iIndex) == 0)
				{
					LogError("Invalid index \"%s\" at Weapons config melee secton", sBuffer);
				}
				else
				{
					//Load stuffs in index
					ConfigMelee Melee;
					
					Melee.iIndex = iIndex;
					Melee.iIndexPrefab = kv.GetNum("prefab", -1);
					Melee.iIndexReplace = kv.GetNum("weapon", -1);
					kv.GetString("text", Melee.sText, sizeof(Melee.sText));
					kv.GetString("attrib", Melee.sAttrib, sizeof(Melee.sAttrib));
					
					//Push all into arraylist
					g_aConfigMelee.PushArray(Melee);
				}
			} 
			while (kv.GotoNextKey(false));
		}
		
		kv.GoBack();
	}
	
	delete kv;
	
	delete g_mConfigReskins;
	g_mConfigReskins = Config_LoadReskins();
	
	delete g_aConfigDebris;
	g_aConfigDebris = Config_LoadDebris();
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
		mRarity.SetValue("static", WeaponRarity_Static);
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
				StrToLower(sBuffer, sBuffer, sizeof(sBuffer));
				
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
						if (IsValidSurvivorClass(iClass) && TF2Econ_GetItemLoadoutSlot(wep.iIndex, iClass) >= 0)
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
				
				kv.GetString("callback_pickup", sBuffer, sizeof(sBuffer));
				wep.pickupCallback = GetFunctionByName(null, sBuffer);
				
				kv.GetString("callback_spawn", sBuffer, sizeof(sBuffer));
				wep.spawnCallback = GetFunctionByName(null, sBuffer);
				
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

bool Config_LoadClassesSection(KeyValues kv, ClientClasses classes)
{
	//Survivor, Zombie and Infected
	classes.bEnabled = !!kv.GetNum("enable", classes.bEnabled);
	classes.iRegen = kv.GetNum("regen", classes.iRegen);
	
	//Survivor
	classes.iAmmo = kv.GetNum("ammo", classes.iAmmo);
	
	//Zombie and Infected
	classes.iHealth = kv.GetNum("health", classes.iHealth);
	classes.iDegen = kv.GetNum("degen", classes.iDegen);
	classes.aWeapons = Config_GetWeaponClasses(kv);
	classes.flSpree = kv.GetFloat("spree", classes.flSpree);
	classes.flHorde = kv.GetFloat("horde", classes.flHorde);
	classes.flMaxSpree = kv.GetFloat("maxspree", classes.flMaxSpree);
	classes.flMaxHorde = kv.GetFloat("maxhorde", classes.flMaxHorde);
	classes.bGlow = !!kv.GetNum("glow", classes.bGlow);
	classes.bThirdperson = !!kv.GetNum("thirdperson", classes.bThirdperson);
	
	//GetColor4 dont have default buffer to set
	char sBuffer[1];
	kv.GetString("color", sBuffer, sizeof(sBuffer));
	if (sBuffer[0])
		kv.GetColor4("color", classes.iColor);
	
	kv.GetString("message", classes.sMessage, sizeof(classes.sMessage), classes.sMessage);
	kv.GetString("menu", classes.sMenu, sizeof(classes.sMenu));
	kv.GetString("worldmodel", classes.sWorldModel, sizeof(classes.sWorldModel), classes.sWorldModel);
	kv.GetString("viewmodel", classes.sViewModel, sizeof(classes.sViewModel), classes.sViewModel);
	classes.bViewModelAnim = !!kv.GetNum("viewmodel_anim", classes.bViewModelAnim);
	kv.GetString("sound_spawn", classes.sSoundSpawn, sizeof(classes.sSoundSpawn), classes.sSoundSpawn);
	classes.iRageCooldown = kv.GetNum("ragecooldown", classes.iRageCooldown);
	classes.callback_spawn = Config_GetFunction(kv, "callback_spawn", classes.callback_spawn);
	classes.callback_rage = Config_GetFunction(kv, "callback_rage", classes.callback_rage);
	classes.callback_think = Config_GetFunction(kv, "callback_think", classes.callback_think);
	classes.callback_touch = Config_GetFunction(kv, "callback_touch", classes.callback_touch);
	classes.callback_death = Config_GetFunction(kv, "callback_death", classes.callback_death);
	
	return true;
}

Function Config_GetFunction(KeyValues kv, const char[] sKey, Function defaultFunction)
{
	char sBuffer[64];
	kv.GetString(sKey, sBuffer, sizeof(sBuffer));
	if (!sBuffer[0])
		return defaultFunction;
	
	Function func = GetFunctionByName(null, sBuffer);
	if (func == INVALID_FUNCTION)
		LogError("Unable to find function '%s' in config", sBuffer);
	
	return func;
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
				kv.GetString("attrib", weapon.sAttribs, sizeof(weapon.sAttribs));
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

ArrayList Config_LoadDebris()
{
	KeyValues kv = Config_LoadFile(CONFIG_DEBRIS, "Debris");
	if (kv == null)
		return null;
	
	ArrayList aDebris = new ArrayList(sizeof(Debris));
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			Debris debris;
			kv.GetSectionName(debris.sModel, sizeof(debris.sModel));
			debris.flScale = kv.GetFloat("scale", 1.0);
			kv.GetVector("offset", debris.vecOffset);
			kv.GetVector("angle", debris.vecAngle);
			kv.GetString("iconname", debris.sIconName, sizeof(debris.sIconName));
			debris.flChance = kv.GetFloat("chance", 1.0);
			
			aDebris.PushArray(debris);
			PrecacheModel(debris.sModel);
		}
		while (kv.GotoNextKey(false));
	}
	
	delete kv;
	return aDebris;
}


StringMap Config_LoadMusic(KeyValues kv)
{
	StringMap mMusics = new StringMap();
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			SoundMusic music;
			kv.GetSectionName(music.sName, sizeof(music.sName));
			StrToLower(music.sName, music.sName, sizeof(music.sName));
			
			//Check if name already exists
			if (mMusics.GetArray(music.sName, music, sizeof(music)))
			{
				LogError("Duplicate config music \"%s\" found", music.sName);
				continue;
			}
			
			if (kv.JumpToKey("sound", false))
			{
				if (kv.GotoFirstSubKey(false))
				{
					music.aSounds = new ArrayList(sizeof(SoundFilepath));
					
					do
					{
						SoundFilepath filepath;
						kv.GetString(NULL_STRING, filepath.sFilepath, sizeof(filepath.sFilepath));
						
						char sBuffer[32];
						kv.GetSectionName(sBuffer, sizeof(sBuffer));
						filepath.flDuration = StringToFloat(sBuffer);
						
						music.aSounds.PushArray(filepath);
					}
					while (kv.GotoNextKey(false));
					kv.GoBack();
				}
				else
				{
					LogError("Config music \"%s\" must have atleast one \"sound\"", music.sName);
					continue;
				}
				
				kv.GoBack();
			}
			else
			{
				LogError("Config music \"%s\" must have \"sound\" section", music.sName);
				continue;
			}
			
			music.iPriority = kv.GetNum("priority", 0);
			mMusics.SetArray(music.sName, music, sizeof(music));
			
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
	
	return mMusics;
}

void Config_LoadInfectedVo(KeyValues kv, ArrayList aSoundVo[view_as<int>(Infected_Count)][view_as<int>(SoundVo_Count)])
{
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char sInfected[64];
			kv.GetSectionName(sInfected, sizeof(sInfected));
			Infected nInfected = GetInfected(sInfected);
			if (nInfected == Infected_Unknown)
			{
				LogError("Unknown infected name \"%s\" from sound vo config", sInfected);
				continue;
			}
			
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char sVoType[64], sFilepath[PLATFORM_MAX_PATH];
					kv.GetSectionName(sVoType, sizeof(sVoType));
					kv.GetString(NULL_STRING, sFilepath, sizeof(sFilepath));
					
					StrToLower(sVoType, sVoType, sizeof(sVoType));
					SoundVo nSoundVo = Sound_GetVoType(sVoType);
					if (nSoundVo == SoundVo_Unknown)
					{
						LogError("Unknown sound vo type \"%s\" from infected \"%s\" in config", sVoType, sInfected);
						continue;
					}
					
					if (!aSoundVo[nInfected][nSoundVo])
						aSoundVo[nInfected][nSoundVo] = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
					
					aSoundVo[nInfected][nSoundVo].PushString(sFilepath);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
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

int Config_GetOriginalItemDefIndex(int iIndex)
{
	int iOrigIndex;
	
	char sIndex[8];
	IntToString(iIndex, sIndex, sizeof(sIndex));
	
	if (g_mConfigReskins.GetValue(sIndex, iOrigIndex))
		return iOrigIndex;
	else
		return iIndex;
}

bool Config_GetMeleeByDefIndex(int iIndex, ConfigMelee melee)
{
	int iPos = g_aConfigMelee.FindValue(iIndex, ConfigMelee::iIndex);
	if (iPos == -1)
		return false;
	
	g_aConfigMelee.GetArray(iPos, melee);
	return true;
}

void Config_GetRandomDebris(Debris debris)
{
	ArrayList aList = new ArrayList(sizeof(Debris));
	int iLength = g_aConfigDebris.Length;
	for (int i = 0; i < iLength; i++)
	{
		g_aConfigDebris.GetArray(i, debris);
		if (debris.flChance > GetRandomFloat(0.0, 1.0))
			aList.PushArray(debris);
	}
	
	int iRandom = GetRandomInt(0, aList.Length - 1);
	aList.GetArray(iRandom, debris);
	delete aList;
}

bool Config_GetDebrisFromModel(const char[] sModel, Debris debris)
{
	int iLength = g_aConfigDebris.Length;
	for (int i = 0; i < iLength; i++)
	{
		g_aConfigDebris.GetArray(i, debris);
		if (StrEqual(debris.sModel, sModel))
			return true;
	}
	
	return false;
}
