#define DROPPED_AIM_DISTANCE	100.0
#define DROPPED_AIM_RADIUS		18.0
#define DROPPED_SPAWN_HEIGHT	40.0
#define DROPPED_SPREAD			14.0
#define DROPPED_CHECK_INTERVAL	0.1
#define DROPPED_CHECK_DURATION	6.0

static ArrayList g_aDroppedWeapons;
static float g_flDroppedLastOrigin[2048][3];
static float g_flDroppedLastCenter[2048][3];
static float g_flDroppedCheckEnd[2048];
static bool g_bDroppedCheckReady[2048];
static int g_iRareOutline[2048] = {INVALID_ENT_REFERENCE, ...};
static int g_iRareOutlineClassMask[2048];

void DroppedWeapon_Reset()
{
	delete g_aDroppedWeapons;
	g_aDroppedWeapons = new ArrayList();
}

void DroppedWeapon_OnSurvivorDeath(int iVictim)
{
	float vecCenter[3];
	GetClientAbsOrigin(iVictim, vecCenter);
	vecCenter[2] += DROPPED_SPAWN_HEIGHT;
	
	float flYaw = GetRandomFloat(0.0, 360.0);
	int iCount = 0;
	
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_Secondary; iSlot++)
	{
		int iWeapon = TF2_GetItemInSlot(iVictim, iSlot);
		if (iWeapon <= MaxClients)
			continue;
		
		Weapon wep;
		int iIndex = Config_GetOriginalItemDefIndex(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"));
		if (!GetWeaponFromIndex(wep, iIndex) || wep.iIndex < 0 || wep.nRarity == WeaponRarity_Pickup)
			continue;
		
		float flDirection = flYaw + 180.0 * float(iCount) + 45.0 * float(iCount / 2);
		float vecDirection[3];
		vecDirection[0] = Cosine(DegToRad(flDirection));
		vecDirection[1] = Sine(DegToRad(flDirection));
		
		float vecOrigin[3];
		vecOrigin[0] = vecCenter[0] + vecDirection[0] * DROPPED_SPREAD;
		vecOrigin[1] = vecCenter[1] + vecDirection[1] * DROPPED_SPREAD;
		vecOrigin[2] = vecCenter[2] + 8.0 * float(iCount);
		
		TR_TraceRayFilter(vecCenter, vecOrigin, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Trace_DroppedWeaponWorld);
		if (TR_DidHit())
		{
			TR_GetEndPosition(vecOrigin);
			vecOrigin[0] -= vecDirection[0] * 4.0;
			vecOrigin[1] -= vecDirection[1] * 4.0;
		}
		
		float vecAngles[3], vecVelocity[3];
		vecAngles[1] = flDirection;
		
		float flSpeed = GetRandomFloat(60.0, 110.0);
		vecVelocity[0] = vecDirection[0] * flSpeed;
		vecVelocity[1] = vecDirection[1] * flSpeed;
		vecVelocity[2] = GetRandomFloat(140.0, 200.0);
		
		DroppedWeapon_Create(wep, vecOrigin, vecAngles, vecVelocity);
		iCount++;
	}
}

int DroppedWeapon_Create(Weapon wep, const float vecOrigin[3], const float vecAngles[3], const float vecVelocity[3])
{
	if (!DroppedWeapon_HasCollisionModel(wep.sModel))
		return DroppedWeapon_CreateStatic(wep, vecOrigin, vecAngles);
	
	int iProp = CreateEntityByName("prop_physics_override");
	if (iProp == INVALID_ENT_REFERENCE)
		return INVALID_ENT_REFERENCE;
	
	char sSkin[8];
	IntToString(wep.iSkin, sSkin, sizeof(sSkin));
	
	DispatchKeyValue(iProp, "targetname", DROPPED_WEAPON_NAME);
	DispatchKeyValue(iProp, "model", wep.sModel);
	DispatchKeyValue(iProp, "skin", sSkin);
	DispatchKeyValue(iProp, "spawnflags", "6");
	DispatchKeyValue(iProp, "physdamagescale", "0.0");
	DispatchKeyValue(iProp, "nodamageforces", "1");
	DispatchKeyValueVector(iProp, "origin", vecOrigin);
	DispatchKeyValueVector(iProp, "angles", vecAngles);
	DispatchSpawn(iProp);
	
	if (GetEntProp(iProp, Prop_Send, "m_nSolidType") == view_as<int>(SOLID_NONE))
	{
		RemoveEntity(iProp);
		return DroppedWeapon_CreateStatic(wep, vecOrigin, vecAngles);
	}
	
	SetEntProp(iProp, Prop_Data, "m_takedamage", DAMAGE_NO);
	
	if (wep.iColor[0] + wep.iColor[1] + wep.iColor[2] > 0)
	{
		SetEntityRenderMode(iProp, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iProp, wep.iColor[0], wep.iColor[1], wep.iColor[2], 255);
	}
	
	if (wep.sModelAttach[0])
	{
		int iChild = CreateEntityByName("prop_dynamic");
		SetEntityModel(iChild, wep.sModelAttach);
		SetEntProp(iChild, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW|EF_NOINTERP);
		SetEntityCollisionGroup(iChild, COLLISION_GROUP_NONE);
		DispatchSpawn(iChild);
		
		SetVariantString("!activator");
		AcceptEntityInput(iChild, "SetParent", iProp);
	}
	
	TeleportEntity(iProp, NULL_VECTOR, NULL_VECTOR, vecVelocity);
	
	DroppedWeapon_StartWorldCheck(iProp);
	
	if (!g_aDroppedWeapons)
		g_aDroppedWeapons = new ArrayList();
	
	g_aDroppedWeapons.Push(EntIndexToEntRef(iProp));
	
	if (wep.nRarity == WeaponRarity_Rare)
		RareOutline_Set(iProp, wep);
	
	return iProp;
}

int DroppedWeapon_CreateStatic(Weapon wep, const float vecOrigin[3], const float vecAngles[3])
{
	float vecEnd[3], vecFloor[3], vecFlat[3];
	vecEnd[0] = vecOrigin[0];
	vecEnd[1] = vecOrigin[1];
	vecEnd[2] = vecOrigin[2] - 1000.0;
	
	TR_TraceRayFilter(vecOrigin, vecEnd, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Trace_DroppedWeaponWorld);
	TR_GetEndPosition(vecFloor);
	
	vecFlat[1] = vecAngles[1];
	
	int iProp = CreateEntityByName("prop_dynamic");
	if (iProp == INVALID_ENT_REFERENCE)
		return INVALID_ENT_REFERENCE;
	
	DispatchKeyValue(iProp, "targetname", DROPPED_WEAPON_NAME);
	DispatchKeyValue(iProp, "model", wep.sModel);
	DispatchKeyValue(iProp, "solid", "2");
	DispatchKeyValueVector(iProp, "origin", vecFloor);
	DispatchKeyValueVector(iProp, "angles", vecFlat);
	DispatchSpawn(iProp);
	
	SetEntProp(iProp, Prop_Send, "m_nSkin", 99);
	SetWeaponModel(iProp, wep);
	Weapons_SetupProp(iProp);
	
	if (wep.nRarity == WeaponRarity_Rare)
		RareOutline_Set(iProp, wep);
	
	return iProp;
}

static bool DroppedWeapon_HasCollisionModel(const char[] sModel)
{
	char sPhy[PLATFORM_MAX_PATH];
	strcopy(sPhy, sizeof(sPhy), sModel);
	
	int iExtension = strlen(sPhy) - 4;
	if (iExtension <= 0 || !StrEqual(sPhy[iExtension], ".mdl", false))
		return false;
	
	strcopy(sPhy[iExtension], sizeof(sPhy) - iExtension, ".phy");
	return FileExists(sPhy, true);
}

int DroppedWeapon_Replace(int iTarget, Weapon wep)
{
	float vecOrigin[3], vecAngles[3], vecVelocity[3];
	GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", vecOrigin);
	GetEntPropVector(iTarget, Prop_Data, "m_angAbsRotation", vecAngles);
	
	vecOrigin[2] += 10.0;
	vecVelocity[2] = 100.0;
	
	return DroppedWeapon_Create(wep, vecOrigin, vecAngles, vecVelocity);
}

void DroppedWeapon_StartWorldCheck(int iProp)
{
	g_bDroppedCheckReady[iProp] = false;
	DroppedWeapon_SetCheckPoint(iProp);
	
	g_flDroppedCheckEnd[iProp] = GetGameTime() + DROPPED_CHECK_DURATION;
	CreateTimer(DROPPED_CHECK_INTERVAL, Timer_DroppedWeaponWorldCheck, EntIndexToEntRef(iProp), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DroppedWeaponWorldCheck(Handle hTimer, int iRef)
{
	int iProp = EntRefToEntIndex(iRef);
	if (iProp == INVALID_ENT_REFERENCE)
		return Plugin_Stop;
	
	if (g_bDroppedCheckReady[iProp])
	{
		float vecCenter[3], vecLastCenter[3];
		DroppedWeapon_GetCenter(iProp, vecCenter);
		
		for (int i = 0; i < 3; i++)
			vecLastCenter[i] = g_flDroppedLastCenter[iProp][i];
		
		TR_TraceRayFilter(vecLastCenter, vecCenter, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Trace_DroppedWeaponWorld);
		if (TR_DidHit())
		{
			float vecLastOrigin[3], vecStop[3];
			for (int i = 0; i < 3; i++)
				vecLastOrigin[i] = g_flDroppedLastOrigin[iProp][i];
			
			TeleportEntity(iProp, vecLastOrigin, NULL_VECTOR, vecStop);
			AcceptEntityInput(iProp, "DisableMotion");
			return Plugin_Stop;
		}
	}
	
	DroppedWeapon_SetCheckPoint(iProp);
	
	if (GetGameTime() >= g_flDroppedCheckEnd[iProp])
		return Plugin_Stop;
	
	return Plugin_Continue;
}

static void DroppedWeapon_SetCheckPoint(int iProp)
{
	float vecOrigin[3], vecCenter[3];
	GetEntPropVector(iProp, Prop_Data, "m_vecAbsOrigin", vecOrigin);
	DroppedWeapon_GetCenter(iProp, vecCenter);
	
	if (!g_bDroppedCheckReady[iProp])
	{
		TR_TraceRayFilter(vecCenter, vecCenter, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Trace_DroppedWeaponWorld);
		if (TR_StartSolid())
			return;
		
		g_bDroppedCheckReady[iProp] = true;
	}
	
	for (int i = 0; i < 3; i++)
	{
		g_flDroppedLastOrigin[iProp][i] = vecOrigin[i];
		g_flDroppedLastCenter[iProp][i] = vecCenter[i];
	}
}

static void DroppedWeapon_GetCenter(int iProp, float vecCenter[3])
{
	float vecOrigin[3], vecAngles[3], vecMins[3], vecMaxs[3], vecOffset[3];
	GetEntPropVector(iProp, Prop_Data, "m_vecAbsOrigin", vecOrigin);
	GetEntPropVector(iProp, Prop_Data, "m_angAbsRotation", vecAngles);
	GetEntPropVector(iProp, Prop_Send, "m_vecMins", vecMins);
	GetEntPropVector(iProp, Prop_Send, "m_vecMaxs", vecMaxs);
	
	AddVectors(vecMins, vecMaxs, vecOffset);
	ScaleVector(vecOffset, 0.5);
	RotateVector(vecOffset, vecAngles, vecCenter);
	AddVectors(vecOrigin, vecCenter, vecCenter);
}

bool Trace_DroppedWeaponWorld(int iEntity, int iMask, any iData)
{
	if (iEntity == 0)
		return true;
	
	if (iEntity <= MaxClients)
		return false;
	
	char sClassname[64];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
	return StrContains(sClassname, "func_") == 0 && !StrEqual(sClassname, "func_respawnroomvisualizer");
}

bool DroppedWeapon_IsPhysics(int iEntity)
{
	return IsClassname(iEntity, "prop_physics") && GetWeaponType(iEntity) == WeaponType_Dropped;
}

int DroppedWeapon_FindAimTarget(int iClient)
{
	if (!g_aDroppedWeapons || !g_aDroppedWeapons.Length)
		return -1;
	
	float vecEye[3], vecAngles[3], vecForward[3];
	GetClientEyePosition(iClient, vecEye);
	GetClientEyeAngles(iClient, vecAngles);
	GetAngleVectors(vecAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
	
	int iBest = -1;
	float flBest = DROPPED_AIM_RADIUS;
	
	for (int i = g_aDroppedWeapons.Length - 1; i >= 0; i--)
	{
		int iEntity = EntRefToEntIndex(g_aDroppedWeapons.Get(i));
		if (iEntity == INVALID_ENT_REFERENCE)
		{
			g_aDroppedWeapons.Erase(i);
			continue;
		}
		
		float vecCenter[3], vecDelta[3], vecClosest[3];
		DroppedWeapon_GetCenter(iEntity, vecCenter);
		SubtractVectors(vecCenter, vecEye, vecDelta);
		
		float flAlong = GetVectorDotProduct(vecDelta, vecForward);
		if (flAlong <= 0.0 || flAlong > DROPPED_AIM_DISTANCE)
			continue;
		
		vecClosest[0] = vecForward[0] * flAlong;
		vecClosest[1] = vecForward[1] * flAlong;
		vecClosest[2] = vecForward[2] * flAlong;
		
		float flMiss = GetVectorDistance(vecClosest, vecDelta);
		if (flMiss >= flBest)
			continue;
		
		TR_TraceRayFilter(vecEye, vecCenter, MASK_SOLID, RayType_EndPoint, Trace_DroppedWeaponSight, iEntity);
		if (TR_DidHit())
			continue;
		
		iBest = iEntity;
		flBest = flMiss;
	}
	
	return iBest;
}

bool Trace_DroppedWeaponSight(int iEntity, int iMask, any iData)
{
	if (iEntity == iData)
		return false;
	
	if (0 < iEntity <= MaxClients)
		return IsZombie(iEntity) != 0;
	
	return true;
}

void DroppedWeapon_OnEntityDestroyed(int iEntity)
{
	if (MaxClients < iEntity < sizeof(g_iRareOutline))
		RareOutline_Remove(iEntity);
}

void RareOutline_Set(int iEntity, Weapon wep)
{
	RareOutline_Remove(iEntity);
	
	int iClassMask;
	for (TFClassType nClass = TFClass_Scout; nClass <= TFClass_Engineer; nClass++)
	{
		if (TF2_GetItemSlot(wep.iIndex, nClass) >= 0)
			iClassMask |= (1 << view_as<int>(nClass));
	}
	
	int iGlow = CreateBonemerge(iEntity);
	SetEntPropString(iGlow, Prop_Data, "m_iName", RARE_OUTLINE_NAME);
	SetEntProp(iGlow, Prop_Send, "m_bGlowEnabled", true);
	g_iRareOutlineClassMask[iGlow] = iClassMask;
	SDKHook(iGlow, SDKHook_SetTransmit, RareOutline_SetTransmit);
	
	g_iRareOutline[iEntity] = EntIndexToEntRef(iGlow);
}

void RareOutline_Update(int iEntity, Weapon wep)
{
	if (wep.nRarity == WeaponRarity_Rare)
		RareOutline_Set(iEntity, wep);
	else
		RareOutline_Remove(iEntity);
}

void RareOutline_Remove(int iEntity)
{
	if (iEntity <= MaxClients || iEntity >= sizeof(g_iRareOutline))
		return;
	
	int iGlow = EntRefToEntIndex(g_iRareOutline[iEntity]);
	if (iGlow != INVALID_ENT_REFERENCE)
		RemoveEntity(iGlow);
	
	g_iRareOutline[iEntity] = INVALID_ENT_REFERENCE;
}

bool RareOutline_IsOutline(int iGlow)
{
	char sName[64];
	GetEntPropString(iGlow, Prop_Data, "m_iName", sName, sizeof(sName));
	return StrEqual(sName, RARE_OUTLINE_NAME);
}

public Action RareOutline_SetTransmit(int iGlow, int iClient)
{
	int iWeapon = GetEntPropEnt(iGlow, Prop_Data, "m_hEffectEntity");
	if (iWeapon == INVALID_ENT_REFERENCE)
	{
		RemoveEntity(iGlow);
		return Plugin_Handled;
	}
	
	if (!IsValidLivingSurvivor(iClient))
		return Plugin_Handled;
	
	if (g_iRareOutlineClassMask[iGlow] & (1 << view_as<int>(TF2_GetPlayerClass(iClient))))
		return Plugin_Continue;
	
	return Plugin_Handled;
}
