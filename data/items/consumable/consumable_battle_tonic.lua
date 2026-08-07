-- Battle Tonic: the Warbrewer's free drink (fighter x alchemist). Restores stamina and does NOT end your
-- turn.
--
-- The item S2 was built for. "Quaff as a free action" has been the Warbrewer's stated mechanic since the
-- discipline was first sketched, and the engine had no shape for it -- the shipped approximation was the
-- Brawler's Bandolier granting Haste on a drink, which its own header admitted was a stand-in. `free`
-- now means what it says: the cast bills no initiative and leaves the turn open, so the tonic is drunk
-- BETWEEN doing things rather than instead of doing them.
--
-- That is the whole discipline in one line. A fighter's problem with the alchemist's shelf has always
-- been the exchange rate: a turn spent drinking is a turn not spent swinging, and no potion is worth a
-- swing. Take the turn cost away and the entire Crucible becomes a fighter's shelf.
--
-- One free action per turn (Combat.FREE_ACTIONS_PER_TURN), so this is not a bottomless stamina bar --
-- and the grid greys the second one with a reason rather than leaving a dead button.
--
-- Not tagged `potion`: the Cafe resells that tag and ignores standing, which would put a gated
-- discipline draught on the grocer's shelf turn one (docs/classes.md).
local Curve = require("models.curve")

return {
    name = "Battle Tonic",
    description = "Restores stamina without ending your turn.",
    flavor = "Brewed for people who have somewhere to be, and are already there.",
    sprite = "assets/items/consumable_battle_tonic.png",
    type = "consumable",
    tags = { "draught", "restorative" },
    class = "alchemist",
    discipline = "warbrewer",
    price = 250,
    unlockQuests = 9,
    maxStack = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 0,
        free = true, -- S2: bills no initiative and leaves the turn open (docs/classes.md)
        consumesItem = true,
        restore = Curve.ramp(20),
        description = "Restores stamina as a free action.",
        effect = function(fx)
            fx.restore(fx.user, "stamina", fx.amount)
        end,
    },
}
