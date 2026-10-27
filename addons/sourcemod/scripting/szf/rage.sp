#define RAGE_DURATION				5.0
#define RAGE_DURATION_LONG			10.0
#define RAGE_SCOUT_SPEED			20.0
#define RAGE_SCOUT_BALL_DAMAGE		30.0
#define RAGE_SOLDIER_BANNER_MULTI	3.0
#define RAGE_PYRO_RINGS				5
#define RAGE_PYRO_RING_INTERVAL		0.5
#define RAGE_PYRO_RING_DAMAGE		6.0
#define RAGE_PYRO_RING_RADIUS		135.0
#define RAGE_DEMO_PUSH				250.0
#define RAGE_DEMO_PUSH_UP			150.0
#define RAGE_HEAVY_RESIST			0.8
#define RAGE_SNIPER_RANGE			100.0
#define RAGE_SNIPER_BASE_RANGE		48.0
#define RAGE_ENGINEER_SHELLS		40
#define RAGE_ENGINEER_DURATION		2.0
#define RAGE_MEDIC_REGEN			5
#define RAGE_MEDIC_RADIUS			400.0
#define RAGE_MEDIC_RING_INTERVAL	0.1
#define RAGE_MEDIC_RING_LIFE		0.15
#define RAGE_BEAM_FADEOUT			0x0008

#define RAGE_OVERLAY				"szf/overlays/rage_screen"
#define RAGE_OVERLAY_VMT			"materials/szf/overlays/rage_screen.vmt"
#define RAGE_OVERLAY_VTF			"materials/szf/overlays/rage.vtf"

static float g_flRageEffectEnd[MAXPLAYERS + 1];
static TFClassType g_nRageEffectClass[MAXPLAYERS + 1];
static bool g_bRageOverlay[MAXPLAYERS + 1];
static int g_iRageMelee[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
static float g_flRageMeleeOldRange[MAXPLAYERS + 1];
static int g_iRagePyroRingsLeft[MAXPLAYERS + 1];
static int g_iRageMedicCircle[MAXPLAYERS + 1];
static int g_iRageBeamSprite;
static int g_iRageHaloSprite;
static bool g_bRageOverlayAvailable;

void Rage_Precache()
{
	g_iRageBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iRageHaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
	PrecacheParticle("heavy_ring_of_fire");
	
	g_bRageOverlayAvailable = FileExists(RAGE_OVERLAY_VMT, true) && FileExists(RAGE_OVERLAY_VTF, true);
	if (g_bRageOverlayAvailable)
	{
		AddFileToDownloadsTable(RAGE_OVERLAY_VMT);
		AddFileToDownloadsTable(RAGE_OVERLAY_VTF);
	}
}

void Rage_OnRage(int iClient)
{
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	switch (nClass)
	{
		case TFClass_Scout:
		{
			Rage_StartEffect(iClient, nClass, RAGE_DURATION);
			CPrintToChat(iClient, "%t", "Rage_Scout", "{orange}");
		}
		case TFClass_Soldier:
		{
			Rage_StartEffect(iClient, nClass, RAGE_DURATION);
			CPrintToChat(iClient, "%t", "Rage_Soldier", "{orange}");
		}
		case TFClass_Pyro:
		{
			Rage_StartEffect(iClient, nClass, RAGE_PYRO_RINGS * RAGE_PYRO_RING_INTERVAL);
			CPrintToChat(iClient, "%t", "Rage_Pyro", "{orange}");
			
			Rage_PyroRing(iClient);
			g_iRagePyroRingsLeft[iClient] = RAGE_PYRO_RINGS - 1;
			
			DataPack hPack;
			CreateDataTimer(RAGE_PYRO_RING_INTERVAL, Timer_RagePyroRing, hPack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			hPack.WriteCell(GetClientSerial(iClient));
			hPack.WriteFloat(g_flRageEffectEnd[iClient]);
		}
		case TFClass_DemoMan:
		{
			Rage_StartEffect(iClient, nClass, RAGE_DURATION);
			CPrintToChat(iClient, "%t", "Rage_Demoman", "{orange}");
		}
		case TFClass_Heavy:
		{
			Rage_StartEffect(iClient, nClass, RAGE_DURATION);
			CPrintToChat(iClient, "%t", "Rage_Heavy", "{orange}");
		}
		case TFClass_Engineer:
		{
			Rage_StartEffect(iClient, nClass, RAGE_ENGINEER_DURATION);
			CPrintToChat(iClient, "%t", "Rage_Engineer", "{orange}");
			Rage_EngineerSentries(iClient);
		}
		case TFClass_Medic:
		{
			Rage_StartEffect(iClient, nClass, RAGE_DURATION);
			CPrintToChat(iClient, "%t", "Rage_Medic", "{orange}");
			Rage_MedicCircle(iClient);
		}
		case TFClass_Sniper:
		{
			Rage_StartEffect(iClient, nClass, RAGE_DURATION_LONG);
			CPrintToChat(iClient, "%t", "Rage_Sniper", "{orange}");
		}
		case TFClass_Spy:
		{
			Rage_StartEffect(iClient, nClass, RAGE_DURATION_LONG);
			CPrintToChat(iClient, "%t", "Rage_Spy", "{orange}");
			TF2_AddCondition(iClient, TFCond_Stealthed, RAGE_DURATION_LONG);
		}
	}
}

void Rage_OnClientPutInServer(int iClient)
{
	g_flRageEffectEnd[iClient] = 0.0;
	g_bRageOverlay[iClient] = false;
	g_iRageMelee[iClient] = INVALID_ENT_REFERENCE;
}

void Rage_EndTimedEffect(int iClient)
{
	g_iRageMedicCircle[iClient]++;
	Rage_EndEffect(iClient);
}

static void Rage_EndEffect(int iClient)
{
	if (g_bRageOverlay[iClient])
	{
		g_bRageOverlay[iClient] = false;
		if (IsClientInGame(iClient))
			Rage_SetOverlay(iClient, "");
	}
	
	if (g_flRageEffectEnd[iClient] <= 0.0)
		return;
	
	g_flRageEffectEnd[iClient] = 0.0;
	
	int iMelee = EntRefToEntIndex(g_iRageMelee[iClient]);
	g_iRageMelee[iClient] = INVALID_ENT_REFERENCE;
	if (iMelee > MaxClients)
	{
		if (g_flRageMeleeOldRange[iClient] > 0.0)
			TF2Attrib_SetByName(iMelee, "melee range multiplier", g_flRageMeleeOldRange[iClient]);
		else
			TF2Attrib_RemoveByName(iMelee, "melee range multiplier");
	}
	
	if (IsClientInGame(iClient) && IsPlayerAlive(iClient))
		SDKCall_SetSpeed(iClient);
}

float Rage_GetSpeedBonus(int iClient)
{
	return Rage_IsEffectActive(iClient, TFClass_Scout) ? RAGE_SCOUT_SPEED : 0.0;
}

float Rage_GetBannerChargeMulti(int iClient)
{
	return Rage_IsEffectActive(iClient, TFClass_Soldier) ? RAGE_SOLDIER_BANNER_MULTI : 1.0;
}

void Rage_OnConditionRemoved(int iClient, TFCond nCond)
{
	if (nCond != TFCond_Stealthed && nCond != TFCond_StealthedUserBuffFade)
		return;
	
	if (!Rage_IsEffectActive(iClient, TFClass_Spy) || !IsValidLivingZombie(iClient) || g_nRoundState != SZFRoundState_Active)
		return;
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_Stealthed) || TF2_IsPlayerInCondition(iClient, TFCond_StealthedUserBuffFade))
		return;
	
	float flTimeLeft = g_flRageEffectEnd[iClient] - GetGameTime();
	if (flTimeLeft > 0.1)
		TF2_AddCondition(iClient, TFCond_Stealthed, flTimeLeft);
}

bool Rage_OnZombieHit(int iVictim, int iAttacker, int iDamageCustom, float &flDamage)
{
	if (iDamageCustom != TF_CUSTOM_BASEBALL || !IsValidSurvivor(iVictim) || !IsValidZombie(iAttacker) || !Rage_IsEffectActive(iAttacker, TFClass_Scout))
		return false;
	
	flDamage = RAGE_SCOUT_BALL_DAMAGE;
	return true;
}

bool Rage_OnTakeDamage(int iVictim, float &flDamage)
{
	if (!Rage_IsEffectActive(iVictim, TFClass_Heavy) || !IsValidZombie(iVictim))
		return false;
	
	flDamage *= RAGE_HEAVY_RESIST;
	return true;
}

void Rage_OnTakeDamagePost(int iVictim, int iAttacker, float flDamage)
{
	if (flDamage <= 0.0 || iVictim == iAttacker || !IsValidLivingSurvivor(iVictim) || !IsValidLivingZombie(iAttacker) || !Rage_IsEffectActive(iAttacker, TFClass_DemoMan))
		return;
	
	DataPack hPack = new DataPack();
	hPack.WriteCell(GetClientSerial(iVictim));
	hPack.WriteCell(GetClientSerial(iAttacker));
	RequestFrame(Frame_RageKnockback, hPack);
}

public void Frame_RageKnockback(DataPack hPack)
{
	hPack.Reset();
	int iVictim = GetClientFromSerial(hPack.ReadCell());
	int iAttacker = GetClientFromSerial(hPack.ReadCell());
	delete hPack;
	
	if (!iVictim || !iAttacker || !IsValidLivingSurvivor(iVictim) || !IsClientInGame(iAttacker))
		return;
	
	if (Infected_IsJockeyVictim(iVictim))
		return;
	
	float vecAttacker[3], vecVictim[3], vecDir[3];
	GetClientAbsOrigin(iAttacker, vecAttacker);
	GetClientAbsOrigin(iVictim, vecVictim);
	MakeVectorFromPoints(vecAttacker, vecVictim, vecDir);
	vecDir[2] = 0.0;
	if (NormalizeVector(vecDir, vecDir) <= 0.0)
		return;
	
	float vecVelocity[3];
	GetEntPropVector(iVictim, Prop_Data, "m_vecVelocity", vecVelocity);
	vecVelocity[0] += vecDir[0] * RAGE_DEMO_PUSH;
	vecVelocity[1] += vecDir[1] * RAGE_DEMO_PUSH;
	if (vecVelocity[2] < RAGE_DEMO_PUSH_UP)
		vecVelocity[2] = RAGE_DEMO_PUSH_UP;
	
	TeleportEntity(iVictim, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}

static bool Rage_IsEffectActive(int iClient, TFClassType nClass)
{
	return g_flRageEffectEnd[iClient] > GetGameTime() && g_nRageEffectClass[iClient] == nClass;
}

static void Rage_StartEffect(int iClient, TFClassType nClass, float flDuration)
{
	Rage_EndEffect(iClient);
	
	g_flRageEffectEnd[iClient] = GetGameTime() + flDuration;
	g_nRageEffectClass[iClient] = nClass;
	
	if (g_bRageOverlayAvailable)
	{
		Rage_SetOverlay(iClient, RAGE_OVERLAY);
		g_bRageOverlay[iClient] = true;
	}
	
	if (nClass == TFClass_Sniper)
	{
		int iMelee = GetPlayerWeaponSlot(iClient, WeaponSlot_Melee);
		if (iMelee > MaxClients)
		{
			g_flRageMeleeOldRange[iClient] = 0.0;
			Address pAttrib = TF2Attrib_GetByName(iMelee, "melee range multiplier");
			if (pAttrib != Address_Null)
				g_flRageMeleeOldRange[iClient] = TF2Attrib_GetValue(pAttrib);
			
			float flRange = g_flRageMeleeOldRange[iClient] > 0.0 ? g_flRageMeleeOldRange[iClient] : 1.0;
			TF2Attrib_SetByName(iMelee, "melee range multiplier", flRange * (RAGE_SNIPER_BASE_RANGE + RAGE_SNIPER_RANGE) / RAGE_SNIPER_BASE_RANGE);
			g_iRageMelee[iClient] = EntIndexToEntRef(iMelee);
		}
	}
	
	SDKCall_SetSpeed(iClient);
	CreateTimer(flDuration, Timer_RageEffectEnd, GetClientSerial(iClient));
}

static void Rage_SetOverlay(int iClient, const char[] sMaterial)
{
	SetVariantString(sMaterial);
	AcceptEntityInput(iClient, "SetScriptOverlayMaterial");
}

public Action Timer_RageEffectEnd(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	
	if (iClient && g_flRageEffectEnd[iClient] > 0.0 && g_flRageEffectEnd[iClient] <= GetGameTime() + 0.05)
		Rage_EndEffect(iClient);
	
	return Plugin_Continue;
}

public Action Timer_RagePyroRing(Handle hTimer, DataPack hPack)
{
	hPack.Reset();
	int iClient = GetClientFromSerial(hPack.ReadCell());
	float flEffectEnd = hPack.ReadFloat();
	
	if (!iClient || g_flRageEffectEnd[iClient] != flEffectEnd || !Rage_IsEffectActive(iClient, TFClass_Pyro) || !IsValidLivingZombie(iClient))
		return Plugin_Stop;
	
	Rage_PyroRing(iClient);
	
	g_iRagePyroRingsLeft[iClient]--;
	return g_iRagePyroRingsLeft[iClient] > 0 ? Plugin_Continue : Plugin_Stop;
}

static void Rage_PyroRing(int iClient)
{
	if (g_nRoundState != SZFRoundState_Active)
		return;
	
	float vecOrigin[3], vecCenter[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	WorldSpaceCenter(iClient, vecCenter);
	
	int iWeapon = GetPlayerWeaponSlot(iClient, WeaponSlot_Melee);
	
	for (int iVictim = 1; iVictim <= MaxClients; iVictim++)
	{
		if (!IsValidLivingSurvivor(iVictim) || TF2_IsPlayerInCondition(iVictim, TFCond_Ubercharged))
			continue;
		
		float vecVictim[3], vecMins[3], vecMaxs[3];
		GetClientAbsOrigin(iVictim, vecVictim);
		GetClientMins(iVictim, vecMins);
		GetClientMaxs(iVictim, vecMaxs);
		
		if (!(vecOrigin[2] > vecVictim[2] + vecMins[2] - 32.0 && vecOrigin[2] < vecVictim[2] + vecMaxs[2]))
			continue;
		
		float flDistanceSqr = 0.0;
		for (int i = 0; i < 3; i++)
		{
			float flNearest = fMax(vecVictim[i] + vecMins[i], fMin(vecOrigin[i], vecVictim[i] + vecMaxs[i]));
			float flDelta = vecOrigin[i] - flNearest;
			flDistanceSqr += flDelta * flDelta;
		}
		
		if (flDistanceSqr > RAGE_PYRO_RING_RADIUS * RAGE_PYRO_RING_RADIUS)
			continue;
		
		float vecSpot[3];
		WorldSpaceCenter(iVictim, vecSpot);
		TR_TraceRayFilter(vecCenter, vecSpot, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Trace_DontHitClients);
		if (TR_DidHit())
			continue;
		
		SDKHooks_TakeDamage(iVictim, iClient, iClient, RAGE_PYRO_RING_DAMAGE, DMG_PLASMA, iWeapon, NULL_VECTOR, vecOrigin);
	}
	
	ShowParticle("heavy_ring_of_fire", 1.0, vecOrigin);
}

static void Rage_EngineerSentries(int iClient)
{
	int iSentry = -1;
	while ((iSentry = FindEntityByClassname(iSentry, "obj_sentrygun")) != -1)
	{
		if (GetEntPropEnt(iSentry, Prop_Send, "m_hBuilder") != iClient)
			continue;
		
		if (GetEntProp(iSentry, Prop_Send, "m_bBuilding") || GetEntProp(iSentry, Prop_Send, "m_bPlacing") || GetEntProp(iSentry, Prop_Send, "m_bCarried"))
			continue;
		
		SetEntProp(iSentry, Prop_Send, "m_iAmmoShells", RAGE_ENGINEER_SHELLS);
	}
}

static void Rage_MedicCircle(int iClient)
{
	g_iRageMedicCircle[iClient]++;
	
	float vecCenter[3];
	GetClientAbsOrigin(iClient, vecCenter);
	
	Rage_SendMedicRing(vecCenter, RAGE_MEDIC_RING_LIFE + RAGE_MEDIC_RING_INTERVAL, 0);
	
	DataPack hPack;
	CreateDataTimer(RAGE_MEDIC_RING_INTERVAL, Timer_RageMedicCircle, hPack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	hPack.WriteCell(0);
	hPack.WriteCell(GetClientSerial(iClient));
	hPack.WriteCell(g_iRageMedicCircle[iClient]);
	hPack.WriteFloatArray(vecCenter, sizeof(vecCenter));
}

public Action Timer_RageMedicCircle(Handle hTimer, DataPack hPack)
{
	hPack.Reset();
	int iRing = hPack.ReadCell() + 1;
	int iMedic = GetClientFromSerial(hPack.ReadCell());
	int iCircle = hPack.ReadCell();
	float vecCenter[3];
	hPack.ReadFloatArray(vecCenter, sizeof(vecCenter));
	
	if (g_nRoundState != SZFRoundState_Active)
		return Plugin_Stop;
	
	if (!iMedic || g_iRageMedicCircle[iMedic] != iCircle || !IsValidLivingZombie(iMedic))
	{
		Rage_SendMedicRing(vecCenter, 1.0, RAGE_BEAM_FADEOUT);
		return Plugin_Stop;
	}
	
	GetClientAbsOrigin(iMedic, vecCenter);
	
	int iRingsPerSecond = RoundToNearest(1.0 / RAGE_MEDIC_RING_INTERVAL);
	if (iRing % iRingsPerSecond == 0)
		Rage_MedicHeal(iMedic, vecCenter);
	
	if (iRing >= RoundToNearest(RAGE_DURATION) * iRingsPerSecond)
	{
		Rage_SendMedicRing(vecCenter, 1.0, RAGE_BEAM_FADEOUT);
		return Plugin_Stop;
	}
	
	Rage_SendMedicRing(vecCenter, RAGE_MEDIC_RING_LIFE, 0);
	
	hPack.Reset();
	hPack.WriteCell(iRing);
	hPack.ReadCell();
	hPack.ReadCell();
	hPack.WriteFloatArray(vecCenter, sizeof(vecCenter));
	return Plugin_Continue;
}

static void Rage_MedicHeal(int iMedic, const float vecCenter[3])
{
	for (int iOther = 1; iOther <= MaxClients; iOther++)
	{
		if (iOther == iMedic || !IsValidLivingZombie(iOther) || g_nInfected[iOther] == Infected_Tank)
			continue;
		
		float vecOther[3];
		GetClientAbsOrigin(iOther, vecOther);
		if (GetVectorDistance(vecCenter, vecOther) > RAGE_MEDIC_RADIUS)
			continue;
		
		int iHealth = GetClientHealth(iOther);
		int iMaxHealth = SDKCall_GetMaxHealth(iOther);
		if (iHealth >= iMaxHealth)
			continue;
		
		int iHeal = min(RAGE_MEDIC_REGEN, iMaxHealth - iHealth);
		SetEntityHealth(iOther, iHealth + iHeal);
		
		Event event = CreateEvent("player_healonhit", true);
		event.SetInt("amount", iHeal);
		event.SetInt("entindex", iOther);
		event.FireToClient(iOther);
		event.Cancel();
	}
}

static void Rage_SendMedicRing(const float vecCenter[3], float flLife, int iFlags)
{
	float vecRing[3];
	vecRing = vecCenter;
	vecRing[2] += 10.0;
	TE_SetupBeamRingPoint(vecRing, RAGE_MEDIC_RADIUS * 2.0 - 1.0, RAGE_MEDIC_RADIUS * 2.0, g_iRageBeamSprite, g_iRageHaloSprite, 0, 15, flLife, 6.0, 0.0, {0, 255, 0, 255}, 0, iFlags);
	TE_SendToAll();
}
