
//copy pasted from ZR, handles all the logic for us without spamming arrays.
enum
{
	HitCooldown = 0,
}

enum struct HitDetectionEnum
{
	int Attacker;
	int Victim;
	float Time;
	int Offset;
}
static ArrayList hGlobalHitDetectionLogic;

bool IsIn_HitDetectionCooldown(int attacker, int victim, int offset = 0)
{
	// ArrayList is empty currently
	if(!hGlobalHitDetectionLogic)
		return false;
	
	HitDetectionEnum data;
	int length = hGlobalHitDetectionLogic.Length;
	for(int i; i < length; i++)
	{
		// Loop through the arraylist to find the right attacker and victim
		hGlobalHitDetectionLogic.GetArray(i, data);
		if(data.Attacker == attacker && data.Victim == victim && data.Offset == offset)
		{
			// We found our match
			return data.Time > GetGameTime();
		}
	}

	// We found nothing
	return false;
}

void Set_HitDetectionCooldown(int attacker, int victim, float time, int offset = 0)
{
	// Create if empty
	if(!hGlobalHitDetectionLogic)
		hGlobalHitDetectionLogic = new ArrayList(sizeof(HitDetectionEnum));
	
	HitDetectionEnum data;
	int length = hGlobalHitDetectionLogic.Length;
	for(int i; i < length; i++)
	{
		// Loop through the arraylist to find the right attacker and victim
		hGlobalHitDetectionLogic.GetArray(i, data);
		if(data.Attacker == attacker && data.Victim == victim && data.Offset == offset)
		{
			// We found our match, update the value
			data.Time = time;
			hGlobalHitDetectionLogic.SetArray(i, data);
			return;
		}
	}

	// Create a new entry
	data.Attacker = attacker;
	data.Victim = victim;
	data.Offset = offset;
	data.Time = time;
	hGlobalHitDetectionLogic.PushArray(data);
}

// Deletes the entry if a entity died/removed/etc.
void EntityKilled_HitDetectionCooldown(int entity, int offset = -1)
{
	// ArrayList is empty currently
	if(!hGlobalHitDetectionLogic)
		return;
	
	HitDetectionEnum data;
	int length = hGlobalHitDetectionLogic.Length;
	for(int i; i < length; i++)
	{
		// Loop through the arraylist to find the right attacker and victim
		hGlobalHitDetectionLogic.GetArray(i, data);
		
		if(offset != -1 && data.Offset != offset)
			continue;

		if(data.Attacker == entity || data.Victim == entity)
		{
			// We found a match
			hGlobalHitDetectionLogic.Erase(i);
			i--;
			length--;
		}
	}
}
