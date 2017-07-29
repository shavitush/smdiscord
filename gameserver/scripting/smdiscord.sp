/*
 * SourceMod <-> Discord
 * by: shavit
 *
 * This file is part of SourceMod <-> Discord.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
*/

#include <sourcemod>
#include <dynamic>
#include <chat-processor>
#include <SteamWorks>

#pragma newdecls required
#pragma semicolon 1

#define SMDISCORD_VERSION "1.0"

ConVar hostname = null;
char gS_WebhookURL[1024];

public Plugin myinfo =
{
	name = "SourceMod <-> Discord",
	author = "shavit",
	description = "Relays in-game chat into a Discord channel.",
	version = SMDISCORD_VERSION,
	url = "https://github.com/shavitush/smdiscord"
}

public void OnPluginStart()
{
	hostname = FindConVar("hostname");
	CreateConVar("smdiscord_version", SMDISCORD_VERSION, "Plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	char[] sError = new char[256];

	if(!LoadConfig(sError, 256))
	{
		SetFailState("Couldn't load the configuration file. Error: %s", error);
	}
}

bool LoadConfig(char[] error, int maxlen)
{
	char[] sPath = new char[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/smdiscord.cfg");

	Dynamic dConfigFile = Dynamic();

	if(!dConfigFile.ReadKeyValues(sPath))
	{
		dConfigFile.Dispose();

		FormatEx(error, maxlen, "Couldn't access \"%s\". Make sure that the file exists and has correct permissions set.", sPath);

		return false;
	}

	dConfigFile.GetString("WebhookURL", gS_WebhookURL, 1024);

	if(StrContains(gS_WebhookURL, "https://discordapp.com/api/webhooks") == -1)
	{
		FormatEx(error, maxlen, "Please change the value of WebhookURL in the configuration file (\"%s\") to a valid URL. Current value is \"%s\".", sPath, gS_WebhookURL);

		return false;
	}

	return true;
}

void EscapeString(char[] string, int maxlen)
{
	ReplaceString(string, maxlen, "@", "＠");
	ReplaceString(string, maxlen, "'", "＇");
	ReplaceString(string, maxlen, "\"", "＂");
}

public Action OnChatMessage(int &author, ArrayList recipients, eChatFlags &flag, char[] name, char[] message, bool &bProcessColors, bool &bRemoveColors)
{
	char[] sHostname = new char[32];
	hostname.GetString(sHostname, 32);
	EscapeString(sHostname, 32);

	char[] sFormat = new char[1024];
	FormatEx(sFormat, 1024, "{\"username\":\"%s\", \"content\":\"{message}\"}", sHostname);
	
	char[] sAuthID = new char[32];
	GetClientAuthId(author, AuthId_Steam3, sAuthID, 32);

	char[] sTime = new char[8];
	FormatTime(sTime, 8, "%H:%I");

	char[] sNewMessage = new char[1024];
	FormatEx(sNewMessage, 1024, "%s | %s - %s: %s", sTime, sAuthID, name, message);
	EscapeString(sNewMessage, 1024);
	ReplaceString(sFormat, 1024, "{message}", sNewMessage);

	PrintToServer("%s", sFormat);

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, gS_WebhookURL);
	SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sFormat, strlen(sFormat));
	SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete));
	SteamWorks_SendHTTPRequest(hRequest);

	return Plugin_Continue;
}

public void OnRequestComplete(Handle hRequest, bool bFailed, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
	delete hRequest;
}
