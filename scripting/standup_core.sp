#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>
#include <msharedutil/misc>

#include <standup/stocks_chat>
#include <standup/core>

#undef REQUIRE_PLUGIN
#include <standup/hud>
#include <standup/help>
#include <standup/ljmode>


#pragma semicolon 1
#pragma newdecls required


#define PLUGIN_VERSION          "1.0"


// For testing.
//#define DEBUG
//#define DEBUG_STRF_DELTA
//#define DEBUG_STRF_ANGLES
//#define DEBUG_STRF_DATA


#define GAME_CONF_FILE          "standup_core.games"

#define DEF_MAX_RECORDS_QUERY   21

#define DEBUGLINE_DRAW_TIME     6.0
#define DEBUGLINE_WIDTH         1.0

#define ZONE_DRAW_INTERVAL      1.0
#define ZONE_WIDTH              0.25
#define BUILDDRAW_INTERVAL      0.1

#define MATH_PI                 3.141592653589793238462643383279502884197169399375105820974944592307816406286
#define DEG_TO_RAD              MATH_PI / 180.0
#define RAD_TO_DEG              180.0 / MATH_PI
#define DEG45_RAD               45.0 * DEG_TO_RAD
#define DEG90_RAD               90.0 * DEG_TO_RAD

#define STRF_FORMAT             "# - Sync - Time - Gains - Losses"


#define VALID_WEP_SPD           250.0

#define MIN_ONGROUND_TIME       0.5
#define MAX_LJ_Z_DIF            0.1 // Maximum difference in z-axis. Without traces, it's usually around 1.4. When doing bhops it can go up to 5 units.
#define MAX_LJ_TIME             1.1 // If longjump takes longer than this, we will not show any stats even when failed.
#define MAX_LADDER_TIME         1.3
#define MAX_BASEVELOCITY        0.1 // Velocities, even when reset, are usually ~0.001...

#define JUMPFLAG_INVALID        0
#define JUMPFLAG_VALIDSTART     ( 1 << 0 )
#define JUMPFLAG_BHOP           ( 1 << 1 )
#define JUMPFLAG_WEIRD          ( 1 << 2 )
#define JUMPFLAG_MULTIBHOP      ( 1 << 3 )
#define JUMPFLAG_FAILED         ( 1 << 4 )
#define JUMPFLAG_LADDER         ( 1 << 5 )
#define JUMPFLAG_MAYBEFAILED    ( 1 << 6 )
#define JUMPFLAG_HASCROUCHED    ( 1 << 7 )
#define JUMPFLAG_HASSTOOD       ( 1 << 8 )

#define BLOCK_MIN               240
#define BLOCK_MAX               300

#define CHEATSTATE_NONE         0
#define CHEATSTATE_BASEVEL      1
#define CHEATSTATE_WATER        2
#define CHEATSTATE_MOVETYPE     3
#define CHEATSTATE_SURF         4
#define CHEATSTATE_LADDER       5
#define CHEATSTATE_MISC         6

#define STRAFE_INVALID          0
#define STRAFE_LEFT             1
#define STRAFE_RIGHT            2

enum BlockDir
{
    BLOCKDIR_INVALID = -1,
    BLOCKDIR_RIGHT,
    BLOCKDIR_FWD,
    BLOCKDIR_LEFT,
    BLOCKDIR_BWD
};


enum ZoneData
{
    ZONE_ENTREF = 0,
    ZONE_BLOCK,
    ZONE_OPP_ENTREF,
    bool:ZONE_ISSTART,
    BlockDir:ZONE_DIR,
    //ZONE_FLAGS,
    
    Float:ZONE_MINS[3],
    Float:ZONE_MAXS[3]
};

#define ZONE_SIZE       11


enum StrafeData
{
    Float:STRF_SYNC = 0,
    Float:STRF_TIME,
    Float:STRF_GAINS,
    Float:STRF_LOSSES
};

#define STRAFE_SIZE     4


enum
{
    KEY_INVALID = -1,
    KEY_MOVELEFT,
    KEY_MOVERIGHT,
    KEY_FORWARD,
    KEY_BACK,
    
    NUM_KEYS
};


bool g_bLibrary_Hud;
bool g_bLibrary_LjMode;


// Important client stuff
int g_iClientId[MAXPLAYERS];
bool g_bEnabledStats[MAXPLAYERS];


// Misc. client stuff.
float g_flSpam[MAXPLAYERS];
float g_flNextHintTime[MAXPLAYERS];


// Personal best stuff.
float g_flPB_Distance[MAXPLAYERS][NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];
float g_flPB_Distance_Block[MAXPLAYERS][NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];
int g_iPB_Block[MAXPLAYERS][NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];


// Server best
float g_flBest_Distance[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];
float g_flBest_Distance_Block[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];
int g_iBest_Block[NUM_JUMPSTYLE][NUM_JUMPDIR][NUM_JUMPSTANCE];


// Building stuff for admins.
float g_vecBuild_Start[MAXPLAYERS][3];
bool g_bBuildBlock[MAXPLAYERS];
int g_nBuildBlockDist[MAXPLAYERS];


// Block stuff
ArrayList g_hBlocks;

int g_iStartTouchBlock[MAXPLAYERS];
float g_flLastBlockStartTouch[MAXPLAYERS];

int g_iEndTouchBlock[MAXPLAYERS];
float g_flLastBlockEndTouch[MAXPLAYERS];


float g_vecWjStartPos[MAXPLAYERS][3];
// Jump stuff
int g_fJumpFlags[MAXPLAYERS];
bool g_bHasJumped[MAXPLAYERS];

float g_flLastLandTime[MAXPLAYERS];
float g_flLastJumpTime[MAXPLAYERS];

int g_fStartFlags[MAXPLAYERS];
float g_vecJumpStartPos[MAXPLAYERS][3];
float g_vecJumpStartVel[MAXPLAYERS][3];

float g_flMaxJumpTime[MAXPLAYERS];
float g_flPreSpd[MAXPLAYERS];
float g_flLastSpd[MAXPLAYERS];
//float g_flTopSpd[MAXPLAYERS]; We can ditch the topspd since we can just use the gains and losses to calculate it.

float g_vecLastAirVel[MAXPLAYERS][3];
float g_flLastYaw[MAXPLAYERS];
int g_fLastFlags[MAXPLAYERS];
int g_fLastButtons[MAXPLAYERS];
MoveType g_iLastMoveType[MAXPLAYERS];
float g_flLastFwd[MAXPLAYERS];
float g_flLastSide[MAXPLAYERS];

int g_nDirection[MAXPLAYERS][NUM_JUMPDIR];
int g_nKeyPresses[MAXPLAYERS][NUM_KEYS]; // Only counted when PRESSED during a jump.
// Holding something down before jump and then during it doesn't count.

int g_iCheatState[MAXPLAYERS];
float g_flLastCheatTime[MAXPLAYERS];

// Weapon stuff
//float g_flLastWeaponSwitch[MAXPLAYERS];
float g_flLastBadSpdTime[MAXPLAYERS];


// Failed stuff
float g_vecLastValidPos[MAXPLAYERS][3];
float g_vecFailedVel[MAXPLAYERS][3];
int g_fFailedFlags[MAXPLAYERS];


// Strafe stuff
ArrayList g_hCurStrafes[MAXPLAYERS];
ArrayList g_hFailedStrafes[MAXPLAYERS];

int g_iLastStrafe[MAXPLAYERS];
int g_nCurStrafeSync[MAXPLAYERS];
int g_nCurStrafeSyncMax[MAXPLAYERS];
//float g_flCurStrafeStartSpd[MAXPLAYERS];
float g_flCurStrafeGains[MAXPLAYERS];
float g_flCurStrafeLosses[MAXPLAYERS];

// Engine time will have floating point errors!!
int g_nStrafeStartTick[MAXPLAYERS];


// Ladder stuff
float g_vecLadderNormal[MAXPLAYERS][3];
float g_flLastLadderTime[MAXPLAYERS];


float g_flCurTime;

char g_szCurrentMap[64];

static const float g_vecPlyMins[] = { -16.0, -16.0, 0.0 };
static const float g_vecPlyMaxs[] = { 16.0, 16.0, 0.0 };

static const int g_clrWhite[] = { 255, 255, 255, 255 };
static const int g_clrRed[] = { 255, 0, 0, 255 };
static const int g_clrBlue[] = { 0, 0, 255, 255 };

int g_iBeamMat;


// FORWARDS
Handle g_hForward_OnJumpFinished;

Handle g_hForward_OnStatsEnabled;
Handle g_hForward_OnStatsDisabled;

// FUNCS
Handle g_hFunc_GetPlayerMaxSpeed;


// Here comes the cvars!
// Min dist
ConVar g_ConVar_MinDist_Bhop_Ducked;
ConVar g_ConVar_MinDist_Wj_Ducked;
ConVar g_ConVar_MinDist_Lj_Ducked;

ConVar g_ConVar_MinDist_Bhop_Stand;
ConVar g_ConVar_MinDist_Wj_Stand;
ConVar g_ConVar_MinDist_Lj_Stand;
ConVar g_ConVar_MinDist_Up_Stand;

ConVar g_ConVar_MinDist_Bhop;
ConVar g_ConVar_MinDist_Wj;
ConVar g_ConVar_MinDist_Lj;
ConVar g_ConVar_MinDist_Up;

// Good dist
ConVar g_ConVar_GoodDist_Bhop_Ducked;
ConVar g_ConVar_GoodDist_Wj_Ducked;
ConVar g_ConVar_GoodDist_Lj_Ducked;

ConVar g_ConVar_GoodDist_Bhop_Stand;
ConVar g_ConVar_GoodDist_Wj_Stand;
ConVar g_ConVar_GoodDist_Lj_Stand;

ConVar g_ConVar_GoodDist_Bhop;
ConVar g_ConVar_GoodDist_Wj;
ConVar g_ConVar_GoodDist_Lj;

// Very good dist
ConVar g_ConVar_VeryGoodDist_Bhop_Ducked;
ConVar g_ConVar_VeryGoodDist_Wj_Ducked;
ConVar g_ConVar_VeryGoodDist_Lj_Ducked;

ConVar g_ConVar_VeryGoodDist_Bhop_Stand;
ConVar g_ConVar_VeryGoodDist_Wj_Stand;
ConVar g_ConVar_VeryGoodDist_Lj_Stand;

ConVar g_ConVar_VeryGoodDist_Bhop;
ConVar g_ConVar_VeryGoodDist_Wj;
ConVar g_ConVar_VeryGoodDist_Lj;


// Amazing dist
ConVar g_ConVar_AmazingDist_Bhop_Ducked;
ConVar g_ConVar_AmazingDist_Wj_Ducked;
ConVar g_ConVar_AmazingDist_Lj_Ducked;

ConVar g_ConVar_AmazingDist_Bhop_Stand;
ConVar g_ConVar_AmazingDist_Wj_Stand;
ConVar g_ConVar_AmazingDist_Lj_Stand;

ConVar g_ConVar_AmazingDist_Bhop;
ConVar g_ConVar_AmazingDist_Wj;
ConVar g_ConVar_AmazingDist_Lj;

// Ladders
ConVar g_ConVar_MinDist_Ladder;
ConVar g_ConVar_MinDist_Ladder_Stand;

ConVar g_ConVar_GoodDist_Ladder_Stand;
ConVar g_ConVar_GoodDist_Ladder;

ConVar g_ConVar_VeryGoodDist_Ladder_Stand;
ConVar g_ConVar_VeryGoodDist_Ladder;

ConVar g_ConVar_AmazingDist_Ladder_Stand;
ConVar g_ConVar_AmazingDist_Ladder;

// Misc.
ConVar g_ConVar_Wj_MaxDrop;
ConVar g_ConVar_Wj_MaxPreSpeed;
ConVar g_ConVar_Lj_MaxPreSpeed;
ConVar g_ConVar_HintTime;
ConVar g_ConVar_StrafeMenuTime;
ConVar g_ConVar_MinAvgStrafeTime;
ConVar g_ConVar_MaxAvgStrafeSync;
ConVar g_ConVar_MaxPerfSyncStrfs;
ConVar g_ConVar_PerfSync;
ConVar g_ConVar_MaxStrafes;
ConVar g_ConVar_SaveNonMarkedBlock;


#include "standup_core/commands.sp"
#include "standup_core/db.sp"
#include "standup_core/events.sp"
#include "standup_core/natives.sp"


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Core",
    description = "Core of "...PLUGIN_NAME_CORE..." lj stats",
    version = PLUGIN_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    if ( late )
    {
        strcopy( szError, error_len, PLUGIN_NAME_CORE..." cannot be loaded late!" );
        return APLRes_Failure;
    }
    
    
    EngineVersion eng = GetEngineVersion();
    
    if ( eng != Engine_CSS && eng != Engine_CSGO )
    {
        char szFolder[32];
        GetGameFolderName( szFolder, sizeof( szFolder ) );
        
        FormatEx( szError, error_len, PLUGIN_NAME_CORE..." does not support %s!", szFolder );
        
        return APLRes_Failure;
    }
    
    
    // LIBRARIES
    RegPluginLibrary( LIBRARY_CORE );
    
    
    // NATIVES
    CreateNative( "Standup_IsClientStatsEnabled", Native_IsClientStatsEnabled );
    CreateNative( "Standup_SetClientStats", Native_SetClientStats );
    CreateNative( "Standup_GetClientPrespeed", Native_GetClientPrespeed );
    CreateNative( "Standup_GetClientNextHint", Native_GetClientNextHint );
    CreateNative( "Standup_IsSpammingCommand", Native_IsSpammingCommand );
    
    CreateNative( "Standup_InvalidateJump", Native_InvalidateJump );
    
    CreateNative( "Standup_GetGoodDistance", Native_GetGoodDistance );
    CreateNative( "Standup_GetVeryGoodDistance", Native_GetVeryGoodDistance );
    CreateNative( "Standup_GetAmazingDistance", Native_GetAmazingDistance );
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    // LIBRARIES
    g_bLibrary_Hud = LibraryExists( LIBRARY_HUD );
    g_bLibrary_LjMode = LibraryExists( LIBRARY_CORE_LJMODE );
    
    
    // FORWARDS
    g_hForward_OnJumpFinished = CreateGlobalForward( "Standup_OnJumpFinished", ET_Ignore, Param_Cell, Param_Array );
    
    g_hForward_OnStatsEnabled = CreateGlobalForward( "Standup_OnStatsEnabled", ET_Ignore, Param_Cell );
    g_hForward_OnStatsDisabled = CreateGlobalForward( "Standup_OnStatsDisabled", ET_Ignore, Param_Cell );
    
    
    // EVENTS
    HookEvent( "teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy ); // CSS
    
    HookEntityOutput( "trigger_teleport", "OnStartTouch", Event_Teleport_OnStartTouch );
    
    
    // COMMANDS
    RegConsoleCmd( "sm_ljwr", Command_DisplayRecords, "Display longjump records." );
    RegConsoleCmd( "sm_ljtop", Command_DisplayRecords );
    RegConsoleCmd( "sm_ljrecords", Command_DisplayRecords );
    
    RegConsoleCmd( "sm_ljrecordsbyname", Command_DisplayRecordsByName );
    
    RegConsoleCmd( "sm_mylj", Command_DisplayMyRecords );
    RegConsoleCmd( "sm_myljrecords", Command_DisplayMyRecords );
    
    RegConsoleCmd( "sm_ljcredits", Command_Credits );
    RegConsoleCmd( "sm_ljversion", Command_Version );
    
    
    RegAdminCmd( "sm_ljbuildmenu", Command_Admin_Menu_BlockMenu, ADMFLAG_SU_LVL2 );
    
    RegAdminCmd( "sm_startblock", Command_Admin_BlockStart, ADMFLAG_SU_LVL2 );
    RegAdminCmd( "sm_endblock", Command_Admin_BlockEnd, ADMFLAG_SU_LVL2 );
    RegAdminCmd( "sm_cancelblock", Command_Admin_BlockCancel, ADMFLAG_SU_LVL2 );
    
    RegAdminCmd( "sm_createblockend", Command_Admin_SetBlockDist, ADMFLAG_SU_LVL2 );
    
    RegAdminCmd( "sm_removeblock", Command_Admin_BlockRemove, ADMFLAG_SU_LVL2 );
    
    
    RegConsoleCmd( "sm_ljblock", Command_GoToBlock, "Go to a lj block." );
    
    
    // GAME CONFIG
    Handle hGameConf = LoadGameConfigFile( GAME_CONF_FILE );
    
    bool bFailed;
    
    if ( hGameConf != null )
    {
        StartPrepSDKCall( SDKCall_Player );
        
        if ( PrepSDKCall_SetFromConf( hGameConf, SDKConf_Virtual, "GetPlayerMaxSpeed" ) )
        {
            PrepSDKCall_SetReturnInfo( SDKType_Float, SDKPass_Plain );
            g_hFunc_GetPlayerMaxSpeed = EndPrepSDKCall();
            
            if ( g_hFunc_GetPlayerMaxSpeed == null )
            {
                LogError( SU_PRE_CLEAR..."Couldn't finalize SDKCall for GetPlayerMaxSpeed!" );
                
                bFailed = true;
            }
        }
        else
        {
            LogError( SU_PRE_CLEAR..."Couldn't find GetPlayerMaxSpeed offset from gamedata/"...GAME_CONF_FILE...".txt!" );
            
            bFailed = true;
        }
    }
    else
    {
        LogError( SU_PRE_CLEAR..."Missing gamedata/"...GAME_CONF_FILE...".txt file!" );
        
        bFailed = true;
    }
    
    if ( bFailed )
    {
        for ( int i = 0; i < 3; i++ )
        {
            PrintToServer( SU_PRE_CLEAR..."Weapon speed check cannot be made!" );
        }
    }
    
    delete hGameConf;
    
    
    // CVARS
    
    // Min dist
    g_ConVar_MinDist_Bhop_Ducked = CreateConVar( "standup_mindist_bhop_ducked", "200", "", _, true, 0.0, true, 300.0 );
    g_ConVar_MinDist_Wj_Ducked = CreateConVar( "standup_mindist_wj_ducked", "120", "", _, true, 0.0, true, 300.0 );
    g_ConVar_MinDist_Lj_Ducked = CreateConVar( "standup_mindist_lj_ducked", "110", "", _, true, 0.0, true, 300.0 );
    
    g_ConVar_MinDist_Bhop_Stand = CreateConVar( "standup_mindist_bhop_stand", "240", "", _, true, 0.0, true, 300.0 );
    g_ConVar_MinDist_Wj_Stand = CreateConVar( "standup_mindist_wj_stand", "230", "", _, true, 0.0, true, 300.0 );
    g_ConVar_MinDist_Lj_Stand = CreateConVar( "standup_mindist_lj_stand", "220", "", _, true, 0.0, true, 300.0 );
    g_ConVar_MinDist_Up_Stand = CreateConVar( "standup_mindist_up_stand", "100", "", _, true, 0.0, true, 300.0 );
    
    g_ConVar_MinDist_Bhop = CreateConVar( "standup_mindist_bhop", "250", "", _, true, 0.0, true, 300.0 );
    g_ConVar_MinDist_Wj = CreateConVar( "standup_mindist_wj", "240", "", _, true, 0.0, true, 300.0 );
    g_ConVar_MinDist_Lj = CreateConVar( "standup_mindist_lj", "230", "", _, true, 0.0, true, 300.0 );
    g_ConVar_MinDist_Up = CreateConVar( "standup_mindist_up", "120", "", _, true, 0.0, true, 300.0 );
    
    // Good dist
    g_ConVar_GoodDist_Bhop_Ducked = CreateConVar( "standup_gooddist_bhop_ducked", "275", "", _, true, 0.0 );
    g_ConVar_GoodDist_Wj_Ducked = CreateConVar( "standup_gooddist_wj_ducked", "245", "", _, true, 0.0 );
    g_ConVar_GoodDist_Lj_Ducked = CreateConVar( "standup_gooddist_lj_ducked", "130", "", _, true, 0.0 );
    
    g_ConVar_GoodDist_Bhop_Stand = CreateConVar( "standup_gooddist_bhop_stand", "275", "", _, true, 0.0 );
    g_ConVar_GoodDist_Wj_Stand = CreateConVar( "standup_gooddist_wj_stand", "260", "", _, true, 0.0 );
    g_ConVar_GoodDist_Lj_Stand = CreateConVar( "standup_gooddist_lj_stand", "252", "", _, true, 0.0 );
    
    g_ConVar_GoodDist_Bhop = CreateConVar( "standup_gooddist_bhop", "270", "", _, true, 0.0 );
    g_ConVar_GoodDist_Wj = CreateConVar( "standup_gooddist_wj", "280", "", _, true, 0.0 );
    g_ConVar_GoodDist_Lj = CreateConVar( "standup_gooddist_lj", "260", "", _, true, 0.0 );
    
    // Very good dist
    g_ConVar_VeryGoodDist_Bhop_Ducked = CreateConVar( "standup_verygooddist_bhop_ducked", "285", "", _, true, 0.0 );
    g_ConVar_VeryGoodDist_Wj_Ducked = CreateConVar( "standup_verygooddist_wj_ducked", "250", "", _, true, 0.0 );
    g_ConVar_VeryGoodDist_Lj_Ducked = CreateConVar( "standup_verygooddist_lj_ducked", "140", "", _, true, 0.0 );
    
    g_ConVar_VeryGoodDist_Bhop_Stand = CreateConVar( "standup_verygooddist_bhop_stand", "285", "", _, true, 0.0 );
    g_ConVar_VeryGoodDist_Wj_Stand = CreateConVar( "standup_verygooddist_wj_stand", "270", "", _, true, 0.0 );
    g_ConVar_VeryGoodDist_Lj_Stand = CreateConVar( "standup_verygooddist_lj_stand", "255", "", _, true, 0.0 );
    
    g_ConVar_VeryGoodDist_Bhop = CreateConVar( "standup_verygooddist_bhop", "300", "", _, true, 0.0 );
    g_ConVar_VeryGoodDist_Wj = CreateConVar( "standup_verygooddist_wj", "290", "", _, true, 0.0 );
    g_ConVar_VeryGoodDist_Lj = CreateConVar( "standup_verygooddist_lj", "265", "", _, true, 0.0 );
    
    // Amazing dist
    g_ConVar_AmazingDist_Bhop_Ducked = CreateConVar( "standup_amazingdist_bhop_ducked", "290", "", _, true, 0.0 );
    g_ConVar_AmazingDist_Wj_Ducked = CreateConVar( "standup_amazingdist_wj_ducked", "260", "", _, true, 0.0 );
    g_ConVar_AmazingDist_Lj_Ducked = CreateConVar( "standup_amazingdist_lj_ducked", "145", "", _, true, 0.0 );
    
    g_ConVar_AmazingDist_Bhop_Stand = CreateConVar( "standup_amazingdist_bhop_stand", "290", "", _, true, 0.0 );
    g_ConVar_AmazingDist_Wj_Stand = CreateConVar( "standup_amazingdist_wj_stand", "280", "", _, true, 0.0 );
    g_ConVar_AmazingDist_Lj_Stand = CreateConVar( "standup_amazingdist_lj_stand", "260", "", _, true, 0.0 );
    
    g_ConVar_AmazingDist_Bhop = CreateConVar( "standup_amazingdist_bhop", "310", "", _, true, 0.0 );
    g_ConVar_AmazingDist_Wj = CreateConVar( "standup_amazingdist_wj", "300", "", _, true, 0.0 );
    g_ConVar_AmazingDist_Lj = CreateConVar( "standup_amazingdist_lj", "270", "", _, true, 0.0 );
    
    // Ladders
    g_ConVar_MinDist_Ladder_Stand = CreateConVar( "standup_mindist_ladder_stand", "50", "", _, true, 0.0 );
    g_ConVar_MinDist_Ladder = CreateConVar( "standup_mindist_ladder", "60", "", _, true, 0.0 );
    
    g_ConVar_GoodDist_Ladder_Stand = CreateConVar( "standup_gooddist_ladder_stand", "130", "", _, true, 0.0 );
    g_ConVar_GoodDist_Ladder = CreateConVar( "standup_gooddist_ladder", "155", "", _, true, 0.0 );
    
    g_ConVar_VeryGoodDist_Ladder_Stand = CreateConVar( "standup_verygooddist_ladder_stand", "140", "", _, true, 0.0 );
    g_ConVar_VeryGoodDist_Ladder = CreateConVar( "standup_verygooddist_ladder", "165", "", _, true, 0.0 );
    
    g_ConVar_AmazingDist_Ladder_Stand = CreateConVar( "standup_amazingdist_ladder_stand", "150", "", _, true, 0.0 );
    g_ConVar_AmazingDist_Ladder = CreateConVar( "standup_amazingdist_ladder", "170", "", _, true, 0.0 );
    
    // Misc. cvars
    g_ConVar_Wj_MaxDrop = CreateConVar( "standup_wj_maxdrop", "32", "Maximum drop in units for weirdjump.", _, true, 0.0 );
    g_ConVar_Wj_MaxPreSpeed = CreateConVar( "standup_wj_maxprespeed", "300", "Maximum prespeed from the drop. (0 = disable)", _, true, 0.0 );
    g_ConVar_Lj_MaxPreSpeed = CreateConVar( "standup_lj_maxprespeed", "279", "Maximum prespeed for normal longjump.", _, true, 0.0 );
    
    g_ConVar_HintTime = CreateConVar( "standup_minhintholdtime", "1.4", "Minimum time we hold the longjump info on player's screen. (to override prespeed text. 0 = disable)", _, true, 0.0, true, 5.0 );
    g_ConVar_StrafeMenuTime = CreateConVar( "standup_strafemenutime", "5", "Time to keep the strafe menu open in seconds. (0 = disable)", _, true, 0.0 );
    
    g_ConVar_MinAvgStrafeTime = CreateConVar( "standup_minavgstrafetime", "60", "Minimum average time for player's strafes, in msec.", _, true, 0.0 );
    g_ConVar_MaxAvgStrafeSync = CreateConVar( "standup_maxavgstrafesync", "98", "Maximum average sync for player's strafes, in percentages. 0 = disable", _, true, 0.0, true, 100.0 );
    g_ConVar_MaxPerfSyncStrfs = CreateConVar( "standup_maxperfsyncstrfs", "77", "Maximum perfect sync strafes, in percentages. 0 = disable", _, true, 0.0, true, 100.0 );
    g_ConVar_PerfSync = CreateConVar( "standup_perfsync", "99", "What is considered a perfect sync, in percentages. 0 = disable", _, true, 0.0, true, 100.0 );
    
    g_ConVar_MaxStrafes = CreateConVar( "standup_maxstrafes", "12", "Maximum strafe count that is considered legit.", _, true, 0.0 );
    
    g_ConVar_SaveNonMarkedBlock = CreateConVar( "standup_save_nonmarked_blockjumps", "0", "Allow non-marked block jumps to be saved.", _, true, 0.0, true, 1.0 );
    
    
    // MISC.
    CreateTimer( ZONE_DRAW_INTERVAL, Timer_DrawBlockZones, _, TIMER_REPEAT );
    
    DB_InitDatabase();
}

public void Standup_RequestHelpCmds()
{
    Standup_AddCommand( "ljwr", "Display longjump records. Use \"ljwr <args>\" to display specific records!", true );
    Standup_AddCommand( "ljblock", "Go to LJ block. Displays menu if no arguments given.", true );
    Standup_AddCommand( "ljcredits", "Display plugin credits." );
    Standup_AddCommand( "ljversion", "Display plugin version." );
    
    // Admin stuff.
    Standup_AddCommand( "ljbuildmenu", "Menu for LJ block creation.", _, true );
}

public void OnLibraryAdded( const char[] szName )
{
    if ( StrEqual( szName, LIBRARY_HUD ) )              g_bLibrary_Hud = true;
    else if ( StrEqual( szName, LIBRARY_CORE_LJMODE ) ) g_bLibrary_LjMode = true;
}

public void OnLibraryRemoved( const char[] szName )
{
    if ( StrEqual( szName, LIBRARY_HUD ) )              g_bLibrary_Hud = false;
    else if ( StrEqual( szName, LIBRARY_CORE_LJMODE ) ) g_bLibrary_LjMode = false;
}

public void OnMapStart()
{
    // PRECACHING
    PrecacheModel( MAGIC_BRUSH_MODEL );
    
    g_iBeamMat = PrecacheModel( "materials/sprites/laserbeam.vmt" );
    
    
    // RESETS
    if ( g_hBlocks != null )
    {
        delete g_hBlocks;
    }
    
    g_hBlocks = new ArrayList( view_as<int>( ZoneData ) );
    
    
    for ( int a = 0; a < NUM_JUMPSTYLE; a++ )
        for ( int b = 0; b < NUM_JUMPDIR; b++ )
            for ( int c = 0; c < NUM_JUMPSTANCE; c++ )
            {
                g_flBest_Distance[a][b][c] = 0.0;
                g_flBest_Distance_Block[a][b][c] = 0.0;
                g_iBest_Block[a][b][c] = 0;
            }
    
    
    GetLowerCurrentMap( g_szCurrentMap, sizeof( g_szCurrentMap ) );
    
    DB_InitRecords();
    DB_InitMap();
}

public void OnClientPutInServer( int client )
{
    g_iClientId[client] = 0;
    
    // If we need to type sm_lj, disable lj stats by default.
    g_bEnabledStats[client] = !g_bLibrary_LjMode;
    
    if ( g_bEnabledStats[client] )
    {
        Call_StartForward( g_hForward_OnStatsEnabled );
        Call_PushCell( client );
        Call_Finish();
    }
    
    
    g_iStartTouchBlock[client] = -1;
    g_iEndTouchBlock[client] = -1;
    
    g_bBuildBlock[client] = false;
    g_nBuildBlockDist[client] = BLOCK_MIN;
    
    g_flLastJumpTime[client] = 0.0;
    g_flLastLandTime[client] = 0.0;
    
    g_bHasJumped[client] = false;
    g_fJumpFlags[client] = JUMPFLAG_INVALID;
    
    g_flPreSpd[client] = 0.0;
    
    g_iLastStrafe[client] = STRAFE_INVALID;
    StartNewStrafe( client );
    ResetClientStrafes( client );
    
    g_flMaxJumpTime[client] = 0.0;
    g_flNextHintTime[client] = 0.0;
    
    g_flSpam[client] = 0.0;
    
    g_iCheatState[client] = CHEATSTATE_NONE;
    g_flLastCheatTime[client] = 0.0;
    
    g_flLastBadSpdTime[client] = 0.0;
    
    g_flLastLadderTime[client] = 0.0;
    
    
    for ( int a = 0; a < NUM_JUMPSTYLE; a++ )
        for ( int b = 0; b < NUM_JUMPDIR; b++ )
            for ( int c = 0; c < NUM_JUMPSTANCE; c++ )
            {
                g_flPB_Distance[client][a][b][c] = 0.0;
                g_flPB_Distance_Block[client][a][b][c] = 0.0;
                g_iPB_Block[client][a][b][c] = 0;
            }
    
    if ( !IsFakeClient( client ) )
    {
        if ( g_hFunc_GetPlayerMaxSpeed != null )
        {
            SDKHook( client, SDKHook_WeaponSwitchPost, Event_Client_WeaponSwitchPost );
        }
        
        SDKHook( client, SDKHook_PreThinkPost, Event_Client_PreThinkPost );
        SDKHook( client, SDKHook_PostThinkPost, Event_Client_PostThinkPost );
    }
}

public void OnClientDisconnect( int client )
{
    if ( !IsFakeClient( client ) )
        DB_SaveClientData( client );
    
    g_iClientId[client] = 0;
    
    
    if ( g_hCurStrafes[client] != null )
    {
        delete g_hCurStrafes[client];
        g_hCurStrafes[client] = null;
    }
    
    if ( g_hFailedStrafes[client] != null )
    {
        delete g_hFailedStrafes[client];
        g_hFailedStrafes[client] = null;
    }
}

//#define SU_DISPLAYBETAMSG

public void OnClientPostAdminCheck( int client )
{
    if ( !IsFakeClient( client ) )
    {
        DB_GetClientData( client );
        
        // Delay has to be added, since for some reason SayText2 msgs need some delay. Does not happen with TextMsg.
#if defined SU_DISPLAYBETAMSG
        CreateTimer( 1.0, Timer_DisplayWelcomeMsg, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
#endif
    }
}

#if defined SU_DISPLAYBETAMSG
    public Action Timer_DisplayWelcomeMsg( Handle hTimer, int client )
    {
        if ( (client = GetClientOfUserId( client )) && IsClientInGame( client ) )
        {
            SU_PrintToChat( client, client, SU_PRE_CHAT..."Welcome, "...CLR_TEAM..."%N"...CLR_CHAT..."! This server is running soon to be public LJ-stats plugin.", client );
        }
    }
#endif

public void OnGameFrame()
{
    g_flCurTime = GetEngineTime();
}

public Action OnPlayerRunCmd(   int client,
                                int &buttons,
                                int &impulse, // Not used
                                float vel[3],
                                float angles[3] )
{
    if ( !IsPlayerAlive( client ) || IsFakeClient( client ) ) return Plugin_Continue;
    
    if ( !g_bEnabledStats[client] ) return Plugin_Continue;
    
    
    int fFlags = GetEntityFlags( client );
    MoveType mtype = GetEntityMoveType( client );
    
    bool bCheating = CheckCheating( client, fFlags, mtype );
    
    if ( fFlags & FL_ONGROUND )
    {
        OnGround( client, fFlags, bCheating, buttons, angles[1] );
    }
    else
    {
        InAir( client, fFlags, mtype, buttons, angles[1], vel[0], vel[1] );
    }
    
    
    g_fLastFlags[client] = fFlags;
    g_flLastYaw[client] = angles[1];
    g_fLastButtons[client] = buttons;
    g_iLastMoveType[client] = mtype;
    g_flLastFwd[client] = vel[0];
    g_flLastSide[client] = vel[1];
    
    return Plugin_Continue;
}

stock void CopyStrafes( int client, int fResult, ArrayList &hStrafes )
{
    if ( !(fResult & RESULT_FAILED) )
    {
        if ( g_hCurStrafes[client] == null ) return;
        
        
        // We haven't finished our last strafe.
        hStrafes = g_hCurStrafes[client].Clone();
        
        if ( IsStrafeValid( client ) )
        {
            InsertStrafe( client, hStrafes );
        }
    }
    else
    {
        if ( g_hFailedStrafes[client] == null ) return;
        
        
        hStrafes = g_hFailedStrafes[client].Clone();
    }
}

stock bool IsValidJump( int client, int style, const float vecStart[3], const float vecEnd[3], int &fResult, ArrayList &hStrafes, int &num_strfs, int minstrafes = 1, float flRaise = 8.0 )
{
    // If not enough strafes, just ignore the jump completely.
    if ( (num_strfs = GetArrayLength_Safe( hStrafes )) < minstrafes )
    {
        return false;
    }
    
    
    if ( !(fResult & RESULT_FAILED) )
    {
        if ( !CanSee( vecStart, vecEnd, flRaise, style ) )
        {
            return false;
        }
        
        if ( num_strfs > g_ConVar_MaxStrafes.IntValue )
        {
            fResult |= RESULT_FAILED;
            
            SU_PrintToChat( client, client, SU_PRE_CHAT..."You did too many strafes! You haxxor! :(" );
        }
    }

    
    return true;
}

stock bool ValidLastPos( int client, float vec[3] )
{
    // Maximum difference in distance between the end position and last valid position.
    // They may be couple frames apart.
    #define MAX_FRAME_DIST        24.0
    #define MAX_FRAME_DIST_SQ    MAX_FRAME_DIST * MAX_FRAME_DIST
    
#if defined DEBUG
    PrintToServer( SU_PRE_DEV..."Last valid pos dif: %.1f units", GetVectorDistance( g_vecLastValidPos[client], vec, false ) );
#endif
    
    return ( GetVectorDistance( g_vecLastValidPos[client], vec, true ) < MAX_FRAME_DIST_SQ );
}


stock void EndJump( int client, int fEndFlags, bool bForceFailed = false )
{
    if ( g_flLastJumpTime[client] < g_flLastBadSpdTime[client] ) return;
    
    
    int fResult = ( g_fJumpFlags[client] & JUMPFLAG_FAILED || bForceFailed ) ? RESULT_FAILED : 0;
    
    float vecStart[3];
    float vecStart_Vel[3];
    
    float vecEnd[3];
    float vecEnd_Vel[3];
    
    int style = JUMPSTYLE_INVALID;
    float flHeight;
    
    vecStart = g_vecJumpStartPos[client];
    
    vecStart_Vel = g_vecJumpStartVel[client];
    
    
    
    if ( !(fResult & RESULT_FAILED) )
    {
        GetClientAbsOrigin( client, vecEnd );
        
        if ( DoPlayerTraceDown( vecEnd ) )
        {
            TR_GetEndPosition( vecEnd );
        }
        
        if ( !IsValidGrounding( vecStart[2], vecEnd[2] ) )
        {
            flHeight = vecEnd[2] - vecStart[2];
            
            // Is upjump?
            if ( flHeight > 4.0 && flHeight < 72.0 )
            {
                style = JUMPSTYLE_UP;
            }
            else
            {
                // Not on valid ground, if we didn't fail-fail, just ignore the jump completely.
                fResult = ( g_fJumpFlags[client] & JUMPFLAG_MAYBEFAILED ) ? RESULT_FAILED : 0;
                
                if ( !(fResult & RESULT_FAILED) ) return;
            }
        }
        
        GetEntityVelocity( client, vecEnd_Vel );
        
        if ( !(fResult & RESULT_FAILED) && !ValidLastPos( client, vecEnd ) )
        {
            return;
        }
    }
    
    ArrayList hStrafes;
    CopyStrafes( client, fResult, hStrafes );
    
    if ( hStrafes == null ) return;
    
    
    int num_strfs;
    
    if ( !IsValidJump( client, style, vecStart, vecEnd, fResult, hStrafes, num_strfs, _, 3.0 ) )
    {
        delete hStrafes;
        return;
    }
    
    
    if ( fResult & RESULT_FAILED )
    {
        fEndFlags = g_fFailedFlags[client];
        
        vecEnd = g_vecLastValidPos[client];
        vecEnd_Vel = g_vecFailedVel[client];
    }
    
    float vecStart_Landing[3];
    float vecEnd_Landing[3];
    
    // Normal distance for non-block jumps.
    vecStart_Landing = vecStart;
    vecEnd_Landing = vecEnd;
    
    GetClientLandingPoint( vecStart_Landing, vecStart_Vel, false );
    GetClientLandingPoint( vecEnd_Landing, vecEnd_Vel, true );
    
    vecStart_Landing[2] = 0.0;
    vecEnd_Landing[2] = 0.0;
    float flDistance = GetVectorDistance( vecStart_Landing, vecEnd_Landing, false );
    
    
    // For block jumps. We will also use these landing coords for our block distance.
    vecStart_Landing = vecStart;
    vecEnd_Landing = vecEnd;
    
    GetClientLandingPoint_True( vecStart_Landing, vecStart_Vel, false );
    GetClientLandingPoint_True( vecEnd_Landing, vecEnd_Vel, true );
    
    vecStart_Landing[2] = 0.0;
    vecEnd_Landing[2] = 0.0;
    float flDistance_True = GetVectorDistance( vecStart_Landing, vecEnd_Landing, false );
    
    
    // Determine our jump styles.
    if ( style == JUMPSTYLE_INVALID )
    {
        style = GetJumpStyle( g_fJumpFlags[client] );
    }
    
    int dir = GetJumpDir( client );
    int stance = ( !(fEndFlags & FL_DUCKING) && !(g_fJumpFlags[client] & JUMPFLAG_HASCROUCHED) ) ? JUMPSTANCE_STANDUP : JUMPSTANCE_NORMAL;
    
    if ( stance == JUMPSTANCE_NORMAL && g_fStartFlags[client] & FL_DUCKING && !(g_fJumpFlags[client] & JUMPFLAG_HASSTOOD) )
    {
        stance = JUMPSTANCE_DUCKED;
    }
    
    float mindist = GetStyleMinDistance( style, stance );
    float maxdist = Standup_GetAmazingDistance( style, stance ) * 1.5;
    
    if ( !IsValidDistance( client, flDistance_True, mindist, maxdist ) )
    {
        delete hStrafes;
        return;
    }
    
    
    // Check for a valid block lj.
    // > 0 is a block lj.
    int block = 0;
    float block_edge = 0.0;
    int start_dist = 0;
    int len_block = GetArrayLength_Safe( g_hBlocks );
    
    if ( g_iEndTouchBlock[client] != -1 && g_iEndTouchBlock[client] < len_block )
    {
        start_dist = g_hBlocks.Get( g_iEndTouchBlock[client], view_as<int>( ZONE_BLOCK ) );
    }
    
    if ( style != JUMPSTYLE_UP )
    {
        if ( !(fResult & RESULT_FAILED) )
        {
            if (start_dist
            &&  g_iStartTouchBlock[client] != -1
            &&  g_iEndTouchBlock[client] != -1
            &&  g_iStartTouchBlock[client] != g_iEndTouchBlock[client]
            &&  g_hBlocks.Get( g_iStartTouchBlock[client], view_as<int>( ZONE_BLOCK ) ) == start_dist
            &&  flDistance_True >= float( start_dist )
            &&  (g_flCurTime - g_flLastBlockStartTouch[client]) < 0.2 )
            {
                block = start_dist;
            }
            
#if defined DEBUG
            PrintToServer( SU_PRE_DEV..."Start index: %i - Dist: %i", g_iEndTouchBlock[client], start_dist );
#endif
        }
        // Without this check, touching a block and then going somewhere else to lj and failing would still consider it as a block jump and display invalid edge.
        // Kinda hacky but works well enough.
        else if ( (g_flCurTime - g_flLastBlockEndTouch[client]) < MAX_LJ_TIME )
        {
            // Check jump angle.
            float vecDif[2];
            int i;
            
            // Compare both ways, since the end will inherit the same direction.
            for ( i = 0; i < 2; i++ ) vecDif[i] = vecEnd[i] - vecStart[i];
            BlockDir dir1 = YawToBlockDir( VectorToAngle( vecDif[0], vecDif[1] ) );
            
            BlockDir dir2 = GetOppBlockDir( dir1 );
            
            
            BlockDir realdir = g_hBlocks.Get( g_iStartTouchBlock[client], view_as<int>( ZONE_DIR ) );
            
            if ( dir1 == realdir || dir2 == realdir )
            {
                block = start_dist;
            }
        }
        
        
        if ( !block )
        {
            block = GetJumpBlock( vecStart, vecEnd, vecStart_Landing, vecEnd_Landing, flDistance, block_edge );
            
            if ( block )
            {
                if ( !IsValidDistance( client, flDistance, mindist, maxdist ) )
                {
                    delete hStrafes;
                    return;
                }
                
                fResult |= RESULT_NONMARKED_BLOCK;
            }
        }
    }
    
    if ( block && !(fResult & RESULT_NONMARKED_BLOCK) )
    {
        int iZoneData[ZONE_SIZE];
        float vecMins[3];
        float vecMaxs[3];
        
        g_hBlocks.GetArray( g_iEndTouchBlock[client], iZoneData, view_as<int>( ZoneData ) );
        
        CopyArray( iZoneData[ZONE_MINS], vecMins, 3 );
        CopyArray( iZoneData[ZONE_MAXS], vecMaxs, 3 );
        
        
#if defined DEBUG
        Debug_DrawPoint( client, vecStart_Landing, g_clrRed );
#endif
        
        // Is block. Use our TRUE SUPER REAL NON-FICTION 100% FACT distance.
        // In other words, only use one axis.
        switch ( YawToBlockDir( VectorToAngle( vecStart_Vel[0], vecStart_Vel[1] ) ) )
        {
            case BLOCKDIR_RIGHT :
            {
                block_edge = vecMaxs[0] - vecStart_Landing[0];
                
                flDistance = FloatAbs( vecEnd_Landing[0] - vecStart_Landing[0] );
            }
            case BLOCKDIR_FWD :
            {
                block_edge = vecMaxs[1] - vecStart_Landing[1];
                
                flDistance = FloatAbs( vecEnd_Landing[1] - vecStart_Landing[1] );
            }
            case BLOCKDIR_LEFT :
            {
                block_edge = vecStart_Landing[0] - vecMins[0];
                
                flDistance = FloatAbs( vecStart_Landing[0] - vecEnd_Landing[0] );
            }
            case BLOCKDIR_BWD :
            {
                block_edge = vecStart_Landing[1] - vecMins[1];
                
                flDistance = FloatAbs( vecStart_Landing[1] - vecEnd_Landing[1] );
            }
        }
        
        if ( !IsValidDistance( client, flDistance, mindist, maxdist ) )
        {
            delete hStrafes;
            return;
        }
        
        // If our edge and distance don't line up, just limit edge.
        /*if ( block_edge != 0.0 && (flDistance - block_edge) < float( block ) )
        {
            block_edge = flDistance - float( block );
        }*/
    }
    
    // This shouldn't be possible...
    if ( block_edge < 0.0 )
    {
        fResult |= RESULT_FAILED;
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Negative edge not allowed!" );
    }
    
    
    float flAvgSync;
    float flAvgTime;
    
    float flTopSpd = g_flPreSpd[client];
    
    GetStrafeData( client, hStrafes, fResult, num_strfs, flAvgSync, flAvgTime, flTopSpd );
    
    
    if ( style == JUMPSTYLE_WEIRD )
    {
        flHeight = g_vecWjStartPos[client][2] - vecStart[2];
    }
    
    // Construct our jump message.
    static int iJump[JMP_SIZE];
    iJump[JMP_STYLE] = style;
    iJump[JMP_DIR] = dir;
    iJump[JMP_STANCE] = stance;
    iJump[JMP_DIST] = view_as<int>( flDistance );
    iJump[JMP_DIST_TRUE] = view_as<int>( flDistance_True );
    iJump[JMP_PRESPD] = view_as<int>( g_flPreSpd[client] );
    iJump[JMP_TOPSPD] = view_as<int>( flTopSpd );
    iJump[JMP_BLOCK] = block;
    iJump[JMP_BLOCK_EDGE] = view_as<int>( block_edge );
    iJump[JMP_NUMSTRFS] = num_strfs;
    iJump[JMP_AVG_SYNC] = view_as<int>( flAvgSync );
    iJump[JMP_AVG_TIME] = view_as<int>( flAvgTime );
    iJump[JMP_RESULTFLAGS] = fResult;
    iJump[JMP_MISCDATA1] = view_as<int>( flHeight );
    
    // Save to db if we succeeded.
    if ( !(fResult & RESULT_FAILED) )
    {
#if defined DEBUG
        DrawClientBB( client );
        
        PrintToServer( SU_PRE_DEV..."%i strfs (jumpflags: %i) - lj: %.3f - prev pb: %.3f - prev pb block: %.3f - block: %i",
            num_strfs,
            g_fJumpFlags[client],
            flDistance,
            g_flPB_Distance[client][style][dir][stance],
            g_flPB_Distance_Block[client][style][dir][stance],
            block );
#endif
        if ( IS_STYLE_LEGIT( iJump[JMP_STYLE] ) )
        {
            SaveJump( client, iJump[JMP_RESULTFLAGS], iJump, hStrafes );
        }
    }
    
    
    SendJumpForward( client, iJump );
    
    
    DisplayStats( client, iJump, hStrafes );
    
    delete hStrafes;
}

stock void EndLadderjump( int client, int fEndFlags, bool bForceFailed = false )
{
    if ( g_flLastLadderTime[client] < g_flLastBadSpdTime[client] ) return;
    
    
    int fResult = ( g_fJumpFlags[client] & JUMPFLAG_FAILED || bForceFailed ) ? RESULT_FAILED : 0;
    
    float vecStart[3];
    float vecEnd[3];
    float vecStart_Vel[3];
    float vecEnd_Vel[3];
    
    
    vecStart = g_vecJumpStartPos[client];
    
    
    if ( !(fResult & RESULT_FAILED) )
    {
        GetClientAbsOrigin( client, vecEnd );
        
        
        if ( !IsValidGrounding( vecStart[2], vecEnd[2] ) )
        {
            // Not on valid ground, if we didn't fail-fail, just ignore the jump completely.
            fResult = ( g_fJumpFlags[client] & JUMPFLAG_MAYBEFAILED ) ? RESULT_FAILED : 0;
            
            if ( !(fResult & RESULT_FAILED) ) return;
        }
        else
        {
            if ( !ValidLastPos( client, vecEnd ) ) return;
            
            
            GetEntityVelocity( client, vecEnd_Vel );
        }
    }
    
    if ( fResult & RESULT_FAILED )
    {
        fEndFlags = g_fFailedFlags[client];
        
        vecEnd = g_vecLastValidPos[client];
        vecEnd_Vel = g_vecFailedVel[client];
    }
    
    
    ArrayList hStrafes;
    CopyStrafes( client, fResult, hStrafes );
    
    if ( hStrafes == null ) return;
    
    
    int num_strfs;
    if ( !IsValidJump( client, JUMPSTYLE_LADDER, vecStart, vecEnd, fResult, hStrafes, num_strfs, 0, 8.0 ) )
    {
        delete hStrafes;
        return;
    }
    
    
#if defined DEBUG
    DrawClientBB_Pos( client, vecEnd );
#endif
    
    vecStart_Vel[0] = -g_vecLadderNormal[client][0];
    vecStart_Vel[1] = -g_vecLadderNormal[client][1];
    
    GetEntityVelocity( client, vecEnd_Vel );
    
    GetClientLandingPoint_True( vecStart, vecStart_Vel, true );
    GetClientLandingPoint_True( vecEnd, vecEnd_Vel, true );
    
#if defined DEBUG
    DrawClientBB_Pos( client, g_vecJumpStartPos[client] );
    
    Debug_DrawPoint( client, vecStart, g_clrBlue );
    Debug_DrawPoint( client, vecEnd, g_clrBlue );
#endif
    
    float flDistance;
    
    switch ( YawToBlockDir( VectorToAngle( -g_vecLadderNormal[client][0], -g_vecLadderNormal[client][1] ) ) )
    {
        case BLOCKDIR_RIGHT :
        {
            flDistance = vecEnd[0] - vecStart[0];
        }
        case BLOCKDIR_FWD :
        {
            flDistance = vecEnd[1] - vecStart[1];
        }
        case BLOCKDIR_LEFT :
        {
            flDistance = vecStart[0] - vecEnd[0];
        }
        case BLOCKDIR_BWD :
        {
            flDistance = vecStart[1] - vecEnd[1];
        }
    }
    
#if defined DEBUG
    PrintToServer( SU_PRE_DEV..."Distance: %.3f units", flDistance );
#endif
    
    
    int stance = ( !(fEndFlags & FL_DUCKING) && !(g_fJumpFlags[client] & JUMPFLAG_HASCROUCHED) ) ? JUMPSTANCE_STANDUP : JUMPSTANCE_NORMAL;
    

    
    if ( !IsValidDistance( client, flDistance, GetStyleMinDistance( JUMPSTYLE_LADDER, stance ), Standup_GetAmazingDistance( JUMPSTYLE_LADDER, stance ) * 1.5 ) )
    {
        delete hStrafes;
        return;
    }
    
    
    float flAvgSync;
    float flAvgTime;
    
    float flTopSpd = SquareRoot( g_vecJumpStartVel[client][0] * g_vecJumpStartVel[client][0] + g_vecJumpStartVel[client][1] * g_vecJumpStartVel[client][1] );
    
    GetStrafeData( client, hStrafes, fResult, num_strfs, flAvgSync, flAvgTime, flTopSpd );
    
    static int iJump[JMP_SIZE];
    iJump[JMP_STYLE] = JUMPSTYLE_LADDER;
    iJump[JMP_DIR] = GetJumpDir( client );
    iJump[JMP_STANCE] = stance;
    iJump[JMP_DIST] = view_as<int>( flDistance );
    iJump[JMP_DIST_TRUE] = view_as<int>( flDistance );
    iJump[JMP_PRESPD] = view_as<int>( g_flPreSpd[client] );
    iJump[JMP_TOPSPD] = view_as<int>( flTopSpd );
    //iJump[JMP_BLOCK] = 0;
    //iJump[JMP_BLOCK_EDGE] = 0;
    iJump[JMP_NUMSTRFS] = num_strfs;
    iJump[JMP_AVG_SYNC] = view_as<int>( flAvgSync );
    iJump[JMP_AVG_TIME] = view_as<int>( flAvgTime );
    iJump[JMP_RESULTFLAGS] = fResult;
    //iJump[JMP_MISCDATA1] = 0;
    
    if ( !(fResult & RESULT_FAILED) )
    {
#if defined DEBUG
        DrawClientBB( client );
        
        PrintToServer( SU_PRE_DEV..."%i strfs (jumpflags: %i) - lj: %.3f - prev pb: %.3f - prev pb block: %.3f",
            num_strfs,
            g_fJumpFlags[client],
            flDistance,
            g_flPB_Distance[client][JUMPSTYLE_LADDER][iJump[JMP_DIR]][iJump[JMP_STANCE]],
            g_flPB_Distance_Block[client][JUMPSTYLE_LADDER][iJump[JMP_DIR]][iJump[JMP_STANCE]] );
#endif
        
        SaveJump( client, iJump[JMP_RESULTFLAGS], iJump, hStrafes );
    }
    
    
    SendJumpForward( client, iJump );
    
    
    DisplayStats( client, iJump, hStrafes );
    
    delete hStrafes;
}

stock void SendJumpForward( int client, const int iJump[JMP_SIZE] )
{
    Call_StartForward( g_hForward_OnJumpFinished );
    Call_PushCell( client );
    Call_PushArray( iJump, sizeof( iJump ) );
    Call_Finish();
}

stock void SaveJump( int client, int &fResult, const int iJump[JMP_SIZE], ArrayList &hStrafes )
{
    
    bool bSaveNonMarked = ( g_ConVar_SaveNonMarkedBlock.BoolValue || !(fResult & RESULT_NONMARKED_BLOCK) );
    
    int style = iJump[JMP_STYLE];
    int dir = iJump[JMP_DIR];
    int stance = iJump[JMP_STANCE];
    
    float flDistance = view_as<float>( iJump[JMP_DIST] );
    int block = iJump[JMP_BLOCK];
    
    
    
    bool bShouldUpdatePB = flDistance > g_flPB_Distance[client][style][dir][stance];
    
    // Is better block OR is same block but better distance
    bool bShouldUpdatePBBlock = ( block > g_iPB_Block[client][style][dir][stance] ) || ( block && block == g_iPB_Block[client][style][dir][stance] && flDistance > g_flPB_Distance_Block[client][style][dir][stance] );
    
    
    bool bShouldSavePBBlock = bShouldUpdatePBBlock && bSaveNonMarked;
    
    if ( bShouldUpdatePB || bShouldSavePBBlock )
    {
        fResult |= RESULT_SAVED;
    }
    
    if ( bShouldUpdatePBBlock || bShouldUpdatePB )
    {
        // Do the same thing for the best.
        // Is better block OR is same block but better distance
        if ( block > g_iBest_Block[style][dir][stance] || ( block && block == g_iBest_Block[style][dir][stance] && flDistance > g_flBest_Distance_Block[style][dir][stance] ) )
        {
            if ( bShouldSavePBBlock )
            {
                g_flBest_Distance_Block[style][dir][stance] = flDistance;
                g_iBest_Block[style][dir][stance] = block;
            }
            
            fResult |= RESULT_BEST_BLOCK;
        }
        
        
        if ( flDistance > g_flBest_Distance[style][dir][stance] )
        {
            g_flBest_Distance[style][dir][stance] = flDistance;
            
            fResult |= RESULT_BEST_DIST;
        }
        
        if ( bShouldUpdatePBBlock )
        {
            fResult |= RESULT_PB_BLOCK;
            
            if ( bShouldSavePBBlock )
            {
#if defined DEBUG
                PrintToServer( SU_PRE_DEV..."Updating %N's PB block!", client );
#endif
                
                DB_SaveJump( client, iJump, hStrafes, true );
            }
            
            g_flPB_Distance_Block[client][style][dir][stance] = flDistance;
            g_iPB_Block[client][style][dir][stance] = block;
        }
        
        if ( bShouldUpdatePB )
        {
            fResult |= RESULT_PB_DIST;
            
#if defined DEBUG
            PrintToServer( SU_PRE_DEV..."Updating %N's PB!", client );
#endif
            
            DB_SaveJump( client, iJump, hStrafes, false );
            
            g_flPB_Distance[client][style][dir][stance] = flDistance;
        }
    }
}

stock void GetStrafeData( int client, ArrayList &hStrafes, int &fResult, int num_strfs, float &flAvgSync, float &flAvgTime, float &flTopSpd )
{
    // Calc top speed and avg sync/time.
    // Check for cheated avg strafe time (in msec) and sync.
    // Also check for too many perfect strafes.
    int iData[STRAFE_SIZE];
    
    int num_perfstrfs = 0;
    
    // Disable eet.
    float perfsync = ( g_ConVar_PerfSync.FloatValue != 0.0 ) ? g_ConVar_PerfSync.FloatValue : 1337.0;
    
    for ( int i = 0; i < num_strfs; i++ )
    {
        hStrafes.GetArray( i, iData, view_as<int>( StrafeData ) );
        
        
        flAvgSync += iData[view_as<int>( STRF_SYNC )];
        flAvgTime += iData[view_as<int>( STRF_TIME )] * 1000.0;
        
        // Count 'perfect' strafes.
        if ( iData[view_as<int>( STRF_SYNC )] >= perfsync )
        {
            ++num_perfstrfs;
        }
        
        flTopSpd += iData[view_as<int>( STRF_GAINS )] - iData[view_as<int>( STRF_LOSSES )];
    }
    
    flAvgSync = flAvgSync / num_strfs;
    flAvgTime /= num_strfs;
    
    if ( flAvgTime < g_ConVar_MinAvgStrafeTime.FloatValue )
    {
        fResult |= RESULT_FAILED;
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Your average strafe time was too low! (Min: %03.0fms)", g_ConVar_MinAvgStrafeTime.FloatValue );
    }
    
    if ( g_ConVar_MaxAvgStrafeSync.FloatValue != 0.0 && flAvgSync >= g_ConVar_MaxAvgStrafeSync.FloatValue )
    {
        fResult |= RESULT_FAILED;
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Your average strafe sync was too high! (Max: %.1f%%)", g_ConVar_MaxAvgStrafeSync.FloatValue );
    }
    
    if ( g_ConVar_MaxPerfSyncStrfs.FloatValue != 0.0 && (num_perfstrfs / float(num_strfs)) >= (g_ConVar_MaxPerfSyncStrfs.FloatValue / 100.0) )
    {
        fResult |= RESULT_FAILED;
        
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Your perfect sync strafe count was too high! (Max: %.1f%%)", g_ConVar_MaxPerfSyncStrfs.FloatValue );
    }
}

stock bool IsValidDistance( int client, float dist, float mindist, float maxdist )
{
    if ( dist < mindist )
    {
        return false;
    }
    
    if ( dist > maxdist )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Your longjump distance was too high!" );
        return false;
    }
    
    return true;
}

stock bool CanSee( const float vecStart[3], const float vecEnd[3], float flRaise = 8.0, int style = JUMPSTYLE_INVALID )
{
    // Check if something obstructs our vision.
    float vec1[3];
    float vec2[3];
    
    
    // Do special method for upjumps.
    if ( style == JUMPSTYLE_UP )
    {
        vec1[0] = vecStart[0];
        vec1[1] = vecStart[1];
        vec1[2] = vecEnd[2] + flRaise;
        
        vec2[0] = vecEnd[0];
        vec2[1] = vecEnd[1];
        vec2[2] = vecEnd[2] + flRaise;
    }
    else
    {
        vec1[0] = vecStart[0];
        vec1[1] = vecStart[1];
        vec1[2] = vecStart[2] + flRaise;
        
        vec2[0] = vecEnd[0];
        vec2[1] = vecEnd[1];
        vec2[2] = vecEnd[2] + flRaise;
    }

    
    TR_TraceRayFilter( vec1, vec2, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_GroundOnly );
    
    if ( TR_DidHit() )
    {
#if defined DEBUG
        PrintToServer( SU_PRE_DEV..."Something obstructed our vision!" );
#endif
        return false;
    }
    
    return true;
}

stock bool IsValidLongjump( int client )
{
    return (g_bHasJumped[client]
        &&    g_fJumpFlags[client] & JUMPFLAG_VALIDSTART
        &&    g_iCheatState[client] == CHEATSTATE_NONE
        &&    !(g_fJumpFlags[client] & JUMPFLAG_MULTIBHOP)
        &&    !(g_fJumpFlags[client] & JUMPFLAG_LADDER) );
}

stock bool IsValidLadderjump( int client )
{
    return ( g_fJumpFlags[client] & JUMPFLAG_LADDER && g_iCheatState[client] == CHEATSTATE_LADDER );
}

stock void OnGround( int client, int fFlags, bool bCheating, int buttons, float yaw )
{
    // We jumped and now we landed.
    if ( !(g_fLastFlags[client] & FL_ONGROUND) )
    {
        // We were in valid LJ, this is our end position.
        if ( IsValidLongjump( client ) )
        {
            // Took too long? Don't display stats.
            if ( g_flCurTime < g_flMaxJumpTime[client] )
            {
                EndJump( client, fFlags );
                
                
                // If it was a normal lj, let us keep it as a start, else reset. (for bhop lj)
                if ( g_fJumpFlags[client] & JUMPFLAG_WEIRD || g_fJumpFlags[client] & JUMPFLAG_BHOP )
                {
                    g_fJumpFlags[client] = JUMPFLAG_INVALID;
                }
            }
            else
            {
                g_fJumpFlags[client] = JUMPFLAG_INVALID;
            }
        }
        else if ( IsValidLadderjump( client ) )
        {
            EndLadderjump( client, fFlags );
            
            g_fJumpFlags[client] = JUMPFLAG_INVALID;
        }
        
#if defined DEBUG
        if ( g_bHasJumped[client] )
        {
            PrintToServer( SU_PRE_DEV..."%i was in air for %.1f!", client, g_flCurTime - g_flLastJumpTime[client] );
        }
#endif
        
        g_bHasJumped[client] = false;
        g_flLastLandTime[client] = g_flCurTime;
    }
    
    
    // We're on the ground and about to jump.
    if ( buttons & IN_JUMP && !(g_fLastButtons[client] & IN_JUMP) )
    {
        float vecPos[3];
        GetClientAbsOrigin( client, vecPos );
        
        
        if ( !bCheating )
        {
            GetEntityVelocity( client, g_vecJumpStartVel[client] );
            g_flPreSpd[client] = SquareRoot( g_vecJumpStartVel[client][0] * g_vecJumpStartVel[client][0] + g_vecJumpStartVel[client][1] * g_vecJumpStartVel[client][1] );
            
            StartLongjump( client, vecPos, fFlags );
            
            g_vecJumpStartPos[client] = vecPos;
            
            // Clear out our cheat flags on jump.
            g_iCheatState[client] = CHEATSTATE_NONE;
        }
        
        
        g_bHasJumped[client] = true;
        g_flLastJumpTime[client] = g_flCurTime;
    }
}

stock bool HasCheatedRecently( int client )
{
    return ( (g_flCurTime - g_flLastCheatTime[client]) < MIN_ONGROUND_TIME );
}

stock bool HasGoodWeapon( int client )
{
    return ( GetPlayerMaxSpeed( client ) == VALID_WEP_SPD && (g_flCurTime - g_flLastBadSpdTime[client]) > 0.1 );
}

stock void StartNewJump( int client, int fFlags )
{
    // Ladder prespeed takes into account z-axis that's why we're recalculation this instead of using the prespeed.
    g_flLastSpd[client] = SquareRoot( g_vecJumpStartVel[client][0] * g_vecJumpStartVel[client][0] + g_vecJumpStartVel[client][1] * g_vecJumpStartVel[client][1] );
    
    
    // Strafe stuff...
    g_iLastStrafe[client] = STRAFE_INVALID;
    ResetClientStrafes( client );
    StartNewStrafe( client );
    //g_flCurStrafeStartSpd[client] = g_flPreSpd[client];
    
    
    g_fStartFlags[client] = fFlags;
    
    FillArray( g_nKeyPresses[client], 0, NUM_KEYS );
    FillArray( g_nDirection[client], 0, NUM_JUMPDIR );
}

stock void StartLadderjump( int client, int fFlags )
{
    if ( g_flPreSpd[client] < 200.0 ) return;
    
    if ( HasCheatedRecently( client ) || !HasGoodWeapon( client ) )
    {
        g_fJumpFlags[client] = JUMPFLAG_INVALID;
        return;
    }
    
    g_fJumpFlags[client] = JUMPFLAG_LADDER;
    
    g_flMaxJumpTime[client] = g_flCurTime + MAX_LADDER_TIME;
    
    StartNewJump( client, fFlags );
}

stock void StartLongjump( int client, float vecCurPos[3], int fFlags )
{
    if ( HasCheatedRecently( client ) || !HasGoodWeapon( client ) )
    {
        g_fJumpFlags[client] = JUMPFLAG_INVALID;
        return;
    }
    
    
    int style = GetJumpStyle( g_fJumpFlags[client] );
    
    // Don't even bother to record anything if our prestrafe is not good enough.
    if ( g_flPreSpd[client] < GetStyleMinPrestrafe( style, ( fFlags & FL_DUCKING ) ? true : false ) )
    {
        g_fJumpFlags[client] = JUMPFLAG_INVALID;
        return;
    }
    
    // Reset everything.
    StartNewJump( client, fFlags );
    
    
    g_fJumpFlags[client] &= ~JUMPFLAG_HASSTOOD;
    g_fJumpFlags[client] &= ~JUMPFLAG_HASCROUCHED;
    
    
    g_flMaxJumpTime[client] = g_flCurTime + MAX_LJ_TIME;
    
    
    // Time on ground has to be enough to be considered a valid LJ start.
    if ( (g_flCurTime - g_flLastLandTime[client]) > MIN_ONGROUND_TIME )
    {
        g_fJumpFlags[client] = ( g_flPreSpd[client] < GetStyleMaxPrestrafe( JUMPSTYLE_LJ ) ) ? JUMPFLAG_VALIDSTART : JUMPFLAG_INVALID;
    }
    else
    {
        if ( g_fJumpFlags[client] & JUMPFLAG_WEIRD )
        {
            if ( DoPlayerTraceDown( vecCurPos ) )
            {
                TR_GetEndPosition( vecCurPos );
            }
            
            float flDrop = g_vecWjStartPos[client][2] - vecCurPos[2];
            
#if defined DEBUG
            PrintToServer( SU_PRE_DEV..."%i attempting wj! (drop: %.2f, prespd: %.1f)", client, flDrop, g_flPreSpd[client] );
#endif
            
            #define MAX_WJ_DIST        64.0
            #define MAX_WJ_DIST_SQ    MAX_WJ_DIST * MAX_WJ_DIST
            
            if (flDrop > 2.0
            &&  flDrop <= g_ConVar_Wj_MaxDrop.FloatValue
            &&  (g_ConVar_Wj_MaxPreSpeed.FloatValue != 0.0 && g_flPreSpd[client] <= g_ConVar_Wj_MaxPreSpeed.FloatValue)
            &&  !(g_fJumpFlags[client] & JUMPFLAG_MULTIBHOP)
            &&  GetVectorDistance( g_vecWjStartPos[client], vecCurPos, true ) > MAX_WJ_DIST_SQ
            &&  CanSee( vecCurPos, g_vecWjStartPos[client] ) )
            {
                
                g_fJumpFlags[client] |= JUMPFLAG_VALIDSTART;
            }
            else
            {
                g_fJumpFlags[client] = JUMPFLAG_INVALID;
            }
        }
        
        // Already have bhop flag? Means we're doing multibhop which shouldn't be recorded.
        else if ( g_fJumpFlags[client] & JUMPFLAG_BHOP )
        {
#if defined DEBUG
            PrintToServer( SU_PRE_DEV..."%i did multibhop!", client );
#endif
            g_fJumpFlags[client] |= JUMPFLAG_MULTIBHOP;
            g_fJumpFlags[client] &= ~JUMPFLAG_VALIDSTART;
        }
        else
        {
            if ( DoPlayerTraceDown( vecCurPos ) )
            {
                TR_GetEndPosition( vecCurPos );
            }
            
            if ( IsValidGrounding( vecCurPos[2], g_vecJumpStartPos[client][2] ) )
            {
#if defined DEBUG
                PrintToServer( SU_PRE_DEV..."%i did bhop!", client );
#endif
                g_fJumpFlags[client] |= JUMPFLAG_BHOP;
            }
            else
            {
                g_fJumpFlags[client] = JUMPFLAG_INVALID;
            }
        }
    }
    
#if defined DEBUG
    DrawClientBB( client );
#endif
}

stock bool IsValidLadderNormal( float vec[3] )
{
    return ( (vec[0] == 1.0 || vec[0] == -1.0 || vec[0] == 0.0) && (vec[1] == 1.0 || vec[1] == -1.0 || vec[1] == 0.0) && vec[2] == 0.0 );
}

stock bool IsClientInValidJump( int client )
{
    return ( g_fJumpFlags[client] & JUMPFLAG_VALIDSTART || g_fJumpFlags[client] & JUMPFLAG_LADDER );
}

stock void InAir( int client, int fFlags, MoveType movetype, int buttons, float yaw, float fwdspd, float sidespd )
{
    static float vecLadderStartPos[MAXPLAYERS][3];
    static float vecLadderStartVel[MAXPLAYERS][3];
    
    if ( movetype != MOVETYPE_WALK )
    {
        if ( movetype == MOVETYPE_LADDER )
        {
            GetEntPropVector( client, Prop_Data, "m_vecLadderNormal", g_vecLadderNormal[client] );
            
            GetClientAbsOrigin( client, vecLadderStartPos[client] );
            
            GetEntityVelocity( client, vecLadderStartVel[client] );
            
            g_flLastLadderTime[client] = g_flCurTime;
        }
        
        return;
    }
    
    
    // No longer on ladder, start of a ladder jump.
    if ( g_iLastMoveType[client] == MOVETYPE_LADDER )
    {
#if defined DEBUG
        //PrintToServer( SU_PRE_DEV..."Ladder normal: (%.1f, %.1f, %.1f)", g_vecLadderNormal[client][0], g_vecLadderNormal[client][1], g_vecLadderNormal[client][2] );
#endif

        if ( !(g_fLastFlags[client] & FL_DUCKING) && IsValidLadderNormal( g_vecLadderNormal[client] ) )
        {
#if defined DEBUG
            PrintToServer( SU_PRE_DEV..."Started a ladder jump!" );
#endif
            
            
            g_vecJumpStartPos[client] = vecLadderStartPos[client];
            g_vecJumpStartVel[client] = vecLadderStartVel[client];
            
            g_flPreSpd[client] = SquareRoot(vecLadderStartVel[client][0] * vecLadderStartVel[client][0]
                                        +    vecLadderStartVel[client][1] * vecLadderStartVel[client][1]
                                        +    vecLadderStartVel[client][2] * vecLadderStartVel[client][2] );
            
            StartLadderjump( client, fFlags );
        }
    }
    
    // Our jump has been going on for too long, stop doing everything and show the stats.
    if ( g_bHasJumped[client] && g_flCurTime >= g_flMaxJumpTime[client] && IsClientInValidJump( client ) )
    {
#if defined DEBUG
        PrintToServer( SU_PRE_DEV..."Jump took too long!" );
#endif
        
        if ( g_fJumpFlags[client] & JUMPFLAG_LADDER )
        {
            EndLadderjump( client, fFlags, true );
        }
        else
        {
            EndJump( client, fFlags, true );
        }
        
        g_fJumpFlags[client] = JUMPFLAG_INVALID;
        
        return;
    }
    
    if ( g_fJumpFlags[client] & JUMPFLAG_FAILED ) return;
    
    
    // We didn't jump, may be a start of a weird jump...
    if ( !g_bHasJumped[client] && g_fLastFlags[client] & FL_ONGROUND && movetype == MOVETYPE_WALK && !HasCheatedRecently( client ) )
    {
#if defined DEBUG
        PrintToServer( SU_PRE_DEV..."%i start of weirdjump.", client );
#endif
        
        GetClientAbsOrigin( client, g_vecWjStartPos[client] );
        
        g_fJumpFlags[client] |= JUMPFLAG_WEIRD;
    }
    
    if ( !IsClientInValidJump( client ) ) return;
    
    
    if ( fFlags & FL_DUCKING )
    {
        g_fJumpFlags[client] |= JUMPFLAG_HASCROUCHED;
    }
    else
    {
        g_fJumpFlags[client] |= JUMPFLAG_HASSTOOD;
    }
    
    // Check for a failed jump.
    static float vecTemp[3];
    GetClientAbsOrigin( client, vecTemp );
    
    float flDif = vecTemp[2] - g_vecJumpStartPos[client][2];
    
    // Steps aren't checked in the air.
    if ( flDif <= -0.1 )
    {
#if defined DEBUG
        PrintToServer( SU_PRE_DEV..."Jump is under z-axis!" );
#endif
        // If our situation is too hopeless, just end it.
        if ( (fFlags & FL_DUCKING && flDif <= -32.0) || flDif <= -64.0 )
        {
            g_fJumpFlags[client] |= JUMPFLAG_FAILED;
            
#if defined DEBUG
            PrintToServer( SU_PRE_DEV..."Failed jump!" );
#endif
        }
        
        if ( !(g_fJumpFlags[client] & JUMPFLAG_MAYBEFAILED) )
        {
            // We MAY have failed.
            g_fJumpFlags[client] |= JUMPFLAG_MAYBEFAILED;
            
            
            g_fFailedFlags[client] = fFlags;
            
            GetEntityVelocity( client, g_vecFailedVel[client] );
            
            
            // Clone all strafes in case we fail.
            if ( g_hCurStrafes[client] != null )
            {
                if ( g_hFailedStrafes[client] != null )
                {
                    delete g_hFailedStrafes[client];
                }
                
                g_hFailedStrafes[client] = g_hCurStrafes[client].Clone();
                
                
                // Finish last strafe but don't start a new one.
                if ( IsStrafeValid( client ) )
                {
                    InsertStrafe( client, g_hFailedStrafes[client] );
                }
            }
            
#if defined DEBUG
            PrintToServer( SU_PRE_DEV..."May have failed!" );
#endif
        }
    }
    else
    {
        g_fJumpFlags[client] &= ~JUMPFLAG_MAYBEFAILED;
        
        // Save it in case we fail our jump next frame.
        CopyArray( vecTemp, g_vecLastValidPos[client], 3 );
    }
    
    
    // Record our key presses.
    // Used to recognize directions.
    GetEntityVelocity( client, vecTemp );
    
    if ( fwdspd != 0.0 || sidespd != 0.0 )
        CheckJumpDirection( client, vecTemp, yaw );
    
    if ( sidespd < 0.0 && !(g_flLastSide[client] < 0.0) )
    {
        g_nKeyPresses[client][KEY_MOVELEFT]++;
    }
    
    if ( sidespd > 0.0 && !(g_flLastSide[client] > 0.0) )
    {
        g_nKeyPresses[client][KEY_MOVERIGHT]++;
    }
    
    if ( fwdspd > 0.0 && !(g_flLastFwd[client] > 0.0) )
    {
        g_nKeyPresses[client][KEY_FORWARD]++;
    }
    
    if ( fwdspd < 0.0 && !(g_flLastFwd[client] < 0.0) )
    {
        g_nKeyPresses[client][KEY_BACK]++;
    }
    
    
    /*
        Please note that OnPlayerRunCmd is ran (heh, get it?) before player movement.
        
        Using properties in this function is simply accessing previous frame's data.
        That is why we apply gains first and then check for a new strafe.
    */
    
    // Has to be squared for gains since we now use them for top speed.
    float flSpd = SquareRoot( vecTemp[0] * vecTemp[0] + vecTemp[1] * vecTemp[1] );
    
    
    if ( flSpd > g_flLastSpd[client] )
    {
        g_nCurStrafeSync[client]++;
        
        g_flCurStrafeGains[client] += flSpd - g_flLastSpd[client];
    }
    else
    {
        g_flCurStrafeLosses[client] += g_flLastSpd[client] - flSpd;
    }
    
    g_nCurStrafeSyncMax[client]++;
    
    
    int iCurStrafe = GetClientStrafe( client, vecTemp );
    
    if ( g_iLastStrafe[client] != iCurStrafe && g_iLastStrafe[client] != STRAFE_INVALID )
    {
        // New strafe!
        if ( IsStrafeValid( client ) )
        {
            InsertStrafe( client, g_hCurStrafes[client] );
        }
        
        StartNewStrafe( client );
    }
    
    // Update top speed.
    /*if ( flSpd > g_flTopSpd[client] )
    {
        g_flTopSpd[client] = flSpd;
    }*/
    
    g_iLastStrafe[client] = iCurStrafe;
    g_flLastSpd[client] = flSpd;
    
    g_vecLastAirVel[client] = vecTemp;
}

stock bool IsStrafeValid( int client )
{
    // If our last strafe was only 1 frame long and we didn't even get speed, it probably wasn't a valid strafe in the first place.
    return ( (g_nCurStrafeSyncMax[client] > 1 || g_nCurStrafeSync[client] > 0) && (GetGameTickCount() - g_nStrafeStartTick[client]) > 0 );
}

stock void InsertStrafe( int client, ArrayList &hStrafes )
{
    static int iData[STRAFE_SIZE];
    
    
    iData[view_as<int>( STRF_SYNC )] = g_nCurStrafeSync[client] / float( g_nCurStrafeSyncMax[client] ) * 100.0;
    
    
#if defined DEBUG_STRF_DATA
    PrintToServer( SU_PRE_DEV..."Sync is %.3f (%i/%i)", iData[view_as<int>( STRF_SYNC )], g_nCurStrafeSync[client], g_nCurStrafeSyncMax[client] );
#endif
    
    
    iData[view_as<int>( STRF_TIME )] = ( GetGameTickCount() - g_nStrafeStartTick[client] ) * GetTickInterval();
    iData[view_as<int>( STRF_GAINS )] = g_flCurStrafeGains[client];
    iData[view_as<int>( STRF_LOSSES )] = g_flCurStrafeLosses[client];
    
    hStrafes.PushArray( iData, view_as<int>( StrafeData ) );
}

stock void StartNewStrafe( int client )
{
    g_nCurStrafeSync[client] = 0;
    g_nCurStrafeSyncMax[client] = 0;
    g_flCurStrafeGains[client] = 0.0;
    g_flCurStrafeLosses[client] = 0.0;
    
    g_nStrafeStartTick[client] = GetGameTickCount();
}

stock bool GetClientLandingPoint( float vecPos[3], float vecVel[3], bool bFront )
{
    // Starting and landing points are taken from the furthest point.
    // E.g, behind the player when starting and in front when landing.
    // This is the normal circle method which means it is not accurate to player's mins and maxs.
    // Check below for that.
    
    float length = SquareRoot( vecVel[0] * vecVel[0] + vecVel[1] * vecVel[1] );
    
    if ( length <= 0.0 ) return false;
    
    
    float vecOff[2];
    
    vecOff[0] = ( vecVel[0] / length ) * 16.0;
    vecOff[1] = ( vecVel[1] / length ) * 16.0;
    
    // Flip for the back.
    if ( !bFront )
    {
        vecOff[0] = -vecOff[0];
        vecOff[1] = -vecOff[1];
    }
    
    vecPos[0] += vecOff[0];
    vecPos[1] += vecOff[1];
    
    return true;
}

stock bool GetClientLandingPoint_True( float vecPos[3], const float vecVel[3], bool bFront )
{
    // NOTE: This will allow players to "cheat" by jumping in 45 degree angles and gaining ~14 units.
    // It would be correct, but not consistent and fair.
    // Used for block ljs for now.
    
    // Thanks to the people @ http://stackoverflow.com/questions/4061576/finding-points-on-a-rectangle-at-a-given-angle
    
    // First we have to rotate our vector by 90 degrees.
    /*
        X' = COSINE * X - SINE * Y
        Y' = SINE * X + COSINE * Y
    */
    
    if ( vecVel[0] == 0.0 && vecVel[1] == 0.0 ) return false;
    
    float cos;
    float sin;
    
    if ( bFront )
    {
        // In front of us
        cos = Cosine( DEG90_RAD );
        sin = Sine( DEG90_RAD );
    }
    else
    {
        // Behind us
        cos = Cosine( -DEG90_RAD );
        sin = Sine( -DEG90_RAD );
    }
    
    float theta = ArcTangent2(    cos * vecVel[0] - sin * vecVel[1],
                                sin * vecVel[0] + cos * vecVel[1] );
    
    float theta_tan = Tangent( theta );
    
    int region;
    
    if ( theta > -DEG45_RAD && theta <= DEG45_RAD )
    {
        region = 0;
    }
    else if ( theta > DEG45_RAD && theta <= (MATH_PI - DEG45_RAD) )
    {
        region = 1;
    }
    else if ( theta > (MATH_PI - DEG45_RAD) || theta <= -(MATH_PI - DEG45_RAD) )
    {
        region = 2;
    }
    else
    {
        region = 3;
    }
    
    float x_fac = 1.0;
    float y_fac = 1.0;
    
    switch ( region )
    {
        case 0 : y_fac = -1.0;
        case 1 : y_fac = -1.0;
        case 2 : x_fac = -1.0;
        case 3 : x_fac = -1.0;
    }
    
    if ( region == 0 || region == 2 )
    {
        vecPos[0] += x_fac * g_vecPlyMaxs[0];
        vecPos[1] += y_fac * g_vecPlyMaxs[0] * theta_tan;
    }
    else
    {
        vecPos[0] += x_fac * (32.0 / (2.0 * theta_tan));
        vecPos[1] += y_fac * g_vecPlyMaxs[0];
    }
    
    return true;
}

stock int GetJumpStyle( int flags )
{
    if ( flags & JUMPFLAG_BHOP ) return JUMPSTYLE_BUNNY;
    if ( flags & JUMPFLAG_WEIRD ) return JUMPSTYLE_WEIRD;
    
    return JUMPSTYLE_LJ;
}

stock float GetStyleMinPrestrafe( int style, bool bDucked = false )
{
    if ( bDucked ) return 80.0;
    
    switch ( style )
    {
        case JUMPSTYLE_BUNNY : return    250.0;
        case JUMPSTYLE_WEIRD : return    245.0;
        case JUMPSTYLE_LJ : return        240.0;
    }
    
    return 200.0;
}

stock float GetStyleMaxPrestrafe( int style )
{
    switch ( style )
    {
        case JUMPSTYLE_LJ : return      g_ConVar_Lj_MaxPreSpeed.FloatValue;
        case JUMPSTYLE_WEIRD : return   g_ConVar_Wj_MaxPreSpeed.FloatValue;
    }
    
    return 700.0;
}

stock float GetStyleMinDistance( int style, int stance )
{
    #define DISABLED_STYLE        1337.0
    
    switch ( stance )
    {
        case JUMPSTANCE_DUCKED :
        {
            // Ducked
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return   g_ConVar_MinDist_Bhop_Ducked.FloatValue;
                case JUMPSTYLE_WEIRD : return   g_ConVar_MinDist_Wj_Ducked.FloatValue;
                case JUMPSTYLE_LJ : return      g_ConVar_MinDist_Lj_Ducked.FloatValue;
                case JUMPSTYLE_LADDER : return  DISABLED_STYLE;
                case JUMPSTYLE_UP : return      DISABLED_STYLE;
            }
        }
        case JUMPSTANCE_STANDUP :
        {
            // Standup
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return   g_ConVar_MinDist_Bhop_Stand.FloatValue;
                case JUMPSTYLE_WEIRD : return   g_ConVar_MinDist_Wj_Stand.FloatValue;
                case JUMPSTYLE_LJ : return      g_ConVar_MinDist_Lj_Stand.FloatValue;
                case JUMPSTYLE_LADDER : return  g_ConVar_MinDist_Ladder_Stand.FloatValue;
                case JUMPSTYLE_UP : return      g_ConVar_MinDist_Up_Stand.FloatValue;
            }
        }
        default :
        {
            // Normal
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return   g_ConVar_MinDist_Bhop.FloatValue;
                case JUMPSTYLE_WEIRD : return   g_ConVar_MinDist_Wj.FloatValue;
                case JUMPSTYLE_LJ : return      g_ConVar_MinDist_Lj.FloatValue;
                case JUMPSTYLE_LADDER : return  g_ConVar_MinDist_Ladder.FloatValue;
                case JUMPSTYLE_UP : return      g_ConVar_MinDist_Up.FloatValue;
            }
        }
    }
    
    return 250.0;
}

stock void FormatStrafes( char[] sz, int len, int num, float sync, float time, float gains, float losses )
{
    //                    "XX   XXX%   XXXms   XXX.X   XXX.X"
    FormatEx( sz, len,    "%02i   %03.0f%%   %03.0fms   %04.1f   %04.1f",
        num,
        sync,
        time * 1000.0,
        gains,
        losses );
}

stock void FormatStrafeItem( char[] sz, int len, float avgtime, float avgsync )
{
    // "Avg: XXXms @ XXX%"
    FormatEx( sz, len, "Avg: %03.0fms @ %.1f%%", avgtime, avgsync );
}

stock void DisplayStats( int client, const int iJump[JMP_SIZE], ArrayList &hStrafes )
{
    // Structure our strafes into a string.
    static char szStrafes[500];
    strcopy( szStrafes, sizeof( szStrafes ), STRF_FORMAT..."\n " );
    
    char szStrafe[64];
    int iData[STRAFE_SIZE];
    for ( int i = 0; i < iJump[JMP_NUMSTRFS]; i++ )
    {
        hStrafes.GetArray( i, iData, view_as<int>( StrafeData ) );
        
        FormatStrafes( szStrafe, sizeof( szStrafe ),
            i + 1,
            iData[view_as<int>( STRF_SYNC )],
            iData[view_as<int>( STRF_TIME )],
            iData[view_as<int>( STRF_GAINS )],
            iData[view_as<int>( STRF_LOSSES )] );
        
        Format( szStrafes, sizeof( szStrafes ), "%s\n%s", szStrafes, szStrafe );
    }
    
    Format( szStrafes, sizeof( szStrafes ), "%s\n ", szStrafes );
    
    char szItem[32];
    FormatStrafeItem( szItem, sizeof( szItem ), view_as<float>( iJump[JMP_AVG_TIME] ), view_as<float>( iJump[JMP_AVG_SYNC] ) );
    
    
    char szJumps[32];
    FormatJumpName( szJumps, sizeof( szJumps ), iJump[JMP_STYLE], iJump[JMP_DIR], iJump[JMP_STANCE], false, true );
    
    
    char szMiscInfo[40];
    
    if ( iJump[JMP_BLOCK] )
    {
        // "(XXX block, XX.X edge)"
        
        // More than 32 units is useless or it has to be invalid.
        char szEdge[16];
        if ( view_as<float>( iJump[JMP_BLOCK_EDGE] ) < 32.0 )
        {
            FormatEx( szEdge, sizeof( szEdge ), ", %.1f edge", iJump[JMP_BLOCK_EDGE] );
        }
        
        FormatEx( szMiscInfo, sizeof( szMiscInfo ), "(%i block%s", iJump[JMP_BLOCK], szEdge );
    }
    else if ( iJump[JMP_STYLE] != JUMPSTYLE_LADDER )
    {
        // "(true: XXX.XXX)"
        FormatEx( szMiscInfo, sizeof( szMiscInfo ), "(true: %.3f", iJump[JMP_DIST_TRUE] );
    }
    
    if ( iJump[JMP_STYLE] == JUMPSTYLE_UP || iJump[JMP_STYLE] == JUMPSTYLE_WEIRD )
    {
        Format( szMiscInfo, sizeof( szMiscInfo ), "%s, height: %.1f",
            szMiscInfo,
            iJump[JMP_MISCDATA1] );
    }
    
    
    // Lines requires something. A new line cannot be right after another new line.
    if ( szMiscInfo[0] == '\0' )
    {
        strcopy( szMiscInfo, sizeof( szMiscInfo ), " " );
    }
    else
    {
        Format( szMiscInfo, sizeof( szMiscInfo ), "%s)", szMiscInfo );
    }
    
    bool invalidblockjump = (    (iJump[JMP_RESULTFLAGS] & RESULT_PB_BLOCK || iJump[JMP_RESULTFLAGS] & RESULT_PB_DIST)
                            &&    iJump[JMP_RESULTFLAGS] & RESULT_NONMARKED_BLOCK
                            &&    !(iJump[JMP_RESULTFLAGS] & RESULT_SAVED) );
    
    static char szHint[150];
    
    if ( GetUserMessageType() == UM_Protobuf )
    {
        // "BW Ducked Ladderjump (Failed) | ~XXX.XXX unitsC(XXX block, XX.X edge, height: XX.X)CPrespeed: XXX.X | Max speed: XXX.X"
        FormatEx( szHint, sizeof( szHint ), "%s%s%s | %s%.3f units\n%s\nPrespeed: %.1f | Max speed: %.1f",
            szJumps,
            ( iJump[JMP_RESULTFLAGS] & RESULT_FAILED ) ? " (Failed)" : "",
            invalidblockjump ? " (X)" : "",
            ( iJump[JMP_RESULTFLAGS] & RESULT_FAILED ) ? "~" : "",
            iJump[JMP_DIST],
            szMiscInfo,
            iJump[JMP_PRESPD],
            iJump[JMP_TOPSPD] );
    }
    else
    {
        // "BW Ducked Ladderjump (Failed)C~XXX.XXX unitsC(XXX block, XX.X edge, height: XX.X)CPrespeed: XXX.XCMax speed: XXX.XC CStrafes: XXCSync: XX.X pct."
        FormatEx( szHint, sizeof( szHint ), "%s%s%s\n%s%.3f units\n%s\nPrespeed: %.1f\nMax speed: %.1f\n \nStrafes: %i\nSync: %.1f pct.",
            szJumps,
            ( iJump[JMP_RESULTFLAGS] & RESULT_FAILED ) ? " (Failed)" : "",
            invalidblockjump ? " (X)" : "",
            ( iJump[JMP_RESULTFLAGS] & RESULT_FAILED ) ? "~" : "",
            iJump[JMP_DIST],
            szMiscInfo,
            iJump[JMP_PRESPD],
            iJump[JMP_TOPSPD],
            iJump[JMP_NUMSTRFS],
            iJump[JMP_AVG_SYNC] );
    }
    
    
    char szName[MAX_NAME_LENGTH];
    GetClientName( client, szName, sizeof( szName ) );
    
    
    static char szConsole[150];
    // " (Failed)C~XXX.XXX units (XXX block, XX.X edge, height: XX.X)CPrespeed: XXX.XCMax speed: XXX.XCCStrafes: XXCAvg Sync: %.1f%CAvg Time: XXXms"
    FormatEx( szConsole, sizeof( szConsole ), "%s%s\n%s%.3f %s\nPrespeed: %.1f\nMax speed: %.1f\n\nStrafes: %i\nAvg Sync: %.1f%%\nAvg Time: %03.0fms",
        ( iJump[JMP_RESULTFLAGS] & RESULT_FAILED ) ? " (Failed)" : "",
        invalidblockjump ? " (X)" : "",
        ( iJump[JMP_RESULTFLAGS] & RESULT_FAILED ) ? "~" : "",
        iJump[JMP_DIST],
        szMiscInfo,
        iJump[JMP_PRESPD],
        iJump[JMP_TOPSPD],
        iJump[JMP_NUMSTRFS],
        iJump[JMP_AVG_SYNC],
        iJump[JMP_AVG_TIME] );
    
    
    // Displays also to spectators.
    bool bDisplay;
    bool bDisplayConsole;
    int hideflags;
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
        
        
        if (client == i
        ||    (client != i && !IsPlayerAlive( i ) && GetClientObserverTarget( i ) == client) )
        {
            bDisplay = true;
            bDisplayConsole = true;
            
            // Check if target wants them printed.
            if ( g_bLibrary_Hud )
            {
                hideflags = Standup_GetClientHideFlags( i );
                
                if ( hideflags & HIDEFLAG_STATS ) bDisplay = false;
                if ( hideflags & HIDEFLAG_STATS_CON ) bDisplayConsole = false;
            }
            
            if ( bDisplay )
            {
                if ( g_ConVar_StrafeMenuTime.IntValue != 0 )
                {
                    Menu mMenu = new Menu( Handler_Empty );
                    
                    mMenu.SetTitle( "%s", szStrafes );
                    mMenu.AddItem( "", szItem );
                    mMenu.ExitButton = false;
                    
                    mMenu.Display( i, g_ConVar_StrafeMenuTime.IntValue );
                }
                
                if ( g_ConVar_HintTime.FloatValue != 0.0 )
                {
                    PrintHintText( i, szHint );
                    
                    // Minimum time to draw the lj text for.
                    g_flNextHintTime[i] = g_flCurTime + g_ConVar_HintTime.FloatValue;
                }
            }
            
            if ( bDisplayConsole )
            {
                PrintToConsole( i, "---------------------------\n%s\n\n%s%s\n\n%s", szName, szJumps, szConsole, szStrafes );
            }
        }
    }
}

public int Handler_Empty( Menu mMenu, MenuAction action, int client, int item )
{
    if ( action == MenuAction_End ) delete mMenu;
    
    return 0;
}

public int Handler_DisplayRecords_GotoJumpData( Menu mMenu, MenuAction action, int client, int index )
{
    if ( action == MenuAction_End ) { delete mMenu; return 0; }
    if ( action != MenuAction_Select ) return 0;
    
    
    char szInfo[64];
    if ( !GetMenuItem( mMenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    char szBuffer[5][6];
    
    if ( ExplodeString( szInfo, "_", szBuffer, sizeof( szBuffer ), sizeof( szBuffer[] ) ) < 5 )
        return 0;
    
    int uid = StringToInt( szBuffer[0] );
    int style = StringToInt( szBuffer[1] );
    int dir = StringToInt( szBuffer[2] );
    int stance = StringToInt( szBuffer[3] );
    int block = StringToInt( szBuffer[4] );
    
    if ( !IS_STYLE_LEGIT( style ) ) return 0;
    if ( !IS_DIR( dir ) ) return 0;
    if ( !IS_STANCE( stance ) ) return 0;
    
    if ( uid )
    {
#if defined DEBUG
        PrintToServer( SU_PRE_DEV..."Searching for jump data: (%i, %i, %i, %i, %i)", uid, style, dir, stance, block );
#endif
        DB_DisplayJumpData( client, uid, style, dir, stance, block );
    }
    
    return 0;
}

public int Handler_DisplayRecords_GotoStrafeData( Menu mMenu, MenuAction action, int client, int index )
{
    if ( action == MenuAction_End ) { delete mMenu; return 0; }
    if ( action != MenuAction_Select ) return 0;
    
    
    char szInfo[64];
    if ( !GetMenuItem( mMenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    char szBuffer[6][6];
    
    if ( ExplodeString( szInfo, "_", szBuffer, sizeof( szBuffer ), sizeof( szBuffer[] ) ) < 6 )
        return 0;
    
    
    int uid = StringToInt( szBuffer[0] );
    int style = StringToInt( szBuffer[1] );
    int dir = StringToInt( szBuffer[2] );
    int stance = StringToInt( szBuffer[3] );
    int block = StringToInt( szBuffer[4] );
    int numstrfs = StringToInt( szBuffer[5] );
    
    if ( !IS_STYLE_LEGIT( style ) ) return 0;
    if ( !IS_DIR( dir ) ) return 0;
    if ( !IS_STANCE( stance ) ) return 0;
    
    
    if ( uid > 0 )
    {
        if ( index == 1 && GetAdminFlags( GetUserAdmin( client ), Access_Real ) & ADMFLAG_SU_LVL3 )
        {
            LogAction( client, -1, SU_PRE_CLEAR..."Deleting longjump record! (%i, %i, %i, %i, %i)", uid, style, dir, stance, block );
            
            DB_DeleteJumpRecord( uid, style, dir, stance, block );
        }
        else if ( numstrfs > 0 )
        {
#if defined DEBUG
            PrintToServer( SU_PRE_DEV..."Searching for strafe data: (%i, %i, %i, %i, %i)", uid, style, dir, stance, block );
#endif
            
            DB_DisplayStrafeData( client, uid, style, dir, stance, block, numstrfs );
        }
    }
    
    return 0;
}

public int Handler_GotoBlock( Menu mMenu, MenuAction action, int client, int index )
{
    if ( action == MenuAction_End ) { delete mMenu; return 0; }
    if ( action != MenuAction_Select ) return 0;
    
    if ( !IsPlayerAlive( client ) ) return 0;
    
    
    char szInfo[16];
    if ( !GetMenuItem( mMenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    char szBuffer[2][5];
    if ( ExplodeString( szInfo, "_", szBuffer, sizeof( szBuffer ), sizeof( szBuffer[] ) ) < 2 )
    {
        return 0;
    }
    
    
    int i = StringToInt( szBuffer[0] );
    int dist = StringToInt( szBuffer[1] );
    
    int len = GetArrayLength_Safe( g_hBlocks );
    
    if ( i < 0 || i >= len || g_hBlocks.Get( i, view_as<int>( ZONE_BLOCK ) ) != dist ) return 0;
    
    
    TeleportPlayerToBlock( client, i );
    
    return 0;
}

stock int CheckBlocks()
{
    int len = GetArrayLength_Safe( g_hBlocks );
    
    int num;
    
    for ( int i = 0; i < len; i++ )
    {
        if ( EntRefToEntIndex( g_hBlocks.Get( i, view_as<int>( ZONE_ENTREF ) ) ) < 1 )
        {
            CreateZoneEntity( i );
            
            num++;
        }
    }
    
#if defined DEBUG
    PrintToServer( SU_PRE_CLEAR..."Respawned %i block zones.", num );
#endif
    
    return num;
}

stock bool CheckCheating( int client, int fFlags, MoveType movetype )
{
    // Base velocity is the velocity applied by outside sources. (trigger_push, etc.)
    static float vecTemp[3];
    GetEntPropVector( client, Prop_Data, "m_vecBaseVelocity", vecTemp );
    
    if (
            vecTemp[0] > MAX_BASEVELOCITY || vecTemp[0] < -MAX_BASEVELOCITY
        ||    vecTemp[1] > MAX_BASEVELOCITY || vecTemp[1] < -MAX_BASEVELOCITY
        ||    vecTemp[2] > MAX_BASEVELOCITY || vecTemp[2] < -MAX_BASEVELOCITY )
    {
        MarkAsCheated( client, CHEATSTATE_BASEVEL );
        return true;
    }
    
    
    if ( GetEntProp( client, Prop_Send, "m_nWaterLevel" ) > 1 )
    {
        MarkAsCheated( client, CHEATSTATE_WATER );
        return true;
    }
    
    
    if ( movetype != MOVETYPE_WALK )
    {
        if ( movetype == MOVETYPE_LADDER )
        {
            g_iCheatState[client] = CHEATSTATE_LADDER;
        }
        else
        {
            MarkAsCheated( client, CHEATSTATE_MOVETYPE );
        }
        
        return true;
    }
    
    
    if ( fFlags & FL_ONGROUND || !IsClientInValidJump( client ) )
        return false;
    
    
    // Trace down to check for invalid surfaces.
    static float vecStart[3];
    GetClientAbsOrigin( client, vecStart );
    
    vecTemp[0] = vecStart[0];
    vecTemp[1] = vecStart[1];
    vecTemp[2] = vecStart[2] - 4.0;
    
    vecStart[2] += 4.0; // Start a bit higher.
    
    
    if ( DoPlayerTrace( vecStart, vecTemp ) )
    {
        TR_GetPlaneNormal( null, vecTemp );
        
        // Anything less than 0.4-0.45 is surfable, cannot remember exactly.
        if ( vecTemp[2] != 1.0 && vecTemp[2] != 0.0 )
        {
            MarkAsCheated( client, CHEATSTATE_SURF );
            
            if ( (g_flCurTime - g_flLastJumpTime[client]) > 0.2 )
            {
                SU_PrintToChat( client, client, SU_PRE_CHAT..."Invalid surface detected!" );
            }
            
            return true;
        }
    }
    
    return false;
}

stock bool DoPlayerTraceDown( const float vec[3] )
{
    float vec1[3], vec2[3];
    
    vec1[0] = vec[0];
    vec1[1] = vec[1];
    vec1[2] = vec[2] + 4.0;
    
    vec2[0] = vec[0];
    vec2[1] = vec[1];
    vec2[2] = vec[2] - 4.0;
    
    
    return DoPlayerTrace( vec1, vec2 );
}

stock bool DoPlayerTrace( const float vecStart[3], const float vecEnd[3] )
{
    TR_TraceHullFilter( vecStart, vecEnd, g_vecPlyMins, g_vecPlyMaxs, MASK_PLAYERSOLID, TraceFilter_GroundOnly );
    
    return TR_DidHit();
}

public bool TraceFilter_GroundOnly( int ent, int mask )
{
    return !IS_ENT_PLAYER( ent );
}

stock void MarkAsCheated( int client, int state )
{
    g_iCheatState[client] = state;
    g_flLastCheatTime[client] = g_flCurTime;
    
    g_fJumpFlags[client] = JUMPFLAG_INVALID;
}

stock void ResetClientStrafes( int client )
{
    if ( g_hCurStrafes[client] != null )
    {
        delete g_hCurStrafes[client];
    }
    
    g_hCurStrafes[client] = new ArrayList( view_as<int>( StrafeData ) );
    
    if ( g_hFailedStrafes[client] != null )
    {
        delete g_hFailedStrafes[client];
        g_hFailedStrafes[client] = null;
    }
}

stock int GetJumpDir( int client )
{
    int dir_best = JUMPDIR_FWD;
    int dir_best_amt;
    
    for ( int i = 0; i < NUM_JUMPDIR; i++ )
        if ( g_nDirection[client][i] > dir_best_amt )
        {
            dir_best = i;
            dir_best_amt = g_nDirection[client][i];
        }
    
    
    // Check just in case.
    if ( dir_best == JUMPDIR_SW )
    {
        if ( g_nKeyPresses[client][KEY_MOVELEFT] && g_nKeyPresses[client][KEY_MOVERIGHT] )
        {
            dir_best = JUMPDIR_FWD;
        }
    }
    
    return dir_best;
}

stock void CheckJumpDirection( int client, float vel[3], float yaw )
{
    // Give 20 degree cap.
    float angle = GetAngleToVelocity( vel, yaw );
    
    if ( angle < 20.0 && angle > -20.0 )
    {
        g_nDirection[client][JUMPDIR_FWD]++;
    }
    else if ( angle > 160.0 || angle < -160.0 )
    {
        g_nDirection[client][JUMPDIR_BWD]++;
    }
    else if ( (angle > 70.0 && angle < 110.0) || (angle < -70.0 && angle > -110.0) )
    {
        g_nDirection[client][JUMPDIR_SW]++;
    }
    
#if defined DEBUG_STRF_ANGLES
    PrintToServer( SU_PRE_DEV..."Strafe Angle: %.1f", angle );
#endif
}

stock float GetAngleToVelocity( float vel[3], float yaw )
{
    // First convert the yaw to radians then convert that to a vector.
    yaw = DegToRad( yaw );
    
    float vecDir[3];
    vecDir[0] = Cosine( yaw );
    vecDir[1] = Sine( yaw );
    
    // Get the angle between our velocity vector and yaw vector.
    return RadToDeg( GetVectorsAngle( vel, vecDir ) );
}

stock bool HasPressedMultiple( const int keypresses[NUM_KEYS] )
{
    // Has pressed one or none at all.
    bool bHasPressed;
    
    for ( int i = 0; i < NUM_KEYS; i++ )
    {
        if ( keypresses[i] )
        {
            if ( bHasPressed ) return true;
            
            bHasPressed = true;
        }
    }
    
    return false;
}

stock int GetClientStrafe( int client, const float curvel[3] )
{
    float delta;
    
    if ( g_iLastStrafe[client] != STRAFE_INVALID )
    {
        delta = GetVectorsAngle( g_vecLastAirVel[client], curvel );
    }
    else
    {
        delta = GetVectorsAngle( g_vecJumpStartVel[client], curvel );
    }
    
#if defined DEBUG_STRF_DELTA
    PrintToServer( SU_PRE_DEV..."Strafe delta: %.6f", delta );
#endif
    
    if ( delta == 0.0 )
    {
        return g_iLastStrafe[client];
    }
    else
    {
        return ( delta > 0.0 ) ? STRAFE_LEFT : STRAFE_RIGHT;
    }
}

stock bool IsValidGrounding( float start, float end )
{
    float flDif = start - end;
    
#if defined DEBUG
    PrintToServer( SU_PRE_DEV..."Grounding dif: %.1f (%s)", flDif, ( flDif <= MAX_LJ_Z_DIF && flDif >= -MAX_LJ_Z_DIF ) ? "Valid" : "Invalid" );
#endif
    
    return ( flDif <= MAX_LJ_Z_DIF && flDif >= -MAX_LJ_Z_DIF );
}

#if defined DEBUG
    stock void Debug_DrawPoint( int client, float vecPos[3], const int clr[4] )
    {
        float vecTemp[3];
        
        vecTemp[0] = vecPos[0];
        vecTemp[1] = vecPos[1];
        vecTemp[2] = vecPos[2] + 32.0;
        
        TE_SetupBeamPoints( vecPos, vecTemp, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, 1.0, 1.0, 0, 0.0, clr, 0 );
        TE_SendToClient( client, 0.0 );
    }
#endif

stock float GetPlayerMaxSpeed( int client )
{
#if defined DEBUG
    PrintToServer( SU_PRE_DEV..."GetPlayerMaxSpeed(%i): %.1f",
        client,
        ( g_hFunc_GetPlayerMaxSpeed != null ) ? SDKCall( g_hFunc_GetPlayerMaxSpeed, client ) : -1.0 );
#endif
    
    return ( g_hFunc_GetPlayerMaxSpeed != null ) ? SDKCall( g_hFunc_GetPlayerMaxSpeed, client ) : VALID_WEP_SPD;
}

stock int GetTriggerIndex( int ent )
{
    return GetEntProp( ent, Prop_Data, "m_iHealth" );
}

stock int SetTriggerIndex( int ent, int index )
{
    SetEntProp( ent, Prop_Data, "m_iHealth", index );
}

stock int FindBlock( const float vecPos[3], int startindex = -1 )
{
    int iData[ZONE_SIZE];
    float vecMins[3];
    float vecMaxs[3];
    
    startindex++;
    
    int len = GetArrayLength_Safe( g_hBlocks );
    for ( int i = startindex; i < len; i ++ )
    {
        g_hBlocks.GetArray( i, iData, view_as<int>( ZoneData ) );
        
        CopyArray( iData[ZONE_MINS], vecMins, 3 );
        CopyArray( iData[ZONE_MAXS], vecMaxs, 3 );
        
        if ( IsInsideBounds_Draw( vecPos, vecMins, vecMaxs ) )
        {
            return i;
        }
    }
    
    return -1;
}

stock bool IsSameBlocks( int index1, int index2 )
{
    int len = GetArrayLength_Safe( g_hBlocks );
    
    if ( (index1 < 0 || index1 <= len) || (index2 < 0 || index2 <= len) )
        return false;
    
    return ( g_hBlocks.Get( index1, view_as<int>( ZONE_BLOCK ) ) == g_hBlocks.Get( index2, view_as<int>( ZONE_BLOCK ) ) );
}

stock bool IsInsideBounds_Draw( const float vecPos[3], const float vecMins[3], const float vecMaxs[3] )
{
#if defined DEBUG
    float vecBeam1[3];
    float vecBeam2[3];
    float vecBeam3[3];
    float vecBeam4[3];
    float vecBeam5[3];
    float vecBeam6[3];
    float vecBeam7[3];
    float vecBeam8[3];
    
    // Bottom
    vecBeam1 = vecMins;
    
    vecBeam2[0] = vecMins[0];
    vecBeam2[1] = vecMaxs[1];
    vecBeam2[2] = vecMins[2];
    
    vecBeam3[0] = vecMaxs[0];
    vecBeam3[1] = vecMaxs[1];
    vecBeam3[2] = vecMins[2];
    
    vecBeam4[0] = vecMaxs[0];
    vecBeam4[1] = vecMins[1];
    vecBeam4[2] = vecMins[2];
    
    // Top
    vecBeam5[0] = vecMins[0];
    vecBeam5[1] = vecMins[1];
    vecBeam5[2] = vecMaxs[2];
    
    vecBeam6[0] = vecMins[0];
    vecBeam6[1] = vecMaxs[1];
    vecBeam6[2] = vecMaxs[2];
    
    vecBeam7 = vecMaxs;
    
    vecBeam8[0] = vecMaxs[0];
    vecBeam8[1] = vecMins[1];
    vecBeam8[2] = vecMaxs[2];
    
    
    // Bottom
    TE_SetupBeamPoints( vecBeam1, vecBeam2, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( vecBeam2, vecBeam3, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( vecBeam3, vecBeam4, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( vecBeam4, vecBeam1, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    
    // Top
    TE_SetupBeamPoints( vecBeam5, vecBeam6, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( vecBeam6, vecBeam7, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( vecBeam7, vecBeam8, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( vecBeam8, vecBeam5, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    
    // Connect from bottom to top.
    TE_SetupBeamPoints( vecBeam1, vecBeam5, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( vecBeam2, vecBeam6, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( vecBeam3, vecBeam7, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( vecBeam4, vecBeam8, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToAll( 0.0 );
    
    
    float vecPos2[3];
    vecPos2 = vecPos;
    vecPos2[2] += 4.0;
    
    TE_SetupBeamPoints( vecPos, vecPos2, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrRed, 0 );
    TE_SendToAll( 0.0 );
#endif
    
    return IsInsideBounds_Draw( vecPos, vecMins, vecMaxs );
}

stock bool IsInsideBounds_Draw_PlayerMinsMaxs( float vecPos[3], float vecBoundMins[3], float vecBoundMaxs[3] )
{
    // Kinda hacky way of checking it but one of the bounds should always be in it.
    float vecMins[3];
    float vecMaxs[3];
    
    // Ignore z-axis.
    vecMins[0] = vecPos[0] + g_vecPlyMins[0];
    vecMins[1] = vecPos[1] + g_vecPlyMins[1];
    vecMins[2] = vecPos[2] + 8.0;
    
    vecMaxs[0] = vecPos[0] + g_vecPlyMaxs[0];
    vecMaxs[1] = vecPos[1] + g_vecPlyMaxs[1];
    vecMaxs[2] = vecPos[2] + 8.0;
    
    return ( IsInsideBounds_Draw( vecMins, vecBoundMins, vecBoundMaxs ) || IsInsideBounds_Draw( vecMaxs, vecBoundMins, vecBoundMaxs ) );
}

stock void DrawClientBB_Pos( int client, const float vecPos[3] )
{
    float vecTemp1[3];
    float vecTemp2[3];
    
    vecTemp1[2] = vecPos[2];
    vecTemp2[2] = vecPos[2];
    
    // Then our mins-maxs lines.
    vecTemp1[0] = vecPos[0] + 16.0;
    vecTemp1[1] = vecPos[1] + 16.0;
    vecTemp2[0] = vecPos[0] + 16.0;
    vecTemp2[1] = vecPos[1] - 16.0;
    TE_SetupBeamPoints( vecTemp1, vecTemp2, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrRed, 0 );
    TE_SendToClient( client, 0.0 );
    
    vecTemp1[0] = vecPos[0] + 16.0;
    vecTemp1[1] = vecPos[1] - 16.0;
    vecTemp2[0] = vecPos[0] - 16.0;
    vecTemp2[1] = vecPos[1] - 16.0;
    TE_SetupBeamPoints( vecTemp1, vecTemp2, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrRed, 0 );
    TE_SendToClient( client, 0.0 );
    
    vecTemp1[0] = vecPos[0] - 16.0;
    vecTemp1[1] = vecPos[1] - 16.0;
    vecTemp2[0] = vecPos[0] - 16.0;
    vecTemp2[1] = vecPos[1] + 16.0;
    TE_SetupBeamPoints( vecTemp1, vecTemp2, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrRed, 0 );
    TE_SendToClient( client, 0.0 );
    
    vecTemp1[0] = vecPos[0] - 16.0;
    vecTemp1[1] = vecPos[1] + 16.0;
    vecTemp2[0] = vecPos[0] + 16.0;
    vecTemp2[1] = vecPos[1] + 16.0;
    TE_SetupBeamPoints( vecTemp1, vecTemp2, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrRed, 0 );
    TE_SendToClient( client, 0.0 );
}

stock void DrawClientBB( int client )
{
    float vecPos[3];
    GetClientAbsOrigin( client, vecPos );
    
    DrawClientBB_Pos( client, vecPos );
}

stock int InsertNewBlock( int dist = 0, int opp_entref = -1, const float vecMins[3], const float vecMaxs[3], bool bStart = false, BlockDir dir = BLOCKDIR_INVALID )
{
#if defined DEBUG
    PrintToServer( SU_PRE_DEV..."Inserting block %i (end: %i)!", dist, bStart );
#endif
    
    int iData[ZONE_SIZE];
    
    iData[ZONE_BLOCK] = dist;
    iData[ZONE_OPP_ENTREF] = opp_entref;
    iData[ZONE_ISSTART] = bStart;
    iData[ZONE_DIR] = dir;
    
    CopyArray( vecMins, iData[ZONE_MINS], 3 );
    CopyArray( vecMaxs, iData[ZONE_MAXS], 3 );
    
    return g_hBlocks.PushArray( iData, view_as<int>( ZoneData ) );
}

stock int CreateZoneEntity( int index )
{
    if ( index < 0 || index >= GetArrayLength_Safe( g_hBlocks ) )
        return -1;
    
    
    int iData[ZONE_SIZE];
    g_hBlocks.GetArray( index, iData, view_as<int>( ZoneData ) );
    
    float vecMins[3];
    float vecMaxs[3];
    CopyArray( iData[ZONE_MINS], vecMins, 3 );
    CopyArray( iData[ZONE_MAXS], vecMaxs, 3 );
    
    int ent = CreateTrigger( vecMins, vecMaxs );
    if ( ent > 0 )
    {
        SetTriggerIndex( ent, index );
        g_hBlocks.Set( index, EntIndexToEntRef( ent ), view_as<int>( ZONE_ENTREF ) );
        
        SDKHook( ent, SDKHook_StartTouchPost, Event_StartTouchPost_Block );
        SDKHook( ent, SDKHook_EndTouchPost, Event_EndTouchPost_Block );
        
        return ent;
    }
    
    return -1;
}

stock bool IsSpammingCommand( int client, float time = 1.0 )
{
    if ( g_flSpam[client] > g_flCurTime )
    {
        SU_PrintToChat( client, client, SU_PRE_CHAT..."Please wait before using this command, thanks." );
        return true;
    }
    
    g_flSpam[client] = g_flCurTime + time;
    
    return false;
}

public void Event_StartTouchPost_Block( int trigger, int ent )
{
    if ( IS_ENT_PLAYER( ent ) )
    {
#if defined DEBUG
        PrintToServer( SU_PRE_DEV..."StartTouchPost( %i, %i )", trigger, ent );
#endif
        
        g_flLastBlockStartTouch[ent] = g_flCurTime;
        g_iStartTouchBlock[ent] = CheckBlock( trigger );
    }
}

public void Event_EndTouchPost_Block( int trigger, int ent )
{
    if ( IS_ENT_PLAYER( ent ) )
    {
#if defined DEBUG
        PrintToServer( SU_PRE_DEV..."EndTouchPost( %i, %i )", trigger, ent );
#endif
        
        g_flLastBlockEndTouch[ent] = g_flCurTime;
        g_iEndTouchBlock[ent] = CheckBlock( trigger );
    }
}

stock int CheckBlock( int trigger )
{
    int blockindex = GetTriggerIndex( trigger );
    
    if (    blockindex >= GetArrayLength_Safe( g_hBlocks )
        ||    blockindex < 0
        ||    trigger != EntRefToEntIndex( g_hBlocks.Get( blockindex, view_as<int>( ZONE_ENTREF ) ) ) )
    {
        LogError( SU_PRE_CLEAR..."Invalid block entity index!" );
        return -1;
    }
    
    return blockindex;
}

stock int GetJumpBlock( const float vecStart[3], const float vecEnd[3], const float vecStart_Landing[3], const float vecEnd_Landing[3], float &return_dist, float &block_edge )
{
    // Create a unit vector.
    float vecDir[2];
    int i;
    
    for ( i = 0; i < 2; i++ )
        vecDir[i] = vecEnd[i] - vecStart[i];
    
    
    float len = SquareRoot( vecDir[0] * vecDir[0] + vecDir[1] * vecDir[1] );
    
    vecDir[0] /= len;
    vecDir[1] /= len;
    
    
    // Construct a vector that is in the middle of the jump.
    float vec[3];
    
    for ( i = 0; i < 2; i++ )
        vec[i] = vecStart[i] + vecDir[i] * ( len / 2.0 );
    
    vec[2] = vecStart[2] - 3.0;
    
    
    if ( TR_PointOutsideWorld( vec ) ) return 0;
    
    if ( IsValidGrounding( vecEnd[2], vec[2] ) )
    {
        return 0;
    }
    
    // Now trace both sides from the midpoint to get the start-end positions. Make sure the surface normal is valid.
    float ang[3], vec1[3], normal[3];
    
    BlockDir dir = YawToBlockDir( VectorToAngle( vecDir[0], vecDir[1] ) );
    
    
    ang[1] = GetBlockDirAngle( dir );
    
    TR_TraceRayFilter( vec, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_GroundOnly );
    
    TR_GetPlaneNormal( null, normal );
    if ( !IsValidSurfaceNormal( normal ) ) return 0;
    
    
    TR_GetEndPosition( vec1 );
    
    
    float vec2[3];
    
    ang[1] = GetBlockDirAngle( GetOppBlockDir( dir ) );
    
    TR_TraceRayFilter( vec, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_GroundOnly );
    
    TR_GetPlaneNormal( null, normal );
    if ( !IsValidSurfaceNormal( normal ) ) return 0;
    
    TR_GetEndPosition( vec2 );
    
#if defined DEBUG
    TE_SetupBeamPoints( vec1, vec2, g_iBeamMat, 0, 0, 0, DEBUGLINE_DRAW_TIME, DEBUGLINE_WIDTH, DEBUGLINE_WIDTH, 0, 0.0, g_clrRed, 0 );
    TE_SendToAll( 0.0 );
#endif
    
    
    vec1[2] = 0.0;
    vec2[2] = 0.0;
    
    float dist = GetVectorDistance( vec1, vec2, false );
    
    if ( RoundFloat( dist ) > BLOCK_MAX ) return 0;
    
    if ( RoundFloat( dist ) < BLOCK_MIN ) return 0;
    
    
    // Round the vector, since traces are imperfect.
    vec2[0] = float( RoundFloat( vec2[0] ) );
    vec2[1] = float( RoundFloat( vec2[1] ) );
    
    switch ( dir )
    {
        case BLOCKDIR_RIGHT :
        {
            return_dist = vecEnd_Landing[0] - vecStart_Landing[0];
            
            block_edge = vec2[0] - vecStart_Landing[0];
        }
        case BLOCKDIR_FWD :
        {
            return_dist = vecEnd_Landing[1] - vecStart_Landing[1];
            
            block_edge = vec2[1] - vecStart_Landing[1];
        }
        case BLOCKDIR_LEFT :
        {
            return_dist = vecStart_Landing[0] - vecEnd_Landing[0];
            
            block_edge = vecStart_Landing[0] - vec2[0];
        }
        case BLOCKDIR_BWD :
        {
            return_dist = vecStart_Landing[1] - vecEnd_Landing[1];
            
            block_edge = vecStart_Landing[1] - vec2[1];
        }
    }
    
    return RoundFloat( dist );
}

stock bool IsValidSurfaceNormal( const float normal[3] )
{
    // A ramp.
    if ( normal[2] != 0.0 ) return false;
    
    // Don't count slanted walls!
    if ( normal[0] != 0.0 && normal[0] != 1.0 ) return false;
    if ( normal[1] != 0.0 && normal[1] != 1.0 ) return false;
    
    return true;
}

stock void RoundVector( float vec[3] )
{
    vec[0] = float( RoundFloat( vec[0] ) );
    vec[1] = float( RoundFloat( vec[1] ) );
    vec[2] = float( RoundFloat( vec[2] ) );
}

enum
{
    RECORDTYPE_INVALID = -1,
    RECORDTYPE_STYLE,
    RECORDTYPE_DIR,
    RECORDTYPE_STANCE,
    RECORDTYPE_BLOCKONLY
};

stock void ParseRecordArgs( int client, int args, int uid = 0, int target = 0, int maxrecords = DEF_MAX_RECORDS_QUERY )
{
    char szArg[12];
    
    int style = JUMPSTYLE_LJ;
    int dir = JUMPDIR_INVALID;
    int stance = JUMPSTANCE_INVALID;
    bool bBlockOnly = false;
    
    int num;
    
    if ( args > 3 )
        args = 3;
    
    for ( int i = 1; i <= args; i++ )
    {
        GetCmdArg( i, szArg, sizeof( szArg ) );
        
        switch ( ParseArg( num, szArg ) )
        {
            case RECORDTYPE_STYLE : style = num;
            case RECORDTYPE_DIR : dir = num;
            case RECORDTYPE_STANCE : stance = num;
            case RECORDTYPE_BLOCKONLY : bBlockOnly = true;
            default :
            {
                SU_PrintToChat( client, client, SU_PRE_CHAT..."Invalid argument: '%s'", szArg );
            }
        }
    }
    
    if ( style == JUMPSTYLE_LADDER || style == JUMPSTYLE_WEIRD )
    {
        bBlockOnly = false;
    }
    
    DB_DisplayRecords( client, bBlockOnly, style, dir, stance, uid, target, _, _, maxrecords );
}

stock int ParseArg( int &type, const char[] szArg )
{
    // Styles
    if ( StrEqual( szArg, "lj", false ) || StrEqual( szArg, "longjump", false ) )
    {
        type = JUMPSTYLE_LJ;
        return RECORDTYPE_STYLE;
    }
    if ( StrEqual( szArg, "bhop", false ) || StrEqual( szArg, "bunnyhop", false ) || StrEqual( szArg, "b", false ) )
    {
        type = JUMPSTYLE_BUNNY;
        return RECORDTYPE_STYLE;
    }
    if ( StrEqual( szArg, "wj", false ) || StrEqual( szArg, "weird", false ) || StrEqual( szArg, "weirdjump", false ) )
    {
        type = JUMPSTYLE_WEIRD;
        return RECORDTYPE_STYLE;
    }
    if ( StrEqual( szArg, "laj", false ) || StrEqual( szArg, "la", false ) || StrEqual( szArg, "ladder", false ) || StrEqual( szArg, "ladderjump", false ) )
    {
        type = JUMPSTYLE_LADDER;
        return RECORDTYPE_STYLE;
    }
    // Directions
    if ( StrEqual( szArg, "fwd", false ) || StrEqual( szArg, "forward", false ) || StrEqual( szArg, "normal", false ) )
    {
        type = JUMPDIR_FWD;
        return RECORDTYPE_DIR;
    }
    if ( StrEqual( szArg, "bw", false ) || StrEqual( szArg, "backward", false ) || StrEqual( szArg, "backwards", false ) )
    {
        type = JUMPDIR_BWD;
        return RECORDTYPE_DIR;
    }
    if ( StrEqual( szArg, "sw", false ) || StrEqual( szArg, "sideways", false ) )
    {
        type = JUMPDIR_SW;
        return RECORDTYPE_DIR;
    }
    // Stances
    if ( StrEqual( szArg, "d", false ) || StrEqual( szArg, "duck", false ) || StrEqual( szArg, "ducked", false ) || StrEqual( szArg, "crouch", false ) || StrEqual( szArg, "crouched", false ) )
    {
        type = JUMPSTANCE_DUCKED;
        return RECORDTYPE_STANCE;
    }
    if ( StrEqual( szArg, "stand", false ) )
    {
        type = JUMPSTANCE_STANDUP;
        return RECORDTYPE_STANCE;
    }
    
    if ( StrEqual( szArg, "block", false ) || StrEqual( szArg, "blockjump", false ) )
    {
        return RECORDTYPE_BLOCKONLY;
    }
    
    return RECORDTYPE_INVALID;
}

/*stock bool HasSubString( const char[] sz, const char[] szSub )
{
    return ( StrContains( sz, szSub, false ) != -1 );
}*/

stock bool CreateEndZone( int startindex, int block, const float vecMins[3], const float vecMaxs[3], BlockDir dir )
{
    float vecDif[2];
    vecDif[0] = FloatAbs( vecMaxs[0] - vecMins[0] );
    vecDif[1] = FloatAbs( vecMaxs[1] - vecMins[1] );
    
    float x_scale = 0.0;
    float y_scale = 0.0;
    
    BlockDirToMult( dir, x_scale, y_scale );
    
    
    float flDist = float( block );
    float add_x = vecDif[0] * x_scale + flDist * x_scale;
    float add_y = vecDif[1] * y_scale + flDist * y_scale;
    
    float vecNewMins[3];
    vecNewMins[0] = vecMins[0] + add_x;
    vecNewMins[1] = vecMins[1] + add_y;
    vecNewMins[2] = vecMins[2];
    
    float vecNewMaxs[3];
    vecNewMaxs[0] = vecMaxs[0] + add_x;
    vecNewMaxs[1] = vecMaxs[1] + add_y;
    vecNewMaxs[2] = vecMaxs[2];
    
    
    int start_entref = g_hBlocks.Get( startindex, view_as<int>( ZONE_ENTREF ) );
    int endindex = InsertNewBlock( block, start_entref, vecNewMins, vecNewMaxs, false, dir );
    
    if ( endindex != -1 )
    {
        int end_ent = CreateZoneEntity( endindex );
        
        if ( end_ent != -1 )
        {
            g_hBlocks.Set( startindex, EntIndexToEntRef( end_ent ), view_as<int>( ZONE_OPP_ENTREF ) );
            g_hBlocks.Set( startindex, dir, view_as<int>( ZONE_DIR ) );
            
            return true;
        }
    }
    
    return false;
}

stock BlockDir YawToBlockDir( float yaw )
{
    if ( yaw > -45.0 && yaw < 45.0 )
    {
        // Right
        return BLOCKDIR_RIGHT;
    }
    else if ( yaw >= 45.0 && yaw < 135.0 )
    {
        // Up
        return BLOCKDIR_FWD;
    }
    else if ( yaw >= 135.0 || yaw < -135.0 )
    {
        // Left
        return BLOCKDIR_LEFT;
    }
    else
    {
        // Down
        return BLOCKDIR_BWD;
    }
}

stock float GetBlockDirAngle( BlockDir dir )
{
    switch ( dir )
    {
        case BLOCKDIR_FWD : return 90.0;
        case BLOCKDIR_LEFT : return 180.0;
        case BLOCKDIR_BWD : return -90.0;
    }
    
    return 0.0;
}

stock BlockDir GetOppBlockDir( BlockDir dir )
{
    switch ( dir )
    {
        case BLOCKDIR_RIGHT : return BLOCKDIR_LEFT;
        case BLOCKDIR_FWD : return BLOCKDIR_BWD;
        case BLOCKDIR_LEFT : return BLOCKDIR_RIGHT;
    }
    
    return BLOCKDIR_FWD;
}

stock void BlockDirToMult( BlockDir dir, float &x_scale, float &y_scale )
{
    switch ( dir )
    {
        case BLOCKDIR_RIGHT : x_scale = 1.0;
        case BLOCKDIR_FWD : y_scale = 1.0;
        case BLOCKDIR_LEFT : x_scale = -1.0;
        case BLOCKDIR_BWD : y_scale = -1.0;
    }
}

stock float VectorToAngle( float x, float y )
{
    return RadToDeg( ArcTangent2( y, x ) );
}

stock void TeleportPlayerToBlock( int client, int index )
{
    int iData[ZONE_SIZE];
    
    g_hBlocks.GetArray( index, iData, view_as<int>( ZoneData ) );
    
    float vecMins[3];
    float vecMaxs[3];
    
    CopyArray( iData[ZONE_MINS], vecMins, 3 );
    CopyArray( iData[ZONE_MAXS], vecMaxs, 3 );
    
    float vecPos[3];
    vecPos[0] = vecMins[0] + ( vecMaxs[0] - vecMins[0] ) / 2;
    vecPos[1] = vecMins[1] + ( vecMaxs[1] - vecMins[1] ) / 2;
    vecPos[2] = vecMins[2] + 16.0;
    
    float vecAng[3];
    
    
    vecAng[1] = GetBlockDirAngle( iData[ZONE_DIR] );
    
    TeleportEntity( client, vecPos, vecAng, ORIGIN_VECTOR );
}

public Action Timer_DrawBlockZones( Handle hTimer )
{
    int len = GetArrayLength_Safe( g_hBlocks );
    if ( len > 0 )
    {
        static int iData[ZONE_SIZE];
        static float vecMins[3];
        static float vecTemp[3];
        
        static float vecBeam1[3];
        static float vecBeam2[3];
        static float vecBeam3[3];
        static float vecBeam4[3];
        
        int[] clients = new int[MaxClients];
        int nClients;
        
        int client;
        
        for ( int i = 0; i < len; i++ )
        {
            g_hBlocks.GetArray( i, iData, view_as<int>( ZoneData ) );
            
            CopyArray( iData[ZONE_MINS], vecMins, 3 );
            
            nClients = 0;
            // Check if player is too far away.
            // We can't draw too many beams to the client.
            for ( client = 1; client <= MaxClients; client++ )
                if ( IsClientInGame( client ) && !IsFakeClient( client ) )
                {
                    if ( g_bLibrary_Hud )
                    {
                        if ( Standup_GetClientHideFlags( client ) & HIDEFLAG_LJBLOCKS )
                            continue;
                    }
                    
                    
                    GetClientAbsOrigin( client, vecTemp );
                    
                    #define MAX_DIST        800.0
                    #define MAX_DIST_SQ        MAX_DIST * MAX_DIST
                    
                    if ( GetVectorDistance( vecTemp, vecMins, true ) < MAX_DIST_SQ )
                    {
                        clients[nClients++] = client;
                    }
                }
            
            if ( !nClients ) continue;
            
            
            CopyArray( iData[ZONE_MAXS], vecTemp, 3 );
            
            vecMins[2] += 0.5;
            
            vecBeam1 = vecMins;
            
            vecBeam2[0] = vecMins[0];
            vecBeam2[1] = vecTemp[1];
            vecBeam2[2] = vecMins[2];
            
            vecBeam3[0] = vecTemp[0];
            vecBeam3[1] = vecTemp[1];
            vecBeam3[2] = vecMins[2];
            
            vecBeam4[0] = vecTemp[0];
            vecBeam4[1] = vecMins[1];
            vecBeam4[2] = vecMins[2];
            
            TE_SetupBeamPoints( vecBeam1, vecBeam2, g_iBeamMat, 0, 0, 0, ZONE_DRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, g_clrBlue, 0 );
            TE_Send( clients, nClients, 0.0 );
            TE_SetupBeamPoints( vecBeam2, vecBeam3, g_iBeamMat, 0, 0, 0, ZONE_DRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, g_clrBlue, 0 );
            TE_Send( clients, nClients, 0.0 );
            TE_SetupBeamPoints( vecBeam3, vecBeam4, g_iBeamMat, 0, 0, 0, ZONE_DRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, g_clrBlue, 0 );
            TE_Send( clients, nClients, 0.0 );
            TE_SetupBeamPoints( vecBeam4, vecBeam1, g_iBeamMat, 0, 0, 0, ZONE_DRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, g_clrBlue, 0 );
            TE_Send( clients, nClients, 0.0 );
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_DisplayBuildZones( Handle hTimer, int client )
{
    if ( !IsClientInGame( client ) || !IsPlayerAlive( client ) || !g_bBuildBlock[client] )
    {
        g_bBuildBlock[client] = false;
        
        return Plugin_Stop;
    }
    
    
    float vecCurPos[3];
    GetClientAbsOrigin( client, vecCurPos );
    
    RoundVector( vecCurPos );
    vecCurPos[2] += 1.0;
    
    float vecBeam1[3];
    float vecBeam2[3];
    float vecBeam3[3];
    float vecBeam4[3];
    
    vecBeam1 = vecCurPos;
    
    vecBeam2[0] = vecCurPos[0];
    vecBeam2[1] = g_vecBuild_Start[client][1];
    vecBeam2[2] = vecCurPos[2];
    
    vecBeam3 = g_vecBuild_Start[client];
    vecBeam3[2] = vecCurPos[2];
    
    vecBeam4[0] = g_vecBuild_Start[client][0];
    vecBeam4[1] = vecCurPos[1];
    vecBeam4[2] = vecCurPos[2];
    
    TE_SetupBeamPoints( vecBeam1, vecBeam2, g_iBeamMat, 0, 0, 0, BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToClient( client, 0.0 );
    TE_SetupBeamPoints( vecBeam2, vecBeam3, g_iBeamMat, 0, 0, 0, BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToClient( client, 0.0 );
    TE_SetupBeamPoints( vecBeam3, vecBeam4, g_iBeamMat, 0, 0, 0, BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToClient( client, 0.0 );
    TE_SetupBeamPoints( vecBeam4, vecBeam1, g_iBeamMat, 0, 0, 0, BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, g_clrWhite, 0 );
    TE_SendToClient( client, 0.0 );
    
    return Plugin_Continue;
}