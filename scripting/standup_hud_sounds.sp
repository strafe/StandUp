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
    name = PLUGIN_NAME_CORE..." - HUD | Sounds",
    description = "",
    version = "1.0"
};

public void OnPluginStart()
{
    RegConsoleCmd( "sm_ljsounds", Command_Menu_Sounds );
    RegConsoleCmd( "sm_ljsound", Command_Menu_Sounds );
}

public void Standup_RequestHelpCmds()
{
    Standup_AddCommand( "ljsounds", "Which record sounds to play.", true );
}

public Action Command_Menu_Sounds( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Menu mMenu = new Menu( Handler_SoundsMenu );
    mMenu.SetTitle( "Sounds\n " );
    
    
    int hideflags = Standup_GetClientHideFlags( client );
    
    mMenu.AddItem( "", ( hideflags & HIDEFLAG_SNDS )        ? "My Sounds: OFF" : "My Sounds: ON" );
    mMenu.AddItem( "", ( hideflags & HIDEFLAG_GLOBALSNDS )    ? "Global Sounds: OFF" : "Global Sounds: ON" );
    mMenu.AddItem( "", ( hideflags & HIDEFLAG_WRSNDS )        ? "WR Sounds: OFF" : "WR Sounds: ON" );
    
    mMenu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Handler_SoundsMenu( Menu mMenu, MenuAction action, int client, int index )
{
    if ( action == MenuAction_End ) { delete mMenu; return 0; }
    if ( action != MenuAction_Select ) return 0;
    
    switch ( index )
    {
        case 0 :
        {
            if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_SNDS )
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_SNDS );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."My Sounds: "...CLR_TEAM..."ON" );
            }
            else
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_SNDS );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."My Sounds: "...CLR_TEAM..."OFF" );
            }
        }
        case 1 :
        {
            if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_GLOBALSNDS )
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_GLOBALSNDS );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."Global Sounds: "...CLR_TEAM..."ON" );
            }
            else
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_GLOBALSNDS );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."Global Sounds: "...CLR_TEAM..."OFF" );
            }
        }
        case 2 :
        {
            if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_WRSNDS )
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_WRSNDS );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."WR Sounds: "...CLR_TEAM..."ON" );
            }
            else
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_WRSNDS );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."WR Sounds: "...CLR_TEAM..."OFF" );
            }
        }
    }
    
    FakeClientCommand( client, "sm_ljsounds" );
    
    return 0;
}