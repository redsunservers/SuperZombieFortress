void Command_Init()
{
	RegServerCmd("szf_zombietank", Command_ServerTank);
	RegServerCmd("szf_tank", Command_ServerTank);
	RegServerCmd("szf_panic_event", Command_ServerRage);
	RegServerCmd("szf_zombierage", Command_ServerRage);
	
	RegAdminCmd("sm_tank", Command_ZombieTank, ADMFLAG_CHANGEMAP, "(Try to) call a tank.");
	RegAdminCmd("sm_rage", Command_ZombieRage, ADMFLAG_CHANGEMAP, "(Try to) call a frenzy.");
	RegAdminCmd("sm_infected", Command_ForceInfected, ADMFLAG_CHANGEMAP, "Force someone to become infected on next spawn.");
	RegAdminCmd("sm_szfreload", Command_ReloadConfigs, ADMFLAG_RCON, "Reload SZF configs.");
	RegAdminCmd("sm_stun", Command_Stun, ADMFLAG_RCON, "SZF Stun player.");
	
	RegConsoleCmd("sm_zf", Command_MainMenu);
	RegConsoleCmd("sm_szf", Command_MainMenu);
	RegConsoleCmd("sm_music", Command_MusicToggle);
}

public Action Command_ServerTank(int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	ZombieTank();
	return Plugin_Handled;
}

public Action Command_ServerRage(int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	char sDuration[256];
	GetCmdArgString(sDuration, sizeof(sDuration));
	float flDuration = StringToFloat(sDuration);
	
	ZombieRage(flDuration);
	return Plugin_Handled;
}

public Action Command_ZombieTank(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	ZombieTank(iClient);
	return Plugin_Handled;
}

public Action Command_ZombieRage(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	ZombieRage();
	return Plugin_Handled;
}

public Action Command_ForceInfected(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 2)
	{
		CReplyToCommand(iClient, "%t", "Command_InfectedUsage", "{red}");
		return Plugin_Handled;
	}
	
	char sTarget[32], sInfected[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sInfected, sizeof(sInfected));
	
	Infected nInfected = Infected_None;
	for (int i = 1; i < view_as<int>(Infected_Count); i++)
	{
		char sBuffer[32];
		GetInfectedName(sBuffer, sizeof(sBuffer), i);
		if (StrContains(sBuffer, sInfected, false) > -1)
		{
			nInfected = view_as<Infected>(i);
			strcopy(sInfected, sizeof(sInfected), sBuffer);
			break;
		}
	}
	
	if (nInfected == Infected_None)
	{
		CReplyToCommand(iClient, "%t", "Command_InfectedNoInfected", "{red}", sInfected);
		return Plugin_Handled;
	}
	
	int iTargetList[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(iTargetList), COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML);
	if (iTargetCount <= 0)
	{
		CReplyToCommand(iClient, "%t", "Command_InfectedNoTarget", "{red}");
		return Plugin_Handled;
	}
	
	int iCount = 0;
	for (int i = 0; i < iTargetCount; i++)
	{
		if (IsValidZombie(iTargetList[i]))
		{
			g_nNextInfected[iTargetList[i]] = nInfected;
			iCount++;
		}
	}
	
	if (iCount == 0)
		CReplyToCommand(iClient, "%t", "Command_InfectedNoZombie", "{red}");
	else
		CReplyToCommand(iClient, "%t", "Command_InfectedSet", "{limegreen}", iCount, sInfected);
	
	return Plugin_Handled;
}

public Action Command_ReloadConfigs(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	Config_Refresh();
	Classes_Refresh();
	Weapons_Refresh();
	
	return Plugin_Handled;
}

public Action Command_Stun(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t", "Command_StunUsage", "{red}");
		return Plugin_Handled;
	}
	
	char sTarget[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	
	int iTargetList[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(iTargetList), COMMAND_FILTER_NO_IMMUNITY|COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bIsML);
	if (iTargetCount <= 0)
	{
		CReplyToCommand(iClient, "%t", "Command_StunNoTarget", "{red}");
		return Plugin_Handled;
	}
	
	float flDuration;
	if (iArgs >= 2)
	{
		char sBuffer[16];
		GetCmdArg(2, sBuffer, sizeof(sBuffer));
		flDuration = StringToFloat(sBuffer);
	}
	
	for (int i = 0; i < iTargetCount; i++)
	{
		if (flDuration > 0)
			Stun_StartPlayer(iTargetList[i], flDuration);
		else
			Stun_StartPlayer(iTargetList[i]);
	}
	
	CReplyToCommand(iClient, "%t", "Command_StunSet", "{limegreen}", iTargetCount);
	return Plugin_Handled;
}

public Action Command_MainMenu(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	Menu_DisplayMain(iClient);

	return Plugin_Handled;
}

public Action Command_MusicToggle(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (IsValidClient(iClient))
	{
		char sPreference[32];
		
		if (g_bNoMusicForClient[iClient])
		{
			g_bNoMusicForClient[iClient] = false;
			CPrintToChat(iClient, "%t", "Command_MusicEnable", "{limegreen}");
		}
		else if (!g_bNoMusicForClient[iClient])
		{
			g_bNoMusicForClient[iClient] = true;
			CPrintToChat(iClient, "%t", "Command_MusicDisable", "{limegreen}");
		}
		
		Format(sPreference, sizeof(sPreference), "%d", g_bNoMusicForClient[iClient]);
		SetClientCookie(iClient, g_cNoMusicForPlayer, sPreference);
	}
	
	return Plugin_Handled;
}