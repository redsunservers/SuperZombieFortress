enum struct WeaponClasses
{
	int iIndex;
	char sClassname[256];
	char sAttribs[256];
}

enum struct SurvivorClasses
{
	TFClassType nClass;
	bool bEnabled;
	float flSpeed;
	int iRegen;
	int iAmmo;
}

enum struct ZombieClasses
{
	TFClassType nClass;
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
	TFClassType nClass;
	bool bEnabled;
	int iHealth;
	float flSpeed;
	int iRegen;
	int iDegen;
	int iColor[4];
	char sMsg[256];
	char sModel[PLATFORM_MAX_PATH];
	ArrayList aWeapons;
}

TFClassType[view_as<int>(TFClassType)] g_nSurvivorClass;
TFClassType[view_as<int>(TFClassType)] g_nZombieClass;
Infected[view_as<int>(Infected)] g_nInfectedClass;

int g_iSurvivorClassCount;
int g_iZombieClassCount;
int g_iInfectedClassCount;

static SurvivorClasses g_SurvivorClasses[view_as<int>(TFClassType)];
static ZombieClasses g_ZombieClasses[view_as<int>(TFClassType)];
static InfectedClasses g_InfectedClasses[view_as<int>(Infected)];

static ArrayList g_aSurvivorClasses;
static ArrayList g_aZombieClasses;
static ArrayList g_aInfectedClasses;

void Classes_Refresh()
{
	delete g_aSurvivorClasses;
	
	//Load survivor config
	g_aSurvivorClasses = Config_LoadSurvivorClasses();
	
	g_iSurvivorClassCount = 0;
	int iLength = g_aSurvivorClasses.Length;
	for (int i = 0; i < iLength; i++)
	{
		SurvivorClasses sur;
		g_aSurvivorClasses.GetArray(i, sur);
		
		if (sur.bEnabled)
		{
			g_nSurvivorClass[g_iSurvivorClassCount] = sur.nClass;
			g_iSurvivorClassCount++;
		}
		
		g_SurvivorClasses[sur.nClass] = sur;
	}
	
	//Delete zombie handles
	if (g_aZombieClasses)
	{
		iLength = g_aZombieClasses.Length;
		for (int i = 0; i < iLength; i++)
		{
			ZombieClasses zom;
			g_aZombieClasses.GetArray(i, zom);
			delete zom.aWeapons;
		}
		
		delete g_aZombieClasses;
	}
	
	//Load zombie config
	g_aZombieClasses = Config_LoadZombieClasses();
	
	iLength = g_aZombieClasses.Length;
	g_iZombieClassCount = 0;
	for (int i = 0; i < iLength; i++)
	{
		ZombieClasses zom;
		g_aZombieClasses.GetArray(i, zom);
		
		if (zom.bEnabled)
		{
			g_nZombieClass[g_iZombieClassCount] = zom.nClass;
			g_iZombieClassCount++;
		}
		
		g_ZombieClasses[zom.nClass] = zom;
	}
	
	//Delete infected handles
	if (g_aInfectedClasses)
	{
		iLength = g_aInfectedClasses.Length;
		for (int i = 0; i < iLength; i++)
		{
			InfectedClasses inf;
			g_aInfectedClasses.GetArray(i, inf);
			delete inf.aWeapons;
		}
		
		delete g_aInfectedClasses;
	}
	
	//Load infected config
	g_aInfectedClasses = Config_LoadInfectedClasses();
	
	iLength = g_aInfectedClasses.Length;
	g_iInfectedClassCount = 0;
	for (int i = 0; i < iLength; i++)
	{
		InfectedClasses inf;
		g_aInfectedClasses.GetArray(i, inf);
		
		if (inf.bEnabled)
		{
			g_nInfectedClass[g_iInfectedClassCount] = inf.nInfected;
			g_iInfectedClassCount++;
		}
		
		g_InfectedClasses[inf.nInfected] = inf;
	}
	
	Classes_Precache();
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

stock float GetClientBaseSpeed(int iClient)
{
	if (IsValidZombie(iClient))
	{
		if (g_nInfected[iClient] != Infected_None)
			return g_InfectedClasses[g_nInfected[iClient]].flSpeed;

		return g_ZombieClasses[TF2_GetPlayerClass(iClient)].flSpeed;
	}

	return g_SurvivorClasses[TF2_GetPlayerClass(iClient)].flSpeed;
}

////////////////////////////////////////////////////////////
//
// Survivor Variables
//
////////////////////////////////////////////////////////////

stock bool IsValidSurvivorClass(TFClassType nClass)
{
	return g_SurvivorClasses[nClass].bEnabled;
}

stock TFClassType GetRandomSurvivorClass()
{
	return g_nSurvivorClass[GetRandomInt(0, g_iSurvivorClassCount-1)];
}

stock int GetSurvivorClassCount()
{
	return g_iSurvivorClassCount;
}

stock float GetSurvivorSpeed(TFClassType nClass)
{
	return g_SurvivorClasses[nClass].flSpeed;
}

stock int GetSurvivorRegen(TFClassType nClass)
{
	return g_SurvivorClasses[nClass].iRegen;
}

stock int GetSurvivorAmmo(TFClassType nClass)
{
	return g_SurvivorClasses[nClass].iAmmo;
}

////////////////////////////////////////////////////////////
//
// Zombie Variables
//
////////////////////////////////////////////////////////////

stock bool IsValidZombieClass(TFClassType nClass)
{
	return g_ZombieClasses[nClass].bEnabled;
}

stock TFClassType GetRandomZombieClass()
{
	return g_nZombieClass[GetRandomInt(0, g_iZombieClassCount-1)];
}

stock int GetZombieClassCount()
{
	return g_iZombieClassCount;
}

stock int GetZombieHealth(TFClassType nClass)
{
	return g_ZombieClasses[nClass].iHealth;
}

stock float GetZombieSpeed(TFClassType nClass)
{
	return g_ZombieClasses[nClass].flSpeed;
}

stock int GetZombieRegen(TFClassType nClass)
{
	return g_ZombieClasses[nClass].iRegen;
}

stock int GetZombieDegen(TFClassType nClass)
{
	return g_ZombieClasses[nClass].iDegen;
}

stock float GetZombieSpree(TFClassType nClass)
{
	return g_ZombieClasses[nClass].flSpree;
}

stock float GetZombieHorde(TFClassType nClass)
{
	return g_ZombieClasses[nClass].flHorde;
}

stock float GetZombieMaxSpree(TFClassType nClass)
{
	return g_ZombieClasses[nClass].flMaxSpree;
}

stock float GetZombieMaxHorde(TFClassType nClass)
{
	return g_ZombieClasses[nClass].flMaxHorde;
}

stock bool GetZombieWeapon(TFClassType nClass, int &iPos, WeaponClasses weapon)
{
	if (!g_ZombieClasses[nClass].aWeapons || iPos < 0 || iPos >= g_ZombieClasses[nClass].aWeapons.Length)
		return false;
	
	g_ZombieClasses[nClass].aWeapons.GetArray(iPos, weapon);
	
	iPos++;
	return true;
}

////////////////////////////////////////////////////////////
//
// Special Infected Variables
//
////////////////////////////////////////////////////////////

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
	return g_InfectedClasses[nInfected].nClass;
}

stock int GetInfectedHealth(Infected nInfected)
{
	return g_InfectedClasses[nInfected].iHealth;
}

stock float GetInfectedSpeed(Infected nInfected)
{
	return g_InfectedClasses[nInfected].flSpeed;
}

stock int GetInfectedRegen(Infected nInfected)
{
	return g_InfectedClasses[nInfected].iRegen;
}

stock int GetInfectedDegen(Infected nInfected)
{
	return g_InfectedClasses[nInfected].iDegen;
}

stock int GetInfectedColor(int iValue, Infected nInfected)
{
	return g_InfectedClasses[nInfected].iColor[iValue];
}

stock bool GetInfectedMessage(char[] sBuffer, int iLength, Infected nInfected)
{
	if (g_InfectedClasses[nInfected].sMsg[0] == '\0')
		return false;
	
	strcopy(sBuffer, iLength, g_InfectedClasses[nInfected].sMsg);
	return true;
}

stock bool GetInfectedModel(Infected nInfected, char[] sBuffer, int iLength)
{
	if (g_InfectedClasses[nInfected].sModel[0] == '\0')
		return false;
	
	strcopy(sBuffer, iLength, g_InfectedClasses[nInfected].sModel);
	return true;
}

stock bool GetInfectedWeapon(Infected nInfected, int &iPos, WeaponClasses weapon)
{
	if (!g_InfectedClasses[nInfected].aWeapons || iPos < 0 || iPos >= g_InfectedClasses[nInfected].aWeapons.Length)
		return false;
	
	g_InfectedClasses[nInfected].aWeapons.GetArray(iPos, weapon);
	
	iPos++;
	return true;
}