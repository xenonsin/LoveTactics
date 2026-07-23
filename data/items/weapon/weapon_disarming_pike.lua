-- A spear, so it skewers a line (docs/weapons.md). Its extra is that the thrust takes their weapons: both
-- tiles are left Disarmed (status_disarmed), unable to use any weapon at all -- bare fists still work.
--
-- Quest-only: `class` with no `price`.
--
-- The pole-arm's historical job, and a gap in this catalog: `status_disarmed` was authored and no weapon
-- in the game applied it. What makes it a spear's rather than anybody else's is the LINE -- disarming one
-- body is a nuisance and disarming a rank of two is a turn where the enemy front simply has nothing to
-- swing, which is the whole reason a wall of polearms was ever worth standing behind.
--
-- Read against data/items/weapon/weapon_mailpiercer.lua, which Halts the far tile: that one takes a foe's
-- ABILITIES and leaves its reflexes, this one takes its weapons and leaves everything else. Halted cannot
-- act but can still parry; Disarmed can act, cast, and answer -- with fists. Two different holes cut in
-- the same body, and the pair is worth carrying against different rosters.
--
-- Deliberately worthless against a beast: a wolf's fangs are `natural`, not something you can knock out
-- of its hands. It is a weapon for fighting armed men, which is the honest reading of a disarm.
return {
    name = "The Disarming Pike",
    description = "Skewers the two tiles ahead and strikes the weapons from both: they cannot use any weapon until it wears off.",
    flavor = "The Bastion's drill masters spend a whole season on this one motion, and the recruits spend all of it asking why they cannot just stab him.",
    sprite = "assets/items/disarming_pike.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2,
    class = "knight",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4, -- slower than an iron spear: the motion is a hook and a twist, not a thrust
        cost = { stat = "stamina", amount = 10 },
        -- Under an iron spear's, and it should be -- the point of this swing is not the wound.
        damage = { 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9 },
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                if u.alive then fx.applyStatus(u, "status_disarmed") end
            end
        end,
    },
}
