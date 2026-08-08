class_name PlantCatalog
extends RefCounted


const SOIL_NAMES := {
	"aroid": "Aroid Mix",
	"moist": "Moist Mix",
	"loam": "Loam Mix",
	"gritty": "Gritty Mix",
}

const FEED_NAMES := {
	"foliage": "Foliage Feed",
	"bloom": "Bloom Feed",
	"herb": "Herb Feed",
	"succulent": "Succulent Tonic",
}

const MUTATION_NAMES := {
	"variegated": "Variegated",
}

const MUTATION_VALUE_MULTIPLIERS := {
	"variegated": 1.65,
}

const CARE_ITEM_ACCENTS := {
	"soil:aroid": Color("#718b5d"),
	"soil:moist": Color("#648a9b"),
	"soil:loam": Color("#a36f4d"),
	"soil:gritty": Color("#8d887b"),
	"feed:foliage": Color("#5fa36e"),
	"feed:bloom": Color("#bf7f9c"),
	"feed:herb": Color("#8b77aa"),
	"feed:succulent": Color("#559b91"),
}

const SPECIES := {
	"monstera_deliciosa": {
		"name": "Monstera deliciosa",
		"group": "Foliage",
		"soil": "aroid",
		"feed": "foliage",
		"water_use": 0.0040,
		"nutrition_use": 0.0016,
		"optimal_low": 0.38,
		"optimal_high": 0.76,
		"growth_seconds": 310.0,
		"offshoot_seconds": 175.0,
		"starter_price": 24,
		"offshoot_value": 42,
		"model": "res://assets/models/plants/monstera_deliciosa.glb",
		"accent": Color("#4e9b61"),
	},
	"alocasia_polly": {
		"name": "Alocasia Polly",
		"group": "Foliage",
		"soil": "aroid",
		"feed": "foliage",
		"water_use": 0.0054,
		"nutrition_use": 0.0018,
		"optimal_low": 0.46,
		"optimal_high": 0.79,
		"growth_seconds": 355.0,
		"offshoot_seconds": 210.0,
		"starter_price": 31,
		"offshoot_value": 54,
		"model": "res://assets/models/plants/alocasia_polly.glb",
		"accent": Color("#3e805b"),
	},
	"golden_pothos": {
		"name": "Golden pothos",
		"group": "Foliage",
		"soil": "aroid",
		"feed": "foliage",
		"water_use": 0.0036,
		"nutrition_use": 0.0014,
		"optimal_low": 0.32,
		"optimal_high": 0.72,
		"growth_seconds": 245.0,
		"offshoot_seconds": 130.0,
		"starter_price": 18,
		"offshoot_value": 32,
		"model": "res://assets/models/plants/golden_pothos.glb",
		"accent": Color("#78a84d"),
	},
	"snake_plant": {
		"name": "Snake plant",
		"group": "Foliage",
		"soil": "gritty",
		"feed": "succulent",
		"water_use": 0.0013,
		"nutrition_use": 0.0008,
		"optimal_low": 0.17,
		"optimal_high": 0.50,
		"growth_seconds": 390.0,
		"offshoot_seconds": 230.0,
		"starter_price": 27,
		"offshoot_value": 49,
		"model": "res://assets/models/plants/snake_plant.glb",
		"accent": Color("#8ca64d"),
	},
	"peace_lily": {
		"name": "Peace lily",
		"group": "Foliage",
		"soil": "moist",
		"feed": "bloom",
		"water_use": 0.0058,
		"nutrition_use": 0.0018,
		"optimal_low": 0.50,
		"optimal_high": 0.84,
		"growth_seconds": 340.0,
		"offshoot_seconds": 195.0,
		"starter_price": 29,
		"offshoot_value": 51,
		"model": "res://assets/models/plants/peace_lily.glb",
		"accent": Color("#d8e8d5"),
	},
	"boston_fern": {
		"name": "Boston fern",
		"group": "Foliage",
		"soil": "moist",
		"feed": "foliage",
		"water_use": 0.0064,
		"nutrition_use": 0.0017,
		"optimal_low": 0.56,
		"optimal_high": 0.88,
		"growth_seconds": 325.0,
		"offshoot_seconds": 185.0,
		"starter_price": 26,
		"offshoot_value": 46,
		"model": "res://assets/models/plants/boston_fern.glb",
		"accent": Color("#65a66b"),
	},
	"lily": {
		"name": "Lily",
		"group": "Ornament",
		"soil": "loam",
		"feed": "bloom",
		"water_use": 0.0048,
		"nutrition_use": 0.0020,
		"optimal_low": 0.42,
		"optimal_high": 0.78,
		"growth_seconds": 300.0,
		"offshoot_seconds": 170.0,
		"starter_price": 22,
		"offshoot_value": 40,
		"model": "res://assets/models/plants/lily.glb",
		"accent": Color("#efcad5"),
	},
	"sunflower": {
		"name": "Dwarf sunflower",
		"group": "Ornament",
		"soil": "loam",
		"feed": "bloom",
		"water_use": 0.0060,
		"nutrition_use": 0.0023,
		"optimal_low": 0.45,
		"optimal_high": 0.80,
		"growth_seconds": 280.0,
		"offshoot_seconds": 205.0,
		"starter_price": 20,
		"offshoot_value": 37,
		"model": "res://assets/models/plants/sunflower.glb",
		"accent": Color("#e9b642"),
	},
	"lavender": {
		"name": "Lavender",
		"group": "Herb",
		"soil": "gritty",
		"feed": "herb",
		"water_use": 0.0021,
		"nutrition_use": 0.0012,
		"optimal_low": 0.20,
		"optimal_high": 0.56,
		"growth_seconds": 285.0,
		"offshoot_seconds": 155.0,
		"starter_price": 21,
		"offshoot_value": 38,
		"model": "res://assets/models/plants/lavender.glb",
		"accent": Color("#9673aa"),
	},
	"mint": {
		"name": "Mint",
		"group": "Herb",
		"soil": "moist",
		"feed": "herb",
		"water_use": 0.0062,
		"nutrition_use": 0.0017,
		"optimal_low": 0.50,
		"optimal_high": 0.88,
		"growth_seconds": 220.0,
		"offshoot_seconds": 110.0,
		"starter_price": 16,
		"offshoot_value": 29,
		"model": "res://assets/models/plants/mint.glb",
		"accent": Color("#73bd76"),
	},
	"aloe_vera": {
		"name": "Aloe vera",
		"group": "Succulent",
		"soil": "gritty",
		"feed": "succulent",
		"water_use": 0.0015,
		"nutrition_use": 0.0009,
		"optimal_low": 0.16,
		"optimal_high": 0.48,
		"growth_seconds": 365.0,
		"offshoot_seconds": 190.0,
		"starter_price": 25,
		"offshoot_value": 44,
		"model": "res://assets/models/plants/aloe_vera.glb",
		"accent": Color("#5e9d6f"),
	},
	"echeveria": {
		"name": "Echeveria",
		"group": "Succulent",
		"soil": "gritty",
		"feed": "succulent",
		"water_use": 0.0011,
		"nutrition_use": 0.0008,
		"optimal_low": 0.14,
		"optimal_high": 0.44,
		"growth_seconds": 345.0,
		"offshoot_seconds": 180.0,
		"starter_price": 23,
		"offshoot_value": 41,
		"model": "res://assets/models/plants/echeveria.glb",
		"accent": Color("#82a58c"),
	},
}

const BASE_ITEMS := {
	"watering_can": {"name": "Watering can", "kind": "tool", "price": 0, "icon": "water"},
	"trowel": {"name": "Trowel", "kind": "tool", "price": 0, "icon": "trowel"},
	"secateurs": {"name": "Secateurs", "kind": "tool", "price": 0, "icon": "cut"},
	"empty_pot": {"name": "Empty pot", "kind": "equipment", "price": 0, "icon": "starter"},
	"soil:aroid": {"name": "Aroid Mix", "kind": "soil", "profile": "aroid", "price": 8, "icon": "soil:aroid"},
	"soil:moist": {"name": "Moist Mix", "kind": "soil", "profile": "moist", "price": 8, "icon": "soil:moist"},
	"soil:loam": {"name": "Loam Mix", "kind": "soil", "profile": "loam", "price": 7, "icon": "soil:loam"},
	"soil:gritty": {"name": "Gritty Mix", "kind": "soil", "profile": "gritty", "price": 8, "icon": "soil:gritty"},
	"feed:foliage": {"name": "Foliage Feed", "kind": "feed", "profile": "foliage", "price": 7, "icon": "feed:foliage"},
	"feed:bloom": {"name": "Bloom Feed", "kind": "feed", "profile": "bloom", "price": 7, "icon": "feed:bloom"},
	"feed:herb": {"name": "Herb Feed", "kind": "feed", "profile": "herb", "price": 6, "icon": "feed:herb"},
	"feed:succulent": {"name": "Succulent Tonic", "kind": "feed", "profile": "succulent", "price": 7, "icon": "feed:succulent"},
}


static func species(species_id: String) -> Dictionary:
	return SPECIES.get(species_id, {}).duplicate(true)


static func species_ids() -> Array[String]:
	var ids: Array[String] = []
	for species_id in SPECIES:
		ids.append(species_id)
	return ids


static func item(item_id: String) -> Dictionary:
	if BASE_ITEMS.has(item_id):
		return BASE_ITEMS[item_id].duplicate(true)
	if item_id.begins_with("starter:"):
		var species_id := item_id.trim_prefix("starter:")
		var data := species(species_id)
		if data:
			return {
				"name": "%s starter" % data.name,
				"kind": "starter",
				"species": species_id,
				"price": data.starter_price,
				"icon": "starter",
			}
	if item_id.begins_with("offshoot:"):
		var payload := item_id.trim_prefix("offshoot:")
		var parts := payload.split("#", false, 1)
		var species_id := str(parts[0])
		var mutation_id := str(parts[1]) if parts.size() > 1 else ""
		if not mutation_id.is_empty() and not MUTATION_NAMES.has(mutation_id):
			return {}
		var data := species(species_id)
		if data:
			var multiplier := float(MUTATION_VALUE_MULTIPLIERS.get(mutation_id, 1.0))
			var mutation_prefix := "%s " % MUTATION_NAMES.get(mutation_id, mutation_id.capitalize()) if not mutation_id.is_empty() else ""
			return {
				"name": "%s%s offshoot" % [mutation_prefix, data.name],
				"kind": "offshoot",
				"species": species_id,
				"mutation": mutation_id,
				"price": int(round(float(data.offshoot_value) * multiplier)),
				"icon": "offshoot",
			}
	return {}


static func shop_item_ids() -> Array[String]:
	var result: Array[String] = []
	for species_id in species_ids():
		result.append("starter:%s" % species_id)
	for item_id in BASE_ITEMS:
		if BASE_ITEMS[item_id].kind in ["soil", "feed"]:
			result.append(item_id)
	return result


static func display_name(item_id: String) -> String:
	var data := item(item_id)
	return data.get("name", item_id.capitalize())


static func care_item_accent(item_id: String) -> Color:
	return Color(CARE_ITEM_ACCENTS.get(item_id, Color("#8c684b")))
