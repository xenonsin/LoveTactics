-- A Gaunt Vigil: a hooded iron figure a knight drives into the ground, which stands there and objects
-- to sorcery. Like the banner (data/characters/character_banner.lua) it is a standing object rather
-- than a fighter -- summoned control-"none" and `timeless`, so it never moves, never strikes, takes no
-- turns, and occupies no slot in the turn order.
--
-- Unlike the banner it holds no ground open. Its whole effect is a reflex it carries in its own kit:
-- trait_gaunt_vigil, which fires on Trait.onAnyCast -- the broadcast hook added for exactly this shape
-- of thing -- and bites whoever just finished working a spell nearby. The vigil does not need a turn to
-- do that, and could not use one if it had it.
--
-- WHY IT IS SLOTH'S. Every other answer to an enemy caster in this game is an interrupt: silence them,
-- stun them, deny them, shatter the channel. All of them are things you have to DO, on your turn, at
-- the right moment. This is the knight's version -- a thing you put down once, in the place the enemy
-- caster will have to work from, which then charges rent forever without anybody spending another
-- action on it. It does not stop the spell. It just makes casting there cost something.
--
-- Real health and real armour so cutting it down is a genuine decision for the enemy: an enemy mage
-- that wants to cast freely must spend a turn breaking the vigil, which is a turn it did not spend
-- casting -- so the vigil has already worked even when it is destroyed immediately.
return {
    name = "Gaunt Vigil",
    sprite = "assets/chars/gaunt_vigil.png",
    stats = {
        health = 26, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 6, magicDefense = 10, -- warded against exactly what it is standing there to punish
        movement = 0, -- driven into the floor
        speed = 0,    -- takes no turns; its answer rides on somebody else's cast
    },
    startingItems = { "utility_vigil_ward" },
}
