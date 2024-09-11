#define CONFIG_SOUNDS       "configs/szf/sounds.cfg"

enum struct SoundFilepath
{
	char sFilepath[PLATFORM_MAX_PATH];
	float flDuration;
}

enum struct SoundMusic
{
	char sName[64];
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

static StringMap g_mSoundMusic;
static ArrayList g_aSoundVoInfected[view_as<int>(Infected_Count)][view_as<int>(SoundVo_Count)];

static SoundFilepath g_SoundFilepath[MAXPLAYERS];
static SoundMusic g_SoundMusic[MAXPLAYERS];
static Handle g_hSoundMusicTimer[MAXPLAYERS];

bool g_bNoMusicForClient[MAXPLAYERS];

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
	//Check if there music override
	if (iCount <= 0 || Sound_IsMusicOverrideOn())
		return;
	
	SoundMusic music;
	if (!g_mSoundMusic.GetArray(sName, music, sizeof(music)))
		return;
	
	//Get random sound only once, play same sound to all clients
	SoundFilepath filepath;
	music.aSounds.GetArray(GetRandomInt(0, music.aSounds.Length - 1), filepath, sizeof(filepath));
	
	for (int i = 0; i < iCount; i++)
	{
		int iClient = iClients[i];
		
		//Client don't want to hear music
		if (g_bNoMusicForClient[iClient])
			continue;
		
		//If current sound the same, don't play again
		if (StrEqual(g_SoundMusic[iClient].sName, music.sName))
			continue;
		
		//Don't play if current sound have higher priority than sound we wanted to play
		if (g_SoundMusic[iClient].iPriority > music.iPriority)
			continue;
		
		//End current sound before we start new sound
		Sound_EndMusic(iClient);
		
		//Play sound to client
		EmitSoundToClient(iClient, filepath.sFilepath, _, SNDCHAN_STATIC, SNDLEVEL_NONE);
		
		//Set sound global variables as that sound
		g_SoundFilepath[iClient] = filepath;
		g_SoundMusic[iClient] = music;
		
		//If duration not specified, use one from config
		if (flDuration <= 0.0)
			flDuration = filepath.flDuration;
		
		//if duration specified, create timer to end sound
		if (flDuration > 0.0)
			g_hSoundMusicTimer[iClient] = CreateTimer(flDuration, Timer_EndMusic, GetClientSerial(iClient));
	}
}

public Action Timer_EndMusic(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	
	//Check if client current sound is still the same
	if (g_hSoundMusicTimer[iClient] == hTimer)
		Sound_EndMusic(iClient);
	
	return Plugin_Continue;
}

void Sound_EndMusic(int iClient)
{
	//If there currently no sound on, no point doing it
	if (!g_SoundFilepath[iClient].sFilepath[0])
		return;
	
	//End whatever current music from g_sSound to all clients
	if (IsClientInGame(iClient))
		StopSound(iClient, SNDCHAN_STATIC, g_SoundFilepath[iClient].sFilepath);
	
	//Reset global variables
	SoundFilepath filepath;
	g_SoundFilepath[iClient] = filepath;
	
	SoundMusic music;
	g_SoundMusic[iClient] = music;
	
	g_hSoundMusicTimer[iClient] = null;
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
		//Only play if survivor dont have higher or same priortiy music
		if (IsValidLivingSurvivor(i) && g_SoundMusic[i].iPriority < Sound_GetPriority(sName))
		{
			//Is survivor nearby victim
			GetClientAbsOrigin(i, vecOrigin);
			if (GetVectorDistance(vecOrigin, vecVictimOrigin) <= 128.0)
			{
				iClients[iCount] = i;
				iCount++;
			}
		}
	}
	
	Sound_PlayMusic(iClients, iCount, sName);
}

void Sound_Timer()	//This timer fires every 1 second from timer_main
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		//No sound playing for survivor, lets play rabies
		if (IsValidLivingSurvivor(iClient) && !g_SoundFilepath[iClient].sFilepath[0])
			Sound_PlayMusicToClient(iClient, "rabies");
	}
}

bool Sound_IsCurrentMusic(int iClient, const char[] sName)
{
	return StrEqual(g_SoundMusic[iClient].sName, sName);
}

int Sound_GetPriority(const char[] sName)
{
	SoundMusic music;
	g_mSoundMusic.GetArray(sName, music, sizeof(music));
	return music.iPriority;
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