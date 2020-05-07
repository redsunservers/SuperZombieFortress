void Command_Init()
{
	RegServerCmd("szf_zombietank", Command_ServerTank);
	RegServerCmd("szf_tank", Command_ServerTank);
	RegServerCmd("szf_panic_event", Command_ServerRage);
	RegServerCmd("szf_zombierage", Command_ServerRage);
	
	RegAdminCmd("sm_tank", Command_ZombieTank, ADMFLAG_CHANGEMAP, "(Try to) call a tank.");
	RegAdminCmd("sm_rage", Command_ZombieRage, ADMFLAG_CHANGEMAP, "(Try to) call a frenzy.");
	RegAdminCmd("sm_boomer", Command_ForceBoomer, ADMFLAG_CHANGEMAP, "Become a boomer on next respawn.");
	RegAdminCmd("sm_charger", Command_ForceCharger, ADMFLAG_CHANGEMAP, "Become a charger on next respawn.");
	RegAdminCmd("sm_kingpin", Command_ForceScreamer, ADMFLAG_CHANGEMAP, "Become a screamer on next respawn.");
	RegAdminCmd("sm_stalker", Command_ForcePredator, ADMFLAG_CHANGEMAP, "Become a predator on next respawn.");
	RegAdminCmd("sm_hunter", Command_ForceHopper, ADMFLAG_CHANGEMAP, "Become a hunter on next respawn.");
	RegAdminCmd("sm_smoker", Command_ForceSmoker, ADMFLAG_CHANGEMAP, "Become a smoker on next respawn.");
	RegAdminCmd("sm_spitter", Command_ForceSpitter, ADMFLAG_CHANGEMAP, "Become a spitter on next respawn.");
	RegAdminCmd("sm_jockey", Command_ForceJockey, ADMFLAG_CHANGEMAP, "Become a jockey on next respawn.");
	RegAdminCmd("sm_szfreload", Command_ReloadConfigs, ADMFLAG_RCON, "Reload SZF configs.");
	
	RegConsoleCmd("sm_zf", Command_MainMenu);
	RegConsoleCmd("sm_szf", Command_MainMenu);
	RegConsoleCmd("sm_music", Command_MusicToggle);
}

public Action Command_ServerTank(int iArgs)
{
	ZombieTank();
	
	return Plugin_Handled;
}

public Action Command_ServerRage(int iArgs)
{
	char sDuration[256];
	GetCmdArgString(sDuration, sizeof(sDuration));
	float flDuration = StringToFloat(sDuration);
	
	ZombieRage(flDuration);
	
	return Plugin_Handled;
}

public Action Command_ZombieTank(int iClient, int iArgs)
{
	ZombieTank(iClient);
	return Plugin_Handled;
}

public Action Command_ZombieRage(int iClient, int iArgs)
{
	ZombieRage();
	
	return Plugin_Handled;
}

public Action Command_ForceBoomer(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Boomer;
	
	return Plugin_Handled;
}

public Action Command_ForceCharger(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Charger;
	
	return Plugin_Handled;
}

public Action Command_ForceScreamer(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Kingpin;
	
	return Plugin_Handled;
}

public Action Command_ForcePredator(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Stalker;
	
	return Plugin_Handled;
}

public Action Command_ForceHopper(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Hunter;
	
	return Plugin_Handled;
}

public Action Command_ForceSmoker(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Smoker;
	
	return Plugin_Handled;
}

public Action Command_ForceSpitter(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Spitter;
	
	return Plugin_Handled;
}

public Action Command_ForceJockey(int iClient, int iArgs)
{
	if (IsZombie(iClient))
		g_nNextInfected[iClient] = Infected_Jockey;
	
	return Plugin_Handled;
}

public Action Command_ReloadConfigs(int iClient, int iArgs)
{
	Config_Refresh();
	Classes_Refresh();
	Weapons_Refresh();
	
	return Plugin_Handled;
}

public Action Command_MainMenu(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	Menu_PrintMain(iClient);

	return Plugin_Handled;
}

public Action Command_MusicToggle(int iClient, int iArgs)
{
	if (IsValidClient(iClient))
	{
		char sPreference[32];
		
		if (g_bNoMusicForClient[iClient])
		{
			g_bNoMusicForClient[iClient] = false;
			CPrintToChat(iClient, "{limegreen}Music has been enabled.");
		}
		else if (!g_bNoMusicForClient[iClient])
		{
			g_bNoMusicForClient[iClient] = true;
			CPrintToChat(iClient, "{limegreen}Music has been disabled.");
		}
		
		Format(sPreference, sizeof(sPreference), "%d", g_bNoMusicForClient[iClient]);
		SetClientCookie(iClient, g_cNoMusicForPlayer, sPreference);
	}
	
	return Plugin_Handled;
}