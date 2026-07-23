-- A longbow, so it is drawn before it looses and reaches five tiles (docs/weapons.md). Its extra is that
-- grief is a trigger: the shaft lands for far more when an ally of the archer has died in this battle,
-- and the wound deepens with every one of them.
--
-- Quest-only: `class` with no `price`.
--
-- It reads the `allyDown` tally (Combat.tally, raised on every surviving ally when a body falls), which
-- is a counter the engine already keeps and which no item has ever spent. What it buys is a weapon that
-- is honestly poor for most of a fight and becomes the heaviest shot in the game in the part of a fight
-- that was going badly -- so it is the one item on the hunter's shelf that gets stronger as the run gets
-- worse.
--
-- Read against data/items/weapon/weapon_long_count.lua, which scales on turns survived: that one rewards
-- the fight going long, this one rewards it going wrong, and they are different curves because a long
-- fight and a losing one are not the same thing. A party that is winning cleanly never sees this weapon
-- do anything.
--
-- Deliberately not a revenge mechanic aimed at a killer -- nothing here tracks who did it. The archer is
-- not avenging anybody in particular; the shot is simply worth more once the company has started paying.
return {
    name = "The Last Word",
    description = "A drawn shaft that lands far harder for every ally who has fallen this battle.",
    flavor = "The Lodge does not issue it to hunters who have not lost anyone. There would be no point.",
    sprite = "assets/items/last_word.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        channel = 2,
        cost = { stat = "stamina", amount = 10 },
        -- Well under the iron longbow's, and that is the FLOOR: this is what it lands while the party is
        -- intact, which should feel like carrying the wrong bow.
        damage = { 5, 6, 6, 7, 8, 9, 9, 10, 11, 12, 13 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local Combat = require("models.combat")
            -- +60% per fallen ally. Steep, because the counter is scarce and terrible to fill: a party
            -- that has lost three people is a party about to lose the fight, and this is what it has.
            local lost = Combat.tallyCount(fx.user, "allyDown") or 0
            fx.damage(t, { amount = math.floor((fx.amount or 0) * (1 + 0.6 * lost)) })
        end,
    },
}
