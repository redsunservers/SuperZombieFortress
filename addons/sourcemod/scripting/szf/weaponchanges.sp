#define ITEM_RIGHTEOUS_BISON		442
#define ITEM_POMSON					588

#define ENERGY_RING_SPEED_BONUS		1.2
#define BISON_DAMAGE				20.0
#define BISON_TICK_TIME				0.025

#define DALOKOHS_HEALTH_STOCK		50.0
#define DALOKOHS_HEALTH_BONUS		100.0
#define DALOKOHS_DURATION			30.0

#define HUOLONG_RADIUS_STOCK		135.0
#define HUOLONG_RADIUS				270.0
#define HUOLONG_INTERVAL			0.5

#define VACCINATOR_UBER_RESIST		0.75
#define MINICRIT_MULTIPLIER			1.35

enum
{
	MinigunState_Idle = 0,
	MinigunState_StartFiring,
	MinigunState_Firing,
	MinigunState_Spinning,
	MinigunState_DryFire,
}

static TFCond g_nCritBoostConds[] = {
	TFCond_Kritzkrieged,
	TFCond_HalloweenCritCandy,
	TFCond_CritCanteen,
	TFCond_CritOnFirstBlood,
	TFCond_CritOnWin,
	TFCond_CritOnFlagCapture,
	TFCond_CritOnKill,
	TFCond_CritMmmph,
	TFCond_CritOnDamage,
	TFCond_CritRuneTemp
};

static bool g_bBisonCrit[2048];
static ArrayList g_aBisonHits[2048];
static bool g_bCritBeforeModify[MAXPLAYERS + 1];
static int g_iHuoLongState[MAXPLAYERS + 1];
static float g_flHuoLongNextRing[MAXPLAYERS + 1];

void WeaponChanges_OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrEqual(sClassname, "tf_projectile_energy_ring"))
		SDKHook(iEntity, SDKHook_SpawnPost, EnergyRing_SpawnPost);
}

void WeaponChanges_OnEntityDestroyed(int iEntity)
{
	if (0 < iEntity < sizeof(g_aBisonHits))
	{
		delete g_aBisonHits[iEntity];
		g_bBisonCrit[iEntity] = false;
	}
}

public void EnergyRing_SpawnPost(int iRing)
{
	SDKUnhook(iRing, SDKHook_SpawnPost, EnergyRing_SpawnPost);
	RequestFrame(Frame_EnergyRingSetup, EntIndexToEntRef(iRing));
}

public void Frame_EnergyRingSetup(int iRef)
{
	int iRing = EntRefToEntIndex(iRef);
	if (iRing == INVALID_ENT_REFERENCE)
		return;
	
	int iLauncher = GetEntPropEnt(iRing, Prop_Send, "m_hLauncher");
	if (iLauncher <= MaxClients || !HasEntProp(iLauncher, Prop_Send, "m_iItemDefinitionIndex"))
		return;
	
	int iIndex = Config_GetOriginalItemDefIndex(GetEntProp(iLauncher, Prop_Send, "m_iItemDefinitionIndex"));
	if (iIndex != ITEM_RIGHTEOUS_BISON && iIndex != ITEM_POMSON)
		return;
	
	float vecVelocity[3];
	GetEntPropVector(iRing, Prop_Data, "m_vecAbsVelocity", vecVelocity);
	ScaleVector(vecVelocity, ENERGY_RING_SPEED_BONUS);
	TeleportEntity(iRing, NULL_VECTOR, NULL_VECTOR, vecVelocity);
	SetEntPropVector(iRing, Prop_Send, "m_vInitialVelocity", vecVelocity);
	
	if (iIndex != ITEM_RIGHTEOUS_BISON)
		return;
	
	int iOwner = GetEntPropEnt(iRing, Prop_Send, "m_hOwnerEntity");
	g_bBisonCrit[iRing] = IsValidClient(iOwner) && WeaponChanges_IsCritBoosted(iOwner);
	
	delete g_aBisonHits[iRing];
	g_aBisonHits[iRing] = new ArrayList(2);
	
	SDKHook(iRing, SDKHook_Touch, BisonRing_Touch);
}

public Action BisonRing_Touch(int iRing, int iOther)
{
	bool bPlayer = (0 < iOther <= MaxClients);
	bool bBuilding = !bPlayer && iOther > MaxClients && WeaponChanges_IsBuilding(iOther);
	
	if (!bPlayer && !bBuilding)
	{
		if (iOther > MaxClients && IsWeaponPropClassname(iOther) && GetWeaponType(iOther) != WeaponType_Invalid)
			return Plugin_Handled;
		
		return Plugin_Continue;
	}
	
	int iOwner = GetEntPropEnt(iRing, Prop_Send, "m_hOwnerEntity");
	if (iOther == iOwner || GetEntProp(iOther, Prop_Send, "m_iTeamNum") == GetEntProp(iRing, Prop_Send, "m_iTeamNum"))
		return Plugin_Handled;
	
	if (bPlayer && !IsPlayerAlive(iOther))
		return Plugin_Handled;
	
	if (!BisonRing_CanHit(iRing, iOther, GetGameTime()))
		return Plugin_Handled;
	
	int iDamageType = DMG_BULLET|DMG_USEDISTANCEMOD|DMG_NOCLOSEDISTANCEMOD|DMG_PREVENT_PHYSICS_FORCE;
	if (g_bBisonCrit[iRing])
		iDamageType |= DMG_CRIT;
	
	float vecPos[3];
	GetEntPropVector(iRing, Prop_Data, "m_vecAbsOrigin", vecPos);
	
	int iLauncher = GetEntPropEnt(iRing, Prop_Send, "m_hLauncher");
	int iAttacker = IsValidClient(iOwner) ? iOwner : iRing;
	
	SDKHooks_TakeDamage(iOther, iRing, iAttacker, BISON_DAMAGE, iDamageType, iLauncher, NULL_VECTOR, vecPos, false);
	
	EmitGameSoundToAll("Weapon_Bison.ProjectileImpactWorld", iRing);
	
	return Plugin_Handled;
}

static bool BisonRing_CanHit(int iRing, int iTarget, float flGameTime)
{
	ArrayList aHits = g_aBisonHits[iRing];
	if (!aHits)
		return true;
	
	int iRef = EntIndexToEntRef(iTarget);
	int iPos = aHits.FindValue(iRef, 0);
	if (iPos == -1)
	{
		iPos = aHits.Push(iRef);
		aHits.Set(iPos, flGameTime, 1);
		return true;
	}
	
	if (flGameTime - view_as<float>(aHits.Get(iPos, 1)) < BISON_TICK_TIME)
		return false;
	
	aHits.Set(iPos, flGameTime, 1);
	return true;
}

static bool WeaponChanges_IsBuilding(int iEntity)
{
	char sClassname[64];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
	return StrContains(sClassname, "obj_") == 0;
}

static bool WeaponChanges_IsCritBoosted(int iClient)
{
	for (int i = 0; i < sizeof(g_nCritBoostConds); i++)
	{
		if (TF2_IsPlayerInCondition(iClient, g_nCritBoostConds[i]))
			return true;
	}
	
	return false;
}

void WeaponChanges_OnClientThink(int iClient)
{
	if (!IsValidLivingSurvivor(iClient) || TF2_GetPlayerClass(iClient) != TFClass_Heavy)
	{
		g_iHuoLongState[iClient] = MinigunState_Idle;
		return;
	}
	
	Address pAttrib = TF2Attrib_GetByName(iClient, "hidden maxhealth non buffed");
	if (pAttrib != Address_Null && TF2Attrib_GetValue(pAttrib) == DALOKOHS_HEALTH_STOCK)
		TF2Attrib_AddCustomPlayerAttribute(iClient, "hidden maxhealth non buffed", DALOKOHS_HEALTH_BONUS, DALOKOHS_DURATION);
	
	HuoLong_Think(iClient);
}

static void HuoLong_Think(int iClient)
{
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients || !HasEntProp(iWeapon, Prop_Send, "m_iWeaponState"))
	{
		g_iHuoLongState[iClient] = MinigunState_Idle;
		return;
	}
	
	float flGameTime = GetGameTime();
	int iState = GetEntProp(iWeapon, Prop_Send, "m_iWeaponState");
	int iLastState = g_iHuoLongState[iClient];
	if (iState != iLastState)
	{
		if (iLastState == MinigunState_Idle || iLastState == MinigunState_StartFiring || iLastState == MinigunState_DryFire)
			g_flHuoLongNextRing[iClient] = flGameTime + HUOLONG_INTERVAL;
		
		g_iHuoLongState[iClient] = iState;
	}
	
	if (iState <= MinigunState_StartFiring || flGameTime < g_flHuoLongNextRing[iClient])
		return;
	
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType < 0 || GetEntProp(iClient, Prop_Send, "m_iAmmo", _, iAmmoType) <= 0)
		return;
	
	int iDamage = TF2Attrib_HookValueInt(0, "ring_of_fire_while_aiming", iWeapon);
	if (iDamage <= 0)
		return;
	
	g_flHuoLongNextRing[iClient] = flGameTime + HUOLONG_INTERVAL;
	HuoLong_OuterRing(iClient, iWeapon, iDamage);
}

static void HuoLong_OuterRing(int iClient, int iWeapon, int iDamage)
{
	float vecOrigin[3], vecCenter[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	WorldSpaceCenter(iClient, vecCenter);
	
	int iTeam = GetClientTeam(iClient);
	
	for (int iVictim = 1; iVictim <= MaxClients; iVictim++)
	{
		if (!IsValidLivingClient(iVictim) || GetClientTeam(iVictim) == iTeam || TF2_IsPlayerInCondition(iVictim, TFCond_Ubercharged))
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
		
		if (flDistanceSqr <= HUOLONG_RADIUS_STOCK * HUOLONG_RADIUS_STOCK || flDistanceSqr > HUOLONG_RADIUS * HUOLONG_RADIUS)
			continue;
		
		float vecSpot[3];
		WorldSpaceCenter(iVictim, vecSpot);
		TR_TraceRayFilter(vecCenter, vecSpot, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Trace_DontHitClients);
		if (TR_DidHit())
			continue;
		
		SDKHooks_TakeDamage(iVictim, iClient, iClient, float(iDamage), DMG_PLASMA, iWeapon, NULL_VECTOR, vecOrigin, false);
	}
}

void WeaponChanges_OnTakeDamagePre(int iVictim, int iDamageType)
{
	if (0 < iVictim <= MaxClients)
		g_bCritBeforeModify[iVictim] = (iDamageType & DMG_CRIT) != 0;
}

Action WeaponChanges_OnTakeDamageAlive(int iVictim, float &flDamage, int &iDamageType)
{
	if (!WeaponChanges_IsVaccinatorUbered(iVictim))
		return Plugin_Continue;
	
	if (iDamageType & DMG_CRIT)
	{
		if (!g_bCritBeforeModify[iVictim])
			flDamage /= MINICRIT_MULTIPLIER;
		
		iDamageType &= ~DMG_CRIT;
	}
	
	flDamage *= VACCINATOR_UBER_RESIST;
	return Plugin_Changed;
}

bool WeaponChanges_IsVaccinatorUbered(int iClient)
{
	return TF2_IsPlayerInCondition(iClient, TFCond_UberBulletResist)
		|| TF2_IsPlayerInCondition(iClient, TFCond_UberBlastResist)
		|| TF2_IsPlayerInCondition(iClient, TFCond_UberFireResist);
}
