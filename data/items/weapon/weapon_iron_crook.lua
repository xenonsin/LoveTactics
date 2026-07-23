-- A staff, so it swaps Wait into Focus (docs/weapons.md) -- and its STRIKE is `physical`/`impact`, which
-- is the deviation. Every other staff in the game hits with magic and is therefore useless in exactly the
-- circumstance a mage most needs to hit something.
--
-- Quest-only: `class` with no `price`.
--
-- What it answers is the caster's worst turn: Silenced, or standing in a gagging storm, or facing
-- something carrying `resist magical`, or holding status_magic_denied -- a mage in any of those states has
-- a staff that does nothing at all and a Focus that gives back mana it cannot spend. This one still
-- refills the pool for later AND has an honest club on the end of it for now.
--
-- The pairing worth reading is data/items/weapon/weapon_unravelling_wand.lua, which does the same thing
-- to the wand family. Both are the Arcanum admitting that some fights are not arguments about magic. The
-- wand keeps its reach and gives up the school; this keeps the Focus and gives up the school. Neither
-- gives up its family's actual contract.
--
-- It is also the only staff whose strike is worth swinging on purpose -- the curve is well above the
-- family's usual afterthought -- which is what makes it the mage's weapon of last resort rather than a
-- worse wand.
return {
    name = "The Iron Crook",
    description = "Replaces Wait with Focus. Its strike is honest iron: no ward turns it, and no silence stops it.",
    flavor = "Four hundred years of theory, and the Archmage's answer to being gagged was a stick with a lump on the end.",
    sprite = "assets/items/iron_crook.png",
    type = "weapon",
    -- `physical` and `impact` in place of the family's usual magical: the deviation and the weapon. The
    -- `impact` tag also means it shatters a Frozen body, like every other blunt thing in the game
    -- (data/status/status_freeze.lua) -- so a mage's own Ice Bolt sets up its own staff.
    tags = { "staff", "impact", "physical", "melee" },
    class = "mage",
    waitBehavior = {
        kind = "focus",
        mana = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }, -- a plain staff's: nothing traded here
        speed = 10,
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        -- Roughly double the family's usual afterthought. It has to be a real club, or the deviation buys
        -- nothing: a physical strike for four damage is as useless against a warded foe as a magical one.
        damage = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
        effect = function(fx)
            fx.damage(fx.target) -- tags default to the item's, so the blow is physical
        end,
    },
}
