#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>

#include <msharedutil/ents>

#include <standup/stocks_chat>
#include <standup/core>
#include <standup/teams>


#pragma semicolon 1
#pragma newdecls required


int g_iPreferredTeam;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Teams",
    description = "",
    version = "1.0"
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( LIBRARY_TEAMS );
    
    // NATIVES
    CreateNative( "Standup_GetPreferredTeam", Native_GetPreferredTeam );
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_spec", Command_Spec, "Go to spectator team." );
    RegConsoleCmd( "sm_spectate", Command_Spec );
    RegConsoleCmd( "sm_spectator", Command_Spec );
    
    RegConsoleCmd( "sm_r", Command_Spawn );
    RegConsoleCmd( "sm_re", Command_Spawn );
    RegConsoleCmd( "sm_respawn", Command_Spawn );
    RegConsoleCmd( "sm_spawn", Command_Spawn );
    
    
    LoadTranslations( "common.phrases" );
}

public void OnMapStart()
{
    int num_ct;
    int num_t;
    
    int ent = -1;
    while ( (ent = FindEntityByClassname( ent, "info_player_counterterrorist" )) != -1 ) num_ct++;
    ent = -1;
    while ( (ent = FindEntityByClassname( ent, "info_player_terrorist" )) != -1 ) num_t++;
    
    
    g_iPreferredTeam = ( num_ct >= num_t ) ? CS_TEAM_CT : CS_TEAM_T;
}

public Action Command_Spec( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR )
    {
        ChangeClientTeam( client, g_iPreferredTeam );
        CS_RespawnPlayer( client );
    }
    else
    {
        int target = 0;
        
        if ( args )
        {
            char szTarget[MAX_NAME_LENGTH];
            GetCmdArgString( szTarget, sizeof( szTarget ) );
            
            target = FindTarget( client, szTarget, false, false );
        }
        
        ChangeClientTeam( client, CS_TEAM_SPECTATOR );
        
        if ( client != target && IS_ENT_PLAYER( target ) && IsClientInGame( target ) && IsPlayerAlive( target ) )
        {
            SetEntPropEnt( client, Prop_Send, "m_hObserverTarget", target );
            SetEntProp( client, Prop_Send, "m_iObserverMode", OBS_MODE_IN_EYE );
        }
    }
    
    return Plugin_Handled;
}

public Action Command_Spawn( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR )
    {
        ChangeClientTeam( client, g_iPreferredTeam );
    }
    
    CS_RespawnPlayer( client );
    
    return Plugin_Handled;
}

// NATIVES
public int Native_GetPreferredTeam( Handle hPlugin, int numParams )
{
    return g_iPreferredTeam;
}