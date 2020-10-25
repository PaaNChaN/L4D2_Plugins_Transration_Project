/*
Vocalize To Chat
Copyright (C) 2014  Buster "Mr. Zero" Nielsen

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/* Includes */
#include <sourcemod>
#include <l4d_stocks>
#include <sceneprocessor>

/* Plugin Information */
public Plugin:myinfo = 
{
	name		= "Vocalize To Chat",
	author		= "Buster \"Mr. Zero\" Nielsen",
	description	= "Prints player initiated vocalize commands to chat.",
	version		= "1.0.0",
	url		= "mrzerodk@gmail.com"
}

/* Globals */
#define DEBUG 0
#define DEBUG_TAG "VocalizeToChat"

new String:g_TranslationPath[PLATFORM_MAX_PATH]

#define CONVAR_SCENE_MAXCAPTIONRADIUS "scene_maxcaptionradius"
new g_MaxDistFromScene

new Handle:g_CachedTranslatedVocalizes

#define PRINT_VOCALIZE_LAYOUT "\x01\x03%T %N\x01 :  %T\x01" // (Voice) Player :  Thanks!
#define PRINT_VOCALIZE_VOICE_TAG "(Voice)"

#define TRANSLATION_FILE "vocalizetochat.phrases.txt"
#define TRANSLATION_SMPATH "translations/vocalizetochat.phrases.txt"

#define USE_VERSION_CONVAR 1
#define CONVAR_VERSION_NAME "vocalizetochat_version"
#define CONVAR_VERSION_DESC "Version of Vocalize To Chat SourceMod plugin"
#define CONVAR_VERSION_VALUE "1.0.0"

/* Plugin Functions */
public OnPluginStart()
{
	g_CachedTranslatedVocalizes = CreateTrie()
	
	LoadTranslations(TRANSLATION_FILE)
	BuildPath(Path_SM, g_TranslationPath, sizeof(g_TranslationPath), TRANSLATION_SMPATH)
	
#if USE_VERSION_CONVAR
	CreateConVar(CONVAR_VERSION_NAME, CONVAR_VERSION_VALUE, CONVAR_VERSION_DESC, FCVAR_NOTIFY)
#endif
}

public OnConfigsExecuted()
{
	new Handle:convar = FindConVar(CONVAR_SCENE_MAXCAPTIONRADIUS)
	if (convar != INVALID_HANDLE)
	{
		g_MaxDistFromScene = GetConVarInt(convar)
	}
}

public OnSceneStageChanged(scene, SceneStages:stage)
{
	if (stage != SceneStage_Started)
	{
		return
	}
	
	new client = GetActorFromScene(scene)
	
#if DEBUG
	Debug_PrintText("Scene started")
	Debug_PrintText(" - Actor %d", client)
#endif
	
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || L4DTeam:GetClientTeam(client) != L4DTeam_Survivor)
	{
		return
	}
	
	new String:vocalize[128]
	if (GetSceneVocalize(scene, vocalize, sizeof(vocalize)) == 0)
	{
		return
	}
	
#if DEBUG
	Debug_PrintText(" - Vocalize \"%s\"", vocalize)
#endif
	
	if (!IsVocalizeInTranslation(vocalize))
	{
		return
	}
	
	StringToLower(vocalize)
	
	decl Float:sceneOrigin[3]
	decl Float:origin[3]
	GetClientAbsOrigin(client, sceneOrigin)
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue
		}
		
		if (L4DTeam:GetClientTeam(i) != L4DTeam_Survivor && !L4D_IsPlayerIdle(i))
		{
			continue
		}
		
		GetClientAbsOrigin(i, origin)
		
		if (i != client && GetVectorDistance(sceneOrigin, origin) > g_MaxDistFromScene)
		{
			continue
		}
		
#if DEBUG
		Debug_PrintText("Sending say text...")
#endif
		SayText2(i, client, PRINT_VOCALIZE_LAYOUT, PRINT_VOCALIZE_VOICE_TAG, i, client, vocalize, i)
#if DEBUG
		Debug_PrintText("Done!")
#endif
	}
}

bool:IsVocalizeInTranslation(const String:vocalize[])
{
	new isVocalizeValid = false
	if (GetTrieValue(g_CachedTranslatedVocalizes, vocalize, isVocalizeValid))
	{
		return bool:isVocalizeValid
	}
	
	decl String:translationString[128]
	Format(translationString, sizeof(translationString), "%s", vocalize)
	StringToLower(translationString)
	
	new Handle:file = OpenFile(g_TranslationPath, "r")
	
	if (file == INVALID_HANDLE)
	{
		return false
	}
	
	decl String:buffer[128]
	Format(translationString, sizeof(translationString), "\"%s\"", translationString)
	
	while (!IsEndOfFile(file) && ReadFileLine(file, buffer, 128))
	{
		StringToLower(buffer)
		if (StrContains(buffer, translationString) != -1)
		{
			isVocalizeValid = true
			break
		}
	}
	
	CloseHandle(file)
	SetTrieValue(g_CachedTranslatedVocalizes, vocalize, isVocalizeValid)
	return bool:isVocalizeValid
}

stock SayText2(client, author, const String:format[], any:...)
{
	decl String:buffer[256];
	VFormat(buffer, 256, format, 4);
	
	new Handle:hBuffer = StartMessageOne("SayText2", client);
	BfWriteByte(hBuffer, author);
	BfWriteByte(hBuffer, true);
	BfWriteString(hBuffer, buffer);
	EndMessage();
}

stock StringToLower(String:string[])
{
	new len = strlen(string)
	new i = 0
	
	for (i = 0; i < len; i++)
	{
		if (string[i] == '\0')
		{
			break
		}
		string[i] = CharToLower(string[i])
	}
	
	string[i] = '\0'
}

#if DEBUG
stock Debug_PrintText(const String:format[], any:...)
{
	decl String:buffer[256]
	VFormat(buffer, sizeof(buffer), format, 2)

	LogMessage(buffer)

	new AdminId:adminId
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client))
		{
			continue;
		}

		adminId = GetUserAdmin(client)
		if (adminId == INVALID_ADMIN_ID || !GetAdminFlag(adminId, Admin_Root))
		{
			continue
		}

		PrintToChat(client, "[%s] %s", DEBUG_TAG, buffer)
	}
}
#endif