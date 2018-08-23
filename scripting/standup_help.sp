// Everything related to the help command.
#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include <msharedutil/arrayvec>

#include <standup/stocks_chat>
#include <standup/core>
#include <standup/help>


#pragma semicolon 1
#pragma newdecls required


//#define DEBUG


#define MAX_COMMAND_LENGTH      32
#define MAX_COMMAND_LENGTH_CELL MAX_COMMAND_LENGTH / 4

#define MAX_DESC_LENGTH         256
#define MAX_DESC_LENGTH_CELL    MAX_DESC_LENGTH / 4

enum CommandData
{
    CMD_COMMAND[MAX_COMMAND_LENGTH_CELL],
    CMD_DESC[MAX_DESC_LENGTH_CELL],
    bool:CMD_IMPORTANT,
    bool:CMD_ADMINONLY
};

#define CMD_SIZE    MAX_COMMAND_LENGTH_CELL + MAX_DESC_LENGTH_CELL + 2

ArrayList g_hCommands;

Handle g_hForward_RequestHelpCmds;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Helper",
    description = "",
    version = "1.0"
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( LIBRARY_HELP );
    
    
    // FORWARDS
    g_hForward_RequestHelpCmds = CreateGlobalForward( "Standup_RequestHelpCmds", ET_Ignore );
    
    // NATIVES
    CreateNative( "Standup_AddCommand", Native_AddCommand );
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    // COMMANDS
    RegConsoleCmd( "sm_ljhelp", Command_Help );
}

public void OnAllPluginsLoaded()
{
    if ( g_hCommands != null )
    {
        delete g_hCommands;
    }
    
    g_hCommands = new ArrayList( view_as<int>( CommandData ) );
    
    // This forward ensures every plugin can add commands.
    Call_StartForward( g_hForward_RequestHelpCmds );
    Call_Finish();
}

public void OnClientPostAdminCheck( int client )
{
    if ( !IsFakeClient( client ) )
    {
        CreateTimer( 2.0, Timer_HelperMsg, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
    }
}

public Action Timer_HelperMsg( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Type "...CLR_TEAM..."!ljhelp"...CLR_CHAT..." in chat for a list of commands." );
    }
}

public Action Command_Help( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Standup_IsSpammingCommand( client ) ) return Plugin_Handled;
    
    
    int len = GetArrayLength_Safe( g_hCommands );
    if ( len > 0 )
    {
        bool bIsAdmin = ( GetUserAdmin( client ) != INVALID_ADMIN_ID );
        
        int iCmd[CMD_SIZE];
        char szImportant[162];
        
        int num;
        
        PrintToConsole( client, "-------------------------------------\nCommands:" );
        
        for ( int i = 0; i < len; i++ )
        {
            g_hCommands.GetArray( i, iCmd, view_as<int>( CommandData ) );
            
            if ( iCmd[CMD_ADMINONLY] && !bIsAdmin )
            {
                continue;
            }
            
            
            PrintToConsole( client, "%s - %s", iCmd[CMD_COMMAND], iCmd[CMD_DESC] );
            
            if ( iCmd[CMD_IMPORTANT] )
            {
                Format( szImportant, sizeof( szImportant ), "%s%s%s%s",
                    szImportant,
                    ( szImportant[0] == '\0' ) ? "" : ", ",
                    iCmd[CMD_COMMAND],
                    iCmd[CMD_ADMINONLY] ? " (Admin Only)" : "" );
            }
            
            num++;
        }
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Printed "...CLR_TEAM..."%i"...CLR_CHAT..." commands to console! Main ones: \x04%s", num, szImportant );
    }
    else
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Sorry, couldn't find any commands!" );
    }
    
    return Plugin_Handled;
}

// NATIVES
public int Native_AddCommand( Handle hPlugin, int numParams )
{
#if defined DEBUG
    PrintToServer( "Native_AddCommand( %x )", hPlugin );
#endif
    
    if ( g_hCommands == null )
    {
        return -1;
    }
    
    
    int iCmd[CMD_SIZE];
    char szCmd[MAX_COMMAND_LENGTH];
    char szDesc[MAX_DESC_LENGTH];
    
    GetNativeString( 1, szCmd, sizeof( szCmd ) );
    GetNativeString( 2, szDesc, sizeof( szDesc ) );
    
    CopyArray( view_as<int>( szCmd ), iCmd[CMD_COMMAND], MAX_COMMAND_LENGTH_CELL );
    CopyArray( view_as<int>( szDesc ), iCmd[CMD_DESC], MAX_DESC_LENGTH_CELL );
    
    iCmd[CMD_IMPORTANT] = GetNativeCell( 3 );
    iCmd[CMD_ADMINONLY] = GetNativeCell( 4 );
    
    return g_hCommands.PushArray( iCmd, view_as<int>( CommandData ) );
}