#pragma semicolon 1

#define DEBUG

#define EU_MAX_ENT 64
#define EU_PROP_INVALID -1
#define EU_PROP_SEND 0
#define EU_PROP_DATA 1
#define EU_INVALID_PROP_SEND_OFFSET -1
#define EU_INVALID_PROP_DATA_OFFSET -1
#define EU_ENTITY_SPAWN_NAME "eu_entity"
#define EU_PREFIX " \x09[\x04EU\x09]"
#define EU_PREFIX_CONSOLE "[EU]"

#define PLUGIN_AUTHOR "Rachnus"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
//#include <sdkhooks>

#pragma newdecls required

ArrayList g_hEntities[MAXPLAYERS + 1];
ArrayList g_hUnownedEntities;
int g_iSelectedEnt[MAXPLAYERS + 1] =  { INVALID_ENT_REFERENCE, ... };

ConVar g_DestroyEntsOnDisconnect;
ConVar g_PrintPreciseVectors;

public Plugin myinfo = 
{
	name = "Entity Utilities v1.0",
	author = PLUGIN_AUTHOR,
	description = "Create/Edit/View entities",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rachnus"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	g_DestroyEntsOnDisconnect = CreateConVar("entityutilities_destroy_ents_on_disconnect", "1", "Should the players entities get destroyed on disconnect", FCVAR_NOTIFY);
	g_PrintPreciseVectors = CreateConVar("entityutilities_print_precise_vectors", "1", "Should vectors be printed with many decimals or 2 decimals", FCVAR_NOTIFY);
	
	RegAdminCmd("sm_ent_create", Command_EntCreate, ADMFLAG_ROOT, "Creates an entity");
	RegAdminCmd("sm_ent_keyvalue", Command_EntKeyValue, ADMFLAG_ROOT, "Dispatch a keyvalue to an entity (Used before spawning)");
	RegAdminCmd("sm_ent_keyvaluefloat", Command_EntKeyValueFloat, ADMFLAG_ROOT, "Dispatch a float keyvalue to an entity (Used before spawning)");
	RegAdminCmd("sm_ent_keyvaluevector", Command_EntKeyValueVector, ADMFLAG_ROOT, "Dispatch a vector keyvalue to an entity (Used before spawning)");
	RegAdminCmd("sm_ent_spawn", Command_EntSpawn, ADMFLAG_ROOT, "Spawns the entity");
	
	RegAdminCmd("sm_ent_input", Command_EntInput, ADMFLAG_ROOT, "Accept Entity Input");
	
	RegAdminCmd("sm_ent_position", Command_EntPosition, ADMFLAG_ROOT, "Sets position of selected entity to aim (Position can be passed as arguments as 3 floats)");
	RegAdminCmd("sm_ent_angles", Command_EntAngles, ADMFLAG_ROOT, "Sets angles of selected entity to aim (Angles can be passed as arguments as 3 floats)");
	RegAdminCmd("sm_ent_velocity", Command_EntVelocity, ADMFLAG_ROOT, "Sets velocity of selected entity, passed by argument as 3 floats");
	
	RegAdminCmd("sm_ent_selected", Command_EntSelected, ADMFLAG_ROOT, "Prints generic information about selected entity");
	RegAdminCmd("sm_ent_select", Command_EntSelect, ADMFLAG_ROOT, "Select an entity at aim (Selects by name if argument is passed)");
	RegAdminCmd("sm_ent_select_index", Command_EntSelectIndex, ADMFLAG_ROOT, "Select an entity by entity index");
	RegAdminCmd("sm_ent_select_ref", Command_EntSelectRef, ADMFLAG_ROOT, "Select an entity by entity reference");
	RegAdminCmd("sm_ent_select_self", Command_EntSelectSelf, ADMFLAG_ROOT, "Select your player");
	RegAdminCmd("sm_ent_select_world", Command_EntSelectWorld, ADMFLAG_ROOT, "Select the world (Entity 0)");
	
	RegAdminCmd("sm_ent_setprop", Command_EntSetProp, ADMFLAG_ROOT, "Set property of an entity");
	RegAdminCmd("sm_ent_getprop", Command_EntGetProp, ADMFLAG_ROOT, "Print property of an entity");

	RegAdminCmd("sm_ent_killall", Command_KillAll, ADMFLAG_ROOT, "Kills all entities spawned by players");
	RegAdminCmd("sm_ent_killmy", Command_KillMy, ADMFLAG_ROOT, "Kills entities spawned by player using this command");
	RegAdminCmd("sm_ent_killunowned", Command_KillUnowned, ADMFLAG_ROOT, "Kills entities spawned by players that disconnected");
	
	RegAdminCmd("sm_ent_list", Command_EntList, ADMFLAG_ROOT, "Lists all entities owned by a client");
	
	RegAdminCmd("sm_ent_count", Command_EntCount, ADMFLAG_ROOT, "Prints amount of existing entities with classname passed as arg");
	
	for (int i = 0; i < MAXPLAYERS + 1; i++)
		g_hEntities[i] = new ArrayList();
		
	g_hUnownedEntities = new ArrayList();
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
			OnClientPutInServer(i);
	}
}

public Action Command_EntCreate(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(args == 0)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_create <classname>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	if(g_hEntities[client].Length >= EU_MAX_ENT)
	{
		char message[256];
		Format(message, sizeof(message), "%s Exceeded max entity limit per player (\x04%d\x09)", EU_PREFIX, EU_MAX_ENT);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int entity = CreateEntityByName(arg);
	if(entity <= INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Could not spawn entity '\x04%s\x09'", EU_PREFIX, arg);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	int ref = EntIndexToEntRef(entity);
	g_hEntities[client].Push(ref);
	g_iSelectedEnt[client] = ref;
	
	char authid[32];
	GetClientAuthId(client, AuthId_SteamID64, authid, sizeof(authid));
	
	char string[128];
	Format(string, sizeof(string), "%s;%s", EU_ENTITY_SPAWN_NAME, authid);
	
	DispatchKeyValue(entity, "targetname", string);

	char message[256];
	Format(message, sizeof(message), "%s Entity '\x04%s\x09' created!", EU_PREFIX, arg);
	ReplyToCommandColor(client, message, replySource);
	
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
	return Plugin_Handled;
}

public Action Command_EntSpawn(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	float traceendPos[3], eyeAngles[3], eyePos[3];
	GetClientEyeAngles(client, eyeAngles);
	GetClientEyePosition(client, eyePos);

	Handle trace = TR_TraceRayFilterEx(eyePos, eyeAngles, MASK_ALL, RayType_Infinite, TraceFilterNotSelf, client);
	if(TR_DidHit(trace))
		TR_GetEndPosition(traceendPos, trace);

	CloseHandle(trace);

	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	int ref = EntIndexToEntRef(entity);
	DispatchSpawn(entity);
	TeleportEntity(entity, traceendPos, NULL_VECTOR, NULL_VECTOR);
	
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	char message[256];
	Format(message, sizeof(message), "%s Spawned at:", EU_PREFIX);
	ReplyToCommandColor(client, message, replySource);
	PrintVector(client, "Position", "X", "Y", "Z", traceendPos, replySource);
	ReplyToCommandColor(client, " ", replySource);
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
	return Plugin_Handled;
}

public Action Command_EntKeyValue(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(args != 2)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_keyvalue <keyname> <value>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	int ref = EntIndexToEntRef(entity);
	char arg[65], arg2[65];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	if(StrEqual(arg, "model", false))
	{
		if(!IsModelPrecached(arg2))
			PrecacheModel(arg2);
	}
	
	DispatchKeyValue(entity, arg, arg2);
	
	char message[256];
	Format(message, sizeof(message), "%s Set keyvalue '\x0C%s\x09' to '\x0C%s\x09'", EU_PREFIX, arg, arg2);
	ReplyToCommandColor(client, message, replySource);
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
	return Plugin_Handled;
}

public Action Command_EntKeyValueFloat(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(args != 2)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_keyvaluefloat <keyname> <value>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	int ref = EntIndexToEntRef(entity);
	char arg[65], arg2[65];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	float value = StringToFloat(arg2);
	
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	DispatchKeyValueFloat(entity, arg, value);
	
	char message[256];
	Format(message, sizeof(message), "%s Set keyvalue '\x0C%s\x09' to '\x0C%f\x09'", EU_PREFIX, arg, value);
	ReplyToCommandColor(client, message, replySource);

	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
	return Plugin_Handled;
}

public Action Command_EntKeyValueVector(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(args != 4)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_keyvaluevector <keyname> <value1> <value2> <value3>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	int ref = EntIndexToEntRef(entity);
	char arg[65], arg2[65], arg3[65], arg4[65];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	GetCmdArg(4, arg4, sizeof(arg4));
	
	float value[3];
	value[0] = StringToFloat(arg2);
	value[1] = StringToFloat(arg3);
	value[2] = StringToFloat(arg4);
	
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	DispatchKeyValueVector(entity, arg, value);
	
	char message[256];
	Format(message, sizeof(message), "%s Set keyvalue '\x0C%s\x09' to:", EU_PREFIX, arg);
	ReplyToCommandColor(client, message, replySource);
	PrintVector(client, arg, "X", "Y", "Z", value, replySource);
	ReplyToCommandColor(client, " ", replySource);
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
	return Plugin_Handled;
}

public Action Command_EntInput(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(args < 1 || args > 4)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_input <input> <activator> <caller> <outputid>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	int ref = EntIndexToEntRef(entity);
	char arg[65], arg2[65], arg3[65], arg4[65];
	
	Format(arg2, sizeof(arg2), "%d", INVALID_ENT_REFERENCE);
	Format(arg3, sizeof(arg3), "%d", INVALID_ENT_REFERENCE);
	Format(arg4, sizeof(arg4), "%d", 0);
	
	GetCmdArg(1, arg, sizeof(arg));
	if(args > 1)
		GetCmdArg(2, arg2, sizeof(arg2));
	if(args > 2)
		GetCmdArg(3, arg3, sizeof(arg3));
	if(args > 3)
		GetCmdArg(4, arg4, sizeof(arg4));
	
	int activator = StringToInt(arg2);
	int caller = StringToInt(arg3);
	int outputid = StringToInt(arg4);
	
	
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	AcceptEntityInput(entity, arg, activator, caller, outputid);
	
	char message[256];
	Format(message, sizeof(message), "%s Input '\x0C%s\x09' called", EU_PREFIX, arg);
	ReplyToCommandColor(client, message, replySource);
		
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Activator", activator, replySource);
	PrintInt(client, "Caller", caller, replySource);
	PrintInt(client, "Output ID", outputid, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
	return Plugin_Handled;
}


public Action Command_EntPosition(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	int ref = EntIndexToEntRef(entity);
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	if(args == 3)
	{
		char arg[65], arg2[65], arg3[65];
		
		GetCmdArg(1, arg, sizeof(arg));
		GetCmdArg(2, arg2, sizeof(arg2));
		GetCmdArg(3, arg3, sizeof(arg3));
		
		float value[3];
		value[0] = StringToFloat(arg);
		value[1] = StringToFloat(arg2);
		value[2] = StringToFloat(arg3);
		
		TeleportEntity(entity, value, NULL_VECTOR, NULL_VECTOR);
		
		char message[256];
		Format(message, sizeof(message), "%s Set position to:", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		PrintVector(client, "Position", "X", "Y", "Z", value, replySource);
		ReplyToCommandColor(client, " ", replySource);
		PrintString(client, "Entity", className, replySource);
		PrintInt(client, "Entity Index", entity, replySource);
		PrintInt(client, "Entity Reference", ref, replySource);
		return Plugin_Handled;
	}
	
	float traceendPos[3], eyeAngles[3], eyePos[3];
	GetClientEyeAngles(client, eyeAngles);
	GetClientEyePosition(client, eyePos);

	Handle trace = TR_TraceRayFilterEx(eyePos, eyeAngles, MASK_ALL, RayType_Infinite, TraceFilterNotSelf, client);
	if(TR_DidHit(trace))
		TR_GetEndPosition(traceendPos, trace);

	CloseHandle(trace);
	
	TeleportEntity(entity, traceendPos, NULL_VECTOR, NULL_VECTOR);
	
	char message[256];
	Format(message, sizeof(message), "%s Set position to:", EU_PREFIX);
	ReplyToCommandColor(client, message, replySource);
	PrintVector(client, "Position", "X", "Y", "Z", traceendPos, replySource);
	ReplyToCommandColor(client, " ", replySource);
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
	return Plugin_Handled;
}

public Action Command_EntAngles(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	int ref = EntIndexToEntRef(entity);
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	if(args == 3)
	{
		char arg[65], arg2[65], arg3[65];
		
		GetCmdArg(1, arg, sizeof(arg));
		GetCmdArg(2, arg2, sizeof(arg2));
		GetCmdArg(3, arg3, sizeof(arg3));
		
		float value[3];
		value[0] = StringToFloat(arg);
		value[1] = StringToFloat(arg2);
		value[2] = StringToFloat(arg3);
		
		TeleportEntity(entity, NULL_VECTOR, value, NULL_VECTOR);
		
		char message[256];
		Format(message, sizeof(message), "%s Set angles to:", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		PrintVector(client, "Angles", "X", "Y", "Z", value, replySource);
		ReplyToCommandColor(client, " ", replySource);
		PrintString(client, "Entity", className, replySource);
		PrintInt(client, "Entity Index", entity, replySource);
		PrintInt(client, "Entity Reference", ref, replySource);
		return Plugin_Handled;
	}
	
	float eyeAngles[3];
	GetClientEyeAngles(client, eyeAngles);

	TeleportEntity(entity, NULL_VECTOR, eyeAngles, NULL_VECTOR);
	
	char message[256];
	Format(message, sizeof(message), "%s Set angles to:", EU_PREFIX);
	ReplyToCommandColor(client, message, replySource);
	PrintVector(client, "Angles", "X", "Y", "Z", eyeAngles, replySource);
	ReplyToCommandColor(client, " ", replySource);
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
	return Plugin_Handled;
}

public Action Command_EntVelocity(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(args != 3)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_velocity <value1> <value2> <value3>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	int ref = EntIndexToEntRef(entity);
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));

	char arg[65], arg2[65], arg3[65];
	
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	
	float value[3];
	value[0] = StringToFloat(arg);
	value[1] = StringToFloat(arg2);
	value[2] = StringToFloat(arg3);
	
	TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, value);
	
	char message[256];
	Format(message, sizeof(message), "%s Set velocity to:", EU_PREFIX);
	ReplyToCommandColor(client, message, replySource);
	ReplyToCommandColor(client, " ", replySource);
	PrintVector(client, "Velocity", "X", "Y", "Z", value, replySource);
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelect(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	if(args == 1)
	{
		char arg[65];
		GetCmdArg(1, arg, sizeof(arg));
		
		int iEnt = MAXPLAYERS + 1;
		char targetName[32];
		while((iEnt = FindEntityByClassname(iEnt, "*")) != -1)
		{
			if(iEnt < MAXPLAYERS + 1 || !IsValidEntity(iEnt))
				continue;
				
			GetEntPropString(iEnt, Prop_Data, "m_iName", targetName, sizeof(targetName));
			if(StrEqual(targetName, arg, false))
			{
				SelectEntity(client, iEnt, false, replySource);
				return Plugin_Handled;
			}
		}
		char message[256];
		Format(message, sizeof(message), "%s Could not find an entity with name '\x04%s\x09'", EU_PREFIX, arg);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	SelectEntity(client, GetClientAimTarget(client, false), false, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelected(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	PrintSelectedEntity(client, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelectIndex(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(args != 1)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_select_index <index>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	int entity = StringToInt(arg);
	
	SelectEntity(client, entity, false, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelectRef(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(args != 1)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_select_index <index>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	int entity = EntRefToEntIndex(StringToInt(arg));
	
	SelectEntity(client, entity, false, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelectSelf(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	SelectEntity(client, client, false, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelectWorld(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	SelectEntity(client, 0, true, replySource);
	return Plugin_Handled;
}

public Action Command_EntSetProp(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	char prop[65], szValue1[65], szValue2[65], szValue3[65], szSize[65], szElement[65];
	GetCmdArg(1, prop, sizeof(prop));
	
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	bool send = false;
	bool data = false;
	
	int element = 0;
	int size = 4;
	
	PropFieldType sendFieldType = PropField_Unsupported;
	PropFieldType dataFieldType = PropField_Unsupported;
	
	Format(szSize, sizeof(szSize), "%d", 4);
	Format(szElement, sizeof(szElement), "%d", 0);
	
	if(FindSendPropInfo(className, prop, sendFieldType) != EU_INVALID_PROP_SEND_OFFSET)
	{
		switch(sendFieldType)
		{
			case PropField_Integer:
			{
				if(args < 2 || args > 4)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property(int)> <value> <size=4> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				GetCmdArg(2, szValue1, sizeof(szValue1));
				if(args > 2) GetCmdArg(3, szSize, sizeof(szSize));
				if(args > 3) GetCmdArg(4, szElement, sizeof(szElement));
				
				size = StringToInt(szSize);
				element = StringToInt(szElement);
				int value = StringToInt(szValue1);
				SetEntProp(entity, Prop_Send, prop, value, size, element);
			}
			case PropField_Float:
			{
				if(args < 2 || args > 3)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property(float)> <value> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				GetCmdArg(2, szValue1, sizeof(szValue1));
				
				if(args > 2) GetCmdArg(3, szElement, sizeof(szElement));
			
				element = StringToInt(szElement);
				float value = StringToFloat(szValue1);
				SetEntPropFloat(entity, Prop_Send, prop, value, element);
			}
			case PropField_String:
			{
				if(args < 2 || args > 3)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property(string)> <value> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				GetCmdArg(2, szValue1, sizeof(szValue1));
				if(args > 2) GetCmdArg(3, szElement, sizeof(szElement));
			
				element = StringToInt(szElement);
				SetEntPropString(entity, Prop_Send, prop, szValue1, element);
			}
			case PropField_String_T:
			{
				if(args < 2 || args > 3)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property(string)> <value> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				GetCmdArg(2, szValue1, sizeof(szValue1));
				if(args > 2) GetCmdArg(3, szElement, sizeof(szElement));

				element = StringToInt(szElement);
				SetEntPropString(entity, Prop_Send, prop, szValue1, element);
			}
			case PropField_Vector:
			{
				if(args < 4 || args > 5)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property(vector)> <value1> <value2> <value3> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				GetCmdArg(2, szValue1, sizeof(szValue1));
				GetCmdArg(3, szValue2, sizeof(szValue2));
				GetCmdArg(4, szValue3, sizeof(szValue3));
				
				if(args > 4) GetCmdArg(5, szElement, sizeof(szElement));

				element = StringToInt(szElement);
				float value[3];
				value[0] = StringToFloat(szValue1);
				value[1] = StringToFloat(szValue2);
				value[2] = StringToFloat(szValue3);
				SetEntPropVector(entity, Prop_Send, prop, value, element);
			}
			case PropField_Entity:
			{
				if(args < 2 || args > 3)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property(entity)> <value> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				GetCmdArg(2, szValue1, sizeof(szValue1));
				if(args > 2) GetCmdArg(3, szElement, sizeof(szElement));

				element = StringToInt(szElement);
				int value = StringToInt(szValue1);
				SetEntPropEnt(entity, Prop_Send, prop, value, element);
			}
		}
		
		send = true;
	}

	if(FindDataMapInfo(entity, prop, dataFieldType) != EU_INVALID_PROP_DATA_OFFSET)
	{
		switch(dataFieldType)
		{
			case PropField_Integer:
			{
				if(args < 2 || args > 4)
				{
					char message[256];
					Format(message, sizeof(message), "s Usage \x04sm_ent_setprop <property(int)> <value> <size=4> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				GetCmdArg(2, szValue1, sizeof(szValue1));
				if(args > 2) GetCmdArg(3, szSize, sizeof(szSize));
				if(args > 3) GetCmdArg(4, szElement, sizeof(szElement));
			
				size = StringToInt(szSize);
				element = StringToInt(szElement);
				int value = StringToInt(szValue1);
				SetEntProp(entity, Prop_Data, prop, value, size, element);
			}
			case PropField_Float:
			{
				if(args < 2 || args > 3)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property(float)> <value> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}

				GetCmdArg(2, szValue1, sizeof(szValue1));
				if(args > 2) GetCmdArg(3, szElement, sizeof(szElement));
			
				element = StringToInt(szElement);
				float value = StringToFloat(szValue1);
				SetEntPropFloat(entity, Prop_Data, prop, value, element);
			}
			case PropField_String:
			{
				if(args < 2 || args > 3)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property(string)> <value> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				GetCmdArg(2, szValue1, sizeof(szValue1));
				if(args > 2) GetCmdArg(3, szElement, sizeof(szElement));
			
				element = StringToInt(szElement);
				SetEntPropString(entity, Prop_Data, prop, szValue1, element);
			}
			case PropField_String_T:
			{
				if(args < 2 || args > 3)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property(string)> <value> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				GetCmdArg(2, szValue1, sizeof(szValue1));
				if(args > 2) GetCmdArg(3, szElement, sizeof(szElement));
	
				element = StringToInt(szElement);
				SetEntPropString(entity, Prop_Data, prop, szValue1, element);
			}
			case PropField_Vector:
			{
				if(args < 4 || args > 5)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property(vector)> <value1> <value2> <value3> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				GetCmdArg(2, szValue1, sizeof(szValue1));
				GetCmdArg(3, szValue2, sizeof(szValue2));
				GetCmdArg(4, szValue3, sizeof(szValue3));
				if(args > 4) GetCmdArg(5, szElement, sizeof(szElement));
			
				element = StringToInt(szElement);
				float value[3];
				value[0] = StringToFloat(szValue1);
				value[1] = StringToFloat(szValue2);
				value[2] = StringToFloat(szValue3);
				SetEntPropVector(entity, Prop_Data, prop, value, element);
			}
			case PropField_Entity:
			{
				if(args < 2 || args > 3)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property(entity)> <value> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				GetCmdArg(2, szValue1, sizeof(szValue1));
				if(args > 2) GetCmdArg(3, szElement, sizeof(szElement));
				
				element = StringToInt(szElement);
				int value = StringToInt(szValue1);
				SetEntPropEnt(entity, Prop_Data, prop, value, element);
			}
		}
		
		data = true;
	}
	
	if(send)
	{
		switch(sendFieldType)
		{
			case PropField_Integer:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				PrintInt(client, prop, GetEntProp(entity, Prop_Send, prop, size, element), replySource);
			}
			case PropField_Float:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				PrintFloat(client, prop, GetEntPropFloat(entity, Prop_Send, prop, element), replySource);
			}
			case PropField_String:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				char string[256];
				GetEntPropString(entity, Prop_Send, prop, string, sizeof(string), element);
				PrintString(client, prop, string, replySource);
			}
			case PropField_String_T:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				char string[256];
				GetEntPropString(entity, Prop_Send, prop, string, sizeof(string), element);
				PrintString(client, prop, string, replySource);
			}
			case PropField_Vector:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				float vec[3];
				GetEntPropVector(entity, Prop_Send, prop, vec, element);
				PrintVector(client, prop, "X", "Y", "Z", vec, replySource);
			}
			case PropField_Entity:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				PrintInt(client, prop, GetEntPropEnt(entity, Prop_Send, prop, element), replySource);
			}
		}
	}
	if(data)
	{
		switch(dataFieldType)
		{
			case PropField_Integer:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				PrintInt(client, prop, GetEntProp(entity, Prop_Data, prop, size, element), replySource);
			}
			case PropField_Float:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				PrintFloat(client, prop, GetEntPropFloat(entity, Prop_Data, prop, element), replySource);
			}
			case PropField_String:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				char string[256];
				GetEntPropString(entity, Prop_Data, prop, string, sizeof(string), element);
				PrintString(client, prop, string, replySource);
			}
			case PropField_String_T:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				char string[256];
				GetEntPropString(entity, Prop_Data, prop, string, sizeof(string), element);
				PrintString(client, prop, string, replySource);
			}
			case PropField_Vector:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				float vec[3];
				GetEntPropVector(entity, Prop_Data, prop, vec, element);
				PrintVector(client, prop, "X", "Y", "Z", vec, replySource);
			}
			case PropField_Entity:
			{
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				PrintInt(client, prop, GetEntPropEnt(entity, Prop_Data, prop, element), replySource);
			}
		}
	}
	else
	{
		char message[256];
		Format(message, sizeof(message), "%s Could not find prop '\x04%s\x09'", EU_PREFIX, prop);
		ReplyToCommandColor(client, message, replySource);
	}
	
	return Plugin_Handled;
}

public Action Command_EntGetProp(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	char prop[65], szSize[65], szElement[65];
	GetCmdArg(1, prop, sizeof(prop));
	
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	bool send = false;
	bool data = false;
	
	PropFieldType sendFieldType = PropField_Unsupported;
	PropFieldType dataFieldType = PropField_Unsupported;

	Format(szSize, sizeof(szSize), "%d", 4);
	Format(szElement, sizeof(szElement), "%d", 0);

	if(FindSendPropInfo(className, prop, sendFieldType) != EU_INVALID_PROP_SEND_OFFSET)
		send = true;
		
	if(FindDataMapInfo(entity, prop, dataFieldType) != EU_INVALID_PROP_DATA_OFFSET)
		data = true;
	
	if(send || data)
	{
		char message[256];
		Format(message, sizeof(message), "%s Property get:", EU_PREFIX, prop);
		ReplyToCommandColor(client, message, replySource);
	}
	else
	{
		char message[256];
		Format(message, sizeof(message), "%s Could not find prop '\x04%s\x09'", EU_PREFIX, prop);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}

	if(send)
	{
		switch(sendFieldType)
		{
			case PropField_Integer:
			{
				if(args < 1 || args > 3)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <size=4> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szSize, sizeof(szSize));
				if(args > 2) GetCmdArg(3, szElement, sizeof(szElement));

				int size = StringToInt(szSize);
				int element = StringToInt(szElement);
				
				char string[256];
				Format(string, sizeof(string), "SEND - %s", prop);
				PrintInt(client, string, GetEntProp(entity, Prop_Send, prop, size, element), replySource);
			}
			case PropField_Float:
			{
				if(args < 1 || args > 2)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szElement, sizeof(szElement));
				
				int element = StringToInt(szElement);
				
				char string[256];
				Format(string, sizeof(string), "SEND - %s", prop);
				PrintFloat(client, string, GetEntPropFloat(entity, Prop_Send, prop, element), replySource);
			}
			case PropField_String:
			{
				if(args < 1 || args > 2)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szElement, sizeof(szElement));

				int element = StringToInt(szElement);
				
				char string[256];
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Send, prop, value, sizeof(value), element);
				Format(string, sizeof(string), "SEND - %s", prop);
				PrintString(client, string, value, replySource);
			}
			case PropField_String_T:
			{
				if(args < 1 || args > 2)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szElement, sizeof(szElement));

				int element = StringToInt(szElement);
				
				char string[256];
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Send, prop, value, sizeof(value), element);
				Format(string, sizeof(string), "SEND - %s", prop);
				PrintString(client, string, value, replySource);
			}
			case PropField_Vector:
			{
				if(args < 1 || args > 2)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szElement, sizeof(szElement));
			
				int element = StringToInt(szElement);
				
				char string[256];
				float value[3];
				GetEntPropVector(entity, Prop_Send, prop, value, element);
				Format(string, sizeof(string), "SEND - %s", prop);
				PrintVector(client, string, "X", "Y", "Z", value, replySource);
			}
			case PropField_Entity:
			{
				if(args < 1 || args > 2)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szElement, sizeof(szElement));

				int element = StringToInt(szElement);
				
				char string[256];
				Format(string, sizeof(string), "SEND - %s", prop);
				PrintInt(client, string, GetEntPropEnt(entity, Prop_Send, prop, element), replySource);
			}
		}
	}
	if(data)
	{
		switch(dataFieldType)
		{
			case PropField_Integer:
			{
				if(args < 1 || args > 3)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <size=4> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szSize, sizeof(szSize));
				if(args > 2) GetCmdArg(3, szElement, sizeof(szElement));

				int size = StringToInt(szSize);
				int element = StringToInt(szElement);
				
				char string[256];
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintInt(client, string, GetEntProp(entity, Prop_Data, prop, size, element), replySource);
			}
			case PropField_Float:
			{
				if(args < 1 || args > 2)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szElement, sizeof(szElement));
			
				int element = StringToInt(szElement);
				
				char string[256];
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintFloat(client, string, GetEntPropFloat(entity, Prop_Data, prop, element), replySource);
			}
			case PropField_String:
			{
				if(args < 1 || args > 2)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szElement, sizeof(szElement));

				int element = StringToInt(szElement);
				
				char string[256];
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Data, prop, value, sizeof(value), element);
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintString(client, string, value, replySource);
			}
			case PropField_String_T:
			{
				if(args < 1 || args > 2)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szElement, sizeof(szElement));

				int element = StringToInt(szElement);
				
				char string[256];
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Data, prop, value, sizeof(value), element);
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintString(client, string, value, replySource);
			}
			case PropField_Vector:
			{
				if(args < 1 || args > 2)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szElement, sizeof(szElement));

				int element = StringToInt(szElement);
				
				char string[256];
				float value[3];
				GetEntPropVector(entity, Prop_Data, prop, value, element);
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintVector(client, string, "X", "Y", "Z", value, replySource);
			}
			case PropField_Entity:
			{
				if(args < 1 || args > 2)
				{
					char message[256];
					Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <element=0>", EU_PREFIX);
					ReplyToCommandColor(client, message, replySource);
					return Plugin_Handled;
				}
				
				if(args > 1) GetCmdArg(2, szElement, sizeof(szElement));
			
				int element = StringToInt(szElement);
				
				char string[256];
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintInt(client, string, GetEntPropEnt(entity, Prop_Data, prop, element), replySource);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Command_KillAll(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	int count = 0;
	int unownedCount = 0;
	for (int i = 0; i <= MaxClients; i++)
	{
		for (int j = 0; j < g_hEntities[i].Length; j++)
		{
			int ent = EntRefToEntIndex(g_hEntities[i].Get(j));
			if(ent != INVALID_ENT_REFERENCE)
			{
				AcceptEntityInput(ent, "Kill");
				count++;
			}
		}	
		g_hEntities[i].Clear();
	}
	
	for (int i = 0; i < g_hUnownedEntities.Length; i++)
	{
		int ent = EntRefToEntIndex(g_hUnownedEntities.Get(i));
		if(ent != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(ent, "Kill");
			unownedCount++;
		}
	}
	
	g_hUnownedEntities.Clear();
	
	if(count == 0)
	{
		char message[256];
		Format(message, sizeof(message), "%s There are no player spawned entities", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
	}
	else
	{
		char message[256];
		Format(message, sizeof(message), "%s Removed \x04%d\x09 player owned entities", EU_PREFIX, count);
		ReplyToCommandColor(client, message, replySource);
		Format(message, sizeof(message), "%s Removed \x04%d\x09 player unowned entities", EU_PREFIX, unownedCount);
		ReplyToCommandColor(client, message, replySource);
		Format(message, sizeof(message), "%s Total: \x04%d\x09", EU_PREFIX, unownedCount + count);
		ReplyToCommandColor(client, message, replySource);
	}
	return Plugin_Handled;
}

public Action Command_KillMy(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	int count = 0;
	for (int i = 0; i < g_hEntities[client].Length; i++)
	{
		int ent = EntRefToEntIndex(g_hEntities[client].Get(i));
		if(ent != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(ent, "Kill");
			count++;
		}
	}
	
	g_hEntities[client].Clear();

	if(count == 0)
	{
		char message[256];
		Format(message, sizeof(message), "%s There are no player spawned entities", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
	}
	else
	{
		char message[256];
		Format(message, sizeof(message), "%s Removed \x04%d\x09 entities", EU_PREFIX, count);
		ReplyToCommandColor(client, message, replySource);
	}
	return Plugin_Handled;
}


public Action Command_KillUnowned(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	int count = 0;
	for (int i = 0; i < g_hUnownedEntities.Length; i++)
	{
		int ent = EntRefToEntIndex(g_hUnownedEntities.Get(i));
		if(ent != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(ent, "Kill");
			count++;
		}
	}
	
	g_hUnownedEntities.Clear();

	if(count == 0)
	{
		char message[256];
		Format(message, sizeof(message), "%s There are no unowned entities", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
	}
	else
	{
		char message[256];
		Format(message, sizeof(message), "%s Removed \x04%d\x09 entities", EU_PREFIX, count);
		ReplyToCommandColor(client, message, replySource);
	}
	return Plugin_Handled;
}

public Action Command_EntCount(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
		
	if(args != 1)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_count <classname>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}	
	
	int count = 0;
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
		
	int iEnt = INVALID_ENT_REFERENCE;
	while((iEnt = FindEntityByClassname(iEnt, arg)) != -1)
	{
		if(iEnt < 0 || !IsValidEntity(iEnt))
			continue;
			
		char classname[65];
		GetEntityClassname(iEnt, classname, sizeof(classname));
		if(StrEqual(classname, arg, false))
			count++;
	}
	
	char message[256];
	Format(message, sizeof(message), "%s Found \x04%d\x09 entities with class name '\x04%s\x09'", EU_PREFIX, count, arg);
	ReplyToCommandColor(client, message, replySource);
	return Plugin_Handled;
}

public Action Command_EntList(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
		
	if(args != 1)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_list <#userid|client>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}	
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int target = FindTarget(client, arg, true, true);
	if(!IsValidClient(target))
	{
		ReplyToTargetError(client, target);
		return Plugin_Handled;
	}
	
	PrintClientEntities(client, target, replySource);

	return Plugin_Handled;
}

// OTHER
public bool TraceFilterNotSelf(int entityhit, int mask, any entity)
{
	if(entity == 0 && entityhit != entity)
		return true;
	
	return false;
}

// STOCKS
/*
enum PropType
{
	Prop_Send = 0,	< This property is networked. 
	Prop_Data = 1,	< This property is for save game data fields. 
};
*/

stock int StringToPropType(const char[] proptype)
{
	if(StrEqual(proptype, "prop_send", false))
		return 0;
	else if(StrEqual(proptype, "prop_data", false))
		return 1;
	return -1;
}

stock int GetClientBySteamID64(const char[] steamid64)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		char authid[32];
		GetClientAuthId(i, AuthId_SteamID64, authid, sizeof(authid));
		
		if(StrEqual(authid, steamid64, false))
			return i;
	}
	
	return INVALID_ENT_REFERENCE;
}

stock bool IsValidClient(int client)
{
	if(client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client))
			return true;
	}
	return false;
}

stock void PrintClientEntities(int client, int target, ReplySource source)
{
	int count = 0;
	char message[256], classname[65];
	Format(message, sizeof(message), "%s %N\'s entities:", EU_PREFIX, target);
	ReplyToCommandColor(client, message, source);
	switch(source)
	{
		case SM_REPLY_TO_CONSOLE:
		{
			for (int i = 0; i < g_hEntities[target].Length; i++)
			{
				int ent = EntRefToEntIndex(g_hEntities[target].Get(i));
				GetEntityClassname(ent, classname, sizeof(classname));
				PrintToConsole(client, "%s %s [ Ent Index: %d ] [ Ent Ref: %d ]", EU_PREFIX_CONSOLE, classname, ent, g_hEntities[target].Get(i));
				count++;
			}
			
		}
		case SM_REPLY_TO_CHAT:
		{
			for (int i = 0; i < g_hEntities[target].Length; i++)
			{
				int ent = EntRefToEntIndex(g_hEntities[target].Get(i));
				GetEntityClassname(ent, classname, sizeof(classname));
				PrintToChat(client, "%s \x04%s\x09 [ Ent Index: \x04%d\x09 ] [ Ent Ref: \x04%d\x09 ]", EU_PREFIX, classname, ent, g_hEntities[target].Get(i));
				count++;
			}
		}
	}

	Format(message, sizeof(message), "%s Entity count: \x04%d\x09", EU_PREFIX, count);
	ReplyToCommandColor(client, message, source);
}

stock void ReplyToCommandColor(int client, const char[] message, ReplySource source)
{
	char szTemp[256];
	Format(szTemp, sizeof(szTemp), message);
	ReplaceString(szTemp, sizeof(szTemp), "\x04", "", false);
	ReplaceString(szTemp, sizeof(szTemp), "\x09", "", false);
	ReplaceString(szTemp, sizeof(szTemp), "\x0C", "", false);
	TrimString(szTemp);
	switch(source)
	{
		case SM_REPLY_TO_CONSOLE:
		{
			PrintToConsole(client, szTemp);
		}
		case SM_REPLY_TO_CHAT:
		{
			PrintToChat(client, message);
		}
	}
}

stock void PrintInt(int client, const char[] key, int value, ReplySource source)
{
	switch(source)
	{
		case SM_REPLY_TO_CONSOLE:
		{
			PrintToConsole(client, "%s [ %s: %d ]", EU_PREFIX_CONSOLE, key, value);
		}
		case SM_REPLY_TO_CHAT:
		{
			PrintToChat(client, "%s [ %s: \x04%d\x09 ]", EU_PREFIX, key, value);
		}
	}
}

stock void PrintFloat(int client, const char[] key, float value, ReplySource source)
{
	switch(source)
	{
		case SM_REPLY_TO_CONSOLE:
		{
			PrintToConsole(client, "%s [ %s: %f ]", EU_PREFIX_CONSOLE, key, value);
		}
		case SM_REPLY_TO_CHAT:
		{
			PrintToChat(client, "%s [ %s: \x04%f\x09 ]", EU_PREFIX, key, value);
		}
	}
}

stock void PrintString(int client, const char[] key, const char[] value, ReplySource source)
{
	switch(source)
	{
		case SM_REPLY_TO_CONSOLE:
		{
			PrintToConsole(client, "%s [ %s: %s ]", EU_PREFIX_CONSOLE, key, value);
		}
		case SM_REPLY_TO_CHAT:
		{
			PrintToChat(client, "%s [ %s: \x04%s\x09 ]", EU_PREFIX, key, value);
		}
	}
}

stock void PrintVector(int client, const char[] key, const char[] key1, const char[] key2, const char[] key3, float vec[3], ReplySource source)
{
	switch(source)
	{
		case SM_REPLY_TO_CONSOLE:
		{
			if(g_PrintPreciseVectors.BoolValue)
			{
				PrintToConsole(client, "%s [ %s %s: %f ]", EU_PREFIX_CONSOLE, key, key1, vec[0]);
				PrintToConsole(client, "%s [ %s %s: %f ]", EU_PREFIX_CONSOLE, key, key2, vec[1]);
				PrintToConsole(client, "%s [ %s %s: %f ]", EU_PREFIX_CONSOLE, key, key3, vec[2]);
			}
			else
			{
				PrintToConsole(client, "%s [ %s: %.2f %.2f %.2f ]", EU_PREFIX_CONSOLE, key, vec[0], vec[1], vec[2]);
			}
		}
		case SM_REPLY_TO_CHAT:
		{
			if(g_PrintPreciseVectors.BoolValue)
			{
				PrintToChat(client, "%s [ %s \x07%s: %f\x09 ]", EU_PREFIX, key, key1, vec[0]);
				PrintToChat(client, "%s [ %s \x04%s: %f\x09 ]", EU_PREFIX, key, key2, vec[1]);
				PrintToChat(client, "%s [ %s \x0C%s: %f\x09 ]", EU_PREFIX, key, key3, vec[2]);
			}
			else
			{
				PrintToChat(client, "%s [ %s: \x07%.2f \x04%.2f \x0C%.2f\x09 ]", EU_PREFIX, key, vec[0], vec[1], vec[2]);
			}
		}
	}
	
}

stock int HasSelectedEntity(int client)
{
	int ent = EntRefToEntIndex(g_iSelectedEnt[client]);
	if(ent != INVALID_ENT_REFERENCE)
		return ent;
		
	g_iSelectedEnt[client] = INVALID_ENT_REFERENCE;
	return INVALID_ENT_REFERENCE;
}

stock void SelectEntity(int client, int entity, bool world = false, ReplySource replySource)
{
	if((entity < 0 || !IsValidEntity(entity)) || (!world && entity == 0)) // Do not select world
	{
		char message[256];
		Format(message, sizeof(message), "%s Invalid entity selected!", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}

	g_iSelectedEnt[client] = EntIndexToEntRef(entity);
	PrintSelectedEntity(client, replySource);
}

stock void PrintSelectedEntity(int client, ReplySource replySource)
{
	int ent = EntRefToEntIndex(g_iSelectedEnt[client]);
	float entPos[3], entAngles[3];
	GetEntPropVector(ent, Prop_Data, "m_vecOrigin", entPos);
	GetEntPropVector(ent, Prop_Data, "m_angRotation", entAngles);
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(ent, className, sizeof(className));
	char message[256];
	Format(message, sizeof(message), "%s Selected entity: '\x04%s\x09'", EU_PREFIX, className);
	ReplyToCommandColor(client, message, replySource);
	if(IsValidClient(ent))
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(ent, name, sizeof(name));
		PrintString(client, "Steam Name", name, replySource);
	}
	
	PrintVector(client, "Position", "X", "Y", "Z", entPos, replySource);
	PrintVector(client, "Angles", "X", "Y", "Z", entAngles, replySource);
	PrintInt(client, "Entity Index", ent, replySource);
	PrintInt(client, "Entity Reference", g_iSelectedEnt[client], replySource);

}

// FORWARDS
public void OnClientDisconnect(int client)
{
	if(g_DestroyEntsOnDisconnect.BoolValue)
	{
		for (int i = 0; i < g_hEntities[client].Length; i++)
		{
			int ent = EntRefToEntIndex(g_hEntities[client].Get(i));
			if(ent != INVALID_ENT_REFERENCE)
				AcceptEntityInput(ent, "Kill");
		}
	}
	else
	{
		for (int i = 0; i < g_hEntities[client].Length; i++)
			g_hUnownedEntities.Push(g_hEntities[client].Get(i));
	}
	g_hEntities[client].Clear();
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;
		
	char authid[32];
	GetClientAuthId(client, AuthId_SteamID64, authid, sizeof(authid));
	int iEnt = MAXPLAYERS + 1;
	char targetName[32];
	while((iEnt = FindEntityByClassname(iEnt, "*")) != -1)
	{
		if(iEnt < MAXPLAYERS + 1 || !IsValidEntity(iEnt))
			continue;
		
		int ref = EntIndexToEntRef(iEnt);
		GetEntPropString(iEnt, Prop_Data, "m_iName", targetName, sizeof(targetName));
		if(StrContains(targetName, EU_ENTITY_SPAWN_NAME, false) != -1)
		{
			char szTempArray[2][64];
			ExplodeString(targetName, ";", szTempArray, 2, sizeof(szTempArray[]));
			if(StrEqual(authid, szTempArray[1], false))
				g_hEntities[client].Push(ref);

			int index = -1;
			if((index = g_hUnownedEntities.FindValue(ref)) != -1)
				g_hUnownedEntities.Erase(index);
				
		}	
	}
}

public void OnMapStart()
{
	for (int i = 0; i <= MaxClients; i++)
		g_hEntities[i].Clear();

	g_hUnownedEntities.Clear();
}