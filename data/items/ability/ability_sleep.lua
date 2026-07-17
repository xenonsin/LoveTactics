-- Sleep: put a foe under. The victim is shoved far down the turn order and stays there -- unless
-- anything at all hits it, which wakes it and hands back the time it hadn't served
-- (data/status/sleep.lua).
--
-- The mage's crowd-control cast, and the one whose correct use is counterintuitive enough to be worth
-- stating: DO NOT sleep the thing you are about to kill. A sleeper takes one hit and is awake with most
-- of its turn refunded, so opening on it wastes the spell entirely. Sleep is for the unit you intend to
-- IGNORE -- the flanking wolf, the second archer, the melee brick you cannot afford to trade with
-- yet -- so the fight becomes four-on-three for a stretch. It buys tempo, not damage.
--
-- Which puts it in a genuine three-way choice on the mage's own shelf rather than a ladder:
--   * Sleep     -- the longest removal, on the widest target list, undone by any hit. Cheap.
--   * Polymorph -- shorter and dearer, but it holds THROUGH damage: a pig you are stabbing stays a pig.
--   * Silence   -- doesn't remove anyone, just takes their spells.
-- Sleep and Polymorph are near-inverses -- one is removal you must respect, the other is removal you
-- can beat on -- and the fight decides which you wanted.
--
-- Landing it is deterministic; what varies is how long it holds. magicDefense and statusResist shorten
-- it, and every previous Sleep on the same victim this battle halves it again until it stops landing at
-- all (see the resistance contract in models/status.lua). No rolls: the player can read the board and
-- know what the cast buys before spending on it.
return {
    name = "Sleep",
    description = "Puts a foe far down the turn order. Any damage wakes it.",
    flavor = "Do not sleep the thing you are about to kill. Sleep the one you intend to ignore.",
    sprite = "assets/items/ability_sleep.png",
    type = "ability",
    tags = { "arcane", "magical", "utility" },
    class = "mage",
    price = 220,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            if fx.target then fx.applyStatus(fx.target, "status_sleep") end
        end,
    },
}
