class_name BotNames
## Bot display names: plausible handles, not "Bot 3".

const NAMES := [
	"Halvard", "Nix", "Orrin", "Pemberly", "Saskia", "Tomasz", "Wren", "Ilse", "Kojo", "Marisol",
	"Dagny", "Ravi", "Tallis", "Yusra", "Bertram", "Cato", "Fennick", "Greta", "Hadley", "Ione",
	"Jaxon", "Kestrel", "Lior", "Maud", "Nadir", "Oksana", "Piran", "Quill", "Rosalind", "Soren",
	"Tamsin", "Ulric", "Vesna", "Wolfram", "Xiomara", "Yannick", "Zephyrine", "Ansel", "Brix", "Corvin",
]


static func pick(seed_: int) -> String:
	return NAMES[absi(seed_ * 7 + 3) % NAMES.size()]
