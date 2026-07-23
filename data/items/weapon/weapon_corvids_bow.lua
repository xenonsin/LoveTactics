-- A bow, so it shoots at range with a dead point-blank band (docs/weapons.md). Its extra is that it
-- shoots the enemy's REACH away: the shaft leaves the target Blinded (status_blind), and a blinded unit's
-- ability range is cut back toward its own feet.
--
-- Quest-only: `class` with no `price`.
--
-- The archer's answer to the other archer, and the only counter in the game to range as such. Everything
-- else the party owns for dealing with an enemy shooter is positional -- close the distance, break line of
-- sight, get behind cover -- and all of it costs turns during which you are being shot. This costs one
-- arrow and the enemy's bow stops reaching you.
--
-- It works on casters just as well, which is the reason to carry it against a warband with no bows in it
-- at all: a blinded mage cannot reach the back line either, and unlike a Silence this does not care
-- whether the working is paid in mana.
--
-- Worth nothing whatever against a melee line, since Blind never cuts range below adjacent -- a man with
-- a sword is already standing where he needs to be. It is a read on the enemy roster, like most of the
-- best quest weapons here.
return {
    name = "Corvid's Bow",
    description = "Fires at range and blinds: the target's own abilities can no longer reach far.",
    flavor = "Crows go for the eyes because the rest of it can wait. The Lodge found this insight portable.",
    sprite = "assets/items/corvids_bow.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2,
        requiresSight = true,
        speed = 2,
        cost = { stat = "stamina", amount = 7 },
        -- Under an iron bow's: taking an enemy archer's reach away is worth more than the arrow.
        damage = { 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9 },
        effect = function(fx)
            fx.damage(fx.target)
            if fx.target and fx.target.alive then
                fx.applyStatus(fx.target, "status_blind")
            end
        end,
    },
}
