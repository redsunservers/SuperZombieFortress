#if defined _superzombiefortress_included
	#endinput
#endif
#define _superzombiefortress_included

enum WeaponRarity
{
	WeaponRarity_Common,
	WeaponRarity_Uncommon,
	WeaponRarity_Rare,
	WeaponRarity_Static,
	WeaponRarity_Pickup,
};

/**
 * Forward called when a last survivor is triggered
 *
 * @param	iClient		Client whose the last survivor
 * @noreturn
 */
forward void SZF_OnLastSurvivor(int iClient);

/**
 * Forward called when attacker backstabbed victim
 *
 * @param	iVictim		Client whose got backstabbed
 * @param	iAttacker	Client whose backstabbed victim
 * @noreturn
 */
forward void SZF_OnBackstab(int iVictim, int iAttacker);

/**
 * Forward called when a tank spawns
 *
 * @param	iTank		Client whose the tank who spawned
 * @noreturn
 */
forward void SZF_OnTankSpawn(int iTank);

/**
 * Forward called when a tank dies
 *
 * @param	iTank		Client whose the tank who died
 * @param	iMVP		Client whose dealt the most damage to tank, 0 if nobody dealt damage to tank or invalid client
 * @param	iDamage		Damage amount from client whose dealt the most damage to tank
 * @noreturn
 */
forward void SZF_OnTankDeath(int iTank, int iMVP, int iDamage);

/**
 * Forward called when zombie use quick respawn to become special infected
 *
 * @param	iClient		Client whose use the quick respawn to become special infected
 * @noreturn
 */
forward void SZF_OnQuickSpawnAsSpecialInfected(int iClient);

/**
 * Forward called when charger charged to stun a survivor
 *
 * @param	iCharger	Client whose the charger to stun a survivor
 * @param	iVictim		Client whose the victim stunned from the charger
 * @noreturn
 */
forward void SZF_OnChargerHit(int iCharger, int iVictim);

/**
 * Forward called when hunter pounced to stun a survivor
 *
 * @param	iHunter		Client whose the hunter to stun a survivor
 * @param	iVictim		Client whose the victim stunned from the hunter
 * @noreturn
 */
forward void SZF_OnHunterHit(int iHunter, int iVictim);

/**
 * Forward called when a boomer explodes
 *
 * @param	iBoomer		Client whose the boomer explode
 * @param	iClients	Array of clients whose jarated from boomer
 * @param	iLength		Amount of clients jarated from boomer
 * @noreturn
 */
forward void SZF_OnBoomerExplode(int iBoomer, int iClients[MAXPLAYERS], int iLength);

/**
 * Forward called when survivor picked up a weapon
 *
 * @param	iClient		Client whose picked up the weapon
 * @param	iWeapon		Weapon entity whose picked up
 * @param	rarity		Rarity of the weapon
 * @noreturn
 */
forward void SZF_OnWeaponPickup(int iClient, int iWeapon, WeaponRarity rarity);

/**
 * Forward called when survivor called a rare weapon
 *
 * @param	iClient		Client whose called a rare weapon
 * @noreturn
 */
forward void SZF_OnWeaponCallout(int iClient);

/**
 * Forward called when plugin need a client name to display in chat to override default name and color
 * plugin uses morecolors.inc to display chat with colors
 *
 * @param	iClient		Client whose to get name
 * @param	sName		String to store name
 * @param	iLength		Length of string
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
 * Forward called when survivor is about to pick up a weapon
 *
 * @param	iClient		Client whose picked up the weapon
 * @param	iTarget		Prop entity whose picked up
 * @param	rarity		Rarity of the weapon
 * @return	Plugin_Handled to prevent picking up the weapon, Plugin_Stop to also prevent calling out rare weapons, Plugin_Continue otherwise
 */
forward Action SZF_ShouldPickupWeapon(int iClient, int iTarget, WeaponRarity rarity);

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
 * @param	iClient		Client whose to get weapon pickup counts
 * @return	Weapon pickup counts
 * @error	Invalid client or client not in game
 */
native int SZF_GetWeaponPickupCount(int iClient);

/**
 * Gets client total rare weapon pickup counts stored in cookies
 *
 * @param	iClient		Client whose to get rare weapon pickup counts
 * @return	Rare weapon pickup counts
 * @error	Invalid client or client not in game
 */
native int SZF_GetWeaponRarePickupCount(int iClient);

/**
 * Gets client total weapon callout counts stored in cookies
 *
 * @param	iClient		Client whose to get weapon callout counts
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

public void __pl_superzombiefortress_SetNTVOptional()
{
	MarkNativeAsOptional("SZF_GetSurvivorTeam");
	MarkNativeAsOptional("SZF_GetZombieTeam");
	MarkNativeAsOptional("SZF_GetLastSurvivor");
	MarkNativeAsOptional("SZF_GetWeaponPickupCount");
	MarkNativeAsOptional("SZF_GetWeaponRarePickupCount");
	MarkNativeAsOptional("SZF_GetWeaponCalloutCount");
}