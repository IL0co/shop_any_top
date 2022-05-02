#include <shop>

public Plugin myinfo =
{
	name = "[Shop] Top Expensive Inventory",
	description = "Adds a menu with a top of the players' expensive inventories.",
	author = "iLoco",
	version = "1.0.0",
	url = "Discord: iLoco#7631 | Telegram: @LocoCat | hlmod.ru/members/iloco.94537/"
};

#define QUERY "SELECT name, SUM(`buy_price`) as `total` FROM `%sboughts` LEFT JOIN `%splayers` WHERE `player_id` = `id` AND `buy_price` > '0' GROUP BY `player_id` ORDER BY `total` DESC LIMIT %i;"

// sm plugins reload shop_top_expensive_inventory;sm plugins load shop_top_expensive_inventory

#pragma newdecls required	
#pragma semicolon 1

char g_sDBPrefix[32];
int g_iPos[MAXPLAYERS + 1];
int g_iPage[MAXPLAYERS + 1];
ArrayList g_arItems;
Database g_hDb;
// KeyValues kv

#define TIME 60
#define LIMIT 100
#define LIMIT_PAGE 10
#define NAME_LIMIT 32

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnPluginStart()
{
	LoadTranslations("shop_top_expensive_inventory.phrases");
	LoadTranslations("core.phrases");
	
	if(Shop_IsStarted()) {
		Shop_Started();
	}
}

public void Shop_Started()
{
	Shop_GetDatabasePrefix(g_sDBPrefix, sizeof(g_sDBPrefix));
	g_hDb = Shop_GetDatabase();

	Shop_AddToFunctionsMenu(CB_Shop_OnFuncDisplay, CB_Shop_OnFuncSelect);
}

public void CB_Shop_OnFuncDisplay(int client, char[] buffer, int maxlength)
{
	FormatEx(buffer, maxlength, "%T", "Menu. Functions Name", client);
}

public bool CB_Shop_OnFuncSelect(int client)
{
	static int next_update;
	int now_time = GetTime();

	if(g_arItems == INVALID_HANDLE) {
		g_arItems = new ArrayList(64);
	}

	if(now_time >= next_update) {
		g_arItems.Clear();
		next_update = TIME + now_time;

		char buffer[256];
		FormatEx(buffer, sizeof(buffer), QUERY, g_sDBPrefix, g_sDBPrefix, LIMIT);
		DBResultSet result = SQL_Query(g_hDb, buffer);

		if(result != INVALID_HANDLE) {
			int id = 1;
			while(result.FetchRow()) {
				result.FetchString(0, buffer, sizeof(buffer));
				buffer[NAME_LIMIT] = 0;
				Format(buffer, sizeof(buffer), "%t", "Menu. Item Format", id++, buffer, result.FetchInt(1));
				// Format(buffer, sizeof(buffer), "#%d. %d - %24s", id++, result.FetchInt(1), buffer);
				// PrintToServer(buffer);
				g_arItems.PushString(buffer);
			}
			delete result;
		}
	}

	g_iPage[client] = 0;
	Menu_TopInv(client);
	return true;
}

void Menu_TopInv(int client)
{	
	char buff[64];
	int length = g_arItems.Length;
	Panel panel = new Panel();
	SetGlobalTransTarget(client);

	FormatEx(buff, sizeof(buff), "%t", "Menu. Tittle");
	panel.SetTitle(buff);

	int limit, item = g_iPage[client]*LIMIT_PAGE;
	while(item < length && limit++ < LIMIT_PAGE) {
		g_arItems.GetString(item++, buff, sizeof(buff));
		panel.DrawText(buff);
	}

	if(!length) {
		FormatEx(buff, sizeof(buff), "%t", "Menu. Nothing");
		panel.DrawText(buff);
	}

	panel.DrawText(" ");

	static const char Items[][] = {"Back", "Next", "Exit"};
	for(int id; id < 3; id++) if(id != 1 || (id == 1 && item < length)) {
		FormatEx(buff, sizeof(buff), "%t", Items[id]);
		panel.CurrentKey = id+7;
		panel.DrawItem(buff);
	}

	panel.Send(client, MenuHandler_TopInv, 0);
	delete panel;
}

public int MenuHandler_TopInv(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select) {
		if(item == 7) {
			if(g_iPage[client] == 0) {
				Shop_ShowFunctionsMenu(client);
			} else {
				g_iPage[client] -= 1;
				Menu_TopInv(client);
			}
		} else if(item == 8) {
			g_iPage[client] += 1;
			Menu_TopInv(client);
		}
	}

	return 0;
}
