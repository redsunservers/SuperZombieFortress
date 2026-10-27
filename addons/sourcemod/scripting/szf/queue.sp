static Cookie g_cQueuePoints;

static ConVar g_cvQueueEnable;
static ConVar g_cvQueueBase;
static ConVar g_cvQueueKills;
static ConVar g_cvQueueKillsMax;
static ConVar g_cvQueueSurvivorKills;
static ConVar g_cvQueueSurvivorKillsMax;
static ConVar g_cvQueueHeal;
static ConVar g_cvQueueHealMax;

static int g_iQueuePoints[MAXPLAYERS + 1];
static bool g_bQueuePendingReset[MAXPLAYERS + 1];
static int g_iQueuePendingGain[MAXPLAYERS + 1];
static int g_iQueueZombieKills[MAXPLAYERS + 1];
static int g_iQueueSurvivorKills[MAXPLAYERS + 1];
static int g_iQueueHealing[MAXPLAYERS + 1];

void Queue_Init()
{
	g_cQueuePoints = PrefSave_NewCookie("szf_queue_points", "Zombie queue points: the players with the most start the next round as zombies.", CookieAccess_Protected);
	
	g_cvQueueEnable = CreateConVar("sm_szf_queue_enable", "1", "<0/1> Pick who starts as zombie with the zombie queue (most queue points first). 0 = the old least-recent-zombie rotation, and queue points stop changing.", _, true, 0.0, true, 1.0);
	g_cvQueueBase = CreateConVar("sm_szf_queue_base", "20", "Queue points every player on a team (or in spectator) gains at round end, before reductions. Players who started the round as zombie gain nothing and stay on 0.", _, true, 0.0);
	g_cvQueueKills = CreateConVar("sm_szf_queue_kills", "10", "Zombies (specials and the Tank included) a survivor kills in a round for each queue point taken off. 0 to disable.", _, true, 0.0);
	g_cvQueueKillsMax = CreateConVar("sm_szf_queue_kills_max", "10", "Most queue points zombie kills can take off in a round.", _, true, 0.0);
	g_cvQueueSurvivorKills = CreateConVar("sm_szf_queue_survivor_kills", "1", "Survivors a player kills as a zombie in a round for each queue point taken off. 0 to disable.", _, true, 0.0);
	g_cvQueueSurvivorKillsMax = CreateConVar("sm_szf_queue_survivor_kills_max", "10", "Most queue points survivor kills can take off in a round.", _, true, 0.0);
	g_cvQueueHeal = CreateConVar("sm_szf_queue_heal", "1000", "Health a survivor heals other survivors for in a round for each queue point taken off. 0 to disable.", _, true, 0.0);
	g_cvQueueHealMax = CreateConVar("sm_szf_queue_heal_max", "10", "Most queue points healing can take off in a round.", _, true, 0.0);
}

bool Queue_IsEnabled()
{
	return g_cvQueueEnable.BoolValue;
}

int Queue_GetPoints(int iClient)
{
	if (Queue_StartedAsZombie(iClient))
		return 0;
	
	return g_iQueuePoints[iClient];
}

void Queue_OnClientPutInServer(int iClient)
{
	g_iQueuePoints[iClient] = 0;
	g_bQueuePendingReset[iClient] = false;
	g_iQueuePendingGain[iClient] = 0;
	g_iQueueZombieKills[iClient] = 0;
	g_iQueueSurvivorKills[iClient] = 0;
	g_iQueueHealing[iClient] = 0;
}

void Queue_OnClientDisconnect(int iClient)
{
	g_bQueuePendingReset[iClient] = false;
	g_iQueuePendingGain[iClient] = 0;
}

void Queue_OnClientCookiesCached(int iClient)
{
	char sValue[16];
	g_cQueuePoints.Get(iClient, sValue, sizeof(sValue));
	g_iQueuePoints[iClient] = StringToInt(sValue);
	
	if (g_bQueuePendingReset[iClient] || g_iQueuePendingGain[iClient] != 0)
	{
		if (g_bQueuePendingReset[iClient])
			g_iQueuePoints[iClient] = 0;
		
		g_iQueuePoints[iClient] += g_iQueuePendingGain[iClient];
		g_bQueuePendingReset[iClient] = false;
		g_iQueuePendingGain[iClient] = 0;
		Queue_SaveCookie(iClient);
	}
}

int Sort_ZombieQueue(int iClient1, int iClient2, const int[] iClients, Handle hData)
{
	if (g_cvQueueEnable.BoolValue)
	{
		int iPoints1 = Queue_GetPoints(iClient1);
		int iPoints2 = Queue_GetPoints(iClient2);
		
		if (iPoints1 < iPoints2)
			return -1;
		else if (iPoints1 > iPoints2)
			return 1;
	}
	
	return Compare_LastPlayedZombie(iClient1, iClient2);
}

int Queue_GetOrder(int[] iClients)
{
	int iLength;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient) && (TF2_GetClientTeam(iClient) != TFTeam_Spectator || Split_ShouldPlaceSpectator(iClient)))
			iClients[iLength++] = iClient;
	
	SortCustom1D(iClients, iLength, Sort_ZombieQueue);
	return iLength;
}

void Queue_OnRoundRespawn()
{
	Queue_ResetRound();
}

void Queue_OnPlayerDeath(int iVictim, int iKiller, bool bDeadRinger)
{
	if (bDeadRinger || iKiller == iVictim || !Queue_IsRoundPlaying())
		return;
	
	if (IsValidSurvivor(iVictim) && IsValidZombie(iKiller))
		g_iQueueSurvivorKills[iKiller]++;
	else if (IsValidZombie(iVictim) && IsValidSurvivor(iKiller))
		g_iQueueZombieKills[iKiller]++;
}

void Queue_OnPlayerHealed(int iPatient, int iHealer, int iAmount)
{
	if (iHealer == iPatient || iAmount <= 0 || !IsValidSurvivor(iHealer) || !IsValidSurvivor(iPatient) || !Queue_IsRoundPlaying())
		return;
	
	g_iQueueHealing[iHealer] += iAmount;
}

void Queue_OnRoundEnd()
{
	if (g_cvQueueEnable.BoolValue && Queue_IsRoundPlaying())
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (!IsClientInGame(iClient))
				continue;
			
			TFTeam nTeam = TF2_GetClientTeam(iClient);
			bool bSpectator = (nTeam == TFTeam_Spectator && !IsFakeClient(iClient));
			if (nTeam <= TFTeam_Spectator && !bSpectator)
				continue;
			
			if (Queue_StartedAsZombie(iClient))
			{
				Queue_ChangePoints(iClient, true, 0);
				
				if (!IsFakeClient(iClient))
					CPrintToChat(iClient, "%t", "Queue_RoundZombie", "{limegreen}", "{lightsalmon}");
				
				continue;
			}
			
			Queue_AwardRound(iClient, bSpectator);
		}
	}
	
	Queue_ResetRound();
}

static void Queue_AwardRound(int iClient, bool bSpectator)
{
	int iGain = g_cvQueueBase.IntValue;
	if (!bSpectator)
	{
		iGain -= Queue_GetReduction(g_iQueueZombieKills[iClient], g_cvQueueKills.IntValue, g_cvQueueKillsMax.IntValue);
		iGain -= Queue_GetReduction(g_iQueueSurvivorKills[iClient], g_cvQueueSurvivorKills.IntValue, g_cvQueueSurvivorKillsMax.IntValue);
		iGain -= Queue_GetReduction(g_iQueueHealing[iClient], g_cvQueueHeal.IntValue, g_cvQueueHealMax.IntValue);
	}
	
	Queue_ChangePoints(iClient, false, iGain);
	
	if (IsFakeClient(iClient))
		return;
	
	CPrintToChat(iClient, "%t", "Queue_RoundSurvivor", "{limegreen}", "{lightsalmon}", iGain, g_iQueuePoints[iClient]);
}

static bool Queue_StartedAsZombie(int iClient)
{
	return g_iRoundPlayedCount > 0 && GetRoundPlayedAsZombie(iClient) == g_iRoundPlayedCount;
}

static void Queue_ChangePoints(int iClient, bool bReset, int iGain)
{
	if (bReset)
		g_iQueuePoints[iClient] = 0;
	
	g_iQueuePoints[iClient] += iGain;
	
	if (IsFakeClient(iClient))
		return;
	
	if (AreClientCookiesCached(iClient))
	{
		Queue_SaveCookie(iClient);
	}
	else
	{
		if (bReset)
		{
			g_bQueuePendingReset[iClient] = true;
			g_iQueuePendingGain[iClient] = 0;
		}
		
		g_iQueuePendingGain[iClient] += iGain;
	}
}

static void Queue_SaveCookie(int iClient)
{
	char sValue[16];
	IntToString(g_iQueuePoints[iClient], sValue, sizeof(sValue));
	PrefSave_SetCookie(iClient, g_cQueuePoints, sValue);
}

static int Queue_GetReduction(int iCount, int iPer, int iMax)
{
	if (iPer <= 0 || iMax <= 0)
		return 0;
	
	int iReduction = iCount / iPer;
	if (iReduction > iMax)
		iReduction = iMax;
	
	return iReduction;
}

static void Queue_ResetRound()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_iQueueZombieKills[iClient] = 0;
		g_iQueueSurvivorKills[iClient] = 0;
		g_iQueueHealing[iClient] = 0;
	}
}

static bool Queue_IsRoundPlaying()
{
	return g_nRoundState == SZFRoundState_Grace || g_nRoundState == SZFRoundState_Active;
}
