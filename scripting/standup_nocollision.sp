#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include <standup/core>


#pragma semicolon 1
#pragma newdecls required


#define COLLISION_TRIGGERONLY    2
#define COLLISION_DEF_PLAYER    5


ConVar g_ConVar_OnlyStats;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - No Collision",
    description = "",
    version = "1.0"
};

public void OnPluginStart()
{
    HookEvent( "player_spawn", Event_PlayerSpawn );
    
    
    g_ConVar_OnlyStats = CreateConVar( "standup_nocollision_onlystats", "0", "Do we disable player collisions only when player has LJ stats enabled?", _, true, 0.0, true, 1.0 );
}

public void Standup_OnStatsEnabled( int client )
{
    if ( IsPlayerAlive( client ) )
    {
        ToggleCollisions( client, false );
    }
}

public void Standup_OnStatsDisabled( int client )
{
    if ( IsPlayerAlive( client ) && g_ConVar_OnlyStats.BoolValue )
    {
        ToggleCollisions( client, true );
    }
}

public void Event_PlayerSpawn( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
    int client;
    
    if ( !(client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) )) ) return;
    
    if ( GetClientTeam( client ) < CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    
    if ( !IsFakeClient( client ) && (!g_ConVar_OnlyStats.BoolValue || Standup_IsClientStatsEnabled( client )) )
    {
        ToggleCollisions( client, false );
    }
    
    //RequestFrame( Event_PlayerSpawn_Delay, GetClientUserId( client ) );
}

/*public void Event_PlayerSpawn_Delay( int client )
{
    if ( (client = GetClientOfUserId( client )) )
    {
        
    }
}*/

stock void ToggleCollisions( int client, bool bMode )
{
    SetEntProp( client, Prop_Send, "m_CollisionGroup", bMode ? COLLISION_DEF_PLAYER : COLLISION_TRIGGERONLY );
}