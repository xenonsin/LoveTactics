-- Totem of Mending: the Totemist's second priest-shelf totem (hunter x priest). It plants a post
-- projecting RENEWAL rather than healing ground.
--
-- The distinction against Raise Totem is the whole item, and it is mechanical rather than numeric.
-- Raise Totem lays hazard_heal: you are mended while you stand in it, and the moment you step out the
-- mending stops. This lays hazard_renewal, which grants Regeneration -- a status the ally CARRIES AWAY.
--
-- So the two totems ask opposite things of a party. One says hold this ground; the other says come and
-- touch this, then go and do your job. A Totemist owning both is not owning the same item twice at
-- different strengths -- which is what a "+n" version of Raise Totem would have been, and what the
-- contract forbids (docs/classes.md: if an item's only claim on a shelf is its flavour, it is on the
-- wrong shelf).
--
-- It is also the totem that works for a party that cannot stand still: a Skirmisher or a Ninja will
-- never camp in a heal zone, and until now the Totemist had nothing to offer them.
return {
    name = "Totem of Mending",
    description = "Plants a totem granting Regeneration -- allies who touch its ground carry the healing away with them.",
    flavor = "You are not meant to stay. You are meant to come back through.",
    sprite = "assets/items/ability_totem_of_mending.png",
    type = "ability",
    tags = { "holy", "summon" },
    class = "priest",
    discipline = "totemist",
    price = 380,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 5,
        support = true,
        cost = { stat = "mana", amount = 12 },
        description = "Plants a totem laying Renewal around it: allies gain Regeneration and keep it when they leave.",
        effect = function(fx)
            local totem = fx.summon("character_totem", fx.tx, fx.ty, {
                control = "none", timeless = true, scaling = { health = 3 }, amount = fx.level,
            })
            if not (totem and totem.alive) then return end
            -- Owned by the totem, so cutting the post down lifts the ground with it
            -- (Hazard.dropOwnedBy) -- the same bargain every planted zone in the game makes.
            for dy = -1, 1 do
                for dx = -1, 1 do
                    fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_renewal",
                        { amount = 4 + fx.level, owner = totem, duration = 9999 })
                end
            end
        end,
    },
}
