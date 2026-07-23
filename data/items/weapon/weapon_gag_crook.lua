-- A staff, so it swaps Wait into Focus (docs/weapons.md). Its extra is the one hostile wait swap in the
-- game: every Focus cuts every ADJACENT ENEMY off from magic (status_magic_denied) -- no spell, no
-- enchanted weapon, no arcane relic works for them while it holds.
--
-- Quest-only: `class` with no `price`.
--
-- `covers` pointed outward. The Crozier and the Oathkeeper Shield both spread a gift to the bodies beside
-- their bearer (docs/weapons.md: "one word means 'and everyone beside you' on either half of the wait
-- swap"), and this is the same sentence aimed at the enemy -- so `waitBehavior.afflicts` is the mirror
-- of `covers`, and the two now bracket what a wait swap can be.
--
-- What it produces is a priest who is dangerous to stand next to and does nothing at range, which is a
-- genuinely strange thing to play. The correct use is to walk INTO the enemy caster line and sit down --
-- the opposite of everything a robed character is normally told to do -- and refill mana while the
-- Arcanum's answer to you stops working. It is the Cathedral's opinion of the Arcanum rendered as a
-- verb.
--
-- Deliberately gated on adjacency and on spending the turn. A silence that reached would be a spell, and
-- a silence that was free would end caster fights outright; this costs a whole turn and requires the
-- priest to be standing in arm's reach of the thing it is silencing.
return {
    name = "The Gag-Crook",
    description = "Replaces Wait with Focus: recover mana, and cut every enemy beside you off from magic entirely.",
    flavor = "The Cathedral does not debate the Arcanum. It sits down next to them.",
    sprite = "assets/items/gag_crook.png",
    type = "weapon",
    tags = { "staff", "magical", "holy", "melee" },
    class = "priest",
    waitBehavior = {
        kind = "focus",
        -- Shallower than a plain staff's: the silence is paid for out of the meditation's own depth.
        mana = { 6, 7, 7, 8, 9, 9, 10, 11, 12, 12, 13 },
        speed = 10,
        -- The mirror of `covers`: applied to every adjacent ENEMY on each Focus (Combat.focus).
        afflicts = "status_magic_denied",
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
