#include <sourcemod>
#include <sdktools>

#include <standup/stocks_chat>

//#undef REQUIRE_PLUGIN
#include <standup/core>


#pragma semicolon 1
#pragma newdecls required


#define WARNING_INTERVAL    0.1

float g_flNextWarning[MAXPLAYERS];

int g_fLastButtons[MAXPLAYERS];
float g_flLastFwd[MAXPLAYERS];
float g_flLastSide[MAXPLAYERS];


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Anti-Cheat | Button Check",
    description = "Check for inconsistencies in player's buttons. Disables +strafe.",
    version = "1.0"
};

public void OnClientPutInServer( int client )
{
    g_flNextWarning[client] = 0.0;
}

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount )
{
    // Check if player has a strafe-hack that modifies the velocity and don't actually press the keys for them.
    // NOTE: Can be called when tabbing back in to the game.
    // 0 = forwardspeed
    // 1 = sidespeed
    // 2 = upspeed
    if ( IsFakeClient( client ) ) return Plugin_Continue;
    
#if defined REQUIRE_PLUGIN
    if ( !Standup_IsClientStatsEnabled( client ) ) return Plugin_Continue;
#endif
    
    if ( IsPlayerAlive( client ) )
    {
        // Forward
        if ( vel[0] > 0.0 && !(buttons & IN_FORWARD) )
        {
            PunishPlayer( client, buttons, vel );
        }
        // Back
        else if ( vel[0] < 0.0 && !(buttons & IN_BACK) )
        {
            PunishPlayer( client, buttons, vel );
        }
        // Moveleft
        else if ( vel[1] < 0.0 && !(buttons & IN_MOVELEFT) )
        {
            PunishPlayer( client, buttons, vel );
        }
        // Moveright
        else if ( vel[1] > 0.0 && !(buttons & IN_MOVERIGHT) )
        {
            PunishPlayer( client, buttons, vel );
        }
    }
    
    g_fLastButtons[client] = buttons;
    g_flLastFwd[client] = vel[0];
    g_flLastSide[client] = vel[1];
    
    return Plugin_Continue;
}

stock void PunishPlayer( int client, int &buttons, float vel[3] )
{
#if defined REQUIRE_PLUGIN
    Standup_InvalidateJump( client );
#endif
    
    float flCurTime = GetEngineTime();
    
    if ( g_flNextWarning[client] < flCurTime )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Detected inconsistency in your buttons! (\x04+strafe or tabbing back"...CLR_CHAT...")" );
    }
    
    buttons = g_fLastButtons[client];
    
    vel[0] = g_flLastFwd[client];
    vel[1] = g_flLastSide[client];
    
    g_flNextWarning[client] = flCurTime + WARNING_INTERVAL;
    
    //ForcePlayerSuicide( client );
}