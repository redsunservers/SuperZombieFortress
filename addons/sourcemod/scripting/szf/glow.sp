enum GlowType
{
	GlowType_StunTeammate = 0,
	GlowType_BoomerPack,
	
	GlowType_Count
}

#define GLOW_EDICT_MARGIN		256

static ArrayList g_aGlows;
static int g_iGlowViewer[2048];
static int g_iGlowTarget[2048];
static GlowType g_nGlowType[2048];

void Glow_Clear()
{
	delete g_aGlows;
	g_aGlows = new ArrayList();
}

void Glow_Create(int iViewer, int iTarget, GlowType nType, const int iColor[4])
{
	if (!g_aGlows)
		g_aGlows = new ArrayList();
	
	if (iViewer == iTarget || Glow_Find(iViewer, iTarget, nType) != -1)
		return;
	
	if (IsFakeClient(iViewer) || GetEntityCount() > GetMaxEntities() - GLOW_EDICT_MARGIN)
		return;
	
	char sOldName[128], sName[64];
	GetEntPropString(iTarget, Prop_Data, "m_iName", sOldName, sizeof(sOldName));
	FormatEx(sName, sizeof(sName), "szf_glow_target_%d", iTarget);
	DispatchKeyValue(iTarget, "targetname", sName);
	
	int iGlow = CreateEntityByName("tf_glow");
	if (iGlow > MaxClients)
	{
		char sColor[32];
		FormatEx(sColor, sizeof(sColor), "%d %d %d %d", iColor[0], iColor[1], iColor[2], iColor[3]);
		DispatchKeyValue(iGlow, "target", sName);
		DispatchKeyValue(iGlow, "Mode", "0");
		DispatchKeyValue(iGlow, "GlowColor", sColor);
		DispatchSpawn(iGlow);
	}
	
	DispatchKeyValue(iTarget, "targetname", sOldName);
	
	if (iGlow <= MaxClients)
		return;
	
	if (GetEntPropEnt(iGlow, Prop_Send, "m_hTarget") != iTarget)
	{
		RemoveEntity(iGlow);
		return;
	}
	
	SetVariantString("!activator");
	AcceptEntityInput(iGlow, "SetParent", iTarget, iTarget);
	
	g_iGlowViewer[iGlow] = iViewer;
	g_iGlowTarget[iGlow] = iTarget;
	g_nGlowType[iGlow] = nType;
	g_aGlows.Push(EntIndexToEntRef(iGlow));
	
	Glow_ClearAlwaysFlag(iGlow);
	SDKHook(iGlow, SDKHook_SetTransmit, Glow_SetTransmit);
}

public Action Glow_SetTransmit(int iGlow, int iClient)
{
	Glow_ClearAlwaysFlag(iGlow);
	
	if (iClient != g_iGlowViewer[iGlow])
		return Plugin_Handled;
	
	return Plugin_Continue;
}

static void Glow_ClearAlwaysFlag(int iGlow)
{
	int iFlags = GetEdictFlags(iGlow);
	if (iFlags & FL_EDICT_ALWAYS)
		SetEdictFlags(iGlow, iFlags & ~FL_EDICT_ALWAYS);
}

static int Glow_Find(int iViewer, int iTarget, GlowType nType)
{
	for (int i = g_aGlows.Length - 1; i >= 0; i--)
	{
		int iGlow = EntRefToEntIndex(g_aGlows.Get(i));
		if (iGlow <= MaxClients)
		{
			g_aGlows.Erase(i);
			continue;
		}
		
		if (g_iGlowViewer[iGlow] == iViewer && g_iGlowTarget[iGlow] == iTarget && g_nGlowType[iGlow] == nType)
			return i;
	}
	
	return -1;
}

void Glow_RemoveViewer(int iClient, GlowType nType)
{
	Glow_Remove(iClient, 0, nType);
}

void Glow_RemoveClient(int iClient)
{
	if (iClient <= 0)
		return;
	
	for (int i = 0; i < view_as<int>(GlowType_Count); i++)
	{
		Glow_Remove(iClient, 0, view_as<GlowType>(i));
		Glow_Remove(0, iClient, view_as<GlowType>(i));
	}
}

void Glow_Remove(int iViewer, int iTarget, GlowType nType)
{
	if (!g_aGlows)
		return;
	
	for (int i = g_aGlows.Length - 1; i >= 0; i--)
	{
		int iGlow = EntRefToEntIndex(g_aGlows.Get(i));
		if (iGlow <= MaxClients)
		{
			g_aGlows.Erase(i);
			continue;
		}
		
		if (g_nGlowType[iGlow] != nType || (iViewer && g_iGlowViewer[iGlow] != iViewer) || (iTarget && g_iGlowTarget[iGlow] != iTarget))
			continue;
		
		g_aGlows.Erase(i);
		RemoveEntity(iGlow);
	}
}
