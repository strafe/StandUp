// Everything related to playback and bots.
#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>
#include <msharedutil/misc>

#include <standup/stocks_chat>
#include <standup/core>

#undef REQUIRE_PLUGIN
#include <standup/hud>
#include <standup/help>


#pragma semicolon 1
#pragma newdecls required


//#define DEBUG
//#define DEBUG_PLAYBACK_TICK


#define RECORDING_PRE       -1
#define RECORDING_START     0

#define MAX_RECORD_FRAMES   350

#define MAX_BOTS            12

enum FrameData
{
    FRAME_BUTTONS = 0,
    Float:FRAME_POS[3],
    Float:FRAME_ANG[2]
};

#define FRAME_SIZE          6


ArrayList g_hRecording[MAXPLAYERS];
int g_nRecordingTick[MAXPLAYERS];


bool g_bAssignedBot[MAXPLAYERS];


// Best bots
ArrayList g_hBestRec[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];
int g_iBestBot[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];

float g_flBestDist[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];
float g_flBestPreSpd[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];
float g_flBestTopSpd[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];
int g_nBestStrfs[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];
float g_flBestSync[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];
char g_szBestName[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE][MAX_NAME_LENGTH];
char g_szBestJumpName[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE][32];


int g_iBotStyle[MAXPLAYERS];
int g_iBotDir[MAXPLAYERS];
int g_iBotStance[MAXPLAYERS];
int g_nRecMax[MAXPLAYERS];

int g_nNumLJBots;


ConVar g_ConVar_BotQuota;
ConVar g_ConVar_BotNoclip;
ConVar g_ConVar_NumBots;

float g_flTickRate;
int g_nMaxRecordingTicks;


bool g_bLibrary_Hud;

Handle g_hForward_CanUseBot;


#include "standup_recording/file.sp"


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Recording",
    description = "",
    version = "1.0"
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // NATIVES
    CreateNative( "Standup_LoadRecording", Native_LoadRecording );
    CreateNative( "Standup_SetRecordingBot", Native_SetRecordingBot );
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    // LIBRARIES
    g_bLibrary_Hud = LibraryExists( LIBRARY_HUD );
    
    // NATIVES
    g_hForward_CanUseBot = CreateGlobalForward( "Standup_CanUseBot", ET_Hook, Param_Cell );
    
    // EVENTS
    HookEvent( "player_spawn", Event_PlayerSpawn );
    
    // COMMANDS
#if defined DEBUG
    RegAdminCmd( "sm_listljrecinfo", Command_Admin_PrintInfo, ADMFLAG_ROOT );
#endif
    
    // CVARS
    g_ConVar_BotNoclip = CreateConVar( "standup_recording_botnoclip", "0", "Whether bots have noclip.", _, true, 0.0, true, 1.0 );
    HookConVarChange( g_ConVar_BotNoclip, Event_ConVar_BotNoclip );
    
    g_ConVar_NumBots = CreateConVar( "standup_recording_numbots", "1", "Number of lj playback bots to allow.", _, true, 0.0, true, 32.0 );
    
    g_ConVar_BotQuota = FindConVar( "bot_quota" );
    if ( g_ConVar_BotQuota == null )
    {
        SetFailState( SU_PRE_CLEAR..."Couldn't find cvar handle for bot_quota!" );
    }
    
    
    g_flTickRate = float( RoundFloat( 1 / GetTickInterval() ) );
    
    g_nMaxRecordingTicks = RoundFloat( g_flTickRate / 100.0 * MAX_RECORD_FRAMES );
    
#if defined DEBUG
    PrintToServer( SU_PRE_CLEAR..."Max recording ticks: %i", g_nMaxRecordingTicks );
#endif
    
    
    CreateTimer( 0.25, Timer_DisplayInfo, _, TIMER_REPEAT );
}

public void OnLibraryAdded( const char[] szName )
{
    if ( StrEqual( szName, LIBRARY_HUD ) ) g_bLibrary_Hud = true;
}

public void OnLibraryRemoved( const char[] szName )
{
    if ( StrEqual( szName, LIBRARY_HUD ) ) g_bLibrary_Hud = false;
}

public void OnConfigsExecuted()
{
    ConVar hCvar;
    
    hCvar = FindConVar( "bot_stop" );
    if ( hCvar != null )
    {
        hCvar.SetBool( true );
        delete hCvar;
    }
    
    hCvar = FindConVar( "bot_quota_mode" );
    if ( hCvar != null )
    {
        hCvar.SetString( "normal" );
        delete hCvar;
    }
    
    hCvar = FindConVar( "bot_join_after_player" );
    if ( hCvar != null )
    {
        hCvar.SetBool( false );
        delete hCvar;
    }
    
    hCvar = FindConVar( "bot_chatter" );
    if ( hCvar != null )
    {
        hCvar.SetString( "off" );
        delete hCvar;
    }
}

public void OnMapStart()
{
    g_nNumLJBots = 0;
    
    
    for ( int a = 0; a < NUM_JUMPSTYLE; a++ )
        for ( int b = 0; b < NUM_JUMPDIR; b++ )
            for ( int c = 0; c < NUM_JUMPSTANCE; c++ )
            {
                g_flBestDist[a][b][c] = 0.0;
                g_iBestBot[a][b][c] = 0;
                
                if ( g_hBestRec[a][b][c] != null )
                {
                    delete g_hBestRec[a][b][c];
                    g_hBestRec[a][b][c] = null;
                }
            }
    
    
#if defined DEBUG
    int num = LoadAllRecordings();
    
    PrintToServer( SU_PRE_CLEAR..."Loaded %i recording files!", num );
#else
    LoadAllRecordings();
#endif
    
    // Some delay has to be added since some timers will override the quota.
    CreateTimer( 5.0, Timer_AddBotQuota, _, TIMER_FLAG_NO_MAPCHANGE );
}

public Action Timer_AddBotQuota( Handle hTimer )
{
    if ( !g_ConVar_BotQuota.IntValue && g_ConVar_NumBots.IntValue )
        g_ConVar_BotQuota.SetInt( g_ConVar_NumBots.IntValue );
}

public void OnClientPutInServer( int client )
{
    if ( g_hRecording[client] != null )
    {
        delete g_hRecording[client];
        g_hRecording[client] = null;
    }
    
    if ( IsFakeClient( client ) )
    {
        if ( g_nNumLJBots < g_ConVar_NumBots.IntValue )
        {
            Action result;
            
            Call_StartForward( g_hForward_CanUseBot );
            Call_PushCell( client );
            Call_Finish( result );
            
            if ( result == Plugin_Continue )
            {
                SetClientInfo( client, "name", "LJ Record Playback" );
                g_bAssignedBot[client] = true;
                
                
                g_nRecordingTick[client] = 0;
                FindNextPlayback( client );
                
                g_nNumLJBots++;
                
                return;
            }
        }
        
        g_bAssignedBot[client] = false;
    }
    else
    {
        g_hRecording[client] = new ArrayList( view_as<int>( FrameData ), g_nMaxRecordingTicks );
        g_nRecordingTick[client] = 0;
    }
}

public void OnClientDisconnect( int client )
{
    if ( IsFakeClient( client ) )
    {
        if ( g_iBestBot[ g_iBotStyle[client] ][ g_iBotDir[client] ][ g_iBotStance[client] ] == client )
        {
            g_iBestBot[ g_iBotStyle[client] ][ g_iBotDir[client] ][ g_iBotStance[client] ] = 0;
        }
        
        if ( g_bAssignedBot[client] )
            g_nNumLJBots--;
    }
}

public Action Command_Admin_PrintInfo( int client, int args )
{
    int a, b, c;
    
    char szMsg[162];
    
    for ( a = 0; a < NUM_JUMPSTYLE; a++ )
        for ( b = 0; b < NUM_JUMPDIR; b++ )
            for ( c = 0; c < NUM_JUMPSTANCE; c++ )
                if ( g_hBestRec[a][b][c] != null )
                {
                    FormatEx( szMsg, sizeof( szMsg ), "%s | Ply Name: %s | Dist: %.1f", g_szBestJumpName[a][b][c], g_szBestName[a][b][c], g_flBestDist[a][b][c] );
                    
                    if ( client )
                    {
                        PrintToConsole( client, szMsg );
                    }
                    else
                    {
                        PrintToServer( szMsg );
                    }
                }
    
    return Plugin_Handled;
}

public void Standup_OnJumpFinished( int client, const int iJump[JMP_SIZE] )
{
    if ( iJump[JMP_RESULTFLAGS] & RESULT_FAILED ) return;
    
    if ( !IS_STYLE_LEGIT( iJump[JMP_STYLE] ) ) return;
    
    
    // Start to save the recording...
    if ( view_as<float>( iJump[JMP_DIST] ) > g_flBestDist[ iJump[JMP_STYLE] ][ iJump[JMP_DIR] ][ iJump[JMP_STANCE] ]/*iJump[JMP_RESULTFLAGS] & RESULT_BEST_DIST || view_as<float>( iJump[JMP_DIST] ) > GetVeryGoodDistance( iJump[JMP_STYLE], iJump[JMP_STANCE] )*/ )
    {
        DataPack dp;
        
        CreateDataTimer( 0.4, Timer_RecordSave, dp, TIMER_FLAG_NO_MAPCHANGE );
        
        dp.WriteCell( GetClientUserId( client ) );
        dp.WriteCell( iJump[JMP_STYLE] );
        dp.WriteCell( iJump[JMP_DIR] );
        dp.WriteCell( iJump[JMP_STANCE] );
        dp.WriteFloat( view_as<float>( iJump[JMP_DIST] ) );
        dp.WriteFloat( view_as<float>( iJump[JMP_PRESPD] ) );
        dp.WriteFloat( view_as<float>( iJump[JMP_TOPSPD] ) );
        dp.WriteCell( iJump[JMP_NUMSTRFS] );
        dp.WriteFloat( view_as<float>( iJump[JMP_AVG_SYNC] ) );
    }
}

public Action OnPlayerRunCmd(   int client,
                                int &buttons,
                                int &impulse, // Not used
                                float vel[3],
                                float angles[3] )
{
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    
    
    // Shared between recording and playback.
    static int iFrame[FRAME_SIZE];
    static float vecTemp[3];
    
    if ( !IsFakeClient( client ) )
    {
        if ( Standup_IsClientStatsEnabled( client ) )
        {
            /*
                RECORDING
            */
            GetEntPropVector( client, Prop_Data, "m_vecOrigin", vecTemp );
            //GetClientAbsOrigin( client, vecTemp );
            
            CopyArray( vecTemp, iFrame[FRAME_POS], 3 );
            CopyArray( angles, iFrame[FRAME_ANG], 2 );
            
            iFrame[FRAME_BUTTONS] = buttons;
            
            
            g_hRecording[client].SetArray( g_nRecordingTick[client], iFrame, view_as<int>( FrameData ) );
            
            if ( ++g_nRecordingTick[client] >= g_nMaxRecordingTicks )
            {
                g_nRecordingTick[client] = 0;
            }
        }
        
        return Plugin_Continue;
    }
    
    /*
        PLAYBACK
    */
    if ( !g_bAssignedBot[client] ) return Plugin_Continue;
    
    
    if ( g_hBestRec[ g_iBotStyle[client] ][ g_iBotDir[client] ][ g_iBotStance[client] ] != null )
    {
        vel = ORIGIN_VECTOR;
        
#if defined DEBUG_PLAYBACK_TICK
        PrintToServer( "[%i, %i, %i] | Playback tick: %i", g_iBotStyle[client], g_iBotDir[client], g_iBotStance[client], g_nRecordingTick[client] );
#endif
        
        if ( g_nRecordingTick[client] == RECORDING_PRE )
        {
            g_hBestRec[ g_iBotStyle[client] ][ g_iBotDir[client] ][ g_iBotStance[client] ].GetArray( 0, iFrame, view_as<int>( FrameData ) );
            
            buttons = iFrame[FRAME_BUTTONS];
            
            CopyArray( iFrame[FRAME_POS], vecTemp, 3 );
            CopyArray( iFrame[FRAME_ANG], angles, 2 );
            
            
            TeleportEntity( client, vecTemp, angles, ORIGIN_VECTOR );
            
            return Plugin_Continue;
        }
        else if ( g_nRecordingTick[client] < g_nRecMax[client] )
        {
            g_hBestRec[ g_iBotStyle[client] ][ g_iBotDir[client] ][ g_iBotStance[client] ].GetArray( g_nRecordingTick[client], iFrame, view_as<int>( FrameData ) );
            
            // Build velocity.
            static float vecPrevPos[3];
            GetClientAbsOrigin( client, vecPrevPos );
            
            
            buttons = iFrame[FRAME_BUTTONS];
            
            CopyArray( iFrame[FRAME_POS], vecTemp, 3 );
            CopyArray( iFrame[FRAME_ANG], angles, 2 );
            
            #define MAX_DIST    128.0
            #define MAX_DIST_SQ    MAX_DIST * MAX_DIST
            
            if ( GetVectorDistance( vecPrevPos, vecTemp, true ) > MAX_DIST_SQ )
            {
                TeleportEntity( client, vecTemp, angles, NULL_VECTOR );
            }
            else
            {
                for ( int i = 0; i < 3; i++ )
                {
                    vecTemp[i] = ( vecTemp[i] - vecPrevPos[i] ) * g_flTickRate;
                }
                
                TeleportEntity( client, NULL_VECTOR, angles, vecTemp );
            }
            
            
            if ( ++g_nRecordingTick[client] >= g_nRecMax[client] )
            {
                CreateTimer( 0.5, Timer_Bot_GotoStart, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
            }
            
            return Plugin_Continue;
        }
    }
    
    return Plugin_Continue;
}

public void Event_ConVar_BotNoclip( ConVar hConVar, const char[] szOldValue, const char[] szNewValue )
{
    MoveType mtype = hConVar.BoolValue ? MOVETYPE_NOCLIP : MOVETYPE_WALK;
    
    for ( int i = 1; i <= MaxClients; i++ )
        if ( IsClientInGame( i ) && IsFakeClient( i ) )
            SetEntityMoveType( i, mtype );
}

public void Event_PlayerSpawn( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
    int client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
    
    if ( !client || GetClientTeam( client ) <= CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    if ( !IsFakeClient( client ) ) return;
    
    
    RequestFrame( Event_PlayerSpawn_Delay, GetClientUserId( client ) );
}

public void Event_PlayerSpawn_Delay( int client )
{
    if ( (client = GetClientOfUserId( client )) && IsPlayerAlive( client ) && g_bAssignedBot[client] )
    {
        SetEntityGravity( client, 0.0 );
        
        if ( g_ConVar_BotNoclip.BoolValue )
        {
            SetEntityMoveType( client, MOVETYPE_NOCLIP );
        }
        
        // Debris + no trigger collision.
        SetEntProp( client, Prop_Send, "m_CollisionGroup", 1 );
    }
}

// TIMERS
public Action Timer_Bot_GotoStart( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) )
    {
        FindNextPlayback( client );
        
        g_nRecordingTick[client] = RECORDING_PRE;
        
        CreateTimer( 0.5, Timer_Bot_StartPlayback, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
    }
}

public Action Timer_Bot_StartPlayback( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) )
    {
        g_nRecordingTick[client] = RECORDING_START;
    }
}

public Action Timer_RecordSave( Handle hTimer, DataPack dp )
{
    dp.Reset();
    
    int client = dp.ReadCell();
    
    if ( !(client = GetClientOfUserId( client )) ) return Plugin_Handled;
    
    
    if ( g_hRecording[client] != null && g_hRecording[client].Length > 2 )
    {
        int style = dp.ReadCell();
        int dir = dp.ReadCell();
        int stance = dp.ReadCell();
        float dist = dp.ReadFloat();
        float prespd = dp.ReadFloat();
        float topspd = dp.ReadFloat();
        int strfs = dp.ReadCell();
        float sync = dp.ReadFloat();
        
        char szName[MAX_NAME_LENGTH];
        GetClientName( client, szName, sizeof( szName ) );
        
        // Copy everything over.
        CloneRecording( g_hRecording[client], g_hBestRec[style][dir][stance], g_nRecordingTick[client] );
        
        // And the record data.
        g_flBestDist[style][dir][stance] = dist;
        g_flBestPreSpd[style][dir][stance] = prespd;
        g_flBestTopSpd[style][dir][stance] = topspd;
        g_nBestStrfs[style][dir][stance] = strfs;
        g_flBestSync[style][dir][stance] = sync;
        
        strcopy( g_szBestName[style][dir][stance], sizeof( g_szBestName[][][] ), szName );
        
        FormatJumpName( g_szBestJumpName[style][dir][stance], sizeof( g_szBestJumpName[][][] ), style, dir, stance, true, true );
        
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Your record can be viewed through a record bot!" );
        
        if ( !SaveRecording( style, dir, stance, g_hBestRec[style][dir][stance],
            dist,
            prespd,
            topspd,
            strfs,
            sync,
            szName ) )
        {
            SU_PrintToChat( client, client, SU_PRE_CHAT..."Couldn't save your recording to disk!!" );
        }
    }
    else
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Couldn't save your record!" );
    }
    
    return Plugin_Handled;
}

public Action Timer_DisplayInfo( Handle hTimer )
{
    int target;
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) || IsPlayerAlive( i ) ) continue;
        
        if ( g_bLibrary_Hud )
        {
            if ( Standup_GetClientHideFlags( i ) & HIDEFLAG_PLAYBACKINFO )
                continue;
        }
        
        
        target = GetClientObserverTarget( i );
        
        if ( IS_ENT_PLAYER( target ) && IsClientInGame( target ) && IsPlayerAlive( target ) && IsFakeClient( target ) && g_bAssignedBot[target] )
        {
            int style = g_iBotStyle[target];
            int dir = g_iBotDir[target];
            int stance = g_iBotStance[target];
            
            if ( g_hBestRec[style][dir][stance] != null && g_nRecMax[target] > 0 )
            {
                PrintHintText( i, "%s\n%s\n%.3f units\n \nPrespeed: %.1f\nMax speed: %.1f\nStrafes: %i\nSync: %.1f pct.",
                    g_szBestName[style][dir][stance],
                    g_szBestJumpName[style][dir][stance],
                    g_flBestDist[style][dir][stance],
                    g_flBestPreSpd[style][dir][stance],
                    g_flBestTopSpd[style][dir][stance],
                    g_nBestStrfs[style][dir][stance],
                    g_flBestSync[style][dir][stance] );
            }
            else
            {
                PrintHintText( i, "Empty Recording" );
            }
        }
    }
}

stock void CloneRecording( ArrayList &hFrom, ArrayList &hTo, int startindex = 0 )
{
    if ( hTo != null ) delete hTo;
    
    hTo = new ArrayList( view_as<int>( FrameData ) );
    
    int len = hFrom.Length;
    int lastframe = startindex - 1;
    
    if ( lastframe < 0 ) lastframe = len - 1;
    
    // Alright, copy our stuff from the first frame.
    int iData[FRAME_SIZE];
    for ( int i = startindex;; i++ )
    {
        if ( i >= len ) i = 0;
        
        
        hFrom.GetArray( i, iData, view_as<int>( FrameData ) );
        
        // Stops the annoying shooting.
        iData[FRAME_BUTTONS] &= ~IN_ATTACK;
        
        hTo.PushArray( iData, view_as<int>( FrameData ) );

        if ( i == lastframe ) break;
    }
    
    len = hTo.Length;
}

#define IS_RECORDING_TAKEN(%0,%1,%2)        ( g_iBestBot[%0][%1][%2] != 0 )

stock bool FindNextPlayback( int bot )
{
    int i;
    
    for ( i = g_iBotStance[bot] + 1; i < NUM_JUMPSTANCE; i++ )
        if ( g_hBestRec[ g_iBotStyle[bot] ][ g_iBotDir[bot] ][i] != null && !IS_RECORDING_TAKEN( g_iBotStyle[bot], g_iBotDir[bot], i ) )
        {
            CopyRecordingToBot( bot, g_iBotStyle[bot], g_iBotDir[bot], i );
            
            return true;
        }
    
    for ( i = g_iBotDir[bot] + 1; i < NUM_JUMPDIR; i++ )
        if ( g_hBestRec[ g_iBotStyle[bot] ][i][0] != null && !IS_RECORDING_TAKEN( g_iBotStyle[bot], i, 0 ) )
        {
            CopyRecordingToBot( bot, g_iBotStyle[bot], i, 0 );
            
            return true;
        }
    
    int j, k;
    int startindex = g_iBotStyle[bot] + 1;
    
    if ( !IS_STYLE( startindex ) )
        startindex = 0;
    
    for ( i = startindex; i < NUM_JUMPSTYLE; i++ )
        for ( j = 0; j < NUM_JUMPDIR; j++ )
            for ( k = 0; k < NUM_JUMPSTANCE; k++ )
                if ( g_hBestRec[i][j][k] != null && !IS_RECORDING_TAKEN( i, j, k ) )
                {
                    CopyRecordingToBot( bot, i, j, k );
                    
                    return true;
                }
    
    for ( i = 0; i < NUM_JUMPSTYLE; i++ )
        for ( j = 0; j < NUM_JUMPDIR; j++ )
            for ( k = 0; k < NUM_JUMPSTANCE; k++ )
                if ( g_hBestRec[i][j][k] != null && !IS_RECORDING_TAKEN( i, j, k ) )
                {
                    CopyRecordingToBot( bot, i, j, k );
                    
                    return true;
                }
    
    return false;
}

stock void CopyRecordingToBot( int bot, int style, int dir, int stance )
{
    g_iBestBot[ g_iBotStyle[bot] ][ g_iBotDir[bot] ][ g_iBotStance[bot] ] = 0;
    
    g_iBotStyle[bot] = style;
    g_iBotDir[bot] = dir;
    g_iBotStance[bot] = stance;
    
    g_nRecMax[bot] = GetArrayLength_Safe( g_hBestRec[style][dir][stance] );
    
    g_iBestBot[style][dir][stance] = bot;
}

// NATIVES
public int Native_LoadRecording( Handle hPlugin, int numParams )
{
    int style = GetNativeCell( 1 );
    if ( !IS_STYLE( style ) ) return 0;
    
    int dir = GetNativeCell( 2 );
    if ( !IS_DIR( dir ) ) return 0;
    
    int stance = GetNativeCell( 3 );
    if ( !IS_STANCE( stance ) ) return 0;
    
    LoadRecording( style, dir, stance );
    
    return 1;
}

public int Native_SetRecordingBot( Handle hPlugin, int numParams )
{
    int bot = GetNativeCell( 1 );
    
    g_bAssignedBot[bot] = GetNativeCell( 2 ) ? true : false;
    
    return 1;
}