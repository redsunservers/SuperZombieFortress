
#define OBJECTIVE_SURVIVORS			4
#define OBJECTIVE_DISTANCE			500.0
#define OBJECTIVE_DISTANCE_MARGIN	25.0
#define OBJECTIVE_CHECK_INTERVAL	0.1
#define OBJECTIVE_ZONE_INTERVAL		0.5
#define OBJECTIVE_COND_TIME			0.3
#define OBJECTIVE_FAR_TIME			120.0
#define OBJECTIVE_WARNINGS			4
#define OBJECTIVE_DAMAGE			20.0
#define OBJECTIVE_DAMAGE_INTERVAL	1.0
#define OBJECTIVE_LENIENCE_TIME		120.0
#define OBJECTIVE_POINT_REACH		128.0
#define OBJECTIVE_MARKER_MODEL		"models/effects/cappoint_hologram.mdl"
#define OBJECTIVE_MARKER_NAME		"szf_objective_marker"

static const int g_iObjectiveGlowColor[4] = {255, 215, 0, 255};

static bool g_bObjectiveFar[MAXPLAYERS + 1];
static bool g_bObjectiveWarned[MAXPLAYERS + 1];
static float g_flObjectiveFarTime[MAXPLAYERS + 1];
static float g_flObjectiveNextDamage[MAXPLAYERS + 1];
static float g_flObjectiveNextCheck;
static float g_flObjectiveLastCheck;
static float g_flObjectiveNextZones;
static float g_flObjectiveLenienceEnd;
static bool g_bObjectiveLenienceTold;
static int g_iObjectiveDamaging;

static int g_iObjectiveZoneCount;
static int g_iObjectiveZoneMask = -1;
static int g_iObjectiveZoneTrigger[MAX_CONTROL_POINTS];
static int g_iObjectiveZonePoint[MAX_CONTROL_POINTS];
static int g_iObjectiveZoneMarker[MAX_CONTROL_POINTS];
static float g_vecObjectiveZoneMins[MAX_CONTROL_POINTS][3];
static float g_vecObjectiveZoneMaxs[MAX_CONTROL_POINTS][3];

void Objective_Precache()
{
	PrecacheModel(OBJECTIVE_MARKER_MODEL);
}

void Objective_OnRoundActive()
{
	Objective_RemoveMarkers();
	g_iObjectiveZoneCount = 0;
	g_iObjectiveZoneMask = -1;
	g_flObjectiveNextZones = 0.0;
	g_flObjectiveLenienceEnd = 0.0;
	g_bObjectiveLenienceTold = false;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		Objective_ResetClient(iClient, true);
}

void Objective_ResetClient(int iClient, bool bRound = false)
{
	g_bObjectiveFar[iClient] = false;
	g_flObjectiveFarTime[iClient] = 0.0;
	g_flObjectiveNextDamage[iClient] = 0.0;
	
	if (bRound)
		g_bObjectiveWarned[iClient] = false;
}

void Objective_OnPointCaptured(TFTeam nTeam)
{
	g_flObjectiveNextZones = 0.0;
	
	if (nTeam != TFTeam_Survivor || g_nRoundState != SZFRoundState_Active)
		return;
	
	if (MapConfig_GetSetting(MapSetting_ObjectiveLenience) == 0.0)
	{
		CPrintToChatDebug("Objective: no lenience after this capture (\"objectivelenience\" is 0 for this map)");
		return;
	}
	
	g_flObjectiveLenienceEnd = GetGameTime() + OBJECTIVE_LENIENCE_TIME;
	g_bObjectiveLenienceTold = false;
	CPrintToChatDebug("Objective: %.0f s of lenience after this capture", OBJECTIVE_LENIENCE_TIME);
}

void Objective_Update()
{
	float flNow = GetGameTime();
	if (g_flObjectiveNextCheck - flNow > OBJECTIVE_CHECK_INTERVAL)
		g_flObjectiveNextCheck = 0.0;
	
	if (flNow < g_flObjectiveNextCheck)
		return;
	
	float flElapsed = flNow - g_flObjectiveLastCheck;
	if (flElapsed <= 0.0 || flElapsed > OBJECTIVE_CHECK_INTERVAL * 5.0)
		flElapsed = OBJECTIVE_CHECK_INTERVAL;
	
	g_flObjectiveLastCheck = flNow;
	g_flObjectiveNextCheck = flNow + OBJECTIVE_CHECK_INTERVAL;
	
	bool bActive = g_nRoundState == SZFRoundState_Active;
	bool bFew = bActive && GetSurvivorCount() <= OBJECTIVE_SURVIVORS;
	bool bLenience = bActive && g_flObjectiveLenienceEnd > flNow;
	
	if (bFew)
	{
		if (flNow >= g_flObjectiveNextZones || g_flObjectiveNextZones - flNow > OBJECTIVE_ZONE_INTERVAL)
		{
			g_flObjectiveNextZones = flNow + OBJECTIVE_ZONE_INTERVAL;
			Objective_FindZones();
		}
		
		if (bLenience && !g_bObjectiveLenienceTold && g_iObjectiveZoneCount > 0)
		{
			g_bObjectiveLenienceTold = true;
			
			for (int iClient = 1; iClient <= MaxClients; iClient++)
				if (IsValidLivingSurvivor(iClient))
					CPrintToChat(iClient, "%t", "Objective_Lenience", "{limegreen}", "{lightsalmon}");
		}
	}
	
	bool bPressure = bFew && !bLenience && g_iObjectiveZoneCount > 0;
	int iViewers = 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		bool bSurvivor = bActive && IsValidLivingSurvivor(iClient);
		bool bFar = bSurvivor && bPressure && Objective_IsFar(iClient, g_bObjectiveFar[iClient]);
		
		if (bFar)
		{
			if (!IsFakeClient(iClient))
				iViewers++;
			
			TF2_AddCondition(iClient, TFCond_MarkedForDeath, OBJECTIVE_COND_TIME);
			
			if (!g_bObjectiveWarned[iClient])
			{
				g_bObjectiveWarned[iClient] = true;
				CPrintToChat(iClient, "%t", "Objective_Vulnerable", "{limegreen}", "{red}", OBJECTIVE_SURVIVORS);
			}
			
			Objective_AddFarTime(iClient, flElapsed);
			Objective_Outline(iClient);
		}
		else if (g_bObjectiveFar[iClient])
		{
			Glow_RemoveViewer(iClient, GlowType_Objective);
		}
		
		g_bObjectiveFar[iClient] = bFar;
		
		if (bSurvivor && !bLenience && g_flObjectiveFarTime[iClient] >= OBJECTIVE_FAR_TIME)
			Objective_Damage(iClient, flNow);
	}
	
	if (!iViewers)
		Objective_RemoveMarkers();
}

static bool Objective_IsFar(int iClient, bool bWasFar)
{
	float vecOrigin[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	
	float flLimit = bWasFar ? OBJECTIVE_DISTANCE - OBJECTIVE_DISTANCE_MARGIN : OBJECTIVE_DISTANCE;
	flLimit *= flLimit;
	
	for (int iZone = 0; iZone < g_iObjectiveZoneCount; iZone++)
	{
		float flDistanceSqr = 0.0;
		for (int i = 0; i < 3; i++)
		{
			float flNearest = fMax(g_vecObjectiveZoneMins[iZone][i], fMin(vecOrigin[i], g_vecObjectiveZoneMaxs[iZone][i]));
			float flDelta = vecOrigin[i] - flNearest;
			flDistanceSqr += flDelta * flDelta;
		}
		
		if (flDistanceSqr <= flLimit)
			return false;
	}
	
	return true;
}

static void Objective_AddFarTime(int iClient, float flElapsed)
{
	if (g_flObjectiveFarTime[iClient] >= OBJECTIVE_FAR_TIME)
		return;
	
	float flStep = OBJECTIVE_FAR_TIME / float(OBJECTIVE_WARNINGS);
	int iBefore = RoundToFloor(g_flObjectiveFarTime[iClient] / flStep);
	g_flObjectiveFarTime[iClient] = fMin(OBJECTIVE_FAR_TIME, g_flObjectiveFarTime[iClient] + flElapsed);
	int iWarning = RoundToFloor(g_flObjectiveFarTime[iClient] / flStep);
	if (iWarning <= iBefore)
		return;
	
	char sPhrase[32];
	FormatEx(sPhrase, sizeof(sPhrase), "Objective_Warning%d", iWarning);
	CPrintToChat(iClient, "%t", sPhrase, "{limegreen}", "{red}");
}

static void Objective_Damage(int iClient, float flNow)
{
	if (g_flObjectiveNextDamage[iClient] - flNow > OBJECTIVE_DAMAGE_INTERVAL)
		g_flObjectiveNextDamage[iClient] = 0.0;
	
	float flDue = g_flObjectiveNextDamage[iClient];
	if (flNow < flDue)
		return;
	
	if (flDue > 0.0 && flNow - flDue < OBJECTIVE_DAMAGE_INTERVAL)
		g_flObjectiveNextDamage[iClient] = flDue + OBJECTIVE_DAMAGE_INTERVAL;
	else
		g_flObjectiveNextDamage[iClient] = flNow + OBJECTIVE_DAMAGE_INTERVAL;
	
	g_iObjectiveDamaging = iClient;
	SDKHooks_TakeDamage(iClient, iClient, iClient, OBJECTIVE_DAMAGE, DMG_PREVENT_PHYSICS_FORCE);
	g_iObjectiveDamaging = 0;
	
	if (IsClientInGame(iClient) && IsPlayerAlive(iClient))
		SDKCall_SetSpeed(iClient);
}

bool Objective_OnTakeDamageAlive(int iVictim, float &flDamage)
{
	if (!g_iObjectiveDamaging || iVictim != g_iObjectiveDamaging)
		return false;
	
	flDamage = OBJECTIVE_DAMAGE;
	return true;
}

static void Objective_FindZones()
{
	int iOldCount = g_iObjectiveZoneCount;
	int iOldTrigger[MAX_CONTROL_POINTS], iOldMarker[MAX_CONTROL_POINTS];
	for (int i = 0; i < iOldCount; i++)
	{
		iOldTrigger[i] = g_iObjectiveZoneTrigger[i];
		iOldMarker[i] = g_iObjectiveZoneMarker[i];
	}
	
	g_iObjectiveZoneCount = 0;
	
	int iMask;
	int iTeam = view_as<int>(TFTeam_Survivor);
	int iResource = FindEntityByClassname(-1, "tf_objective_resource");
	int iTrigger = -1;
	while (iResource != -1 && g_iObjectiveZoneCount < MAX_CONTROL_POINTS && (iTrigger = FindEntityByClassname(iTrigger, "trigger_capture_area")) != -1)
	{
		if (GetEntProp(iTrigger, Prop_Data, "m_bDisabled"))
			continue;
		
		int iPoint = GetCapturePointFromTrigger(iTrigger);
		if (iPoint == INVALID_ENT_REFERENCE)
			continue;
		
		int iIndex = GetEntProp(iPoint, Prop_Data, "m_iPointIndex");
		if (iIndex < 0 || iIndex >= MAX_CONTROL_POINTS)
			continue;
		
		if (GetEntProp(iResource, Prop_Send, "m_iOwner", _, iIndex) == iTeam
			|| GetEntProp(iResource, Prop_Send, "m_bCPLocked", _, iIndex)
			|| !GetEntProp(iResource, Prop_Send, "m_bTeamCanCap", _, iIndex + iTeam * MAX_CONTROL_POINTS)
			|| (GetEntProp(iResource, Prop_Send, "m_bPlayingMiniRounds") && !GetEntProp(iResource, Prop_Send, "m_bInMiniRound", _, iIndex)))
			continue;
		
		if (!SDKCall_TeamMayCapturePoint(TFTeam_Survivor, iIndex))
			continue;
		
		iMask |= (1 << iIndex);
		
		int iZone = g_iObjectiveZoneCount++;
		g_iObjectiveZoneTrigger[iZone] = EntIndexToEntRef(iTrigger);
		g_iObjectiveZonePoint[iZone] = EntIndexToEntRef(iPoint);
		g_iObjectiveZoneMarker[iZone] = INVALID_ENT_REFERENCE;
		
		float vecOrigin[3], vecMins[3], vecMaxs[3];
		GetEntPropVector(iTrigger, Prop_Data, "m_vecAbsOrigin", vecOrigin);
		GetEntPropVector(iTrigger, Prop_Data, "m_vecMins", vecMins);
		GetEntPropVector(iTrigger, Prop_Data, "m_vecMaxs", vecMaxs);
		for (int i = 0; i < 3; i++)
		{
			g_vecObjectiveZoneMins[iZone][i] = vecOrigin[i] + vecMins[i];
			g_vecObjectiveZoneMaxs[iZone][i] = vecOrigin[i] + vecMaxs[i];
		}
		
		for (int i = 0; i < iOldCount; i++)
		{
			if (iOldTrigger[i] != g_iObjectiveZoneTrigger[iZone])
				continue;
			
			g_iObjectiveZoneMarker[iZone] = iOldMarker[i];
			iOldMarker[i] = INVALID_ENT_REFERENCE;
		}
	}
	
	for (int i = 0; i < iOldCount; i++)
		Objective_RemoveMarker(iOldMarker[i]);
	
	if (iMask != g_iObjectiveZoneMask)
	{
		g_iObjectiveZoneMask = iMask;
		
		char sPoints[64];
		for (int i = 0; i < MAX_CONTROL_POINTS; i++)
			if (iMask & (1 << i))
				Format(sPoints, sizeof(sPoints), "%s%s%d", sPoints, sPoints[0] ? ", " : "", i);
		
		if (!sPoints[0])
			strcopy(sPoints, sizeof(sPoints), "none");
		
		CPrintToChatDebug("Objective: capture zones open to the survivors: control point %s", sPoints);
	}
}

static void Objective_Outline(int iClient)
{
	if (IsFakeClient(iClient))
		return;
	
	for (int iZone = 0; iZone < g_iObjectiveZoneCount; iZone++)
	{
		int iMarker = EntRefToEntIndex(g_iObjectiveZoneMarker[iZone]);
		if (iMarker <= MaxClients)
		{
			iMarker = Objective_CreateMarker(iZone);
			if (iMarker <= MaxClients)
				continue;
			
			g_iObjectiveZoneMarker[iZone] = EntIndexToEntRef(iMarker);
		}
		
		Glow_Create(iClient, iMarker, GlowType_Objective, g_iObjectiveGlowColor);
	}
}

static int Objective_CreateMarker(int iZone)
{
	if (GetEntityCount() > GetMaxEntities() - GLOW_EDICT_MARGIN)
		return INVALID_ENT_REFERENCE;
	
	float vecPos[3], vecEnd[3], vecAngles[3];
	for (int i = 0; i < 3; i++)
		vecPos[i] = (g_vecObjectiveZoneMins[iZone][i] + g_vecObjectiveZoneMaxs[iZone][i]) * 0.5;
	
	vecEnd = vecPos;
	vecEnd[2] = g_vecObjectiveZoneMins[iZone][2] - 16.0;
	TR_TraceRayFilter(vecPos, vecEnd, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Trace_DontHitClients);
	if (TR_DidHit() && !TR_StartSolid())
		TR_GetEndPosition(vecPos);
	else
		vecPos[2] = g_vecObjectiveZoneMins[iZone][2];
	
	char sModel[PLATFORM_MAX_PATH];
	int iBody, iSkin;
	int iPoint = EntRefToEntIndex(g_iObjectiveZonePoint[iZone]);
	if (iPoint > MaxClients)
	{
		GetEntityModel(iPoint, sModel, sizeof(sModel));
		iBody = GetEntProp(iPoint, Prop_Send, "m_nBody");
		iSkin = GetEntProp(iPoint, Prop_Send, "m_nSkin");
		
		if (sModel[0] && !(GetEntProp(iPoint, Prop_Send, "m_fEffects") & EF_NODRAW))
		{
			float vecPoint[3];
			GetEntPropVector(iPoint, Prop_Data, "m_vecAbsOrigin", vecPoint);
			
			bool bInReach = true;
			for (int i = 0; i < 3; i++)
				if (vecPoint[i] < g_vecObjectiveZoneMins[iZone][i] - OBJECTIVE_POINT_REACH || vecPoint[i] > g_vecObjectiveZoneMaxs[iZone][i] + OBJECTIVE_POINT_REACH)
					bInReach = false;
			
			if (bInReach)
			{
				vecPos = vecPoint;
				GetEntPropVector(iPoint, Prop_Data, "m_angAbsRotation", vecAngles);
			}
		}
	}
	
	if (!sModel[0])
		strcopy(sModel, sizeof(sModel), OBJECTIVE_MARKER_MODEL);
	
	int iMarker = CreateEntityByName("prop_dynamic_override");
	if (iMarker <= MaxClients)
		return INVALID_ENT_REFERENCE;
	
	DispatchKeyValue(iMarker, "targetname", OBJECTIVE_MARKER_NAME);
	DispatchKeyValue(iMarker, "model", sModel);
	DispatchKeyValue(iMarker, "solid", "0");
	DispatchKeyValue(iMarker, "disableshadows", "1");
	DispatchKeyValueVector(iMarker, "origin", vecPos);
	DispatchKeyValueVector(iMarker, "angles", vecAngles);
	DispatchSpawn(iMarker);
	
	SetEntProp(iMarker, Prop_Send, "m_nBody", iBody);
	SetEntProp(iMarker, Prop_Send, "m_nSkin", iSkin);
	SetEntityRenderMode(iMarker, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iMarker, 255, 255, 255, 0);
	
	return iMarker;
}

static void Objective_RemoveMarker(int iRef)
{
	int iMarker = EntRefToEntIndex(iRef);
	if (iMarker <= MaxClients)
		return;
	
	Glow_Remove(0, iMarker, GlowType_Objective);
	RemoveEntity(iMarker);
}

static void Objective_RemoveMarkers()
{
	for (int iZone = 0; iZone < g_iObjectiveZoneCount; iZone++)
	{
		Objective_RemoveMarker(g_iObjectiveZoneMarker[iZone]);
		g_iObjectiveZoneMarker[iZone] = INVALID_ENT_REFERENCE;
	}
}
