#define CONFIG_MAPS		"configs/szf/maps.cfg"
#define MAPCONFIG_LOWPLAYERCOUNT	"LowPlayerCount"
#define MAPSETTING_UNSET			-999999.0
#define MAPCONFIG_REINFORCEMENTTRIGGERS	"reinforcementtriggers"
#define MAPCONFIG_REINFORCEMENTRELAY	"reinforcementrelay"

enum
{
	MapSetting_StartRespawnTime = 0,
	MapSetting_PreFrenzyRate,
	MapSetting_FrenzyRespawnTime,
	MapSetting_FrenzyDuration,
	MapSetting_PostFrenzyRespawnTime,
	MapSetting_PostFrenzyRate,
	MapSetting_Frenzy2RespawnTime,
	MapSetting_Post2ndFrenzyRespawnTime,
	MapSetting_StartingRatio,
	MapSetting_DisableManualFrenzy,
	MapSetting_MinicritZombies,
	MapSetting_MinicritDuration,
	MapSetting_DisableForcedTank,
	MapSetting_ZombieDamage,
	MapSetting_RareWeaponChance,
	MapSetting_LowPlayerRatio,
	MapSetting_LowPlayerRatioCount,
	MapSetting_ReinforcementTime,
	MapSetting_ReinforcementPercent,
	MapSetting_ReinforcementThreshold,
	MapSetting_DisableReinforcementTimer,
	MapSetting_Reinforcements,
	MapSetting_ObjectiveLenience,
	
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
	"frenzy2respawntime",
	"post2ndfrenzyrespawntime",
	"startingratio",
	"disablemanualfrenzy",
	"minicritzombies",
	"minicritduration",
	"disableforcedtank",
	"zombiedamage",
	"rareweaponchance",
	"lowplayerratio",
	"lowplayerratiocount",
	"reinforcementtime",
	"reinforcementpercent",
	"reinforcementthreshold",
	"disablereinforcementtimer",
	"reinforcements",
	"objectivelenience"
};

static const float g_flMapSettingDefaults[] =
{
	20.0,
	25.0,
	10.0,
	20.0,
	12.0,
	30.0,
	10.0,
	4.0,
	4.0,
	0.0,
	3.0,
	120.0,
	0.0,
	-1.0,
	-1.0,
	0.0,
	0.0,
	300.0,
	15.0,
	50.0,
	0.0,
	0.0,
	1.0
};

static bool g_bMapConfigLoaded;
static float g_flMapSettings[MapSetting_Count];
static ArrayList g_aMapLevels;
static StringMap g_mMapLevels;
static int g_iMapLevel = -1;
static char g_sMapLevel[64];
static bool g_bMapLevelForNextRound;
static bool g_bMapRebalancePending;
static bool g_bMapCaseLevels;
static float g_flMapLowSettings[MapSetting_Count];
static int g_iMapLowZombies;
static ArrayList g_aMapLevelLow;
static ArrayList g_aMapLevelLowZombies;
static StringMap g_mReinforcementTriggers;

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
	
	if (!g_aMapLevelLow)
	{
		g_aMapLevelLow = new ArrayList(MapSetting_Count);
		g_aMapLevelLowZombies = new ArrayList();
	}
	else
	{
		g_aMapLevelLow.Clear();
		g_aMapLevelLowZombies.Clear();
	}
	
	g_iMapLowZombies = 0;
	for (int i = 0; i < MapSetting_Count; i++)
		g_flMapLowSettings[i] = MAPSETTING_UNSET;
	
	g_iMapLevel = -1;
	g_bMapCaseLevels = false;
	g_bMapConfigLoaded = true;
	
	if (!g_mReinforcementTriggers)
		g_mReinforcementTriggers = new StringMap();
	else
		g_mReinforcementTriggers.Clear();
	
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
			g_iMapLowZombies = MapConfig_ReadLowPlayerCount(kv, g_flMapLowSettings, 0);
			MapConfig_ReadReinforcementTriggers(kv);
			
			if (kv.JumpToKey("levels", false))
			{
				if (kv.GotoFirstSubKey(true))
				{
					do
					{
						char sRelay[64];
						kv.GetSectionName(sRelay, sizeof(sRelay));
						MapConfig_ToLower(sRelay);
						
						int iColon = FindCharInString(sRelay, ':', true);
						if (iColon != -1)
						{
							int iCase = StringToInt(sRelay[iColon + 1]);
							if (1 <= iCase <= 16)
							{
								char sCase[64];
								strcopy(sCase, sizeof(sCase), sRelay);
								sCase[iColon] = '\0';
								FormatEx(sRelay, sizeof(sRelay), "%s:%d", sCase, iCase);
								g_bMapCaseLevels = true;
							}
							else
							{
								LogError("Level \"%s\" in %s is never picked: a logic_case's case number, 1 to 16, goes after the ':'", sRelay, CONFIG_MAPS);
							}
						}
						
						float flLevel[MapSetting_Count];
						for (int i = 0; i < MapSetting_Count; i++)
							flLevel[i] = MAPSETTING_UNSET;
						
						MapConfig_ReadSection(kv, flLevel);
						g_mMapLevels.SetValue(sRelay, g_aMapLevels.PushArray(flLevel));
						
						float flLow[MapSetting_Count];
						g_aMapLevelLowZombies.Push(MapConfig_ReadLowPlayerCount(kv, flLow, g_iMapLowZombies));
						g_aMapLevelLow.PushArray(flLow);
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
	
	MapConfig_CreateLevelRelays();
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

static int MapConfig_ReadLowPlayerCount(KeyValues kv, float flLow[MapSetting_Count], int iInherit)
{
	for (int i = 0; i < MapSetting_Count; i++)
		flLow[i] = MAPSETTING_UNSET;
	
	if (!kv.JumpToKey(MAPCONFIG_LOWPLAYERCOUNT, false))
		return 0;
	
	MapConfig_ReadSection(kv, flLow);
	
	int iZombies = iInherit;
	char sValue[32];
	kv.GetString("StartingZombieCount", sValue, sizeof(sValue));
	TrimString(sValue);
	if (sValue[0])
		iZombies = StringToInt(sValue);
	
	for (int i = 0; i < MapSetting_Count; i++)
	{
		if (MapConfig_IsRatioSetting(i) && flLow[i] != MAPSETTING_UNSET)
		{
			LogError("\"%s\" in a \"%s\" block of %s is ignored: the starting zombie count decides whether the block is used", g_sMapSettingKeys[i], MAPCONFIG_LOWPLAYERCOUNT, CONFIG_MAPS);
			flLow[i] = MAPSETTING_UNSET;
		}
	}
	
	if (iZombies <= 0)
		LogError("A \"%s\" block in %s has no \"StartingZombieCount\" above 0, so it's never used", MAPCONFIG_LOWPLAYERCOUNT, CONFIG_MAPS);
	
	kv.GoBack();
	return iZombies;
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
		if (StrEqual(sValue, "true", false))
			flSettings[i] = 1.0;
		else if (StrEqual(sValue, "false", false))
			flSettings[i] = 0.0;
		else if (StringToFloatEx(sValue, flValue) > 0)
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
	
	bool bLevel = (0 <= g_iMapLevel < g_aMapLevels.Length);
	bool bLow = !MapConfig_IsRatioSetting(iSetting);
	float flValue = g_flMapSettings[iSetting];
	
	if (bLow && MapConfig_IsLowPlayerCount(g_iMapLowZombies) && g_flMapLowSettings[iSetting] != MAPSETTING_UNSET)
		flValue = g_flMapLowSettings[iSetting];
	
	if (bLevel)
	{
		float flLevel = view_as<float>(g_aMapLevels.Get(g_iMapLevel, iSetting));
		if (flLevel != MAPSETTING_UNSET)
			flValue = flLevel;
		
		if (bLow && MapConfig_IsLowPlayerCount(g_aMapLevelLowZombies.Get(g_iMapLevel)))
		{
			float flLow = view_as<float>(g_aMapLevelLow.Get(g_iMapLevel, iSetting));
			if (flLow != MAPSETTING_UNSET)
				flValue = flLow;
		}
	}
	
	return flValue;
}

static bool MapConfig_IsLowPlayerCount(int iMaxZombies)
{
	return iMaxZombies > 0 && 0 <= g_iStartingZombies <= iMaxZombies;
}

void MapConfig_DebugValueSet()
{
	if (!g_bMapConfigLoaded)
		return;
	
	bool bLevel = (0 <= g_iMapLevel < g_aMapLevels.Length) && MapConfig_IsLowPlayerCount(g_aMapLevelLowZombies.Get(g_iMapLevel));
	if (bLevel || MapConfig_IsLowPlayerCount(g_iMapLowZombies))
		CPrintToChatDebug("Map values: %s \"%s\" (%d starting zombies)", bLevel ? "level" : "map", MAPCONFIG_LOWPLAYERCOUNT, g_iStartingZombies);
}

bool MapConfig_BlockManualFrenzy(const char[] sSource)
{
	if (MapConfig_GetSetting(MapSetting_DisableManualFrenzy) == 0.0)
		return false;
	
	CPrintToChatDebug("Map frenzy (%s) ignored: disablemanualfrenzy", sSource);
	return true;
}

bool MapConfig_BlockForcedTank(const char[] sSource = "")
{
	if (MapConfig_GetSetting(MapSetting_DisableForcedTank) == 0.0)
		return false;
	
	if (sSource[0])
		CPrintToChatDebug("Tank (%s) blocked: disableforcedtank", sSource);
	
	return true;
}

static float MapConfig_GetStartingRatio(int iPlayers)
{
	float flRatio = MapConfig_GetSetting(MapSetting_StartingRatio);
	
	float flLowRatio = MapConfig_GetSetting(MapSetting_LowPlayerRatio);
	int iLowMaxPlayers = RoundToFloor(MapConfig_GetSetting(MapSetting_LowPlayerRatioCount));
	if (flLowRatio > 0.0 && iLowMaxPlayers > 0 && iPlayers <= iLowMaxPlayers)
		flRatio = flLowRatio;
	
	if (flRatio < 1.0)
		flRatio = 1.0;
	
	return flRatio;
}

static bool MapConfig_IsRatioSetting(int iSetting)
{
	return iSetting == MapSetting_StartingRatio || iSetting == MapSetting_LowPlayerRatio || iSetting == MapSetting_LowPlayerRatioCount;
}

int MapConfig_GetStartingZombies(int iPlayers)
{
	if (iPlayers < 2)
		return 0;
	
	float flRatio = MapConfig_GetStartingRatio(iPlayers);
	
	int iZombies = RoundToCeil(float(iPlayers) / flRatio - 0.001);
	if (iZombies < 1)
		iZombies = 1;
	
	if (iZombies > iPlayers - 1)
		iZombies = iPlayers - 1;
	
	CPrintToChatDebug("Starting zombies: %d of %d players (starting ratio %.2f)", iZombies, iPlayers, flRatio);
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
	
	MapConfig_PickLevel(sRelay);
}

void MapConfig_OnCaseTrigger(int iEntity, const char[] sOutput)
{
	if (!g_bMapCaseLevels || !g_mMapLevels)
		return;
	
	char sTargetName[64];
	GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
	if (!sTargetName[0])
		return;
	
	char sNumber[16];
	strcopy(sNumber, sizeof(sNumber), sOutput);
	ReplaceString(sNumber, sizeof(sNumber), "OnCase", "", false);
	
	char sLevel[64];
	FormatEx(sLevel, sizeof(sLevel), "%s:%d", sTargetName, StringToInt(sNumber));
	MapConfig_ToLower(sLevel);
	
	MapConfig_PickLevel(sLevel);
}

static void MapConfig_PickLevel(const char[] sLevel)
{
	int iLevel;
	if (!g_mMapLevels.GetValue(sLevel, iLevel))
		return;
	
	g_iMapLevel = iLevel;
	strcopy(g_sMapLevel, sizeof(g_sMapLevel), sLevel);
	CPrintToChatDebug("Map level picked: %s (starting ratio %.2f)", sLevel, MapConfig_GetSetting(MapSetting_StartingRatio));
	MapConfig_DebugValueSet();
	
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

void MapConfig_CreateLevelRelays()
{
	if (!g_mMapLevels || !g_mMapLevels.Size)
		return;
	
	int iMade;
	StringMapSnapshot snapshot = g_mMapLevels.Snapshot();
	int iLength = snapshot.Length;
	for (int i = 0; i < iLength; i++)
	{
		char sRelay[64];
		snapshot.GetKey(i, sRelay, sizeof(sRelay));
		if (StrContains(sRelay, ":") != -1 || MapConfig_HasRelay(sRelay))
			continue;
		
		int iRelay = CreateEntityByName("logic_relay");
		if (!IsValidEntity(iRelay))
			continue;
		
		DispatchKeyValue(iRelay, "targetname", sRelay);
		DispatchKeyValue(iRelay, "spawnflags", "2");
		DispatchSpawn(iRelay);
		iMade++;
	}
	
	delete snapshot;
	
	if (iMade)
		CPrintToChatDebug("Map level relays made by the plugin: %d", iMade);
}

static bool MapConfig_HasRelay(const char[] sRelay)
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "logic_relay")) != -1)
	{
		char sTargetName[64];
		GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
		if (StrEqual(sTargetName, sRelay, false))
			return true;
	}
	
	return false;
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
	
	g_iStartingZombies = MapConfig_GetStartingZombies(iPlayers);
	MapConfig_DebugValueSet();
	int iWantSurvivors = iPlayers - g_iStartingZombies;
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

float MapConfig_GetZombieDamage()
{
	float flValue = MapConfig_GetSetting(MapSetting_ZombieDamage);
	return flValue >= 0.0 ? flValue : g_cvZombieDamage.FloatValue;
}

float MapConfig_GetRareWeaponChance()
{
	float flValue = MapConfig_GetSetting(MapSetting_RareWeaponChance);
	return flValue >= 0.0 ? flValue : g_cvWeaponRareChance.FloatValue;
}

static void MapConfig_ReadReinforcementTriggers(KeyValues kv)
{
	char sRelay[256];
	kv.GetString(MAPCONFIG_REINFORCEMENTRELAY, sRelay, sizeof(sRelay));
	TrimString(sRelay);
	if (sRelay[0])
	{
		char sKey[300];
		MapConfig_TriggerKey("relay", sRelay, sKey, sizeof(sKey));
		g_mReinforcementTriggers.SetValue(sKey, true);
	}
	
	if (!kv.JumpToKey(MAPCONFIG_REINFORCEMENTTRIGGERS, false))
		return;
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char sType[16], sName[256];
			kv.GetSectionName(sType, sizeof(sType));
			kv.GetString(NULL_STRING, sName, sizeof(sName));
			TrimString(sName);
			MapConfig_ToLower(sType);
			
			if (!StrEqual(sType, "relay") && !StrEqual(sType, "capture"))
				LogError("\"%s\" in a \"%s\" block of %s is ignored: use \"relay\" or \"capture\"", sType, MAPCONFIG_REINFORCEMENTTRIGGERS, CONFIG_MAPS);
			else if (sName[0])
			{
				char sKey[300];
				MapConfig_TriggerKey(sType, sName, sKey, sizeof(sKey));
				g_mReinforcementTriggers.SetValue(sKey, true);
			}
		}
		while (kv.GotoNextKey(false));
		
		kv.GoBack();
	}
	
	kv.GoBack();
}

bool MapConfig_IsReinforcementTrigger(const char[] sType, const char[] sName)
{
	if (!g_mReinforcementTriggers || !g_mReinforcementTriggers.Size || !sName[0])
		return false;
	
	char sKey[300];
	MapConfig_TriggerKey(sType, sName, sKey, sizeof(sKey));
	return g_mReinforcementTriggers.ContainsKey(sKey);
}

static void MapConfig_TriggerKey(const char[] sType, const char[] sName, char[] sKey, int iLength)
{
	Format(sKey, iLength, "%s:%s", sType, sName);
	MapConfig_ToLower(sKey);
}
