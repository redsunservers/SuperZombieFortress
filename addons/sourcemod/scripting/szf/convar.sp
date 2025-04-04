enum struct ConVarInfo
{
	ConVar hConVar;
	float flSZFValue;
	float flDefaultValue;
}

static ArrayList g_aConVar;

void ConVar_Init()
{
	char sBuffer[32];
	Format(sBuffer, sizeof(sBuffer), "%s.%s", PLUGIN_VERSION, PLUGIN_VERSION_REVISION);
	CreateConVar("sm_szf_version", sBuffer, "Current Super Zombie Fortress Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	g_cvForceOn = CreateConVar("sm_szf_force_on", "1", "<0/1> Force enable SZF for next map.", _, true, 0.0, true, 1.0);
	g_cvDebug = CreateConVar("sm_szf_debug", "1", "Enable debugs?", _, true, 0.0, true, 1.0);
	g_cvRatio = CreateConVar("sm_szf_ratio", "0.80", "<0.01-1.00> Percentage of players that start as survivors.", _, true, 0.01, true, 1.0);
	g_cvTankHealth = CreateConVar("sm_szf_tank_health", "400", "Amount of health the Tank gets per alive survivor.", _, true, 10.0);
	g_cvTankHealthMin = CreateConVar("sm_szf_tank_health_min", "1000", "Minimum amount of health the Tank can spawn with.", _, true, 0.0);
	g_cvTankHealthMax = CreateConVar("sm_szf_tank_health_max", "10000", "Maximum amount of health the Tank can spawn with.", _, true, 0.0);
	g_cvTankTime = CreateConVar("sm_szf_tank_time", "35.0", "Adjusts the damage the Tank takes per second. 0 to disable.", _, true, 0.0);
	g_cvTankStab = CreateConVar("sm_szf_tank_stab", "500", "Flat Damage dealt to the Tank from a backstab.", _, true, 0.0);
	g_cvTankDebrisLifetime = CreateConVar("sm_szf_tank_debris_lifetime", "20.0", "Amount of time (in seconds) it takes for debris thrown by Tanks to despawn. Use 0 to prevent despawning.", _, true, 0.0);
	g_cvSpecialInfectedInterval = CreateConVar("sm_szf_special_infected_interval", "40.0", "Seconds interval to select a random infected to be special infected. -1 to disable it.", _, true, -1.0);
	g_cvJockeyMovementVictim = CreateConVar("sm_szf_jockey_movement_victim", "0.25", "Percentage of movement speed applied to victim from jockey grab.", _, true, 0.0);
	g_cvJockeyMovementAttacker = CreateConVar("sm_szf_jockey_movement_attacker", "0.75", "Percentage of movement speed applied to jockey during grab.", _, true, 0.0);
	g_cvFrenzyTankChance = CreateConVar("sm_szf_frenzy_tank", "0.0", "% Chance of a Tank appearing instead of a frenzy.", _, true, 0.0, true, 1.0);
	g_cvStunImmunity = CreateConVar("sm_szf_stun_immunity", "0.0", "How long until the survivor can be stunned again.", _, true, 0.0);
	g_cvLastStandKingRuneDuration = CreateConVar("sm_szf_laststand_kingrune_duration", "-1.0", "How long the last survivor gets the King Rune, -1.0 for infinite.", _, true, -1.0);
	g_cvLastStandDefenseDuration = CreateConVar("sm_szf_laststand_defense_duration", "30.0", "How long the last survivor gets the Defense Buff, -1.0 for infinite.", _, true, -1.0);
	g_cvDispenserAmmoCooldown = CreateConVar("sm_szf_dispenser_ammo_cooldown", "8.0", "Cooldown before client could gain ammo from dispensers.", _, true, 0.0);
	g_cvDispenserHealRate = CreateConVar("sm_szf_dispenser_heal_rate", "0.2", "Heal rate multiplier for survivor's dispensers.", _, true, 0.0);
	g_cvBannerRequirement = CreateConVar("sm_szf_banner_requirement", "200.0", "Total damage requirement to build banner meter.", _, true, 0.0);
	g_cvMeleeIgnoreTeammates = CreateConVar("sm_szf_melee_ignores_teammates", "1.0", "<0/1> If enabled, melee hits will ignore teammates.", _, true, 0.0, true, 1.0);
	g_cvPunishAvoidingPlayers = CreateConVar("sm_szf_punish_avoiding_players", "1.0", "<0/1> If enabled, players who avoid playing on the Infected team will be forced back into it in the next round they play.", _, true, 0.0, true, 1.0);
	
	ConVar_InitEvent(g_FrenzyEvent, "frenzy", "60.0", "120.0", "0.1", "60");
	ConVar_InitEvent(g_TankEvent, "tank", "120.0", "180.0", "0.1", "100");
	
	g_aConVar = new ArrayList(sizeof(ConVarInfo));
	
	ConVar_Add("mp_autoteambalance", 0.0);
	ConVar_Add("mp_teams_unbalance_limit", 0.0);
	ConVar_Add("mp_scrambleteams_auto", 0.0);
	ConVar_Add("mp_waitingforplayers_time", 70.0);
	
	ConVar_Add("spec_freeze_time", -1.0);
	
	ConVar_Add("sv_turbophysics", 0.0);
	
	ConVar_Add("tf_obj_upgrade_per_hit", 0.0);
	ConVar_Add("tf_player_movement_restart_freeze", 0.0);
	ConVar_Add("tf_sentrygun_metal_per_shell", 201.0);
	ConVar_Add("tf_weapon_criticals", 0.0);
}

void ConVar_InitEvent(ConVarEvent event, const char[] sSyntax, const char[] sCooldown, const char[] sInterval, const char[] sThreshold, const char[] sKillSpree)
{
	event.cvCooldown = CreateConVar(ConVar_FormatString(sSyntax, "sm_szf_%s_cooldown"), sCooldown, ConVar_FormatString(sSyntax, "Cooldown in seconds for %s."), _, true, 0.0);
	event.cvSurvivorDeathInterval = CreateConVar(ConVar_FormatString(sSyntax, "sm_szf_%s_survivor_death_interval"), sInterval, ConVar_FormatString(sSyntax, "Check in the past seconds on how many survivors died to trigger %s."), _, true, 0.0);
	event.cvSurvivorDeathThreshold = CreateConVar(ConVar_FormatString(sSyntax, "sm_szf_%s_survivor_death_threshold"), sThreshold, ConVar_FormatString(sSyntax, "Min %% amount of survivors who have died in the past seconds to trigger %s."), _, true, 0.0, true, 1.0);
	event.cvKillSpree = CreateConVar(ConVar_FormatString(sSyntax, "sm_szf_%s_killspree"), sKillSpree, ConVar_FormatString(sSyntax, "Amount of infected deaths to trigger %s, multiplied by %% of infecteds."), _, true, 0.0);
	event.cvChance = CreateConVar(ConVar_FormatString(sSyntax, "sm_szf_%s_chance"), "0.0", ConVar_FormatString(sSyntax, "%% Chance of a %s frenzy."), _, true, 0.0, true, 1.0);
}

char[] ConVar_FormatString(const char[] sSyntax, const char[] sName)
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), sName, sSyntax);
	return sBuffer;
}

void ConVar_Add(const char[] sConVar, float flValue)
{
	ConVarInfo info;
	info.hConVar = FindConVar(sConVar);
	info.flSZFValue = flValue;
	g_aConVar.PushArray(info);
	
	info.hConVar.AddChangeHook(ConVar_OnChanged);
}

void ConVar_Enable()
{
	int iLength = g_aConVar.Length;
	for (int i = 0; i < iLength; i++)
	{
		ConVarInfo info;
		g_aConVar.GetArray(i, info);
		info.flDefaultValue = info.hConVar.FloatValue;
		g_aConVar.SetArray(i, info);
		
		info.hConVar.FloatValue = info.flSZFValue;
	}
}

void ConVar_Disable()
{
	int iLength = g_aConVar.Length;
	for (int i = 0; i < iLength; i++)
	{
		ConVarInfo info;
		g_aConVar.GetArray(i, info);
		info.hConVar.FloatValue = info.flDefaultValue;
	}
}

public void ConVar_OnChanged(ConVar hConVar, const char[] oldValue, const char[] newValue)
{
	if (!g_bEnabled)
		return;
	
	int iPos = g_aConVar.FindValue(hConVar, ConVarInfo::hConVar);
	if (iPos >= 0)
	{
		ConVarInfo info;
		g_aConVar.GetArray(iPos, info);
		float flValue = StringToFloat(newValue);
		
		if (flValue != info.flSZFValue)
			info.hConVar.FloatValue = info.flSZFValue;
	}
}