// =====================================================================
//   UA RolePlay — український RP-мод для open.mp
//   Акаунти, банк, PayDay, роботи, автосалон, RP-чат, адмінка.
//   База даних: вбудований SQLite (файл scriptfiles/uarp.db).
//
//   Цей файл зберігається в UTF-8. GitHub перед компіляцією
//   перетворює його у Windows-1251, щоб українські літери працювали в грі.
// =====================================================================

#include <open.mp>

#define SERVER_NAME        "UA RolePlay"
#define SERVER_VERSION     "UA-RP 1.0"

// ---------------------------------------------------------------- кольори
#define C_WHITE      0xFFFFFFFF
#define C_GREY       0xAFAFAFFF
#define C_YELLOW     0xFFC93CFF
#define C_BLUE       0x4FA3FFFF
#define C_GREEN      0x3DDC84FF
#define C_RED        0xFF5A5AFF
#define C_PURPLE     0xC2A2DAFF
#define C_ORANGE     0xFFA63CFF

// ---------------------------------------------------------------- економіка
#define START_MONEY      5000
#define PAYDAY_BASE      500
#define PAYDAY_PER_LVL   100
#define PAYDAY_MINUTES   60
#define LOADER_PAY       150
#define BANK_INTEREST    1      // % на депозит за PayDay (від суми до 100 000)

// ---------------------------------------------------------------- точки
#define SPAWN_X   1759.04
#define SPAWN_Y   -1898.13
#define SPAWN_Z   13.56
#define SPAWN_A   270.0

#define BANK_X    1481.03
#define BANK_Y    -1771.0
#define BANK_Z    18.79

#define JOBC_X    1466.4
#define JOBC_Y    -1744.0
#define JOBC_Z    13.55

#define DEAL_X    2131.8
#define DEAL_Y    -1150.8
#define DEAL_Z    24.1

#define LOAD_TAKE_X   2775.6
#define LOAD_TAKE_Y   -2420.0
#define LOAD_TAKE_Z   13.64
#define LOAD_DROP_X   2744.0
#define LOAD_DROP_Y   -2440.0
#define LOAD_DROP_Z   13.64

#define TRUCK_X   2193.0
#define TRUCK_Y   -2253.0
#define TRUCK_Z   13.54

// ---------------------------------------------------------------- діалоги
#define DLG_LOGIN       1
#define DLG_REG         2
#define DLG_REG_SEX     3
#define DLG_MENU        10
#define DLG_HELP        11
#define DLG_STATS       12
#define DLG_GPS         13
#define DLG_BANK        20
#define DLG_BANK_DEP    21
#define DLG_BANK_WD     22
#define DLG_BANK_INFO   23
#define DLG_DEALER      30
#define DLG_JOBS        40
#define DLG_INFO        99

// ---------------------------------------------------------------- роботи
#define JOB_NONE     0
#define JOB_LOADER   1
#define JOB_TRUCKER  2

// ---------------------------------------------------------------- чекпоінти
#define CP_NONE      0
#define CP_GPS       1
#define CP_LOADER    2
#define CP_TRUCK     3

enum E_PLAYER
{
	pID,
	bool:pLogged,
	pPass[65],
	pSalt[17],
	pMoney,
	pBank,
	pLevel,
	pExp,
	pSkin,
	pAdmin,
	pMinutes,
	pJob,
	pCar,
	pCarVeh,
	pLoginTries,
	pCP,
	bool:pCarrying,
	pTruck,
	pPickupTick,
	pMuteUntil
}
new P[MAX_PLAYERS][E_PLAYER];

new DB:gDB;
new Text:gLogoTD;
new gPickBank, gPickJobs, gPickDealer, gPickLoadTake, gPickTruck;

// Автосалон
enum E_CARDEAL { dModel, dName[24], dPrice }
new const gDealer[][E_CARDEAL] =
{
	{462, "Faggio (мопед)",   5000},
	{404, "Perennial",        15000},
	{410, "Manana",           18000},
	{445, "Admiral",          35000},
	{507, "Elegant",          45000},
	{560, "Sultan",           120000},
	{541, "Bullet",           250000}
};

// Точки доставки далекобійника
new const Float:gTruckDest[][3] =
{
	{1940.0, -1772.0, 13.39},
	{1355.0, -1750.0, 13.38},
	{2446.0, -1760.0, 13.59},
	{1000.0, -1300.0, 13.38},
	{2114.0, -1772.0, 13.39}
};

// GPS
enum E_GPS { gName[48], Float:gX, Float:gY, Float:gZ }
new const gGps[][E_GPS] =
{
	{"Вокзал (місце появи)",        SPAWN_X, SPAWN_Y, SPAWN_Z},
	{"Банк (мерія)",                BANK_X,  BANK_Y,  BANK_Z},
	{"Біржа праці",                 JOBC_X,  JOBC_Y,  JOBC_Z},
	{"Автосалон",                   DEAL_X,  DEAL_Y,  DEAL_Z},
	{"Склад (робота вантажника)",   LOAD_TAKE_X, LOAD_TAKE_Y, LOAD_TAKE_Z},
	{"База далекобійників",         TRUCK_X, TRUCK_Y, TRUCK_Z}
};

main()
{
	print("\n==========================================");
	print("  " SERVER_NAME " (" SERVER_VERSION ") завантажено");
	print("==========================================\n");
}

// =====================================================================
//   ДОПОМІЖНІ ФУНКЦІЇ
// =====================================================================

stock strtok(const string[], &index)
{
	new length = strlen(string);
	while ((index < length) && (string[index] <= ' ')) index++;
	new offset = index;
	new result[64];
	while ((index < length) && (string[index] > ' ') && ((index - offset) < (sizeof(result) - 1)))
	{
		result[index - offset] = string[index];
		index++;
	}
	result[index - offset] = EOS;
	return result;
}

stock strrest(const string[], &index)
{
	new length = strlen(string);
	while ((index < length) && (string[index] <= ' ')) index++;
	new result[144];
	new i = 0;
	while ((index < length) && (i < (sizeof(result) - 1)))
	{
		result[i++] = string[index++];
	}
	result[i] = EOS;
	return result;
}

stock IsNumeric(const s[])
{
	new len = strlen(s);
	if (len == 0 || len > 9) return 0;
	for (new i = 0; i < len; i++)
	{
		if (s[i] < '0' || s[i] > '9') return 0;
	}
	return 1;
}

stock PlayerName(playerid)
{
	new name[MAX_PLAYER_NAME + 1];
	GetPlayerName(playerid, name, sizeof(name));
	return name;
}

// Ім'я для RP-чату: Ivan_Petrenko -> Ivan Petrenko
stock RPName(playerid)
{
	new name[MAX_PLAYER_NAME + 1];
	GetPlayerName(playerid, name, sizeof(name));
	for (new i = 0; name[i] != EOS; i++)
	{
		if (name[i] == '_') name[i] = ' ';
	}
	return name;
}

// RP-формат ніка: Ім'я_Прізвище латиницею
stock IsRPName(const name[])
{
	new len = strlen(name), under = -1;
	if (len < 5 || len > 20) return 0;
	for (new i = 0; i < len; i++)
	{
		new c = name[i];
		if (c == '_')
		{
			if (under != -1) return 0;
			under = i;
			continue;
		}
		if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))) return 0;
	}
	if (under < 2 || under > len - 3) return 0;
	if (!(name[0] >= 'A' && name[0] <= 'Z')) return 0;
	if (!(name[under + 1] >= 'A' && name[under + 1] <= 'Z')) return 0;
	return 1;
}

stock RandomSalt(dest[], size)
{
	static const chars[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	for (new i = 0; i < size - 1; i++)
	{
		dest[i] = chars[random(sizeof(chars) - 1)];
	}
	dest[size - 1] = EOS;
}

stock SetMoney(playerid, amount)
{
	P[playerid][pMoney] = amount;
	ResetPlayerMoney(playerid);
	GivePlayerMoney(playerid, amount);
}

stock GiveMoney(playerid, amount)
{
	SetMoney(playerid, P[playerid][pMoney] + amount);
}

stock LocalMessage(playerid, Float:radius, colour, const text[])
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid, x, y, z);
	new vw = GetPlayerVirtualWorld(playerid);
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (!IsPlayerConnected(i) || !P[i][pLogged]) continue;
		if (GetPlayerVirtualWorld(i) != vw) continue;
		if (IsPlayerInRangeOfPoint(i, radius, x, y, z))
		{
			SendClientMessage(i, colour, "%s", text);
		}
	}
}

stock AdminMessage(colour, const text[])
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (IsPlayerConnected(i) && P[i][pAdmin] > 0)
		{
			SendClientMessage(i, colour, "%s", text);
		}
	}
}

stock SetCP(playerid, type, Float:x, Float:y, Float:z, Float:size)
{
	DisablePlayerCheckpoint(playerid);
	P[playerid][pCP] = type;
	SetPlayerCheckpoint(playerid, x, y, z, size);
}

stock ClearCP(playerid)
{
	DisablePlayerCheckpoint(playerid);
	P[playerid][pCP] = CP_NONE;
}

stock ResetPlayerData(playerid)
{
	P[playerid][pID] = 0;
	P[playerid][pLogged] = false;
	P[playerid][pPass][0] = EOS;
	P[playerid][pSalt][0] = EOS;
	P[playerid][pMoney] = 0;
	P[playerid][pBank] = 0;
	P[playerid][pLevel] = 1;
	P[playerid][pExp] = 0;
	P[playerid][pSkin] = 26;
	P[playerid][pAdmin] = 0;
	P[playerid][pMinutes] = 0;
	P[playerid][pJob] = JOB_NONE;
	P[playerid][pCar] = 0;
	P[playerid][pCarVeh] = INVALID_VEHICLE_ID;
	P[playerid][pLoginTries] = 0;
	P[playerid][pCP] = CP_NONE;
	P[playerid][pCarrying] = false;
	P[playerid][pTruck] = INVALID_VEHICLE_ID;
	P[playerid][pPickupTick] = 0;
	P[playerid][pMuteUntil] = 0;
}

stock JobName(job)
{
	new s[32];
	switch (job)
	{
		case JOB_LOADER:  s = "Вантажник";
		case JOB_TRUCKER: s = "Далекобійник";
		default:          s = "Безробітний";
	}
	return s;
}

// =====================================================================
//   БАЗА ДАНИХ
// =====================================================================

stock DB_Init()
{
	gDB = DB_Open("uarp.db");
	if (gDB == DB:0)
	{
		print("[UA-RP] ПОМИЛКА: не вдалося відкрити scriptfiles/uarp.db");
		return 0;
	}
	DB_FreeResultSet(DB_ExecuteQuery(gDB,
		"CREATE TABLE IF NOT EXISTS accounts (\
		id INTEGER PRIMARY KEY AUTOINCREMENT,\
		name TEXT UNIQUE COLLATE NOCASE,\
		pass TEXT, salt TEXT,\
		money INTEGER DEFAULT 0, bank INTEGER DEFAULT 0,\
		level INTEGER DEFAULT 1, exp INTEGER DEFAULT 0,\
		skin INTEGER DEFAULT 26, admin INTEGER DEFAULT 0,\
		minutes INTEGER DEFAULT 0, job INTEGER DEFAULT 0,\
		car INTEGER DEFAULT 0, regdate TEXT)"));
	print("[UA-RP] База даних uarp.db підключена");
	return 1;
}

stock Acc_Save(playerid)
{
	if (!P[playerid][pLogged]) return 0;
	DB_FreeResultSet(DB_ExecuteQuery(gDB,
		"UPDATE accounts SET money=%d, bank=%d, level=%d, exp=%d, skin=%d, admin=%d, minutes=%d, job=%d, car=%d WHERE id=%d",
		P[playerid][pMoney], P[playerid][pBank], P[playerid][pLevel], P[playerid][pExp],
		P[playerid][pSkin], P[playerid][pAdmin], P[playerid][pMinutes], P[playerid][pJob],
		P[playerid][pCar], P[playerid][pID]));
	return 1;
}

// Чи є акаунт; якщо так — завантажує пароль і сіль
stock Acc_Exists(playerid)
{
	new DBResult:r = DB_ExecuteQuery(gDB, "SELECT id, pass, salt FROM accounts WHERE name='%s' LIMIT 1", PlayerName(playerid));
	new found = 0;
	if (r)
	{
		if (DB_GetRowCount(r) > 0)
		{
			found = 1;
			P[playerid][pID] = DB_GetFieldIntByName(r, "id");
			DB_GetFieldStringByName(r, "pass", P[playerid][pPass], 65);
			DB_GetFieldStringByName(r, "salt", P[playerid][pSalt], 17);
		}
		DB_FreeResultSet(r);
	}
	return found;
}

stock Acc_Load(playerid)
{
	new DBResult:r = DB_ExecuteQuery(gDB, "SELECT * FROM accounts WHERE id=%d", P[playerid][pID]);
	if (!r) return 0;
	if (DB_GetRowCount(r) > 0)
	{
		P[playerid][pMoney]   = DB_GetFieldIntByName(r, "money");
		P[playerid][pBank]    = DB_GetFieldIntByName(r, "bank");
		P[playerid][pLevel]   = DB_GetFieldIntByName(r, "level");
		P[playerid][pExp]     = DB_GetFieldIntByName(r, "exp");
		P[playerid][pSkin]    = DB_GetFieldIntByName(r, "skin");
		P[playerid][pAdmin]   = DB_GetFieldIntByName(r, "admin");
		P[playerid][pMinutes] = DB_GetFieldIntByName(r, "minutes");
		P[playerid][pJob]     = DB_GetFieldIntByName(r, "job");
		P[playerid][pCar]     = DB_GetFieldIntByName(r, "car");
	}
	DB_FreeResultSet(r);
	return 1;
}

// =====================================================================
//   ВХІД І РЕЄСТРАЦІЯ
// =====================================================================

stock ShowLogin(playerid, const extra[] = "")
{
	new body[256];
	format(body, sizeof(body),
		"{FFFFFF}Вітаємо на {FFC93C}" SERVER_NAME "{FFFFFF}!\n\nАкаунт {FFC93C}%s{FFFFFF} зареєстровано.\nВведіть пароль:%s",
		PlayerName(playerid), extra);
	ShowPlayerDialog(playerid, DLG_LOGIN, DIALOG_STYLE_PASSWORD, "Вхід", body, "Увійти", "Вийти");
}

stock ShowRegister(playerid, const extra[] = "")
{
	new body[320];
	format(body, sizeof(body),
		"{FFFFFF}Вітаємо на {FFC93C}" SERVER_NAME "{FFFFFF}!\n\nНік {FFC93C}%s{FFFFFF} вільний.\nПридумайте пароль (від 6 до 32 символів):%s",
		PlayerName(playerid), extra);
	ShowPlayerDialog(playerid, DLG_REG, DIALOG_STYLE_PASSWORD, "Реєстрація", body, "Далі", "Вийти");
}

stock FinishLogin(playerid)
{
	P[playerid][pLogged] = true;
	SetSpawnInfo(playerid, NO_TEAM, P[playerid][pSkin], SPAWN_X, SPAWN_Y, SPAWN_Z, SPAWN_A);
	TogglePlayerSpectating(playerid, false);
	SetMoney(playerid, P[playerid][pMoney]);
	SetPlayerScore(playerid, P[playerid][pLevel]);
	SendClientMessage(playerid, C_GREEN, "Ви увійшли в гру. Головне меню: /menu, допомога: /help");
	if (P[playerid][pAdmin] > 0)
	{
		SendClientMessage(playerid, C_YELLOW, "Ви адміністратор %d рівня. Команди: /ahelp", P[playerid][pAdmin]);
	}
}

// =====================================================================
//   ПОДІЇ СЕРВЕРА
// =====================================================================

public OnGameModeInit()
{
	SetGameModeText(SERVER_VERSION);
	DisableInteriorEnterExits();
	EnableStuntBonusForAll(false);
	ManualVehicleEngineAndLights();
	ShowPlayerMarkers(PLAYER_MARKERS_MODE_STREAMED);
	SetNameTagDrawDistance(25.0);
	UsePlayerPedAnims();
	AddPlayerClass(26, SPAWN_X, SPAWN_Y, SPAWN_Z, SPAWN_A);

	DB_Init();

	// Пікапи та підписи
	gPickBank     = CreatePickup(1274, 1, BANK_X, BANK_Y, BANK_Z);
	gPickJobs     = CreatePickup(1210, 1, JOBC_X, JOBC_Y, JOBC_Z);
	gPickDealer   = CreatePickup(1239, 1, DEAL_X, DEAL_Y, DEAL_Z);
	gPickLoadTake = CreatePickup(1271, 1, LOAD_TAKE_X, LOAD_TAKE_Y, LOAD_TAKE_Z);
	gPickTruck    = CreatePickup(1239, 1, TRUCK_X, TRUCK_Y, TRUCK_Z);

	Create3DTextLabel("{FFC93C}Банк\n{FFFFFF}Станьте на значок", C_WHITE, BANK_X, BANK_Y, BANK_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FFC93C}Біржа праці\n{FFFFFF}Станьте на значок", C_WHITE, JOBC_X, JOBC_Y, JOBC_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FFC93C}Автосалон\n{FFFFFF}Станьте на значок", C_WHITE, DEAL_X, DEAL_Y, DEAL_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FFC93C}Склад\n{FFFFFF}Візьміть ящик", C_WHITE, LOAD_TAKE_X, LOAD_TAKE_Y, LOAD_TAKE_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FFC93C}База далекобійників\n{FFFFFF}/work — почати рейс", C_WHITE, TRUCK_X, TRUCK_Y, TRUCK_Z + 0.6, 20.0, 0);

	// Транспорт біля вокзалу для новачків
	AddStaticVehicleEx(462, 1777.0, -1890.0, 13.2, 270.0, -1, -1, 600);
	AddStaticVehicleEx(462, 1777.0, -1893.0, 13.2, 270.0, -1, -1, 600);
	AddStaticVehicleEx(462, 1777.0, -1896.0, 13.2, 270.0, -1, -1, 600);
	AddStaticVehicleEx(509, 1777.0, -1899.0, 13.2, 270.0, -1, -1, 600);
	AddStaticVehicleEx(509, 1777.0, -1902.0, 13.2, 270.0, -1, -1, 600);

	gLogoTD = TextDrawCreate(608.0, 5.0, "UA ~y~ROLEPLAY");
	TextDrawAlignment(gLogoTD, TEXT_DRAW_ALIGN_RIGHT);
	TextDrawFont(gLogoTD, TEXT_DRAW_FONT_3);
	TextDrawLetterSize(gLogoTD, 0.35, 1.3);
	TextDrawColour(gLogoTD, 0xFFFFFFFF);
	TextDrawSetOutline(gLogoTD, 1);

	SetTimer("MinuteTimer", 60000, true);

	new h, m, s;
	gettime(h, m, s);
	SetWorldTime(h);
	return 1;
}

public OnGameModeExit()
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (IsPlayerConnected(i)) Acc_Save(i);
	}
	DB_Close(gDB);
	return 1;
}

public OnPlayerConnect(playerid)
{
	ResetPlayerData(playerid);
	SetPlayerColor(playerid, 0xFFFFFF00);
	TextDrawShowForPlayer(playerid, gLogoTD);
	for (new i = 0; i < 20; i++) SendClientMessage(playerid, C_WHITE, " ");

	if (!IsRPName(PlayerName(playerid)))
	{
		SendClientMessage(playerid, C_RED, "Нік має бути у форматі Ім'я_Прізвище латиницею, наприклад Ivan_Petrenko.");
		SendClientMessage(playerid, C_RED, "Змініть нік у лаунчері та зайдіть знову.");
		SetTimerEx("DelayedKick", 500, false, "i", playerid);
		return 1;
	}

	TogglePlayerSpectating(playerid, true);
	SetTimerEx("ShowAuth", 400, false, "i", playerid);
	return 1;
}

forward ShowAuth(playerid);
public ShowAuth(playerid)
{
	if (!IsPlayerConnected(playerid)) return 0;
	SetPlayerCameraPos(playerid, 1800.0, -1950.0, 60.0);
	SetPlayerCameraLookAt(playerid, 1759.0, -1898.0, 13.5);
	if (Acc_Exists(playerid)) ShowLogin(playerid);
	else ShowRegister(playerid);
	return 1;
}

forward DelayedKick(playerid);
public DelayedKick(playerid)
{
	Kick(playerid);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	Acc_Save(playerid);
	if (P[playerid][pCarVeh] != INVALID_VEHICLE_ID) DestroyVehicle(P[playerid][pCarVeh]);
	if (P[playerid][pTruck] != INVALID_VEHICLE_ID) DestroyVehicle(P[playerid][pTruck]);
	ResetPlayerData(playerid);
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	if (P[playerid][pLogged])
	{
		SetSpawnInfo(playerid, NO_TEAM, P[playerid][pSkin], SPAWN_X, SPAWN_Y, SPAWN_Z, SPAWN_A);
		SpawnPlayer(playerid);
	}
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	return P[playerid][pLogged] ? 1 : 0;
}

public OnPlayerSpawn(playerid)
{
	if (!P[playerid][pLogged])
	{
		Kick(playerid);
		return 1;
	}
	SetPlayerSkin(playerid, P[playerid][pSkin]);
	SetPlayerInterior(playerid, 0);
	SetPlayerVirtualWorld(playerid, 0);
	SetMoney(playerid, P[playerid][pMoney]);
	return 1;
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
	if (P[playerid][pCarrying])
	{
		P[playerid][pCarrying] = false;
		RemovePlayerAttachedObject(playerid, 9);
	}
	ClearCP(playerid);
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch (dialogid)
	{
		case DLG_LOGIN:
		{
			if (!response) return Kick(playerid);
			new hash[65];
			SHA256_PassHash(inputtext, P[playerid][pSalt], hash, sizeof(hash));
			if (strcmp(hash, P[playerid][pPass], false) != 0 || strlen(inputtext) == 0)
			{
				P[playerid][pLoginTries]++;
				if (P[playerid][pLoginTries] >= 3)
				{
					SendClientMessage(playerid, C_RED, "Неправильний пароль 3 рази. Вас від'єднано.");
					SetTimerEx("DelayedKick", 500, false, "i", playerid);
					return 1;
				}
				new extra[64];
				format(extra, sizeof(extra), "\n\n{FF5A5A}Неправильний пароль. Спроб залишилось: %d", 3 - P[playerid][pLoginTries]);
				ShowLogin(playerid, extra);
				return 1;
			}
			Acc_Load(playerid);
			FinishLogin(playerid);
			return 1;
		}
		case DLG_REG:
		{
			if (!response) return Kick(playerid);
			new len = strlen(inputtext);
			if (len < 6 || len > 32)
			{
				ShowRegister(playerid, "\n\n{FF5A5A}Пароль має бути від 6 до 32 символів.");
				return 1;
			}
			RandomSalt(P[playerid][pSalt], 17);
			SHA256_PassHash(inputtext, P[playerid][pSalt], P[playerid][pPass], 65);
			ShowPlayerDialog(playerid, DLG_REG_SEX, DIALOG_STYLE_LIST, "Стать персонажа", "Чоловік\nЖінка", "Обрати", "");
			return 1;
		}
		case DLG_REG_SEX:
		{
			P[playerid][pSkin] = (response && listitem == 1) ? 56 : 26;
			new date[24], y, mo, d;
			getdate(y, mo, d);
			format(date, sizeof(date), "%02d.%02d.%d", d, mo, y);
			DB_FreeResultSet(DB_ExecuteQuery(gDB,
				"INSERT INTO accounts (name, pass, salt, money, skin, regdate) VALUES ('%s', '%s', '%s', %d, %d, '%s')",
				PlayerName(playerid), P[playerid][pPass], P[playerid][pSalt], START_MONEY, P[playerid][pSkin], date));
			if (!Acc_Exists(playerid))
			{
				SendClientMessage(playerid, C_RED, "Помилка реєстрації. Спробуйте ще раз.");
				SetTimerEx("DelayedKick", 500, false, "i", playerid);
				return 1;
			}
			P[playerid][pMoney] = START_MONEY;
			P[playerid][pLevel] = 1;
			FinishLogin(playerid);
			SendClientMessage(playerid, C_YELLOW, "Реєстрацію завершено! Ви отримали $%d на старт.", START_MONEY);
			SendClientMessage(playerid, C_YELLOW, "Почніть з біржі праці: /gps -> Біржа праці.");
			return 1;
		}
		case DLG_MENU:
		{
			if (!response) return 1;
			switch (listitem)
			{
				case 0: ShowStats(playerid);
				case 1: ShowGps(playerid);
				case 2: ShowHelp(playerid);
				case 3: CmdCar(playerid);
				case 4: SendClientMessage(playerid, C_GREY, "Щоб написати адміну, введіть /report [текст]");
			}
			return 1;
		}
		case DLG_GPS:
		{
			if (!response) return 1;
			if (listitem < 0 || listitem >= sizeof(gGps)) return 1;
			SetCP(playerid, CP_GPS, gGps[listitem][gX], gGps[listitem][gY], gGps[listitem][gZ], 4.0);
			SendClientMessage(playerid, C_BLUE, "Мітку поставлено на карті: %s", gGps[listitem][gName]);
			return 1;
		}
		case DLG_BANK:
		{
			if (!response) return 1;
			switch (listitem)
			{
				case 0:
				{
					new body[160];
					format(body, sizeof(body), "{FFFFFF}На рахунку: {3DDC84}$%d\n{FFFFFF}Готівка: {3DDC84}$%d\n\n{AFAFAF}Відсоток на депозит: %d%% щогодини (PayDay)",
						P[playerid][pBank], P[playerid][pMoney], BANK_INTEREST);
					ShowPlayerDialog(playerid, DLG_BANK_INFO, DIALOG_STYLE_MSGBOX, "Банк — рахунок", body, "Назад", "");
				}
				case 1: ShowPlayerDialog(playerid, DLG_BANK_DEP, DIALOG_STYLE_INPUT, "Банк — покласти", "{FFFFFF}Скільки грошей покласти на рахунок?", "Покласти", "Назад");
				case 2: ShowPlayerDialog(playerid, DLG_BANK_WD, DIALOG_STYLE_INPUT, "Банк — зняти", "{FFFFFF}Скільки грошей зняти з рахунку?", "Зняти", "Назад");
			}
			return 1;
		}
		case DLG_BANK_INFO:
		{
			ShowBank(playerid);
			return 1;
		}
		case DLG_BANK_DEP, DLG_BANK_WD:
		{
			if (!response) return ShowBank(playerid);
			if (!IsNumeric(inputtext))
			{
				SendClientMessage(playerid, C_RED, "Введіть суму цифрами.");
				return ShowBank(playerid);
			}
			new sum = strval(inputtext);
			if (sum <= 0) return ShowBank(playerid);
			if (dialogid == DLG_BANK_DEP)
			{
				if (sum > P[playerid][pMoney]) { SendClientMessage(playerid, C_RED, "У вас немає стільки готівки."); return ShowBank(playerid); }
				GiveMoney(playerid, -sum);
				P[playerid][pBank] += sum;
				SendClientMessage(playerid, C_GREEN, "Ви поклали $%d. На рахунку: $%d", sum, P[playerid][pBank]);
			}
			else
			{
				if (sum > P[playerid][pBank]) { SendClientMessage(playerid, C_RED, "На рахунку недостатньо грошей."); return ShowBank(playerid); }
				P[playerid][pBank] -= sum;
				GiveMoney(playerid, sum);
				SendClientMessage(playerid, C_GREEN, "Ви зняли $%d. На рахунку: $%d", sum, P[playerid][pBank]);
			}
			Acc_Save(playerid);
			return 1;
		}
		case DLG_DEALER:
		{
			if (!response) return 1;
			if (listitem < 0 || listitem >= sizeof(gDealer)) return 1;
			new price = gDealer[listitem][dPrice];
			if (P[playerid][pMoney] < price)
			{
				SendClientMessage(playerid, C_RED, "Недостатньо готівки. Потрібно $%d.", price);
				return 1;
			}
			GiveMoney(playerid, -price);
			if (P[playerid][pCarVeh] != INVALID_VEHICLE_ID)
			{
				DestroyVehicle(P[playerid][pCarVeh]);
				P[playerid][pCarVeh] = INVALID_VEHICLE_ID;
			}
			P[playerid][pCar] = gDealer[listitem][dModel];
			Acc_Save(playerid);
			SendClientMessage(playerid, C_GREEN, "Вітаємо з покупкою: %s! Викликати авто: /car, замок: /lock, двигун: /e", gDealer[listitem][dName]);
			CmdCar(playerid);
			return 1;
		}
		case DLG_JOBS:
		{
			if (!response) return 1;
			switch (listitem)
			{
				case 0:
				{
					P[playerid][pJob] = JOB_LOADER;
					SendClientMessage(playerid, C_GREEN, "Ви влаштувались вантажником. Їдьте на склад у порту (мітка на карті).");
					SetCP(playerid, CP_GPS, LOAD_TAKE_X, LOAD_TAKE_Y, LOAD_TAKE_Z, 3.0);
				}
				case 1:
				{
					if (P[playerid][pLevel] < 2)
					{
						SendClientMessage(playerid, C_RED, "Далекобійником можна стати з 2 рівня.");
						return 1;
					}
					P[playerid][pJob] = JOB_TRUCKER;
					SendClientMessage(playerid, C_GREEN, "Ви влаштувались далекобійником. Їдьте на базу (мітка) і введіть /work.");
					SetCP(playerid, CP_GPS, TRUCK_X, TRUCK_Y, TRUCK_Z, 3.0);
				}
				case 2:
				{
					P[playerid][pJob] = JOB_NONE;
					SendClientMessage(playerid, C_GREY, "Ви звільнились з роботи.");
				}
			}
			Acc_Save(playerid);
			return 1;
		}
	}
	return 0;
}

// =====================================================================
//   ДІАЛОГИ-МЕНЮ
// =====================================================================

stock ShowMenu(playerid)
{
	ShowPlayerDialog(playerid, DLG_MENU, DIALOG_STYLE_LIST, "Головне меню",
		"Моя статистика\nGPS — навігатор\nДопомога і команди\nВикликати своє авто\nЗв'язок з адміном",
		"Обрати", "Закрити");
	return 1;
}

stock ShowStats(playerid)
{
	new body[512], car[32];
	if (P[playerid][pCar] == 0) car = "немає";
	else
	{
		car = "є";
		for (new i = 0; i < sizeof(gDealer); i++)
		{
			if (gDealer[i][dModel] == P[playerid][pCar]) { format(car, sizeof(car), "%s", gDealer[i][dName]); break; }
		}
	}
	format(body, sizeof(body),
		"{FFFFFF}Ім'я: {FFC93C}%s\n{FFFFFF}Рівень: {FFC93C}%d {AFAFAF}(досвід %d/%d)\n{FFFFFF}Готівка: {3DDC84}$%d\n{FFFFFF}Банк: {3DDC84}$%d\n{FFFFFF}Робота: {FFC93C}%s\n{FFFFFF}Авто: {FFC93C}%s\n{FFFFFF}До PayDay: {FFC93C}%d хв",
		RPName(playerid), P[playerid][pLevel], P[playerid][pExp], P[playerid][pLevel] * 4,
		P[playerid][pMoney], P[playerid][pBank], JobName(P[playerid][pJob]), car,
		PAYDAY_MINUTES - (P[playerid][pMinutes] % PAYDAY_MINUTES));
	ShowPlayerDialog(playerid, DLG_STATS, DIALOG_STYLE_MSGBOX, "Статистика", body, "Закрити", "");
	return 1;
}

stock ShowGps(playerid)
{
	new body[512];
	for (new i = 0; i < sizeof(gGps); i++)
	{
		strcat(body, gGps[i][gName]);
		strcat(body, "\n");
	}
	ShowPlayerDialog(playerid, DLG_GPS, DIALOG_STYLE_LIST, "GPS — куди їхати?", body, "Поставити мітку", "Закрити");
	return 1;
}

stock ShowHelp(playerid)
{
	ShowPlayerDialog(playerid, DLG_HELP, DIALOG_STYLE_MSGBOX, "Допомога",
		"{FFC93C}Основне:{FFFFFF} /menu /stats /gps /help\n\
{FFC93C}Гроші:{FFFFFF} банк — значок біля мерії, /pay [id] [сума]\n\
{FFC93C}Робота:{FFFFFF} біржа праці біля мерії, /work, /quitjob\n\
{FFC93C}Авто:{FFFFFF} автосалон, /car, /lock, /e (двигун)\n\
{FFC93C}RP-чат:{FFFFFF} /me /do /try /b (OOC) /s (крик) /pm [id] [текст]\n\
{FFC93C}Інше:{FFFFFF} /report [текст] — написати адміну\n\n\
{AFAFAF}PayDay кожні 60 хвилин гри: зарплата на банк і досвід.",
		"Закрити", "");
	return 1;
}

stock ShowBank(playerid)
{
	ShowPlayerDialog(playerid, DLG_BANK, DIALOG_STYLE_LIST, "Банк UA RolePlay",
		"Мій рахунок\nПокласти гроші\nЗняти гроші", "Обрати", "Закрити");
	return 1;
}

stock ShowDealer(playerid)
{
	new body[512], line[64];
	strcat(body, "Модель\tЦіна\n");
	for (new i = 0; i < sizeof(gDealer); i++)
	{
		format(line, sizeof(line), "%s\t{3DDC84}$%d\n", gDealer[i][dName], gDealer[i][dPrice]);
		strcat(body, line);
	}
	ShowPlayerDialog(playerid, DLG_DEALER, DIALOG_STYLE_TABLIST_HEADERS, "Автосалон", body, "Купити", "Закрити");
	return 1;
}

stock ShowJobs(playerid)
{
	ShowPlayerDialog(playerid, DLG_JOBS, DIALOG_STYLE_LIST, "Біржа праці",
		"Вантажник (з 1 рівня)\nДалекобійник (з 2 рівня)\nЗвільнитися з роботи", "Обрати", "Закрити");
	return 1;
}

stock CmdCar(playerid)
{
	if (P[playerid][pCar] == 0)
	{
		SendClientMessage(playerid, C_RED, "У вас немає авто. Купіть його в автосалоні (/gps).");
		return 1;
	}
	if (IsPlayerInAnyVehicle(playerid))
	{
		SendClientMessage(playerid, C_RED, "Спершу вийдіть з транспорту.");
		return 1;
	}
	if (P[playerid][pCarVeh] != INVALID_VEHICLE_ID) DestroyVehicle(P[playerid][pCarVeh]);
	new Float:x, Float:y, Float:z, Float:a;
	GetPlayerPos(playerid, x, y, z);
	GetPlayerFacingAngle(playerid, a);
	x += 3.0 * floatsin(-a + 90.0, degrees);
	y += 3.0 * floatcos(-a + 90.0, degrees);
	new veh = CreateVehicle(P[playerid][pCar], x, y, z + 0.5, a, -1, -1, -1);
	P[playerid][pCarVeh] = veh;
	new plate[16];
	format(plate, sizeof(plate), "UA %04d", P[playerid][pID]);
	SetVehicleNumberPlate(veh, plate);
	SetVehicleVirtualWorld(veh, GetPlayerVirtualWorld(playerid));
	SetVehicleParamsEx(veh, 0, 0, 0, 0, 0, 0, 0);
	SendClientMessage(playerid, C_GREEN, "Ваше авто подано поруч. Двигун: /e, замок: /lock");
	return 1;
}

// =====================================================================
//   ТАЙМЕРИ: PayDay
// =====================================================================

forward MinuteTimer();
public MinuteTimer()
{
	new h, m, s;
	gettime(h, m, s);
	if (m == 0) SetWorldTime(h);

	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (!IsPlayerConnected(i) || !P[i][pLogged]) continue;
		P[i][pMinutes]++;
		if (P[i][pMinutes] % PAYDAY_MINUTES == 0) PayDay(i);
	}
	return 1;
}

stock PayDay(playerid)
{
	new salary = PAYDAY_BASE + P[playerid][pLevel] * PAYDAY_PER_LVL;
	new base = P[playerid][pBank];
	if (base > 100000) base = 100000;
	new interest = base * BANK_INTEREST / 100;
	P[playerid][pBank] += salary + interest;
	P[playerid][pExp]++;
	SendClientMessage(playerid, C_YELLOW, "========== PayDay ==========");
	SendClientMessage(playerid, C_WHITE, "Зарплата: $%d | Відсотки банку: $%d | На рахунку: $%d", salary, interest, P[playerid][pBank]);
	if (P[playerid][pExp] >= P[playerid][pLevel] * 4)
	{
		P[playerid][pExp] = 0;
		P[playerid][pLevel]++;
		SetPlayerScore(playerid, P[playerid][pLevel]);
		SendClientMessage(playerid, C_GREEN, "Вітаємо! Ваш рівень підвищено до %d.", P[playerid][pLevel]);
	}
	Acc_Save(playerid);
}

// =====================================================================
//   ПІКАПИ ТА ЧЕКПОІНТИ (зручно на телефоні — все відкривається саме)
// =====================================================================

public OnPlayerPickUpPickup(playerid, pickupid)
{
	if (!P[playerid][pLogged]) return 1;
	new now = GetTickCount();
	if (now - P[playerid][pPickupTick] < 4000) return 1;
	P[playerid][pPickupTick] = now;

	if (pickupid == gPickBank) ShowBank(playerid);
	else if (pickupid == gPickJobs) ShowJobs(playerid);
	else if (pickupid == gPickDealer) ShowDealer(playerid);
	else if (pickupid == gPickLoadTake)
	{
		if (P[playerid][pJob] != JOB_LOADER)
		{
			SendClientMessage(playerid, C_GREY, "Це склад. Влаштуйтесь вантажником на біржі праці.");
			return 1;
		}
		if (P[playerid][pCarrying]) return 1;
		if (IsPlayerInAnyVehicle(playerid)) return 1;
		P[playerid][pCarrying] = true;
		SetPlayerAttachedObject(playerid, 9, 1271, 1, 0.002953, 0.469660, -0.009797, 269.851104, 34.443557, 0.0, 0.804894, 1.0, 0.822361);
		SetPlayerSpecialAction(playerid, SPECIAL_ACTION_CARRY);
		SetCP(playerid, CP_LOADER, LOAD_DROP_X, LOAD_DROP_Y, LOAD_DROP_Z, 2.0);
		SendClientMessage(playerid, C_BLUE, "Ви взяли ящик. Віднесіть його до мітки.");
	}
	else if (pickupid == gPickTruck)
	{
		if (P[playerid][pJob] == JOB_TRUCKER) SendClientMessage(playerid, C_BLUE, "Введіть /work, щоб узяти вантажівку і почати рейс.");
		else SendClientMessage(playerid, C_GREY, "База далекобійників. Робота доступна з 2 рівня на біржі праці.");
	}
	return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
	switch (P[playerid][pCP])
	{
		case CP_GPS:
		{
			ClearCP(playerid);
			SendClientMessage(playerid, C_BLUE, "Ви прибули на місце.");
		}
		case CP_LOADER:
		{
			if (!P[playerid][pCarrying]) return 1;
			P[playerid][pCarrying] = false;
			RemovePlayerAttachedObject(playerid, 9);
			SetPlayerSpecialAction(playerid, SPECIAL_ACTION_NONE);
			GiveMoney(playerid, LOADER_PAY);
			ClearCP(playerid);
			SetCP(playerid, CP_GPS, LOAD_TAKE_X, LOAD_TAKE_Y, LOAD_TAKE_Z, 2.0);
			SendClientMessage(playerid, C_GREEN, "+$%d. Поверніться на склад за новим ящиком.", LOADER_PAY);
		}
		case CP_TRUCK:
		{
			new veh = GetPlayerVehicleID(playerid);
			if (veh == 0 || veh != P[playerid][pTruck])
			{
				SendClientMessage(playerid, C_RED, "Потрібно приїхати на своїй вантажівці.");
				return 1;
			}
			new pay = 600 + random(300) + P[playerid][pLevel] * 20;
			GiveMoney(playerid, pay);
			SendClientMessage(playerid, C_GREEN, "Вантаж доставлено! +$%d. Наступна точка — на карті. Завершити: /work", pay);
			NextTruckPoint(playerid);
		}
	}
	return 1;
}

stock NextTruckPoint(playerid)
{
	new i = random(sizeof(gTruckDest));
	SetCP(playerid, CP_TRUCK, gTruckDest[i][0], gTruckDest[i][1], gTruckDest[i][2], 6.0);
}

public OnPlayerStateChange(playerid, PLAYER_STATE:newstate, PLAYER_STATE:oldstate)
{
	if (newstate == PLAYER_STATE_DRIVER)
	{
		new veh = GetPlayerVehicleID(playerid);
		for (new i = 0; i < MAX_PLAYERS; i++)
		{
			if (i != playerid && IsPlayerConnected(i) && P[i][pCarVeh] == veh)
			{
				new engine, lights, alarm, doors, bonnet, boot, objective;
				GetVehicleParamsEx(veh, engine, lights, alarm, doors, bonnet, boot, objective);
				if (doors == 1)
				{
					RemovePlayerFromVehicle(playerid);
					SendClientMessage(playerid, C_RED, "Це авто зачинене.");
					return 1;
				}
			}
		}
		new engine, lights, alarm, doors, bonnet, boot, objective;
		GetVehicleParamsEx(veh, engine, lights, alarm, doors, bonnet, boot, objective);
		if (engine != 1) SendClientMessage(playerid, C_GREY, "Щоб завести двигун, введіть /e");
	}
	return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (!IsPlayerConnected(i)) continue;
		if (P[i][pTruck] == vehicleid)
		{
			P[i][pTruck] = INVALID_VEHICLE_ID;
			ClearCP(i);
			SendClientMessage(i, C_RED, "Вашу вантажівку знищено. Рейс скасовано.");
		}
		if (P[i][pCarVeh] == vehicleid)
		{
			DestroyVehicle(vehicleid);
			P[i][pCarVeh] = INVALID_VEHICLE_ID;
			SendClientMessage(i, C_RED, "Ваше авто розбите. Викличте його знову: /car");
		}
	}
	return 1;
}

// =====================================================================
//   ЧАТ
// =====================================================================

public OnPlayerText(playerid, text[])
{
	if (!P[playerid][pLogged]) return 0;
	if (P[playerid][pMuteUntil] > gettime())
	{
		SendClientMessage(playerid, C_RED, "У вас блокування чату.");
		return 0;
	}
	new msg[144];
	format(msg, sizeof(msg), "%s каже: %s", RPName(playerid), text);
	LocalMessage(playerid, 20.0, C_WHITE, msg);
	SetPlayerChatBubble(playerid, text, C_WHITE, 20.0, 6000);
	return 0;
}

// =====================================================================
//   КОМАНДИ
// =====================================================================

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!P[playerid][pLogged]) return 1;
	new idx = 0, cmd[64], tmp[64], msg[160];
	cmd = strtok(cmdtext, idx);

	// ---------------------------- основні
	if (!strcmp(cmd, "/menu", true) || !strcmp(cmd, "/mm", true)) return ShowMenu(playerid);
	if (!strcmp(cmd, "/help", true)) return ShowHelp(playerid);
	if (!strcmp(cmd, "/stats", true)) return ShowStats(playerid);
	if (!strcmp(cmd, "/gps", true)) return ShowGps(playerid);

	// ---------------------------- RP-чат
	if (!strcmp(cmd, "/me", true))
	{
		new text[144]; text = strrest(cmdtext, idx);
		if (!text[0]) return SendClientMessage(playerid, C_GREY, "Використання: /me [дія]");
		format(msg, sizeof(msg), "%s %s", RPName(playerid), text);
		LocalMessage(playerid, 20.0, C_PURPLE, msg);
		return 1;
	}
	if (!strcmp(cmd, "/do", true))
	{
		new text[144]; text = strrest(cmdtext, idx);
		if (!text[0]) return SendClientMessage(playerid, C_GREY, "Використання: /do [опис]");
		format(msg, sizeof(msg), "%s (%s)", text, RPName(playerid));
		LocalMessage(playerid, 20.0, C_PURPLE, msg);
		return 1;
	}
	if (!strcmp(cmd, "/try", true))
	{
		new text[144]; text = strrest(cmdtext, idx);
		if (!text[0]) return SendClientMessage(playerid, C_GREY, "Використання: /try [дія]");
		if (random(2)) format(msg, sizeof(msg), "%s %s {3DDC84}| Вдало", RPName(playerid), text);
		else format(msg, sizeof(msg), "%s %s {FF5A5A}| Невдало", RPName(playerid), text);
		LocalMessage(playerid, 20.0, C_PURPLE, msg);
		return 1;
	}
	if (!strcmp(cmd, "/b", true))
	{
		new text[144]; text = strrest(cmdtext, idx);
		if (!text[0]) return SendClientMessage(playerid, C_GREY, "Використання: /b [текст] — OOC-чат");
		format(msg, sizeof(msg), "(( %s [%d]: %s ))", PlayerName(playerid), playerid, text);
		LocalMessage(playerid, 20.0, C_GREY, msg);
		return 1;
	}
	if (!strcmp(cmd, "/s", true))
	{
		new text[144]; text = strrest(cmdtext, idx);
		if (!text[0]) return SendClientMessage(playerid, C_GREY, "Використання: /s [текст] — крикнути");
		format(msg, sizeof(msg), "%s кричить: %s!", RPName(playerid), text);
		LocalMessage(playerid, 40.0, C_WHITE, msg);
		return 1;
	}
	if (!strcmp(cmd, "/pm", true))
	{
		tmp = strtok(cmdtext, idx);
		new text[144]; text = strrest(cmdtext, idx);
		if (!IsNumeric(tmp) || !text[0]) return SendClientMessage(playerid, C_GREY, "Використання: /pm [id] [текст]");
		new id = strval(tmp);
		if (!IsPlayerConnected(id) || !P[id][pLogged]) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
		SendClientMessage(id, C_YELLOW, "(( ПП від %s [%d]: %s ))", PlayerName(playerid), playerid, text);
		SendClientMessage(playerid, C_YELLOW, "(( ПП для %s [%d]: %s ))", PlayerName(id), id, text);
		return 1;
	}
	if (!strcmp(cmd, "/report", true))
	{
		new text[144]; text = strrest(cmdtext, idx);
		if (!text[0]) return SendClientMessage(playerid, C_GREY, "Використання: /report [текст]");
		format(msg, sizeof(msg), "[Репорт] %s [%d]: %s", PlayerName(playerid), playerid, text);
		AdminMessage(C_ORANGE, msg);
		SendClientMessage(playerid, C_GREEN, "Ваше повідомлення надіслано адміністрації.");
		return 1;
	}

	// ---------------------------- гроші
	if (!strcmp(cmd, "/pay", true))
	{
		tmp = strtok(cmdtext, idx);
		new tmp2[64]; tmp2 = strtok(cmdtext, idx);
		if (!IsNumeric(tmp) || !IsNumeric(tmp2)) return SendClientMessage(playerid, C_GREY, "Використання: /pay [id] [сума]");
		new id = strval(tmp), sum = strval(tmp2);
		if (id == playerid || !IsPlayerConnected(id) || !P[id][pLogged]) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
		new Float:x, Float:y, Float:z;
		GetPlayerPos(id, x, y, z);
		if (!IsPlayerInRangeOfPoint(playerid, 5.0, x, y, z)) return SendClientMessage(playerid, C_RED, "Гравець має бути поруч.");
		if (sum <= 0 || sum > 100000) return SendClientMessage(playerid, C_RED, "Сума від $1 до $100000.");
		if (sum > P[playerid][pMoney]) return SendClientMessage(playerid, C_RED, "У вас немає стільки грошей.");
		GiveMoney(playerid, -sum);
		GiveMoney(id, sum);
		SendClientMessage(playerid, C_GREEN, "Ви передали $%d гравцю %s.", sum, RPName(id));
		SendClientMessage(id, C_GREEN, "%s передав вам $%d.", RPName(playerid), sum);
		format(msg, sizeof(msg), "%s дістає гроші і передає їх %s", RPName(playerid), RPName(id));
		LocalMessage(playerid, 15.0, C_PURPLE, msg);
		Acc_Save(playerid); Acc_Save(id);
		return 1;
	}

	// ---------------------------- робота
	if (!strcmp(cmd, "/work", true))
	{
		if (P[playerid][pJob] != JOB_TRUCKER) return SendClientMessage(playerid, C_RED, "Команда для далекобійників.");
		if (P[playerid][pTruck] != INVALID_VEHICLE_ID)
		{
			DestroyVehicle(P[playerid][pTruck]);
			P[playerid][pTruck] = INVALID_VEHICLE_ID;
			ClearCP(playerid);
			SendClientMessage(playerid, C_GREY, "Зміну завершено, вантажівку повернуто на базу.");
			return 1;
		}
		if (!IsPlayerInRangeOfPoint(playerid, 8.0, TRUCK_X, TRUCK_Y, TRUCK_Z)) return SendClientMessage(playerid, C_RED, "Почати рейс можна лише на базі далекобійників (/gps).");
		new veh = CreateVehicle(499, TRUCK_X + 6.0, TRUCK_Y, TRUCK_Z + 0.5, 90.0, 1, 1, -1);
		P[playerid][pTruck] = veh;
		SetVehicleNumberPlate(veh, "UA-CARGO");
		PutPlayerInVehicle(playerid, veh, 0);
		SetVehicleParamsEx(veh, 1, 1, 0, 0, 0, 0, 0);
		NextTruckPoint(playerid);
		SendClientMessage(playerid, C_GREEN, "Вантажівку видано. Доставте вантаж до мітки на карті.");
		return 1;
	}
	if (!strcmp(cmd, "/quitjob", true))
	{
		if (P[playerid][pJob] == JOB_NONE) return SendClientMessage(playerid, C_RED, "Ви ніде не працюєте.");
		P[playerid][pJob] = JOB_NONE;
		if (P[playerid][pTruck] != INVALID_VEHICLE_ID) { DestroyVehicle(P[playerid][pTruck]); P[playerid][pTruck] = INVALID_VEHICLE_ID; }
		if (P[playerid][pCarrying]) { P[playerid][pCarrying] = false; RemovePlayerAttachedObject(playerid, 9); SetPlayerSpecialAction(playerid, SPECIAL_ACTION_NONE); }
		ClearCP(playerid);
		Acc_Save(playerid);
		SendClientMessage(playerid, C_GREY, "Ви звільнились з роботи.");
		return 1;
	}

	// ---------------------------- транспорт
	if (!strcmp(cmd, "/car", true)) return CmdCar(playerid);
	if (!strcmp(cmd, "/lock", true))
	{
		new veh = P[playerid][pCarVeh];
		if (veh == INVALID_VEHICLE_ID) return SendClientMessage(playerid, C_RED, "Ваше авто не викликане (/car).");
		new Float:x, Float:y, Float:z;
		GetVehiclePos(veh, x, y, z);
		if (!IsPlayerInRangeOfPoint(playerid, 8.0, x, y, z)) return SendClientMessage(playerid, C_RED, "Ви далеко від свого авто.");
		new engine, lights, alarm, doors, bonnet, boot, objective;
		GetVehicleParamsEx(veh, engine, lights, alarm, doors, bonnet, boot, objective);
		doors = (doors == 1) ? 0 : 1;
		SetVehicleParamsEx(veh, engine, lights, alarm, doors, bonnet, boot, objective);
		if (doors) GameTextForPlayer(playerid, "~r~LOCKED", 1500, 3);
		else GameTextForPlayer(playerid, "~g~UNLOCKED", 1500, 3);
		return 1;
	}
	if (!strcmp(cmd, "/e", true) || !strcmp(cmd, "/engine", true))
	{
		if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER) return SendClientMessage(playerid, C_RED, "Ви маєте бути за кермом.");
		new veh = GetPlayerVehicleID(playerid);
		new engine, lights, alarm, doors, bonnet, boot, objective;
		GetVehicleParamsEx(veh, engine, lights, alarm, doors, bonnet, boot, objective);
		engine = (engine == 1) ? 0 : 1;
		SetVehicleParamsEx(veh, engine, engine, alarm, doors, bonnet, boot, objective);
		if (engine) format(msg, sizeof(msg), "%s заводить двигун", RPName(playerid));
		else format(msg, sizeof(msg), "%s глушить двигун", RPName(playerid));
		LocalMessage(playerid, 15.0, C_PURPLE, msg);
		return 1;
	}

	// ---------------------------- адмінка
	if (!strcmp(cmd, "/makeadmin", true))
	{
		if (!IsPlayerAdmin(playerid) && P[playerid][pAdmin] < 5) return 0;
		tmp = strtok(cmdtext, idx);
		new tmp2[64]; tmp2 = strtok(cmdtext, idx);
		if (!IsNumeric(tmp) || !IsNumeric(tmp2)) return SendClientMessage(playerid, C_GREY, "Використання: /makeadmin [id] [0-5]");
		new id = strval(tmp), lvl = strval(tmp2);
		if (!IsPlayerConnected(id) || !P[id][pLogged] || lvl < 0 || lvl > 5) return SendClientMessage(playerid, C_RED, "Неправильний id або рівень.");
		P[id][pAdmin] = lvl;
		Acc_Save(id);
		SendClientMessage(id, C_YELLOW, "Вам видано адмінку %d рівня. Команди: /ahelp", lvl);
		SendClientMessage(playerid, C_YELLOW, "Гравцю %s видано адмінку %d рівня.", PlayerName(id), lvl);
		return 1;
	}
	if (P[playerid][pAdmin] > 0)
	{
		if (!strcmp(cmd, "/ahelp", true))
		{
			SendClientMessage(playerid, C_YELLOW, "Адмін-команди:");
			SendClientMessage(playerid, C_WHITE, "1: /goto [id] /gethere [id] /kick [id] [причина] /mute [id] [хв] /a [текст]");
			SendClientMessage(playerid, C_WHITE, "3: /veh [модель] /dv  |  4: /setmoney [id] [сума] /ban [id]  |  5: /makeadmin [id] [рівень]");
			return 1;
		}
		if (!strcmp(cmd, "/a", true))
		{
			new text[144]; text = strrest(cmdtext, idx);
			if (!text[0]) return SendClientMessage(playerid, C_GREY, "/a [текст] — чат адмінів");
			format(msg, sizeof(msg), "[A] %s: %s", PlayerName(playerid), text);
			AdminMessage(C_ORANGE, msg);
			return 1;
		}
		if (!strcmp(cmd, "/goto", true) || !strcmp(cmd, "/gethere", true))
		{
			tmp = strtok(cmdtext, idx);
			if (!IsNumeric(tmp)) return SendClientMessage(playerid, C_GREY, "Використання: /goto [id] або /gethere [id]");
			new id = strval(tmp);
			if (!IsPlayerConnected(id)) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
			new from = playerid, to = id;
			if (!strcmp(cmd, "/gethere", true)) { from = id; to = playerid; }
			new Float:x, Float:y, Float:z;
			GetPlayerPos(to, x, y, z);
			SetPlayerInterior(from, GetPlayerInterior(to));
			SetPlayerVirtualWorld(from, GetPlayerVirtualWorld(to));
			SetPlayerPos(from, x + 1.0, y + 1.0, z);
			return 1;
		}
		if (!strcmp(cmd, "/kick", true))
		{
			tmp = strtok(cmdtext, idx);
			new text[144]; text = strrest(cmdtext, idx);
			if (!IsNumeric(tmp)) return SendClientMessage(playerid, C_GREY, "Використання: /kick [id] [причина]");
			new id = strval(tmp);
			if (!IsPlayerConnected(id)) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
			if (!text[0]) text = "не вказана";
			SendClientMessageToAll(C_RED, "Адмін %s кікнув %s. Причина: %s", PlayerName(playerid), PlayerName(id), text);
			SetTimerEx("DelayedKick", 300, false, "i", id);
			return 1;
		}
		if (!strcmp(cmd, "/mute", true))
		{
			tmp = strtok(cmdtext, idx);
			new tmp2[64]; tmp2 = strtok(cmdtext, idx);
			if (!IsNumeric(tmp) || !IsNumeric(tmp2)) return SendClientMessage(playerid, C_GREY, "Використання: /mute [id] [хвилин]");
			new id = strval(tmp);
			if (!IsPlayerConnected(id)) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
			P[id][pMuteUntil] = gettime() + strval(tmp2) * 60;
			SendClientMessage(id, C_RED, "Адмін заблокував вам чат на %d хв.", strval(tmp2));
			SendClientMessage(playerid, C_YELLOW, "Готово.");
			return 1;
		}
		if (P[playerid][pAdmin] >= 3 && !strcmp(cmd, "/veh", true))
		{
			tmp = strtok(cmdtext, idx);
			if (!IsNumeric(tmp)) return SendClientMessage(playerid, C_GREY, "Використання: /veh [модель 400-611]");
			new model = strval(tmp);
			if (model < 400 || model > 611) return SendClientMessage(playerid, C_RED, "Модель від 400 до 611.");
			new Float:x, Float:y, Float:z, Float:a;
			GetPlayerPos(playerid, x, y, z);
			GetPlayerFacingAngle(playerid, a);
			new veh = CreateVehicle(model, x, y, z + 0.5, a, -1, -1, -1);
			SetVehicleVirtualWorld(veh, GetPlayerVirtualWorld(playerid));
			PutPlayerInVehicle(playerid, veh, 0);
			SetVehicleParamsEx(veh, 1, 1, 0, 0, 0, 0, 0);
			return 1;
		}
		if (P[playerid][pAdmin] >= 3 && !strcmp(cmd, "/dv", true))
		{
			new veh = GetPlayerVehicleID(playerid);
			if (veh == 0) return SendClientMessage(playerid, C_RED, "Сядьте в транспорт.");
			DestroyVehicle(veh);
			return 1;
		}
		if (P[playerid][pAdmin] >= 4 && !strcmp(cmd, "/setmoney", true))
		{
			tmp = strtok(cmdtext, idx);
			new tmp2[64]; tmp2 = strtok(cmdtext, idx);
			if (!IsNumeric(tmp) || !IsNumeric(tmp2)) return SendClientMessage(playerid, C_GREY, "Використання: /setmoney [id] [сума]");
			new id = strval(tmp);
			if (!IsPlayerConnected(id) || !P[id][pLogged]) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
			SetMoney(id, strval(tmp2));
			Acc_Save(id);
			SendClientMessage(playerid, C_YELLOW, "Готівку %s встановлено: $%d", PlayerName(id), strval(tmp2));
			return 1;
		}
		if (P[playerid][pAdmin] >= 4 && !strcmp(cmd, "/ban", true))
		{
			tmp = strtok(cmdtext, idx);
			if (!IsNumeric(tmp)) return SendClientMessage(playerid, C_GREY, "Використання: /ban [id]");
			new id = strval(tmp);
			if (!IsPlayerConnected(id)) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
			SendClientMessageToAll(C_RED, "Адмін %s заблокував %s.", PlayerName(playerid), PlayerName(id));
			SetTimerEx("DelayedBan", 300, false, "i", id);
			return 1;
		}
	}

	SendClientMessage(playerid, C_GREY, "Невідома команда. Список команд: /help");
	return 1;
}

forward DelayedBan(playerid);
public DelayedBan(playerid)
{
	Ban(playerid);
	return 1;
}

public OnRconLoginAttempt(ip[], password[], success)
{
	return 1;
}
