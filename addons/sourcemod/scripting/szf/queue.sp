enum struct QueueSave
{
	int iSaver;
	int iPatient;
	float flConfirmAt;
}

static Cookie g_cQueuePoints;

static ConVar g_cvQueueEnable;
static ConVar g_cvQueueBase;
static ConVar g_cvQueueKills;
static ConVar g_cvQueueKillsMax;
static ConVar g_cvQueueSpecials;
static ConVar g_cvQueueSpecialsMax;
static ConVar g_cvQueueWin;
static ConVar g_cvQueueSavesMax;
static ConVar g_cvQueueSaveHealth;
static ConVar g_cvQueueSaveHitWindow;
static ConVar g_cvQueueSaveKillTime;
static ConVar g_cvQueueSaveHealTime;

static int g_iQueuePoints[MAXPLAYERS + 1];
static bool g_bQueuePendingReset[MAXPLAYERS + 1];
static int g_iQueuePendingGain[MAXPLAYERS + 1];
static int g_iQueueZombieKills[MAXPLAYERS + 1];
static int g_iQueueSpecialKills[MAXPLAYERS + 1];
static int g_iQueueSaves[MAXPLAYERS + 1];
static float g_flQueueZombieHit[MAXPLAYERS + 1][MAXPLAYERS + 1];
static float g_flQueueLastZombieHit[MAXPLAYERS + 1];
static ArrayList g_aQueueSaves;

void Queue_Init()
{
	g_cQueuePoints = PrefSave_NewCookie("szf_queue_points", "Zombie queue points: the players with the most start the next round as zombies.", CookieAccess_Protected);
	g_aQueueSaves = new ArrayList(sizeof(QueueSave));
	
	g_cvQueueEnable = CreateConVar("sm_szf_queue_enable", "1", "<0/1> Pick who starts as zombie with the zombie queue (most queue points first). 0 = the old least-recent-zombie rotation, and queue points stop changing.", _, true, 0.0, true, 1.0);
	g_cvQueueBase = CreateConVar("sm_szf_queue_base", "20", "Queue points every player on a team gains at round end, before reductions. Players who started the round as zombie gain nothing and stay on 0.", _, true, 0.0);
	g_cvQueueKills = CreateConVar("sm_szf_queue_kills", "15", "Zombies (specials included) a survivor kills in a round for each queue point taken off. 0 to disable.", _, true, 0.0);
	g_cvQueueKillsMax = CreateConVar("sm_szf_queue_kills_max", "5", "Most queue points zombie kills can take off in a round.", _, true, 0.0);
	g_cvQueueSpecials = CreateConVar("sm_szf_queue_specials", "5", "Special infected (the Tank included) a survivor kills in a round for each queue point taken off. 0 to disable.", _, true, 0.0);
	g_cvQueueSpecialsMax = CreateConVar("sm_szf_queue_specials_max", "3", "Most queue points special infected kills can take off in a round.", _, true, 0.0);
	g_cvQueueWin = CreateConVar("sm_szf_queue_win", "5", "Queue points taken off every survivor alive when the survivors win.", _, true, 0.0);
	g_cvQueueSavesMax = CreateConVar("sm_szf_queue_saves_max", "10", "Most queue points saves can take off in a round (1 per save).", _, true, 0.0);
	g_cvQueueSaveHealth = CreateConVar("sm_szf_queue_save_health", "0.2", "A save needs the saved survivor under this share of their max health.", _, true, 0.0, true, 1.0);
	g_cvQueueSaveHitWindow = CreateConVar("sm_szf_queue_save_hit_window", "5.0", "A save needs the saved survivor to have been hit by a zombie (for a kill save: the killed zombie) within this many seconds.", _, true, 0.0);
	g_cvQueueSaveKillTime = CreateConVar("sm_szf_queue_save_kill_time", "30.0", "Seconds the saved survivor must stay alive after a kill save for it to count.", _, true, 0.0);
	g_cvQueueSaveHealTime = CreateConVar("sm_szf_queue_save_heal_time", "60.0", "Seconds the saved survivor must stay alive after a heal save for it to count.", _, true, 0.0);
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
	g_iQueueSpecialKills[iClient] = 0;
	g_iQueueSaves[iClient] = 0;
	g_flQueueLastZombieHit[iClient] = 0.0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_flQueueZombieHit[iClient][i] = 0.0;
		g_flQueueZombieHit[i][iClient] = 0.0;
	}
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
		if (IsClientInGame(iClient) && TF2_GetClientTeam(iClient) != TFTeam_Spectator)
			iClients[iLength++] = iClient;
	
	SortCustom1D(iClients, iLength, Sort_ZombieQueue);
	return iLength;
}

void Queue_OnRoundRespawn()
{
	Queue_ResetRound();
}

void Queue_OnPlayerHurt(int iVictim, int iAttacker)
{
	if (!IsZombie(iAttacker) || !IsSurvivor(iVictim))
		return;
	
	float flNow = GetGameTime();
	g_flQueueZombieHit[iAttacker][iVictim] = flNow;
	g_flQueueLastZombieHit[iVictim] = flNow;
}

void Queue_OnPlayerDeath(int iVictim, int iKiller, bool bDeadRinger)
{
	if (bDeadRinger)
		return;
	
	if (IsValidSurvivor(iVictim))
	{
		int iUserId = GetClientUserId(iVictim);
		for (int i = g_aQueueSaves.Length - 1; i >= 0; i--)
			if (g_aQueueSaves.Get(i, QueueSave::iPatient) == iUserId)
				g_aQueueSaves.Erase(i);
		
		return;
	}
	
	if (!IsValidZombie(iVictim))
		return;
	
	if (IsValidSurvivor(iKiller) && Queue_IsRoundPlaying())
	{
		g_iQueueZombieKills[iKiller]++;
		if (g_nInfected[iVictim] != Infected_None)
			g_iQueueSpecialKills[iKiller]++;
		
		for (int iPatient = 1; iPatient <= MaxClients; iPatient++)
		{
			if (iPatient == iKiller || !Queue_IsRecentHit(g_flQueueZombieHit[iVictim][iPatient]))
				continue;
			
			if (IsValidLivingSurvivor(iPatient) && Queue_IsLowHealth(iPatient, GetClientHealth(iPatient)))
				Queue_AddSave(iKiller, iPatient, g_cvQueueSaveKillTime.FloatValue);
		}
	}
	
	for (int i = 1; i <= MaxClients; i++)
		g_flQueueZombieHit[iVictim][i] = 0.0;
}

void Queue_OnPlayerHealed(int iPatient, int iHealer, int iAmount)
{
	if (iHealer == iPatient || !IsValidSurvivor(iHealer) || !IsValidLivingSurvivor(iPatient) || !Queue_IsRoundPlaying())
		return;
	
	if (Queue_IsRecentHit(g_flQueueLastZombieHit[iPatient]) && Queue_IsLowHealth(iPatient, GetClientHealth(iPatient) - iAmount))
		Queue_AddSave(iHealer, iPatient, g_cvQueueSaveHealTime.FloatValue);
}

void Queue_Update()
{
	if (!Queue_IsRoundPlaying())
		return;
	
	float flNow = GetGameTime();
	for (int i = g_aQueueSaves.Length - 1; i >= 0; i--)
	{
		QueueSave save;
		g_aQueueSaves.GetArray(i, save);
		if (save.flConfirmAt > flNow)
			continue;
		
		g_aQueueSaves.Erase(i);
		Queue_ConfirmSave(save);
	}
}

void Queue_OnRoundEnd(TFTeam nWinner)
{
	if (g_cvQueueEnable.BoolValue && Queue_IsRoundPlaying())
	{
		int iLength = g_aQueueSaves.Length;
		for (int i = 0; i < iLength; i++)
		{
			QueueSave save;
			g_aQueueSaves.GetArray(i, save);
			Queue_ConfirmSave(save);
		}
		
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (!IsClientInGame(iClient) || TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
				continue;
			
			if (Queue_StartedAsZombie(iClient))
			{
				Queue_ChangePoints(iClient, true, 0);
				
				if (!IsFakeClient(iClient))
					CPrintToChat(iClient, "%t", "Queue_RoundZombie", "{limegreen}", "{lightsalmon}");
				
				continue;
			}
			
			Queue_AwardRound(iClient, nWinner);
		}
	}
	
	Queue_ResetRound();
}

static void Queue_AwardRound(int iClient, TFTeam nWinner)
{
	int iBase = g_cvQueueBase.IntValue;
	int iKills = Queue_GetReduction(g_iQueueZombieKills[iClient], g_cvQueueKills.IntValue, g_cvQueueKillsMax.IntValue);
	int iSpecials = Queue_GetReduction(g_iQueueSpecialKills[iClient], g_cvQueueSpecials.IntValue, g_cvQueueSpecialsMax.IntValue);
	int iSaves = Queue_GetReduction(g_iQueueSaves[iClient], 1, g_cvQueueSavesMax.IntValue);
	
	int iWin = 0;
	if (nWinner == TFTeam_Survivor && IsSurvivor(iClient) && IsPlayerAlive(iClient))
		iWin = g_cvQueueWin.IntValue;
	
	int iGain = iBase - iKills - iSpecials - iWin - iSaves;
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

static void Queue_AddSave(int iSaver, int iPatient, float flTime)
{
	if (!g_cvQueueEnable.BoolValue)
		return;
	
	int iSaverId = GetClientUserId(iSaver);
	int iPatientId = GetClientUserId(iPatient);
	
	int iLength = g_aQueueSaves.Length;
	for (int i = 0; i < iLength; i++)
	{
		QueueSave save;
		g_aQueueSaves.GetArray(i, save);
		if (save.iSaver == iSaverId && save.iPatient == iPatientId)
			return;
	}
	
	QueueSave save;
	save.iSaver = iSaverId;
	save.iPatient = iPatientId;
	save.flConfirmAt = GetGameTime() + flTime;
	g_aQueueSaves.PushArray(save);
}

static void Queue_ConfirmSave(QueueSave save)
{
	int iSaver = GetClientOfUserId(save.iSaver);
	int iPatient = GetClientOfUserId(save.iPatient);
	
	if (!iSaver || !IsClientInGame(iSaver) || !IsValidLivingSurvivor(iPatient))
		return;
	
	g_iQueueSaves[iSaver]++;
	
	if (!IsFakeClient(iSaver))
		CPrintToChat(iSaver, "%t", "Queue_SaveConfirmed", "{limegreen}", "{lightsalmon}", iPatient, g_iQueueSaves[iSaver]);
}

static void Queue_ResetRound()
{
	g_aQueueSaves.Clear();
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_iQueueZombieKills[iClient] = 0;
		g_iQueueSpecialKills[iClient] = 0;
		g_iQueueSaves[iClient] = 0;
		g_flQueueLastZombieHit[iClient] = 0.0;
		
		for (int i = 1; i <= MaxClients; i++)
			g_flQueueZombieHit[iClient][i] = 0.0;
	}
}

static bool Queue_IsRoundPlaying()
{
	return g_nRoundState == SZFRoundState_Grace || g_nRoundState == SZFRoundState_Active;
}

static bool Queue_IsRecentHit(float flTime)
{
	if (flTime <= 0.0)
		return false;
	
	float flAgo = GetGameTime() - flTime;
	return flAgo >= 0.0 && flAgo <= g_cvQueueSaveHitWindow.FloatValue;
}

static bool Queue_IsLowHealth(int iClient, int iHealth)
{
	return float(iHealth) < float(SDKCall_GetMaxHealth(iClient)) * g_cvQueueSaveHealth.FloatValue;
}
