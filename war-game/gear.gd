extends RefCounted
## Каталог спорядження і економіка. Спільний для сервера і клієнта.

const START_MONEY := 4000
## Тестовий режим: гроші не закінчуються.
const UNLIMITED_MONEY := true
const UNLIMITED_AMOUNT := 9999999
const FPV_PRICE := 400
const FPV_WEIGHT := 1.5
const MAG_WEIGHT := 0.5

## Ручна осколкова граната (Ф-1 / РГД-5).
const GRENADE_PRICE := 150
const GRENADE_WEIGHT := 0.6
const GRENADE_RANGE := 35.0
const GRENADE_FUSE := 3.2
const GRENADE_RADIUS := 7.0
const GRENADE_DMG := 150.0

## Військова аптечка: лікування за 3 секунди.
const MEDKIT_PRICE := 200
const MEDKIT_WEIGHT := 0.5
const MEDKIT_HEAL := 60
const MEDKIT_TIME := 3.0

const REWARD_KILL := 150
const REWARD_HEADSHOT := 50
const REWARD_DRONE_KILL := 200
const REWARD_DRONE_SHOTDOWN := 100
const REWARD_CAPTURE_TICK := 5
const REWARD_WIN := 500
const REWARD_LOSS := 200

const WEAPONS := {
	"aks74u": {"name": "АКС-74У", "price": 0, "dmg": 22, "rof": 0.09, "mag": 30, "spread": 0.02, "reload": 2.0, "weight": 2.7, "mag_price": 40, "len": 0.55, "zoom": 60.0},
	"ak74": {"name": "АК-74", "price": 2500, "dmg": 27, "rof": 0.1, "mag": 30, "spread": 0.011, "reload": 2.3, "weight": 3.6, "mag_price": 50, "len": 0.78, "zoom": 55.0},
	"m4": {"name": "М4А1", "price": 4000, "dmg": 25, "rof": 0.075, "mag": 30, "spread": 0.008, "reload": 2.1, "weight": 3.4, "mag_price": 60, "len": 0.72, "zoom": 50.0},
	"pkm": {"name": "ПКМ (кулемет)", "price": 7000, "dmg": 30, "rof": 0.085, "mag": 100, "spread": 0.022, "reload": 5.0, "weight": 8.5, "mag_price": 180, "len": 0.95, "zoom": 55.0},
	"svd": {"name": "СВД (снайперська)", "price": 6000, "dmg": 85, "rof": 0.45, "mag": 10, "spread": 0.002, "reload": 2.6, "weight": 4.3, "mag_price": 90, "len": 1.1, "zoom": 18.0},
}
const WEAPON_ORDER := ["aks74u", "ak74", "m4", "svd", "pkm"]

const ARMOR := {
	"none": {"name": "Без броні", "price": 0, "reduce": 0.0, "weight": 0.0},
	"a2": {"name": "Бронежилет, 2 клас", "price": 1500, "reduce": 0.2, "weight": 4.0},
	"a4": {"name": "Бронежилет, 4 клас", "price": 3500, "reduce": 0.35, "weight": 8.0},
	"a5": {"name": "Бронежилет, 5 клас", "price": 6000, "reduce": 0.45, "weight": 12.0},
}
const ARMOR_ORDER := ["none", "a2", "a4", "a5"]

const HELMET := {
	"none": {"name": "Без шолома", "price": 0, "reduce": 0.0, "weight": 0.0},
	"h1": {"name": "Балістичний шолом", "price": 1200, "reduce": 0.5, "weight": 1.4},
}
const HELMET_ORDER := ["none", "h1"]

const RIG := {
	"none": {"name": "Без розгрузки", "price": 0, "mags": 2, "weight": 0.0},
	"light": {"name": "Легка розгрузка", "price": 800, "mags": 4, "weight": 1.0},
	"assault": {"name": "Штурмова розгрузка", "price": 2000, "mags": 6, "weight": 2.0},
}
const RIG_ORDER := ["none", "light", "assault"]

const PACK := {
	"none": {"name": "Без рюкзака", "price": 0, "drones": 1, "mags": 0, "heavy": 1, "weight": 0.0},
	"s": {"name": "Малий рюкзак", "price": 600, "drones": 1, "mags": 1, "heavy": 2, "weight": 0.8},
	"m": {"name": "Середній рюкзак", "price": 1500, "drones": 2, "mags": 2, "heavy": 3, "weight": 1.5},
	"l": {"name": "Великий рейдовий рюкзак", "price": 3000, "drones": 4, "mags": 3, "heavy": 5, "weight": 2.5},
}

## Важке озброєння: гранатомет або міномет. Боєприпаси (постріли/міни) носяться в рюкзаку.
const HEAVY := {
	"none": {"name": "Без важкої зброї", "price": 0, "weight": 0.0, "ammo_name": "", "ammo_price": 0, "ammo_weight": 0.0},
	"rpg": {"name": "РПГ-7 (гранатомет)", "price": 5000, "weight": 6.3, "ammo_name": "постріл ПГ-7", "ammo_price": 300, "ammo_weight": 2.0, "dmg": 220, "radius": 5.0, "speed": 115.0},
	"mortar": {"name": "82-мм міномет", "price": 9000, "weight": 14.0, "ammo_name": "міна 82 мм", "ammo_price": 250, "ammo_weight": 3.1, "dmg": 180, "radius": 12.0, "min_range": 60.0, "max_range": 450.0},
}
const HEAVY_ORDER := ["none", "rpg", "mortar"]
const PACK_ORDER := ["none", "s", "m", "l"]


static func catalog(cat: String) -> Dictionary:
	match cat:
		"w": return WEAPONS
		"a": return ARMOR
		"h": return HELMET
		"r": return RIG
		"p": return PACK
		"x": return HEAVY
	return {}


static func new_profile() -> Dictionary:
	return {
		"money": UNLIMITED_AMOUNT if UNLIMITED_MONEY else START_MONEY,
		"owned": ["w:aks74u", "a:none", "h:none", "r:none", "p:none", "x:none", "a:a2", "p:s"],
		"eq": {"w": "aks74u", "a": "a2", "h": "none", "r": "none", "p": "s", "x": "none"},
		"kit3": true,
		"fpv": 1,
		"gren": 2,
		"med": 2,
		"mags": {"aks74u": 6},
		"heavy_ammo": {"rpg": 0, "mortar": 0},
	}


static func fix_profile(p: Dictionary) -> Dictionary:
	var d := new_profile()
	for k in d:
		if not p.has(k):
			p[k] = d[k]
	# стартовий набір для старих профілів: мінімальна броня і малий рюкзак
	if not p.has("kit3"):
		p["kit3"] = true
		for tag in ["a:a2", "p:s"]:
			if not p.owned.has(tag):
				p.owned.append(tag)
		if p.eq.get("a", "none") == "none":
			p.eq["a"] = "a2"
		if p.eq.get("p", "none") == "none":
			p.eq["p"] = "s"
	if UNLIMITED_MONEY:
		p["money"] = UNLIMITED_AMOUNT
	if not p.has("heavy_ammo") or typeof(p.heavy_ammo) != TYPE_DICTIONARY:
		p.heavy_ammo = {"rpg": 0, "mortar": 0}
	for c in ["w", "a", "h", "r", "p", "x"]:
		if not p.eq.has(c) or not catalog(c).has(p.eq[c]):
			p.eq[c] = d.eq[c]
	return p


static func mag_capacity(eq: Dictionary) -> int:
	return int(RIG[eq.r].mags) + int(PACK[eq.p].mags)


static func drone_slots(eq: Dictionary) -> int:
	return int(PACK[eq.p].drones)


static func grenade_slots(eq: Dictionary) -> int:
	return int({"none": 1, "light": 2, "assault": 4}.get(eq.r, 1)) + int({"none": 0, "s": 1, "m": 2, "l": 2}.get(eq.p, 0))


static func medkit_slots(eq: Dictionary) -> int:
	return 1 + int({"none": 0, "light": 1, "assault": 2}.get(eq.r, 0)) + int({"none": 0, "s": 1, "m": 1, "l": 2}.get(eq.p, 0))


static func heavy_slots(eq: Dictionary) -> int:
	return int(PACK[eq.p].heavy)


static func weight(eq: Dictionary, mags: int, drones: int, heavy_ammo: int = 0, gren: int = 0, med: int = 0) -> float:
	var w: float = WEAPONS[eq.w].weight + ARMOR[eq.a].weight + HELMET[eq.h].weight + RIG[eq.r].weight + PACK[eq.p].weight + HEAVY[eq.x].weight
	w += mags * MAG_WEIGHT + drones * FPV_WEIGHT + heavy_ammo * float(HEAVY[eq.x].ammo_weight) + gren * GRENADE_WEIGHT + med * MEDKIT_WEIGHT
	return w


static func speed_mult(w: float) -> float:
	return clampf(1.12 - w / 45.0, 0.62, 1.08)
