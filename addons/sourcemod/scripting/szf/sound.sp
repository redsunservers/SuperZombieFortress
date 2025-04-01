#define CONFIG_SOUNDS       "configs/szf/sounds.cfg"

enum SoundGroup
{
	SoundGroup_MAX = 8
}

enum struct SoundFilepath
{
	char sFilepath[PLATFORM_MAX_PATH];
	float flDuration;
}

enum struct SoundMusic
{
	char sName[64];
	bool bGroup[SoundGroup_MAX];
	int iPriority;
	ArrayList aSounds;
	
	void PushSound(const char[] sFilepath, float flDuration)
	{
		SoundFilepath filepath;
		strcopy(filepath.sFilepath, sizeof(filepath.sFilepath), sFilepath);
		filepath.flDuration = flDuration;
		
		if (!this.aSounds)
			this.aSounds = new ArrayList(sizeof(SoundFilepath));
		
		this.aSounds.PushArray(filepath);
	}
	
	void GetRandomSound(char[] sFilepath, int iLength, float &flDuration)
	{
		int iRandom = GetRandomInt(0, this.aSounds.Length - 1);
		SoundFilepath filepath;
		this.aSounds.GetArray(iRandom, filepath);
		
		strcopy(sFilepath, iLength, filepath.sFilepath);
		flDuration = filepath.flDuration;
	}
}

enum SoundVo
{
	SoundVo_Unknown = -1,
	SoundVo_Default,
	SoundVo_Pain,
	SoundVo_Fire,
	SoundVo_Attack,
	SoundVo_Rage,
	SoundVo_Mumbling,
	SoundVo_Shoved,
	SoundVo_Death,

	SoundVo_Count,
}

enum SoundSetting
{
	SoundSetting_Full,
	SoundSetting_NoMusic,
	SoundSetting_None,
}

static StringMap g_mSoundMusic;
static ArrayList g_aSoundVoInfected[view_as<int>(Infected_Count)][view_as<int>(SoundVo_Count)];

static SoundFilepath g_SoundFilepath[MAXPLAYERS+1][SoundGroup_MAX];
static SoundMusic g_SoundMusic[MAXPLAYERS+1][SoundGroup_MAX];
static Handle g_hSoundMusicTimer[MAXPLAYERS+1][SoundGroup_MAX];

static SoundSetting g_nClientSoundSetting[MAXPLAYERS+1];

void Sound_Refresh()
{
	if (g_mSoundMusic)
	{
		StringMapSnapshot snapshot = g_mSoundMusic.Snapshot();
		int iLength = snapshot.Length;
		for (int i = 0; i < iLength; i++)
		{
			char sKey[64];
			snapshot.GetKey(i, sKey, sizeof(sKey));
			
			SoundMusic music;
			g_mSoundMusic.GetArray(sKey, music, sizeof(music));
			delete music.aSounds;
		}
		
		delete snapshot;
		delete g_mSoundMusic;
	}
	
	KeyValues kv = Config_LoadFile(CONFIG_SOUNDS, "Sounds");
	if (!kv)
		return;
	
	if (kv.JumpToKey("music", false))
	{
		g_mSoundMusic = Config_LoadMusic(kv);
		kv.GoBack();
	}
	
	if (kv.JumpToKey("vo", false))
	{
		if (kv.JumpToKey("infected", false))
		{
			Config_LoadInfectedVo(kv, g_aSoundVoInfected);
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	delete kv;
	
	Sound_Precache();
}

void Sound_Precache()
{
	if (g_mSoundMusic)
	{
		StringMapSnapshot snapshot = g_mSoundMusic.Snapshot();
		int iLength = snapshot.Length;
		for (int i = 0; i < iLength; i++)
		{
			char sKey[64];
			snapshot.GetKey(i, sKey, sizeof(sKey));
			
			SoundMusic music;
			g_mSoundMusic.GetArray(sKey, music, sizeof(music));
			
			int iSoundLength = music.aSounds.Length;
			for (int j = 0; j < iSoundLength; j++)
			{
				SoundFilepath filepath;
				music.aSounds.GetArray(j, filepath);
				PrecacheSound2(filepath.sFilepath);
			}
		}
		
		delete snapshot;
	}
	
	for (Infected nInfected; nInfected < Infected_Count; nInfected++)
	{
		for (SoundVo nVoType; nVoType < SoundVo_Count; nVoType++)
		{
			if (g_aSoundVoInfected[nInfected][nVoType])
			{
				int iLength = g_aSoundVoInfected[nInfected][nVoType].Length;
				for (int i = 0; i < iLength; i++)
				{
					char sFilepath[PLATFORM_MAX_PATH];
					g_aSoundVoInfected[nInfected][nVoType].GetString(i, sFilepath, sizeof(sFilepath));
					PrecacheSound2(sFilepath);
				}
			}
		}
	}
}

SoundVo Sound_GetVoType(const char[] sVo)
{
	static StringMap mVoType;
	
	if (!mVoType)
	{
		mVoType = new StringMap();
		mVoType.SetValue("default", SoundVo_Default);
		mVoType.SetValue("pain", SoundVo_Pain);
		mVoType.SetValue("fire", SoundVo_Fire);
		mVoType.SetValue("attack", SoundVo_Attack);
		mVoType.SetValue("rage", SoundVo_Rage);
		mVoType.SetValue("mumbling", SoundVo_Mumbling);
		mVoType.SetValue("shoved", SoundVo_Shoved);
		mVoType.SetValue("death", SoundVo_Death);
	}
	
	SoundVo nVoType = SoundVo_Unknown;
	mVoType.GetValue(sVo, nVoType);
	return nVoType;
}

void Sound_PlayMusicToAll(const char[] sName, float flDuration = 0.0)
{
	int[] iClients = new int[MaxClients];
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			iClients[iCount] = iClient;
			iCount++;
		}
	}
	
	Sound_PlayMusic(iClients, iCount, sName, flDuration);
}

void Sound_PlayMusicToTeam(TFTeam nTeam, const char[] sName, float flDuration = 0.0)
{
	int[] iClients = new int[MaxClients];
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && TF2_GetClientTeam(iClient) == nTeam)
		{
			iClients[iCount] = iClient;
			iCount++;
		}
	}
	
	Sound_PlayMusic(iClients, iCount, sName, flDuration);
}

void Sound_PlayMusicToClient(int iClient, const char[] sName, float flDuration = 0.0)
{
	int iClients[1];
	iClients[0] = iClient;
	Sound_PlayMusic(iClients, 1, sName, flDuration);
}

void Sound_PlayMusic(int[] iClients, int iCount, const char[] sName, float flDuration = 0.0)
{
	if (iCount <= 0)
		return;
	
	SoundMusic music;
	if (!g_mSoundMusic.GetArray(sName, music, sizeof(music)))
		ThrowError("Invalid sound name '%s'", sName);
	
	//Get random sound only once, play same sound to all clients
	SoundFilepath filepath;
	music.aSounds.GetArray(GetRandomInt(0, music.aSounds.Length - 1), filepath, sizeof(filepath));
	
	//Check if there music override
	bool bMusic = filepath.sFilepath[0] == '#';
	if (bMusic && Sound_IsMusicOverrideOn())
		return;
	
	for (int i = 0; i < iCount; i++)
	{
		int iClient = iClients[i];
		
		//Client don't want to hear music
		switch (Sound_GetClientSetting(iClient))
		{
			case SoundSetting_NoMusic:
			{
				if (bMusic)
					continue;
			}
			case SoundSetting_None:
			{
				continue;
			}
		}
		
		bool bPlay = true;
		for (SoundGroup nGroup; nGroup < SoundGroup_MAX; nGroup++)
		{
			// Ignore if were not part of this group
			if (!music.bGroup[nGroup])
				continue;
			
			// If sound is already ongoing, don't play again
			if (StrEqual(g_SoundMusic[iClient][nGroup].sName, music.sName))
			{
				bPlay = false;
				break;
			}
			
			// If there an ongoing sound that have higher priority than sound we wanted to play, don't play
			if (g_SoundMusic[iClient][nGroup].iPriority > music.iPriority)
			{
				bPlay = false;
				break;
			}
		}
		
		if (!bPlay)
			continue;
		
		//End current group sound before we start new sound
		for (SoundGroup nGroup; nGroup < SoundGroup_MAX; nGroup++)
			if (music.bGroup[nGroup])
				Sound_EndMusic(iClient, nGroup);
		
		//Play sound to client
		EmitSoundToClient(iClient, filepath.sFilepath, _, SNDCHAN_STATIC, SNDLEVEL_NONE);
		
		//If duration not specified, use one from config
		if (flDuration <= 0.0)
			flDuration = filepath.flDuration;
		
		for (SoundGroup nGroup; nGroup < SoundGroup_MAX; nGroup++)
		{
			if (!music.bGroup[nGroup])
				continue;
			
			//Set sound global variables as that sound
			g_SoundFilepath[iClient][nGroup] = filepath;
			g_SoundMusic[iClient][nGroup] = music;
			
			//if duration specified, create timer to end sound
			if (flDuration > 0.0)
				g_hSoundMusicTimer[iClient][nGroup] = CreateTimer(flDuration, Timer_EndMusic, GetClientSerial(iClient));
		}
	}
}

public Action Timer_EndMusic(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	
	//Check if client current sound is still the same
	for (SoundGroup nGroup; nGroup < SoundGroup_MAX; nGroup++)
	{
		if (g_hSoundMusicTimer[iClient][nGroup] == hTimer)
			Sound_EndMusic(iClient, nGroup);
	}
	
	return Plugin_Continue;
}

void Sound_EndAllMusic(int iClient)
{
	for (SoundGroup nGroup; nGroup < SoundGroup_MAX; nGroup++)
		Sound_EndMusic(iClient, nGroup);
}

void Sound_EndSpecificMusic(int iClient, const char[] sName)
{
	for (SoundGroup nGroup; nGroup < SoundGroup_MAX; nGroup++)
	{
		if (StrEqual(g_SoundMusic[iClient][nGroup].sName, sName))
			Sound_EndMusic(iClient, nGroup);
	}
}

void Sound_EndMusic(int iClient, SoundGroup nGroup)
{
	//If there currently no sound on, no point doing it
	if (!g_SoundFilepath[iClient][nGroup].sFilepath[0])
		return;
	
	//End whatever current music from g_sSound to all clients
	if (IsClientInGame(iClient))
		StopSound(iClient, SNDCHAN_STATIC, g_SoundFilepath[iClient][nGroup].sFilepath);
	
	//Reset global variables
	SoundFilepath filepath;
	g_SoundFilepath[iClient][nGroup] = filepath;
	
	SoundMusic music;
	g_SoundMusic[iClient][nGroup] = music;
	
	g_hSoundMusicTimer[iClient][nGroup] = null;
}

void Sound_Attack(int iVictim, int iAttacker)
{
	TFClassType iClass = TF2_GetPlayerClass(iAttacker);
	bool bDramatic = Stun_IsPlayerStunned(iVictim) || GetClientHealth(iVictim) <= 50;
	char sName[64];
	
	switch (iClass)
	{
		case TFClass_Scout, TFClass_Medic, TFClass_Sniper:
		{
			if (bDramatic)
				sName = "drums";
			else
				sName = "trumpet";
		}
		
		case TFClass_Soldier, TFClass_DemoMan, TFClass_Heavy:
		{
			if (bDramatic)
				sName = "banjo";
			else
				sName = "snare";
		}
		
		case TFClass_Pyro, TFClass_Engineer, TFClass_Spy:
		{
			if (bDramatic)
				sName = "violin";
			else
				sName = "slayer";
		}
	}
	
	if (!sName[0])
		return;
	
	int[] iClients = new int[MaxClients];
	int iCount;
	
	//Play sound to all nearby players
	float vecVictimOrigin[3], vecOrigin[3]; 
	GetClientAbsOrigin(iVictim, vecVictimOrigin);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidLivingSurvivor(i))
			continue;
		
		//Is survivor nearby victim
		GetClientAbsOrigin(i, vecOrigin);
		if (GetVectorDistance(vecOrigin, vecVictimOrigin) > 128.0)
			continue;
		
		iClients[iCount] = i;
		iCount++;
	}
	
	Sound_PlayMusic(iClients, iCount, sName);
}

void Sound_Timer()	//This timer fires every 1 second from timer_main
{
	// Always try to play rabies, it has the lowest priority of all sounds
	Sound_PlayMusicToTeam(TFTeam_Survivor, "rabies");
}

SoundSetting Sound_GetClientSetting(int iClient)
{
	return g_nClientSoundSetting[iClient];
}

void Sound_UpdateClientSetting(int iClient, SoundSetting nSetting)
{
	g_nClientSoundSetting[iClient] = nSetting;
}

bool Sound_IsMusicOverrideOn()
{
	Action action = Forward_ShouldAllowMusicPlay();
	
	if (action == Plugin_Handled || g_bNoMusic)
		return true;
	
	return false;
}

bool Sound_GetInfectedVo(Infected nInfected, SoundVo nVoType, char[] sFilepath, int iLength)
{
	if (!g_aSoundVoInfected[nInfected][nVoType])
		return false;
	
	int iRandom = GetRandomInt(0, g_aSoundVoInfected[nInfected][nVoType].Length - 1);
	
	g_aSoundVoInfected[nInfected][nVoType].GetString(iRandom, sFilepath, iLength);
	return true;
}

bool Sound_PlayInfectedVo(int iClient, Infected nInfected, SoundVo nVoType)
{
	char sFilepath[PLATFORM_MAX_PATH];
	if (Sound_GetInfectedVo(nInfected, nVoType, sFilepath, sizeof(sFilepath)))
	{
		EmitSoundToAll(sFilepath, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		return true;
	}
	
	return false;
}

bool Sound_PlayInfectedVoToAll(Infected nInfected, SoundVo nVoType)
{
	char sFilepath[PLATFORM_MAX_PATH];
	if (Sound_GetInfectedVo(nInfected, nVoType, sFilepath, sizeof(sFilepath)))
	{
		EmitSoundToAll(sFilepath);
		return true;
	}
	
	return false;
}