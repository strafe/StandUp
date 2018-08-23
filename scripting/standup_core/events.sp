public Action Event_RoundRestart( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
    RequestFrame( Event_RoundRestart_Delay );
}

public void Event_RoundRestart_Delay( any data )
{
    CheckBlocks();
}

public void Event_Teleport_OnStartTouch( const char[] szOut, int caller, int activator, float delay )
{
    if ( IS_ENT_PLAYER( activator ) )
    {
#if defined DEBUG
        PrintToServer( SU_PRE_DEV..."%i touched trigger_teleport!", activator );
#endif
        
        MarkAsCheated( activator, CHEATSTATE_NONE );
    }
}

public void Event_Client_WeaponSwitchPost( int client, int weapon )
{
    if ( GetPlayerMaxSpeed( client ) != VALID_WEP_SPD )
    {
        g_flLastBadSpdTime[client] = g_flCurTime;
    }
}

static float g_vecLastPos_Post[MAXPLAYERS][3];

public void Event_Client_PreThinkPost( int client )
{
    if ( !IsPlayerAlive( client ) ) return;
    
    
    static float vecCurPos[3];
    GetClientAbsOrigin( client, vecCurPos );
    
    if ( g_vecLastPos_Post[client][0] != vecCurPos[0] || g_vecLastPos_Post[client][1] != vecCurPos[1] || g_vecLastPos_Post[client][2] != vecCurPos[2] )
    {
#if defined DEBUG
        PrintToServer( SU_PRE_DEV..."Player's %i pos differs! (teleport, push(?))", client );
#endif
        
        MarkAsCheated( client, CHEATSTATE_NONE );
    }
}

public void Event_Client_PostThinkPost( int client )
{
    if ( !IsPlayerAlive( client ) ) return;
    
    
    GetClientAbsOrigin( client, g_vecLastPos_Post[client] );
}