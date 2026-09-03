-- Sealed Hand: cut one body off from HELP. The next single-target friendly working aimed at it -- a heal, a
-- cure, a buff, a revive -- is refused outright (data/status/status_sealed_hand.lua).
--
-- The gap it was written for. Nothing in this catalog touched enemy SUPPORT. Every answer to an enemy
-- healer has been to kill the healer or to out-damage the healing, and against a body the party cannot
-- reach this turn neither of those is a plan. This makes the healer's TURN the thing you attack: they spend
-- the cost, the cooldown and the action, and their champion stays down.
--
-- The mirror of data/status/status_sealed_ward.lua with the sides swapped, and it reuses that ward's exact
-- machinery -- Status.aidWardOn, one charge spent through Status.consumeBarrier, and the same
-- single-target-only clause, so an area heal that catches the sealed body among others goes straight past
-- it. A healer who owns a blast already holds the counterplay and needs to know nothing about this.
--
-- WHY IT IS NOT THE UNCLOSING WOUND. Status.blocksHealing forbids HEALING for as long as it holds, which is
-- attrition and only ever answers a heal. This refuses one WORKING of any friendly kind and is then spent
-- -- the cure that would have lifted your Poison, the buff that would have made them hit harder, the revive
-- that would have stood their champion back up. Attrition versus tempo, and they are different purchases.
--
-- WHY AN ABILITY RATHER THAN A WEAPON. It was briefly a wand, and the wand was wrong twice over: the
-- Arcanum's three quest wands are named for what they leave on their own CASTER (see
-- data/items/weapon/weapon_sealed_ward_wand.lua), and a curse laid on somebody else does not belong in that
-- trio. A grid cell is also the right price for it -- this is a read on the enemy's support kit, and a party
-- facing no healer at all should be able to decline to carry it rather than find it welded to a weapon slot.
--
-- Priced and gated deep. Buying an enemy's whole action for one of yours is the strongest thing tempo can
-- do, and it wants to arrive once the enemy lines actually contain bodies worth denying.
return {
    name = "Sealed Hand",
    description = "Seals a foe: the next single-target friendly working aimed at it is refused.",
    flavor = "The Arcanum does not claim to have wounded anybody. A wound is a thing their priest can answer.",
    sprite = "assets/items/ability_sealed_hand.png",
    type = "ability",
    tags = { "arcane", "utility" },
    class = "mage",
    price = 330,
    unlockQuests = 3,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 16 },
        effect = function(fx)
            local t = fx.target
            if not t or not t.alive then return end
            fx.applyStatus(t, "status_sealed_hand")
        end,
    },
}
