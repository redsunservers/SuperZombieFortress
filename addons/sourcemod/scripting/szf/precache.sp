char g_strHeavymats[][256] =
{
	"materials/models/redsun/left4fortress/heavy/eyeball_l.vmt",
	"materials/models/redsun/left4fortress/heavy/eyeball_r.vmt",

	"materials/models/redsun/left4fortress/heavy/heavy_blue_zombie.vmt",
	"materials/models/redsun/left4fortress/heavy/heavy_blue_zombie_alphatest.vmt",
	"materials/models/redsun/left4fortress/heavy/heavy_blue_zombie_alphatest_sheen.vmt",

	"materials/models/redsun/left4fortress/heavy/heavy_head_blue.vmt",
	"materials/models/redsun/left4fortress/heavy/heavy_head_blue_invun.vmt",

	"materials/models/redsun/left4fortress/heavy/heavy_head_red.vmt",
	"materials/models/redsun/left4fortress/heavy/heavy_head_red_invun.vmt",

	"materials/models/redsun/left4fortress/heavy/heavy_head_zombie.vmt",

	"materials/models/redsun/left4fortress/heavy/heavy_red_zombie.vmt",
	"materials/models/redsun/left4fortress/heavy/heavy_red_zombie_alphatest.vmt",
	"materials/models/redsun/left4fortress/heavy/heavy_red_zombie_alphatest_sheen.vmt",

	"materials/models/redsun/left4fortress/heavy/hvyweapon_blue.vmt",
	"materials/models/redsun/left4fortress/heavy/hvyweapon_blue_invun.vmt",
	"materials/models/redsun/left4fortress/heavy/hvyweapon_blue_sheen.vmt",
	"materials/models/redsun/left4fortress/heavy/hvyweapon_blue_zombie_invun.vmt",

	"materials/models/redsun/left4fortress/heavy/hvyweapon_hands.vmt",
	"materials/models/redsun/left4fortress/heavy/hvyweapon_hands_sheen.vmt",

	"materials/models/redsun/left4fortress/heavy/hvyweapon_red.vmt",
	"materials/models/redsun/left4fortress/heavy/hvyweapon_red_invun.vmt",
	"materials/models/redsun/left4fortress/heavy/hvyweapon_red_sheen.vmt",
	"materials/models/redsun/left4fortress/heavy/hvyweapon_red_zombie_invun.vmt",

	"materials/models/redsun/left4fortress/heavy/skeleton.vmt"
};

char g_strScoutMats[][256] =
{
	"materials/models/redsun/left4fortress/scout/eyeball_l.vmt",
	"materials/models/redsun/left4fortress/scout/eyeball_r.vmt",

	"materials/models/redsun/left4fortress/scout/scout_blue.vmt",
	"materials/models/redsun/left4fortress/scout/scout_blue_invun.vmt",
	"materials/models/redsun/left4fortress/scout/scout_blue_invun_zombie.vmt",
	"materials/models/redsun/left4fortress/scout/scout_blue_zombie.vmt",
	"materials/models/redsun/left4fortress/scout/scout_head_blue.vmt",
	"materials/models/redsun/left4fortress/scout/scout_head_zombie.vmt",
	"materials/models/redsun/left4fortress/scout/scout_head_blue_invun.vmt",

	"materials/models/redsun/left4fortress/scout/scout_head_red.vmt",
	"materials/models/redsun/left4fortress/scout/scout_head_red_invun.vmt",
	"materials/models/redsun/left4fortress/scout/scout_head_zombie.vmt",
	"materials/models/redsun/left4fortress/scout/scout_red.vmt",
	"materials/models/redsun/left4fortress/scout/scout_red_invun.vmt",
	"materials/models/redsun/left4fortress/scout/scout_red_invun_zombie.vmt",
	"materials/models/redsun/left4fortress/scout/scout_red_zombie.vmt",

	"materials/models/redsun/left4fortress/scout/skeleton.vmt"
};

char g_strSpyMats[][256] =
{
	"materials/models/redsun/left4fortress/spy/eyeball_l.vmt",
	"materials/models/redsun/left4fortress/spy/eyeball_r.vmt",

	"materials/models/redsun/left4fortress/spy/spy_head_blue.vmt",
	"materials/models/redsun/left4fortress/spy/spy_head_blue_invun.vmt",
	"materials/models/redsun/left4fortress/spy/spy_head_blue_zombie_invun.vmt",
	"materials/models/redsun/left4fortress/spy/spy_head_blue_zombie_alphatest.vmt",
	"materials/models/redsun/left4fortress/spy/spy_head_blue_zombie.vmt",

	"materials/models/redsun/left4fortress/spy/spy_head_red.vmt",
	"materials/models/redsun/left4fortress/spy/spy_head_red_invun.vmt",
	"materials/models/redsun/left4fortress/spy/spy_head_red_zombie_invun.vmt",
	"materials/models/redsun/left4fortress/spy/spy_head_red_zombie_alphatest.vmt",
	"materials/models/redsun/left4fortress/spy/spy_head_red_zombie.vmt",


	"materials/models/redsun/left4fortress/spy/spy_red_zombie.vmt",
	"materials/models/redsun/left4fortress/spy/spy_red_zombie_alphatest.vmt",
	"materials/models/redsun/left4fortress/spy/spy_red.vmt",
	"materials/models/redsun/left4fortress/spy/spy_red_invun.vmt",
	"materials/models/redsun/left4fortress/spy/spy_red_zombie_invun.vmt",

	"materials/models/redsun/left4fortress/spy/spy_blue.vmt",
	"materials/models/redsun/left4fortress/spy/spy_blue_invun.vmt",
	"materials/models/redsun/left4fortress/spy/spy_blue_zombie_invun.vmt",
	"materials/models/redsun/left4fortress/spy/spy_blue_zombie.vmt",
	"materials/models/redsun/left4fortress/spy/spy_blue_zombie_alphatest.vmt",

	"materials/models/redsun/left4fortress/spy/spy_hands_blue.vmt",
	"materials/models/redsun/left4fortress/spy/spy_hands_red.vmt",

	"materials/models/redsun/left4fortress/spy/skeleton.vmt"
};

void ModelPrecache()
{
	PrepareModel("models/redsun/left4fortress/heavy/heavy_zombie_v2.mdl");
	PrepareModel("models/redsun/left4fortress/scout/scout_zombie_v2.mdl");
	PrepareModel("models/redsun/left4fortress/spy/spy_zombie_v2.mdl");
	DownloadMaterialList(g_strHeavymats, sizeof(g_strHeavymats));
	DownloadMaterialList(g_strScoutMats, sizeof(g_strScoutMats));
	DownloadMaterialList(g_strSpyMats, sizeof(g_strSpyMats));
}

stock void DownloadMaterialList(const char[][] szFileList, int iSize)
{
	char s[PLATFORM_MAX_PATH];
	for (int i = 0; i < iSize; i++)
	{
		strcopy(s, sizeof(s), szFileList[i]);
		AddFileToDownloadsTable(s); // if (FileExists(s, true))
	}
}

stock int PrepareModel(const char[] szModelPath, bool bMdlOnly = false)
{
	char szBase[PLATFORM_MAX_PATH];
	char szPath[PLATFORM_MAX_PATH];
	strcopy(szBase, sizeof(szBase), szModelPath);
	SplitString(szBase, ".mdl", szBase, sizeof(szBase));

	if (!bMdlOnly)
	{
		Format(szPath, sizeof(szPath), "%s.phy", szBase);
		if (FileExists(szPath, true))
		{
			AddFileToDownloadsTable(szPath);
		}

		Format(szPath, sizeof(szPath), "%s.sw.vtx", szBase);
		if (FileExists(szPath, true))
		{
			AddFileToDownloadsTable(szPath);
		}

		Format(szPath, sizeof(szPath), "%s.vvd", szBase);
		if (FileExists(szPath, true))
		{
			AddFileToDownloadsTable(szPath);
		}

		Format(szPath, sizeof(szPath), "%s.dx80.vtx", szBase);
		if (FileExists(szPath, true))
		{
			AddFileToDownloadsTable(szPath);
		}

		Format(szPath, sizeof(szPath), "%s.dx90.vtx", szBase);
		if (FileExists(szPath, true))
		{
			AddFileToDownloadsTable(szPath);
		}
	}

	AddFileToDownloadsTable(szModelPath);

	return PrecacheModel(szModelPath, true);
}
