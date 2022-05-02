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

#define MAX_KEY_LENGTH 32

char g_sDBPrefix[32];
int g_iPage[MAXPLAYERS + 1];
char g_sLastSelected[MAXPLAYERS + 1][MAX_KEY_LENGTH];
char g_sOneKeyMode[MAX_KEY_LENGTH];
int g_iItemsCount;
Database g_hDb;
KeyValues g_kvConfig;


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
	g_kvConfig = new KeyValues("Any Top");
	char buff[512];
	BuildPath(Path_SM, buff, sizeof(buff), "configs/shop/any_top.cfg");

	if(!g_kvConfig.ImportFromFile(buff)) {
		SetFailState("Файл не найден.");
	}

	if(g_kvConfig.GotoFirstSubKey()) {
		do {
			g_iItemsCount++;
		} while(g_kvConfig.GotoNextKey());
	}

	if(!g_iItemsCount) {
		SetFailState("Нету менюшек.");
	} else if(g_iItemsCount == 1) {
		g_kvConfig.GetSectionName(g_sOneKeyMode, sizeof(g_sOneKeyMode));
	}

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
	g_iPage[client] = 0;
	if(g_iItemsCount == 1) {
		g_sLastSelected[client] = g_sOneKeyMode;
		UpdateQuery(g_sOneKeyMode);
		Menu_TopInv(client);
	} else {
		Menu_SelectType(client).Display(client, 0);
	}

	return true;
}

public Menu Menu_SelectType(int client)
{
	SetGlobalTransTarget(client);
	char buff[64], key[MAX_KEY_LENGTH];

	Menu menu = new Menu(MenuHandler_SelectType);
	menu.ExitBackButton = true;

	Format(buff, sizeof(buff), "Test Tittle");
	menu.SetTitle(buff);

	g_kvConfig.Rewind();
	if(g_kvConfig.GotoFirstSubKey()) {
		do {
			g_kvConfig.GetSectionName(key, sizeof(key));
			g_kvConfig.GetString("Menu Name", buff, sizeof(buff), key);
			if(TranslationPhraseExists(buff)) {
				FormatEx(buff, sizeof(buff), "%t", buff);
			}
			menu.AddItem(key, buff);
		}
		while(g_kvConfig.GotoNextKey());
	}

	return menu;
}

public int MenuHandler_SelectType(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select)
	{
		menu.GetItem(item, g_sLastSelected[client], sizeof(g_sLastSelected[]));
		UpdateQuery(g_sLastSelected[client]);
		Menu_TopInv(client);
	}
	else if(action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
		Shop_ShowFunctionsMenu(client);
	}
	else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void Menu_TopInv(int client)
{	
	g_kvConfig.Rewind();
	g_kvConfig.JumpToKey(g_sLastSelected[client]);

	char buff[64];
	ArrayList ar = view_as<ArrayList>(g_kvConfig.GetNum("Array"));
	int length = ar.Length;
	Panel panel = new Panel();
	SetGlobalTransTarget(client);

	g_kvConfig.GetString("Menu Tittle", buff, sizeof(buff));
	if(TranslationPhraseExists(buff)) {
		FormatEx(buff, sizeof(buff), "%t", buff);
	}
	panel.SetTitle(buff);

	int limit, item = g_iPage[client]*LIMIT_PAGE;
	while(item < length && limit++ < LIMIT_PAGE) {
		ar.GetString(item++, buff, sizeof(buff));
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
				if(g_iItemsCount == 1) {
					Shop_ShowFunctionsMenu(client);
				} else {
					Menu_SelectType(client).Display(client, 0);
				}
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

void UpdateQuery(char[] key)
{
	g_kvConfig.Rewind();
	g_kvConfig.JumpToKey(key);

	int now_time = GetTime();
	int next_update = g_kvConfig.GetNum("Next Update");
	if(now_time < next_update) {
		return;
	}
	g_kvConfig.SetNum("Next Update", g_kvConfig.GetNum("Update Time") + now_time);

	char buff[512], format[64], temp_format[64], place[4];
	ArrayList ar = view_as<ArrayList>(g_kvConfig.GetNum("Array"));
	if(ar == INVALID_HANDLE) {
		g_kvConfig.SetNum("Array", view_as<int>((ar = new ArrayList(64))));
	} else {
		ar.Clear();
	}
	
	g_kvConfig.GetString("Item Format", format, sizeof(format));
	g_kvConfig.GetString("DataBase Query", buff, sizeof(buff));
	ReplaceString(buff, sizeof(buff), "{prefix}", g_sDBPrefix);
	DBResultSet result = SQL_Query(g_hDb, buff);

	if(result == INVALID_HANDLE) {
		return;
	}

	int id = 1, field_count, pos;
	while(result.FetchRow()) {
		temp_format = format;

		FormatEx(place, sizeof(place), "%d", id++);
		ReplaceString(temp_format, sizeof(temp_format), "{id}", place);

		field_count = result.FieldCount;
		for(pos = 0; pos < field_count; pos++) {
			result.FetchString(pos, buff, sizeof(buff));
			FormatEx(place, sizeof(place), "{%d}", pos+1);
			ReplaceString(temp_format, sizeof(temp_format), place, buff);
		}

		// buffer[NAME_LIMIT] = 0;
		// Format(buffer, sizeof(buffer), "%t", "Menu. Item Format", id++, buffer, result.FetchInt(1));
		ar.PushString(temp_format);
	}

	delete result;
}