#define FFADE_IN			0x0001		// Just here so we don't pass 0 into the function
#define FFADE_OUT			0x0002		// Fade out (not in)
#define FFADE_MODULATE		0x0004		// Modulate (don't blend)
#define FFADE_STAYOUT		0x0008		// ignores the duration, stays faded out until new ScreenFade message received
#define FFADE_PURGE			0x0010		// Purges all other fades, replacing them with this one

#define SCREENFADE_FRACBITS		9


#define HIDEHUD_WEAPONSELECTION		( 1<<0 )	// Hide ammo count & weapon selection
#define HIDEHUD_FLASHLIGHT			( 1<<1 )
#define HIDEHUD_ALL					( 1<<2 )
#define HIDEHUD_HEALTH				( 1<<3 )	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD			( 1<<4 )	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT			( 1<<5 )	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS			( 1<<6 )	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT				( 1<<7 )	// Hide all communication elements (saytext, voice icon, etc)
#define HIDEHUD_CROSSHAIR			( 1<<8 )	// Hide crosshairs
#define HIDEHUD_VEHICLE_CROSSHAIR	( 1<<9 )	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE			( 1<<10 )
#define HIDEHUD_BONUS_PROGRESS		( 1<<11 )	// Hide bonus progress display (for bonus map challenges)

#define HIDEHUD_BITCOUNT			12


#define BLIND_HIDEHUD				(HIDEHUD_HEALTH|HIDEHUD_MISCSTATUS|HIDEHUD_CROSSHAIR|HIDEHUD_BONUS_PROGRESS)

#define STUN_SPEED_MULTI			0.8
#define STUN_FOG_START_FRACTION		0.5

static const int g_iStunTeammateGlowColor[4] = {255, 255, 255, 255};

enum struct StunInfo
{
	bool bStunned;
	bool bCooldown;
	int iPreviousFogEnt;
	int iCurrentFogEnt;
	int iFogEnt;
	float flFogEnd;
	
	bool bSkyFogSaved;
	int iSkyFogEnable;
	int iSkyFogBlend;
	int iSkyFogColor;
	float flSkyFogStart;
	float flSkyFogEnd;
	float flSkyFogMaxDensity;
	ArrayList aTimers;
}

static StunInfo g_StunInfo[MAXPLAYERS+1];

// -----------------------
// MAIN
// -----------------------

bool Stun_IsPlayerStunned(int iClient)
{
	return g_StunInfo[iClient].bStunned;
}

bool Stun_CanStartPlayer(int iClient)
{
	return !g_StunInfo[iClient].bStunned && !g_StunInfo[iClient].bCooldown && !IsLastManStanding(iClient);
}

bool Stun_StartPlayer(int iClient, float flDuration = 6.0)
{
	if (g_StunInfo[iClient].bStunned || g_StunInfo[iClient].bCooldown)
		return false;	//Already stunned
	
	if (IsLastManStanding(iClient))
		return false;
	
	g_StunInfo[iClient].bStunned = true;
	g_StunInfo[iClient].aTimers = new ArrayList();
	
	if (IsSurvivor(iClient))
	{
		for (int iTeammate = 1; iTeammate <= MaxClients; iTeammate++)
			if (iTeammate != iClient && IsValidLivingSurvivor(iTeammate))
				Glow_Create(iClient, iTeammate, GlowType_StunTeammate, g_iStunTeammateGlowColor);
	}
	
	Stun_ShakeRandom(iClient);
	
	ClientCommand(iClient, "r_screenoverlay\"debug/yuv\"");
	Sound_PlayMusicToClient(iClient, "backstab", flDuration);
	
	SetEntProp(iClient, Prop_Send, "m_iHideHUD", GetEntProp(iClient, Prop_Send, "m_iHideHUD")|BLIND_HIDEHUD);
	TF2Attrib_SetByName(iClient, "deploy time increased", 2.0);
	
	Handle hTimer = CreateTimer(flDuration, Stun_EndPlayerTimer, GetClientSerial(iClient));
	g_StunInfo[iClient].aTimers.Push(hTimer);
	return true;
}

void Stun_ResetClient(int iClient)
{
	if (g_StunInfo[iClient].bStunned && IsClientInGame(iClient))
		ClientCommand(iClient, "r_screenoverlay\"\"");
	
	g_StunInfo[iClient].bStunned = false;
	g_StunInfo[iClient].bCooldown = false;
	g_StunInfo[iClient].iPreviousFogEnt = INVALID_ENT_REFERENCE;
	g_StunInfo[iClient].bSkyFogSaved = false;
	Stun_RemoveFog(iClient);
	delete g_StunInfo[iClient].aTimers;
}

void Stun_OnPostThinkPost(int iClient)
{
	if (g_StunInfo[iClient].bStunned)
		Stun_ClientThink(iClient);
	else
		Stun_CheckObserverFog(iClient);
}

void Stun_EndPlayer(int iClient)
{
	if (!g_StunInfo[iClient].bStunned)
		return;
	
	if (IsPlayerAlive(iClient))	//Keep grey screen if dead
		ClientCommand(iClient, "r_screenoverlay\"\"");
	
	if (IsValidEntity(g_StunInfo[iClient].iPreviousFogEnt))
		SetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl", g_StunInfo[iClient].iPreviousFogEnt);
	else
		SetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl", INVALID_ENT_REFERENCE);
	
	g_StunInfo[iClient].iPreviousFogEnt = INVALID_ENT_REFERENCE;
	g_StunInfo[iClient].bStunned = false;
	delete g_StunInfo[iClient].aTimers;
	
	Stun_RestoreSkyFog(iClient);
	
	Stun_RemoveFog(iClient);
	Glow_RemoveViewer(iClient, GlowType_StunTeammate);
	
	float flCooldown = g_cvStunImmunity.FloatValue;
	if (flCooldown > 0.0)
	{
		CreateTimer(flCooldown, Stun_EndCooldownTimer, GetClientSerial(iClient));
		g_StunInfo[iClient].bCooldown = true;
	}
	
	if (IsPlayerAlive(iClient))
		SetEntProp(iClient, Prop_Send, "m_iHideHUD", GetEntProp(iClient, Prop_Send, "m_iHideHUD") & ~BLIND_HIDEHUD);
	
	TF2Attrib_RemoveByName(iClient, "deploy time increased");
	
	SDKCall_SetSpeed(iClient);
}

public Action Stun_EndPlayerTimer(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!IsValidClient(iClient))
		return Plugin_Continue;
	
	if (!g_StunInfo[iClient].aTimers || g_StunInfo[iClient].aTimers.FindValue(hTimer) == -1)
		return Plugin_Continue;
	
	Stun_EndPlayer(iClient);
	return Plugin_Continue;
}

public Action Stun_EndCooldownTimer(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!IsValidClient(iClient))
		return Plugin_Continue;
	
	
	g_StunInfo[iClient].bCooldown = false;
	return Plugin_Continue;
}

// -----------------------
// FOG
// -----------------------

void Stun_ClientThink(int iClient)
{
	int iFogEnt = g_StunInfo[iClient].iFogEnt;
	if (EntRefToEntIndex(iFogEnt) <= MaxClients)
	{
		iFogEnt = CreateEntityByName("env_fog_controller");
		if (iFogEnt == -1)
			return;
		
		float flDistance = g_cvStunFogDistance.FloatValue;
		DispatchKeyValueFloat(iFogEnt, "fogstart", flDistance * STUN_FOG_START_FRACTION);
		DispatchKeyValueFloat(iFogEnt, "fogend", flDistance);
		DispatchKeyValue(iFogEnt, "fogenable", "1");
		DispatchKeyValue(iFogEnt, "fogmaxdensity", "1");
		DispatchKeyValue(iFogEnt, "fogcolor", "0 0 0");
		DispatchKeyValue(iFogEnt, "fogcolor2", "171 177 209");
		
		DispatchSpawn(iFogEnt);
		iFogEnt = EntIndexToEntRef(iFogEnt);
		g_StunInfo[iClient].iFogEnt = iFogEnt;
		g_StunInfo[iClient].flFogEnd = -1.0;
	}
	
	float flFogEnd = g_cvStunFogDistance.FloatValue;
	if (FloatAbs(flFogEnd - g_StunInfo[iClient].flFogEnd) >= 1.0)
	{
		g_StunInfo[iClient].flFogEnd = flFogEnd;
		
		float flFogStart = flFogEnd * STUN_FOG_START_FRACTION;
		SetVariantFloat(flFogStart);
		AcceptEntityInput(iFogEnt, "SetStartDist");
		SetVariantFloat(flFogEnd);
		AcceptEntityInput(iFogEnt, "SetEndDist");
		
		Stun_SetSkyFog(iClient, flFogStart, flFogEnd);
	}
	
	int iPreviousFogEnt = GetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl");
	if (iPreviousFogEnt != INVALID_ENT_REFERENCE)
		iPreviousFogEnt = EntIndexToEntRef(iPreviousFogEnt);
	
	if (iPreviousFogEnt != iFogEnt)
	{
		g_StunInfo[iClient].iPreviousFogEnt = iPreviousFogEnt;
		SetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl", iFogEnt);
	}
	
	SetEntProp(iClient, Prop_Send, "m_iAirDash", 999);	// Prevent any double-jumping
	SDKCall_SetSpeed(iClient);	//Recalculate speed every frame
}

static void Stun_RemoveFog(int iClient)
{
	int iFogEnt = EntRefToEntIndex(g_StunInfo[iClient].iFogEnt);
	g_StunInfo[iClient].iFogEnt = INVALID_ENT_REFERENCE;
	if (iFogEnt > MaxClients)
		RemoveEntity(iFogEnt);
}

static void Stun_CheckObserverFog(int iClient)
{
	int iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
	if (!(0 < iTarget <= MaxClients) || !g_StunInfo[iTarget].bStunned)
		return;
	
	int iFogEnt = EntRefToEntIndex(g_StunInfo[iTarget].iFogEnt);
	if (iFogEnt <= MaxClients || GetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl") != iFogEnt)
		return;
	
	SetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl", EntRefToEntIndex(g_StunInfo[iTarget].iPreviousFogEnt));
}

static void Stun_SetSkyFog(int iClient, float flStart, float flEnd)
{
	if (GetEntProp(iClient, Prop_Send, "m_skybox3d.area") == 255)
		return;
	
	if (!g_StunInfo[iClient].bSkyFogSaved)
	{
		g_StunInfo[iClient].bSkyFogSaved = true;
		g_StunInfo[iClient].iSkyFogEnable = GetEntProp(iClient, Prop_Send, "m_skybox3d.fog.enable");
		g_StunInfo[iClient].iSkyFogBlend = GetEntProp(iClient, Prop_Send, "m_skybox3d.fog.blend");
		g_StunInfo[iClient].iSkyFogColor = GetEntProp(iClient, Prop_Send, "m_skybox3d.fog.colorPrimary");
		g_StunInfo[iClient].flSkyFogStart = GetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.start");
		g_StunInfo[iClient].flSkyFogEnd = GetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.end");
		g_StunInfo[iClient].flSkyFogMaxDensity = GetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.maxdensity");
		
		SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.enable", 1);
		SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.blend", 0);
		SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.colorPrimary", g_StunInfo[iClient].iSkyFogColor & 0xFF000000);
		SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.maxdensity", 1.0);
	}
	
	SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.start", flStart);
	SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.end", flEnd);
}

static void Stun_RestoreSkyFog(int iClient)
{
	if (!g_StunInfo[iClient].bSkyFogSaved)
		return;
	
	g_StunInfo[iClient].bSkyFogSaved = false;
	SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.enable", g_StunInfo[iClient].iSkyFogEnable);
	SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.blend", g_StunInfo[iClient].iSkyFogBlend);
	SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.colorPrimary", g_StunInfo[iClient].iSkyFogColor);
	SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.start", g_StunInfo[iClient].flSkyFogStart);
	SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.end", g_StunInfo[iClient].flSkyFogEnd);
	SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.maxdensity", g_StunInfo[iClient].flSkyFogMaxDensity);
}

// -----------------------
// -----------------------

float Stun_GetSpeedMulti(int iClient)
{
	if (!g_StunInfo[iClient].bStunned)
		return 1.0;
	
	return STUN_SPEED_MULTI;
}

// -----------------------
// SHAKE
// -----------------------

void Stun_ShakeRandom(int iClient)
{
	float vecVel[3];
	for (int i = 0; i < sizeof(vecVel); i++)
		vecVel[i] = GetRandomFloat(-1.0, 1.0);
	
	Stun_Shake(iClient, vecVel, 1000.0);
}

void Stun_Shake(int iClient, float vecVel[3], float flScale)
{
	NormalizeVector(vecVel, vecVel);
	ScaleVector(vecVel, flScale);
	
	float vecBuffer[3];
	SetEntPropVector(iClient, Prop_Send, "m_vecPunchAngleVel", vecBuffer);
	AddVectors(vecVel, vecBuffer, vecBuffer);
	SetEntPropVector(iClient, Prop_Send, "m_vecPunchAngleVel", vecBuffer);
}