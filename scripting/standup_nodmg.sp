#include <sourcemod>
#include <cstrike>
#include <sdktools>
//#include <sdkhooks>

#include <standup/core>


#pragma semicolon 1
#pragma newdecls required


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - No Damage",
    description = "",
    version = "1.0"
};

public void OnPluginStart()
{
    HookEvent( "player_spawn", Event_PlayerSpawn );
}

/*public Action Event_OnTakeDamage_Client( int victim, int &attacker, int &inflictor, float &flDamage, int &fDamage )
{
    //flDamage = 0.0;
    //return Plugin_Changed;
}*/

public void Event_PlayerSpawn( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
    int client;
    
    if ( !(client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) )) ) return;
    
    if ( GetClientTeam( client ) < CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    
    RequestFrame( Event_PlayerSpawn_Delay, GetClientUserId( client ) );
}

public void Event_PlayerSpawn_Delay( int client )
{
    if ( (client = GetClientOfUserId( client )) && IsPlayerAlive( client ) )
    {
        SetEntProp( client, Prop_Data, "m_takedamage", 1, 1 ); // Events only
        
        // Only real players to stop crashing.
        if ( !IsFakeClient( client ) )
        {
            SetEntProp( client, Prop_Send, "m_nHitboxSet", 2 );
        }
    }
}