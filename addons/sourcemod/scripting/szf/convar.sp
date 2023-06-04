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
	g_cvRatio = CreateConVar("sm_szf_ratio", "0.78", "<0.01-1.00> Percentage of players that start as survivors.", _, true, 0.01, true, 1.0);
	g_cvTankHealth = CreateConVar("sm_szf_tank_health", "400", "Amount of health the Tank gets per alive survivor", _, true, 10.0);
	g_cvTankHealthMin = CreateConVar("sm_szf_tank_health_min", "1000", "Minimum amount of health the Tank can spawn with", _, true, 0.0);
	g_cvTankHealthMax = CreateConVar("sm_szf_tank_health_max", "6000", "Maximum amount of health the Tank can spawn with", _, true, 0.0);
	g_cvTankTime = CreateConVar("sm_szf_tank_time", "30.0", "Adjusts the damage the Tank takes per second. 0 to disable.", _, true, 0.0);
	g_cvTankStab = CreateConVar("sm_szf_tank_stab", "500", "Flat Damage dealt to the Tank from a backstab", _, true, 0.0);
	g_cvJockeyMovementVictim = CreateConVar("sm_szf_jockey_movement_victim", "0.25", "Percentage of movement speed applied to victim from jockey grab", _, true, 0.0);
	g_cvJockeyMovementAttacker = CreateConVar("sm_szf_jockey_movement_attacker", "0.75", "Percentage of movement speed applied to jockey during grab", _, true, 0.0);
	g_cvFrenzyChance = CreateConVar("sm_szf_frenzy_chance", "0.0", "% Chance of a random frenzy", _, true, 0.0);
	g_cvFrenzyTankChance = CreateConVar("sm_szf_frenzy_tank", "0.0", "% Chance of a Tank appearing instead of a frenzy", _, true, 0.0);
	g_cvStunImmunity = CreateConVar("sm_szf_stun_immunity", "0.0", "How long until the survivor can be stunned again", _, true, 0.0);
	g_cvMeleeIgnoreTeammates = CreateConVar("sm_szf_melee_ignores_teammates", "1.0", "<0/1> If enabled, melee hits will ignore teammates", _, true, 0.0, true, 1.0);
	
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