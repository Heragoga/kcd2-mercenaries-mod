# Kleinkrieg - quartermaster voice lines

50 lines. Every one is the quartermaster; Henry never speaks aloud in the 12-contract
accept/report loop below (the player's choices are on-screen text only). Each contract
has two lines on the way out and two on the way back, played back to back, so record
each pair as one continuous thought.

Key = the localisation StringName. Do not rename them.

The two safety-net lines that bracket the whole loop (`seq_qm_banditcamp_yes` /
`seq_qm_banditcamp_letter` in `quartermaster_dialog.xml`) are the exception: Henry's
line there is voiced with no new recording, by pointing straight at existing vanilla
StringNames (`jeni_henry_proste_mi_jen__sjr0` = "Just tell me where they're camping and
I'll worry about the rest." and `post_henry_jsou_mrtvi_vsi_HzlP` = "It's done.", both
tmck/Henry lines that exist in the base game - see reference_henry_vanilla_voicelines.md
for the technique). The audio still has to be shipped, though: the extracted `.ogg` for
each StringName was copied byte-for-byte into `voice/carbongo/` so it packs into this
quest's own VO folder - reusing the StringName only gets you the text for free, not the
sound. The report line's second half, `merc_henry_qm_banditcamp_letter` ("Here's
everything he carried."), has no vanilla match and stays a silent on-screen line like the
rest of the loop.

------------------------------------------------------------------------
## 1. woodland

### Giving the job   [player picks: “Anything needs doing?”]
  merc_kk_acc_1            Nothing that need trouble you. There's a band of yokels camped in the woods west of here, helping themselves to whatever the carters are carrying. Half of them have never held anything sharper than a scythe.

  merc_kk_acc_1_b          The carters are paying to be rid of them - they'd sooner part with a few groschen than the whole load. Go and put the fear of God into them.

### Taking the report   [player picks: “The woods are done.”]
  merc_kk_turn_1           It rarely is much of a fight with that sort. Here's your money - the road's open, the carters are content, and I've a few less complaints to sit through.

  merc_kk_turn_1_b         Nothing else today. Come back when you've spent that and I'll find you something.

------------------------------------------------------------------------
## 2. hillside

### Giving the job   [player picks: “More of the same?”]
  merc_kk_acc_2            Aye, up on the hillside past the mill. Same story as the last, near enough - a dozen hungry men and a few stolen chickens. Should be an easy day's coin.

  merc_kk_acc_2_b          Though I'll tell you what troubles me. That's the third band this month, and peasants don't take to the woods in that number unless something's driven them there. Go and have a look for me.

### Taking the report   [player picks: “It's done. Their leader was wearing Sigismund's colours.”]
  merc_kk_turn_2           On a peasant? ...No. No, that's not a man who stripped a coat off a corpse. Somebody's arming them.

  merc_kk_turn_2_b         One of Sigismund's captains, raising men on the quiet where nobody's counting. I've been at this trade longer than you've been shaving. Take your coin.

------------------------------------------------------------------------
## 3. hillfort

### Giving the job   [player picks: “What's in the old hillfort?”]
  merc_kk_acc_3            There's smoke coming off the old hillfort above the river. Not much of it - a few men at most. But it's the same road the hillside lot came down, and I don't care for the pattern.

  merc_kk_acc_3_b          I know it's hardly work for a whole company. Go anyway, and see who they are before somebody else does.

### Taking the report   [player picks: “Three men, and half dead before I got there.”]
  merc_kk_turn_3           Then they ran from something. Or somebody tidied up after himself and made a poor job of it.

  merc_kk_turn_3_b         Covering his tracks and leaving the wounded where they fell. It's no more than I'd expect of him. Here.

------------------------------------------------------------------------
## 4. Sigismund's company

### Giving the job   [player picks: “Soldiers, you said?”]
  merc_kk_acc_4            Real ones. There's a column of them moving on the Kuttenberg road, and no lord in this district has men to spare for a march like that. They're not garrison, they're not levy, and they're certainly not lost.

  merc_kk_acc_4_b          Whose they are is precisely what I'm paying you to find out. Take the column, and bring me whatever their captain's carrying.

### Taking the report   [player picks: “The column's finished. Their captain had this on him.”]
  merc_kk_turn_4           Ha! There - what did I tell you? A captain, raising men, exactly as I said. ...Hold on a moment.

  merc_kk_turn_4_b         That seal. No soldier alive seals a letter like that - that's a churchman's mark. Leave it with me a day or two. I know a man who reads these things for a living.

------------------------------------------------------------------------
## 5. the mine

### Giving the job   [player picks: “You've had a day with that letter.”]
  merc_kk_acc_5            I have, and I've a name for you. Janos Kanizsai, Archbishop of Esztergom - and there's one I'd hoped never to say aloud again. He put a crown on the wrong king's head a few years back, backed the losing side, got himself pardoned for it, and then watched Sigismund hand his castle and his revenues to men he despises.

  merc_kk_acc_5_b          Now he's paying soldiers on a Bohemian road, out of a silver mine that was never his. There's a band sat on one east of here. Go and see what they're digging.

### Taking the report   [player picks: “The mine's cleared. They were hauling raw ore, not coin.”]
  merc_kk_turn_5           Ore. Not coin. Do you understand what that means? There isn't a market in Bohemia that'll touch unminted silver. It's worthless to him unless he can strike it himself.

  merc_kk_turn_5_b         Which means a mint, and somewhere to put one, and men enough to hold it while it works. Take your pay, and say nothing of this in the tavern.

------------------------------------------------------------------------
## 6. waystation

### Giving the job   [player picks: “Where does the ore go?”]
  merc_kk_acc_6            Twelve mule-loads don't walk to Hungary on their own. They need a road, and a road needs somewhere to stop - fodder, fresh beasts, a roof over the lot of it. There's a camp on the Malesov road grown far too comfortable for a band of thieves.

  merc_kk_acc_6_b          Burn the nest and the road dies with it. Go on with you.

### Taking the report   [player picks: “The waystation's burnt. Fresh straw for forty horses.”]
  merc_kk_turn_6           Forty. God's teeth. That's a great many horses for a band of thieves.

  merc_kk_turn_6_b         That's no thieves' camp, that's a posting inn - and somebody's been keeping it stocked for a company that hasn't arrived yet.

------------------------------------------------------------------------
## 7. silver convoy

### Giving the job   [player picks: “Escort work?”]
  merc_kk_acc_7            That's how it was put to me. A supply column moving at dusk out of the eastern valley, a few men on it, nothing that need trouble a company your size.

  merc_kk_acc_7_b          What I wasn't told, I couldn't say - and if I knew, I'd have charged them a good deal more for it. Go carefully.

### Taking the report   [player picks: “Seven veterans and a knight. This was in the wagon.”]
  merc_kk_turn_7           ...That is a great deal of silver.

  merc_kk_turn_7_b         Then we'll say the wagon was empty when you came upon it. My share buys my silence and yours both. And there's a second seal on this letter, different from the first - whatever he's building, there's a siege at the end of it.

------------------------------------------------------------------------
## 8. ambush

### Giving the job   [player picks: “Stragglers in a hollow?”]
  merc_kk_acc_8            That's what the shepherd told me. A few men gone to ground in the hollow past the treeline, licking their wounds. An hour's work, if that.

  merc_kk_acc_8_b          Aye, I know - nothing's been an hour's work since you started listening to me. Charge me more and stop complaining. Off with you.

### Taking the report   [player picks: “They were waiting for me. Dug in, ground chosen.”]
  merc_kk_turn_8           Then they know. Somebody's counted the holes we've been putting in them and put a name to it.

  merc_kk_turn_8_b         Whose name, yours or mine, I couldn't tell you - and I'd rather not find out. Take your money and watch the road behind you.

------------------------------------------------------------------------
## 9. southern camp

### Giving the job   [player picks: “The southern camp.”]
  merc_kk_acc_9            I've been putting this one off, and I'll admit it. That isn't a camp, it's a town with tents over it. Every man who walks past goes in and doesn't come out again - deserters, runaways, anyone hungry enough. It sits astride the southern road and nothing moves past that they don't take a share of.

  merc_kk_acc_9_b          There'll be more of them than you'd like. Take every man you've got, and don't be proud about it.

### Taking the report   [player picks: “The camp's gone. I found a muster roll in it.”]
  merc_kk_turn_9           Sixty-odd names, and wages set against barely half of them. So he's taking on men he's no coin to pay.

  merc_kk_turn_9_b         That's not recruiting, that's a mob with a flag over it. And a mob has to be pointed at something before it turns round and eats its own paymaster.

------------------------------------------------------------------------
## 10. peasant looters

### Giving the job   [player picks: “Peasants under arms?”]
  merc_kk_acc_10           Armed peasants aren't soldiers, I know it. But there's a column of them on the east road carrying whatever they could lift, and they're walking away from the fighting rather than towards it. The farms along there have been stripped bare.

  merc_kk_acc_10_b         I want them stopped. Whether that means dead is your affair, not mine.

### Taking the report   [player picks: “It's done. They had scythes and bread knives.”]
  merc_kk_turn_10          That'll be the half of the roll with nothing set against it. He armed them, marched them, and never fed them once.

  merc_kk_turn_10_b        ...There's your money. Don't look at me like that - I only pass the work on, I don't write it.

### Taking the report - IF the column was dispersed, not killed   [player picks: “I let them go. They ran for the fields.”]
  merc_kk_turn_10b         Ran home, more likely, and good riddance to the whole business.

  merc_kk_turn_10b_b       Grain's cheaper than graves and a deal quieter, and I'd sooner not explain to a magistrate why we butchered a harvest's worth of farmhands.

------------------------------------------------------------------------
## 11. roman fort

### Giving the job   [player picks: “Four men?”]
  merc_kk_acc_11           Four. The old Roman fort up on the ridge, the one the shepherds won't go near. There were forty in it a fortnight ago and there are four in it now, and I would dearly like to know where the other thirty-six have got to.

  merc_kk_acc_11_b         And mark me - four men left to hold a place like that will be the four he trusts most. Don't go up there thinking it's a mercy.

### Taking the report   [player picks: “The fort's taken. Four men very nearly finished me.”]
  merc_kk_turn_11          Because they were the ones left behind when everyone cheaper had already marched. And now I know where to - it's written here plain enough. Raborsch.

  merc_kk_turn_11_b        He means to hold the ore there, strike it into coin there, and winter the whole company behind its walls. Which means the siege began while you were still climbing that ridge.

------------------------------------------------------------------------
## 12. swamp island

### Giving the job   [player picks: “What's left out in the marsh?”]
  merc_kk_acc_12           It's finished, near enough. But something came out of Raborsch alive and went east into the Kuttenberg marshes, and it took the last of the silver with it. A knight's harness was seen on the causeway.

  merc_kk_acc_12_b         Him again. Go and finish it, and then neither of us need speak of any of this ever again.

### Taking the report   [player picks: “It's over. He had a letter, written and never sent.”]
  merc_kk_turn_12          ...Then he was waiting on an answer that was never coming.

  merc_kk_turn_12_b        Give it here. The ore goes back to the mint, most of it, and the rest we'll not discuss. You did the work. Don't ask me where the money came from and I'll not ask you what you saw.
