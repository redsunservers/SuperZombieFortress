public void Menu_PrintMain(int iClient)
{
	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "Super Zombie Fortress - %s.%s", PLUGIN_VERSION, PLUGIN_VERSION_REVISION);
	
	Panel panel = new Panel();
	panel.SetTitle(sBuffer);
	panel.DrawItem(" Overview");
	panel.DrawItem(" Team: Survivors");
	panel.DrawItem(" Team: Infected");
	panel.DrawItem(" Classes: Survivors");
	panel.DrawItem(" Classes: Infected");
	panel.DrawItem(" Classes: Infected (Special)");
	panel.DrawItem("Exit");
	panel.Send(iClient, Menu_HandleHelp, 30);
	delete panel;
}

public int Menu_HandleHelp(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	if (action == MenuAction_Select)
	{
		switch (iSelect)
		{
			case 1: Menu_PrintOverview(iClient);
			case 2: Menu_PrintTeam(iClient, TFTeam_Survivor);
			case 3: Menu_PrintTeam(iClient, TFTeam_Zombie);
			case 4: Menu_PrintSurClass(iClient);
			case 5: Menu_PrintZomClass(iClient);
			case 6: Menu_PrintZomSpecial(iClient);
			default: return;
		}
	}
}

//Main.Help.Overview Menus
public void Menu_PrintOverview(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Overview");
	panel.DrawText("-------------------------------------------");
	panel.DrawText("Survivors must survive the endless hoarde of Infected.");
	panel.DrawText("When a Survivor dies, they join the Zombie team and play as a Zombie.");
	panel.DrawText("Zombies need to work together to take down the survivors.");
	panel.DrawText("Survivor gain access to morale and weapon pickups, while zombies gain access to special infected.");
	panel.DrawText("-------------------------------------------");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Menu_HandleOverview, 10);
	delete panel;
}

public int Menu_HandleOverview(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	if (action == MenuAction_Select)
	{
		switch (iSelect)
		{
			case 1: Menu_PrintMain(iClient);
			default: return;
		}
	}
}

//Main.Help.Team Menus
public void Menu_PrintTeam(int iClient, TFTeam nTeam)
{
	Panel panel = new Panel();
	if (nTeam == TFTeam_Survivor)
	{
		panel.SetTitle("Survivors");
		panel.DrawText("-------------------------------------------");
		panel.DrawText("Survivors consist of Soldiers, Pyros, Demoman, Medics, Engineers and Snipers.");
		panel.DrawText("Survivors gain regeneration and a small bonus to their damage based on Morale.");
		panel.DrawText("Morale is gained by doing objectives and killing infected but is also lost over time and by negative events.");
		panel.DrawText("Survivors only start with a melee weapon and pick up weapons (using CALL 'MEDIC!', 'mouse1' or 'mouse2') as they progress through the map.");
		panel.DrawText("-------------------------------------------");
	}
	else if (nTeam == TFTeam_Zombie)
	{
		panel.SetTitle("Infected");
		panel.DrawText("-------------------------------------------");
		panel.DrawText("Infected consist of Scouts, Heavies and Spies.");
		panel.DrawText("Infected gain bonuses when sticking together as a hoarde and can enrage which boost health or activate special abilities as special infected.");
		panel.DrawText("Enrage is used by calling for a 'medic' and has a cooldown after use.");
		panel.DrawText("Upon killing a survivor, you may be given the option to respawn as a special infected using .");
		panel.DrawText("-------------------------------------------");
	}
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Menu_HandleTeam, 30);
	delete panel;
}

public int Menu_HandleTeam(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	if (action == MenuAction_Select)
	{
		switch (iSelect)
		{
			case 1: Menu_PrintMain(iClient);
			default: return;
		}
	}
}

//Main.Help.Class Menus
public void Menu_PrintSurClass(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Survivor Classes");
	
	char sClass[32];
	for (int i = 1; i < view_as<int>(TFClassType); i++)
	{
		if (IsValidSurvivorClass(view_as<TFClassType>(i)))
		{
			TF2_GetClassName(sClass, sizeof(sClass), i);
			Format(sClass, sizeof(sClass), " %s", sClass);
			panel.DrawItem(sClass);
		}
	}
	
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Menu_HandleSurClass, 10);
	delete panel;
}

public int Menu_HandleSurClass(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	if (action == MenuAction_Select)
	{
		if (iSelect == GetSurvivorClassCount()+1)
			Menu_PrintMain(iClient);

		if (iSelect <= GetSurvivorClassCount() && iSelect > 0)
		{
			TFClassType aClasses[10];
			int i2;
			for (int i = 1; i < view_as<int>(TFClassType); i++)
			{
				if (IsValidSurvivorClass(view_as<TFClassType>(i)))
					aClasses[i2++] = view_as<TFClassType>(i);
			}
			
			Menu_PrintSurInfo(iClient, aClasses[iSelect]);
		}
	}
}

public void Menu_PrintZomClass(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Zombie Classes");
	
	char sClass[32];
	for (int i = 1; i < view_as<int>(TFClassType); i++)
	{
		if (IsValidZombieClass(view_as<TFClassType>(i)))
		{
			TF2_GetClassName(sClass, sizeof(sClass), i);
			Format(sClass, sizeof(sClass), " %s", sClass);
			panel.DrawItem(sClass);
		}
	}
	
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Menu_HandleZomClass, 10);
	delete panel;
}

public int Menu_HandleZomClass(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	if (action == MenuAction_Select)
	{
		if (iSelect == GetZombieClassCount()+1)
			Menu_PrintMain(iClient);

		if (iSelect <= GetZombieClassCount() && iSelect > 0)
		{
			TFClassType aClasses[10];
			int i2;
			for (int i = 1; i < view_as<int>(TFClassType); i++)
			{
				if (IsValidZombieClass(view_as<TFClassType>(i)))
					aClasses[i2++] = view_as<TFClassType>(i);
			}
			
			Menu_PrintZomInfo(iClient, aClasses[iSelect]);
		}
	}
}

public int Menu_PrintZomSpecial(int iClient)
{
	Panel panel = new Panel();
	panel.SetTitle("Special Infected");
	
	char sInfected[64], sClass[32];
	for (int i = 1; i < view_as<int>(Infected); i++)
	{
		if (IsValidInfected(view_as<Infected>(i)))
		{
			GetInfectedName(sInfected, sizeof(sInfected), i);
			TF2_GetClassName(sClass, sizeof(sClass), i);
			Format(sInfected, sizeof(sInfected), " %s (%s)", sInfected, sClass);
			panel.DrawItem(sClass);
		}
	}
	
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Menu_HandleZomSpecial, 10);
	delete panel;
}

public int Menu_HandleZomSpecial(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	if (action == MenuAction_Select)
	{
		if (iSelect == GetInfectedCount()+1)
			Menu_PrintMain(iClient);

		if (iSelect <= GetInfectedCount() && iSelect > 0)
		{
			Infected aClasses[9];
			int i2;
			for (int i = 1; i < view_as<int>(Infected); i++)
			{
				if (IsValidInfected(view_as<Infected>(i)))
					aClasses[i2++] = view_as<Infected>(i);
			}
			
			Menu_PrintSpecial(iClient, aClasses[iSelect]);
		}
	}
}

public void Menu_PrintSurInfo(int iClient, TFClassType nClass)
{
	Panel panel = new Panel();
	
	char sClass[256];
	TF2_GetClassName(sClass, sizeof(sClass), view_as<int>(nClass));
	panel.SetTitle(sClass);
	panel.DrawText("-------------------------------------------");
	
	//If they can gain/lose ammo on kill
	if (GetSurvivorAmmo(nClass))
	{
		Format(sClass, sizeof(sClass), "%s %d primary ammo per kill%s.", GetSurvivorAmmo(nClass) > 0 ? "Gains" : "Loses", GetSurvivorAmmo(nClass), GetSurvivorAmmo(nClass) > 0 ? ", this can go beyond the usual maximum capacity of your weapon" : "");
		panel.DrawText(sClass);
	}
	
	//If their speed has been modified
	if (GetSurvivorSpeed(nClass) != TF2_GetClassSpeed(nClass))
	{
		Format(sClass, sizeof(sClass), "Movement speed %s to %d (from %d).", GetSurvivorSpeed(nClass) > TF2_GetClassSpeed(nClass) ? "increased" : "lowered", RoundFloat(GetSurvivorSpeed(nClass)), TF2_GetClassSpeed(nClass));
		panel.DrawText(sClass);
	}
	
	switch (nClass)
	{
		case TFClass_Pyro:
		{
			panel.DrawText("Burning zombies move faster.");
			panel.DrawText("Flamethrower ammo limited to 100.");
		}
		case TFClass_Heavy:
		{
			panel.DrawText("Minigun ammo limited to 100.");
		}
		case TFClass_Engineer:
		{
			panel.DrawText("Buildables cannot be upgraded.");
			panel.DrawText("Can only build sentries and dispensers.");
			panel.DrawText("Sentry ammo is limited, decays and cannot be replenished.");
			panel.DrawText("Dispensers act as walls, with higher health than usual but no ammo replenishment.");
		}
		case TFClass_Medic:
		{
			panel.DrawText("Overheal limited to 25%% of maximum health but sticks for a longer duration.");
		}
		case TFClass_Sniper:
		{
			panel.DrawText("SMG doesn't have to reload.");
			panel.DrawText("Jarate slows down Infected.");
		}
		case TFClass_Spy:
		{
			panel.DrawText("Can't use cloak watches but can use disguises.");
		}
	}
	
	panel.DrawText("-------------------------------------------");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Menu_HandleClass, 30);
	delete panel;
}

public void Menu_PrintZomInfo(int iClient, TFClassType nClass)
{
	Panel panel = new Panel();
	
	char sClass[32];
	TF2_GetClassName(sClass, sizeof(sClass), view_as<int>(nClass));
	panel.SetTitle(sClass);
	panel.DrawText("-------------------------------------------");
	
	//If their speed has been modified
	if (GetZombieSpeed(nClass) != TF2_GetClassSpeed(nClass))
	{
		Format(sClass, sizeof(sClass), "Movement speed %s to %d (from %d).", GetZombieSpeed(nClass) > TF2_GetClassSpeed(nClass) ? "increased" : "lowered", RoundFloat(GetZombieSpeed(nClass)), TF2_GetClassSpeed(nClass));
		panel.DrawText(sClass);
	}
	
	switch (nClass)
	{
		case TFClass_Scout:
		{
			panel.DrawText("Balls fired from the Sandman do not stun, it emits a toxic gas that damages Survivors who stand on it instead.");
		}
		case TFClass_Soldier:
		{
			panel.DrawText("Suffers less knockback from attackers.");
			panel.DrawText("Benefits less from movement speed and health regeneration bonuses while in a horde.");
		}
		case TFClass_Pyro, TFClass_DemoMan:
		{
			panel.DrawText("Benefits less from movement speed and health regeneration bonuses while in a horde.");
		}
		case TFClass_Heavy:
		{
			panel.DrawText("Blocks fatal attacks, reducing damage to 150.");
			panel.DrawText("Suffers less knockback from attacks.");
			panel.DrawText("Benefits less from movement speed and health regeneration bonuses while in a horde.");
		}
		case TFClass_Engineer:
		{
			panel.DrawText("Buildables cannot be upgraded.");
			panel.DrawText("Can only build sentries.");
			panel.DrawText("Sentry ammo is limited, decays and cannot be replenished.");
		}
		case TFClass_Medic:
		{
			panel.DrawText("Benefits less from health regeneration bonuses while in a horde.");
		}
		case TFClass_Spy:
		{
			panel.DrawText("Backstabs put the victim into a 'scared' state, slowing and disabling weapon usage for 5.5 seconds.");
			panel.DrawText("Survivors may become a bit resistant to backstabs, reducing the duration, to ensure game balance.");
		}
	}
	
	panel.DrawText("-------------------------------------------");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Menu_HandleClass, 30);
	delete panel;
}

public void Menu_PrintSpecial(int iClient, Infected nInfected)
{
	Panel panel = new Panel();
	
	char sInfected[64], sClass[32];
	GetInfectedName(sInfected, sizeof(sInfected), view_as<int>(nInfected));
	TF2_GetClassName(sClass, sizeof(sClass), view_as<int>(GetInfectedClass(nInfected)));
	Format(sInfected, sizeof(sInfected), "%s (%s)", sInfected, sClass);
	panel.SetTitle(sInfected);
	panel.DrawText("-------------------------------------------");
	
	switch (nInfected)
	{
		case Infected_Tank:
		{
			panel.DrawText("As one of the strongest and brutal infected he has the ability to quickly take down an unsuspecting team of survivors.");
			panel.DrawText("- The Tank has a lot of health which he eventually loses after a while.");
			panel.DrawText("- The Tank starts of fast but is slowed down if damaged by the survivors.");
			panel.DrawText("- The Tank spawns if certain conditions are met.");
		}
		case Infected_Boomer:
		{
			panel.DrawText("He is gross, he is dirty and is not afraid to share this with any unlucky survivors.");
			panel.DrawText("- Upon raging the Boomer explodes, covering survivors close to him in Jarate.");
			panel.DrawText("- On death, the killer and the assister of the killer will be coated in Jarate for a short duration.");
		}
		case Infected_Charger:
		{
			panel.DrawText("His inner rage and insanity has caused him to lose any care for how he uses his body, as long as he can take somebody with it.");
			panel.DrawText("- Using rage to charge the Charger is able to disable a survivor for a short period, damaging based on the victim's health.");
		}
		case Infected_Kingpin:
		{
			panel.DrawText("The Kingpin is the director of the pack, he makes sure that the Zombies give their fullest in taking down the survivors.");
			panel.DrawText("- Using rage, the Kingpin will rally up the Zombies with an ear-piercing yell, increasing the overall power of the zombies.");
			panel.DrawText("- The Kingpin motivates zombies by standing near them, increasing their efficiency.");
			panel.DrawText("- The Kingpin is slower, but takes less damage from attacks.");
		}
		case Infected_Stalker:
		{
			panel.DrawText("The Stalker is elusive, being able to get close to survivors and back away in the blink of an eye.");
			panel.DrawText("- The Stalker is always cloaked if not close to any survivor.");
			panel.DrawText("- Backstabs deal 50 health damage to a survivor, making it 2.5x stronger than a normal backstab.");
		}
		case Infected_Hunter:
		{
			panel.DrawText("The Hunter is a fast being, being very agile they can easily reach beyond the level's obstacles and be hard to get rid off during hectic combat.");
			panel.DrawText("- Using rage, the Hunter will perform a swift leap which can pounce enemies when making physical contact while leaping.");
			panel.DrawText("- Upon pounce, you will be 'stuck' inside the enemy, making you a very dangerous encounter to face when the opponent is alone.");
		}
		case Infected_Smoker:
		{
			panel.DrawText("The Smoker relies on his toxic beam which damages survivors can pulls them towards the Smoker.");
			panel.DrawText("- The pull power grows stronger the less health the victim has.");
			panel.DrawText("- Cannot use rage.");
		}
		case Infected_Spitter:
		{
			panel.DrawText("The Spitter has a filled nasty gas, giving bleed to survivors at medium range for a few seconds");
			panel.DrawText("- Can damage heavily to team if many survivors is nearby eachother");
			panel.DrawText("- Cannot use rage.");
		}
	}
	
	panel.DrawText("-------------------------------------------");
	panel.DrawItem("Return");
	panel.DrawItem("Exit");
	panel.Send(iClient, Menu_HandleClass, 30);
	delete panel;
}

public int Menu_HandleClass(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	if (action == MenuAction_Select)
	{
		switch (iSelect)
		{
			case 1: Menu_PrintMain(iClient);
			default: return;
		}
	}
}
