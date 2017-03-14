/*  SM Franug GangsMod
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <store>

// configure this
#define MAXPLAYERS_IN_KV 1024 // max players cached
#define MAXGANGS_IN_KV 1024 // max gangs cached

#define KV_JUGADORES "data/gangs_players.txt" // file when players are saved
#define KV_BANDAS "data/gangs_names.txt" // file when gangs are saved

// end of configuration




new bool:conectado[MAXPLAYERS+1] = {false, ...};

/* caches */

//

new String:lista_miembros[MAXPLAYERS_IN_KV][5][24];
new g_iNumCommands[MAXPLAYERS_IN_KV];

//

new Handle:bandas_jugadores = INVALID_HANDLE;
new Handle:bandas_nombres = INVALID_HANDLE;

new bool:creandobanda[MAXPLAYERS+1] = {false, ...};

// jugadores
enum Numeros
{
	String:steamid[24],
	String:banda[64],
	String:nombre[64],
	String:invitacion[64],
	String:expulsado[12]
}

new g_list[2048][Numeros];
new g_ListCount;

new Handle:g_ListIndex = INVALID_HANDLE;
// End

// nombre bandas

enum Numeros2
{
	String:nombre[64],
	String:propietario[24],
	numero_miembros,
	vida,
	granada,
	glock,
	String:miembros[512]
}

new g_list2[MAXGANGS_IN_KV][Numeros2];
new g_ListCount2;

new Handle:g_ListIndex2 = INVALID_HANDLE;

// end

/* final de caches */

#define VERSION "b0.4 public version"
new String:Logfile[PLATFORM_MAX_PATH];


public Plugin:myinfo = 
{
	name = "SM Franug GangsMod",
	author = "Franc1sco steam: franug",
	description = "gangs mod",
	version = VERSION,
	url = "http://steamcommunity.com/id/franug"
};

public OnPluginStart()
{
	CreateConVar("sm_FranugGangsMod", VERSION, "Version", FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_CHEAT);

	ListaCacheJugadores();
	ListaCacheBandas();
	
	RegConsoleCmd("say",fnHookSay);
	RegConsoleCmd("say_team",fnHookSay);
	
	RegConsoleCmd("sm_gangs", DID);
	
	RegAdminCmd("sm_gangs_reload", AdminMenu, ADMFLAG_ROOT);
	
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	
	BuildPath(Path_SM, Logfile, sizeof(Logfile), "logs/gangs_records.log");
}

public Action:AdminMenu(client,args) 
{
	ListaCacheJugadores();
	ListaCacheBandas();
	
	ReplyToCommand(client, "\x04[SM_GangsMod] \x01Cache reloaded");
}

public OnMapStart()
{
	ListaCacheJugadores();
	ListaCacheBandas();
}
/*
public OnPluginEnd()
{
	InfoJugadores();
	InfoBandas();
}
*/

InfoJugadores()
{
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), KV_JUGADORES);
	
    
	KeyValuesToFile(bandas_jugadores, path);
}

InfoBandas()
{
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), KV_BANDAS);
	
    
	KeyValuesToFile(bandas_nombres, path);
}


ListaCacheJugadores()
{
	if (bandas_jugadores != INVALID_HANDLE)
		CloseHandle(bandas_jugadores);
    
    
	decl String:file_tmp[PLATFORM_MAX_PATH];
	Format(file_tmp, PLATFORM_MAX_PATH, "addons/sourcemod/%s", KV_JUGADORES);
	
	if(!FileExists(file_tmp))
	{
		decl String:path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), KV_JUGADORES);
	
		bandas_jugadores = CreateKeyValues("players");
		KeyValuesToFile(bandas_jugadores, path);
		
		//LogToGame("no existe");
	}
	else 
	{
		bandas_jugadores = CreateKeyValues("players");
		FileToKeyValues(bandas_jugadores,file_tmp);
		
		//LogToGame("Existe");
	}
    
	/*if (!FileToKeyValues(bandas_jugadores, path))
	{
		SetFailState("\"%s\" missing from server", path);
	}*/

	
	if (g_ListIndex != INVALID_HANDLE)
		CloseHandle(g_ListIndex);
	
	g_ListIndex = CreateTrie();
	g_ListCount = 0;
	
	decl String:steamid_kv[24];
	
	if (KvGotoFirstSubKey(bandas_jugadores))
	{
		do
		{
			KvGetSectionName(bandas_jugadores, steamid_kv, sizeof(steamid_kv));
			strcopy(g_list[g_ListCount][steamid], sizeof(steamid_kv), steamid_kv);
			
			
			SetTrieValue(g_ListIndex, g_list[g_ListCount][steamid], g_ListCount);
			
			KvGetString(bandas_jugadores, "gang", g_list[g_ListCount][banda], 64,"nothing");
			KvGetString(bandas_jugadores, "name", g_list[g_ListCount][nombre], 64);
			KvGetString(bandas_jugadores, "invitation", g_list[g_ListCount][invitacion], 64,"nothing");
			KvGetString(bandas_jugadores, "expelled", g_list[g_ListCount][expulsado], 12,"no");
			
			
			g_ListCount++;
			
		} while (KvGotoNextKey(bandas_jugadores));
		KvRewind(bandas_jugadores);
	}
}


ListaCacheBandas()
{
	if (bandas_nombres != INVALID_HANDLE)
		CloseHandle(bandas_nombres);
    
		
	decl String:file_tmp[PLATFORM_MAX_PATH];
	Format(file_tmp, PLATFORM_MAX_PATH, "addons/sourcemod/%s", KV_BANDAS);
	
	if(!FileExists(file_tmp))
	{
		decl String:path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), KV_BANDAS);
	
		bandas_nombres = CreateKeyValues("gangs");
		KeyValuesToFile(bandas_nombres, path);
	}
	else 
	{
		bandas_nombres = CreateKeyValues("gangs");
		FileToKeyValues(bandas_nombres,file_tmp);
	}
    
	/*if (!FileToKeyValues(bandas_nombres, path))
	{
		SetFailState("\"%s\" missing from server", path);
	}*/

	if (g_ListIndex2 != INVALID_HANDLE)
		CloseHandle(g_ListIndex2);
	
	g_ListIndex2 = CreateTrie();
	g_ListCount2 = 0;
	
	decl String:nombrekv[64];
	
	if (KvGotoFirstSubKey(bandas_nombres))
	{
		do
		{
			KvGetSectionName(bandas_nombres, nombrekv, sizeof(nombrekv));
			strcopy(g_list2[g_ListCount2][nombre], sizeof(nombrekv), nombrekv);
			
			
			SetTrieValue(g_ListIndex2, g_list2[g_ListCount2][nombre], g_ListCount2);
			
			KvGetString(bandas_nombres, "owner", g_list2[g_ListCount2][propietario], 64);
			
			decl String:sTemp[512];
			KvGetString(bandas_nombres, "members", sTemp, 512);
			Format(g_list2[g_ListCount2][miembros], 512, sTemp);
			g_iNumCommands[g_ListCount2] = 0;
			g_iNumCommands[g_ListCount2] = ExplodeString(sTemp, ", ", lista_miembros[g_ListCount2], 5, 24);
			
			//KvGetString(bandas_nombres, "members", g_list2[g_ListCount2][miembros], 512);
			g_list2[g_ListCount2][numero_miembros] = KvGetNum(bandas_nombres, "member_number", 0);
			g_list2[g_ListCount2][vida] = KvGetNum(bandas_nombres, "armor", 1);
			g_list2[g_ListCount2][granada] = KvGetNum(bandas_nombres, "grenade", 1);
			g_list2[g_ListCount2][glock] = KvGetNum(bandas_nombres, "glock", 1);
			
			
			/*if(g_list2[g_ListCount2][numero_miembros] > 0)
			{
					KvJumpToKey(bandas_nombres, "members");
					KvGotoFirstSubKey(bandas_nombres);
					new numerolista;
					do
					{
						decl String:list_tmp[24];
						
						KvGetSectionName(bandas_nombres, list_tmp, sizeof(list_tmp));
						
						Format(lista_miembros[g_ListCount2][numerolista], 24, list_tmp);
						
						
						numerolista++;

					}while (KvGotoNextKey(bandas_nombres));
					
					KvGoBack(bandas_nombres);
					KvGoBack(bandas_nombres);
					
					
			}*/
			
			
			
			g_ListCount2++;
			
		} while (KvGotoNextKey(bandas_nombres));
		KvRewind(bandas_nombres);
	}
}

ComprobarJugador(client)
{
	decl String:status_steamid[24];
	GetClientAuthString(client, status_steamid, sizeof(status_steamid));

	new listado = -1;
	if (!GetTrieValue(g_ListIndex, status_steamid, listado))
	{
		//KvRewind(bandas_jugadores);	
		//KvGetSectionName(bandas_jugadores, steamid_kv, sizeof(steamid_kv));

		KvJumpToKey(bandas_jugadores, status_steamid, true);
			
		strcopy(g_list[g_ListCount][steamid], sizeof(status_steamid), status_steamid);
			
			
		SetTrieValue(g_ListIndex, g_list[g_ListCount][steamid], g_ListCount);
			
		Format(g_list[g_ListCount][banda], 64, "nothing");
		Format(g_list[g_ListCount][nombre], 64, "%N",client);
		Format(g_list[g_ListCount][invitacion], 64, "nothing");
		Format(g_list[g_ListCount][expulsado], 12, "no");
		
		KvSetString(bandas_jugadores, "gang", g_list[g_ListCount][banda]);
		KvSetString(bandas_jugadores, "name", g_list[g_ListCount][nombre]);
		KvSetString(bandas_jugadores, "invitation", g_list[g_ListCount][invitacion]);
		KvSetString(bandas_jugadores, "expelled", g_list[g_ListCount][expulsado]);
		
			
			
		g_ListCount++;
		
		KvRewind(bandas_jugadores);	
		//KeyValuesToFile(bandas_jugadores, KV_JUGADORES);
		InfoJugadores();
	}
	conectado[client] = true;
}

public OnClientPostAdminCheck(client)
{
	creandobanda[client] = false;
	ComprobarJugador(client);
}

public OnClientDisconnect(client)
{
	if(!conectado[client])
		return;
		
	decl String:status_steamid[24];
	GetClientAuthString(client, status_steamid, sizeof(status_steamid));
	new listado = -1;
	if (GetTrieValue(g_ListIndex, status_steamid,listado))
	{
		decl String:name[64];
		GetClientName( client, name, sizeof(name) );
 
		ReplaceString(name, sizeof(name), "'", ".");
		ReplaceString(name, sizeof(name), "<", ".");
		ReplaceString(name, sizeof(name), "\"", ".");
		
		//KvGetSectionName(bandas_jugadores, steamid_kv, sizeof(steamid_kv));
		KvJumpToKey(bandas_jugadores, status_steamid);
			

		Format(g_list[listado][nombre], 64, name);
		
		decl String:tiempo[512];
		FormatTime(tiempo, sizeof(tiempo), "%A, %B %d, %Y - %I:%M:%S%p %Z", GetTime());
		
		KvSetString(bandas_jugadores, "name", g_list[listado][nombre]);
		KvSetString(bandas_jugadores, "last_connection", tiempo);
		
		KvRewind(bandas_jugadores);	
		//KeyValuesToFile(bandas_jugadores, KV_JUGADORES);
		InfoJugadores();
	}
	conectado[client] = false;
}

public Action:DID(clientId,args) 
{
	/*decl String:status_steamid[24];
	GetClientAuthString(clientId, status_steamid, sizeof(status_steamid));
	new listado = -1;
	if (!GetTrieValue(g_ListIndex, status_steamid,listado))
	{
		PrintToChat(clientId, "\x04[SM_GangsMod] \x01Parece ser que no estas en la base de datos, vuelve a entrar al server para meterte en ella");
		return Plugin_Handled;
	}*/
	ComprobarJugador(clientId);
	
	new Handle:menu = CreateMenu(DIDMenuHandler);
	SetMenuTitle(menu, "Gangs Menu");
	AddMenuItem(menu, "opcion1", "Create a gang (need 500 credits)");
	AddMenuItem(menu, "opcion2", "Enter in a gang");
	AddMenuItem(menu, "opcion3", "Exit from a gang");
	AddMenuItem(menu, "opcion4", "Information of your gang");
	AddMenuItem(menu, "opcion5", "Upgrade your gang");
	AddMenuItem(menu, "opcion6", "Management of your gang");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, clientId, MENU_TIME_FOREVER);

	return Plugin_Handled;
	
}


public DIDMenuHandler(Handle:menu, MenuAction:action, client, itemNum) 
{
    if ( action == MenuAction_Select ) 
    {
        new String:info[32];
        
        GetMenuItem(menu, itemNum, info, sizeof(info));

        if ( strcmp(info,"opcion1") == 0 ) 
        {
			//PrintToChatAll("hecho");
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			
			if(StrEqual("nothing",g_list[listado][banda],false))
			{
				new Handle:pack = CreateDataPack();
				WritePackCell(pack, client);
				//WritePackCell(pack, credits);
				Store_GetCredits(Store_GetClientAccountID(client), GetCreditsCallback, pack);
			}
			else
				PrintToChat(client, "\x04[SM_GangsMod] \x01You already have a gang, for create a new gang first exit of your current gang");
            
        }
        else if ( strcmp(info,"opcion2") == 0 ) 
        {
			//PrintToChatAll("hecho");
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			
			if(StrEqual("nothing",g_list[listado][banda],false))
			{
				BuscarBanda(client);
			}
			else
				PrintToChat(client, "\x04[SM_GangsMod] \x01You already have a gang, for want serch other gang then exit of your current gang");
            
        }
        else if ( strcmp(info,"opcion3") == 0 ) 
        {
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			
			if(!StrEqual("nothing",g_list[listado][banda],false))
				Menu_salirbanda(client);
			else
				PrintToChat(client, "\x04[SM_GangsMod] \x01Currently you not have a gang");
        }
        else if ( strcmp(info,"opcion4") == 0 ) 
        {
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			
			if(!StrEqual("nothing",g_list[listado][banda],false))
				Menu_infobanda(client, listado);
			else
				PrintToChat(client, "\x04[SM_GangsMod] \x01Currently you not have a gang");
		}
        else if ( strcmp(info,"opcion5") == 0 ) 
        {
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			
			if(!StrEqual("nothing",g_list[listado][banda],false))
				Mejorarbanda(client, listado);
			else
				PrintToChat(client, "\x04[SM_GangsMod] \x01Currently you not have a gang");
        }
        else if ( strcmp(info,"opcion6") == 0 ) 
        {
			//PrintToChatAll("gestion");
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			
			if(!StrEqual("nothing",g_list[listado][banda],false))
				Menu_gestionbanda(client, listado);
			else
				PrintToChat(client, "\x04[SM_GangsMod] \x01Currently you not have a gang");
        }
    }

    else if (action == MenuAction_Cancel) 
    { 
        PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
    } 

    else if (action == MenuAction_End)
    {
		CloseHandle(menu);
    }
}

public GetCreditsCallback(credits, any:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	
		
	if(credits >= 500)
	{
		HacerBanda(client);
	}
	else
	{
		PrintToChat(client, "\x04[SM_GangsMod] \x01You do not have enough credits to create a gang");
	}
}

HacerBanda(client)
{
	PrintToChat(client, "\x04[SM_GangsMod] \x01Write in chat the name of your gang, write !no for cancel");
	creandobanda[client] = true;
}

public Action:fnHookSay(client,args)
{
	if(creandobanda[client])
	{
		decl String:SayText[512];
		GetCmdArgString(SayText,sizeof(SayText));
		
		StripQuotes(SayText);
	
		if(StrEqual("!no",SayText,false))
		{
			PrintToChat(client, "\x04[SM_GangsMod] \x01The creation of gang has canceled");
			creandobanda[client] = false;
			return;
		}
		if(StrEqual("nothing",SayText,false))
		{
			PrintToChat(client, "\x04[SM_GangsMod] \x01You can not use the name \"nothing\" because you can buggy the plugin :=)");
			//creandobanda[client] = false;
			return;
		}
		
		if(strlen(SayText) > 62)
		{
			PrintToChat(client, "\x04[SM_GangsMod] \x01The name of your gang may not be as long");
			return;
		}
 
		ReplaceString(SayText, sizeof(SayText), "'", ".");
		ReplaceString(SayText, sizeof(SayText), "<", ".");
		ReplaceString(SayText, sizeof(SayText), "\"", ".");
		
		new prueba = -1;
		if(GetTrieValue(g_ListIndex2, SayText, prueba))
		{
			PrintToChat(client, "\x04[SM_GangsMod] \x01The name of this gang already exist, write other name");
			return;
		}
		decl String:status_steamid[24];
		GetClientAuthString(client, status_steamid, sizeof(status_steamid));
		new listado = -1;
		GetTrieValue(g_ListIndex, status_steamid, listado);
		
		if(!StrEqual("nothing",g_list[listado][banda],false))
		{
			PrintToChat(client, "\x04[SM_GangsMod] \x01You already have a gang");
			creandobanda[client] = false;
			return;
		}
		
		PrintToChat(client, "\x04[SM_GangsMod] \x01Your gang has been created successfully, the name of your gang is %s",SayText);
		LogToFile(Logfile, "Player %N [%s] has been created the gang %s",client,status_steamid,SayText);
		
		KvJumpToKey(bandas_nombres, SayText, true);
		
		strcopy(g_list2[g_ListCount2][nombre], sizeof(SayText), SayText);
			
			
		SetTrieValue(g_ListIndex2, g_list2[g_ListCount2][nombre], g_ListCount2);
			
		Format(g_list2[g_ListCount2][propietario], 24, status_steamid);
		//Format(lista_miembros[g_ListCount2], 512, "null, null, null, null, null");
		//Format(g_list2[g_ListCount2][miembros], 512, "ninguno");
		g_list2[g_ListCount2][numero_miembros] = 0;
		g_list2[g_ListCount2][vida] = 1;
		g_list2[g_ListCount2][granada] = 1;
		g_list2[g_ListCount2][glock] = 1;
			
		KvSetString(bandas_nombres, "owner", g_list2[g_ListCount2][propietario]);
		
		decl String:sTemp[512] = "null, null, null, null, null";
		Format(g_list2[g_ListCount2][miembros], 512, sTemp);
		KvSetString(bandas_nombres, "members", g_list2[g_ListCount2][miembros]);
		g_iNumCommands[g_ListCount2] = 0;
		g_iNumCommands[g_ListCount2] = ExplodeString(sTemp, ", ", lista_miembros[g_ListCount2], 10, 24);
		//KvSetString(bandas_nombres, "members", g_list2[g_ListCount2][miembros]);
		KvSetNum(bandas_nombres, "member_number", g_list2[g_ListCount2][numero_miembros]);
		KvSetNum(bandas_nombres, "armor", g_list2[g_ListCount2][vida]);
		KvSetNum(bandas_nombres, "grenade", g_list2[g_ListCount2][granada]);
		KvSetNum(bandas_nombres, "glock", g_list2[g_ListCount2][glock]);
			
			
		g_ListCount2++;
		
		KvRewind(bandas_nombres);	
		KeyValuesToFile(bandas_nombres, KV_BANDAS);
		
		creandobanda[client] = false;
		
		
		Format(g_list[listado][banda], 64, SayText);
		
		KvJumpToKey(bandas_jugadores, status_steamid);
		
		KvSetString(bandas_jugadores, "gang", g_list[listado][banda]);
		
		KvRewind(bandas_jugadores);	
		
		Store_GiveCredits(Store_GetClientAccountID(client), -500);
		
		InfoJugadores();
		InfoBandas();
		
	}
}


public Action:Menu_salirbanda(clientId) 
{
	new Handle:menu = CreateMenu(DIDMenuHandler_dejarbanda);
	SetMenuTitle(menu, "Currently you are in a gang, you want exit from it?");
	AddMenuItem(menu, "opcion1", "Yes exit from my current gang");
	AddMenuItem(menu, "opcion2", "No, stay in my gang");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, clientId, MENU_TIME_FOREVER);
	
}

public DIDMenuHandler_dejarbanda(Handle:menu, MenuAction:action, client, itemNum) 
{
    if ( action == MenuAction_Select ) 
    {
        new String:info[32];
        
        GetMenuItem(menu, itemNum, info, sizeof(info));

        if ( strcmp(info,"opcion1") == 0 ) 
        {
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			
			
			new listado2 = -1;
			if(!GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2))
			{
				PrintToChat(client, "\x04[SM_GangsMod] \x01Now you not have a gang");
				return;
			}
			
			
			//PrintToChatAll("casi llegado xd");
			if(!StrEqual(g_list2[listado2][propietario],status_steamid,false))
			{
				//PrintToChatAll("llegado xd");
				//ReplaceString(g_list2[listado2][miembros], 512, status_steamid, "");
				for(new i = 0; i < g_iNumCommands[listado2]; i++)
				{
					if(StrEqual(status_steamid, lista_miembros[listado2][i]))
					{
						Format(lista_miembros[listado2][i], 24, "null");
					}
				}

				g_list2[listado2][numero_miembros]--;
				KvJumpToKey(bandas_nombres, g_list[listado][banda]);
				KvSetNum(bandas_nombres, "member_number", g_list2[listado2][numero_miembros]);
				

				//ReplaceString(g_list2[listado2][miembros], 512, status_steamid, "null",false);
				ImplodeStrings(lista_miembros[listado2], g_iNumCommands[listado2], ", ", g_list2[listado2][miembros], 512);
				KvSetString(bandas_nombres, "members", g_list2[listado2][miembros]);

		
				//KvSetString(bandas_nombres, "members", g_list2[listado2][miembros]);
		
				KvRewind(bandas_nombres);
				
				decl String:antiguabanda[64];
				Format(antiguabanda, 64, g_list[listado][banda]);
				Format(g_list[listado][banda], 64, "nothing");
				
				KvJumpToKey(bandas_jugadores, status_steamid);
			

		
				KvSetString(bandas_jugadores, "gang", g_list[listado][banda]);
		
				KvRewind(bandas_jugadores);
				
				PrintToChat(client, "\x04[SM_GangsMod] \x01You are out of %s gang, you can search a new gang",antiguabanda);
				LogToFile(Logfile,"Player %N is out of gang %s",client,antiguabanda);
				
				InfoJugadores();
				InfoBandas();
			}
			else if(g_list2[listado2][numero_miembros] > 0)
			{
				Did_pasarlider(client, listado2);
			}
			else
			{
				KvRewind(bandas_nombres);
				//KvDeleteKey(bandas_nombres, g_list[listado][banda]);
				if(KvJumpToKey(bandas_nombres, g_list[listado][banda]))
					KvDeleteThis(bandas_nombres);
				//RemoveFromTrie(g_ListIndex2, g_list[listado][banda]);
				
		
				//KvSetString(bandas_nombres, "members", g_list2[listado2][miembros]);
		
				KvRewind(bandas_nombres);
				InfoBandas();
				
				ListaCacheBandas();
				
				decl String:antiguabanda[64];
				Format(antiguabanda, 64, g_list[listado][banda]);
				Format(g_list[listado][banda], 64, "nothing");
				
				KvJumpToKey(bandas_jugadores, status_steamid);
			

		
				KvSetString(bandas_jugadores, "gang", g_list[listado][banda]);
		
				KvRewind(bandas_jugadores);
				
				//PrintToChat(client, "\x04[SM_GangsMod] \x01Has dejado tu banda, ahora puedes buscar otra");
				
				InfoJugadores();
				
				PrintToChat(client, "\x04[SM_GangsMod] \x01You are out of your gang, and as you are only member of your gang, the gang disappeared");
				
				LogToFile(Logfile,"Player %N is out of gang %s and this gang disappeared",client,antiguabanda);
			}
            
        }
    }

    else if (action == MenuAction_Cancel) 
    { 
        PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
    } 

    else if (action == MenuAction_End)
    {
		CloseHandle(menu);
    }
}

Did_pasarlider(client, listado2)
{
				new Handle:menu = CreateMenu(DIDMenuHandler_pasarlider);
				SetMenuTitle(menu, "You are the owner of this gang\nto exit then select a new owner");
				
				
				for (new i = 0; i < g_iNumCommands[listado2]; i++)
				{
					if(StrEqual("null", lista_miembros[listado2][i],false))
						continue;
						
						
					new listado3 = -1;
					GetTrieValue(g_ListIndex, lista_miembros[listado2][i], listado3);
						
					decl String:desc_item[12];
					Format(desc_item, 12, "%i",listado3);
					AddMenuItem(menu, desc_item, g_list[listado3][nombre]);
				}
				
				SetMenuExitButton(menu, true);
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public DIDMenuHandler_pasarlider(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32];
        
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		new listado = StringToInt(info);
		
		new listado2 = -1;
		GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2);
		

		//KvGotoFirstSubKey(bandas_nombres);

		
		for(new i = 0; i < g_iNumCommands[listado2]; i++)
		{
					if(StrEqual(g_list[listado][steamid], lista_miembros[listado2][i]))
					{
						Format(lista_miembros[listado2][i], 24, "null");
					}
		}
		decl String:tempo[24];
		Format(tempo, 24, g_list2[listado2][propietario]);
		Format(g_list2[listado2][propietario], 24, g_list[listado][steamid]);
		g_list2[listado2][numero_miembros]--;
		KvJumpToKey(bandas_nombres, g_list[listado][banda]);
		KvSetString(bandas_nombres, "owner", g_list2[listado2][propietario]);
		KvSetNum(bandas_nombres, "member_number", g_list2[listado2][numero_miembros]);
				

		//ReplaceString(g_list2[listado2][miembros], 512, g_list[listado][steamid], "null",false);
		ImplodeStrings(lista_miembros[listado2], g_iNumCommands[listado2], ", ", g_list2[listado2][miembros], 512);
		KvSetString(bandas_nombres, "members", g_list2[listado2][miembros]);
		
		
				
		KvRewind(bandas_nombres);
		
		//Format(g_list2[listado2][propietario], 64, "nothing");
				
		KvJumpToKey(bandas_jugadores, tempo);
				
		new listado3 = -1;
		GetTrieValue(g_ListIndex, tempo, listado3);
		
		decl String:antiguabanda[64];
		Format(antiguabanda, 64, g_list[listado3][banda]);
				
		Format(g_list[listado3][banda], 64, "nothing");
		
		KvSetString(bandas_jugadores, "gang", g_list[listado3][banda]);
		
		KvRewind(bandas_jugadores);
		
		
		InfoJugadores();
		InfoBandas();
		
		PrintToChat(client, "\x04[SM_GangsMod] \x01Now you are out of your gang, now you can search a new gang");
		
		LogToFile(Logfile,"Player %N is out of %s leaving as owner to %s",client,antiguabanda,g_list2[listado2][propietario]);
		
	}
		
		

        
	else if (action == MenuAction_Cancel) 
	{ 
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
	} 

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}

}



Menu_infobanda(client, listado) 
{
	new listado2 = -1;
	GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2);
	
	
	new Handle:menu = CreateMenu(DIDMenuHandler_infobanda);
	SetMenuTitle(menu, "Information of your gang");
	decl String:itemok[128];
	
	Format(itemok, 128, "Name: %s",g_list2[listado2][nombre]);
	AddMenuItem(menu, "1", itemok);
	
	Format(itemok, 128, "Owner: %s",g_list2[listado2][propietario]);
	AddMenuItem(menu, "2", itemok);
	
	Format(itemok, 128, "Number of members: %i\n------Habilidades de la banda------",g_list2[listado2][numero_miembros]);
	AddMenuItem(menu, "3", itemok);
	
	Format(itemok, 128, "Extra armor: %i",g_list2[listado2][vida]);
	AddMenuItem(menu, "4", itemok);
	
	Format(itemok, 128, "Extra grenade: %i",g_list2[listado2][granada]);
	AddMenuItem(menu, "5", itemok);
	
	Format(itemok, 128, "Extra glock: %i",g_list2[listado2][glock]);
	AddMenuItem(menu, "6", itemok);
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
}

public DIDMenuHandler_infobanda(Handle:menu, MenuAction:action, client, itemNum) 
{

	if (action == MenuAction_Cancel) 
	{ 
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
	} 

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}



Menu_gestionbanda(client, listado) 
{
	new listado2 = -1;
	GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2);
	
	decl String:status_steamid[24];
	GetClientAuthString(client, status_steamid, sizeof(status_steamid));
	
	
	if(!StrEqual(g_list2[listado2][propietario],status_steamid,false))
	{
		PrintToChat(client, "\x04[SM_GangsMod] \x01You not are the owner of your gang");
		return;
	}
	
	new Handle:menu = CreateMenu(DIDMenuHandler_gestionbanda);
	SetMenuTitle(menu, "Management of your gang");
	
	AddMenuItem(menu, "opcion1", "Invite someone to your gang");
	AddMenuItem(menu, "opcion2", "Give leadership to someone");
	AddMenuItem(menu, "opcion3", "Expelling someone from your gang");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
}

public DIDMenuHandler_gestionbanda(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
        new String:info[32];
        
        GetMenuItem(menu, itemNum, info, sizeof(info));
		
        if ( strcmp(info,"opcion1") == 0 ) 
        {
			Invitar(client);
		}

        else if ( strcmp(info,"opcion2") == 0 ) 
        {
			Pasarlider2(client);
		}
        else if ( strcmp(info,"opcion3") == 0 ) 
        {
			Expulsar(client);
		}
	}
		
	if (action == MenuAction_Cancel) 
	{ 
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
	} 

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

Pasarlider2(client)
{
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			
			//PrintToChatAll("lider");
			new listado2 = -1;
			GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2);
			new Handle:menu2 = CreateMenu(DIDMenuHandler_pasarlider2);
			SetMenuTitle(menu2, "Choose a new owner");
				
				
			for (new i = 0; i < g_iNumCommands[listado2]; i++)
			{
					if(StrEqual("null", lista_miembros[listado2][i],false))
						continue;
						
					new listado3 = -1;
					GetTrieValue(g_ListIndex, lista_miembros[listado2][i], listado3);
						
					decl String:desc_item[12];
					Format(desc_item, 12, "%i",listado3);
					AddMenuItem(menu2, desc_item, g_list[listado3][nombre]);
			}
				
			SetMenuExitButton(menu2, true);
			DisplayMenu(menu2, client, MENU_TIME_FOREVER);
}

public DIDMenuHandler_pasarlider2(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32];
        
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		new listado = StringToInt(info);
		
		new listado2 = -1;
		GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2);
		
		new listado3 = -1;
		GetTrieValue(g_ListIndex, g_list2[listado2][propietario], listado3);
		
		
		
				
		
		for(new i = 0; i < g_iNumCommands[listado2]; i++)
		{
					if(StrEqual(g_list[listado][steamid], lista_miembros[listado2][i]))
					{
						Format(lista_miembros[listado2][i], 24, g_list[listado3][steamid]);
					}
		}

				
		Format(g_list2[listado2][propietario], 24, g_list[listado][steamid]);
		//KvGotoFirstSubKey(bandas_nombres);
		KvJumpToKey(bandas_nombres, g_list[listado][banda]);
		//KvSetNum(bandas_nombres, "member_number", KvGetNum(bandas_nombres, "member_number")-1);
		

		//ReplaceString(g_list2[listado2][miembros], 512, g_list[listado][steamid], g_list[listado3][steamid],false);
		ImplodeStrings(lista_miembros[listado2], g_iNumCommands[listado2], ", ", g_list2[listado2][miembros], 512);
		KvSetString(bandas_nombres, "members", g_list2[listado2][miembros]);
		
		KvSetString(bandas_nombres, "owner", g_list2[listado2][propietario]);
		//KvJumpToKey(bandas_nombres, "members");
		
		//KvSetString(bandas_nombres, g_list[listado][steamid], g_list[listado3][propietario]);
		//PrintToChatAll("el valor es: %s",g_list[listado3][steamid]);
		
		//KvDeleteKey(bandas_nombres, g_list[listado][steamid]);
		KvRewind(bandas_nombres);
		InfoBandas();
		
		//Format(g_list2[listado2][propietario], 24, g_list[listado][steamid]);
		//Format(g_list2[listado2][propietario], 64, "nothing");
				
		//KvJumpToKey(bandas_jugadores, g_list2[listado2][propietario]);
				

		/*		
		Format(g_list[listado3][banda], 64, "nothing");
		
		KvSetString(bandas_jugadores, "gang", g_list[listado3][banda]);
		
		KvRewind(bandas_jugadores);
		
		//KvGotoFirstSubKey(bandas_nombres);
		KvJumpToKey(bandas_nombres, g_list[listado][banda]);
		KvSetString(bandas_nombres, "owner", g_list[listado][steamid]);

				
		KvRewind(bandas_nombres);
		
*/
		//InfoJugadores();
		
		PrintToChat(client, "\x04[SM_GangsMod] \x01The change of owner was successfull");
		
		LogToFile(Logfile,"Player %s [%s] has given the owner of %s to %s [%s]",g_list[listado3][nombre],g_list[listado3][steamid],g_list[listado][banda],g_list[listado][nombre],g_list[listado][steamid]);
	}
		
		

        
	else if (action == MenuAction_Cancel) 
	{ 
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
	} 

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}

}



Invitar(client) 
{
	
	new Handle:menu = CreateMenu(DIDMenuHandler_invitarbanda);
	SetMenuTitle(menu, "Select a player for send invitation");
	decl String:itemok[128];
	decl String:numero[5];
	new cuenta = 0;
	for (new i = 0; i < GetTrieSize(g_ListIndex); i++)
	{
		if(!StrEqual(g_list[i][banda], "nothing"))
			continue;
			
		Format(itemok, 512, "%s - %s",g_list[i][nombre],g_list[i][steamid]);
		IntToString(i, numero, 5);
		AddMenuItem(menu, numero, itemok);
		cuenta++;
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	if(cuenta < 1) PrintToChat(client,"\x04[SM_GangsMod] \x01Gangless players not found");
	
}

public DIDMenuHandler_invitarbanda(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		decl String:status_steamid[24];
		GetClientAuthString(client, status_steamid, sizeof(status_steamid));
		new listado6 = -1;
		GetTrieValue(g_ListIndex, status_steamid, listado6);
			
		new listado7 = -1;
		GetTrieValue(g_ListIndex2, g_list[listado6][banda], listado7);
		if(g_list2[listado7][numero_miembros] >= 5)
		{
			PrintToChat(client,"\x04[SM_GangsMod] \x01Your gang is completed");
			return;
		}
	
		new String:info[32];
        
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		new listado = StringToInt(info);
		if(!StrEqual(g_list[listado][banda], "nothing"))
		{
			PrintToChat(client,"\x04[SM_GangsMod] \x01This player already have a gang");
			return;
		}
		
		
		new listado3 = -1;
		GetTrieValue(g_ListIndex, status_steamid, listado3);
		Format(g_list[listado][invitacion], 64, g_list[listado3][banda]);
		
		KvJumpToKey(bandas_jugadores, g_list[listado][steamid]);
		KvSetString(bandas_jugadores, "invitation", g_list[listado][invitacion]);
		
		PrintToChat(client,"\x04[SM_GangsMod] \x01Invitation sent to %s",g_list[listado][nombre]);
		
		KvRewind(bandas_jugadores);
		InfoJugadores();
		
		for (new i = 1; i < MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				GetClientAuthString(i, status_steamid, sizeof(status_steamid));
				if(StrEqual(status_steamid, g_list[listado][steamid]))
				{
					Invitado(i, listado);
				}
			}
		}
		LogToFile(Logfile,"Owner %s [%s] of the gang %s has sent invitation to %s [%s]",g_list[listado6][nombre],g_list[listado6][steamid],g_list[listado6][banda],g_list[listado][nombre],g_list[listado][steamid]);
		
		
		
	}
		
	if (action == MenuAction_Cancel) 
	{ 
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
	} 

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}



Expulsar(client) 
{
	decl String:status_steamid[24];
	GetClientAuthString(client, status_steamid, sizeof(status_steamid));
		
	new listado = -1;
	GetTrieValue(g_ListIndex, status_steamid, listado);
	new listado2 = -1;
	GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2);
	
	new Handle:menu = CreateMenu(DIDMenuHandler_expulsarbanda);
	SetMenuTitle(menu, "Select a member of your gang to eject");
	decl String:itemok[128];
	decl String:numero[5];
	new cuenta = 0;
	for (new i = 0; i < GetTrieSize(g_ListIndex); i++)
	{
		if(!StrEqual(g_list[i][banda], g_list[listado][banda]) || StrEqual(g_list[i][steamid], g_list[listado][steamid]))
			continue;
			
		Format(itemok, 512, "%s - %s",g_list[i][nombre],g_list[i][steamid]);
		IntToString(i, numero, 5);
		AddMenuItem(menu, numero, itemok);
		cuenta++;
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	if(cuenta < 1) PrintToChat(client,"\x04[SM_GangsMod] \x01Members not found");
	
}

public DIDMenuHandler_expulsarbanda(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32];
        
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		new listado = StringToInt(info);
		
		new listado2 = -1;
		GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2);
		
		decl String:labanda[64];
		Format(labanda, 64, g_list[listado][banda]);
		
		Format(g_list[listado][banda], 64, "nothing");
		Format(g_list[listado][expulsado], 5, "si");
		
		KvJumpToKey(bandas_jugadores, g_list[listado][steamid]);
		KvSetString(bandas_jugadores, "expelled", g_list[listado][expulsado]);
		KvSetString(bandas_jugadores, "gang", g_list[listado][banda]);
		
		PrintToChat(client,"\x04[SM_GangsMod] \x01Expelled to %s",g_list[listado][nombre]);
		
		KvRewind(bandas_jugadores);
		InfoJugadores();
		
		decl String:status_steamid[24];
		for (new i = 1; i < MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				GetClientAuthString(i, status_steamid, sizeof(status_steamid));
				if(StrEqual(status_steamid, g_list[listado][steamid]))
				{
					Expulsado(i);
				}
			}
		}
		
		
		for(new i = 0; i < g_iNumCommands[listado2]; i++)
		{
					if(StrEqual(g_list[listado][steamid], lista_miembros[listado2][i]))
					{
						Format(lista_miembros[listado2][i], 24, "null");
					}
		}

				
				
		//KvGotoFirstSubKey(bandas_nombres);
		g_list2[listado2][numero_miembros]--;
		KvJumpToKey(bandas_nombres, labanda);
		KvSetNum(bandas_nombres, "member_number", g_list2[listado2][numero_miembros]);
		
		//ReplaceString(g_list2[listado2][miembros], 512, g_list[listado][steamid], "null",false);
		ImplodeStrings(lista_miembros[listado2], g_iNumCommands[listado2], ", ", g_list2[listado2][miembros], 512);
		//PrintToChatAll(g_list2[listado2][miembros]);
		KvSetString(bandas_nombres, "members", g_list2[listado2][miembros]);

		
		//KvDeleteKey(bandas_nombres, g_list[listado][steamid]);
		KvRewind(bandas_nombres);
		InfoBandas();
		
		LogToFile(Logfile,"Owner %N [%s] of gang %s has expelled to %s [%s]",client,g_list2[listado2][propietario],labanda,g_list[listado][nombre],g_list[listado][steamid]);
		
	}
		
	if (action == MenuAction_Cancel) 
	{ 
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
	} 

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}


Mejorarbanda(client, listado) 
{
	new listado2 = -1;
	GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2);
	
	new Handle:menu = CreateMenu(DIDMenuHandler_mejorarbanda);
	SetMenuTitle(menu, "Name of ability - current level - price - For team");
	decl String:itemok[128];
	
	Format(itemok, 128, "Extra armor - %i - 200 credits - Both",g_list2[listado2][vida]);
	if(g_list2[listado2][vida] >= 100)
		AddMenuItem(menu, "opcion1", itemok,ITEMDRAW_DISABLED);
	else
		AddMenuItem(menu, "opcion1", itemok);
		
	Format(itemok, 128, "Extra grenade - %i - 125 credits - Terrorist",g_list2[listado2][granada]);
	if(g_list2[listado2][granada] >= 100)
		AddMenuItem(menu, "opcion2", itemok,ITEMDRAW_DISABLED);
	else
		AddMenuItem(menu, "opcion2", itemok);
	
	Format(itemok, 128, "Extra glock - %i - 225 credits - Both",g_list2[listado2][glock]);
	if(g_list2[listado2][glock] >= 100)
		AddMenuItem(menu, "opcion3", itemok,ITEMDRAW_DISABLED);
	else
		AddMenuItem(menu, "opcion3", itemok);
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	
}

public DIDMenuHandler_mejorarbanda(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32];
        
		GetMenuItem(menu, itemNum, info, sizeof(info));
		if ( strcmp(info,"opcion1") == 0 ) 
        {
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
		
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			new listado2 = -1;
			if(!GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2))
			{
				PrintToChat(client, "\x04[SM_GangsMod] \x01You already not have a gang!");
				return;
			}
			
			new Handle:pack = CreateDataPack();
			WritePackCell(pack, client);
			WritePackCell(pack, listado);
			WritePackCell(pack, listado2);
			//WritePackCell(pack, credits);
			Store_GetCredits(Store_GetClientAccountID(client), GetCreditsCallbackAtributo1, pack);
		
		}
		else if ( strcmp(info,"opcion2") == 0 ) 
		{
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
		
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			new listado2 = -1;
			if(!GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2))
			{
				PrintToChat(client, "\x04[SM_GangsMod] \x01You already not have a gang!");
				return;
			}
			
			new Handle:pack = CreateDataPack();
			WritePackCell(pack, client);
			WritePackCell(pack, listado);
			WritePackCell(pack, listado2);
			//WritePackCell(pack, credits);
			Store_GetCredits(Store_GetClientAccountID(client), GetCreditsCallbackAtributo2, pack);
		}
		else if ( strcmp(info,"opcion3") == 0 ) 
		{
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
		
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			new listado2 = -1;
			if(!GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2))
			{
				PrintToChat(client, "\x04[SM_GangsMod] \x01You already not have a gang!");
				return;
			}
			
			new Handle:pack = CreateDataPack();
			WritePackCell(pack, client);
			WritePackCell(pack, listado);
			WritePackCell(pack, listado2);
			//WritePackCell(pack, credits);
			Store_GetCredits(Store_GetClientAccountID(client), GetCreditsCallbackAtributo3, pack);
		}
		
		
		
		
	}
		
	if (action == MenuAction_Cancel) 
	{ 
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
	} 

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public GetCreditsCallbackAtributo1(credits, any:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new listado = ReadPackCell(pack);
	new listado2 = ReadPackCell(pack);
	
		
	if(credits >= 200)
	{
		g_list2[listado2][vida]++;
		KvJumpToKey(bandas_nombres, g_list[listado][banda]);
		KvSetNum(bandas_nombres, "armor", g_list2[listado2][vida]);
		KvRewind(bandas_nombres);
		InfoBandas();
		PrintToChat(client, "\x04[SM_GangsMod] \x01Ability of Extra armor improved");
		Store_GiveCredits(Store_GetClientAccountID(client), -200);
		
		LogToFile(Logfile, "Player %s [%s] of gang %s has improved ability Extra armor", g_list[listado][nombre],g_list[listado][steamid],g_list[listado][banda]);
		
	}
	else
	{
		PrintToChat(client, "\x04[SM_GangsMod] \x01You do not have enough credits to improve the ability");
	}
}

public GetCreditsCallbackAtributo2(credits, any:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new listado = ReadPackCell(pack);
	new listado2 = ReadPackCell(pack);
	
		
	if(credits >= 125)
	{
		g_list2[listado2][granada]++;
		KvJumpToKey(bandas_nombres, g_list[listado][banda]);
		KvSetNum(bandas_nombres, "grenade", g_list2[listado2][granada]);
		KvRewind(bandas_nombres);
		InfoBandas();
		PrintToChat(client, "\x04[SM_GangsMod] \x01Ability of Grenades improved");
		Store_GiveCredits(Store_GetClientAccountID(client), -125);
		
		LogToFile(Logfile, "Player %s [%s] of gang %s has improved ability Grenades", g_list[listado][nombre],g_list[listado][steamid],g_list[listado][banda]);
	}
	else
	{
		PrintToChat(client, "\x04[SM_GangsMod] \x01You do not have enough credits to improve the ability");
	}
}

public GetCreditsCallbackAtributo3(credits, any:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new listado = ReadPackCell(pack);
	new listado2 = ReadPackCell(pack);
	
		
	if(credits >= 225)
	{
		g_list2[listado2][glock]++;
		KvJumpToKey(bandas_nombres, g_list[listado][banda]);
		KvSetNum(bandas_nombres, "glock", g_list2[listado2][glock]);
		KvRewind(bandas_nombres);
		InfoBandas();
		PrintToChat(client, "\x04[SM_GangsMod] \x01Glock ability improved");
		Store_GiveCredits(Store_GetClientAccountID(client), -225);
		
		LogToFile(Logfile, "Player %s [%s] of gang %s has improved glock ability", g_list[listado][nombre],g_list[listado][steamid],g_list[listado][banda]);
	}
	else
	{
		PrintToChat(client, "\x04[SM_GangsMod] \x01You do not have enough credits to improve the ability");
	}
}

Expulsado(client) 
{
	new Handle:menu = CreateMenu(DIDMenuHandler_expulsado);
	SetMenuTitle(menu, "We notify to you that you has been expelled of your gang\nSearch a new gang");
	AddMenuItem(menu, "opcion1", "Ok, dont remember me more");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	
}

public DIDMenuHandler_expulsado(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32];
        
		GetMenuItem(menu, itemNum, info, sizeof(info));
		if ( strcmp(info,"opcion1") == 0 ) 
        {
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
		
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			
			Format(g_list[listado][expulsado], 12, "no");
			KvJumpToKey(bandas_jugadores, g_list[listado][steamid]);
			KvSetString(bandas_jugadores, "expelled", g_list[listado][expulsado]);
		
			KvRewind(bandas_jugadores);
			InfoJugadores();
			
			PrintToChat(client, "\x04[SM_GangsMod] \x01Now this not will be remembered more, you must search a new gang");
			
		
		}
	}
		
	if (action == MenuAction_Cancel) 
	{ 
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
	} 

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}


Invitado(client, listado) 
{
	new Handle:menu = CreateMenu(DIDMenuHandler_invitado);
	SetMenuTitle(menu, "You are invited to the gang %s",g_list[listado][invitacion]);
	AddMenuItem(menu, "opcion1", "Accept invitation");
	AddMenuItem(menu, "opcion2", "Reject invitation");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	
}

public DIDMenuHandler_invitado(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32];
        
		GetMenuItem(menu, itemNum, info, sizeof(info));
		if ( strcmp(info,"opcion1") == 0 ) 
        {
			decl String:status_steamid[24];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
		
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			
			new listado2 = -1;
			if(!GetTrieValue(g_ListIndex2, g_list[listado][invitacion], listado2))
			{
				Format(g_list[listado][invitacion], 64, "nothing");
				KvJumpToKey(bandas_jugadores, g_list[listado][steamid]);
				KvSetString(bandas_jugadores, "invitation", g_list[listado][invitacion]);
		
				KvRewind(bandas_jugadores);
				InfoJugadores();
				PrintToChat(client, "\x04[SM_GangsMod] \x01Sorry but currently this gang not longer exist");
				return;
			}
			if(g_list2[listado2][numero_miembros] >= 5)
			{
				Format(g_list[listado][invitacion], 64, "nothing");
				KvJumpToKey(bandas_jugadores, g_list[listado][steamid]);
				KvSetString(bandas_jugadores, "invitation", g_list[listado][invitacion]);
		
				KvRewind(bandas_jugadores);
				InfoJugadores();
				PrintToChat(client, "\x04[SM_GangsMod] \x01Sorry but this gang is completed");
				return;
			}
			else
			{
				
				Format(g_list[listado][banda], 64, g_list[listado][invitacion]);
				Format(g_list[listado][invitacion], 64, "nothing");
				KvJumpToKey(bandas_jugadores, g_list[listado][steamid]);
				KvSetString(bandas_jugadores, "invitation", g_list[listado][invitacion]);
				KvSetString(bandas_jugadores, "gang", g_list[listado][banda]);
		
				KvRewind(bandas_jugadores);
				InfoJugadores();
				
				for(new i = 0; i < g_iNumCommands[listado2]; i++)
				{
					if(StrEqual(lista_miembros[listado2][i], "null"))
					{
						Format(lista_miembros[listado2][i], 24, g_list[listado][steamid]);
						break;
					}
				}
				
				g_list2[listado2][numero_miembros]++;
				KvJumpToKey(bandas_nombres, g_list[listado][banda]);
				KvSetNum(bandas_nombres, "member_number", g_list2[listado2][numero_miembros]);
				

				//ReplaceString(g_list2[listado2][miembros], 512, status_steamid, "null",false);
				ImplodeStrings(lista_miembros[listado2], g_iNumCommands[listado2], ", ", g_list2[listado2][miembros], 512);
				KvSetString(bandas_nombres, "members", g_list2[listado2][miembros]);

		
				//KvSetString(bandas_nombres, "members", g_list2[listado2][miembros]);
		
				KvRewind(bandas_nombres);
				InfoBandas();
				
				PrintToChat(client, "\x04[SM_GangsMod] \x01You have joined the gang %s",g_list[listado][banda]);
				
				decl String:status_steamid2[24];
				for (new i = 1; i < MaxClients; i++)
				{
					if (IsClientInGame(i))
					{
						GetClientAuthString(i, status_steamid2, sizeof(status_steamid2));
						if(StrEqual(status_steamid2, g_list2[listado2][propietario]))
						{
							PrintToChat(i, "\x04[SM_GangsMod]\x01 %N has joined to your gang",client);
						}
					}
				}
				
				LogToFile(Logfile, "Player %s [%s] has joined to gang %s", g_list[listado][nombre],g_list[listado][steamid],g_list[listado][banda]);
			}
		}
		else if ( strcmp(info,"opcion2") == 0 ) 
        {
			decl String:status_steamid[24], String:bandita[64];
			GetClientAuthString(client, status_steamid, sizeof(status_steamid));
		
			new listado = -1;
			GetTrieValue(g_ListIndex, status_steamid, listado);
			Format(bandita, 64, g_list[listado][invitacion]);
			
			Format(g_list[listado][invitacion], 64, "nothing");
			KvJumpToKey(bandas_jugadores, g_list[listado][steamid]);
			KvSetString(bandas_jugadores, "invitation", g_list[listado][invitacion]);
		
			KvRewind(bandas_jugadores);
			InfoJugadores();
			
			PrintToChat(client, "\x04[SM_GangsMod] \x01You have declined the invitation to join the gang %s", bandita);
		}
	}
		
	if (action == MenuAction_Cancel) 
	{ 
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
	} 

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action:Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new equipo = GetClientTeam(client);
	
	if(!IsPlayerAlive(client) || (equipo != 2 && equipo != 3) ) return;
	
	decl String:status_steamid[24];
	GetClientAuthString(client, status_steamid, sizeof(status_steamid));
	new listado = -1;
	if(!GetTrieValue(g_ListIndex, status_steamid, listado)) return;
	
	
	if(!StrEqual(g_list[listado][banda], "nothing"))
	{
		AplicarHabilidad(client, listado);
	}
	else
	{
		if(StrEqual(g_list[listado][expulsado], "si"))
		{
			Expulsado(client);
			return;
		}
		else if(!StrEqual(g_list[listado][invitacion], "nothing"))
		{
			Invitado(client, listado);
			return;
		}
	}
}

AplicarHabilidad(client, listado)
{
	new equipo = GetClientTeam(client);
	
	
	new listado2 = -1;
	GetTrieValue(g_ListIndex2, g_list[listado][banda], listado2);

	new total = (g_list2[listado2][vida] * 2);

	SetEntProp( client, Prop_Send, "m_ArmorValue", total, 1 );
	PrintToChat(client, "\x04[SM_GangsMod] \x01Ability \"Armor\" has given you %i of Armor", total);
	
	if(equipo == 2)
	{	
		new suerte = GetRandomInt(1, 100);
		if(suerte <= g_list2[listado2][granada])
		{
			GivePlayerItem(client, "weapon_hegrenade");
			PrintToChat(client, "\x04[SM_GangsMod] \x01Ability \"grenade\" has give you a grenade");
		
		}
		new suerte2 = GetRandomInt(1, 100);
		if(suerte2 <= g_list2[listado2][glock])
		{
			new ent = GivePlayerItem(client, "weapon_glock");
			SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
			SetEntityRenderColor(ent, 255, 215, 0);
			PrintToChat(client, "\x04[SM_GangsMod] \x01Ability \"glock\" has give you a glock");
		
		}
	}
}


BuscarBanda(client) 
{
	new Handle:menu = CreateMenu(DIDMenuHandler_buscar);
	SetMenuTitle(menu, "Choose a gang");
	decl String:numero[5];
	decl String:itemok[128];
	new cuenta = 0;
	for (new i = 0; i < GetTrieSize(g_ListIndex2); i++)
	{
			
		
		IntToString(i, numero, 5);
		if(g_list2[i][numero_miembros] >= 5)
		{
			Format(itemok, 512, "%s (completed)",g_list2[i][nombre]);
			AddMenuItem(menu, numero, itemok,ITEMDRAW_DISABLED);
		}
		else
		{
			Format(itemok, 512, "%s",g_list2[i][nombre]);
			AddMenuItem(menu, numero, itemok);
		}
		cuenta++;
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	if(cuenta < 1) PrintToChat(client, "\x04[SM_GangsMod] \x01Gangs not found");
	
	
}

public DIDMenuHandler_buscar(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32];
        
		GetMenuItem(menu, itemNum, info, sizeof(info));
		new listado2 = StringToInt(info);
		
		
		

		
		decl String:status_steamid[24];
		new bool:encontrado = false;
		for (new i = 1; i < MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				GetClientAuthString(i, status_steamid, sizeof(status_steamid));
				if(StrEqual(status_steamid, g_list2[listado2][propietario]))
				{
					encontrado = true;
					PrintToChat(client, "\x04[SM_GangsMod] \x01The owner of gang is %N [%s] and he is in game, tell you that you want to join to the gang",i,g_list2[listado2][propietario]);
					PrintToChat(i, "\x04[SM_GangsMod] \x01Player %N want to join to your gang",client);
					break;
				}
			}
		}
		
		if(!encontrado)
		{
			new listado3 = -1;
			GetTrieValue(g_ListIndex, g_list2[listado2][propietario], listado3);
			decl String:amigo[512];
			GetCommunityIDString(g_list2[listado2][propietario], amigo, 18);
			
			PrintToChat(client, "\x04[SM_GangsMod] \x01Owner of the gang is not in game, he is %s and if you want to add to be invited to his gang, his steam profile is",g_list[listado3][nombre]);
			PrintToChat(client, "http://steamcommunity.com/profiles/%s",amigo);
		}
			
			
		
	}
		
	if (action == MenuAction_Cancel) 
	{ 
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
	} 

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

stock bool:GetCommunityIDString(const String:SteamID[], String:CommunityID[], const CommunityIDSize) 
{ 
    decl String:SteamIDParts[3][11]; 
    new const String:Identifier[] = "76561197960265728"; 
     
    if ((CommunityIDSize < 1) || (ExplodeString(SteamID, ":", SteamIDParts, sizeof(SteamIDParts), sizeof(SteamIDParts[])) != 3)) 
    { 
        CommunityID[0] = '\0'; 
        return false; 
    } 

    new Current, CarryOver = (SteamIDParts[1][0] == '1'); 
    for (new i = (CommunityIDSize - 2), j = (strlen(SteamIDParts[2]) - 1), k = (strlen(Identifier) - 1); i >= 0; i--, j--, k--) 
    { 
        Current = (j >= 0 ? (2 * (SteamIDParts[2][j] - '0')) : 0) + CarryOver + (k >= 0 ? ((Identifier[k] - '0') * 1) : 0); 
        CarryOver = Current / 10; 
        CommunityID[i] = (Current % 10) + '0'; 
    } 

    CommunityID[CommunityIDSize - 1] = '\0'; 
    return true; 
}  
