// =====================================================================
//   UA RolePlay — український RP-мод для open.mp
//   Акаунти, паспорт, автошкола, початкові квести, вибір спавну,
//   HUD, банк, PayDay, роботи (вантажник, далекобійник, водій автобуса),
//   автосалон, фракції (поліція, лікарня, уряд), RP-чат, адмінка.
//   База даних: вбудований SQLite (scriptfiles/uarp.db).
//
//   Файл зберігається в UTF-8. GitHub перед компіляцією
//   перетворює його у Windows-1251, щоб українські літери працювали в грі.
// =====================================================================

#include <open.mp>

#define SERVER_NAME        "UA RolePlay"
#define SERVER_VERSION     "UA-RP 1.1"

// ---------------------------------------------------------------- кольори
#define C_WHITE      0xFFFFFFFF
#define C_GREY       0xAFAFAFFF
#define C_YELLOW     0xFFC93CFF
#define C_BLUE       0x4FA3FFFF
#define C_GREEN      0x3DDC84FF
#define C_RED        0xFF5A5AFF
#define C_PURPLE     0xC2A2DAFF
#define C_ORANGE     0xFFA63CFF
#define C_POLICE     0x3A7BFFFF
#define C_MEDIC      0xFF7A9AFF
#define C_GOV        0xE0E0E0FF

// ---------------------------------------------------------------- економіка
#define START_MONEY       5000
#define PAYDAY_BASE       500
#define PAYDAY_PER_LVL    100
#define PAYDAY_MINUTES    60
#define LOADER_PAY        150
#define BUS_PAY           120
#define BANK_INTEREST     1
#define LICENSE_PRICE     500
#define HOSPITAL_FEE      100

// ---------------------------------------------------------------- точки
#define SPAWN_X   1759.04
#define SPAWN_Y   -1898.13
#define SPAWN_Z   13.56
#define SPAWN_A   270.0

#define HALL_X    1481.03
#define HALL_Y    -1771.0
#define HALL_Z    18.79

#define BANK_X    1462.0
#define BANK_Y    -1011.0
#define BANK_Z    26.84

#define JOBC_X    1466.4
#define JOBC_Y    -1744.0
#define JOBC_Z    13.55

#define DEAL_X    2131.8
#define DEAL_Y    -1150.8
#define DEAL_Z    24.1

#define SCHOOL_X  1081.0
#define SCHOOL_Y  -1696.0
#define SCHOOL_Z  13.55

#define HOSP_X    1177.6
#define HOSP_Y    -1323.5
#define HOSP_Z    14.1

#define PD_X      1554.9
#define PD_Y      -1675.6
#define PD_Z      16.2

#define JAIL_X    264.0
#define JAIL_Y    77.5
#define JAIL_Z    1001.04
#define JAIL_INT  6

#define LOAD_TAKE_X   2775.6
#define LOAD_TAKE_Y   -2420.0
#define LOAD_TAKE_Z   13.64
#define LOAD_DROP_X   2744.0
#define LOAD_DROP_Y   -2440.0
#define LOAD_DROP_Z   13.64

#define TRUCK_X   2193.0
#define TRUCK_Y   -2253.0
#define TRUCK_Z   13.54

#define BUS_X     1810.0
#define BUS_Y     -1890.0
#define BUS_Z     13.58

// ---------------------------------------------------------------- діалоги
#define DLG_LOGIN       1
#define DLG_REG         2
#define DLG_REG_SEX     3
#define DLG_SPAWN       4
#define DLG_MENU        10
#define DLG_HELP        11
#define DLG_STATS       12
#define DLG_GPS         13
#define DLG_QUEST       14
#define DLG_FACTION     15
#define DLG_BANK        20
#define DLG_BANK_DEP    21
#define DLG_BANK_WD     22
#define DLG_BANK_INFO   23
#define DLG_DEALER      30
#define DLG_JOBS        40
#define DLG_SCHOOL      50
#define DLG_HALL        60

// ---------------------------------------------------------------- роботи
#define JOB_NONE     0
#define JOB_LOADER   1
#define JOB_TRUCKER  2
#define JOB_BUS      3

// ---------------------------------------------------------------- фракції
#define FAC_NONE     0
#define FAC_POLICE   1
#define FAC_MEDIC    2
#define FAC_GOV      3
#define MAX_FAC      4
#define MAX_RANK     6

// ---------------------------------------------------------------- чекпоінти
#define CP_NONE      0
#define CP_GPS       1
#define CP_LOADER    2
#define CP_TRUCK     3
#define CP_BUS       4
#define CP_TEST      5

// ---------------------------------------------------------------- квести
#define Q_PASSPORT   0
#define Q_JOB        1
#define Q_MONEY      2
#define Q_LICENSE    3
#define Q_DONE       4
#define Q_MONEY_GOAL 500

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
	pBus,
	pBusStop,
	pPickupTick,
	pMuteUntil,
	pFaction,
	pRank,
	pQuest,
	pQuestMoney,
	pPassport,
	pLicense,
	pWanted,
	pJail,
	bool:pCuffed,
	bool:pDied,
	pTestVeh,
	pTestStep,
	pSpawnAt,
	PlayerText:pHud
}
new P[MAX_PLAYERS][E_PLAYER];

new DB:gDB;
new Text:gLogoTD;
new gPickBank, gPickJobs, gPickDealer, gPickLoadTake, gPickTruck, gPickHall, gPickSchool, gPickBus, gPickPD, gPickHosp;

// ---------------------------------------------------------------- довідники
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

new const Float:gTruckDest[][3] =
{
	{1940.0, -1772.0, 13.39},
	{1355.0, -1750.0, 13.38},
	{2446.0, -1760.0, 13.59},
	{1000.0, -1300.0, 13.38},
	{2114.0, -1772.0, 13.39}
};

new const Float:gBusRoute[][3] =
{
	{1824.0, -1755.0, 13.38},
	{1740.0, -1592.0, 13.38},
	{1527.0, -1595.0, 13.38},
	{1369.0, -1735.0, 13.38},
	{1294.0, -1854.0, 13.38},
	{1572.0, -1874.0, 13.38},
	{1808.0, -1872.0, 13.38}
};

new const Float:gTestRoute[][3] =
{
	{1172.0, -1708.0, 13.39},
	{1312.0, -1712.0, 13.38},
	{1314.0, -1570.0, 13.38},
	{1195.0, -1572.0, 13.38},
	{1066.0, -1572.0, 13.38},
	{1060.0, -1700.0, 13.38}
};

enum E_GPS { gName[48], Float:gX, Float:gY, Float:gZ }
new const gGps[][E_GPS] =
{
	{"Вокзал (місце появи)",          SPAWN_X, SPAWN_Y, SPAWN_Z},
	{"Мерія (паспорт)",               HALL_X,  HALL_Y,  HALL_Z},
	{"Банк",                          BANK_X,  BANK_Y,  BANK_Z},
	{"Біржа праці",                   JOBC_X,  JOBC_Y,  JOBC_Z},
	{"Автошкола",                     SCHOOL_X, SCHOOL_Y, SCHOOL_Z},
	{"Автосалон",                     DEAL_X,  DEAL_Y,  DEAL_Z},
	{"Поліція ЛС",                    PD_X,    PD_Y,    PD_Z},
	{"Лікарня",                       HOSP_X,  HOSP_Y,  HOSP_Z},
	{"Склад (вантажник)",             LOAD_TAKE_X, LOAD_TAKE_Y, LOAD_TAKE_Z},
	{"База далекобійників",           TRUCK_X, TRUCK_Y, TRUCK_Z},
	{"Автобусний парк",               BUS_X,   BUS_Y,   BUS_Z}
};

new const gFacName[MAX_FAC][24] =
{
	"Цивільний", "Поліція ЛС", "Лікарня ЛС", "Уряд"
};

new const gFacColor[MAX_FAC] = { C_WHITE, C_POLICE, C_MEDIC, C_GOV };

new const gRankName[MAX_FAC][MAX_RANK][24] =
{
	{"-", "-", "-", "-", "-", "-"},
	{"Кадет", "Офіцер", "Сержант", "Лейтенант", "Капітан", "Шеф поліції"},
	{"Інтерн", "Медбрат", "Лікар", "Хірург", "Зав. відділення", "Головлікар"},
	{"Секретар", "Помічник", "Юрист", "Радник", "Віце-мер", "Мер"}
};

new const gFacSkin[MAX_FAC][MAX_RANK] =
{
	{0, 0, 0, 0, 0, 0},
	{280, 281, 282, 283, 288, 284},
	{274, 275, 276, 274, 275, 276},
	{147, 150, 187, 147, 150, 187}
};

new const Float:gFacHQ[MAX_FAC][3] =
{
	{SPAWN_X, SPAWN_Y, SPAWN_Z},
	{PD_X, PD_Y, PD_Z},
	{HOSP_X, HOSP_Y, HOSP_Z},
	{HALL_X, HALL_Y, HALL_Z}
};

new const gQuestText[][96] =
{
	"Отримайте паспорт у мерії (/gps -> Мерія)",
	"Влаштуйтесь на роботу на біржі праці",
	"Заробіть перші $500 на роботі",
	"Складіть іспит в автошколі",
	"Усі початкові завдання виконано!"
};

new const gQuestReward[] = { 1000, 1000, 2000, 3000, 0 };

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

stock IsValidTarget(id)
{
	return (id >= 0 && id < MAX_PLAYERS && IsPlayerConnected(id) && P[id][pLogged]);
}

stock IsNear(playerid, id, Float:range)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(id, x, y, z);
	return IsPlayerInRangeOfPoint(playerid, range, x, y, z);
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

stock FactionMessage(fac, colour, const text[])
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (IsPlayerConnected(i) && P[i][pLogged] && P[i][pFaction] == fac)
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

stock RankName(playerid)
{
	new s[24];
	new f = P[playerid][pFaction], r = P[playerid][pRank];
	if (f <= FAC_NONE || f >= MAX_FAC || r < 1 || r > MAX_RANK) s = "-";
	else format(s, sizeof(s), "%s", gRankName[f][r - 1]);
	return s;
}

stock JobName(job)
{
	new s[32];
	switch (job)
	{
		case JOB_LOADER:  s = "Вантажник";
		case JOB_TRUCKER: s = "Далекобійник";
		case JOB_BUS:     s = "Водій автобуса";
		default:          s = "Безробітний";
	}
	return s;
}

stock ApplyFactionLook(playerid)
{
	new f = P[playerid][pFaction], r = P[playerid][pRank];
	if (f > FAC_NONE && f < MAX_FAC && r >= 1 && r <= MAX_RANK)
	{
		SetPlayerSkin(playerid, gFacSkin[f][r - 1]);
		SetPlayerColor(playerid, (gFacColor[f] & 0xFFFFFF00) | 0xAA);
		if (f == FAC_POLICE)
		{
			ResetPlayerWeapons(playerid);
			GivePlayerWeapon(playerid, WEAPON_NIGHTSTICK, 1);
			GivePlayerWeapon(playerid, WEAPON_COLT45, 50);
		}
	}
	else
	{
		SetPlayerSkin(playerid, P[playerid][pSkin]);
		SetPlayerColor(playerid, 0xFFFFFF00);
	}
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
	P[playerid][pBus] = INVALID_VEHICLE_ID;
	P[playerid][pBusStop] = 0;
	P[playerid][pPickupTick] = 0;
	P[playerid][pMuteUntil] = 0;
	P[playerid][pFaction] = FAC_NONE;
	P[playerid][pRank] = 0;
	P[playerid][pQuest] = Q_PASSPORT;
	P[playerid][pQuestMoney] = 0;
	P[playerid][pPassport] = 0;
	P[playerid][pLicense] = 0;
	P[playerid][pWanted] = 0;
	P[playerid][pJail] = 0;
	P[playerid][pCuffed] = false;
	P[playerid][pDied] = false;
	P[playerid][pTestVeh] = INVALID_VEHICLE_ID;
	P[playerid][pTestStep] = 0;
	P[playerid][pSpawnAt] = 0;
	P[playerid][pHud] = PlayerText:INVALID_PLAYER_TEXT_DRAW;
}

// =====================================================================
//   HUD (текстдрави латиницею — у стандартному шрифті GTA немає кирилиці)
// =====================================================================

stock Hud_Create(playerid)
{
	new PlayerText:td = CreatePlayerTextDraw(playerid, 500.0, 100.0, "_");
	PlayerTextDrawFont(playerid, td, TEXT_DRAW_FONT_1);
	PlayerTextDrawLetterSize(playerid, td, 0.26, 1.05);
	PlayerTextDrawColour(playerid, td, 0xFFFFFFFF);
	PlayerTextDrawSetOutline(playerid, td, 1);
	PlayerTextDrawAlignment(playerid, td, TEXT_DRAW_ALIGN_LEFT);
	P[playerid][pHud] = td;
	Hud_Update(playerid);
	PlayerTextDrawShow(playerid, td);
}

stock Hud_Update(playerid)
{
	if (P[playerid][pHud] == PlayerText:INVALID_PLAYER_TEXT_DRAW) return 0;
	new s[160];
	format(s, sizeof(s), "LVL ~y~%d~w~  EXP ~y~%d/%d~n~~w~PAYDAY ~y~%dm",
		P[playerid][pLevel], P[playerid][pExp], P[playerid][pLevel] * 4,
		PAYDAY_MINUTES - (P[playerid][pMinutes] % PAYDAY_MINUTES));
	if (P[playerid][pWanted] > 0)
	{
		new w[32];
		format(w, sizeof(w), "~n~~r~WANTED %d", P[playerid][pWanted]);
		strcat(s, w);
	}
	if (P[playerid][pJail] > 0)
	{
		new j[32];
		format(j, sizeof(j), "~n~~r~JAIL %dm", P[playerid][pJail]);
		strcat(s, j);
	}
	PlayerTextDrawSetString(playerid, P[playerid][pHud], "%s", s);
	return 1;
}

// =====================================================================
//   БАЗА ДАНИХ
// =====================================================================

stock DB_AddColumn(const col[])
{
	new DBResult:r = DB_ExecuteQuery(gDB, "SELECT %s FROM accounts LIMIT 1", col);
	if (r)
	{
		DB_FreeResultSet(r);
		return 0;
	}
	r = DB_ExecuteQuery(gDB, "ALTER TABLE accounts ADD COLUMN %s INTEGER DEFAULT 0", col);
	if (r) DB_FreeResultSet(r);
	return 1;
}

stock DB_Init()
{
	gDB = DB_Open("uarp.db");
	if (gDB == DB:0)
	{
		print("[UA-RP] ПОМИЛКА: не вдалося відкрити scriptfiles/uarp.db");
		return 0;
	}
	new DBResult:r = DB_ExecuteQuery(gDB,
		"CREATE TABLE IF NOT EXISTS accounts (\
		id INTEGER PRIMARY KEY AUTOINCREMENT,\
		name TEXT UNIQUE COLLATE NOCASE,\
		pass TEXT, salt TEXT,\
		money INTEGER DEFAULT 0, bank INTEGER DEFAULT 0,\
		level INTEGER DEFAULT 1, exp INTEGER DEFAULT 0,\
		skin INTEGER DEFAULT 26, admin INTEGER DEFAULT 0,\
		minutes INTEGER DEFAULT 0, job INTEGER DEFAULT 0,\
		car INTEGER DEFAULT 0, regdate TEXT)");
	if (r) DB_FreeResultSet(r);

	// Нові поля (для бази, створеної попередньою версією моду)
	DB_AddColumn("faction");
	DB_AddColumn("rank");
	DB_AddColumn("quest");
	DB_AddColumn("qmoney");
	DB_AddColumn("passport");
	DB_AddColumn("license");
	DB_AddColumn("wanted");
	DB_AddColumn("jail");
	print("[UA-RP] База даних uarp.db підключена");
	return 1;
}

stock Acc_Save(playerid)
{
	if (!P[playerid][pLogged]) return 0;
	new DBResult:r = DB_ExecuteQuery(gDB,
		"UPDATE accounts SET money=%d, bank=%d, level=%d, exp=%d, skin=%d, admin=%d, minutes=%d, job=%d, car=%d, \
faction=%d, rank=%d, quest=%d, qmoney=%d, passport=%d, license=%d, wanted=%d, jail=%d WHERE id=%d",
		P[playerid][pMoney], P[playerid][pBank], P[playerid][pLevel], P[playerid][pExp],
		P[playerid][pSkin], P[playerid][pAdmin], P[playerid][pMinutes], P[playerid][pJob],
		P[playerid][pCar], P[playerid][pFaction], P[playerid][pRank], P[playerid][pQuest],
		P[playerid][pQuestMoney], P[playerid][pPassport], P[playerid][pLicense],
		P[playerid][pWanted], P[playerid][pJail], P[playerid][pID]);
	if (r) DB_FreeResultSet(r);
	return 1;
}

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
		P[playerid][pMoney]      = DB_GetFieldIntByName(r, "money");
		P[playerid][pBank]       = DB_GetFieldIntByName(r, "bank");
		P[playerid][pLevel]      = DB_GetFieldIntByName(r, "level");
		P[playerid][pExp]        = DB_GetFieldIntByName(r, "exp");
		P[playerid][pSkin]       = DB_GetFieldIntByName(r, "skin");
		P[playerid][pAdmin]      = DB_GetFieldIntByName(r, "admin");
		P[playerid][pMinutes]    = DB_GetFieldIntByName(r, "minutes");
		P[playerid][pJob]        = DB_GetFieldIntByName(r, "job");
		P[playerid][pCar]        = DB_GetFieldIntByName(r, "car");
		P[playerid][pFaction]    = DB_GetFieldIntByName(r, "faction");
		P[playerid][pRank]       = DB_GetFieldIntByName(r, "rank");
		P[playerid][pQuest]      = DB_GetFieldIntByName(r, "quest");
		P[playerid][pQuestMoney] = DB_GetFieldIntByName(r, "qmoney");
		P[playerid][pPassport]   = DB_GetFieldIntByName(r, "passport");
		P[playerid][pLicense]    = DB_GetFieldIntByName(r, "license");
		P[playerid][pWanted]     = DB_GetFieldIntByName(r, "wanted");
		P[playerid][pJail]       = DB_GetFieldIntByName(r, "jail");
	}
	DB_FreeResultSet(r);
	if (P[playerid][pLevel] < 1) P[playerid][pLevel] = 1;
	if (P[playerid][pFaction] < 0 || P[playerid][pFaction] >= MAX_FAC) P[playerid][pFaction] = FAC_NONE;
	if (P[playerid][pQuest] < 0 || P[playerid][pQuest] > Q_DONE) P[playerid][pQuest] = Q_PASSPORT;
	return 1;
}

// =====================================================================
//   ПОЧАТКОВІ КВЕСТИ
// =====================================================================

stock CheckLevelUp(playerid)
{
	if (P[playerid][pExp] >= P[playerid][pLevel] * 4)
	{
		P[playerid][pExp] = 0;
		P[playerid][pLevel]++;
		SetPlayerScore(playerid, P[playerid][pLevel]);
		SendClientMessage(playerid, C_GREEN, "Вітаємо! Ваш рівень підвищено до %d.", P[playerid][pLevel]);
	}
}

stock Quest_Show(playerid)
{
	new q = P[playerid][pQuest];
	if (q >= Q_DONE)
	{
		SendClientMessage(playerid, C_GREEN, "[Квест] Усі початкові завдання виконано. Ласкаво просимо до міста!");
		return 1;
	}
	SendClientMessage(playerid, C_YELLOW, "[Квест %d/4] %s", q + 1, gQuestText[q]);
	switch (q)
	{
		case Q_PASSPORT: SetCP(playerid, CP_GPS, HALL_X, HALL_Y, HALL_Z, 3.0);
		case Q_JOB:      SetCP(playerid, CP_GPS, JOBC_X, JOBC_Y, JOBC_Z, 3.0);
		case Q_LICENSE:  SetCP(playerid, CP_GPS, SCHOOL_X, SCHOOL_Y, SCHOOL_Z, 3.0);
	}
	return 1;
}

stock Quest_Dialog(playerid)
{
	new body[700], line[160];
	for (new i = 0; i < Q_DONE; i++)
	{
		if (i < P[playerid][pQuest]) format(line, sizeof(line), "{3DDC84}[V] %s\n", gQuestText[i]);
		else if (i == P[playerid][pQuest]) format(line, sizeof(line), "{FFC93C}[>] %s {AFAFAF}(нагорода $%d)\n", gQuestText[i], gQuestReward[i]);
		else format(line, sizeof(line), "{AFAFAF}[ ] %s\n", gQuestText[i]);
		strcat(body, line);
	}
	if (P[playerid][pQuest] == Q_MONEY)
	{
		format(line, sizeof(line), "\n{FFFFFF}Зароблено на роботі: {3DDC84}$%d{FFFFFF} / $%d", P[playerid][pQuestMoney], Q_MONEY_GOAL);
		strcat(body, line);
	}
	ShowPlayerDialog(playerid, DLG_QUEST, DIALOG_STYLE_MSGBOX, "Початкові завдання", body, "Закрити", "");
	return 1;
}

stock Quest_Complete(playerid, stage)
{
	if (P[playerid][pQuest] != stage) return 0;
	new reward = gQuestReward[stage];
	GiveMoney(playerid, reward);
	P[playerid][pExp]++;
	P[playerid][pQuest]++;
	SendClientMessage(playerid, C_GREEN, "[Квест] Виконано: %s  Нагорода: $%d і +1 досвіду.", gQuestText[stage], reward);
	GameTextForPlayer(playerid, "~g~QUEST COMPLETE", 2500, 3);
	CheckLevelUp(playerid);
	Acc_Save(playerid);
	Hud_Update(playerid);
	Quest_Show(playerid);
	return 1;
}

stock AddJobEarnings(playerid, amount)
{
	GiveMoney(playerid, amount);
	if (P[playerid][pQuest] == Q_MONEY)
	{
		P[playerid][pQuestMoney] += amount;
		if (P[playerid][pQuestMoney] >= Q_MONEY_GOAL) Quest_Complete(playerid, Q_MONEY);
	}
}

// =====================================================================
//   ВХІД, РЕЄСТРАЦІЯ, СПАВН
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

stock ShowSpawnChoice(playerid)
{
	new body[256];
	strcat(body, "Вокзал Лос-Сантоса\nМерія\n");
	if (P[playerid][pFaction] > FAC_NONE)
	{
		new line[64];
		format(line, sizeof(line), "Штаб фракції: %s\n", gFacName[P[playerid][pFaction]]);
		strcat(body, line);
	}
	ShowPlayerDialog(playerid, DLG_SPAWN, DIALOG_STYLE_LIST, "Де з'явитися?", body, "Обрати", "");
}

stock ApplySpawnPoint(playerid)
{
	new Float:x = SPAWN_X, Float:y = SPAWN_Y, Float:z = SPAWN_Z;
	switch (P[playerid][pSpawnAt])
	{
		case 1: { x = HALL_X; y = HALL_Y + 3.0; z = HALL_Z; }
		case 2:
		{
			new f = P[playerid][pFaction];
			if (f > FAC_NONE && f < MAX_FAC) { x = gFacHQ[f][0]; y = gFacHQ[f][1]; z = gFacHQ[f][2]; }
		}
	}
	SetSpawnInfo(playerid, NO_TEAM, P[playerid][pSkin], x, y, z, SPAWN_A);
}

stock EnterWorld(playerid)
{
	ApplySpawnPoint(playerid);
	TogglePlayerSpectating(playerid, false);
	SetMoney(playerid, P[playerid][pMoney]);
	SetPlayerScore(playerid, P[playerid][pLevel]);
	Hud_Create(playerid);
	SendClientMessage(playerid, C_GREEN, "Ви увійшли в гру. Головне меню: /menu, допомога: /help, квести: /quest");
	if (P[playerid][pFaction] > FAC_NONE)
	{
		SendClientMessage(playerid, gFacColor[P[playerid][pFaction]], "Фракція: %s, ранг: %s. Рація: /r", gFacName[P[playerid][pFaction]], RankName(playerid));
	}
	if (P[playerid][pAdmin] > 0)
	{
		SendClientMessage(playerid, C_YELLOW, "Ви адміністратор %d рівня. Команди: /ahelp", P[playerid][pAdmin]);
	}
	SetTimerEx("DelayedQuest", 3000, false, "i", playerid);
}

forward DelayedQuest(playerid);
public DelayedQuest(playerid)
{
	if (IsPlayerConnected(playerid) && P[playerid][pLogged]) Quest_Show(playerid);
	return 1;
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

	gPickHall     = CreatePickup(1239, 1, HALL_X, HALL_Y, HALL_Z);
	gPickBank     = CreatePickup(1274, 1, BANK_X, BANK_Y, BANK_Z);
	gPickJobs     = CreatePickup(1210, 1, JOBC_X, JOBC_Y, JOBC_Z);
	gPickSchool   = CreatePickup(1239, 1, SCHOOL_X, SCHOOL_Y, SCHOOL_Z);
	gPickDealer   = CreatePickup(1239, 1, DEAL_X, DEAL_Y, DEAL_Z);
	gPickLoadTake = CreatePickup(1271, 1, LOAD_TAKE_X, LOAD_TAKE_Y, LOAD_TAKE_Z);
	gPickTruck    = CreatePickup(1239, 1, TRUCK_X, TRUCK_Y, TRUCK_Z);
	gPickBus      = CreatePickup(1239, 1, BUS_X, BUS_Y, BUS_Z);
	gPickPD       = CreatePickup(1247, 1, PD_X, PD_Y, PD_Z);
	gPickHosp     = CreatePickup(1240, 1, HOSP_X, HOSP_Y, HOSP_Z);

	Create3DTextLabel("{FFC93C}Мерія\n{FFFFFF}Паспорт, фракції", C_WHITE, HALL_X, HALL_Y, HALL_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FFC93C}Банк\n{FFFFFF}Станьте на значок", C_WHITE, BANK_X, BANK_Y, BANK_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FFC93C}Біржа праці\n{FFFFFF}Станьте на значок", C_WHITE, JOBC_X, JOBC_Y, JOBC_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FFC93C}Автошкола\n{FFFFFF}Іспит на права", C_WHITE, SCHOOL_X, SCHOOL_Y, SCHOOL_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FFC93C}Автосалон\n{FFFFFF}Станьте на значок", C_WHITE, DEAL_X, DEAL_Y, DEAL_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FFC93C}Склад\n{FFFFFF}Візьміть ящик", C_WHITE, LOAD_TAKE_X, LOAD_TAKE_Y, LOAD_TAKE_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FFC93C}База далекобійників\n{FFFFFF}/work — почати рейс", C_WHITE, TRUCK_X, TRUCK_Y, TRUCK_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FFC93C}Автобусний парк\n{FFFFFF}/work — почати маршрут", C_WHITE, BUS_X, BUS_Y, BUS_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{3A7BFF}Поліція Лос-Сантоса", C_WHITE, PD_X, PD_Y, PD_Z + 0.6, 20.0, 0);
	Create3DTextLabel("{FF7A9A}Лікарня Лос-Сантоса", C_WHITE, HOSP_X, HOSP_Y, HOSP_Z + 0.6, 20.0, 0);

	AddStaticVehicleEx(462, 1777.0, -1890.0, 13.2, 270.0, -1, -1, 600);
	AddStaticVehicleEx(462, 1777.0, -1893.0, 13.2, 270.0, -1, -1, 600);
	AddStaticVehicleEx(462, 1777.0, -1896.0, 13.2, 270.0, -1, -1, 600);
	AddStaticVehicleEx(509, 1777.0, -1899.0, 13.2, 270.0, -1, -1, 600);
	AddStaticVehicleEx(509, 1777.0, -1902.0, 13.2, 270.0, -1, -1, 600);
	// Поліцейські авто
	AddStaticVehicleEx(596, 1535.0, -1667.0, 13.2, 0.0, 0, 1, 600);
	AddStaticVehicleEx(596, 1535.0, -1675.0, 13.2, 0.0, 0, 1, 600);
	// Швидкі
	AddStaticVehicleEx(416, 1179.0, -1308.0, 14.0, 270.0, 1, 3, 600);
	AddStaticVehicleEx(416, 1179.0, -1338.0, 14.0, 270.0, 1, 3, 600);

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

forward DelayedBan(playerid);
public DelayedBan(playerid)
{
	Ban(playerid);
	return 1;
}

stock DestroyJobVehicles(playerid)
{
	if (P[playerid][pCarVeh] != INVALID_VEHICLE_ID) { DestroyVehicle(P[playerid][pCarVeh]); P[playerid][pCarVeh] = INVALID_VEHICLE_ID; }
	if (P[playerid][pTruck] != INVALID_VEHICLE_ID) { DestroyVehicle(P[playerid][pTruck]); P[playerid][pTruck] = INVALID_VEHICLE_ID; }
	if (P[playerid][pBus] != INVALID_VEHICLE_ID) { DestroyVehicle(P[playerid][pBus]); P[playerid][pBus] = INVALID_VEHICLE_ID; }
	if (P[playerid][pTestVeh] != INVALID_VEHICLE_ID) { DestroyVehicle(P[playerid][pTestVeh]); P[playerid][pTestVeh] = INVALID_VEHICLE_ID; }
}

public OnPlayerDisconnect(playerid, reason)
{
	// Утеча в наручниках — в'язниця при наступному вході
	if (P[playerid][pLogged] && P[playerid][pCuffed] && P[playerid][pJail] == 0)
	{
		P[playerid][pJail] = 20;
	}
	Acc_Save(playerid);
	DestroyJobVehicles(playerid);
	ResetPlayerData(playerid);
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	if (P[playerid][pLogged])
	{
		ApplySpawnPoint(playerid);
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
	SetPlayerInterior(playerid, 0);
	SetPlayerVirtualWorld(playerid, 0);
	SetMoney(playerid, P[playerid][pMoney]);
	SetPlayerWantedLevel(playerid, P[playerid][pWanted]);
	ApplyFactionLook(playerid);

	if (P[playerid][pJail] > 0)
	{
		SetPlayerInterior(playerid, JAIL_INT);
		SetPlayerPos(playerid, JAIL_X, JAIL_Y, JAIL_Z);
		SendClientMessage(playerid, C_RED, "Ви у в'язниці. Залишилось: %d хв.", P[playerid][pJail]);
	}
	else if (P[playerid][pDied])
	{
		P[playerid][pDied] = false;
		SetPlayerPos(playerid, HOSP_X, HOSP_Y + 2.0, HOSP_Z);
		new fee = HOSPITAL_FEE;
		if (P[playerid][pMoney] < fee) fee = P[playerid][pMoney];
		if (fee > 0) GiveMoney(playerid, -fee);
		SendClientMessage(playerid, C_MEDIC, "Вас доставили до лікарні. Лікування коштувало $%d.", fee);
	}
	Hud_Update(playerid);
	return 1;
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
	if (P[playerid][pCarrying])
	{
		P[playerid][pCarrying] = false;
		RemovePlayerAttachedObject(playerid, 9);
	}
	if (P[playerid][pTestVeh] != INVALID_VEHICLE_ID)
	{
		DestroyVehicle(P[playerid][pTestVeh]);
		P[playerid][pTestVeh] = INVALID_VEHICLE_ID;
	}
	P[playerid][pCuffed] = false;
	P[playerid][pDied] = true;
	ClearCP(playerid);

	// Вбивство — розшук для вбивці (крім поліції)
	if (IsValidTarget(killerid) && P[killerid][pFaction] != FAC_POLICE)
	{
		P[killerid][pWanted] += 2;
		if (P[killerid][pWanted] > 6) P[killerid][pWanted] = 6;
		SetPlayerWantedLevel(killerid, P[killerid][pWanted]);
		SendClientMessage(killerid, C_RED, "Вас оголошено в розшук! Рівень розшуку: %d", P[killerid][pWanted]);
		new msg[144];
		format(msg, sizeof(msg), "[Диспетчер] Убивство! Підозрюваний: %s, рівень розшуку %d", PlayerName(killerid), P[killerid][pWanted]);
		FactionMessage(FAC_POLICE, C_POLICE, msg);
		Hud_Update(killerid);
	}
	return 1;
}

// =====================================================================
//   ДІАЛОГИ
// =====================================================================

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
			P[playerid][pLogged] = true;
			ShowSpawnChoice(playerid);
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
			new DBResult:r = DB_ExecuteQuery(gDB,
				"INSERT INTO accounts (name, pass, salt, money, skin, regdate) VALUES ('%s', '%s', '%s', %d, %d, '%s')",
				PlayerName(playerid), P[playerid][pPass], P[playerid][pSalt], START_MONEY, P[playerid][pSkin], date);
			if (r) DB_FreeResultSet(r);
			if (!Acc_Exists(playerid))
			{
				SendClientMessage(playerid, C_RED, "Помилка реєстрації. Спробуйте ще раз.");
				SetTimerEx("DelayedKick", 500, false, "i", playerid);
				return 1;
			}
			P[playerid][pMoney] = START_MONEY;
			P[playerid][pLevel] = 1;
			P[playerid][pQuest] = Q_PASSPORT;
			P[playerid][pLogged] = true;
			P[playerid][pSpawnAt] = 0;
			Acc_Save(playerid);
			EnterWorld(playerid);
			SendClientMessage(playerid, C_YELLOW, "Реєстрацію завершено! Ви отримали $%d на старт.", START_MONEY);
			SendClientMessage(playerid, C_YELLOW, "Виконуйте початкові завдання (/quest), щоб отримати гроші й досвід.");
			return 1;
		}
		case DLG_SPAWN:
		{
			P[playerid][pSpawnAt] = response ? listitem : 0;
			EnterWorld(playerid);
			return 1;
		}
		case DLG_MENU:
		{
			if (!response) return 1;
			switch (listitem)
			{
				case 0: ShowStats(playerid);
				case 1: Quest_Dialog(playerid);
				case 2: ShowGps(playerid);
				case 3: ShowFactionInfo(playerid);
				case 4: ShowHelp(playerid);
				case 5: CmdCar(playerid);
				case 6: SendClientMessage(playerid, C_GREY, "Щоб написати адміну, введіть /report [текст]");
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
		case DLG_HALL:
		{
			if (!response) return 1;
			if (listitem == 0)
			{
				if (P[playerid][pPassport])
				{
					SendClientMessage(playerid, C_GREY, "У вас уже є паспорт.");
					return 1;
				}
				P[playerid][pPassport] = 1;
				SendClientMessage(playerid, C_GREEN, "Вам видано паспорт громадянина. Тепер можна працювати й вступати до фракцій.");
				Acc_Save(playerid);
				Quest_Complete(playerid, Q_PASSPORT);
			}
			else ShowFactionInfo(playerid);
			return 1;
		}
		case DLG_SCHOOL:
		{
			if (!response) return 1;
			StartDrivingTest(playerid);
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
			if (!P[playerid][pLicense] && !IsLicenseFree(P[playerid][pCar]))
			{
				SendClientMessage(playerid, C_YELLOW, "Щоб керувати цим авто, потрібні права. Складіть іспит в автошколі (/gps).");
			}
			CmdCar(playerid);
			return 1;
		}
		case DLG_JOBS:
		{
			if (!response) return 1;
			if (listitem == 3) return QuitJob(playerid);
			if (!P[playerid][pPassport])
			{
				SendClientMessage(playerid, C_RED, "Без паспорта на роботу не беруть. Отримайте його в мерії (/gps).");
				return 1;
			}
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
					if (P[playerid][pLevel] < 2) return SendClientMessage(playerid, C_RED, "Далекобійником можна стати з 2 рівня.");
					if (!P[playerid][pLicense]) return SendClientMessage(playerid, C_RED, "Потрібні водійські права (автошкола).");
					P[playerid][pJob] = JOB_TRUCKER;
					SendClientMessage(playerid, C_GREEN, "Ви влаштувались далекобійником. Їдьте на базу (мітка) і введіть /work.");
					SetCP(playerid, CP_GPS, TRUCK_X, TRUCK_Y, TRUCK_Z, 3.0);
				}
				case 2:
				{
					if (!P[playerid][pLicense]) return SendClientMessage(playerid, C_RED, "Потрібні водійські права (автошкола).");
					P[playerid][pJob] = JOB_BUS;
					SendClientMessage(playerid, C_GREEN, "Ви влаштувались водієм автобуса. Їдьте в автопарк (мітка) і введіть /work.");
					SetCP(playerid, CP_GPS, BUS_X, BUS_Y, BUS_Z, 3.0);
				}
			}
			Acc_Save(playerid);
			Quest_Complete(playerid, Q_JOB);
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
		"Моя статистика\nПочаткові завдання\nGPS — навігатор\nФракції\nДопомога і команди\nВикликати своє авто\nЗв'язок з адміном",
		"Обрати", "Закрити");
	return 1;
}

stock ShowStats(playerid)
{
	new body[800], car[32];
	if (P[playerid][pCar] == 0) car = "немає";
	else
	{
		car = "є";
		for (new i = 0; i < sizeof(gDealer); i++)
		{
			if (gDealer[i][dModel] == P[playerid][pCar]) { format(car, sizeof(car), "%s", gDealer[i][dName]); break; }
		}
	}
	new pass[16], lic[16];
	if (P[playerid][pPassport]) pass = "є"; else pass = "немає";
	if (P[playerid][pLicense]) lic = "є"; else lic = "немає";
	format(body, sizeof(body),
		"{FFFFFF}Ім'я: {FFC93C}%s\n{FFFFFF}Рівень: {FFC93C}%d {AFAFAF}(досвід %d/%d)\n{FFFFFF}Готівка: {3DDC84}$%d\n{FFFFFF}Банк: {3DDC84}$%d\n\
{FFFFFF}Паспорт: {FFC93C}%s{FFFFFF}  Права: {FFC93C}%s\n{FFFFFF}Робота: {FFC93C}%s\n{FFFFFF}Фракція: {FFC93C}%s {AFAFAF}(%s)\n\
{FFFFFF}Авто: {FFC93C}%s\n{FFFFFF}Розшук: {FF5A5A}%d\n{FFFFFF}До PayDay: {FFC93C}%d хв",
		RPName(playerid), P[playerid][pLevel], P[playerid][pExp], P[playerid][pLevel] * 4,
		P[playerid][pMoney], P[playerid][pBank], pass, lic, JobName(P[playerid][pJob]),
		gFacName[P[playerid][pFaction]], RankName(playerid), car, P[playerid][pWanted],
		PAYDAY_MINUTES - (P[playerid][pMinutes] % PAYDAY_MINUTES));
	ShowPlayerDialog(playerid, DLG_STATS, DIALOG_STYLE_MSGBOX, "Статистика", body, "Закрити", "");
	return 1;
}

stock ShowGps(playerid)
{
	new body[700];
	for (new i = 0; i < sizeof(gGps); i++)
	{
		strcat(body, gGps[i][gName]);
		strcat(body, "\n");
	}
	ShowPlayerDialog(playerid, DLG_GPS, DIALOG_STYLE_LIST, "GPS — куди їхати?", body, "Поставити мітку", "Закрити");
	return 1;
}

stock ShowFactionInfo(playerid)
{
	ShowPlayerDialog(playerid, DLG_FACTION, DIALOG_STYLE_MSGBOX, "Фракції",
		"{3A7BFF}Поліція ЛС{FFFFFF} — охорона порядку: розшук, наручники, арешт.\n\
{FF7A9A}Лікарня ЛС{FFFFFF} — лікування гравців (/heal).\n\
{E0E0E0}Уряд{FFFFFF} — оголошення для міста (/gov).\n\n\
{AFAFAF}Щоб вступити, потрібен паспорт. Зверніться до лідера фракції:\n\
він приймає командою /invite. Лідерів призначає адміністрація.\n\
Зарплата фракції нараховується щогодини разом з PayDay.",
		"Закрити", "");
	return 1;
}

stock ShowHelp(playerid)
{
	ShowPlayerDialog(playerid, DLG_HELP, DIALOG_STYLE_MSGBOX, "Допомога",
		"{FFC93C}Основне:{FFFFFF} /menu /stats /quest /gps /help\n\
{FFC93C}Гроші:{FFFFFF} банк (значок), /pay [id] [сума]\n\
{FFC93C}Робота:{FFFFFF} біржа праці, /work, /quitjob\n\
{FFC93C}Авто:{FFFFFF} автосалон, автошкола, /car /lock /e\n\
{FFC93C}RP-чат:{FFFFFF} /me /do /try /b /s /pm [id] [текст]\n\
{FFC93C}Фракції:{FFFFFF} /r /members /invite /uninvite /giverank\n\
{3A7BFF}Поліція:{FFFFFF} /su /clear /cuff /uncuff /arrest /m /wanted\n\
{FF7A9A}Лікарня:{FFFFFF} /heal [id]   {E0E0E0}Уряд:{FFFFFF} /gov [текст]\n\
{FFC93C}Інше:{FFFFFF} /report [текст]\n\n\
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
		"Вантажник (з 1 рівня)\nДалекобійник (з 2 рівня, потрібні права)\nВодій автобуса (потрібні права)\nЗвільнитися з роботи",
		"Обрати", "Закрити");
	return 1;
}

stock IsLicenseFree(model)
{
	return (model == 462 || model == 509 || model == 510 || model == 481);
}

stock QuitJob(playerid)
{
	if (P[playerid][pJob] == JOB_NONE) return SendClientMessage(playerid, C_RED, "Ви ніде не працюєте.");
	P[playerid][pJob] = JOB_NONE;
	if (P[playerid][pTruck] != INVALID_VEHICLE_ID) { DestroyVehicle(P[playerid][pTruck]); P[playerid][pTruck] = INVALID_VEHICLE_ID; }
	if (P[playerid][pBus] != INVALID_VEHICLE_ID) { DestroyVehicle(P[playerid][pBus]); P[playerid][pBus] = INVALID_VEHICLE_ID; }
	if (P[playerid][pCarrying]) { P[playerid][pCarrying] = false; RemovePlayerAttachedObject(playerid, 9); SetPlayerSpecialAction(playerid, SPECIAL_ACTION_NONE); }
	ClearCP(playerid);
	Acc_Save(playerid);
	SendClientMessage(playerid, C_GREY, "Ви звільнились з роботи.");
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
//   АВТОШКОЛА
// =====================================================================

stock StartDrivingTest(playerid)
{
	if (P[playerid][pLicense]) return SendClientMessage(playerid, C_GREY, "У вас уже є права.");
	if (P[playerid][pTestVeh] != INVALID_VEHICLE_ID) return SendClientMessage(playerid, C_RED, "Ви вже складаєте іспит.");
	if (P[playerid][pMoney] < LICENSE_PRICE) return SendClientMessage(playerid, C_RED, "Іспит коштує $%d.", LICENSE_PRICE);
	GiveMoney(playerid, -LICENSE_PRICE);
	new veh = CreateVehicle(410, SCHOOL_X + 4.0, SCHOOL_Y, SCHOOL_Z + 0.5, 270.0, 1, 1, -1);
	SetVehicleNumberPlate(veh, "SCHOOL");
	P[playerid][pTestVeh] = veh;
	P[playerid][pTestStep] = 0;
	PutPlayerInVehicle(playerid, veh, 0);
	SetVehicleParamsEx(veh, 1, 1, 0, 0, 0, 0, 0);
	SetCP(playerid, CP_TEST, gTestRoute[0][0], gTestRoute[0][1], gTestRoute[0][2], 5.0);
	SendClientMessage(playerid, C_BLUE, "Іспит почався! Проїдьте всі мітки, не розбивши авто. Не виходьте з машини.");
	return 1;
}

stock FailDrivingTest(playerid, const reason[])
{
	if (P[playerid][pTestVeh] != INVALID_VEHICLE_ID)
	{
		DestroyVehicle(P[playerid][pTestVeh]);
		P[playerid][pTestVeh] = INVALID_VEHICLE_ID;
	}
	ClearCP(playerid);
	SendClientMessage(playerid, C_RED, "Іспит не складено: %s. Спробуйте ще раз в автошколі.", reason);
}

// =====================================================================
//   ТАЙМЕРИ: PayDay, в'язниця
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
		if (P[i][pJail] > 0)
		{
			P[i][pJail]--;
			if (P[i][pJail] == 0)
			{
				SetPlayerInterior(i, 0);
				SetPlayerPos(i, PD_X, PD_Y + 3.0, PD_Z);
				SendClientMessage(i, C_GREEN, "Ви відбули покарання і вийшли на волю.");
				Acc_Save(i);
			}
		}
		if (P[i][pMinutes] % PAYDAY_MINUTES == 0) PayDay(i);
		Hud_Update(i);
	}
	return 1;
}

stock PayDay(playerid)
{
	new salary = PAYDAY_BASE + P[playerid][pLevel] * PAYDAY_PER_LVL;
	new facPay = 0;
	if (P[playerid][pFaction] > FAC_NONE && P[playerid][pRank] > 0) facPay = 800 + P[playerid][pRank] * 200;
	new base = P[playerid][pBank];
	if (base > 100000) base = 100000;
	new interest = base * BANK_INTEREST / 100;
	P[playerid][pBank] += salary + facPay + interest;
	P[playerid][pExp]++;
	SendClientMessage(playerid, C_YELLOW, "========== PayDay ==========");
	SendClientMessage(playerid, C_WHITE, "Допомога: $%d | Зарплата фракції: $%d | Відсотки: $%d", salary, facPay, interest);
	SendClientMessage(playerid, C_WHITE, "На рахунку: $%d", P[playerid][pBank]);
	CheckLevelUp(playerid);
	Acc_Save(playerid);
}

// =====================================================================
//   ПІКАПИ ТА ЧЕКПОІНТИ
// =====================================================================

public OnPlayerPickUpPickup(playerid, pickupid)
{
	if (!P[playerid][pLogged]) return 1;
	new now = GetTickCount();
	if (now - P[playerid][pPickupTick] < 4000) return 1;
	P[playerid][pPickupTick] = now;

	if (pickupid == gPickHall)
	{
		ShowPlayerDialog(playerid, DLG_HALL, DIALOG_STYLE_LIST, "Мерія Лос-Сантоса",
			"Отримати паспорт (безкоштовно)\nІнформація про фракції", "Обрати", "Закрити");
	}
	else if (pickupid == gPickBank) ShowBank(playerid);
	else if (pickupid == gPickJobs) ShowJobs(playerid);
	else if (pickupid == gPickDealer) ShowDealer(playerid);
	else if (pickupid == gPickSchool)
	{
		if (P[playerid][pLicense]) return SendClientMessage(playerid, C_GREY, "У вас уже є водійські права.");
		new body[200];
		format(body, sizeof(body), "{FFFFFF}Практичний іспит з водіння.\nВартість: {3DDC84}$%d\n\n{AFAFAF}Проїдьте маршрут, не розбивши авто.", LICENSE_PRICE);
		ShowPlayerDialog(playerid, DLG_SCHOOL, DIALOG_STYLE_MSGBOX, "Автошкола", body, "Почати", "Скасувати");
	}
	else if (pickupid == gPickLoadTake)
	{
		if (P[playerid][pJob] != JOB_LOADER)
		{
			SendClientMessage(playerid, C_GREY, "Це склад. Влаштуйтесь вантажником на біржі праці.");
			return 1;
		}
		if (P[playerid][pCarrying] || IsPlayerInAnyVehicle(playerid)) return 1;
		P[playerid][pCarrying] = true;
		SetPlayerAttachedObject(playerid, 9, 1271, 1, 0.002953, 0.469660, -0.009797, 269.851104, 34.443557, 0.0, 0.804894, 1.0, 0.822361);
		SetPlayerSpecialAction(playerid, SPECIAL_ACTION_CARRY);
		SetCP(playerid, CP_LOADER, LOAD_DROP_X, LOAD_DROP_Y, LOAD_DROP_Z, 2.0);
		SendClientMessage(playerid, C_BLUE, "Ви взяли ящик. Віднесіть його до мітки.");
	}
	else if (pickupid == gPickTruck)
	{
		if (P[playerid][pJob] == JOB_TRUCKER) SendClientMessage(playerid, C_BLUE, "Введіть /work, щоб узяти вантажівку і почати рейс.");
		else SendClientMessage(playerid, C_GREY, "База далекобійників. Робота — на біржі праці.");
	}
	else if (pickupid == gPickBus)
	{
		if (P[playerid][pJob] == JOB_BUS) SendClientMessage(playerid, C_BLUE, "Введіть /work, щоб узяти автобус і почати маршрут.");
		else SendClientMessage(playerid, C_GREY, "Автобусний парк. Робота — на біржі праці.");
	}
	else if (pickupid == gPickPD)
	{
		SendClientMessage(playerid, C_POLICE, "Поліція Лос-Сантоса. Співробітники: /members. Арештованих доставляють сюди (/arrest).");
	}
	else if (pickupid == gPickHosp)
	{
		new Float:hp;
		GetPlayerHealth(playerid, hp);
		if (hp < 100.0)
		{
			if (P[playerid][pMoney] < 200) return SendClientMessage(playerid, C_RED, "Лікування коштує $200.");
			GiveMoney(playerid, -200);
			SetPlayerHealth(playerid, 100.0);
			SendClientMessage(playerid, C_MEDIC, "Вас вилікували за $200.");
		}
		else SendClientMessage(playerid, C_MEDIC, "Лікарня Лос-Сантоса. Ви здорові.");
	}
	return 1;
}

stock NextTruckPoint(playerid)
{
	new i = random(sizeof(gTruckDest));
	SetCP(playerid, CP_TRUCK, gTruckDest[i][0], gTruckDest[i][1], gTruckDest[i][2], 6.0);
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
			SetCP(playerid, CP_GPS, LOAD_TAKE_X, LOAD_TAKE_Y, LOAD_TAKE_Z, 2.0);
			SendClientMessage(playerid, C_GREEN, "+$%d. Поверніться на склад за новим ящиком.", LOADER_PAY);
			AddJobEarnings(playerid, LOADER_PAY);
		}
		case CP_TRUCK:
		{
			new veh = GetPlayerVehicleID(playerid);
			if (veh == 0 || veh != P[playerid][pTruck]) return SendClientMessage(playerid, C_RED, "Потрібно приїхати на своїй вантажівці.");
			new pay = 600 + random(300) + P[playerid][pLevel] * 20;
			SendClientMessage(playerid, C_GREEN, "Вантаж доставлено! +$%d. Наступна точка — на карті. Завершити: /work", pay);
			NextTruckPoint(playerid);
			AddJobEarnings(playerid, pay);
		}
		case CP_BUS:
		{
			new veh = GetPlayerVehicleID(playerid);
			if (veh == 0 || veh != P[playerid][pBus]) return SendClientMessage(playerid, C_RED, "Потрібно приїхати на своєму автобусі.");
			P[playerid][pBusStop]++;
			if (P[playerid][pBusStop] >= sizeof(gBusRoute)) P[playerid][pBusStop] = 0;
			new st = P[playerid][pBusStop];
			SetCP(playerid, CP_BUS, gBusRoute[st][0], gBusRoute[st][1], gBusRoute[st][2], 5.0);
			GameTextForPlayer(playerid, "~g~+$120", 1500, 1);
			AddJobEarnings(playerid, BUS_PAY);
		}
		case CP_TEST:
		{
			new veh = GetPlayerVehicleID(playerid);
			if (veh == 0 || veh != P[playerid][pTestVeh]) return 1;
			P[playerid][pTestStep]++;
			if (P[playerid][pTestStep] >= sizeof(gTestRoute))
			{
				new Float:hp;
				GetVehicleHealth(veh, hp);
				if (hp < 700.0)
				{
					FailDrivingTest(playerid, "авто сильно пошкоджене");
					return 1;
				}
				ClearCP(playerid);
				P[playerid][pTestVeh] = INVALID_VEHICLE_ID;
				DestroyVehicle(veh);
				P[playerid][pLicense] = 1;
				SetPlayerPos(playerid, SCHOOL_X, SCHOOL_Y + 2.0, SCHOOL_Z);
				SendClientMessage(playerid, C_GREEN, "Вітаємо! Ви склали іспит і отримали водійські права.");
				Acc_Save(playerid);
				Quest_Complete(playerid, Q_LICENSE);
				return 1;
			}
			new st = P[playerid][pTestStep];
			SetCP(playerid, CP_TEST, gTestRoute[st][0], gTestRoute[st][1], gTestRoute[st][2], 5.0);
		}
	}
	return 1;
}

public OnPlayerStateChange(playerid, PLAYER_STATE:newstate, PLAYER_STATE:oldstate)
{
	// Вихід з авто під час іспиту — провал
	if (oldstate == PLAYER_STATE_DRIVER && P[playerid][pTestVeh] != INVALID_VEHICLE_ID && P[playerid][pCP] == CP_TEST)
	{
		FailDrivingTest(playerid, "ви вийшли з авто");
		return 1;
	}
	if (newstate == PLAYER_STATE_DRIVER)
	{
		new veh = GetPlayerVehicleID(playerid);
		new model = GetVehicleModel(veh);
		new engine, lights, alarm, doors, bonnet, boot, objective;

		// Чужі зачинені авто
		for (new i = 0; i < MAX_PLAYERS; i++)
		{
			if (i != playerid && IsPlayerConnected(i) && P[i][pCarVeh] == veh)
			{
				GetVehicleParamsEx(veh, engine, lights, alarm, doors, bonnet, boot, objective);
				if (doors == 1)
				{
					RemovePlayerFromVehicle(playerid);
					SendClientMessage(playerid, C_RED, "Це авто зачинене.");
					return 1;
				}
			}
		}
		// Службовий транспорт фракцій
		if ((model == 596 && P[playerid][pFaction] != FAC_POLICE) || (model == 416 && P[playerid][pFaction] != FAC_MEDIC))
		{
			RemovePlayerFromVehicle(playerid);
			SendClientMessage(playerid, C_RED, "Це службовий транспорт фракції.");
			return 1;
		}
		// Права
		if (!P[playerid][pLicense] && !IsLicenseFree(model) && veh != P[playerid][pTestVeh])
		{
			RemovePlayerFromVehicle(playerid);
			SendClientMessage(playerid, C_RED, "У вас немає водійських прав. Складіть іспит в автошколі (/gps).");
			return 1;
		}
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
		if (P[i][pBus] == vehicleid)
		{
			P[i][pBus] = INVALID_VEHICLE_ID;
			ClearCP(i);
			SendClientMessage(i, C_RED, "Ваш автобус знищено. Маршрут скасовано.");
		}
		if (P[i][pTestVeh] == vehicleid)
		{
			FailDrivingTest(i, "авто знищено");
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

stock Cmd_Police(playerid, const cmd[], const cmdtext[], idx)
{
	new tmp[64], msg[180];
	if (P[playerid][pFaction] != FAC_POLICE) return SendClientMessage(playerid, C_RED, "Команда доступна лише поліції.");

	if (!strcmp(cmd, "/wanted", true))
	{
		SendClientMessage(playerid, C_POLICE, "Список розшукуваних:");
		new cnt = 0;
		for (new i = 0; i < MAX_PLAYERS; i++)
		{
			if (IsValidTarget(i) && P[i][pWanted] > 0)
			{
				SendClientMessage(playerid, C_WHITE, "  [%d] %s — рівень %d", i, PlayerName(i), P[i][pWanted]);
				cnt++;
			}
		}
		if (cnt == 0) SendClientMessage(playerid, C_GREY, "  Нікого немає.");
		return 1;
	}
	if (!strcmp(cmd, "/m", true))
	{
		new text[144]; text = strrest(cmdtext, idx);
		if (!text[0]) return SendClientMessage(playerid, C_GREY, "Використання: /m [текст] — мегафон");
		format(msg, sizeof(msg), "[Мегафон] %s: %s", RPName(playerid), text);
		LocalMessage(playerid, 60.0, C_YELLOW, msg);
		return 1;
	}

	tmp = strtok(cmdtext, idx);
	if (!IsNumeric(tmp)) return SendClientMessage(playerid, C_GREY, "Вкажіть id гравця.");
	new id = strval(tmp);
	if (!IsValidTarget(id) || id == playerid) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");

	if (!strcmp(cmd, "/su", true))
	{
		new tmp2[64]; tmp2 = strtok(cmdtext, idx);
		new text[144]; text = strrest(cmdtext, idx);
		if (!IsNumeric(tmp2) || !text[0]) return SendClientMessage(playerid, C_GREY, "Використання: /su [id] [рівень 1-6] [причина]");
		new lvl = strval(tmp2);
		if (lvl < 1 || lvl > 6) return SendClientMessage(playerid, C_RED, "Рівень від 1 до 6.");
		P[id][pWanted] = lvl;
		SetPlayerWantedLevel(id, lvl);
		Hud_Update(id);
		Acc_Save(id);
		SendClientMessage(id, C_RED, "Вас оголошено в розшук (рівень %d). Причина: %s", lvl, text);
		format(msg, sizeof(msg), "[Диспетчер] %s оголосив у розшук %s (рівень %d): %s", RPName(playerid), PlayerName(id), lvl, text);
		FactionMessage(FAC_POLICE, C_POLICE, msg);
		return 1;
	}
	if (!strcmp(cmd, "/clear", true))
	{
		P[id][pWanted] = 0;
		SetPlayerWantedLevel(id, 0);
		Hud_Update(id);
		Acc_Save(id);
		SendClientMessage(id, C_GREEN, "З вас знято розшук.");
		SendClientMessage(playerid, C_POLICE, "Розшук з %s знято.", PlayerName(id));
		return 1;
	}
	if (!IsNear(playerid, id, 3.0)) return SendClientMessage(playerid, C_RED, "Гравець має бути поруч.");
	if (!strcmp(cmd, "/cuff", true))
	{
		if (IsPlayerInAnyVehicle(id)) return SendClientMessage(playerid, C_RED, "Спершу витягніть гравця з авто.");
		P[id][pCuffed] = true;
		TogglePlayerControllable(id, false);
		SetPlayerSpecialAction(id, SPECIAL_ACTION_CUFFED);
		format(msg, sizeof(msg), "%s одягає наручники на %s", RPName(playerid), RPName(id));
		LocalMessage(playerid, 15.0, C_PURPLE, msg);
		return 1;
	}
	if (!strcmp(cmd, "/uncuff", true))
	{
		P[id][pCuffed] = false;
		TogglePlayerControllable(id, true);
		SetPlayerSpecialAction(id, SPECIAL_ACTION_NONE);
		format(msg, sizeof(msg), "%s знімає наручники з %s", RPName(playerid), RPName(id));
		LocalMessage(playerid, 15.0, C_PURPLE, msg);
		return 1;
	}
	if (!strcmp(cmd, "/arrest", true))
	{
		if (!IsPlayerInRangeOfPoint(playerid, 15.0, PD_X, PD_Y, PD_Z)) return SendClientMessage(playerid, C_RED, "Арештувати можна лише біля відділку поліції (/gps).");
		if (P[id][pWanted] == 0) return SendClientMessage(playerid, C_RED, "Гравець не в розшуку.");
		new minutes = P[id][pWanted] * 5;
		P[id][pJail] = minutes;
		P[id][pWanted] = 0;
		P[id][pCuffed] = false;
		SetPlayerWantedLevel(id, 0);
		TogglePlayerControllable(id, true);
		SetPlayerSpecialAction(id, SPECIAL_ACTION_NONE);
		ResetPlayerWeapons(id);
		SetPlayerInterior(id, JAIL_INT);
		SetPlayerPos(id, JAIL_X, JAIL_Y, JAIL_Z);
		Hud_Update(id);
		Acc_Save(id);
		GiveMoney(playerid, 300);
		SendClientMessage(id, C_RED, "Вас заарештовано на %d хв.", minutes);
		SendClientMessage(playerid, C_POLICE, "Ви заарештували %s на %d хв. Премія: $300.", PlayerName(id), minutes);
		SendClientMessageToAll(C_POLICE, "[Новини] Поліція заарештувала %s.", RPName(id));
		return 1;
	}
	return 1;
}

stock Cmd_Admin(playerid, const cmd[], const cmdtext[], idx)
{
	new tmp[64], msg[180];
	if (!strcmp(cmd, "/ahelp", true))
	{
		SendClientMessage(playerid, C_YELLOW, "Адмін-команди:");
		SendClientMessage(playerid, C_WHITE, "1: /goto [id] /gethere [id] /kick [id] [причина] /mute [id] [хв] /a [текст]");
		SendClientMessage(playerid, C_WHITE, "3: /veh [модель] /dv /unjail [id]  |  4: /setmoney [id] [сума] /ban [id] /setleader [id] [0-3]");
		SendClientMessage(playerid, C_WHITE, "5: /makeadmin [id] [рівень]");
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
		if (!IsValidTarget(id)) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
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
		if (!IsValidTarget(id)) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
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
	if (P[playerid][pAdmin] >= 3 && !strcmp(cmd, "/unjail", true))
	{
		tmp = strtok(cmdtext, idx);
		if (!IsNumeric(tmp)) return SendClientMessage(playerid, C_GREY, "Використання: /unjail [id]");
		new id = strval(tmp);
		if (!IsValidTarget(id)) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
		P[id][pJail] = 0;
		SetPlayerInterior(id, 0);
		SetPlayerPos(id, PD_X, PD_Y + 3.0, PD_Z);
		Hud_Update(id);
		Acc_Save(id);
		SendClientMessage(id, C_GREEN, "Адміністратор звільнив вас з в'язниці.");
		return 1;
	}
	if (P[playerid][pAdmin] >= 4 && !strcmp(cmd, "/setmoney", true))
	{
		tmp = strtok(cmdtext, idx);
		new tmp2[64]; tmp2 = strtok(cmdtext, idx);
		if (!IsNumeric(tmp) || !IsNumeric(tmp2)) return SendClientMessage(playerid, C_GREY, "Використання: /setmoney [id] [сума]");
		new id = strval(tmp);
		if (!IsValidTarget(id)) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
		SetMoney(id, strval(tmp2));
		Acc_Save(id);
		SendClientMessage(playerid, C_YELLOW, "Готівку %s встановлено: $%d", PlayerName(id), strval(tmp2));
		return 1;
	}
	if (P[playerid][pAdmin] >= 4 && !strcmp(cmd, "/setleader", true))
	{
		tmp = strtok(cmdtext, idx);
		new tmp2[64]; tmp2 = strtok(cmdtext, idx);
		if (!IsNumeric(tmp) || !IsNumeric(tmp2)) return SendClientMessage(playerid, C_GREY, "Використання: /setleader [id] [1 поліція / 2 лікарня / 3 уряд / 0 зняти]");
		new id = strval(tmp), f = strval(tmp2);
		if (!IsValidTarget(id) || f < 0 || f >= MAX_FAC) return SendClientMessage(playerid, C_RED, "Неправильний id або фракція.");
		P[id][pFaction] = f;
		if (f == FAC_NONE) P[id][pRank] = 0;
		else
		{
			P[id][pRank] = MAX_RANK;
			P[id][pPassport] = 1;
		}
		ApplyFactionLook(id);
		Acc_Save(id);
		if (f == FAC_NONE) SendClientMessage(id, C_YELLOW, "Вас знято з посади лідера фракції.");
		else SendClientMessage(id, gFacColor[f], "Вас призначено лідером фракції «%s». Приймайте людей: /invite", gFacName[f]);
		SendClientMessage(playerid, C_YELLOW, "Готово.");
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
	return 0;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!P[playerid][pLogged]) return 1;
	new idx = 0, cmd[64], tmp[64], msg[180];
	cmd = strtok(cmdtext, idx);

	// В'язниця і наручники обмежують команди
	if (P[playerid][pJail] > 0 || P[playerid][pCuffed])
	{
		if (strcmp(cmd, "/me", true) && strcmp(cmd, "/do", true) && strcmp(cmd, "/b", true) && strcmp(cmd, "/stats", true) && strcmp(cmd, "/report", true))
		{
			SendClientMessage(playerid, C_RED, "Зараз вам доступні лише /me /do /b /stats /report.");
			return 1;
		}
	}

	// ---------------------------- основні
	if (!strcmp(cmd, "/menu", true) || !strcmp(cmd, "/mm", true)) return ShowMenu(playerid);
	if (!strcmp(cmd, "/help", true)) return ShowHelp(playerid);
	if (!strcmp(cmd, "/stats", true)) return ShowStats(playerid);
	if (!strcmp(cmd, "/gps", true)) return ShowGps(playerid);
	if (!strcmp(cmd, "/quest", true) || !strcmp(cmd, "/quests", true)) return Quest_Dialog(playerid);

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
		if (!IsValidTarget(id)) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
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
		if (id == playerid || !IsValidTarget(id)) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
		if (!IsNear(playerid, id, 5.0)) return SendClientMessage(playerid, C_RED, "Гравець має бути поруч.");
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
		if (P[playerid][pJob] == JOB_TRUCKER)
		{
			if (P[playerid][pTruck] != INVALID_VEHICLE_ID)
			{
				DestroyVehicle(P[playerid][pTruck]);
				P[playerid][pTruck] = INVALID_VEHICLE_ID;
				ClearCP(playerid);
				return SendClientMessage(playerid, C_GREY, "Зміну завершено, вантажівку повернуто на базу.");
			}
			if (!IsPlayerInRangeOfPoint(playerid, 8.0, TRUCK_X, TRUCK_Y, TRUCK_Z)) return SendClientMessage(playerid, C_RED, "Почати рейс можна лише на базі далекобійників (/gps).");
			new veh = CreateVehicle(499, TRUCK_X + 6.0, TRUCK_Y, TRUCK_Z + 0.5, 90.0, 1, 1, -1);
			P[playerid][pTruck] = veh;
			SetVehicleNumberPlate(veh, "UA-CARGO");
			PutPlayerInVehicle(playerid, veh, 0);
			SetVehicleParamsEx(veh, 1, 1, 0, 0, 0, 0, 0);
			NextTruckPoint(playerid);
			return SendClientMessage(playerid, C_GREEN, "Вантажівку видано. Доставте вантаж до мітки на карті.");
		}
		if (P[playerid][pJob] == JOB_BUS)
		{
			if (P[playerid][pBus] != INVALID_VEHICLE_ID)
			{
				DestroyVehicle(P[playerid][pBus]);
				P[playerid][pBus] = INVALID_VEHICLE_ID;
				ClearCP(playerid);
				return SendClientMessage(playerid, C_GREY, "Зміну завершено, автобус повернуто в парк.");
			}
			if (!IsPlayerInRangeOfPoint(playerid, 8.0, BUS_X, BUS_Y, BUS_Z)) return SendClientMessage(playerid, C_RED, "Почати маршрут можна лише в автобусному парку (/gps).");
			new veh = CreateVehicle(431, BUS_X + 6.0, BUS_Y, BUS_Z + 0.5, 0.0, 1, 3, -1);
			P[playerid][pBus] = veh;
			P[playerid][pBusStop] = 0;
			SetVehicleNumberPlate(veh, "UA-BUS");
			PutPlayerInVehicle(playerid, veh, 0);
			SetVehicleParamsEx(veh, 1, 1, 0, 0, 0, 0, 0);
			SetCP(playerid, CP_BUS, gBusRoute[0][0], gBusRoute[0][1], gBusRoute[0][2], 5.0);
			return SendClientMessage(playerid, C_GREEN, "Автобус видано. Їдьте зупинками (мітки на карті), $%d за кожну.", BUS_PAY);
		}
		return SendClientMessage(playerid, C_RED, "Команда для далекобійників і водіїв автобуса.");
	}
	if (!strcmp(cmd, "/quitjob", true)) return QuitJob(playerid);

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

	// ---------------------------- фракції: загальні
	new fac = P[playerid][pFaction];
	if (!strcmp(cmd, "/r", true))
	{
		if (fac == FAC_NONE) return SendClientMessage(playerid, C_RED, "Ви не перебуваєте у фракції.");
		new text[144]; text = strrest(cmdtext, idx);
		if (!text[0]) return SendClientMessage(playerid, C_GREY, "Використання: /r [текст] — рація фракції");
		format(msg, sizeof(msg), "[Рація] %s %s: %s", RankName(playerid), RPName(playerid), text);
		FactionMessage(fac, gFacColor[fac], msg);
		return 1;
	}
	if (!strcmp(cmd, "/members", true))
	{
		if (fac == FAC_NONE) return SendClientMessage(playerid, C_RED, "Ви не перебуваєте у фракції.");
		SendClientMessage(playerid, gFacColor[fac], "Співробітники онлайн — %s:", gFacName[fac]);
		for (new i = 0; i < MAX_PLAYERS; i++)
		{
			if (IsValidTarget(i) && P[i][pFaction] == fac)
			{
				SendClientMessage(playerid, C_WHITE, "  [%d] %s — %s", i, RPName(i), RankName(i));
			}
		}
		return 1;
	}
	if (!strcmp(cmd, "/invite", true))
	{
		if (fac == FAC_NONE || P[playerid][pRank] < 5) return SendClientMessage(playerid, C_RED, "Приймати можуть лише ранги 5-6.");
		tmp = strtok(cmdtext, idx);
		if (!IsNumeric(tmp)) return SendClientMessage(playerid, C_GREY, "Використання: /invite [id]");
		new id = strval(tmp);
		if (!IsValidTarget(id) || id == playerid) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
		if (P[id][pFaction] != FAC_NONE) return SendClientMessage(playerid, C_RED, "Гравець уже у фракції.");
		if (!P[id][pPassport]) return SendClientMessage(playerid, C_RED, "У гравця немає паспорта.");
		if (!IsNear(playerid, id, 5.0)) return SendClientMessage(playerid, C_RED, "Гравець має бути поруч.");
		P[id][pFaction] = fac;
		P[id][pRank] = 1;
		ApplyFactionLook(id);
		Acc_Save(id);
		SendClientMessage(id, gFacColor[fac], "Вас прийнято до фракції «%s» на ранг «%s». Рація: /r", gFacName[fac], RankName(id));
		format(msg, sizeof(msg), "[Фракція] %s прийняв до складу %s.", RPName(playerid), RPName(id));
		FactionMessage(fac, gFacColor[fac], msg);
		return 1;
	}
	if (!strcmp(cmd, "/uninvite", true))
	{
		if (fac == FAC_NONE || P[playerid][pRank] < 5) return SendClientMessage(playerid, C_RED, "Звільняти можуть лише ранги 5-6.");
		tmp = strtok(cmdtext, idx);
		if (!IsNumeric(tmp)) return SendClientMessage(playerid, C_GREY, "Використання: /uninvite [id]");
		new id = strval(tmp);
		if (!IsValidTarget(id) || id == playerid || P[id][pFaction] != fac) return SendClientMessage(playerid, C_RED, "Гравець не у вашій фракції.");
		if (P[id][pRank] >= P[playerid][pRank]) return SendClientMessage(playerid, C_RED, "Не можна звільнити рівного або старшого за рангом.");
		P[id][pFaction] = FAC_NONE;
		P[id][pRank] = 0;
		ApplyFactionLook(id);
		ResetPlayerWeapons(id);
		Acc_Save(id);
		SendClientMessage(id, C_RED, "Вас звільнено з фракції «%s».", gFacName[fac]);
		format(msg, sizeof(msg), "[Фракція] %s звільнив %s.", RPName(playerid), RPName(id));
		FactionMessage(fac, gFacColor[fac], msg);
		return 1;
	}
	if (!strcmp(cmd, "/giverank", true))
	{
		if (fac == FAC_NONE || P[playerid][pRank] < 5) return SendClientMessage(playerid, C_RED, "Змінювати ранги можуть лише ранги 5-6.");
		tmp = strtok(cmdtext, idx);
		new tmp2[64]; tmp2 = strtok(cmdtext, idx);
		if (!IsNumeric(tmp) || !IsNumeric(tmp2)) return SendClientMessage(playerid, C_GREY, "Використання: /giverank [id] [ранг]");
		new id = strval(tmp), rank = strval(tmp2);
		if (!IsValidTarget(id) || id == playerid || P[id][pFaction] != fac) return SendClientMessage(playerid, C_RED, "Гравець не у вашій фракції.");
		if (rank < 1 || rank >= P[playerid][pRank]) return SendClientMessage(playerid, C_RED, "Ранг має бути від 1 до %d.", P[playerid][pRank] - 1);
		P[id][pRank] = rank;
		ApplyFactionLook(id);
		Acc_Save(id);
		SendClientMessage(id, gFacColor[fac], "Ваш новий ранг: %s.", RankName(id));
		SendClientMessage(playerid, gFacColor[fac], "Ранг %s змінено на «%s».", RPName(id), RankName(id));
		return 1;
	}

	// ---------------------------- поліція
	if (!strcmp(cmd, "/su", true) || !strcmp(cmd, "/clear", true) || !strcmp(cmd, "/cuff", true) || !strcmp(cmd, "/uncuff", true)
		|| !strcmp(cmd, "/arrest", true) || !strcmp(cmd, "/m", true) || !strcmp(cmd, "/wanted", true))
	{
		return Cmd_Police(playerid, cmd, cmdtext, idx);
	}

	// ---------------------------- лікарня
	if (!strcmp(cmd, "/heal", true))
	{
		if (fac != FAC_MEDIC) return SendClientMessage(playerid, C_RED, "Команда доступна лише лікарям.");
		tmp = strtok(cmdtext, idx);
		if (!IsNumeric(tmp)) return SendClientMessage(playerid, C_GREY, "Використання: /heal [id]");
		new id = strval(tmp);
		if (!IsValidTarget(id)) return SendClientMessage(playerid, C_RED, "Гравця не знайдено.");
		if (id != playerid && !IsNear(playerid, id, 4.0)) return SendClientMessage(playerid, C_RED, "Пацієнт має бути поруч.");
		new Float:hp;
		GetPlayerHealth(id, hp);
		if (hp >= 100.0) return SendClientMessage(playerid, C_GREY, "Пацієнт здоровий.");
		SetPlayerHealth(id, 100.0);
		format(msg, sizeof(msg), "%s надає медичну допомогу %s", RPName(playerid), RPName(id));
		LocalMessage(playerid, 15.0, C_PURPLE, msg);
		if (id != playerid)
		{
			GiveMoney(playerid, 150);
			SendClientMessage(playerid, C_MEDIC, "Пацієнта вилікувано. Місто заплатило вам $150.");
		}
		return 1;
	}

	// ---------------------------- уряд
	if (!strcmp(cmd, "/gov", true))
	{
		if (fac != FAC_GOV || P[playerid][pRank] < 4) return SendClientMessage(playerid, C_RED, "Державні оголошення роблять ранги 4-6 уряду.");
		new text[144]; text = strrest(cmdtext, idx);
		if (!text[0]) return SendClientMessage(playerid, C_GREY, "Використання: /gov [текст]");
		SendClientMessageToAll(C_GOV, "========== Державні новини ==========");
		SendClientMessageToAll(C_GOV, "%s %s: %s", RankName(playerid), RPName(playerid), text);
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
		if (!IsValidTarget(id) || lvl < 0 || lvl > 5) return SendClientMessage(playerid, C_RED, "Неправильний id або рівень.");
		P[id][pAdmin] = lvl;
		Acc_Save(id);
		SendClientMessage(id, C_YELLOW, "Вам видано адмінку %d рівня. Команди: /ahelp", lvl);
		SendClientMessage(playerid, C_YELLOW, "Гравцю %s видано адмінку %d рівня.", PlayerName(id), lvl);
		return 1;
	}
	if (P[playerid][pAdmin] > 0)
	{
		if (Cmd_Admin(playerid, cmd, cmdtext, idx)) return 1;
	}

	SendClientMessage(playerid, C_GREY, "Невідома команда. Список команд: /help");
	return 1;
}

public OnRconLoginAttempt(ip[], password[], success)
{
	return 1;
}
