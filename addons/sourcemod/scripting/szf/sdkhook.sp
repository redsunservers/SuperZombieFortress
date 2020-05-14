void SDKHook_HookClient(int iClient)
{
	SDKHook(iClient, SDKHook_PreThinkPost, Client_PreThinkPost);
	SDKHook(iClient, SDKHook_Touch, Client_Touch);
	SDKHook(iClient, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKHook(iClient, SDKHook_GetMaxHealth, Client_GetMaxHealth);
}

void SDKHook_HookPickup(int iEntity)
{
	SDKHook(iEntity, SDKHook_StartTouch, Pickup_Touch);
	SDKHook(iEntity, SDKHook_Touch, Pickup_Touch);
}

void SDKHook_HookSandvich(int iEntity)
{
	SDKHook(iEntity, SDKHook_Touch, Sandvich_TouchBlock);
	CreateTimer(3.0, Timer_EnableSandvichTouch, EntIndexToEntRef(iEntity));
}

void SDKHook_HookBanana(int iEntity)
{
	SDKHook(iEntity, SDKHook_Touch, Banana_Touch);
}

void SDKHook_HookGasManager(int iEntity)
{
	SDKHook(iEntity, SDKHook_Touch, GasManager_Touch);
}

void SDKHook_HookCaptureArea(int iEntity)
{
	SDKHook(iEntity, SDKHook_StartTouch, CaptureArea_StartTouch);
	SDKHook(iEntity, SDKHook_EndTouch, CaptureArea_EndTouch);
}

public Action Timer_EnableSandvichTouch(Handle hTimer, int iRef)
{
	int iEntity = EntRefToEntIndex(iRef);
	if (!IsValidEntity(iEntity))
		return;
	
	SDKUnhook(iEntity, SDKHook_Touch, Sandvich_TouchBlock);
	SDKHook(iEntity, SDKHook_Touch, OnSandvichTouch);
}

public void Client_PreThinkPost(int iClient)
{
	if (!g_bEnabled)
		return;
	
	UpdateClientCarrying(iClient);
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
}

public Action Client_OnTakeDamage(int iVictim, int &iAttacker, int &iInflicter, float &flDamage, int &iDamageType, int &iWeapon, float vecForce[3], float vecForcePos[3], int iDamageCustom)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (!CanRecieveDamage(iVictim))
		return Plugin_Continue;
	
	bool bChanged = false;
	if (IsValidClient(iVictim) && IsValidClient(iAttacker))
	{
		if (GetClientTeam(iVictim) != GetClientTeam(iAttacker))
			EndGracePeriod();
	}
	
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
			{
				float flMoraleBonus = fMin(GetMorale(iAttacker) * 0.005, 0.25); //50 morale: 0.25
				flDamage = flDamage / g_flZombieDamageScale * (1.1 + flMoraleBonus); //Default: 1.1
			}
			
			//If backstabbed
			if (g_bBackstabbed[iVictim])
			{
				if (flDamage > STUNNED_DAMAGE_CAP)
					flDamage = STUNNED_DAMAGE_CAP;
				
				iDamageType &= ~DMG_CRIT;
			}
			
			bChanged = true;
		}
		
		if (IsValidSurvivor(iVictim) && IsValidZombie(iAttacker))
		{
			Sound_Attack(iVictim, iAttacker);
			
			if (TF2_GetPlayerClass(iVictim) == TFClass_Scout)
			{
				flDamage *= 0.825;
				bChanged = true;
			}
			
			if (TF2_IsPlayerInCondition(iAttacker, TFCond_CritCola)
				|| TF2_IsPlayerInCondition(iAttacker, TFCond_Buffed)
				|| TF2_IsPlayerInCondition(iAttacker, TFCond_CritHype))
			{
				//Reduce damage from crit amplifying items when active
				flDamage *= 0.85;
				bChanged = true;
			}
			
			//Taunt kill, backstabs and highly critical damage
			if (flDamage >= 300.0 || iDamageCustom == TF_CUSTOM_COMBO_PUNCH)
			{
				if (!g_bBackstabbed[iVictim])
				{
					if (IsRazorbackActive(iVictim) && iDamageCustom == TF_CUSTOM_BACKSTAB)
						return Plugin_Continue;
					
					if (g_nInfected[iAttacker] == Infected_Stalker)
						SetEntityHealth(iVictim, GetClientHealth(iVictim) - 50);
					else
						SetEntityHealth(iVictim, GetClientHealth(iVictim) - 20);
					
					AddMorale(iVictim, -5);
					SetBackstabState(iVictim, BACKSTABDURATION_FULL, 0.25);
					SetNextAttack(iAttacker, GetGameTime() + 1.25);
					
					Forward_OnBackstab(iVictim, iAttacker);
					
					flDamage = 1.0;
					bChanged = true;
				}
				
				else
				{
					flDamage = STUNNED_DAMAGE_CAP;
					bChanged = true;
				}
			}
			
			Sound_PlayInfectedVo(iAttacker, g_nInfected[iAttacker], SoundVo_Attack);
		}
		
		if (IsValidZombie(iVictim))
		{
			// zero down physics force, disable physics force
			switch (TF2_GetPlayerClass(iVictim))
			{
				case TFClass_Soldier:
				{
					ScaleVector(vecForce, 0.0);
					iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
					bChanged = true;
				}
				// cap damage to 150
				case TFClass_Heavy:
				{
					if (flDamage > 150.0 && flDamage <= 500.0) flDamage = 150.0;
					ScaleVector(vecForce, 0.0);
					iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
					bChanged = true;
				}
			}
			
			//Disable physics force
			if (IsClassname(iInflicter, "obj_sentrygun"))
				iDamageType |= DMG_PREVENT_PHYSICS_FORCE;
			
			if (IsValidSurvivor(iAttacker))
			{
				if (g_nInfected[iVictim] == Infected_Tank)
				{
					//"SHOOT THAT TANK" voice call
					if (g_flDamageDealtAgainstTank[iAttacker] == 0)
					{
						SetVariantString("randomnum:100");
						AcceptEntityInput(iAttacker, "AddContext");
						SetVariantString("IsMvMDefender:1");
						AcceptEntityInput(iAttacker, "AddContext");
						SetVariantString("TLK_MVM_ATTACK_THE_TANK");
						AcceptEntityInput(iAttacker, "SpeakResponseConcept");
						AcceptEntityInput(iAttacker, "ClearContext");
					}
					
					//Don't instantly kill the tank on a backstab
					if (iDamageCustom == TF_CUSTOM_BACKSTAB)
					{
						flDamage = g_iMaxHealth[iVictim]/11.0;
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
	
	if (bChanged)
		return Plugin_Changed;
	
	return Plugin_Continue;
}

public Action Client_GetMaxHealth(int iClient, int &iMaxHealth)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (g_iMaxHealth[iClient] > 0)
	{
		iMaxHealth = g_iMaxHealth[iClient];
		return Plugin_Changed;
	}
	
	if (g_ClientClasses[iClient].iHealth > 0)
	{
		iMaxHealth = g_ClientClasses[iClient].iHealth;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Pickup_Touch(int iEntity, int iClient)
{
	//If picker is a zombie and entity has no owner (sandvich)
	if (IsValidZombie(iClient) && GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity") == -1)
	{
		char sClassname[32];
		GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
		if (StrContains(sClassname, "item_ammopack") != -1
		|| StrContains(sClassname, "item_healthkit") != -1
		|| StrEqual(sClassname, "tf_ammo_pack"))
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action Sandvich_TouchBlock(int iEntity, int iClient)
{
	return Plugin_Handled;
}

public Action OnSandvichTouch(int iEntity, int iClient)
{
	int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
	int iToucher = iClient;
	
	//Check if both owner and toucher is valid
	if (!IsValidClient(iOwner) || !IsValidClient(iToucher))
		return Plugin_Continue;
	
	//Dont allow owner and tank collect sandvich
	if (iOwner == iToucher || g_nInfected[iToucher] == Infected_Tank)
		return Plugin_Handled;
	
	if (GetClientTeam(iToucher) != GetClientTeam(iOwner))
	{
		//Disable Sandvich and kill it
		SetEntProp(iEntity, Prop_Data, "m_bDisabled", 1);
		RemoveEntity(iEntity);
		
		DealDamage(iOwner, iToucher, 55.0);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Banana_Touch(int iEntity, int iClient)
{
	int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
	int iToucher = iClient;
	
	//Check if both owner and toucher is valid
	if (!IsValidClient(iOwner) || !IsValidClient(iToucher))
		return Plugin_Continue;
	
	//Dont allow tank to collect health
	if (g_nInfected[iToucher] == Infected_Tank)
		return Plugin_Handled;
	
	if (GetClientTeam(iToucher) != GetClientTeam(iOwner))
	{
		//Disable Sandvich and kill it
		SetEntProp(iEntity, Prop_Data, "m_bDisabled", 1);
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
			TF2_MakeBleed(iClient, iOwner, 0.5);
		}
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action CaptureArea_StartTouch(int iEntity, int iClient)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
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
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && IsSurvivor(iClient))
		g_iCapturingPoint[iClient] = -1;
	
	return Plugin_Continue;
}