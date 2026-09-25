-- Tests for THE TWO ROADS TO A FOUND WARE, and for the handful that only ever have one.
--
-- Above a house's opening weapon nothing carries a price (tools/drop_tier.lua's recut): a weapon, a
-- utility or a piece of armor carries a `unlockLevel` instead. What that depth buys is THREE things, and
-- the whole of this file is that they are one number -- how deep the rift gives it up, what a counter
-- charges for one, and the class rung a counter deals it at. docs/shelf.md is the prose.
--
-- WHAT THIS FILE USED TO DEFEND, and it is worth knowing because the cases below are its inverse: a
-- found ware stood on the rack named, silhouetted and UNBUYABLE at any standing until the company had
-- carried one out. That gate came off -- 157 wares reached the player through the price band's tail
-- alone, which is the reachability obligation docs/shelf.md states and that arrangement could not
-- meet. The rift is the head start; the class ladder is the backstop.
--
-- SO WHAT IS DEFENDED NOW is two claims that pull against each other, which is why they are pinned
-- together: an ordinary found ware must be REACHABLE by climbing alone, however unlucky the company --
-- and a TROPHY must not be, at any rung, in any discipline, however rich they are. The second is the
-- only thing keeping "what this body is known for" from being a shopping trip.
--
-- The discovery LEDGER outlived the gate that read it. `player.found` is still stamped at the surface
-- and still rides the save; models/bestiary.lua redacts a body's drop list with it. The cases at the
-- foot of this file are unchanged and still its guard.

local Vendor = require("models.vendor")
local Player = require("models.player")
local Item = require("models.item")
local Save = require("models.save")
local Class = require("models.class")

-- THE HAND-WRITTEN BEAST TROPHIES, named rather than swept. docs/drops.md's rule is "what a body is
-- KNOWN for" -- a judgment made one animal at a time -- and a heuristic that gathered these would also
-- gather the lists tools/drop_assign.lua spread for coverage, which are ordinary stock and must stay
-- buyable. Named here, so adding one is a line somebody writes a sentence next to.
local TROPHIES = {
    "armor_bristlehide", "weapon_unclosing_spear",
    "armor_winterhide", "utility_knapped_claw", "utility_the_yearling_pelt",
    "utility_the_wake", "utility_treeline_horn", "utility_the_last_sounder",
    "ability_mothers_howl", "utility_the_wood_remembers", "weapon_the_second_bite",
    "armor_raveners_hide", "utility_in_and_out",
    "armor_runners_hide",
    -- The Meandering Stag's three (data/characters/character_meandering_stag.lua). The sandals are the
    -- odd one: they are not a new trophy but an existing SHELF item taken off the counter and given to
    -- an animal, which is the first time a piece has moved in that direction.
    "utility_wellspring_sandals", "utility_the_second_hound", "utility_swailing_brand",
    -- The King Slime's two (data/characters/character_king_slime.lua), and they are the first pair
    -- that are not a piece OF the body but the body's own RULES worn: the Surface is its immunity
    -- bounded to an opening turn, the Mantle is its adaptation bounded to one. A counter dealing
    -- either would be selling the boss fight's answer over the counter that the fight exists to
    -- teach, which is exactly what this list is for.
    "utility_unbroken_surface", "armor_quicksilver_mantle",
    -- The wood's slimes (data/characters/character_moss_slime.lua and its King): Gluttony's slime rule,
    -- "what came apart tries to come back together", worn three ways.
    "armor_mosswrap", "utility_crown_of_the_court", "utility_moss_heart",
    -- Lust's velvet slimes (data/characters/character_velvet_slime.lua and its Queen): their Strip,
    -- worn, and the one coat nothing can be stripped from.
    "utility_velvet_glove", "utility_kept_suitors", "utility_loosened_laces", "armor_silk_lining",
    -- The Siren's four and the Lorelei's two (data/characters/character_siren.lua, character_lorelei.lua):
    -- the answer to her, her voice carried, the crew's rope, the mere's echo; her Only Voice and her rock.
    "utility_beeswax", "utility_sirens_comb", "utility_mast_rope", "utility_echo",
    "utility_deaf_heart", "utility_held_note",
    -- Greed's slimes compound (trait_interest): the coin, the purse and the scale are that rule worn.
    "utility_ledger_coin", "utility_compound_purse", "utility_usurers_scale",
    -- The last four slime lines (2026-09-24), each a circle's rule worn: Wrath's Boil Over, Sloth's three
    -- (Torpid, Numbed, Drift), Envy's Mimicry and Begrudge, Pride's Rank.
    "utility_seething_core", "armor_caldera_plate", "utility_flashpoint",
    "armor_unhurried_coat", "utility_idle_hands", "utility_snowbank", "utility_the_slow_hour",
    "utility_stillwater", "utility_heavy_lids", "utility_deep_sleep", "utility_snowslide", "utility_patient_blade",
    "utility_copycat", "utility_mirror_mask", "utility_second_self",
    "utility_pecking_order", "utility_station", "armor_above_reproach",
    -- The Mimic's one (data/characters/character_mimic.lua, models/mimic.lua's Mimic.TROPHY), and it
    -- is the first trophy that is not paid by the rank draw at all: a flat percent on top of the win,
    -- outside the roll. That makes the refusal below load-bearing in a way it is not for the others --
    -- a counter dealing one would not merely shortcut a chase, it would sell the ONLY thing in the game
    -- that widens the carry ceiling to a company that never opened a wrong lid.
    "utility_still_hungry",
    -- The Ancient Stag's three (data/characters/character_stag_beast.lua). The hide is the animal
    -- tanned; the other two are its RULES learned rather than looted -- the same split Feral Instinct
    -- and the Reprisal Quiver already are -- so what a counter would be dealing is the answer to the
    -- fight rather than a piece of the body.
    "armor_bellowhide", "utility_the_close_herd", "utility_lowered_crown",
    -- The succubus line's, and the first trophy on this list that was taken OFF a counter rather than
    -- authored onto a body. Charm sat on the thief shelf at 610 gold, which said that taking a body is
    -- a technique a fence teaches for money; it is the Lust circle's own verb, and it comes off the
    -- thing that used it on you now (data/items/ability/ability_charm.lua). The Congregation is its
    -- payoff (utility_the_congregation) falls off the same line, so the pair is assembled out of one
    -- circle -- but the payoff stays ORDINARY rift stock, shelf-gated like any other find. Only the
    -- taking itself is off the market, because it is the verb the stratum is built on and a counter
    -- dealing one would sell the answer to the fight that exists to teach it.
    "ability_charm",
    -- The Lust garden's (2026-09-23): the Alraune line's four -- its Mandrake whole, its seed, its
    -- sleeping draught, the Anchoress's rule -- and the Hamadryad's bow and the mushroom folk's three.
    -- Each is the body's own trick, and the Dryad line's spells are NOT here: those are ordinary druid
    -- stock, found first and then shelved once the class has grown that far, on the author's call.
    "ability_mandrake_sprout", "ability_gallows_seed", "consumable_mandragora", "utility_the_pit_grows",
    "weapon_churchyard_yew",
    "consumable_puffball", "armor_spongeflesh_mantle", "weapon_spore_censer",
    -- The Whirl Elemental's rush (data/items/ability/ability_whirlwind.lua): the body's own trick, the
    -- one cast that picks its own landing, and off the thing that used it on you.
    "ability_whirlwind",
    -- The spider line's (Gluttony, 2026-09-23), each one of the animal's mechanics rebuilt for a person:
    -- off the Giant Spider its feet (the Mantle) and the line it pays out (the Dragline); off the Larder
    -- Mother her patience, her brood, her senses and her skin. The one priced piece of the set, Spider's
    -- Supper, is NOT here -- it is Poisoner stock the brood also drops.
    "armor_gossamer_mantle", "ability_dragline",
    "utility_the_still_hunt", "ability_brood_sac", "utility_tremor_cord", "armor_castoff_coat",
    -- The Manticore's (Gluttony's seat, 2026-09-23): its Bristle's barbs as a coat, its volley as a
    -- fletching, and the Bristle itself as the chase.
    "armor_quillhide", "utility_barbed_fletching", "utility_the_bristling",
    -- The wyverns' (Gluttony's seat, 2026-09-23): the dive as a cloak, the cut as a hunter's ability, the
    -- flight's wind as a charm, the takeoff as an escape, and the carry as the Highwing's chase.
    "armor_plummet_cloak", "ability_gale_cut", "utility_tailwind_charm", "ability_skyward",
    "ability_bear_away",
    -- The Chimera's (Gluttony's seat, 2026-09-23): the lion's appetite as a Battlemage charm, and each
    -- head as a Beastmaster's -- a head you wear, earned by breaking that head.
    "utility_hearth_hunger", "utility_serpent_head", "utility_goat_head",
    -- The Sabertooths' (Gluttony's approach, 2026-09-23): the ambush as a cloak, the pounce's critical as a
    -- charm, the appetite as a cord, and the Longfang's hunt as her own.
    "armor_stalkers_mantle", "utility_ambush_charm", "utility_trophy_cord", "utility_the_unbroken_stalk",
    -- The Dwarves' (Greed's keep, 2026-09-24): each body drops the trick it fights with -- the Delver's
    -- dive, the Hornblower's painted lead, the Goldsmith's leaf -- and the Thane his mithril.
    "ability_delve", "ability_fools_gold", "ability_gilders_leaf", "armor_mithril_shirt",
    -- Gula's (the wood's general, re-premised 2026-09-23): the beast's inhale as a druid's, and the rule
    -- that learns every blow as a hide. After the Maw on her drop list (Descent.DROPS.gluttony).
    "ability_draw_breath", "armor_studied_hide",
    -- Luxuria's (the fen's general, re-premised as the succubus Queen 2026-09-25): her escape as a
    -- Skirmisher's, a counter to her charm as an Alchemist's, and her old Rapture as a Priest's crowd drain.
    "ability_changing_partners", "utility_smelling_salts", "utility_saints_chalice",
    -- The Sated's (Gluttony's seat, reworked 2026-09-23): the Retch as a Bombardier's, the Eat as a
    -- Barbarian's, the whole fight turned around as a Bulwark's coat, a devoured corpse as a
    -- Necromancer's, and being full as a Paladin's.
    "ability_bile_sac", "utility_bottomless_gut", "armor_distended_girth", "ability_second_helping",
    "utility_sated_charm",
    -- The flight's (Gluttony's approach, 2026-09-23): the hawk's bells as a Trapper's, and the Griffin's
    -- appetite and tithe as a Warbrewer's and a Beastmaster's.
    "utility_hawk_bells", "utility_gorgers_beak", "utility_tithe_feather",
}

local function vendorFor(class)
    for id, def in pairs(Vendor.defs) do
        if def.class == class then return id end
    end
end

-- An ORDINARY found ware: classed, unpriced, carrying a depth, on a class a house actually stocks, and
-- not one of the pieces a body is known for. Picked off the data rather than named, so a re-grade that
-- moves every tier does not redden this file.
--
-- The vendor check is not belt-and-braces: `creature` is a root with kit of its own and no counter
-- anywhere, so a bare isRoot filter picks a demon's cast and asks which shop sells it.
--
-- `unstocked` is excluded by asking Vendor.foundPrice rather than by reading the flag, so this helper
-- and the shelf agree on what "a counter could deal this" means by construction.
-- `dropOnly` IS OUT, and it is out because these cases are about a ware the shelf eventually DEALS --
-- shut under its rung, open at it, priced at what its depth implies. A dropOnly piece is refused at
-- every counter forever (models/vendor.lua): it is on the rack to be read, it sells back like any other
-- found ware, and no rung ever opens it. That is a different contract and it is held one file over, in
-- tests/naga_spec.lua. Without this clause the first one authored simply won the alphabetical lottery
-- this picker runs and failed both cases below for a reason that had nothing to do with either.
local function anyFound(want)
    local best
    for id, def in pairs(Item.defs) do
        if def.unlockLevel and not def.price and def.class and Class.isRoot(def.class) and not def.bound
            and not def.dropOnly
            and vendorFor(def.class) and Vendor.foundPrice(def) ~= nil
            and (not want or want(def)) and (not best or id < best) then
            best = id
        end
    end
    return best
end

local function rowFor(vendorId, itemId, rung)
    for _, entry in ipairs(Vendor.stock(vendorId, rung or 99, nil,
        Class.unlockedSet(Player.new()), Class.levelSet(Player.new()))) do
        if entry.id == itemId then return entry end
    end
end

return {
    {
        -- BOTH HALVES AT ONCE, because either alone is a different (and wrong) design: open at rung 0
        -- is the old catalogue, and shut at the top of the ladder is content nobody can reach.
        name = "a found ware is shut under its rung and dealt at it, and the rung is its depth",
        fn = function()
            -- A ware deep enough to have a rung to climb; a tier-1 piece is open from the first
            -- morning and could not tell a working gate from a missing one.
            local id = anyFound(function(def) return def.unlockLevel >= 3 end)
            assert(id, "no unpriced, classed ware below the opening tier -- the tier pass did not run")
            local def = Item.defs[id]
            local vendorId = vendorFor(def.class)
            assert(vendorId, def.class .. " has no vendor to stock " .. id)
            -- NO LONGER `- 1`: since the fold the rung IS the class level (tools/ladder_fold),
            -- so the depth a thing falls at and the level that buys it are one number.
            local need = def.unlockLevel

            local shut = rowFor(vendorId, id, need - 1)
            assert(shut, id .. " is not on " .. vendorId .. "'s shelf at all -- a shelf that hides what "
                .. "it cannot yet deal is a record of what you have, not of what there is")
            assert(shut.locked, id .. " (depth " .. def.unlockLevel .. ") is buyable at class level "
                .. (need - 1) .. ", a rung under its own")
            assert(shut.lockReason == "rung",
                id .. " is shut for the wrong reason: " .. tostring(shut.lockReason))
            -- THE ROW REPORTS THE RUNG IT WAS MEASURED AGAINST, not the authored rank. Two fifths of
            -- the catalogue carries no `unlockLevel`, so a reader taking the rank would promise a
            -- gate at 0 over a tile that refuses the press -- which is what the shop's refusal
            -- sentence and the market's rotation band both read (ui/panels/shop.lua, models/market.lua).
            assert(shut.rung == need, id .. " reports rung " .. tostring(shut.rung) .. ", not the "
                .. need .. " its depth names")
            -- The OTHER road, still named on the row: climb to the rung, or go down to the floor.
            assert(shut.unlockLevel, id .. " does not report the depth it falls at")

            local open = rowFor(vendorId, id, need)
            assert(open and not open.locked,
                id .. " is still shut at class level " .. need .. ", the rung its depth names")
            assert(open.lockReason == nil,
                "a dealt row still names a reason: " .. tostring(open.lockReason))
        end,
    },
    {
        -- NOTHING WAS CARRIED OUT, and that is the case. The gate is the ladder and only the ladder;
        -- a company that has never seen one of these buys it the moment the class is grown for it.
        name = "the rung is the whole gate -- having found one is asked nowhere",
        fn = function()
            local id = anyFound()
            local def = Item.defs[id]
            local player = Player.new()
            assert(not Player.hasFound(player, id), id .. " is already in a fresh company's ledger")

            local row = rowFor(vendorFor(def.class), id, 99)
            assert(row and not row.locked,
                id .. " is refused to a company at the top of the ladder that never found one")

            -- Derived, never authored: the depth is read as the slot the ware would have had.
            assert(row.price and row.price > 0, id .. " is stocked at no price at all")
            assert(row.price == Vendor.foundPrice(def),
                id .. " is priced at " .. tostring(row.price) .. ", not the "
                .. tostring(Vendor.foundPrice(def)) .. " its depth implies")
        end,
    },
    {
        -- THE EXCEPTION, AND IT IS THE ONE THING KEEPING A CHASE FROM BEING AN ERRAND. Asserted at the
        -- TOP of the ladder with the discipline sets handed over, because "not yet" and "not ever" are
        -- the two answers this has to tell apart -- a trophy shut at rung 0 would pass a lazier check
        -- and open at rung 8.
        -- SHOWN AND REFUSED, which is the 2026-09-20 reading. This case used to assert the opposite --
        -- that a trophy stood on no rack at all -- and that was the behaviour rather than the intent: a
        -- nil price kept it out of Vendor.stock as a side effect, so the rarest pieces in the game were
        -- invisible at every counter and a player had no way to learn they existed. The MONEY half is
        -- unchanged and is still asserted below: no price in either direction.
        name = "a trophy is shown at every counter, refused by name, and bought back by nobody",
        fn = function()
            for _, id in ipairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def, id .. " is named a trophy and is not in the data")
                assert(def.unstocked, id .. " lost its `unstocked` flag: a counter will deal one")
                assert(def.unlockLevel, id .. " has no depth, so nothing can drop it either")
                assert(Vendor.foundPrice(def) == nil, id .. " can still be quoted a price")
                assert(Vendor.sellValue(Item.instantiate(id)) == 0,
                    id .. " sells back: a piece that exists only where it fell has no market price in "
                    .. "either direction")

                local vendorId = def.class and vendorFor(def.class)
                if vendorId then
                    -- At the top of the ladder, so the only thing that can be shutting it is the flag.
                    local row = rowFor(vendorId, id, 99)
                    assert(row, id .. " vanished from " .. vendorId .. "'s rack -- a trophy is a want "
                        .. "list entry, and a want list nobody can read is not one")
                    assert(row.locked and row.lockReason == "monster drop",
                        id .. " is on the rack unrefused, or refused by the wrong word: "
                        .. tostring(row.lockReason))
                    assert(not row.price, id .. " quotes a price on a tile nobody may press")
                end
            end
        end,
    },
    {
        -- CLASS LEVEL IS THE ONLY GATE, and this is the case that says so. The shelf has had gates come
        -- and go -- a quest count, a discipline, a price band, a discovery ledger -- and every one of
        -- them was removed by an argument rather than by anything going red, which is how the prose
        -- describing them outlived them by a year (see the comments this file's own header corrects).
        --
        -- So the set is pinned from the closed end: a row is out, or it is shut for one of exactly
        -- three reasons, and all three are answered by growing a class. "rung" reads the level
        -- directly. "class" reads it one step removed -- an earned discipline is itself unlocked by
        -- class levels. "monster drop" is the authored exception, and it is the only one that never
        -- opens.
        --
        -- A FOURTH REASON APPEARING HERE IS THE POINT. If somebody adds a gate, this reddens with its
        -- name in the message, and the decision to widen the rule gets made on purpose.
        name = "a shelf is shut for exactly three reasons, and every one of them is a class level",
        fn = function()
            local ALLOWED = { rung = true, class = true, ["monster drop"] = true }
            local player = Player.new()
            local seen, offenders = {}, {}
            for vendorId in pairs(Vendor.defs) do
                for _, row in ipairs(Vendor.stock(vendorId, 0, nil,
                    Class.unlockedSet(player), Class.levelSet(player))) do
                    if row.locked then
                        local why = row.lockReason
                        seen[why or "<nil>"] = true
                        if not ALLOWED[why] then
                            offenders[#offenders + 1] = row.id .. " (" .. tostring(why) .. ")"
                        end
                    else
                        -- An OPEN row must carry no reason at all: a tile that is buyable and also
                        -- explains why it is not would print the refusal under a price the player can
                        -- pay (ui/panels/shop.lua reads the two separately).
                        if row.lockReason then
                            offenders[#offenders + 1] = row.id .. " is open and still gives a reason"
                        end
                    end
                end
            end
            table.sort(offenders)
            assert(#offenders == 0, "a shelf row is shut for a reason that is not a class level: "
                .. table.concat(offenders, ", "))

            -- ...and the sweep really did walk shut rows of each kind, so a rack that quietly stopped
            -- locking anything cannot read as a pass (the green-on-nothing failure).
            assert(seen.rung, "no row anywhere was shut on the rung -- this sweep is not scanning")
            assert(seen["monster drop"], "no trophy was shut: they are stocked now and must be refused")
        end,
    },
    {
        -- THE SET IS CLOSED, from the other end. Without this, flagging a piece by accident -- or a
        -- tool pass writing the field -- makes a ware unbuyable at every counter in the game in
        -- silence, which is the failure the recut already shipped once in the other direction.
        -- (It no longer makes it INVISIBLE: since 2026-09-20 a trophy is stocked and greyed rather
        -- than absent. The flag still decides the money, which is what this set is guarding.)
        name = "nothing outside the named trophies carries the flag",
        fn = function()
            local named = {}
            for _, id in ipairs(TROPHIES) do named[id] = true end
            for id, def in pairs(Item.defs) do
                assert(not def.unstocked or named[id],
                    id .. " carries `unstocked` and is not a named trophy -- no counter in the game "
                    .. "will deal or buy one, and docs/drops.md says who is allowed to be")
            end
        end,
    },
    {
        name = "the ledger is stamped by an expedition ending, and rides the save",
        fn = function()
            local player = Player.new()
            assert(not Player.hasFound(player, "weapon_iron_sword"),
                "a fresh company has discovered something")

            -- Everything the company is holding, marked -- which is what both exits do now that a wipe
            -- surfaces with the haul as surely as the stair does.
            local id = anyFound()
            Player.grantItem(player, id)
            local added = Player.recordFound(player)
            assert(added > 0, "recordFound marked nothing at all")
            assert(Player.hasFound(player, id), id .. " was carried out and not recorded")

            -- Idempotent: surfacing twice with the same thing is one discovery.
            assert(Player.recordFound(player) == 0, "a second surfacing re-counted what was already known")

            local back = Save.restore(Save.snapshot(player))
            assert(Player.hasFound(back, id), id .. " did not survive a save round-trip")
        end,
    },
    {
        -- The load-bearing default: every save written before this existed has no ledger, and must load
        -- as a company that has discovered nothing rather than crashing or discovering everything.
        name = "a player with no ledger reads as having found nothing, and never errors",
        fn = function()
            assert(Player.hasFound(nil, "weapon_iron_sword") == false, "a nil player should read false")
            assert(Player.hasFound({}, "weapon_iron_sword") == false, "a ledgerless player should read false")
            assert(Player.recordFound(nil) == 0, "recordFound errored on a nil player")
        end,
    },
    {
        -- A DUPLICATE HAULED OUT MUST BE WORTH SOMETHING. Reading `price` alone here would have made
        -- every weapon, utility and piece of armor above the opener worth nothing at a counter the
        -- moment the recut took their prices off.
        name = "a found ware sells back, at half what it would be stocked at",
        fn = function()
            local id = anyFound()
            local instance = Item.instantiate(id)
            local value = Vendor.sellValue(instance)
            assert(value > 0, id .. " sells for nothing: a duplicate is unusable and unsellable")
            assert(value == math.floor(Vendor.foundPrice(Item.defs[id]) * 0.5),
                id .. " sells at " .. value .. ", off the half-of-stocked rate every other ware takes")
        end,
    },
}
