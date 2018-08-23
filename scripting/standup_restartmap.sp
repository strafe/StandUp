#include <sourcemod>

#include <msharedutil/misc>

#include <standup/stocks_chat>
#include <standup/core>


#pragma semicolon 1
#pragma newdecls required


// Minimum time to spent on a map before resetting. (in seconds)
#define MIN_TIME_MAP        3600.0

#define CHECK_INTERVAL        600.0

float g_flMapStart;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = "",
    name = PLUGIN_NAME_CORE..." - Restart Map",
    description = "Restart map for better performance if no players are found.",
    version = "1.0"
};

public void OnPluginStart()
{
    CreateTimer( CHECK_INTERVAL, Timer_CheckRestart, _, TIMER_REPEAT );
}

public void OnMapStart()
{
    g_flMapStart = GetEngineTime();
}

public Action Timer_CheckRestart( Handle hTimer )
{
    if ( (GetEngineTime() - g_flMapStart) > MIN_TIME_MAP && !HasPlayers() )
    {
        PrintToServer( SU_PRE_CLEAR..."Restarting map for performance!" );
        
        char szMap[32];
        GetLowerCurrentMap( szMap, sizeof( szMap ) );
        
        ServerCommand( "changelevel %s", szMap );
    }
}

stock bool HasPlayers()
{
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientConnected( i ) && !IsFakeClient( i ) )
        {
            return true;
        }
    }
    
    return false;
}