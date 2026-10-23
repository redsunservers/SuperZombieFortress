static ConVar g_cvSpecialDamage;
static ConVar g_cvSpecialQueueMax;

static int g_iSpecialQueue[MAXPLAYERS + 1];
static int g_iSpecialDamage[MAXPLAYERS + 1];
static bool g_bSpecialDamageQueued[MAXPLAYERS + 1];
static bool g_bSpecialNewLife[MAXPLAYERS + 1];

void SpecialQueue_Init()
{
	g_cvSpecialDamage = CreateConVar("sm_szf_special_damage", "300", "Total damage a zombie deals to survivors (added up across lives) to be guaranteed a special infected life. The total resets when they spawn as that special, and at round start. 0 to disable.", _, true, 0.0);
	g_cvSpecialQueueMax = CreateConVar("sm_szf_special_queue_max", "0", "Most special infected lives a zombie can have queued at once (picks in the same life queue up instead of being lost). 0 = no limit.", _, true, 0.0);
}

static void SpecialQueue_Reset(int iClient)
{
	g_iSpecialQueue[iClient] = 0;
	g_iSpecialDamage[iClient] = 0;
	g_bSpecialDamageQueued[iClient] = false;
	g_bSpecialNewLife[iClient] = false;
	g_bSpecialIgnoreCooldown[iClient] = false;
}

void SpecialQueue_OnClientPutInServer(int iClient)
{
	SpecialQueue_Reset(iClient);
}

void SpecialQueue_OnRoundRespawn()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		SpecialQueue_Reset(iClient);
}

bool SpecialQueue_Add(int iClient, const char[] sReason)
{
	int iMax = g_cvSpecialQueueMax.IntValue;
	if (iMax > 0 && g_iSpecialQueue[iClient] >= iMax)
		return false;
	
	g_iSpecialQueue[iClient]++;
	CPrintToChatDebug("Special queue: %N +1 (%s), %d queued", iClient, sReason, g_iSpecialQueue[iClient]);
	return true;
}

bool SpecialQueue_Has(int iClient)
{
	return g_iSpecialQueue[iClient] > 0;
}

bool SpecialQueue_CanTake(int iClient)
{
	return g_iSpecialQueue[iClient] > 0 && g_bSpecialNewLife[iClient];
}

bool SpecialQueue_IsGuaranteed(int iClient)
{
	return g_bSpecialDamageQueued[iClient];
}

void SpecialQueue_OnPlayerDeath(int iVictim)
{
	if (0 < iVictim <= MaxClients)
		g_bSpecialNewLife[iVictim] = true;
}

void SpecialQueue_OnSpawned(int iClient)
{
	g_bSpecialNewLife[iClient] = false;
}

void SpecialQueue_Take(int iClient)
{
	if (g_iSpecialQueue[iClient] > 0)
		g_iSpecialQueue[iClient]--;
	
	if (g_bSpecialDamageQueued[iClient])
	{
		g_bSpecialDamageQueued[iClient] = false;
		g_iSpecialDamage[iClient] = 0;
	}
	
	CPrintToChatDebug("Special queue: %N spawned as a special, %d left", iClient, g_iSpecialQueue[iClient]);
}

void SpecialQueue_OnPlayerHurt(int iVictim, int iAttacker, int iDamage)
{
	if (g_nRoundState != SZFRoundState_Active || iDamage <= 0 || !IsValidZombie(iAttacker) || !IsValidSurvivor(iVictim))
		return;
	
	int iRequired = g_cvSpecialDamage.IntValue;
	if (iRequired <= 0 || g_bSpecialDamageQueued[iAttacker])
		return;
	
	g_iSpecialDamage[iAttacker] += iDamage;
	if (g_iSpecialDamage[iAttacker] >= iRequired && SpecialQueue_Add(iAttacker, "damage"))
		g_bSpecialDamageQueued[iAttacker] = true;
}
