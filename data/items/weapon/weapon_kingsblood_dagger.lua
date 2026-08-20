-- Undercroft rank-4. Fast and vicious: it costs almost nothing to swing, so it swings often. The
-- Undercroft never says whose blood named it, only what the name is worth.
--
-- It is sold, resold, and stolen back. The guild takes a cut each time -- the first hint of Greed,
-- whose general lifts the kit out of your hands mid-fight.
--
-- Its EXTRA over the plain iron dagger (data/items/weapon/weapon_iron_dagger.lua), which bleeds the same:
-- this one knows the way in. A foe already bleeding is a door standing open, and the Kingsblood puts
-- half the swing's power again straight through it -- then leaves a deeper wound than any other blade
-- (a bleed of 5 against the ordinary 3).
--
-- Which is Greed's whole argument in a weapon: it does not make the opening, it takes what is already
-- open. That makes it the one dagger that wants a SECOND dagger in the party -- open the wound with a
-- cheap iron blade, then let this one collect. It is also why it is worth stealing, and why the guild
-- keeps selling it back to you.
local Curve = require("models.curve")

return {
    name = "Kingsblood Dagger",
    description = "Inflicts a deep Bleed. Deal 50% more damage to a bleeding foe.",
    flavor = "The Undercroft never says whose blood named it, only what the name is worth. It does not make the opening; it takes what is already open.",
    sprite = "assets/items/kingsblood_dagger.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    class = "rogue",
    -- The Undercroft's rank-4, and priced like the other six lines' (800 / rank 4: the Crimson Greataxe,
    -- the Oathkeeper Shield, the Censer of Dawn, the Hornbow of the Hunt, the Philosopher's Stone, the
    -- Codex of Hubris). That symmetry is load-bearing: for every vendor, the standing that finally puts
    -- its 800-gold relic on the shelf is the standing that lets you face the general the relic has been
    -- describing (docs/story.md). Greed was the one line where it did not hold -- this file said
    -- "Undercroft rank-4" in its first line and then carried no `price` and no `repRank` at all, so the
    -- shop had no top rung and the rule quietly had six cases instead of seven.
    --
    -- Being sold is also the more Greedish arrangement, whatever an earlier note here claimed: the guild
    -- sells it, buys it back, and takes a cut each time. You pay the Undercroft for the knife it named
    -- after somebody's blood, which is the joke.
    price = 740,
    unlockQuests = 5,
    stealPriority = 2, -- a thief covets it above ordinary kit (below a Decoy's bait)
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 1, -- the fastest strike in the game: you act again almost at once
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(15, 25),
        effect = function(fx)
            -- A wound already open is a door: half the swing's power again goes straight through it.
            -- Read BEFORE the strike, so it answers "was this foe already bleeding when I found it?"
            -- rather than rewarding the blade for the cut it is making right now.
            local open = fx.hasStatus(fx.target, "status_bleed")
            local reopen = open and math.floor(fx.amount * 0.5) or 0
            -- Daggers bleed (docs/weapons.md); this one cuts deeper than the ordinary 3. The wound rides
            -- the blow, so a guardian who takes the hit takes the deeper cut too.
            fx.damage(fx.target, { amount = fx.amount + reopen, inflicts = { id = "status_bleed", magnitude = 5 } })
        end,
    },
}
