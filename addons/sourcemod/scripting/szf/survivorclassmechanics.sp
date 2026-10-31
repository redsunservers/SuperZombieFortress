#define SCOUTTEAM_FAR_DISTANCE		700.0
#define SCOUTTEAM_FAR_MARGIN		25.0
#define SCOUTTEAM_NEAR_DISTANCE		300.0
#define SCOUTTEAM_NEAR_DAMAGE		0.8
#define SCOUTTEAM_CHECK_INTERVAL	0.1
#define SCOUTTEAM_COND_TIME			0.3
#define SCOUTTEAM_MESSAGE_GAP		10.0
#define SCOUTTEAM_BANNER_RADIUS		450.0
#define SCOUTTEAM_BUFF_BATTALIONS	2
#define SCOUTTEAM_BUFF_PULSE_TIME	1.2

enum ScoutTeamState
{
	ScoutTeam_None = 0,
	ScoutTeam_Near,
	ScoutTeam_Far
}

static ScoutTeamState g_nScoutTeamState[MAXPLAYERS + 1];
static float g_flScoutTeamNearEnd[MAXPLAYERS + 1];
static float g_flScoutTeamDefensePickupEnd[MAXPLAYERS + 1];
static float g_flScoutTeamMessageTime[MAXPLAYERS + 1];
static float g_flScoutTeamNextCheck;
static float g_flScoutTeamBattalionsEnd[MAXPLAYERS + 1];
static float g_flScoutTeamHitDamage[MAXPLAYERS + 1];
static bool g_bScoutTeamBuffEvent;

void ScoutTeam_Init()
{
	g_bScoutTeamBuffEvent = HookEventEx("player_buff", ScoutTeam_PlayerBuff);
}

public Action ScoutTeam_PlayerBuff(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (0 < iClient <= MaxClients && event.GetInt("buff_type") == SCOUTTEAM_BUFF_BATTALIONS)
		g_flScoutTeamBattalionsEnd[iClient] = GetGameTime() + SCOUTTEAM_BUFF_PULSE_TIME;
	
	return Plugin_Continue;
}

void ScoutTeam_Update()
{
	float flNow = GetGameTime();
	if (g_flScoutTeamNextCheck - flNow > SCOUTTEAM_CHECK_INTERVAL)
		g_flScoutTeamNextCheck = 0.0;
	
	if (flNow < g_flScoutTeamNextCheck)
		return;
	
	g_flScoutTeamNextCheck = flNow + SCOUTTEAM_CHECK_INTERVAL;
	
	bool bActive = g_nRoundState == SZFRoundState_Active;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		ScoutTeamState nState = ScoutTeam_None;
		if (bActive && IsValidLivingSurvivor(iClient) && TF2_GetPlayerClass(iClient) == TFClass_Scout)
			nState = ScoutTeam_GetState(iClient, g_nScoutTeamState[iClient] == ScoutTeam_Far);
		
		if (nState == ScoutTeam_Far)
		{
			TF2_AddCondition(iClient, TFCond_MarkedForDeath, SCOUTTEAM_COND_TIME);
			
			float flEngineTime = GetEngineTime();
			if (g_nScoutTeamState[iClient] != ScoutTeam_Far && flEngineTime - g_flScoutTeamMessageTime[iClient] >= SCOUTTEAM_MESSAGE_GAP)
			{
				g_flScoutTeamMessageTime[iClient] = flEngineTime;
				CPrintToChat(iClient, "%t", "Survivor_ScoutVulnerable", "{red}");
			}
		}
		else if (nState == ScoutTeam_Near)
		{
			if (!ScoutTeam_HasTeamBattalions(iClient))
				TF2_AddCondition(iClient, TFCond_DefenseBuffed, SCOUTTEAM_COND_TIME);
			
			g_flScoutTeamNearEnd[iClient] = flNow + SCOUTTEAM_COND_TIME;
		}
		
		g_nScoutTeamState[iClient] = nState;
	}
}

static ScoutTeamState ScoutTeam_GetState(int iClient, bool bWasFar)
{
	float vecOrigin[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	
	float flNearest = -1.0;
	float flNearestScout = -1.0;
	for (int iOther = 1; iOther <= MaxClients; iOther++)
	{
		if (iOther == iClient || !IsValidLivingSurvivor(iOther))
			continue;
		
		float vecOther[3];
		GetClientAbsOrigin(iOther, vecOther);
		float flDistance = GetVectorDistance(vecOrigin, vecOther, true);
		if (TF2_GetPlayerClass(iOther) == TFClass_Scout)
		{
			if (flNearestScout < 0.0 || flDistance < flNearestScout)
				flNearestScout = flDistance;
		}
		else if (flNearest < 0.0 || flDistance < flNearest)
		{
			flNearest = flDistance;
		}
	}
	
	if (flNearest < 0.0)
		flNearest = flNearestScout;
	
	if (flNearest < 0.0)
		return ScoutTeam_None;
	
	if (flNearest <= SCOUTTEAM_NEAR_DISTANCE * SCOUTTEAM_NEAR_DISTANCE)
		return ScoutTeam_Near;
	
	float flFar = bWasFar ? SCOUTTEAM_FAR_DISTANCE - SCOUTTEAM_FAR_MARGIN : SCOUTTEAM_FAR_DISTANCE;
	if (flNearest > flFar * flFar)
		return ScoutTeam_Far;
	
	return ScoutTeam_None;
}

void ScoutTeam_OnTakeDamagePre(int iVictim, float flDamage, int iDamageType)
{
	g_flScoutTeamHitDamage[iVictim] = (iDamageType & DMG_USEDISTANCEMOD) ? flDamage : 0.0;
}

bool ScoutTeam_OnTakeDamageAlive(int iVictim, int iInflicter, int iWeapon, float &flDamage, int iDamageType, int iDamageCustom)
{
	float flBase = g_flScoutTeamHitDamage[iVictim];
	g_flScoutTeamHitDamage[iVictim] = 0.0;
	
	float flNow = GetGameTime();
	if (g_flScoutTeamNearEnd[iVictim] <= flNow || !TF2_IsPlayerInCondition(iVictim, TFCond_DefenseBuffed))
		return false;
	
	if (iDamageCustom == TF_CUSTOM_BACKSTAB || (iDamageType & DMG_CRUSH) || TF2_IsPlayerInCondition(iVictim, TFCond_DefenseBuffMmmph))
		return false;
	
	if (iWeapon > MaxClients && IsValidEntity(iWeapon) && TF2Attrib_HookValueInt(0, "mod_pierce_resists_absorbs", iWeapon) != 0)
		return false;
	
	if (g_flScoutTeamDefensePickupEnd[iVictim] > flNow || ScoutTeam_HasTeamBattalions(iVictim))
		return false;
	
	float flCut = IsClassname(iInflicter, "obj_sentrygun") ? 0.5 : 0.65;
	if (flBase > 0.0)
		flDamage = SCOUTTEAM_NEAR_DAMAGE * (flDamage + (1.0 - flCut) * flBase);
	else
		flDamage *= SCOUTTEAM_NEAR_DAMAGE / flCut;
	
	return true;
}

static bool ScoutTeam_HasTeamBattalions(int iClient)
{
	if (g_bScoutTeamBuffEvent)
		return g_flScoutTeamBattalionsEnd[iClient] > GetGameTime();
	
	float vecOrigin[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	
	for (int iSoldier = 1; iSoldier <= MaxClients; iSoldier++)
	{
		if (iSoldier == iClient || !IsValidLivingSurvivor(iSoldier) || !GetEntProp(iSoldier, Prop_Send, "m_bRageDraining"))
			continue;
		
		if (TF2Attrib_HookValueInt(0, "set_buff_type", iSoldier) != SCOUTTEAM_BUFF_BATTALIONS)
			continue;
		
		float vecSoldier[3];
		GetClientAbsOrigin(iSoldier, vecSoldier);
		float flRadius = TF2Attrib_HookValueFloat(SCOUTTEAM_BANNER_RADIUS, "mod_soldier_buff_range", iSoldier);
		if (GetVectorDistance(vecOrigin, vecSoldier, true) <= flRadius * flRadius)
			return true;
	}
	
	return false;
}

void ScoutTeam_OnDefensePickup(int iClient, float flDuration)
{
	g_flScoutTeamDefensePickupEnd[iClient] = GetGameTime() + flDuration;
}

void ScoutTeam_ResetClient(int iClient, bool bConnect = false)
{
	g_nScoutTeamState[iClient] = ScoutTeam_None;
	g_flScoutTeamNearEnd[iClient] = 0.0;
	g_flScoutTeamDefensePickupEnd[iClient] = 0.0;
	g_flScoutTeamBattalionsEnd[iClient] = 0.0;
	g_flScoutTeamHitDamage[iClient] = 0.0;
	
	if (bConnect)
		g_flScoutTeamMessageTime[iClient] = -SCOUTTEAM_MESSAGE_GAP;
}
