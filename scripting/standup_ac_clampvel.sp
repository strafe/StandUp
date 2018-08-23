#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <standup/core>


#pragma semicolon 1
#pragma newdecls required


ConVar g_ConVar_Clamp_Fwd;
float g_flClamp_Fwd;

ConVar g_ConVar_Clamp_Side;
float g_flClamp_Side;

ConVar g_ConVar_Clamp_Up;
float g_flClamp_Up;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Anti-Cheat | Clamp Velocities",
    description = "Clamps ucmd velocities.",
    version = "1.0"
};

public void OnPluginStart()
{
    // CVARS
    g_ConVar_Clamp_Fwd = CreateConVar( "standup_ac_clampvel_fwd", "400", "cl_forwardspeed limiter. 0 = disable", _, true, 0.0, true, 1000.0 );
    g_ConVar_Clamp_Side = CreateConVar( "standup_ac_clampvel_side", "400", "cl_sidespeed limiter. 0 = disable", _, true, 0.0, true, 1000.0 );
    g_ConVar_Clamp_Up = CreateConVar( "standup_ac_clampvel_up", "0", "cl_upspeed limiter. 0 = disable", _, true, 0.0, true, 1000.0 );
    
    HookConVarChange( g_ConVar_Clamp_Fwd, Event_ConVar_Clamp_Fwd );
    HookConVarChange( g_ConVar_Clamp_Side, Event_ConVar_Clamp_Side );
    HookConVarChange( g_ConVar_Clamp_Up, Event_ConVar_Clamp_Up );
}

public void OnConfigsExecuted()
{
    g_flClamp_Fwd = g_ConVar_Clamp_Fwd.FloatValue;
    g_flClamp_Side = g_ConVar_Clamp_Side.FloatValue;
    g_flClamp_Up = g_ConVar_Clamp_Up.FloatValue;
}

public void Event_ConVar_Clamp_Fwd( ConVar hConVar, const char[] szOldValue, const char[] szNewValue )
{
    g_flClamp_Fwd = hConVar.FloatValue;
}

public void Event_ConVar_Clamp_Side( ConVar hConVar, const char[] szOldValue, const char[] szNewValue )
{
    g_flClamp_Side = hConVar.FloatValue;
}

public void Event_ConVar_Clamp_Up( ConVar hConVar, const char[] szOldValue, const char[] szNewValue )
{
    g_flClamp_Up = hConVar.FloatValue;
}

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3] )
{
#if defined REQUIRE_PLUGIN
    if ( !Standup_IsClientStatsEnabled( client ) ) return Plugin_Continue;
#endif
    
    if ( IsPlayerAlive( client ) && !IsFakeClient( client ) )
    {
        if ( g_flClamp_Fwd != 0.0 )
        {
            ClampFloat( -g_flClamp_Fwd, g_flClamp_Fwd, vel[0] );
        }
        
        if ( g_flClamp_Side != 0.0 )
        {
            ClampFloat( -g_flClamp_Side, g_flClamp_Side, vel[1] );
        }
        
        if ( g_flClamp_Up != 0.0 )
        {
            ClampFloat( -g_flClamp_Up, g_flClamp_Up, vel[2] );
        }
    }
    
    return Plugin_Continue;
}

stock bool ClampFloat( float min, float max, float &fl )
{
    if ( fl > max )
    {
        fl = max;
        return true;
    }
    
    if ( fl < min )
    {
        fl = min;
        return true;
    }
    
    return false;
}