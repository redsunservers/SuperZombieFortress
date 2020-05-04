static Handle g_hSDKCallGetMaxHealth;
static Handle g_hSDKCallGetMaxAmmo;
static Handle g_hSDKCallEquipWearable;
static Handle g_hSDKCallPlaySpecificSequence;
static Handle g_hSDKCallGetEquippedWearable;
static Handle g_hSDKCallGiveNamedItem;
static Handle g_hSDKCallGetLoadoutItem;
static Handle g_hSDKCallGetBaseEntity;

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
	PrepSDKCall_SetFromConf(hSZF, SDKConf_Signature, "CTFPlayer::PlaySpecificSequence");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKCallPlaySpecificSequence = EndPrepSDKCall();
	if (!g_hSDKCallPlaySpecificSequence)
		LogMessage("Failed to create call: CTFPlayer::PlaySpecificSequence");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hSZF, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKCallGetEquippedWearable = EndPrepSDKCall();
	if (!g_hSDKCallGetEquippedWearable)
		LogError("Failed to create call: CTFPlayer::GetEquippedWearableForLoadoutSlot!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hSZF, SDKConf_Virtual, "CTFPlayer::GiveNamedItem");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	g_hSDKCallGiveNamedItem = EndPrepSDKCall();
	if (!g_hSDKCallGiveNamedItem)
		LogError("Failed to create call: CTFPlayer::GiveNamedItem!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hSZF, SDKConf_Signature, "CTFPlayer::GetLoadoutItem");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	g_hSDKCallGetLoadoutItem = EndPrepSDKCall();
	if (!g_hSDKCallGetLoadoutItem)
		LogError("Failed to create call: CTFPlayer::GetLoadoutItem!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hSZF, SDKConf_Virtual, "CBaseEntity::GetBaseEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKCallGetBaseEntity = EndPrepSDKCall();
	if (!g_hSDKCallGetBaseEntity)
		LogError("Failed to create call: CBaseEntity::GetBaseEntity!");
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

bool SDKCall_PlaySpecificSequence(int iClient, const char[] sAnimationName)
{
	return SDKCall(g_hSDKCallPlaySpecificSequence, iClient, sAnimationName);
}

int SDKCall_GetEquippedWearable(int iClient, int iSlot)
{
	return SDKCall(g_hSDKCallGetEquippedWearable, iClient, iSlot);
}

Address SDKCall_GiveNamedItem(int iClient, const char[] sClassname, int iSubType, Address pItem, bool bForce = false, bool bSkipHook = true)
{
	g_bSkipGiveNamedItemHook = bSkipHook;
	return SDKCall(g_hSDKCallGiveNamedItem, iClient, sClassname, iSubType, pItem, bForce);
}

/*
 * Returns a pointer to CEconItemView
 */
Address SDKCall_GetLoadoutItem(int iClient, TFClassType iClass, int iSlot)
{
	return SDKCall(g_hSDKCallGetLoadoutItem, iClient, iClass, iSlot, false);
}

int SDKCall_GetBaseEntity(Address pEnt)
{
	return SDKCall(g_hSDKCallGetBaseEntity, pEnt);
}
