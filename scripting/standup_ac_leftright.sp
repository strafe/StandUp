#include <sourcemod>
#include <sdktools>

#include <standup/stocks_chat>

//#undef REQUIRE_PLUGIN
#include <standup/core>


#pragma semicolon 1
#pragma newdecls required


#define WARNING_INTERVAL    1.0

float g_flNextWarning[MAXPLAYERS];


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Anti-Cheat | +left/+right",
    description = "Disables +left/+right",
    version = "1.0"
};

public void OnClientPutInServer( int client )
{
    g_flNextWarning[client] = 0.0;
}

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3] )
{
#if defined REQUIRE_PLUGIN
    if ( !Standup_IsClientStatsEnabled( client ) ) return Plugin_Continue;
#endif
    
    if ( !IsFakeClient( client ) && IsPlayerAlive( client ) )
    {
        static float flLastYaw[MAXPLAYERS];
        
        if ( buttons & IN_LEFT || buttons & IN_RIGHT )
        {
            float flCurTime = GetEngineTime();
            
            if ( g_flNextWarning[client] < flCurTime )
            {
                SU_PrintToChat( client, client, SU_PRE_CHAT..."+left/+right isn't allowed!" );
            }
            
            g_flNextWarning[client] = flCurTime + WARNING_INTERVAL;
            
            
            angles[1] = flLastYaw[client];
        }
        
        flLastYaw[client] = angles[1];
    }
    
    return Plugin_Continue;
}