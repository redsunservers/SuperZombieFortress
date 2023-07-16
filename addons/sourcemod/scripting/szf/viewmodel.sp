void ViewModel_UpdateClient(int iClient)
{
	if (!g_ClientClasses[iClient].sViewModel[0])
	{
		ViewModel_RemoveWearable(iClient);
	}
	else if (!g_ClientClasses[iClient].bViewModelAnim)
	{
		// Create 2 viewmodels for each weapons, one for arms and other for weapons
		
		// Cleanup any unneeded viewmodels
		int iArmsModelIndex = GetModelIndex(g_ClientClasses[iClient].sViewModel);
		
		int iWearable = INVALID_ENT_REFERENCE;
		while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable_vm")) != INVALID_ENT_REFERENCE)
		{
			if (GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") != iClient)
				continue;
			
			int iModelIndex = GetEntProp(iWearable, Prop_Send, "m_nModelIndex");
			if (iModelIndex == iArmsModelIndex)
				continue;
			
			int iWeapon = GetEntPropEnt(iWearable, Prop_Send, "m_hWeaponAssociatedWith");
			if (iWeapon == INVALID_ENT_REFERENCE || GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") != iClient)
			{
				RemoveEntity(iWearable);
				continue;
			}
			
			if (iModelIndex == GetEntProp(iWeapon, Prop_Send, "m_iWorldModelIndex"))
				continue;
			
			RemoveEntity(iWearable);
		}
		
		if (ViewModel_Get(iClient, iArmsModelIndex, INVALID_ENT_REFERENCE) == INVALID_ENT_REFERENCE)
			ViewModels_CreateWearable(iClient, iArmsModelIndex, INVALID_ENT_REFERENCE);
		
		for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
		{
			int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
			if (iWeapon == INVALID_ENT_REFERENCE)
				continue;
			
			int iWeaponModelIndex = GetEntProp(iWeapon, Prop_Send, "m_iWorldModelIndex");
			if (ViewModel_Get(iClient, iWeaponModelIndex, iWeapon) == INVALID_ENT_REFERENCE)
				ViewModels_CreateWearable(iClient, iWeaponModelIndex, iWeapon);
		}
		
		AddEntityEffect(GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"), EF_NODRAW);
	}
	else
	{
		ViewModel_RemoveWearable(iClient);
		
		int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
		SetEntityModel(iViewModel, g_ClientClasses[iClient].sViewModel);
		RemoveEntityEffect(iViewModel, EF_NODRAW);
		
		int iModelIndex = GetModelIndex(g_ClientClasses[iClient].sViewModel);
		
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		SetEntityModel(iWeapon, g_ClientClasses[iClient].sViewModel);
		SetEntProp(iWeapon, Prop_Send, "m_iViewModelIndex", iModelIndex);
		SetEntProp(iWeapon, Prop_Send, "m_nCustomViewmodelModelIndex", iModelIndex);
		AddEntityEffect(iWeapon, EF_NODRAW);
	}
}

int ViewModels_CreateWearable(int iClient, int iModelIndex, int iWeapon)
{
	int iWearable = CreateEntityByName("tf_wearable_vm");
	
	float vecOrigin[3], vecAngles[3];
	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", vecOrigin);
	GetEntPropVector(iClient, Prop_Send, "m_angRotation", vecAngles);
	TeleportEntity(iWearable, vecOrigin, vecAngles, NULL_VECTOR);
	
	SetEntProp(iWearable, Prop_Send, "m_bValidatedAttachedEntity", true);
	SetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity", iClient);
	SetEntProp(iWearable, Prop_Send, "m_iTeamNum", GetClientTeam(iClient));
	SetEntProp(iWearable, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	SetEntPropEnt(iWearable, Prop_Send, "m_hWeaponAssociatedWith", iWeapon);
	
	SetEntProp(iWearable, Prop_Send, "m_nModelIndex", iModelIndex);
	DispatchSpawn(iWearable);
	
	SetVariantString("!activator");
	AcceptEntityInput(iWearable, "SetParent", GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"));
	
	return EntIndexToEntRef(iWearable);
}

int ViewModel_Get(int iClient, int iModelIndex, int iWeapon)
{
	int iWearable = INVALID_ENT_REFERENCE;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable_vm")) != INVALID_ENT_REFERENCE)
	{
		if (GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") != iClient)
			continue;
		
		if (GetEntProp(iWearable, Prop_Send, "m_nModelIndex") != iModelIndex)
			continue;
		
		if (GetEntProp(iWearable, Prop_Send, "m_hWeaponAssociatedWith") != iWeapon)
			continue;
		
		return iWearable;
	}
	
	return iWearable;
}

void ViewModel_RemoveWearable(int iClient)
{
	int iWearable = INVALID_ENT_REFERENCE;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable_vm")) != INVALID_ENT_REFERENCE)
		if (GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == iClient)
			RemoveEntity(iWearable);
}

void ViewModel_SetAnimation(int iClient, const char[] sActivity)
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "self.ResetSequence(self.LookupSequence(`%s`))", sActivity);	// SetSequence/ResetSequence
	SetVariantString(sBuffer);
	AcceptEntityInput(GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"), "RunScriptCode");
}
