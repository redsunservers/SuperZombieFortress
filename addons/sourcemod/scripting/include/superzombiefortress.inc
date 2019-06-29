#if defined _superzombiefortress_included
	#endinput
#endif
#define _superzombiefortress_included

enum eWeaponsRarity
{
	eWeaponsRarity_Common,
	eWeaponsRarity_Uncommon,
	eWeaponsRarity_Rare,
	eWeaponsRarity_Pickup,
};

/**
 * Forward called when a last survivor is triggered
 *
 * @param	iClient		client whose the last survivor
 * @noreturn
 */
forward void SZF_OnLastSurvivor(int iClient);

/**
 * Forward called when attacker backstabbed victim
 *
 * @param	iVictim		client whose got backstabbed
 * @param	iAttacker	client whose backstabbed victim
 * @noreturn
 */
forward void SZF_OnBackstab(int iVictim, int iAttacker);

/**
 * Forward called when a tank spawns
 *
 * @param	iTank		client whose the tank who spawned
 * @noreturn
 */
forward void SZF_OnTankSpawn(int iTank);

/**
 * Forward called when a tank dies
 *
 * @param	iTank		client whose the tank who died
 * @param	iMVP		client whose dealt the most damage to tank, 0 if nobody dealt damage to tank or invalid client
 * @param	iDamage		damage amount from client whose dealt the most damage to tank
 * @noreturn
 */
forward void SZF_OnTankDeath(int iTank, int iMVP, int iDamage);

/**
 * Forward called when zombie use quick respawn to become special infected
 *
 * @param	iClient		client whose use the quick respawn to become special infected
 * @noreturn
 */
forward void SZF_OnQuickSpawnAsSpecialInfected(int iClient);

/**
 * Forward called when charger charged to stun a survivor
 *
 * @param	iCharger	client whose the charger to stun a survivor
 * @param	iVictim		client whose the victim stunned from the charger
 * @noreturn
 */
forward void SZF_OnChargerHit(int iCharger, int iVictim);

/**
 * Forward called when hunter pounced to stun a survivor
 *
 * @param	iHunter		client whose the hunter to stun a survivor
 * @param	iVictim		client whose the victim stunned from the hunter
 * @noreturn
 */
forward void SZF_OnHunterHit(int iHunter, int iVictim);

/**
 * Forward called when a boomer explodes
 *
 * @param	iBoomer		client whose the boomer explode
 * @param	iClients	array of clients whose jarated from boomer
 * @param	iLength		amount of clients jarated from boomer
 * @noreturn
 */
forward void SZF_OnBoomerExplode(int iBoomer, int iClients[MAXPLAYERS], int iLength);

/**
 * Forward called when survivor picked up a weapon
 *
 * @param	iClient		client whose picked up the weapon
 * @param	iWeapon		Weapon entity whose picked up
 * @param	rarity		Rarity of the weapon
 * @noreturn
 */
forward void SZF_OnWeaponPickup(int iClient, int iWeapon, eWeaponsRarity rarity);

/**
 * Forward called when survivor called a rare weapon
 *
 * @param	iClient		client whose called a rare weapon
 * @noreturn
 */
forward void SZF_OnWeaponCallout(int iClient);

/**
 * Forward called when plugin need a client name to display in chat to override default name and color
 * plugin uses morecolors.inc to display chat with colors
 *
 * @param	iClient		client whose to get name
 * @param	sName		string to store name
 * @param	iLength		length of string
 * @noreturn
 */
forward void SZF_GetClientName(int iClient, char[] sName, int iLength);

/**
 * Forward called whose client should start as zombie when new round starts
 *
 * @param	iClient		client whose should start as zombie or not
 * @return	Plugin_Handled to force client start zombie, Plugin_Continue otherwise
 */
forward Action SZF_ShouldStartZombie(int iClient);

/**
 * Forward called whenever if plugin needs to know to allow music playing
 *
 * @return	Plugin_Handled to stop music being played, Plugin_Continue otherwise
 */
forward Action SZF_ShouldAllowMusicPlay();

/**
 * Gets current team survivor team is
 *
 * @return	TFTeam of survivor team
 */
native TFTeam SZF_GetSurvivorTeam();

/**
 * Gets current team zombie team is
 *
 * @return	TFTeam of zombie team
 */
native TFTeam SZF_GetZombieTeam();

/**
 * Gets client whose last survivor
 *
 * @return	Client whose last survivor, 0 if theres no last survivors
 */
native int SZF_GetLastSurvivor();

/**
 * Gets client total weapon pickup counts stored in cookies
 *
 * @param	iClient		client whose to get weapon pickup counts
 * @return	Weapon pickup counts
 * @error	Invalid client or client not in game
 */
native int SZF_GetWeaponPickupCount(int iClient);

/**
 * Gets client total rare weapon pickup counts stored in cookies
 *
 * @param	iClient		client whose to get rare weapon pickup counts
 * @return	Rare weapon pickup counts
 * @error	Invalid client or client not in game
 */
native int SZF_GetWeaponRarePickupCount(int iClient);

/**
 * Gets client total weapon callout counts stored in cookies
 *
 * @param	iClient		client whose to get weapon callout counts
 * @return	Weapon callout counts
 * @error	Invalid client or client not in game
 */
native int SZF_GetWeaponCalloutCount(int iClient);

public SharedPlugin __pl_superzombiefortress =
{
	name = "superzombiefortress",
	file = "superzombiefortress.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

public __pl_superzombiefortress_SetNTVOptional()
{
	MarkNativeAsOptional("SZF_GetSurvivorTeam");
	MarkNativeAsOptional("SZF_GetZombieTeam");
	MarkNativeAsOptional("SZF_GetLastSurvivor");
	MarkNativeAsOptional("SZF_GetWeaponPickupCount");
	MarkNativeAsOptional("SZF_GetWeaponRarePickupCount");
	MarkNativeAsOptional("SZF_GetWeaponCalloutCount");
}