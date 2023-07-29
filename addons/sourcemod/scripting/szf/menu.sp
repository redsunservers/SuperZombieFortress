enum MenuSelect
{
	MenuSelect_Survivor,
	MenuSelect_Zombie,
	MenuSelect_Infected,
}

static MenuSelect g_nMenuClientSelect[MAXPLAYERS];

void Menu_DisplayMain(int iClient)
{
	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_MainTitle", iClient, PLUGIN_VERSION, PLUGIN_VERSION_REVISION);
	
	Menu hMenu = new Menu(Menu_SelectMain);
	hMenu.SetTitle(sBuffer);
	Menu_AddItemTranslation(hMenu, "overview", "Menu_MainOverview", iClient);
	Menu_AddItemTranslation(hMenu, "team_survivor", "Menu_MainTeamSurvivor", iClient);
	Menu_AddItemTranslation(hMenu, "team_zombie", "Menu_MainTeamZombie", iClient);
	Menu_AddItemTranslation(hMenu, "classes_survivor", "Menu_MainClassesSurvivor", iClient);
	Menu_AddItemTranslation(hMenu, "classes_zombie", "Menu_MainClassesZombie", iClient);
	Menu_AddItemTranslation(hMenu, "classes_infected", "Menu_MainClassesInfected", iClient);
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Menu_SelectMain(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sSelect[32];
			hMenu.GetItem(iSelect, sSelect, sizeof(sSelect));
			if (StrEqual(sSelect, "overview"))
				Menu_DisplayInfo(iClient, "Menu_MainOverview", "Menu_Overview");
			else if (StrEqual(sSelect, "team_survivor"))
				Menu_DisplayInfo(iClient, "Menu_MainTeamSurvivor", "Menu_TeamSurvivors");
			else if (StrEqual(sSelect, "team_zombie"))
				Menu_DisplayInfo(iClient, "Menu_MainTeamZombie", "Menu_TeamZombie");
			else if (StrEqual(sSelect, "classes_survivor"))
				Menu_DisplayClasses(iClient, "Menu_MainClassesSurvivor", MenuSelect_Survivor);
			else if (StrEqual(sSelect, "classes_zombie"))
				Menu_DisplayClasses(iClient, "Menu_MainClassesZombie", MenuSelect_Zombie);
			else if (StrEqual(sSelect, "classes_infected"))
				Menu_DisplayClasses(iClient, "Menu_MainClassesInfected", MenuSelect_Infected);
		}
		case MenuAction_End:
		{
			delete hMenu;
		}
	}
	
	return 0;
}

void Menu_DisplayInfo(int iClient, const char[] sTitle, const char[] sInfo)
{
	char sBuffer[512];
	Menu hMenu = new Menu(Menu_SelectInfo);
	Format(sBuffer, sizeof(sBuffer), "%T", sTitle, iClient);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");
	
	if (sInfo[0])
		Format(sBuffer, sizeof(sBuffer), "%s\n%T", sBuffer, sInfo, iClient);
	
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");
	
	hMenu.SetTitle(sBuffer);
	Menu_AddItemTranslation(hMenu, "back", "Menu_MainBack", iClient);
	
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Menu_SelectInfo(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			Menu_DisplayMain(iClient);
		}
		case MenuAction_End:
		{
			delete hMenu;
		}
	}
	
	return 0;
}

void Menu_DisplayClasses(int iClient, const char[] sTitle, MenuSelect nSelect)
{
	g_nMenuClientSelect[iClient] = nSelect;
	
	Menu hMenu = new Menu(Menu_SelectClasses);
	Menu_SetTitleTranslation(hMenu, sTitle, iClient);
	
	if (nSelect == MenuSelect_Survivor)
		for (int i = 1; i < sizeof(g_iClassDisplay); i++)
			if (IsValidSurvivorClass(g_iClassDisplay[i]))
				hMenu.AddItem(g_sClassNames[g_iClassDisplay[i]], g_sClassNames[g_iClassDisplay[i]]);
	
	if (nSelect == MenuSelect_Zombie)
		for (int i = 1; i < sizeof(g_iClassDisplay); i++)
			if (IsValidZombieClass(g_iClassDisplay[i]))
				hMenu.AddItem(g_sClassNames[g_iClassDisplay[i]], g_sClassNames[g_iClassDisplay[i]]);
	
	if (nSelect == MenuSelect_Infected)
		for (int i = 1; i < sizeof(g_sInfectedNames); i++)
			if (IsValidInfected(view_as<Infected>(i)))
				hMenu.AddItem(g_sInfectedNames[i], g_sInfectedNames[i]);
	
	//hMenu.ExitBackButton = true;
	hMenu.Pagination = MENU_NO_PAGINATION;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Menu_SelectClasses(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sSelect[32], sSearch[32], sBuffer[64];
			hMenu.GetItem(iSelect, sSelect, sizeof(sSelect));
			StrToLower(sSelect, sSearch, sizeof(sSearch));
			switch (g_nMenuClientSelect[iClient])
			{
				case MenuSelect_Survivor:
				{
					GetSurvivorMenu(TF2_GetClass(sSearch), sBuffer, sizeof(sBuffer));
					Menu_DisplayClassesInfo(iClient, "Menu_MainClassesSurvivor", sSelect, sBuffer, MenuSelect_Survivor);
				}
				case MenuSelect_Zombie:
				{
					GetZombieMenu(TF2_GetClass(sSearch), sBuffer, sizeof(sBuffer));
					Menu_DisplayClassesInfo(iClient, "Menu_MainClassesZombie", sSelect, sBuffer, MenuSelect_Zombie);
				}
				case MenuSelect_Infected:
				{
					GetInfectedMenu(GetInfected(sSearch), sBuffer, sizeof(sBuffer));
					Menu_DisplayClassesInfo(iClient, "Menu_MainClassesInfected", sSelect, sBuffer, MenuSelect_Infected);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (iSelect == MenuCancel_Exit)
				Menu_DisplayMain(iClient);
		}
		case MenuAction_End:
		{
			delete hMenu;
		}
	}
	
	return 0;
}

void Menu_DisplayClassesInfo(int iClient, const char[] sTitle, const char[] sClass, const char[] sInfo, MenuSelect nSelect)
{
	g_nMenuClientSelect[iClient] = nSelect;
	
	char sBuffer[512];
	Menu hMenu = new Menu(Menu_SelectClassesInfo);
	Format(sBuffer, sizeof(sBuffer), "%T (%s)", sTitle, iClient, sClass);
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");
	
	if (sInfo[0])
		Format(sBuffer, sizeof(sBuffer), "%s\n%T", sBuffer, sInfo, iClient);
	
	StrCat(sBuffer, sizeof(sBuffer), "\n-------------------------------------------");
	
	hMenu.SetTitle(sBuffer);
	Menu_AddItemTranslation(hMenu, "back", "Menu_MainBack", iClient);
	
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Menu_SelectClassesInfo(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (g_nMenuClientSelect[iClient])
			{
				case MenuSelect_Survivor: Menu_DisplayClasses(iClient, "Menu_MainClassesSurvivor", MenuSelect_Survivor);
				case MenuSelect_Zombie: Menu_DisplayClasses(iClient, "Menu_MainClassesZombie", MenuSelect_Zombie);
				case MenuSelect_Infected: Menu_DisplayClasses(iClient, "Menu_MainClassesInfected", MenuSelect_Infected);
			}
		}
		case MenuAction_End:
		{
			delete hMenu;
		}
	}
	
	return 0;
}

void Menu_SetTitleTranslation(Menu hMenu, const char[] sTranslation, int iClient)
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "%T", sTranslation, iClient);
	hMenu.SetTitle(sBuffer);
}

void Menu_AddItemTranslation(Menu hMenu, const char[] sInfo, const char[] sTranslation, int iClient, int iItemDraw = ITEMDRAW_DEFAULT)
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "%T", sTranslation, iClient);
	hMenu.AddItem(sInfo, sBuffer, iItemDraw);
}