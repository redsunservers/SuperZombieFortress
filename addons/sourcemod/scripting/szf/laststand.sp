#define LASTSTAND_HUNTER_DAMAGE		20.0
#define LASTSTAND_INTANGIBLE_MIN	0.5
#define LASTSTAND_LONE_HEALTH		0.25
#define LASTSTAND_REGEN_MULTI		0.5
#define LASTSTAND_RESIST_FEW			0.5
#define LASTSTAND_RESIST_MANY			0.95
#define LASTSTAND_RESIST_FEW_PLAYERS	2.0
#define LASTSTAND_RESIST_MANY_PLAYERS	40.0
#define LEFT4DEAD_RESIST_FEW			0.3
#define LEFT4DEAD_RESIST_MANY			0.6
#define LEFT4DEAD_RESIST_FEW_PLAYERS	16.0
#define LEFT4DEAD_RESIST_MANY_PLAYERS	40.0
#define LEFT4DEAD_HEAL_MULTI			0.25
#define LEFT4DEAD_SPEED_MULTI			1.1
#define LASTSTAND_TF2_TAKEN				0.25

static int g_iLastStandHealth[MAXPLAYERS + 1] = {-1, ...};
static int g_iLastStandHitHealth[MAXPLAYERS + 1] = {-1, ...};
static int g_iLastStandHitAttacker[MAXPLAYERS + 1];
static float g_flLastStandRegen[MAXPLAYERS + 1];
static float g_flLastStandHurtTime[MAXPLAYERS + 1];
static float g_flLastStandDamageCarry[MAXPLAYERS + 1];
static bool g_bIntangible[MAXPLAYERS + 1];
static float g_flIntangibleStart[MAXPLAYERS + 1];
static float g_flBonkEnd[MAXPLAYERS + 1];
static float g_flLastStandStart;
static bool g_bLastStandTankSent;
static int g_iLoneSurvivor;
static bool g_bLeft4DeadRound;
static bool g_bLeft4Dead;
static float g_flLeft4DeadHealCarry[MAXPLAYERS + 1];
static int g_iLastStandHitDepth[MAXPLAYERS + 1];
static int g_iLastStandKunaiHealth[MAXPLAYERS + 1] = {-1, ...};

bool IsLastManStanding(int iClient)
{
	return g_bLastSurvivor && IsValidLivingSurvivor(iClient);
}

bool IsLeft4Dead(int iClient)
{
	return g_bLeft4Dead && IsValidLivingSurvivor(iClient);
}

bool IsStunImmune(int iClient)
{
	return IsLastManStanding(iClient) || IsLeft4Dead(iClient);
}

void LastStand_OnStart()
{
	g_flLastStandStart = GetGameTime();
	g_bLastStandTankSent = false;
}

void LastStand_Update()
{
	if (!(g_bLastSurvivor || g_bLeft4Dead) || g_bLastStandTankSent || g_nRoundState != SZFRoundState_Active)
		return;
	
	float flTime = g_cvLastStandTankTime.FloatValue;
	if (flTime <= 0.0)
		return;
	
	if (GetGameTime() - fMax(g_flLastStandStart, g_flRoundStarted) < flTime)
		return;
	
	if (MapConfig_BlockForcedTank(g_bLeft4Dead ? "Left 4 Dead" : "Last Man Standing"))
	{
		g_bLastStandTankSent = true;
		return;
	}
	
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
	LastStand_ResetLeft4Dead();
	int iSurvivors = LastStand_CountSurvivors(0, false);
	int iMinSurvivors = g_cvLeft4DeadSurvivors.IntValue;
	if (iMinSurvivors > 0 && iSurvivors >= iMinSurvivors)
	{
		g_bLeft4DeadRound = true;
		g_iLoneSurvivor = 0;
		CPrintToChatDebug("Left 4 Dead round: %d starting survivors", iSurvivors);
		LastStand_CheckLeft4Dead(0);
		return;
	}
	
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

bool LastStand_IsLeft4DeadRound()
{
	return g_bLeft4DeadRound;
}

void LastStand_CheckLeft4Dead(int iIgnoredClient)
{
	if (!g_bLeft4DeadRound || g_bLeft4Dead || g_nRoundState != SZFRoundState_Active)
		return;
	
	int iSurvivors = LastStand_CountSurvivors(iIgnoredClient, true);
	if (iSurvivors <= 0 || iSurvivors > g_cvLeft4DeadCount.IntValue)
		return;
	
	g_bLeft4Dead = true;
	LastStand_OnStart();
	
	int iClients[MAXPLAYERS];
	int iCount;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (iClient == iIgnoredClient || !IsValidLivingSurvivor(iClient))
			continue;
		
		iClients[iCount++] = iClient;
		
		Stun_EndPlayer(iClient);
		TF2_RemoveCondition(iClient, TFCond_Dazed);
		g_flLeft4DeadHealCarry[iClient] = 0.0;
		
		TF2_AddCondition(iClient, TFCond_KingRune, g_cvLastStandKingRuneDuration.FloatValue);
		SetEntityHealth(iClient, SDKCall_GetMaxHealth(iClient));
		SDKCall_SetSpeed(iClient);
	}
	
	for (int i = 0; i < iCount; i++)
	{
		char sName[128];
		GetClientName2(iClients[i], sName, sizeof(sName));
		
		if (iCount == 1)
			CPrintToChatAllEx(iClients[i], "%t", "Survivor_Left4DeadNameAlone", sName, "{green}");
		else if (i == iCount - 1)
			CPrintToChatAllEx(iClients[i], "%t", "Survivor_Left4DeadNameLast", sName, "{green}", "{green}");
		else
			CPrintToChatAllEx(iClients[i], "%s", sName);
	}
	
	if (iCount == 1)
		CPrintToChatAllEx(iClients[0], "%t", "Survivor_Left4DeadOne", "{green}");
	else
		CPrintToChatAllEx(iClients[0], "%t", "Survivor_Left4Dead", "{green}");
	
	Sound_PlayMusicToAll("laststand");
	
	FireRelay("FireUser1", "szf_laststand");
}

void LastStand_ResetLeft4Dead()
{
	g_bLeft4DeadRound = false;
	g_bLeft4Dead = false;
}

static int LastStand_CountSurvivors(int iIgnoredClient, bool bAlive)
{
	int iCount;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (iClient != iIgnoredClient && (bAlive ? IsValidLivingSurvivor(iClient) : IsValidSurvivor(iClient)))
			iCount++;
	
	return iCount;
}

static float LastStand_GetLeft4DeadResistance()
{
	return LastStand_Remap(float(GetActivePlayerCount()), LEFT4DEAD_RESIST_FEW_PLAYERS, LEFT4DEAD_RESIST_MANY_PLAYERS, LEFT4DEAD_RESIST_FEW, LEFT4DEAD_RESIST_MANY);
}

bool LastStand_OnLeft4DeadDamage(int iVictim, float &flDamage, int iDamageCustom)
{
	if (!IsLeft4Dead(iVictim) || iDamageCustom == TF_CUSTOM_TRIGGER_HURT)
		return false;
	
	g_flLastStandDamageCarry[iVictim] += flDamage * (1.0 - LastStand_GetLeft4DeadResistance());
	flDamage = float(RoundToFloor(g_flLastStandDamageCarry[iVictim]));
	g_flLastStandDamageCarry[iVictim] -= flDamage;
	return true;
}

float LastStand_GetSpeedMulti(int iClient)
{
	return IsLeft4Dead(iClient) ? LEFT4DEAD_SPEED_MULTI : 1.0;
}

static void LastStand_CutLeft4DeadHeal(int iClient, int iHealthBefore)
{
	int iGain = GetClientHealth(iClient) - iHealthBefore;
	if (iGain <= 0)
		return;
	
	g_flLeft4DeadHealCarry[iClient] += float(iGain) * LEFT4DEAD_HEAL_MULTI;
	int iKeep = RoundToFloor(g_flLeft4DeadHealCarry[iClient]);
	g_flLeft4DeadHealCarry[iClient] -= float(iKeep);
	SetEntityHealth(iClient, iHealthBefore + iKeep);
}

void LastStand_OnHealOnHit(int iClient, int iAmount, int iDefIndex)
{
	if (iAmount <= 0 || !IsLeft4Dead(iClient) || g_iLastStandHitDepth[iClient] > 0)
		return;
	
	int iWeapon = LastStand_GetWeaponByDefIndex(iClient, iDefIndex);
	if (iWeapon <= MaxClients)
		return;
	
	if (TF2Attrib_HookValueInt(0, "add_health_on_radius_damage", iWeapon) > 0)
	{
		LastStand_CutLeft4DeadHeal(iClient, GetClientHealth(iClient) - iAmount);
		return;
	}
	
	if (TF2Attrib_HookValueFloat(0.0, "active_item_health_regen", iWeapon) != 0.0)
		return;
	
	if (TF2Attrib_HookValueInt(0, "add_onhit_addhealth", iWeapon) <= 0 && !TF2_IsPlayerInCondition(iClient, TFCond_RegenBuffed))
		return;
	
	int iHealth = GetClientHealth(iClient);
	if (iHealth < SDKCall_GetMaxHealth(iClient))
		LastStand_CutLeft4DeadHeal(iClient, iHealth - iAmount);
}

static int LastStand_GetWeaponByDefIndex(int iClient, int iDefIndex)
{
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon > MaxClients && GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") == iDefIndex)
			return iWeapon;
	}
	
	return -1;
}

static void LastStand_CheckKunaiKill(int iVictim, int iAttacker, int iWeapon, int iDamageCustom, int iHealth)
{
	if (iDamageCustom == TF_CUSTOM_BACKSTAB && !IsPlayerAlive(iVictim) && iWeapon > MaxClients && IsValidEntity(iWeapon)
		&& TF2Attrib_HookValueInt(0, "sanguisuge", iWeapon) > 0)
		g_iLastStandKunaiHealth[iAttacker] = iHealth;
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
	g_flLastStandRegen[iClient] = 0.0;
	g_flLastStandHurtTime[iClient] = 0.0;
	g_flLastStandDamageCarry[iClient] = 0.0;
	g_flLeft4DeadHealCarry[iClient] = 0.0;
	g_iLastStandKunaiHealth[iClient] = -1;
	g_iLastStandHitDepth[iClient] = 0;
	
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
	g_flLastStandRegen[iClient] = 0.0;
	g_flLastStandHurtTime[iClient] = 0.0;
	g_flLastStandDamageCarry[iClient] = 0.0;
	g_flLeft4DeadHealCarry[iClient] = 0.0;
	g_iLastStandKunaiHealth[iClient] = -1;
	g_iLastStandHitDepth[iClient] = 0;
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

int LastStand_GetRegen(int iClient, int iClassRegen)
{
	float flRegen = float(iClassRegen);
	float flTimeSinceDamage = GetGameTime() - g_flLastStandHurtTime[iClient];
	
	if (TF2_GetPlayerClass(iClient) == TFClass_Medic)
		flRegen += 3.0 * LastStand_Remap(flTimeSinceDamage, 5.0, 10.0, 1.0, 2.0);
	
	float flItemRegen = TF2Attrib_HookValueFloat(0.0, "add_health_regen", iClient);
	if (flItemRegen > 0.0)
		flRegen += flItemRegen * (flTimeSinceDamage < 5.0 ? 0.25 : LastStand_Remap(flTimeSinceDamage, 5.0, 10.0, 0.5, 1.0));
	
	g_flLastStandRegen[iClient] += flRegen * LASTSTAND_REGEN_MULTI;
	int iRegen = RoundToZero(g_flLastStandRegen[iClient]);
	g_flLastStandRegen[iClient] -= float(iRegen);
	return iRegen;
}

static float LastStand_Remap(float flValue, float flInA, float flInB, float flOutA, float flOutB)
{
	float flFraction = fMax(0.0, fMin(1.0, (flValue - flInA) / (flInB - flInA)));
	return flOutA + (flOutB - flOutA) * flFraction;
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
	if (g_iLastStandKunaiHealth[iClient] >= 0)
	{
		if (IsLeft4Dead(iClient))
			LastStand_CutLeft4DeadHeal(iClient, g_iLastStandKunaiHealth[iClient]);
		else if (IsLastManStanding(iClient) && GetClientHealth(iClient) > g_iLastStandKunaiHealth[iClient])
			SetEntityHealth(iClient, g_iLastStandKunaiHealth[iClient]);
		
		g_iLastStandKunaiHealth[iClient] = -1;
	}
	
	g_iLastStandHitDepth[iClient] = 0;
	
	if (IsLastManStanding(iClient))
		g_iLastStandHealth[iClient] = GetClientHealth(iClient);
	else
		g_iLastStandHealth[iClient] = -1;
}

void LastStand_OnHurt(int iClient)
{
	g_flLastStandHurtTime[iClient] = GetGameTime();
	LastStand_LowerCap(iClient);
}

static void LastStand_LowerCap(int iClient)
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
	
	if (iVictim == iAttacker || !IsValidZombie(iVictim) || !(IsLastManStanding(iAttacker) || IsLeft4Dead(iAttacker)))
		return;
	
	g_iLastStandHitHealth[iVictim] = GetClientHealth(iAttacker);
	g_iLastStandHitAttacker[iVictim] = iAttacker;
	g_iLastStandHitDepth[iAttacker]++;
}

void LastStand_OnZombieDamagedPost(int iVictim, int iWeapon, int iDamageCustom)
{
	int iHealth = g_iLastStandHitHealth[iVictim];
	if (iHealth < 0)
		return;
	
	g_iLastStandHitHealth[iVictim] = -1;
	
	int iAttacker = g_iLastStandHitAttacker[iVictim];
	if (g_iLastStandHitDepth[iAttacker] > 0)
		g_iLastStandHitDepth[iAttacker]--;
	
	if (IsLeft4Dead(iAttacker))
	{
		LastStand_CutLeft4DeadHeal(iAttacker, iHealth);
		LastStand_CheckKunaiKill(iVictim, iAttacker, iWeapon, iDamageCustom, GetClientHealth(iAttacker));
		return;
	}
	
	if (!IsLastManStanding(iAttacker))
		return;
	
	LastStand_CheckKunaiKill(iVictim, iAttacker, iWeapon, iDamageCustom, iHealth);
	
	if (GetClientHealth(iAttacker) > iHealth)
		SetEntityHealth(iAttacker, iHealth);
	
	LastStand_LowerCap(iAttacker);
}

float LastStand_GetResistance()
{
	return LastStand_Remap(float(GetActivePlayerCount()), LASTSTAND_RESIST_FEW_PLAYERS, LASTSTAND_RESIST_MANY_PLAYERS, LASTSTAND_RESIST_FEW, LASTSTAND_RESIST_MANY);
}

bool LastStand_OnTakeDamage(int iVictim, float &flDamage, int iDamageType, int iDamageCustom)
{
	if (!IsLastManStanding(iVictim) || !TF2_IsPlayerInCondition(iVictim, TFCond_DefenseBuffMmmph))
		return false;
	
	if (iDamageCustom == TF_CUSTOM_BACKSTAB || (iDamageType & DMG_CRUSH))
		return false;
	
	float flMulti = (1.0 - LastStand_GetResistance()) / LASTSTAND_TF2_TAKEN;
	if (iDamageCustom == TF_CUSTOM_TRIGGER_HURT && flMulti < 1.0)
		return false;
	
	g_flLastStandDamageCarry[iVictim] += flDamage * flMulti;
	flDamage = float(RoundToFloor(g_flLastStandDamageCarry[iVictim]));
	g_flLastStandDamageCarry[iVictim] -= flDamage;
	return true;
}

void LastStand_OnBonkEnd(int iClient)
{
	g_flBonkEnd[iClient] = GetGameTime();
}

bool LastStand_IsBonkSlowdown(int iClient)
{
	return GetGameTime() - g_flBonkEnd[iClient] < 0.5;
}

float LastStand_GetMeleeDamage(int iAttacker, int iWeapon)
{
	float flDamage = 65.0;
	switch (TF2_GetPlayerClass(iAttacker))
	{
		case TFClass_Scout: flDamage = 35.0;
		case TFClass_Spy: flDamage = 40.0;
	}
	
	if (iWeapon > MaxClients && IsValidEntity(iWeapon))
		return TF2Attrib_HookValueFloat(flDamage, "mult_dmg", iWeapon);
	
	return flDamage;
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
