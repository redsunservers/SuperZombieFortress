enum struct Detour
{
	char sName[64];
	DynamicDetour hDetour;
	DHookCallback callbackPre;
	DHookCallback callbackPost;
}

static ArrayList g_aDHookDetours;

static DynamicHook g_hDHookGetCaptureValueForPlayer;
static DynamicHook g_hDHookTeamMayCapturePoint;
static DynamicHook g_hDHookSetWinningTeam;
static DynamicHook g_hDHookRoundRespawn;
static DynamicHook g_hDHookGiveNamedItem;
static DynamicHook g_hDHookRefillThink;
static DynamicHook g_hDHookDispenseAmmo;
static DynamicHook g_hDHookGetHealRate;
static DynamicHook g_hDHookSmack;

static TFTeam g_iOldClientTeam[MAXPLAYERS+1];
static float g_flLastDispenserUsed[MAXPLAYERS + 1];

static int g_iHookIdGiveNamedItem[MAXPLAYERS+1];

void DHook_Init(GameData hSZF)
{
	g_aDHookDetours = new ArrayList(sizeof(Detour));
	
	DHook_CreateDetour(hSZF, "CTFPlayer::TeamFortress_CalculateMaxSpeed", _, DHook_CalculateMaxSpeedPost);
	DHook_CreateDetour(hSZF, "CTFWeaponBaseMelee::DoSwingTraceInternal", DHook_DoSwingTraceInternalPre, DHook_DoSwingTraceInternalPost);
	
	g_hDHookGetCaptureValueForPlayer = DHook_CreateVirtual(hSZF, "CTeamplayRules::GetCaptureValueForPlayer");
	g_hDHookTeamMayCapturePoint = DHook_CreateVirtual(hSZF, "CTeamplayRules::TeamMayCapturePoint");
	g_hDHookSetWinningTeam = DHook_CreateVirtual(hSZF, "CTeamplayRules::SetWinningTeam");
	g_hDHookRoundRespawn = DHook_CreateVirtual(hSZF, "CTeamplayRoundBasedRules::RoundRespawn");
	g_hDHookGiveNamedItem = DHook_CreateVirtual(hSZF, "CTFPlayer::GiveNamedItem");
	g_hDHookRefillThink = DHook_CreateVirtual(hSZF, "CObjectDispenser::RefillThink");
	g_hDHookDispenseAmmo = DHook_CreateVirtual(hSZF, "CObjectDispenser::DispenseAmmo");
	g_hDHookGetHealRate = DHook_CreateVirtual(hSZF, "CObjectDispenser::GetHealRate");
	g_hDHookSmack = DHook_CreateVirtual(hSZF, "CTFWeaponBaseMelee::Smack");
}

static void DHook_CreateDetour(GameData hGameData, const char[] sName, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	Detour detour;
	detour.hDetour = DynamicDetour.FromConf(hGameData, sName);
	if (!detour.hDetour)
	{
		LogError("Failed to create detour: %s", sName);
	}
	else
	{
		strcopy(detour.sName, sizeof(detour.sName), sName);
		detour.callbackPre = callbackPre;
		detour.callbackPost = callbackPost;
		g_aDHookDetours.PushArray(detour);
	}
}

static DynamicHook DHook_CreateVirtual(GameData hGameData, const char[] sName)
{
	DynamicHook hHook = DynamicHook.FromConf(hGameData, sName);
	if (!hHook)
		LogError("Failed to create hook: %s", sName);
	
	return hHook;
}

void DHook_HookGiveNamedItem(int iClient)
{
	if (!g_bTF2Items)
		g_iHookIdGiveNamedItem[iClient] = g_hDHookGiveNamedItem.HookEntity(Hook_Pre, iClient, DHook_OnGiveNamedItemPre, DHook_OnGiveNamedItemRemoved);
}

void DHook_UnhookGiveNamedItem(int iClient)
{
	if (g_iHookIdGiveNamedItem[iClient])
	{
		DHookRemoveHookID(g_iHookIdGiveNamedItem[iClient]);
		g_iHookIdGiveNamedItem[iClient] = INVALID_HOOK_ID;	
	}
}

bool DHook_IsGiveNamedItemActive()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (g_iHookIdGiveNamedItem[iClient])
			return true;
	
	return false;
}

void DHook_OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrEqual(sClassname, "obj_dispenser"))
	{
		g_hDHookRefillThink.HookEntity(Hook_Pre, iEntity, DHook_RefillThinkPre);
		g_hDHookDispenseAmmo.HookEntity(Hook_Pre, iEntity, DHook_DispenseAmmoPre);
		g_hDHookDispenseAmmo.HookEntity(Hook_Post, iEntity, DHook_DispenseAmmoPost);
		g_hDHookGetHealRate.HookEntity(Hook_Post, iEntity, DHook_GetHealRatePost);
	}
}

void DHook_HookMelee(int iEntity)
{
	g_hDHookSmack.HookEntity(Hook_Pre, iEntity, DHook_SmackPre);
}

void DHook_Enable()
{
	int iLength = g_aDHookDetours.Length;
	for (int i = 0; i < iLength; i++)
	{
		Detour detour;
		g_aDHookDetours.GetArray(i, detour);
		
		if (detour.callbackPre != INVALID_FUNCTION)
			if (!detour.hDetour.Enable(Hook_Pre, detour.callbackPre))
				LogError("Failed to enable pre detour: %s", detour.sName);
		
		if (detour.callbackPost != INVALID_FUNCTION)
			if (!detour.hDetour.Enable(Hook_Post, detour.callbackPost))
				LogError("Failed to enable post detour: %s", detour.sName);
	}
	
	g_hDHookGetCaptureValueForPlayer.HookGamerules(Hook_Post, DHook_GetCaptureValueForPlayerPost);
	g_hDHookTeamMayCapturePoint.HookGamerules(Hook_Post, DHook_TeamMayCapturePointPost);
	g_hDHookSetWinningTeam.HookGamerules(Hook_Pre, DHook_SetWinningTeamPre);
	g_hDHookRoundRespawn.HookGamerules(Hook_Pre, DHook_RoundRespawnPre);
}

void DHook_Disable()
{
	int iLength = g_aDHookDetours.Length;
	for (int i = 0; i < iLength; i++)
	{
		Detour detour;
		g_aDHookDetours.GetArray(i, detour);
		
		if (detour.callbackPre != INVALID_FUNCTION)
			if (!detour.hDetour.Disable(Hook_Pre, detour.callbackPre))
				LogError("Failed to disable pre detour: %s", detour.sName);
		
		if (detour.callbackPost != INVALID_FUNCTION)
			if (!detour.hDetour.Disable(Hook_Post, detour.callbackPost))
				LogError("Failed to disable post detour: %s", detour.sName);
	}
}

public MRESReturn DHook_CalculateMaxSpeedPost(int iClient, DHookReturn hReturn)
{
	if (IsClientInGame(iClient) && IsPlayerAlive(iClient))
	{
		float flSpeed = hReturn.Value;
		if (flSpeed <= 1.0)
			return MRES_Ignored;
		
		flSpeed += g_ClientClasses[iClient].flSpeed;
		
		if (IsZombie(iClient))
		{
			if (g_nInfected[iClient] == Infected_None)
			{
				//Movement speed increase
				float flSpeedBonus = fMin(g_ClientClasses[iClient].flMaxHorde, g_ClientClasses[iClient].flHorde * g_iHorde[iClient]);
				
				if (TF2_IsPlayerInCondition(iClient, TFCond_TeleportedGlow))
					flSpeedBonus += 40.0; //Screamer effect
				
				if (GetClientHealth(iClient) > SDKCall_GetMaxHealth(iClient))
					flSpeedBonus += 20.0; //Has overheal due to normal rage
				
				if (g_bZombieRage && flSpeedBonus < 40.0)
					flSpeedBonus += 40.0; //Map-wide zombie enrage event, but don't stack too much from other bonus
				
				flSpeed += flSpeedBonus;
				
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
					//Tank: movement speed penalty based on damage taken and dealt
					case Infected_Tank:
					{
						//Reduce speed when tank deals damage to survivors 
						flSpeed -= fMin(70.0, (float(g_iDamageDealtLife[iClient]) / 10.0));
						
						//Reduce speed when tank takes damage from survivors 
						flSpeed -= fMin(100.0, (float(g_iDamageTakenLife[iClient]) / 10.0));
						
						if (TF2_IsPlayerInCondition(iClient, TFCond_Jarated))
							flSpeed -= 30.0; //Jarate'd by sniper
					}
					
					//Cloaked: super speed if cloaked
					case Infected_Stalker:
					{
						if (TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
							flSpeed += 200.0;
					}
				}
			}
		}
		else if (IsSurvivor(iClient))
		{
			//If under 50 health, tick away one speed per hp lost
			if (GetClientHealth(iClient) < 50)
				flSpeed -= 50.0 - float(GetClientHealth(iClient));
		}
		
		if (Stun_IsPlayerStunned(iClient))
		{
			flSpeed *= Stun_GetSpeedMulti(iClient);
			if (GetEntityFlags(iClient) & FL_ONGROUND)
			{
				float vecVelocity[3];
				GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vecVelocity);
				if (GetVectorLength(vecVelocity) > flSpeed)
				{
					NormalizeVector(vecVelocity, vecVelocity);
					ScaleVector(vecVelocity, flSpeed);
					TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVelocity);
				}
			}
		}
		
		if (flSpeed <= 1.0)	// Do not set speed to negative or you'll send em to the backrooms
			flSpeed = 1.0;
		
		hReturn.Value = flSpeed;
		return MRES_Override;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_DoSwingTraceInternalPre(int iMelee, DHookReturn hReturn, DHookParam hParams)
{
	if (!g_cvMeleeIgnoreTeammates.BoolValue)
		return MRES_Ignored;
	
	// Ignore weapons with "speed buff ally" attribute
	float flSpeedBuffAlly = 0.0;
	if (TF2_WeaponFindAttribute(iMelee, 251, flSpeedBuffAlly) && flSpeedBuffAlly)
		return MRES_Ignored;
	
	// Enable MvM for this function for melee trace hack
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
	
	int iOwner = GetEntPropEnt(iMelee, Prop_Send, "m_hOwnerEntity");
	TFTeam iOwnerTeam = TF2_GetClientTeam(iOwner);
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;
		
		// Save current team for later
		TFTeam iTeam = TF2_GetClientTeam(iClient);
		g_iOldClientTeam[iClient] = iTeam;
		
		// Melee trace ignores teammates for MvM invaders
		// Move teammates to the BLU team and enemies to the RED team
		SetEntProp(iClient, Prop_Data, "m_iTeamNum", iTeam == iOwnerTeam ? TFTeam_Blue : TFTeam_Red);
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_DoSwingTraceInternalPost(int iMelee, DHookReturn hReturn, DHookParam hParams)
{
	if (!g_cvMeleeIgnoreTeammates.BoolValue)
		return MRES_Ignored;
	
	// Ignore weapons with "speed buff ally" attribute
	float flSpeedBuffAlly = 0.0;
	if (TF2_WeaponFindAttribute(iMelee, 251, flSpeedBuffAlly) && flSpeedBuffAlly)
		return MRES_Ignored;
	
	// Disable MvM so there are no lingering effects
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;
		
		// Restore client's previous team
		SetEntProp(iClient, Prop_Data, "m_iTeamNum", g_iOldClientTeam[iClient]);
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_OnGiveNamedItemPre(int iClient, DHookReturn hReturn, DHookParam hParams)
{
	// Block if one of the pointers is null
	if (hParams.IsNull(1) || hParams.IsNull(3))
	{
		hReturn.Value = 0;
		return MRES_Supercede;
	}
	
	int iIndex = hParams.GetObjectVar(3, g_iOffsetItemDefinitionIndex, ObjectValueType_Int) & 0xFFFF;
	
	Action iAction = OnGiveNamedItem(iClient, iIndex);
	
	if (iAction == Plugin_Handled)
	{
		hReturn.Value = 0;
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

public MRESReturn DHook_RefillThinkPre(int iDispenser, DHookReturn hReturn, DHookParam hParams)
{
	if (view_as<TFTeam>(GetEntProp(iDispenser, Prop_Send, "m_iTeamNum")) == TFTeam_Survivor)
		return MRES_Supercede;
	
	return MRES_Ignored;
}

public MRESReturn DHook_DispenseAmmoPre(int iDispenser, DHookReturn hReturn, DHookParam hParams)
{
	int iClient = hParams.Get(1);
	if (!IsValidLivingSurvivor(iClient))
		return MRES_Ignored;
	
	if (g_flLastDispenserUsed[iClient] + g_cvDispenserAmmoCooldown.FloatValue <= GetGameTime())
	{
		SetEntProp(iDispenser, Prop_Send, "m_iAmmoMetal", 0);	// prevent giving engis metal, reverted back in post
		g_flLastDispenserUsed[iClient] = GetGameTime();
		return MRES_Ignored;
	}
	else
	{
		hReturn.Value = false;
		return MRES_Supercede;
	}
}

public MRESReturn DHook_DispenseAmmoPost(int iDispenser, DHookReturn hReturn, DHookParam hParams)
{
	int iClient = GetEntPropEnt(iDispenser, Prop_Send, "m_hBuilder");
	if (!IsValidLivingSurvivor(iClient))
		return MRES_Ignored;
	
	if (hReturn.Value)
		g_flDispenserUsage[iClient] -= 1.0 / g_cvDispenserAmmoMax.FloatValue;
	
	if (g_flDispenserUsage[iClient] > 0.0)
	{
		SetEntProp(iDispenser, Prop_Send, "m_iAmmoMetal", RoundToCeil(g_flDispenserUsage[iClient] * MINI_DISPENSER_MAX_METAL));
	}
	else
	{
		SetVariantInt(GetEntProp(iDispenser, Prop_Send, "m_iMaxHealth"));
		AcceptEntityInput(iDispenser, "RemoveHealth");
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_GetHealRatePost(int iDispenser, DHookReturn hReturn, DHookParam hParams)
{
	if (view_as<TFTeam>(GetEntProp(iDispenser, Prop_Send, "m_iTeamNum")) == TFTeam_Survivor)
	{
		float flValue = hReturn.Value;
		flValue *= g_cvDispenserHealRate.FloatValue;
		hReturn.Value = flValue;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_SmackPre(int iMelee)
{
	static bool bLoop;
	if (bLoop)
		return MRES_Ignored;
	
	bLoop = true;
	
	// Keep looping to see how many we'll hit until when we miss
	int iPrevSolid[MAXPLAYERS+1];
	
	// TODO fix boston basher
	
	do
	{
		g_iClientTakenDamage = 0;
		
		SDKCall_Smack(iMelee);
		
		if (!g_iClientTakenDamage)
			break;	// didn't hit anyone
		
		if (GetEntPropEnt(iMelee, Prop_Send, "m_hOwnerEntity") == g_iClientTakenDamage)
			break;	// Hit yourself, idiot (Boston Basher)
		
		// Prevent victim able to get hit again, to see who else is in the way
		iPrevSolid[g_iClientTakenDamage] = GetEntProp(g_iClientTakenDamage, Prop_Send, "m_nSolidType");
		SetEntProp(g_iClientTakenDamage, Prop_Send, "m_nSolidType", SOLID_NONE);
		
		g_flMeleeDmgMultiplier *= g_cvMeleeCleaveMultipler.FloatValue;
	}
	while (g_iClientTakenDamage);
	
	for (int i = 1; i <= MaxClients; i++)
		if (iPrevSolid[i])
			SetEntProp(i, Prop_Send, "m_nSolidType", iPrevSolid[i]);
	
	bLoop = false;
	g_flMeleeDmgMultiplier = 1.0;
	return MRES_Supercede;
}

public MRESReturn DHook_GetCaptureValueForPlayerPost(DHookReturn hReturn, DHookParam hParams)
{
	int iClient = hParams.Get(1);
	
	if (TF2_GetPlayerClass(iClient) == TFClass_Scout) //Reduce capture rate for scout
	{
		hReturn.Value--;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_TeamMayCapturePointPost(DHookReturn hReturn, DHookParam hParams)
{
	TFTeam nTeam = hParams.Get(1);
	if (nTeam != TFTeam_Zombie)
		return MRES_Ignored;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && g_nInfected[iClient] == Infected_Tank)
		{
			// Allow tank to "capture" CP, but really just blocking cap progress
			hReturn.Value = true;
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_SetWinningTeamPre(DHookParam hParams)
{
	hParams.Set(4, false);	// always return false to bSwitchTeams
	return MRES_ChangedOverride;
}

public MRESReturn DHook_RoundRespawnPre()
{
	if (g_nRoundState == SZFRoundState_Setup)
		return MRES_Ignored;
	
	DetermineControlPoints();
	
	g_bLastSurvivor = false;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_iDamageZombie[iClient] = 0;
		g_iKillsThisLife[iClient] = 0;
		g_bSpawnAsSpecialInfected[iClient] = false;
		g_nInfected[iClient] = Infected_None;
		g_nNextInfected[iClient] = Infected_None;
		g_iMaxHealth[iClient] = -1;
		g_flTimeStartAsZombie[iClient] = 0.0;
		g_flDamageDealtAgainstTank[iClient] = 0.0;
	}
	
	for (int i = 0; i < view_as<int>(Infected_Count); i++)
	{
		g_flInfectedCooldown[i] = 0.0;
		g_iInfectedCooldown[i] = 0;
	}
	
	g_nRoundState = SZFRoundState_Grace;
	g_iRoundPlayedCount++;
	
	CPrintToChatAll("%t", "Grace_Start", "{green}");
	
	//Assign players to zombie and survivor teams.
	int[] iClients = new int[MaxClients];
	int iLength = 0;
	int iSurvivorCount;
	
	//Find all active players.
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		Sound_EndAllMusic(iClient);
		
		if (IsClientInGame(iClient) && TF2_GetClientTeam(iClient) != TFTeam_Spectator)
		{
			// Add all unassigned and users already in team, unassigned users assumes to be put in zombie team later
			iClients[iLength] = iClient;
			iLength++;
		}
	}
	
	SortIntegers(iClients, iLength, Sort_Random);	//Randomize player list
	SortCustom1D(iClients, iLength, Sort_LastPlayedZombie);	//Order by round last played as zombie
	
	//Calculate team counts. At least one survivor must exist.
	iSurvivorCount = RoundToFloor(iLength * g_cvRatio.FloatValue);
	if (iSurvivorCount == 0 && iLength > 0)
		iSurvivorCount = 1;
	
	TFTeam[] nClientTeam = new TFTeam[MaxClients+1];
	
	//Check if we need to force players to survivor or zombie team
	for (int i = 0; i < iLength; i++)
	{
		int iClient = iClients[i];
		
		if (TF2_GetClientTeam(iClient) > TFTeam_Spectator)
		{
			Action action = Forward_ShouldStartZombie(iClient);
			
			if (action == Plugin_Handled || (g_iForceZombieStartTimestamp[iClient] > 0 && g_cvPunishAvoidingPlayers.BoolValue))
			{
				if (action != Plugin_Handled)
				{
					// If they attempted to skip playing as zombie last time, force them to be in the zombie team
					if (g_iForceZombieStartTimestamp[iClient] > g_iRoundTimestamp)
					{
						CPrintToChat(iClient, "%t", "Infected_ForceStart_LastRound", "{red}");
					}
					else
					{
						char sDuration[256];
						GetVaguePeriodOfTimeFromTimestamp(sDuration, sizeof(sDuration), g_iForceZombieStartTimestamp[iClient], iClient);
						
						CPrintToChat(iClient, "%t", "Infected_ForceStart", "{red}",  g_sForceZombieStartMapName[iClient], sDuration);
					}
					
					g_iForceZombieStartTimestamp[iClient] = 0;
					g_sForceZombieStartMapName[iClient] = "";
					
					g_cForceZombieStartTimestamp.Set(iClient, "0");
					g_cForceZombieStartMapName.Set(iClient, "");
				}
				
				//Zombie
				SpawnClient(iClient, TFTeam_Zombie, false);
				nClientTeam[iClient] = TFTeam_Zombie;
				g_flTimeStartAsZombie[iClient] = GetGameTime();
				SetClientStartedAsZombie(iClient);
			}
		}
	}
	
	//From SortIntegers, we set the rest to survivors, then zombies
	for (int i = 0; i < iLength; i++)
	{
		int iClient = iClients[i];
		
		//Check if they have not already been assigned
		if (TF2_GetClientTeam(iClient) > TFTeam_Spectator && !(nClientTeam[iClient] == TFTeam_Zombie) && !(nClientTeam[iClient] == TFTeam_Survivor))
		{
			if (iSurvivorCount > 0)
			{
				//Survivor
				SpawnClient(iClient, TFTeam_Survivor, false);
				nClientTeam[iClient] = TFTeam_Survivor;
				iSurvivorCount--;
			}
			else
			{
				//Zombie
				SpawnClient(iClient, TFTeam_Zombie, false);
				nClientTeam[iClient] = TFTeam_Zombie;
				g_flTimeStartAsZombie[iClient] = GetGameTime();
				SetClientStartedAsZombie(iClient);
			}
		}
	}
	
	//Reset counters
	g_flCapScale = -1.0;
	g_aSurvivorDeathTimes.Clear();
	g_iZombiesKilledSpree = 0;
	g_iTanksSpawned = 0;
	
	g_flTimeProgress = 0.0;
	g_hTimerProgress = null;
	
	g_iRoundTimestamp = GetTime();
	
	//Handle grace period timers.
	CreateTimer(0.5, Timer_GraceStartPost, TIMER_FLAG_NO_MAPCHANGE);
	
	SetGlow();
	UpdateZombieDamageScale();
	
	return MRES_Ignored;
}