static int g_iViewModelRef[MAXPLAYERS] = {INVALID_ENT_REFERENCE, ...};

void ViewModel_Create(int iClient, const char[] sModel, const float vecAnglesOffset[3] = NULL_VECTOR, float flHeight = 0.0)
{
	int iViewModel = CreateEntityByName("prop_dynamic");
	if (iViewModel <= MaxClients)
		return;
	
	SetEntPropEnt(iViewModel, Prop_Send, "m_hOwnerEntity", iClient);
	SetEntProp(iViewModel, Prop_Send, "m_nSkin", GetClientTeam(iClient) - 2);
	
	DispatchKeyValue(iViewModel, "model", sModel);
	DispatchKeyValue(iViewModel, "disablereceiveshadows", "0");
	DispatchKeyValue(iViewModel, "disableshadows", "1");
	
	float vecOrigin[3], vecAngles[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	GetClientAbsAngles(iClient, vecAngles);
	
	vecOrigin[2] += flHeight;
	AddVectors(vecAngles, vecAnglesOffset, vecAngles);
	
	TeleportEntity(iViewModel, vecOrigin, vecAngles, NULL_VECTOR);
	DispatchSpawn(iViewModel);
	
	SetVariantString("!activator");
	AcceptEntityInput(iViewModel, "SetParent", GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"));
	
	SDKHook(iViewModel, SDKHook_SetTransmit, ViewModel_SetTransmit);
	
	g_iViewModelRef[iClient] = EntIndexToEntRef(iViewModel);
}

void ViewModel_Hide(int iClient)
{
	if (IsValidEntity(g_iViewModelRef[iClient]))
		SetEntProp(GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"), Prop_Send, "m_fEffects", EF_NODRAW);
}

void ViewModel_SetAnimation(int iClient, const char[] sAnimation)
{
	if (IsValidEntity(g_iViewModelRef[iClient]))
	{
		SetVariantString(sAnimation);
		AcceptEntityInput(g_iViewModelRef[iClient], "SetAnimation");
	}
}

void ViewModel_SetDefaultAnimation(int iClient, const char[] sAnimation)
{
	if (IsValidEntity(g_iViewModelRef[iClient]))
	{
		SetVariantString(sAnimation);
		AcceptEntityInput(g_iViewModelRef[iClient], "SetDefaultAnimation");
	}
}

void ViewModel_Destroy(int iClient)
{
	if (IsValidEntity(g_iViewModelRef[iClient]))
		RemoveEntity(g_iViewModelRef[iClient]);
	
	g_iViewModelRef[iClient] = INVALID_ENT_REFERENCE;
}

public Action ViewModel_SetTransmit(int iViewModel, int iClient)
{
	int iOwner = GetEntPropEnt(iViewModel, Prop_Send, "m_hOwnerEntity");
	if (!IsValidLivingClient(iOwner) || iViewModel != EntRefToEntIndex(g_iViewModelRef[iOwner]))
	{
		//Viewmodel entity no longer valid
		ViewModel_Destroy(iOwner);
		return Plugin_Handled;
	}
	
	//Allow if spectating owner and in firstperson
	if (iClient != iOwner)
	{
		if (GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget") == iOwner && GetEntProp(iClient, Prop_Send, "m_iObserverMode") == OBS_MODE_IN_EYE)
		    return Plugin_Continue;
		
		return Plugin_Handled;
	}
	
	//Allow if client itself and in firstperson
	if (TF2_IsPlayerInCondition(iClient, TFCond_Taunting) || GetEntProp(iClient, Prop_Send, "m_nForceTauntCam"))
		return Plugin_Handled;
	
	return Plugin_Continue;
}