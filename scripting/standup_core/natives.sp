public int Native_IsClientStatsEnabled( Handle hPlugin, int numParams )
{
    return g_bEnabledStats[GetNativeCell( 1 )];
}

public int Native_SetClientStats( Handle hPlugin, int numParams )
{
    int client = GetNativeCell( 1 );
    bool mode = view_as<bool>( GetNativeCell( 2 ) );
    
    MarkAsCheated( client, CHEATSTATE_MISC );
    
    
    if ( g_bEnabledStats[client] != mode )
    {
        if ( mode )
        {
            Call_StartForward( g_hForward_OnStatsEnabled );
            Call_PushCell( client );
            Call_Finish();
        }
        else
        {
            Call_StartForward( g_hForward_OnStatsDisabled );
            Call_PushCell( client );
            Call_Finish();
        }
    }
    
    g_bEnabledStats[client] = mode;
    
    return 1;
}

public int Native_GetClientPrespeed( Handle hPlugin, int numParams )
{
    return view_as<int>( g_flPreSpd[GetNativeCell( 1 )] );
}

public int Native_GetClientNextHint( Handle hPlugin, int numParams )
{
    return view_as<int>( g_flNextHintTime[GetNativeCell( 1 )] );
}

public int Native_IsSpammingCommand( Handle hPlugin, int numParams )
{
    return IsSpammingCommand( GetNativeCell( 1 ), GetNativeCell( 2 ) );
}

public int Native_InvalidateJump( Handle hPlugin, int numParams )
{
    MarkAsCheated( GetNativeCell( 1 ), CHEATSTATE_MISC );
    
    return 1;
}

public int Native_GetGoodDistance( Handle hPlugin, int numParams )
{
    int style = GetNativeCell( 1 );
    int stance = GetNativeCell( 2 );
    
    switch ( stance )
    {
        case JUMPSTANCE_DUCKED :
        {
            // Ducked
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return view_as<int>( g_ConVar_GoodDist_Bhop_Ducked.FloatValue );
                case JUMPSTYLE_WEIRD : return view_as<int>( g_ConVar_GoodDist_Wj_Ducked.FloatValue );
                case JUMPSTYLE_LJ : return view_as<int>( g_ConVar_GoodDist_Lj_Ducked.FloatValue );
            }
        }
        case JUMPSTANCE_STANDUP :
        {
            // Standup
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return view_as<int>( g_ConVar_GoodDist_Bhop_Stand.FloatValue );
                case JUMPSTYLE_WEIRD : return view_as<int>( g_ConVar_GoodDist_Wj_Stand.FloatValue );
                case JUMPSTYLE_LJ : return view_as<int>( g_ConVar_GoodDist_Lj_Stand.FloatValue );
                case JUMPSTYLE_LADDER : return view_as<int>( g_ConVar_GoodDist_Ladder_Stand.FloatValue );
            }
        }
        default :
        {
            // Normal
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return view_as<int>( g_ConVar_GoodDist_Bhop.FloatValue );
                case JUMPSTYLE_WEIRD : return view_as<int>( g_ConVar_GoodDist_Wj.FloatValue );
                case JUMPSTYLE_LJ : return view_as<int>( g_ConVar_GoodDist_Lj.FloatValue );
                case JUMPSTYLE_LADDER : return view_as<int>( g_ConVar_GoodDist_Ladder.FloatValue );
            }
        }
    }
    
    return view_as<int>( 260.0 );
}

public int Native_GetVeryGoodDistance( Handle hPlugin, int numParams )
{
    int style = GetNativeCell( 1 );
    int stance = GetNativeCell( 2 );
    
    switch ( stance )
    {
        case JUMPSTANCE_DUCKED :
        {
            // Ducked
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return view_as<int>( g_ConVar_VeryGoodDist_Bhop_Ducked.FloatValue );
                case JUMPSTYLE_WEIRD : return view_as<int>( g_ConVar_VeryGoodDist_Wj_Ducked.FloatValue );
                case JUMPSTYLE_LJ : return view_as<int>( g_ConVar_VeryGoodDist_Lj_Ducked.FloatValue );
            }
        }
        case JUMPSTANCE_STANDUP :
        {
            // Standup
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return view_as<int>( g_ConVar_VeryGoodDist_Bhop_Stand.FloatValue );
                case JUMPSTYLE_WEIRD : return view_as<int>( g_ConVar_VeryGoodDist_Wj_Stand.FloatValue );
                case JUMPSTYLE_LJ : return view_as<int>( g_ConVar_VeryGoodDist_Lj_Stand.FloatValue );
                case JUMPSTYLE_LADDER : return view_as<int>( g_ConVar_VeryGoodDist_Ladder_Stand.FloatValue );
            }
        }
        default :
        {
            // Normal
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return view_as<int>( g_ConVar_VeryGoodDist_Bhop.FloatValue );
                case JUMPSTYLE_WEIRD : return view_as<int>( g_ConVar_VeryGoodDist_Wj.FloatValue );
                case JUMPSTYLE_LJ : return view_as<int>( g_ConVar_VeryGoodDist_Lj.FloatValue );
                case JUMPSTYLE_LADDER : return view_as<int>( g_ConVar_VeryGoodDist_Ladder.FloatValue );
            }
        }
    }
    
    return view_as<int>( 265.0 );
}

public int Native_GetAmazingDistance( Handle hPlugin, int numParams )
{
    int style = GetNativeCell( 1 );
    int stance = GetNativeCell( 2 );
    
    switch ( stance )
    {
        case JUMPSTANCE_DUCKED :
        {
            // Ducked
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return view_as<int>( g_ConVar_AmazingDist_Bhop_Ducked.FloatValue );
                case JUMPSTYLE_WEIRD : return view_as<int>( g_ConVar_AmazingDist_Wj_Ducked.FloatValue );
                case JUMPSTYLE_LJ : return view_as<int>( g_ConVar_AmazingDist_Lj_Ducked.FloatValue );
            }
        }
        case JUMPSTANCE_STANDUP :
        {
            // Standup
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return view_as<int>( g_ConVar_AmazingDist_Bhop_Stand.FloatValue );
                case JUMPSTYLE_WEIRD : return view_as<int>( g_ConVar_AmazingDist_Wj_Stand.FloatValue );
                case JUMPSTYLE_LJ : return view_as<int>( g_ConVar_AmazingDist_Lj_Stand.FloatValue );
                case JUMPSTYLE_LADDER : return view_as<int>( g_ConVar_AmazingDist_Ladder_Stand.FloatValue );
            }
        }
        default :
        {
            // Normal
            switch ( style )
            {
                case JUMPSTYLE_BUNNY : return view_as<int>( g_ConVar_AmazingDist_Bhop.FloatValue );
                case JUMPSTYLE_WEIRD : return view_as<int>( g_ConVar_AmazingDist_Wj.FloatValue );
                case JUMPSTYLE_LJ : return view_as<int>( g_ConVar_AmazingDist_Lj.FloatValue );
                case JUMPSTYLE_LADDER : return view_as<int>( g_ConVar_AmazingDist_Ladder.FloatValue );
            }
        }
    }
    
    return view_as<int>( 270.0 );
}