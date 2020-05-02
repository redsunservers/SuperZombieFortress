static Handle g_hSDKCallGetMaxHealth;
static Handle g_hSDKCallGetMaxAmmo;
static Handle g_hSDKCallEquipWearable;
static Handle g_hSDKCallGetEquippedWearable;

void SDKCall_Init(GameData hSDKHooks, GameData hTF2, GameData hSZF)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hSDKHooks, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKCallGetMaxHealth = EndPrepSDKCall();
	if (!g_hSDKCallGetMaxHealth)
		LogError("Failed to create call: CTFPlayer::GetMaxHealth!");
	
	int iRemoveWearableOffset = hTF2.GetOffset("RemoveWearable");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(iRemoveWearableOffset-1);// Assume EquipWearable is always behind RemoveWearable
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKCallEquipWearable = EndPrepSDKCall();
	if (!g_hSDKCallEquipWearable)
		LogError("Failed to create call: CBasePlayer::EquipWearable!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hSZF, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKCallGetMaxAmmo = EndPrepSDKCall();
	if (!g_hSDKCallGetMaxAmmo)
		LogError("Failed to create call: CTFPlayer::GetMaxAmmo!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hSZF, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKCallGetEquippedWearable = EndPrepSDKCall();
	if (!g_hSDKCallGetEquippedWearable)
		LogError("Failed to create call: CTFPlayer::GetEquippedWearableForLoadoutSlot!");
}

int SDKCall_GetMaxHealth(int iClient)
{
	return SDKCall(g_hSDKCallGetMaxHealth, iClient);
}

void SDKCall_EquipWearable(int iClient, int iWearable)
{
	SDKCall(g_hSDKCallEquipWearable, iClient, iWearable);
}

int SDKCall_GetMaxAmmo(int iClient, int iSlot)
{
	return SDKCall(g_hSDKCallGetMaxAmmo, iClient, iSlot, -1);
}

int SDKCall_GetEquippedWearable(int iClient, int iSlot)
{
	return SDKCall(g_hSDKCallGetEquippedWearable, iClient, iSlot);
}
