-- BLOOD COURIER: the Familiar's rule (data/items/utility/utility_blood_courier.lua; Wrath's vampires,
-- 2026-09-26). What a familiar drinks is not its own: the drink goes to the NEAREST vampire on its side, which
-- resets its Thirst and heals it as if it had bitten -- or, for a familiar the company whistled up, it heals the
-- body that called it by the whole of the damage (models/thirst.lua's Thirst.drink reads the flag).
return {
    name = "Blood Courier",
    description = "What it drinks goes to the nearest vampire, as if that vampire had bitten. Whistled up, it heals whoever called it.",
    bloodCourier = true,
}
