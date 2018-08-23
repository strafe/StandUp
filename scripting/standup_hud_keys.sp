#include <sourcemod>
#include <sdktools>

#include <msharedutil/ents>

#include <standup/stocks_chat>
#include <standup/core>
#include <standup/hud>

#undef REQUIRE_PLUGIN
#include <standup/help>


#pragma semicolon 1
#pragma newdecls required


/*
    By saving our buttons, we will always display the keys to target even when key presses are done between interval.
*/
int g_fLastButtons[MAXPLAYERS];

ConVar g_ConVar_Interval;
int g_nIntervalMod = 8;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - HUD | Keys",
    description = "",
    version = "1.0"
};

public void OnPluginStart()
{
    // LIBRARIES
    RegPluginLibrary( LIBRARY_HUD );
    
    
    // CMDS
    RegConsoleCmd( "sm_keys", Command_Menu_Keys, "Menu to select whether to enable/disable key displaying." );
    RegConsoleCmd( "sm_key", Command_Menu_Keys );
    RegConsoleCmd( "sm_showkeys", Command_Menu_Keys );
    
    
    // CVARS
    g_ConVar_Interval = CreateConVar( "standup_hud_keys_interval", "0.08", "Update interval for keys.", _, true, 0.01, true, 1.0 );
    HookConVarChange( g_ConVar_Interval, Event_ConVar_Interval );
    
    //CreateTimer( 0.03, Timer_DisplayKeys, _, TIMER_REPEAT );
}

public void Standup_RequestHelpCmds()
{
    Standup_AddCommand( "keys", "Toggle key displaying.", true );
}

public void OnConfigsExecuted()
{
    DetermineInterval( g_ConVar_Interval.FloatValue );
}

public void Event_ConVar_Interval( ConVar hConVar, const char[] szOldValue, const char[] szNewValue )
{
    DetermineInterval( hConVar.FloatValue );
}

stock void DetermineInterval( float interval )
{
    g_nIntervalMod = RoundFloat( 1 / GetTickInterval() * interval );
    
    if ( g_nIntervalMod < 2 )
    {
        g_nIntervalMod = 2;
    }
}

public void OnGameFrame()
{
    if ( GetGameTickCount() % g_nIntervalMod ) return;
    
    
    int target;
    
    for ( int client = 1; client <= MaxClients; client++ )
    {
        if ( !IsClientInGame( client ) ) continue;
        
        
        if ( !IsPlayerAlive( client ) )
        {
            if ( !IS_ENT_PLAYER( (target = GetClientObserverTarget( client )) ) ) continue;
            
            if ( !IsClientInGame( target ) || !IsPlayerAlive( target ) ) continue;
            
            
            if ( !(Standup_GetClientHideFlags( client ) & HIDEFLAG_SPECKEYS) )
            {
                DisplayKeys( client, target );
            }
        }
        else if ( !(Standup_GetClientHideFlags( client ) & HIDEFLAG_MYKEYS) )
        {
            DisplayKeys( client, client );
        }
    }
}

/*public int GetClientButtons( int client )
{
    return GetEntProp( client, Prop_Data, "m_nButtons" );
}*/

public Action OnPlayerRunCmd( int client )
{
    g_fLastButtons[client] |= GetClientButtons( client );
}

public Action Command_Menu_Keys( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Menu mMenu = new Menu( Handler_KeysMenu );
    mMenu.SetTitle( "Keys\n " );
    
    
    int hideflags = Standup_GetClientHideFlags( client );
    
    mMenu.AddItem( "", ( hideflags & HIDEFLAG_SPECKEYS )? "Spectator Keys: OFF" : "Spectator Keys: ON" );
    mMenu.AddItem( "", ( hideflags & HIDEFLAG_MYKEYS )    ? "My Keys: OFF" : "My Keys: ON" );
    
    mMenu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Handler_KeysMenu( Menu mMenu, MenuAction action, int client, int index )
{
    if ( action == MenuAction_End ) { delete mMenu; return 0; }
    if ( action != MenuAction_Select ) return 0;
    
    switch ( index )
    {
        case 0 :
        {
            if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_SPECKEYS )
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_SPECKEYS );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."Spectator keys: "...CLR_TEAM..."ON" );
            }
            else
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_SPECKEYS );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."Spectator keys: "...CLR_TEAM..."OFF" );
            }
        }
        case 1 :
        {
            if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_MYKEYS )
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_MYKEYS );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."My keys: "...CLR_TEAM..."ON" );
            }
            else
            {
                Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_MYKEYS );
                SU_PrintToChat( client, client, SU_PRE_CHAT..."My keys: "...CLR_TEAM..."OFF" );
            }
        }
    }
    
    FakeClientCommand( client, "sm_keys" );
    
    return 0;
}

stock void DisplayKeys( int client, int target )
{
    //int buttons = GetEntProp( target, Prop_Data, "m_nButtons" );
    
    // Update to latest buttons.
    g_fLastButtons[target] |= GetClientButtons( target );
    
    // "  W"
    // "A S D"
    // "SPACE"
    // "DUCK"
    static char szMsg[64];
    FormatEx( szMsg, sizeof( szMsg ), "        %s      \n     %s  %s  %s\n%s\n%s",
        ( g_fLastButtons[target] & IN_FORWARD ) ? "W" : "  ",
        ( g_fLastButtons[target] & IN_MOVELEFT ) ? "A" : " ",
        ( g_fLastButtons[target] & IN_BACK ) ? "S" : " ",
        ( g_fLastButtons[target] & IN_MOVERIGHT ) ? "D" : " ",
        ( g_fLastButtons[target] & IN_JUMP ) ? "      JUMP" : "",
        ( g_fLastButtons[target] & IN_DUCK ) ? "      DUCK" : "" );
    
    PrintCenterText( client, szMsg );
    
    g_fLastButtons[target] = 0;
}