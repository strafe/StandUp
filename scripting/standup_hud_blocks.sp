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
    name = PLUGIN_NAME_CORE..." - HUD | Longjump Blocks",
    description = "Toggle LJ block displaying.",
    version = "1.0"
};

public void OnPluginStart()
{
    RegConsoleCmd( "sm_hideljblocks", Command_HideBlocks );
    RegConsoleCmd( "sm_hideblocks", Command_HideBlocks );
}

public void Standup_RequestHelpCmds()
{
    Standup_AddCommand( "hideblocks", "Toggle LJ block displaying." );
}

public Action Command_HideBlocks( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_LJBLOCKS )
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_LJBLOCKS );
        SU_PrintToChat( client, client, SU_PRE_CHAT..."LJ Blocks: "...CLR_TEAM..."ON" );
    }
    else
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_LJBLOCKS );
        SU_PrintToChat( client, client, SU_PRE_CHAT..."LJ Blocks: "...CLR_TEAM..."OFF" );
    }
    
    return Plugin_Handled;
}