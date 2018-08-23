#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>

#include <standup/core>
#include <standup/teams>


#pragma semicolon 1
#pragma newdecls required


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Teams | Auto-join",
    description = "Automatically joins player to a team.",
    version = "1.0"
};

//
public void OnPluginStart()
{
    HookEvent( "player_team", Event_ClientTeam );
    
    // Blocked commands.
    RegConsoleCmd( "jointeam", Command_JoinTeam );
    RegConsoleCmd( "joinclass", Command_JoinClass );
}

public void OnClientPutInServer( int client )
{
    CreateTimer( 1.0, Timer_ClientPutInServer, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
}

public Action Command_JoinTeam( int client, int args )
{
    return IsPlayerAlive( client ) ? Plugin_Handled : Plugin_Continue;
}

public Action Command_JoinClass( int client, int args )
{
    return Plugin_Handled;
}

public Action Timer_ClientPutInServer( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) && !IsPlayerAlive( client ) )
    {
        ChangeClientTeam( client, Standup_GetPreferredTeam() );
        CS_RespawnPlayer( client );
    }
}

public Action Event_ClientTeam( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
    if ( GetEventInt( hEvent, "team" ) > CS_TEAM_SPECTATOR )
    {
        CreateTimer( 1.0, Timer_ClientJoinTeam, GetEventInt( hEvent, "userid" ), TIMER_FLAG_NO_MAPCHANGE );
    }
}

public Action Timer_ClientJoinTeam( Handle hTimer, int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    
    if ( GetClientTeam( client ) > CS_TEAM_SPECTATOR && !IsPlayerAlive( client ) )
    {
        CS_RespawnPlayer( client );
    }
}