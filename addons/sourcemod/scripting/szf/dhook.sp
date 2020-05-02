static Handle g_hDHookSetWinningTeam;
static Handle g_hDHookRoundRespawn;
static Handle g_hDHookGetMaxHealth;
static Handle g_hDHookShouldBallTouch;
static Handle g_hDHookGiveNamedItem;
static Handle g_hDHookDeactivate;

static int g_iHookIdGiveNamedItem[TF_MAXPLAYERS];

void DHook_Init(GameData hSDKHooks, GameData hSZF)
{
	int iOffset = hSDKHooks.GetOffset("GetMaxHealth");
	g_hDHookGetMaxHealth = DHookCreate(iOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity);
	if (g_hDHookGetMaxHealth == null)
		LogMessage("Failed to create hook: CTFPlayer::GetMaxHealth!");
	
	iOffset = hSZF.GetOffset("CTeamplayRoundBasedRules::SetWinningTeam");
	g_hDHookSetWinningTeam = DHookCreate(iOffset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore);
	if (g_hDHookSetWinningTeam == null)
	{
		LogMessage("Failed to create hook: CTeamplayRoundBasedRules::SetWinningTeam!");
	}
	else
	{
		DHookAddParam(g_hDHookSetWinningTeam, HookParamType_Int);	// team
		DHookAddParam(g_hDHookSetWinningTeam, HookParamType_Int);	// iWinReason
		DHookAddParam(g_hDHookSetWinningTeam, HookParamType_Bool);	// bForceMapReset
		DHookAddParam(g_hDHookSetWinningTeam, HookParamType_Bool);	// bSwitchTeams
		DHookAddParam(g_hDHookSetWinningTeam, HookParamType_Bool);	// bDontAddScore
		DHookAddParam(g_hDHookSetWinningTeam, HookParamType_Bool);	// bFinal
	}
	
	iOffset = hSZF.GetOffset("CTeamplayRoundBasedRules::RoundRespawn");
	g_hDHookRoundRespawn = DHookCreate(iOffset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore);
	if (g_hDHookRoundRespawn == null)
		LogMessage("Failed to create hook: CTeamplayRoundBasedRules::RoundRespawn!");
	
	iOffset = hSZF.GetOffset("CTFStunBall::ShouldBallTouch");
	g_hDHookShouldBallTouch = DHookCreate(iOffset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity);
	if (g_hDHookShouldBallTouch == null)
		LogMessage("Failed to create hook: CTFStunBall::ShouldBallTouch!");
	else
		DHookAddParam(g_hDHookShouldBallTouch, HookParamType_CBaseEntity);
	
	iOffset = hSZF.GetOffset("CTFPlayer::GiveNamedItem");
	g_hDHookGiveNamedItem = DHookCreate(iOffset, HookType_Entity, ReturnType_CBaseEntity, ThisPointer_CBaseEntity);
	if (g_hDHookGiveNamedItem == null)
	{
		LogMessage("Failed to create hook: CTFPlayer::GiveNamedItem!");
	}
	else
	{
		DHookAddParam(g_hDHookGiveNamedItem, HookParamType_CharPtr); //*szClassname
		DHookAddParam(g_hDHookGiveNamedItem, HookParamType_Int); //iSubType
		DHookAddParam(g_hDHookGiveNamedItem, HookParamType_ObjectPtr); //*cscript
		DHookAddParam(g_hDHookGiveNamedItem, HookParamType_Bool); //:b:
	}
	
	// Detour used to prevent a crash with "game_ui" entity
	// void CGameUI::Deactivate( CBaseEntity *pActivator )
	g_hDHookDeactivate = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	if (g_hDHookDeactivate == null)
	{
		LogMessage("Failed to create detour handle for CGameUI::Deactivate!");
	}
	else
	{
		if (!DHookSetFromConf(g_hDHookDeactivate, hSZF, SDKConf_Signature, "CGameUI::Deactivate"))
		{
			LogMessage("Failed to retrieve CGameUI::Deactivate address!");
			delete g_hDHookDeactivate;
		}
		else
		{
			DHookAddParam(g_hDHookDeactivate, HookParamType_Int); // CBaseEntity *pActivator
			
			if (!DHookEnableDetour(g_hDHookDeactivate, false, Detour_CGameUI_Deactivate))
			{
				LogMessage("Failed to enable CGameUI::Deactivate detour!");
				delete g_hDHookDeactivate;
			}
		}
	}
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

void DHook_HookClient(int iClient)
{
	DHookEntity(g_hDHookGetMaxHealth, false, iClient, _, DHook_GetMaxHealthPre);
}

void DHook_HookStunBall(int iStunBall)
{
	DHookEntity(g_hDHookShouldBallTouch, false, iStunBall, _, DHook_ShouldBallTouchPre);
}

void DHook_HookGamerules()
{
	DHookGamerules(g_hDHookSetWinningTeam, false, _, DHook_SetWinningTeamPre);
	DHookGamerules(g_hDHookRoundRespawn, false, _, DHook_RoundRespawnPre);
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
	
	int iIndex = DHookGetParamObjectPtrVar(hParams, 3, 4, ObjectValueType_Int) & 0xFFFF;
	
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

public MRESReturn DHook_GetMaxHealthPre(int iClient, Handle hReturn)
{
	if (g_iMaxHealth[iClient] > 0)
	{
		DHookSetReturn(hReturn, g_iMaxHealth[iClient]);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_ShouldBallTouchPre(int iEntity, Handle hReturn, Handle hParams)
{
	if (!g_bEnabled) return MRES_Ignored;
	
	int iToucher = DHookGetParam(hParams, 1);
	int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
	if (IsValidLivingSurvivor(iToucher) && IsValidZombie(iOwner))
	{
		SpitterGoo(iToucher, iOwner);
		AcceptEntityInput(iEntity, "kill");
		
		DHookSetReturn(hReturn, false);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_SetWinningTeamPre(Handle hParams)
{
	DHookSetParam(hParams, 4, false);	// always return false to bSwitchTeams
	return MRES_ChangedOverride;
}

public MRESReturn DHook_RoundRespawnPre()
{
	if (!g_bEnabled) return;
	if (g_nRoundState == SZFRoundState_Setup) return;
	
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
		g_iEyelanderHead[iClient] = 0;
		g_iMaxHealth[iClient] = -1;
		g_iSuperHealthSubtract[iClient] = 0;
		g_flTimeStartAsZombie[iClient] = 0.0;
	}
	
	for (int i = 0; i < view_as<int>(Infected); i++)
	{
		g_flInfectedCooldown[i] = 0.0;
		g_iInfectedCooldown[i] = 0;
	}
	
	g_iZombieTank = 0;
	RemoveAllGoo();
	
	g_nRoundState = SZFRoundState_Grace;
	
	CPrintToChatAll("{green}Grace period begun. Survivors can change classes.");
	
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
			EndSound(iClient);
			
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
					CPrintToChat(iClient, "{red}You have been forcibly set to infected team due to attempting to skip playing as a infected.");
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
	
	g_flTimeProgress = 0.0;
	g_hTimerProgress = null;
	
	//Handle grace period timers.
	CreateTimer(0.5, Timer_GraceStartPost, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(45.0, Timer_GraceEnd, TIMER_FLAG_NO_MAPCHANGE);
	
	SetGlow();
	UpdateZombieDamageScale();
}