// Includes menus.
stock bool CheckDist( int client, int dist )
{
    if ( dist == 0 )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Invalid distance!" );
        return false;
    }
    
    if ( dist > BLOCK_MAX )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."%i is too high! (Max: %i)", dist, BLOCK_MAX );
        return false;
    }
    
    if ( dist < BLOCK_MIN )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."%i is too low! (Min: %i)", dist, BLOCK_MIN );
        return false;
    }
    
    return true;
}

public Action Command_GoToBlock( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !SU_CanUseCommand( client ) ) return Plugin_Handled;
    
    if ( IsSpammingCommand( client, 1.0 ) ) return Plugin_Handled;
    
    int len = GetArrayLength_Safe( g_hBlocks );
    if ( len < 1 )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."No block zones exist!" );
        return Plugin_Handled;
    }
    
    
    int dist = 0;
    
    if ( args )
    {
        char szArg[5];
        GetCmdArgString( szArg, sizeof( szArg ) );
        
        dist = StringToInt( szArg );
    }
    else
    {
        Menu mMenu = new Menu( Handler_GotoBlock );
        mMenu.SetTitle( "Go to a block!\n " );
        
        char szItem[16];
        char szInfo[16];
        
        int num = 0;
        
        for ( int i = 0; i < len; i++ )
        {
            if ( !g_hBlocks.Get( i, view_as<int>( ZONE_ISSTART ) ) ) continue;
            
            if ( g_hBlocks.Get( i, view_as<int>( ZONE_DIR ) ) == BLOCKDIR_INVALID ) continue;
            
            if ( EntRefToEntIndex( g_hBlocks.Get( i, view_as<int>( ZONE_OPP_ENTREF ) ) ) < 1 ) continue;
            
            dist = g_hBlocks.Get( i, view_as<int>( ZONE_BLOCK ) );
            if ( !dist ) continue;
            
            
            FormatEx( szItem, sizeof( szItem ), "%i block", dist );
            
            FormatEx( szInfo, sizeof( szInfo ), "%i_%i", i, dist );
            mMenu.AddItem( szInfo, szItem );
            
            num++;
        }
        
        if ( !num )
        {
            mMenu.AddItem( szInfo, "No block zones found... :(" );
        }
        
        mMenu.Display( client, MENU_TIME_FOREVER );
        
        return Plugin_Handled;
    }
    
    if ( CheckDist( client, dist ) )
    {
        for ( int i = 0; i < len; i++ )
        {
            if ( !g_hBlocks.Get( i, view_as<int>( ZONE_ISSTART ) ) ) continue;
            
            
            if ( dist == g_hBlocks.Get( i, view_as<int>( ZONE_BLOCK ) ) )
            {
                TeleportPlayerToBlock( client, i );
                return Plugin_Handled;
            }
        }
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Sorry, that block hasn't been setup yet!" );
    }
    
    return Plugin_Handled;
}

stock void PrintListHelper( int client )
{
    SU_PrintToChat( client, client, SU_PRE_CHAT..."You can type \x04!command <args>"...CLR_CHAT..." to specify your search. (eg. \x04sw ladderjump"...CLR_CHAT...", \x04lj bw block"...CLR_CHAT...")" );
}

public Action Command_DisplayRecords( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( IsSpammingCommand( client, 2.0 ) ) return Plugin_Handled;
    
    
    if ( !args )
    {
        PrintListHelper( client );
        DB_DisplayRecords( client );
    }
    else
    {
        ParseRecordArgs( client, args );
    }
    
    return Plugin_Handled;
}

public Action Command_DisplayRecordsByName( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !args )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Usage: sm_ljrecordsbyname <name>" );
        return Plugin_Handled;
    }
    
    static char szName[64];
    if ( GetCmdArgString( szName, sizeof( szName ) ) < 1 )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Invalid usage!" );
        return Plugin_Handled;
    }
    
    if ( IsSpammingCommand( client, 2.0 ) ) return Plugin_Handled;
    
    
    DB_DisplayRecords( client, _, JUMPSTYLE_INVALID, _, _, _, _, szName, sizeof( szName ) );
    
    return Plugin_Handled;
}

public Action Command_DisplayMyRecords( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( IsSpammingCommand( client, 2.0 ) ) return Plugin_Handled;
    
    
    if ( !args )
    {
        PrintListHelper( client );
        DB_DisplayRecords( client, _, JUMPSTYLE_INVALID, _, _, g_iClientId[client], client, _, _, 0 );
    }
    else
    {
        ParseRecordArgs( client, args, g_iClientId[client], client, 0 );
    }
    
    return Plugin_Handled;
}

public Action Command_Admin_BlockStart( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !SU_CanUseCommand( client ) ) return Plugin_Handled;
    
    if ( g_bBuildBlock[client] )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."You are already building another zone!" );
        return Plugin_Handled;
    }
    
    
    g_bBuildBlock[client] = true;
    GetClientAbsOrigin( client, g_vecBuild_Start[client] );
    
    g_vecBuild_Start[client][2] = float( RoundFloat( g_vecBuild_Start[client][2] - 0.5 ) );
    RoundVector( g_vecBuild_Start[client] );
    
    CreateTimer( BUILDDRAW_INTERVAL, Timer_DisplayBuildZones, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
    
    SU_PrintToChat( client, client, SU_PRE_CHAT..."You started a block zone!" );
    
    return Plugin_Handled;
}

public Action Command_Admin_BlockEnd( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !SU_CanUseCommand( client ) ) return Plugin_Handled;
    
    if ( !g_bBuildBlock[client] )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."You haven't even started to build! (sm_startblock)" );
        return Plugin_Handled;
    }
    
    
    float vecPos[3];
    GetClientAbsOrigin( client, vecPos );
    
    vecPos[2] += 128.0;
    RoundVector( vecPos );
    
    CorrectMinsMaxs( g_vecBuild_Start[client], vecPos );
    
    
    if ( CreateZoneEntity( InsertNewBlock( _, _, g_vecBuild_Start[client], vecPos, true ) ) < 1 )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Couldn't create block trigger entity! Please try again." );
    }
    
    g_bBuildBlock[client] = false;
    
    return Plugin_Handled;
}

public Action Command_Admin_SetBlockDist( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    int len = GetArrayLength_Safe( g_hBlocks );
    if ( len < 1 )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."No zones exist!" );
        return Plugin_Handled;
    }
    
    
    int dist;
    
    if ( !args )
    {
        if ( !CheckDist( client, g_nBuildBlockDist[client] ) )
        {
            SU_PrintToChat( client, client, SU_PRE_CHAT..."Usage: sm_setblockdist <distance> (%i-%i)", BLOCK_MIN, BLOCK_MAX );
            return Plugin_Handled;
        }
        
        dist = g_nBuildBlockDist[client];
    }
    else
    {
        char szValue[5];
        GetCmdArgString( szValue, sizeof( szValue ) );
        
        dist = StringToInt( szValue );
        
        if ( !CheckDist( client, dist ) ) return Plugin_Handled;
    }
    
    float vecPos[3];
    GetClientAbsOrigin( client, vecPos );
    vecPos[2] += 2.0;
    
    int index = FindBlock( vecPos );
    
    if ( index != -1 )
    {
        if ( !g_hBlocks.Get( index, view_as<int>( ZONE_ISSTART ) ) )
        {
            SU_PrintToChat( client, client, SU_PRE_CHAT..."That is not the starting zone!" );
            return Plugin_Handled;
        }
        
        // Check if the end already exists. If so, erase it.
        int endent = EntRefToEntIndex( g_hBlocks.Get( index, view_as<int>( ZONE_OPP_ENTREF ) ) );
        
        if ( endent > 0 )
        {
            int endblock = CheckBlock( endent );
            
            if ( endblock != -1 )
            {
                KillEntity( endent );
                
                g_hBlocks.Erase( endblock );
            }
        }
        
        float vecAng[3];
        GetClientEyeAngles( client, vecAng );
        
        BlockDir dir = YawToBlockDir( vecAng[1] );
        
        int iData[ZONE_SIZE];
        float vecMins[3];
        float vecMaxs[3];
        
        g_hBlocks.GetArray( index, iData, view_as<int>( ZoneData ) );
        
        CopyArray( iData[ZONE_MINS], vecMins, 3 );
        CopyArray( iData[ZONE_MAXS], vecMaxs, 3 );
        
        
        if ( CreateEndZone( index, dist, vecMins, vecMaxs, dir ) )
        {
            g_hBlocks.Set( index, dist, view_as<int>( ZONE_BLOCK ) );
            
            SU_PrintToChat( client, client, SU_PRE_CHAT..."Created end for %i block!", dist );
            
            
            DB_SaveBlock( dist, dir, vecMins, vecMaxs );
        }
        else
        {
            SU_PrintToChat( client, client, SU_PRE_CHAT..."Couldn't create block end trigger entity! Please try again." );
        }
    }
    else
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."You're not inside any zone!" );
    }
    
    return Plugin_Handled;
}

public Action Command_Admin_BlockRemove( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    int len = GetArrayLength_Safe( g_hBlocks );
    if ( len < 1 )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."No blocks exist!" );
        return Plugin_Handled;
    }
    
    
    int index = -1;
    
    if ( args )
    {
        char szArg[5];
        GetCmdArgString( szArg, sizeof( szArg ) );
        
        int block = StringToInt( szArg );
        
        if ( !CheckDist( client, block ) ) return Plugin_Handled;
        
        for ( int i = 0; i < len; i++ )
        {
            if ( block == g_hBlocks.Get( i, view_as<int>( ZONE_BLOCK ) ) )
            {
                index = i;
                break;
            }
        }
        
        if ( index == -1 )
        {
            SU_PrintToChat( client, client, SU_PRE_CHAT..."Block %i doesn't exist!", block );
            return Plugin_Handled;
        }
    }
    else
    {
        float vecPos[3];
        GetClientAbsOrigin( client, vecPos );
        vecPos[2] += 2.0;
        
        index = FindBlock( vecPos );
    }
    
    if ( index != -1 )
    {
        // Delete all blocks with the same distance.
        int dist = g_hBlocks.Get( index, view_as<int>( ZONE_BLOCK ) );
        
        int ent = EntRefToEntIndex( g_hBlocks.Get( index, view_as<int>( ZONE_ENTREF ) ) );
        
        if ( ent > 0 ) KillEntity( ent );
        
        g_hBlocks.Erase( index );
        
        
        len = g_hBlocks.Length;
        
        for ( int i = 0; i < len; i ++ )
            if ( dist == g_hBlocks.Get( i, view_as<int>( ZONE_BLOCK ) ) )
            {
                ent = EntRefToEntIndex( g_hBlocks.Get( i, view_as<int>( ZONE_ENTREF ) ) );
                
                if ( ent > 0 ) KillEntity( ent );
                
                g_hBlocks.Erase( i );
                
                break;
            }
        
        
        // Erase from database.
        DB_DeleteBlock( dist );
    }
    else
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Couldn't find a zone. Please use sm_deleteblock <num>" );
    }
    
    return Plugin_Handled;
}

public Action Command_Admin_BlockCancel( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( g_bBuildBlock[client] )
    {
        g_bBuildBlock[client] = false;
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Block has been cancelled!" );
    }
    else
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."You are not building anything!" );
    }
    
    return Plugin_Handled;
}

public Action Command_Admin_Menu_BlockMenu( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Menu mMenu = new Menu( Handler_Admin_Block );
    mMenu.SetTitle( "LJ Block Building\n " );
    
    char szItem[32];
    FormatEx( szItem, sizeof( szItem ), "Create %i End", g_nBuildBlockDist[client] );
    
    if ( g_bBuildBlock[client] )
    {
        mMenu.AddItem( "", "Start Block", ITEMDRAW_DISABLED );
        mMenu.AddItem( "", "End Block" );
        mMenu.AddItem( "", "Cancel Block\n " );
        
        mMenu.AddItem( "", szItem, ITEMDRAW_DISABLED );
    }
    else
    {
        mMenu.AddItem( "", "Start Block" );
        mMenu.AddItem( "", "End Block", ITEMDRAW_DISABLED );
        mMenu.AddItem( "", "Cancel Block\n ", ITEMDRAW_DISABLED );
        
        mMenu.AddItem( "", szItem );
    }
    
    mMenu.AddItem( "", "+ Increase Distance" );
    mMenu.AddItem( "", "- Decrease Distance" );
    
    mMenu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Handler_Admin_Block( Menu mMenu, MenuAction action, int client, int index )
{
    if ( action == MenuAction_End )
    {
        delete mMenu;
        return 0;
    }
    
    if ( action != MenuAction_Select ) return 0;
    
    
    switch ( index )
    {
        case 0 : FakeClientCommand( client, "sm_startblock" );
        case 1 : FakeClientCommand( client, "sm_endblock" );
        case 2 : FakeClientCommand( client, "sm_cancelblock" );
        case 3 : FakeClientCommand( client, "sm_createblockend %i", g_nBuildBlockDist[client] );
        case 4 :
        {
            g_nBuildBlockDist[client]++;
            
            if ( g_nBuildBlockDist[client] > BLOCK_MAX )
            {
                g_nBuildBlockDist[client] = BLOCK_MAX;
            }
            else if ( g_nBuildBlockDist[client] < BLOCK_MIN )
            {
                g_nBuildBlockDist[client] = BLOCK_MIN;
            }
        }
        case 5 :
        {
            g_nBuildBlockDist[client]--;
            
            if ( g_nBuildBlockDist[client] > BLOCK_MAX )
            {
                g_nBuildBlockDist[client] = BLOCK_MAX;
            }
            else if ( g_nBuildBlockDist[client] < BLOCK_MIN )
            {
                g_nBuildBlockDist[client] = BLOCK_MIN;
            }
        }
    }
    
    FakeClientCommand( client, "sm_ljblockmenu" );
    
    return 0;
}

public Action Command_Credits( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Panel pPanel = new Panel();
    
    pPanel.SetTitle( "Credits:" );
    
    pPanel.DrawItem( "", ITEMDRAW_SPACER );
    pPanel.DrawText( "Mehis - Author" );
    pPanel.DrawText( "Yeckoh - Moral support, testing" );
    pPanel.DrawItem( "", ITEMDRAW_SPACER );
    
    pPanel.DrawItem( "Exit", ITEMDRAW_CONTROL );
    
    pPanel.Send( client, Handler_Empty, MENU_TIME_FOREVER );
    
    delete pPanel;
    
    return Plugin_Handled;
}

public Action Command_Version( int client, int args )
{
    if ( client )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Running "...PLUGIN_NAME_CORE..." version "...PLUGIN_VERSION..." by "...PLUGIN_AUTHOR_CORE );
    }
    else
    {
        PrintToServer( SU_PRE_CLEAR..."Running "...PLUGIN_NAME_CORE..." version "...PLUGIN_VERSION..." by "...PLUGIN_AUTHOR_CORE );
    }
    
    return Plugin_Handled;
}