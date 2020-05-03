//ConVars
static ConVar mp_autoteambalance;
static ConVar mp_teams_unbalance_limit;
static ConVar mp_scrambleteams_auto;
static ConVar mp_waitingforplayers_time;
static ConVar tf_weapon_criticals;
static ConVar tf_obj_upgrade_per_hit;
static ConVar tf_sentrygun_metal_per_shell;
static ConVar tf_spy_invis_time;
static ConVar tf_spy_invis_unstealth_time;
static ConVar tf_spy_cloak_no_attack_time;

void ConVar_Init()
{
	char sBuffer[32];
	Format(sBuffer, sizeof(sBuffer), "%s.%s", PLUGIN_VERSION, PLUGIN_VERSION_REVISION);
	CreateConVar("sm_szf_version", sBuffer, "Current Super Zombie Fortress Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	g_cvForceOn = CreateConVar("sm_szf_force_on", "1", "<0/1> Activate SZF for non-SZF maps.", _, true, 0.0, true, 1.0);
	g_cvRatio = CreateConVar("sm_szf_ratio", "0.78", "<0.01-1.00> Percentage of players that start as survivors.", _, true, 0.01, true, 1.0);
	g_cvTankHealth = CreateConVar("sm_szf_tank_health", "400", "Amount of health the Tank gets per alive survivor", _, true, 10.0);
	g_cvTankHealthMin = CreateConVar("sm_szf_tank_health_min", "1000", "Minimum amount of health the Tank can spawn with", _, true, 0.0);
	g_cvTankHealthMax = CreateConVar("sm_szf_tank_health_max", "6000", "Maximum amount of health the Tank can spawn with", _, true, 0.0);
	g_cvTankTime = CreateConVar("sm_szf_tank_time", "30.0", "Adjusts the damage the Tank takes per second. If the value is 70.0, the Tank will take damage that will make him die (if unhurt by survivors) after 70 seconds. 0 to disable.", _, true, 0.0);
	g_cvFrenzyChance = CreateConVar("sm_szf_frenzy_chance", "0.0", "% Chance of a random frenzy", _, true, 0.0);
	g_cvFrenzyTankChance = CreateConVar("sm_szf_frenzy_tank", "0.0", "% Chance of a Tank appearing instead of a frenzy", _, true, 0.0);
	
	mp_autoteambalance = FindConVar("mp_autoteambalance");
	mp_teams_unbalance_limit = FindConVar("mp_teams_unbalance_limit");
	mp_scrambleteams_auto = FindConVar("mp_scrambleteams_auto");
	mp_waitingforplayers_time = FindConVar("mp_waitingforplayers_time");
	tf_weapon_criticals = FindConVar("tf_weapon_criticals");
	tf_obj_upgrade_per_hit = FindConVar("tf_obj_upgrade_per_hit");
	tf_sentrygun_metal_per_shell = FindConVar("tf_sentrygun_metal_per_shell");
	tf_spy_invis_time = FindConVar("tf_spy_invis_time");
	tf_spy_invis_unstealth_time = FindConVar("tf_spy_invis_unstealth_time");
	tf_spy_cloak_no_attack_time = FindConVar("tf_spy_cloak_no_attack_time");
}

void ConVar_Enable()
{
	mp_autoteambalance.SetBool(false);
	mp_teams_unbalance_limit.SetBool(false);
	mp_scrambleteams_auto.SetBool(false);
	mp_waitingforplayers_time.SetInt(70);
	tf_weapon_criticals.SetBool(false);
	tf_obj_upgrade_per_hit.SetInt(0);
	tf_sentrygun_metal_per_shell.SetInt(201);
	tf_spy_invis_time.SetFloat(0.5);
	tf_spy_invis_unstealth_time.SetFloat(0.75);
	tf_spy_cloak_no_attack_time.SetFloat(1.0);
	
	mp_autoteambalance.AddChangeHook(OnConvarChanged);
	mp_teams_unbalance_limit.AddChangeHook(OnConvarChanged);
	mp_scrambleteams_auto.AddChangeHook(OnConvarChanged);
	mp_waitingforplayers_time.AddChangeHook(OnConvarChanged);
	tf_weapon_criticals.AddChangeHook(OnConvarChanged);
	tf_obj_upgrade_per_hit.AddChangeHook(OnConvarChanged);
	tf_sentrygun_metal_per_shell.AddChangeHook(OnConvarChanged);
	tf_spy_invis_time.AddChangeHook(OnConvarChanged);
	tf_spy_invis_unstealth_time.AddChangeHook(OnConvarChanged);
	tf_spy_cloak_no_attack_time.AddChangeHook(OnConvarChanged);
}

void ConVar_Disable()
{
	mp_autoteambalance.RemoveChangeHook(OnConvarChanged);
	mp_teams_unbalance_limit.RemoveChangeHook(OnConvarChanged);
	mp_scrambleteams_auto.RemoveChangeHook(OnConvarChanged);
	mp_waitingforplayers_time.RemoveChangeHook(OnConvarChanged);
	tf_weapon_criticals.RemoveChangeHook(OnConvarChanged);
	tf_obj_upgrade_per_hit.RemoveChangeHook(OnConvarChanged);
	tf_sentrygun_metal_per_shell.RemoveChangeHook(OnConvarChanged);
	tf_spy_invis_time.RemoveChangeHook(OnConvarChanged);
	tf_spy_invis_unstealth_time.RemoveChangeHook(OnConvarChanged);
	tf_spy_cloak_no_attack_time.RemoveChangeHook(OnConvarChanged);
	
	mp_autoteambalance.RestoreDefault();
	mp_teams_unbalance_limit.RestoreDefault();
	mp_scrambleteams_auto.RestoreDefault();
	mp_waitingforplayers_time.RestoreDefault();
	tf_weapon_criticals.RestoreDefault();
	tf_obj_upgrade_per_hit.RestoreDefault();
	tf_sentrygun_metal_per_shell.RestoreDefault();
	tf_spy_invis_time.RestoreDefault();
	tf_spy_invis_unstealth_time.RestoreDefault();
	tf_spy_cloak_no_attack_time.RestoreDefault();
}

public void OnConvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	float flValue = StringToFloat(newValue);
	
	if (convar == mp_autoteambalance && flValue != 0.0)
		mp_autoteambalance.SetBool(false);
	else if (convar == mp_teams_unbalance_limit && flValue != 0.0)
		mp_teams_unbalance_limit.SetBool(false);
	else if (convar == mp_scrambleteams_auto && flValue != 0.0)
		mp_scrambleteams_auto.SetBool(false);
	else if (convar == mp_waitingforplayers_time && flValue != 70.0)
		mp_waitingforplayers_time.SetInt(70);
	else if (convar == tf_weapon_criticals && flValue != 0.0)
		tf_weapon_criticals.SetBool(false);
	else if (convar == tf_obj_upgrade_per_hit && flValue != 0.0)
		tf_obj_upgrade_per_hit.SetInt(0);
	else if (convar == tf_sentrygun_metal_per_shell && flValue != 201.0)
		tf_sentrygun_metal_per_shell.SetInt(201);
	else if (convar == tf_spy_invis_time && flValue != 0.5)
		tf_spy_invis_time.SetFloat(0.5);
	else if (convar == tf_spy_invis_unstealth_time && flValue != 0.75)
		tf_spy_invis_unstealth_time.SetFloat(0.75);
	else if (convar == tf_spy_cloak_no_attack_time && flValue != 1.0)
		tf_spy_cloak_no_attack_time.SetFloat(1.0);
}