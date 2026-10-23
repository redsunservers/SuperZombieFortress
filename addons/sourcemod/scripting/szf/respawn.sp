#define RESPAWN_TF2_WAVE_MARGIN	5.0
#define FRENZY_SPECIAL_DEATHS	5

enum
{
	RespawnPhase_None = 0,
	RespawnPhase_PreFrenzy,
	RespawnPhase_Frenzy1,
	RespawnPhase_PostFrenzy,
	RespawnPhase_Frenzy2,
	RespawnPhase_Final
}

static int g_iRespawnPhase;
static float g_flRespawnPhaseStart;
static bool g_bRespawnTimelineFrenzy;
static float g_flZombieRespawnAt[MAXPLAYERS + 1];
static int g_iRespawnPlayerManager = INVALID_ENT_REFERENCE;
static int g_iFrenzyZombieDeaths;

static bool g_bSpecialPartner[MAXPLAYERS + 1];
static bool g_bForcedSniper[MAXPLAYERS + 1];
static int g_iPendingPartners[view_as<int>(Infected_Count)];

void Respawn_OnRoundRespawn()
{
	g_iRespawnPhase = RespawnPhase_None;
	g_bRespawnTimelineFrenzy = false;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_flZombieRespawnAt[iClient] = 0.0;
		g_bSpecialPartner[iClient] = false;
		g_bForcedSniper[iClient] = false;
	}
	
	for (int i = 0; i < sizeof(g_iPendingPartners); i++)
		g_iPendingPartners[i] = 0;
}

void Respawn_OnRoundActive()
{
	Respawn_SetPhase(RespawnPhase_PreFrenzy);
}

void Respawn_OnRoundEnd()
{
	g_iRespawnPhase = RespawnPhase_None;
}

static void Respawn_SetPhase(int iPhase)
{
	g_iRespawnPhase = iPhase;
	g_flRespawnPhaseStart = GetGameTime();
	CPrintToChatDebug("Respawn timeline phase %d, zombie respawn time %.0fs", iPhase, Respawn_GetTime());
}

void Respawn_Update()
{
	if (g_nRoundState == SZFRoundState_Active)
	{
		switch (g_iRespawnPhase)
		{
			case RespawnPhase_PreFrenzy:
			{
				if (Respawn_IsFrenzyDue(MapConfig_GetSetting(MapSetting_StartRespawnTime), MapConfig_GetSetting(MapSetting_PreFrenzyRate)))
					Respawn_StartFrenzy(RespawnPhase_Frenzy1);
			}
			case RespawnPhase_PostFrenzy:
			{
				if (Respawn_IsFrenzyDue(MapConfig_GetSetting(MapSetting_PostFrenzyRespawnTime), MapConfig_GetSetting(MapSetting_PostFrenzyRate)))
					Respawn_StartFrenzy(RespawnPhase_Frenzy2);
			}
		}
	}
	
	if (g_bZombieRage)
		SetTeamRespawnWaveTime(TFTeam_Zombie, 0.0);
	else
		SetTeamRespawnWaveTime(TFTeam_Zombie, Respawn_GetTime() + RESPAWN_TF2_WAVE_MARGIN);
}

float Respawn_GetTime()
{
	if (g_bZombieRage)
		return 0.0;
	
	switch (g_iRespawnPhase)
	{
		case RespawnPhase_PreFrenzy:
		{
			return Respawn_CountDown(MapConfig_GetSetting(MapSetting_StartRespawnTime), MapConfig_GetSetting(MapSetting_PreFrenzyRate));
		}
		case RespawnPhase_PostFrenzy:
		{
			return Respawn_CountDown(MapConfig_GetSetting(MapSetting_PostFrenzyRespawnTime), MapConfig_GetSetting(MapSetting_PostFrenzyRate));
		}
		case RespawnPhase_Frenzy1, RespawnPhase_Frenzy2:
		{
			return 0.0;
		}
		case RespawnPhase_Final:
		{
			return fMax(0.0, MapConfig_GetSetting(MapSetting_Post2ndFrenzyRespawnTime));
		}
	}
	
	return fMax(0.0, MapConfig_GetSetting(MapSetting_StartRespawnTime));
}

static int Respawn_GetSteps(float flRate)
{
	if (flRate <= 0.0)
		return 0;
	
	return RoundToFloor((GetGameTime() - g_flRespawnPhaseStart) / flRate);
}

static float Respawn_CountDown(float flStart, float flRate)
{
	float flHold = MapConfig_GetSetting(MapSetting_FrenzyRespawnTime);
	if (flHold > flStart)
		flHold = flStart;
	
	float flTime = flStart - float(Respawn_GetSteps(flRate));
	if (flTime < flHold)
		flTime = flHold;
	
	return fMax(0.0, flTime);
}

static bool Respawn_IsFrenzyDue(float flStart, float flRate)
{
	int iSteps = Respawn_GetSteps(flRate);
	return iSteps > 0 && flStart - float(iSteps) <= MapConfig_GetSetting(MapSetting_FrenzyRespawnTime);
}

static void Respawn_StartFrenzy(int iPhase)
{
	if (g_bZombieRage || g_bNoDirectorRages || ZombiesHaveTank() || ZombiesTankComing())
		return;
	
	float flDuration = MapConfig_GetSetting(MapSetting_FrenzyDuration);
	if (flDuration < 1.0)
		flDuration = 1.0;
	
	ZombieRage(flDuration, true);
	if (!g_bZombieRage)
		return;
	
	g_bRespawnTimelineFrenzy = true;
	Respawn_SetPhase(iPhase);
}

void Respawn_OnFrenzyStart()
{
	g_iFrenzyZombieDeaths = 0;
}

void Respawn_OnFrenzyEnd()
{
	if (!g_bRespawnTimelineFrenzy)
		return;
	
	g_bRespawnTimelineFrenzy = false;
	
	if (g_iRespawnPhase == RespawnPhase_Frenzy1)
		Respawn_SetPhase(RespawnPhase_PostFrenzy);
	else if (g_iRespawnPhase == RespawnPhase_Frenzy2)
		Respawn_SetPhase(RespawnPhase_Final);
}

void Respawn_ScheduleZombie(int iClient, float flDelay)
{
	if (flDelay < 0.1)
		flDelay = 0.1;
	
	g_flZombieRespawnAt[iClient] = GetGameTime() + flDelay;
	CreateTimer(flDelay, Timer_RespawnZombie, GetClientSerial(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_RespawnZombie(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient || !IsClientInGame(iClient) || IsPlayerAlive(iClient) || !IsZombie(iClient))
		return Plugin_Continue;
	
	if (!g_bEnabled || g_nRoundState != SZFRoundState_Active)
		return Plugin_Continue;
	
	if (GetGameTime() < g_flZombieRespawnAt[iClient] - 0.05)
		return Plugin_Continue;
	
	TF2_RespawnPlayer2(iClient);
	return Plugin_Continue;
}

void Respawn_OnSpawn(int iClient)
{
	g_flZombieRespawnAt[iClient] = 0.0;
}

void Respawn_ClientDisconnect(int iClient)
{
	g_flZombieRespawnAt[iClient] = 0.0;
	g_bSpecialPartner[iClient] = false;
	g_bForcedSniper[iClient] = false;
}

void Respawn_HookPlayerManager()
{
	int iEntity = FindEntityByClassname(-1, "tf_player_manager");
	if (iEntity == -1 || EntRefToEntIndex(g_iRespawnPlayerManager) == iEntity)
		return;
	
	g_iRespawnPlayerManager = EntIndexToEntRef(iEntity);
	SDKHook(iEntity, SDKHook_ThinkPost, Respawn_PlayerManagerThinkPost);
}

public void Respawn_PlayerManagerThinkPost(int iEntity)
{
	if (!g_bEnabled || g_nRoundState != SZFRoundState_Active)
		return;
	
	float flGameTime = GetGameTime();
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_flZombieRespawnAt[iClient] <= flGameTime || !IsClientInGame(iClient) || IsPlayerAlive(iClient) || !IsZombie(iClient))
			continue;
		
		float flTF2Time = GetEntPropFloat(iEntity, Prop_Send, "m_flNextRespawnTime", iClient);
		if (flTF2Time <= 0.0 || g_flZombieRespawnAt[iClient] < flTF2Time)
			SetEntPropFloat(iEntity, Prop_Send, "m_flNextRespawnTime", g_flZombieRespawnAt[iClient], iClient);
	}
}

void Respawn_OnFrenzyZombieDeath(int iVictim)
{
	g_iFrenzyZombieDeaths++;
	if (g_iFrenzyZombieDeaths % FRENZY_SPECIAL_DEATHS != 0)
		return;
	
	int iClient = iVictim;
	if (!Respawn_CanGetSpecial(iClient))
		iClient = Respawn_FindSpecialCandidate();
	
	if (!iClient && IsValidZombie(iVictim))
		iClient = iVictim;
	
	if (!iClient)
		return;
	
	if (SpecialQueue_Add(iClient, "frenzy"))
		g_bSpecialIgnoreCooldown[iClient] = true;
}

static bool Respawn_CanGetSpecial(int iClient)
{
	return IsValidZombie(iClient) && !SpecialQueue_Has(iClient) && g_nNextInfected[iClient] == Infected_None;
}

static int Respawn_FindSpecialCandidate()
{
	int iDead[MAXPLAYERS], iAlive[MAXPLAYERS];
	int iDeadCount, iAliveCount;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!Respawn_CanGetSpecial(iClient))
			continue;
		
		if (!IsPlayerAlive(iClient))
			iDead[iDeadCount++] = iClient;
		else if (g_nInfected[iClient] == Infected_None)
			iAlive[iAliveCount++] = iClient;
	}
	
	if (iDeadCount > 0)
		return iDead[GetRandomInt(0, iDeadCount - 1)];
	
	if (iAliveCount > 0)
		return iAlive[GetRandomInt(0, iAliveCount - 1)];
	
	return 0;
}

void Respawn_OnSpecialPicked(int iClient, Infected nInfected)
{
	if (nInfected != Infected_Spitter && nInfected != Infected_Jockey)
		return;
	
	int iPartner = Respawn_FindDeadZombie(iClient);
	if (!iPartner)
	{
		g_iPendingPartners[view_as<int>(nInfected)]++;
		return;
	}
	
	g_nNextInfected[iPartner] = nInfected;
	g_bSpecialPartner[iPartner] = true;
	RequestFrame(Frame_RespawnGroupMember, GetClientSerial(iPartner));
}

Infected Respawn_TakePendingPartner(int iClient)
{
	for (int i = 0; i < sizeof(g_iPendingPartners); i++)
	{
		if (g_iPendingPartners[i] <= 0 || !IsValidInfected(view_as<Infected>(i)))
			continue;
		
		g_iPendingPartners[i]--;
		g_bSpecialPartner[iClient] = true;
		return view_as<Infected>(i);
	}
	
	return Infected_None;
}

bool Respawn_TakePartnerSpawn(int iClient)
{
	bool bPartner = g_bSpecialPartner[iClient];
	g_bSpecialPartner[iClient] = false;
	return bPartner;
}

void Respawn_OnBoomerSpawn(int iBoomer)
{
	float flWindow = g_cvBoomerPackWindow.FloatValue;
	if (flWindow <= 0.0 || !IsValidZombieClass(TFClass_Sniper))
		return;
	
	float flLimit = GetGameTime() + flWindow;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (iClient == iBoomer || !IsValidZombie(iClient) || IsPlayerAlive(iClient))
			continue;
		
		if (g_flZombieRespawnAt[iClient] <= 0.0 || g_flZombieRespawnAt[iClient] > flLimit)
			continue;
		
		if (g_nNextInfected[iClient] != Infected_None || SpecialQueue_Has(iClient) || g_bSpecialPartner[iClient])
			continue;
		
		g_bForcedSniper[iClient] = true;
		RequestFrame(Frame_RespawnGroupMember, GetClientSerial(iClient));
	}
}

bool Respawn_TakeForcedSniper(int iClient)
{
	bool bSniper = g_bForcedSniper[iClient];
	g_bForcedSniper[iClient] = false;
	return bSniper;
}

void Frame_RespawnGroupMember(int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient || !IsClientInGame(iClient) || IsPlayerAlive(iClient) || !IsZombie(iClient))
		return;
	
	if (!g_bEnabled || g_nRoundState != SZFRoundState_Active)
		return;
	
	TF2_RespawnPlayer2(iClient);
}

static int Respawn_FindDeadZombie(int iIgnore)
{
	int iBest;
	float flBest;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (iClient == iIgnore || !IsValidZombie(iClient) || IsPlayerAlive(iClient))
			continue;
		
		if (g_nNextInfected[iClient] != Infected_None || SpecialQueue_Has(iClient) || g_bSpecialPartner[iClient] || g_bForcedSniper[iClient])
			continue;
		
		float flRespawnAt = g_flZombieRespawnAt[iClient];
		if (flRespawnAt <= 0.0)
			flRespawnAt = GetGameTime() + 99999.0;
		
		if (!iBest || flRespawnAt < flBest)
		{
			iBest = iClient;
			flBest = flRespawnAt;
		}
	}
	
	return iBest;
}
