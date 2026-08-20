-- Muster Banner: the Warlord's answer to a stalemate. It plants the same destructible standard the
-- Rally and Sacred Banners raise (data/characters/character_banner.lua), but the ground it holds open
-- is MUSTERED (data/hazards/hazard_muster.lua) -- a zone that reads its two effects off whose feet are
-- on it: allies braced (Heroism), enemies left Exposed. One square, sorted by side.
--
-- Where Rally and Sacred hand out a pure buff, this one is a banner you plant BETWEEN the lines: it is
-- worth the most exactly where your people and theirs are standing on the same tiles, which is the
-- uncomfortable, decisive ground a Warlord is supposed to want (see hazard_muster.lua for why the
-- double reading is a whole item rather than two smaller ones). It stacks with the other banners' zones
-- the way any two banner-fields do -- separate zone ids, separate statuses -- so a Warlord holding a
-- Rally and a Muster field over one square rallies AND braces the rank that stands in both.
--
-- The muster hazard carries a short clock of its own (it was authored to WALK, on the Muster Cuirass);
-- planted here it is OWNED by the banner and quotes the banner-zone's forever-duration instead, so the
-- square answers to the standard's life and not to a count. Cut the standard down and Hazard.dropOwnedBy
-- takes the whole square with it -- the rule every banner obeys. See ability_rally_banner.lua for how
-- the banner body and its owned zone work.
return {
    name = "Muster Banner",
    description = "Plants a destructible banner: allies stand braced in its square, enemies stand open.",
    flavor = "Raised on the seam where the two lines meet. There is no safe place to plant it, which is the point.",
    sprite = "assets/items/ability_muster_banner.png",
    type = "ability",
    tags = { "banner" },
    class = "fighter",
    discipline = "warlord", -- deeper cut of the shelf: buyable only once the warlord gate is cleared
    price = 740,
    unlockQuests = 5,
    activeAbility = {
        target = "tile", -- aim an empty tile; the standard rises there
        range = 3,
        speed = 5,
        support = true, -- planted for your own line: reads green, and the AI treats it so
        cost = { stat = "stamina", amount = 14 },
        effect = function(fx)
            -- The banner's staying power is what forging it buys: +3 health per upgrade level over the
            -- base body, exactly as the Rally and Sacred Banners scale. A banner never moves or strikes,
            -- so how long it STANDS is the only thing an upgrade could mean.
            local banner = fx.summon("character_banner", fx.tx, fx.ty, {
                control = "none", timeless = true,
                scaling = { health = 3 }, amount = fx.level,
            })
            if banner and banner.alive then
                -- Lay the 3x3 of Mustered ground and hand every tile to the banner as its owner, so the
                -- whole square lifts the instant the standard falls. `duration = 9999` overrides the
                -- muster hazard's own short walking-clock: an owned zone answers to its owner's life, not
                -- to a count (see models/hazard.lua). Tiles that can't hold a zone (a wall, off the map)
                -- are skipped by Hazard.place returning nil.
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_muster", { owner = banner, duration = 9999 })
                    end
                end
            end
        end,
    },
}
