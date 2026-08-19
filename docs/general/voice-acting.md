# How to Contribute Voicelines

This guide covers how to record voicelines for the mod. I'm no professional voice actor, so take this as practical advice from experience—for recording environment setup or acting technique, YouTube will serve you better than I will.

## What We Need

For now, the mod needs short ambient lines mercs say while walking around or following the player. Think **one to three sentences, self-contained but not trivial.** They could tell a short story, give advice, or muse on life, God, Henry, food—whatever feels right. Try to match the writing style of KCD2: give them a medieval ring to them. Don't overthink it; give your imagination free rein.

Write a few lines first (one or two to start) to test your setup before committing to a full batch.

---

## Step 1: Structure Your Lines

Chop your writing into individual voicelines. **Each line should be five to ten words**—roughly the amount of text that fits above an NPC's head in-game.

Create a table mapping each line to an ID:

| ID | Line |
|----|------|
| `merc_strawberry_story_1` | I used to gather strawberries by the basket |
| `merc_strawberry_story_2` | Eat them right off the bush |

Keep this table—you'll need it later.

---

## Step 2: Prepare Your Recording Setup

Quality matters. **A phone mic or most headsets won't cut it.** A standalone mic is required—a Blue Yeti or similar is ideal.

* Place the mic roughly **30 cm from your mouth**—close, but not too close.
* Record in a **small, quiet room**: no fans, AC, road noise, or PC hum.
* No quiet room? Try a **closet**, or cover yourself and the mic with a thick blanket.

---

## Step 3: Record

Each voiceline gets its **own file, named after its ID** from your table. Hit record, and re-record as many times as you need until you're happy with it. There's no rush.

---

## Step 4: Acting Advice

**Do not try to fake a raspy or "character" voice.** If you're not trained for it, you'll strain your vocal cords and lose your voice for a while—not worth it.

Instead: be yourself, but *inhabit the situation.* You've been marching all day in heavy armor. You don't know when the next ambush comes. You don't know if today is your last. Close your eyes, sit with that for a moment—then speak.

---

## Step 5: Post-Processing

The repo has a tool for this: `tools/voice_master.py` denoises, dereverbs, EQs and
levels a whole folder of takes to match base-game dialogue, and exports `.ogg` at
48000 Hz. Run `python tools/voice_master.py --gui <your folder>` for sliders and A/B
playback. See [voice-mastering.md](voice-mastering.md).

If you would rather do it by hand, at minimum:

1. **Denoise** and **normalize** your lines (Audacity handles both).
2. Play with the **equalizer** until it sounds right.
3. Search YouTube if something still sounds off.
4. Export as **`.ogg`, 48000 Hz**.

---

## Step 6: Send It In

Once you're happy with everything:

1. Put all your `.ogg` files in a folder alongside a `.txt` file containing your ID-to-line table from Step 1.
2. Zip the folder up.
3. Upload to Google Drive, set sharing to *"Anyone with the link"*, and send me the link.

I'll integrate your lines in the next update.
