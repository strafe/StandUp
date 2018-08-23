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
    name = PLUGIN_NAME_CORE..." - HUD | Chat Records",
    description = "Toggle chat record displaying.",
    version = "1.0"
};

public void OnPluginStart()
{
    RegConsoleCmd( "sm_ljchat", Command_Menu_Chat );
}

public void Standup_RequestHelpCmds()
{
    Standup_AddCommand( "ljchat", "Toggle chat record displaying." );
}

public Action Command_Menu_Chat( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Menu mMenu = new Menu( Handler_ChatMenu );
    mMenu.SetTitle( "Chat Records\n " );
    
    
    int hideflags = Standup_GetClientHideFlags( client );
    
    mMenu.AddItem( "", ( hideflags & HIDEFLAG_MYCHATRECORD )    ? "My Chat Records: OFF" : "My Chat Records: ON" );
    mMenu.AddItem( "", ( hideflags & HIDEFLAG_CHATRECORD )        ? "Chat Records: OFF" : "Chat Records: ON" );
    mMenu.AddItem( "", ( hideflags & HIDEFLAG_RECCHATRECORD )    ? "Best Chat Records: OFF" : "Best Chat Records: ON" );
    
    mMenu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Handler_ChatMenu( Menu mMenu, MenuAction action, int client, int index )
{
    if ( action == MenuAction_End ) { delete mMenu; return 0; }
    if ( action != MenuAction_Select ) return 0;
    
    switch ( index )
    {
        case 0 :
        {
            if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_MYCHATRECORD )
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_MYCHATRECORD );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."My Chat Records: "...CLR_TEAM..."ON" );
            }
            else
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_MYCHATRECORD );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."My Chat Records: "...CLR_TEAM..."OFF" );
            }
        }
        case 1 :
        {
            if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_CHATRECORD )
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_CHATRECORD );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."Chat Records: "...CLR_TEAM..."ON" );
            }
            else
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_CHATRECORD );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."Chat Records: "...CLR_TEAM..."OFF" );
            }
        }
        case 2 :
        {
            if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_RECCHATRECORD )
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_RECCHATRECORD );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."Best Chat Records: "...CLR_TEAM..."ON" );
            }
            else
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_RECCHATRECORD );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."Best Chat Records: "...CLR_TEAM..."OFF" );
            }
        }
    }
    
    FakeClientCommand( client, "sm_ljchat" );
    
    return 0;
}