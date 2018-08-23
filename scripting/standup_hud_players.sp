#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <msharedutil/ents>

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
    name = PLUGIN_NAME_CORE..." - HUD | Hide Players",
    description = "Lets players hide other players.",
    version = "1.0"
};

public void OnPluginStart()
{
    RegConsoleCmd( "sm_hideplayers", Command_HidePlayers );
    RegConsoleCmd( "sm_hidebots", Command_HideBots );
}

public void Standup_RequestHelpCmds()
{
    Standup_AddCommand( "hideplayers", "Toggles player displaying.", true );
    Standup_AddCommand( "hidebots", "Toggles bot displaying.", true );
}

public void OnClientPutInServer( int client )
{
    // Has to be hooked to everybody(?)
    SDKHook( client, SDKHook_SetTransmit, Event_Client_SetTransmit );
}

public Action Command_HidePlayers( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_PLAYERS )
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_PLAYERS );
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Players: "...CLR_TEAM..."ON" );
    }
    else
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_PLAYERS );
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Players: "...CLR_TEAM..."OFF" );
    }
    
    return Plugin_Handled;
}

public Action Command_HideBots( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_BOTS )
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_BOTS );
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Bots: "...CLR_TEAM..."ON" );
    }
    else
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_BOTS );
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Bots: "...CLR_TEAM..."OFF" );
    }
    
    return Plugin_Handled;
}

public Action Event_Client_SetTransmit( int ent, int client )
{
    if ( !IS_ENT_PLAYER( ent ) || client == ent ) return Plugin_Continue;
    
    // If we're spectating somebody, show them.
    // Note: m_hObserverTarget will return an index even when in roaming mode.
    if ( !IsPlayerAlive( client ) && GetClientObserverTarget( client ) == ent && GetClientObserverMode( client ) != OBS_MODE_ROAMING )
    {
        return Plugin_Continue;
    }
    
    
    if ( IsFakeClient( ent ) )
    {
        return ( Standup_GetClientHideFlags( client ) & HIDEFLAG_BOTS ) ? Plugin_Handled : Plugin_Continue;
    }
    
    return ( Standup_GetClientHideFlags( client ) & HIDEFLAG_PLAYERS ) ? Plugin_Handled : Plugin_Continue;
}