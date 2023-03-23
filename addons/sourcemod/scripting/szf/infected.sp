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

static Handle g_hTimerTank[TF_MAXPLAYERS];
static float g_flTankLifetime[TF_MAXPLAYERS];
static int g_iTankHealthSubtract[TF_MAXPLAYERS];

public void Infected_OnTankSpawn(int iClient)
{
	if (g_flTankLifetime[iClient] < GetGameTime() - 0.5)	//Prevent multiple announces from spawnroom
	{
		//TAAAAANK
		CPrintToChatAll("%t", "Tank_Spawn", "{red}");
		Sound_PlayInfectedVoToAll(Infected_Tank, SoundVo_Fire);
		
		g_iTanksSpawned++;
	}
	
	g_hTimerTank[iClient] = CreateTimer(1.0, Infected_TankTimer, GetClientSerial(iClient), TIMER_REPEAT);
	g_flTankLifetime[iClient] = GetGameTime();
	
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

public Action Infected_OnTankAnim(int iClient, PlayerAnimEvent_t &nAnim, int &iData)
{
	if (nAnim == PLAYERANIMEVENT_SPAWN)
	{
		ViewModel_SetDefaultAnimation(iClient, "f_idle");
		ViewModel_SetAnimation(iClient, "f_draw");
	}
	else if (nAnim == PLAYERANIMEVENT_ATTACK_PRIMARY || nAnim == PLAYERANIMEVENT_ATTACK_SECONDARY || nAnim == PLAYERANIMEVENT_ATTACK_GRENADE)
	{
		//One of those anim always get played because of force crit, pick one of those at random
		//TODO check if all 3 anim exists
		
		switch (GetRandomInt(1, 3))
		{
			case 1: nAnim = PLAYERANIMEVENT_ATTACK_PRIMARY;
			case 2: nAnim = PLAYERANIMEVENT_ATTACK_SECONDARY;
			case 3: nAnim = PLAYERANIMEVENT_ATTACK_GRENADE;
		}
		
		ViewModel_SetAnimation(iClient, "f_swing_crit");
		return Plugin_Changed;
	}
	
	//TODO check death anim
	
	return Plugin_Continue;
}

public void Infected_OnTankTouch(int iClient, int iToucher)
{
	if (IsClassname(iToucher, "func_respawnroom"))
	{
		//Reset lifetime so tank don't drain it's health while in spawnroom
		if (!GetEntProp(iToucher, Prop_Data, "m_bDisabled") && GetEntProp(iToucher, Prop_Send, "m_iTeamNum") == GetClientTeam(iClient))
			g_flTankLifetime[iClient] = GetGameTime();
	}
}

public void Infected_OnTankDeath(int iVictim, int iKiller, int iAssist)
{
	g_hTimerTank[iVictim] = null;
	g_iDamageZombie[iVictim] = 0;
	
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
			//If current music is tank, end it
			if (Sound_IsCurrentMusic(i, "tank"))
				Sound_EndMusic(i);
			
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

public Action Infected_OnBoomerAnim(int iClient, PlayerAnimEvent_t &nAnim, int &iData)
{
	if (nAnim == PLAYERANIMEVENT_SPAWN)
	{
		ViewModel_SetDefaultAnimation(iClient, "f_idle");
		ViewModel_SetAnimation(iClient, "f_draw");
	}
	else if (nAnim == PLAYERANIMEVENT_ATTACK_PRIMARY || nAnim == PLAYERANIMEVENT_ATTACK_SECONDARY || nAnim == PLAYERANIMEVENT_ATTACK_GRENADE)
	{
		//One of those anim always get played because of no random crit, pick one of those at random
		//TODO check if all 3 anim exists, and swings with correct anim
		
		switch (GetRandomInt(1, 3))
		{
			case 1:
			{
				nAnim = PLAYERANIMEVENT_ATTACK_PRIMARY;
				ViewModel_SetAnimation(iClient, "f_swing_left");
			}
			case 2:
			{
				nAnim = PLAYERANIMEVENT_ATTACK_SECONDARY;
				ViewModel_SetAnimation(iClient, "f_swing_right");
			}
			case 3:
			{
				nAnim = PLAYERANIMEVENT_ATTACK_GRENADE;
				ViewModel_SetAnimation(iClient, "f_swing_crit");
			}
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
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

static float g_flChargerEndCharge[TF_MAXPLAYERS];
static bool g_bChargerHitSurvivor[TF_MAXPLAYERS][TF_MAXPLAYERS];

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

public Action Infected_OnChargerAnim(int iClient, PlayerAnimEvent_t &nAnim, int &iData)
{
	if (nAnim == PLAYERANIMEVENT_SPAWN)
	{
		ViewModel_SetDefaultAnimation(iClient, "b_idle");
		ViewModel_SetAnimation(iClient, "b_draw");
	}
	else if (nAnim == PLAYERANIMEVENT_ATTACK_PRIMARY || nAnim == PLAYERANIMEVENT_ATTACK_SECONDARY || nAnim == PLAYERANIMEVENT_ATTACK_GRENADE)
	{
		switch (GetRandomInt(1, 2))
		{
			case 1: ViewModel_SetAnimation(iClient, "b_swing_a");
			case 2: ViewModel_SetAnimation(iClient, "b_swing_b");
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
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

static bool g_bHunterIsUsingPounce[TF_MAXPLAYERS];

public void Infected_DoHunterJump(int iClient)
{
	float vecVelocity[3];
	float vecEyeAngles[3];
	
	GetClientEyeAngles(iClient, vecEyeAngles);
	
	vecVelocity[0] = Cosine(DegToRad(vecEyeAngles[0])) * Cosine(DegToRad(vecEyeAngles[1])) * 920;
	vecVelocity[1] = Cosine(DegToRad(vecEyeAngles[0])) * Sine(DegToRad(vecEyeAngles[1])) * 920;
	vecVelocity[2] = 460.0;
	
	SDKCall_PlaySpecificSequence(iClient, "pounce_idle_low");
	ViewModel_SetAnimation(iClient, "claw_lunge_layer");
	
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

public Action Infected_OnHunterAnim(int iClient, PlayerAnimEvent_t &nAnim, int &iData)
{
	if (nAnim == PLAYERANIMEVENT_SPAWN)
	{
		ViewModel_SetDefaultAnimation(iClient, "b_idle");
		ViewModel_SetAnimation(iClient, "b_draw");
	}
	else if (nAnim == PLAYERANIMEVENT_ATTACK_PRIMARY || nAnim == PLAYERANIMEVENT_ATTACK_SECONDARY || nAnim == PLAYERANIMEVENT_ATTACK_GRENADE)
	{
		switch (GetRandomInt(1, 3))
		{
			case 1: ViewModel_SetAnimation(iClient, "b_swing_a");
			case 2: ViewModel_SetAnimation(iClient, "b_swing_b");
			case 3: ViewModel_SetAnimation(iClient, "b_swing_c");
		}
	}
	
	return Plugin_Continue;
}

public void Infected_OnHunterTouch(int iClient, int iToucher)
{
	if (!g_bHunterIsUsingPounce[iClient] || !IsValidLivingSurvivor(iToucher))
		return;
	
	const float flDuration = 5.5;
	if (Stun_StartPlayer(iToucher, flDuration))
	{
		SetEntityHealth(iToucher, GetClientHealth(iToucher) - 20);
		SetNextAttack(iClient, GetGameTime() + 0.6);
		
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

static int g_iSmokerBeamHits[TF_MAXPLAYERS];
static int g_iSmokerBeamHitVictim[TF_MAXPLAYERS];

public void Infected_OnSmokerThink(int iClient, int &iButtons)
{
	if (iButtons & IN_ATTACK2 && (GetEntityFlags(iClient) & FL_ONGROUND == FL_ONGROUND))
	{
		if (GetEntityMoveType(iClient) == MOVETYPE_NONE)
			SDKCall_PlaySpecificSequence(iClient, "tongue_attack_grab_survivor");
		
		SetEntityMoveType(iClient, MOVETYPE_NONE);
		Infected_DoSmokerBeam(iClient);
	}
	else if (GetEntityMoveType(iClient) == MOVETYPE_NONE)
	{
		ViewModel_SetAnimation(iClient, "cough");
		
		g_iSmokerBeamHits[iClient] = 0;
		g_iSmokerBeamHitVictim[iClient] = 0;
		SetEntityMoveType(iClient, MOVETYPE_WALK);
	}
}

void Infected_DoSmokerBeam(int iClient)
{
	float vecOrigin[3], vecAngles[3], vecEndOrigin[3], vecHitPos[3];
	GetClientEyePosition(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngles);
	
	Handle hTrace = TR_TraceRayFilterEx(vecOrigin, vecAngles, MASK_ALL, RayType_Infinite, Trace_DontHitEntity, iClient);
	TR_GetEndPosition(vecEndOrigin, hTrace);
	
	//750 in L4D2, scaled to TF2 player hull sizing (32hu -> 48hu)
	if (GetVectorDistance(vecOrigin, vecEndOrigin) > 1150.0)
	{
		delete hTrace;
		SDKCall_PlaySpecificSequence(iClient, "tongue_attack_drag_survivor");
		return;
	}
	
	//Smoker's tongue beam
	//Beam that gets sent to all other clients
	TE_SetupBeamPoints(vecOrigin, vecEndOrigin, g_iSprite, 0, 0, 0, 0.08, 5.0, 5.0, 10, 0.0, { 64, 0, 0, 255 }, 0);
	int iTotal = 0;
	int[] iClients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && i != iClient)
			iClients[iTotal++] = i;
	
	TE_Send(iClients, iTotal);
	
	//Send a different beam to smoker
	float vecNewOrigin[3];
	vecNewOrigin[0] = vecOrigin[0];
	vecNewOrigin[1] = vecOrigin[1];
	vecNewOrigin[2] = vecOrigin[2] - 7.0;
	TE_SetupBeamPoints(vecNewOrigin, vecEndOrigin, g_iSprite, 0, 0, 0, 0.08, 2.0, 5.0, 10, 0.0, { 64, 0, 0, 255 }, 0);
	TE_SendToClient(iClient);
	
	int iHit = TR_GetEntityIndex(hTrace);
	
	if (TR_DidHit(hTrace) && IsValidLivingSurvivor(iHit) && !TF2_IsPlayerInCondition(iHit, TFCond_Dazed))
	{
		//Calculate pull velocity towards Smoker
		float vecVelocity[3];
		GetClientAbsOrigin(iHit, vecHitPos);
		MakeVectorFromPoints(vecOrigin, vecHitPos, vecVelocity);
		NormalizeVector(vecVelocity, vecVelocity);
		ScaleVector(vecVelocity, fMin(-450.0 + GetClientHealth(iHit), -10.0) );
		TeleportEntity(iHit, NULL_VECTOR, NULL_VECTOR, vecVelocity);
		
		//If target changed, change stored target AND reset beam hit count
		if (g_iSmokerBeamHitVictim[iClient] != iHit)
		{
			g_iSmokerBeamHitVictim[iClient] = iHit;
			g_iSmokerBeamHits[iClient] = 0;
			
			SDKCall_PlaySpecificSequence(iClient, "tongue_attack_drag_survivor_idle");
			ViewModel_SetAnimation(iClient, "tongue");
		}
		
		//Increase count and if it reaches a threshold, apply damage
		g_iSmokerBeamHits[iClient]++;
		if (g_iSmokerBeamHits[iClient] == 5)
		{
			DealDamage(iClient, iHit, 2.0); //Do damage
			g_iSmokerBeamHits[iClient] = 0;
		}
		
		Shake(iHit, 4.0, 0.2); //Shake effect
	}
	else if (g_iSmokerBeamHitVictim[iClient])
	{
		g_iSmokerBeamHitVictim[iClient] = 0;
		g_iSmokerBeamHits[iClient] = 0;
		
		SDKCall_PlaySpecificSequence(iClient, "tongue_attack_drag_survivor");
	}
	
	delete hTrace;
}

public Action Infected_OnSmokerAnim(int iClient, PlayerAnimEvent_t &nAnim, int &iData)
{
	if (nAnim == PLAYERANIMEVENT_SPAWN)
	{
		ViewModel_SetDefaultAnimation(iClient, "m_idle");
	}
	else if (nAnim == PLAYERANIMEVENT_ATTACK_PRIMARY || nAnim == PLAYERANIMEVENT_ATTACK_SECONDARY || nAnim == PLAYERANIMEVENT_ATTACK_GRENADE)
	{
		switch (GetRandomInt(1, 2))
		{
			case 1: ViewModel_SetAnimation(iClient, "m_swing_a");
			case 2: ViewModel_SetAnimation(iClient, "m_swing_b");
		}
	}
	
	return Plugin_Continue;
}

////////////////
// Spitter
////////////////

public void Infected_DoSpitterGas(int iClient)
{
	SDKCall_PlaySpecificSequence(iClient, "spitter_spitting");
	ViewModel_SetAnimation(iClient, "spit");
	
	TF2_AddCondition(iClient, TFCond_FreezeInput, 1.0);
	
	int iGas = TF2_GetItemInSlot(iClient, WeaponSlot_Secondary);
	if (iGas > MaxClients)
		SDKCall_TossJarThink(iGas);
}

public Action Infected_OnSpitterAnim(int iClient, PlayerAnimEvent_t &nAnim, int &iData)
{
	if (nAnim == PLAYERANIMEVENT_SPAWN)
	{
		ViewModel_SetDefaultAnimation(iClient, "fa_idle");
		ViewModel_SetAnimation(iClient, "fa_draw");
	}
	else if (nAnim == PLAYERANIMEVENT_ATTACK_PRIMARY || nAnim == PLAYERANIMEVENT_ATTACK_SECONDARY || nAnim == PLAYERANIMEVENT_ATTACK_GRENADE)
	{
		ViewModel_SetAnimation(iClient, "fa_swing_a");
	}
	
	return Plugin_Continue;
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

static bool g_bJockeyIsUsingPounce[TF_MAXPLAYERS];
static int g_iJockeyTarget[TF_MAXPLAYERS];

public void Infected_DoJockeyJump(int iClient)
{
	float vecVelocity[3];
	float vecEyeAngles[3];
	
	GetClientEyeAngles(iClient, vecEyeAngles);
	
	vecVelocity[0] = Cosine(DegToRad(vecEyeAngles[0])) * Cosine(DegToRad(vecEyeAngles[1])) * 690;
	vecVelocity[1] = Cosine(DegToRad(vecEyeAngles[0])) * Sine(DegToRad(vecEyeAngles[1])) * 690;
	vecVelocity[2] = 345.0;
	
	SDKCall_PlaySpecificSequence(iClient, "Pounce");
	ViewModel_SetAnimation(iClient, "lunge");
	
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
			SetEntProp(iClient, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
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
	SetEntProp(iClient, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
	SDKCall_PlaySpecificSequence(iClient, "jockey_ride");
}

public Action Infected_OnJockeyAnim(int iClient, PlayerAnimEvent_t &nAnim, int &iData)
{
	if (nAnim == PLAYERANIMEVENT_SPAWN)
	{
		ViewModel_SetDefaultAnimation(iClient, "s_idle");
		ViewModel_SetAnimation(iClient, "s_draw");
	}
	else if (nAnim == PLAYERANIMEVENT_ATTACK_PRIMARY || nAnim == PLAYERANIMEVENT_ATTACK_SECONDARY || nAnim == PLAYERANIMEVENT_ATTACK_GRENADE)
	{
		ViewModel_SetAnimation(iClient, "s_swing_a");
	}
	
	return Plugin_Continue;
}

public void Infected_OnJockeyDeath(int iClient, int iKiller, int iAssist)
{
	g_bJockeyIsUsingPounce[iClient] = false;
	g_iJockeyTarget[iClient] = 0;
}