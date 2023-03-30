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
	}
}

void SDKHook_HookClient(int iClient)
{
	SDKHook(iClient, SDKHook_PreThink, Client_PreThink);
	SDKHook(iClient, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKHook(iClient, SDKHook_Touch, Client_Touch);
	SDKHook(iClient, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKHook(iClient, SDKHook_GetMaxHealth, Client_GetMaxHealth);
}

void SDKHook_UnhookClient(int iClient)
{
	SDKUnhook(iClient, SDKHook_PreThink, Client_PreThink);
	SDKUnhook(iClient, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKUnhook(iClient, SDKHook_Touch, Client_Touch);
	SDKUnhook(iClient, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKUnhook(iClient, SDKHook_GetMaxHealth, Client_GetMaxHealth);
}

public Action Client_PreThink(int iClient)
{
	if (!g_iOffsetDisguiseCompleteTime)
		g_iOffsetDisguiseCompleteTime = FindSendPropInfo("CTFPlayer", "m_unTauntSourceItemID_High") + 4;
	
	g_flDisguiseCompleteTime = GetEntDataFloat(iClient, g_iOffsetDisguiseCompleteTime);
	return Plugin_Continue;
}

public void Client_PreThinkPost(int iClient)
{
	UpdateClientCarrying(iClient);
	
	if (g_flDisguiseCompleteTime && !GetEntDataFloat(iClient, g_iOffsetDisguiseCompleteTime))
		OnClientDisguise(iClient);
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
	if (!CanRecieveDamage(iVictim))
		return Plugin_Continue;
	
	bool bChanged = false;
	
	//Disable fall damage to tank
	if (g_nInfected[iVictim] == Infected_Tank && iDamageType & DMG_FALL)
	{
		flDamage = 0.0;
		bChanged = true;
	}
	
	if (iVictim != iAttacker)
	{
		if (IsValidLivingClient(iAttacker) && flDamage < 300.0)
		{
			//Damage scaling Zombies
			if (IsValidZombie(iAttacker))
				flDamage = flDamage * g_flZombieDamageScale * 0.7; //Default: 0.7
			
			//Damage scaling Survivors
			if (IsValidSurvivor(iAttacker) && !IsClassname(iInflicter, "obj_sentrygun"))
				flDamage /= g_flZombieDamageScale;
			
			bChanged = true;
		}
		
		if (IsValidSurvivor(iVictim) && IsValidZombie(iAttacker))
		{
			Sound_Attack(iVictim, iAttacker);
			
			if (TF2_IsPlayerInCondition(iAttacker, TFCond_CritCola)
				|| TF2_IsPlayerInCondition(iAttacker, TFCond_Buffed)
				|| TF2_IsPlayerInCondition(iAttacker, TFCond_CritHype))
			{
				//Reduce damage from crit amplifying items when active
				flDamage *= 0.85;
				bChanged = true;
			}
			
			//Taunt kill, backstabs and gunslinger combo punch
			if (flDamage >= 300.0
				|| iDamageCustom == TF_CUSTOM_BACKSTAB
				|| iDamageCustom == TF_CUSTOM_TAUNT_GRENADE
				|| (TF2_GetPlayerClass(iAttacker) == TFClass_Engineer && GetEntProp(iAttacker, Prop_Send, "m_iNextMeleeCrit") == MELEE_CRIT))
			{
				
				if (TF2_IsPlayerInCondition(iVictim, TFCond_Ubercharged) || (IsRazorbackActive(iVictim) && iDamageCustom == TF_CUSTOM_BACKSTAB))
					return Plugin_Continue;
				
				bool bStunned;
				if (g_nInfected[iAttacker] == Infected_Stalker)
					bStunned = Stun_StartPlayer(iVictim, 10.0);
				else
					bStunned = Stun_StartPlayer(iVictim);
				
				if (bStunned)
					Forward_OnBackstab(iVictim, iAttacker);
				
				flDamage = 1.0;
				bChanged = true;
			}
			
			Sound_PlayInfectedVo(iAttacker, g_nInfected[iAttacker], SoundVo_Attack);
		}
		
		if (IsValidZombie(iVictim))
		{
			//Tank is immune to knockback
			if (g_nInfected[iVictim] == Infected_Tank)
			{
				ScaleVector(vecForce, 0.0);
				iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
				bChanged = true;
			}
			
			//Disable physics force from sentry damage
			if (IsClassname(iInflicter, "obj_sentrygun"))
				iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
			
			if (IsValidSurvivor(iAttacker))
			{
				if (g_nInfected[iVictim] == Infected_Tank)
				{
					//"SHOOT THAT TANK" voice call
					SetVariantString("IsMvMDefender:1");
					AcceptEntityInput(iAttacker, "AddContext");
					SetVariantString("TLK_MVM_ATTACK_THE_TANK");
					AcceptEntityInput(iAttacker, "SpeakResponseConcept");
					AcceptEntityInput(iAttacker, "ClearContext");
					
					//Don't instantly kill the tank on a backstab
					if (iDamageCustom == TF_CUSTOM_BACKSTAB)
					{
						flDamage = g_iMaxHealth[iVictim]*g_cvTankStab.FloatValue/3.0;
						iDamageType |= DMG_CRIT;
						SetNextAttack(iAttacker, GetGameTime() + 1.25);
					}
					
					g_flDamageDealtAgainstTank[iAttacker] += flDamage;
					ScaleVector(vecForce, 0.0);
					iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
				}
				
				else if (TF2_IsPlayerInCondition(iVictim, TFCond_CritCola)
					|| TF2_IsPlayerInCondition(iVictim, TFCond_Buffed)
					|| TF2_IsPlayerInCondition(iVictim, TFCond_CritHype))
				{
					//Increase damage taken from crit amplifying items when active
					flDamage *= 1.1;
					bChanged = true;
				}
			}
		}
		
		//Check if tank takes damage from map deathpit, if so kill him
		if (g_nInfected[iVictim] == Infected_Tank && MaxClients < iAttacker)
		{
			char strAttacker[32];
			GetEdictClassname(iAttacker, strAttacker, sizeof(strAttacker));
			if (strcmp(strAttacker, "trigger_hurt") == 0 && flDamage >= 450.0)
				ForcePlayerSuicide(iVictim);
		}
	}
	
	if (Stun_IsPlayerStunned(iVictim))
		Stun_Shake(iVictim, vecForce, flDamage * 8.0);
	
	SDKCall_SetSpeed(iVictim);
	
	if (bChanged)
		return Plugin_Changed;
	
	return Plugin_Continue;
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

public Action Prop_SetSpawnedWeapon(int iWeapon)
{
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
			//Dont allow anyone touch sandvich for first 3 seconds
			SDKHook(iEntity, SDKHook_Touch, Pickup_BlockTouch);
			CreateTimer(3.0, Timer_EnableSandvichTouch, EntIndexToEntRef(iEntity));
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

public Action Pickup_BlockTouch(int iEntity, int iToucher)
{
	return Plugin_Handled;
}

public Action Timer_EnableSandvichTouch(Handle hTimer, int iRef)
{
	int iEntity = EntRefToEntIndex(iRef);
	if (!IsValidEntity(iEntity))
		return Plugin_Continue;
	
	SDKUnhook(iEntity, SDKHook_Touch, Pickup_BlockTouch);
	SDKHook(iEntity, SDKHook_Touch, Pickup_SandvichTouch);
	
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
		DealDamage(iOwner, iToucher, 55.0);
		
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
		DealDamage(iOwner, iToucher, 30.0);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action GasManager_Touch(int iGasManager, int iClient)
{
	if (IsValidSurvivor(iClient))
	{
		if (!TF2_IsPlayerInCondition(iClient, TFCond_Bleeding))
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
	if (!IsClassname(iEntity, "trigger_capture_area"))
		return Plugin_Continue;
	
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
	{
		char sTriggerName[128];
		GetEntPropString(iEntity, Prop_Data, "m_iszCapPointName", sTriggerName, sizeof(sTriggerName));	//Get trigger cap name
		
		int i = -1;
		while ((i = FindEntityByClassname(i, "team_control_point")) != -1)	//find team_control_point
		{
			char sPointName[128];
			GetEntPropString(i, Prop_Data, "m_iName", sPointName, sizeof(sPointName));
			if (strcmp(sPointName, sTriggerName, false) == 0)	//Check if trigger cap is the same as team_control_point
			{
				int iIndex = GetEntProp(i, Prop_Data, "m_iPointIndex");	//Get his index
				
				for (int j = 0; j < g_iControlPoints; j++)
					if (g_iControlPointsInfo[j][0] == iIndex && g_iControlPointsInfo[j][1] != 2)	//Check if that capture have not already been captured
						g_iCapturingPoint[iClient] = iIndex;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action CaptureArea_EndTouch(int iEntity, int iClient)
{
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
		g_iCapturingPoint[iClient] = -1;
	
	return Plugin_Continue;
}