static Handle g_hDHookSetWinningTeam;
static Handle g_hDHookRoundRespawn;
static Handle g_hDHookGiveNamedItem;

static int g_iOffsetItemDefinitionIndex;
static int g_iOffsetOuter;

static int g_iDHookCalculateMaxSpeedClient;

static int g_iHookIdGiveNamedItem[TF_MAXPLAYERS];

void DHook_Init(GameData hSZF)
{
	DHook_CreateDetour(hSZF, "CTFPlayer::DoAnimationEvent", DHook_DoAnimationEventPre, _);
	DHook_CreateDetour(hSZF, "CTFPlayerShared::DetermineDisguiseWeapon", DHook_DetermineDisguiseWeaponPre, _);
	
	DHook_CreateDetour(hSZF, "CGameUI::Deactivate", DHook_DeactivatePre, _);
	DHook_CreateDetour(hSZF, "CTFPlayer::TeamFortress_CalculateMaxSpeed", DHook_CalculateMaxSpeedPre, DHook_CalculateMaxSpeedPost);
	
	g_hDHookSetWinningTeam = DHook_CreateVirtual(hSZF, "CTeamplayRoundBasedRules::SetWinningTeam");
	g_hDHookRoundRespawn = DHook_CreateVirtual(hSZF, "CTeamplayRoundBasedRules::RoundRespawn");
	g_hDHookGiveNamedItem = DHook_CreateVirtual(hSZF, "CTFPlayer::GiveNamedItem");
	
	g_iOffsetItemDefinitionIndex = hSZF.GetOffset("CEconItemView::m_iItemDefinitionIndex");
	g_iOffsetOuter = hSZF.GetOffset("CTFPlayerShared::m_pOuter");
}

static void DHook_CreateDetour(GameData gamedata, const char[] name, DHookCallback preCallback = INVALID_FUNCTION, DHookCallback postCallback = INVALID_FUNCTION)
{
	Handle detour = DHookCreateFromConf(gamedata, name);
	if (!detour)
	{
		LogError("Failed to create detour: %s", name);
	}
	else
	{
		if (preCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour, false, preCallback))
				LogError("Failed to enable pre detour: %s", name);
		
		if (postCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour, true, postCallback))
				LogError("Failed to enable post detour: %s", name);
		
		delete detour;
	}
}

static Handle DHook_CreateVirtual(GameData hGameData, const char[] sName)
{
	Handle hHook = DHookCreateFromConf(hGameData, sName);
	if (!hHook)
		LogError("Failed to create hook: %s", sName);
	
	return hHook;
}

void DHook_HookGiveNamedItem(int iClient)
{
	if (!g_bTF2Items)
		g_iHookIdGiveNamedItem[iClient] = DHookEntity(g_hDHookGiveNamedItem, false, iClient, DHook_OnGiveNamedItemRemoved, DHook_OnGiveNamedItemPre);
}

void DHook_UnhookGiveNamedItem(int iClient)
{
	if (g_iHookIdGiveNamedItem[iClient])
	{
		DHookRemoveHookID(g_iHookIdGiveNamedItem[iClient]);
		g_iHookIdGiveNamedItem[iClient] = 0;	
	}
}

bool DHook_IsGiveNamedItemActive()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (g_iHookIdGiveNamedItem[iClient])
			return true;
	
	return false;
}

void DHook_HookGamerules()
{
	DHookGamerules(g_hDHookSetWinningTeam, false, _, DHook_SetWinningTeamPre);
	DHookGamerules(g_hDHookRoundRespawn, false, _, DHook_RoundRespawnPre);
}

public MRESReturn DHook_DoAnimationEventPre(int iClient, Handle hParams)
{
	if (g_ClientClasses[iClient].callback_anim != INVALID_FUNCTION)
	{
		PlayerAnimEvent_t nAnim = DHookGetParam(hParams, 1);
		int iData = DHookGetParam(hParams, 2);
		
		Call_StartFunction(null, g_ClientClasses[iClient].callback_anim);
		Call_PushCell(iClient);
		Call_PushCellRef(nAnim);
		Call_PushCellRef(iData);
		
		Action action;
		Call_Finish(action);
		
		if (action >= Plugin_Handled)
			return MRES_Supercede;
		
		if (action == Plugin_Changed)
		{
			DHookSetParam(hParams, 1, nAnim);
			DHookSetParam(hParams, 2, iData);
			return MRES_ChangedOverride;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_DetermineDisguiseWeaponPre(Address pPlayerShared, Handle hParams)
{
	if (!g_bEnabled)
		return MRES_Ignored;
	
	Address pAddress = view_as<Address>(LoadFromAddress(pPlayerShared + view_as<Address>(g_iOffsetOuter), NumberType_Int32));
	int iClient = SDKCall_GetBaseEntity(pAddress);
	
	int iTarget = GetEntProp(iClient, Prop_Send, "m_iDisguiseTargetIndex");
	if (0 < iTarget <= MaxClients && IsSurvivor(iClient))
	{
		//Set class and team to whoever target is, so voodoo souls and zombie weapons is shown
		SetEntProp(iClient, Prop_Send, "m_nDisguiseClass", TF2_GetPlayerClass(iTarget));
		SetEntProp(iClient, Prop_Send, "m_nDisguiseTeam", TF2_GetClientTeam(iTarget));
		
		//Zombies have rome vision, set rome model override to whatever custom model
		SetEntProp(iClient, Prop_Send, "m_nModelIndexOverrides", GetEntProp(iTarget, Prop_Send, "m_nModelIndex"), _, VISION_MODE_ROME);
	}
	
	//Never allow force primary
	DHookSetParam(hParams, 1, false);
	return MRES_ChangedOverride;
}

public MRESReturn DHook_DeactivatePre(int iThis, Handle hParams)
{
	if (!g_bEnabled)
		return MRES_Ignored;
	
	// Detour used to prevent a crash with "game_ui" entity
	// World entity 0 should always be valid
	// If not, then pass a resource entity like "tf_gamerules"
	int iEntity = 0;
	while ((iEntity = FindEntityByClassname(iEntity, "*")) != -1)
	{
		DHookSetParam(hParams, 1, GetEntityAddress(iEntity));
		return MRES_ChangedHandled;
	}
	return MRES_Ignored;
}

public MRESReturn DHook_CalculateMaxSpeedPre(Address pAddress, Handle hReturn, Handle hParams)
{
	g_iDHookCalculateMaxSpeedClient = SDKCall_GetBaseEntity(pAddress);
}

public MRESReturn DHook_CalculateMaxSpeedPost(Address pAddress, Handle hReturn, Handle hParams)
{
	int iClient = g_iDHookCalculateMaxSpeedClient;
	float flSpeed = DHookGetReturn(hReturn);
	
	if (IsPlayerAlive(iClient))
	{
		//Handle speed bonuses.
		if ((!TF2_IsPlayerInCondition(iClient, TFCond_Slowed) && !TF2_IsPlayerInCondition(iClient, TFCond_Dazed)) || g_bBackstabbed[iClient])
		{
			if (IsZombie(iClient))
			{
				if (g_nInfected[iClient] == Infected_None)
				{
					//Movement speed increase
					flSpeed += fMin(g_ClientClasses[iClient].flMaxSpree, g_ClientClasses[iClient].flSpree * g_iZombiesKilledSpree) + fMin(g_ClientClasses[iClient].flMaxHorde, g_ClientClasses[iClient].flHorde * g_iHorde[iClient]);
					
					if (g_bZombieRage)
						flSpeed += 40.0; //Map-wide zombie enrage event
					
					if (TF2_IsPlayerInCondition(iClient, TFCond_OnFire))
						flSpeed += 20.0; //On fire
					
					if (TF2_IsPlayerInCondition(iClient, TFCond_TeleportedGlow))
						flSpeed += 20.0; //Screamer effect
					
					if (GetClientHealth(iClient) > SDKCall_GetMaxHealth(iClient))
						flSpeed += 20.0; //Has overheal due to normal rage
					
					//Movement speed decrease
					if (TF2_IsPlayerInCondition(iClient, TFCond_Jarated))
						flSpeed -= 30.0; //Jarate'd by sniper
					
					if (GetClientHealth(iClient) < 50)
						flSpeed -= 50.0 - float(GetClientHealth(iClient)); //If under 50 health, tick away one speed per hp lost
				}
				else
				{
					switch (g_nInfected[iClient])
					{
						//Tank: movement speed bonus based on damage taken and ignite speed bonus
						case Infected_Tank:
						{
							//Reduce speed when tank deals damage to survivors 
							flSpeed -= fMin(70.0, (float(g_iDamageDealtLife[iClient]) / 10.0));
							
							//Reduce speed when tank takes damage from survivors 
							flSpeed -= fMin(100.0, (float(g_iDamageTakenLife[iClient]) / 10.0));
							
							if (TF2_IsPlayerInCondition(iClient, TFCond_OnFire))
								flSpeed += 40.0; //On fire
							
							if (TF2_IsPlayerInCondition(iClient, TFCond_Jarated))
								flSpeed -= 30.0; //Jarate'd by sniper
						}
						
						//Cloaked: super speed if cloaked
						case Infected_Stalker:
						{
							if (TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
								flSpeed += 80.0;
						}
					}
				}
			}
			else if (IsSurvivor(iClient))
			{
				//If under 50 health, tick away one speed per hp lost
				if (GetClientHealth(iClient) < 50)
					flSpeed -= 50.0 - float(GetClientHealth(iClient));
				
				if (g_bBackstabbed[iClient])
					flSpeed *= 0.66;
			}
		}
	}
	
	DHookSetReturn(hReturn, flSpeed);
	return MRES_Override;
}

public MRESReturn DHook_OnGiveNamedItemPre(int iClient, Handle hReturn, Handle hParams)
{
	// Block if one of the pointers is null
	if (DHookIsNullParam(hParams, 1) || DHookIsNullParam(hParams, 3))
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}
	
	char sClassname[256];
	DHookGetParamString(hParams, 1, sClassname, sizeof(sClassname));
	
	int iIndex = DHookGetParamObjectPtrVar(hParams, 3, g_iOffsetItemDefinitionIndex, ObjectValueType_Int) & 0xFFFF;
	
	Action iAction = OnGiveNamedItem(iClient, sClassname, iIndex);
	
	if (iAction == Plugin_Handled)
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public void DHook_OnGiveNamedItemRemoved(int iHookId)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_iHookIdGiveNamedItem[iClient] == iHookId)
		{
			g_iHookIdGiveNamedItem[iClient] = 0;
			return;
		}
	}
}

public MRESReturn DHook_SetWinningTeamPre(Handle hParams)
{
	DHookSetParam(hParams, 4, false);	// always return false to bSwitchTeams
	return MRES_ChangedOverride;
}

public MRESReturn DHook_RoundRespawnPre()
{
	if (!g_bEnabled)
		return;
	
	if (g_nRoundState == SZFRoundState_Setup)
		return;
	
	DetermineControlPoints();
	
	g_bLastSurvivor = false;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_iDamageZombie[iClient] = 0;
		g_iKillsThisLife[iClient] = 0;
		g_bSpawnAsSpecialInfected[iClient] = false;
		g_nInfected[iClient] = Infected_None;
		g_nNextInfected[iClient] = Infected_None;
		g_bReplaceRageWithSpecialInfectedSpawn[iClient] = false;
		g_iMaxHealth[iClient] = -1;
		g_flTimeStartAsZombie[iClient] = 0.0;
		g_flDamageDealtAgainstTank[iClient] = 0.0;
	}
	
	for (int i = 0; i < view_as<int>(Infected); i++)
	{
		g_flInfectedCooldown[i] = 0.0;
		g_iInfectedCooldown[i] = 0;
	}
	
	g_nRoundState = SZFRoundState_Grace;
	
	CPrintToChatAll("%t", "Grace_Start", "{green}");
	
	//Assign players to zombie and survivor teams.
	if (g_bNewRound)
	{
		int[] iClients = new int[MaxClients];
		int iLength = 0;
		int iSurvivorCount;
		
		//Find all active players.
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			g_iZombiesKilledSurvivor[iClient] = 0;
			Sound_EndMusic(iClient);
			
			if (IsClientInGame(iClient) && TF2_GetClientTeam(iClient) > TFTeam_Spectator)
			{
				iClients[iLength] = iClient;
				iLength++;
			}
		}
		
		//Randomize, sort players
		SortIntegers(iClients, iLength, Sort_Random);
		
		//Calculate team counts. At least one survivor must exist.
		iSurvivorCount = RoundToFloor(iLength * g_cvRatio.FloatValue);
		if (iSurvivorCount == 0 && iLength > 0)
			iSurvivorCount = 1;
		
		TFTeam[] nClientTeam = new TFTeam[MaxClients+1];
		g_iStartSurvivors = 0;
		
		//Check if we need to force players to survivor or zombie team
		for (int i = 0; i < iLength; i++)
		{
			int iClient = iClients[i];
			
			if (IsValidClient(iClient))
			{
				Action action = Forward_ShouldStartZombie(iClient);
				
				if (action == Plugin_Handled)
				{
					//Zombie
					SpawnClient(iClient, TFTeam_Zombie, false);
					nClientTeam[iClient] = TFTeam_Zombie;
					g_bStartedAsZombie[iClient] = true;
					g_flTimeStartAsZombie[iClient] = GetGameTime();
				}
				else if (g_bForceZombieStart[iClient] && !g_bFirstRound)
				{
					//If they attempted to skip playing as zombie last time, force him to be in zombie team
					CPrintToChat(iClient, "%t", "Infected_ForceStart", "{red}");
					g_bForceZombieStart[iClient] = false;
					SetClientCookie(iClient, g_cForceZombieStart, "0");
					
					//Zombie
					SpawnClient(iClient, TFTeam_Zombie, false);
					nClientTeam[iClient] = TFTeam_Zombie;
					g_bStartedAsZombie[iClient] = true;
					g_flTimeStartAsZombie[iClient] = GetGameTime();
				}
				else if (g_bStartedAsZombie[iClient])
				{
					//Players who started as zombie last time is forced to be survivors
					
					//Survivor
					SpawnClient(iClient, TFTeam_Survivor, false);
					nClientTeam[iClient] = TFTeam_Survivor;
					g_bStartedAsZombie[iClient] = false;
					g_iStartSurvivors++;
					iSurvivorCount--;
				}
			}
		}
		
		//From SortIntegers, we set the rest to survivors, then zombies
		for (int i = 0; i < iLength; i++)
		{
			int iClient = iClients[i];
			
			//Check if they have not already been assigned
			if (IsValidClient(iClient) && !(nClientTeam[iClient] == TFTeam_Zombie) && !(nClientTeam[iClient] == TFTeam_Survivor))
			{
				if (iSurvivorCount > 0)
				{
					//Survivor
					SpawnClient(iClient, TFTeam_Survivor, false);
					nClientTeam[iClient] = TFTeam_Survivor;
					g_bStartedAsZombie[iClient] = false;
					g_iStartSurvivors++;
					iSurvivorCount--;
				}
				else
				{
					//Zombie
					SpawnClient(iClient, TFTeam_Zombie, false);
					nClientTeam[iClient] = TFTeam_Zombie;
					g_bStartedAsZombie[iClient] = true;
					g_flTimeStartAsZombie[iClient] = GetGameTime();
				}
			}
		}
	}
	
	//Reset counters
	g_flCapScale = -1.0;
	g_flSurvivorsLastDeath = GetGameTime();
	g_iSurvivorsKilledCounter = 0;
	g_iZombiesKilledCounter = 0;
	g_iZombiesKilledSpree = 0;
	g_iTanksSpawned = 0;
	
	g_flTimeProgress = 0.0;
	g_hTimerProgress = null;
	
	//Handle grace period timers.
	CreateTimer(0.5, Timer_GraceStartPost, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(45.0, Timer_GraceEnd, TIMER_FLAG_NO_MAPCHANGE);
	
	SetGlow();
	UpdateZombieDamageScale();
}