-- The Kept Wound: a ward that does not forgive what it swallows. It turns aside physical blows like
-- any barrier -- and then hands the whole accumulated total to everything standing around its bearer
-- when it finally lets go (data/status/status_kept_wound.lua).
--
-- WARDING AS AN AGGRESSIVE TURN, which nothing else in this game manages. Shielding an ally has always
-- been purely defensive: you spend an action and the board is exactly as it was, minus one blow. This
-- makes the enemy's own violence into the payload -- the harder they hit your ward, the worse the
-- answer, and the answer lands where they are standing, which is next to the person they were hitting.
--
-- So it rewards putting the shield on the unit the enemy most WANTS dead, rather than on the one least
-- able to take a hit. That is the opposite of every instinct a barrier normally trains, and it is the
-- whole reason to carry this over a plain Physical Barrier.
--
-- BOTH ENDINGS ARE THE SAME ENDING. Whether the last charge is spent or the duration simply runs out,
-- the wound is given back (Status.remove fires onExpire on every removal path). A ward nobody tested
-- has banked nothing and bursts for nothing -- honest, and worth knowing before casting it on somebody
-- nobody is aiming at.
--
-- The burst takes ALLIES standing adjacent as well, on the same rule every explosion in this game
-- follows. A priest who wards the front-liner in the middle of their own line has made a real decision
-- rather than a free one.
--
-- ADJACENCY: a `censer` beside it, like the rest of the Cathedral's serious work.
return {
    name = "The Kept Wound",
    description = "Wards an ally from physical blows, then bursts for everything it swallowed.",
    flavor = "Nothing is forgiven. It is only ever held, and the Cathedral is very good at holding.",
    sprite = "assets/items/ability_kept_wound.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "priest",
    price = 380,
    repRank = 4,
    activeAbility = {
        target = "ally", -- includes the caster: a priest may keep their own wound
        range = 4,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        support = true,
        requiresAdjacent = { tag = "censer" },
        effect = function(fx)
            -- `hits` is what the forge buys, exactly as the plain barriers' upgrade does -- a ward that
            -- negates outright cannot negate harder, so coverage is the only axis. More charges also
            -- means a bigger burst, since every charge is another blow banked: one number, two payoffs.
            fx.applyStatus(fx.target, "status_kept_wound", {
                magnitude = 2 + math.floor(fx.level / 3),
                duration = 15 + fx.level,
            })
        end,
    },
}
