void Infected_DoRageAbility(int iClient)
{
	switch (g_nInfected[iClient])
	{
		case Infected_None:
		{
			g_iRageTimer[iClient] = 31;
			Infected_DoGenericRage(iClient);
			EmitSoundToAll(g_sVoZombieCommonRage[GetRandomInt(0, sizeof(g_sVoZombieCommonRage)-1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
		case Infected_Boomer:
		{
			if (g_nRoundState == SZFRoundState_Active)
			{
				Infected_DoBoomerExplosion(iClient, 600.0);
				EmitSoundToAll(g_sVoZombieBoomerExplode[GetRandomInt(0, sizeof(g_sVoZombieBoomerExplode)-1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
		}
		case Infected_Charger:
		{
			g_iRageTimer[iClient] = 16;
			TF2_AddCondition(iClient, TFCond_Charging, 1.65);
			
			//Can sometimes charge for 0.1 sec, add push force
			float vecVel[3], vecAngles[3];
			GetClientEyeAngles(iClient, vecAngles);
			vecVel[0] = 450.0 * Cosine(DegToRad(vecAngles[1]));
			vecVel[1] = 450.0 * Sine(DegToRad(vecAngles[1]));
			TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVel);
			SDKCall_PlaySpecificSequence(iClient, "Charger_Charge");
			
			EmitSoundToAll(g_sVoZombieChargerCharge[GetRandomInt(0, sizeof(g_sVoZombieChargerCharge)-1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
		case Infected_Kingpin:
		{
			g_iRageTimer[iClient] = 21;
			Infected_DoKingpinRage(iClient, 600.0);
			
			char sPath[64];
			Format(sPath, sizeof(sPath), "ambient/halloween/male_scream_%d.wav", GetRandomInt(15, 16));
			EmitSoundToAll(sPath, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
		case Infected_Hunter:
		{
			g_iRageTimer[iClient] = 3;
			Infected_DoHunterJump(iClient);
			EmitSoundToAll(g_sVoZombieHunterLeap[GetRandomInt(0, sizeof(g_sVoZombieHunterLeap) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
	}
}

void Infected_TimerMin(int iClient)
{
	//Tank
	if (g_nInfected[iClient] == Infected_Tank)
	{
		//Tank super health handler
		int iHealth = GetClientHealth(iClient);
		int iMaxHealth = SDKCall_GetMaxHealth(iClient);
		if (iHealth < iMaxHealth || g_flTankLifetime[iClient] < GetGameTime() - 15.0)
		{
			if (iHealth - g_iSuperHealthSubtract[iClient] > 0)
				SetEntityHealth(iClient, iHealth - g_iSuperHealthSubtract[iClient]);
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
	}
	
	//Kingpin
	if (g_nInfected[iClient] == Infected_Kingpin)
	{
		TF2_AddCondition(iClient, TFCond_TeleportedGlow, 1.5);
		
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
				{
					TF2_AddCondition(i, TFCond_TeleportedGlow, 1.5);
					g_iScreamerNearby[i] = true;
				}
				else
				{
					g_iScreamerNearby[i] = false;
				}
			}
		}
	}
	
	//Stalker
	if (g_nInfected[iClient] == Infected_Stalker)
	{
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
					bTooClose = true;
			}
		}
		
		if (!bTooClose && !TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
			TF2_AddCondition(iClient, TFCond_Cloaked, TFCondDuration_Infinite);
		else if (bTooClose && TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
			TF2_RemoveCondition(iClient, TFCond_Cloaked);
	}
}

void Infected_GameFrame(int iClient)
{
	if (g_nInfected[iClient] == Infected_Stalker)
		TF2_SetCloakMeter(iClient, 100.0);
	
	//Charger's charge
	if (g_nInfected[iClient] == Infected_Charger && TF2_IsPlayerInCondition(iClient, TFCond_Charging))
	{
		float vecPosClient[3];
		float vecPosCharger[3];
		float flDistance;
		GetClientEyePosition(iClient, vecPosCharger);
		
		for (int iVictim = 1; iVictim <= MaxClients; iVictim++)
		{
			if (IsClientInGame(iVictim) && IsPlayerAlive(iVictim) && IsSurvivor(iVictim))
			{
				GetClientEyePosition(iVictim, vecPosClient);
				flDistance = GetVectorDistance(vecPosCharger, vecPosClient);
				if (flDistance <= 95.0)
				{
					if (!g_bBackstabbed[iVictim])
					{
						SetBackstabState(iVictim, BACKSTABDURATION_FULL, 0.8);
						SetNextAttack(iClient, GetGameTime() + 0.6);
						
						TF2_MakeBleed(iVictim, iClient, 2.0);
						DealDamage(iClient, iVictim, 30.0);
						
						char sPath[PLATFORM_MAX_PATH];
						Format(sPath, sizeof(sPath), "weapons/demo_charge_hit_flesh_range1.wav", GetRandomInt(1, 3));
						EmitSoundToAll(sPath, iClient);
						
						Forward_OnChargerHit(iClient, iVictim);
					}
					
					TF2_RemoveCondition(iClient, TFCond_Charging);
					break; //Target found, break the loop.
				}
			}
		}
	}
	
	//Hopper's pounce
	if (IsValidLivingZombie(iClient) && g_nInfected[iClient] == Infected_Hunter && g_bHopperIsUsingPounce[iClient])
	{
		float vecPosClient[3];
		float flPosHopper[3];
		float flDistance;
		GetClientEyePosition(iClient, flPosHopper);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i))
			{
				GetClientEyePosition(i, vecPosClient);
				flDistance = GetVectorDistance(flPosHopper, vecPosClient);
				if (flDistance <= 90.0)
				{
					if (!g_bBackstabbed[i])
					{
						SetEntityHealth(i, GetClientHealth(i) - 20);
						
						SetBackstabState(i, BACKSTABDURATION_FULL, 1.0);
						SetNextAttack(iClient, GetGameTime() + 0.6);
						
						//Teleport hunter inside the target
						GetClientAbsOrigin(i, vecPosClient);
						TeleportEntity(iClient, vecPosClient, NULL_VECTOR, NULL_VECTOR);
						//Dont allow hunter to move during lock
						TF2_StunPlayer(iClient, BACKSTABDURATION_FULL, 1.0, TF_STUNFLAG_SLOWDOWN, 0);
						
						Forward_OnHunterHit(iClient, i);
					}
					
					g_iRageTimer[iClient] = 21;
					g_bHopperIsUsingPounce[iClient] = false;
					break; //Break the loop, since we found our target
				}
			}
		}
	}
}

void Infected_PlayerRunCmd(int iClient, int &iButtons)
{
	//Smoker
	if (g_nInfected[iClient] == Infected_Smoker)
	{
		if (iButtons & IN_ATTACK2 && (GetEntityFlags(iClient) & FL_ONGROUND == FL_ONGROUND))
		{
			SetEntityMoveType(iClient, MOVETYPE_NONE);
			Infected_DoSmokerBeam(iClient);
		}
		else if (GetEntityMoveType(iClient) == MOVETYPE_NONE)
		{
			g_iSmokerBeamHits[iClient] = 0;
			g_iSmokerBeamHitVictim[iClient] = 0;
			SetEntityMoveType(iClient, MOVETYPE_WALK);
		}
	}
	
	//Stalker
	if (g_nInfected[iClient] == Infected_Stalker)
	{
		//To prevent fuckery with cloaking
		if (iButtons & IN_ATTACK2)
			iButtons &= ~IN_ATTACK2;
	}
}

void Infected_PlayerDeath(int iVictim)
{
	//Boomer
	if (g_nInfected[iVictim] == Infected_Boomer)
		Infected_DoBoomerExplosion(iVictim, 400.0);
}

//-----------------------

void Infected_DoGenericRage(int iClient)
{
	int iHealth = GetClientHealth(iClient);
	SetEntityHealth(iClient, RoundToCeil(iHealth * 1.5));
	
	float vecClientPos[3];
	GetClientEyePosition(iClient, vecClientPos);
	vecClientPos[2] -= 60.0; //Wheel goes down or smth, so thats why i did that i guess
	
	ShowParticle("spell_cast_wheel_blue", 4.0, vecClientPos);
	PrintHintText(iClient, "Rage Activated!");
}

void Infected_DoBoomerExplosion(int iClient, float flRadius)
{
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
				PlaySound(i, SoundEvent_Jarate, flDuration);
				
				iClientsTemp[iCount] = i;
				iCount++;
			}
		}
	}
	
	int iClients[MAXPLAYERS];
	for (int i = 0; i < iCount; i++)
		iClients[i] = iClientsTemp[i];
	
	Forward_OnBoomerExplode(iClient, iClients, iCount);
	
	if (IsPlayerAlive(iClient))
		FakeClientCommandEx(iClient, "explode");
}

void Infected_DoKingpinRage(int iClient, float flRadius)
{
	float vecPosScreamer[3]; //Fun fact: this is based on l4d's scrapped "screamer" special infected, which "buffed" zombies with its presence
	float vecPosZombie[3];
	GetClientEyePosition(iClient, vecPosScreamer);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsZombie(i))
		{
			GetClientEyePosition(i, vecPosZombie);
			float flDistance = GetVectorDistance(vecPosScreamer, vecPosZombie);
			if (flDistance <= flRadius)
			{
				TF2_AddCondition(i, TFCond_DefenseBuffed, 7.0 - flDistance / 120.0);
				Shake(i, 3.0, 3.0);
			}
		}
	}
}

void Infected_DoHunterJump(int iClient)
{
	char sPath[64];
	Format(sPath, sizeof(sPath), "ambient/halloween/male_scream_%d.wav", GetRandomInt(18, 19));
	EmitSoundToAll(sPath, iClient, SNDLEVEL_AIRCRAFT);
	
	CreateTimer(0.3, Timer_SetHunterJump, iClient);
	
	float vecVelocity[3];
	float vecEyeAngles[3];
	
	GetClientEyeAngles(iClient, vecEyeAngles);
	
	vecVelocity[0] = Cosine(DegToRad(vecEyeAngles[0])) * Cosine(DegToRad(vecEyeAngles[1])) * 920;
	vecVelocity[1] = Cosine(DegToRad(vecEyeAngles[0])) * Sine(DegToRad(vecEyeAngles[1])) * 920;
	vecVelocity[2] = 460.0;
	
	SetEntProp(iClient, Prop_Send, "m_bJumping", true);
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVelocity);
	SDKCall_PlaySpecificSequence(iClient, "Jump_Float_melee");
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
		return;
	}
	
	//Smoker's tongue beam
	//Beam that gets sent to all other clients
	TE_SetupBeamPoints(vecOrigin, vecEndOrigin, g_iSprite, 0, 0, 0, 0.08, 5.0, 5.0, 10, 0.0, { 255, 255, 255, 255 }, 0);
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
	TE_SetupBeamPoints(vecNewOrigin, vecEndOrigin, g_iSprite, 0, 0, 0, 0.08, 2.0, 5.0, 10, 0.0, { 255, 255, 255, 255 }, 0);
	TE_SendToClient(iClient);
	
	int iHit = TR_GetEntityIndex(hTrace);
	
	if (TR_DidHit(hTrace) && IsValidLivingSurvivor(iHit) && !TF2_IsPlayerInCondition(iHit, TFCond_Dazed))
	{
		//Calculate pull velocity towards Smoker
		if (!g_bBackstabbed[iClient])
		{
			float vecVelocity[3];
			GetClientAbsOrigin(iHit, vecHitPos);
			MakeVectorFromPoints(vecOrigin, vecHitPos, vecVelocity);
			NormalizeVector(vecVelocity, vecVelocity);
			ScaleVector(vecVelocity, fMin(-450.0 + GetClientHealth(iHit), -10.0) );
			TeleportEntity(iHit, NULL_VECTOR, NULL_VECTOR, vecVelocity);
		}
		
		//If target changed, change stored target AND reset beam hit count
		if (g_iSmokerBeamHitVictim[iClient] != iHit)
		{
			g_iSmokerBeamHitVictim[iClient] = iHit;
			g_iSmokerBeamHits[iClient] = 0;
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
	
	delete hTrace;
}

public Action Timer_SetHunterJump(Handle timer, any iClient)
{
	if (IsValidLivingZombie(iClient))
		g_bHopperIsUsingPounce[iClient] = true;
	
	return Plugin_Continue;
}