enum struct SurvivorClasses
{
	TFClassType iClass;
	bool bEnabled;
	float flSpeed;
	int iRegen;
	int iAmmo;
}

enum struct ZombieClasses
{
	TFClassType iClass;
	bool bEnabled;
	int iHealth;
	float flSpeed;
	int iRegen;
	int iDegen;
	float flSpree;
	float flHorde;
	float flMaxSpree;
	float flMaxHorde;
	ArrayList aWeapons;
}

enum struct InfectedClasses
{
	Infected nInfected;
	TFClassType iInfectedClass;
	bool bEnabled;
	int iHealth;
	float flSpeed;
	bool bGlow;
	int iRegen;
	int iDegen;
	int iColor[4];
	char sMessage[256];
	char sModel[PLATFORM_MAX_PATH];
	ArrayList aWeapons;
	int iRageCooldown;
	Function callback_spawn;
	Function callback_rage;
	Function callback_think;
	Function callback_death;
}

static TFClassType g_nSurvivorClass[view_as<int>(TFClassType)];
static TFClassType g_nZombieClass[view_as<int>(TFClassType)];
static Infected g_nInfectedClass[view_as<int>(Infected)];

static int g_iSurvivorClassCount;
static int g_iZombieClassCount;
static int g_iInfectedClassCount;

static SurvivorClasses g_SurvivorClasses[view_as<int>(TFClassType)];
static ZombieClasses g_ZombieClasses[view_as<int>(TFClassType)];
static InfectedClasses g_InfectedClasses[view_as<int>(Infected)];

void Classes_Refresh()
{
	//Load survivor config
	ArrayList aSurvivorClasses = Config_LoadSurvivorClasses();
	
	g_iSurvivorClassCount = 0;
	int iLength = aSurvivorClasses.Length;
	for (int i = 0; i < iLength; i++)
	{
		SurvivorClasses sur;
		aSurvivorClasses.GetArray(i, sur);
		
		if (sur.bEnabled)
		{
			g_nSurvivorClass[g_iSurvivorClassCount] = sur.iClass;
			g_iSurvivorClassCount++;
		}
		
		g_SurvivorClasses[sur.iClass] = sur;
	}
	
	delete aSurvivorClasses;
	
	//Load zombie config
	ArrayList aZombieClasses = Config_LoadZombieClasses();
	
	g_iZombieClassCount = 0;
	iLength = aZombieClasses.Length;
	for (int i = 0; i < iLength; i++)
	{
		ZombieClasses zom;
		aZombieClasses.GetArray(i, zom);
		
		if (zom.bEnabled)
		{
			g_nZombieClass[g_iZombieClassCount] = zom.iClass;
			g_iZombieClassCount++;
		}
		
		//Delete handles
		delete g_ZombieClasses[zom.iClass].aWeapons;
		
		g_ZombieClasses[zom.iClass] = zom;
	}
	
	delete aZombieClasses;
	
	//Load infected config
	ArrayList aInfectedClasses = Config_LoadInfectedClasses();
	
	g_iInfectedClassCount = 0;
	iLength = aInfectedClasses.Length;
	for (int i = 0; i < iLength; i++)
	{
		InfectedClasses inf;
		aInfectedClasses.GetArray(i, inf);
		
		if (inf.bEnabled)
		{
			g_nInfectedClass[g_iInfectedClassCount] = inf.nInfected;
			g_iInfectedClassCount++;
		}
		
		//Delete handles
		delete g_InfectedClasses[inf.nInfected].aWeapons;
		
		g_InfectedClasses[inf.nInfected] = inf;
	}
	
	delete aInfectedClasses;
	
	Classes_Precache();
	
	//Set new config to clients
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			Classes_SetClient(iClient);
}

void Classes_Precache()
{
	for (Infected nInfected; nInfected < Infected; nInfected++)
	{
		if (g_InfectedClasses[nInfected].sModel[0] != '\0')
		{
			PrecacheModel(g_InfectedClasses[nInfected].sModel);
			AddModelToDownloadsTable(g_InfectedClasses[nInfected].sModel);
		}
	}
}

void Classes_SetClient(int iClient, Infected nInfected = view_as<Infected>(-1), TFClassType iClass = TFClass_Unknown)
{
	ClientClasses nothing;
	g_ClientClasses[iClient] = nothing;
	
	if (nInfected != view_as<Infected>(-1))
		g_nInfected[iClient] = nInfected;
	
	if (g_nInfected[iClient] != Infected_None)
		iClass = GetInfectedClass(g_nInfected[iClient]);
	else if (iClass == TFClass_Unknown)
		iClass = TF2_GetPlayerClass(iClient);
	
	if (IsSurvivor(iClient))
	{
		//Survivor classes
		g_ClientClasses[iClient].flSpeed = g_SurvivorClasses[iClass].flSpeed;
		g_ClientClasses[iClient].iRegen = g_SurvivorClasses[iClass].iRegen;
		g_ClientClasses[iClient].iAmmo = g_SurvivorClasses[iClass].iAmmo;
		
		g_ClientClasses[iClient].callback_spawn = INVALID_FUNCTION;
		g_ClientClasses[iClient].callback_rage = INVALID_FUNCTION;
		g_ClientClasses[iClient].callback_think = INVALID_FUNCTION;
		g_ClientClasses[iClient].callback_death = INVALID_FUNCTION;
	}
	else if (IsZombie(iClient))
	{
		//Zombie classes, special infected unaffected
		g_ClientClasses[iClient].flSpree = g_ZombieClasses[iClass].flSpree;
		g_ClientClasses[iClient].flHorde = g_ZombieClasses[iClass].flHorde;
		g_ClientClasses[iClient].flMaxSpree = g_ZombieClasses[iClass].flMaxSpree;
		g_ClientClasses[iClient].flMaxHorde = g_ZombieClasses[iClass].flMaxHorde;
		
		//Normal and Special infected
		g_ClientClasses[iClient].iRageCooldown = g_InfectedClasses[g_nInfected[iClient]].iRageCooldown;
		g_ClientClasses[iClient].callback_spawn = g_InfectedClasses[g_nInfected[iClient]].callback_spawn;
		g_ClientClasses[iClient].callback_rage = g_InfectedClasses[g_nInfected[iClient]].callback_rage;
		g_ClientClasses[iClient].callback_think = g_InfectedClasses[g_nInfected[iClient]].callback_think;
		g_ClientClasses[iClient].callback_death = g_InfectedClasses[g_nInfected[iClient]].callback_death;
		
		if (g_nInfected[iClient] == Infected_None)
		{
			//Zombie classes
			g_ClientClasses[iClient].flSpeed = g_ZombieClasses[iClass].flSpeed;
			g_ClientClasses[iClient].iRegen = g_ZombieClasses[iClass].iRegen;
			g_ClientClasses[iClient].iHealth = g_ZombieClasses[iClass].iHealth;
			g_ClientClasses[iClient].iDegen = g_ZombieClasses[iClass].iDegen;
			g_ClientClasses[iClient].aWeapons = g_ZombieClasses[iClass].aWeapons;
		}
		else
		{
			//Infected classes
			g_ClientClasses[iClient].flSpeed = g_InfectedClasses[g_nInfected[iClient]].flSpeed;
			g_ClientClasses[iClient].iRegen = g_InfectedClasses[g_nInfected[iClient]].iRegen;
			g_ClientClasses[iClient].iHealth = g_InfectedClasses[g_nInfected[iClient]].iHealth;
			g_ClientClasses[iClient].iDegen = g_InfectedClasses[g_nInfected[iClient]].iDegen;
			g_ClientClasses[iClient].aWeapons = g_InfectedClasses[g_nInfected[iClient]].aWeapons;
			
			//Infected classes, zombies don't get one
			g_ClientClasses[iClient].iInfectedClass = g_InfectedClasses[g_nInfected[iClient]].iInfectedClass;
			g_ClientClasses[iClient].bGlow = g_InfectedClasses[g_nInfected[iClient]].bGlow;
			g_ClientClasses[iClient].iColor = g_InfectedClasses[g_nInfected[iClient]].iColor;
			strcopy(g_ClientClasses[iClient].sMessage, sizeof(g_ClientClasses[].sMessage), g_InfectedClasses[g_nInfected[iClient]].sMessage);
			strcopy(g_ClientClasses[iClient].sModel, sizeof(g_ClientClasses[].sModel), g_InfectedClasses[g_nInfected[iClient]].sModel);
		}
	}
}

stock bool IsValidSurvivorClass(TFClassType iClass)
{
	return g_SurvivorClasses[iClass].bEnabled;
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