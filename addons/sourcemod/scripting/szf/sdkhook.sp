static int g_iOffsetDisguiseCompleteTime;
static float g_flDisguiseCompleteTime;

void SDKHook_OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (StrEqual(sClassname, "prop_dynamic") && g_nRoundState == SZFRoundState_Active)
	{
		SDKHook(iEntity, SDKHook_SpawnPost, Prop_SetSpawnedWeapon);
	}
	else if (StrContains(sClassname, "item_healthkit") == 0 || StrContains(sClassname, "item_ammopack") == 0 || StrEqual(sClassname, "tf_ammo_pack"))
	{
		SDKHook(iEntity, SDKHook_SpawnPost, Pickup_SpawnPost);
		
		if (StrContains(sClassname, "item_healthkit") == 0)
			SDKHook(iEntity, SDKHook_TouchPost, HealthKit_TouchPost);
	}
	else if (StrEqual(sClassname, "tf_projectile_jar_gas"))
	{
		SDKHook(iEntity, SDKHook_SpawnPost, GasProjectile_SpawnPost);
	}
	else if (StrEqual(sClassname, "tf_gas_manager"))
	{
		SDKHook(iEntity, SDKHook_Touch, GasManager_Touch);
		SDKHook(iEntity, SDKHook_EndTouch, GasManager_EndTouch);
	}
	else if (StrEqual(sClassname, "trigger_capture_area"))
	{
		SDKHook(iEntity, SDKHook_StartTouch, CaptureArea_StartTouch);
		SDKHook(iEntity, SDKHook_EndTouch, CaptureArea_EndTouch);
		SDKHook(iEntity, SDKHook_Think, CaptureArea_Think);
		SDKHook(iEntity, SDKHook_ThinkPost, CaptureArea_Think);
	}
}

void SDKHook_HookClient(int iClient)
{
	SDKHook(iClient, SDKHook_Spawn, Client_Spawn);
	SDKHook(iClient, SDKHook_PreThink, Client_PreThink);
	SDKHook(iClient, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKHook(iClient, SDKHook_PostThinkPost, Client_PostThinkPost);
	SDKHook(iClient, SDKHook_Touch, Client_Touch);
	SDKHook(iClient, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKHook(iClient, SDKHook_OnTakeDamagePost, Client_OnTakeDamagePost);
	SDKHook(iClient, SDKHook_OnTakeDamageAlive, Client_OnTakeDamageAlive);
	SDKHook(iClient, SDKHook_GetMaxHealth, Client_GetMaxHealth);
	SDKHook(iClient, SDKHook_WeaponSwitchPost, Client_WeaponSwitchPost);
}

void SDKHook_UnhookClient(int iClient)
{
	SDKUnhook(iClient, SDKHook_Spawn, Client_Spawn);
	SDKUnhook(iClient, SDKHook_PreThink, Client_PreThink);
	SDKUnhook(iClient, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKUnhook(iClient, SDKHook_PostThinkPost, Client_PostThinkPost);
	SDKUnhook(iClient, SDKHook_Touch, Client_Touch);
	SDKUnhook(iClient, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKUnhook(iClient, SDKHook_OnTakeDamagePost, Client_OnTakeDamagePost);
	SDKUnhook(iClient, SDKHook_OnTakeDamageAlive, Client_OnTakeDamageAlive);
	SDKUnhook(iClient, SDKHook_GetMaxHealth, Client_GetMaxHealth);
	SDKUnhook(iClient, SDKHook_WeaponSwitchPost, Client_WeaponSwitchPost);
}

public Action Client_Spawn(int iClient)
{
	// Reset arms so generated weapons don't get the wrong viewmodel
	ViewModel_ResetArms(iClient);
	ViewModel_TakePreference(iClient);
	Classes_SetClient(iClient);
	return Plugin_Continue;
}

public Action Client_PreThink(int iClient)
{
	if (!g_iOffsetDisguiseCompleteTime)
		g_iOffsetDisguiseCompleteTime = FindSendPropInfo("CTFPlayer", "m_unTauntSourceItemID_High") + 4;
	
	g_flDisguiseCompleteTime = GetEntDataFloat(iClient, g_iOffsetDisguiseCompleteTime);
	
	LastStand_OnPreThink(iClient);
	return Plugin_Continue;
}

public void Client_PreThinkPost(int iClient)
{
	UpdateClientCarrying(iClient);
	
	// This should only be changed from reset, e.g. player spawn or banner used
	float flRageMeter = GetEntPropFloat(iClient, Prop_Send, "m_flRageMeter");
	if (g_flBannerMeter[iClient] > flRageMeter)
		g_flBannerMeter[iClient] = flRageMeter;
	
	if (g_flDisguiseCompleteTime && !GetEntDataFloat(iClient, g_iOffsetDisguiseCompleteTime))
		OnClientDisguise(iClient);
	
	WeaponChanges_OnClientThink(iClient);
}

public void Client_PostThinkPost(int iClient)
{
	Stun_OnPostThinkPost(iClient);
	LastStand_OnPostThinkPost(iClient);
}

public Action Client_Touch(int iClient, int iToucher)
{
	if (g_ClientClasses[iClient].callback_touch != INVALID_FUNCTION)
	{
		Call_StartFunction(null, g_ClientClasses[iClient].callback_touch);
		Call_PushCell(iClient);
		Call_PushCell(iToucher);
		Call_Finish();
	}
	
	return Plugin_Continue;
}

public Action Client_OnTakeDamage(int iVictim, int &iAttacker, int &iInflicter, float &flDamage, int &iDamageType, int &iWeapon, float vecForce[3], float vecForcePos[3], int iDamageCustom)
{
	WeaponChanges_OnTakeDamagePre(iVictim, iDamageType);
	LastStand_OnZombieDamagedPre(iVictim, iAttacker);
	
	if (!CanRecieveDamage(iVictim))
		return Plugin_Continue;
	
	Debris debris;
	if (Config_GetDebrisFromEntity(iInflicter, debris) && GetEntPropEnt(iInflicter, Prop_Send, "m_hOwnerEntity") != iAttacker)
		return Plugin_Stop;	// Prevent TF2 game allowing debris to damage victim, we want to handle our own damages
	
	bool bChanged = false;
	
	if (g_ClientClasses[iVictim].callback_damage != INVALID_FUNCTION)
	{
		Call_StartFunction(null, g_ClientClasses[iVictim].callback_damage);
		Call_PushCell(iVictim);
		Call_PushCellRef(iAttacker);
		Call_PushCellRef(iInflicter);
		Call_PushFloatRef(flDamage);
		Call_PushCellRef(iDamageType);
		Call_PushCellRef(iWeapon);
		Call_PushArrayEx(vecForce, sizeof(vecForce), SM_PARAM_COPYBACK);
		Call_PushArrayEx(vecForcePos, sizeof(vecForcePos), SM_PARAM_COPYBACK);
		Call_PushCell(iDamageCustom);
		
		Action action;
		Call_Finish(action);
		if (action >= Plugin_Changed)
			bChanged = true;
	}
	
	if (iVictim != iAttacker)
	{
		if (IsValidLivingClient(iAttacker) && g_ClientClasses[iAttacker].callback_attack != INVALID_FUNCTION)
		{
			Call_StartFunction(null, g_ClientClasses[iAttacker].callback_attack);
			Call_PushCell(iVictim);
			Call_PushCellRef(iAttacker);
			Call_PushCellRef(iInflicter);
			Call_PushFloatRef(flDamage);
			Call_PushCellRef(iDamageType);
			Call_PushCellRef(iWeapon);
			Call_PushArrayEx(vecForce, sizeof(vecForce), SM_PARAM_COPYBACK);
			Call_PushArrayEx(vecForcePos, sizeof(vecForcePos), SM_PARAM_COPYBACK);
			Call_PushCell(iDamageCustom);
			
			Action action;
			Call_Finish(action);
			if (action >= Plugin_Changed)
				bChanged = true;
		}
		
		bool bLastStand = IsValidZombie(iAttacker) && IsLastManStanding(iVictim);
		if (bLastStand && iDamageCustom == TF_CUSTOM_BACKSTAB)
		{
			if (g_nInfected[iAttacker] == Infected_Stalker)
				flDamage = Infected_GetStalkerBackstabDamage(false);
			else
				flDamage = LastStand_GetBackstabDamage(iWeapon);
			
			iDamageType &= ~DMG_CRIT;
			bChanged = true;
		}
		
		if (IsValidZombie(iAttacker) && (flDamage < 300.0 || bLastStand))
		{
			flDamage *= g_cvZombieDamage.FloatValue;
			bChanged = true;
		}
		
		if (IsValidSurvivor(iVictim) && IsValidZombie(iAttacker))
		{
			Sound_Attack(iVictim, iAttacker);
			
			//Taunt kill, backstabs and gunslinger combo punch
			if (!bLastStand && (flDamage >= 300.0
				|| iDamageCustom == TF_CUSTOM_BACKSTAB
				|| iDamageCustom == TF_CUSTOM_TAUNT_GRENADE
				|| (TF2_GetPlayerClass(iAttacker) == TFClass_Engineer && GetEntProp(iAttacker, Prop_Send, "m_iNextMeleeCrit") == MELEE_CRIT)))
			{
				
				if (TF2_IsPlayerInCondition(iVictim, TFCond_Ubercharged) || (IsRazorbackActive(iVictim) && iDamageCustom == TF_CUSTOM_BACKSTAB))
					return Plugin_Continue;
				
				bool bWasStunned = Stun_IsPlayerStunned(iVictim);
				
				bool bStunned;
				if (g_nInfected[iAttacker] == Infected_Stalker)
					bStunned = Stun_StartPlayer(iVictim, 10.0);
				else
					bStunned = Stun_StartPlayer(iVictim);
				
				if (bStunned)
					Forward_OnBackstab(iVictim, iAttacker);
				
				if (g_nInfected[iAttacker] == Infected_Stalker && iDamageCustom == TF_CUSTOM_BACKSTAB)
				{
					flDamage = Infected_GetStalkerBackstabDamage(bWasStunned) * g_cvZombieDamage.FloatValue;
					iDamageType &= ~DMG_CRIT;
				}
				else
				{
					flDamage = 1.0;
				}
				
				bChanged = true;
			}
			
			Sound_PlayInfectedVo(iAttacker, g_nInfected[iAttacker], SoundVo_Attack);
		}
		
		if (IsValidZombie(iVictim))
		{
			//Disable physics force from sentry damage
			if (IsClassname(iInflicter, "obj_sentrygun"))
				iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
		}
	}
	
	if (Stun_IsPlayerStunned(iVictim))
		Stun_Shake(iVictim, vecForce, flDamage * 8.0);
	
	SDKCall_SetSpeed(iVictim);
	
	WeaponChanges_OnTakeDamagePre(iVictim, iDamageType);
	
	if (bChanged)
		return Plugin_Changed;
	
	return Plugin_Continue;
}

public void Client_OnTakeDamagePost(int iVictim, int iAttacker, int iInflicter, float flDamage, int iDamageType, int iWeapon, const float vecForce[3], const float vecForcePos[3], int iDamageCustom)
{
	LastStand_OnZombieDamagedPost(iVictim);
}

public Action Client_OnTakeDamageAlive(int iVictim, int &iAttacker, int &iInflicter, float &flDamage, int &iDamageType, int &iWeapon, float vecForce[3], float vecForcePos[3], int iDamageCustom)
{
	return WeaponChanges_OnTakeDamageAlive(iVictim, flDamage, iDamageType);
}

public Action Client_GetMaxHealth(int iClient, int &iMaxHealth)
{
	if (g_iMaxHealth[iClient] > 0)
	{
		iMaxHealth = g_iMaxHealth[iClient];
		return Plugin_Changed;
	}
	
	if (g_ClientClasses[iClient].iHealth != 0)
	{
		iMaxHealth += g_ClientClasses[iClient].iHealth;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void Client_WeaponSwitchPost(int iClient, int iWeapon)
{
	ViewModel_UpdateClient(iClient);
}

public Action Prop_SetSpawnedWeapon(int iWeapon)
{
	if (!Weapons_IsSpawningExtra())
		SetWeapon(iWeapon);
	
	return Plugin_Continue;
}

public void Pickup_SpawnPost(int iEntity)
{
	int iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	TFTeam nTeam = TFTeam_Unassigned;
	if (iOwner != -1)
		nTeam = view_as<TFTeam>(GetEntProp(iOwner, Prop_Send, "m_iTeamNum"));
	
	if (nTeam == TFTeam_Zombie && IsClassname(iEntity, "tf_ammo_pack"))
	{
		//Remove ammo pack from zombie death and zombie's building destroyed
		RemoveEntity(iEntity);
	}
	else if (iOwner == -1 || nTeam == TFTeam_Survivor || (IsValidClient(iOwner) && GetClientHealth(iOwner) <= 0))
	{
		//Pickup came from map, or created by survivor (sandvich), or owner just died (candy cane). Disallow zombie able to pickup
		SDKHook(iEntity, SDKHook_Touch, Pickup_BlockZombieTouch);
	}
	else if (nTeam == TFTeam_Zombie)
	{
		if (IsClassname(iEntity, "item_healthkit_medium"))	//Lunchbox sandvich
		{
			SDKHook(iEntity, SDKHook_Touch, Pickup_SandvichTouch);
		}
		else if (IsClassname(iEntity, "item_healthkit_small"))	//Lunchbox non-sandvich
		{
			SDKHook(iEntity, SDKHook_Touch, Pickup_BananaTouch);
		}
	}
}

public Action Pickup_BlockZombieTouch(int iEntity, int iToucher)
{
	if (IsValidZombie(iToucher))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action Pickup_SandvichTouch(int iEntity, int iToucher)
{
	//Check if toucher is valid client
	if (!IsValidClient(iToucher))
		return Plugin_Continue;
	
	//Dont allow owner and tank collect sandvich
	int iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if (iOwner == iToucher || g_nInfected[iToucher] == Infected_Tank)
		return Plugin_Handled;
	
	if (IsSurvivor(iToucher))
	{
		//Kill it and deal damage
		RemoveEntity(iEntity);
		DealDamage(iOwner, iToucher, 105.0);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Pickup_BananaTouch(int iEntity, int iToucher)
{
	//Check if toucher is valid client
	if (!IsValidClient(iToucher))
		return Plugin_Continue;
	
	//Dont allow tank collect health
	if (g_nInfected[iToucher] == Infected_Tank)
		return Plugin_Handled;
	
	if (IsSurvivor(iToucher))
	{
		int iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
		
		//Kill it and deal damage
		RemoveEntity(iEntity);
		DealDamage(iOwner, iToucher, 60.0);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void GasProjectile_SpawnPost(int iGasProjectile)
{
	int iOwner = GetEntPropEnt(iGasProjectile, Prop_Send, "m_hOwnerEntity");
	if (!IsValidZombie(iOwner))
		return;
	
	SetEntityRenderMode(iGasProjectile, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iGasProjectile, 0, 255, 0, 255);
	SetEntPropFloat(iGasProjectile, Prop_Send, "m_flModelScale", 1.5);
	
	SetEntityModel(iGasProjectile, SPITTER_SPIT_MODEL);
	for (int i = 0; i < sizeof(g_sSpitterParticles); i++)
		AttachParticle(iGasProjectile, g_sSpitterParticles[i]);
}

public Action GasManager_Touch(int iGasManager, int iClient)
{
	if (IsValidSurvivor(iClient))
	{
		// There a case that user can have gas effect before TF2_OnConditionAdded is called, wait for it to be gone
		if (!TF2_IsPlayerInCondition(iClient, TFCond_Bleeding) && !TF2_IsPlayerInCondition(iClient, TFCond_Gas))
		{
			//Deal bleed instead of gas
			int iOwner = GetEntPropEnt(iGasManager, Prop_Send, "m_hOwnerEntity");
			
			if (GetClientTeam(iClient) != GetClientTeam(iOwner))
				TF2_MakeBleed(iClient, iOwner, 0.5);
		}
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action GasManager_EndTouch(int iGasManager, int iClient)
{
	if (IsValidSurvivor(iClient))
	{
		//Add 5 extra secs of bleed after leaving
		int iOwner = GetEntPropEnt(iGasManager, Prop_Send, "m_hOwnerEntity");
		
		if (GetClientTeam(iClient) != GetClientTeam(iOwner))
		{
			TF2_RemoveCondition(iClient, TFCond_Bleeding);
			TF2_MakeBleed(iClient, iOwner, 5.0);
		}
	}
	
	return Plugin_Continue;
}

public Action CaptureArea_StartTouch(int iEntity, int iClient)
{
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
	{
		int iCP = GetCapturePointFromTrigger(iEntity);
		int iIndex = GetEntProp(iCP, Prop_Data, "m_iPointIndex");
		if (g_iControlPointsInfo[iIndex] != CPState_Capped)	//Check if that capture have not already been captured
			g_iCapturingPoint[iClient] = iIndex;
	}
	
	return Plugin_Continue;
}

public Action CaptureArea_EndTouch(int iEntity, int iClient)
{
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
		g_iCapturingPoint[iClient] = -1;
	
	return Plugin_Continue;
}

public Action CaptureArea_Think(int iEntity)
{
	static int iOffset = -1;
	if (iOffset == -1)
		iOffset = FindDataMapInfo(iEntity, "m_flCapTime");
	
	float flTimeRemaining = GetEntDataFloat(iEntity, iOffset + 4);	// m_fTimeRemaining
	if (!flTimeRemaining || flTimeRemaining >= 0.5)
		return Plugin_Continue;
	
	// CP about to be captured, is there anyone waiting to be tank
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient) && g_nNextInfected[iClient] == Infected_Tank)
			TF2_RespawnPlayer2(iClient);	// Yes, force spawn now
	
	return Plugin_Continue;
}