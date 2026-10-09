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
    -- The Giant Toad's (Gluttony's seat, 2026-09-25): its hop as a tank's greaves, which is how a body in
    -- plate stops being slow, and its swallow as a Barbarian's, beside the Bottomless Gut.
    "utility_bog_hopper_greaves", "ability_the_gullet",
    -- The Coin-Eaters' (Greed's approach, 2026-09-25): the scarab's roll made of bodies as a Fighter's,
    -- the mite's rusting hide as a Knight's coat, the Queen's egg laid in a foe as a Beastmaster's.
    "ability_gathering_roll", "armor_rustcoat", "ability_brood_sting",
    -- The dead of Greed's approach (2026-09-25, "The Dead Hand"): the dwarf skeleton's want, nerves, eyes and
    -- arrival; the kobold skeleton's offering; the wight's shroud, drift and touch; the ghoul's nails and
    -- bite; and Vesh's signature, raise, hand, ledger and call.
    "armor_hollow_helm", "utility_nerveless_bones", "utility_skull_lantern", "weapon_deep_delvers_pick",
    "ability_offering_bone", "utility_wights_shroud", "ability_through_the_rock", "ability_barrow_touch",
    "consumable_ghoul_nail_paste", "ability_ghouls_bite", "ability_foreclosure", "ability_raise_the_owing",
    "utility_the_dead_hand", "utility_ledger_of_the_lured", "ability_call_the_lured",
    -- The Paymaster's (Greed's approach, 2026-09-26, round 5 of "The Paymaster"): his Pay Out turned round,
    -- the company's own gold thrown at a tile -- a heap where nobody stands, a blow where a foe does.
    "ability_thrown_wages",
    -- The wyverns' (Gluttony's seat, 2026-09-23): the dive as a cloak, the cut as a hunter's ability, the
    -- flight's wind as a charm, the takeoff as an escape, and the carry as the Highwing's chase.
    "armor_plummet_cloak", "ability_gale_cut", "utility_tailwind_charm", "ability_skyward",
    "ability_bear_away",
    -- The Chimera's (Gluttony's seat, 2026-09-23): the lion's appetite as a Battlemage charm, and each
    -- head as a Beastmaster's -- a head you wear, earned by breaking that head.
    "utility_hearth_hunger", "utility_serpent_head", "utility_goat_head",
    -- The Thing Under the Seam's (Greed's seat, 2026-09-26): its lash as a mace that drags and burns, and
    -- its shadow as a mantle nothing past three tiles can aim through.
    "weapon_whip_of_flame", "utility_shadow_mantle",
    -- The Sabertooths' (Gluttony's approach, 2026-09-23): the ambush as a cloak, the pounce's critical as a
    -- charm, the appetite as a cord, and the Longfang's hunt as her own.
    "armor_stalkers_mantle", "utility_ambush_charm", "utility_trophy_cord", "utility_the_unbroken_stalk",
    -- The Dwarves' (Greed's keep, 2026-09-24): each body drops the trick it fights with -- the Delver's
    -- dive, the Hornblower's painted lead, the Goldsmith's leaf -- and the Thane his mithril.
    "ability_delve", "ability_fools_gold", "ability_gilders_leaf", "armor_mithril_shirt",
    -- The Gilt Wyrm's (2026-09-25): what a dwarf becomes at three Dragon-Sickness, and the saga it came out
    -- of -- Sigurd's sword, Fafnir's helm, the heart, the leaf, the breath and the otter's gold skin.
    "weapon_gram", "armor_aegishjalmur", "ability_wyrms_venom", "utility_lindworm_heart",
    "utility_linden_leaf", "utility_every_hair_covered",
    -- The Kobolds' (Greed's deeps, 2026-09-25): each body drops the trick it fights with -- the Skulker's
    -- footwork, the Trapwright's rock, the Broodkeeper's egg, the priest's borrowed fire -- and the
    -- Godling its own scale.
    "utility_scurry", "ability_deadfall", "ability_dragon_egg", "ability_borrowed_breath",
    "utility_godlings_scale",
    -- The Goblins' (Wrath, 2026-09-26): each body drops the trick it fights with -- the Cutter's throw, the
    -- Firebrand's feet, the Fanatic's spin, the Brute's burst, the Hexer's mist, the Redcap's cap and pike,
    -- the Bugbear's hood, the Hobgoblin's lash -- and the King the lever off his throne.
    "ability_toss", "utility_firewalkers_wraps", "ability_spin_out", "ability_bottled_rage",
    "ability_red_mist", "utility_dipped_cap", "weapon_redcaps_pike", "utility_ambushers_hood",
    "weapon_hobgoblins_lash", "ability_kings_lever",
    -- The Orcs' (Wrath, 2026-09-26): each body drops what it fights with, less the compulsion -- the Grunt's
    -- scars, the Berserker's streak twice (an axe and a utility), the Drummer's drum, the Blood-Caller's
    -- offering, the Handler's goad, the Pit-Fighter's belt, and the Warchief's torc and succession.
    "utility_orc_scars", "weapon_unbroken_axe", "utility_warpaint", "ability_marching_drum",
    "ability_blood_offering", "ability_goad", "utility_pit_fighters_belt", "utility_heirs_torc",
    "ability_the_strongest_leads",
    -- The Angels' (Pride, 2026-09-30): the Herald's trumpet, the Virtue's aegis, the Seraph's wing, the Ophan's
    -- wheel and the Throne's verdict.
    "utility_heralds_trumpet", "ability_virtues_aegis", "armor_seraphs_wing", "weapon_wheel_of_eyes",
    "ability_thrones_verdict",
    -- Superbia's, the Morning Star (Pride's general): her relic, her halo, her form, her Host and her Fall.
    "utility_the_morning_star", "armor_halo_of_the_morning", "armor_perfect_plate",
    "utility_mirror_of_the_morning", "ability_cocytus_wing",
    -- The Oni's (Wrath, 2026-09-27): the Oni's horn, the Greatblade's sword and stew, the Shadow's thread, the
    -- Priestess's bell, the Swordmaster's katana, the Twins' morning star and borrowed eyes, the General's dome.
    "utility_oni_horn", "weapon_odachi", "consumable_questionable_stew", "ability_steel_thread",
    "ability_purifying_bell", "weapon_instant_draw_katana", "weapon_morning_star", "utility_borrowed_eyes",
    "ability_black_flame_dome",
    -- SLOTH'S COLD, SLICE D (2026-10-04): the Yuki-onna's breath, the Snow Queen's splinter, the Mare's bridle.
    "utility_white_silence", "ability_splinter_of_the_mirror", "utility_mares_bridle",
    -- The Elves of Pride's approach (2026-09-30): the Retainer's livery, the Longbow's bow, the Bladedancer's veil,
    -- the Starcaller's sandals, the Highborn's circlet, the Elf-Lord's laurel.
    "armor_livery_of_the_house", "weapon_heartstring_longbow", "armor_dancers_veil", "armor_skywalkers_sandals",
    "utility_highborn_circlet", "utility_laurel_of_renown",
    -- The Vampires' (Wrath, 2026-09-26): the ghoul's vitae, the bat's whistle, the Fledgling's fang and scent,
    -- the Duelist's cloak, the Hemomancer's two spells, the Communicant's chalice, and the Sire's signet and box.
    "consumable_vitae", "ability_familiars_whistle", "weapon_hungering_fang", "utility_bloodhounds_scent",
    "armor_mistcloak", "ability_open_veins", "ability_boiling_blood", "utility_communion_chalice",
    "utility_sires_signet", "utility_box_of_grave_earth",
    -- ...and the Gorged's heart (2026-09-27): what it could not hold, worn as a shield.
    "utility_surfeit_heart",
    -- The Blood Countess's (Wrath's seat, 2026-09-27): her swap as a Duelist's, her spikes as a Knight's plate.
    "ability_the_waltz", "armor_iron_maiden",
    -- The Thousand-Winged's (Wrath's approach, 2026-09-27): the swarm's own flight, off its bats.
    "ability_swarm_form",
    -- The Minotaur's (Wrath's seat, 2026-09-27): its double axe as a Barbarian's, its charge as a Vanguard's.
    "weapon_labrys", "utility_bulls_brow",
    -- Furor's (2026-09-28): his arms as a move, the Colosseum's own piece, his arm, his stillness.
    "ability_thousand_hands", "ability_severing_blow", "utility_the_asuras_arm", "utility_tapas_beads",
    -- The djinn's (Pride's approach, 2026-09-30): the Djinni's gale, the Ifrit's coal, the Marid's tide; and the
    -- Wishmaker's (Pride's seat): the Last Lamp.
    "ability_djinnis_breath", "utility_ifrits_coal", "ability_marids_tide", "utility_the_last_lamp",
    -- The Faceless of Envy's seat, slice B (2026-10-03): the Doppelganger's, Mirror-Knight's, Colossus's, Mask-Maker's
    -- and the Water Mirror's.
    "ability_doppel_step", "armor_polished_shield", "armor_twofold_hauberk", "ability_faceless_retinue",
    "ability_still_water",
    -- Wrath's elementals' (the approach and the seat, 2026-09-28): each body's three rules, handed over one by one.
    "utility_flowwalkers_soles", "utility_heart_of_the_wildfire", "utility_coal_in_the_fist",
    "weapon_forked_rod", "utility_flashpan", "utility_static_coil",
    "ability_pyroclast", "utility_eruption_stone", "ability_ball_lightning",
    -- The Gold Golem's (Greed's approach, 2026-09-25): all three trophies, each one of its rules turned to
    -- work on every floor -- the pull as a lodestone, the hoard as a purse, the plates as ballast.
    "utility_lodestone", "utility_spilled_purse", "utility_golden_ballast",
    -- The Gilded King's (Greed's seat, 2026-09-26): the crown he wears, and the bread that starved him.
    "utility_the_gilded_crown", "ability_gilded_bread",
    -- Gula's (the wood's general, re-premised 2026-09-23): the beast's inhale as a druid's, and the rule
    -- that learns every blow as a hide. After the Maw on her drop list (Descent.DROPS.gluttony).
    "ability_draw_breath", "armor_studied_hide",
    -- Luxuria's (the fen's general, re-premised as the succubus Queen 2026-09-25): her escape as a
    -- Skirmisher's, a counter to her charm as an Alchemist's, and her old Rapture as a Priest's crowd drain.
    "ability_changing_partners", "utility_smelling_salts", "utility_saints_chalice",
    -- Avaritia's (the deeps' general, re-premised as an elder dragon 2026-09-25): her breath and her strafe
    -- as a Mage's (she carries the breath herself), her wings as a Skirmisher's, her melted gold and her
    -- ledger as a Mammonite's, her ground as a Bulwark's greaves. After the Gilded Belly on her list.
    "ability_dragonfire", "utility_wingbeat_mantle", "ability_gild", "armor_emberwalk_greaves",
    "ability_fire_from_the_sky", "utility_hoard_ledger",
    -- The Many Faced One's (Envy's general, slice F 2026-10-03): its split as a Ninja's, the answer to its masks
    -- as a Bombardier's. After the Pretender's Crown on its list.
    "ability_splitting_image", "consumable_unmasking_powder",
    -- The Sated's (Gluttony's seat, reworked 2026-09-23): the Retch as a Bombardier's, the Eat as a
    -- Barbarian's, the whole fight turned around as a Bulwark's coat, a devoured corpse as a
    -- Necromancer's, and being full as a Paladin's.
    "ability_bile_sac", "utility_bottomless_gut", "armor_distended_girth", "ability_second_helping",
    "utility_sated_charm",
    -- The flight's (Gluttony's approach, 2026-09-23): the hawk's bells as a Trapper's, and the Griffin's
    -- appetite and tithe as a Warbrewer's and a Beastmaster's.
    "utility_hawk_bells", "utility_gorgers_beak", "utility_tithe_feather",
    -- Pride's approach beasts and the Titan (2026-09-30): the Lioness's hold as a Hunter's, the Lion's roar as a
    -- Knight's coat, the Peacock-Basilisk's gaze as a Rogue's, and the Titan's chain as a Barbarian's.
    "utility_hold_the_quarry", "armor_golden_mane", "utility_peacocks_train", "weapon_titans_chain",
    -- Pride's one-off elites' (2026-09-30, "Pride's Bestiary"): the Unicorn's horn as an Exorcist's blade, the
    -- Sphinx's riddle as an Inquisitor's, the Phoenix's rising as a Priest's, the Tower-Giant's ambition as a
    -- Barbarian's maul.
    "weapon_horn_of_purity", "utility_sphinxs_riddle", "utility_phoenix_feather", "weapon_babel_maul",
    -- ENVY'S BESTIARY, slice E (2026-10-03): Leviathan's rising as an Elementalist's and its wake as a Vanguard's,
    -- Medusa's stare as a Shaman's, her hair as a Poisoner's and her mirror as an Artificer's, the Kinslayer's Mark
    -- as a Duelist's.
    "ability_undertow", "armor_leviathans_wake", "ability_gorgons_gaze", "armor_serpent_locks",
    "utility_hand_mirror", "utility_the_mark",
    -- SLOTH'S TOLLKEEPERS, SLICE F (2026-10-04): the Collector's pike as a Knight's, the Bailiff's bar as a Bulwark's,
    -- the Outrider's lance as a Vanguard's, Mora's ledger as a Mammonite's.
    "weapon_collectors_pike", "armor_bailiffs_bar", "weapon_passing_lance", "utility_toll_ledger",
    -- end SLOTH'S TOLLKEEPERS, SLICE F
    -- The sins' own payment (2026-10-01, "there can never be creature drops"): every general's relic and every
    -- lieutenant's piece left the creature bucket for a real shelf, as trophies -- the first entry on each
    -- Descent.DROPS list. Pride's Codex is reworked separately and is not named here.
    "utility_maw_of_the_unfed", "utility_larder_hook",           -- Gluttony: hunter, hunter
    "utility_reliquary_unbidden", "utility_beggars_bowl",        -- Lust: rogue, inquisitor
    "utility_gilded_belly", "utility_tally_stick",               -- Greed: mammonite, mammonite
    "utility_pretenders_crown", "utility_second_vessel",         -- Envy: alchemist; the Vessel was the stand-in's
    -- Livia's Glass left Envy's list with her (slice F, 2026-10-03) and stays a trophy on the alchemist's rack.
    "utility_envious_glass",
    "utility_the_broken_vow", "utility_anvils_face",             -- Wrath: monk, fighter
    "weapon_forsworn_pike", "utility_unblown_horn",              -- Sloth: knight, knight
    "utility_marginal_gloss",                                    -- Pride: mage
    -- SUBLIMITAS (2026-10-01): Pride's lieutenant, an elf archmage; her book is a Mage's trophy, not a
    -- creature's organ.
    "utility_codex_unanswered",
    -- THE FACELESS OF ENVY, SLICE A (2026-10-03, "Envy's Bestiary"): the soldier's face as a Ninja's, the
    -- Assassin's kills as an Assassin's, the Skin-Thief's flaying as a Thief's knife, the Champion's hand as a
    -- Duelist's mask.
    "ability_borrowed_face", "utility_hall_of_faces", "weapon_flaying_knife", "utility_mask_of_champions",
    -- ENVY'S SEAT, SLICE C (2026-10-03): the one-off families' -- the Homunculus's stone as an Apothecary's, the
    -- Brazen Head's last two words as a Theurge's and an Artificer's, the Echo's shell as a Spellbreaker's,
    -- Arachne's shuttle as a Theurge's, the Penitents' wire as an Inquisitor's.
    "utility_stone_heart", "ability_time_was", "utility_time_is_past", "utility_echoing_shell",
    "utility_weavers_shuttle", "utility_iron_thread",
    -- end ENVY'S SEAT, SLICE C
    -- SLOTH'S TROLLS (slice B, 2026-10-04): the troll's blood as an Apothecary's and its arm as a Plague Knight's,
    -- the toll as a Mammonite's tax, the Scarlord's club as a fighter's, and the Ogre's throw as a Barbarian's.
    "consumable_troll_blood", "utility_grafted_troll_arm", "utility_bridge_tax", "weapon_scarring_club",
    "ability_ogres_heave",
    -- end SLOTH'S TROLLS
    -- ENVY'S APPROACH ONE-OFFS (slice D, 2026-10-03): the Evil Eye's charm as an Exorcist's, the Mirage's trick as a
    -- Ninja's, the Patchwork's stitch as an Apothecary's, the Shade's lee as an Assassin's cloak, the Weighers' scale
    -- as an Inquisitor's, the Green-Eyed Monster's roar as a Barbarian's, and the eels' hide as a Skirmisher's boots.
    "utility_nazar", "ability_mirage_step", "ability_surgeons_thread", "armor_shade_cloak",
    "utility_scale_of_hearts", "ability_jealous_roar", "armor_eel_skin_boots",
    -- ENVY'S APPROACH, ROUND 4 (2026-10-06): the Wasting One's smile as a Plague Knight's, and the Pale Crone's leap
    -- as a Skirmisher's.
    "utility_the_thin_smile", "utility_thorned_staff",
    -- THE CROWN'S BESTIARY, SLICE B (2026-10-09): the Pit Imp's Offer as a Warlord's, the Chain Fiend's hook as a
    -- Trapper's, the Erinys's arrow as an Inquisitor's, the Balor's throes as a Bombardier's, and the Death
    -- Knight's bulwark as a Sentinel's plate.
    "ability_signed_in_blood", "ability_hook_and_drag", "ability_furys_verdict", "utility_last_breath",
    "armor_oathbound_plate",
    -- SLOTH'S BESTIARY, SLICE A (2026-10-04): the Ground Sloth's bank as a Monk's fist, the Old Sloth's hide as a
    -- Warden's, the yeti's roar as a Hunter's mantle, and the Dread's whiteout as a Ninja's cloak.
    "utility_sleepers_claws", "armor_hibernal_hide", "armor_yeti_hide_mantle", "armor_whiteout_cloak",
    -- end SLOTH'S BESTIARY, SLICE A
    -- SLOTH'S BESTIARY, SLICE C (2026-10-04): the Bog Bodies' spear as a Sentinel's, the Cairn-Keeper's stone as a
    -- Warlord's, the Frost Worm's note as a Shaman's, and the Noonday Demon's afternoon as an Inquisitor's charm.
    "weapon_peat_black_spear", "utility_cairn_stone", "ability_worms_trill", "utility_meridian_charm",
    -- SLOTH'S DREAMERS (slice E, 2026-10-04): the moth's cloud as an Apothecary's censer, Baku's charm as an
    -- Exorcist's ward, the Old Spruce's wood as a Druid's staff.
    "utility_poppy_censer", "utility_bakus_ward", "weapon_spruce_staff",
    -- SLOTH'S STAIRS, SLICE G (2026-10-04): the Sandman's sowing as a Trapper's and his hourglass as a Ninja's;
    -- Desidia's Long Sleep as a Knight's relic, her Drowse as a Warden's Lull, her sleepers' shades as a
    -- Necromancer's lantern, and the coat that refuses her sleep as a Knight's. Acedia's Pike and the Unblown Horn
    -- above left Sloth's lists and stay trophies on the knight's rack.
    "ability_sandmans_pouch", "utility_the_hourglass", "utility_the_long_sleep", "ability_lull",
    "utility_nightmare_lantern", "armor_restless_mail",
    -- end SLOTH'S STAIRS, SLICE G
    -- THE CROWN'S BESTIARY, SLICE E (2026-10-09): the Lethe-Drinker's cup as a Warden's, the Hungry Ghost's mouth as
    -- a Spellbreaker's, and all three of the Lernaean Hydra's: a Barbarian's hide, a Crusader's sear, a Poisoner's
    -- blood.
    "utility_cup_of_lethe", "utility_pinhole_mouth", "armor_two_heads", "ability_cauterise", "utility_hydras_blood",
    -- end THE CROWN'S BESTIARY, SLICE E
    -- THE CROWN'S BESTIARY, SLICE A (2026-10-09): the Lesser Archon's edge as a Battlemage's, the Greater Archon's
    -- beam as a Mage's, the Warden's post as a Sentinel's, and the Duke's Ascension as a Champion's.
    "utility_mana_edge", "ability_killing_magic", "utility_wardens_post", "utility_ascension",
    -- end THE CROWN'S BESTIARY, SLICE A
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
