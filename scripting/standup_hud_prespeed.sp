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


ConVar g_ConVar_Interval;
int g_nIntervalMod = 8;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - HUD | Prespeed",
    description = "",
    version = "1.0"
};

public void OnPluginStart()
{
    RegConsoleCmd( "sm_prespeed", Command_PreSpeed );
    
    
    // CVARS
    g_ConVar_Interval = CreateConVar( "standup_hud_prespeed_interval", "0.08", "Update interval for prespeed.", _, true, 0.01, true, 1.0 );
    HookConVarChange( g_ConVar_Interval, Event_ConVar_Interval );
    
    //CreateTimer( 0.05, Timer_DisplayPrespeed, _, TIMER_REPEAT );
}

public void Standup_RequestHelpCmds()
{
    Standup_AddCommand( "prespeed", "Toggle prespeed displaying.", true );
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
    float spd;
    MoveType movetype;
    int flags;
    
    for ( int client = 1; client <= MaxClients; client++ )
    {
        if ( !IsClientInGame( client ) || IsFakeClient( client ) ) continue;
        
        if ( !Standup_IsClientStatsEnabled( client ) ) continue;
        
        
        if ( !IsPlayerAlive( client ) )
        {
            if ( !IS_ENT_PLAYER( (target = GetClientObserverTarget( client )) ) ) continue;
            
            if ( !IsClientInGame( target ) || !IsPlayerAlive( target ) || IsFakeClient( target ) ) continue;
        }
        else
        {
            target = client;
        }
        
        if ( !(Standup_GetClientHideFlags( client ) & HIDEFLAG_PRESPD) && Standup_GetClientNextHint( client ) < GetEngineTime() )
        {
            if ( GetEntProp( target, Prop_Send, "m_nWaterLevel" ) > 1 )
            {
                continue;
            }
            
            
            #define MIN_SPD                 200.0
            #define MIN_SPD_SQ              MIN_SPD * MIN_SPD
            
            #define MIN_SPD_DUCKED          70.0
            #define MIN_SPD_DUCKED_SQ       MIN_SPD_DUCKED * MIN_SPD_DUCKED
            
            #define MIN_SPD_LADDER          150.0
            #define MIN_SPD_LADDER_SQ       MIN_SPD_LADDER * MIN_SPD_LADDER
            
            flags = GetEntityFlags( target );
            
            movetype = GetEntityMoveType( target );
            
            if ( movetype != MOVETYPE_WALK )
            {
                if ( movetype == MOVETYPE_LADDER )
                {
                    spd = GetEntityTrueSpeedSquared( target );
                    
                    if ( spd > MIN_SPD_LADDER_SQ )
                    {
                        DisplayPrespeed( client, SquareRoot( spd ) );
                    }
                }
                
                continue;
            }
            
            if ( flags & FL_ONGROUND )
            {
                spd = GetEntitySpeedSquared( target );
                
                if ( flags & FL_DUCKING )
                {
                    if ( spd >= MIN_SPD_DUCKED_SQ )
                    {
                        DisplayPrespeed( client, SquareRoot( spd ) );
                    }
                }
                else if ( spd >= MIN_SPD_SQ )
                {
                    DisplayPrespeed( client, SquareRoot( spd ) );
                }
            }
            else if ( (spd = Standup_GetClientPrespeed( target )) > MIN_SPD )
            {
                DisplayPrespeed( client, spd );
            }
        }
    }
}

public Action Command_PreSpeed( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_PRESPD )
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) & ~HIDEFLAG_PRESPD );
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Prespeed: "...CLR_TEAM..."ON" );
    }
    else
    {
        Standup_SetClientHideFlags( client, Standup_GetClientHideFlags( client ) | HIDEFLAG_PRESPD );
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Prespeed: "...CLR_TEAM..."OFF" );
    }
    
    return Plugin_Handled;
}

stock void DisplayPrespeed( int client, float spd )
{
    PrintHintText( client, "Prespeed\n%04.1f", spd );
}