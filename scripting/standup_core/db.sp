Handle g_hDB;


#define TABLE_ZONEDATA          "ljzonedata"
#define TABLE_USERDATA          "ljuserdata"
#define TABLE_LJDATA            "ljjumpdata"
#define TABLE_STRFDATA          "ljstrfdata"

#define DB_NAME                 "ljstats"

#define MAX_DB_NAME_LENGTH      31 * 2 + 1 // 63


// Not supported.
//#define MYSQL


#include "standup_core/db_threaded.sp"


stock bool GetClientSteam( int client, char[] szSteam, int len )
{
    if ( !GetClientAuthId( client, AuthId_Steam3, szSteam, len, true ) )
    {
        LogError( SU_PRE_CLEAR..."Couldn't retrieve client's \"%N\" Steam Id!", client );
        
        
        if ( IsClientInGame( client ) )
        {
            SU_PrintToChat( client, client, SU_PRE_CHAT..."Couldn't retrieve your Steam Id. Please reconnect and make sure you are connected to Steam!!" );
        }
        
        return false;
    }
    
    return true;
}

stock void DB_LogError( char[] szAdd, int client = 0, char[] szClientMsg = "" )
{
    char szError[128];
    SQL_GetError( g_hDB, szError, sizeof( szError ) );
    LogError( SU_PRE_CLEAR..."SQL Error: %s (%s)", szError, szAdd );
    
    if ( client && szClientMsg[0] != '\0' )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."%s", szClientMsg );
    }
}

stock bool DB_GetEscaped( char[] szEsc, int len, const char[] szDef = "" )
{
    if ( !SQL_EscapeString( g_hDB, szEsc, szEsc, len ) )
    {
        strcopy( szEsc, len, szDef );
        
        return false;
    }
    
    return true;
}

stock void DB_InitDatabase()
{
    char szError[128];
    
#if defined MYSQL
    g_hDB = SQL_Connect( DB_NAME, true, szError, sizeof( szError ) );
#else
    Handle kv = CreateKeyValues( "" );
    KvSetString( kv, "driver", "sqlite" );
    KvSetString( kv, "database", DB_NAME );
    
    g_hDB = SQL_ConnectCustom( kv, szError, sizeof( szError ), false );
    
    delete kv;
#endif

    if ( g_hDB == null )
    {
        SetFailState( SU_PRE_CLEAR..."Unable to establish connection to the database! (Error: %s)", szError );
    }
    
    PrintToServer( SU_PRE_CLEAR..."Established connection to the database!" );
    
    // INSERT INTO ljjumpdata (uid, jstyle, jdir, jstance, jisblock, jblock, jedge, jdist, jdisttrue, jprespd, jtopspd, jnumstrfs, javgsync, javgtime) SELECT uid, jstyle, jdir, jstance, jisblock, jblock, jedge, jdist, 0.0, 0.0, jtopspd, jnumstrfs, jtotalsync, 0.0 FROM ljjumpdata_old
    // INSERT INTO ljstrfdata (uid, jstyle, jdir, jstance, jisblock, strfid, sync, gains, losses, time) SELECT uid, jstyle, jdir, jstance, jisblock, strfid, sync, gains, losses, time FROM ljstrfdata_old
    
    
    // NOTE: Must be INTEGER PRIMARY KEY. INT PRIMARY KEY does not count.
    SQL_TQuery( g_hDB, Threaded_Empty,
        "CREATE TABLE IF NOT EXISTS "...TABLE_USERDATA..." (uid INTEGER PRIMARY KEY, steamid VARCHAR(63) NOT NULL, name VARCHAR(62) DEFAULT 'N/A')", _, DBPrio_High );
    
    SQL_TQuery( g_hDB, Threaded_Empty,
        "CREATE TABLE IF NOT EXISTS "...TABLE_LJDATA..." (uid INT NOT NULL, jstyle INT NOT NULL, jdir INT NOT NULL, jstance INT NOT NULL, jisblock INT NOT NULL, jblock INT NOT NULL, jedge REAL NOT NULL, jdist INT NOT NULL, jdisttrue INT NOT NULL, jprespd REAL NOT NULL, jtopspd REAL NOT NULL, jnumstrfs INT NOT NULL, javgsync REAL NOT NULL, javgtime REAL NOT NULL, jmdata1 REAL NOT NULL, PRIMARY KEY(uid, jstyle, jdir, jstance, jisblock))", _, DBPrio_High );
    
    SQL_TQuery( g_hDB, Threaded_Empty,
        "CREATE TABLE IF NOT EXISTS "...TABLE_STRFDATA..." (uid INT NOT NULL, jstyle INT NOT NULL, jdir INT NOT NULL, jstance INT NOT NULL, jisblock INT NOT NULL, strfid INT NOT NULL, sync REAL NOT NULL, gains REAL NOT NULL, losses REAL NOT NULL, time REAL NOT NULL, PRIMARY KEY(uid, jstyle, jdir, jstance, jisblock, strfid))", _, DBPrio_High );
    
    SQL_TQuery( g_hDB, Threaded_Empty,
        "CREATE TABLE IF NOT EXISTS "...TABLE_ZONEDATA..." (map VARCHAR(63) NOT NULL, block INT NOT NULL, dir INT NOT NULL, min0 REAL NOT NULL, min1 REAL NOT NULL, min2 REAL NOT NULL, max0 REAL NOT NULL, max1 REAL NOT NULL, max2 REAL NOT NULL, PRIMARY KEY(map, block))" );
}

stock void DB_InitRecords()
{
    SQL_TQuery( g_hDB, Threaded_GetBestRecords, "SELECT jstyle, jdir, jstance, jisblock, jblock, jdist FROM "...TABLE_LJDATA..." GROUP BY jstyle, jdir, jstance, jisblock ORDER BY MAX(jdist)", _, DBPrio_High );
}

stock void DB_InitMap()
{
    char szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT block, dir, min0, min1, min2, max0, max1, max2 FROM "...TABLE_ZONEDATA..." WHERE map = '%s' ORDER BY block", g_szCurrentMap );
    
    SQL_TQuery( g_hDB, Threaded_GetMapData, szQuery, _, DBPrio_High );
}

stock void DB_GetClientData( int client )
{
    static char szSteam[64];
    if ( !GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return;
    
    
    static char szQuery[162];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT uid FROM "...TABLE_USERDATA..." WHERE steamid = '%s'", szSteam );
    
    SQL_TQuery( g_hDB, Threaded_GetClientData, szQuery, GetClientUserId( client ), DBPrio_High );
}

stock void DB_SaveClientData( int client )
{
    if ( !g_iClientId[client] ) return;
    
    
    static char szSteam[64];
    if ( !GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return;
    
    
    static char szName[MAX_DB_NAME_LENGTH];
    GetClientName( client, szName, sizeof( szName ) );
    
    DB_GetEscaped( szName, sizeof( szName ), "N/A" );
    
    
    static char szQuery[192];
    FormatEx( szQuery, sizeof( szQuery ), "UPDATE "...TABLE_USERDATA..." SET name = '%s' WHERE steamid = '%s'", szName, szSteam );
    
    SQL_TQuery( g_hDB, Threaded_Empty, szQuery, _, DBPrio_High );
}

stock void DB_SaveJump( int client, const int iJump[JMP_SIZE], ArrayList &hStrafes, bool bIsBlock )
{
    if ( !g_iClientId[client] )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Cannot save your jump into the database! Please reconnect." );
        return;
    }
    
    
    int num_strfs = hStrafes.Length;
    
    // uid INT NOT NULL, jstyle INT NOT NULL, jdir INT NOT NULL, jstance INT NOT NULL, jisblock INT NOT NULL, jblock INT NOT NULL, jedge REAL NOT NULL, jdist INT NOT NULL, jdisttrue INT NOT NULL, jprespd REAL NOT NULL, jtopspd REAL NOT NULL, jnumstrfs INT NOT NULL, javgsync REAL NOT NULL, javgtime REAL NOT NULL
    static char szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "INSERT OR REPLACE INTO "...TABLE_LJDATA..." VALUES (%i, %i, %i, %i, %i, %i, %.4f, %.4f, %.4f, %.4f, %.4f, %i, %.4f, %.4f, %.4f)",
        g_iClientId[client], // uid
        iJump[JMP_STYLE], // jstyle
        iJump[JMP_DIR], // jdir
        iJump[JMP_STANCE], // jstance
        bIsBlock, // jisblock
        iJump[JMP_BLOCK], // jblock
        iJump[JMP_BLOCK_EDGE], // jedge
        iJump[JMP_DIST], // jdist
        iJump[JMP_DIST_TRUE], // jdisttrue
        iJump[JMP_PRESPD], // jprespd
        iJump[JMP_TOPSPD], // jtopspd
        num_strfs, // jnumstrfs
        iJump[JMP_AVG_SYNC], // javgsync
        iJump[JMP_AVG_TIME], // javgtime
        iJump[JMP_MISCDATA1] ); // jmdata1
    
    SQL_TQuery( g_hDB, Threaded_Empty, szQuery, GetClientUserId( client ), DBPrio_Normal );
    
    
    // Next, save strafes.
    int iData[STRAFE_SIZE];
    
    for ( int i = 0; i < num_strfs; i++ )
    {
        hStrafes.GetArray( i, iData, view_as<int>( StrafeData ) );
        
        FormatEx( szQuery, sizeof( szQuery ), "INSERT OR REPLACE INTO "...TABLE_STRFDATA..." VALUES (%i, %i, %i, %i, %i, %i, %.3f, %.3f, %.3f, %.4f)",
            g_iClientId[client], // uid
            iJump[JMP_STYLE], // jstyle
            iJump[JMP_DIR], // jdir
            iJump[JMP_STANCE], // jstance
            bIsBlock, // jisblock
            i, // strfid
            iData[view_as<int>( STRF_SYNC )], // sync
            iData[view_as<int>( STRF_GAINS )], // gains
            iData[view_as<int>( STRF_LOSSES )], // losses
            iData[view_as<int>( STRF_TIME )] ); // time
        
        SQL_TQuery( g_hDB, Threaded_Empty, szQuery, _, DBPrio_Normal );
    }
    
    
    // Remove unnecessary strafe records.
    // Not required since all queries only ask for specific amount of strafes.
    // This will just keep the db clean.
    FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...TABLE_STRFDATA..." WHERE uid = %i AND jstyle = %i AND jdir = %i AND jstance = %i AND jisblock = %i AND strfid >= %i",
        g_iClientId[client],
        iJump[JMP_STYLE], // jstyle
        iJump[JMP_DIR], // jdir
        iJump[JMP_STANCE], // jstance
        bIsBlock, // jisblock
        num_strfs );
    
    SQL_TQuery( g_hDB, Threaded_Empty, szQuery, _, DBPrio_Low );
}

stock void DB_SaveBlock( int dist, BlockDir dir, const float vecMins[3], const float vecMaxs[3] )
{
    char szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "INSERT OR REPLACE INTO "...TABLE_ZONEDATA..." VALUES ('%s', %i, %i, %.0f, %.0f, %.0f, %.0f, %.0f, %.0f)",
        g_szCurrentMap, // map
        dist, // block
        dir, // dir
        vecMins[0], // min0
        vecMins[1], // min1
        vecMins[2], // min2
        vecMaxs[0], // max0
        vecMaxs[1], // max1
        vecMaxs[2] ); // max2
    
    SQL_TQuery( g_hDB, Threaded_Empty, szQuery, _, DBPrio_Low );
}

stock void DB_DisplayRecords( int client, bool bBlock = false, int style = JUMPSTYLE_LJ, int dir = JUMPDIR_INVALID, int stance = JUMPSTANCE_INVALID, int uid = 0, int target = 0, char[] szSearchName = "", int searchlen = 0, int maxrecords = DEF_MAX_RECORDS_QUERY )
{
    static char szQuery[400];
    
    FormatEx( szQuery, sizeof( szQuery ), "SELECT uid, jstyle, jdir, jstance, jblock, jdist, jnumstrfs, javgsync" );
    
    
    if ( searchlen )
    {
        Format( szQuery, sizeof( szQuery ), "%s FROM "...TABLE_LJDATA..." NATURAL JOIN "...TABLE_USERDATA, szQuery );
    }
    else if ( !uid )
    {
        Format( szQuery, sizeof( szQuery ), "%s, name FROM "...TABLE_LJDATA..." NATURAL JOIN "...TABLE_USERDATA, szQuery );
    }
    else
    {
        Format( szQuery, sizeof( szQuery ), "%s FROM "...TABLE_LJDATA, szQuery );
    }
    
    Format( szQuery, sizeof( szQuery ), "%s WHERE jisblock = %i", szQuery, bBlock );
    
    
    if ( uid > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND uid = %i", szQuery, uid );
    }
    
    if ( searchlen > 0 )
    {
        if ( !DB_GetEscaped( szSearchName, searchlen ) )
        {
            return;
        }
        
        Format( szQuery, sizeof( szQuery ), "%s AND name LIKE '%s'", szQuery, szSearchName );
    }
    
    if ( style != JUMPSTYLE_INVALID )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND jstyle = %i", szQuery, style );
    }
    
    if ( dir != JUMPDIR_INVALID )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND jdir = %i", szQuery, dir );
    }
    
    if ( stance != JUMPSTANCE_INVALID )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND jstance = %i", szQuery, stance );
    }
    
    if ( bBlock )
    {
        Format( szQuery, sizeof( szQuery ), "%s ORDER BY jblock DESC, jdist DESC", szQuery );
    }
    else
    {
        Format( szQuery, sizeof( szQuery ), "%s ORDER BY jdist DESC", szQuery );
    }
    
    if ( maxrecords > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s LIMIT %i", szQuery, maxrecords );
    }
    
    
    int iData[7];
    iData[0] = GetClientUserId( client );
    iData[1] = bBlock;
    iData[2] = style;
    iData[3] = dir;
    iData[4] = stance;
    iData[5] = uid;
    iData[6] = target ? GetClientUserId( target ) : 0;
    
    ArrayList hData = new ArrayList( sizeof( iData ) );
    hData.PushArray( iData, sizeof( iData ) );
    
    
    SQL_TQuery( g_hDB, Threaded_DisplayRecords, szQuery, hData, DBPrio_Low );
}

stock void DB_DisplayJumpData( int client, int uid, int style, int dir, int stance, int block )
{
    static char szQuery[300];
    
    FormatEx( szQuery, sizeof( szQuery), "SELECT name, jdist, jdisttrue, jprespd, jtopspd, jnumstrfs, javgsync, javgtime, jblock, jedge FROM "...TABLE_LJDATA..." NATURAL JOIN "...TABLE_USERDATA..." WHERE uid = %i AND jstyle = %i AND jdir = %i AND jstance = %i AND jisblock = %i LIMIT 1",
        uid,
        style,
        dir,
        stance,
        block );
    
    int iData[6];
    iData[0] = GetClientUserId( client );
    iData[1] = uid;
    iData[2] = style;
    iData[3] = dir;
    iData[4] = stance;
    iData[5] = block;
    
    ArrayList hData = new ArrayList( sizeof( iData ) );
    hData.PushArray( iData, sizeof( iData ) );
    
    SQL_TQuery( g_hDB, Threaded_DisplayJumpData, szQuery, hData, DBPrio_Low );
}

stock void DB_DisplayStrafeData( int client, int uid, int style, int dir, int stance, int block, int numstrfs )
{
    static char szQuery[256];
    
    FormatEx( szQuery, sizeof( szQuery), "SELECT sync, time, gains, losses FROM "...TABLE_STRFDATA..." WHERE uid = %i AND jstyle = %i AND jdir = %i AND jstance = %i AND jisblock = %i ORDER BY strfid LIMIT %i",
        uid,
        style,
        dir,
        stance,
        block,
        numstrfs );
    
    SQL_TQuery( g_hDB, Threaded_DisplayStrafeData, szQuery, GetClientUserId( client ), DBPrio_Low );
}

/*stock void DB_GetClientRanking( int client, int style = JUMPSTYLE_LJ, int dir = JUMPDIR_FWD, int stance = JUMPSTANCE_NORMAL )
{
    char szQuery[256];
    
    FormatEx( szQuery, sizeof( szQuery ), "SELECT COUNT() FROM "...TABLE_LJDATA..."" );
}*/

stock void DB_DeleteBlock( int dist )
{
    char szQuery[128];
    FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...TABLE_ZONEDATA..." WHERE block = %i AND map = '%s'", dist, g_szCurrentMap );
    
    SQL_TQuery( g_hDB, Threaded_Empty, szQuery, _, DBPrio_Low );
}

stock void DB_DeleteJumpRecord( int uid, int style, int dir, int stance, int block )
{
    char szQuery[256];
    
    
    FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...TABLE_LJDATA..." WHERE uid = %i AND jstyle = %i AND jdir = %i AND jstance = %i AND jisblock = %i",
        uid,
        style,
        dir,
        stance,
        block );
    
    SQL_TQuery( g_hDB, Threaded_Empty, szQuery, _, DBPrio_Low );
    
    
    FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...TABLE_STRFDATA..." WHERE uid = %i AND jstyle = %i AND jdir = %i AND jstance = %i AND jisblock = %i",
        uid,
        style,
        dir,
        stance,
        block );
    
    SQL_TQuery( g_hDB, Threaded_Empty, szQuery, _, DBPrio_Low );
}