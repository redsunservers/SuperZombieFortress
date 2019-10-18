TFClassType[view_as<int>(TFClassType)] g_nSurvivorClass;
TFClassType[view_as<int>(TFClassType)] g_nZombieClass;

static bool g_bValidSurvivor[view_as<int>(TFClassType)];
static bool g_bValidZombie[view_as<int>(TFClassType)];

static float g_flSurvivorSpeed[view_as<int>(TFClassType)];
static int g_iSurvivorRegen[view_as<int>(TFClassType)];
static int g_iSurvivorAmmo[view_as<int>(TFClassType)];

static float g_flZombieSpeed[view_as<int>(TFClassType)];
static int g_iZombieRegen[view_as<int>(TFClassType)];
static int g_iZombieDegen[view_as<int>(TFClassType)];
static int g_iZombieIndex[view_as<int>(TFClassType)];
static char g_sZombieAttribs[view_as<int>(TFClassType)][256];

static ArrayList g_SurvivorClasses;
static ArrayList g_ZombieClasses;

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
	int iIndex;
	char sAttribs[256];
}

void Classes_Setup()
{
	g_SurvivorClasses = Config_LoadSurvivorClasses();
	
	int iCurrent;
	int iLength = g_SurvivorClasses.Length;
	TFClassType nClass;
	for (int i = 0; i < iLength; i++)
	{
		SurvivorClasses sur;
		g_SurvivorClasses.GetArray(i, sur);
		
		nClass = sur.nClass;
		g_bValidSurvivor[nClass] = sur.bEnabled;
		if (g_bValidSurvivor[nClass])
		{
			g_nSurvivorClass[iCurrent] = nClass;
			iCurrent++;
		}

		g_flSurvivorSpeed[nClass] = sur.flSpeed;
		g_iSurvivorRegen[nClass] = sur.iRegen;
		g_iSurvivorAmmo[nClass] = sur.iAmmo;
	}
	
	g_ZombieClasses = Config_LoadZombieClasses();
	
	iLength = g_ZombieClasses.Length;
	iCurrent = 0;
	for (int i = 0; i < iLength; i++)
	{
		ZombieClasses zom;
		g_ZombieClasses.GetArray(i, zom);
		
		nClass = zom.nClass;
		g_bValidZombie[nClass] = zom.bEnabled;
		if (g_bValidZombie[nClass])
		{
			g_nZombieClass[iCurrent] = nClass;
			iCurrent++;
		}

		g_flZombieSpeed[nClass] = zom.flSpeed;
		g_iZombieRegen[nClass] = zom.iRegen;
		g_iZombieIndex[nClass] = zom.iIndex;
		strcopy(g_sZombieAttribs[nClass], sizeof(g_sZombieAttribs[]), zom.sAttribs);
	}
}

stock float GetClientBaseSpeed(int iClient)
{
	if (IsValidZombie(iClient))
		return g_flZombieSpeed[TF2_GetPlayerClass(iClient)];

	return g_flSurvivorSpeed[TF2_GetPlayerClass(iClient)];
}

////////////////////////////////////////////////////////////
//
// Survivor Variables
//
////////////////////////////////////////////////////////////

stock bool IsValidSurvivorClass(TFClassType nClass)
{
	return g_bValidSurvivor[nClass];
}

stock int GetSurvivorClassCount()
{
	return sizeof(g_nSurvivorClass[]);
}

stock TFClassType GetRandomSurvivorClass()
{
	return g_nSurvivorClass[GetRandomInt(0, sizeof(g_nSurvivorClass)-1)];
}

stock float GetSurvivorSpeed(TFClassType nClass)
{
	return g_flSurvivorSpeed[nClass];
}

stock int GetSurvivorRegen(TFClassType nClass)
{
	return g_iSurvivorRegen[nClass];
}

stock int GetSurvivorAmmo(TFClassType nClass)
{
	return g_iSurvivorAmmo[nClass];
}

////////////////////////////////////////////////////////////
//
// Zombie Variables
//
////////////////////////////////////////////////////////////

stock bool IsValidZombieClass(TFClassType nClass)
{
	return g_bValidZombie[nClass];
}

stock TFClassType GetRandomZombieClass()
{
	return g_nZombieClass[GetRandomInt(0, sizeof(g_nZombieClass)-1)];
}

stock int GetZombieClassCount()
{
	return sizeof(g_nZombieClass[]);
}

stock float GetZombieSpeed(TFClassType nClass)
{
	return g_flZombieSpeed[nClass];
}

stock int GetZombieRegen(TFClassType nClass)
{
	return g_iZombieRegen[nClass];
}

stock int GetZombieDegen(TFClassType nClass)
{
	return g_iZombieDegen[nClass];
}

stock int GetZombieIndex(TFClassType nClass)
{
	return g_iZombieIndex[nClass];
}

stock int GetZombieAttribs(char[] sBuffer, int iLength, TFClassType nClass)
{
	strcopy(sBuffer, iLength, g_sZombieAttribs[nClass]);
	return strlen(sBuffer);
}