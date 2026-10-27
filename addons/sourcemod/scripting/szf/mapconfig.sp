#define CONFIG_MAPS		"configs/szf/maps.cfg"

enum
{
	MapSetting_StartRespawnTime = 0,
	MapSetting_PreFrenzyRate,
	MapSetting_FrenzyRespawnTime,
	MapSetting_FrenzyDuration,
	MapSetting_PostFrenzyRespawnTime,
	MapSetting_PostFrenzyRate,
	MapSetting_Post2ndFrenzyRespawnTime,
	MapSetting_StartingRatio,
	
	MapSetting_Count
}

static const char g_sMapSettingKeys[][] =
{
	"startrespawntime",
	"prefrenzyrate",
	"frenzyrespawntime",
	"frenzyduration",
	"postfrenzyrespawntime",
	"postfrenzyrate",
	"post2ndfrenzyrespawntime",
	"startingratio"
};

static const float g_flMapSettingDefaults[] =
{
	20.0,
	25.0,
	10.0,
	20.0,
	12.0,
	30.0,
	4.0,
	4.0
};

static bool g_bMapConfigLoaded;
static float g_flMapSettings[MapSetting_Count];
static ArrayList g_aMapLevels;
static StringMap g_mMapLevels;
static int g_iMapLevel = -1;
static char g_sMapLevel[64];
static bool g_bMapLevelForNextRound;
static bool g_bMapRebalancePending;

static int g_iSplitUserId[MAXPLAYERS + 1];
static int g_iSplitZombieRound[MAXPLAYERS + 1];
static bool g_bSplitForced[MAXPLAYERS + 1];
static int g_iSplitCount;
static bool g_bSplitValid;

void MapConfig_Load()
{
	for (int i = 0; i < MapSetting_Count; i++)
		g_flMapSettings[i] = g_flMapSettingDefaults[i];
	
	if (!g_aMapLevels)
		g_aMapLevels = new ArrayList(MapSetting_Count);
	else
		g_aMapLevels.Clear();
	
	if (!g_mMapLevels)
		g_mMapLevels = new StringMap();
	else
		g_mMapLevels.Clear();
	
	g_iMapLevel = -1;
	g_bMapConfigLoaded = true;
	
	KeyValues kv = Config_LoadFile(CONFIG_MAPS, "Maps");
	if (!kv)
		return;
	
	if (kv.JumpToKey("default", false))
	{
		MapConfig_ReadSection(kv, g_flMapSettings);
		kv.GoBack();
	}
	
	char sMapPath[PLATFORM_MAX_PATH], sMap[PLATFORM_MAX_PATH];
	GetCurrentMap(sMapPath, sizeof(sMapPath));
	if (!GetMapDisplayName(sMapPath, sMap, sizeof(sMap)))
		strcopy(sMap, sizeof(sMap), sMapPath);
	
	if (kv.JumpToKey("maps", false))
	{
		if (MapConfig_JumpToMap(kv, sMap))
		{
			MapConfig_ReadSection(kv, g_flMapSettings);
			
			if (kv.JumpToKey("levels", false))
			{
				if (kv.GotoFirstSubKey(true))
				{
					do
					{
						char sRelay[64];
						kv.GetSectionName(sRelay, sizeof(sRelay));
						MapConfig_ToLower(sRelay);
						
						float flLevel[MapSetting_Count];
						for (int i = 0; i < MapSetting_Count; i++)
							flLevel[i] = g_flMapSettings[i];
						
						MapConfig_ReadSection(kv, flLevel);
						g_mMapLevels.SetValue(sRelay, g_aMapLevels.PushArray(flLevel));
					}
					while (kv.GotoNextKey(true));
					
					kv.GoBack();
				}
				
				kv.GoBack();
			}
			
			kv.GoBack();
		}
		
		kv.GoBack();
	}
	
	delete kv;
	
	if (g_sMapLevel[0] && !g_mMapLevels.GetValue(g_sMapLevel, g_iMapLevel))
		g_iMapLevel = -1;
}

static bool MapConfig_JumpToMap(KeyValues kv, const char[] sMap)
{
	if (kv.JumpToKey(sMap, false))
		return true;
	
	char sBest[PLATFORM_MAX_PATH];
	int iBestLength = -1;
	
	if (kv.GotoFirstSubKey(true))
	{
		do
		{
			char sName[PLATFORM_MAX_PATH];
			kv.GetSectionName(sName, sizeof(sName));
			
			int iLength = strlen(sName);
			if (iLength < 2 || sName[iLength - 1] != '*')
				continue;
			
			sName[iLength - 1] = '\0';
			if (iLength - 1 > iBestLength && StrContains(sMap, sName, false) == 0)
			{
				iBestLength = iLength - 1;
				kv.GetSectionName(sBest, sizeof(sBest));
			}
		}
		while (kv.GotoNextKey(true));
		
		kv.GoBack();
	}
	
	return iBestLength >= 0 && kv.JumpToKey(sBest, false);
}

static void MapConfig_ReadSection(KeyValues kv, float flSettings[MapSetting_Count])
{
	for (int i = 0; i < MapSetting_Count; i++)
	{
		char sValue[32];
		kv.GetString(g_sMapSettingKeys[i], sValue, sizeof(sValue));
		TrimString(sValue);
		if (!sValue[0])
			continue;
		
		float flValue;
		if (StringToFloatEx(sValue, flValue) > 0)
			flSettings[i] = flValue;
		else
			LogError("Invalid value \"%s\" for \"%s\" in %s", sValue, g_sMapSettingKeys[i], CONFIG_MAPS);
	}
}

static void MapConfig_ToLower(char[] sBuffer)
{
	for (int i = 0; sBuffer[i]; i++)
		sBuffer[i] = CharToLower(sBuffer[i]);
}

float MapConfig_GetSetting(int iSetting)
{
	if (!g_bMapConfigLoaded)
		return g_flMapSettingDefaults[iSetting];
	
	if (0 <= g_iMapLevel < g_aMapLevels.Length)
		return view_as<float>(g_aMapLevels.Get(g_iMapLevel, iSetting));
	
	return g_flMapSettings[iSetting];
}

int MapConfig_GetStartingZombies(int iPlayers)
{
	if (iPlayers < 2)
		return 0;
	
	float flRatio = MapConfig_GetSetting(MapSetting_StartingRatio);
	if (flRatio < 1.0)
		flRatio = 1.0;
	
	int iZombies = RoundToCeil(float(iPlayers) / flRatio - 0.001);
	if (iZombies < 1)
		iZombies = 1;
	
	if (iZombies > iPlayers - 1)
		iZombies = iPlayers - 1;
	
	return iZombies;
}

void MapConfig_OnRoundEnd()
{
	g_bMapLevelForNextRound = false;
	g_bSplitValid = false;
}

void MapConfig_Reset()
{
	g_iMapLevel = -1;
	g_sMapLevel[0] = '\0';
	g_bMapLevelForNextRound = false;
	g_bMapRebalancePending = false;
	g_bSplitValid = false;
	g_iSplitCount = 0;
}

void MapConfig_OnRoundRespawn()
{
	if (!g_bMapLevelForNextRound)
	{
		g_iMapLevel = -1;
		g_sMapLevel[0] = '\0';
	}
	
	g_bMapLevelForNextRound = false;
	g_bMapRebalancePending = false;
}

void MapConfig_OnRelayTrigger(const char[] sTargetName)
{
	if (!g_mMapLevels || !g_mMapLevels.Size || !sTargetName[0])
		return;
	
	char sRelay[64];
	strcopy(sRelay, sizeof(sRelay), sTargetName);
	MapConfig_ToLower(sRelay);
	
	int iLevel;
	if (!g_mMapLevels.GetValue(sRelay, iLevel))
		return;
	
	g_iMapLevel = iLevel;
	strcopy(g_sMapLevel, sizeof(g_sMapLevel), sRelay);
	CPrintToChatDebug("Map level picked: %s (starting ratio %.2f)", sRelay, MapConfig_GetSetting(MapSetting_StartingRatio));
	
	switch (g_nRoundState)
	{
		case SZFRoundState_Setup, SZFRoundState_End:
		{
			g_bMapLevelForNextRound = true;
		}
		case SZFRoundState_Grace:
		{
			if (!g_bMapRebalancePending)
			{
				g_bMapRebalancePending = true;
				RequestFrame(Frame_MapConfigRebalance);
			}
		}
	}
}

public void Frame_MapConfigRebalance(any data)
{
	if (!g_bMapRebalancePending)
		return;
	
	g_bMapRebalancePending = false;
	
	if (!g_bEnabled || g_nRoundState != SZFRoundState_Grace || !g_bSplitValid)
		return;
	
	MapConfig_RebalanceTeams();
}

void MapConfig_SplitBegin()
{
	g_iSplitCount = 0;
	g_bSplitValid = true;
}

void MapConfig_SplitAdd(int iClient)
{
	if (g_iSplitCount >= sizeof(g_iSplitUserId))
		return;
	
	g_iSplitUserId[g_iSplitCount] = GetClientUserId(iClient);
	g_iSplitZombieRound[g_iSplitCount] = GetRoundPlayedAsZombie(iClient);
	g_bSplitForced[g_iSplitCount] = false;
	g_iSplitCount++;
}

void MapConfig_SplitSetForced(int iClient)
{
	int iUserId = GetClientUserId(iClient);
	for (int i = 0; i < g_iSplitCount; i++)
		if (g_iSplitUserId[i] == iUserId)
			g_bSplitForced[i] = true;
}

static void MapConfig_RebalanceTeams()
{
	int iPlayers, iSurvivors;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || TF2_GetClientTeam(iClient) == TFTeam_Spectator)
			continue;
		
		iPlayers++;
		if (IsSurvivor(iClient))
			iSurvivors++;
	}
	
	int iWantSurvivors = iPlayers - MapConfig_GetStartingZombies(iPlayers);
	if (iWantSurvivors < 1)
		iWantSurvivors = 1;
	
	if (iSurvivors > iWantSurvivors)
	{
		for (int iPass = 0; iPass < 2 && iSurvivors > iWantSurvivors; iPass++)
		{
			for (int i = g_iSplitCount - 1; i >= 0 && iSurvivors > iWantSurvivors; i--)
			{
				int iClient = GetClientOfUserId(g_iSplitUserId[i]);
				if (!iClient || !IsClientInGame(iClient) || !IsSurvivor(iClient))
					continue;
				
				if (iPass == 0 && !g_bOptInZombie[iClient])
					continue;
				
				DropCarryingItem(iClient);
				SpawnClient(iClient, TFTeam_Zombie);
				g_flTimeStartAsZombie[iClient] = GetGameTime();
				SetClientStartedAsZombie(iClient);
				CPrintToChat(iClient, "{red}This round's level starts with more zombies, you have been moved to the Infected.");
				iSurvivors--;
			}
		}
	}
	else if (iSurvivors < iWantSurvivors && !g_bLastSurvivor)
	{
		for (int iPass = 0; iPass < 2 && iSurvivors < iWantSurvivors; iPass++)
		{
			for (int i = 0; i < g_iSplitCount && iSurvivors < iWantSurvivors; i++)
			{
				int iClient = GetClientOfUserId(g_iSplitUserId[i]);
				if (!iClient || !IsClientInGame(iClient) || !IsZombie(iClient) || g_bSplitForced[i])
					continue;
				
				if (iPass == 0 && g_bOptInZombie[iClient])
					continue;
				
				SpawnClient(iClient, TFTeam_Survivor);
				g_flTimeStartAsZombie[iClient] = 0.0;
				SetRoundPlayedAsZombie(iClient, g_iSplitZombieRound[i]);
				CPrintToChat(iClient, "{green}This round's level starts with fewer zombies, you have been moved to the Survivors.");
				iSurvivors++;
			}
		}
	}
}
