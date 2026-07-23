-- A spear, so it owes the family's contract (docs/weapons.md): the two tiles directly in front, aimed
-- by picking a neighbour. What it adds over data/items/weapon/weapon_iron_spear.lua is that it is also
-- the pole the colours are nailed to -- the first thrust of a battle drives the standard into the
-- ground beside the wielder, and the 3x3 square around it becomes Rally ground (hazard_rally) for as
-- long as the standard stands.
--
-- The duality is the whole item, and it is a state you can see: the standard is either UP or it is
-- not. Up, this is an ordinary polearm fighting beside its own colours and the line around it is
-- Inspired. Down -- because nobody has thrust yet, or because the enemy cut the standard out from
-- under it -- the very next thrust plants it again. So the weapon has two modes and only one button,
-- and which mode you are in is a fact on the board rather than a counter on a tooltip.
--
-- What it does NOT cost is a turn. Every other way of raising a standard in this game is a cast that
-- does nothing else (data/items/ability/ability_rally_banner.lua and its siblings); this one is a
-- spear thrust that happens to end with the butt of the pike in the dirt. That is what the price and
-- the rank buy, and it is why the damage curve underneath sits below an iron spear's: you are paying
-- for the planting with every swing you take afterwards.
--
-- Two notes on how it is wired, both worth knowing before copying it:
--   * `noClaim`. An item that summons normally falls silent while its creature stands
--     (Combat.itemBlockReason -- one wolf per horn). A WEAPON cannot afford that rule: it would disarm
--     its bearer for exactly as long as the rally lasted. So the standard is planted without taking
--     the item's claim, and what remembers it instead is `fx.user.standard` -- a field on the UNIT,
--     which lives and dies with the battle. An item field would survive into the next fight and the
--     weapon would spend that battle believing in a standard that is not there.
--   * The rally is the GROUND, not the pole. The banner body (data/characters/character_banner.lua)
--     owns the nine hazard tiles, so cutting it down lifts the whole square on that beat
--     (Hazard.dropOwnedBy) -- and then the next thrust raises it somewhere else.
--
-- The banner itself is FIGHTER's vocabulary (docs/classes.md: banners belong to wrath's Warlord). It
-- is on the knight's shelf deliberately: what a Warlord's standard does is make a charge hit harder,
-- and what this one does is decide where the line is and hold that spot -- planted, immobile, and
-- worth defending. Sloth's shelf is the one that answers "where do we stand", and this is that
-- question asked with a flag in it.
return {
    name = "Marching Standard",
    description = "Skewers the two tiles ahead. While no standard of yours stands, the thrust plants one beside you.",
    flavor = "The Bastion's colours do not lead the advance. They mark the place nobody moves from.",
    sprite = "assets/items/marching_standard.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee", "banner" },
    hands = 2, -- a two-handed polearm, as every spear is
    class = "knight",
    price = 520,
    repRank = 4,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 11 },
        damage = { 5, 6, 6, 7, 7, 8, 8, 9, 10, 10, 11 }, -- under an iron spear's: the standard is the rest
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            -- The thrust always happens, whatever state the colours are in: this is a spear first, and
            -- the family's line is not conditional on anything.
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end

            -- ...and then the colours, if they are down. `standard` lives on the UNIT (see the note
            -- above), so a battle always opens with the standard to plant and a cut-down standard is
            -- raised again by the next thrust.
            local standing = fx.user.standard
            if standing and standing.alive then return end

            local bx, by = fx.openTileNear(fx.user.x, fx.user.y)
            if not bx then return end -- hemmed in on all eight sides: nowhere to drive it
            local banner = fx.summon("character_banner", bx, by, {
                control = "none", timeless = true, -- it never acts and never enters the turn order
                noClaim = true,                    -- ...and never silences the weapon that planted it
                scaling = { health = 3 }, amount = fx.level, -- a forged pole is harder to knock over
            })
            if banner and banner.alive then
                fx.user.standard = banner
                -- The rally IS the square, owned by the pole: cut the pole down and the ground lifts
                -- with it. Tiles that cannot hold a zone (a wall, off the map) are skipped by
                -- Hazard.place returning nil.
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        fx.placeHazard(bx + dx, by + dy, "hazard_rally", { owner = banner })
                    end
                end
                fx.log("action", string.format("%s drives the colours into the ground.",
                    (fx.user.char and fx.user.char.name) or "Unit"), fx.user)
            end
        end,
    },
}
