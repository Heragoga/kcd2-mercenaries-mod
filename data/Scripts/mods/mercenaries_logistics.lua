-- Quartermaster logistics: the camp-management systems the quartermaster fronts,
-- all feeding one central MORALE stat (combat effectiveness, desertion and mutiny
-- read off it) plus food, drink, wages and upgrades. Save-persistent across camp
-- breaks. The numbers below are first-pass tunables. See
-- docs/quartermaster-logistics.md for the full model.

-- ==== Tunables ====
mercenaries.SecondsPerDay        = 86400
mercenaries.LogiEveningHour      = 18
mercenaries.FeedRatio            = 8           -- mercs fed per food unit/day (higher = supplies stretch further)

mercenaries.MoraleMin            = -100
mercenaries.MoraleMax            = 100
mercenaries.MoraleDecayPerDay    = 5           -- toward 0
mercenaries.MoraleLowWarnAt      = -20         -- "morale is low" text warning below this
mercenaries.MoraleDesertAt       = -70         -- mercs only start deserting below this (low-morale icon warns at -50 first)
mercenaries.MoraleMutinyAt       = -90         -- desertions escalate to hostile mutiny below this
mercenaries.MoraleTiredDrain     = 10          -- /day once out of camp > grace
mercenaries.MoraleStarveDrain    = 5           -- /day while starving
mercenaries.MoraleDrinkGain      = 10          -- /day while drink available
mercenaries.MoraleInnGain        = 10          -- /day while the inn stands
mercenaries.MoraleWageDrain      = 10          -- /day while unpaid
mercenaries.MoralePerKill        = 5
-- Morale GAIN from kills is uncapped: winning a big battle should feel like winning a big
-- battle, and the squad is already paying for it in the losses below.
-- Morale LOSS from deaths IS capped, per fight. Without a cap a disaster is unbounded - ten
-- dead is -50, twenty is -100, i.e. straight from any starting morale to mutiny in one
-- engagement, with no way back. The cap makes a massacre severe but survivable.
mercenaries.MoraleDeathCapPerFight = 50

-- Battlefield spoils, per confirmed kill: what you strip off the body.
-- Food is in the same units as everything else here - one unit feeds FeedRatio (8) mercs for
-- a day, so 3 units is a day's food for 24 men. Wages are groschen into the war chest, priced
-- as merc-days at the medium tier, so "2 wages" is two men paid for a day.
mercenaries.LootPerKillFood  = 3
mercenaries.LootPerKillDrink = 1
mercenaries.LootPerKillWages = 2               -- merc-days, converted at WagePerTier.medium
mercenaries.MoraleDeathPenalty   = 5           -- per merc that dies
mercenaries.TirednessGraceDays   = 3           -- days out of camp before tiredness bites (kept in step with ExhaustedBuffDays so the icon and the morale penalty line up)
mercenaries.StartingSupplyDays   = 3           -- days of food and drink handed out when the first camp goes up

mercenaries.DesertSecondsPerMerc = 86400       -- one desertion/mutiny per game-day of negative morale

mercenaries.FoodBuyCost          = 100
mercenaries.FoodBuyAmount        = 5
mercenaries.CofferDepositStep    = 500         -- groschen per "put money toward wages"
mercenaries.WagePerTier          = { weak = 5, medium = 10, strong = 20 }

-- Upgrades
mercenaries.UpgFoodCartCost      = 500
mercenaries.UpgFoodCartDays      = 10
mercenaries.UpgFoodCartFeeds     = 10          -- mercs covered per day while it stands
mercenaries.UpgInnCost           = 1000
mercenaries.UpgInnDays           = 3
mercenaries.UpgHunterCost        = 2000
mercenaries.UpgHunterFeeds       = 5           -- mercs fed per spot, forever, if >=2 in camp
mercenaries.UpgHunterMinCamp     = 2
mercenaries.UpgSmithyCost        = 3000
mercenaries.UpgSmithyPct         = 20
mercenaries.UpgAlchemyCost       = 3000
mercenaries.UpgPracticeCost      = 1000
mercenaries.PracticeMaxLevel     = 6
mercenaries.PracticePctPerLevel  = 8
mercenaries.UpgHouseCost         = 1000        -- swaps the player's tent for a hut
mercenaries.UpgTowerCost         = 100         -- TEMP: buying only enables aim-placing an archer tower (no persistence)
mercenaries.UpgArcherCartCost    = 300         -- TEMP: buying only enables aim-placing an archer cart (3 archers, no persistence)

mercenaries.UpgWallCost          = 2000        -- palisade around the camp; stays with this pitch

-- Combat buff tiers (net effectiveness %). LogiApplyBuffs picks the closest.
mercenaries.CombatBuffTiers = {
    { pct = -50, guid = "e5a10001-2c4b-4e6a-9f01-000000000001" },
    { pct = -25, guid = "e5a10002-2c4b-4e6a-9f01-000000000002" },
    { pct =  15, guid = "e5a10003-2c4b-4e6a-9f01-000000000003" },
    { pct =  30, guid = "e5a10004-2c4b-4e6a-9f01-000000000004" },
    { pct =  50, guid = "e5a10005-2c4b-4e6a-9f01-000000000005" },
    { pct =  75, guid = "e5a10006-2c4b-4e6a-9f01-000000000006" },
}
mercenaries.BuffAlchemy = "e5a10007-2c4b-4e6a-9f01-000000000007"
-- Every buff this system might have put on a merc (removed before re-applying).
mercenaries.AllLogiBuffs = {
    "e5a10001-2c4b-4e6a-9f01-000000000001", "e5a10002-2c4b-4e6a-9f01-000000000002",
    "e5a10003-2c4b-4e6a-9f01-000000000003", "e5a10004-2c4b-4e6a-9f01-000000000004",
    "e5a10005-2c4b-4e6a-9f01-000000000005", "e5a10006-2c4b-4e6a-9f01-000000000006",
    "e5a10007-2c4b-4e6a-9f01-000000000007",
    "c1d2e3f4-a5b6-47c8-9d0e-1f2a3b4c5d6e", "d2e3f4a5-b6c7-48d9-8e0f-2a3b4c5d6e7f", -- legacy
}

-- Food/drink item classes (any of these delivered gives 1 unit). Generated from
-- the vanilla item tables: food_type 3 = drink; food_type 1 = potion (excluded
-- from both); every other <Food> type (fruit/meat/bowel/vegetable/etc) = food.
mercenaries.FoodItemClasses = {
    "0251611c-74a0-43c9-9ac8-28a44bf1655d", "025f546b-7465-4070-a57d-e84852adc184", "02d9c556-6c40-4e5e-abab-48b2acc7287a", "06759b71-0814-4dbe-8306-003f21d724f5",
    "06787e37-2822-4180-9dda-6aa1a2d15707", "06be2a3d-4e05-4a78-85cd-33879cd669c9", "07029524-8385-4926-8fee-035db316d770", "0712d873-29bd-4fdd-8966-79aefb82c829",
    "082e5192-fff9-4637-aa64-e4785bfe34f8", "0b4e244a-e3de-4502-afd0-fb7fe309629a", "10ee7741-d121-4d3a-b342-d72920d6d90e", "14503d71-7b97-42a2-af4e-90dbc62b5fe7",
    "1472bcff-e6c8-41f2-8fa4-658410464238", "154a8471-b753-4f84-ac5f-d989c8532d02", "15674da0-110f-4a95-8adb-8e87696a16d8", "18694c4b-2c87-4e11-8790-5ffdc4df322e",
    "18ff9093-2cc4-4ab3-9f34-7cb0dd7cd30a", "19644921-6bb7-4342-be8d-dc235362d20b", "1ad779b6-1156-48c5-b5ea-b377cbcbd5ad", "1c2da556-488b-4a86-b22a-c42acb299938",
    "1d5c770a-4e82-4ec1-913a-ebdd9a05477b", "1d8ffd19-af12-4bd7-8afd-43b9b0348ade", "1df1ee61-0b44-4efd-bfa4-37efbcd4be42", "208362ca-1006-4821-8118-227e64143a3e",
    "20d7df96-9d99-4260-bb73-c5443aba5e63", "2140f040-4d49-4403-9137-5e1bf29dbe15", "21fbb699-2f08-4d6d-aebd-442c2406e865", "220fd40a-3990-4a34-b6de-eb4a6451539b",
    "2264f217-590e-4c0f-a4c6-f50c6532b9f6", "2264f217-590e-4c0f-a4c6-f50c6532b9ff", "239ea469-3237-48d8-af90-da7cdf4140dc", "2485a0f4-22b5-40d1-9025-b57345f08ce2",
    "2491e052-9676-4e69-a66c-123bc1006193", "2606aceb-9a94-4342-aa26-f6e6548a0be7", "265f4d46-a993-464f-8f84-919569aa6818", "26b67cb9-c283-49c3-ac2a-87a3ce38eb1f",
    "27795e53-68b1-4d05-9b02-ae1815c8095b", "295c54f8-76a3-42fa-8fe1-8f1ecb63576b", "29a4f58e-6e00-4f9c-9273-1a76e0eccff0", "2a10687c-b9ed-430c-bf7d-644ece4fc1e5",
    "2a10687c-b9ed-430c-bf7d-644ece4fc1ef", "2a2ac072-a7eb-42f5-8757-776c02647559", "2ac0499c-a18f-425f-ab8c-bc81eaa0142a", "2c78ec3d-c7ea-4326-9f9c-5536ea67a626",
    "2eeb7bf7-f0ac-4c46-9468-97c2f76cb254", "2eeb7bf7-f0ac-4c46-9468-97c2f76cb25f", "2f5a67c7-3298-44a9-bee4-106d42d3ce22", "2ffa5ff9-d5ed-44cb-b789-b62098383efd",
    "319a7fe7-1c5d-42fa-80cd-83126cb6eaff", "3590f22a-3fcf-441a-9774-6c3f87f6d190", "363b64a7-9005-45f2-9bea-4b5330159fe5", "373747b8-5225-41ba-b511-56526ff90a30",
    "38cafd4d-55a4-4121-bb3f-5b4815eaad03", "3bebc0b5-dcf8-4449-b37a-a5a362995826", "3c056762-3e14-471a-8f0e-8d57919fb9c4", "3c78b620-ca94-11e1-9b23-0800200c9a66",
    "4088cfbd-c7cc-46ba-9e68-8db8815932e3", "41acaacc-6a6d-4520-968c-329ac41054ad", "4240311f-d0ba-4d01-be4e-685cc75d1d4f", "43e66d17-75e5-4832-a511-48c77b8d4cb3",
    "4446bc26-efff-4117-b4f5-19ee9045847d", "44593169-7482-4293-80bc-01c3144e4fa2", "45f9883e-73b1-429f-a127-34fbfd7084aa", "470cfa96-9bf4-41ee-9c74-cf2a1176ce45",
    "4802fa80-37b4-4017-9ee2-7b48a83fe065", "490b5820-b717-4750-bca4-ae5e26eb7368", "4a3dc302-b035-44cc-a49b-9da912c28cc1", "4a6fa310-067a-404d-9813-bd1761d1c70d",
    "4c5a74d8-92b1-4c78-bdef-6c19a762e062", "4d1d646c-ce45-434b-96ae-cfa27b86b4b6", "4dab452b-7f35-4cd9-942f-f59fd14c83fe", "4eed0a2b-1233-40b4-88f5-7f67de916b58",
    "51555071-7c55-4da1-9b61-ee3c14fde18b", "537ef442-be44-4e97-85a4-cc02344d8a5e", "5459ce70-3c48-402f-9f59-98e2594328e8", "55537a99-41ba-4497-925c-a543ced248e3",
    "5585da96-12c9-478d-a1a2-d5f206d9fe72", "56271b31-57c1-443a-8d97-9524ee2a8240", "5690cb19-872c-4b84-a437-d40d96b0ee51", "5a3a64c0-d3ee-4be1-b070-543de4a678f1",
    "5a3e8ba3-e413-4167-b5de-16471793f4ab", "5c0981cd-1c99-4690-8e54-29dbfc315c1d", "5c974431-58ce-4717-bd13-e457a83e8383", "5d87431e-03bd-4ae3-b73a-8ddb52a9af51",
    "5dceabb5-aef0-4bf5-b401-acbc30a44e21", "5e5514d7-e603-4634-b4d7-e1801010f398", "5f02ef0d-0551-44b1-902c-c96a8650d01d", "5f9951e9-2b3d-4bfb-aaa7-0b5cada6d116",
    "5ff91d0f-e525-4b37-9256-d8fea8be1c8d", "61cc4ee1-3066-4203-b331-0268c77ebb82", "661cee65-b667-46d4-9cf8-8bd3dafe5fdd", "667f27c6-9994-4517-b839-9c53a932c526",
    "68d9f225-030a-43c0-83b3-c4bc57568581", "6a324aa9-a566-406c-a3f8-6c416a00b399", "6c6d9f9a-a6fe-48d2-a1df-e939301db3c7", "6f1d0e9e-d532-4476-af7a-e24ea01da040",
    "71940f4a-de33-4473-9006-c371f1a62ad5", "72fc5bfd-fade-43f1-8edc-dd3880de59d8", "74bc6c64-73f9-4128-bbc1-3da5894cc28a", "76fd4ad3-84e2-444c-9822-b67c4adbc349",
    "7899825d-ed6f-4f00-b698-649ba652cf6d", "78dca400-f504-42ff-a02b-700018f39993", "7ae2e77b-bdae-46cb-b6ac-f532cf225748", "7d273b3b-b9dc-405c-a003-92c7b087a067",
    "81358847-cc24-4036-aa0f-99f180cd4ecc", "81c21fdc-3d62-4d1f-854f-eb364db1bcff", "8438f1a0-18c2-4a47-89c6-bf3f00bcae67", "84fb8a3d-fa6d-4b01-a354-f0ac110a3536",
    "86e4ff24-88db-4024-abe6-46545fa0fbd1", "8a0bfe8a-ff7d-4059-bb6f-ae062fb00d9a", "8ae96c33-8557-4410-8401-2c2e40d00e36", "8d6964b1-b645-4aa1-adcc-db22646f3722",
    "8dd487d6-de84-450e-9179-d68019395734", "8e9bbf5f-a334-4859-9e1b-8da270ddb4b5", "8f882709-5192-4c95-bf1f-d44fb8ffd214", "8fdb519f-51a4-4531-a20e-732065dd1ede",
    "907a2cd5-2730-424e-bf11-ef1f2db8f7e1", "90bc395d-39ee-460a-a658-f434ed2df760", "9173874c-7494-42ee-8965-a0d12d673945", "9373471a-28cd-4719-a343-4669dd501a0a",
    "94f31361-094b-4f8a-ad6c-dbf357c98d74", "95328452-30e4-46b9-a90b-195c67708e52", "953b8e18-bf41-477a-91f3-8c261c684f45", "961d80db-9847-4c65-aa1e-3b2366d66068",
    "991b9519-d017-42aa-96ab-8b7c9b805e10", "99ae492a-33aa-434c-96f5-c34ce2fd1a51", "9aa61103-1bf1-ed91-5642-939c5307cf06", "9bf17d06-8f2c-4b00-af30-5571fc2bfb0a",
    "9cd4c555-9e0c-468e-8829-a62a93dda80c", "9dd42af6-e0e0-42e8-81e8-fff02f8d1579", "9e06cfd7-6412-446c-99dc-e27c6bcef003", "9eb8db52-658e-48e6-a146-7b6efa510ece",
    "a0a6a756-e204-4943-b215-543471b5cc39", "a30e5fae-634b-4a97-8a16-f06ad72a0b7f", "a3483b1b-bef2-402e-906f-0c2fd4917f49", "a574386e-ea5d-4b94-a655-663b2381eded",
    "a7f3105b-4529-4507-8968-1f0ed512af2f", "a8a2dd92-f182-4311-a9ee-a8a667c335c1", "aaad7362-ec12-4e22-885c-075450001468", "ab3fcd8d-874a-4710-b6ce-7f249b706fb6",
    "ae1bbf2f-6bee-4e7d-82a0-5cd898ab8718", "b1de7a91-1644-4ad6-b186-a5b40764be7f", "b2f8f5e3-8e5e-4600-a4bb-be17e2d4a058", "b3e363cf-8dde-4733-89a9-c468d5580d2e",
    "b3ea937c-5912-45ee-96c6-9331289407f0", "b7ee311c-736b-4f7c-987b-8431ce3b5600", "ba4b74ad-f8f1-427e-905b-1bc8c27163e7", "bc26419a-f9d5-40bb-98f0-05b6c527e85a",
    "c191701b-3ad1-43ff-b4d1-4e56c9d95dda", "c27e73bd-05db-42c5-963e-09c42395160a", "c352d8ae-4021-4f9b-b49c-b1f087f2cd2c", "c6d9387a-30de-469a-a785-3220bf0426ba",
    "c888acac-26ef-4f4a-be33-0b8bd82e7500", "ca873759-2d0d-4f2f-ba05-49b6c1872a9e", "cd36244d-4785-4353-ab84-9ea4aea50b61", "ce4f5692-581d-401a-8479-0c55658d77a8",
    "cfe1c8ad-3788-45c3-8b89-7217c7529802", "d031224d-34c3-4f2b-98f7-d77789a309c2", "d2ffc509-509f-4db0-81b6-ad5311231e10", "d69c08d2-3631-4301-9107-018696c775a5",
    "d7248e1e-64dd-4d38-8049-826eb2fb39d0", "db357169-2012-4c12-b82b-d021cd4c8d9f", "db66940d-09bc-4450-8df9-8268e52e4ac2", "dc4dde5d-2196-41dd-8c5f-1ae94365fe23",
    "dede8ec9-3f0e-4c07-975f-320a7cc72452", "e19d0a82-e5cc-49b2-b0a2-14b004cb4717", "e1cc4970-df00-4fec-b831-976b753fd73f", "e9170235-1d45-465b-bdec-a5599605e15e",
    "ea84be32-b3fc-4dfa-8dab-7169bd9e441d", "ed346ec4-7db7-4fdc-9cf5-c2a90f6afa3a", "ef881d5c-0490-402c-b39f-79daa80c0471", "f0c9f56f-cd0f-4973-bfb5-3cea3e756bcc",
    "f2e16499-8a27-4acc-a4af-f29e00300507", "f2ee05db-430c-4505-8b39-ce658fb4bb74", "f6ede291-0b47-4dab-85bf-c507ad0e90a7", "f93c9156-efa1-4712-bb48-3ce5d50962bb",
    "fa79bacf-3838-4028-8f91-3e89712c0c64", "fbb641e5-a1a0-43ba-bfa8-c411bfa79f46", "fc1ce409-2815-4b44-be8d-01097702ae0f", "fddaec6e-f86d-41fe-8d58-86a816cc9f91",
    "ff25cae9-7182-4d55-bbb0-0706404e5b69", "ff44440b-aeeb-409a-9830-4f29d7feabbf",
}

mercenaries.DrinkItemClasses = {
    "01d468fe-0fe8-4bb3-9bcc-e8abcbb9e9a4", "0b2fcda5-11d1-46c4-9336-67f433136fbf", "0cb47176-06c5-42a9-8d70-969e917eb999", "0cfe3456-8eee-4cf5-bbaf-b632e3879be7",
    "125ce7ce-2289-4419-a8cc-a4675bfb83c1", "18920886-b5cf-45a6-86f9-eb92268f48bc", "2529e246-6f1b-4529-8d6b-64245207bae8", "27144e47-00aa-468e-a81b-49cb3b248b07",
    "38df365c-a4bb-462b-80cc-eb92f16930fa", "390c0dc8-23fd-42a0-91f2-a4d42f96a387", "3a6936e1-cb05-4c4c-b6f6-379322c13c93", "448d0ea2-c3b4-42ed-aadb-95bddecd206a",
    "52afd6fa-9377-457c-83a2-b5b39321a4dc", "573f381a-884a-4afd-b7f9-5d13342decbf", "5afcf991-f1ce-48f6-8188-71710835e538", "5eb8af37-0db9-43f9-b6fd-d3d428b8ef6b",
    "5f4b1982-77c8-4d6a-a3b1-e3aa5ee499cc", "60fa1492-0a52-48b5-8134-787453cdbcd3", "78c516d4-f64c-4d26-b59a-7a6a793632f4", "7c5126cd-b010-4484-8465-22a3d69fa0df",
    "856c0dc8-23fd-23a0-91f2-a4d42f96a946", "856c0dc8-23fd-43a0-91f2-a4d42f96a946", "856c0dc8-23fd-57a0-91f2-a4d42f96a946", "856c0dc8-23fd-82a0-91f2-a4d42f96a946",
    "856c0dc8-23fd-85a0-91f2-a4d42f96a458", "856c0dc8-23fd-85a0-91f2-a4d42f96a547", "856c0dc8-23fd-85a0-91f2-a4d42f96a841", "856c0dc8-23fd-85a0-91f2-a4d42f96a946",
    "856c0dc8-23fd-95a0-91f2-a4d42f96a946", "86e325c8-9104-4e55-9c2c-8797f29ffc58", "8eee3594-8fe9-4eb0-8971-07bfe8643898", "8f9a404d-3c13-4abb-91f7-7d111fe93782",
    "93595b3f-64b1-411b-bd7d-79518aff3e35", "9872a67f-e235-4641-913a-737681f52870", "99f1aec0-1f14-4006-ac1d-5614b28c5ba4", "a0ab454f-2935-4744-8115-53aafe17d66b",
    "a19f631a-cde3-49fa-97c8-8dc7ef8eab03", "a9ae4ee2-b096-423f-8ac7-c375acc17bec", "aa3286d9-2f20-43e9-a492-ade194ef62f4", "b13717cf-c4d0-4e79-9f56-cb0fecc26eaf",
    "bc8759ad-fc9b-4577-88a4-2008dbda647f", "c4e0a19f-43d8-4b8a-aa83-25f919e69a8b", "c64b7286-07b8-4bdf-afd0-359171d35249", "c93e2332-2902-4d88-bdb1-cde721a77d9b",
    "ca5a0aa3-e373-48ec-96e4-1c3b9907bac3", "d896e858-2a93-48bc-8c55-81eee57f82a6", "dea2883f-6bd9-4f6e-bae8-80322d428652", "e1cfd45b-f055-41ad-9393-2609cfd0d3b8",
    "ebec6979-8181-491e-b28a-8252f9d782f5", "ee4d5b06-0a7e-4073-969b-b11131e97fef", "f31650f8-cf73-4c97-85dc-2860c212b339", "f6713b92-f35e-4b86-bd7a-02eeac968295",
    "f831eca7-ee22-4d69-b08e-ce701e09eb9e",
}

-- ==== In-memory state ====
function mercenaries:LogiState()
    if not _G.MercLogi then
        _G.MercLogi = {
            morale = 0,
            tiredness = 0,
            food = 0, drink = 0,
            starving = false, drinkAvailable = false, innActive = false, unpaid = false,
            wagesWithheld = false, coffer = 0,
            foodCartDays = 0, innDays = 0, hunterSpots = 0,
            hasSmithy = false, hasAlchemy = false, hasPracticeYard = false, hasHouse = false, trainLevel = 0,
            lastUpkeepDay = nil, lastTick = nil,
            -- runtime combat tracking
            lastAliveCount = nil, selfRemoved = 0, desertProgress = 0,
            engaged = {}, fightDeathMorale = 0, fightLootKills = 0, wasInFight = false,
            buffApplied = {}, warnLevel = 0,
        }
    end
    return _G.MercLogi
end

-- ==== Time / squad helpers ====
function mercenaries:LogiNow()
    local ok, t = pcall(function() return Calendar.GetWorldTime() end)
    if ok and type(t) == "number" then return t end
    return 0
end
function mercenaries:LogiUpkeepDay()
    return math.floor((self:LogiNow() - self.LogiEveningHour * 3600) / self.SecondsPerDay)
end
function mercenaries:LogiAliveCount()
    local n = 0
    for _, ent in pairs(self.ActiveMercs) do
        if ent and self:IsAliveAndWell(ent, true) then n = n + 1 end
    end
    return n
end
function mercenaries:LogiCountByTier()
    local c = { weak = 0, medium = 0, strong = 0, total = 0 }
    for name, ent in pairs(self.ActiveMercs) do
        if ent and self:IsAliveAndWell(ent, true) then
            local tier = self:GetTierFromName(name) or "weak"
            c[tier] = (c[tier] or 0) + 1
            c.total = c.total + 1
        end
    end
    return c
end
function mercenaries:LogiWageTotal()
    local c = self:LogiCountByTier()
    return c.weak * self.WagePerTier.weak + c.medium * self.WagePerTier.medium + c.strong * self.WagePerTier.strong
end

-- ==== Morale / buffs ====
-- Every adjustment is logged with its reason (skipping the sub-0.1 continuous
-- drift deltas so the log isn't spammed each tick).
function mercenaries:LogiAddMorale(delta, reason)
    local L = self:LogiState()
    local before = L.morale
    L.morale = math.max(self.MoraleMin, math.min(self.MoraleMax, before + delta))
    -- Log only when whole-number morale moves, so ~0.1/tick drift doesn't flood
    -- the log; discrete events (kills, deaths, upkeep) still cross an integer.
    local bi, ai = math.floor(before + 0.5), math.floor(L.morale + 0.5)
    if bi ~= ai then
        System.LogAlways(string.format("[Logistics] Morale %d -> %d (%s)",
            bi, ai, tostring(reason or "?")))
    end
end

-- Adjust a numeric stock field (food/drink/coffer) and log it with a reason.
function mercenaries:LogiAdjust(field, delta, reason)
    local L = self:LogiState()
    local before = L[field] or 0
    L[field] = before + delta
    System.LogAlways(string.format("[Logistics] %s %+d (%s): %d -> %d",
        field, delta, tostring(reason or "?"), before, L[field]))
end

-- Net squad combat effectiveness %, folding morale, smithy, training and starving.
function mercenaries:LogiCombatPct()
    local L = self:LogiState()
    local pct = 0
    -- Morale swings effectiveness both ways: +50% at full morale, and a slight
    -- debuff as it goes negative (~-25% by -50, where the low-morale icon shows;
    -- desertions only start at -70). Positive and negative scale the same, 0.5%/pt.
    pct = pct + L.morale * 0.5
    if L.hasSmithy then pct = pct + self.UpgSmithyPct end
    if L.hasPracticeYard then pct = pct + (L.trainLevel or 0) * self.PracticePctPerLevel end
    if L.starving then pct = pct - 50 end
    return pct
end

function mercenaries:LogiCombatBuffGuid(pct)
    if pct > -10 and pct < 10 then return nil end
    local best, bestDist
    for _, tier in ipairs(self.CombatBuffTiers) do
        local d = math.abs(tier.pct - pct)
        if not bestDist or d < bestDist then best, bestDist = tier.guid, d end
    end
    return best
end

-- Applies the combat tier + alchemy buff to each merc, only touching a soul when
-- its applied signature changes (so it's cheap every tick and new mercs inherit
-- the current state).
function mercenaries:LogiApplyBuffs()
    local L = self:LogiState()
    local guid = self:LogiCombatBuffGuid(self:LogiCombatPct())
    local sig = tostring(guid) .. (L.hasAlchemy and "|al" or "")
    L.buffApplied = L.buffApplied or {}
    for name, ent in pairs(self.ActiveMercs) do
        if ent and ent.soul and L.buffApplied[name] ~= sig then
            pcall(function()
                for _, g in ipairs(self.AllLogiBuffs) do ent.soul:RemoveAllBuffsByGuid(g) end
                if guid then ent.soul:AddBuff(guid) end
                if L.hasAlchemy then ent.soul:AddBuff(self.BuffAlchemy) end
            end)
            L.buffApplied[name] = sig
        end
    end
end

-- ==== Persistence ====
mercenaries.LogiLastSaved = {}
function mercenaries:LogiSaveField(tag, val)
    val = tostring(val)
    if self.LogiLastSaved[tag] == val then return end
    self.LogiLastSaved[tag] = val
    self:SaveString(tag, val)
end
function mercenaries:LogiSave()
    local L = self:LogiState()
    self:LogiSaveField("QMMorale", tostring(math.floor(L.morale + 0.5)))
    self:LogiSaveField("QMTiredness", tostring(math.floor(L.tiredness / 300) * 300))
    self:LogiSaveField("QMFood", L.food)
    self:LogiSaveField("QMDrink", L.drink)
    self:LogiSaveField("QMStarving", L.starving and 1 or 0)
    self:LogiSaveField("QMDrinkAvail", L.drinkAvailable and 1 or 0)
    self:LogiSaveField("QMWagesWithheld", L.wagesWithheld and 1 or 0)
    self:LogiSaveField("QMUnpaid", L.unpaid and 1 or 0)
    self:LogiSaveField("QMCoffer", L.coffer)
    if L.lastUpkeepDay ~= nil then self:LogiSaveField("QMLastUpkeepDay", L.lastUpkeepDay) end
    self:LogiSaveField("QMFoodCartDays", L.foodCartDays)
    self:LogiSaveField("QMInnDays", L.innDays)
    self:LogiSaveField("QMHunterSpots", L.hunterSpots)
    self:LogiSaveField("QMSmithy", L.hasSmithy and 1 or 0)
    self:LogiSaveField("QMAlchemy", L.hasAlchemy and 1 or 0)
    self:LogiSaveField("QMPractice", L.hasPracticeYard and 1 or 0)
    self:LogiSaveField("QMHouse", L.hasHouse and 1 or 0)
    self:LogiSaveField("QMTrainLevel", L.trainLevel)
end
function mercenaries:LogiLoad()
    local L = self:LogiState()
    local function num(tag, d) local s = self:LoadString(tag); return (s and tonumber(s)) or d end
    L.morale          = num("QMMorale", 0)
    L.tiredness       = num("QMTiredness", 0)
    L.food            = num("QMFood", 0)
    L.drink           = num("QMDrink", 0)
    L.starving        = num("QMStarving", 0) == 1
    L.drinkAvailable  = num("QMDrinkAvail", 0) == 1
    L.wagesWithheld   = num("QMWagesWithheld", 0) == 1
    L.unpaid          = num("QMUnpaid", 0) == 1
    L.coffer          = num("QMCoffer", 0)
    local up          = self:LoadString("QMLastUpkeepDay"); L.lastUpkeepDay = up and tonumber(up) or nil
    L.foodCartDays    = num("QMFoodCartDays", 0)
    L.innDays         = num("QMInnDays", 0)
    L.hunterSpots     = num("QMHunterSpots", 0)
    L.hasSmithy       = num("QMSmithy", 0) == 1
    L.hasAlchemy      = num("QMAlchemy", 0) == 1
    L.hasPracticeYard = num("QMPractice", 0) == 1
    L.hasHouse        = num("QMHouse", 0) == 1
    L.trainLevel      = num("QMTrainLevel", 0)
    L.innActive       = L.innDays > 0
    L.lastTick = self:LogiNow()          -- not persisted (see comment in LogiTick)
    L.lastAliveCount = self:LogiAliveCount()
    L.selfRemoved = 0; L.desertProgress = 0; L.engaged = {}; L.fightDeathMorale = 0; L.fightLootKills = 0; L.wasInFight = false
    L.buffApplied = {}
    self.LogiLastSaved = {}
    self:LogiApplyBuffs()
    System.LogAlways(string.format("[Logistics] Loaded: morale=%d food=%d drink=%d coffer=%d upgrades(cart=%d inn=%d hunt=%d smithy=%s alch=%s yard=%s L%d)",
        math.floor(L.morale), L.food, L.drink, L.coffer, L.foodCartDays, L.innDays, L.hunterSpots,
        tostring(L.hasSmithy), tostring(L.hasAlchemy), tostring(L.hasPracticeYard), L.trainLevel))
end

-- ==== Tiredness (drives morale, not its own desertion clock) ====
function mercenaries:LogiUpdateTiredness(dt)
    local L = self:LogiState()
    self:Recount()
    local count = _G.MercCount or 0
    if _G.MercenariesDismissed or count <= 0 then
        L.tiredness = 0
        return
    end
    if self.CampActive then
        -- rest in camp: tiredness bleeds off fast (half a day clears the grace)
        L.tiredness = math.max(0, L.tiredness - 6 * dt)
    else
        L.tiredness = L.tiredness + dt
    end
end

-- ==== Kills / deaths ====
function mercenaries:LogiTrackCombat()
    local L = self:LogiState()

    -- Who we are engaged with is worked out FIRST, so the fight-start reset happens before
    -- this tick's deaths are counted. With the reset further down, a merc who died in the
    -- opening tick of a battle was charged against the PREVIOUS fight's cap - which, if that
    -- fight had already maxed out, meant his death cost nothing at all.
    -- armed only: CachedEnemies also holds hostiles who haven't drawn yet (they are aggro
    -- sources, not a fight in progress).
    local nowEngaged = {}
    for _, entry in ipairs(self.CachedEnemies or {}) do
        if entry.wuid and entry.armed then nowEngaged[tostring(entry.wuid)] = entry.wuid end
    end
    local anyLive = next(nowEngaged) ~= nil
    if anyLive and not L.wasInFight then
        L.fightDeathMorale = 0           -- new fight - reset the per-fight loss cap
        L.fightLootKills   = 0           -- ...and the spoils tally the after-action report reads
    end

    -- Deaths: a drop in the live count that we didn't cause ourselves. Capped per fight.
    local alive = self:LogiAliveCount()
    if L.lastAliveCount == nil then L.lastAliveCount = alive end
    if not _G.MercenariesDismissed then
        local drop = L.lastAliveCount - alive - (L.selfRemoved or 0)
        if drop > 0 then
            local want = self.MoraleDeathPenalty * drop
            local room = self.MoraleDeathCapPerFight - (L.fightDeathMorale or 0)
            local loss = math.min(want, math.max(0, room))
            if loss > 0 then
                self:LogiAddMorale(-loss, drop .. " merc death(s)")
                L.fightDeathMorale = (L.fightDeathMorale or 0) + loss
            end
        end
    end
    L.selfRemoved = 0
    L.lastAliveCount = alive

    -- Kills: enemies we were engaged with that are now confirmed dead.
    -- Confirm deaths among previously-engaged enemies.
    for wstr, wuid in pairs(L.engaged or {}) do
        if not nowEngaged[wstr] then
            local dead = false
            pcall(function()
                local e = XGenAIModule.GetEntityByWUID(wuid)
                if e and e.actor and e.actor.IsDead and e.actor:IsDead() then dead = true end
            end)
            if dead then
                -- Uncapped: MoraleMax already bounds the total, so a big win simply pushes
                -- toward it instead of stopping dead after four kills.
                self:LogiAddMorale(self.MoralePerKill, "enemy killed")
                self:LogiLootKill()
            end
        end
    end
    L.engaged = nowEngaged

    -- Falling edge: the last man we were engaged with is down. Report the spoils and, more
    -- to the point, what they bought - supplies only mean anything as DAYS.
    if L.wasInFight and not anyLive and (L.fightLootKills or 0) > 0 then
        self:LogiAfterActionReport()
    end
    L.wasInFight = anyLive
end

-- Strip a body. Deliberately NOT capped like the morale gain: morale is capped so one big
-- battle cannot bank a fortnight of goodwill, whereas supplies scale with bodies because
-- that is the point - a long fight should keep the squad fed.
function mercenaries:LogiLootKill()
    local L = self:LogiState()
    L.fightLootKills = (L.fightLootKills or 0) + 1

    if self.LootPerKillFood  > 0 then self:LogiAdjust("food",  self.LootPerKillFood,  "battlefield spoils") end
    if self.LootPerKillDrink > 0 then self:LogiAdjust("drink", self.LootPerKillDrink, "battlefield spoils") end

    local coin = self.LootPerKillWages * (self.WagePerTier.medium or 10)
    if coin > 0 then self:LogiAdjust("coffer", coin, "battlefield spoils") end

    -- Fresh supplies clear the starving / no-drink flags the same way a delivery does.
    self:Recount()
    local need = math.max(1, math.ceil((_G.MercCount or 0) / self.FeedRatio))
    if L.starving and L.food >= need then L.starving = false end
    if not L.drinkAvailable and L.drink >= need then L.drinkAvailable = true end
    self:LogiSave()
end

-- After-action report: how long the squad is now provisioned for. Wage runway counts the war
-- chest plus the player's purse, exactly as LogiAskStats does, because both get spent on payday.
function mercenaries:LogiAfterActionReport()
    local L = self:LogiState()
    local wageDay = self:LogiWageTotal()
    local money = 0; pcall(function() money = player.inventory:GetMoney() end)
    local runway = (wageDay > 0) and math.floor(((L.coffer or 0) + money) / wageDay) or 999

    self:LogiInfo("@merc_n_spoils " .. (L.fightLootKills or 0)
        .. " @merc_n_food "  .. L.food  .. " @merc_n_days " .. self:LogiSupplyDays(L.food)
        .. " @merc_n_drink " .. L.drink .. " @merc_n_days " .. self:LogiSupplyDays(L.drink)
        .. " @merc_n_cnow "  .. (L.coffer or 0) .. " @merc_n_wdays " .. runway)

    System.LogAlways(string.format(
        "[Logistics] after-action: %d kill(s) looted; food %d (%dd), drink %d (%dd), chest %d (%dd of wages)",
        L.fightLootKills or 0, L.food, self:LogiSupplyDays(L.food),
        L.drink, self:LogiSupplyDays(L.drink), L.coffer or 0, runway))
    L.fightLootKills = 0
end

-- ==== Continuous morale rates ====
function mercenaries:LogiMoraleTick(dt)
    local L = self:LogiState()
    self:Recount()
    if _G.MercenariesDismissed or (_G.MercCount or 0) <= 0 then return end
    local inCamp = self.CampActive
    local rate = 0
    local why = {}
    if (not inCamp) and (L.tiredness / self.SecondsPerDay) > self.TirednessGraceDays then
        rate = rate - self.MoraleTiredDrain; table.insert(why, "tired -" .. self.MoraleTiredDrain)
    end
    if L.starving then rate = rate - self.MoraleStarveDrain; table.insert(why, "starving -" .. self.MoraleStarveDrain) end
    if L.drinkAvailable then rate = rate + self.MoraleDrinkGain; table.insert(why, "drink +" .. self.MoraleDrinkGain) end
    if L.innActive then rate = rate + self.MoraleInnGain; table.insert(why, "inn +" .. self.MoraleInnGain) end
    if L.unpaid then rate = rate - self.MoraleWageDrain; table.insert(why, "unpaid -" .. self.MoraleWageDrain) end
    -- passive drift toward 0 (negative only recovers while camped)
    if L.morale > 0 then rate = rate - self.MoraleDecayPerDay; table.insert(why, "decay -" .. self.MoraleDecayPerDay)
    elseif L.morale < 0 and inCamp then rate = rate + self.MoraleDecayPerDay; table.insert(why, "camp recovery +" .. self.MoraleDecayPerDay) end
    self:LogiAddMorale(rate * (dt / self.SecondsPerDay), "drift/day: " .. (rate ~= 0 and table.concat(why, ", ") or "none"))

    -- Warnings on the way down.
    local lvl = 0
    if L.morale <= self.MoraleMutinyAt then lvl = 2
    elseif L.morale < self.MoraleLowWarnAt then lvl = 1 end
    if lvl > (L.warnLevel or 0) then
        if lvl == 1 then Game.SendInfoText('merc_logi_morale_low', false, 0, 4)
        elseif lvl == 2 then Game.SendInfoText('merc_logi_morale_mutiny', false, 0, 4) end
    end
    L.warnLevel = lvl
end

-- ==== Desertion / mutiny (driven by negative morale) ====
function mercenaries:LogiRemoveOneMerc(mutiny)
    for _, tier in ipairs({ "weak", "medium", "strong" }) do
        for name, ent in pairs(self.ActiveMercs) do
            if ent and self:IsAliveAndWell(ent, true) and (self:GetTierFromName(name) or "weak") == tier then
                local L = self:LogiState()
                if L.buffApplied then L.buffApplied[name] = nil end
                self.ActiveMercs[name] = nil
                L.selfRemoved = (L.selfRemoved or 0) + 1
                System.LogAlways(string.format("[Logistics] Merc %s (%s) %s - reason: morale %d %s",
                    tostring(name), tier, mutiny and "MUTINIED" or "deserted", math.floor(L.morale),
                    mutiny and "(<= mutiny threshold)" or "(<= desertion threshold)"))
                pcall(function() System.RemoveEntity(ent.id) end)
                if mutiny then
                    -- The merc turns on you: reappears as a hostile renegade in
                    -- the current squad's colours.
                    pcall(function()
                        self:SpawnRenegade(1, _G.MercCurrentOutfit or 1, tier, _G.MercCurrentWeapon or 1)
                    end)
                end
                self:Recount()
                return true
            end
        end
    end
    return false
end

function mercenaries:LogiDesertionTick(dt)
    local L = self:LogiState()
    -- Nobody leaves until morale sinks below the desertion threshold (-50). Above
    -- that a low-morale squad just fights a bit worse (see LogiCombatPct).
    if L.morale > self.MoraleDesertAt or _G.MercenariesDismissed or (_G.MercCount or 0) <= 0 then
        L.desertProgress = 0
        return
    end
    L.desertProgress = (L.desertProgress or 0) + dt
    while L.desertProgress >= self.DesertSecondsPerMerc do
        L.desertProgress = L.desertProgress - self.DesertSecondsPerMerc
        if L.morale <= self.MoraleMutinyAt then
            if self:LogiRemoveOneMerc(true) then
                Game.SendInfoText('merc_logi_mutiny_event', false, 0, 4)
            end
        else
            if self:LogiRemoveOneMerc(false) then
                Game.SendInfoText('merc_logi_desert_event', false, 0, 4)
            end
        end
    end
end

-- ==== Daily upkeep (evening) ====
function mercenaries:LogiProcessUpkeep()
    local L = self:LogiState()
    self:Recount()
    local count = _G.MercCount or 0
    if _G.MercenariesDismissed or count <= 0 then return end

    -- Passive food from upgrades.
    local covered = 0
    if self.CampActive and count >= self.UpgHunterMinCamp then
        covered = covered + self.UpgHunterFeeds * (L.hunterSpots or 0)
    end
    if (L.foodCartDays or 0) > 0 then
        covered = covered + self.UpgFoodCartFeeds
        L.foodCartDays = L.foodCartDays - 1
        -- Out of supply days: the cart packs up and leaves camp.
        if L.foodCartDays <= 0 then pcall(function() self:DespawnCampFoodCart() end) end
    end
    local toFeed = math.max(0, count - covered)
    local need = math.ceil(toFeed / self.FeedRatio)
    if need <= L.food then
        self:LogiAdjust("food", -need, "evening ration for " .. count .. " men")
        L.starving = false
    else
        L.starving = true
        Game.SendInfoText('merc_logi_hungry', false, 0, 4)
    end

    -- Drink (inn covers it, else drink units). Optional - no penalty when short.
    if (L.innDays or 0) > 0 then
        L.drinkAvailable = true
        L.innActive = true
        L.innDays = L.innDays - 1
    else
        L.innActive = false
        local dneed = math.ceil(count / self.FeedRatio)
        if dneed <= L.drink then
            self:LogiAdjust("drink", -dneed, "evening round for " .. count .. " men")
            L.drinkAvailable = true
        else
            L.drinkAvailable = false
        end
    end

    -- Practice yard: about one tier's worth of training a day.
    if L.hasPracticeYard and (L.trainLevel or 0) < self.PracticeMaxLevel then
        L.trainLevel = (L.trainLevel or 0) + 1
    end

    self:LogiProcessWages()
    self:LogiApplyBuffs()
end

-- Lift starving the moment food is on hand again (ration is still only consumed
-- at the evening tally, so no double-charge).
function mercenaries:LogiReconcile()
    local L = self:LogiState()
    self:Recount()
    local count = _G.MercCount or 0
    if count <= 0 then return end
    local need = math.ceil(count / self.FeedRatio)
    if L.starving and L.food >= need then L.starving = false end
    if not L.drinkAvailable and L.drink >= need then L.drinkAvailable = true end
    self:LogiApplyBuffs()
end

-- ==== Wages (coffer first, then the player's purse) ====
-- Number lines use the "@labelKey <number>" pattern: every visible word must be
-- an @-key, only bare numbers between them, or the engine adds a stray '@'.
function mercenaries:LogiInfo(s)
    pcall(function() Game.SendInfoText(s, false, 0, 5) end)
end

function mercenaries:LogiProcessWages()
    local L = self:LogiState()
    -- Reset the per-evening record the summary reads.
    L.lastWageTotal, L.lastWageCoffer, L.lastWagePurse = 0, 0, 0
    if L.wagesWithheld then L.unpaid = true; return end
    local total = self:LogiWageTotal()
    if total <= 0 then L.unpaid = false; return end
    local money = 0
    pcall(function() money = player.inventory:GetMoney() end)
    local coffer = L.coffer or 0
    if coffer + money >= total then
        local fromCoffer = math.min(coffer, total)
        if fromCoffer > 0 then self:LogiAdjust("coffer", -fromCoffer, "wages") end
        local fromPurse = total - fromCoffer
        if fromPurse > 0 then pcall(function() player.inventory:RemoveMoney(fromPurse) end) end
        L.unpaid = false
        L.lastWageTotal, L.lastWageCoffer, L.lastWagePurse = total, fromCoffer, fromPurse
        System.LogAlways("[Logistics] Wages paid: " .. total .. " (coffer " .. fromCoffer .. " + purse " .. fromPurse .. ")")
    else
        L.unpaid = true
        L.lastWageTotal = total
        self:LogiInfo("@merc_n_wshort " .. (total - (coffer + money)))
    end
end

-- ==== In-camp health regen ====
-- While camped the men recover fully over a day, the quartermaster over an hour
-- (driven off game time, so sleeping/waiting counts). Not logged (per-tick noise).
function mercenaries:LogiCampRegen(dt)
    if not self.CampActive or dt <= 0 then return end
    local mercHeal = 100 * dt / self.SecondsPerDay   -- full over a day
    local qmHeal   = 100 * dt / 3600                  -- full over an hour
    for _, ent in pairs(self.ActiveMercs) do
        if ent and ent.soul and self:IsAliveAndWell(ent, false) then
            pcall(function()
                local hp = ent.soul:GetState('health')
                if hp and hp < 100 then ent.soul:SetState('health', math.min(100, hp + mercHeal)) end
            end)
        end
    end
    pcall(function()
        local qm = self.QuartermasterName and System.GetEntityByName(self.QuartermasterName)
        if qm and qm.soul then
            local hp = qm.soul:GetState('health')
            if hp and hp < 100 then qm.soul:SetState('health', math.min(100, hp + qmHeal)) end
        end
    end)
end

-- ==== Master tick (LowPriorityMonitorLoop, 5s real) ====
function mercenaries:LogiTick()
    local ok, err = pcall(function()
        local L = self:LogiState()
        local now = self:LogiNow()
        if now <= 0 then return end                        -- world time not ready
        if L.lastTick == nil then L.lastTick = now end
        local dt = now - L.lastTick
        L.lastTick = now
        if dt < 0 then dt = 0 end
        if dt > 3 * self.SecondsPerDay then dt = 3 * self.SecondsPerDay end

        self:LogiTrackCombat()          -- kills/deaths -> morale (discrete)
        self:LogiUpdateTiredness(dt)
        self:LogiMoraleTick(dt)         -- continuous morale rates
        self:LogiCampRegen(dt)          -- in-camp health recovery

        local day = self:LogiUpkeepDay()
        if L.lastUpkeepDay == nil then L.lastUpkeepDay = day end
        local guard, didUpkeep = 0, false
        while L.lastUpkeepDay < day and guard < 40 do
            L.lastUpkeepDay = L.lastUpkeepDay + 1
            guard = guard + 1
            self:LogiProcessUpkeep()
            didUpkeep = true
        end
        -- One evening summary, after any upkeep, listing the day's tallies.
        if didUpkeep then self:LogiEveningSummary() end

        self:LogiReconcile()
        self:LogiDesertionTick(dt)
        self:LogiApplyBuffs()
        self:LogiUpdateStatusBuffs()    -- mirror squad state onto the HUD icons
        self:LogiSave()
    end)
    if not ok then System.LogAlways('[Logistics] LogiTick error: ' .. tostring(err)) end
end

-- ==== Quartermaster dialog actions ====
function mercenaries:LogiDeliverFood()
    local delivered = 0
    pcall(function()
        local p = player.inventory
        for _, cls in ipairs(self.FoodItemClasses) do
            local n = p:GetCountOfClass(cls)
            if n and n > 0 then p:DeleteItemOfClass(cls, n); delivered = delivered + n end
        end
    end)
    if delivered > 0 then
        self:LogiAdjust("food", delivered, "delivered by player")
        self:LogiReconcile(); self:LogiSave()
        self:LogiInfo("@merc_n_fdeliv " .. delivered .. " @merc_n_stock " .. self:LogiState().food .. " @merc_n_days " .. self:LogiSupplyDays(self:LogiState().food))
    else
        Game.SendInfoText('merc_logi_nothing_to_deliver', false, 0, 3)
    end
end

-- Result of the food-delivery UI panel (CreateItemDelivery). The panel physically
-- moves the chosen food into the quartermaster's inventory, so the true amount is
-- whatever he now holds - we count that and clear it back out (units are the
-- abstraction the rest of the system runs on). We do NOT trust the token count:
-- ItemDeliveryHandler has no .Amount output, so the reward always carries 1
-- regardless of how many items were handed over; the token is just a "a delivery
-- happened" signal. `_signal` is that token count, deliberately ignored.
function mercenaries:LogiPanelFood(_signal)
    local delivered = 0
    pcall(function()
        local qm = self.QuartermasterName and System.GetEntityByName(self.QuartermasterName)
        if qm and qm.inventory then
            for _, cls in ipairs(self.FoodItemClasses) do
                local n = qm.inventory:GetCountOfClass(cls)
                if n and n > 0 then
                    delivered = delivered + n
                    qm.inventory:DeleteItemOfClass(cls, n)
                end
            end
        end
    end)
    if delivered <= 0 then return end
    self:LogiAdjust("food", delivered, "delivered via panel")
    self:LogiReconcile(); self:LogiSave()
    self:LogiInfo("@merc_n_ftook " .. delivered .. " @merc_n_stock " .. self:LogiState().food .. " @merc_n_days " .. self:LogiSupplyDays(self:LogiState().food))
end

function mercenaries:LogiDeliverDrink()
    local delivered = 0
    pcall(function()
        local p = player.inventory
        for _, cls in ipairs(self.DrinkItemClasses) do
            local n = p:GetCountOfClass(cls)
            if n and n > 0 then p:DeleteItemOfClass(cls, n); delivered = delivered + n end
        end
    end)
    if delivered > 0 then
        self:LogiAdjust("drink", delivered, "delivered by player")
        self:LogiReconcile(); self:LogiSave()
        self:LogiInfo("@merc_n_ddeliv " .. delivered .. " @merc_n_stock " .. self:LogiState().drink .. " @merc_n_days " .. self:LogiSupplyDays(self:LogiState().drink))
    else
        Game.SendInfoText('merc_logi_nothing_to_deliver', false, 0, 3)
    end
end

-- Result of the drink-delivery UI panel (CreateItemDelivery, food_type 3).
-- Mirror of LogiPanelFood: count what the quartermaster actually received and
-- clear it out. The token count (`_signal`) is ignored for the same reason - the
-- handler has no .Amount output, so it is always 1.
function mercenaries:LogiPanelDrink(_signal)
    local delivered = 0
    pcall(function()
        local qm = self.QuartermasterName and System.GetEntityByName(self.QuartermasterName)
        if qm and qm.inventory then
            for _, cls in ipairs(self.DrinkItemClasses) do
                local n = qm.inventory:GetCountOfClass(cls)
                if n and n > 0 then
                    delivered = delivered + n
                    qm.inventory:DeleteItemOfClass(cls, n)
                end
            end
        end
    end)
    if delivered <= 0 then return end
    self:LogiAdjust("drink", delivered, "delivered via panel")
    self:LogiReconcile(); self:LogiSave()
    self:LogiInfo("@merc_n_dtook " .. delivered .. " @merc_n_stock " .. self:LogiState().drink .. " @merc_n_days " .. self:LogiSupplyDays(self:LogiState().drink))
end

function mercenaries:LogiBuyFood()
    if not self:LogiSpend(self.FoodBuyCost) then return end
    self:LogiAdjust("food", self.FoodBuyAmount, "bought for " .. self.FoodBuyCost .. " groschen")
    self:LogiReconcile(); self:LogiSave()
    self:LogiInfo("@merc_n_fbought " .. self.FoodBuyAmount .. " @merc_n_cost " .. self.FoodBuyCost .. " @merc_n_stock " .. self:LogiState().food)
end

-- Shared "can we afford X, and take it" helper.
function mercenaries:LogiSpend(cost)
    local money = 0
    pcall(function() money = player.inventory:GetMoney() end)
    if money < cost then
        Game.SendInfoText('merc_info_not_enough_money', false, 0, 3)
        return false
    end
    pcall(function() player.inventory:RemoveMoney(cost) end)
    return true
end

function mercenaries:LogiToggleWithholdWages()
    local L = self:LogiState()
    L.wagesWithheld = not L.wagesWithheld
    if not L.wagesWithheld then L.unpaid = false end
    self:LogiSave()
    Game.SendInfoText(L.wagesWithheld and 'merc_logi_wages_withhold_on' or 'merc_logi_wages_withhold_off', false, 0, 4)
end

-- War chest: pre-fund wages (stands in for "sell loot" - the engine gives no way
-- to enumerate arbitrary inventory loot to sell).
function mercenaries:LogiDepositCoffer()
    if not self:LogiSpend(self.CofferDepositStep) then return end
    local L = self:LogiState()
    self:LogiAdjust("coffer", self.CofferDepositStep, "player deposit")
    self:LogiSave()
    self:LogiInfo("@merc_n_cadd " .. self.CofferDepositStep .. " @merc_n_cnow " .. L.coffer)
end
function mercenaries:LogiWithdrawCoffer()
    local L = self:LogiState()
    if (L.coffer or 0) <= 0 then
        Game.SendInfoText('merc_logi_coffer_empty', false, 0, 3)
        return
    end
    -- Only clear the coffer if the money actually landed in the purse - never
    -- zero it on a failed AddMoney, or the coin would just vanish.
    local taken = L.coffer
    local ok = pcall(function() player.inventory:AddMoney(L.coffer) end)
    if ok then
        self:LogiAdjust("coffer", -taken, "withdrawn by player")
        self:LogiSave()
        self:LogiInfo("@merc_n_ctake " .. taken)
    else
        System.LogAlways('[Logistics] AddMoney failed; coffer kept at ' .. tostring(L.coffer))
        Game.SendInfoText('merc_logi_coffer_empty', false, 0, 3)
    end
end

-- Upgrades
--
-- Every camp upgrade occupies a GRID TILE, allocated when the camp is laid out
-- (see CampActiveStations / CampStationTiles) so it gets the same room as a
-- campfire cluster and can't overlap one. A tile can only be reserved while the
-- grid is being built, so buying an upgrade mid-camp rebuilds the whole camp
-- rather than dropping the new structure into whatever gap it can find.
function mercenaries:LogiRebuildCampForUpgrade()
    pcall(function()
        if not (self.CampActive and self.CampCenter) then return end
        -- Grab the pitch before breaking (BreakMercCamp forgets it), so the camp
        -- goes back up exactly where it stood instead of in front of the player -
        -- who may have wandered off since making it.
        local origin = self.CampBuildOrigin
        self:BreakMercCamp(true)
        -- Sweep anything the teardown didn't have tracked, so the camp is rebuilt
        -- from scratch rather than stacking a second set of props on the first.
        self:ClearAnyLeftoverCamp()
        self:SpawnMercCamp(origin, true)
    end)
end

-- Strip every upgrade back to a bare camp. No refund - this is for undoing a layout,
-- not selling. The timed ones (food cart, inn) are zeroed like the permanent ones, and
-- the smithy/alchemy buffs are re-applied afterwards so the mercs lose their bonuses.
-- The camp is rebuilt the same way buying one rebuilds it, so the freed grid tiles are
-- released and the props actually disappear.
function mercenaries:LogiRemoveAllUpgrades()
    local L = self:LogiState()
    L.foodCartDays    = 0
    L.innDays         = 0
    L.innActive       = false
    L.hunterSpots     = 0
    L.hasSmithy       = false
    L.hasAlchemy      = false
    L.hasPracticeYard = false
    L.hasHouse        = false
    L.trainLevel      = 0

    pcall(function() self:DespawnCampFoodCart() end)
    -- defences are per-pitch: take them down AND forget them, or they would come back
    -- with the camp rebuild below
    pcall(function() self:DefClearWorld() end)
    pcall(function() self:DefForget() end)
    pcall(function() self:LogiApplyBuffs() end)
    self:LogiSave()
    self:LogiRebuildCampForUpgrade()
    Game.SendInfoText('merc_logi_upg_removed', false, 0, 4)
    System.LogAlways("[Logistics] all upgrades removed")
end

function mercenaries:LogiBuyFoodCart()
    if not self:LogiSpend(self.UpgFoodCartCost) then return end
    self:LogiState().foodCartDays = self.UpgFoodCartDays
    self:LogiSave(); Game.SendInfoText('merc_logi_upg_bought', false, 0, 4)
    self:LogiRebuildCampForUpgrade()
end
function mercenaries:LogiBuyInn()
    if not self:LogiSpend(self.UpgInnCost) then return end
    local L = self:LogiState(); L.innDays = self.UpgInnDays; L.innActive = true
    self:LogiSave(); Game.SendInfoText('merc_logi_upg_bought', false, 0, 4)
    self:LogiRebuildCampForUpgrade()
end
function mercenaries:LogiBuyHunter()
    if not self:LogiSpend(self.UpgHunterCost) then return end
    local L = self:LogiState(); L.hunterSpots = (L.hunterSpots or 0) + 1
    self:LogiSave(); Game.SendInfoText('merc_logi_upg_bought', false, 0, 4)
    if L.hunterSpots == 1 then self:LogiRebuildCampForUpgrade() end   -- only the first one builds the station
end
function mercenaries:LogiBuySmithy()
    local L = self:LogiState()
    if L.hasSmithy then Game.SendInfoText('merc_logi_upg_have', false, 0, 3); return end
    if not self:LogiSpend(self.UpgSmithyCost) then return end
    L.hasSmithy = true; self:LogiApplyBuffs(); self:LogiSave(); Game.SendInfoText('merc_logi_upg_bought', false, 0, 4)
    self:LogiRebuildCampForUpgrade()
end
function mercenaries:LogiBuyAlchemy()
    local L = self:LogiState()
    if L.hasAlchemy then Game.SendInfoText('merc_logi_upg_have', false, 0, 3); return end
    if not self:LogiSpend(self.UpgAlchemyCost) then return end
    L.hasAlchemy = true; self:LogiApplyBuffs(); self:LogiSave(); Game.SendInfoText('merc_logi_upg_bought', false, 0, 4)
    self:LogiRebuildCampForUpgrade()
end
function mercenaries:LogiBuyHouse()
    local L = self:LogiState()
    if L.hasHouse then Game.SendInfoText('merc_logi_upg_have', false, 0, 3); return end
    if not self:LogiSpend(self.UpgHouseCost) then return end
    L.hasHouse = true; self:LogiSave(); Game.SendInfoText('merc_logi_upg_bought', false, 0, 4)
    self:LogiRebuildCampForUpgrade()
end
-- TEMP archer-tower upgrade: buying it just enables aim-placement (StartTowerPlacement).
-- No hasTower flag / no save persistence yet - intentionally throwaway for now.
function mercenaries:LogiBuyTower()
    if not self:LogiSpend(self.UpgTowerCost) then return end
    Game.SendInfoText('merc_logi_upg_bought', false, 0, 3)
    self:StartTowerPlacement()
end
-- TEMP archer-cart upgrade: buying it enables aim-placement, same as the tower.
-- The wall is bought once per pitch, then drawn by the player (merc_wall_build's
-- click-to-place). It is saved against this camp's anchor, so it survives a save
-- and an upgrade rebuild but is left behind if the company pitches elsewhere.
function mercenaries:LogiBuyWall()
    if not (self.CampActive and self.CampBuildOrigin) then
        Game.SendInfoText('merc_info_camp_not_active', false, 0, 3); return
    end
    if not self:LogiSpend(self.UpgWallCost) then return end
    Game.SendInfoText('merc_logi_upg_bought', false, 0, 3)
    self:StartWallBuild()
end

function mercenaries:LogiBuyArcherCart()
    if not self:LogiSpend(self.UpgArcherCartCost) then return end
    Game.SendInfoText('merc_logi_upg_bought', false, 0, 3)
    self:StartArcherCartPlacement()
end
function mercenaries:LogiBuyPractice()
    local L = self:LogiState()
    if L.hasPracticeYard then Game.SendInfoText('merc_logi_upg_have', false, 0, 3); return end
    if not self:LogiSpend(self.UpgPracticeCost) then return end
    L.hasPracticeYard = true; self:LogiSave(); Game.SendInfoText('merc_logi_upg_bought', false, 0, 4)
    -- Raise the practice yard right now if we're already in camp (mirrors the
    -- smithy/alchemy), then set some mercs drilling; otherwise it comes up on the
    -- next camp make.
    pcall(function()
        if self.CampActive and self.CampCenter and not self.CampPracticeYard then
            if self:SpawnCampPracticeYard(self.CampCenter) then
                self:AssignCampTrainers(self.CampPracticeYard.numDummies)
            end
        end
    end)
end

-- Starting stores, granted once: the first camp you ever pitch comes with
-- StartingSupplyDays of rations and drink for the squad you have at the time.
-- Guarded by a saved flag, so rebuilds (upgrades) and save restores don't top up.
function mercenaries:LogiGrantStartingSupplies()
    if self:LoadString("QMStartSupplies") == "1" then return end
    self:SaveString("QMStartSupplies", "1")
    self:Recount()
    local perDay = math.max(1, math.ceil((_G.MercCount or 0) / self.FeedRatio))
    local units = perDay * self.StartingSupplyDays
    local L = self:LogiState()
    self:LogiAdjust("food", units, "starting stores")
    self:LogiAdjust("drink", units, "starting stores")
    L.starving = false
    L.drinkAvailable = true
end

-- Days of a supply the current squad has left.
function mercenaries:LogiSupplyDays(units)
    self:Recount()
    local need = math.max(1, math.ceil((_G.MercCount or 0) / self.FeedRatio))
    return math.floor((units or 0) / need)
end

function mercenaries:LogiAskFood()
    local L = self:LogiState()
    self:LogiInfo("@merc_n_food " .. L.food .. " @merc_n_days " .. self:LogiSupplyDays(L.food))
end
function mercenaries:LogiAskDrink()
    local L = self:LogiState()
    self:LogiInfo("@merc_n_drink " .. L.drink .. " @merc_n_days " .. self:LogiSupplyDays(L.drink))
end

-- Overall report (numbers, camp-debug style).
function mercenaries:LogiAskStats()
    local L = self:LogiState()
    local total = self:LogiWageTotal()
    local money = 0; pcall(function() money = player.inventory:GetMoney() end)
    local runway = (total > 0) and math.floor(((L.coffer or 0) + money) / total) or 999
    self:LogiInfo("@merc_n_morale " .. math.floor(L.morale) .. " @merc_n_food " .. L.food .. " @merc_n_days " .. self:LogiSupplyDays(L.food)
        .. " @merc_n_drink " .. L.drink .. " @merc_n_days " .. self:LogiSupplyDays(L.drink)
        .. " @merc_n_cnow " .. (L.coffer or 0) .. " @merc_n_wpd " .. total .. " @merc_n_wdays " .. runway)
end

-- The nightly tally the player asked for: food/drink left, what wages cost and
-- where they came from (war chest vs purse), and morale.
function mercenaries:LogiEveningSummary()
    local L = self:LogiState()
    if (L.lastWageTotal or 0) > 0 and not L.unpaid then
        if (L.lastWagePurse or 0) > 0 and (L.lastWageCoffer or 0) > 0 then
            self:LogiInfo("@merc_n_ewages " .. L.lastWageTotal .. " @merc_n_fromchest " .. L.lastWageCoffer .. " @merc_n_frompurse " .. L.lastWagePurse
                .. " @merc_n_food " .. L.food .. " @merc_n_drink " .. L.drink .. " @merc_n_morale " .. math.floor(L.morale))
        elseif (L.lastWagePurse or 0) > 0 then
            self:LogiInfo("@merc_n_ewages " .. L.lastWageTotal .. " @merc_n_frompurse " .. L.lastWageTotal
                .. " @merc_n_food " .. L.food .. " @merc_n_drink " .. L.drink .. " @merc_n_morale " .. math.floor(L.morale))
        else
            self:LogiInfo("@merc_n_ewages " .. L.lastWageTotal .. " @merc_n_fromchest " .. L.lastWageTotal
                .. " @merc_n_food " .. L.food .. " @merc_n_drink " .. L.drink .. " @merc_n_morale " .. math.floor(L.morale))
        end
    else
        self:LogiInfo("@merc_n_food " .. L.food .. " @merc_n_drink " .. L.drink .. " @merc_n_cnow " .. (L.coffer or 0) .. " @merc_n_morale " .. math.floor(L.morale))
    end
end

-- (The tutorial is now a spoken dialog with the quartermaster - see
-- quartermaster_dialog.xml - rather than a queue of HUD lines.)
