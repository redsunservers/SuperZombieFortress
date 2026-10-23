#define LASTSTAND_HUNTER_DAMAGE		20.0
#define LASTSTAND_INTANGIBLE_MIN	0.5
#define LASTSTAND_LONE_HEALTH		0.25

static int g_iLastStandHealth[MAXPLAYERS + 1] = {-1, ...};
static int g_iLastStandHitHealth[MAXPLAYERS + 1] = {-1, ...};
static int g_iLastStandHitAttacker[MAXPLAYERS + 1];
static bool g_bIntangible[MAXPLAYERS + 1];
static float g_flIntangibleStart[MAXPLAYERS + 1];
static float g_flBonkEnd[MAXPLAYERS + 1];
static float g_flLastStandStart;
static bool g_bLastStandTankSent;
static int g_iLoneSurvivor;

bool IsLastManStanding(int iClient)
{
	return g_bLastSurvivor && IsValidLivingSurvivor(iClient);
}

void LastStand_OnStart()
{
	g_flLastStandStart = GetGameTime();
	g_bLastStandTankSent = false;
}

void LastStand_Update()
{
	if (!g_bLastSurvivor || g_bLastStandTankSent || g_nRoundState != SZFRoundState_Active)
		return;
	
	float flTime = g_cvLastStandTankTime.FloatValue;
	if (flTime <= 0.0)
		return;
	
	if (GetGameTime() - fMax(g_flLastStandStart, g_flRoundStarted) < flTime)
		return;
	
	if (ZombiesHaveTank() || ZombiesTankComing())
		return;
	
	ZombieTank();
	if (!ZombiesTankComing())
		return;
	
	g_bLastStandTankSent = true;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient) && g_nNextInfected[iClient] == Infected_Tank)
			TF2_RespawnPlayer2(iClient);
}

void LastStand_OnRoundActive()
{
	g_iLoneSurvivor = LastStand_GetOnlySurvivor();
	if (g_iLoneSurvivor)
		LastStand_CheckLoneSurvivor(g_iLoneSurvivor);
}

bool LastStand_IsLoneSurvivor(int iClient)
{
	return iClient && iClient == g_iLoneSurvivor;
}

void LastStand_CheckLoneSurvivor(int iClient)
{
	if (!LastStand_IsLoneSurvivor(iClient) || g_bLastSurvivor || g_nRoundState != SZFRoundState_Active)
		return;
	
	if (LastStand_GetOnlySurvivor() != iClient)
		return;
	
	int iHealth = GetClientHealth(iClient);
	if (float(iHealth) >= float(SDKCall_GetMaxHealth(iClient)) * LASTSTAND_LONE_HEALTH)
		return;
	
	g_iLoneSurvivor = 0;
	StartLastSurvivor(iClient);
}

static int LastStand_GetOnlySurvivor()
{
	int iSurvivor;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidLivingSurvivor(iClient))
		{
			if (iSurvivor)
				return 0;
			
			iSurvivor = iClient;
		}
	}
	
	return iSurvivor;
}

void LastStand_AllowHealth(int iClient)
{
	if (IsLastManStanding(iClient))
		g_iLastStandHealth[iClient] = GetClientHealth(iClient);
}

void LastStand_ResetClient(int iClient)
{
	g_iLastStandHealth[iClient] = -1;
	g_iLastStandHitHealth[iClient] = -1;
	
	if (g_bIntangible[iClient])
	{
		g_bIntangible[iClient] = false;
		
		if (IsClientInGame(iClient))
			SetEntityCollisionGroup(iClient, COLLISION_GROUP_PLAYER);
	}
}

void LastStand_ClientDisconnect(int iClient)
{
	g_iLastStandHealth[iClient] = -1;
	g_iLastStandHitHealth[iClient] = -1;
	g_bIntangible[iClient] = false;
	g_flBonkEnd[iClient] = 0.0;
	
	if (g_iLoneSurvivor == iClient)
		g_iLoneSurvivor = 0;
}

public Action HealthKit_Touch(int iEntity, int iOther)
{
	if (0 < iOther <= MaxClients && IsLastManStanding(iOther))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

void LastStand_OnPreThink(int iClient)
{
	if (g_iLastStandHealth[iClient] < 0 || !IsLastManStanding(iClient))
		return;
	
	if (GetEntProp(iClient, Prop_Send, "m_nNumHealers") > 0)
	{
		g_iLastStandHealth[iClient] = GetClientHealth(iClient);
		return;
	}
	
	if (GetClientHealth(iClient) > g_iLastStandHealth[iClient])
		SetEntityHealth(iClient, g_iLastStandHealth[iClient]);
}

void LastStand_OnPostThinkPost(int iClient)
{
	if (IsLastManStanding(iClient))
		g_iLastStandHealth[iClient] = GetClientHealth(iClient);
	else
		g_iLastStandHealth[iClient] = -1;
}

void LastStand_OnHurt(int iClient)
{
	if (g_iLastStandHealth[iClient] < 0)
		return;
	
	int iHealth = GetClientHealth(iClient);
	if (iHealth < g_iLastStandHealth[iClient])
		g_iLastStandHealth[iClient] = iHealth;
}

void LastStand_OnZombieDamagedPre(int iVictim, int iAttacker)
{
	g_iLastStandHitHealth[iVictim] = -1;
	
	if (iVictim == iAttacker || !IsValidZombie(iVictim) || !IsLastManStanding(iAttacker))
		return;
	
	g_iLastStandHitHealth[iVictim] = GetClientHealth(iAttacker);
	g_iLastStandHitAttacker[iVictim] = iAttacker;
}

void LastStand_OnZombieDamagedPost(int iVictim)
{
	int iHealth = g_iLastStandHitHealth[iVictim];
	if (iHealth < 0)
		return;
	
	g_iLastStandHitHealth[iVictim] = -1;
	
	int iAttacker = g_iLastStandHitAttacker[iVictim];
	if (!IsLastManStanding(iAttacker))
		return;
	
	if (GetClientHealth(iAttacker) > iHealth)
		SetEntityHealth(iAttacker, iHealth);
	
	LastStand_OnHurt(iAttacker);
}

void LastStand_OnBonkEnd(int iClient)
{
	g_flBonkEnd[iClient] = GetGameTime();
}

bool LastStand_IsBonkSlowdown(int iClient)
{
	return GetGameTime() - g_flBonkEnd[iClient] < 0.5;
}

float LastStand_GetBackstabDamage(int iWeapon)
{
	const float flKnifeDamage = 40.0;
	
	if (iWeapon > MaxClients && IsValidEntity(iWeapon))
		return TF2Attrib_HookValueFloat(flKnifeDamage, "mult_dmg", iWeapon);
	
	return flKnifeDamage;
}

void LastStand_OnHunterPounce(int iHunter, int iVictim)
{
	SDKHooks_TakeDamage(iVictim, iHunter, iHunter, LASTSTAND_HUNTER_DAMAGE, DMG_CLUB|DMG_PREVENT_PHYSICS_FORCE);
	
	SetPlayerIntangible(iHunter);
	
	Forward_OnHunterHit(iHunter, iVictim);
}

void SetPlayerIntangible(int iClient)
{
	SetEntityCollisionGroup(iClient, COLLISION_GROUP_DEBRIS_TRIGGER);
	g_flIntangibleStart[iClient] = GetGameTime();
	
	if (!g_bIntangible[iClient])
	{
		g_bIntangible[iClient] = true;
		CreateTimer(0.1, Timer_LastStandIntangible, GetClientSerial(iClient), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_LastStandIntangible(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient || !g_bIntangible[iClient])
		return Plugin_Stop;
	
	if (IsPlayerAlive(iClient) && (GetGameTime() - g_flIntangibleStart[iClient] < LASTSTAND_INTANGIBLE_MIN || LastStand_IsInsideSurvivor(iClient)))
		return Plugin_Continue;
	
	g_bIntangible[iClient] = false;
	SetEntityCollisionGroup(iClient, COLLISION_GROUP_PLAYER);
	return Plugin_Stop;
}

static bool LastStand_IsInsideSurvivor(int iClient)
{
	float vecOrigin[3], vecMins[3], vecMaxs[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	GetClientMins(iClient, vecMins);
	GetClientMaxs(iClient, vecMaxs);
	
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (!IsValidLivingSurvivor(iSurvivor))
			continue;
		
		float vecOther[3], vecOtherMins[3], vecOtherMaxs[3];
		GetClientAbsOrigin(iSurvivor, vecOther);
		GetClientMins(iSurvivor, vecOtherMins);
		GetClientMaxs(iSurvivor, vecOtherMaxs);
		
		bool bOverlap = true;
		for (int i = 0; i < 3; i++)
		{
			if (vecOrigin[i] + vecMins[i] > vecOther[i] + vecOtherMaxs[i] || vecOrigin[i] + vecMaxs[i] < vecOther[i] + vecOtherMins[i])
			{
				bOverlap = false;
				break;
			}
		}
		
		if (bOverlap)
			return true;
	}
	
	return false;
}
