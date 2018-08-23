#include <sourcemod>
#include <sdktools>

#include <msharedutil/arrayvec>

#include <standup/stocks_chat>
#include <standup/core>

#undef REQUIRE_PLUGIN
#include <standup/help>
#include <influx/core>


//#define DEBUG


#pragma semicolon 1
#pragma newdecls required


#define MAX_GCP_NAME        32
#define MAX_GCP_NAME_CELL   MAX_GCP_NAME / 4

enum GlobalCPData
{
    GCP_NAME[MAX_GCP_NAME_CELL],
    
    Float:GCP_POS[3],
    Float:GCP_ANG[2]
};

ArrayList g_hGlobalCPs;


enum CPData
{
    Float:CP_POS[3] = 0,
    Float:CP_ANG[2]
};

#define CP_SIZE         5

#define GCP_SIZE        MAX_GCP_NAME_CELL + 5

ArrayList g_hCPs[MAXPLAYERS];
int g_iCPIndex[MAXPLAYERS];

bool g_bUseAngles[MAXPLAYERS];

#define MAX_CPS         10


// LIBRARIES
bool g_bLib_Influx;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Checkpoints",
    description = "",
    version = "1.0"
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // NATIVES
    CreateNative( "Standup_AddGlobalCP", Native_AddGlobalCP );
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    RegConsoleCmd( "sm_save", Command_Save );
    RegConsoleCmd( "sm_cp", Command_Save );
    
    RegConsoleCmd( "sm_goto", Command_Goto );
    RegConsoleCmd( "sm_gocp", Command_Goto );
    RegConsoleCmd( "sm_gotocp", Command_Goto );
    RegConsoleCmd( "sm_tele", Command_Goto );
    
    RegConsoleCmd( "sm_global", Command_Menu_GotoGlobal );
    RegConsoleCmd( "sm_globalgoto", Command_Menu_GotoGlobal );
    RegConsoleCmd( "sm_globaltele", Command_Menu_GotoGlobal );
    
    RegConsoleCmd( "sm_useangles", Command_UseAngles );
    RegConsoleCmd( "sm_angles", Command_UseAngles );
    RegConsoleCmd( "sm_ang", Command_UseAngles );
    
    //RegAdminCmd( "sm_saveglobal", Command_Admin_, ADMFLAG_LJ_LVL1 );
    
    
    // LIBRARIES
    g_bLib_Influx = LibraryExists( INFLUX_LIB_CORE );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_CORE ) ) g_bLib_Influx = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_CORE ) ) g_bLib_Influx = false;
}

public void Standup_RequestHelpCmds()
{
    Standup_AddCommand( "save", "Saves a checkpoint!", true );
    Standup_AddCommand( "tele", "Goes to latest checkpoint.", true );
    Standup_AddCommand( "useangles", "Toggle whether you want to use angles or not.", true );
}

public void OnMapStart()
{
    if ( g_hGlobalCPs != null )
    {
        delete g_hGlobalCPs;
    }
}

public void OnClientPutInServer( int client )
{
    g_bUseAngles[client] = true;
    
    ResetChecks( client );
}

stock void ResetChecks( int client )
{
    if ( g_hCPs[client] != null )
    {
        delete g_hCPs[client];
    }
    
    g_hCPs[client] = new ArrayList( view_as<int>( CPData ) );
    
    g_iCPIndex[client] = -1;
}

public Action Command_Save( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !SU_CanUseCommand( client, true, true ) ) return Plugin_Handled;
    
    
    /*if ( g_hCPs[client] != null )
    {
        ResetChecks( client );
    }*/
    
    float vecPos[3];
    GetClientAbsOrigin( client, vecPos );
    
    float vecAng[3];
    GetClientEyeAngles( client, vecAng );
    
    int iData[CP_SIZE];
    CopyArray( vecPos, iData[CP_POS], 3 );
    CopyArray( vecAng, iData[CP_ANG], 2 );
    
    
    if ( ++g_iCPIndex[client] >= MAX_CPS )
    {
        g_iCPIndex[client] = 0;
    }
    
    if ( g_hCPs[client].Length >= MAX_CPS )
    {
        g_hCPs[client].SetArray( g_iCPIndex[client], iData, view_as<int>( CPData ) );
    }
    else
    {
        g_hCPs[client].PushArray( iData, view_as<int>( CPData ) );
    }
    
    SU_PrintToChat( client, client, SU_PRE_CHAT..."Saved your location." );
    
    return Plugin_Handled;
}

public Action Command_Goto( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !SU_CanUseCommand( client, true, true ) ) return Plugin_Handled;
    
    
    if ( g_hCPs[client] == null || g_iCPIndex[client] == -1 || g_iCPIndex[client] >= g_hCPs[client].Length )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."You haven't saved a location!" );
        return Plugin_Handled;
    }
    
    
    float vecPos[3];
    float vecAng[3];
    
    int iData[CP_SIZE];
    g_hCPs[client].GetArray( g_iCPIndex[client], iData, view_as<int>( CPData ) );
    
    CopyArray( iData[CP_POS], vecPos, 3 );
    CopyArray( iData[CP_ANG], vecAng, 2 );
    
#if defined DEBUG
    PrintToServer( SU_PRE_DEV..."Teleporting to (%.0f, %.0f, %.0f) - index: %i", vecPos[0], vecPos[1], vecPos[2], g_iCPIndex[client] );
#endif
    
    TeleportToCheckpoint( client, vecPos, vecAng );
    
    return Plugin_Handled;
}

public Action Command_UseAngles( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !SU_CanUseCommand( client, true, true ) ) return Plugin_Handled;
    
    
    g_bUseAngles[client] = !g_bUseAngles[client];
    
    SU_PrintToChat( client, client, SU_PRE_CHAT..."Set Angles: "...CLR_TEAM..."%s", ( g_bUseAngles[client] ) ? "ON" : "OFF" );
    
    return Plugin_Handled;
}

public Action Command_Menu_GotoGlobal( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !SU_CanUseCommand( client, true, true ) ) return Plugin_Handled;
    
    
    int len = GetArrayLength_Safe( g_hGlobalCPs );
    if ( len < 1 )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."No global checkpoints exist!" );
        return Plugin_Handled;
    }
    
    
    char szName[MAX_GCP_NAME];
    
    if ( args && !Standup_IsSpammingCommand( client ) )
    {
        // Find matching name.
        GetCmdArgString( szName, sizeof( szName ) );
        StripQuotes( szName );
        
        if ( strlen( szName ) < 2 )
        {
            char szCmp[MAX_GCP_NAME];
            
            for ( int i = 0; i < len; i++ )
            {
                g_hGlobalCPs.GetString( i, szCmp, sizeof( szCmp ) );
                
                if ( StrContains( szName, szCmp, false ) == 0 )
                {
                    float vecPos[3];
                    float vecAng[3];
                    
                    
                    vecPos[0] = view_as<float>( g_hGlobalCPs.Get( i, view_as<int>( GCP_POS ) ) );
                    vecPos[1] = view_as<float>( g_hGlobalCPs.Get( i, view_as<int>( GCP_POS ) + 1 ) );
                    vecPos[2] = view_as<float>( g_hGlobalCPs.Get( i, view_as<int>( GCP_POS ) + 2 ) );
                    
                    vecAng[0] = view_as<float>( g_hGlobalCPs.Get( i, view_as<int>( GCP_ANG ) ) );
                    vecAng[1] = view_as<float>( g_hGlobalCPs.Get( i, view_as<int>( GCP_ANG ) + 1 ) );
                    
                    
                    TeleportToCheckpoint( client, vecPos, vecAng );
                    return Plugin_Handled;
                    
                }
            }
            
            SU_PrintToChat( client, client, SU_PRE_CHAT..."Sorry, couldn't find a global checkpoint you were looking for." );
        }
        else
        {
            SU_PrintToChat( client, client, SU_PRE_CHAT..."Invalid argument. Must be at least 2 characters." );
        }
    }
    
    Menu mMenu = new Menu( Handler_CP );
    mMenu.SetTitle( "Global CPs\n " );
    
    for ( int i = 0; i < len; i++ )
    {
        g_hGlobalCPs.GetString( i, szName, sizeof( szName ) );
        
        mMenu.AddItem( "g", szName );
    }
    
    mMenu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Handler_CP( Menu mMenu, MenuAction action, int client, int index )
{
    if ( action == MenuAction_End ) { delete mMenu; return 0; }
    if ( action != MenuAction_Select ) return 0;
    
    
    // Handle both global and local checkpoints.
    char szInfo[2];
    if ( !GetMenuItem( mMenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    float vecPos[3];
    float vecAng[3];
    int len;
    
    if ( szInfo[0] == 'g' )
    {
        len = GetArrayLength_Safe( g_hGlobalCPs );
        
        if ( len < 1 || index < 0 || index >= len ) return 0;
        
        
        vecPos[0] = view_as<float>( g_hGlobalCPs.Get( index, view_as<int>( GCP_POS ) ) );
        vecPos[1] = view_as<float>( g_hGlobalCPs.Get( index, view_as<int>( GCP_POS ) + 1 ) );
        vecPos[2] = view_as<float>( g_hGlobalCPs.Get( index, view_as<int>( GCP_POS ) + 2 ) );
        
        vecAng[0] = view_as<float>( g_hGlobalCPs.Get( index, view_as<int>( GCP_ANG ) ) );
        vecAng[1] = view_as<float>( g_hGlobalCPs.Get( index, view_as<int>( GCP_ANG ) + 1 ) );
        
        FakeClientCommand( client, "sm_global" );
    }
    else
    {
        len = GetArrayLength_Safe(  g_hCPs[client] );
        
        if ( len < 1 || index < 0 || index >= len ) return 0;
        
        
        // !!! Can't use .Get
        int iData[CP_SIZE];
        g_hCPs[client].GetArray( index, iData, view_as<int>( CPData ) );
        
        CopyArray( iData[CP_POS], vecPos, 3 );
        CopyArray( iData[CP_ANG], vecAng, 2 );
        
        FakeClientCommand( client, "sm_ljcpmenu" );
    }
    
    TeleportToCheckpoint( client, vecPos, vecAng );
    
    return 0;
}

stock void TeleportToCheckpoint( int client, float vecPos[3], float vecAng[3] )
{
    // Tell the timer not to count this run anymore for using checkpoints.
    if ( g_bLib_Influx )
    {
        Influx_InvalidateClientRun( client );
    }
    
    
    TeleportEntity( client, vecPos, ( g_bUseAngles[client] ) ? vecAng : NULL_VECTOR, ORIGIN_VECTOR );
}

// NATIVES
public int Native_AddGlobalCP( Handle hPlugin, int numParams )
{
    if ( g_hGlobalCPs == null )
    {
        g_hGlobalCPs = new ArrayList( view_as<int>( GlobalCPData ) );
    }
    
    int iData[GCP_SIZE];
    
    float vecPos[3];
    float vecAng[3];
    GetNativeArray( 1, vecPos, sizeof( vecPos ) );
    GetNativeArray( 2, vecAng, sizeof( vecAng ) );
    
    CopyArray( vecPos, iData[GCP_POS], 3 );
    CopyArray( vecAng, iData[GCP_ANG], 2 );
    
    
    char szName[MAX_GCP_NAME];
    int written;
    FormatNativeString( 0, 3, 4, sizeof( szName ), written, szName );
    
    CopyArray( view_as<int>( szName ), iData[GCP_NAME], MAX_GCP_NAME_CELL );
    
    return g_hGlobalCPs.PushArray( iData, view_as<int>( GlobalCPData ) );
}