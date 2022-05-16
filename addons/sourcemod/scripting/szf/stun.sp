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

#define BLIND_COLOR			{0, 0, 0, 255}
#define BLIND_MULTI_SPEED_MIN		0.5

enum struct StunInfo
{
	bool bStunned;
	int iPreviousFogEnt;
	int iCurrentFogEnt;
	
	float flCurrentBlinkStart;
	float flCurrentBlinkStartHold;
	float flCurrentBlinkEndHold;
	float flCurrentBlinkEnd;
}

static StunInfo g_StunInfo[TF_MAXPLAYERS];

// -----------------------
// MAIN
// -----------------------

bool Stun_IsPlayerStunned(int iClient)
{
	return g_StunInfo[iClient].bStunned;
}

bool Stun_StartPlayer(int iClient, float flDuration = 10.0)
{
	if (g_StunInfo[iClient].bStunned)
		return false;	//Already stunned
	
	const float flFirstFade = 1.0;
	DataPack hPack;
	
	CreateFade(iClient, flFirstFade, 0.0, FFADE_IN|FFADE_PURGE, BLIND_COLOR);
	
	Stun_ShakeRandom(iClient);
	
	ClientCommand(iClient, "r_screenoverlay\"debug/yuv\"");
	Sound_PlayMusicToClient(iClient, "backstab", flDuration);
	
	float flFadeIn, flFadeHold, flFadeOut;
	Stun_GetRandomBlinkDuration(flDuration, flFadeIn, flFadeHold, flFadeOut);
	flFadeOut = 1.0;
	
	CreateDataTimer(flDuration - flFadeIn - flFadeHold, Stun_StartBlinkTimer, hPack);
	hPack.WriteCell(GetClientSerial(iClient));
	hPack.WriteFloat(flFadeIn);
	hPack.WriteFloat(flFadeHold);
	hPack.WriteFloat(1.0);
	
	float flDurationMade = flFirstFade;
	float flDurationLeft = flDuration - flFadeIn - flFadeHold - flDurationMade;
	while (Stun_GetRandomBlinkDuration(flDurationLeft, flFadeIn, flFadeHold, flFadeOut))
	{
		CreateDataTimer(flDurationMade, Stun_StartBlinkTimer, hPack);
		hPack.WriteCell(GetClientSerial(iClient));
		hPack.WriteFloat(flFadeIn);
		hPack.WriteFloat(flFadeHold);
		hPack.WriteFloat(flFadeOut);
		
		flDurationMade += flFadeIn + flFadeHold + flFadeOut;
		flDurationLeft -= flFadeIn + flFadeHold + flFadeOut;
	}
	
	g_StunInfo[iClient].bStunned = true;
	
	SetEntProp(iClient, Prop_Send, "m_iHideHUD", GetEntProp(iClient, Prop_Send, "m_iHideHUD")|HIDEHUD_ALL);
	
	SDKHook(iClient, SDKHook_PostThinkPost, Stun_ClientThink);
	CreateTimer(flDuration, Stun_EndPlayerTimer, GetClientSerial(iClient));
	return true;
}

void Stun_EndPlayer(int iClient)
{
	ClientCommand(iClient, "r_screenoverlay\"\"");
	
	SetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl", g_StunInfo[iClient].iPreviousFogEnt);
	g_StunInfo[iClient].iPreviousFogEnt = INVALID_ENT_REFERENCE;
	g_StunInfo[iClient].bStunned = false;
	
	SetEntProp(iClient, Prop_Send, "m_iHideHUD", GetEntProp(iClient, Prop_Send, "m_iHideHUD") & ~HIDEHUD_ALL);
	TF2_RemoveCondition(iClient, TFCond_LostFooting);
	SDKUnhook(iClient, SDKHook_PostThinkPost, Stun_ClientThink);
	SDKCall_SetSpeed(iClient);
}

public Action Stun_EndPlayerTimer(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Continue;
	
	Stun_EndPlayer(iClient);
	return Plugin_Continue;
}

// -----------------------
// FOG
// -----------------------

void Stun_ClientThink(int iClient)
{
	static int iFogEnt = INVALID_ENT_REFERENCE;
	static int iFog = 512;
	
	if (!IsValidEntity(iFogEnt))
	{
		iFogEnt = EntIndexToEntRef(CreateEntityByName("env_fog_controller"));
		DispatchKeyValue(iFogEnt, "fogstart", "512");
		DispatchKeyValue(iFogEnt, "fogend", "512");
		DispatchKeyValue(iFogEnt, "fogenable", "1");
		DispatchKeyValue(iFogEnt, "fogcolor", "0 0 0");
		DispatchKeyValue(iFogEnt, "fogcolor2", "171 177 209");
		
		DispatchSpawn(iFogEnt);
	}
	
	iFog--;
	
	SetVariantFloat(float(iFog));
	AcceptEntityInput(iFogEnt, "SetStartDist");
	
	int iPreviousFogEnt = EntIndexToEntRef(GetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl"));
	if (iPreviousFogEnt != iFogEnt)
	{
		g_StunInfo[iClient].iPreviousFogEnt = iPreviousFogEnt;
		SetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl", iFogEnt);
	}
	
	TF2_AddCondition(iClient, TFCond_LostFooting, TFCondDuration_Infinite);
	SDKCall_SetSpeed(iClient);	//Recalculate speed every frame
}

// -----------------------
// BLINK
// -----------------------

Action Stun_StartBlinkTimer(Handle hTimer, DataPack hPack)
{
	hPack.Reset();
	int iClient = GetClientFromSerial(hPack.ReadCell());
	float flFadeIn = hPack.ReadFloat();
	float flFadeHold = hPack.ReadFloat();
	float flFadeOut = hPack.ReadFloat();
	
	CreateFade(iClient, flFadeIn, flFadeHold, FFADE_OUT|FFADE_PURGE, BLIND_COLOR);
	
	CreateDataTimer(flFadeIn, Stun_EndBlinkTimer, hPack);
	hPack.WriteCell(GetClientSerial(iClient));
	hPack.WriteFloat(flFadeHold);
	hPack.WriteFloat(flFadeOut);
	
	float flGameTime = GetGameTime();
	g_StunInfo[iClient].flCurrentBlinkStart = flGameTime;
	g_StunInfo[iClient].flCurrentBlinkStartHold = flGameTime + flFadeIn;
	g_StunInfo[iClient].flCurrentBlinkEndHold = flGameTime + flFadeIn + flFadeHold;
	g_StunInfo[iClient].flCurrentBlinkEnd = flGameTime + flFadeIn + flFadeHold + flFadeOut;
	
	return Plugin_Continue;
}

Action Stun_EndBlinkTimer(Handle hTimer, DataPack hPack)
{
	hPack.Reset();
	int iClient = GetClientFromSerial(hPack.ReadCell());
	float flFadeHold = hPack.ReadFloat();
	float flFadeOut = hPack.ReadFloat();
	
	CreateFade(iClient, flFadeOut, flFadeHold, FFADE_IN|FFADE_PURGE, BLIND_COLOR);
	
	return Plugin_Continue;
}

void CreateFade(int iClient, float flDuration, float flHoldTime, int iFlags, int iColor[4])
{
	BfWrite bf = UserMessageToBfWrite(StartMessageOne("Fade", iClient));
	bf.WriteShort(RoundToNearest(flDuration * (1 << SCREENFADE_FRACBITS)));	//Fade duration
	bf.WriteShort(RoundToNearest(flHoldTime * (1 << SCREENFADE_FRACBITS)));	//Hold Time
	bf.WriteShort(iFlags);		//Fade type
	bf.WriteByte(iColor[0]);	//Red
	bf.WriteByte(iColor[1]);	//Green
	bf.WriteByte(iColor[2]);	//Blue
	bf.WriteByte(iColor[3]);	//Alpha
	EndMessage();
}

float Stun_GetSpeedMulti(int iClient)
{
	if (!g_StunInfo[iClient].bStunned)
		return 1.0;
	
	float flGameTime = GetGameTime();
	if (g_StunInfo[iClient].flCurrentBlinkStart <= flGameTime <= g_StunInfo[iClient].flCurrentBlinkStartHold)
	{
		float flDuration = g_StunInfo[iClient].flCurrentBlinkStartHold - g_StunInfo[iClient].flCurrentBlinkStart;
		float flProgress = flGameTime - g_StunInfo[iClient].flCurrentBlinkStart;
		float flPercentage = 1.0 - (flProgress / flDuration);
		return (flPercentage * (1.0 - BLIND_MULTI_SPEED_MIN)) + BLIND_MULTI_SPEED_MIN;
	}
	else if (g_StunInfo[iClient].flCurrentBlinkStartHold <= flGameTime <= g_StunInfo[iClient].flCurrentBlinkEndHold)
	{
		return BLIND_MULTI_SPEED_MIN;
	}
	else if (g_StunInfo[iClient].flCurrentBlinkEndHold <= flGameTime <= g_StunInfo[iClient].flCurrentBlinkEnd)
	{
		float flDuration = g_StunInfo[iClient].flCurrentBlinkEnd - g_StunInfo[iClient].flCurrentBlinkEndHold;
		float flProgress = flGameTime - g_StunInfo[iClient].flCurrentBlinkEndHold;
		float flPercentage = (flProgress / flDuration);
		return (flPercentage * (1.0 - BLIND_MULTI_SPEED_MIN)) + BLIND_MULTI_SPEED_MIN;
	}
	else
	{
		return 1.0;
	}
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

bool Stun_GetRandomBlinkDuration(float flDurationLeft, float &flFadeIn, float &flFadeHold, float &flFadeOut)
{
	const float flMinDuration = 3.0;
	const float flMaxDuration = 6.0;
	
	float flTotalDuration;
	
	if (flDurationLeft < flMinDuration)
	{
		return false;
	}
	else if (flMinDuration <= flDurationLeft < flMaxDuration)
	{
		flTotalDuration = flDurationLeft;
	}
	else
	{
		float flDuration = flDurationLeft - flMinDuration;
		if (flDuration > flMaxDuration)
			flDuration = flMaxDuration;
		
		flTotalDuration = GetRandomFloat(flMinDuration, flDuration);
	}
	
	//flFadeHold = GetRandomFloat(1.0, 2.0);
	flFadeHold = GetRandomFloat(0.5, 1.0);
	flFadeIn = GetRandomFloat(0.5, flTotalDuration - 0.5 - flFadeHold);
	flFadeOut = flTotalDuration - flFadeIn - flFadeHold;
	return true;
}