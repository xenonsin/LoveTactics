return {
    name = "Mage",
    sprite = "assets/chars/mage.png",
    portrait = "assets/portraits/mage.png", -- large VN portrait for conversations (falls back if missing)
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    class = "mage",
    -- 42 health and 4 defense, standing next to a swordsman, is a corpse. Left to herself she keeps
    -- her distance (models/ai.lua); the Fireball in her grid carries its own rule about when the
    -- wind-up is worth paying for.
    archetype = "skirmish",
    stats = {
        health = 42, mana = 80, stamina = 10, -- resource stats
        staminaRegen = 1, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 5, magicDamage = 18,          -- flat stats
        defense = 4, magicDefense = 12,
        movement = 3, -- number of spaces this character can move
        speed = 3,    -- initiative tie-break; folded into starting initiative
    },
    -- Starting loadout as the 3x3 grid the player sees (row-major); false = an empty cell. The
    -- build-around is the Overflowing Focus relic in the center (data/items/utility/utility_overflowing_focus.lua):
    -- a bound item -- never moved, stowed, sold, or stolen, only forged -- that pays a cast's mana
    -- shortfall in blood (Overchannel). healing_potion stays in cell 1 (its default-weapon / basic-attack
    -- ordering is unchanged). Fire Stone infuses adjacent weapons/abilities with fire + Burn; it sits
    -- next to Fireball so the mage's spells set foes alight from the start (see fire_stone.lua). Summon
    -- Fire Elemental reserves a quarter of the deep mana pool for as long as the elemental stands.
    startingItems = {
        "consumable_healing_potion", "ability_jolt",             "armor_silk_robes",
        "weapon_parasitic_staff", "utility_overflowing_focus",   "utility_fire_stone",
        "ability_rain",   "ability_summon_fire_elemental", "ability_fireball",
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so
    -- its range shows, and driving the basic click-to-use. The player can re-pin any ability.
    defaultAction = "ability_fireball",
    -- Basic tactics (models/ai.lua): a glass body breaks off when it is bloodied rather than standing
    -- to trade. The Fireball in the grid carries its own rule for when the wind-up is worth paying, so
    -- the one thing left to author here is self-preservation.
    ai = {
        { priority = "emergency", act = "retreat", when = { subject = "self", test = "hp_pct_below", value = 0.3 } },
    },
}
