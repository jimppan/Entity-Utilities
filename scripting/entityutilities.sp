#pragma semicolon 1

#define EU_CMD_CREATE_ENTITY 	"sm_ent_create"
#define EU_CMD_KEYVALUE 		"sm_ent_keyvalue"
#define EU_CMD_KEYVALUE_FLOAT 	"sm_ent_keyvaluefloat"
#define EU_CMD_KEYVALUE_VECTOR 	"sm_ent_keyvaluevector"
#define EU_CMD_SPAWN 			"sm_ent_spawn"

#define EU_CMD_VARIANT			"sm_ent_variant"
#define EU_CMD_VARIANT_CLEAR	"sm_ent_variant_clear"
#define EU_CMD_INPUT 			"sm_ent_input"

#define EU_CMD_SCRIPT 			"sm_ent_script"
#define EU_CMD_SCRIPT_RELOAD 	"sm_ent_script_reload"
#define EU_CMD_SCRIPT_RECORD 	"sm_ent_script_record"
#define EU_CMD_SCRIPT_SAVE		"sm_ent_script_save"
#define EU_CMD_SCRIPT_CLEAR		"sm_ent_script_clear"
#define EU_CMD_SCRIPT_DELETE	"sm_ent_script_delete"
#define EU_CMD_SCRIPT_LIST		"sm_ent_script_list"

#define EU_CMD_POSITION 		"sm_ent_position"
#define EU_CMD_ANGLES 			"sm_ent_angles"
#define EU_CMD_VELOCITY 		"sm_ent_velocity"

#define EU_CMD_SELECTED 		"sm_ent_selected"
#define EU_CMD_SELECT 			"sm_ent_select"
#define EU_CMD_SELECT_INDEX 	"sm_ent_select_index"
#define EU_CMD_SELECT_REF 		"sm_ent_select_ref"
#define EU_CMD_SELECT_SELF 		"sm_ent_select_self"
#define EU_CMD_SELECT_WORLD 	"sm_ent_select_world"

#define EU_CMD_WATCH 			"sm_ent_watch"
#define EU_CMD_UNWATCH 			"sm_ent_unwatch"
#define EU_CMD_WATCH_CLEAR 		"sm_ent_watch_clear"
#define EU_CMD_WATCH_LIST		"sm_ent_watch_list"

#define EU_CMD_SET_PROP 		"sm_ent_setprop"
#define EU_CMD_GET_PROP 		"sm_ent_getprop"

#define EU_CMD_KILL_ALL 		"sm_ent_killall"
#define EU_CMD_KILL_MY 			"sm_ent_killmy"
#define EU_CMD_KILL_UNOWNED 	"sm_ent_killunowned"

#define EU_CMD_LIST				"sm_ent_list"
#define EU_CMD_COUNT 			"sm_ent_count"

#define EU_MAX_ENT 64
#define EU_PROP_INVALID -1
#define EU_PROP_SEND 0
#define EU_PROP_DATA 1
#define EU_INVALID_PROP_SEND_OFFSET -1
#define EU_INVALID_PROP_DATA_OFFSET -1
#define EU_INVALID_PROP_INDEX -1
#define EU_INVALID_VARIANT "INVALID_VARIANT"
#define EU_MAX_WATCHED_PROPS 32
#define EU_MAX_PROP_NAME_SIZE 32
#define EU_ENTITY_SPAWN_NAME "eu_entity"
#define EU_PREFIX " \x09[\x04EU\x09]"
#define EU_PREFIX_CONSOLE "[EU]"
#define EU_CONFIG_FILE "entityutilities.cfg"

#define PLUGIN_AUTHOR "Rachnus"
#define PLUGIN_VERSION "1.16"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

enum //EntityPropInfo
{
	ENTITY_PROP_SEND = 0,
	ENTITY_PROP_DATA,
	ENTITY_REFERENCE,
	ENTITY_PROPERTY_TYPE,
	ENTITY_SIZE,
	ENTITY_ELEMENT,
	ENTITY_REPLY_SOURCE,
	ENTITY_PREVIOUS_SEND_VALUE,
	ENTITY_PREVIOUS_DATA_VALUE,
	
	ENTITY_PROPERTY,
	ENTITY_MAX
}

KeyValues g_hScripts;

ArrayList g_hWatchedPropStrings[MAXPLAYERS + 1];
ArrayList g_hWatchedProps[MAXPLAYERS + 1];
ArrayList g_hRecordedScript[MAXPLAYERS + 1];
bool g_bRecording[MAXPLAYERS + 1] =  { false, ... };

ArrayList g_hEntities[MAXPLAYERS + 1];
ArrayList g_hUnownedEntities;
int g_iSelectedEnt[MAXPLAYERS + 1] =  { INVALID_ENT_REFERENCE, ... };

ConVar g_DestroyEntsOnDisconnect;
ConVar g_PrintPreciseVectors;

char g_szVariantString[PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name = "Entity Utilities v1.16",
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
	
	RegAdminCmd(EU_CMD_CREATE_ENTITY, Command_EntCreate, ADMFLAG_ROOT, "Creates an entity");
	RegAdminCmd(EU_CMD_KEYVALUE, Command_EntKeyValue, ADMFLAG_ROOT, "Dispatch a keyvalue to an entity (Used before spawning)");
	RegAdminCmd(EU_CMD_KEYVALUE_FLOAT, Command_EntKeyValueFloat, ADMFLAG_ROOT, "Dispatch a float keyvalue to an entity (Used before spawning)");
	RegAdminCmd(EU_CMD_KEYVALUE_VECTOR, Command_EntKeyValueVector, ADMFLAG_ROOT, "Dispatch a vector keyvalue to an entity (Used before spawning)");
	RegAdminCmd(EU_CMD_SPAWN, Command_EntSpawn, ADMFLAG_ROOT, "Spawns the entity");
	
	RegAdminCmd(EU_CMD_VARIANT, Command_EntVariant, ADMFLAG_ROOT, "Set Variant String");
	RegAdminCmd(EU_CMD_VARIANT_CLEAR, Command_EntVariantClear, ADMFLAG_ROOT, "Clear Variant String");
	RegAdminCmd(EU_CMD_INPUT, Command_EntInput, ADMFLAG_ROOT, "Accept Entity Input");
	
	RegAdminCmd(EU_CMD_SCRIPT, Command_EntScript, ADMFLAG_ROOT, "Execute multiple lines of command with a help of a script found in configs/entityutilities.cfg");
	RegAdminCmd(EU_CMD_SCRIPT_RELOAD, Command_EntScriptReload, ADMFLAG_ROOT, "Reloads scripts (configs/entityutilities.cfg)");
	RegAdminCmd(EU_CMD_SCRIPT_RECORD, Command_EntScriptRecord, ADMFLAG_ROOT, "Starts recording all commands executed by this plugin");
	RegAdminCmd(EU_CMD_SCRIPT_SAVE, Command_EntScriptSave, ADMFLAG_ROOT, "Saves recorded script to configs/entityutilities.cfg");
	RegAdminCmd(EU_CMD_SCRIPT_CLEAR, Command_EntScriptClear, ADMFLAG_ROOT, "Clears the current recording");
	RegAdminCmd(EU_CMD_SCRIPT_DELETE, Command_EntScriptDelete, ADMFLAG_ROOT, "Delete existing script from configs/entityutilities.cfg");
	RegAdminCmd(EU_CMD_SCRIPT_LIST, Command_EntScriptList, ADMFLAG_ROOT, "List all existing scripts in configs/entityutilities.cfg");
	
	RegAdminCmd(EU_CMD_POSITION, Command_EntPosition, ADMFLAG_ROOT, "Sets position of selected entity to aim (Position can be passed as arguments as 3 floats)");
	RegAdminCmd(EU_CMD_ANGLES, Command_EntAngles, ADMFLAG_ROOT, "Sets angles of selected entity to aim (Angles can be passed as arguments as 3 floats)");
	RegAdminCmd(EU_CMD_VELOCITY, Command_EntVelocity, ADMFLAG_ROOT, "Sets velocity of selected entity, passed by argument as 3 floats");
	
	RegAdminCmd(EU_CMD_SELECTED, Command_EntSelected, ADMFLAG_ROOT, "Prints generic information about selected entity");
	RegAdminCmd(EU_CMD_SELECT, Command_EntSelect, ADMFLAG_ROOT, "Select an entity at aim (Selects by name if argument is passed)");
	RegAdminCmd(EU_CMD_SELECT_INDEX, Command_EntSelectIndex, ADMFLAG_ROOT, "Select an entity by entity index");
	RegAdminCmd(EU_CMD_SELECT_REF, Command_EntSelectRef, ADMFLAG_ROOT, "Select an entity by entity reference");
	RegAdminCmd(EU_CMD_SELECT_SELF, Command_EntSelectSelf, ADMFLAG_ROOT, "Select your player");
	RegAdminCmd(EU_CMD_SELECT_WORLD, Command_EntSelectWorld, ADMFLAG_ROOT, "Select the world (Entity 0)");
	
	RegAdminCmd(EU_CMD_WATCH, Command_EntWatch, ADMFLAG_ROOT, "Prints to chat when prop passed by argument changes");
	RegAdminCmd(EU_CMD_UNWATCH, Command_EntUnwatch, ADMFLAG_ROOT, "Stops watching for prop");
	RegAdminCmd(EU_CMD_WATCH_CLEAR, Command_EntWatchClear, ADMFLAG_ROOT, "Clears all watched props");
	RegAdminCmd(EU_CMD_WATCH_LIST, Command_EntWatchList, ADMFLAG_ROOT, "List all props being watched");
	
	RegAdminCmd(EU_CMD_SET_PROP, Command_EntSetProp, ADMFLAG_ROOT, "Set property of an entity");
	RegAdminCmd(EU_CMD_GET_PROP, Command_EntGetProp, ADMFLAG_ROOT, "Print property of an entity");

	RegAdminCmd(EU_CMD_KILL_ALL, Command_KillAll, ADMFLAG_ROOT, "Kills all entities spawned by players");
	RegAdminCmd(EU_CMD_KILL_MY, Command_KillMy, ADMFLAG_ROOT, "Kills entities spawned by player using this command");
	RegAdminCmd(EU_CMD_KILL_UNOWNED, Command_KillUnowned, ADMFLAG_ROOT, "Kills entities spawned by players that disconnected");
	
	RegAdminCmd(EU_CMD_LIST, Command_EntList, ADMFLAG_ROOT, "Lists all entities owned by a client");
	RegAdminCmd(EU_CMD_COUNT, Command_EntCount, ADMFLAG_ROOT, "Prints amount of existing entities with classname passed as arg");
	
	Format(g_szVariantString, sizeof(g_szVariantString), EU_INVALID_VARIANT);
	
	for (int i = 0; i < MAXPLAYERS + 1; i++)
	{
		g_hEntities[i] = new ArrayList();
		g_hWatchedProps[i] = new ArrayList(ENTITY_MAX);
		g_hWatchedPropStrings[i] = new ArrayList(PLATFORM_MAX_PATH);
		g_hRecordedScript[i] = new ArrayList(PLATFORM_MAX_PATH);
	}
		
	g_hUnownedEntities = new ArrayList();
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
			OnClientPutInServer(i);
	}
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/%s", EU_CONFIG_FILE);
	g_hScripts = new KeyValues("Scripts");
	g_hScripts.ImportFromFile(path);
}

/************/
/* COMMANDS */
/************/
public Action Command_EntCreate(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s", command, arg);
		RecordScriptCommand(client, command);
	}
	
	CMDEntCreate(client, arg, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntSpawn(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	CMDEntSpawn(client, args, replySource);
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	return Plugin_Handled;
}

public Action Command_EntKeyValue(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char arg[65], arg2[65];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s %s", command, arg, arg2);
		RecordScriptCommand(client, command);
	}
	
	CMDEntKeyValue(client, arg, arg2, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntKeyValueFloat(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char arg[65], arg2[65];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s %s", command, arg, arg2);
		RecordScriptCommand(client, command);
	}
	
	float value = StringToFloat(arg2);
	CMDEntKeyValueFloat(client, arg, value, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntKeyValueVector(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char arg[65], arg2[65], arg3[65], arg4[65];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	GetCmdArg(4, arg4, sizeof(arg4));
	
	float value[3];
	value[0] = StringToFloat(arg2);
	value[1] = StringToFloat(arg3);
	value[2] = StringToFloat(arg4);
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s %s %s %s", command, arg, arg2, arg3, arg4);
		RecordScriptCommand(client, command);
	}
	
	CMDEntKeyValueVector(client, arg, value, args, replySource);
	
	return Plugin_Handled;
}

public Action Command_EntInput(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
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
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s %s %s %s", command, arg, arg2, arg3, arg4);
		RecordScriptCommand(client, command);
	}
	
	CMDEntInput(client, arg, activator, caller, outputid, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntScript(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char script[65];
	GetCmdArg(1, script, sizeof(script));
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s", command, script);
		RecordScriptCommand(client, command);
	}
	
	CMDEntScript(client, script, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntScriptReload(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	
	CMDEntScriptReload(client, args, replySource);	
	return Plugin_Handled;
}

public Action Command_EntScriptRecord(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	/* DO NOT RECORD THIS COMMAND
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	*/
	CMDEntScriptRecord(client, args, replySource);	
	return Plugin_Handled;
}

public Action Command_EntScriptSave(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char arg[65];
	GetCmdArgString(arg, sizeof(arg));
	/* DO NOT RECORD THIS COMMAND
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		Format(command, sizeof(command), "%s %s", command, arg);
		RecordScriptCommand(client, command);
	}
	*/
	
	CMDEntScriptSave(client, arg, args, replySource);	
	return Plugin_Handled;
}

public Action Command_EntScriptClear(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	/* DO NOT RECORD THIS COMMAND
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	*/
	CMDEntScriptClear(client, args, replySource);	
	return Plugin_Handled;
}

public Action Command_EntScriptDelete(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char arg[65];
	GetCmdArgString(arg, sizeof(arg));
	/* DO NOT RECORD THIS COMMAND
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		Format(command, sizeof(command), "%s %s", command, arg);
		RecordScriptCommand(client, command);
	}
	*/
	CMDEntScriptDelete(client, arg, args, replySource);	
	return Plugin_Handled;
}

public Action Command_EntScriptList(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		Format(command, sizeof(command), "%s %s", command, arg);
		RecordScriptCommand(client, command);
	}
	
	CMDEntScriptList(client, arg, args, replySource);	
	return Plugin_Handled;
}

public Action Command_EntVariant(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();

	char arg[65];
	GetCmdArgString(arg, sizeof(arg));
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s", command, arg);
		RecordScriptCommand(client, command);
	}
	
	CMDEntVariant(client, arg, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntVariantClear(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	
	CMDEntVariantClear(client, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntPosition(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char arg[65], arg2[65], arg3[65];
	float value[3];
	
	if(args == 3)
	{
		GetCmdArg(1, arg, sizeof(arg));
		GetCmdArg(2, arg2, sizeof(arg2));
		GetCmdArg(3, arg3, sizeof(arg3));

		value[0] = StringToFloat(arg);
		value[1] = StringToFloat(arg2);
		value[2] = StringToFloat(arg3);
	}
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s %s %s", command, arg, arg2, arg3);
		RecordScriptCommand(client, command);
	}
	
	CMDEntPosition(client, value, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntAngles(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	char arg[65], arg2[65], arg3[65];
	float value[3];
	if(args == 3)
	{
		GetCmdArg(1, arg, sizeof(arg));
		GetCmdArg(2, arg2, sizeof(arg2));
		GetCmdArg(3, arg3, sizeof(arg3));
	
		value[0] = StringToFloat(arg);
		value[1] = StringToFloat(arg2);
		value[2] = StringToFloat(arg3);
	}
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s %s %s", command, arg, arg2, arg3);
		RecordScriptCommand(client, command);
	}
	
	CMDEntAngles(client, value, args, replySource);

	return Plugin_Handled;
}

public Action Command_EntVelocity(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();

	char arg[65], arg2[65], arg3[65];
	
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	
	float value[3];
	value[0] = StringToFloat(arg);
	value[1] = StringToFloat(arg2);
	value[2] = StringToFloat(arg3);
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s %s %s", command, arg, arg2, arg3);
		RecordScriptCommand(client, command);
	}
	
	CMDEntVelocity(client, value, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelect(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
		
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s", command, arg);
		RecordScriptCommand(client, command);
	}
		
	CMDEntSelect(client, arg, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelected(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	
	CMDEntSelected(client, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelectIndex(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s", command, arg);
		RecordScriptCommand(client, command);
	}
	
	int entity = StringToInt(arg);
	CMDEntSelectIndex(client, entity, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelectRef(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	int ref = StringToInt(arg);
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s", command, arg);
		RecordScriptCommand(client, command);
	}
	
	CMDEntSelectRef(client, ref, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelectSelf(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	
	CMDEntSelectSelf(client, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntSelectWorld(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	
	CMDEntSelectWorld(client, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntWatch(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char prop[65], szSize[65], szElement[65];
	GetCmdArg(1, prop, sizeof(prop));
	
	int size = 4;
	int element = 0;
	
	if(args > 1) 
	{
		GetCmdArg(2, szSize, sizeof(szSize));
		size = StringToInt(szSize);
	}
	
	if(args > 2) 
	{
		GetCmdArg(3, szElement, sizeof(szElement));
		element = StringToInt(szElement);
	}
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s %d %d", command, prop, size, element);
		RecordScriptCommand(client, command);
	}
	
	CMDEntWatch(client, prop, size, element, args, replySource);
	
	return Plugin_Handled;
}

public Action Command_EntUnwatch(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char prop[65], szSize[65], szElement[65];
	GetCmdArg(1, prop, sizeof(prop));
	
	int size = 4;
	int element = 0;
	
	if(args > 1)
	{
		GetCmdArg(2, szSize, sizeof(szSize));
		size = StringToInt(szSize);
	}
	
	if(args > 2) 
	{
		GetCmdArg(3, szElement, sizeof(szElement));
		element = StringToInt(szElement);
	}
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s %d %d", command, prop, size, element);
		RecordScriptCommand(client, command);
	}
	
	CMDEntUnwatch(client, prop, size, element, args, replySource);
	
	return Plugin_Handled;
}

public Action Command_EntWatchClear(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	
	CMDEntWatchClear(client, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntWatchList(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	
	CMDEntWatchList(client, args, replySource);
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
	int size = 4;
	int element = 0;
	
	bool send = false;
	bool data = false;
	
	GetCmdArg(1, prop, sizeof(prop));
	
	PropFieldType sendFieldType = PropField_Unsupported;
	PropFieldType dataFieldType = PropField_Unsupported;
	PropFieldType finalFieldType = PropField_Unsupported;
	
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	if(FindSendPropInfo(className, prop, sendFieldType) != EU_INVALID_PROP_SEND_OFFSET)
		send = true;
		
	if(FindDataMapInfo(entity, prop, dataFieldType) != EU_INVALID_PROP_DATA_OFFSET)
		data = true;
	
	if(!send && !data)
	{
		char message[256];
		Format(message, sizeof(message), "%s Could not find prop '\x04%s\x09'", EU_PREFIX, prop);
		ReplyToCommandColor(client, message, replySource);
		return Plugin_Handled;
	}
	
	finalFieldType = view_as<PropFieldType>(max(view_as<int>(sendFieldType), view_as<int>(dataFieldType)));
	if(finalFieldType == PropField_Vector)
	{
		if(args < 4 || args > 6)
		{
			char message[256];
			Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property> <value1> <value2> <value3> <size=4> <element=0>", EU_PREFIX);
			ReplyToCommandColor(client, message, replySource);
			return Plugin_Handled;
		}
		
		if(args > 4)
		{
			GetCmdArg(5, szSize, sizeof(szSize));
			size = StringToInt(szSize);
		}
		
		if(args > 5)
		{
			GetCmdArg(6, szElement, sizeof(szElement));
			element = StringToInt(szElement);
		}
		
		GetCmdArg(2, szValue1, sizeof(szValue1));
		GetCmdArg(3, szValue2, sizeof(szValue2));
		GetCmdArg(4, szValue3, sizeof(szValue3));
		
		if(g_bRecording[client])
		{
			char command[PLATFORM_MAX_PATH];
			GetCmdArg(0, command, sizeof(command));
			
			Format(command, sizeof(command), "%s %s %s %s %s %d %d", command, prop, szValue1, szValue2, szValue3, size, element);
			RecordScriptCommand(client, command);
		}
		
		CMDEntSetProp(client, prop, szValue1, szValue2, szValue3, size, element, args, replySource);
	}
	else
	{
		if(args < 2 || args > 4)
		{
			char message[256];
			Format(message, sizeof(message), "%s Usage \x04sm_ent_setprop <property> <value> <size=4> <element=0>", EU_PREFIX);
			ReplyToCommandColor(client, message, replySource);
			return Plugin_Handled;
		}
		
		if(args > 2)
		{
			GetCmdArg(3, szSize, sizeof(szSize));
			size = StringToInt(szSize);
		}
		
		if(args > 3)
		{
			GetCmdArg(4, szElement, sizeof(szElement));
			element = StringToInt(szElement);
		}
		
		GetCmdArg(2, szValue1, sizeof(szValue1));
		
		if(g_bRecording[client])
		{
			char command[PLATFORM_MAX_PATH];
			GetCmdArg(0, command, sizeof(command));
			
			Format(command, sizeof(command), "%s %s %s %d %d", command, prop, szValue1, size, element);
			RecordScriptCommand(client, command);
		}
		
		CMDEntSetProp(client, prop, szValue1, szValue2, szValue3, size, element, args, replySource);
	}
	
	return Plugin_Handled;
}

public Action Command_EntGetProp(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	int size = 4;
	int element = 0;
	
	char prop[65], szSize[65], szElement[65];
	GetCmdArg(1, prop, sizeof(prop));
	if(args > 1) 
	{
		GetCmdArg(2, szSize, sizeof(szSize));
		size = StringToInt(szSize);
	}
	if(args > 2) 
	{
		GetCmdArg(3, szElement, sizeof(szElement));
		element = StringToInt(szElement);
	}
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s %d %d", command, prop, size, element);
		RecordScriptCommand(client, command);
	}
	
	CMDEntGetProp(client, prop, size, element, args, replySource);

	return Plugin_Handled;
}

public Action Command_KillAll(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	
	CMDKillAll(client, args, replySource);
	return Plugin_Handled;
}

public Action Command_KillMy(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	
	CMDKillMy(client, args, replySource);
	return Plugin_Handled;
}

public Action Command_KillUnowned(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		RecordScriptCommand(client, command);
	}
	
	CMDKillUnowned(client, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntCount(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s", command, arg);
		RecordScriptCommand(client, command);
	}
	
	CMDEntCount(client, arg, args, replySource);
	return Plugin_Handled;
}

public Action Command_EntList(int client, int args)
{
	ReplySource replySource = GetCmdReplySource();
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	if(g_bRecording[client])
	{
		char command[PLATFORM_MAX_PATH];
		GetCmdArg(0, command, sizeof(command));
		
		Format(command, sizeof(command), "%s %s", command, arg);
		RecordScriptCommand(client, command);
	}
	
	CMDEntList(client, arg, args, replySource);

	return Plugin_Handled;
}

/*********/
/* OTHER */
/*********/
public bool TraceFilterNotSelf(int entityhit, int mask, any entity)
{
	if(entity == 0 && entityhit != entity)
		return true;
	
	return false;
}

/******************/
/* STOCK COMMANDS */
/******************/

stock void CMDEntCreate(int client, const char[] classname, int args, ReplySource replySource)
{
	if(args == 0)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_create <classname>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	if(g_hEntities[client].Length >= EU_MAX_ENT)
	{
		char message[256];
		Format(message, sizeof(message), "%s Exceeded max entity limit per player (\x04%d\x09)", EU_PREFIX, EU_MAX_ENT);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int entity = CreateEntityByName(classname);
	if(entity <= INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Could not spawn entity '\x04%s\x09'", EU_PREFIX, classname);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	int ref = EntIndexToEntRef(entity);
	g_hEntities[client].Push(ref);
	g_iSelectedEnt[client] = ref;
	
	char authid[32];
	GetClientAuthIdEx(client, AuthId_SteamID64, authid, sizeof(authid));
	
	char string[128];
	Format(string, sizeof(string), "%s;%s", EU_ENTITY_SPAWN_NAME, authid);
	
	DispatchKeyValue(entity, "targetname", string);

	char message[256];
	Format(message, sizeof(message), "%s Entity '\x04%s\x09' created!", EU_PREFIX, classname);
	ReplyToCommandColor(client, message, replySource);
	
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
}

stock void CMDEntKeyValue(int client, const char[] key, const char[] value, int args, ReplySource replySource)
{
	if(args != 2)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_keyvalue <keyname> <value>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	int ref = EntIndexToEntRef(entity);

	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	if(StrEqual(key, "model", false))
	{
		if(!IsModelPrecached(value))
			PrecacheModel(value);
	}
	
	DispatchKeyValue(entity, key, value);
	
	char message[256];
	Format(message, sizeof(message), "%s Set keyvalue '\x0C%s\x09' to '\x0C%s\x09'", EU_PREFIX, key, value);
	ReplyToCommandColor(client, message, replySource);
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
}

stock void CMDEntKeyValueFloat(int client, const char[] key, float value, int args, ReplySource replySource)
{
	if(args != 2)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_keyvaluefloat <keyname> <value>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	int ref = EntIndexToEntRef(entity);
	
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	DispatchKeyValueFloat(entity, key, value);
	
	char message[256];
	Format(message, sizeof(message), "%s Set keyvalue '\x0C%s\x09' to '\x0C%f\x09'", EU_PREFIX, key, value);
	ReplyToCommandColor(client, message, replySource);

	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
}

stock void CMDEntKeyValueVector(int client, const char[] key, float value[3], int args, ReplySource replySource)
{
	if(args != 4)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_keyvaluevector <keyname> <value1> <value2> <value3>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	int ref = EntIndexToEntRef(entity);

	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	DispatchKeyValueVector(entity, key, value);
	
	char message[256];
	Format(message, sizeof(message), "%s Set keyvalue '\x0C%s\x09' to:", EU_PREFIX, key);
	ReplyToCommandColor(client, message, replySource);
	PrintVector(client, key, "X", "Y", "Z", value, replySource);
	ReplyToCommandColor(client, " ", replySource);
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
}

stock void CMDEntSpawn(int client, int args, ReplySource replySource)
{
	float traceendPos[3], eyeAngles[3], eyePos[3];
	if(IsValidClient(client))
	{
		GetClientEyeAngles(client, eyeAngles);
		GetClientEyePosition(client, eyePos);
	
		Handle trace = TR_TraceRayFilterEx(eyePos, eyeAngles, MASK_ALL, RayType_Infinite, TraceFilterNotSelf, client);
		if(TR_DidHit(trace))
			TR_GetEndPosition(traceendPos, trace);
	
		delete trace;
	}
	else
	{
		traceendPos[0] = 0.0;
		traceendPos[1] = 0.0;
		traceendPos[2] = 0.0;
	}

	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
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
}

stock void CMDEntInput(int client, const char[] input, int activator, int caller, int outputid, int args, ReplySource replySource)
{
	if(args < 1 || args > 4)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_input <input> <activator> <caller> <outputid>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	int ref = EntIndexToEntRef(entity);
	
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	if(!StrEqual(g_szVariantString, EU_INVALID_VARIANT, false))
		SetVariantString(g_szVariantString);
		
	AcceptEntityInput(entity, input, activator, caller, outputid);
	
	char message[256];
	Format(message, sizeof(message), "%s Input '\x0C%s\x09' called", EU_PREFIX, input);
	ReplyToCommandColor(client, message, replySource);
		
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Activator", activator, replySource);
	PrintInt(client, "Caller", caller, replySource);
	PrintInt(client, "Output ID", outputid, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
}

stock void CMDEntScript(int client, const char[] script, int args, ReplySource replySource)
{
	if(args != 1)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_script <script>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	g_hScripts.Rewind();
	if(g_hScripts.JumpToKey(script))
	{
		
		int counter = 1;
		char command[PLATFORM_MAX_PATH];
		while(!StrEqual(command, "STOP", false))
		{
			char szCounter[16];
			IntToString(counter++, szCounter, sizeof(szCounter));
			g_hScripts.GetString(szCounter, command, sizeof(command), "STOP");
			if(!StrEqual(command, "STOP", false)) //confused
			{
				char commandArguments[8][PLATFORM_MAX_PATH];
   			 	ExplodeString(command, " ", commandArguments, sizeof(commandArguments), sizeof(commandArguments[]));
  				int argCount = GetStringCount(commandArguments, 8) - 1;
  				
	 			if(StrEqual(commandArguments[0], EU_CMD_CREATE_ENTITY, false))				//sm_ent_create <classname(string>
	 			{
					if(argCount == 1) 
						CMDEntCreate(client, commandArguments[1], argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_KEYVALUE, false))				//sm_ent_keyvalue <key(string> <value(string)>
	 			{
					if(argCount == 2) 
						CMDEntKeyValue(client, commandArguments[1], commandArguments[2], argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_KEYVALUE_FLOAT, false))		//sm_ent_keyvaluefloat <key(string> <value(float)>
	 			{
					if(argCount == 2) 
						CMDEntKeyValueFloat(client, commandArguments[1], StringToFloat(commandArguments[2]), argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_KEYVALUE_VECTOR, false))		//sm_ent_keyvaluevector <key(string)> <value1(float)> <value2(float)> <value3(float)>
	 			{
					if(argCount == 4) 
					{
						float vec[3];
						vec[0] = StringToFloat(commandArguments[2]);
						vec[1] = StringToFloat(commandArguments[3]);
						vec[2] = StringToFloat(commandArguments[4]);
						CMDEntKeyValueVector(client, commandArguments[1], vec, argCount, replySource);
					}
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SPAWN, false))					//sm_ent_spawn
	 			{
					CMDEntSpawn(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_VARIANT, false))				//sm_ent_variant <variant(string)[optional]>
	 			{
					CMDEntVariant(client, commandArguments[1], argCount, replySource);	
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_VARIANT_CLEAR, false))			//sm_ent_variant_clear
	 			{
					CMDEntVariantClear(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_INPUT, false))					//sm_ent_input <input(string)> <activator(int)[optional]> <caller(int)[optional]> <outputid(int)[optional]> 
	 			{
					if(argCount > 0 && argCount < 5) 
						CMDEntInput(client, commandArguments[1], StringToInt(commandArguments[2]), StringToInt(commandArguments[3]), StringToInt(commandArguments[4]), argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT, false))				//sm_ent_script <script(string)>
	 			{
					if(argCount == 1)
						CMDEntScript(client, commandArguments[1], argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_RELOAD, false))			//sm_ent_script_reload
	 			{
	 				CMDEntScriptReload(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_RECORD, false))			//sm_ent_script_record
	 			{
	 				CMDEntScriptRecord(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_SAVE, false))			//sm_ent_script_save <name(string)>
	 			{
	 				if(argCount == 1)
	 					CMDEntScriptSave(client, commandArguments[1], argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_CLEAR, false))			//sm_ent_script_clear
	 			{
	 				CMDEntScriptClear(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_DELETE, false))			//sm_ent_script_delete <name(string)>
	 			{
	 				if(argCount == 1)
	 					CMDEntScriptDelete(client, commandArguments[1], argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_LIST, false))			//sm_ent_script_list
	 			{
	 				CMDEntScriptList(client, commandArguments[1], argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_POSITION, false))				//sm_ent_position <value1(float)[optional]> <value2(float)[optional]> <value3(float)[optional]>
	 			{
					float vec[3];
					vec[0] = StringToFloat(commandArguments[1]);
					vec[1] = StringToFloat(commandArguments[2]);
					vec[2] = StringToFloat(commandArguments[3]);
					CMDEntPosition(client, vec, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_ANGLES, false))				//sm_ent_angles <value1(float)[optional]> <value2(float)[optional]> <value3(float)[optional]>
	 			{
	 				float vec[3];
					vec[0] = StringToFloat(commandArguments[1]);
					vec[1] = StringToFloat(commandArguments[2]);
					vec[2] = StringToFloat(commandArguments[3]);
					CMDEntAngles(client, vec, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_VELOCITY, false))				//sm_ent_velocity <value1(float)> <value2(float)> <value3(float)>
	 			{
	 				if(argCount == 3)
					{
						float vec[3];
						vec[0] = StringToFloat(commandArguments[1]);
						vec[1] = StringToFloat(commandArguments[2]);
						vec[2] = StringToFloat(commandArguments[3]);
						CMDEntVelocity(client, vec, argCount, replySource);
					}
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SELECTED, false))				//sm_ent_selected
	 			{
	 				CMDEntSelected(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SELECT, false))				//sm_ent_select <name(string)[optional]>
	 			{
	 				CMDEntSelect(client, commandArguments[1], argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SELECT_INDEX, false))			//sm_ent_select_index <index(int)>
	 			{
	 				if(argCount == 1) 
						CMDEntSelectIndex(client, StringToInt(commandArguments[1]), argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SELECT_REF, false))			//sm_ent_select_ref <reference(int)>
	 			{
	 				if(argCount == 1)
						CMDEntSelectRef(client, StringToInt(commandArguments[1]), argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SELECT_SELF, false))			//sm_ent_select_self
	 			{
					CMDEntSelectSelf(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SELECT_WORLD, false))			//sm_ent_select_world
	 			{
					CMDEntSelectWorld(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_WATCH, false))					//sm_ent_watch <prop(string)> <size(int)[optional]> <element(int)[optional]>
	 			{
	 				if(argCount > 0 && argCount < 4)
						CMDEntWatch(client, commandArguments[1], StringToInt(commandArguments[2]), StringToInt(commandArguments[3]), argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_UNWATCH, false))				//sm_ent_unwatch <prop(string)> <size(int)[optional]> <element(int)[optional]>
	 			{
	 				if(argCount > 0 && argCount < 4)
						CMDEntUnwatch(client, commandArguments[1], StringToInt(commandArguments[2]), StringToInt(commandArguments[3]), argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_WATCH_CLEAR, false))			//sm_ent_watch_clear
	 			{
	 				CMDEntWatchClear(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_WATCH_LIST, false))			//sm_ent_watch_list
	 			{
	 				CMDEntWatchList(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_SET_PROP, false))				//sm_ent_setprop <prop(string)> <value1(any)> <value2(float)[optional]> <value3(float)[optional]> <size(int)[optional]> <element(int)[optional]>
	 			{
	 				if(argCount > 0 && argCount < 7)
						CMDEntSetProp(client, commandArguments[1], commandArguments[2], commandArguments[3], commandArguments[4], StringToInt(commandArguments[5]), StringToInt(commandArguments[6]), argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_GET_PROP, false))				//sm_ent_getprop <prop(string)> <size(int)[optional]> <element(int)[optional]>
	 			{
	 				if(argCount > 0 && argCount < 4)
						CMDEntGetProp(client, commandArguments[1], StringToInt(commandArguments[1]), StringToInt(commandArguments[1]), argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_KILL_ALL, false))				//sm_ent_killall
	 			{
					CMDKillAll(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_KILL_MY, false))				//sm_ent_killmy
	 			{
					CMDKillMy(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_KILL_UNOWNED, false))			//sm_ent_killunowned
	 			{
					CMDKillUnowned(client, argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_LIST, false))					//sm_ent_list <#userid(int)|name(string)>
	 			{
					if(argCount == 1)
						CMDEntList(client, commandArguments[1], argCount, replySource);
	 			}
	 			else if(StrEqual(commandArguments[0], EU_CMD_COUNT, false))					//sm_ent_count <classname>
	 			{
					if(argCount == 1)
						CMDEntCount(client, commandArguments[1], argCount, replySource);
	 			}
			}
		}
		
		char message[256];
		Format(message, sizeof(message), "%s Script '\x04%s\x09' executed", EU_PREFIX, script);
		ReplyToCommandColor(client, message, replySource);
		return;
	}	

	char message[256];
	Format(message, sizeof(message), "%s Script '\x04%s\x09' could not be found", EU_PREFIX, script);
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntScriptReload(int client, int args, ReplySource replySource)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/%s", EU_CONFIG_FILE);
	g_hScripts = new KeyValues("Scripts");
	g_hScripts.ImportFromFile(path);

	char message[256];
	Format(message, sizeof(message), "%s Scripts reloaded!", EU_PREFIX);
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntScriptRecord(int client, int args, ReplySource replySource)
{
	g_bRecording[client] = true;
	char message[256];
	Format(message, sizeof(message), "%s Commands are now being recorded!", EU_PREFIX);
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntScriptSave(int client, const char[] name, int args, ReplySource replySource)
{
	if(args != 1)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_script_save <name>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	g_hScripts.Rewind();
	if(g_hScripts.JumpToKey(name, false))
	{
		char message[256];
		Format(message, sizeof(message), "%s Script '\x04%s\x09' already exists", EU_PREFIX, name);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	g_hScripts.JumpToKey(name, true);
	
	for (int i = 0; i < g_hRecordedScript[client].Length; i++)
	{
		char key[8], command[PLATFORM_MAX_PATH];
		Format(key, sizeof(key), "%d", i + 1);
		g_hRecordedScript[client].GetString(i, command, sizeof(command));
		g_hScripts.SetString(key, command);
	}
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/%s", EU_CONFIG_FILE);
	
	g_hScripts.Rewind();
	g_hScripts.ExportToFile(path);
	
	char message[256];
	Format(message, sizeof(message), "%s Script '\x04%s\x09' saved!", EU_PREFIX, name);
	g_bRecording[client] = false;
	g_hRecordedScript[client].Clear();
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntScriptClear(int client, int args, ReplySource replySource)
{
	g_hRecordedScript[client].Clear();

	char message[256];
	Format(message, sizeof(message), "%s Script recording cleared!", EU_PREFIX);
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntScriptDelete(int client, const char[] name, int args, ReplySource replySource)
{
	if(args != 1)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_script_delete <name>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	g_hScripts.Rewind();
	if(!g_hScripts.JumpToKey(name, false))
	{
		char message[256];
		Format(message, sizeof(message), "%s Script '\x04%s\x09' does not exist", EU_PREFIX, name);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	g_hScripts.DeleteThis();
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/%s", EU_CONFIG_FILE);
	
	g_hScripts.Rewind();
	g_hScripts.ExportToFile(path);
	
	char message[256];
	Format(message, sizeof(message), "%s Script '\x04%s\x09' deleted!", EU_PREFIX, name);
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntScriptList(int client, const char[] script, int args, ReplySource replySource)
{
	g_hScripts.Rewind();
	if(args != 1)
	{
		int count = 0;
		if(!g_hScripts.GotoFirstSubKey())
		{
			char message[256];
			Format(message, sizeof(message), "%s No scripts found", EU_PREFIX);
			ReplyToCommandColor(client, message, replySource);
			return;
		}
		
		do 
		{
			char name[PLATFORM_MAX_PATH];
			g_hScripts.GetSectionName(name, sizeof(name));
			char message[256];
			Format(message, sizeof(message), "%s \x04%s", EU_PREFIX, name);
			ReplyToCommandColor(client, message, replySource);
			count++;
			
		} while (g_hScripts.GotoNextKey());
		
		char message[256];
		Format(message, sizeof(message), "%s Total: \x04%d\x09", EU_PREFIX, count);
		ReplyToCommandColor(client, message, replySource);
		return;
	}

	if(!g_hScripts.JumpToKey(script))
	{
		char message[256];
		Format(message, sizeof(message), "%s Script '\x04%s\x09' does not exist", EU_PREFIX, script);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	char message[256];
	Format(message, sizeof(message), "%s Script '\x04%s\x09':", EU_PREFIX, script);
	ReplyToCommandColor(client, message, replySource);
	
	int counter = 1;
	char command[PLATFORM_MAX_PATH];
	while(!StrEqual(command, "STOP", false))
	{
		char szCounter[16];
		IntToString(counter++, szCounter, sizeof(szCounter));
		g_hScripts.GetString(szCounter, command, sizeof(command), "STOP");
		if(!StrEqual(command, "STOP", false)) //confused
		{
			Format(message, sizeof(message), "%s - %s", EU_PREFIX, command);
			ReplyToCommandColor(client, message, replySource);
		}
	}
}

stock void CMDEntVariant(int client, const char[] value, int args, ReplySource replySource)
{
	if(StrEqual(value, "", false))
	{
		if(StrEqual(g_szVariantString, EU_INVALID_VARIANT, false))
		{
			char message[256];
			Format(message, sizeof(message), "%s Variant string is not set", EU_PREFIX, g_szVariantString);
			ReplyToCommandColor(client, message, replySource);
			return;
		}
		char message[256];
		Format(message, sizeof(message), "%s Current variant string: '\x04%s\x09'", EU_PREFIX, g_szVariantString);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	Format(g_szVariantString, sizeof(g_szVariantString), value);
	
	char message[256];
	Format(message, sizeof(message), "%s '\x04%s\x09' will now be set before every \x04sm_ent_input \x09call", EU_PREFIX, value);
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntVariantClear(int client, int args, ReplySource replySource)
{
	Format(g_szVariantString, sizeof(g_szVariantString), EU_INVALID_VARIANT);
	
	char message[256];
	Format(message, sizeof(message), "%s Variant string will no longer be set", EU_PREFIX);
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntPosition(int client, float pos[3], int args, ReplySource replySource)
{
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int ref = EntIndexToEntRef(entity);
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	if(args == 3)
	{
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
		
		char message[256];
		Format(message, sizeof(message), "%s Set position to:", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		PrintVector(client, "Position", "X", "Y", "Z", pos, replySource);
		ReplyToCommandColor(client, " ", replySource);
		PrintString(client, "Entity", className, replySource);
		PrintInt(client, "Entity Index", entity, replySource);
		PrintInt(client, "Entity Reference", ref, replySource);
		return;
	}
	
	float traceendPos[3], eyeAngles[3], eyePos[3];
	GetClientEyeAngles(client, eyeAngles);
	GetClientEyePosition(client, eyePos);

	Handle trace = TR_TraceRayFilterEx(eyePos, eyeAngles, MASK_ALL, RayType_Infinite, TraceFilterNotSelf, client);
	if(TR_DidHit(trace))
		TR_GetEndPosition(traceendPos, trace);

	delete trace;
	
	TeleportEntity(entity, traceendPos, NULL_VECTOR, NULL_VECTOR);
	
	char message[256];
	Format(message, sizeof(message), "%s Set position to:", EU_PREFIX);
	ReplyToCommandColor(client, message, replySource);
	PrintVector(client, "Position", "X", "Y", "Z", traceendPos, replySource);
	ReplyToCommandColor(client, " ", replySource);
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
}

stock void CMDEntAngles(int client, float angles[3], int args, ReplySource replySource)
{
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int ref = EntIndexToEntRef(entity);
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	if(args == 3)
	{
		TeleportEntity(entity, NULL_VECTOR, angles, NULL_VECTOR);
		
		char message[256];
		Format(message, sizeof(message), "%s Set angles to:", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		PrintVector(client, "Angles", "X", "Y", "Z", angles, replySource);
		ReplyToCommandColor(client, " ", replySource);
		PrintString(client, "Entity", className, replySource);
		PrintInt(client, "Entity Index", entity, replySource);
		PrintInt(client, "Entity Reference", ref, replySource);
		return;
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
}

stock void CMDEntVelocity(int client, float vel[3], int args, ReplySource replySource)
{
	if(args != 3)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_velocity <value1> <value2> <value3>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int ref = EntIndexToEntRef(entity);
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));

	TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vel);
	
	char message[256];
	Format(message, sizeof(message), "%s Set velocity to:", EU_PREFIX);
	ReplyToCommandColor(client, message, replySource);
	PrintVector(client, "Velocity", "X", "Y", "Z", vel, replySource);
	ReplyToCommandColor(client, " ", replySource);
	PrintString(client, "Entity", className, replySource);
	PrintInt(client, "Entity Index", entity, replySource);
	PrintInt(client, "Entity Reference", ref, replySource);
}

stock void CMDEntSelect(int client, const char[] name, int args, ReplySource replySource)
{
	if(!StrEqual(name, "", false))
	{
		int iEnt = MAXPLAYERS + 1;
		char targetName[32];
		while((iEnt = FindEntityByClassname(iEnt, "*")) != -1)
		{
			if(iEnt < MAXPLAYERS + 1 || !IsValidEntity(iEnt))
				continue;
				
			GetEntPropString(iEnt, Prop_Data, "m_iName", targetName, sizeof(targetName));
			if(StrEqual(targetName, name, false))
			{
				SelectEntity(client, iEnt, false, replySource);
				return;
			}
		}
		char message[256];
		Format(message, sizeof(message), "%s Could not find an entity with name '\x04%s\x09'", EU_PREFIX, name);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	SelectEntity(client, GetClientAimTarget(client, false), false, replySource);
}

stock void CMDEntSelectIndex(int client, int index, int args, ReplySource replySource)
{
	if(args != 1)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_select_index <index>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	SelectEntity(client, index, false, replySource);
}

stock void CMDEntSelectRef(int client, int ref, int args, ReplySource replySource)
{
	if(args != 1)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_select_index <index>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int entity = EntRefToEntIndex(ref);
	SelectEntity(client, entity, false, replySource);
}

stock void CMDEntSelected(int client, int args, ReplySource replySource)
{
	PrintSelectedEntity(client, replySource);
}

stock void CMDEntSelectSelf(int client, int args, ReplySource replySource)
{
	SelectEntity(client, client, false, replySource);
}

stock void CMDEntSelectWorld(int client, int args, ReplySource replySource)
{
	SelectEntity(client, 0, true, replySource);
}

stock void CMDEntWatch(int client, const char[] prop, int size, int element, int args, ReplySource replySource)
{
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	PropFieldType sendFieldType = PropField_Unsupported;
	PropFieldType dataFieldType = PropField_Unsupported;
	
	bool send = false;
	bool data = false;

	char classname[65];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if(FindSendPropInfo(classname, prop, sendFieldType) != EU_INVALID_PROP_SEND_OFFSET)
		send = true;
	if(FindDataMapInfo(entity, prop, dataFieldType) != EU_INVALID_PROP_SEND_OFFSET)
		data = true;
	
	PropFieldType finalFieldType = view_as<PropFieldType>(max(view_as<int>(sendFieldType), view_as<int>(dataFieldType)));
	
	if(!send && !data)
	{
		char message[256];
		Format(message, sizeof(message), "%s Could not find property", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int propIndex = FindWatchedProperty(client, prop, size, element);
	if(propIndex != EU_INVALID_PROP_INDEX)
	{
		char message[256];
		Format(message, sizeof(message), "%s Property '\x04%s\x09' is already being watched", EU_PREFIX, prop);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	g_hWatchedProps[client].Push(send);
	g_hWatchedProps[client].Push(data);
	g_hWatchedProps[client].Push(g_iSelectedEnt[client]);
	g_hWatchedProps[client].Push(finalFieldType);
	g_hWatchedProps[client].Push(size);
	g_hWatchedProps[client].Push(element);
	g_hWatchedProps[client].Push(replySource);
	
	
	g_hWatchedPropStrings[client].PushString(prop);

	if(send)
	{
		switch(finalFieldType)
		{
			case PropField_Integer:
			{
				g_hWatchedProps[client].Push(GetEntProp(entity, Prop_Send, prop, size, element));
				g_hWatchedPropStrings[client].PushString("");
			}
			case PropField_Float:
			{
				g_hWatchedProps[client].Push(GetEntPropFloat(entity, Prop_Send, prop, element));
				g_hWatchedPropStrings[client].PushString("");
			}
			case PropField_String:
			{
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Send, prop, value, sizeof(value), element);
				g_hWatchedPropStrings[client].PushString(value);
				g_hWatchedProps[client].Push(0);
			}
			case PropField_String_T:
			{
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Send, prop, value, sizeof(value), element);
				g_hWatchedPropStrings[client].PushString(value);
				g_hWatchedProps[client].Push(0);
			}
			case PropField_Vector:
			{
				float value[3];
				GetEntPropVector(entity, Prop_Send, prop, value, element);
				g_hWatchedProps[client].PushArray(value, sizeof(value));
				g_hWatchedPropStrings[client].PushString("");
			}
			case PropField_Entity:
			{
				g_hWatchedProps[client].Push(GetEntPropEnt(entity, Prop_Send, prop, element));
				g_hWatchedPropStrings[client].PushString("");
			}
			default:
			{
				g_hWatchedProps[client].Push(0);
				g_hWatchedPropStrings[client].PushString("");
			}
		}
	}
	else
	{
		g_hWatchedProps[client].Push(0);
		g_hWatchedPropStrings[client].PushString("");
	}
	
	if(data)
	{
		switch(finalFieldType)
		{
			case PropField_Integer:
			{
				g_hWatchedProps[client].Push(GetEntProp(entity, Prop_Data, prop, size, element));
				g_hWatchedPropStrings[client].PushString("");
			}
			case PropField_Float:
			{
				g_hWatchedProps[client].Push(GetEntPropFloat(entity, Prop_Data, prop, element));
				g_hWatchedPropStrings[client].PushString("");
			}
			case PropField_String:
			{
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Data, prop, value, sizeof(value), element);
				g_hWatchedPropStrings[client].PushString(value);
				g_hWatchedProps[client].Push(0);
			}
			case PropField_String_T:
			{
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Data, prop, value, sizeof(value), element);
				g_hWatchedPropStrings[client].PushString(value);
				g_hWatchedProps[client].Push(0);
			}
			case PropField_Vector:
			{
				float value[3];
				GetEntPropVector(entity, Prop_Data, prop, value, element);
				g_hWatchedProps[client].PushArray(value, sizeof(value));
				g_hWatchedPropStrings[client].PushString("");
			}
			case PropField_Entity:
			{
				g_hWatchedProps[client].Push(GetEntPropEnt(entity, Prop_Data, prop, element));
				g_hWatchedPropStrings[client].PushString("");
			}
			default:
			{
				g_hWatchedProps[client].Push(0);
				g_hWatchedPropStrings[client].PushString("");
			}
		}
	}
	else
	{
		g_hWatchedProps[client].Push(0);
		g_hWatchedPropStrings[client].PushString("");
	}
	
	char message[256];
	Format(message, sizeof(message), "%s Property '\x04%s\x09' is now being watched", EU_PREFIX, prop);
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntUnwatch(int client, const char[] prop, int size, int element, int args, ReplySource replySource)
{
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	PropFieldType sendFieldType = PropField_Unsupported;
	PropFieldType dataFieldType = PropField_Unsupported;
	
	bool send = false;
	bool data = false;
	
	char classname[65];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if(FindSendPropInfo(classname, prop, sendFieldType) != EU_INVALID_PROP_SEND_OFFSET)
		send = true;
	if(FindDataMapInfo(entity, prop, dataFieldType) != EU_INVALID_PROP_SEND_OFFSET)
		data = true;
	
	if(!send && !data)
	{
		char message[256];
		Format(message, sizeof(message), "%s Could not find property", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int propIndex = FindWatchedProperty(client, prop, size, element);
	if(propIndex == EU_INVALID_PROP_INDEX)
	{
		char message[256];
		Format(message, sizeof(message), "%s Property '\x04%s\x09' is not being watched", EU_PREFIX, prop);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	for (int j = ENTITY_MAX - 2; j >= 0; j--)
		g_hWatchedProps[client].Erase(propIndex * (ENTITY_MAX - 1) + j);

	g_hWatchedPropStrings[client].Erase(propIndex+2);
	g_hWatchedPropStrings[client].Erase(propIndex+1);
	g_hWatchedPropStrings[client].Erase(propIndex);

	char message[256];
	Format(message, sizeof(message), "%s Property '\x04%s\x09' is no longer being watched", EU_PREFIX, prop);
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntWatchClear(int client, int args, ReplySource replySource)
{
	if(g_hWatchedProps[client].Length == 0)
	{
		char message[256];
		Format(message, sizeof(message), "%s You do not have any watched properties", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	char message[256];
	Format(message, sizeof(message), "%s Stopped watching \x04%d\x09 properties", EU_PREFIX, g_hWatchedPropStrings[client].Length / 3);
	ReplyToCommandColor(client, message, replySource);
	
	g_hWatchedProps[client].Clear();
	g_hWatchedPropStrings[client].Clear();
}

stock void CMDEntWatchList(int client, int args, ReplySource replySource)
{
	if(g_hWatchedProps[client].Length == 0)
	{
		char message[256];
		Format(message, sizeof(message), "%s You do not have any watched properties", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int count = 0;
	
	for (int i = 0; i < g_hWatchedPropStrings[client].Length / 3; i++)
	{
		char prop[PLATFORM_MAX_PATH];
		bool send = false;
		bool data = false;
		PropFieldType dummyPropType = PropField_Unsupported;
		int dummySize = 4;
		int dummyElement = 0;
		ReplySource dummyReply = SM_REPLY_TO_CHAT;
		
		int entity = GetWatchedProp(client, i, prop, sizeof(prop), send, data, dummyPropType, dummySize, dummyElement, dummyReply);
		
		char message[256];
		
		if(send)
		{
			Format(message, sizeof(message), "%s [ \x03SEND\x09 ] [ \x04%s\x09 ] [ Entity Index: \x04%d\x09 ] [ Entity Reference: \x04%d\x09 ]", EU_PREFIX, prop, entity, EntIndexToEntRef(entity));
			ReplyToCommandColor(client, message, replySource);
		}
		
		if(data)
		{
			Format(message, sizeof(message), "%s [ \x03DATA\x09 ] [ \x04%s\x09 ] [ Entity Index: \x04%d\x09 ] [ Entity Reference: \x04%d\x09 ]", EU_PREFIX, prop, entity, EntIndexToEntRef(entity));
			ReplyToCommandColor(client, message, replySource);
		}
		
		if(data || send)
			count++;
	}
	
	char message[256];
	Format(message, sizeof(message), "%s Currently watching over \x04%d\x09 properties", EU_PREFIX, count);
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntSetProp(int client, const char[] prop, const char[] szValue1, const char[] szValue2, const char[] szValue3, int size, int element, int args, ReplySource replySource)
{
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	bool send = false;
	bool data = false;
	
	PropFieldType sendFieldType = PropField_Unsupported;
	PropFieldType dataFieldType = PropField_Unsupported;
	
	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	if(FindSendPropInfo(className, prop, sendFieldType) != EU_INVALID_PROP_SEND_OFFSET)
		send = true;
		
	if(FindDataMapInfo(entity, prop, dataFieldType) != EU_INVALID_PROP_DATA_OFFSET)
		data = true;
	
	if(send)
	{
		switch(sendFieldType)
		{
			case PropField_Integer:
			{
				int value = StringToInt(szValue1);
				SetEntProp(entity, Prop_Send, prop, value, size, element);
				
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				PrintInt(client, prop, GetEntProp(entity, Prop_Send, prop, size, element), replySource);
			}
			case PropField_Float:
			{
				float value = StringToFloat(szValue1);
				SetEntPropFloat(entity, Prop_Send, prop, value, element);
				
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				PrintFloat(client, prop, GetEntPropFloat(entity, Prop_Send, prop, element), replySource);
			}
			case PropField_String:
			{
				SetEntPropString(entity, Prop_Send, prop, szValue1, element);
				
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				char string[256];
				GetEntPropString(entity, Prop_Send, prop, string, sizeof(string), element);
				PrintString(client, prop, string, replySource);
			}
			case PropField_String_T:
			{
				SetEntPropString(entity, Prop_Send, prop, szValue1, element);
				
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				char string[256];
				GetEntPropString(entity, Prop_Send, prop, string, sizeof(string), element);
				PrintString(client, prop, string, replySource);
			}
			case PropField_Vector:
			{
				float value[3];
				value[0] = StringToFloat(szValue1);
				value[1] = StringToFloat(szValue2);
				value[2] = StringToFloat(szValue3);
				SetEntPropVector(entity, Prop_Send, prop, value, element);
				
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				float vec[3];
				GetEntPropVector(entity, Prop_Send, prop, vec, element);
				PrintVector(client, prop, "X", "Y", "Z", vec, replySource);
			}
			case PropField_Entity:
			{
				int value = StringToInt(szValue1);
				SetEntPropEnt(entity, Prop_Send, prop, value, element);
				
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
				int value = StringToInt(szValue1);
				SetEntProp(entity, Prop_Data, prop, value, size, element);
				
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				PrintInt(client, prop, GetEntProp(entity, Prop_Data, prop, size, element), replySource);
			}
			case PropField_Float:
			{
				float value = StringToFloat(szValue1);
				SetEntPropFloat(entity, Prop_Data, prop, value, element);
				
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				PrintFloat(client, prop, GetEntPropFloat(entity, Prop_Data, prop, element), replySource);
			}
			case PropField_String:
			{
				SetEntPropString(entity, Prop_Data, prop, szValue1, element);
				
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				char string[256];
				GetEntPropString(entity, Prop_Data, prop, string, sizeof(string), element);
				PrintString(client, prop, string, replySource);
			}
			case PropField_String_T:
			{
				SetEntPropString(entity, Prop_Data, prop, szValue1, element);
				
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				char string[256];
				GetEntPropString(entity, Prop_Data, prop, string, sizeof(string), element);
				PrintString(client, prop, string, replySource);
			}
			case PropField_Vector:
			{

				float value[3];
				value[0] = StringToFloat(szValue1);
				value[1] = StringToFloat(szValue2);
				value[2] = StringToFloat(szValue3);
				SetEntPropVector(entity, Prop_Data, prop, value, element);
				
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				float vec[3];
				GetEntPropVector(entity, Prop_Data, prop, vec, element);
				PrintVector(client, prop, "X", "Y", "Z", vec, replySource);
			}
			case PropField_Entity:
			{
				int value = StringToInt(szValue1);
				SetEntPropEnt(entity, Prop_Data, prop, value, element);
				
				char message[256];
				Format(message, sizeof(message), "%s Property set:", EU_PREFIX, prop);
				ReplyToCommandColor(client, message, replySource);
				PrintInt(client, prop, GetEntPropEnt(entity, Prop_Data, prop, element), replySource);
			}
		}
	}
}

stock void CMDEntGetProp(int client, const char[] prop, int size, int element, int args, ReplySource replySource)
{
	if(args < 1 || args > 3)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_getprop <property> <size=4> <element=0>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	int entity = INVALID_ENT_REFERENCE;
	if((entity = HasSelectedEntity(client)) == INVALID_ENT_REFERENCE)
	{
		char message[256];
		Format(message, sizeof(message), "%s Select an entity with \x04sm_ent_select", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}

	char className[PLATFORM_MAX_PATH];
	GetEntityClassname(entity, className, sizeof(className));
	
	bool send = false;
	bool data = false;
	
	PropFieldType sendFieldType = PropField_Unsupported;
	PropFieldType dataFieldType = PropField_Unsupported;

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
		return;
	}

	if(send)
	{
		switch(sendFieldType)
		{
			case PropField_Integer:
			{
				char string[256];
				Format(string, sizeof(string), "SEND - %s", prop);
				PrintInt(client, string, GetEntProp(entity, Prop_Send, prop, size, element), replySource);
			}
			case PropField_Float:
			{
				char string[256];
				Format(string, sizeof(string), "SEND - %s", prop);
				PrintFloat(client, string, GetEntPropFloat(entity, Prop_Send, prop, element), replySource);
			}
			case PropField_String:
			{
				char string[256];
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Send, prop, value, sizeof(value), element);
				Format(string, sizeof(string), "SEND - %s", prop);
				PrintString(client, string, value, replySource);
			}
			case PropField_String_T:
			{
				char string[256];
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Send, prop, value, sizeof(value), element);
				Format(string, sizeof(string), "SEND - %s", prop);
				PrintString(client, string, value, replySource);
			}
			case PropField_Vector:
			{
				char string[256];
				float value[3];
				GetEntPropVector(entity, Prop_Send, prop, value, element);
				Format(string, sizeof(string), "SEND - %s", prop);
				PrintVector(client, string, "X", "Y", "Z", value, replySource);
			}
			case PropField_Entity:
			{
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
				char string[256];
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintInt(client, string, GetEntProp(entity, Prop_Data, prop, size, element), replySource);
			}
			case PropField_Float:
			{
				char string[256];
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintFloat(client, string, GetEntPropFloat(entity, Prop_Data, prop, element), replySource);
			}
			case PropField_String:
			{
				char string[256];
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Data, prop, value, sizeof(value), element);
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintString(client, string, value, replySource);
			}
			case PropField_String_T:
			{
				char string[256];
				char value[PLATFORM_MAX_PATH];
				GetEntPropString(entity, Prop_Data, prop, value, sizeof(value), element);
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintString(client, string, value, replySource);
			}
			case PropField_Vector:
			{
				char string[256];
				float value[3];
				GetEntPropVector(entity, Prop_Data, prop, value, element);
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintVector(client, string, "X", "Y", "Z", value, replySource);
			}
			case PropField_Entity:
			{
				char string[256];
				Format(string, sizeof(string), "DATA - %s", prop);
				PrintInt(client, string, GetEntPropEnt(entity, Prop_Data, prop, element), replySource);
			}
		}
	}
	return;
}

stock void CMDKillAll(int client, int args, ReplySource replySource)
{
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
}

stock void CMDKillMy(int client, int args, ReplySource replySource)
{
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
}

stock void CMDKillUnowned(int client, int args, ReplySource replySource)
{
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
}

stock void CMDEntCount(int client, const char[] targetClassName, int args, ReplySource replySource)
{
	if(args != 1)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_count <classname>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}	
	
	int count = 0;
	
	int iEnt = INVALID_ENT_REFERENCE;
	while((iEnt = FindEntityByClassname(iEnt, targetClassName)) != -1)
	{
		if(iEnt < 0 || !IsValidEntity(iEnt))
			continue;
			
		char classname[65];
		GetEntityClassname(iEnt, classname, sizeof(classname));
		if(StrEqual(classname, targetClassName, false))
			count++;
	}
	
	char message[256];
	Format(message, sizeof(message), "%s Found \x04%d\x09 entities with class name '\x04%s\x09'", EU_PREFIX, count, targetClassName);
	ReplyToCommandColor(client, message, replySource);
}

stock void CMDEntList(int client, const char[] szTarget, int args, ReplySource replySource)
{
	if(args != 1)
	{
		char message[256];
		Format(message, sizeof(message), "%s Usage \x04sm_ent_list <#userid|client>", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}	
	
	int target = FindTarget(client, szTarget, true, true);
	if(!IsValidClient(target))
	{
		char message[256];
		Format(message, sizeof(message), "%s Invalid target", EU_PREFIX);
		ReplyToCommandColor(client, message, replySource);
		return;
	}
	
	PrintClientEntities(client, target, replySource);
}

/**********/
/* STOCKS */
/**********/
stock void RecordScriptCommand(int client, const char[] command)
{
	char commandArguments[8][PLATFORM_MAX_PATH];
   	ExplodeString(command, " ", commandArguments, sizeof(commandArguments), sizeof(commandArguments[]));
  	int argCount = GetStringCount(commandArguments, 8) - 1;
  	
  	if(StrEqual(commandArguments[0], EU_CMD_CREATE_ENTITY, false))				//sm_ent_create <classname(string>
	{
		if(argCount == 1) 
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_KEYVALUE, false))				//sm_ent_keyvalue <key(string> <value(string)>
	{
		if(argCount == 2) 
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_KEYVALUE_FLOAT, false))		//sm_ent_keyvaluefloat <key(string> <value(float)>
	{
		if(argCount == 2) 
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_KEYVALUE_VECTOR, false))		//sm_ent_keyvaluevector <key(string)> <value1(float)> <value2(float)> <value3(float)>
	{
		if(argCount == 4) 
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SPAWN, false))					//sm_ent_spawn
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_VARIANT, false))				//sm_ent_variant <variant(string)[optional]>
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_VARIANT_CLEAR, false))			//sm_ent_variant_clear
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_INPUT, false))					//sm_ent_input <input(string)> <activator(int)[optional]> <caller(int)[optional]> <outputid(int)[optional]> 
	{
		if(argCount > 0 && argCount < 5) 
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT, false))				//sm_ent_script <script(string)>
	{
		if(argCount == 1)
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_RELOAD, false))			//sm_ent_script_reload
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_RECORD, false))			//sm_ent_script_record
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_SAVE, false))			//sm_ent_script_save <name(string)>
	{
		if(argCount == 1)
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_CLEAR, false))			//sm_ent_script_clear
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_DELETE, false))			//sm_ent_script_delete <name(string)>
	{
		if(argCount == 1)
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SCRIPT_LIST, false))			//sm_ent_script_list
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_POSITION, false))				//sm_ent_position <value1(float)[optional]> <value2(float)[optional]> <value3(float)[optional]>
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_ANGLES, false))				//sm_ent_angles <value1(float)[optional]> <value2(float)[optional]> <value3(float)[optional]>
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_VELOCITY, false))				//sm_ent_velocity <value1(float)> <value2(float)> <value3(float)>
	{
		if(argCount == 3)
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SELECTED, false))				//sm_ent_selected
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SELECT, false))				//sm_ent_select <name(string)[optional]>
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SELECT_INDEX, false))			//sm_ent_select_index <index(int)>
	{
		if(argCount == 1) 
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SELECT_REF, false))			//sm_ent_select_ref <reference(int)>
	{
		if(argCount == 1)
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SELECT_SELF, false))			//sm_ent_select_self
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SELECT_WORLD, false))			//sm_ent_select_world
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_WATCH, false))					//sm_ent_watch <prop(string)> <size(int)[optional]> <element(int)[optional]>
	{
		if(argCount > 0 && argCount < 4)
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_UNWATCH, false))				//sm_ent_unwatch <prop(string)> <size(int)[optional]> <element(int)[optional]>
	{
		if(argCount > 0 && argCount < 4)
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_WATCH_CLEAR, false))			//sm_ent_watch_clear
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_WATCH_LIST, false))			//sm_ent_watch_list
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_SET_PROP, false))				//sm_ent_setprop <prop(string)> <value1(any)> <value2(float)[optional]> <value3(float)[optional]> <size(int)[optional]> <element(int)[optional]>
	{
		if(argCount > 0 && argCount < 7)
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_GET_PROP, false))				//sm_ent_getprop <prop(string)> <size(int)[optional]> <element(int)[optional]>
	{
		if(argCount > 0 && argCount < 4)
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_KILL_ALL, false))				//sm_ent_killall
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_KILL_MY, false))				//sm_ent_killmy
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_KILL_UNOWNED, false))			//sm_ent_killunowned
	{
		g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_LIST, false))					//sm_ent_list <#userid(int)|name(string)>
	{
		if(argCount == 1)
			g_hRecordedScript[client].PushString(command);
	}
	else if(StrEqual(commandArguments[0], EU_CMD_COUNT, false))					//sm_ent_count <classname>
	{
		if(argCount == 1)
			g_hRecordedScript[client].PushString(command);
	}
}

stock void GetClientAuthIdEx(int client, AuthIdType type, char[] buff, int size)
{
	if(IsValidClient(client))
		GetClientAuthId(client, type, buff, size);
	else if(client == 0)
		Format(buff, size, "server");
}

stock int GetStringCount(const char[][] strings, int length)
{
	int count = 0;
	for (int i = 0; i < length; i++)
	{
		if(!StrEqual(strings[i], "", false))
			count++;
	}
	return count;
}

stock int FindWatchedProperty(int client, const char[] prop, int size = 4, int element = 0)
{
	for (int i = 0; i < g_hWatchedPropStrings[client].Length / 3; i++)
	{
		char watchedProp[PLATFORM_MAX_PATH];
		g_hWatchedPropStrings[client].GetString(i * 3, watchedProp, sizeof(watchedProp));
		if(	StrEqual(prop, watchedProp, false) && 
			size == g_hWatchedProps[client].Get(i * (ENTITY_MAX - 1) + ENTITY_SIZE) && 
			element == g_hWatchedProps[client].Get(i * (ENTITY_MAX - 1) + ENTITY_ELEMENT))
		{
			// Found watched prop
			return i;
		}
	}
	return EU_INVALID_PROP_INDEX;
}

// Returns entity index
stock int GetWatchedProp(int client, int arrIndex, char[] propBuffer, int propBufferSize, bool& propSend, bool& propData, PropFieldType& propType, int& size, int& element, ReplySource& replySource)
{
	char prop[PLATFORM_MAX_PATH];
	g_hWatchedPropStrings[client].GetString(arrIndex*3, prop, sizeof(prop));
	
	Format(propBuffer, propBufferSize, prop);
	propSend = g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1));
	propData = g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_PROP_DATA);
	propType = view_as<PropFieldType>(g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_PROPERTY_TYPE));
	size = g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_SIZE);
	element = g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_ELEMENT);
	replySource = view_as<ReplySource>(g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_REPLY_SOURCE));
	return EntRefToEntIndex(g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_REFERENCE));
}

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
		GetClientAuthIdEx(i, AuthId_SteamID64, authid, sizeof(authid));
		
		if(StrEqual(authid, steamid64, false))
			return i;
	}
	
	return INVALID_ENT_REFERENCE;
}

stock int max(int x, int y)
{
	return x >= y ? x : y;
}

stock int min(int x, int y)
{
	return x <= y ? x : y;
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

/************/
/* FORWARDS */
/************/

public void OnGameFrame()
{
	for (int client = 0; client <= MaxClients; client++)
	{
		for (int arrIndex = 0; arrIndex < (g_hWatchedPropStrings[client].Length / 3); arrIndex++)
		{
			char prop[PLATFORM_MAX_PATH];
			bool send = false;
			bool data = false;
			PropFieldType propType = PropField_Unsupported;
			int size = 4;
			int element = 0;
			ReplySource replySource = SM_REPLY_TO_CHAT;
			
			int entity = GetWatchedProp(client, arrIndex, prop, sizeof(prop), send, data, propType, size, element, replySource);
			if(!IsValidEntity(entity))
			{
				for (int j = ENTITY_MAX - 2; j >= 0; j--)
					g_hWatchedProps[client].Erase(arrIndex * (ENTITY_MAX - 1) + j);
					
				g_hWatchedPropStrings[client].Erase(arrIndex+2);
				g_hWatchedPropStrings[client].Erase(arrIndex+1);
				g_hWatchedPropStrings[client].Erase(arrIndex);
				continue;
			}
			
			if(send)
			{
				switch(propType)
				{
					case PropField_Integer:
					{
						int prevValue = g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_SEND_VALUE);
						int newValue = GetEntProp(entity, Prop_Send, prop, size, element);
						if(prevValue != newValue)
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03SEND\x09] \x04%s\x09 has changed from \x0C%d\x09 to \x0C%d\x09", EU_PREFIX, prop, prevValue, newValue);
							ReplyToCommandColor(client, message, replySource);
							g_hWatchedProps[client].Set(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_SEND_VALUE, newValue);
						}
					}
					case PropField_Float:
					{
						float prevValue = g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_SEND_VALUE);
						float newValue = GetEntPropFloat(entity, Prop_Send, prop, element);
						if(prevValue != newValue)
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03SEND\x09] \x04%s\x09 has changed from \x0C%f\x09 to \x0C%f\x09", EU_PREFIX, prop, prevValue, newValue);
							ReplyToCommandColor(client, message, replySource);
							g_hWatchedProps[client].Set(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_SEND_VALUE, newValue);
						}
					}
					case PropField_String:
					{
						char prevValue[PLATFORM_MAX_PATH], newValue[PLATFORM_MAX_PATH];
						g_hWatchedPropStrings[client].GetString(arrIndex * 3 + 1, prevValue, sizeof(prevValue));
						GetEntPropString(entity, Prop_Send, prop, newValue, sizeof(newValue), element);
						if(!StrEqual(prevValue, newValue, true))
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03SEND\x09] \x04%s\x09 has changed from \x0C%s\x09 to \x0C%s\x09", EU_PREFIX, prop, prevValue, newValue);
							ReplyToCommandColor(client, message, replySource);
							g_hWatchedPropStrings[client].SetString(arrIndex * 3 + 1, newValue);
							
						}
					}
					case PropField_String_T:
					{
						char prevValue[PLATFORM_MAX_PATH], newValue[PLATFORM_MAX_PATH];
						g_hWatchedPropStrings[client].GetString(arrIndex * 3 + 1, prevValue, sizeof(prevValue));
						GetEntPropString(entity, Prop_Send, prop, newValue, sizeof(newValue), element);
						if(!StrEqual(prevValue, newValue, true))
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03SEND\x09] \x04%s\x09 has changed from \x0C%s\x09 to \x0C%s\x09", EU_PREFIX, prop, prevValue, newValue);
							ReplyToCommandColor(client, message, replySource);
							g_hWatchedPropStrings[client].SetString(arrIndex * 3 + 1, newValue);
							
						}
					}
					case PropField_Vector:
					{
						float prevValue[3], newValue[3];
						g_hWatchedProps[client].GetArray(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_SEND_VALUE, prevValue, sizeof(prevValue));
						GetEntPropVector(entity, Prop_Send, prop, newValue, element);
						if(	prevValue[0] != newValue[0] ||
							prevValue[1] != newValue[1] ||
							prevValue[2] != newValue[2])
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03SEND\x09] \x04%s\x09 has changed from:", EU_PREFIX, prop);
							ReplyToCommandColor(client, message, replySource);
							Format(message, sizeof(message), "%s [\x03SEND\x09] [ \x07%.2f \x04%.2f \x0C%.2f\x09 ] to [ \x07%.2f \x04%.2f \x0C%.2f\x09 ]", EU_PREFIX, prevValue[0], prevValue[1], prevValue[2], newValue[0], newValue[1], newValue[2]);
							ReplyToCommandColor(client, message, replySource);
							
							g_hWatchedProps[client].SetArray(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_SEND_VALUE, newValue, sizeof(newValue));
						}
					}
					case PropField_Entity:
					{
						int prevValue = g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_SEND_VALUE);
						int newValue = GetEntPropEnt(entity, Prop_Send, prop, element);
						if(prevValue != newValue)
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03SEND\x09] \x04%s\x09 has changed from \x0C%d\x09 to \x0C%d\x09", EU_PREFIX, prop, prevValue, newValue);
							ReplyToCommandColor(client, message, replySource);
							g_hWatchedProps[client].Set(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_SEND_VALUE, newValue);
						}
					}
				}
			}
			if(data)
			{
				switch(propType)
				{
					case PropField_Integer:
					{
						int prevValue = g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_DATA_VALUE);
						int newValue = GetEntProp(entity, Prop_Data, prop, size, element);
						if(prevValue != newValue)
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03DATA\x09] \x04%s\x09 has changed from \x0C%d\x09 to \x0C%d\x09", EU_PREFIX, prop, prevValue, newValue);
							ReplyToCommandColor(client, message, replySource);
							g_hWatchedProps[client].Set(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_DATA_VALUE, newValue);
						}
					}
					case PropField_Float:
					{
						float prevValue = g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_DATA_VALUE);
						float newValue = GetEntPropFloat(entity, Prop_Data, prop, element);
						if(prevValue != newValue)
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03DATA\x09] \x04%s\x09 has changed from \x0C%f\x09 to \x0C%f\x09", EU_PREFIX, prop, prevValue, newValue);
							ReplyToCommandColor(client, message, replySource);
							g_hWatchedProps[client].Set(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_DATA_VALUE, newValue);
						}
					}
					case PropField_String:
					{
						char prevValue[PLATFORM_MAX_PATH], newValue[PLATFORM_MAX_PATH];
						g_hWatchedPropStrings[client].GetString(arrIndex * 3 + 2, prevValue, sizeof(prevValue));
						GetEntPropString(entity, Prop_Data, prop, newValue, sizeof(newValue), element);
						if(!StrEqual(prevValue, newValue, true))
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03DATA\x09] \x04%s\x09 has changed from \x0C%s\x09 to \x0C%s\x09", EU_PREFIX, prop, prevValue, newValue);
							ReplyToCommandColor(client, message, replySource);
							g_hWatchedPropStrings[client].SetString(arrIndex * 3 + 2, newValue);
							
						}
					}
					case PropField_String_T:
					{
						char prevValue[PLATFORM_MAX_PATH], newValue[PLATFORM_MAX_PATH];
						g_hWatchedPropStrings[client].GetString(arrIndex * 3 + 2, prevValue, sizeof(prevValue));

						GetEntPropString(entity, Prop_Data, prop, newValue, sizeof(newValue), element);
						if(!StrEqual(prevValue, newValue, true))
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03DATA\x09] \x04%s\x09 has changed from \x0C%s\x09 to \x0C%s\x09", EU_PREFIX, prop, prevValue, newValue);
							ReplyToCommandColor(client, message, replySource);
							g_hWatchedPropStrings[client].SetString(arrIndex * 3 + 2, newValue);
						}
					}
					case PropField_Vector:
					{
						float prevValue[3], newValue[3];
						g_hWatchedProps[client].GetArray(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_DATA_VALUE, prevValue, sizeof(prevValue));
						GetEntPropVector(entity, Prop_Data, prop, newValue, element);
						if(	prevValue[0] != newValue[0] ||
							prevValue[1] != newValue[1] ||
							prevValue[2] != newValue[2])
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03DATA\x09] \x04%s\x09 has changed from:", EU_PREFIX, prop);
							ReplyToCommandColor(client, message, replySource);
							Format(message, sizeof(message), "%s [ \x07%.2f \x04%.2f \x0C%.2f\x09 ] to [ \x07%.2f \x04%.2f \x0C%.2f\x09 ]", EU_PREFIX, prevValue[0], prevValue[1], prevValue[2], newValue[0], newValue[1], newValue[2]);
							ReplyToCommandColor(client, message, replySource);
							
							g_hWatchedProps[client].SetArray(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_DATA_VALUE, newValue, sizeof(newValue));
						}
					}
					case PropField_Entity:
					{
						int prevValue = g_hWatchedProps[client].Get(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_DATA_VALUE);
						int newValue = GetEntPropEnt(entity, Prop_Data, prop, element);
						if(prevValue != newValue)
						{
							char message[256];
							Format(message, sizeof(message), "%s [\x03DATA\x09] \x04%s\x09 has changed from \x0C%d\x09 to \x0C%d\x09", EU_PREFIX, prop, prevValue, newValue);
							ReplyToCommandColor(client, message, replySource);
							g_hWatchedProps[client].Set(arrIndex * (ENTITY_MAX - 1) + ENTITY_PREVIOUS_DATA_VALUE, newValue);
						}
					}
				}
			}
		}
	}
}

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
	
	g_bRecording[client] = false;
	g_iSelectedEnt[client] = INVALID_ENT_REFERENCE;
	g_hEntities[client].Clear();
	g_hRecordedScript[client].Clear();
	g_hWatchedProps[client].Clear();
	g_hWatchedPropStrings[client].Clear();
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;
		
	char authid[32];
	GetClientAuthIdEx(client, AuthId_SteamID64, authid, sizeof(authid));
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