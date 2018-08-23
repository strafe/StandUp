#include <sourcemod>

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
    name = PLUGIN_NAME_CORE..." - HUD | Playback Info",
    description = "Toggle playback bot info displaying.",
    version = "1.0"
};

public void OnPluginStart()
{
    // COMMANDS
    RegConsoleCmd( "sm_playbackinfo", Command_PlaybackInfo );
}

public void Standup_RequestHelpCmds()
{
    Standup_AddCommand( "playbackinfo", "Toggle playback bot info displaying." );
}

public Action Command_PlaybackInfo( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_PLAYBACKINFO )
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_PLAYBACKINFO );
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Playback Info: "...CLR_TEAM..."ON" );
    }
    else
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_PLAYBACKINFO );
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Playback Info: "...CLR_TEAM..."OFF" );
    }
    
    return Plugin_Handled;
}