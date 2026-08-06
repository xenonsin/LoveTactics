-- A mace, so it displaces (docs/weapons.md). Its extra is that the displacement moves the WIELDER too:
-- the hook catches a foe, drives it two tiles, and the knight comes the whole way with it.
--
-- Quest-only: `class` with no `price`.
--
-- It used to be aimed at an ALLY -- it hooked a friend two tiles and dealt nothing to anybody -- and
-- docs/weapons.md carried a ⚠️ against it for exactly that. A weapon whose target is your own side is not
-- a weapon; it also cannot be graded, because "how much damage should this do at its slot" has no answer
-- when the answer would wound the person it is pointed at (Balance.gradesOnMagnitude). The repositioning
-- it sold is now the ability shelf's business, where support belongs, and this is a mace again.
--
-- What survives the change is the REASON the old one was worth a slot. Movement in this game is the
-- scarcest thing there is: a unit that has already acted cannot move, a rooted one cannot move, a Mired
-- or Crippled one moves badly. The crook still answers that -- it just answers it for the bearer, off an
-- attack, rather than handing a step to somebody else. Nothing else in the mace family moves its own
-- wielder; every other one of them shoves a body away and stays exactly where it stood.
--
-- Built on Combat.charge (fx.charge) rather than a shove plus a step, because that motion already exists
-- and is already tested: the pair moves in LOCKSTEP -- the target leads, the wielder follows into each
-- tile it vacates -- the run stops against terrain or a wall, and a bystander caught in the lane is
-- shoved aside. Lockstep for the whole drive is why the knight ends up behind the foe's LANDING tile
-- rather than on the square it first left, which is the one thing about this weapon worth reading twice
-- (tests/weapon_spec.lua pins both positions).
--
-- Hand-rolling it as knockback-then-teleport would have needed the shove's travel read back to know
-- whether to follow at all, and two things make that worse than it looks: the preview's fx.knockback
-- returns a flat 0 however far the body would go, so the follow-step would have previewed as nothing;
-- and Combat.teleportUnit does not check whether the arrival tile is occupied, so a shove blocked by a
-- wall would have stacked the knight onto the body it failed to move.
--
-- Two tiles rather than the Charge ability's three, and it carries a mace's blow where that one carries
-- none. Read against data/items/ability/ability_charge.lua: the fighter's Charge is a whole grid cell
-- spent on the motion alone, and this is the motion mounted on a weapon that also has to hit.
local Curve = require("models.curve")

return {
    name = "Shepherd's Crook",
    description = "Hooks a foe two tiles and advances with it.",
    flavor = "The Bastion issues one per company and never explains it. The companies that work it out do not give it back.",
    sprite = "assets/items/shepherds_crook.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    class = "knight",
    activeAbility = {
        target = "enemy",
        range = 1, -- the hook has to reach: the target starts adjacent, as Charge's pin does
        -- Quick for a mace (the iron mace swings at 4). The crook is a catch and a walk rather than a
        -- full-shouldered blow, and a repositioning tool that cost a heavy swing's tempo would never be
        -- worth the turn it spends.
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        -- Its slot's number, which at slot 0 is the iron mace's exactly (Balance.slotTarget). That is
        -- the ladder working rather than a coincidence: same family, same slot, same magnitude, and the
        -- motion is the whole of what tells them apart.
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            local t = fx.target
            if not t or not t.alive then return end
            -- The blow first, then the drive. Not folded into the damage as opts.knockback the way
            -- data/items/weapon/weapon_iron_mace.lua folds its shove: this displacement is a charge, not
            -- a knockback, and the two are different motions in the engine -- a charge moves two bodies
            -- in lockstep and clears its own lane.
            fx.damage(t)
            fx.charge(t, 2)
        end,
    },
}
