#define CONFIG_CLASSES       "configs/szf/classes.cfg"

static TFClassType g_nSurvivorClass[view_as<int>(TFClassType)];
static TFClassType g_nZombieClass[view_as<int>(TFClassType)];
static Infected g_nInfectedClass[view_as<int>(Infected)];

static int g_iSurvivorClassCount;
static int g_iZombieClassCount;
static int g_iInfectedClassCount;

static ClientClasses g_SurvivorClasses[view_as<int>(TFClassType)];
static ClientClasses g_ZombieClasses[view_as<int>(TFClassType)];
static ClientClasses g_InfectedClasses[view_as<int>(Infected)];

void Classes_Refresh()
{
	
	KeyValues kv = Config_LoadFile(CONFIG_CLASSES, "Classes");
	if (!kv)
		return;
	
	//Setup default values
	ClientClasses DefaultClasses;
	DefaultClasses.bEnabled = true;
	DefaultClasses.iRegen = 2;
	DefaultClasses.iDegen = 3;
	DefaultClasses.flSpree = 1.0;
	DefaultClasses.flHorde = 2.0;
	DefaultClasses.flMaxSpree = 20.0;
	DefaultClasses.flMaxHorde = 20.0;
	DefaultClasses.iColor = {255, 255, 255, 255};
	DefaultClasses.callback_spawn = INVALID_FUNCTION;
	DefaultClasses.callback_rage = INVALID_FUNCTION;
	DefaultClasses.callback_think = INVALID_FUNCTION;
	DefaultClasses.callback_anim = INVALID_FUNCTION;
	DefaultClasses.callback_death = INVALID_FUNCTION;
	
	g_iSurvivorClassCount = 0;
	g_iZombieClassCount = 0;
	g_iInfectedClassCount = 0;
	
	//Set survivors default
	for (int i; i < sizeof(g_SurvivorClasses); i++)
	{
		delete g_SurvivorClasses[i].aWeapons;
		g_SurvivorClasses[i] = DefaultClasses;
	}
	
	//Load survivors config
	if (!Classes_LoadTeam(kv, "survivors", g_SurvivorClasses))
	{
		delete kv;
		return;
	}
	
	//Setup survivors enabled
	for (int i; i < sizeof(g_SurvivorClasses); i++)
	{
		if (g_SurvivorClasses[i].bEnabled)
		{
			g_nSurvivorClass[g_iSurvivorClassCount] = view_as<TFClassType>(i);
			g_iSurvivorClassCount++;
		}
	}
	
	//Set zombies default
	for (int i; i < sizeof(g_ZombieClasses); i++)
	{
		delete g_ZombieClasses[i].aWeapons;
		g_ZombieClasses[i] = DefaultClasses;
	}
	
	//Load zombies config
	if (!Classes_LoadTeam(kv, "zombies", g_ZombieClasses))
	{
		delete kv;
		return;
	}
	
	//Setup zombies enabled
	for (int i; i < sizeof(g_ZombieClasses); i++)
	{
		if (g_ZombieClasses[i].bEnabled)
		{
			g_nZombieClass[g_iZombieClassCount] = view_as<TFClassType>(i);
			g_iZombieClassCount++;
		}
	}
	
	for (int i; i < sizeof(g_InfectedClasses); i++)
		delete g_InfectedClasses[i].aWeapons;
	
	if (!Classes_LoadInfected(kv, "infected", g_InfectedClasses))
	{
		delete kv;
		return;
	}
	
	for (int i; i < sizeof(g_InfectedClasses); i++)
	{
		if (g_InfectedClasses[i].bEnabled)
		{
			g_nInfectedClass[g_iInfectedClassCount] = view_as<Infected>(i);
			g_iInfectedClassCount++;
		}
	}
	
	Classes_Precache();
	
	//Set new config to clients
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			Classes_SetClient(iClient);
}

bool Classes_LoadTeam(KeyValues kv, const char[] sKey, ClientClasses classes[view_as<int>(TFClassType)])
{
	if (!kv.JumpToKey(sKey, false))
	{
		LogError("Unable to find key \"%s\" in config file: %s", sKey, CONFIG_CLASSES);
		delete kv;
		return false;
	}
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char sBuffer[256];
			kv.GetSectionName(sBuffer, sizeof(sBuffer));
			TFClassType iClass = TF2_GetClass(sBuffer);
			if (iClass == TFClass_Unknown)
			{
				LogError("Invalid class '%s'.", sBuffer);
				continue;
			}
			
			Config_LoadClassesSection(kv, classes[iClass]);
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
	kv.GoBack();
	
	return true;
}

bool Classes_LoadInfected(KeyValues kv, const char[] sKey, ClientClasses classes[view_as<int>(Infected)])
{
	if (!kv.JumpToKey(sKey, false))
	{
		LogError("Unable to find key \"%s\" in config file: %s", sKey, CONFIG_CLASSES);
		delete kv;
		return false;
	}
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char sBuffer[256];
			kv.GetSectionName(sBuffer, sizeof(sBuffer));
			Infected nInfected = GetInfected(sBuffer);
			if (nInfected == Infected_Unknown)
			{
				LogError("Invalid infected '%s'.", sBuffer);
				continue;
			}
			
			kv.GetString("class", sBuffer, sizeof(sBuffer));
			TFClassType iInfectedClass = TF2_GetClass(sBuffer);
			
			//Copy zombies into infected to use as default values for infected
			classes[nInfected] = g_ZombieClasses[iInfectedClass];
			classes[nInfected].iInfectedClass = iInfectedClass;
			
			Config_LoadClassesSection(kv, classes[nInfected]);
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
	kv.GoBack();
	
	return true;
}

void Classes_Precache()
{
	for (Infected nInfected; nInfected < Infected; nInfected++)
	{
		if (g_InfectedClasses[nInfected].sModel[0])
		{
			PrecacheModel(g_InfectedClasses[nInfected].sModel);
			AddModelToDownloadsTable(g_InfectedClasses[nInfected].sModel);
		}
		
		if (g_InfectedClasses[nInfected].sSoundSpawn[0])
			PrecacheSound2(g_InfectedClasses[nInfected].sSoundSpawn);
	}
}

void Classes_SetClient(int iClient, Infected nInfected = view_as<Infected>(-1), TFClassType iClass = TFClass_Unknown)
{
	if (nInfected != view_as<Infected>(-1))
		g_nInfected[iClient] = nInfected;
	
	if (g_nInfected[iClient] != Infected_None)
		iClass = GetInfectedClass(g_nInfected[iClient]);
	else if (iClass == TFClass_Unknown)
		iClass = TF2_GetPlayerClass(iClient);
	
	if (IsSurvivor(iClient))
	{
		g_ClientClasses[iClient] = g_SurvivorClasses[iClass];
	}
	else if (IsZombie(iClient))
	{
		if (g_nInfected[iClient] == Infected_None)
			g_ClientClasses[iClient] = g_ZombieClasses[iClass];
		else
			g_ClientClasses[iClient] = g_InfectedClasses[g_nInfected[iClient]];
	}
}

stock bool IsValidSurvivorClass(TFClassType iClass)
{
	return g_SurvivorClasses[iClass].bEnabled;
}

stock bool GetSurvivorMenu(TFClassType iClass, char[] sBuffer, int iLength)
{
	if (!g_SurvivorClasses[iClass].sMenu[0])
		return false;
	
	strcopy(sBuffer, iLength, g_SurvivorClasses[iClass].sMenu);
	return true;
}

stock TFClassType GetRandomSurvivorClass()
{
	return g_nSurvivorClass[GetRandomInt(0, g_iSurvivorClassCount-1)];
}

stock int GetSurvivorClassCount()
{
	return g_iSurvivorClassCount;
}

stock bool IsValidZombieClass(TFClassType iClass)
{
	return g_ZombieClasses[iClass].bEnabled;
}

stock bool GetZombieMenu(TFClassType iClass, char[] sBuffer, int iLength)
{
	if (!g_ZombieClasses[iClass].sMenu[0])
		return false;
	
	strcopy(sBuffer, iLength, g_ZombieClasses[iClass].sMenu);
	return true;
}

stock TFClassType GetRandomZombieClass()
{
	return g_nZombieClass[GetRandomInt(0, g_iZombieClassCount-1)];
}

stock int GetZombieClassCount()
{
	return g_iZombieClassCount;
}

stock bool IsValidInfected(Infected nInfected)
{
	return g_InfectedClasses[nInfected].bEnabled;
}

stock bool GetInfectedMenu(Infected nInfected, char[] sBuffer, int iLength)
{
	if (!g_InfectedClasses[nInfected].sMenu[0])
		return false;
	
	strcopy(sBuffer, iLength, g_InfectedClasses[nInfected].sMenu);
	return true;
}

stock Infected GetRandomInfected()
{
	return g_nInfectedClass[GetRandomInt(2, g_iInfectedClassCount-1)];
}

stock int GetInfectedCount()
{
	return g_iInfectedClassCount;
}

stock TFClassType GetInfectedClass(Infected nInfected)
{
	return g_InfectedClasses[nInfected].iInfectedClass;
}