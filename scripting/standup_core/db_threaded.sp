/*
    TODO: Use panels
*/

public void Threaded_GetBestRecords( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
    if ( hQuery == null )
    {
        DB_LogError( "retrieving records" );
        return;
    }
    
    if ( !SQL_GetRowCount( hQuery ) ) return;
    
    
    int style;
    int dir;
    int stance;
    
    while ( SQL_FetchRow( hQuery ) )
    {
        style = SQL_FetchInt( hQuery, 0 );
        dir = SQL_FetchInt( hQuery, 1 );
        stance = SQL_FetchInt( hQuery, 2 );
        
        if ( SQL_FetchInt( hQuery, 3 ) ) // jisblock
        {
            g_iBest_Block[style][dir][stance] = SQL_FetchInt( hQuery, 4 );
            
            g_flBest_Distance_Block[style][dir][stance] = SQL_FetchFloat( hQuery, 5 );
        }
        else
        {
            g_flBest_Distance[style][dir][stance] = SQL_FetchFloat( hQuery, 5 );
        }
    }
}

public void Threaded_GetMapData( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
    if ( hQuery == null )
    {
        DB_LogError( "retrieving map data" );
        return;
    }
    
    if ( !SQL_GetRowCount( hQuery ) ) return;
    
    
    g_hBlocks = new ArrayList( view_as<int>( ZoneData ) );
    
    
    float vecMins[3];
    float vecMaxs[3];
    
    int block;
    BlockDir dir;
    
    int startindex;
    
    while ( SQL_FetchRow( hQuery ) )
    {
        block = SQL_FetchInt( hQuery, 0 );
        dir = view_as<BlockDir>( SQL_FetchInt( hQuery, 1 ) );
        
        if ( dir == BLOCKDIR_INVALID ) continue;
        
        
        vecMins[0] = SQL_FetchFloat( hQuery, 2 );
        vecMins[1] = SQL_FetchFloat( hQuery, 3 );
        vecMins[2] = SQL_FetchFloat( hQuery, 4 );
        vecMaxs[0] = SQL_FetchFloat( hQuery, 5 );
        vecMaxs[1] = SQL_FetchFloat( hQuery, 6 );
        vecMaxs[2] = SQL_FetchFloat( hQuery, 7 );
        
        startindex = InsertNewBlock( block, _, vecMins, vecMaxs, true, dir );
        
        CreateZoneEntity( startindex );
        
        CreateEndZone( startindex, block, vecMins, vecMaxs, dir );
    }
}

public void Threaded_DisplayRecords( Handle hOwner, Handle hQuery, const char[] szError, ArrayList hData )
{
    int client;
    if ( (client = GetClientOfUserId( hData.Get( 0, 0 ) )) )
    {
        if ( hQuery == null )
        {
            DB_LogError( "displaying records to client", client, "Sorry, an error occurred with the database." );
            
            delete hData;
            return;
        }
        
        
        bool bBlock = hData.Get( 0, 1 );
        int reqstyle = hData.Get( 0, 2 );
        int reqdir = hData.Get( 0, 3 );
        int reqstance = hData.Get( 0, 4 );
        int requid = hData.Get( 0, 5 );
        int target = GetClientOfUserId( hData.Get( 0, 6 ) );
        
        char szJumps[32];
        FormatJumpName( szJumps, sizeof( szJumps ), reqstyle, reqdir, reqstance );
        
        char szBlock[16];
        if ( bBlock )
        {
            strcopy( szBlock, sizeof( szBlock ), "(Block) " );
        }
        
        char szName[MAX_NAME_LENGTH + 2];
        
        
        if ( target && IsClientInGame( target ) )
        {
            GetClientName( target, szName, sizeof( szName ) );
            Format( szName, sizeof( szName ), "(%s) ", szName );
        }
        
        Menu mMenu = new Menu( Handler_DisplayRecords_GotoJumpData );
        mMenu.SetTitle( "Records %s%s%s\n ", szName, szBlock, szJumps );
        
        strcopy( szName, sizeof( szName ), "" );
        
        if ( SQL_GetRowCount( hQuery ) )
        {
            char szItem[128];
            char szInfo[32];
            
            int num;
            
            int uid;
            int style;
            int dir;
            int stance;
            int block;
            int strfs;
            int field;
            
            while ( SQL_FetchRow( hQuery ) )
            {
                num++;
                
                uid = SQL_FetchInt( hQuery, 0 );
                style = SQL_FetchInt( hQuery, 1 );
                dir = SQL_FetchInt( hQuery, 2 );
                stance = SQL_FetchInt( hQuery, 3 );
                block = SQL_FetchInt( hQuery, 4 );
                strfs = SQL_FetchInt( hQuery, 6 );
                
                // Empty the strings if we queried just for them. They'll be in the title.
                FormatJumpName( szJumps, sizeof( szJumps ),
                    ( reqstyle == JUMPSTYLE_INVALID ) ? style : JUMPSTYLE_INVALID,
                    ( reqdir == JUMPDIR_INVALID ) ? dir : JUMPDIR_INVALID,
                    ( reqstance == JUMPSTANCE_INVALID ) ? stance : JUMPSTANCE_INVALID,
                    true, true );
                
                if ( block )
                {
                    FormatEx( szBlock, sizeof( szBlock ), "(%i) ", block );
                }
                else
                {
                    strcopy( szBlock, sizeof( szBlock ), "" );
                }
                
                if ( requid < 1 )
                {
                    if ( SQL_FieldNameToNum( hQuery, "name", field ) )
                    {
                        SQL_FetchString( hQuery, field, szName, sizeof( szName ) );
                        LimitString( szName, sizeof( szName ), 14 );
                    }
                }
                
                
                // Format the displayed string.
                // "#01  XXX.X (XXX) BW Standup Ladder | XXXXXXXXXXXXX | XX strfs @ 100% sync"
                FormatEx( szItem, sizeof( szItem ), "#%02i  %.1f %s%s | %i strfs @ %.0f%%%s%s",
                    num,
                    SQL_FetchFloat( hQuery, 5 ), // Dist
                    szBlock,
                    szJumps,
                    strfs,
                    SQL_FetchFloat( hQuery, 7 ), // Sync
                    ( szName[0] != '\0' ) ? " | " : "",
                    szName ); 
                
                // Format the info to display jump data.
                FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i_%i_%i", uid, style, dir, stance, bBlock );
                
                mMenu.AddItem( szInfo, szItem );
            }
        }
        else
        {
            mMenu.AddItem( "", "No records were found... :(", ITEMDRAW_DISABLED );
        }
        
        mMenu.Display( client, MENU_TIME_FOREVER );
    }
    
    delete hData;
}

public void Threaded_DisplayJumpData( Handle hOwner, Handle hQuery, const char[] szError, ArrayList hData )
{
    int client;
    if ( (client = GetClientOfUserId( hData.Get( 0, 0 ) )) )
    {
        if ( hQuery == null )
        {
            DB_LogError( "displaying jump data to client", client, "Sorry, an error occurred with the database." );
            
            delete hData;
            return;
        }
        
        int style = hData.Get( 0, 2 );
        int dir = hData.Get( 0, 3 );
        int stance = hData.Get( 0, 4 );
        int numstrfs;
        
        Menu mMenu = new Menu( Handler_DisplayRecords_GotoStrafeData );
        
        char szItem[256];
        FormatEx( szItem, sizeof ( szItem ), "Jump Info\n \n" );
        
        
        
        if ( SQL_FetchRow( hQuery ) )
        {
            char szName[MAX_NAME_LENGTH];
            SQL_FetchString( hQuery, 0, szName, sizeof( szName ) );
            
            numstrfs = SQL_FetchInt( hQuery, 5 );
            
            Format( szItem, sizeof( szItem ), "%s\n%s\n \nDistance: %.3f (true: %.3f) units\nPrespeed: %.3f\nMax speed: %.3f\n \nStrafes: %i\nSync: %.1f%%\nAvg Time: %.0fms",
                szItem,
                szName,
                SQL_FetchFloat( hQuery, 1 ), // jdist
                SQL_FetchFloat( hQuery, 2 ), // jdisttrue
                SQL_FetchFloat( hQuery, 3 ), // jprespd
                SQL_FetchFloat( hQuery, 4 ), // jtopspd
                numstrfs, // jnumstrfs
                SQL_FetchFloat( hQuery, 6 ), // javgsync
                SQL_FetchFloat( hQuery, 7 ) ); // javgtime
            
            int block = SQL_FetchInt( hQuery, 8 ); // jblock
            
            if ( block )
            {
                Format( szItem, sizeof( szItem ), "%s\n \nEdge: %.1f (%i block)",
                    szItem,
                    SQL_FetchFloat( hQuery, 9 ), // jedge
                    block );
            }
        }
        else
        {
            Format( szItem, sizeof( szItem ), "%sSomething went wrong! :(", szItem );
        }
        
        mMenu.SetTitle( "%s\n ", szItem );
        
        
        char szInfo[24];
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i_%i_%i_%i",
            hData.Get( 0, 1 ), // uid
            style,
            dir,
            stance,
            hData.Get( 0, 5 ), // block
            numstrfs );
        
        if ( GetAdminFlags( GetUserAdmin( client ), Access_Real ) & ADMFLAG_SU_LVL3 )
        {
            mMenu.AddItem( szInfo, "Strafe Data\n " );
            mMenu.AddItem( szInfo, "Delete this record" );
        }
        else
        {
            mMenu.AddItem( szInfo, "Strafe Data" );
        }
        
        mMenu.Display( client, MENU_TIME_FOREVER );
    }
    
    delete hData;
}

public void Threaded_DisplayStrafeData( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( hQuery == null )
    {
        DB_LogError( "displaying strafe data to client", client, "Sorry, an error occurred with the database." );
        
        return;
    }
    
    
    Menu mMenu = new Menu( Handler_Empty );
    
    
    if ( SQL_GetRowCount( hQuery ) )
    {
        char szItem[500];
        strcopy( szItem, sizeof( szItem ), STRF_FORMAT..."\n \n" );
        
        char szStrafe[64];
        
        int num;
        float sync;
        float gains;
        float losses;
        float time;
        
        float totalsync;
        float totaltime;
        
        while ( SQL_FetchRow( hQuery ) )
        {
            num++;
            
            sync = SQL_FetchFloat( hQuery, 0 );
            time = SQL_FetchFloat( hQuery, 1 );
            gains = SQL_FetchFloat( hQuery, 2 );
            losses = SQL_FetchFloat( hQuery, 3 );
            
            FormatStrafes( szStrafe, sizeof( szStrafe ), num, sync, time, gains, losses );
            
            Format( szItem, sizeof( szItem ), "%s%s\n", szItem, szStrafe );
            
            totalsync += sync;
            totaltime += time * 1000.0;
        }
        
        Format( szItem, sizeof( szItem ), "%s ", szItem );
        
        mMenu.SetTitle( "%s", szItem );
        
        char szTemp[32];
        FormatStrafeItem( szTemp, sizeof( szTemp ), totaltime / num, totalsync / num );
        mMenu.AddItem( "", szTemp );
        
        mMenu.ExitButton = false;
    }
    else
    {
        mMenu.SetTitle( "No strafe data found!!\n " );
        mMenu.ExitButton = true;
    }
    
    mMenu.Display( client, MENU_TIME_FOREVER );
}

public void Threaded_GetClientData( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
    if ( hQuery == null )
    {
        DB_LogError( "retrieving client data", GetClientOfUserId( client ), "Sorry, an error occurred with the database." );
        return;
    }
    
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    
    char szSteam[64];
    if ( !GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return;
    
    
    if ( SQL_GetRowCount( hQuery ) > 1 )
    {
        DB_LogError( "attempted to retrieve user data but found multiple results!!" );
    }
    
    // No record for client yet.
    if ( !SQL_FetchRow( hQuery ) )
    {
        char szName[MAX_NAME_LENGTH];
        GetClientName( client, szName, sizeof( szName ) );
        DB_GetEscaped( szName, sizeof( szName ), "N/A" );
    
        char szQuery[128];
        FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...TABLE_USERDATA..." (steamid, name) VALUES ('%s', '%s')", szSteam, szName );
        
        SQL_TQuery( g_hDB, Threaded_InsertNewUser, szQuery, GetClientUserId( client ), DBPrio_High );
    }
    // Our id was found. This means we should have a record in the database!
    else
    {
        g_iClientId[client] = SQL_FetchInt( hQuery, 0 );
        
        
        static char szQuery[256];
        FormatEx( szQuery, sizeof( szQuery ), "SELECT jstyle, jdir, jstance, jisblock, jblock, jdist FROM "...TABLE_LJDATA..." WHERE uid = %i", g_iClientId[client] );
        
        SQL_TQuery( g_hDB, Threaded_GetClientJumps, szQuery, GetClientUserId( client ), DBPrio_Normal );
    }
}

public void Threaded_InsertNewUser( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
    if ( hQuery == null )
    {
        DB_LogError( "inserting new user data, data may already exist", GetClientOfUserId( client ), "Couldn't insert a new record into the database! Please try to reconnect." );
        return;
    }
    
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    
    char szSteam[64];
    if ( !GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return;
    
    
    char szQuery[128];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT uid FROM "...TABLE_USERDATA..." WHERE steamid = '%s'", szSteam );
    
    SQL_TQuery( g_hDB, Threaded_GetNewUserId, szQuery, GetClientUserId( client ), DBPrio_High );
}

public void Threaded_GetNewUserId( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
    if ( hQuery == null )
    {
        DB_LogError( "retrieving a new id for user", GetClientOfUserId( client ), "Couldn't retrieve your id. Please, try to reconnect." );
        return;
    }
    
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    
    if ( SQL_FetchRow( hQuery ) )
    {
        g_iClientId[client] = SQL_FetchInt( hQuery, 0 );
    }
    else
    {
        DB_LogError( "no user id was found for a new user", client, "Couldn't retrieve your id. Please, try to reconnect." );
    }
}

public void Threaded_GetClientJumps( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
    if ( hQuery == null )
    {
        DB_LogError( "retrieving client's jumps", GetClientOfUserId( client ), "Couldn't retrieve your jump records!" );
        return;
    }
    
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( !SQL_GetRowCount( hQuery ) ) return;
    
    
    int style;
    int dir;
    int stance;
    
    while ( SQL_FetchRow( hQuery ) )
    {
        style = SQL_FetchInt( hQuery, 0 );
        dir = SQL_FetchInt( hQuery, 1 );
        stance = SQL_FetchInt( hQuery, 2 );
        
        if ( SQL_FetchInt( hQuery, 3 ) )
        {
            g_flPB_Distance_Block[client][style][dir][stance] = SQL_FetchFloat( hQuery, 5 );
            g_iPB_Block[client][style][dir][stance] = SQL_FetchInt( hQuery, 4 );
            
#if defined DEBUG
            PrintToServer( SU_PRE_DEV..."Found jump record (%i, %i, %i, %i - %.1f)",
                style,
                dir,
                stance,
                g_iPB_Block[client][style][dir][stance],
                g_flPB_Distance_Block[client][style][dir][stance] );
#endif
        }
        else
        {
            g_flPB_Distance[client][style][dir][stance] = SQL_FetchFloat( hQuery, 5 );
            
#if defined DEBUG
            PrintToServer( SU_PRE_DEV..."Found jump record (%i, %i, %i, 0 - %.1f)",
                style,
                dir,
                stance,
                g_flPB_Distance[client][style][dir][stance] );
#endif
        }
    }
}

public void Threaded_Empty( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
    if ( hQuery == null )
    {
        if ( (client = GetClientOfUserId( client )) )
        {
            DB_LogError( "inserting data into database", client, "An error occurred while saving your data!" );
        }
        else
        {
            DB_LogError( "inserting data into database" );
        }
    }
}