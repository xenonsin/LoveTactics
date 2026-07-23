-- Collapse: the mage folds a patch of the world inward, and everything hostile within four tiles is
-- dragged up against it.
--
-- Read against Pull (data/items/ability/ability_pull.lua), which is the same verb aimed once. That one
-- hooks a single archer out of its dead zone; this takes the entire enemy formation and puts it in one
-- place. Nothing else in the game rearranges a board this hard, and the reason it is a MAGE ability
-- rather than the fighter's is the reason pride owns hazards and channels in the first place: the
-- other classes argue with the board, and the Arcanum edits it.
--
-- It deals nothing. What it does is SET UP -- and it sets up the caster's own catalogue, because a
-- crowd standing on one tile is what every area spell on this shelf was priced against and almost
-- never gets. Collapse, then Fireball, is the two-turn sentence the ability exists to let a mage say.
--
-- Pulled toward the CASTER, not toward an aimed tile, and that is the cost rather than a limitation:
-- the mage ends the turn with the whole enemy line standing on top of it, which for the frailest body
-- in the party is a genuinely bad place to be. Buying the setup means surviving one round of what you
-- just gathered. It pairs with the Careful Sigil (data/items/utility/utility_careful_sigil.lua) for
-- exactly that reason -- the follow-up blast has to be one you can afford to be standing inside.
--
-- Every unit dragged sets off whatever it is dragged ACROSS (Combat.pull walks them a tile at a time
-- through shoveStep), so a field of traps and hazards is worth far more with this in the grid: it does
-- not only gather them, it drags them over everything the party laid on the way in. Being dragged is a
-- move, not a blink, so a bleeding foe bleeds the whole way (docs/weapons.md, "Bleed").
--
-- Foes only. The mage is not gathering its own line.
return {
    name = "Collapse",
    description = "Drags every foe within four tiles up against you, over everything in the way.",
    flavor = "The Arcanum calls it a correction. It is difficult to watch and call it that.",
    sprite = "assets/items/ability_pull.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "magical", "arcane" },
    class = "mage",
    price = 460,
    repRank = 3,
    activeAbility = {
        target = "self",   -- the fold is centred on the caster; there is nothing to aim
        range = 0,
        speed = 6,
        support = true,    -- it lands no damage: it reads green, and the danger is where it leaves them
        cost = { stat = "mana", amount = 16 },
        -- Radius rather than an aoe footprint: nothing is being blasted, so there is no area to paint.
        -- The reach is read straight off the level curve below.
        effect = function(fx)
            local radius = 4 + math.floor(fx.level / 4) -- 4 at base, 5 from level 4, 6 from level 8
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, radius)) do
                -- Combat.pull refuses on its own for a target with no clear line and one already
                -- adjacent simply does not move, so neither needs a check here.
                if u.side ~= fx.user.side then fx.pull(u) end
            end
        end,
    },
}
