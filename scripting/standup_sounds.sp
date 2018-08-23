// Everything related to sounds.
#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>

#include <standup/stocks_chat>
#include <standup/core>

#undef REQUIRE_PLUGIN
#include <standup/hud>


#pragma semicolon 1
#pragma newdecls required


//#define DEBUG


#define PLATFORM_MAX_PATH_CELL  PLATFORM_MAX_PATH / 4

#define FILE_NAME               "standup_sounds.cfg"


bool g_bLibrary_Hud;


ArrayList g_hSounds_Good;
ArrayList g_hSounds_VeryGood;
ArrayList g_hSounds_Amazing;
ArrayList g_hSounds_Best;

EngineVersion g_Engine;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Sounds",
    description = "",
    version = "1.0"
};

public void OnPluginStart()
{
    // LIBRARIES
    g_bLibrary_Hud = LibraryExists( LIBRARY_HUD );
    
    
    g_hSounds_Good = new ArrayList( PLATFORM_MAX_PATH_CELL );
    g_hSounds_VeryGood = new ArrayList( PLATFORM_MAX_PATH_CELL );
    g_hSounds_Amazing = new ArrayList( PLATFORM_MAX_PATH_CELL );
    g_hSounds_Best = new ArrayList( PLATFORM_MAX_PATH_CELL );
    
    
    g_Engine = GetEngineVersion();
}

public void OnLibraryAdded( const char[] szName )
{
    if ( StrEqual( szName, LIBRARY_HUD ) ) g_bLibrary_Hud = true;
}

public void OnLibraryRemoved( const char[] szName )
{
    if ( StrEqual( szName, LIBRARY_HUD ) ) g_bLibrary_Hud = false;
}

stock bool PrecacheSound_( char[] sz )
{
    PrecacheSound
}

public void OnMapStart()
{
    g_hSounds_Good.Clear();
    g_hSounds_VeryGood.Clear();
    g_hSounds_Amazing.Clear();
    g_hSounds_Best.Clear();
    
    
    char szBuffer[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szBuffer, sizeof( szBuffer ), "configs/"...FILE_NAME );
    
    File hFile = OpenFile( szBuffer, "r" );
    
    
    if ( hFile != null )
    {
        enum
        {
            SNDTYPE_GOOD = 0,
            SNDTYPE_VERYGOOD,
            SNDTYPE_AMAZING,
            SNDTYPE_BEST
        };
        
        char szLine[PLATFORM_MAX_PATH + 128];
        char szDownload[PLATFORM_MAX_PATH];
        
        int index;
        int char_index;
        int arg;
        
        int sndtype;
       // int comindex;
        
        while ( hFile.ReadLine( szLine, sizeof( szLine ) ) )
        {
            index = 0;
            char_index = 0;
            arg = 0;
            
            // Check has to be AT THE END of the loop.
            do
            {
                index = BreakString( szLine[char_index], szBuffer, sizeof( szBuffer ) );
                
                if ( szBuffer[0] == '\0' || szBuffer[0] == '\n' ) break;
                
                if ( StrContains( szBuffer, "//" ) == 0 )
                {
                    break;
                }
                
#if defined DEBUG
                PrintToServer( SU_PRE_CLEAR..."Found string: \"%s\"", szBuffer );
#endif
                
                switch ( arg )
                {
                    case 0 :
                    {
                        #define GOOD_STR            "good"
                        #define VERYGOOD_STR        "verygood"
                        #define AMAZING_STR         "amazing"
                        #define BEST_STR            "best"
                        
                        if ( StrContains( szBuffer, GOOD_STR, false ) == 0 )
                        {
                            sndtype = SNDTYPE_GOOD;
                        }
                        else if ( StrContains( szBuffer, VERYGOOD_STR, false ) == 0 )
                        {
                            sndtype = SNDTYPE_VERYGOOD;
                        }
                        else if ( StrContains( szBuffer, AMAZING_STR, false ) == 0 )
                        {
                            sndtype = SNDTYPE_AMAZING;
                        }
                        else if ( StrContains( szBuffer, BEST_STR, false ) == 0 )
                        {
                            sndtype = SNDTYPE_BEST;
                        }
                        else
                        {
                            LogError( SU_PRE_CLEAR..."Found invalid sound type \"%s\"! Please use "...GOOD_STR..."/"...VERYGOOD_STR..."/"...AMAZING_STR..."/"...BEST_STR, szBuffer );
                            break;
                        }
                    }
                    case 1 :
                    {
                        if ( StrContains( szBuffer, "sound", false ) == 0 && (szBuffer[5] == '\\' || szBuffer[5] == '/') )
                        {
                            LogError( SU_PRE_CLEAR..."Please remove \"sound/\" from the sound path! (%s)", szBuffer );
                        }
                        
                        /*comindex = StrContains( szBuffer, "//", false );
                        
                        if ( comindex != -1 )
                        {
                            szBuffer
                        }*/
                        
                        
                        if ( g_Engine == Engine_CSGO || PrecacheSound( szBuffer ) )
                        {
                            FormatEx( szDownload, sizeof( szDownload ), "sound/%s", szBuffer );
                            
                            AddFileToDownloadsTable( szDownload );
                            
                            PrefetchSound( szBuffer );
                        }
                        else
                        {
                            LogError( SU_PRE_CLEAR..."Unable to precache sound \"%s\"! Please make sure your path is valid!", szBuffer );
                            break;
                        }
                        
                        
                        switch ( sndtype )
                        {
                            case SNDTYPE_GOOD : g_hSounds_Good.PushString( szBuffer );
                            case SNDTYPE_VERYGOOD : g_hSounds_VeryGood.PushString( szBuffer );
                            case SNDTYPE_AMAZING : g_hSounds_Amazing.PushString( szBuffer );
                            case SNDTYPE_BEST : g_hSounds_Best.PushString( szBuffer );
                            default : break;
                        }
                    }
                    default : break;
                }
                
                arg++;
                char_index += index;
            }
            while ( index != -1 || arg < 2 );
        }

    }
    
    delete hFile;
}

public void Standup_OnJumpFinished(    int client, const int iJump[JMP_SIZE] )
{
    if ( iJump[JMP_RESULTFLAGS] & RESULT_FAILED ) return;
    
    
    int style = iJump[JMP_STYLE];
    
    if ( !IS_STYLE_LEGIT( style ) ) return;
    
    
    int len;
    static char szSound[PLATFORM_MAX_PATH];
    
    int stance = iJump[JMP_STANCE];
    float flDistance = view_as<float>( iJump[JMP_DIST] );
    
    if ( iJump[JMP_RESULTFLAGS] & RESULT_BEST_BLOCK || iJump[JMP_RESULTFLAGS] & RESULT_BEST_DIST )
    {
        if ( (len = GetArrayLength_Safe( g_hSounds_Best )) <= 0 )
            return;
        
        // Has to be at least good so it doesn't get spammed.
        if ( flDistance < Standup_GetVeryGoodDistance( style, stance ) )
            return;
        
        
        g_hSounds_Best.GetString( GetRandomInt( 0, len - 1 ), szSound, sizeof( szSound ) );
        
        PlayRecordSound( szSound, true );
    }
    else if ( flDistance >= Standup_GetAmazingDistance( style, stance ) )
    {
        if ( (len = GetArrayLength_Safe( g_hSounds_Amazing )) <= 0 )
            return;
        
        
        g_hSounds_Amazing.GetString( GetRandomInt( 0, len - 1 ), szSound, sizeof( szSound ) );
        
        PlayRecordSound( szSound, false );
    }
    else if ( flDistance >= Standup_GetVeryGoodDistance( style, stance ) )
    {
        if ( (len = GetArrayLength_Safe( g_hSounds_VeryGood )) <= 0 )
            return;
        
        
        g_hSounds_VeryGood.GetString( GetRandomInt( 0, len - 1 ), szSound, sizeof( szSound ) );
        
        PlayRecordSoundToClient( client, szSound );
    }
    else if ( flDistance >= Standup_GetGoodDistance( style, stance ) )
    {
        if ( (len = GetArrayLength_Safe( g_hSounds_Good )) <= 0 )
            return;
        
        
        g_hSounds_Good.GetString( GetRandomInt( 0, len - 1 ), szSound, sizeof( szSound ) );
        
        PlayRecordSoundToClient( client, szSound );
    }
}

stock void PlayRecordSound( const char[] szSound, bool bBest = false )
{
#if defined DEBUG
    PrintToServer( SU_PRE_CLEAR..."Playing sound to everybody!" );
#endif
    
    // Play to everybody.
    int[] clients = new int[MaxClients];
    int nClients;
    
    int wantedflag = bBest ? HIDEFLAG_WRSNDS : HIDEFLAG_GLOBALSNDS;
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
        
        
        if ( g_bLibrary_Hud )
        {
            if ( Standup_GetClientHideFlags( i ) & wantedflag ) continue;
        }
        
        clients[nClients++] = i;
    }
    
    if ( nClients )
    {
        EmitSound_CSGO( clients, nClients, szSound );
    }
}

stock void PlayRecordSoundToClient( int client, const char[] szSound )
{
#if defined DEBUG
    PrintToServer( SU_PRE_CLEAR..."Playing sounds to %N!", client );
#endif
    
    // Play to target and spectators.
    int[] clients = new int[MaxClients];
    int nClients;
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
        
        if ( i != client && (IsPlayerAlive( i ) || GetClientObserverTarget( i ) != client) )
        {
            continue;
        }
        
        
        if ( g_bLibrary_Hud )
        {
            if ( Standup_GetClientHideFlags( i ) & HIDEFLAG_SNDS ) continue;
        }
        
        clients[nClients++] = i;
    }
    
    if ( nClients )
    {
        EmitSound_CSGO( clients, nClients, szSound );
    }
}

stock void EmitSound_CSGO( const int[] clients, int nClients, const char[] szSound )
{
    if ( g_Engine == Engine_CSGO )
    {
        char szCommand[PLATFORM_MAX_PATH + 16];
        FormatEx( szCommand, sizeof( szCommand ), "play */%s", szSound );
        
        for ( int i = 0; i < nClients; i++ )
        {
            ClientCommand( clients[i], szCommand );
        }
    }
    else
    {
        EmitSound( clients, nClients, szSound );
    }
}