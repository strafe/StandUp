#include <sourcemod>
#include <sdkhooks>

#include <standup/core>


#pragma semicolon 1
#pragma newdecls required


public Plugin myinfo =
{
    author = PLUGIN_AUTHOR_CORE,
    url = PLUGIN_URL_CORE,
    name = PLUGIN_NAME_CORE..." - Disable Weapon Drops",
    description = "",
    version = "1.0"
};

public void OnPluginStart()
{
    //CreateTimer( 360.0, Timer_CleanUpWeapon, _, TIMER_REPEAT );
}

public void OnClientPutInServer( int client )
{
    SDKHook( client, SDKHook_WeaponDrop, Event_Client_WeaponDrop );
}

public Action Event_Client_WeaponDrop( int client, int weapon )
{
    return Plugin_Handled;
}

/*public Action Timer_CleanUpWeapon( Handle hTimer )
{
    int ent = -1;
    while ( (ent = FindEntityByClassname( ent, "weapon_*" )) != -1 )
    {
        if ( !IsValidEntity( ent ) ) continue;
        
        if ( IS_ENT_PLAYER( GetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity" ) ) ) continue;
        
        
        AcceptEntityInput(  )
    }
}*/