#define CONFIG_WEAPONS "configs/szf/weapons.cfg"

enum struct eConfigMelee
{
	int iIndex;
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