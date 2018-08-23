#define MAGIC_NUMBER_V1         0x1337

#define MAGIC_NUMBER_CUR        MAGIC_NUMBER_V1

#define RECORDS_DIR             "ljrecords"

static const char szDirJumpStyle[][] = { "lj", "weird", "bhop", "ladder", "up" };
static const char szDirJumpDir[][] = { "fwd", "bwd", "sw" };
static const char szDirJumpStance[][] = { "nrml", "standup", "ducked" };

stock bool ExCreateDir( const char[] szPath )
{
    if ( !DirExists( szPath ) )
    {
        CreateDirectory( szPath, 511 );
        
        if ( !DirExists( szPath ) )
        {
            LogError( SU_PRE_CLEAR..."Couldn't create folder! (%s)", szPath );
            return false;
        }
    }
    
    return true;
}

stock bool IsFrameInvalid( const int iFrame[FRAME_SIZE] )
{
    // If the angles are invalid, it'll crash the server.
    return (iFrame[FRAME_ANG] > 180.0
    ||      iFrame[FRAME_ANG] < -180.0
    ||      iFrame[view_as<int>( FRAME_ANG ) + 1] > 180.0
    ||      iFrame[view_as<int>( FRAME_ANG ) + 1] < -180.0 );
}

/*
    Structure:
    
    Magic number
    Frame count
    Tick rate
    
    Style
    Direction
    Stance
    
    Distance
    Prespeed
    Topspeed
    Strf Count
    Sync
    
    Frame data...
*/

stock int LoadAllRecordings()
{
    char szMap[32];
    GetLowerCurrentMap( szMap, sizeof( szMap ) );
    
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), RECORDS_DIR..."/%s", szMap );
    
    if ( !DirExists( szPath ) ) return 0;
    
    int num;
    
    int len;
    int dotpos;
    
    DirectoryListing hDir = OpenDirectory( szPath );
    
    if ( hDir == null ) return 0;
    
    
    char szFile[PLATFORM_MAX_PATH];
    
    while ( hDir.GetNext( szFile, sizeof( szFile ) ) )
    {
        // . and ..
        if ( szFile[0] == '.' || szFile[0] == '\0' ) continue;
        
        // Check file extension.
        len = strlen( szFile );
        dotpos = 0;
        
        for ( int i = 0; i < len; i++ )
        {
            if ( szFile[i] == '.' ) dotpos = i;
        }

        if ( !StrEqual( szFile[dotpos], ".rec" ) ) continue;
        
        
        Format( szFile, sizeof( szFile ), "%s/%s", szPath, szFile );
        
        
        if ( LoadRecordingFile( szFile ) )
        {
            num++;
        }
    }
    
    return num;
}

stock bool LoadRecording( int style, int dir, int stance )
{
    char szMap[32];
    GetLowerCurrentMap( szMap, sizeof( szMap ) );
    
    
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), RECORDS_DIR..."/%s/%s/%s_%s_%s.rec", szMap, szDirJumpStyle[style], szDirJumpDir[dir], szDirJumpStance[stance] );
    
    
    return LoadRecordingFile( szPath );
}

stock bool LoadRecordingFile( const char[] szPath )
{
    Handle hFile = OpenFile( szPath, "rb" );
    
    if ( hFile == null ) return false;
    
    
    int temp;
    ReadFileCell( hFile, temp, 4 );
    
    if ( temp != MAGIC_NUMBER_CUR )
    {
        LogError( SU_PRE_CLEAR..."Attempted to read from .rec file with different magic number!" );
        
        delete hFile;
        return false;
    }
    
    
    int len;
    ReadFileCell( hFile, len, 4 );
    
    if ( len < 1 )
    {
        delete hFile;
        return false;
    }
    
    
    ReadFileCell( hFile, temp, 4 );
    
    if ( temp != RoundFloat( g_flTickRate ) )
    {
        LogError( SU_PRE_CLEAR..."Recording tickrate differs from server's tickrate! (Recording: %i - Server: %.0f)", temp, g_flTickRate );
        
        delete hFile;
        return false;
    }
    
    
    int style = -1;
    int dir = -1;
    int stance = -1;
    
    ReadFileCell( hFile, style, 4 );
    if ( !IS_STYLE( style ) )
    {
        LogError( SU_PRE_CLEAR..."Recording file contains invalid jump style index! (%i)", style );
        
        delete hFile;
        return false;
    }
    
    ReadFileCell( hFile, dir, 4 );
    if ( !IS_DIR( dir ) )
    {
        LogError( SU_PRE_CLEAR..."Recording file contains invalid jump direction index! (%i)", dir );
        
        delete hFile;
        return false;
    }
    
    ReadFileCell( hFile, stance, 4 );
    if ( !IS_STANCE( stance ) )
    {
        LogError( SU_PRE_CLEAR..."Recording file contains invalid jump stance index! (%i)", stance );
        
        delete hFile;
        return false;
    }
    
    ReadFileCell( hFile, view_as<int>( g_flBestDist[style][dir][stance] ), 4 ); // Distance
    ReadFileCell( hFile,  view_as<int>( g_flBestPreSpd[style][dir][stance] ), 4 ); // Prespeed
    ReadFileCell( hFile,  view_as<int>( g_flBestTopSpd[style][dir][stance] ), 4 ); // Topspeed
    ReadFileCell( hFile, g_nBestStrfs[style][dir][stance], 4 ); // Strafe count
    ReadFileCell( hFile,  view_as<int>( g_flBestSync[style][dir][stance] ), 4 ); // Sync
    
    if ( ReadFileString( hFile, g_szBestName[style][dir][stance], sizeof( g_szBestName[][][] ), -1 ) == -1 )
    {
        LogError( SU_PRE_CLEAR..."Invalid player name found in recording file!" );
        
        delete hFile;
        return false;
    }
    
    FormatJumpName( g_szBestJumpName[style][dir][stance], sizeof( g_szBestJumpName[][][] ), style, dir, stance, true, true );
    
    
    if ( g_hBestRec[style][dir][stance] != null )
    {
        delete g_hBestRec[style][dir][stance];
    }
    
    g_hBestRec[style][dir][stance] = new ArrayList( view_as<int>( FrameData ) );
    
    int iFrame[FRAME_SIZE];
    for ( int i = 0; i < len; i++ )
    {
        if ( ReadFile( hFile, iFrame, view_as<int>( FrameData ), 4 ) == -1 )
        {
            LogError( SU_PRE_CLEAR..."Encountered a sudden end of file!" );
            
            delete hFile;
            return false;
        }
        
        if ( IsFrameInvalid( iFrame ) )
        {
            LogError( SU_PRE_CLEAR..."Recording file (%s) has invalid player angles! {%.1f, %.1f}", szPath, iFrame[FRAME_ANG], iFrame[view_as<int>( FRAME_ANG ) + 1] );
            
            delete g_hBestRec[style][dir][stance];
            
            delete hFile;
            return false;
        }
        
        g_hBestRec[style][dir][stance].PushArray( iFrame, view_as<int>( FrameData ) );
    }
    
    delete hFile;
    
    return true;
}

stock bool SaveRecording( int style, int dir, int stance, ArrayList &hRec,
    float flDist,
    float flPreSpd,
    float flTopSpd,
    int numstrfs,
    float flSync,
    const char[] szName )
{
    static char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "ljrecords" );
    
    if ( !ExCreateDir( szPath ) ) return false;
    
    
    char szMap[32];
    GetLowerCurrentMap( szMap, sizeof( szMap ) );
    
    Format( szPath, sizeof( szPath ), "%s/%s", szPath, szMap );
    if ( !ExCreateDir( szPath ) ) return false;
    
    
    Format( szPath, sizeof( szPath ), "%s/%s_%s_%s.rec", szPath, szDirJumpStyle[style], szDirJumpDir[dir], szDirJumpStance[stance] );
    
    
    Handle hFile = OpenFile( szPath, "wb" );
    if ( hFile == null )
    {
        LogError( SU_PRE_CLEAR..."Couldn't open file to write! (%s)", szPath );
        return false;
    }
    
    
    WriteFileCell( hFile, MAGIC_NUMBER_CUR, 4 ); // Magic number
    
    
    int len = hRec.Length;
    
    WriteFileCell( hFile, len, 4 ); // Frame count
    WriteFileCell( hFile, RoundFloat( g_flTickRate ), 4 ); // Tickrate
    
    WriteFileCell( hFile, style, 4 ); // Style
    WriteFileCell( hFile, dir, 4 ); // Direction
    WriteFileCell( hFile, stance, 4 ); // Stance
    
    WriteFileCell( hFile, view_as<int>( flDist ), 4 ); // Distance
    WriteFileCell( hFile, view_as<int>( flPreSpd ), 4 ); // Prespeed
    WriteFileCell( hFile, view_as<int>( flTopSpd ), 4 ); // Topspeed
    WriteFileCell( hFile, numstrfs, 4 ); // Strafe count
    WriteFileCell( hFile, view_as<int>( flSync ), 4 ); // Sync
    
    WriteFileString( hFile, szName, true ); // Player name
    
    
    int iFrame[FRAME_SIZE];
    for ( int i = 0; i < len; i++ )
    {
        hRec.GetArray( i, iFrame, view_as<int>( FrameData ) );
        
        if ( !WriteFile( hFile, iFrame, view_as<int>( FrameData ), 4 ) )
        {
            LogError( SU_PRE_CLEAR..."Couldn't write frame data onto file! (%s)", szPath );
            
            delete hFile;
            return false;
        }
    }
    
    delete hFile;
    
    return true;
}