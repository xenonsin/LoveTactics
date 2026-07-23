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
return {
    name = "Kingsblood Dagger",
    description = "Inflicts a deep Bleed, and strikes far harder into a foe already bleeding.",
    flavor = "The Undercroft never says whose blood named it, only what the name is worth. It does not make the opening; it takes what is already open.",
    sprite = "assets/items/kingsblood_dagger.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    -- Quest-only: a `class` with no `price` tallies toward rogue growth but sits on no shelf, and no
    -- `price` also keeps it out of the random spoils pool (models/spoils.lua), which reads `price` as the
    -- "is this ordinary stock?" marker. The Undercroft sells it back to you in fiction; in play it is a
    -- thing you are given for doing the guild a service, which is the more Greedish arrangement anyway.
    class = "rogue",
    stealPriority = 2, -- a thief covets it above ordinary kit (below a Decoy's bait)
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 1, -- the fastest strike in the game: you act again almost at once
        cost = { stat = "stamina", amount = 4 },
        damage = { 9, 10, 11, 12, 13, 14, 14, 15, 16, 17, 18 },
        effect = function(fx)
            -- A wound already open is a door: half the swing's power again goes straight through it.
            -- Read BEFORE the strike, so it answers "was this foe already bleeding when I found it?"
            -- rather than rewarding the blade for the cut it is making right now.
            local open = fx.hasStatus(fx.target, "status_bleed")
            local reopen = open and math.floor(fx.amount * 0.5) or 0
            fx.damage(fx.target, { amount = fx.amount + reopen })
            -- Daggers bleed (docs/weapons.md); this one cuts deeper than the ordinary 3.
            fx.applyStatus(fx.target, "status_bleed", { magnitude = 5 })
        end,
    },
}
