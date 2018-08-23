#include <sourcemod>

#include <standup/stocks_chat>
#include <standup/core>
#include <standup/ljmode>


#pragma semicolon 1
#pragma newdecls required


Handle g_hForward_OnStatsEnable;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Core | LJ mode",
    description = "",
    version = "1.0"
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( LIBRARY_CORE_LJMODE );
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    // NATIVES
    g_hForward_OnStatsEnable = CreateGlobalForward( "Standup_OnStatsEnable", ET_Hook, Param_Cell, Param_String, Param_Cell );
    
    // CMDS
    RegConsoleCmd( "sm_lj", Command_ToggleLJ, "Toggle LJ stats." );
}

public Action Command_ToggleLJ( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( Standup_IsClientStatsEnabled( client ) )
    {
        Standup_SetClientStats( client, false );
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."LJ Stats: "...CLR_TEAM..."OFF" );
        return Plugin_Handled;
    }
    
    
    Action result;
    
    static char szMsg[256];
    strcopy( szMsg, sizeof( szMsg ), "Sorry, you cannot enable LJ stats!" );
    
    Call_StartForward( g_hForward_OnStatsEnable );
    Call_PushCell( client );
    Call_PushStringEx( szMsg, sizeof( szMsg ), 0, SM_PARAM_COPYBACK );
    Call_PushCell( sizeof( szMsg ) );
    int error = Call_Finish( result );
    
    if ( error != SP_ERROR_NONE ) return Plugin_Handled;
    
    
    if ( result == Plugin_Continue )
    {
        Standup_SetClientStats( client, true );
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."LJ Stats: "...CLR_TEAM..."ON" );
    }
    else
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."%s", szMsg );
    }
    
    return Plugin_Handled;
}