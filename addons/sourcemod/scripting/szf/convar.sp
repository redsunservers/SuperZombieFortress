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
	g_cvDebug = CreateConVar("sm_szf_debug", "0", "Enable debugs?", _, true, 0.0, true, 1.0);
	g_cvZombieDamage = CreateConVar("sm_szf_zombie_damage", "0.6", "Multiplier on all damage zombies deal with their weapons. Survivors always deal normal damage.", _, true, 0.0);
	g_cvZombieDamageUnderstaffed = CreateConVar("sm_szf_zombie_damage_understaffed", "0.8", "Multiplier on zombie weapon damage, instead of sm_szf_zombie_damage, while fewer zombies are alive than the round's starting zombie count.", _, true, 0.0);
	g_cvDirectorFrenzy = CreateConVar("sm_szf_director_frenzy", "0", "<0/1> Let the old director start frenzies on its own. Frenzies come from the respawn timeline (maps.cfg) instead.", _, true, 0.0, true, 1.0);
	g_cvDirectorTank = CreateConVar("sm_szf_director_tank", "0", "<0/1> Let the old director (and the last control point) call Tanks on their own. Tanks otherwise only come from maps, admins and a long Last Man Standing.", _, true, 0.0, true, 1.0);
	g_cvLastStandTankTime = CreateConVar("sm_szf_laststand_tank_time", "300.0", "Seconds of Last Man Standing before a Tank is sent, once per round. 0 to disable.", _, true, 0.0);
	g_cvWeaponSpawnReappear = CreateConVar("sm_szf_weapon_spawn_reappear", "0.25", "% chance for spawn weapons to reappear.", _, true, 0.0, true, 1.0);
	g_cvWeaponPickupChance = CreateConVar("sm_szf_weapon_pickup_chance", "0.07", "% chance for normal weapons to be pickups.", _, true, 0.0, true, 1.0);
	g_cvWeaponRareChance = CreateConVar("sm_szf_weapon_rare_chance", "0.2", "% chance for normal weapons to be rare.", _, true, 0.0, true, 1.0);
	g_cvWeaponRareCap = CreateConVar("sm_szf_weapon_rare_cap", "50", "Max amount of rare weapons to generate", _, true, 0.0);
	g_cvTankHealth = CreateConVar("sm_szf_tank_health", "350", "Amount of health the Tank gets per alive survivor.", _, true, 10.0);
	g_cvTankHealthMin = CreateConVar("sm_szf_tank_health_min", "1000", "Minimum amount of health the Tank can spawn with.", _, true, 0.0);
	g_cvTankHealthMax = CreateConVar("sm_szf_tank_health_max", "10000", "Maximum amount of health the Tank can spawn with.", _, true, 0.0);
	g_cvTankTime = CreateConVar("sm_szf_tank_time", "60.0", "Adjusts the damage the Tank takes per second. 0 to disable.", _, true, 0.0);
	g_cvTankStab = CreateConVar("sm_szf_tank_stab", "500", "Flat Damage dealt to the Tank from a backstab.", _, true, 0.0);
	g_cvTankDebrisLifetime = CreateConVar("sm_szf_tank_debris_lifetime", "20.0", "Amount of time (in seconds) it takes for debris thrown by Tanks to despawn. Use 0 to prevent despawning.", _, true, 0.0);
	g_cvSpecialInfectedInterval = CreateConVar("sm_szf_special_infected_interval", "35.0", "Seconds between picks of a random zombie to be a special infected with 2 or fewer active players. It rises in a straight line to sm_szf_special_infected_interval_max at sm_szf_special_infected_interval_players. -1 to disable it.", _, true, -1.0);
	g_cvSpecialInfectedIntervalMax = CreateConVar("sm_szf_special_infected_interval_max", "60.0", "Seconds between special infected picks with sm_szf_special_infected_interval_players or more active players.", _, true, 0.0);
	g_cvSpecialInfectedIntervalPlayers = CreateConVar("sm_szf_special_infected_interval_players", "40", "Active players at which the special infected interval reaches sm_szf_special_infected_interval_max (it is sm_szf_special_infected_interval at 2).", _, true, 3.0);
	g_cvBoomerPackWindow = CreateConVar("sm_szf_boomer_pack_window", "9.0", "When a Boomer spawns, dead zombies due to respawn within this many seconds respawn with it as Snipers, where it spawned. 0 to disable.", _, true, 0.0);
	g_cvJockeyMovementVictim = CreateConVar("sm_szf_jockey_movement_victim", "0.0", "Share of the victim's max speed the victim steers with (look direction) during a jockey grab. Their movement keys are blocked either way.", _, true, 0.0);
	g_cvJockeyMovementAttacker = CreateConVar("sm_szf_jockey_movement_attacker", "1.0", "Share of the victim's max speed the jockey steers the victim with during a grab.", _, true, 0.0);
	g_cvJockeyVictimSpeed = CreateConVar("sm_szf_jockey_victim_speed", "1.0", "Max speed multiplier of a survivor ridden by a jockey (1.0 = their normal speed).", _, true, 0.0);
	g_cvJockeyRideScale = CreateConVar("sm_szf_jockey_ride_scale", "1.25", "Model and hitbox scale of a jockey while it rides a survivor, so it's easier to hit up there. 1 = normal size.", _, true, 0.5, true, 2.0);
	g_cvSpectatorsJoin = CreateConVar("sm_szf_spectators_join", "0", "<0/1> Put players who are in spectator when a new round starts on a team, through the normal team split (zombie queue). 0: they stay in spectator, aren't counted in the split, and can join the Infected when the zombie join lock allows.", _, true, 0.0, true, 1.0);
	g_cvJoinLockTime = CreateConVar("sm_szf_join_lock_time", "120.0", "Players who aren't on a team can't join the Infected during setup and for this many seconds after it ends, unless the Infected team has fewer players than the round's starting zombie count. 0 = only during setup.", _, true, 0.0);
	g_cvChargerSlamStun = CreateConVar("sm_szf_charger_slam_stun", "6.0", "How long a survivor is stunned when a charging Charger pushes them into a wall or object (6 = a normal backstab stun). 0 to disable.", _, true, 0.0);
	g_cvFrenzyTankChance = CreateConVar("sm_szf_frenzy_tank", "0.0", "% Chance of a Tank appearing instead of a frenzy.", _, true, 0.0, true, 1.0);
	g_cvFrenzyRespawnStress = CreateConVar("sm_szf_frenzy_respawn_stress", "30.0", "Amount of seconds divided by playercount to add in frenzy respawn stress", _, true, 0.0, true, 120.0);
	g_cvStunImmunity = CreateConVar("sm_szf_stun_immunity", "0.0", "How long until the survivor can be stunned again.", _, true, 0.0);
	g_cvStunFogDistance = CreateConVar("sm_szf_stun_fog_distance", "500.0", "A stunned survivor sees black fog: everything this many units away is black, and the fog starts at half of it. Only the stunned player sees it.", _, true, 16.0);
	g_cvLastStandKingRuneDuration = CreateConVar("sm_szf_laststand_kingrune_duration", "-1.0", "How long the last survivor (and Left 4 Dead's last survivors) get the King Rune, -1.0 for infinite.", _, true, -1.0);
	g_cvLeft4DeadSurvivors = CreateConVar("sm_szf_left4dead_survivors", "12", "A round that starts with this many survivors or more has Left 4 Dead instead of Last Man Standing: the last sm_szf_left4dead_count survivors get mini-crits, damage resistance (30% at 16 players to 60% at 40), stun immunity, 10% more speed and a quarter of heal on hit and on kill. 0 to disable.", _, true, 0.0);
	g_cvLeft4DeadCount = CreateConVar("sm_szf_left4dead_count", "4", "How many survivors are left when Left 4 Dead starts.", _, true, 1.0);
	g_cvLastStandDefenseDuration = CreateConVar("sm_szf_laststand_defense_duration", "-1.0", "How long the last survivor gets damage resistance (50% at 2 players to 95% at 40), -1.0 for the whole stand.", _, true, -1.0);
	g_cvDispenserAmmoCooldown = CreateConVar("sm_szf_dispenser_ammo_cooldown", "4.0", "Cooldown before client could gain ammo from dispensers.", _, true, 0.0);
	g_cvDispenserAmmoMax = CreateConVar("sm_szf_dispenser_ammo_max", "20", "Max amount of ticks dispenser could dispense before self-destructs.", _, true, 0.0);
	g_cvDispenserHealRate = CreateConVar("sm_szf_dispenser_heal_rate", "0.8", "Heal rate multiplier for survivor's dispensers.", _, true, 0.0);
	g_cvDispenserHealMax = CreateConVar("sm_szf_dispenser_heal_max", "800", "Max amount of health dispenser could dispense before self-destructs.", _, true, 0.0);
	g_cvDispenserHealth = CreateConVar("sm_szf_dispenser_health", "200", "Max health of survivor dispensers. They start building at half of it.", _, true, 2.0);
	g_cvSentryShells = CreateConVar("sm_szf_sentry_shells", "80", "Shells a survivor sentry is capped to once built. It self-destructs at 0.", _, true, 1.0);
	g_cvSentryDecayFiring = CreateConVar("sm_szf_sentry_decay_firing", "1", "Shells a survivor sentry loses each second when it fired during that second.", _, true, 0.0);
	g_cvSentryDecayIdle = CreateConVar("sm_szf_sentry_decay_idle", "2", "Shells a survivor sentry loses each second when it didn't fire.", _, true, 0.0);
	g_cvBannerRequirement = CreateConVar("sm_szf_banner_requirement", "200.0", "Total damage requirement to build banner meter.", _, true, 0.0);
	g_cvMeleeIgnoreTeammates = CreateConVar("sm_szf_melee_ignores_teammates", "1.0", "<0/1> If enabled, melee hits will ignore teammates.", _, true, 0.0, true, 1.0);
	g_cvPunishAvoidingPlayers = CreateConVar("sm_szf_punish_avoiding_players", "1.0", "<0/1> If enabled, players who avoid playing on the Infected team will be forced back into it in the next round they play.", _, true, 0.0, true, 1.0);
	
	g_cvFriendlyFire = FindConVar("mp_friendlyfire");
	
	//                              syntax    cooldown interval threshold killspree progress
	ConVar_InitEvent(g_FrenzyEvent, "frenzy", "60.0",  "150.0", "0.1",    "50",     "0.2");
	ConVar_InitEvent(g_TankEvent,   "tank",   "120.0", "240.0", "0.1",    "80",     "0.3");
	
	g_aConVar = new ArrayList(sizeof(ConVarInfo));
	
	ConVar_Add("mp_autoteambalance", 0.0);
	ConVar_Add("mp_teams_unbalance_limit", 0.0);
	ConVar_Add("mp_scrambleteams_auto", 0.0);
	ConVar_Add("mp_waitingforplayers_time", 50.0);
	ConVar_Add("mp_forceautoteam", 0.0);
	
	ConVar_Add("spec_freeze_time", -1.0);
	
	ConVar_Add("sv_turbophysics", 0.0);
	
	ConVar_Add("tf_obj_upgrade_per_hit", 0.0);
	ConVar_Add("tf_player_movement_restart_freeze", 0.0);
	ConVar_Add("tf_sentrygun_metal_per_shell", 201.0);
	ConVar_Add("tf_weapon_criticals", 0.0);
}

void ConVar_InitEvent(ConVarEvent event, const char[] sSyntax, const char[] sCooldown, const char[] sInterval, const char[] sThreshold, const char[] sKillSpree, const char[] sProgress)
{
	event.cvCooldown = CreateConVar(ConVar_FormatString(sSyntax, "sm_szf_%s_cooldown"), sCooldown, ConVar_FormatString(sSyntax, "Cooldown in seconds for %s."), _, true, 0.0);
	event.cvSurvivorDeathInterval = CreateConVar(ConVar_FormatString(sSyntax, "sm_szf_%s_survivor_death_interval"), sInterval, ConVar_FormatString(sSyntax, "Check in the past seconds on how many survivors died to trigger %s."), _, true, 0.0);
	event.cvSurvivorDeathThreshold = CreateConVar(ConVar_FormatString(sSyntax, "sm_szf_%s_survivor_death_threshold"), sThreshold, ConVar_FormatString(sSyntax, "Min %% amount of survivors who have died in the past seconds to trigger %s."), _, true, 0.0, true, 1.0);
	event.cvKillSpree = CreateConVar(ConVar_FormatString(sSyntax, "sm_szf_%s_killspree"), sKillSpree, ConVar_FormatString(sSyntax, "Amount of infected deaths to trigger %s, multiplied by %% of infecteds."), _, true, 0.0);
	event.cvProgress = CreateConVar(ConVar_FormatString(sSyntax, "sm_szf_%s_progress"), sProgress, ConVar_FormatString(sSyntax, "Min %% of playerbase being survivor to trigger %s by map progress."), _, true, 0.0, true, 1.0);
	event.cvChance = CreateConVar(ConVar_FormatString(sSyntax, "sm_szf_%s_chance"), "0.0", ConVar_FormatString(sSyntax, "%% Chance of a random %s."), _, true, 0.0, true, 1.0);
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