void Event_Init()
{
	HookEvent("teamplay_setup_finished", Event_SetupEnd);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("player_builtobject", Event_PlayerBuiltObject);
	HookEvent("teamplay_point_captured", Event_CPCapture);
	HookEvent("teamplay_point_startcapture", Event_CPCaptureStart);
	HookEvent("teamplay_broadcast_audio", Event_Broadcast, EventHookMode_Pre);
}

public Action Event_SetupEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	EndGracePeriod();
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	//Prepare for a completely new round, if
	//+ Round was a full round (full_round flag is set), OR
	//+ Zombies are the winning team.
	TFTeam nTeam = view_as<TFTeam>(event.GetInt("team"));
	g_bNewRound = event.GetBool("full_round") || (nTeam == TFTeam_Zombie);
	g_nRoundState = SZFRoundState_End;
	
	if (nTeam == TFTeam_Zombie)
		PlaySoundAll(SoundMusic_ZombieWin);
	else if (nTeam == TFTeam_Survivor)
		PlaySoundAll(SoundMusic_SurvivorWin);
	
	SetGlow();
	UpdateZombieDamageScale();
	g_bTankRefreshed = false;
	
	return Plugin_Continue;
}

public Action Event_PlayerInventoryUpdate(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return;
	
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	//Reset overlay
	ClientCommand(iClient, "r_screenoverlay\"\"");
	
	if (g_iMaxHealth[iClient] != -1)
	{
		//Make sure max health hook is reset properly
		g_iMaxHealth[iClient] = -1;
		TF2_RespawnPlayer2(iClient);
		return;
	}
	
	g_iSuperHealthSubtract[iClient] = 0;
	g_bHitOnce[iClient] = false;
	g_bHopperIsUsingPounce[iClient] = false;
	g_bBackstabbed[iClient] = false;
	g_iKillsThisLife[iClient] = 0;
	g_iDamageTakenLife[iClient] = 0;
	g_iDamageDealtLife[iClient] = 0;
	
	ResetClientState(iClient);
	DropCarryingItem(iClient, false);
	
	SetEntityRenderColor(iClient, 255, 255, 255, 255);
	SetEntityRenderMode(iClient, RENDER_NORMAL);
	
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	Infected nInfected = g_nInfected[iClient];
	
	//Figure out what special infected client is
	if (g_nRoundState == SZFRoundState_Active)
	{
		if (g_iZombieTank > 0 && g_iZombieTank == iClient)
		{
			g_iZombieTank = 0;
			nInfected = Infected_Tank;
		}
		else
		{
			//If client got a force set as specific special infected, set as that infected
			if (g_nNextInfected[iClient] != Infected_None)
			{
				nInfected = g_nNextInfected[iClient];
			}
			else if (g_bSpawnAsSpecialInfected[iClient] == true)
			{
				g_bSpawnAsSpecialInfected[iClient] = false;
				
				//Create list of all special infected to randomize, apart from tank and non-special infected
				int iLength = view_as<int>(Infected) - 2;
				Infected[] nSpecialInfected = new Infected[iLength];
				for (int i = 0; i < iLength; i++)
					nSpecialInfected[i] = view_as<Infected>(i + 2);
				
				//Randomize, sort list of special infected
				SortIntegers(view_as<int>(nSpecialInfected), iLength, Sort_Random);
				
				//Go through each special infected in the list and find the first one thats not in cooldown
				int i = 0;
				while (nInfected == Infected_None && i < iLength)
				{
					if (IsValidInfected(nSpecialInfected[i]) && g_flInfectedCooldown[nSpecialInfected[i]] <= GetGameTime() - 12.0 && g_iInfectedCooldown[nSpecialInfected[i]] != iClient)
					{
						//We found it, set as that special infected
						nInfected = nSpecialInfected[i];
					}
					
					i++;
				}
				
				//Check if player spawned using fast respawn
				if (g_bReplaceRageWithSpecialInfectedSpawn[iClient])
				{
					//Check if they did not become special infected because all is in cooldown
					if (g_nInfected[iClient] == Infected_None)
						CPrintToChat(iClient, "{red}All special infected seems to be in a cooldown...");
					
					g_bReplaceRageWithSpecialInfectedSpawn[iClient] = false;
				}
			}
		}
	}
	
	Classes_SetClient(iClient, nInfected);
	
	//Force respawn if client is playing as disallowed class
	if (IsSurvivor(iClient))
	{
		if (g_nRoundState == SZFRoundState_Active)
		{
			SpawnClient(iClient, TFTeam_Zombie);
			return;
		}
		
		if (!IsValidSurvivorClass(nClass))
		{
			TF2_RespawnPlayer2(iClient);
			return;
		}
		
		HandleSurvivorLoadout(iClient);
		if (GetCookie(iClient, g_cFirstTimeSurvivor) < 1)
			InitiateSurvivorTutorial(iClient);
	}
	else if (IsZombie(iClient))
	{
		if (g_nInfected[iClient] != Infected_None && nClass != GetInfectedClass(g_nInfected[iClient]))
		{
			TF2_SetPlayerClass(iClient, GetInfectedClass(g_nInfected[iClient]));
			TF2_RespawnPlayer(iClient);
			return;
		}
		
		if (!IsValidZombieClass(nClass))
		{
			TF2_RespawnPlayer2(iClient);
			return;
		}
		
		if (g_nRoundState == SZFRoundState_Active)
			if (g_nInfected[iClient] != Infected_Tank && !PerformFastRespawn(iClient))
				TF2_AddCondition(iClient, TFCond_Ubercharged, 2.0);
		
		HandleZombieLoadout(iClient);
		if (GetCookie(iClient, g_cFirstTimeZombie) < 1)
			InitiateZombieTutorial(iClient);
	}
	
	if (g_nRoundState == SZFRoundState_Active)
	{
		if (g_nInfected[iClient] == Infected_Tank)
		{
			//TAAAAANK
			g_flTankLifetime[iClient] = GetGameTime();
			
			int iSurvivors = GetSurvivorCount();
			int iHealth = g_cvTankHealth.IntValue * iSurvivors;
			
			if (iHealth < g_cvTankHealthMin.IntValue)
				iHealth = g_cvTankHealthMin.IntValue;
			
			if (iHealth > g_cvTankHealthMax.IntValue)
				iHealth = g_cvTankHealthMax.IntValue;
			
			g_iMaxHealth[iClient] = iHealth;
			SetEntityHealth(iClient, iHealth);
			
			int iSubtract = 0;
			if (g_cvTankTime.FloatValue > 0.0)
			{
				iSubtract = RoundFloat(float(iHealth) / g_cvTankTime.FloatValue);
				if (iSubtract < 3)
					iSubtract = 3;
			}
			
			g_iSuperHealthSubtract[iClient] = iSubtract;
			TF2_AddCondition(iClient, TFCond_Kritzkrieged, TFCondDuration_Infinite);
			
			EmitSoundToAll(g_sVoZombieTankOnFire[GetRandomInt(0, sizeof(g_sVoZombieTankOnFire)-1)]);
			
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
						data.WriteString("Do not let the Tank get close to you, his attacks are very lethal.");
						
						CreateDataTimer(4.5, Timer_DisplayTutorialMessage, data);
						data.WriteCell(i);
						data.WriteFloat(4.0);
						data.WriteString("Run and shoot the Tank, it will slow the Tank down and kill it.");
						
						SetCookie(i, 2, g_cFirstTimeSurvivor);
					}
					
					SetVariantString("TLK_MVM_TANK_CALLOUT");
					AcceptEntityInput(i, "SpeakResponseConcept");
					
					CPrintToChat(i, "{red}Incoming TAAAAANK!");
					
					if (GetCurrentSound(i) != SoundMusic_LastStand || !IsMusicOverrideOn()) //lms current sound check seems not to work, may need to check it later
						PlaySound(i, SoundMusic_Tank);	
				}
				
				g_flDamageDealtAgainstTank[i] = 0.0;
			}
			
			Forward_OnTankSpawn(iClient);
		}
		
		if (g_nInfected[iClient] != Infected_None)
		{
			SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
			SetEntityRenderColor(iClient, g_ClientClasses[iClient].iColor[0], g_ClientClasses[iClient].iColor[1], g_ClientClasses[iClient].iColor[2], g_ClientClasses[iClient].iColor[3]);
			
			if (g_ClientClasses[iClient].sMessage[0])
				CPrintToChat(iClient, g_ClientClasses[iClient].sMessage);
			
			if (g_nInfected[iClient] != Infected_Tank && g_iInfectedCooldown[g_nInfected[iClient]] != iClient)
			{
				//Set new cooldown
				g_flInfectedCooldown[g_nInfected[iClient]] = GetGameTime();	//time for cooldown
				g_iInfectedCooldown[g_nInfected[iClient]] = iClient;			//client to prevent abuse to cycle through any infected
			}
		}
		
		if (g_bShouldBacteriaPlay[iClient])
		{
			EmitSoundToClient(iClient, g_sSoundSpawnInfected[g_nInfected[iClient]]);
			
			for (int i = 1; i <= MaxClients; i++)
				if (IsValidSurvivor(i))
					EmitSoundToClient(i, g_sSoundSpawnInfected[g_nInfected[iClient]]);
			
			g_bShouldBacteriaPlay[iClient] = false;
		}
	}
	
	SetGlow();
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	int iKillers[2];
	int iVictim = GetClientOfUserId(event.GetInt("userid"));
	iKillers[0] = GetClientOfUserId(event.GetInt("attacker"));
	iKillers[1] = GetClientOfUserId(event.GetInt("assister"));
	bool bDeadRinger = event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER != 0;
	
	ClientCommand(iVictim, "r_screenoverlay\"\"");
	
	DropCarryingItem(iVictim);
	
	//Handle bonuses
	if (!bDeadRinger && IsValidZombie(iKillers[0]) && iKillers[0] != iVictim)
	{
		g_iKillsThisLife[iKillers[0]]++;
		
		//50%
		if (g_nNextInfected[iKillers[0]] == Infected_None && !GetRandomInt(0, 1) && g_nRoundState == SZFRoundState_Active)
			g_bSpawnAsSpecialInfected[iKillers[0]] = true;
		
		if (g_iKillsThisLife[iKillers[0]] == 3)
			TF2_AddCondition(iKillers[0], TFCond_DefenseBuffed, TFCondDuration_Infinite);
	}
	
	if (!bDeadRinger && IsValidZombie(iKillers[1]) && iKillers[1] != iVictim)
	{
		//20%
		if (g_nNextInfected[iVictim] == Infected_None && !GetRandomInt(0, 4) && g_nRoundState == SZFRoundState_Active)
			g_bSpawnAsSpecialInfected[iKillers[1]] = true;
	}
	
	if (iVictim != iKillers[0] && event.GetInt("weapon_def_index") == INDEX_FISTS && iKillers[0] == event.GetInt("inflictor_entindex"))
	{
		//Some custom special infected use fists, but kill icon reports it incorrectly
		//TODO fix buildings kill aswell, those dont have 'weapon_def_index'
		event.SetString("weapon_logclassname", "fists");
		event.SetString("weapon", "fists");
		event.SetInt("weaponid", TF_WEAPON_FISTS);
	}
	
	if (g_nInfected[iVictim] == Infected_Tank)
	{
		g_iDamageZombie[iVictim] = 0;
		
		int iWinner = 0;
		float flHighest = 0.0;
		
		for (int i = 0; i < sizeof(iKillers); i++)
		{
			SetVariantString("TLK_MVM_TANK_DEAD");
			AcceptEntityInput(iKillers[i], "SpeakResponseConcept");
		}
		
		EmitSoundToAll(g_sVoZombieTankDeath[GetRandomInt(0, sizeof(g_sVoZombieTankDeath)-1)]);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			//If current music is tank, end it
			if (GetCurrentSound(i) == SoundMusic_Tank)
				EndSound(i);
			
			if (IsValidLivingSurvivor(i))
			{
				if (flHighest < g_flDamageDealtAgainstTank[i])
				{
					flHighest = g_flDamageDealtAgainstTank[i];
					iWinner = i;
				}
				
				AddMorale(i, 20);
			}
		}
		
		if (flHighest > 0.0)
		{
			SetHudTextParams(-1.0, 0.3, 8.0, 200, 255, 200, 128, 1);
			
			for (int i = 1; i <= MaxClients; i++)
				if (IsValidClient(i))
					ShowHudText(i, 5, "The Tank '%N' has died\nMost damage: %N (%d)", iVictim, iWinner, RoundFloat(flHighest));
		}
		
		if (g_iDamageDealtLife[iVictim] <= 50 && g_iDamageTakenLife[iVictim] <= 150 && !g_bTankRefreshed)
		{
			g_bTankRefreshed = true;
			Classes_SetClient(iVictim, Infected_None);
			ZombieTank();
		}
		
		Forward_OnTankDeath(iVictim, iWinner, RoundFloat(flHighest));
	}
	
	g_iMaxHealth[iVictim] = -1;
	g_bShouldBacteriaPlay[iVictim] = true;
	g_bReplaceRageWithSpecialInfectedSpawn[iVictim] = false;
	
	Infected g_nInfectedIndex = g_nInfected[iVictim];
	
	//Handle zombie death logic, all round states.
	if (IsValidZombie(iVictim))
	{
		Infected_PlayerDeath(iVictim);
		Classes_SetClient(iVictim, Infected_None);
		
		//10%
		if (IsValidSurvivor(iKillers[0]) && !GetRandomInt(0, 9) && g_nRoundState == SZFRoundState_Active)
			g_bSpawnAsSpecialInfected[iVictim] = true;
		
		//Set special infected state
		if (g_nNextInfected[iVictim] != Infected_None)
		{
			if (iVictim != g_iZombieTank)
				Classes_SetClient(iVictim, g_nNextInfected[iVictim]);
			
			g_nNextInfected[iVictim] = Infected_None;
		}
		
		//Remove dropped ammopacks from zombies.
		int iEntity = -1;
		while ((iEntity = FindEntityByClassname(iEntity, "tf_ammo_pack")) != -1)
			if (GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iVictim)
				RemoveEntity(iEntity);
		
		//Zombie rage: instant respawn
		if (g_bZombieRage && g_nRoundState == SZFRoundState_Active)
		{
			float flTimer = 0.1;
			
			//Check if respawn stress reaches time limit, if so add cooldown/timer so we dont instant respawn too much zombies at once
			if (g_flRageRespawnStress > GetGameTime())
				flTimer += (g_flRageRespawnStress - GetGameTime()) * 1.2;
			
			g_flRageRespawnStress += 1.7;	//Add stress time 1.7 sec for every respawn zombies
			CreateTimer(flTimer, Timer_RespawnPlayer, iVictim);
		}
		
		//Check for spec bypass from AFK manager
		RequestFrame(Frame_CheckZombieBypass, iVictim);
	}
	
	//Instant respawn outside of the actual gameplay
	if (g_nRoundState != SZFRoundState_Active && g_nRoundState != SZFRoundState_End)
	{
		CreateTimer(0.1, Timer_RespawnPlayer, iVictim);
		return Plugin_Continue;
	}
	
	//Handle survivor death logic, active round only.
	if (IsValidSurvivor(iVictim) && !bDeadRinger)
	{
		//Black and white effect for death
		ClientCommand(iVictim, "r_screenoverlay\"debug/yuv\"");
		
		if (IsValidZombie(iKillers[0]))
		{
			g_flSurvivorsLastDeath = GetGameTime();
			g_iZombiesKilledSpree = max(RoundToNearest(float(g_iZombiesKilledSpree) / 2.0) - 8, 0);
			g_iSurvivorsKilledCounter++;
		}
		
		//reset backstab state
		g_bBackstabbed[iVictim] = false;
		
		//Set zombie time to iVictim as he started playing zombie
		g_flTimeStartAsZombie[iVictim] = GetGameTime();
		
		//Transfer player to zombie team.
		CreateTimer(6.0, Timer_Zombify, iVictim, TIMER_FLAG_NO_MAPCHANGE);
		//Check if he's the last
		CheckLastSurvivor(iVictim);
		
		PlaySound(iVictim, SoundEvent_Dead, 3.0);
	}
	
	//Handle zombie death logic, active round only.
	else if (IsValidZombie(iVictim))
	{
		if (IsValidSurvivor(iKillers[0]))
		{
			g_iZombiesKilledSpree++;
			g_iZombiesKilledCounter++;
			g_iZombiesKilledSurvivor[iKillers[0]]++;
		}
		
		for (int i = 0; i < 2; i++)
		{
			if (IsValidLivingClient(iKillers[i]))
			{
				//Handle ammo kill bonuses.
				TF2_AddAmmo(iKillers[i], WeaponSlot_Primary, g_ClientClasses[iKillers[i]].iAmmo);
				
				//Handle morale bonuses.
				//+ Each kill adds morale.
				
				//Player gets more morale if low morale instead of high morale
				//Player gets more morale if high zombies, but dont give too much morale if already at high
				
				int iMorale = GetMorale(iKillers[i]);
				
				if (iMorale < 0)
					iMorale = 0;
				else if (iMorale > 100)
					iMorale = 100;
				
				float flPercentage = (float(GetZombieCount()) / (float(GetZombieCount()) + float(GetSurvivorCount())));
				int iBase;
				float flMultiplier;
				
				//Roll to get starting morale adds
				if (i == 0)	//Main killer
				{
					if (g_nInfectedIndex == Infected_None)
						iBase = GetRandomInt(6, 9);
					else
						iBase = GetRandomInt(10, 13);
				}
				else	//Assist kill
				{
					if (g_nInfectedIndex == Infected_None)
						iBase = GetRandomInt(2, 5);
					else
						iBase = GetRandomInt(6, 9);
				}
				
				//  0 morale   0% zombies -> 1.0
				//  0 morale 100% zombies -> 2.0
				
				// 50 morale   0% zombies -> 0.5
				// 50 morale 100% zombies -> 1.0
				
				//100 morale   0% zombies -> 0.0
				//100 morale 100% zombies -> 0.0
				flMultiplier = (1.0 - (float(iMorale) / 100.0)) * (flPercentage * 2.0);
				
				//Multiply base roll by multiplier
				iBase = RoundToNearest(float(iBase) * flMultiplier);
				AddMorale(iKillers[i], iBase);
				
				//+ Each kill grants a small health bonus and increases current crit bonus.
				int iHealth = GetClientHealth(iKillers[i]);
				int iMaxHealth = SDKCall_GetMaxHealth(iKillers[i]);
				if (iHealth < iMaxHealth)
				{
					iHealth += iMorale * 2;
					iHealth = min(iHealth, iMaxHealth);
					//SetEntityHealth(iKillers[i], iHealth);
				}
			}
		}
	}
	
	SetGlow();
	
	return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	int iVictim = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	int iDamageAmount = event.GetInt("damageamount");
	
	if (IsValidClient(iVictim) && IsValidClient(iAttacker) && iAttacker != iVictim)
	{
		g_iDamageTakenLife[iVictim] += iDamageAmount;
		g_iDamageDealtLife[iAttacker] += iDamageAmount;
		
		if (IsValidZombie(iAttacker))
			g_iDamageZombie[iAttacker] += iDamageAmount;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerBuiltObject(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	int iEntity = event.GetInt("index");
	TFObjectType nObjectType = view_as<TFObjectType>(event.GetInt("object"));
	
	//1. Handle dispenser rules.
	//       Disable dispensers when they begin construction.
	//       Increase max health to 300 (default level 1 is 150).
	if (nObjectType == TFObject_Dispenser)
	{
		SetEntProp(iEntity, Prop_Send, "m_bDisabled", 1); //fuck you
		SetEntProp(iEntity, Prop_Send, "m_bCarried", 1); //die already
		SetEntProp(iEntity, Prop_Send, "m_iMaxHealth", 300);
		AcceptEntityInput(iEntity, "Disable"); //just stop doing that beam thing you cunt
	}
	
	return Plugin_Continue;
}

public Action Event_CPCapture(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iControlPoints <= 0) 
		return;
	
	int iCaptureIndex = event.GetInt("cp");
	if (iCaptureIndex < 0 || iCaptureIndex >= g_iControlPoints)
		return;
	
	for (int i = 0; i < g_iControlPoints; i++)
	{
		if (g_iControlPointsInfo[i][0] == iCaptureIndex)
			g_iControlPointsInfo[i][1] = 2;
	}
	
	//Control point capture: increase morale
	for (int iClient = 0; iClient < MaxClients; iClient++)
	{
		if (g_iCapturingPoint[iClient] == iCaptureIndex)
		{
			AddMorale(iClient, 20);
			g_iCapturingPoint[iClient] = -1;
		}
	}
	
	CheckRemainingCP();
}

public Action Event_CPCaptureStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iControlPoints <= 0)
		return;
	
	int iCaptureIndex = event.GetInt("cp");
	if (iCaptureIndex < 0 || iCaptureIndex >= g_iControlPoints)
		return;
	
	for (int i = 0; i < g_iControlPoints; i++)
		if (g_iControlPointsInfo[i][0] == iCaptureIndex)
			g_iControlPointsInfo[i][1] = 1;
	
	CheckRemainingCP();
}

public Action Event_Broadcast(Event event, const char[] name, bool dontBroadcast)
{
	char sSound[20];
	event.GetString("sound", sSound, sizeof(sSound));
	
	if (!strcmp(sSound, "Game.YourTeamWon", false) || !strcmp(sSound, "Game.YourTeamLost", false))
		return Plugin_Handled;
	
	return Plugin_Continue;
}