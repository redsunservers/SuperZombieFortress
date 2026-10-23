enum MenuSelect
{
	MenuSelect_Survivor,
	MenuSelect_Zombie,
	MenuSelect_Infected,
}

static MenuSelect g_nMenuClientSelect[MAXPLAYERS+1];

void Menu_DisplayMain(int iClient)
{
	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_MainTitle", iClient, PLUGIN_VERSION, PLUGIN_VERSION_REVISION);
	
	Menu hMenu = new Menu(Menu_SelectMain);
	hMenu.SetTitle(sBuffer);
	Menu_AddItemTranslation(hMenu, "overview", "Menu_MainOverview", iClient);
	Menu_AddItemTranslation(hMenu, "queue", "Menu_MainQueue", iClient);
	Menu_AddItemTranslation(hMenu, "team_survivor", "Menu_MainTeamSurvivor", iClient);
	Menu_AddItemTranslation(hMenu, "team_zombie", "Menu_MainTeamZombie", iClient);
	Menu_AddItemTranslation(hMenu, "classes_survivor", "Menu_MainClassesSurvivor", iClient);
	Menu_AddItemTranslation(hMenu, "classes_zombie", "Menu_MainClassesZombie", iClient);
	Menu_AddItemTranslation(hMenu, "classes_infected", "Menu_MainClassesInfected", iClient);
	Menu_AddItemTranslation(hMenu, "settings", "Menu_MainSettings", iClient);
	hMenu.Pagination = MENU_NO_PAGINATION;
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
			else if (StrEqual(sSelect, "queue"))
				Menu_DisplayQueue(iClient, true);
			else if (StrEqual(sSelect, "settings"))
				Menu_DisplaySettings(iClient);
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

#define QUEUE_LIST_ROWS	8

static bool g_bQueuePanelBack[MAXPLAYERS+1];

void Menu_DisplayQueue(int iClient, bool bFromMain = false)
{
	if (!Queue_IsEnabled())
	{
		CPrintToChat(iClient, "%t", "Queue_Disabled", "{red}");
		if (bFromMain)
			Menu_DisplayMain(iClient);
		
		return;
	}
	
	int[] iClients = new int[MaxClients];
	int iLength = Queue_GetOrder(iClients);
	
	char sBuffer[128];
	Panel hPanel = new Panel();
	
	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_QueueTitle", iClient);
	hPanel.SetTitle(sBuffer);
	
	for (int iRow = 1; iRow <= QUEUE_LIST_ROWS; iRow++)
	{
		if (iRow <= iLength)
		{
			int iTarget = iClients[iLength - iRow];
			Format(sBuffer, sizeof(sBuffer), "%T", "Menu_QueueEntry", iClient, iRow, iTarget, Queue_GetPoints(iTarget));
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "Menu_QueueEntryNone", iClient, iRow);
		}
		
		hPanel.DrawText(sBuffer);
	}
	
	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_QueuePoints", iClient, Queue_GetPoints(iClient));
	hPanel.DrawText(sBuffer);
	
	int iKeys = (1 << 9);
	if (bFromMain)
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "Menu_QueueBack", iClient);
		hPanel.DrawItem(sBuffer);
		iKeys |= (1 << 0);
	}
	
	hPanel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_QueueExit", iClient);
	hPanel.DrawText(sBuffer);
	hPanel.SetKeys(iKeys);
	
	g_bQueuePanelBack[iClient] = bFromMain;
	hPanel.Send(iClient, Menu_SelectQueue, MENU_TIME_FOREVER);
	delete hPanel;
}

public int Menu_SelectQueue(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	if (action != MenuAction_Select)
		return 0;
	
	if (iSelect == 1 && g_bQueuePanelBack[iClient])
	{
		Menu_PlayPanelSound(iClient, true);
		Menu_DisplayMain(iClient);
	}
	else if (iSelect == 10)
	{
		Menu_PlayPanelSound(iClient, false);
	}
	
	return 0;
}

static char g_sMenuSoundExit[PLATFORM_MAX_PATH];
static char g_sMenuSoundExitBack[PLATFORM_MAX_PATH];
static bool g_bMenuSoundsRead;
static ConVar g_cvMenuSounds;

static void Menu_PlayPanelSound(int iClient, bool bExitBack)
{
	if (!g_bMenuSoundsRead)
	{
		g_bMenuSoundsRead = true;
		g_cvMenuSounds = FindConVar("sm_menu_sounds");
		
		GameData hCore = new GameData("core.games");
		if (hCore)
		{
			hCore.GetKeyValue("MenuExitSound", g_sMenuSoundExit, sizeof(g_sMenuSoundExit));
			hCore.GetKeyValue("MenuExitBackSound", g_sMenuSoundExitBack, sizeof(g_sMenuSoundExitBack));
			delete hCore;
		}
	}
	
	if (g_cvMenuSounds && !g_cvMenuSounds.BoolValue)
		return;
	
	if (bExitBack)
	{
		if (g_sMenuSoundExitBack[0])
			EmitSoundToClient(iClient, g_sMenuSoundExitBack);
	}
	else if (g_sMenuSoundExit[0])
	{
		EmitSoundToClient(iClient, g_sMenuSoundExit);
	}
}

void Menu_DisplaySettings(int iClient)
{
	Menu hMenu = new Menu(Menu_SelectSettings);
	Menu_SetTitleTranslation(hMenu, "Menu_SettingsTitle", iClient);
	
	Menu_AddToggleItem(hMenu, "optin_zombie", "Menu_SettingsAlwaysZombie", iClient, g_bOptInZombie[iClient]);
	Menu_AddToggleItem(hMenu, "custom_viewmodels", "Menu_SettingsCustomViewModels", iClient, g_bCustomViewModels[iClient]);
	Menu_AddItemTranslation(hMenu, "music", "Menu_SettingsMusic", iClient);
	
	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Menu_SelectSettings(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sSelect[32];
			hMenu.GetItem(iSelect, sSelect, sizeof(sSelect));
			if (StrEqual(sSelect, "optin_zombie"))
			{
				if (!AreClientCookiesCached(iClient))
				{
					CPrintToChat(iClient, "%t", "Menu_SettingsNotLoaded", "{red}");
				}
				else
				{
					g_bOptInZombie[iClient] = !g_bOptInZombie[iClient];
					
					if (g_bOptInZombie[iClient])
					{
						PrefSave_SetCookie(iClient, g_cOptInZombie, "1");
						CPrintToChat(iClient, "%t", "Menu_SettingsAlwaysZombieOn", "{limegreen}", "{lightsalmon}");
					}
					else
					{
						PrefSave_SetCookie(iClient, g_cOptInZombie, "0");
						CPrintToChat(iClient, "%t", "Menu_SettingsAlwaysZombieOff", "{limegreen}", "{lightsalmon}");
					}
				}
				
				Menu_DisplaySettings(iClient);
			}
			else if (StrEqual(sSelect, "custom_viewmodels"))
			{
				if (!AreClientCookiesCached(iClient))
				{
					CPrintToChat(iClient, "%t", "Menu_SettingsNotLoaded", "{red}");
				}
				else
				{
					g_bCustomViewModels[iClient] = !g_bCustomViewModels[iClient];
					
					if (g_bCustomViewModels[iClient])
					{
						PrefSave_SetCookie(iClient, g_cCustomViewModels, "1");
						CPrintToChat(iClient, "%t", "Menu_SettingsCustomViewModelsOn", "{limegreen}", "{lightsalmon}");
					}
					else
					{
						PrefSave_SetCookie(iClient, g_cCustomViewModels, "0");
						CPrintToChat(iClient, "%t", "Menu_SettingsCustomViewModelsOff", "{limegreen}", "{lightsalmon}");
					}
				}
				
				Menu_DisplaySettings(iClient);
			}
			else if (StrEqual(sSelect, "music"))
			{
				Menu_DisplayMusicSetting(iClient, true);
			}
		}
		case MenuAction_Cancel:
		{
			if (iSelect == MenuCancel_ExitBack)
				Menu_DisplayMain(iClient);
		}
		case MenuAction_End:
		{
			delete hMenu;
		}
	}
	
	return 0;
}

void Menu_DisplayMusicSetting(int iClient, bool bFromSettings = false)
{
	SoundSetting nCurrent = Sound_GetClientSetting(iClient);
	
	Menu hMenu = new Menu(Menu_SelectSoundSetting);
	Menu_SetTitleTranslation(hMenu, "Menu_SoundTitle", iClient);
	
	for (SoundSetting nSetting; nSetting < view_as<SoundSetting>(sizeof(g_sSoundSettingTranslation)); nSetting++)
	{
		char sInt[12];
		IntToString(nSetting, sInt, sizeof(sInt));
		
		Menu_AddItemTranslation(hMenu, sInt, g_sSoundSettingTranslation[nSetting], iClient, nCurrent == nSetting ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	
	hMenu.ExitBackButton = bFromSettings;
	hMenu.ExitButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Menu_SelectSoundSetting(Menu hMenu, MenuAction action, int iClient, int iSelect)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sSelect[12], sDisplay[256];
			hMenu.GetItem(iSelect, sSelect, sizeof(sSelect), _, sDisplay, sizeof(sDisplay));
			SoundSetting nSetting = view_as<SoundSetting>(StringToInt(sSelect));
			
			if (!AreClientCookiesCached(iClient))
			{
				CPrintToChat(iClient, "%t", "Menu_SettingsNotLoaded", "{red}");
			}
			else
			{
				Sound_UpdateClientSetting(iClient, nSetting);
				PrefSave_SetCookie(iClient, g_cSoundPreference, sSelect);
				
				CPrintToChat(iClient, "%t", "Menu_SoundSelected", "{limegreen}", sDisplay, "{lightsalmon}");
			}
			
			if (hMenu.ExitBackButton)
				Menu_DisplaySettings(iClient);
		}
		case MenuAction_Cancel:
		{
			if (iSelect == MenuCancel_ExitBack)
				Menu_DisplaySettings(iClient);
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

void Menu_AddToggleItem(Menu hMenu, const char[] sInfo, const char[] sTranslation, int iClient, bool bOn)
{
	char sState[32], sBuffer[256];
	if (bOn)
		Format(sState, sizeof(sState), "%T", "Menu_SettingsOn", iClient);
	else
		Format(sState, sizeof(sState), "%T", "Menu_SettingsOff", iClient);
	
	Format(sBuffer, sizeof(sBuffer), "%T", sTranslation, iClient, sState);
	hMenu.AddItem(sInfo, sBuffer);
}

void Menu_AddItemTranslation(Menu hMenu, const char[] sInfo, const char[] sTranslation, int iClient, int iItemDraw = ITEMDRAW_DEFAULT)
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "%T", sTranslation, iClient);
	hMenu.AddItem(sInfo, sBuffer, iItemDraw);
}