void Native_AskLoad()
{
	CreateNative("SZF_GetSurvivorTeam", Native_GetSurvivorTeam);
	CreateNative("SZF_GetZombieTeam", Native_GetZombieTeam);
	CreateNative("SZF_GetLastSurvivor", Native_GetLastSurvivor);
	CreateNative("SZF_GetWeaponPickupCount", Native_GetWeaponPickupCount);
	CreateNative("SZF_GetWeaponRarePickupCount", Native_GetWeaponRarePickupCount);
	CreateNative("SZF_GetWeaponCalloutCount", Native_GetWeaponCalloutCount);
}

public any Native_GetSurvivorTeam(Handle hPlugin, int iNumParams)
{
	return TFTeam_Survivor;
}

public any Native_GetZombieTeam(Handle hPlugin, int iNumParams)
{
	return TFTeam_Zombie;
}

public any Native_GetLastSurvivor(Handle hPlugin, int iNumParams)
{
	if (!g_bLastSurvivor)
		return 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidLivingSurvivor(iClient))
			return iClient;
	
	return 0;
}

public any Native_GetWeaponPickupCount(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client %d", iClient);
	if (!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	
	return GetCookie(iClient, g_cWeaponsPicked);
}

public any Native_GetWeaponRarePickupCount(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client %d", iClient);
	if (!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	
	return GetCookie(iClient, g_cWeaponsRarePicked);
}

public any Native_GetWeaponCalloutCount(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (iClient <= 0 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client %d", iClient);
	if (!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	
	return GetCookie(iClient, g_cWeaponsCalled);
}
