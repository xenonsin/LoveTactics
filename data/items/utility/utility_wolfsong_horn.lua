-- Kaya's signature relic: the horn she was given the day the wolf first answered it. Two things ride on
-- it, and the second is built on the first.
--
-- THE WOLF (passive, data/traits/trait_wolf_companion.lua): a wolf fields itself at her side at the
-- opening bell, free of any mana reservation. It is summoned `noClaim`, so -- unlike a summon ABILITY --
-- it does not lock this item's active; instead it is stashed on her as `unit.wolfCompanion`, which the
-- howl below reads. It CANNOT be resummoned: one wolf, granted once. When it falls it is gone for the
-- rest of the battle, and the horn falls silent with it.
--
-- THE QUIETING HOWL (active, the build-up): the horn does not kill, it STOPS -- "the hunt that knows
-- when to stop" turned on the enemy. It charges as the wolf draws blood (`unlock.event =
-- "companionDamage"`, banked on the summoner in Combat.dealDamage), and it can only be sounded WHILE
-- the wolf still stands (`unlock.when` reads `unit.wolfCompanion`). Sound it and every foe within two
-- tiles of Kaya OR of her wolf is rooted where it stands. It re-locks after each use (a repeatable
-- unlock), so a wolf that keeps biting can raise the howl again -- and a dead wolf can raise it never.
--
-- The gating is the whole character of the relic: her control is only as alive as the bond is. It also
-- plays straight against a heal-on-hit foe (Gula) -- rooting the ring lets a kiting archer break the
-- long trade instead of feeding it, which is temperance read as tactics (docs/story.md, "The Hunter's
-- Lodge").
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. Kaya's
-- blueprint sits it in the center of the loadout grid as the build-around. No `price`: no vendor stocks
-- or buys it; forged at the Blacksmith, its speed curve rising. `class = "hunter"` with no `price` is the
-- signature convention (compare data/items/utility/utility_aqua_vitae.lua): unbuyable, and still tallying
-- toward hunter growth (docs/classes.md).
return {
    name = "Wolfsong Horn",
    -- The wolf-alive gate is a RULE the player must know, so it stays in the description, not the flavor
    -- (docs/item-text.md): flavor is never load-bearing.
    description = "A wolf starts at your side. Sound the horn while it lives to root every foe within two tiles of you or the wolf.",
    flavor = "Raised beside a wolf, and it still comes when the horn sounds. What the horn calls, it calls but once.",
    sprite = "assets/items/sig_wolfsong_horn.png",
    type = "utility", -- a horn: `bound` (not the type) is what locks it in place
    tags = { "signature" },
    class = "hunter",
    bound = true,
    traits = { "trait_wolf_companion" },
    bonus = { speed = { 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 } }, -- levels 0..10
    activeAbility = {
        description = "Roots every foe within two tiles of you or your wolf. Charges as the wolf draws blood; usable only while the wolf lives.",
        target = "self", -- centred on Kaya; the effect also reaches around the wolf
        range = 1,
        speed = 6,
        unlock = {
            event = "companionDamage", count = 40, text = "Wolf draws blood",
            -- Only while the wolf still stands: it charges the horn by drawing blood, and it cannot be
            -- resummoned, so a dead wolf silences the horn (trait_wolf_companion sets unit.wolfCompanion).
            when = function(unit) local w = unit and unit.wolfCompanion; return (w and w.alive) or false end,
        },
        -- The howl's footprint: within two tiles of Kaya AND of her wolf. Declared here (not computed
        -- inside the effect) so the red area-highlight the player sees and the foes the howl actually
        -- roots are one and the same set (Combat.aoeCells de-dups the overlap and clamps to the board).
        -- The wolf is alive whenever the howl can fire (the `when` gate), but the preview is honest even
        -- mid-charge, so it is guarded here too.
        aoe = {
            cells = function(_, tx, ty, unit)
                local out = {}
                local function ring(cx, cy)
                    for dx = -2, 2 do for dy = -2, 2 do out[#out + 1] = { x = cx + dx, y = cy + dy } end end
                end
                ring(tx, ty)
                local wolf = unit and unit.wolfCompanion
                if wolf and wolf.alive then ring(wolf.x, wolf.y) end
                return out
            end,
        },
        effect = function(fx)
            -- One truth with the preview: sweep the very footprint aoeCells drew, and root every foe on
            -- it (allies and the wolf itself sit on those tiles too, so they are filtered out).
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.applyStatus(u, "status_root")
                end
            end
        end,
    },
}
