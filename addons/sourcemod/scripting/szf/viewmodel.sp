char g_sViewModelsArms[][PLATFORM_MAX_PATH] = {
	"",
	"models/weapons/c_models/c_scout_arms.mdl",
	"models/weapons/c_models/c_sniper_arms.mdl",
	"models/weapons/c_models/c_soldier_arms.mdl",
	"models/weapons/c_models/c_demo_arms.mdl",
	"models/weapons/c_models/c_medic_arms.mdl",
	"models/weapons/c_models/c_heavy_arms.mdl",
	"models/weapons/c_models/c_pyro_arms.mdl",
	"models/weapons/c_models/c_spy_arms.mdl",
	"models/weapons/c_models/c_engineer_arms.mdl",
};

static bool g_bCustomThisLife[MAXPLAYERS + 1] = {true, ...};

void ViewModel_TakePreference(int iClient)
{
	g_bCustomThisLife[iClient] = g_bCustomViewModels[iClient];
}

void ViewModel_UpdateClient(int iClient)
{
	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	
	if (g_ClientClasses[iClient].bThirdperson)
	{
		ViewModel_RemoveWearable(iClient);
		AddEntityEffect(iViewModel, EF_NODRAW);
	}
	else if (!g_ClientClasses[iClient].sViewModel[0] || !g_bCustomThisLife[iClient])
	{
		ViewModel_RemoveWearable(iClient);
		
		if (g_ClientClasses[iClient].sViewModel[0])
		{
			if (iViewModel != INVALID_ENT_REFERENCE && GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") != INVALID_ENT_REFERENCE)
				RemoveEntityEffect(iViewModel, EF_NODRAW);
			
			ViewModel_SetForeignWeaponArms(iClient, iViewModel);
		}
	}
	else if (!g_ClientClasses[iClient].bViewModelAnim)
	{
		// Create a viewmodel for arm, and another for each weapons
		
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
		
		// Create arm
		if (ViewModel_Get(iClient, iArmsModelIndex, INVALID_ENT_REFERENCE) == INVALID_ENT_REFERENCE)
			ViewModels_CreateWearable(iClient, iArmsModelIndex, INVALID_ENT_REFERENCE);
		
		// Create weapons
		for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
		{
			int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
			if (iWeapon == INVALID_ENT_REFERENCE)
				continue;
			
			int iWeaponModelIndex = GetEntProp(iWeapon, Prop_Send, "m_iWorldModelIndex");
			iWearable = ViewModel_Get(iClient, iWeaponModelIndex, iWeapon);
			if (iWearable == INVALID_ENT_REFERENCE)
				ViewModels_CreateWearable(iClient, iWeaponModelIndex, iWeapon);
			else
				RemoveEntityEffect(iWearable, EF_NODRAW);	// may've been hidden from weapon switching
		}
		
		AddEntityEffect(iViewModel, EF_NODRAW);
	}
	else
	{
		ViewModel_RemoveWearable(iClient);
		
		SetEntityModel(iViewModel, g_ClientClasses[iClient].sViewModel);
		RemoveEntityEffect(iViewModel, EF_NODRAW);
		
		int iModelIndex = GetModelIndex(g_ClientClasses[iClient].sViewModel);
		
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		if (iWeapon != INVALID_ENT_REFERENCE)
		{
			SetEntityModel(iWeapon, g_ClientClasses[iClient].sViewModel);
			SetEntProp(iWeapon, Prop_Send, "m_iViewModelIndex", iModelIndex);
			SetEntProp(iWeapon, Prop_Send, "m_nCustomViewmodelModelIndex", iModelIndex);
			AddEntityEffect(iWeapon, EF_NODRAW);
		}
	}
}

static void ViewModel_SetForeignWeaponArms(int iClient, int iViewModel)
{
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == INVALID_ENT_REFERENCE || iViewModel == INVALID_ENT_REFERENCE)
		return;
	
	int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	if (TF2Econ_GetItemLoadoutSlot(iIndex, TF2_GetPlayerClass(iClient)) >= 0)
		return;
	
	for (int i = 1; i < sizeof(g_sViewModelsArms); i++)
	{
		if (!g_sViewModelsArms[i][0] || TF2Econ_GetItemLoadoutSlot(iIndex, view_as<TFClassType>(i)) < 0)
			continue;
		
		int iModelIndex = PrecacheModel(g_sViewModelsArms[i]);
		
		SetEntityModel(iViewModel, g_sViewModelsArms[i]);
		RemoveEntityEffect(iViewModel, EF_NODRAW);
		
		SetEntityModel(iWeapon, g_sViewModelsArms[i]);
		SetEntProp(iWeapon, Prop_Send, "m_iViewModelIndex", iModelIndex);
		SetEntProp(iWeapon, Prop_Send, "m_nCustomViewmodelModelIndex", iModelIndex);
		AddEntityEffect(iWeapon, EF_NODRAW);
		return;
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
	
	if (iWeapon != INVALID_ENT_REFERENCE)
		SetEntPropEnt(iWeapon, Prop_Send, "m_hExtraWearableViewModel", iWearable);
	
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
		
		if (GetEntPropEnt(iWearable, Prop_Send, "m_hWeaponAssociatedWith") != iWeapon)
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

void ViewModel_ResetArms(int iClient)
{
	if (!g_ClientClasses[iClient].bViewModelAnim)
		return;	// No need to set if we didn't override it to begin with
	
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	if (!g_sViewModelsArms[nClass][0])
		return;
	
	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (iViewModel != INVALID_ENT_REFERENCE)
		SetEntityModel(iViewModel, g_sViewModelsArms[nClass]);
	
}

void ViewModel_SetAnimation(int iClient, const char[] sActivity)
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "local s = self.LookupSequence(`%s`); if (s >= 0) self.ResetSequence(s)", sActivity);	// SetSequence/ResetSequence
	SetVariantString(sBuffer);
	AcceptEntityInput(GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"), "RunScriptCode");
}
