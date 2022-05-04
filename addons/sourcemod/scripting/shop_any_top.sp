#include <shop>

public Plugin myinfo =
{
	name = "[Shop] Any Top",
	description = "Adds players stats to the shop function menu.",
	author = "iLoco",
	version = "1.0.0",
	url = "Discord: iLoco#7631 | Telegram: @LocoCat | hlmod.ru/members/iloco.94537/"
};

// sm plugins reload shop_any_top;sm plugins load shop_any_top;say !shop

#pragma newdecls required
#pragma semicolon 1

#define MAX_KEY_LENGTH 64

KeyValues g_kvConfig;
Database g_hDb;
char g_sDBPrefix[32];
char g_sOneKeyMode[MAX_KEY_LENGTH];
char g_sOneKeyName[64];
char g_sLastSelected[MAXPLAYERS + 1][MAX_KEY_LENGTH];
int g_iPage[MAXPLAYERS + 1];
int g_iSelection[MAXPLAYERS + 1];
int g_iItemsCount;

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnPluginStart()
{
	char buff[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buff, sizeof(buff), "configs/shop/any_top.cfg");

	(g_kvConfig = new KeyValues("Any Top")).SetEscapeSequences(true);
	if(!g_kvConfig.ImportFromFile(buff)) {
		SetFailState("Config file not found. '%s'", buff);
	}

	if(!g_kvConfig.GotoFirstSubKey()) {
		SetFailState("There are no items in the config, or it is damaged.");
	}

	do {
		g_iItemsCount++;
		g_kvConfig.SetNum("Array", view_as<int>(new ArrayList(64)));
	} while(g_kvConfig.GotoNextKey());

	if(g_iItemsCount == 1) {
		g_kvConfig.GetSectionName(g_sOneKeyMode, sizeof(g_sOneKeyMode));
		g_kvConfig.GetString("Menu Name", g_sOneKeyName, sizeof(g_sOneKeyName), g_sOneKeyMode);
	}
	PrintToChatAll("g_iItemsCount %i", g_iItemsCount);

	LoadTranslations("shop_any_top.phrases");
	LoadTranslations("core.phrases");

	if(Shop_IsStarted()) {
		Shop_Started();
	}
}

public void Shop_Started()
{
	g_hDb = Shop_GetDatabase();
	Shop_GetDatabasePrefix(g_sDBPrefix, sizeof(g_sDBPrefix));
	Shop_AddToFunctionsMenu(CB_Shop_OnFuncDisplay, CB_Shop_OnFuncSelect);
}

public void CB_Shop_OnFuncDisplay(int client, char[] buffer, int maxlength)
{
	SetGlobalTransTarget(client);
	if(g_iItemsCount == 1) {
		CheckTranslateExists(g_sOneKeyName, buffer, maxlength);
	} else {
		FormatEx(buffer, maxlength, "%t", "Menu. Functions Name");
	}
}

public bool CB_Shop_OnFuncSelect(int client)
{
	if(g_iItemsCount == 1) {
		g_sLastSelected[client] = g_sOneKeyMode;
		UpdateQuery(g_sOneKeyMode, client);
	} else {
		Menu_SelectType(client).Display(client, 0);
	}

	return true;
}

public Menu Menu_SelectType(int client)
{
	SetGlobalTransTarget(client);
	Menu menu = new Menu(MenuHandler_SelectType);
	menu.ExitBackButton = true;

	char buff[64], key[MAX_KEY_LENGTH];
	Format(buff, sizeof(buff), "%t", "Menu. Functions Tittle");
	menu.SetTitle(buff);

	g_kvConfig.Rewind();
	g_kvConfig.GotoFirstSubKey();

	do {
		g_kvConfig.GetSectionName(key, sizeof(key));
		g_kvConfig.GetString("Menu Name", buff, sizeof(buff), key);
		CheckTranslateExists(buff, buff, sizeof(buff));
		menu.AddItem(key, buff);
	} while(g_kvConfig.GotoNextKey());

	return menu;
}

public int MenuHandler_SelectType(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select) {
		g_iSelection[client] = menu.Selection;
		menu.GetItem(item, g_sLastSelected[client], sizeof(g_sLastSelected[]));
		UpdateQuery(g_sLastSelected[client], client);
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

	g_kvConfig.GetString("Menu Tittle", buff, sizeof(buff), g_sLastSelected[client]);
	CheckTranslateExists(buff, buff, sizeof(buff));
	panel.SetTitle(buff);

	g_kvConfig.GetString("Header", buff, sizeof(buff));
	panel.DrawText(buff);

	int page_limit = g_kvConfig.GetNum("Limit On Page", 10);
	int limit, item = g_iPage[client]*page_limit;
	while(item < length && limit++ < page_limit) {
		ar.GetString(item++, buff, sizeof(buff));
		panel.DrawText(buff);
	}

	if(g_kvConfig.GetNum("Fill The Void"))	while(limit++ < page_limit) {
		panel.DrawText(" ");
	}

	if(!length) {
		FormatEx(buff, sizeof(buff), "%t", "Menu. Nothing");
		panel.DrawText(buff);
	}

	g_kvConfig.GetString("Footer", buff, sizeof(buff));
	panel.DrawText(buff);

	static const char def_keys[][] = {"Back", "Next", "Exit"};
	static const char kv_keys[][] = {"Back Button", "Next Button", "Exit Button"};
	for(int id; id < 3; id++) if(id != 1 || (id == 1 && item < length)) {
		g_kvConfig.GetString(kv_keys[id], buff, sizeof(buff), def_keys[id]);
		CheckTranslateExists(buff, buff, sizeof(buff));
		panel.CurrentKey = id+7;
		panel.DrawItem(buff);
	} else {
		panel.DrawText(" ");
	}

	panel.Send(client, MenuHandler_TopInv, 0);
	delete panel;
}

public int MenuHandler_TopInv(Menu menu, MenuAction action, int client, int item)
{
	if(action != MenuAction_Select || item == 9) {
		return 0;
	}

	if(item == 7 && g_iPage[client] == 0) {
		if(g_iItemsCount == 1) {
			Shop_ShowFunctionsMenu(client);
		} else {
			Menu_SelectType(client).DisplayAt(client, g_iSelection[client], 0);
		}
	} else {
		g_iPage[client] += (item == 8) ? 1 : -1;
		Menu_TopInv(client);
	}

	return 0;
}

void CheckTranslateExists(const char[] input, char[] buffer, int maxlen)
{
	if(TranslationPhraseExists(input)) {
		Format(buffer, maxlen, "%t", input);
	}
}

void UpdateQuery(char[] key, int client)
{
	g_kvConfig.Rewind();
	g_kvConfig.JumpToKey(key);

	char buff[512], player_id[12];

	if(!key[0]) {
		g_kvConfig.GetSectionName(key, MAX_KEY_LENGTH);
	}

	int now_time = GetTime();
	if(now_time < g_kvConfig.GetNum("Next Update")) {
		g_iPage[client] = 0;
		Menu_TopInv(client);
		return;
	}
	g_kvConfig.SetNum("Next Update", g_kvConfig.GetNum("Update Time") + now_time);

	DataPack pack = new DataPack();
	pack.WriteCell(g_kvConfig.GetNum("Array"));
	pack.WriteCell(client > 0 ? GetClientUserId(client) : 0);
	g_kvConfig.GetString("#format", buff, sizeof(buff));
	pack.WriteString(buff);
	g_kvConfig.GetString("Item Format", buff, sizeof(buff));
	pack.WriteString(buff);

	g_kvConfig.GetString("DataBase Query", buff, sizeof(buff));
	FormatEx(player_id, sizeof(player_id), "%i", Shop_GetClientId(client));
	ReplaceString(buff, sizeof(buff), "{player_id}", player_id);
	ReplaceString(buff, sizeof(buff), "{prefix}", g_sDBPrefix);
	g_hDb.Query(CB_Query_OnGetData, buff, pack);
}

public void CB_Query_OnGetData(Database db, DBResultSet result, const char[] error, DataPack pack)
{
	if(error[0]) {
		LogError("CB_Query_OnGetData: %s", error);
		delete pack;
		return;
	}

	pack.Reset();
	ArrayList ar = pack.ReadCell();
	int client = GetClientOfUserId(pack.ReadCell());
	ar.Clear();

	char temp_format[128], buff[64];
	int id = 1, pos, field_count = result.FieldCount;
	char[][] exp = new char[field_count][12];
	int[] limit = new int[field_count];
	pack.ReadString(temp_format, sizeof(temp_format));
	ExplodeString(temp_format, ",", exp, field_count, 12);
	
	for(int symbol; pos < field_count; pos++) {
		TrimString(exp[pos]);
		if(!exp[pos][0]) {
			strcopy(exp[pos], 12, "%s");
			limit[pos] = sizeof(buff)-1;
			continue;
		}
		symbol = FindCharInString(exp[pos], 's', true)+1;
		limit[pos] = exp[pos][symbol] ? StringToInt(exp[pos][symbol]) : sizeof(buff)-1;
		exp[pos][symbol] = 0;
	}
	
	char format[128], place[8];
	pack.ReadString(format, sizeof(format));
	delete pack;

	while(result.FetchRow()) {
		temp_format = format;

		FormatEx(place, sizeof(place), "%d", id++);
		ReplaceString(temp_format, sizeof(temp_format), "{id}", place);

		for(pos = 0; pos < field_count; pos++) {
			result.FetchString(pos, buff, sizeof(buff));
			buff[limit[pos]] = 0;
			Format(buff, sizeof(buff), exp[pos], buff);
			FormatEx(place, sizeof(place), "{%d}", pos+1);
			ReplaceString(temp_format, sizeof(temp_format), place, buff);
		}

		ar.PushString(temp_format);
	}

	if(client > 0 && client < MaxClients && IsClientInGame(client)) {
		g_iPage[client] = 0;
		Menu_TopInv(client);
	}
}