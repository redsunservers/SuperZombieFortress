void Console_Init()
{
	AddCommandListener(Console_JoinTeam, "jointeam");
	AddCommandListener(Console_JoinTeam, "spectate");
	AddCommandListener(Console_JoinTeam, "autoteam");
	AddCommandListener(Console_JoinClass, "joinclass");
	AddCommandListener(Console_VoiceMenu, "voicemenu");
	AddCommandListener(Console_Build, "build");
}

public Action Console_JoinTeam(int iClient, const char[] sCommand, int iArgs)
{
	char sArg[32];
	char sSurTeam[16];
	char sZomTeam[16];
	char sZomVgui[16];
	
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 1 && StrEqual(sCommand, "jointeam", false))
		return Plugin_Handled;
	
	if (g_nRoundState < SZFRoundState_Grace)
		return Plugin_Continue;
	
	if (!IsClientInGame(iClient))
		return Plugin_Continue;
	
	//Get command/arg on which team player joined
	if (StrEqual(sCommand, "jointeam", false)) //This is done because "jointeam spectate" should take priority over "spectate"
		GetCmdArg(1, sArg, sizeof(sArg));
	else if (StrEqual(sCommand, "spectate", false))
		strcopy(sArg, sizeof(sArg), "spectate");	
	else if (StrEqual(sCommand, "autoteam", false))
		strcopy(sArg, sizeof(sArg), "autoteam");		
	
	//Check if client is trying to skip playing as zombie by joining spectator
	if (StrEqual(sArg, "spectate", false))
		CheckZombieBypass(iClient);
	
	//Assign team-specific strings
	if (TFTeam_Zombie == TFTeam_Blue)
	{
		sSurTeam = "red";
		sZomTeam = "blue";
		sZomVgui = "class_blue";
	}
	else
	{
		sSurTeam = "blue";
		sZomTeam = "red";
		sZomVgui = "class_red";
	}
	
	if (g_nRoundState == SZFRoundState_Grace)
	{
		TFTeam nTeam = TF2_GetClientTeam(iClient);
		
		//If a client tries to join the infected team or a random team during grace period...
		if (StrEqual(sArg, sZomTeam, false) || StrEqual(sArg, "auto", false) || StrEqual(sArg, "autoteam", false))
		{
			//...as survivor, don't let them.
			if (nTeam == TFTeam_Survivor)
			{
				CPrintToChat(iClient, "{red}You can not switch to the opposing team during grace period.");
				return Plugin_Handled;
			}
			
			//...as a spectator who didn't start as an infected, set them as infected after grace period ends, after warning them.
			if (nTeam <= TFTeam_Spectator && !g_bStartedAsZombie[iClient])
			{
				if (!g_bWaitingForTeamSwitch[iClient])
				{
					if (nTeam == TFTeam_Unassigned) //If they're unassigned, let them spectate for now.
						TF2_ChangeClientTeam(iClient, TFTeam_Spectator);
					
					CPrintToChat(iClient, "{red}You will join the Infected team when grace period ends.");
					g_bWaitingForTeamSwitch[iClient] = true;
				}
				
				return Plugin_Handled;
			}	
		}
		//If client tries to spectate during grace period, make them
		//not be booted into the infected team if they tried to join
		//it before.
		else if (StrEqual(sArg, "spectate", false))
		{
			if (nTeam <= TFTeam_Spectator && g_bWaitingForTeamSwitch[iClient])
			{
				CPrintToChat(iClient, "{green}You will no longer automatically join the Infected team when grace period ends.");
				g_bWaitingForTeamSwitch[iClient] = false;
			}
			
			return Plugin_Continue;
		}
		
		//If client tries to join the survivor team during grace period, 
		//deny and set them as infected instead.
		else if (StrEqual(sArg, sSurTeam, false))
		{
			if (nTeam <= TFTeam_Spectator && !g_bWaitingForTeamSwitch[iClient])
			{
				//However, if they started as infected, they can spawn as infected again, normally.
				if (g_bStartedAsZombie[iClient])
				{
					TF2_ChangeClientTeam(iClient, TFTeam_Zombie);
					ShowVGUIPanel(iClient, sZomVgui);
				}
				else
				{
					if (nTeam == TFTeam_Unassigned) //If they're unassigned, let them spectate for now.
						TF2_ChangeClientTeam(iClient, TFTeam_Spectator);
					
					CPrintToChat(iClient, "{red}Can not join the Survivor team at this time. You will join the Infected team when grace period ends.");
					g_bWaitingForTeamSwitch[iClient] = true;
				}
			}
			
			return Plugin_Handled;
		}
		//Prevent joining any other team.
		else
			return Plugin_Handled;
	}
	
	else if (g_nRoundState > SZFRoundState_Grace)
	{
		//If client tries to join the survivor team or a random team
		//during an active round, place them on the zombie
		//team and present them with the zombie class select screen.
		if (StrEqual(sArg, sSurTeam, false) || StrEqual(sArg, "auto", false))
		{
			TF2_ChangeClientTeam(iClient, TFTeam_Zombie);
			ShowVGUIPanel(iClient, sZomVgui);
			return Plugin_Handled;
		}
		//If client tries to join the zombie team or spectator
		//during an active round, let them do so.
		else if (StrEqual(sArg, sZomTeam, false) || StrEqual(sArg, "spectate", false))
			return Plugin_Continue;
		//Prevent joining any other team.
		else
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Console_JoinClass(int iClient, const char[] sCommand, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 1)
		return Plugin_Handled;
	
	char sArg[32], sMsg[256];
	GetCmdArg(1, sArg, sizeof(sArg));
	
	if (IsZombie(iClient))
	{
		//Check if the player selected a valid zombie class
		if (IsValidZombieClass(TF2_GetClass(sArg)))
			return Plugin_Continue;
		
		//It's invalid, then display which classes the player can choose
		for (int i = 1; i < view_as<int>(TFClassType); i++)
		{
			if (IsValidZombieClass(view_as<TFClassType>(i)))
			{
				//Place a comma before if it's not the first one
				if (strlen(sMsg))
					Format(sMsg, sizeof(sMsg), "%s,", sMsg);
				
				TF2_GetClassName(sArg, sizeof(sArg), i);
				Format(sMsg, sizeof(sMsg), "%s %s", sMsg, sArg);
			}
		}
		
		CPrintToChat(iClient, "{red}Valid zombies:%s.", sMsg);
		return Plugin_Continue;
	}
	else if (IsSurvivor(iClient))
	{
		//Prevent survivors from switching classes during the round.
		if (g_nRoundState == SZFRoundState_Active)
		{
			CPrintToChat(iClient, "{red}Survivors can't change classes during a round.");
			return Plugin_Handled;
		}
		
		//Check if the player selected a valid survivor class
		if (IsValidSurvivorClass(TF2_GetClass(sArg)))
			return Plugin_Continue;
		
		//It's invalid, then display which classes the player can choose
		for (int i = 1; i < view_as<int>(TFClassType); i++)
		{
			if (IsValidSurvivorClass(view_as<TFClassType>(i)))
			{
				//Place a comma before if it's not the first one
				if (strlen(sMsg))
					Format(sMsg, sizeof(sMsg), "%s,", sMsg);
				
				TF2_GetClassName(sArg, sizeof(sArg), i);
				Format(sMsg, sizeof(sMsg), "%s %s", sMsg, sArg);
			}
		}
		
		CPrintToChat(iClient, "{red}Valid survivors:%s.", sMsg);
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

public Action Console_VoiceMenu(int iClient, const char[] sCommand, int iArgs)
{
	if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Continue;
	
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 2)
		return Plugin_Handled;
	
	char sArg1[32];
	char sArg2[32];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	
	//Capture call for medic commands (represented by "voicemenu 0 0").
	//Activate zombie Rage ability (150% health), if possible. Rage
	//can't be activated below full health or if it's already active.
	//Rage recharges after 30 seconds.
	if (sArg1[0] == '0' && sArg2[0] == '0')
	{
		//If an item was succesfully grabbed
		if (AttemptGrabItem(iClient))
			return Plugin_Handled;
		
		if (IsSurvivor(iClient) && AttemptCarryItem(iClient))
			return Plugin_Handled;
		
		if (IsZombie(iClient) && !TF2_IsPlayerInCondition(iClient, TFCond_Taunting))
		{
			if (g_nRoundState == SZFRoundState_Active && g_bSpawnAsSpecialInfected[iClient] && g_bReplaceRageWithSpecialInfectedSpawn[iClient])
			{
				TF2_RespawnPlayer2(iClient);
				
				Forward_OnQuickSpawnAsSpecialInfected(iClient);
				
				//Broadcast to team
				char sName[255];
				char sMessage[255];
				GetClientName2(iClient, sName, sizeof(sName));
				
				Format(sMessage, sizeof(sMessage), "(TEAM) %s\x01 : I have used my {limegreen}quick respawn into special infected\x01!", sName);
				for (int i = 1; i <= MaxClients; i++)
					if (IsValidClient(i) && GetClientTeam(i) == GetClientTeam(iClient))
						CPrintToChatEx(i, iClient, sMessage);
			}
			else if (g_iRageTimer[iClient] == 0)
			{
				switch (g_nInfected[iClient])
				{
					case Infected_None:
					{
						g_iRageTimer[iClient] = 31;
						DoGenericRage(iClient);
						EmitSoundToAll(g_sVoZombieCommonRage[GetRandomInt(0, sizeof(g_sVoZombieCommonRage)-1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
					}
					case Infected_Boomer:
					{
						if (g_nRoundState == SZFRoundState_Active)
						{
							DoBoomerExplosion(iClient, 600.0);
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
						
						EmitSoundToAll(g_sVoZombieChargerCharge[GetRandomInt(0, sizeof(g_sVoZombieChargerCharge)-1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
					}
					case Infected_Kingpin:
					{
						g_iRageTimer[iClient] = 21;
						DoKingpinRage(iClient, 600.0);
						
						char sPath[64];
						Format(sPath, sizeof(sPath), "ambient/halloween/male_scream_%d.wav", GetRandomInt(15, 16));
						EmitSoundToAll(sPath, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
					}
					case Infected_Hunter:
					{
						g_iRageTimer[iClient] = 3;
						DoHunterJump(iClient);
						EmitSoundToAll(g_sVoZombieHunterLeap[GetRandomInt(0, sizeof(g_sVoZombieHunterLeap) - 1)], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
					}
				}
			}
			else
			{
				ClientCommand(iClient, "voicemenu 2 5");
				PrintHintText(iClient, "Can't Activate Rage!");
			}
			
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action Console_Build(int iClient, const char[] sCommand, int iArgs)
{
	if (!g_bEnabled || !iClient)
		return Plugin_Continue;
	
	//Get arguments
	char sObjectType[32];
	GetCmdArg(1, sObjectType, sizeof(sObjectType));
	TFObjectType nObjectType = view_as<TFObjectType>(StringToInt(sObjectType));
	
	//if not a sentry and is a zombie, then block building
	if (IsZombie(iClient) && nObjectType != TFObject_Sentry)
		return Plugin_Handled;
	
	//if not sentry or dispenser, then block building
	if (nObjectType != TFObject_Dispenser && nObjectType != TFObject_Sentry)
		return Plugin_Handled;
	
	return Plugin_Continue;
}