static GlobalForward g_hForwardLastSurvivor;
static GlobalForward g_hForwardBackstab;
static GlobalForward g_hForwardTankSpawn;
static GlobalForward g_hForwardTankDeath;
static GlobalForward g_hForwardQuickSpawnAsSpecialInfected;
static GlobalForward g_hForwardChargerHit;
static GlobalForward g_hForwardHunterHit;
static GlobalForward g_hForwardBoomerExplode;
static GlobalForward g_hForwardWeaponPickup;
static GlobalForward g_hForwardWeaponPickupPre;
static GlobalForward g_hForwardWeaponCallout;
static GlobalForward g_hForwardClientName;
static GlobalForward g_hForwardStartZombie;
static GlobalForward g_hForwardAllowMusicPlay;

void Forward_AskLoad()
{
	g_hForwardLastSurvivor = new GlobalForward("SZF_OnLastSurvivor", ET_Ignore, Param_Cell);
	g_hForwardBackstab = new GlobalForward("SZF_OnBackstab", ET_Ignore, Param_Cell, Param_Cell);
	g_hForwardTankSpawn = new GlobalForward("SZF_OnTankSpawn", ET_Ignore, Param_Cell);
	g_hForwardTankDeath = new GlobalForward("SZF_OnTankDeath", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hForwardQuickSpawnAsSpecialInfected = new GlobalForward("SZF_OnQuickSpawnAsSpecialInfected", ET_Ignore, Param_Cell);
	g_hForwardChargerHit = new GlobalForward("SZF_OnChargerHit", ET_Ignore, Param_Cell, Param_Cell);
	g_hForwardHunterHit = new GlobalForward("SZF_OnHunterHit", ET_Ignore, Param_Cell, Param_Cell);
	g_hForwardBoomerExplode = new GlobalForward("SZF_OnBoomerExplode", ET_Ignore, Param_Cell, Param_Array, Param_Cell);
	g_hForwardWeaponPickup = new GlobalForward("SZF_OnWeaponPickup", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hForwardWeaponPickupPre = new GlobalForward("SZF_ShouldPickupWeapon", ET_Single, Param_Cell, Param_Cell, Param_Cell);
	g_hForwardWeaponCallout = new GlobalForward("SZF_OnWeaponCallout", ET_Ignore, Param_Cell);
	g_hForwardClientName = new GlobalForward("SZF_GetClientName", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	g_hForwardStartZombie = new GlobalForward("SZF_ShouldStartZombie", ET_Hook, Param_Cell);
	g_hForwardAllowMusicPlay = new GlobalForward("SZF_ShouldAllowMusicPlay", ET_Hook);
}

void Forward_OnLastSurvivor(int iClient)
{
	Call_StartForward(g_hForwardLastSurvivor);
	Call_PushCell(iClient);
	Call_Finish();
}

void Forward_OnBackstab(int iVictim, int iAttacker)
{
	Call_StartForward(g_hForwardBackstab);
	Call_PushCell(iVictim);
	Call_PushCell(iAttacker);
	Call_Finish();
}

void Forward_OnTankSpawn(int iClient)
{
	Call_StartForward(g_hForwardTankSpawn);
	Call_PushCell(iClient);
	Call_Finish();
}

void Forward_OnTankDeath(int iVictim, int iWinner, int iDamage)
{
	Call_StartForward(g_hForwardTankDeath);
	Call_PushCell(iVictim);
	Call_PushCell(iWinner);
	Call_PushCell(iDamage);
	Call_Finish();
}

void Forward_OnQuickSpawnAsSpecialInfected(int iClient)
{
	Call_StartForward(g_hForwardQuickSpawnAsSpecialInfected);
	Call_PushCell(iClient);
	Call_Finish();
}

void Forward_OnChargerHit(int iClient, int iVictim)
{
	Call_StartForward(g_hForwardChargerHit);
	Call_PushCell(iClient);
	Call_PushCell(iVictim);
	Call_Finish();
}

void Forward_OnHunterHit(int iClient, int iVictim)
{
	Call_StartForward(g_hForwardHunterHit);
	Call_PushCell(iClient);
	Call_PushCell(iVictim);
	Call_Finish();
}

void Forward_OnBoomerExplode(int iClient, int iClients[MAXPLAYERS], int iCount)
{
	Call_StartForward(g_hForwardBoomerExplode);
	Call_PushCell(iClient);
	Call_PushArray(iClients, MAXPLAYERS);
	Call_PushCell(iCount);
	Call_Finish();
}

void Forward_OnWeaponPickup(int iClient, int iWeapon, WeaponRarity nRarity)
{
	Call_StartForward(g_hForwardWeaponPickup);
	Call_PushCell(iClient);
	Call_PushCell(iWeapon);
	Call_PushCell(nRarity);
	Call_Finish();
}

Action Forward_OnWeaponPickupPre(int iClient, int iTarget, WeaponRarity nRarity)
{
	Action action = Plugin_Continue;
	Call_StartForward(g_hForwardWeaponPickupPre);
	Call_PushCell(iClient);
	Call_PushCell(iTarget);
	Call_PushCell(nRarity);
	Call_Finish(action);
	return action;
}

void Forward_OnWeaponCallout(int iClient)
{
	Call_StartForward(g_hForwardWeaponCallout);
	Call_PushCell(iClient);
	Call_Finish();
}

void Forward_GetClientName(int iClient, char[] sName, int iLength)
{
	Call_StartForward(g_hForwardClientName);
	Call_PushCell(iClient);
	Call_PushStringEx(sName, iLength, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(iLength);
	Call_Finish();
}

Action Forward_ShouldStartZombie(int iClient)
{
	Action action = Plugin_Continue;
	Call_StartForward(g_hForwardStartZombie);
	Call_PushCell(iClient);
	Call_Finish(action);
	return action;
}

Action Forward_ShouldAllowMusicPlay()
{
	Action action = Plugin_Continue;
	Call_StartForward(g_hForwardAllowMusicPlay);
	Call_Finish(action);
	return action;
}