-- Static data: class/weapon/armor information

GearTradeTracker_OutputOrder = {
    "HEAD",
    "NECK",
    "SHOULDER",
    "CHEST",
    "WAIST",
    "LEGS",
    "FEET",
    "WRIST",
    "HANDS",
    "FINGER",
    "TRINKET",
    "BACK",
    "MAINHAND 1H STR",
    "MAINHAND 1H AGI",
    "MAINHAND 1H INT",
    "MAINHAND 2H STR",
    "MAINHAND 2H AGI",
    "MAINHAND 2H INT",
    "OFFHAND 1H STR",
    "OFFHAND 1H AGI",
    "OFFHAND 1H INT",
    "OFFHAND SHIELD",
    "OFFHAND FRILL",
}

GearTradeTracker_ArmorBySlotID = {
    [1]  = "HEAD",
    [2]  = "NECK",
    [3]  = "SHOULDER",
    [5]  = "CHEST",
    [6]  = "WAIST",
    [7]  = "LEGS",
    [8]  = "FEET",
    [9]  = "WRIST",
    [10] = "HANDS",
    [11] = "FINGER1",
    [12] = "FINGER2",
    [13] = "TRINKET1",
    [14] = "TRINKET2",
    [15] = "BACK",
}

GearTradeTracker_AllSlots = {
    Armor = {
        "HEAD", "NECK", "SHOULDER", "CHEST", "WAIST",
        "LEGS", "FEET", "WRIST", "HANDS",
        "FINGER1", "FINGER2",
        "TRINKET1", "TRINKET2",
        "BACK",
    },

    Weapons = {
        { slot = "MAINHAND", hand = "1H", stat = "INT" },
        { slot = "MAINHAND", hand = "1H", stat = "STR" },
        { slot = "MAINHAND", hand = "1H", stat = "AGI" },

        { slot = "MAINHAND", hand = "2H", stat = "STR" },
        { slot = "MAINHAND", hand = "2H", stat = "AGI" },
        { slot = "MAINHAND", hand = "2H", stat = "INT" },

        { slot = "OFFHAND", hand = "1H", stat = "INT" },
        { slot = "OFFHAND", hand = "1H", stat = "STR" },
        { slot = "OFFHAND", hand = "1H", stat = "AGI" },

        { slot = "OFFHAND", hand = "SHIELD", stat = nil },
        { slot = "OFFHAND", hand = "FRILL",  stat = nil },
    }
}

GearTradeTracker_ClassPrimaryStats = {
    WARRIOR   = { STR = true },
    PALADIN   = { STR = true, INT = true },
    HUNTER    = { AGI = true },
    ROGUE     = { AGI = true },
    PRIEST    = { INT = true },
    SHAMAN    = { INT = true, AGI = true },
    MAGE      = { INT = true },
    WARLOCK   = { INT = true },
    DRUID     = { INT = true, AGI = true },
    DEATHKNIGHT = { STR = true },
    MONK      = { AGI = true, INT = true },
    DEMONHUNTER = { AGI = true, INT = true },
    EVOKER    = { INT = true },
}

GearTradeTracker_ClassWeaponTypes = {
    WARRIOR      = { ["1H"]=true, ["2H"]=true, SHIELD=true },
    PALADIN      = { ["1H"]=true, ["2H"]=true, SHIELD=true },
    HUNTER       = { ["1H"]=true, ["2H"]=true },
    ROGUE        = { ["1H"]=true },
    PRIEST       = { ["1H"]=true, ["2H"]=true, FRILL=true },
    SHAMAN       = { ["1H"]=true, ["2H"]=true, SHIELD=true },
    MAGE         = { ["1H"]=true, ["2H"]=true, FRILL=true },
    WARLOCK      = { ["1H"]=true, ["2H"]=true, FRILL=true },
    DRUID        = { ["1H"]=true, ["2H"]=true, FRILL=true },
    DEATHKNIGHT  = { ["1H"]=true, ["2H"]=true },
    MONK         = { ["1H"]=true, ["2H"]=true },
    DEMONHUNTER  = { ["1H"]=true },
    EVOKER       = { ["1H"]=true, ["2H"]=true, FRILL=true },
}
