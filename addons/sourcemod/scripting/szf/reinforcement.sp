#define REINFORCE_WARNING_TIME		20.0
#define REINFORCE_GROUP_DISTANCE	200.0
#define REINFORCE_POINTS_STARTING	10
#define REINFORCE_POINTS_KILL		2
#define REINFORCE_POINTS_ASSIST		1
#define REINFORCE_DAMAGE_PER_POINT	1000
#define REINFORCE_SOUND				"mvm/mvm_bought_in.wav"
#define REINFORCE_DUCK_VIEW			45.0
#define REINFORCE_ORDER_STEP		100000.0
#define REINFORCE_TRACE_PASSES		MAXPLAYERS
#define REINFORCE_IDLE_TIME			5.0
#define REINFORCE_IDLE_REPEAT		1.0
#define REINFORCE_IDLE_SOUND		"ui/system_message_alert.wav"
#define REINFORCE_IDLE_CHANNEL		SNDCHAN_USER_BASE

static const float g_vecReinforceHullMins[3] = {-24.0, -24.0, 0.0};
static const float g_vecReinforceHullMaxs[3] = {24.0, 24.0, 82.0};

static int g_iReinforcePoints[MAXPLAYERS + 1];
static int g_iReinforceDamage[MAXPLAYERS + 1];
static int g_iReinforceWave[MAXPLAYERS + 1];
static TFClassType g_nReinforceClass[MAXPLAYERS + 1];
static bool g_bReinforceSpawning[MAXPLAYERS + 1];
static bool g_bReinforceCrouch[MAXPLAYERS + 1];
static int g_iReinforceIdle[MAXPLAYERS + 1];
static int g_iReinforceArrivals;
static float g_vecReinforceSpot[MAXPLAYERS + 1][3];
static float g_vecReinforceAngles[MAXPLAYERS + 1][3];
static int g_iReinforceStartSurvivors;
static int g_iReinforceRound;
static int g_iReinforceLastWave;
static bool g_bReinforceTimerDone;
static StringMap g_mReinforceTriggersUsed;
static int g_iReinforceIgnore[MAXPLAYERS + 1];
static int g_iReinforceIgnoreCount;

void Reinforce_Init()
{
	AddCommandListener(Reinforce_OnCommand, "voicemenu");
	AddCommandListener(Reinforce_OnCommand, "taunt");
	AddCommandListener(Reinforce_OnCommand, "+taunt");
	AddCommandListener(Reinforce_OnCommand, "+inspect_server");
	AddCommandListener(Reinforce_OnCommand, "say");
	AddCommandListener(Reinforce_OnCommand, "say_team");
	AddCommandListener(Reinforce_OnCommand, "menuselect");
	AddCommandListener(Reinforce_OnCommand, "joinclass");
}

public Action Reinforce_OnCommand(int iClient, const char[] sCommand, int iArgs)
{
	if (0 < iClient <= MaxClients)
		g_iReinforceIdle[iClient] = 0;
	
	return Plugin_Continue;
}

void Reinforce_Precache()
{
	PrecacheSound(REINFORCE_SOUND);
	PrecacheSound(REINFORCE_IDLE_SOUND);
}

void Reinforce_ResetClient(int iClient)
{
	g_iReinforcePoints[iClient] = 0;
	g_iReinforceDamage[iClient] = 0;
	g_iReinforceWave[iClient] = 0;
	g_nReinforceClass[iClient] = TFClass_Unknown;
	g_bReinforceSpawning[iClient] = false;
	g_bReinforceCrouch[iClient] = false;
	g_iReinforceIdle[iClient] = 0;
}

void Reinforce_OnRoundActive()
{
	g_iReinforceRound++;
	g_bReinforceTimerDone = false;
	
	if (!g_mReinforceTriggersUsed)
		g_mReinforceTriggersUsed = new StringMap();
	else
		g_mReinforceTriggersUsed.Clear();
	
	g_iReinforceStartSurvivors = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_iReinforcePoints[iClient] = 0;
		g_iReinforceDamage[iClient] = 0;
		g_iReinforceWave[iClient] = 0;
		g_nReinforceClass[iClient] = TFClass_Unknown;
		
		if (IsValidSurvivor(iClient))
			g_iReinforceStartSurvivors++;
		else if (IsValidZombie(iClient))
			g_iReinforcePoints[iClient] = REINFORCE_POINTS_STARTING;
	}
}

void Reinforce_OnPlayerDeath(int iVictim, int iKiller, int iAssister, bool bDeadRinger)
{
	if (g_nRoundState != SZFRoundState_Active || bDeadRinger || !IsValidSurvivor(iVictim))
		return;
	
	if (IsValidZombie(iKiller))
		g_iReinforcePoints[iKiller] += REINFORCE_POINTS_KILL;
	
	if (IsValidZombie(iAssister) && iAssister != iKiller)
		g_iReinforcePoints[iAssister] += REINFORCE_POINTS_ASSIST;
}

void Reinforce_OnPlayerHurt(int iVictim, int iAttacker, int iDamage, int iDamageCustom)
{
	if (g_nRoundState != SZFRoundState_Active || iDamage <= 0 || !IsValidZombie(iAttacker) || !IsValidSurvivor(iVictim))
		return;
	
	if (g_nInfected[iAttacker] != Infected_None || !IsPlayerAlive(iAttacker) || iDamageCustom == TF_CUSTOM_BLEEDING)
		return;
	
	g_iReinforceDamage[iAttacker] += iDamage;
	while (g_iReinforceDamage[iAttacker] >= REINFORCE_DAMAGE_PER_POINT)
	{
		g_iReinforceDamage[iAttacker] -= REINFORCE_DAMAGE_PER_POINT;
		g_iReinforcePoints[iAttacker]++;
	}
}

void Reinforce_Update()
{
	if (g_nRoundState != SZFRoundState_Active || g_bReinforceTimerDone || !Reinforce_IsEnabled())
		return;
	
	float flTime = MapConfig_GetSetting(MapSetting_ReinforcementTime);
	if (flTime <= 0.0 || MapConfig_GetSetting(MapSetting_DisableReinforcementTimer) != 0.0)
		return;
	
	float flElapsed = GetGameTime() - g_flRoundStarted;
	if (flElapsed >= flTime)
	{
		g_bReinforceTimerDone = true;
		CPrintToChatDebug("Reinforcements (timer) skipped: %d of %d starting survivors alive", Reinforce_CountLivingSurvivors(), g_iReinforceStartSurvivors);
		return;
	}
	
	if (flElapsed < flTime - REINFORCE_WARNING_TIME || !Reinforce_IsThresholdMet() || !Reinforce_StartWave("timer"))
		return;
	
	g_bReinforceTimerDone = true;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidSurvivor(iClient))
			CPrintToChat(iClient, "%t", "Reinforce_Warning", "{limegreen}", "{lightsalmon}");
}

void Reinforce_OnRelayTrigger(const char[] sTargetName)
{
	if (sTargetName[0] && MapConfig_IsReinforcementTrigger("relay", sTargetName))
		Reinforce_OnMapTrigger("relay", sTargetName);
}

void Reinforce_OnPointCaptured(int iPointIndex, const char[] sPrintName, TFTeam nTeam)
{
	if (nTeam != TFTeam_Survivor)
		return;
	
	char sName[256];
	int iPoint = -1;
	while ((iPoint = FindEntityByClassname(iPoint, "team_control_point")) != -1)
	{
		if (GetEntProp(iPoint, Prop_Data, "m_iPointIndex") != iPointIndex)
			continue;
		
		GetEntPropString(iPoint, Prop_Data, "m_iszPrintName", sName, sizeof(sName));
		if (sPrintName[0] && !StrEqual(sName, sPrintName))
			continue;
		
		GetEntPropString(iPoint, Prop_Data, "m_iName", sName, sizeof(sName));
		if (sName[0] && MapConfig_IsReinforcementTrigger("capture", sName))
		{
			Reinforce_OnMapTrigger("capture", sName);
			return;
		}
	}
	
	if (sPrintName[0] && MapConfig_IsReinforcementTrigger("capture", sPrintName))
	{
		Reinforce_OnMapTrigger("capture", sPrintName);
		return;
	}
	
	IntToString(iPointIndex, sName, sizeof(sName));
	if (MapConfig_IsReinforcementTrigger("capture", sName))
		Reinforce_OnMapTrigger("capture", sName);
}

static void Reinforce_OnMapTrigger(const char[] sType, const char[] sName)
{
	if (g_nRoundState != SZFRoundState_Active || !g_mReinforceTriggersUsed)
		return;
	
	char sKey[300];
	Format(sKey, sizeof(sKey), "%s:%s", sType, sName);
	for (int i = 0; sKey[i]; i++)
		sKey[i] = CharToLower(sKey[i]);
	
	if (!Reinforce_IsEnabled())
	{
		CPrintToChatDebug("Reinforcements (%s) ignored: reinforcements are off for this map", sKey);
		return;
	}
	
	if (g_mReinforceTriggersUsed.ContainsKey(sKey))
		return;
	
	if (!Reinforce_IsThresholdMet())
	{
		CPrintToChatDebug("Reinforcements (%s) skipped: %d of %d starting survivors alive", sKey, Reinforce_CountLivingSurvivors(), g_iReinforceStartSurvivors);
		return;
	}
	
	if (Reinforce_StartWave(sKey))
		g_mReinforceTriggersUsed.SetValue(sKey, true);
}

static bool Reinforce_IsEnabled()
{
	return MapConfig_GetSetting(MapSetting_Reinforcements) != 0.0;
}

static bool Reinforce_IsThresholdMet()
{
	if (g_iReinforceStartSurvivors <= 0)
		return false;
	
	int iAlive = Reinforce_CountLivingSurvivors();
	return iAlive > 0 && float(iAlive) < float(g_iReinforceStartSurvivors) * MapConfig_GetSetting(MapSetting_ReinforcementThreshold) / 100.0;
}

static int Reinforce_CountLivingSurvivors()
{
	int iCount;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidLivingSurvivor(iClient))
			iCount++;
	
	return iCount;
}

static int Reinforce_GetCount()
{
	float flPercent = MapConfig_GetSetting(MapSetting_ReinforcementPercent);
	if (flPercent <= 0.0 || g_iReinforceStartSurvivors <= 0)
		return 0;
	
	int iCount = RoundToCeil(float(g_iReinforceStartSurvivors) * flPercent / 100.0 - 0.001);
	return iCount < 1 ? 1 : iCount;
}

static bool Reinforce_StartWave(const char[] sSource)
{
	int iWant = Reinforce_GetCount();
	if (iWant <= 0)
		return false;
	
	int iChosen[MAXPLAYERS];
	int iCount = Reinforce_PickPlayers(iWant, iChosen, 0);
	if (iCount <= 0)
	{
		CPrintToChatDebug("Reinforcements (%s): no zombie to send", sSource);
		return false;
	}
	
	int iWave = ++g_iReinforceLastWave;
	DataPack data;
	CreateDataTimer(REINFORCE_WARNING_TIME, Timer_ReinforceArrive, data, TIMER_FLAG_NO_MAPCHANGE);
	data.WriteCell(g_iReinforceRound);
	data.WriteCell(iWave);
	data.WriteCell(iWant);
	data.WriteString(sSource);
	data.WriteCell(iCount);
	
	for (int i = 0; i < iCount; i++)
	{
		int iClient = iChosen[i];
		g_iReinforceWave[iClient] = iWave;
		g_nReinforceClass[iClient] = TFClass_Unknown;
		data.WriteCell(GetClientUserId(iClient));
		CPrintToChat(iClient, "%t", "Reinforce_Chosen", "{limegreen}", "{lightsalmon}", RoundToNearest(REINFORCE_WARNING_TIME));
	}
	
	CPrintToChatDebug("Reinforcements (%s): %d picked (%d wanted), arriving in %.0f s", sSource, iCount, iWant, REINFORCE_WARNING_TIME);
	return true;
}

public Action Timer_ReinforceArrive(Handle hTimer, DataPack data)
{
	data.Reset();
	int iRound = data.ReadCell();
	int iWave = data.ReadCell();
	int iWant = data.ReadCell();
	char sSource[300];
	data.ReadString(sSource, sizeof(sSource));
	int iPicked = data.ReadCell();
	
	int iChosen[MAXPLAYERS];
	int iCount;
	for (int i = 0; i < iPicked; i++)
	{
		int iClient = GetClientOfUserId(data.ReadCell());
		if (!iClient || g_iReinforceWave[iClient] != iWave)
			continue;
		
		g_iReinforceWave[iClient] = 0;
		if (Reinforce_CanBePicked(iClient))
			iChosen[iCount++] = iClient;
		else
			g_nReinforceClass[iClient] = TFClass_Unknown;
	}
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (g_iReinforceWave[iClient] == iWave)
			g_iReinforceWave[iClient] = 0;
	
	if (g_bEnabled && g_nRoundState == SZFRoundState_Active && iRound == g_iReinforceRound)
		Reinforce_Send(sSource, iWant, iPicked, iChosen, iCount);
	else
		Reinforce_ForgetClasses(iChosen, 0, iCount);
	
	return Plugin_Stop;
}

static void Reinforce_Send(const char[] sSource, int iWant, int iPicked, int[] iChosen, int iCount)
{
	int iGroup[MAXPLAYERS];
	int iGroupCount = Reinforce_GetBiggestGroup(iGroup);
	if (iGroupCount <= 0)
	{
		Reinforce_ForgetClasses(iChosen, 0, iCount);
		return;
	}
	
	int iMax = Reinforce_GetMaxCount();
	if (iMax < 0)
		iMax = 0;
	
	if (iCount > iMax)
	{
		Reinforce_ForgetClasses(iChosen, iMax, iCount);
		iCount = iMax;
	}
	
	if (iCount < iPicked)
		iCount = Reinforce_PickPlayers(iPicked, iChosen, iCount);
	
	if (iCount <= 0)
	{
		CPrintToChatDebug("Reinforcements (%s): no zombie to send", sSource);
		return;
	}
	
	Reinforce_AssignSpots(iGroup, iGroupCount, iChosen, iCount);
	
	for (int i = 0; i < iCount; i++)
	{
		int iClient = iChosen[i];
		g_iReinforcePoints[iClient] = 0;
		g_iReinforceDamage[iClient] = 0;
		
		g_nInfected[iClient] = Infected_None;
		g_nNextInfected[iClient] = Infected_None;
		Respawn_ClientDisconnect(iClient);
		g_flTimeStartAsZombie[iClient] = 0.0;
		
		TFClassType nClass = g_nReinforceClass[iClient];
		g_nReinforceClass[iClient] = TFClass_Unknown;
		if (nClass != TFClass_Unknown && IsValidSurvivorClass(nClass))
			TF2_SetPlayerClass(iClient, nClass);
		
		g_bReinforceSpawning[iClient] = true;
		SpawnClient(iClient, TFTeam_Survivor);
		g_bReinforceSpawning[iClient] = false;
	}
	
	CPrintToChatAll("%t", "Reinforce_Arrived", "{limegreen}", "{lightsalmon}");
	EmitSoundToAll(REINFORCE_SOUND);
	
	LastStand_EndLeft4Dead();
	
	CPrintToChatDebug("Reinforcements (%s): %d sent (%d wanted), %d of %d starting survivors were alive, group of %d", sSource, iCount, iWant, Reinforce_CountLivingSurvivors() - iCount, g_iReinforceStartSurvivors, iGroupCount);
}

bool Reinforce_IsSpawning(int iClient)
{
	return g_bReinforceSpawning[iClient];
}

bool Reinforce_IsPending(int iClient)
{
	return g_iReinforceWave[iClient] != 0 && g_nRoundState == SZFRoundState_Active;
}

static void Reinforce_ForgetClasses(const int[] iChosen, int iFrom, int iTo)
{
	for (int i = iFrom; i < iTo; i++)
		g_nReinforceClass[iChosen[i]] = TFClass_Unknown;
}

bool Reinforce_OnJoinClass(int iClient, const char[] sClass)
{
	if (!Reinforce_IsPending(iClient))
		return false;
	
	TFClassType nClass = TF2_GetClass(sClass);
	if (nClass == TFClass_Unknown && StrEqual(sClass, "random", false))
		nClass = GetRandomSurvivorClass();
	
	char sName[32];
	if (nClass == TFClass_Unknown || !IsValidSurvivorClass(nClass))
	{
		char sMsg[256];
		for (int i = 1; i <= view_as<int>(TFClass_Engineer); i++)
		{
			if (!IsValidSurvivorClass(view_as<TFClassType>(i)))
				continue;
			
			if (sMsg[0])
				StrCat(sMsg, sizeof(sMsg), ",");
			
			TF2_GetClassName(sName, sizeof(sName), i);
			Format(sMsg, sizeof(sMsg), "%s %s", sMsg, sName);
		}
		
		CPrintToChat(iClient, "%t", "JoinClass_ValidSurvivors", "{red}", sMsg);
		return true;
	}
	
	g_nReinforceClass[iClient] = nClass;
	TF2_GetClassName(sName, sizeof(sName), view_as<int>(nClass));
	CPrintToChat(iClient, "%t", "Reinforce_ClassPicked", "{limegreen}", "{lightsalmon}", sName);
	return true;
}

void Reinforce_OnSurvivorSpawn(int iClient)
{
	if (!g_bReinforceSpawning[iClient])
		return;
	
	g_bReinforceSpawning[iClient] = false;
	float vecStill[3];
	TeleportEntity(iClient, g_vecReinforceSpot[iClient], g_vecReinforceAngles[iClient], vecStill);
	if (g_bReinforceCrouch[iClient])
		Reinforce_Crouch(iClient);
	
	RequestFrame(Frame_ReinforceSpawned, GetClientUserId(iClient));
	
	g_iReinforceIdle[iClient] = 0;
	if (!IsFakeClient(iClient))
	{
		g_iReinforceIdle[iClient] = ++g_iReinforceArrivals;
		Reinforce_StartIdleTimer(iClient, REINFORCE_IDLE_TIME);
	}
}

public void OnPlayerRunCmdPre(int iClient, int iButtons, int iImpulse, const float vecVel[3], const float vecAngles[3], int iWeapon, int iSubType, int iCmdNum, int iTickCount, int iSeed, const int iMouse[2])
{
	if (g_iReinforceIdle[iClient] && (iButtons || iImpulse || iWeapon || iMouse[0] || iMouse[1]))
		g_iReinforceIdle[iClient] = 0;
}

static void Reinforce_StartIdleTimer(int iClient, float flDelay)
{
	DataPack data;
	CreateDataTimer(flDelay, Timer_ReinforceIdle, data, TIMER_FLAG_NO_MAPCHANGE);
	data.WriteCell(GetClientUserId(iClient));
	data.WriteCell(g_iReinforceIdle[iClient]);
}

public Action Timer_ReinforceIdle(Handle hTimer, DataPack data)
{
	data.Reset();
	int iClient = GetClientOfUserId(data.ReadCell());
	int iArrival = data.ReadCell();
	if (!iClient || g_iReinforceIdle[iClient] != iArrival)
		return Plugin_Stop;
	
	if (!g_bEnabled || g_nRoundState != SZFRoundState_Active || !IsValidLivingSurvivor(iClient))
	{
		g_iReinforceIdle[iClient] = 0;
		return Plugin_Stop;
	}
	
	EmitSoundToClient(iClient, REINFORCE_IDLE_SOUND, _, REINFORCE_IDLE_CHANNEL);
	Reinforce_StartIdleTimer(iClient, REINFORCE_IDLE_REPEAT);
	return Plugin_Stop;
}

public void Frame_ReinforceSpawned(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (!iClient)
		return;
	
	bool bCrouch = g_bReinforceCrouch[iClient];
	g_bReinforceCrouch[iClient] = false;
	if (!g_bEnabled || g_nRoundState != SZFRoundState_Active || !IsValidLivingSurvivor(iClient))
		return;
	
	if (bCrouch)
		Reinforce_Crouch(iClient);
	
	Reinforce_GiveWeapons(iClient);
}

static void Reinforce_Crouch(int iClient)
{
	SetEntProp(iClient, Prop_Send, "m_bDucked", true);
	SetEntityFlags(iClient, GetEntityFlags(iClient) | FL_DUCKING);
	SetEntPropFloat(iClient, Prop_Send, "m_vecViewOffset[2]", REINFORCE_DUCK_VIEW);
}

static void Reinforce_GiveWeapons(int iClient)
{
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	int iActive = INVALID_ENT_REFERENCE;
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_Secondary; iSlot++)
	{
		Weapon wep;
		if (!Reinforce_RollWeapon(nClass, iSlot, wep))
			continue;
		
		int iWeapon = Reinforce_EquipWeapon(iClient, iSlot, wep);
		if (iActive == INVALID_ENT_REFERENCE)
			iActive = iWeapon;
	}
	
	if (iActive != INVALID_ENT_REFERENCE)
		TF2_SwitchActiveWeapon(iClient, iActive);
	
	CreateTimer(0.1, Timer_UpdateClientHud, GetClientSerial(iClient));
}

static bool Reinforce_RollWeapon(TFClassType nClass, int iSlot, Weapon wep)
{
	ArrayList aRare = new ArrayList(sizeof(Weapon));
	ArrayList aOther = new ArrayList(sizeof(Weapon));
	Reinforce_AddSlotWeapons(aRare, WeaponRarity_Rare, nClass, iSlot);
	Reinforce_AddSlotWeapons(aOther, WeaponRarity_Common, nClass, iSlot);
	Reinforce_AddSlotWeapons(aOther, WeaponRarity_Uncommon, nClass, iSlot);
	
	ArrayList aList = aOther;
	if (aRare.Length > 0 && (aOther.Length == 0 || GetRandomFloat(0.0, 1.0) < MapConfig_GetRareWeaponChance()))
		aList = aRare;
	
	bool bFound = aList.Length > 0;
	if (bFound)
		aList.GetArray(GetRandomInt(0, aList.Length - 1), wep);
	
	delete aRare;
	delete aOther;
	return bFound;
}

static void Reinforce_AddSlotWeapons(ArrayList aList, WeaponRarity nRarity, TFClassType nClass, int iSlot)
{
	ArrayList aAll = GetAllWeaponsWithRarity(nRarity, _, nClass, true);
	int iLength = aAll.Length;
	for (int i = 0; i < iLength; i++)
	{
		Weapon wep;
		aAll.GetArray(i, wep);
		if (TF2_GetItemSlot(wep.iIndex, nClass) == iSlot)
			aList.PushArray(wep);
	}
	
	delete aAll;
}

static int Reinforce_EquipWeapon(int iClient, int iSlot, Weapon wep)
{
	TF2_RemoveItemInSlot(iClient, iSlot);
	int iWeapon = TF2_CreateAndEquipWeapon(iClient, wep.iIndex, wep.attribs, true);
	if (iWeapon == INVALID_ENT_REFERENCE)
		return INVALID_ENT_REFERENCE;
	
	SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", SDKCall_GetDefaultItemChargeMeterValue(iWeapon), iSlot);
	
	char sClassname[256];
	TF2Econ_GetItemClassName(wep.iIndex, sClassname, sizeof(sClassname));
	if (StrContains(sClassname, "tf_wearable") == 0)
		return INVALID_ENT_REFERENCE;
	
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType > -1)
	{
		SetEntProp(iClient, Prop_Send, "m_iAmmo", 0, _, iAmmoType);
		GivePlayerAmmo(iClient, 9999, iAmmoType, true);
	}
	
	return iWeapon;
}

static int Reinforce_PickPlayers(int iWant, int[] iChosen, int iAlready)
{
	int iMax = Reinforce_GetMaxCount();
	if (iWant > iMax)
		iWant = iMax;
	
	bool bTaken[MAXPLAYERS + 1];
	for (int i = 0; i < iAlready; i++)
		bTaken[iChosen[i]] = true;
	
	int iCount = iAlready;
	while (iCount < iWant)
	{
		int iBest, iBestPoints = -1, iTies;
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (bTaken[iClient] || !Reinforce_CanBePicked(iClient))
				continue;
			
			int iPoints = g_iReinforcePoints[iClient];
			if (iPoints > iBestPoints)
			{
				iBest = iClient;
				iBestPoints = iPoints;
				iTies = 1;
			}
			else if (iPoints == iBestPoints && GetRandomInt(0, iTies++) == 0)
			{
				iBest = iClient;
			}
		}
		
		if (!iBest)
			break;
		
		bTaken[iBest] = true;
		g_nReinforceClass[iBest] = TFClass_Unknown;
		iChosen[iCount++] = iBest;
	}
	
	return iCount;
}

static int Reinforce_GetMaxCount()
{
	int iCount = -1;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidZombie(iClient) && !Reinforce_IsPending(iClient))
			iCount++;
	
	return iCount;
}

static bool Reinforce_CanBePicked(int iClient)
{
	if (!IsValidZombie(iClient) || Reinforce_IsPending(iClient))
		return false;
	
	return g_nNextInfected[iClient] == Infected_None && !(g_nInfected[iClient] == Infected_Tank && IsPlayerAlive(iClient));
}

static int Reinforce_GetBiggestGroup(int[] iGroup)
{
	int iSurvivors[MAXPLAYERS];
	float vecPos[MAXPLAYERS][3];
	int iCount;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsValidLivingSurvivor(iClient))
			continue;
		
		iSurvivors[iCount] = iClient;
		GetClientAbsOrigin(iClient, vecPos[iCount]);
		iCount++;
	}
	
	int iGroupOf[MAXPLAYERS];
	for (int i = 0; i < iCount; i++)
		iGroupOf[i] = -1;
	
	float flDistance = REINFORCE_GROUP_DISTANCE * REINFORCE_GROUP_DISTANCE;
	int iQueue[MAXPLAYERS];
	int iGroups, iBestGroup = -1, iBestSize, iTies;
	for (int i = 0; i < iCount; i++)
	{
		if (iGroupOf[i] != -1)
			continue;
		
		int iHead, iTail;
		iQueue[iTail++] = i;
		iGroupOf[i] = iGroups;
		while (iHead < iTail)
		{
			int iFrom = iQueue[iHead++];
			for (int j = 0; j < iCount; j++)
			{
				if (iGroupOf[j] == -1 && GetVectorDistance(vecPos[iFrom], vecPos[j], true) <= flDistance)
				{
					iGroupOf[j] = iGroups;
					iQueue[iTail++] = j;
				}
			}
		}
		
		if (iTail > iBestSize)
		{
			iBestGroup = iGroups;
			iBestSize = iTail;
			iTies = 1;
		}
		else if (iTail == iBestSize && GetRandomInt(0, iTies++) == 0)
		{
			iBestGroup = iGroups;
		}
		
		iGroups++;
	}
	
	int iSize;
	for (int i = 0; i < iCount; i++)
		if (iGroupOf[i] == iBestGroup)
			iGroup[iSize++] = iSurvivors[i];
	
	return iSize;
}

static void Reinforce_AssignSpots(const int[] iGroup, int iGroupCount, const int[] iChosen, int iChosenCount)
{
	float vecMembers[MAXPLAYERS][3];
	float vecCentre[3];
	for (int i = 0; i < iGroupCount; i++)
	{
		GetClientAbsOrigin(iGroup[i], vecMembers[i]);
		AddVectors(vecCentre, vecMembers[i], vecCentre);
	}
	
	ScaleVector(vecCentre, 1.0 / float(iGroupCount));
	
	int iOrder[MAXPLAYERS];
	float flOrder[MAXPLAYERS];
	int iKindCount[4];
	for (int i = 0; i < iGroupCount; i++)
	{
		int iMember = iGroup[i];
		int iFlags = GetEntityFlags(iMember);
		bool bOnGround = (iFlags & FL_ONGROUND) != 0;
		bool bCrouching = (iFlags & FL_DUCKING) || GetEntProp(iMember, Prop_Send, "m_bDucking");
		int iKind = 3;
		if (!bCrouching && Reinforce_HasRoom(vecMembers[i], iChosen, iChosenCount))
			iKind = bOnGround ? 0 : 1;
		else if ((iFlags & FL_DUCKING) && bOnGround)
			iKind = 2;
		
		iKindCount[iKind]++;
		float flKey = float(iKind) * REINFORCE_ORDER_STEP + GetVectorDistance(vecMembers[i], vecCentre);
		
		int j = i;
		while (j > 0 && flOrder[j - 1] > flKey)
		{
			iOrder[j] = iOrder[j - 1];
			flOrder[j] = flOrder[j - 1];
			j--;
		}
		
		iOrder[j] = i;
		flOrder[j] = flKey;
	}
	
	int iBestKind;
	while (iBestKind < 3 && !iKindCount[iBestKind])
		iBestKind++;
	
	bool bCrouch = iBestKind >= 2;
	int iTake = iKindCount[iBestKind];
	for (int i = 0; i < iChosenCount; i++)
	{
		int iMember = iOrder[i % iTake];
		int iClient = iChosen[i];
		g_bReinforceCrouch[iClient] = bCrouch;
		for (int k = 0; k < 3; k++)
			g_vecReinforceSpot[iClient][k] = vecMembers[iMember][k];
		
		GetClientEyeAngles(iGroup[iMember], g_vecReinforceAngles[iClient]);
		g_vecReinforceAngles[iClient][0] = 0.0;
		g_vecReinforceAngles[iClient][2] = 0.0;
	}
}

static bool Reinforce_HasRoom(const float vecPos[3], const int[] iChosen, int iChosenCount)
{
	float vecEnd[3];
	bool bStartSolid;
	Reinforce_TraceHull(vecPos, vecPos, iChosen, iChosenCount, vecEnd, bStartSolid);
	return !bStartSolid;
}

static bool Reinforce_TraceHull(const float vecStart[3], const float vecEnd[3], const int[] iChosen, int iChosenCount, float vecEndPos[3], bool &bStartSolid)
{
	g_iReinforceIgnoreCount = 0;
	for (int iPass = 0; iPass < REINFORCE_TRACE_PASSES; iPass++)
	{
		TR_TraceHullFilter(vecStart, vecEnd, g_vecReinforceHullMins, g_vecReinforceHullMaxs, MASK_PLAYERSOLID, Reinforce_TraceFilter);
		
		int iHit = TR_GetEntityIndex();
		if (0 < iHit <= MaxClients && g_iReinforceIgnoreCount < sizeof(g_iReinforceIgnore) && Reinforce_IsPassable(iHit, iChosen, iChosenCount))
		{
			g_iReinforceIgnore[g_iReinforceIgnoreCount++] = iHit;
			continue;
		}
		
		bStartSolid = TR_StartSolid();
		TR_GetEndPosition(vecEndPos);
		return TR_DidHit();
	}
	
	bStartSolid = true;
	return true;
}

static bool Reinforce_IsPassable(int iClient, const int[] iChosen, int iChosenCount)
{
	if (!IsValidClient(iClient) || IsSurvivor(iClient))
		return true;
	
	for (int i = 0; i < iChosenCount; i++)
		if (iChosen[i] == iClient)
			return true;
	
	return false;
}

public bool Reinforce_TraceFilter(int iEntity, int iContentsMask)
{
	for (int i = 0; i < g_iReinforceIgnoreCount; i++)
		if (g_iReinforceIgnore[i] == iEntity)
			return false;
	
	return true;
}
