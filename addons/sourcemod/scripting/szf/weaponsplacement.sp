// Auto-place weapons for maps that don't have one

static bool g_bPlace;

// Approx same size as player ducking (width 49, height 63)
static float g_vecMins[3] = { -24.0, -24.0, 0.0 };
static float g_vecMaxs[3] = { 24.0, 24.0, 64.0 };
static ArrayList g_aWeaponPositions;

#define SOUND_SPAWN	"ui/halloween_boss_escape_sixty.wav"

void Placement_Reset()
{
	g_aWeaponPositions = new ArrayList(3);
	PrecacheSound(SOUND_SPAWN);
}

void Placement_TimerCreateSpawns(Handle hTimer, int iMaxCount)
{
	Placement_CreateSpawns("szf_weapon", iMaxCount);
	EmitSoundToAll(SOUND_SPAWN, _, SNDCHAN_STATIC, SNDLEVEL_NONE);
	CPrintToChatAll("{green}More survivor weapons has spawned!");	// TODO red for zombie
}

void Placement_CreateSpawns(char[] sWeapon = "szf_weapon_common", int iMaxCount = 50)
{
	ArrayList aEntities = new ArrayList();
	
	int iEntity = INVALID_ENT_REFERENCE;
	
	while ((iEntity = FindEntityByClassname(iEntity, "tf_halloween_gift_spawn_location")) != INVALID_ENT_REFERENCE)
		aEntities.Push(iEntity);
	
	while ((iEntity = FindEntityByClassname(iEntity, "entity_spawn_point")) != INVALID_ENT_REFERENCE)
		aEntities.Push(iEntity);
	
	while ((iEntity = FindEntityByClassname(iEntity, "info_player_teamspawn")) != INVALID_ENT_REFERENCE)
		if (view_as<TFTeam>(GetEntProp(iEntity, Prop_Send, "m_iTeamNum")) == TFTeam_Red)
			aEntities.Push(iEntity);
	
	aEntities.Sort(Sort_Random, Sort_Integer);
	int iLength = aEntities.Length;
	
	int iIndex;
	int iAttempts;
	
	while (g_aWeaponPositions.Length < iMaxCount && iAttempts < 25)
	{
		iEntity = aEntities.Get(iIndex);
		iIndex++;
		iAttempts++;
		
		if (iIndex >= iLength)
			iIndex = 0;
		
		float vecPositon[3], vecEnd[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecPositon);
		vecPositon[2] += 64.0;
		
		if (TR_PointOutsideWorld(vecPositon))
			continue;
		
		float vecAngles[3];
		vecAngles[1] = GetRandomFloat(0.0, 360.0);
		AnglesToVelocity(vecAngles, vecEnd, 2048.0);
		
		AddVectors(vecPositon, vecEnd, vecEnd);
		TR_TraceHullFilter(vecPositon, vecEnd, g_vecMins, g_vecMaxs, MASK_PLAYERSOLID, Placement_TraceFilter);
		TR_GetEndPosition(vecPositon);
		
		Placement_GetFloor(vecPositon, vecEnd);
		
		// Is there triggers in the way?
		g_bPlace = true;
		
		TR_EnumerateEntitiesHull(vecPositon, vecEnd, g_vecMins, g_vecMaxs, PARTITION_TRIGGER_EDICTS, Placement_TraceEnumerate);
		if (!g_bPlace)
			continue;
		
		// Are the gap not too far off between hull and ray traces?
		TR_TraceRayFilter(vecPositon, {90.0, 0.0, 0.0}, MASK_PLAYERSOLID, RayType_Infinite, Placement_TraceFilter);
		TR_GetEndPosition(vecPositon);
		if (GetVectorDistance(vecEnd, vecPositon) > 4.0)
			continue;
		
		bool bAllow = true;
		int iLen = g_aWeaponPositions.Length;
		for (int i = 0; i < iLen; i++)
		{
			float vecOther[3];
			g_aWeaponPositions.GetArray(i, vecOther, sizeof(vecOther));
			if (GetVectorDistance(vecEnd, vecOther) > 32.0)
				continue;
			
			bAllow = false;
			break;
		}
		
		if (!bAllow)
			continue;
		
		vecEnd[2] += 3.0;
		
		vecAngles[1] = GetRandomFloat(0.0, 360.0);
		vecAngles[2] = 90.0;
		
		iEntity = CreateEntityByName("prop_dynamic");
		TeleportEntity(iEntity, vecEnd, vecAngles);
		SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
		SetEntProp(iEntity, Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
		SetEntPropString(iEntity, Prop_Data, "m_iName", sWeapon);
		SetWeapon(iEntity);
		DispatchSpawn(iEntity);
		
		g_aWeaponPositions.PushArray(vecEnd);
		iAttempts = 0;
	}
}

static void Placement_GetFloor(const float vecPositon[3], float vecEnd[3])
{
	vecEnd = vecPositon;
	
	if (TR_PointOutsideWorld(vecEnd))
		return;	// meh, just return same as what we have
	
	vecEnd[2] -= 8192.0;
	
	TR_TraceHullFilter(vecPositon, vecEnd, g_vecMins, g_vecMaxs, MASK_PLAYERSOLID, Placement_TraceFilter);
	TR_GetEndPosition(vecEnd);
}

static bool Placement_TraceFilter(int iEntity, int iMask, any nData)
{
	// Above LAST_SHARED_COLLISION_GROUP is all of the dynamic TF2 stuffs, e.g. TF_COLLISIONGROUP_GRENADES, TFCOLLISION_GROUP_OBJECT, etc
	int iCollisionGroup = GetEntProp(iEntity, Prop_Send, "m_CollisionGroup");
	if (iCollisionGroup == COLLISION_GROUP_DEBRIS || iCollisionGroup == COLLISION_GROUP_PLAYER || iCollisionGroup >= LAST_SHARED_COLLISION_GROUP)
		return false;
	
	return true;
}

static bool Placement_TraceEnumerate(int iEntity)
{
	static char sBadClassnames[][] = {
		"func_croc",
		"trigger_catapult",
		"trigger_hurt",
		"trigger_ignite",
		"trigger_push",
		"trigger_teleport",
	};
	
	char sClassname[256];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
	
	for (int i = 0; i < sizeof(sBadClassnames); i++)
	{
		if (StrEqual(sClassname, sBadClassnames[i]))
		{
			TR_ClipCurrentRayToEntity(MASK_ALL, iEntity);
			if (!TR_DidHit())
				return true;
			
			g_bPlace = false;
			return false;
		}
	}
	
	return true;
}
