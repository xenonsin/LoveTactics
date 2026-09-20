-- LAY THE HEX: the Shaman's binding, pointed at a body's gear instead of at the ground
-- (models/curse.lua). One piece of what the target is carrying takes a curse, and it is a real one --
-- the same object the Cathedral charges to lift.
--
-- THE FIRST STOCK OF THE CURSE HALF, and the shallowest: it names no hex, so Combat.curseItem rolls one
-- the rift's first floor could have dealt. The Anchor and the rest of the deep ladder belong to the
-- things that CHOSE them (ability_sink_the_anchor, a boss's rule, a find the Touchstone reads), because
-- a cast that could roll The Anchor at will would be a hard lock on a 4-mana spell.
--
-- IT HAS TO DO SOMETHING TO A BODY WITH NO KIT, and that is the whole reason for the damage line. Curses
-- land on grid pieces, and a beast's fangs are `noSteal` -- so against a wolf, a dire boar or anything
-- else fighting with its own body, fx.curse finds nothing and answers nil. Without the blow underneath,
-- a player who cast this at the wrong target would have spent a turn and a quarter of their mana on a
-- log line. With it, the hex is the upside and the bolt is the floor.
--
-- AGAINST A FOE IT LASTS THE FIGHT; AGAINST THE PARTY IT LASTS UNTIL THE RITE. Enemies are rebuilt from
-- their blueprints every battle (fx.curse's own note says so), so this is a within-fight debuff on
-- anything the player points it at. That asymmetry is deliberate and is what keeps a hexing ability
-- merely good where a hexing ENEMY is frightening.
local Curve = require("models.curve")

return {
    name = "Lay the Hex",
    description = "Curses one piece of a foe's kit, and deals dark damage.",
    flavor = "Something small and patient goes into the grip, gets comfortable, and starts to complain.",
    sprite = "assets/items/ability_lay_the_hex.png",
    type = "ability",
    tags = { "dark", "magical" },
    class = "shaman",
    -- SLOT 4, AND THE SLOT PICKED THE DAMAGE RATHER THAN THE OTHER WAY ROUND. An ability's magnitude is
    -- the one its unlock slot names (models/balance.lua's slotTarget, a straight line from ability_fire_bolt
    -- unforged to the same spell fully forged), so authoring the bolt low and the slot high is a purchase
    -- that is a downgrade. Four is where the everyday hex wants to be: cheap enough to cast most turns,
    -- which is what makes running a grid out of cursable pieces a real plan. Price is slot 4's band.
    price = 410,
    unlockQuests = 4,
    activeAbility = {
        target = "enemy",
        range = 4,
        speed = 5,
        cost = { stat = "mana", amount = 7 },
        damage = Curve.ramp(11, 21),
        description = "Curses one piece of the target's kit, and deals dark damage.",
        effect = function(fx)
            fx.damage(fx.target)
            -- No id: the shallow end of the ladder. The blow lands whether or not anything takes.
            fx.curse(fx.target)
        end,
    },
}
