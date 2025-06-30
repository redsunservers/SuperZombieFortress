// Copy pasted from ZR, handles all the logic for us without spamming arrays.

enum struct HitDetectionEnum
{
	int iAttacker;
	int iVictim;
	float flTime;
	int iOffset;
}

static ArrayList g_aHitDetections;

bool IsIn_HitDetectionCooldown(int iAttacker, int iVictim, int iOffset = 0)
{
	// ArrayList is empty currently
	if (!g_aHitDetections)
		return false;
	
	HitDetectionEnum data;
	int iLength = g_aHitDetections.Length;
	for (int i = 0; i < iLength; i++)
	{
		// Loop through the arraylist to find the right iAttacker and iVictim
		g_aHitDetections.GetArray(i, data);
		if (data.iAttacker == iAttacker && data.iVictim == iVictim && data.iOffset == iOffset)
			return data.flTime > GetGameTime();	// We found our match
	}

	// We found nothing
	return false;
}

void Set_HitDetectionCooldown(int iAttacker, int iVictim, float flTime, int iOffset = 0)
{
	// Create if empty
	if (!g_aHitDetections)
		g_aHitDetections = new ArrayList(sizeof(HitDetectionEnum));
	
	HitDetectionEnum data;
	int iLength = g_aHitDetections.Length;
	for (int i = 0; i < iLength; i++)
	{
		// Loop through the arraylist to find the right iAttacker and iVictim
		g_aHitDetections.GetArray(i, data);
		if (data.iAttacker == iAttacker && data.iVictim == iVictim && data.iOffset == iOffset)
		{
			// We found our match, update the value
			data.flTime = flTime;
			g_aHitDetections.SetArray(i, data);
			return;
		}
	}

	// Create a new entry
	data.iAttacker = iAttacker;
	data.iVictim = iVictim;
	data.iOffset = iOffset;
	data.flTime = flTime;
	g_aHitDetections.PushArray(data);
}

// Deletes the entry if a entity died/removed/etc.
void EntityKilled_HitDetectionCooldown(int entity, int iOffset = -1)
{
	// ArrayList is empty currently
	if (!g_aHitDetections)
		return;
	
	HitDetectionEnum data;
	int iLength = g_aHitDetections.Length;
	for (int i = 0; i < iLength; i++)
	{
		// Loop through the arraylist to find the right iAttacker and iVictim
		g_aHitDetections.GetArray(i, data);
		
		if (iOffset != -1 && data.iOffset != iOffset)
			continue;

		if (data.iAttacker == entity || data.iVictim == entity)
		{
			// We found a match
			g_aHitDetections.Erase(i);
			i--;
			iLength--;
		}
	}
}
