#define OBJECTIVE_CHECK_INTERVAL	0.1
#define OBJECTIVE_ZONE_INTERVAL		0.5
#define OBJECTIVE_DOME_EXTRA		1000.0
#define OBJECTIVE_DOME_END			500.0
#define OBJECTIVE_DOME_SPEED		25.0
#define OBJECTIVE_DOME_HOLD			30.0
#define OBJECTIVE_DOME_PREPARE		4.5
#define OBJECTIVE_GROUP_DISTANCE	1500.0
#define OBJECTIVE_FLOOR_REACH		256.0
#define OBJECTIVE_DAMAGE			20.0
#define OBJECTIVE_DAMAGE_INTERVAL	1.0
#define OBJECTIVE_BUILDING_DAMAGE	15
#define OBJECTIVE_BUILDING_INTERVAL	0.5
#define OBJECTIVE_FADE_START		0.7
#define OBJECTIVE_FADE_ALPHA		64
#define OBJECTIVE_FADE_DURATION		2000
#define OBJECTIVE_DOME_PROP_RADIUS	10000.0
#define OBJECTIVE_DOME_MODEL		"models/kirillian/brsphere_huge.mdl"
#define OBJECTIVE_DOME_NAME			"szf_objective_dome"
#define OBJECTIVE_DAMAGE_SOUND		"ui/medic_alert.wav"

static const int g_iObjectiveDomeColor[3] = {0, 0, 255};

static const char g_sObjectiveDomeFiles[][] =
{
	OBJECTIVE_DOME_MODEL,
	"models/kirillian/brsphere_huge.vvd",
	"models/kirillian/brsphere_huge.dx80.vtx",
	"models/kirillian/brsphere_huge.dx90.vtx",
	"materials/models/kirillian/brsphere/br_fog.vmt",
	"materials/models/kirillian/brsphere/br_fog.vtf"
};

static bool g_bObjectiveModel;
static bool g_bObjectiveOn;
static float g_flObjectiveNextCheck;
static float g_flObjectiveLastCheck;
static float g_flObjectiveNextZones;
static float g_flObjectiveNextBuildings;
static float g_flObjectiveOutside[MAXPLAYERS + 1];
static int g_iObjectiveDamaging;

static bool g_bObjectiveDome;
static int g_iObjectiveDome = INVALID_ENT_REFERENCE;
static int g_iObjectiveDomeTrigger = INVALID_ENT_REFERENCE;
static float g_vecObjectiveDome[3];
static float g_flObjectiveDomeStartRadius;
static float g_flObjectiveDomeRadius;
static float g_flObjectiveDomeStart;
static float g_flObjectiveDomeHold;
static bool g_bObjectiveDomeShown;
static int g_iObjectiveDomeAlpha;
static bool g_bObjectiveDomePrev;
static float g_vecObjectiveDomePrev[3];
static int g_iObjectiveDomePrevTrigger = INVALID_ENT_REFERENCE;
static float g_flObjectiveDomePrevRadius;
static float g_flObjectiveDomePrevHold;

static int g_iObjectiveZoneCount;
static int g_iObjectiveZoneMask = -1;
static int g_iObjectiveZoneTrigger[MAX_CONTROL_POINTS];
static float g_vecObjectiveZoneMins[MAX_CONTROL_POINTS][3];
static float g_vecObjectiveZoneMaxs[MAX_CONTROL_POINTS][3];

void Objective_Precache()
{
	g_bObjectiveModel = true;
	for (int i = 0; i < sizeof(g_sObjectiveDomeFiles); i++)
	{
		if (FileExists(g_sObjectiveDomeFiles[i], true))
			continue;
		
		LogError("No Left 4 Dead dome: %s isn't on the server", g_sObjectiveDomeFiles[i]);
		g_bObjectiveModel = false;
	}
	
	if (!g_bObjectiveModel)
		return;
	
	PrecacheModel(OBJECTIVE_DOME_MODEL);
	for (int i = 0; i < sizeof(g_sObjectiveDomeFiles); i++)
		AddFileToDownloadsTable(g_sObjectiveDomeFiles[i]);
	
	PrecacheSound(OBJECTIVE_DAMAGE_SOUND);
}

void Objective_OnRoundActive()
{
	Objective_End();
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		Objective_ResetClient(iClient);
}

void Objective_ResetClient(int iClient)
{
	g_flObjectiveOutside[iClient] = 0.0;
}

void Objective_OnPointCaptured()
{
	g_flObjectiveNextZones = 0.0;
}

void Objective_End()
{
	Objective_RemoveDome();
	g_bObjectiveOn = false;
	g_bObjectiveDomePrev = false;
	g_iObjectiveDomePrevTrigger = INVALID_ENT_REFERENCE;
	g_iObjectiveZoneCount = 0;
	g_iObjectiveZoneMask = -1;
	g_flObjectiveNextZones = 0.0;
}

void Objective_Update()
{
	if (!LastStand_IsLeft4DeadActive() || g_nRoundState != SZFRoundState_Active || !g_bObjectiveModel
		|| MapConfig_GetSetting(MapSetting_ObjectiveDome) == 0.0)
	{
		if (g_bObjectiveOn)
			Objective_End();
		
		return;
	}
	
	g_bObjectiveOn = true;
	
	float flNow = GetGameTime();
	Objective_DomeThink(flNow);
	
	if (g_flObjectiveNextCheck - flNow > OBJECTIVE_CHECK_INTERVAL)
		g_flObjectiveNextCheck = 0.0;
	
	if (flNow < g_flObjectiveNextCheck)
		return;
	
	float flElapsed = flNow - g_flObjectiveLastCheck;
	if (flElapsed <= 0.0 || flElapsed > OBJECTIVE_CHECK_INTERVAL * 5.0)
		flElapsed = OBJECTIVE_CHECK_INTERVAL;
	
	g_flObjectiveLastCheck = flNow;
	g_flObjectiveNextCheck = flNow + OBJECTIVE_CHECK_INTERVAL;
	
	if (flNow >= g_flObjectiveNextZones || g_flObjectiveNextZones - flNow > OBJECTIVE_ZONE_INTERVAL)
	{
		g_flObjectiveNextZones = flNow + OBJECTIVE_ZONE_INTERVAL;
		Objective_FindZones();
		Objective_PlaceDome(flNow);
	}
	
	if (!g_bObjectiveDome || EntRefToEntIndex(g_iObjectiveDome) <= MaxClients)
		return;
	
	Objective_CheckSurvivors(flNow, flElapsed);
	Objective_CheckBuildings(flNow);
}

static void Objective_PlaceDome(float flNow)
{
	if (g_bObjectiveDome)
	{
		for (int iZone = 0; iZone < g_iObjectiveZoneCount; iZone++)
			if (g_iObjectiveZoneTrigger[iZone] == g_iObjectiveDomeTrigger)
				return;
		
		for (int i = 0; i < 3; i++)
			g_vecObjectiveDomePrev[i] = g_vecObjectiveDome[i];
		
		g_bObjectiveDomePrev = true;
		g_iObjectiveDomePrevTrigger = g_iObjectiveDomeTrigger;
		g_flObjectiveDomePrevRadius = g_flObjectiveDomeRadius;
		g_flObjectiveDomePrevHold = fMax(OBJECTIVE_DOME_PREPARE, g_flObjectiveDomeHold - (flNow - g_flObjectiveDomeStart));
		Objective_RemoveDome();
	}
	
	if (!g_iObjectiveZoneCount)
		return;
	
	int iBest = -1;
	float flBest = 0.0;
	float vecBest[3];
	for (int iZone = 0; iZone < g_iObjectiveZoneCount; iZone++)
	{
		float vecCentre[3], vecFrom[3];
		Objective_GetZoneFloor(iZone, vecCentre);
		
		float flDistance = 0.0;
		if (g_bObjectiveDomePrev)
			flDistance = GetVectorDistance(vecCentre, g_vecObjectiveDomePrev);
		else if (Objective_GetGroupPosition(vecCentre, vecFrom))
			flDistance = GetVectorDistance(vecCentre, vecFrom);
		
		if (iBest != -1 && flDistance >= flBest)
			continue;
		
		iBest = iZone;
		flBest = flDistance;
		for (int i = 0; i < 3; i++)
			vecBest[i] = vecCentre[i];
	}
	
	for (int i = 0; i < 3; i++)
		g_vecObjectiveDome[i] = vecBest[i];
	
	g_flObjectiveDomeStartRadius = fMax(OBJECTIVE_DOME_END, flBest + OBJECTIVE_DOME_EXTRA);
	g_flObjectiveDomeHold = OBJECTIVE_DOME_HOLD;
	
	if (g_bObjectiveDomePrev && g_iObjectiveZoneTrigger[iBest] == g_iObjectiveDomePrevTrigger)
	{
		g_flObjectiveDomeStartRadius = g_flObjectiveDomePrevRadius;
		g_flObjectiveDomeHold = g_flObjectiveDomePrevHold;
	}
	
	g_flObjectiveDomeRadius = g_flObjectiveDomeStartRadius;
	g_flObjectiveDomeStart = flNow;
	g_iObjectiveDomeTrigger = g_iObjectiveZoneTrigger[iBest];
	g_bObjectiveDome = true;
	g_bObjectiveDomeShown = Objective_CreateDomeProp() > MaxClients;
	
	CPrintToChatDebug("Objective: dome at %.0f %.0f %.0f, radius %.0f (%.0f hu from %s + %.0f)", g_vecObjectiveDome[0], g_vecObjectiveDome[1], g_vecObjectiveDome[2],
		g_flObjectiveDomeStartRadius, flBest, g_bObjectiveDomePrev ? "the objective before" : "the survivors", OBJECTIVE_DOME_EXTRA);
}

static void Objective_GetZoneFloor(int iZone, float vecPos[3])
{
	float vecStart[3], vecEnd[3];
	for (int i = 0; i < 3; i++)
	{
		vecPos[i] = (g_vecObjectiveZoneMins[iZone][i] + g_vecObjectiveZoneMaxs[iZone][i]) * 0.5;
		vecStart[i] = vecPos[i];
		vecEnd[i] = vecPos[i];
	}
	
	vecEnd[2] = g_vecObjectiveZoneMins[iZone][2] - OBJECTIVE_FLOOR_REACH;
	
	for (int iTry = 0; iTry < 2; iTry++)
	{
		TR_TraceRayFilter(vecStart, vecEnd, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Trace_DontHitClients);
		if (TR_StartSolid())
		{
			vecStart[2] = g_vecObjectiveZoneMaxs[iZone][2];
			continue;
		}
		
		if (TR_DidHit())
			TR_GetEndPosition(vecPos);
		else
			vecPos[2] = g_vecObjectiveZoneMins[iZone][2];
		
		return;
	}
	
}

static bool Objective_GetGroupPosition(const float vecObjective[3], float vecPos[3])
{
	float vecOrigins[MAXPLAYERS][3];
	int iCount;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (iCount < MAXPLAYERS && IsValidLivingSurvivor(iClient))
		{
			GetClientAbsOrigin(iClient, vecOrigins[iCount]);
			iCount++;
		}
	}
	
	if (!iCount)
		return false;
	
	float vecSum[3];
	int iGrouped;
	for (int i = 0; i < iCount; i++)
	{
		bool bGrouped = false;
		for (int j = 0; j < iCount; j++)
		{
			if (j != i && GetVectorDistance(vecOrigins[i], vecOrigins[j], true) <= OBJECTIVE_GROUP_DISTANCE * OBJECTIVE_GROUP_DISTANCE)
			{
				bGrouped = true;
				break;
			}
		}
		
		if (!bGrouped)
			continue;
		
		iGrouped++;
		for (int k = 0; k < 3; k++)
			vecSum[k] += vecOrigins[i][k];
	}
	
	if (iGrouped)
	{
		for (int k = 0; k < 3; k++)
			vecPos[k] = vecSum[k] / float(iGrouped);
		
		return true;
	}
	
	int iClosest = -1, iSecond = -1;
	float flClosest = 0.0, flSecond = 0.0;
	for (int i = 0; i < iCount; i++)
	{
		float flDistance = GetVectorDistance(vecOrigins[i], vecObjective, true);
		if (iClosest == -1 || flDistance < flClosest)
		{
			iSecond = iClosest;
			flSecond = flClosest;
			iClosest = i;
			flClosest = flDistance;
		}
		else if (iSecond == -1 || flDistance < flSecond)
		{
			iSecond = i;
			flSecond = flDistance;
		}
	}
	
	int iPick = iSecond != -1 ? iSecond : iClosest;
	for (int k = 0; k < 3; k++)
		vecPos[k] = vecOrigins[iPick][k];
	
	return true;
}

static void Objective_DomeThink(float flNow)
{
	if (!g_bObjectiveDome)
		return;
	
	int iDome = EntRefToEntIndex(g_iObjectiveDome);
	if (iDome <= MaxClients)
	{
		iDome = Objective_CreateDomeProp();
		if (iDome <= MaxClients)
			return;
		
		if (!g_bObjectiveDomeShown)
		{
			g_bObjectiveDomeShown = true;
			g_flObjectiveDomeStart = flNow;
		}
	}
	
	float flAge = flNow - g_flObjectiveDomeStart;
	float flRadius = fMax(OBJECTIVE_DOME_END, g_flObjectiveDomeStartRadius - OBJECTIVE_DOME_SPEED * fMax(0.0, flAge - g_flObjectiveDomeHold));
	if (flRadius != g_flObjectiveDomeRadius)
	{
		g_flObjectiveDomeRadius = flRadius;
		SetEntPropFloat(iDome, Prop_Send, "m_flModelScale", Objective_GetDomeScale());
	}
	
	int iAlpha = 255;
	if (flAge < OBJECTIVE_DOME_PREPARE)
	{
		float flBlink = flAge - float(RoundToFloor(flAge));
		if (flBlink > 0.5)
			flBlink = 1.0 - flBlink;
		
		iAlpha = RoundToFloor(flBlink * 2.0 * 255.0);
	}
	
	if (iAlpha != g_iObjectiveDomeAlpha)
	{
		g_iObjectiveDomeAlpha = iAlpha;
		SetEntityRenderColor(iDome, g_iObjectiveDomeColor[0], g_iObjectiveDomeColor[1], g_iObjectiveDomeColor[2], iAlpha);
	}
}

static float Objective_GetDomeScale()
{
	return SquareRoot(g_flObjectiveDomeRadius / OBJECTIVE_DOME_PROP_RADIUS);
}

static int Objective_CreateDomeProp()
{
	if (GetEntityCount() > GetMaxEntities() - GLOW_EDICT_MARGIN)
		return INVALID_ENT_REFERENCE;
	
	int iDome = CreateEntityByName("prop_dynamic_override");
	if (iDome <= MaxClients)
		return INVALID_ENT_REFERENCE;
	
	DispatchKeyValue(iDome, "targetname", OBJECTIVE_DOME_NAME);
	DispatchKeyValue(iDome, "model", OBJECTIVE_DOME_MODEL);
	DispatchKeyValue(iDome, "solid", "0");
	DispatchKeyValue(iDome, "disableshadows", "1");
	DispatchKeyValueVector(iDome, "origin", g_vecObjectiveDome);
	SetEntPropFloat(iDome, Prop_Send, "m_flModelScale", Objective_GetDomeScale());
	DispatchSpawn(iDome);
	
	g_iObjectiveDomeAlpha = 0;
	SetEntityRenderMode(iDome, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iDome, g_iObjectiveDomeColor[0], g_iObjectiveDomeColor[1], g_iObjectiveDomeColor[2], 0);
	
	SetEdictFlags(iDome, GetEdictFlags(iDome) | FL_EDICT_ALWAYS);
	
	g_iObjectiveDome = EntIndexToEntRef(iDome);
	return iDome;
}

static void Objective_RemoveDome()
{
	int iDome = EntRefToEntIndex(g_iObjectiveDome);
	if (iDome > MaxClients)
		RemoveEntity(iDome);
	
	g_iObjectiveDome = INVALID_ENT_REFERENCE;
	g_iObjectiveDomeTrigger = INVALID_ENT_REFERENCE;
	g_bObjectiveDome = false;
}

static void Objective_CheckSurvivors(float flNow, float flElapsed)
{
	bool bLive = flNow - g_flObjectiveDomeStart >= OBJECTIVE_DOME_PREPARE;
	float flShown = float(g_iObjectiveDomeAlpha) / 255.0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsValidLivingSurvivor(iClient))
			continue;
		
		float vecEyes[3];
		GetClientEyePosition(iClient, vecEyes);
		float flPlace = GetVectorDistance(vecEyes, g_vecObjectiveDome) / g_flObjectiveDomeRadius;
		
		if (flPlace > OBJECTIVE_FADE_START && !IsFakeClient(iClient))
		{
			float flAlpha = float(OBJECTIVE_FADE_ALPHA) * flShown;
			if (flPlace < 1.0)
				flAlpha *= (flPlace - OBJECTIVE_FADE_START) / (1.0 - OBJECTIVE_FADE_START);
			
			Objective_Fade(iClient, RoundToNearest(flAlpha));
		}
		
		if (!bLive || flPlace <= 1.0)
			continue;
		
		g_flObjectiveOutside[iClient] += flElapsed;
		if (g_flObjectiveOutside[iClient] >= OBJECTIVE_DAMAGE_INTERVAL)
		{
			g_flObjectiveOutside[iClient] -= OBJECTIVE_DAMAGE_INTERVAL;
			Objective_Damage(iClient);
		}
	}
}

static void Objective_Fade(int iClient, int iAlpha)
{
	if (iAlpha <= 0)
		return;
	
	BfWrite bf = UserMessageToBfWrite(StartMessageOne("Fade", iClient));
	bf.WriteShort(OBJECTIVE_FADE_DURATION);
	bf.WriteShort(0);
	bf.WriteShort(0x0001);
	bf.WriteByte(g_iObjectiveDomeColor[0]);
	bf.WriteByte(g_iObjectiveDomeColor[1]);
	bf.WriteByte(g_iObjectiveDomeColor[2]);
	bf.WriteByte(iAlpha);
	EndMessage();
}

static void Objective_CheckBuildings(float flNow)
{
	if (g_flObjectiveNextBuildings - flNow > OBJECTIVE_BUILDING_INTERVAL)
		g_flObjectiveNextBuildings = 0.0;
	
	float flDue = g_flObjectiveNextBuildings;
	if (flNow < flDue || flNow - g_flObjectiveDomeStart < OBJECTIVE_DOME_PREPARE)
		return;
	
	if (flDue > 0.0 && flNow - flDue < OBJECTIVE_BUILDING_INTERVAL)
		g_flObjectiveNextBuildings = flDue + OBJECTIVE_BUILDING_INTERVAL;
	else
		g_flObjectiveNextBuildings = flNow + OBJECTIVE_BUILDING_INTERVAL;
	
	int iBuilding = -1;
	while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1)
	{
		if (GetEntProp(iBuilding, Prop_Send, "m_iTeamNum") != view_as<int>(TFTeam_Survivor)
			|| GetEntProp(iBuilding, Prop_Send, "m_bCarried") || GetEntProp(iBuilding, Prop_Send, "m_bPlacing"))
			continue;
		
		float vecOrigin[3];
		GetEntPropVector(iBuilding, Prop_Data, "m_vecAbsOrigin", vecOrigin);
		if (GetVectorDistance(vecOrigin, g_vecObjectiveDome) <= g_flObjectiveDomeRadius)
			continue;
		
		SetVariantInt(OBJECTIVE_BUILDING_DAMAGE);
		AcceptEntityInput(iBuilding, "RemoveHealth");
	}
}

static void Objective_Damage(int iClient)
{
	g_iObjectiveDamaging = iClient;
	SDKHooks_TakeDamage(iClient, iClient, iClient, OBJECTIVE_DAMAGE, DMG_PREVENT_PHYSICS_FORCE);
	g_iObjectiveDamaging = 0;
	
	if (!IsClientInGame(iClient))
		return;
	
	if (!IsFakeClient(iClient))
		EmitSoundToClient(iClient, OBJECTIVE_DAMAGE_SOUND);
	
	if (IsPlayerAlive(iClient))
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
		
		float vecOrigin[3], vecMins[3], vecMaxs[3];
		GetEntPropVector(iTrigger, Prop_Data, "m_vecAbsOrigin", vecOrigin);
		GetEntPropVector(iTrigger, Prop_Data, "m_vecMins", vecMins);
		GetEntPropVector(iTrigger, Prop_Data, "m_vecMaxs", vecMaxs);
		for (int i = 0; i < 3; i++)
		{
			g_vecObjectiveZoneMins[iZone][i] = vecOrigin[i] + vecMins[i];
			g_vecObjectiveZoneMaxs[iZone][i] = vecOrigin[i] + vecMaxs[i];
		}
	}
	
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
