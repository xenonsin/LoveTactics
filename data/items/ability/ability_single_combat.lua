-- Single Combat: the knight calls one enemy out, and neither of them may walk away. Both are Duelbound
-- (data/status/status_duelbound.lua) -- rooted in place, free to swing and to answer -- and whichever
-- of them is still standing when the binding lifts keeps something of the other for the rest of the
-- battle.
--
-- WHAT IT ACTUALLY DOES is take movement away from two people, and that is a far more interesting
-- thing than it sounds, because the two are almost never equally happy about it. The spell does not
-- decide who benefits; the tiles they were standing on already did.
--
--   * Bind a SKIRMISHER and it is a prison. Everything a hit-and-run fighter owns is predicated on
--     leaving, and it may not leave.
--   * Bind a CASTER and it is a death sentence, provided your knight can actually reach it.
--   * Bind another WALL and you have wasted a turn making two immovable objects even more immovable.
--   * And it binds YOU too. A knight who calls out the wrong piece has volunteered to stand in one
--     place while the rest of the enemy line walks over and takes its time.
--
-- Won by OUTLIVING, never by killing. If the bound foe falls to somebody else's arrow, the knight
-- still collects -- what the binding measured was who was left standing in it. That is deliberate: an
-- execute would have made this a rogue item, and the whole party being able to help win a knight's
-- duel is the correct reading of a company.
--
-- ADJACENCY: any `weapon`. You cannot call somebody out empty-handed -- and unlike the tighter gates on
-- the rest of this shelf, this one is deliberately loose. What the knight brings to the duel is their
-- own business, and the spell has an opinion about the challenge rather than about the sword.
return {
    name = "Single Combat",
    description = "Binds the caster and one foe in place; the survivor keeps some of the other's strength.",
    flavor = "Name, rank, and the ground. The rest of the field is asked, politely, to look elsewhere.",
    sprite = "assets/items/ability_single_combat.png",
    type = "ability",
    tags = { "physical" },
    class = "knight",
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 10 },
        requiresAdjacent = { type = "weapon" },
        effect = function(fx)
            local dur = 15 + fx.level
            local gain = 3 + fx.level
            -- fx.applyStatus hands back the live instance, which is what lets the two bindings point at
            -- each other: each one's `opponent` is the other's bearer, and each one's onExpire asks
            -- "is the body I was bound to down?" independently. Two instances rather than one shared
            -- object, because they are genuinely separate -- a Cure on one of them frees that duellist
            -- and leaves the other rooted, which is exactly right.
            local mine = fx.applyStatus(fx.user, "status_duelbound", { duration = dur, magnitude = gain })
            local theirs = fx.applyStatus(fx.target, "status_duelbound", { duration = dur, magnitude = gain })
            if mine then mine.opponent = fx.target end
            if theirs then theirs.opponent = fx.user end
            fx.log("status", string.format("%s calls %s out.",
                fx.user.char and fx.user.char.name or "Unit",
                fx.target.char and fx.target.char.name or "a foe"), { fx.user, fx.target })
        end,
    },
}
