static Database g_hPrefSaveDb;
static bool g_bPrefSaveMySQL;
static StringMap g_mPrefSaveNames;

void PrefSave_Init()
{
	char sConfig[32] = "clientprefs";
	if (!SQL_CheckConfig(sConfig))
		strcopy(sConfig, sizeof(sConfig), "storage-local");
	
	Database.Connect(PrefSave_OnConnect, sConfig);
}

Cookie PrefSave_NewCookie(const char[] sName, const char[] sDescription, CookieAccess nAccess)
{
	Cookie cookie = new Cookie(sName, sDescription, nAccess);
	
	if (!g_mPrefSaveNames)
		g_mPrefSaveNames = new StringMap();
	
	char sKey[16];
	IntToString(view_as<int>(cookie), sKey, sizeof(sKey));
	g_mPrefSaveNames.SetString(sKey, sName);
	
	return cookie;
}

void PrefSave_SetCookie(int iClient, Cookie cookie, const char[] sValue)
{
	cookie.Set(iClient, sValue);
	
	if (!g_hPrefSaveDb || !g_mPrefSaveNames || IsFakeClient(iClient) || !AreClientCookiesCached(iClient))
		return;
	
	char sKey[16], sName[32];
	IntToString(view_as<int>(cookie), sKey, sizeof(sKey));
	if (!g_mPrefSaveNames.GetString(sKey, sName, sizeof(sName)))
		return;
	
	char sAuth[64];
	if (!GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth)))
		return;
	
	char sSafeAuth[129], sSafeName[65], sSafeValue[201];
	g_hPrefSaveDb.Escape(sAuth, sSafeAuth, sizeof(sSafeAuth));
	g_hPrefSaveDb.Escape(sName, sSafeName, sizeof(sSafeName));
	g_hPrefSaveDb.Escape(sValue, sSafeValue, sizeof(sSafeValue));
	
	int iTime = GetTime();
	char sQuery[768];
	if (g_bPrefSaveMySQL)
	{
		Format(sQuery, sizeof(sQuery), "INSERT INTO sm_cookie_cache (player, cookie_id, value, timestamp) SELECT '%s', id, '%s', %d FROM sm_cookies WHERE name = '%s' ON DUPLICATE KEY UPDATE value = '%s', timestamp = %d",
			sSafeAuth, sSafeValue, iTime, sSafeName, sSafeValue, iTime);
	}
	else
	{
		Format(sQuery, sizeof(sQuery), "INSERT OR REPLACE INTO sm_cookie_cache (player, cookie_id, value, timestamp) SELECT '%s', id, '%s', %d FROM sm_cookies WHERE name = '%s'",
			sSafeAuth, sSafeValue, iTime, sSafeName);
	}
	
	g_hPrefSaveDb.Query(PrefSave_OnQuery, sQuery);
}

void PrefSave_OnConnect(Database hDb, const char[] sError, any data)
{
	if (!hDb)
	{
		LogError("Could not connect to the clientprefs database, player settings only save when players disconnect: %s", sError);
		return;
	}
	
	char sDriver[16];
	hDb.Driver.GetIdentifier(sDriver, sizeof(sDriver));
	if (StrEqual(sDriver, "sqlite"))
	{
		g_bPrefSaveMySQL = false;
	}
	else if (StrEqual(sDriver, "mysql"))
	{
		g_bPrefSaveMySQL = true;
	}
	else
	{
		LogError("The clientprefs database uses \"%s\", which SZF can't save settings to straight away. Player settings only save when players disconnect.", sDriver);
		delete hDb;
		return;
	}
	
	g_hPrefSaveDb = hDb;
}

void PrefSave_OnQuery(Database hDb, DBResultSet hResults, const char[] sError, any data)
{
	if (!hResults)
		LogError("Could not save a player setting to the clientprefs database: %s", sError);
}
