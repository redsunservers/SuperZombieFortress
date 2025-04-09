////////////////
// Normal
////////////////

public void Infected_DoGenericRage(int iClient)
{
	int iHealth = GetClientHealth(iClient);
	SetEntityHealth(iClient, RoundToCeil(iHealth * 1.5));
	
	float vecClientPos[3];
	GetClientEyePosition(iClient, vecClientPos);
	vecClientPos[2] -= 60.0; //Wheel goes down or smth, so thats why i did that i guess
	
	ShowParticle("spell_cast_wheel_blue", 4.0, vecClientPos);
	PrintHintText(iClient, "%t", "Infected_RageUsed");
	Sound_PlayInfectedVo(iClient, Infected_None, SoundVo_Rage);
}

public void Infected_DoNoRage(int iClient)
{
	PrintHintText(iClient, "%t", "Infected_CantUseRage");
}

////////////////
// Tank
////////////////

static Handle g_hTimerTank[MAXPLAYERS+1];
static float g_flTankLifetime[MAXPLAYERS+1];
static int g_iTankHealthSubtract[MAXPLAYERS+1];
static int g_iTankDebris[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};

public void Infected_OnTankSpawn(int iClient)
{
	//TAAAAANK
	CPrintToChatAll("%t", "Tank_Spawn", "{red}");
	Sound_PlayInfectedVoToAll(Infected_Tank, SoundVo_Fire);
	
	g_iTanksSpawned++;
	
	g_hTimerTank[iClient] = CreateTimer(1.0, Infected_TankTimer, GetClientSerial(iClient), TIMER_REPEAT);
	g_flTankLifetime[iClient] = GetGameTime();
	g_iTankDebris[iClient] = INVALID_ENT_REFERENCE;
	
	int iSurvivors = GetSurvivorCount();
	int iHealth = g_cvTankHealth.IntValue * iSurvivors;
	iHealth = max(iHealth, g_cvTankHealthMin.IntValue);
	iHealth = min(iHealth, g_cvTankHealthMax.IntValue);
	
	g_iMaxHealth[iClient] = iHealth;
	SetEntityHealth(iClient, iHealth);
	
	int iSubtract = 0;
	if (g_cvTankTime.FloatValue > 0.0)
		iSubtract = max(RoundFloat(float(iHealth) / g_cvTankTime.FloatValue), 3);
	
	g_iTankHealthSubtract[iClient] = iSubtract;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (GetCookie(i, g_cFirstTimeSurvivor) < 2)
			{
				DataPack data;
				CreateDataTimer(0.5, Timer_DisplayTutorialMessage, data);
				data.WriteCell(i);
				data.WriteFloat(4.0);
				data.WriteString("Tutorial_TankSpawn1");
				
				CreateDataTimer(4.5, Timer_DisplayTutorialMessage, data);
				data.WriteCell(i);
				data.WriteFloat(4.0);
				data.WriteString("Tutorial_TankSpawn2");
				
				SetCookie(i, 2, g_cFirstTimeSurvivor);
			}
			
			SetVariantString("IsMvMDefender:1");
			AcceptEntityInput(i, "AddContext");
			SetVariantString("TLK_MVM_TANK_CALLOUT");
			AcceptEntityInput(i, "SpeakResponseConcept");
			AcceptEntityInput(i, "ClearContext");
		}
	}
	
	Sound_PlayMusicToAll("tank");
	FireRelay("FireUser1", "szf_zombietank", "szf_tank", iClient);
	Forward_OnTankSpawn(iClient);
}

public Action Infected_TankTimer(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!IsValidLivingZombie(iClient) || g_hTimerTank[iClient] != hTimer || g_nInfected[iClient] != Infected_Tank)
		return Plugin_Stop;
	
	TF2_AddCondition(iClient, TFCond_Kritzkrieged, 2.0);
	
	//Tank super health handler
	int iHealth = GetClientHealth(iClient);
	int iMaxHealth = SDKCall_GetMaxHealth(iClient);
	if (iHealth < iMaxHealth || g_flTankLifetime[iClient] < GetGameTime() - 15.0)
	{
		if (iHealth - g_iTankHealthSubtract[iClient] > 0)
			SetEntityHealth(iClient, iHealth - g_iTankHealthSubtract[iClient]);
		else
			ForcePlayerSuicide(iClient);
	}
	
	//Screen shake if tank is close by
	float vecPosClient[3];
	float vecPosTank[3];
	float flDistance;
	GetClientEyePosition(iClient, vecPosTank);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i))
		{
			GetClientEyePosition(i, vecPosClient);
			flDistance = GetVectorDistance(vecPosTank, vecPosClient);
			flDistance /= 20.0;
			if (flDistance <= 50.0)
				Shake(i, fMin(50.0 - flDistance, 5.0), 1.2);
		}
	}
	
	return Plugin_Continue;
}

public void Infected_DoTankThrow(int iClient)
{
	float flThrow, flEnd;
	
	SetVariantInt(1);
	AcceptEntityInput(iClient, "SetForcedTauntCam");
	
	switch (GetRandomInt(2, 4))
	{
		case 2:
		{
			SDKCall_PlaySpecificSequence(iClient, "Throw_02");
			flThrow = 2.25;
			flEnd = 3.0;
		}
		case 3:
		{
			SDKCall_PlaySpecificSequence(iClient, "Throw_03");
			flThrow = 2.1;
			flEnd = 2.6;
		}
		case 4:
		{
			SDKCall_PlaySpecificSequence(iClient, "Throw_04");
			flThrow = 2.6;
			flEnd = 3.0;
		}
	}
	
	TF2_AddCondition(iClient, TFCond_FreezeInput, flEnd);
	CreateTimer(flEnd, Infected_DebrisTimerEnd, GetClientSerial(iClient));
	
	int iDebris = CreateEntityByName("prop_physics_override");
	
	Debris debris;
	Config_GetRandomDebris(debris);
	SetEntityModel(iDebris, debris.sModel);
	
	SetEntProp(iDebris, Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
	DispatchKeyValueFloat(iDebris, "massScale", 300.0);
	DispatchKeyValueFloat(iDebris, "modelscale", debris.flScale);
	
	SetEntPropEnt(iDebris, Prop_Send, "m_hOwnerEntity", iClient);
	SetEntProp(iDebris, Prop_Data, "m_spawnflags", SF_PHYSPROP_START_ASLEEP|SF_PHYSPROP_MOTIONDISABLED);
	SetEntProp(iDebris, Prop_Data, "m_takedamage", DAMAGE_NO);
	SetEntityCollisionGroup(iDebris, COLLISION_GROUP_PLAYER);
	SetEntProp(iDebris, Prop_Send, "m_iTeamNum", GetClientTeam(iClient));
	SetEntityRenderMode(iDebris, RENDER_TRANSCOLOR);
	
	int iBonemerge = CreateBonemerge(iClient, "debris");
	
	float vecPos[3], vecAngle[3];
	GetClientAbsOrigin(iClient, vecPos);
	GetClientAbsAngles(iClient, vecAngle);
	AddVectors(vecPos, debris.vecOffset, vecPos);
	AddVectors(vecAngle, debris.vecAngle, vecAngle);
	TeleportEntity(iBonemerge, vecPos, vecAngle, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(iDebris, "SetParent", iBonemerge);
	SetVariantString("debris");
	AcceptEntityInput(iDebris, "SetParentAttachment");
	
	DispatchSpawn(iDebris);
	
	SetEntPropFloat(iDebris, Prop_Data, "m_impactEnergyScale", 0.0);	//After DispatchSpawn, otherwise 1 would be set
	
	g_iTankDebris[iClient] = EntIndexToEntRef(iDebris);
	
	CreateTimer(flThrow, Infected_DebrisTimer, GetClientSerial(iClient));
}

public Action Infected_DebrisTimer(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Continue;
	
	Infected_ActivateDebris(iClient, true);
	
	return Plugin_Continue;
}

void Infected_ActivateDebris(int iClient, bool bVel)
{
	int iDebris = g_iTankDebris[iClient];
	g_iTankDebris[iClient] = INVALID_ENT_REFERENCE;
	
	if (!IsValidEntity(iDebris))
		return;
	
	AcceptEntityInput(iDebris, "ClearParent");
	AcceptEntityInput(iDebris, "EnableMotion");
	ActivateEntity(iDebris);	//So physics can scale with modelscale
	
	int iBonemerge = GetEntPropEnt(iDebris, Prop_Data, "m_pParent");
	if (iBonemerge != INVALID_ENT_REFERENCE && IsClassname(iBonemerge, "tf_taunt_prop"))
		RemoveEntity(iBonemerge);
	
	SDKHook(iDebris, SDKHook_StartTouch, Infected_DebrisStartTouch);
	
	if (bVel)
	{
		// Calculate velocity from eye angle
		float vecAngles[3], vecVel[3];
		GetClientEyeAngles(iClient, vecAngles);
		AnglesToVelocity(vecAngles, vecVel, 2000.0);
		
		// Calculate position by distance between eye and rock,
		float vecEyePos[3], vecDebrisPos[3];
		GetClientEyePosition(iClient, vecEyePos);
		GetEntPropVector(iDebris, Prop_Send, "m_vecOrigin", vecDebrisPos);
		float flDistance = GetVectorDistance(vecEyePos, vecDebrisPos);
		AnglesToVelocity(vecAngles, vecDebrisPos, flDistance);
		AddVectors(vecDebrisPos, vecEyePos, vecDebrisPos);
		
		TeleportEntity(iDebris, vecDebrisPos, NULL_VECTOR, vecVel);
	}
	
	CreateTimer(1.0, Infected_DebrisTimerMoving, iDebris, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	float flLifetime = g_cvTankDebrisLifetime.FloatValue;
	if (flLifetime > 0.0)
		CreateTimer(flLifetime, Infected_DebrisTimerFadeOutStart, iDebris);
}

public Action Infected_DebrisTimerEnd(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!IsValidClient(iClient))
		return Plugin_Continue;
	
	SetVariantInt(0);
	AcceptEntityInput(iClient, "SetForcedTauntCam");
	
	return Plugin_Continue;
}

public Action Infected_DebrisTimerMoving(Handle hTimer, int iDebris)
{
	if (!IsValidEntity(iDebris))
		return Plugin_Stop;
	
	if (GetEntProp(iDebris, Prop_Send, "m_bAwake"))
		return Plugin_Continue;
	
	SetEntityCollisionGroup(iDebris, COLLISION_GROUP_DEBRIS);
	SetEntityMoveType(iDebris, MOVETYPE_NONE);
	
	return Plugin_Stop;
}

public Action Infected_DebrisTimerFadeOutStart(Handle hTimer, int iDebris)
{
	if (!IsValidEntity(iDebris))
		return Plugin_Stop;
	
	SetEntityCollisionGroup(iDebris, COLLISION_GROUP_DEBRIS);
	RequestFrame(Infected_DebrisFrameFadeOut, iDebris);
	
	return Plugin_Continue;
}

void Infected_DebrisFrameFadeOut(int iDebris)
{
	if (!IsValidEntity(iDebris))
		return;
	
	int iColor[4];
	GetEntityRenderColor(iDebris, iColor[0], iColor[1], iColor[2], iColor[3]);
	
	int iAlpha = iColor[3] - 10;
	if (iAlpha <= 0)
	{
		RemoveEntity(iDebris);
		return;
	}
	
	SetEntityRenderColor(iDebris, .a = iAlpha);
	RequestFrame(Infected_DebrisFrameFadeOut, iDebris);
}

public Action Infected_DebrisStartTouch(int iDebris, int iToucher)
{
	int iClient = GetEntPropEnt(iDebris, Prop_Send, "m_hOwnerEntity");
	
	float vecVelocity[3];
	SDKCall_GetVelocity(iDebris, vecVelocity);
	float flSpeed = GetVectorLength(vecVelocity);
	
	if (0 < iToucher <= MaxClients && flSpeed >= 100.0)
		SDKHooks_TakeDamage(iToucher, iDebris, iClient, flSpeed / 4.0);
	
	return Plugin_Continue;
}

public void Infected_OnTankThink(int iClient)
{
	if (!IsPlayerAlive(iClient))
		return;
	
	// Force tank to block any CP being captured
	int iTrigger = INVALID_ENT_REFERENCE;
	while ((iTrigger = FindEntityByClassname(iTrigger, "trigger_capture_area")) != INVALID_ENT_REFERENCE)
	{
		static int iOffset = -1;
		if (iOffset == -1)
			iOffset = FindDataMapInfo(iTrigger, "m_flCapTime");
		
		TFTeam nCapturingTeam = view_as<TFTeam>(GetEntData(iTrigger, iOffset - 12));	// m_nCapturingTeam
		float flTimeRemaining = GetEntDataFloat(iTrigger, iOffset + 4);	// m_fTimeRemaining
		if (nCapturingTeam != TFTeam_Survivor || flTimeRemaining == 0.0)
			continue;
		
		// Stop blocking CP if survivor captures has expired, as otherwise Tank would keep hogging the capture progress
		int iCP = GetCapturePointFromTrigger(iTrigger);
		int iIndex = GetEntProp(iCP, Prop_Data, "m_iPointIndex");
		int iResource = FindEntityByClassname(INVALID_ENT_REFERENCE, "tf_objective_resource");
		int iRequiredCappers = GetEntProp(iResource, Prop_Send, "m_iTeamReqCappers", _, (iIndex + (view_as<int>(TFTeam_Survivor) * MAX_CONTROL_POINTS)));
		float flTimeToCap = GetEntPropFloat(iTrigger, Prop_Data, "m_flCapTime") * 2.0 * float(iRequiredCappers);
		if (flTimeToCap < flTimeRemaining)
			continue;
		
		// Filter usually have red-team only, we want tank to bypass the filter
		int iFilter = GetEntPropEnt(iTrigger, Prop_Data, "m_hFilter");
		SetEntPropEnt(iTrigger, Prop_Data, "m_hFilter", INVALID_ENT_REFERENCE);
		AcceptEntityInput(iTrigger, "StartTouch", iClient, iClient);
		SetEntPropEnt(iTrigger, Prop_Data, "m_hFilter", iFilter);
	}
}

public Action Infected_OnTankDamage(int iClient, int &iAttacker, int &iInflicter, float &flDamage, int &iDamageType, int &iWeapon, float vecForce[3], float vecForcePos[3], int iDamageCustom)
{
	//Tank is immune to knockback
	ScaleVector(vecForce, 0.0);
	iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
			
	//Disable fall damage to tank
	if (iDamageType & DMG_FALL)
		flDamage = 0.0;
	
	if (IsValidSurvivor(iAttacker))
	{
		//"SHOOT THAT TANK" voice call
		SetVariantString("IsMvMDefender:1");
		AcceptEntityInput(iAttacker, "AddContext");
		SetVariantString("TLK_MVM_ATTACK_THE_TANK");
		AcceptEntityInput(iAttacker, "SpeakResponseConcept");
		AcceptEntityInput(iAttacker, "ClearContext");
		
		//Don't instantly kill the tank on a backstab
		if (iDamageCustom == TF_CUSTOM_BACKSTAB)
		{
			flDamage = g_cvTankStab.FloatValue / 3.0;
			iDamageType |= DMG_CRIT;
			SetNextAttack(iAttacker, GetGameTime() + 1.25);
		}
		
		g_flDamageDealtAgainstTank[iAttacker] += flDamage;
	}
	
	//Check if tank takes damage from map deathpit, if so kill him
	if (MaxClients < iAttacker)
	{
		char strAttacker[32];
		GetEntityClassname(iAttacker, strAttacker, sizeof(strAttacker));
		if (StrContains(strAttacker, "trigger_hurt") == 0 && flDamage >= 450.0)
			ForcePlayerSuicide(iClient);
	}
	
	return Plugin_Changed;
}

public void Infected_OnTankDeath(int iVictim, int iKiller, int iAssist)
{
	g_hTimerTank[iVictim] = null;
	g_iDamageZombie[iVictim] = 0;
	
	Infected_ActivateDebris(iVictim, false);	// Drop debris if tank were to hold one
	
	int iTrigger = INVALID_ENT_REFERENCE;
	while ((iTrigger = FindEntityByClassname(iTrigger, "trigger_capture_area")) != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iTrigger, "EndTouch", iVictim, iVictim);
	
	if (0 < iKiller <= MaxClients && IsClientInGame(iKiller))
	{
		SetVariantString("TLK_MVM_TANK_DEAD");
		AcceptEntityInput(iKiller, "SpeakResponseConcept");
	}
	
	if (0 < iAssist <= MaxClients && IsClientInGame(iAssist))
	{
		SetVariantString("TLK_MVM_TANK_DEAD");
		AcceptEntityInput(iAssist, "SpeakResponseConcept");
	}
	
	if(!ZombiesHaveTank(iVictim))
	{
		int iWinner = 0;
		float flHighest = 0.0;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			// End tank music
			Sound_EndSpecificMusic(i, "tank");
			
			if (IsValidLivingSurvivor(i))
			{
				if (flHighest < g_flDamageDealtAgainstTank[i])
				{
					flHighest = g_flDamageDealtAgainstTank[i];
					iWinner = i;
				}
				
				g_flDamageDealtAgainstTank[i] = 0.0;
			}
		}
		
		if (flHighest > 0.0)
		{
			SetHudTextParams(-1.0, 0.3, 8.0, 200, 255, 200, 128, 1);
			
			if (g_iTanksSpawned > 1)
			{
				for (int i = 1; i <= MaxClients; i++)
					if (IsValidClient(i))
						ShowHudText(i, 5, "%t", "Tank_Multi_Died", g_iTanksSpawned, iWinner, RoundFloat(flHighest));
			}
			else
			{
				for (int i = 1; i <= MaxClients; i++)
					if (IsValidClient(i))
						ShowHudText(i, 5, "%t", "Tank_Died", iVictim, iWinner, RoundFloat(flHighest));
			}
		}
		
		g_iTanksSpawned = 0;
		
		if (g_iDamageDealtLife[iVictim] <= 50 && g_iDamageTakenLife[iVictim] <= 150 && !g_bTankRefreshed)
		{
			g_bTankRefreshed = true;
			Classes_SetClient(iVictim, Infected_None);
			ZombieTank();
		}
		
		Forward_OnTankDeath(iVictim, iWinner, RoundFloat(flHighest));
	}
	else
	{
		Forward_OnTankDeath(iVictim, 0, 0);
	}
	
	FireRelay("FireUser2", "szf_zombietank", "szf_tank", iVictim);
}

////////////////
// Boomer
////////////////

public void Infected_DoBoomerRage(int iClient)
{
	Infected_DoBoomerExplosion(iClient, 600.0);
}

public void Infected_OnBoomerDeath(int iClient, int iKiller, int iAssist)
{
	Infected_DoBoomerExplosion(iClient, 400.0);
}

void Infected_DoBoomerExplosion(int iClient, float flRadius)
{
	if (g_nRoundState != SZFRoundState_Active)
		return;
	
	//No need to set rage cooldown: he's fucking dead LMAO
	float vecClientPos[3];
	float vecSurvivorPos[3];
	GetClientEyePosition(iClient, vecClientPos);
	
	ShowParticle("asplode_hoodoo_debris", 6.0, vecClientPos);
	ShowParticle("asplode_hoodoo_dust", 6.0, vecClientPos);
	
	int[] iClientsTemp = new int[MaxClients];
	int iCount = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
		{
			GetClientEyePosition(i, vecSurvivorPos);
			float flDistance = GetVectorDistance(vecClientPos, vecSurvivorPos);
			if (flDistance <= flRadius)
			{
				float flDuration = 12.0 - (flDistance * 0.01);
				TF2_AddCondition(i, TFCond_Jarated, flDuration);
				Sound_PlayMusicToClient(i, "jarate", flDuration);
				
				iClientsTemp[iCount] = i;
				iCount++;
			}
		}
	}
	
	int iClients[MAXPLAYERS];
	for (int i = 0; i < iCount; i++)
		iClients[i] = iClientsTemp[i];
	
	Forward_OnBoomerExplode(iClient, iClients, iCount);
	Sound_PlayInfectedVo(iClient, g_nInfected[iClient], SoundVo_Rage);
	
	if (IsPlayerAlive(iClient))
		FakeClientCommandEx(iClient, "explode");
}

////////////////
// Charger
////////////////

static float g_flChargerEndCharge[MAXPLAYERS+1];
static bool g_bChargerHitSurvivor[MAXPLAYERS+1][MAXPLAYERS+1];

public void Infected_OnChargerSpawn(int iClient)
{
	g_flChargerEndCharge[iClient] = 0.0;
}

public void Infected_DoChargerCharge(int iClient)
{
	for (int i = 1; i <= MaxClients; i++)
		g_bChargerHitSurvivor[iClient][i] = false;
	
	TF2_AddCondition(iClient, TFCond_Charging, 1.65);
	SetNextAttack(iClient, GetGameTime() + 1.65);
	g_flChargerEndCharge[iClient] = GetGameTime() + 1.65;
	
	SDKCall_PlaySpecificSequence(iClient, "Charger_Charge");
}

public void Infected_OnChargerThink(int iClient, int &iButtons)
{
	if (g_flChargerEndCharge[iClient] > GetGameTime())
	{
		iButtons |= IN_FORWARD;
		
		if (!TF2_IsPlayerInCondition(iClient, TFCond_Charging))
			TF2_AddCondition(iClient, TFCond_Charging, g_flChargerEndCharge[iClient] - GetGameTime());
		
		float vecOrigin[3], vecAngles[3], vecVel[3];
		GetClientAbsOrigin(iClient, vecOrigin);
		GetClientEyeAngles(iClient, vecAngles);
		
		//Move origin a bit further so we get a better guess who were colliding with
		vecAngles[0] = 0.0;
		AnglesToVelocity(vecAngles, vecVel, 75.0);
		AddVectors(vecOrigin, vecVel, vecOrigin);
		
		//Keep the charge meter at 100.0, so you never really run out of charge
		SetEntPropFloat(iClient, Prop_Send, "m_flChargeMeter", 100.0);
		
		//Force push charger at stupid amount of speed, WEEEEEEEEEEEEEEEEEE
		const float flSpeed = 520.0;
		AnglesToVelocity(vecAngles, vecVel, flSpeed);
		
		float vecCurrentVelocity[3];
		GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vecCurrentVelocity);
		vecVel[2] = vecCurrentVelocity[2];
		
		TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVel);
		
		for (int iVictim = 1; iVictim <= MaxClients; iVictim++)
		{
			if (IsValidLivingSurvivor(iVictim))
			{
				float vecPosClient[3];
				GetClientAbsOrigin(iVictim, vecPosClient);
				if (GetVectorDistance(vecOrigin, vecPosClient) <= 75.0)
				{
					TF2_AddCondition(iVictim, TFCond_LostFooting, 0.5);	//Allow push victims easier with friction
					
					vecVel[2] = 0.0;
					TeleportEntity(iVictim, NULL_VECTOR, NULL_VECTOR, vecVel);
					
					if (!TF2_IsPlayerInCondition(iVictim, TFCond_Bleeding))
						TF2_MakeBleed(iVictim, iClient, 0.5);
					
					if (!g_bChargerHitSurvivor[iClient][iVictim])
					{
						g_bChargerHitSurvivor[iClient][iVictim] = true;
						Forward_OnChargerHit(iClient, iVictim);
					}
				}
			}
		}
	}
}

public Action Infected_OnChargerAttack(int iVictim, int &iClient, int &iInflicter, float &flDamage, int &iDamageType, int &iWeapon, float vecForce[3], float vecForcePos[3], int iDamageCustom)
{
	if (!(iDamageType & DMG_CLUB))	// melee damage
		return Plugin_Continue;
	
	TF2_AddCondition(iClient, TFCond_CritCola, 0.05);	// mini-crit without visual effects, does unintentionally blocks healing
	
	// Make vector from attacker to victim pos
	float vecOriginVictim[3], vecOriginAttacker[3], vecVelocity[3], vecResult[3];
	GetClientAbsOrigin(iVictim, vecOriginVictim);
	GetClientAbsOrigin(iClient, vecOriginAttacker);
	
	MakeVectorFromPoints(vecOriginAttacker, vecOriginVictim, vecVelocity);
	NormalizeVector(vecVelocity, vecVelocity);
	vecVelocity[2] += 0.5;	// slightly upward
	ScaleVector(vecVelocity, 400.0);
	
	GetEntPropVector(iVictim, Prop_Data, "m_vecVelocity", vecResult);
	AddVectors(vecResult, vecVelocity, vecResult);
	
	TF2_AddCondition(iVictim, TFCond_LostFooting, 0.4);	//Allow push victims easier with friction
	TeleportEntity(iVictim, NULL_VECTOR, NULL_VECTOR, vecResult);
	
	Stun_Shake(iVictim, vecForce, 250.0);	// Give a little screen shake on being knocked back
	
	iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
	return Plugin_Changed;
}

////////////////
// Screamer
////////////////

public void Infected_DoScreamerRage(int iClient)
{
	char sPath[64];
	Format(sPath, sizeof(sPath), "ambient/halloween/male_scream_%d.wav", GetRandomInt(15, 16));
	EmitSoundToAll(sPath, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	
	float vecPosScreamer[3]; //Fun fact: this is based on l4d's scrapped "screamer" special infected, which "buffed" zombies with its presence
	float vecPosZombie[3];
	GetClientEyePosition(iClient, vecPosScreamer);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsZombie(i))
		{
			GetClientEyePosition(i, vecPosZombie);
			float flDistance = GetVectorDistance(vecPosScreamer, vecPosZombie);
			if (flDistance <= 600.0)
			{
				TF2_AddCondition(i, TFCond_DefenseBuffed, 7.0 - flDistance / 120.0);
				Shake(i, 3.0, 3.0);
			}
		}
	}
}

public void Infected_OnScreamerThink(int iClient, int &iButtons)
{
	float flPosClient[3];
	float flPosScreamer[3];
	float flDistance;
	GetClientEyePosition(iClient, flPosScreamer);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingZombie(i))
		{
			GetClientEyePosition(i, flPosClient);
			flDistance = GetVectorDistance(flPosScreamer, flPosClient);
			if (flDistance <= 600.0)
				TF2_AddCondition(i, TFCond_TeleportedGlow, 0.1);
		}
	}
}

////////////////
// Stalker
////////////////

public void Infected_OnStalkerThink(int iClient, int &iButtons)
{
	TF2_SetCloakMeter(iClient, 100.0);
	
	//To prevent fuckery with cloaking
	if (iButtons & IN_ATTACK2)
		iButtons &= ~IN_ATTACK2;
	
	float vecPosClient[3];
	float vecPosPredator[3];
	float flDistance;
	bool bTooClose = false;
	GetClientEyePosition(iClient, vecPosPredator);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
		{
			GetClientEyePosition(i, vecPosClient);
			flDistance = GetVectorDistance(vecPosPredator, vecPosClient);
			if (flDistance <= 250.0)
			{
				bTooClose = true;
				break;
			}
		}
	}
	
	if (!bTooClose && !TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
		TF2_AddCondition(iClient, TFCond_Cloaked, TFCondDuration_Infinite);
	else if (bTooClose && TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
		TF2_RemoveCondition(iClient, TFCond_Cloaked);
}

////////////////
// Hunter
////////////////

static bool g_bHunterIsUsingPounce[MAXPLAYERS+1];

public void Infected_DoHunterJump(int iClient)
{
	float vecVelocity[3];
	float vecEyeAngles[3];
	
	GetClientEyeAngles(iClient, vecEyeAngles);
	
	vecVelocity[0] = Cosine(DegToRad(vecEyeAngles[0])) * Cosine(DegToRad(vecEyeAngles[1])) * 920;
	vecVelocity[1] = Cosine(DegToRad(vecEyeAngles[0])) * Sine(DegToRad(vecEyeAngles[1])) * 920;
	vecVelocity[2] = 460.0;
	
	SDKCall_PlaySpecificSequence(iClient, "pounce_idle_low");
	ViewModel_SetAnimation(iClient, "ACT_VM_LUNGE_LAYER");
	
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVelocity);
	SetEntProp(iClient, Prop_Send, "m_iAirDash", 1);
	SetEntProp(iClient, Prop_Send, "m_bJumping", true);
	
	int iFlags = GetEntityFlags(iClient);
	iFlags &= ~FL_ONGROUND;
	SetEntityFlags(iClient, iFlags);
	
	g_bHunterIsUsingPounce[iClient] = true;
}

public void Infected_OnHunterThink(int iClient, int &iButtons)
{
	if (GetEntityFlags(iClient) & FL_ONGROUND)
		g_bHunterIsUsingPounce[iClient] = false;
}

public void Infected_OnHunterTouch(int iClient, int iToucher)
{
	if (!g_bHunterIsUsingPounce[iClient] || !IsValidLivingSurvivor(iToucher))
		return;
	
	const float flDuration = 5.5;
	if (Stun_StartPlayer(iToucher, flDuration))
	{
		SetEntityHealth(iToucher, GetClientHealth(iToucher) - 20);
		SetNextAttack(iClient, GetGameTime() + 2.0);
		
		//Teleport hunter inside the target
		float vecPosClient[3];
		GetClientAbsOrigin(iToucher, vecPosClient);
		TeleportEntity(iClient, vecPosClient, NULL_VECTOR, NULL_VECTOR);
		
		TF2_StunPlayer(iToucher, flDuration, 0.5, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_SLOWDOWN, 0);
		TF2_StunPlayer(iClient, flDuration, 1.0, TF_STUNFLAG_SLOWDOWN, 0);
		
		Forward_OnHunterHit(iClient, iToucher);
	}
	
	g_bHunterIsUsingPounce[iClient] = false;
	g_iRageTimer[iClient] = 21;
}

public void Infected_OnHunterDeath(int iClient, int iKiller, int iAssist)
{
	g_bHunterIsUsingPounce[iClient] = false;
}

////////////////
// Smoker
////////////////

enum SmokerStatus
{
	SmokerStatus_None,		// not pulling tongue out
	SmokerStatus_Extend,	// extending the tongue
	SmokerStatus_Grabbing,	// in process of grabbing someone, slowly
	SmokerStatus_Retract,	// retract tongue out fast
}

static SmokerStatus g_nSmokerStatus[MAXPLAYERS+1];
static int g_iSmokerRopes[MAXPLAYERS+1][2];
static float g_flSmokerGrabStart[MAXPLAYERS+1];
static int g_iSmokerGrabVictim[MAXPLAYERS+1];

static int g_iSmokerBeamHits[MAXPLAYERS+1];

// TODO convar?
const float flSmokerSpeedSlow = 100.0;
const float flSmokerSpeedFast = 350.0;
const float flSmokerZPosition = -8.0;

public void Infected_OnSmokerThink(int iClient, int &iButtons)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, WeaponSlot_Melee);
	if (iWeapon != INVALID_ENT_REFERENCE)
		SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.0);	// Don't want to swing from m2
	
	if (g_nSmokerStatus[iClient] != SmokerStatus_None && (!IsValidEntity(g_iSmokerRopes[iClient][0]) || !IsValidEntity(g_iSmokerRopes[iClient][1])))
	{
		Infected_EndSmokerBeam(iClient);
		return;
	}
	
	switch (g_nSmokerStatus[iClient])
	{
		case SmokerStatus_None:
		{
			if (iButtons & IN_ATTACK2 && (GetEntityFlags(iClient) & FL_ONGROUND == FL_ONGROUND) && (GetEntityFlags(iClient) & FL_DUCKING != FL_DUCKING))
			{
				// Begin the smoker beam
				Infected_StartSmokerBeam(iClient);
				ViewModel_SetAnimation(iClient, "ACT_VM_TONGUE");
			}
		}
		case SmokerStatus_Extend:
		{
			if (DistanceFromEntities(g_iSmokerRopes[iClient][0], g_iSmokerRopes[iClient][1]) >= 1150.0)
			{
				//750 in L4D2, scaled to TF2 player hull sizing (32hu -> 48hu)
				Infected_RetractSmokerBeam(iClient, SmokerStatus_Retract);
				return;
			}
			
			if (!Infected_DoBeamTrace(iClient))	// find a victim to grab while extending
				return;
			
			if (IsValidLivingSurvivor(g_iSmokerGrabVictim[iClient]))
				Infected_SmokerGrabVictim(iClient);
			
			ViewModel_SetAnimation(iClient, "ACT_VM_TONGUE");
		}
		case SmokerStatus_Grabbing:
		{
			if (!IsValidLivingSurvivor(g_iSmokerGrabVictim[iClient]))
			{
				// Lost a victim
				Infected_RetractSmokerBeam(iClient, SmokerStatus_Retract);
			}
			else
			{
				if (g_flSmokerGrabStart[iClient] + 2.0 <= GetGameTime())
					Infected_RetractSmokerBeam(iClient, SmokerStatus_Retract);
				else
					Infected_RetractSmokerBeam(iClient, SmokerStatus_Grabbing);	// Just to check if tongue speed need to be changed
				
				Infected_SmokerGrabVictim(iClient);
			}
			
			if (!Infected_DoBeamTrace(iClient))
				return;
			
			SDKCall_PlaySpecificSequence(iClient, "tongue_attack_drag_survivor_idle");
			ViewModel_SetAnimation(iClient, "ACT_VM_TONGUE");
		}
		case SmokerStatus_Retract:
		{
			if (DistanceFromEntities(g_iSmokerRopes[iClient][0], g_iSmokerRopes[iClient][1]) <= 20.0)
			{
				Infected_EndSmokerBeam(iClient);
				return;
			}
			
			if (!Infected_DoBeamTrace(iClient))
				return;
			
			Infected_RetractSmokerBeam(iClient, SmokerStatus_Retract);
			
			if (IsValidLivingSurvivor(g_iSmokerGrabVictim[iClient]))
				Infected_SmokerGrabVictim(iClient);
			
			SDKCall_PlaySpecificSequence(iClient, "tongue_attack_drag_survivor_idle");
			ViewModel_SetAnimation(iClient, "ACT_VM_TONGUE");
		}
	}
}

public Action Infected_OnSmokerDamage(int iClient, int &iAttacker, int &iInflicter, float &flDamage, int &iDamageType, int &iWeapon, float vecForce[3], float vecForcePos[3], int iDamageCustom)
{
	if (IsValidLivingSurvivor(iAttacker) && IsValidLivingSurvivor(g_iSmokerGrabVictim[iClient]))
	{
		// Lose the target when taking damage
		g_iSmokerGrabVictim[iClient] = 0;
		Infected_RetractSmokerBeam(iClient, SmokerStatus_Retract);
	}
	
	return Plugin_Continue;
}

void Infected_StartSmokerBeam(int iClient)
{
	g_nSmokerStatus[iClient] = SmokerStatus_Extend;
	g_iSmokerGrabVictim[iClient] = 0;
	
	SDKCall_PlaySpecificSequence(iClient, "tongue_attack_grab_survivor");
	SetEntityMoveType(iClient, MOVETYPE_NONE);
	TF2_AddCondition(iClient, TFCond_FreezeInput, TFCondDuration_Infinite);
	
	float vecOrigin[3], vecAngles[3];
	GetClientEyePosition(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngles);
	vecOrigin[2] += flSmokerZPosition;
	
	for (int i = 0; i < sizeof(g_iSmokerRopes[]); i++)
	{
		int iRope = CreateEntityByName("keyframe_rope");
		g_iSmokerRopes[iClient][i] = iRope;
		
		char sBuffer[32];
		Format(sBuffer, sizeof(sBuffer), "szf_rope_%d", iRope);
		SetEntPropString(iRope, Prop_Data, "m_iName", sBuffer);
		
		DispatchKeyValue(iRope, "RopeMaterial", "sprites/laserbeam.vmt");
		SetEntProp(iRope, Prop_Data, "m_spawnflags", 1);	// SF_ROPE_RESIZE
		
		TeleportEntity(iRope, vecOrigin);
	}
	
	int iRopeMove = g_iSmokerRopes[iClient][0];
	
	char sBuffer[32];
	Format(sBuffer, sizeof(sBuffer), "szf_rope_%d", g_iSmokerRopes[iClient][1]);
	SetEntPropString(iRopeMove, Prop_Data, "m_iNextLinkName", sBuffer);
	
	for (int i = 0; i < sizeof(g_iSmokerRopes[]); i++)
	{
		DispatchSpawn(g_iSmokerRopes[iClient][i]);
		ActivateEntity(g_iSmokerRopes[iClient][i]);
	}
	
	SetVariantString("self.SetMoveType(Constants.EMoveType.MOVETYPE_FLY, Constants.EMoveCollide.MOVECOLLIDE_FLY_CUSTOM)");
	AcceptEntityInput(iRopeMove, "RunScriptCode");
	
	float vecVelocity[3];
	AnglesToVelocity(vecAngles, vecVelocity, flSmokerSpeedFast);
	TeleportEntity(iRopeMove, _, _, vecVelocity);
	
	SDKHook(iRopeMove, SDKHook_Touch, Infected_OnSmokerTouch);
}

void Infected_RetractSmokerBeam(int iClient, SmokerStatus nStatus)
{
	g_nSmokerStatus[iClient] = nStatus;
	
	float vecOriginRope[3], vecOriginClient[3];
	GetEntPropVector(g_iSmokerRopes[iClient][0], Prop_Send, "m_vecOrigin", vecOriginRope);
	GetClientEyePosition(iClient, vecOriginClient);
	vecOriginClient[2] += flSmokerZPosition;
	
	float vecVelocity[3];
	float flSpeed;
	
	if (nStatus == SmokerStatus_Retract)
	{
		MakeVectorFromPoints(vecOriginRope, vecOriginClient, vecVelocity);
		flSpeed = flSmokerSpeedFast;	// WEEEEEEEE
	}
	else if (nStatus == SmokerStatus_Grabbing)
	{
		float vecOriginVictim[3];
		GetEntityCenterPoint(g_iSmokerGrabVictim[iClient], vecOriginVictim);
		float flGap = GetVectorDistance(vecOriginClient, vecOriginRope) - GetVectorDistance(vecOriginClient, vecOriginVictim);
		if (flGap > 10.0)
		{
			// Rope still got a bit of distance to catch up victim, aim tongue to inside victim's body
			MakeVectorFromPoints(vecOriginRope, vecOriginVictim, vecVelocity);
			flSpeed = flGap * 5.0;
		}
		else
		{
			MakeVectorFromPoints(vecOriginRope, vecOriginClient, vecVelocity);
			flSpeed = flSmokerSpeedSlow;
		}
	}
	
	NormalizeVector(vecVelocity, vecVelocity);
	ScaleVector(vecVelocity, flSpeed);
	TeleportEntity(g_iSmokerRopes[iClient][0], _, _, vecVelocity);
}

public void Infected_EndSmokerBeam(int iClient)
{
	if (IsValidLivingSurvivor(g_iSmokerGrabVictim[iClient]))
		TeleportEntity(g_iSmokerGrabVictim[iClient], NULL_VECTOR, NULL_VECTOR, {0.0, 0.0, 0.0});
	
	g_iSmokerGrabVictim[iClient] = 0;
	g_nSmokerStatus[iClient] = SmokerStatus_None;
	
	SetEntityMoveType(iClient, MOVETYPE_WALK);
	TF2_RemoveCondition(iClient, TFCond_FreezeInput);
	
	for (int i = 0; i < sizeof(g_iSmokerRopes[]); i++)
		if (g_iSmokerRopes[iClient][i] && IsValidEntity(g_iSmokerRopes[iClient][i]))	// variable can be 0 as its not initialized as -1
			RemoveEntity(g_iSmokerRopes[iClient][i]);
	
	ViewModel_SetAnimation(iClient, "ACT_VM_COUGH");
}

public Action Infected_OnSmokerTouch(int iRope, int iToucher)
{
	// Hit a wall or something, retract it
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		for (int i = 0; i < sizeof(g_iSmokerRopes[]); i++)
		{
			if (iRope != g_iSmokerRopes[iClient][i])
				continue;
			
			Infected_RetractSmokerBeam(iClient, SmokerStatus_Retract);
			return Plugin_Handled;
		}
	}
	
	// ermm...... weird situation, delete it
	RemoveEntity(iRope);
	return Plugin_Handled;
}

bool Infected_DoBeamTrace(int iClient)
{
	// Ensure one end of the beam is always at client
	float vecOrigin1[3], vecOrigin2[3];
	GetClientEyePosition(iClient, vecOrigin1);
	vecOrigin1[2] += flSmokerZPosition;
	TeleportEntity(g_iSmokerRopes[iClient][1], vecOrigin1);
	GetEntPropVector(g_iSmokerRopes[iClient][0], Prop_Send, "m_vecOrigin", vecOrigin2);
	
	Handle hTrace = TR_TraceRayFilterEx(vecOrigin1, vecOrigin2, MASK_PLAYERSOLID, RayType_EndPoint, Trace_DontHitTeammates, iClient);
	if (TR_DidHit(hTrace))
	{
		int iVictim = TR_GetEntityIndex(hTrace);
		if (IsValidLivingSurvivor(iVictim))
		{
			if (!g_iSmokerGrabVictim[iClient])
			{
				g_flSmokerGrabStart[iClient] = GetGameTime();
				g_iSmokerGrabVictim[iClient] = iVictim;
				Infected_RetractSmokerBeam(iClient, SmokerStatus_Grabbing);
			}
		}
		else
		{
			// Either something got in the way or we got teleported, try extract it
			if (g_nSmokerStatus[iClient] == SmokerStatus_Extend)
			{
				Infected_RetractSmokerBeam(iClient, SmokerStatus_Retract);
				delete hTrace;
				return false;
			}
			else
			{
				float vecVelocity[3];
				GetEntPropVector(g_iSmokerRopes[iClient][0], Prop_Data, "m_vecVelocity", vecVelocity);
				if (GetVectorLength(vecVelocity) < flSmokerSpeedFast * 0.8)
				{
					// Likely hit something and is in the way, end it
					Infected_EndSmokerBeam(iClient);
					delete hTrace;
					return false;
				}
			}
		}
	}
	
	delete hTrace;
	return true;
}

void Infected_SmokerGrabVictim(int iClient)
{
	int iVictim = g_iSmokerGrabVictim[iClient];
	
	//Calculate pull velocity towards Smoker
	float vecOriginVictim[3], vecOriginRopeStart[3], vecOriginRopeEnd[3];
	GetEntityCenterPoint(iVictim, vecOriginVictim);
	GetEntPropVector(g_iSmokerRopes[iClient][0], Prop_Send, "m_vecOrigin", vecOriginRopeStart);
	GetEntPropVector(g_iSmokerRopes[iClient][1], Prop_Send, "m_vecOrigin", vecOriginRopeEnd);
	
	float vecVelocity[3];
	MakeVectorFromPoints(vecOriginVictim, vecOriginRopeEnd, vecVelocity);
	NormalizeVector(vecVelocity, vecVelocity);
	
	if (g_nSmokerStatus[iClient] == SmokerStatus_Grabbing)
	{
		ScaleVector(vecVelocity, flSmokerSpeedSlow);
	}
	else if (g_nSmokerStatus[iClient] == SmokerStatus_Retract)
	{
		if (!TF2_IsPlayerInCondition(iVictim, TFCond_Dazed))
		{
			const float flDuration = 5.0;
			Stun_StartPlayer(iVictim, flDuration);
			TF2_StunPlayer(iVictim, flDuration, 0.2, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_SLOWDOWN, iClient);
		}
		
		float flDistance = GetVectorDistance(vecOriginVictim, vecOriginRopeStart);
		if (flDistance >= 250.0)
		{
			// Lost the victim, abort
			g_iSmokerGrabVictim[iClient] = 0;
			return;
		}
		
		// Add up amount of distance left to catch up from victim to tip of tongue
		ScaleVector(vecVelocity, flSmokerSpeedFast + flDistance);
		
		if (GetEntityFlags(iVictim) & FL_ONGROUND)
			vecVelocity[2] += 300.0;
		else
			vecVelocity[2] += 50.0;
	}
	
	TeleportEntity(iVictim, NULL_VECTOR, NULL_VECTOR, vecVelocity);
	TF2_AddCondition(iVictim, TFCond_LostFooting, 0.2);
	
	//Increase count and if it reaches a threshold, apply damage
	g_iSmokerBeamHits[iClient]++;
	if (g_iSmokerBeamHits[iClient] == 5)
	{
		DealDamage(iClient, iVictim, 2.0); //Do damage
		g_iSmokerBeamHits[iClient] = 0;
	}
	
	Shake(iVictim, 4.0, 0.2); //Shake effect
}

////////////////
// Spitter
////////////////

public void Infected_DoSpitterGas(int iClient)
{
	SDKCall_PlaySpecificSequence(iClient, "spitter_spitting");
	ViewModel_SetAnimation(iClient, "ACT_VM_VOMIT");
	
	TF2_AddCondition(iClient, TFCond_FreezeInput, 1.0);
	
	int iGas = TF2_GetItemInSlot(iClient, WeaponSlot_Secondary);
	if (iGas > MaxClients)
		SDKCall_TossJarThink(iGas);
}

public void Infected_OnSpitterDeath(int iVictim, int iKiller, int iAssist)
{
	int iGas = CreateEntityByName("tf_projectile_jar_gas");
	if (IsValidEntity(iGas))
	{
		SetEntPropEnt(iGas, Prop_Send, "m_hOwnerEntity", iVictim);
		SetEntProp(iGas, Prop_Send, "m_iTeamNum", GetClientTeam(iVictim));
		if (DispatchSpawn(iGas))
		{
			float vecOrigin[3], vecAngles[3];
			GetClientAbsOrigin(iVictim, vecOrigin);
			GetClientAbsAngles(iVictim, vecAngles);
			TeleportEntity(iGas, vecOrigin, vecAngles, NULL_VECTOR);
		}
	}
}

////////////////
// Jockey
////////////////

static bool g_bJockeyIsUsingPounce[MAXPLAYERS+1];
static int g_iJockeyTarget[MAXPLAYERS+1];

public void Infected_DoJockeyJump(int iClient)
{
	float vecVelocity[3];
	float vecEyeAngles[3];
	
	GetClientEyeAngles(iClient, vecEyeAngles);
	
	vecVelocity[0] = Cosine(DegToRad(vecEyeAngles[0])) * Cosine(DegToRad(vecEyeAngles[1])) * 690;
	vecVelocity[1] = Cosine(DegToRad(vecEyeAngles[0])) * Sine(DegToRad(vecEyeAngles[1])) * 690;
	vecVelocity[2] = 345.0;
	
	SDKCall_PlaySpecificSequence(iClient, "Pounce");
	ViewModel_SetAnimation(iClient, "ACT_VM_LUNGE");
	
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVelocity);
	SetEntProp(iClient, Prop_Send, "m_bJumping", true);
	
	int iFlags = GetEntityFlags(iClient);
	iFlags &= ~FL_ONGROUND;
	SetEntityFlags(iClient, iFlags);
	
	g_bJockeyIsUsingPounce[iClient] = true;
}

public void Infected_OnJockeyThink(int iClient, int &iButtons)
{
	if (GetEntityFlags(iClient) & FL_ONGROUND)
		g_bJockeyIsUsingPounce[iClient] = false;
	
	int iTarget = g_iJockeyTarget[iClient];
	if (0 < iTarget <= MaxClients)
	{
		if (IsValidLivingSurvivor(iTarget))
		{
			//Force jockey to crouch
			SetEntProp(iClient, Prop_Send, "m_bDucking", true);
			SetEntProp(iClient, Prop_Send, "m_bDucked", true);
			SetEntityFlags(iClient, GetEntityFlags(iClient)|FL_DUCKING);
			
			//Make target bleeed with jockey on their head
			if (!TF2_IsPlayerInCondition(iTarget, TFCond_Bleeding))
				TF2_MakeBleed(iTarget, iClient, 0.5);
			
			float flSpeed = GetEntPropFloat(iTarget, Prop_Send, "m_flMaxspeed");
			
			//Move target by 75% jockey and 25% themself
			float vecJockeyEye[3], vecTargetEye[3], vecJockeyVel[3], vecTargetVel[3], vecFinalVel[3];
			GetClientEyeAngles(iClient, vecJockeyEye);
			GetClientEyeAngles(iTarget, vecTargetEye);
			vecJockeyEye[2] = 0.0;
			vecTargetEye[2] = 0.0;
			AnglesToVelocity(vecJockeyEye, vecJockeyVel, flSpeed * g_cvJockeyMovementAttacker.FloatValue);
			AnglesToVelocity(vecTargetEye, vecTargetVel, flSpeed * g_cvJockeyMovementVictim.FloatValue);
			
			AddVectors(vecJockeyVel, vecTargetVel, vecFinalVel);
			TeleportEntity(iTarget, NULL_VECTOR, NULL_VECTOR, vecFinalVel);
			
			//Teleport jockey to target eye
			GetClientEyePosition(iTarget, vecTargetEye);
			TeleportEntity(iClient, vecTargetEye, NULL_VECTOR, vecFinalVel);
			
			return;
		}
		else
		{
			//Jockey target no longer valid
			g_iJockeyTarget[iClient] = 0;
			
			SetEntityMoveType(iClient, MOVETYPE_WALK);
			SetEntityCollisionGroup(iClient, COLLISION_GROUP_PLAYER);
		}
	}
}

public void Infected_OnJockeyTouch(int iClient, int iToucher)
{
	//Must not already be latched onto someone and be pouncing
	if (0 < g_iJockeyTarget[iClient] <= MaxClients || !g_bJockeyIsUsingPounce[iClient] || !IsValidLivingSurvivor(iToucher))
		return;
	
	//Jockey must be higher enough than survivor to pounce it
	float vecJockeyEye[3], vecTargetEye[3];
	GetClientEyePosition(iClient, vecJockeyEye);
	GetClientEyePosition(iToucher, vecTargetEye);
	
	if (vecJockeyEye[2] < vecTargetEye[2] + 20.0)
		return;
	
	g_bJockeyIsUsingPounce[iClient] = false;
	g_iJockeyTarget[iClient] = iToucher;
	Shake(iToucher, 3.0, 3.0);
	
	SetEntityMoveType(iClient, MOVETYPE_NONE);
	SetEntityCollisionGroup(iClient, COLLISION_GROUP_DEBRIS_TRIGGER);
	SDKCall_PlaySpecificSequence(iClient, "jockey_ride");
}

public void Infected_OnJockeyDeath(int iClient, int iKiller, int iAssist)
{
	g_bJockeyIsUsingPounce[iClient] = false;
	g_iJockeyTarget[iClient] = 0;
}