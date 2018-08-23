#include <sourcemod>
#include <clientprefs>

#include <standup/stocks_chat>
#include <standup/core>
#include <standup/hud>

//#undef REQUIRE_PLUGIN
//#include <standup/help>


#pragma semicolon 1
#pragma newdecls required


Handle g_hCookie_HideFlags;

int g_fHideFlags[MAXPLAYERS];


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - HUD",
    description = "Requires for all display related things",
    version = "1.0"
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( LIBRARY_HUD );
    
    
    // NATIVES
    CreateNative( "Standup_GetClientHideFlags", Native_GetClientHideFlags );
    CreateNative( "Standup_SetClientHideFlags", Native_SetClientHideFlags );
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    if ( (g_hCookie_HideFlags = RegClientCookie( "standup_hideflags", "Standup HUD Flags", CookieAccess_Protected )) == null )
    {
        SetFailState( SU_PRE_CLEAR..."Couldn't register hideflags cookie!" );
    }
}

public void OnClientDisconnect( int client )
{
    if ( !IsFakeClient( client ) )
    {
        char szCookie[12];
        IntToString( g_fHideFlags[client], szCookie, sizeof( szCookie ) );
        
        SetClientCookie( client, g_hCookie_HideFlags, szCookie );
    }
}

public void OnClientCookiesCached( int client )
{
    if ( AreClientCookiesCached( client ) )
    {
        char szCookie[12];
        GetClientCookie( client, g_hCookie_HideFlags, szCookie, sizeof( szCookie ) );
        
        if ( szCookie[0] != '\0' )
        {
            g_fHideFlags[client] = StringToInt( szCookie );
        }
        else
        {
            g_fHideFlags[client] = DEF_HIDEFLAGS;
        }
    }
    else
    {
        g_fHideFlags[client] = DEF_HIDEFLAGS;
    }
}

// NATIVES
public int Native_GetClientHideFlags( Handle hPlugin, int numParams )
{
    return g_fHideFlags[GetNativeCell( 1 )];
}

public int Native_SetClientHideFlags( Handle hPlugin, int numParams )
{
    g_fHideFlags[GetNativeCell( 1 )] = GetNativeCell( 2 );
    
    return 1;
}