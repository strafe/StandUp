#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include <standup/stocks_chat>
#include <standup/core>
#include <standup/hud>

#undef REQUIRE_PLUGIN
#include <standup/help>


#pragma semicolon 1
#pragma newdecls required


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - HUD | Viewmodels",
    description = "",
    version = "1.0"
};

public void OnPluginStart()
{
    // EVENTS
    HookEvent( "player_spawn", Event_PlayerSpawn );
    
    
    RegConsoleCmd( "sm_viewmodel", Command_ViewModel );
    RegConsoleCmd( "sm_vm", Command_ViewModel );
    RegConsoleCmd( "sm_weapons", Command_ViewModel );
    RegConsoleCmd( "sm_weapon", Command_ViewModel );
}

public void Standup_RequestHelpCmds()
{
    Standup_AddCommand( "viewmodel", "Toggle gun displaying." );
}

public Action Command_ViewModel( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_VM )
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_VM );
        SetClientVM( client, true );
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Viewmodel: "...CLR_TEAM..."ON" );
    }
    else
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_VM );
        SetClientVM( client, false );
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Viewmodel: "...CLR_TEAM..."OFF" );
    }
    
    return Plugin_Handled;
}

public void Event_PlayerSpawn( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
    int client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
    
    if ( !client || GetClientTeam( client ) < CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    if ( IsFakeClient( client ) ) return;
    
    
    RequestFrame( Event_PlayerSpawn_Delay, GetClientUserId( client ) );
}

public void Event_PlayerSpawn_Delay( int client )
{
    if ( (client = GetClientOfUserId( client )) && Standup_GetClientHideFlags( client ) & HIDEFLAG_VM )
    {
        SetClientVM( client, false );
    }
}

stock void SetClientVM( int client, bool bState )
{
    SetEntProp( client, Prop_Data, "m_bDrawViewmodel", bState, 1 );
}