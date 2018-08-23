#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include <standup/stocks_chat>
#include <standup/core>


#pragma semicolon 1
#pragma newdecls required


// For testing. We of course will save this shit to the database.
float g_vecStartPos[3];
float g_vecStartAng[3];
bool g_bStartSet;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Misc. Commands",
    description = "",
    version = "1.0"
};

public void OnPluginStart()
{
    RegAdminCmd( "sm_marklj", Command_Admin_MarkLJ, ADMFLAG_SU_LVL1, "Marks the position for sm_lj command." );
    
    RegConsoleCmd( "sm_gotolj", Command_GotoLJ, "Go to LJ area." );
}

public void OnMapStart()
{
    g_bStartSet = false;
}

public Action Command_Admin_MarkLJ( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !SU_CanUseCommand( client ) ) return Plugin_Handled;
    
    
    GetClientAbsOrigin( client, g_vecStartPos );
    GetClientEyeAngles( client, g_vecStartAng );
    g_bStartSet = true;
    
    SU_PrintToChat( client, client, SU_PRE_CHAT..."(%.0f, %.0f, %.0f) has been marked as the start of LJ area for this map.", g_vecStartPos[0], g_vecStartPos[1], g_vecStartPos[2] );
    
    return Plugin_Handled;
}

public Action Command_GotoLJ( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !SU_CanUseCommand( client ) ) return Plugin_Handled;
    
    
    if ( g_bStartSet )
    {
        TeleportEntity( client, g_vecStartPos, g_vecStartAng, NULL_VECTOR );
    }
    else
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."This map doesn't have LJ area marked!" );
    }
    
    return Plugin_Handled;
}