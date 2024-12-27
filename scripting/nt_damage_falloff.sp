#include <sourcemod>
#include <dhooks>
#include <entity>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

char g_weps[][] = {
	"weapon_mx",
	"weapon_zr68s",
	"weapon_zr68c",
	"weapon_supa7",
	"weapon_aa13",
	"weapon_mx_silenced",
	"weapon_pz",
	
	"weapon_srm",
	"weapon_jitte",
	"weapon_jittescoped",
	"weapon_mpn",
	"weapon_srm_s",
	
	"weapon_kyla", // forget falloff for these are the spread effectively does that?
	"weapon_tachi",
	"weapon_milso",

	"weapon_srs", // forget falloff for these as snipers
	"weapon_zr68l",
	"weapon_m41",
	"weapon_m41s",
	
	"weapon_grenade", // forget, falloff not applicable
	"weapon_remotedet",
	"weapon_knife",
};

float g_multi[] = {
	2.0,
	2.0,
	2.0,
	2.0,
	2.0,
	2.0,
	2.0,
	
	1.0,
	1.0,
	1.0,
	1.0,
	1.0,
	
	0.0,
	0.0,
	0.0,
	
	-1.0,
	-1.0,
	-1.0,
	-1.0,
	
	-1.0,
	-1.0,
	-1.0,
};

static DynamicHook _dh_OnPlayerTakeDmg;
static bool _late;

public Plugin myinfo = {
    name = "NT damage falloff",
    author = "bauxite, credits to rain",
    description = "Implements damage falloff",
    version = "0.1.0",
    url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    _late = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    GameData gd = new GameData("sdkhooks.games/game.neotokyo");
    if (!gd)
    {
        SetFailState("Failed to read GameData");
    }
    int offset = gd.GetOffset("OnTakeDamage");
    if (!offset)
    {
        SetFailState("Failed to find offset");
    }
    delete gd;

    _dh_OnPlayerTakeDmg = new DynamicHook(offset, HookType_Entity,
        ReturnType_Void, ThisPointer_CBaseEntity);
    if (!_dh_OnPlayerTakeDmg)
    {
        SetFailState("Failed to create dynamic hook");
    }

    _dh_OnPlayerTakeDmg.AddParam(HookParamType_ObjectPtr);

    if (_late)
    {
        for (int client = 1; client <= MaxClients; ++client)
        {
            if (IsClientInGame(client))
            {
                OnClientPutInServer(client);
            }
        }
    }
}

public void OnClientPutInServer(int client)
{
    if (INVALID_HOOK_ID == _dh_OnPlayerTakeDmg.HookEntity(Hook_Pre, client, OnTakeDamage))
    {
        SetFailState("Failed to hook entity");
    }
}

MRESReturn OnTakeDamage(int pThis, DHookParam hParams)
{
	int victim = pThis;
	int attacker = hParams.GetObjectVar(1, 14 * 4, ObjectValueType_Ehandle);
	float damage = hParams.GetObjectVar(1, 15 * 4, ObjectValueType_Float);
	
	if( victim == 0 || attacker == 0 || damage <= 1.0 || victim == attacker || !IsClientInGame(attacker)) 
	{
		// maybe no need to check if victim is in game
		// and only checking if attacker is in game due to nades
		
		return MRES_Ignored;
	}
	
	char swep[20];
	int iwep = GetActiveWeapon(attacker);
	
	if(iwep == -1)
	{
		// not a valid weapon
		
		return MRES_Ignored;
	}
	
	GetEntityClassname(iwep, swep, sizeof(swep));
	
	float multi = -1.0;
		
	for(int w = 0; w < sizeof(g_weps); w++)
	{
		if(StrEqual(swep, g_weps[w], true))
		{
			multi = g_multi[w];
			break;
		}
	}
	
	if(multi == -1.0)
	{
		// we didnt find a damage multiplier or not applicable to the weapon
		
		return MRES_Ignored;
	}
	
	float victimOrigin[3];
	float attackerOrigin[3];
	
	GetClientAbsOrigin(victim, victimOrigin);
	GetClientAbsOrigin(attacker, attackerOrigin);
	
	float distance = GetVectorDistance(victimOrigin, attackerOrigin, false);
	float range = 200.0;
	
	if(distance < range)
	{
		// min distance, do nothing
		
		return MRES_Ignored;
	}
	
	float newDamage = (damage * 0.5) + (damage * 0.5) * Pow(0.79, (distance - range)/range);
	
	hParams.SetObjectVar(1, 15 * 4, ObjectValueType_Float, newDamage);
	
	return MRES_ChangedHandled;
}
