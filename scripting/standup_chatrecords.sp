#include <sourcemod>

#include <msharedutil/misc>

#include <standup/stocks_chat>
#include <standup/core>

#undef REQUIRE_PLUGIN
#include <standup/hud>


#pragma semicolon 1
#pragma newdecls required


bool g_bLibrary_Hud;


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Chat Records",
    description = "Handles LJ record printing in chat.",
    version = "1.0"
};

public void OnPluginStart()
{
    g_bLibrary_Hud = LibraryExists( LIBRARY_HUD );
}

public void OnLibraryAdded( const char[] szName )
{
    if ( StrEqual( szName, LIBRARY_HUD ) ) g_bLibrary_Hud = true;
}

public void OnLibraryRemoved( const char[] szName )
{
    if ( StrEqual( szName, LIBRARY_HUD ) ) g_bLibrary_Hud = false;
}

public void Standup_OnJumpFinished(    int client, const int iJump[JMP_SIZE] )
{
    if ( iJump[JMP_RESULTFLAGS] & RESULT_FAILED ) return;
    
    if ( !IS_STYLE_LEGIT( iJump[JMP_STYLE] ) ) return;
    
    
    // Do the chat printing. Requires that the distance is at least good.
    bool bBest = ( iJump[JMP_RESULTFLAGS] & RESULT_BEST_DIST || iJump[JMP_RESULTFLAGS] & RESULT_BEST_BLOCK );
    bool bPB = ( iJump[JMP_RESULTFLAGS] & RESULT_PB_DIST || iJump[JMP_RESULTFLAGS] & RESULT_PB_BLOCK );
    bool bGoodDist = ( view_as<float>( iJump[JMP_DIST] ) >= Standup_GetGoodDistance( iJump[JMP_STYLE], iJump[JMP_STANCE] ) );
    
    
    if ( !bGoodDist && !bPB && !bBest ) return;
    
    
    // The jump name. Use lowercase letters only.
    char szJump[32];
    FormatJumpName( szJump, sizeof( szJump ), iJump[JMP_STYLE], iJump[JMP_DIR], iJump[JMP_STANCE], true, true );
    
    StringToLower( szJump );
    
    
    // Block stuff...
    char szBlock[36];
    
    if ( iJump[JMP_BLOCK] )
    {
        FormatEx( szBlock, sizeof( szBlock ), " ("...CLR_TEAM..."%i block"...CLR_CHAT...", "...CLR_TEAM..."%.1f edge"...CLR_CHAT...")", iJump[JMP_BLOCK], iJump[JMP_BLOCK_EDGE] );
    }
    
    
    // Results...
    char szResults[32];
    
    if ( iJump[JMP_RESULTFLAGS] & RESULT_PB_DIST && !(iJump[JMP_RESULTFLAGS] & RESULT_BEST_DIST) )
    {
        strcopy( szResults, sizeof( szResults ), " (\x04PB DIST"...CLR_CHAT...")" );
    }
    
    if ( iJump[JMP_RESULTFLAGS] & RESULT_PB_BLOCK && !(iJump[JMP_RESULTFLAGS] & RESULT_BEST_BLOCK) )
    {
        Format( szResults, sizeof( szResults ), "%s (\x04PB BLOCK"...CLR_CHAT...")", szResults );
    }
    
    if ( iJump[JMP_RESULTFLAGS] & RESULT_BEST_DIST )
    {
        Format( szResults, sizeof( szResults ), "%s (\x04REC DIST"...CLR_CHAT...")", szResults );
    }
    
    if ( iJump[JMP_RESULTFLAGS] & RESULT_BEST_BLOCK )
    {
        Format( szResults, sizeof( szResults ), "%s (\x04REC BLOCK"...CLR_CHAT...")", szResults );
    }
    
    char szTrueDist[32];
    // If it wasn't a block jump, display our true distance.
    if ( !iJump[JMP_BLOCK] && iJump[JMP_STYLE] != JUMPSTYLE_LADDER )
    {
        FormatEx( szTrueDist, sizeof( szTrueDist ), " (true: "...CLR_TEAM..."%.1f"...CLR_CHAT...")", iJump[JMP_DIST_TRUE] );
    }
    
    // "CXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXC did C133.7C (true: C133.7C) unit Cbw standup ladderC with C%i strfs @ 100.0%C! (C270 blockC, C10.0 edgeC) (CREC DISTC) (CREC BLOCKC)"
    char szBuffer[MAX_SAYTEXT2_LENGTH];
    
    FormatEx( szBuffer, sizeof( szBuffer ), SU_PRE_CHAT...CLR_TEAM..."%N"...CLR_CHAT..." did \x04%.1f"...CLR_CHAT..."%s unit "...CLR_TEAM..."%s"...CLR_CHAT..." with "...CLR_TEAM..."%i strfs @ %.1f%%"...CLR_CHAT..."!%s%s",
        client,
        iJump[JMP_DIST],
        szTrueDist,
        szJump,
        iJump[JMP_NUMSTRFS],
        iJump[JMP_AVG_SYNC],
        szBlock,
        szResults );
    
    
    // And print to players...
    int[] clients = new int[MaxClients];
    int nClients;
    
    if ( !g_bLibrary_Hud || !(Standup_GetClientHideFlags( client ) & HIDEFLAG_MYCHATRECORD) )
    {
        clients[nClients++] = client;
    }
    
    if ( bGoodDist || bBest )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
            
            if ( i == client ) continue;
            
            if ( g_bLibrary_Hud )
            {
                if ( bBest )
                {
                    if ( Standup_GetClientHideFlags( i ) & HIDEFLAG_RECCHATRECORD )
                        continue;
                }
                else if ( Standup_GetClientHideFlags( i ) & HIDEFLAG_CHATRECORD )
                    continue;
            }
            
            
            clients[nClients++] = i;
        }
    }
    
    if ( nClients )
    {
        SU_SendSayText2( client, clients, nClients, szBuffer );
    }
}