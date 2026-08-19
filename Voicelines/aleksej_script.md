# Aleksej of Zaslawye — voice script

44 recorded lines, `voicelines/1.mp3` … `voicelines/44.mp3`. 7 min 5 s total.

`len` is the measured duration of the recording, in seconds, rounded up. It is the
`ReferenceLength` for that line's `<Response>` — the value the dialogue system uses to time an
unvoiced line, so the subtitle stays up for as long as the take runs.

Every line is Aleksej unless marked HENRY.

**Shipped loc key scheme:** one localisation row per recording, `localization/English_xml.xml`
carries `merc_alx_L1`..`merc_alx_L44`, text taken verbatim from this table's `line` column.
Each recording gets its own `<Response Role="role_aleksej" ReferenceLength="<len>">` in the
Skald dialog, where `<len>` is that row's own `len` column below — never a sum of several
recordings. The order of Responses within each Sequence, and where Henry's prompts interrupt,
follows the Sequencing table below exactly. Henry's H1–H9 have no separate recorded-line key at
all: his line *is* the `ui_alx_<beat>_<slug>` `UiPrompt` text, reused as the spoken `<Response>`
text too. This table's `len` values are the single source of truth for both duration and text.

| # | beat | len | line |
|---|---|---|---|
| 1 | 1 assign | 10 | You are the one they talk about in the square. Good. I was beginning to think I would have to do this myself, and I am too old and too fat for the woods. |
| 2 | 1 assign | 6 | There is a camp in the field above the wagoners' camp. The one leading them is called Ondra. |
| 3 | 1 assign | 7 | He took a carter's load on Thursday and took the carter's cock along with it, which was unnecessary. |
| 4 | 1 assign | 8 | The town council will pay two hundred groschen for justice. I will add a hundred of my own for the sake of men everywhere. |
| 5 | 1 assign | 15 | Because the guard would march in broad daylight, in full uniform, with a bard singing of their exploits, and find cold fires and even colder latrines. You, on the other hand, know how to deal with such tasks. |
| 6 | 1 report | 6 | Ondra as well? Good. He was the only one of them worth worrying about. |
| 7 | 1 report | 5 | Take the silver — take it, do not count it in front of me, it is insulting. |
| 8 | 1 report | 6 | You know, in the east we had a man who counted his pay in front of his lord and the whole council. |
| 9 | 1 report | 9 | Every week. For thirty years. And then one week he received coins still hot from the forge. He did not count anything after that. |
| 10 | 2 assign | 7 | Now this one is not thieves beside a road. This is thieves on a hill. |
| 11 | 2 assign | 12 | Silver has been falling through a hole in a cart's bed. Not much at a time — that is the clever part, a little and a little, and nobody's tally is wrong enough to shout about. |
| 12 | 2 assign | 14 | They are dug in on the height behind one of the mines. A man called Vávra keeps their count for them. He was a lumberjack before he was a thief, so he will not run. He will go down swinging something sharp and heavy. |
| 13 | 2 assign | 8 | Everybody. The miners, their foreman, the mine's owner, the town mint, and me. |
| 14 | 2 report | 9 | ...Well. I did not expect bandits to keep such a consistent tally of their, ehm. Earnings. |
| 15 | 2 report | 16 | It speaks of another gaggle of them moving the silver on. You have made this my problem now, Henry. I hope you understand that. A man who knows where the silver goes and does nothing about it is an outlaw himself. |
| 16 | 3 assign | 11 | They will pass near Miskovitz, I think. Their leader is a hedge knight, and he is rumoured to have a shy sweetheart there. You would do well to take them before they reach the village. |
| 17 | 3 assign | 18 | Do not underestimate the knight, however. He has anything but the sweet disposition of his damsel. They say that when he rides with an army, they give him green boys with pitchforks and send him to soften up the enemy. He enjoys it. |
| 18 | 3 assign | 18 | Bring back what you can carry. What you cannot carry, burn it. Ah — no. It is silver. Then you will simply have to break your back. Leave what is left lying in the road for the town's men to find. It does us both good to be seen to be honest. |
| 19 | 3 report | 5 | Oh my. That is a very large haul. Keep all of it, you have earned it. |
| 20 | 3 report | 11 | We had a captain in the north — the far north — who paid us in salt for two winters, because there was no coin between the Dvina and God. |
| 21 | 3 report | 13 | He had overheard two men in a tavern speaking of a merchant, and he misheard salt for silver, and he raided the man anyway. Two winters of salt. Can you imagine that? |
| 22 | 4 assign | 10 | Rabble have burned a mill down and then made their camp on the ashes. Can you imagine that? Sleeping on a bed of smouldering coals. It must be quite warm. |
| 23 | 4 assign | 10 | A man called Kuneš has them in hand, or thinks he does. Go and be quick — I want to eat before dark. They say eating after dark makes for bad sleep. |
| 24 | 4 report | 8 | What did he wear. Exactly. Not what you think he wore. |
| 25 | 4 report | 5 | Hah. Well. That explains a great deal, actually. |
| 26 | 4 report | 9 | There is a captain of Sigismund's working this country. I have heard the name twice this month and dismissed it twice, and that was stupid of me. |
| 27 | 4 report | 9 | He is buying men — deserters, brigands, whatever will hold a pitchfork — and he is paying them out of somebody's silver. Somebody's silver, Henry. |
| 28 | 4 report | 4 | It was never thieves on a hill. It was their payroll. |
| 29 | 5 assign | 7 | I have found his men. Or they have found us — I am not certain which way it goes. |
| 30 | 5 assign | 9 | They ride the low road past the fields tomorrow. I do not know their road past that and I do not know their strength. |
| 31 | 5 assign | 10 | That is the trouble. It could be nothing and it could be an army, and I would not send you if there were anyone else to send. |
| 32 | 5 assign | 5 | I am. Go carefully, my friend. I have grown used to you. |
| 33 | 5 report | 12 | ...Bozhe. You took them past the shrine, then, and walked back here on your own two legs. I have rarely seen a warrior of your might, my friend. |
| 34 | 5 report | 10 | Sit. Sit. I am going to tell you something I should have told you at the very beginning of our acquaintance, and you may be angry with me for it. |
| 35 | 5 report | 17 | There is no captain. There is a man of God — a Hungarian. Kanizsai, archbishop of Gran, or he was. He dropped a crown on the wrong bald head last summer, and Sigismund took his castle, his income and his dignity, in that order. |
| 36 | 5 report | 6 | Not his wife, mind. Being a churchman, he had none. It is the only thing left to him. |
| 37 | 5 report | 10 | What silver he still has, he sends north. Here. To buy an army out of other men's mines — parts of which you have been turning into red stains on our fields. |
| 38 | 5 report | 10 | Because you keep coming back alive, and a man who keeps coming back alive eventually finds things out for himself. I would rather he found them out from a friend. |
| 39 | 9 marsh | 10 | Stop there. Not because of my men — they will not move unless I tell them. Stop there because I want to say this once, and I will not shout it. |
| 40 | 9 marsh | 17 | This water smells of home. Did you know that? Same reeds, same rot, same flat grey sky sitting on it like a lid. Nine years in this country, and I find Zaslawye in a bog outside Kuttenberg. God is not subtle. |
| 41 | 9 marsh | 12 | I served a man. I have not said his name aloud since I crossed the Vistula, and I am going to say it now, because after today there is nobody left who could be hurt by it. Švitrigaila. |
| 42 | 9 marsh | 9 | You have never heard of him. That is the joke. I gave him everything I had, and you have never heard of him. |
| 43 | 9 marsh | 17 | They came with me from Zaslawye. Not for the archbishop — they have never heard of him either, and they pray to a different God in any case. They came because I told them there was better land in the west. I was right. The land here is very good. |
| 44 | 9 marsh | 17 | They cannot go home. Neither can I. So they will die in a marsh for a churchman who stopped writing to me in the autumn, and they will not complain about it, because they never do. Do not make us wait, Henry. It is unkind. |

## Henry's prompts

Henry is unvoiced; these are player dialogue options, not recordings.

| key | beat | text |
|---|---|---|
| `merc_alx_H1` | 1 assign | Why not send the guard? |
| `merc_alx_H2` | 2 assign | Who wants them gone? |
| `merc_alx_H3` | 3 assign | And the silver? |
| `merc_alx_H4` | 4 report | The one leading them wasn't called Kuneš. And he was wearing Sigismund's colours. |
| `merc_alx_H5` | 4 report | *(describe the surcoat)* |
| `merc_alx_H6` | 5 assign | You're sending me anyway. |
| `merc_alx_H7` | 5 report | Why tell me now? |
| `merc_alx_H8` | 9 marsh | Who were you? |
| `merc_alx_H9` | 9 marsh | And your men? |

## Sequencing

- **Beat 1** assign 1,2,3,4 → [H1] → 5. Report 6,7,8,9.
- **Beat 2** assign 10,11,12 → [H2] → 13. Report 14,15.
- **Beat 3** assign 16,17 → [H3] → 18. Report 19,20,21.
- **Beat 4** assign 22,23. Report [H4] → 24 → [H5] → 25,26,27,28.
- **Beat 5** assign 29,30,31 → [H6] → 32. Report 33,34,35,36,37 → [H7] → 38.
- **Beats 6, 7, 8** — no dialogue at all. He is simply gone from his lodging.
- **Beat 9** 39,40 → [H8] → 41,42 → [H9] → 43,44, then he draws.

## Direction notes that survive into the build

- **Line 24 is the only moment the mask is off.** Cold, short, no anger. Everything after it (25–28)
  is invention delivered fast.
- **Line 33 is the slip.** He swore at line 30 he did not know their road past the fields, then
  names a point past them. Lines 30 and 33 are a **matched pair**: the place named in 33 must be
  the actual ambush site and must lie beyond the landmark in 30. If the encounter moves, both
  lines move. Never edit one alone.
- **Lines 19–21** are overpayment played slightly too fast. It is the last money he has for goodwill.
- **"Can you imagine that?"** appears exactly twice — lines 21 and 22. Never in the marsh.
- He never uses a contraction, never states an enemy count, and never names Švitrigaila before 41.
