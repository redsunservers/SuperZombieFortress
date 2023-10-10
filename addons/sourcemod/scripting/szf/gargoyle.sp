#define GARGOYLE_MODEL	"models/props_halloween/gargoyle_ghost.mdl"

static int g_iGargoyleCount;
static int g_iGargoyleCountMax;
static ArrayList g_aAvailableSpawns;

void Gargoyle_Init()
{
	HookEvent("teamplay_round_start", Gargoyle_RoundStart);
	g_aAvailableSpawns = new ArrayList(3);
}

void Gargoyle_Precache()
{
	PrecacheModel(GARGOYLE_MODEL);
}

void Gargoyle_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled || !IsMapZI())
		return;
	
	g_iGargoyleCount = 0;
	g_iGargoyleCountMax = 0;
	g_aAvailableSpawns.Clear();
	
	int iEntity = INVALID_ENT_REFERENCE;
	while ((iEntity = FindEntityByClassname(iEntity, "tf_halloween_gift_spawn_location")) != INVALID_ENT_REFERENCE)
	{
		float vecOrigin[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);
		g_aAvailableSpawns.PushArray(vecOrigin);
		g_iGargoyleCountMax++;
	}
}

void Gargoyle_Spawn()
{
	int iIndex = GetRandomInt(0, g_aAvailableSpawns.Length - 1);
	
	float vecOrigin[3];
	g_aAvailableSpawns.GetArray(iIndex, vecOrigin, sizeof(vecOrigin));
	g_aAvailableSpawns.Erase(iIndex);
	g_iGargoyleCount++;
	
	int iGargoyle = CreateEntityByName("prop_dynamic");
	SetEntityModel(iGargoyle, GARGOYLE_MODEL);
	DispatchKeyValue(iGargoyle, "DefaultAnim", "spin");
	SetEntProp(iGargoyle, Prop_Send, "m_nSolidType", SOLID_BBOX);
	SetEntProp(iGargoyle, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID|FSOLID_TRIGGER);
	
	TeleportEntity(iGargoyle, vecOrigin);
	
	DispatchSpawn(iGargoyle);
	ShowParticle("duck_collect_green", 3.0, vecOrigin);
	
	SDKHook(iGargoyle, SDKHook_TouchPost, Gargoyle_TouchPost);
}

void Gargoyle_TouchPost(int iGargoyle, int iToucher)
{
	if (!IsValidLivingSurvivor(iToucher))
		return;
	
	float vecOrigin[3];
	GetEntPropVector(iGargoyle, Prop_Send, "m_vecOrigin", vecOrigin);
	g_aAvailableSpawns.PushArray(vecOrigin);
	
	ShowParticle("duck_collect_green", 3.0, vecOrigin);
	RemoveEntity(iGargoyle);
	
	g_iGargoyleCount--;
	
	TF2_AddCondition(iToucher, TFCond_HalloweenQuickHeal, 0.5);
}

void Gargoyle_Timer()
{
	if (g_iGargoyleCountMax == 0)
		return;
	
	static float flLastPlacement;
	if (g_nRoundState != SZFRoundState_Active)
	{
		flLastPlacement = 0.0;
		return;
	}
	
	if (g_aAvailableSpawns.Length == 0)
		flLastPlacement = 0.0;
	else if (!flLastPlacement)
		flLastPlacement = GetGameTime();
	
	if (flLastPlacement)
	{
		int iSurvivors = GetSurvivorCount();
		int iZombies = GetZombieCount();
		float flPercentage = float(iZombies) / float(iSurvivors + iZombies);
		
		float flMin = g_cvGargoyleSpawnMin.FloatValue;
		float flMax = g_cvGargoyleSpawnMax.FloatValue;
		
		float flSpawnTime = (flMax - flMin) * flPercentage + flMin;
		flSpawnTime /= g_iGargoyleCountMax;
		if (flLastPlacement + flSpawnTime <= GetGameTime())
		{
			flLastPlacement = GetGameTime();
			Gargoyle_Spawn();
		}
	}
	
	char sMeter[256];
	for (int i = 0; i < g_iGargoyleCount; i++)
		StrCat(sMeter, sizeof(sMeter), "▰");
	
	for (int i = g_iGargoyleCount; i < g_iGargoyleCountMax; i++)
		StrCat(sMeter, sizeof(sMeter), "▱");
	
	float flPercentage = float(g_iGargoyleCount) / float(g_iGargoyleCountMax);
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;
		
		if (IsValidZombie(iClient))
			SetHudTextParams(0.18, 0.71, 1.0, RoundToNearest(255.0 * (1.0 - flPercentage)), RoundToNearest(255.0 * flPercentage), 0, 255);
		else
			SetHudTextParams(0.18, 0.71, 1.0, RoundToNearest(255.0 * flPercentage), RoundToNearest(255.0 * (1.0 - flPercentage)), 0, 255);
		
		ShowHudText(iClient, 3, "Gargoyle: %s", sMeter);	// TODO translation
	}
}

float Gargoyle_GetScaling()
{
	if (g_iGargoyleCountMax == 0)
		return 0.0;
	
	float flPercentage = float(g_iGargoyleCount) / float(g_iGargoyleCountMax);
	return (flPercentage - 0.5) * 0.4;
}