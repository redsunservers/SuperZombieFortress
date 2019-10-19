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
	float flSpeed;
	int iRegen;
	int iDegen;
	float flSpree;
	float flHorde;
	float flMaxSpree;
	float flMaxHorde;
	int iIndex;
	char sAttribs[256];
}

enum struct InfectedClasses
{
	Infected nInfected;
	TFClassType nClass;
	bool bEnabled;
	float flSpeed;
	int iRegen;
	int iDegen;
	int iIndex;
	char sAttribs[256];
}

TFClassType[view_as<int>(TFClassType)] g_nSurvivorClass;
TFClassType[view_as<int>(TFClassType)] g_nZombieClass;
Infected[view_as<int>(Infected)] g_nInfectedClass;

static SurvivorClasses g_SurvivorClasses[view_as<int>(TFClassType)];
static ZombieClasses g_ZombieClasses[view_as<int>(TFClassType)];
static InfectedClasses g_InfectedClasses[view_as<int>(Infected)];

static ArrayList g_aSurvivorClasses;
static ArrayList g_aZombieClasses;
static ArrayList g_aInfectedClasses;

void Classes_Setup()
{
	g_aSurvivorClasses = Config_LoadSurvivorClasses();
	
	int iCurrent;
	int iLength = g_aSurvivorClasses.Length;
	for (int i = 0; i < iLength; i++)
	{
		SurvivorClasses sur;
		g_aSurvivorClasses.GetArray(i, sur);
		
		if (sur.bEnabled)
		{
			g_nSurvivorClass[iCurrent] = sur.nClass;
			iCurrent++;
		}
		
		g_SurvivorClasses[sur.nClass].bEnabled = sur.bEnabled;
		g_SurvivorClasses[sur.nClass].flSpeed = sur.flSpeed;
		g_SurvivorClasses[sur.nClass].iRegen = sur.iRegen;
		g_SurvivorClasses[sur.nClass].iAmmo = sur.iAmmo;
	}
	
	g_aZombieClasses = Config_LoadZombieClasses();
	
	iLength = g_aZombieClasses.Length;
	iCurrent = 0;
	for (int i = 0; i < iLength; i++)
	{
		ZombieClasses zom;
		g_aZombieClasses.GetArray(i, zom);
		
		if (zom.bEnabled)
		{
			g_nZombieClass[iCurrent] = zom.nClass;
			iCurrent++;
		}
		
		g_ZombieClasses[zom.nClass].bEnabled = zom.bEnabled;
		g_ZombieClasses[zom.nClass].flSpeed = zom.flSpeed;
		g_ZombieClasses[zom.nClass].iRegen = zom.iRegen;
		g_ZombieClasses[zom.nClass].iDegen = zom.iDegen;
		g_ZombieClasses[zom.nClass].flSpree = zom.flSpree;
		g_ZombieClasses[zom.nClass].flHorde = zom.flHorde;
		g_ZombieClasses[zom.nClass].flMaxSpree = zom.flMaxSpree;
		g_ZombieClasses[zom.nClass].flMaxHorde = zom.flMaxHorde;
		g_ZombieClasses[zom.nClass].iIndex = zom.iIndex;
		strcopy(g_ZombieClasses[zom.nClass].sAttribs, 256, zom.sAttribs);
	}
	
	g_aInfectedClasses = Config_LoadInfectedClasses();
	
	iLength = g_aInfectedClasses.Length;
	iCurrent = 0;
	for (int i = 0; i < iLength; i++)
	{
		InfectedClasses inf;
		g_aInfectedClasses.GetArray(i, inf);
		
		if (inf.bEnabled)
		{
			g_nInfectedClass[iCurrent] = inf.nInfected;
			iCurrent++;
		}
		
		g_InfectedClasses[inf.nClass].bEnabled = inf.bEnabled;
		g_InfectedClasses[inf.nClass].flSpeed = inf.flSpeed;
		g_InfectedClasses[inf.nClass].iRegen = inf.iRegen;
		g_InfectedClasses[inf.nClass].iDegen = inf.iDegen;
		g_InfectedClasses[inf.nClass].iIndex = inf.iIndex;
		strcopy(g_InfectedClasses[inf.nClass].sAttribs, 256, inf.sAttribs);
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

stock int GetSurvivorClassCount()
{
	return sizeof(g_nSurvivorClass);
}

stock TFClassType GetRandomSurvivorClass()
{
	return g_nSurvivorClass[GetRandomInt(0, sizeof(g_nSurvivorClass)-1)];
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
	return g_nZombieClass[GetRandomInt(0, sizeof(g_nZombieClass)-1)];
}

stock int GetZombieClassCount()
{
	return sizeof(g_nZombieClass);
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

stock int GetZombieIndex(TFClassType nClass)
{
	return g_ZombieClasses[nClass].iIndex;
}

stock int GetZombieAttribs(char[] sBuffer, int iLength, TFClassType nClass)
{
	strcopy(sBuffer, iLength, g_ZombieClasses[nClass].sAttribs);
	return strlen(sBuffer);
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
	return g_nInfectedClass[GetRandomInt(2, sizeof(g_nInfectedClass)-1)];
}

stock int GetInfectedCount()
{
	return sizeof(g_nInfectedClass);
}

stock TFClassType GetInfectedClass(Infected nInfected)
{
	return g_InfectedClasses[nInfected].nClass;
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

stock int GetInfectedIndex(Infected nInfected)
{
	return g_InfectedClasses[nInfected].iIndex;
}

stock int GetInfectedAttribs(char[] sBuffer, int iLength, Infected nInfected)
{
	strcopy(sBuffer, iLength, g_InfectedClasses[nInfected].sAttribs);
	return strlen(sBuffer);
}
