--[[
  orchestration_data.lua
  Knowledge base for Orchestration Helper.

  Every statement here is drawn from the reference works listed in SOURCES
  below. Citation tags on each item point back to source + page.

  EDITORIAL RULE (consensus only)
  -------------------------------
  Combinations that the sources describe as rare, exceptional, seldom used or
  not recommended are NEVER listed as suggestions. They appear, if at all, only
  under "Use sparingly", so the encyclopaedia stays honest without recommending
  something no one actually writes.
]]--

local D = {}

D.SOURCES = {
  RK = {
    tag   = "RK",
    short = "Rimsky-Korsakov, Principles of Orchestration",
    full  = "Nikolay Rimsky-Korsakov, 'Principles of Orchestration, with Musical "
         .. "Examples Drawn from His Own Works', ed. Maximilian Steinberg, "
         .. "trans. Edward Agate (Paris: Edition Russe de Musique, 1922). Public "
         .. "domain. Page numbers follow Volume I of that edition.",
  },
  SIN = {
    tag   = "SIN",
    short = "Singleton, The Orchestra and Its Instruments",
    full  = "Esther Singleton, 'The Orchestra and Its Instruments' (New York: "
         .. "The Symphony Society of New York, 1917). Public domain. Quotes "
         .. "Berlioz, Lavignac, Gevaert, Forsyth and Stone at length; those "
         .. "attributions are kept in the text.",
  },
  WP = {
    tag   = "WP",
    short = "Wikipedia, “Orchestration”",
    full  = "Wikipedia contributors, 'Orchestration', Wikipedia, The Free "
         .. "Encyclopedia (CC BY-SA). Used for the standard instrumentation "
         .. "shorthand and for the orchestration bibliography.",
  },
}

-- e = entry constructor sugar; keeps the table literal below readable.
D.ENTRIES = {}
local function e(t) D.ENTRIES[#D.ENTRIES+1] = t; return t end

-- ============================================================================
-- SECTIONS
-- ============================================================================

e{ id="strings", name="String Section", family="Strings", kind="section",
  aliases={"strings","string","string group","string quartet","string orchestra",
           "bowed strings","stringed instruments"},
  summary="The five-part core of the orchestra and the group Rimsky-Korsakov ranks "
       .. "first for expression: \"We can listen to strings for an almost indefinite "
       .. "period of time without getting tired, so varied are their characteristics.\" "
       .. "Unlike the wind, its number of parts is constant whatever the size of the score.",
  facts={
    {"Parts","Violins I, Violins II, Violas, Violoncellos, Double basses"},
    {"Choir","Violins = soprano (I) and mezzo-soprano (II), Violas = alto/tenor, "
          .. "Violoncellos = tenor/bass, Double basses = deeper bass"},
  },
  sec={
    {"Standard roster", {
      {"Violins I","16 (full) / 12 (medium) / 8 (small)","RK p.6"},
      {"Violins II","14 / 10 / 6","RK p.6"},
      {"Violas","12 / 8 / 4","RK p.6"},
      {"Violoncellos","10 / 6 / 3","RK p.6"},
      {"Double basses","8-10 / 4-6 / 2-3","RK p.6"},
      {"Write for the medium body","\"Played by a larger orchestra a work will be "
        .. "heard to greater advantage; played by a smaller one, the harm done will "
        .. "be minimised.\" Fewer than 8 first violins destroys the balance against "
        .. "the wind; more than 20 obliges you to reinforce the wind.","RK p.6-7"},
    }},
    {"Pairings in unison", {
      {"Violins I + Violins II","No change of colour at all - pure string quartet "
        .. "tone, enriched and amplified. The weight of violins keeps any doubling "
        .. "woodwind from predominating.","RK p.39"},
      {"Violins + Violas","No special new character; the violins stay predominant "
        .. "and the resonance is rich and full.","RK p.39"},
      {"Violas + Violoncellos","Rich, full resonance with the 'cello quality on top.","RK p.39"},
      {"Violins + Violoncellos","Similar to the above but fuller; the 'cello tone "
        .. "prevails.","RK p.40"},
      {"Vns I + Vns II + Violas + ’Cellos","Only possible in the alto-tenor register. "
        .. "Complex, very tense and powerful in forte; extremely full and rich in piano.","RK p.40"},
      {"Violoncellos + Double basses","Rich and full; used for phrases in the very "
        .. "low register.","RK p.40"},
    }},
    {"Doublings in octaves", {
      {"Vns I / Vns II","Very common, above all for figures in the very high register, "
        .. "which otherwise stand too isolated from the ensemble. Secures expression, "
        .. "fullness and firmness.","RK p.40"},
      {"Vns / Violas","Common, especially when the lower octave falls below the "
        .. "violin's open G.","RK p.41"},
      {"Vns I + II / Violas","Use for greater brilliance in the upper part.","RK p.41"},
      {"Vns I / Vns II + Violas","Use to give the lower part a fuller, more "
        .. "cantabile quality.","RK p.41"},
      {"Violas / ’Cellos","Of special use when the violins are otherwise employed.","RK p.41"},
      {"Vns / ’Cellos","For very expressive passages with the 'cellos on the A or D "
        .. "string; more resonant than violas/'cellos, and frequent.","RK p.42"},
      {"’Cellos / D. basses","The normal construction of the bass. Examples are "
        .. "\"to be found everywhere\"; the bass part is sometimes simplified.","RK p.42"},
      {"Vns I + II / Violas + ’Cellos","Each octave doubled in unison. \"Constantly "
        .. "found\", and produces a beautiful tone, somewhat severe in character. For "
        .. "melodies in the middle orchestral range.","RK p.43"},
    }},
    {"Register rule", {
      {"Very high melodies","Above the middle of the 5th octave, double an octave "
        .. "below.","RK p.43"},
      {"Very low melodies","Below the middle of the 1st octave, double an octave "
        .. "above.","RK p.43"},
    }},
    {"Dividing the parts (divisi)", {
      {"Usual pairs","Vns I / Vns II  ·  Vns II / Violas  ·  Violas / 'Cellos  ·  "
        .. "'Cellos / D. basses.","RK p.7"},
      {"Less frequent","Vns I / Violas  ·  Vns II / 'Cellos  ·  Violas / D. basses.","RK p.7"},
      {"Prefer Vns II / Violas","Their numbers are nearly the same (14-10-6 against "
        .. "12-8-4), their roles are allied, and second violins normally sit nearer "
        .. "the violas - so power and execution stay unified.","RK p.8"},
      {"Marking","Always write how the passage divides: \"Vns I, 1, 2, 3 desks\", "
        .. "\"6 'Cellos div. a 3\". Division into four or more parts is rare and suits "
        .. "piano passages, as it greatly reduces volume.","RK p.7"},
    }},
    {"Balance against the wind", {
      {"Piano","One whole department (all Vns I, all Vns II ...) = one wind "
        .. "instrument.","RK p.33"},
      {"Forte","One whole department = two wind instruments, e.g. Violins I = 2 "
        .. "Flutes = 1 Oboe + 1 Clarinet.","RK p.33"},
    }},
    {"Use sparingly", {
      {"Divided strings of the same kind in octaves","Violas I / Violas II, "
        .. "'Cellos I / 'Cellos II, D. basses I / D. basses II: generally to be "
        .. "avoided, because the parts fall on strings that do not correspond and "
        .. "unity of tone is impaired. Violins are the exception.","RK p.44"},
      {"Violas / D. basses in octaves","Seldom arises; only when the 'cellos are "
        .. "otherwise employed.","RK p.42"},
      {"Violins divisi in octaves","Halves the number of players and so drains the "
        .. "melody of resonance - noticeable above all in small orchestras. Usable "
        .. "when the woodwind doubles the strings.","RK p.40-41"},
      {"Vns I / Vns II / Violas / ’Cellos / D. basses in 4 octaves","Very seldom "
        .. "found, and as a rule only when supported by wind.","RK p.45"},
      {"Solo double bass","\"Practically unknown\"; the solo viola is also seldom "
        .. "found. Violin and 'cello solos are the usual ones.","RK p.104"},
    }},

    {"Belkin’s practical notes", {
      {"Compare it with the choir","\"Like the vocal choir, the string family offers "
        .. "excellent homogeneity of timbre, and can play anything from the simplest "
        .. "monophonic line to the richest polyphony. Virtually anything that is "
        .. "suitable for choir will also sound well in strings\" - with a much wider "
        .. "range, greater mobility, more varied articulation, and chords.","BEL p.6"},
      {"Cross the parts freely","\"Unlike choral writing, string writing normally "
        .. "abounds in crossing. This allows the lower instruments to play the main line "
        .. "from time to time, and, most importantly, gives all the individual sections "
        .. "in the family freedom to move... Given the easy blend within the family, "
        .. "such crossing creates no special problems.\"","BEL p.6"},
      {"Pizzicato is percussion, not strings","\"They are best thought of as percussion "
        .. "sounds. While produced by string instruments, they have no timbral affinity "
        .. "with bowed strings.\" Treat plucked strings as pitched percussion when "
        .. "judging blend and contrast.","BEL p.7 & p.25"},
      {"They balance themselves","Unlike the woodwind, \"strings generally balance "
        .. "themselves regardless of voicing\".","MOD"},
    }},
  },
  related={"violin","viola","cello","doublebass","pizzicato","woodwind","brass"},
}

e{ id="woodwind", name="Woodwind Section", family="Woodwind", kind="section",
  aliases={"woodwind","woodwinds","wood-wind","wood wind","winds","wind section",
           "woodwind section","wws"},
  summary="Unlike the strings, the woodwind group varies in both the number of parts "
       .. "and its volume of tone, and the composer chooses the formation. The "
       .. "difference in register and quality between flutes, oboes, clarinets and "
       .. "bassoons is \"striking to a degree\".",
  facts={
    {"Natural order","Flutes, Oboes, Clarinets, Bassoons - the order used in full "
       .. "scores and the one that produces the most natural resonance"},
    {"Two colour classes","Nasal and dark: oboes, bassoons (+ English horn, "
       .. "contrabassoon). Bright 'chest-voice': flutes, clarinets (+ piccolo, "
       .. "alto flute, E-flat clarinet, bass clarinet)"},
  },
  sec={
    {"Formation — in pairs", {
      {"Flutes","2 (II takes piccolo)","RK p.13"},
      {"Oboes","2 (II takes English horn)","RK p.13"},
      {"Clarinets","2 (II takes bass clarinet)","RK p.13"},
      {"Bassoons","2","RK p.13"},
    }},
    {"Formation — in threes", {
      {"Flutes","3 (III takes piccolo, II takes alto flute)","RK p.13"},
      {"Oboes","2 + 1 English horn (III)","RK p.13"},
      {"Clarinets","3 (II takes E-flat clarinet, III takes bass clarinet)","RK p.13"},
      {"Bassoons","2 + 1 contrabassoon (III)","RK p.13"},
    }},
    {"Formation — in fours", {
      {"Flutes","1 piccolo (IV) + 3 flutes (III takes alto flute)","RK p.13"},
      {"Oboes","3 + 1 English horn (IV)","RK p.13"},
      {"Clarinets","3 (II takes E-flat clarinet) + 1 bass clarinet (IV)","RK p.13"},
      {"Bassoons","3 + 1 contrabassoon (IV)","RK p.13"},
    }},
    {"Who changes instruments", {
      {"Never the firsts","The first flute, first oboe, first clarinet and first "
        .. "bassoon never change instrument - their parts are too important to turn "
        .. "from one mouthpiece to another.","RK p.12"},
      {"The specials","Piccolo, alto flute, English horn, E-flat clarinet, bass "
        .. "clarinet and contrabassoon go to the second and third players, who are "
        .. "used to them.","RK p.12"},
    }},
    {"Pairings in unison", {
      {"Flute + Oboe","Fuller than the flute, sweeter than the oboe. Played softly "
        .. "the flute predominates low, the oboe in the upper register.","RK p.47"},
      {"Flute + Clarinet","Fuller than the flute, duller than the clarinet. Flute "
        .. "predominates lower, clarinet higher.","RK p.47"},
      {"Oboe + Clarinet","Fuller than either alone. The dark nasal oboe prevails low, "
        .. "the bright 'chest' clarinet high.","RK p.47"},
      {"Flute + Oboe + Clarinet","Very full. Flute predominates low, oboe in the "
        .. "middle, clarinet high.","RK p.48"},
      {"Bassoon + Clarinet","Very full. The clarinet's gloom prevails low, the "
        .. "bassoon's thinner quality higher.","RK p.48"},
    }},
    {"Doublings in octaves", {
      {"Natural order (upper / lower)","Fl/Ob  ·  Fl/Cl  ·  Ob/Cl  ·  Ob/Fag  ·  "
        .. "Cl/Fag. Deviating from it - bassoon above clarinet or oboe, clarinet "
        .. "above oboe or flute - confuses the registers and the relationship "
        .. "between the tone qualities is lost.","RK p.49"},
      {"Same branch, always good","Fag / C-Fag  ·  Cl / Bass cl  ·  Ob / Eng horn  "
        .. "·  E-flat cl / Cl  ·  Fl / Alto fl  ·  Picc / Fl.","RK p.50"},
      {"Extreme high compass","Double an octave lower: Picc/Fl, Picc/Ob, Picc/Cl.","RK p.50"},
      {"Extreme low compass","Double an octave higher: Fag/C-Fag, Bass cl/Fag, "
        .. "Cl/Fag, Cl/Bass cl.","RK p.50"},
      {"Mixed timbres in octaves","Fully available, following the same rules, e.g. "
        .. "Cl+Ob / Cl+Eng horn, or 2 Fl+Ob / 2 Cl+Eng horn.","RK p.50-51"},
      {"Three octaves","Fl/Ob/Cl  ·  Ob/Cl/Fag  ·  Fl/Cl/Fag  ·  Fl/Ob/Fag.","RK p.51"},
      {"Four octaves","Fl/Ob/Cl/Fag.","RK p.51"},
    }},
    {"Thirds and sixths", {
      {"For thirds, use one colour","2 Flutes, 2 Oboes, 2 Clarinets or 2 Bassoons - "
        .. "best for equality of tone.","RK p.52"},
      {"For sixths, mix colours","In natural register order: Fl/Ob, Fl/Cl, Ob/Cl, "
        .. "Cl/Fag, Ob/Fag.","RK p.52"},
      {"Doubled thirds and sixths","Fl+Ob / Fl+Ob, Fl+Cl / Fl+Cl, or Fl+Ob / Fl+Cl. "
        .. "Tripled: Fl+Ob+Cl / Fl+Ob+Cl, or Ob+2Fl / Ob+2Cl.","RK p.52-53"},
    }},
    {"Harmony", {
      {"Keep writing close","Modern practice allows no void in the intermediate "
        .. "parts. Widely-divided harmony is rare and belongs to piano passages; "
        .. "close writing is the more frequent form, forte or piano.","RK p.78"},
      {"In pairs, mix the doubled timbres","When the wind is in pairs it is a good "
        .. "plan to mix doubled timbres as much as possible. Each chord should be "
        .. "made entirely of doubled or entirely of undoubled parts.","RK p.77-79"},
      {"Overlaying beats crossing","Of overlaying, crossing and enclosure of parts, "
        .. "overlaying (strict natural order) is the best default. Three-part chords "
        .. "go to two instruments of one timbre and a third of another - never to "
        .. "three different timbres.","RK p.72-75"},
      {"Four different timbres","Fine in widely-divided four-part harmony (and the "
        .. "higher the registers, the less the gaps show), but to be avoided in "
        .. "close four-part harmony, where the registers will not correspond.","RK p.74"},
      {"Concords to like instruments","Give octaves, thirds and sixths to instruments "
        .. "of the same kind or colour, and discords to different ones - especially "
        .. "with the penetrating oboe.","RK p.72"},
    }},
    {"Playing characteristics", {
      {"Most flexible","Flutes, then clarinets; but the clarinet beats both for "
        .. "expressive power and subtlety, being able to reduce tone to a breath.","RK p.19"},
      {"Legato vs staccato","Flutes and clarinets excel in sustained legato; oboes "
        .. "and bassoons in distinct, penetrating staccato.","RK p.19"},
      {"Double tonguing","Only on the flute, the reedless instrument.","RK p.19"},
      {"Awkward leaps","The clarinet is not well adapted to sudden octave leaps; "
        .. "these are easier on flute, oboe and bassoon.","RK p.20"},
      {"Arpeggios","Rapid alternation of two intervals legato sounds well on flutes "
        .. "and clarinets, but not on oboes and bassoons.","RK p.20"},
      {"Breathing","Wind players cannot manage extremely long sustained passages - "
        .. "give them rest from time to time. String players need none.","RK p.20"},
    }},
    {"Use sparingly", {
      {"Bassoon + Oboe, Bassoon + Flute","\"Very seldom found except in certain "
        .. "orchestral tutti\", where they add resonance without creating a fresh "
        .. "atmosphere. The same applies to Bassoon+Clarinet+Oboe and "
        .. "Bassoon+Clarinet+Flute.","RK p.48"},
      {"All four in unison","Bassoon + Clarinet + Oboe + Flute is \"equally rare\"; "
        .. "the colour is rich but hard to define.","RK p.48"},
      {"Flute + Bassoon in octaves","Rare, because the two registers lie so far "
        .. "apart.","RK p.49"},
      {"Two of the same instrument in octaves","2 Flutes, 2 Clarinets or 2 Bassoons "
        .. "in octaves is \"certainly not to be recommended\" - the two registers do "
        .. "not correspond. Safe only when strings (arco or pizz.) double both, "
        .. "especially in the middle compass, for repeated or sustained notes.","RK p.49-50"},
      {"Over-doubling generally","Combining timbres adds resonance, sweetness and "
        .. "power but restricts variety of colour and expression: \"Individual "
        .. "timbres lose their characteristics when associated with others.\" Give "
        .. "phrases needing diverse expression to solo instruments.","RK p.48"},
    }},

    {"Belkin’s practical notes", {
      {"Each woodwind is three instruments","\"A good policy is to consider each "
        .. "woodwind as being three instruments in one: a high, a middle, and a low "
        .. "timbre. Combinations that work well in one register can be quite odd in "
        .. "another.\"","BEL p.7"},
      {"Each type is its own choir","\"Each type of woodwind is, in effect, a member of "
        .. "a separate choir: For example, clarinets are available from contrabass to "
        .. "piccolo.\" The double reeds - oboe, English horn, bassoon - can be treated "
        .. "as one family.","BEL p.7"},
      {"Chords are the hard part","\"The main problem in writing for woodwinds occurs "
        .. "when they are used in chords, due to their disparity of timbres.\" No "
        .. "woodwind chord \"blends in the way a string or a brass chord would\"; "
        .. "Rimsky-Korsakov's overlapping and enclosure \"work by making it difficult to "
        .. "decipher who is doing what, in effect fooling the ear\".","BEL p.7-8"},
      {"A different timbre per note is crude","\"The common beginner's mistake, of "
        .. "writing a chord with each note in a different timbre - e.g. four timbres for "
        .. "a four note chord - is very crude.\" Stacked arrangements are the worst; "
        .. "overlapping ones blend best.","BEL p.7-8"},
      {"The oboe decides the blend","\"When writing for massed woodwinds, the oboe is "
        .. "the instrument most likely to hurt the overall blend. It will definitively "
        .. "color any combination, for better or for worse.\" The same chord scored with "
        .. "oboes is \"considerably more pungent\".","BEL p.8"},
      {"With strings, the job is thickness","\"When used in the same plane of tone with "
        .. "strings, the main function of woodwinds is to add volume ('thickness').\" An "
        .. "octave above the strings they can instead add luminosity.","BEL p.8-9"},
      {"With brass, the job is the top of the chord","\"When used in chords, in the same "
        .. "plane of tone with the brass, the winds' main function is to complete the top "
        .. "of the harmony above, since doubling at the unison is virtually "
        .. "imperceptible.\"","BEL p.10"},
    }},
  },
  related={"flute","oboe","clarinet","bassoon","piccolo","englishhorn","bassclarinet",
           "contrabassoon","strings","brass","blend"},
}

e{ id="brass", name="Brass Section", family="Brass", kind="section",
  aliases={"brass","brasswind","brass-wind","brass section","brass group","horns and trumpets"},
  summary="The most resonant group. \"Though far less flexible than the wood-wind, "
       .. "brass instruments heighten the effect of other orchestral groups by their "
       .. "powerful resonance.\" Uniform in resonance throughout, but less suited to "
       .. "expressive playing than the woodwind - energetic power, simplicity and "
       .. "eloquence are its valuable qualities.",
  facts={
    {"Score order","Trumpets, Horns, Trombones, Tuba"},
    {"Swell","\"Brass instruments possess a remarkable capacity for swelling from "
       .. "pianissimo to fortissimo, and reducing the tone inversely\" - the sf > p "
       .. "effect is excellent"},
  },
  sec={
    {"Formation", {
      {"With woodwind in pairs","2 Trumpets, 4 Horns, 3 Trombones, 1 Tuba.","RK p.22"},
      {"With woodwind in threes","3 Trumpets (III takes alto trumpet, or use 2 "
        .. "Cornets + 2 Trumpets), 4 Horns, 3 Trombones, 1 Tuba.","RK p.22"},
      {"With woodwind in fours","3 Trumpets (II takes small trumpet, III alto or "
        .. "bass trumpet), 6 or 8 Horns, 3 Trombones, 1 Tuba.","RK p.22"},
    }},
    {"Balance — the key ratio", {
      {"1 Trumpet = 1 Trombone = 1 Tuba = 2 Horns","In forte the horns are only "
        .. "half as strong as the rest of the brass. To balance a forte you need two "
        .. "horns to one trumpet or trombone.","RK p.23 & p.33"},
      {"Mark the horns louder","If the trumpets and trombones play pp, mark the "
        .. "horns p. In piano all wind, wood and brass, are of fairly equal weight.","RK p.23"},
      {"Against the woodwind","1 Horn = 2 Clarinets = 2 Oboes = 2 Flutes = 2 "
        .. "Bassoons in forte.","RK p.33"},
      {"Cornets","Not quite the force of trumpets and trombones.","RK p.23"},
    }},
    {"Pairings in unison", {
      {"3 Trombones","Frequently met with; extreme power and resonance.","RK p.55"},
      {"4 Horns","Frequently met with; the standard way to give the horn group "
        .. "melodic weight.","RK p.55"},
      {"2 or 3 Trumpets","Used for fanfares and flourishes, which \"fall specially "
        .. "to the lot of the trumpets and horns\".","RK p.54-55"},
      {"4 Horns + 2 Trumpets","A standard reinforcement of the same line.","RK p.55"},
    }},
    {"Doublings in octaves, thirds, sixths", {
      {"The strongest brass doubling","Octaves between timbrally matched instruments - "
        .. "trumpets with trombones - give the most powerful brass doubling. Matching the "
        .. "timbre is what does it; this is the case where like with like wins.",
        "ACTOR Brass: Introduction"},
      {"Normal register order","Trumpet / 2 Horns  ·  Trumpet / Trombone  ·  "
        .. "Trombone / Tuba  ·  2 Trombones / Trombone + Tuba  ·  2 Trumpets / 2 "
        .. "Trombones  ·  2 Horns / Tuba. \"Likewise successful whether the "
        .. "instruments are doubled or not.\"","RK p.56"},
      {"Same kind in octaves","Because the group grades so evenly from dark low to "
        .. "bright high, using brass of the same kind in octaves, thirds or sixths "
        .. "\"invariably leads to satisfactory results\".","RK p.55-56"},
      {"Horns above trombones","2 Horns / 1 Trombone, or 4 Horns / 2 Trombones, "
        .. "exclusively in octaves. Possible, \"though not so reliable\".","RK p.56"},
    }},
    {"Harmony", {
      {"The horn quartet","4 Horns give every facility for perfectly balanced "
        .. "four-part harmony without doubling the bass in octaves.","RK p.82"},
      {"Best heavy layout","2 Horns + Tuba forming the bass in octaves, the three "
        .. "other parts on the trombones: \"beautiful full resonance\".","RK p.83"},
      {"Trombone quartet","The third trombone and tuba usually take the bass in "
        .. "octaves, the three upper parts going to the two remaining trombones "
        .. "reinforced by a trumpet or two horns in unison.","RK p.82-83"},
      {"High four-part","Two trumpets on the upper parts, completed by two trombones "
        .. "or four horns in pairs. With 3 trumpets, give the fourth part to one "
        .. "trombone or two horns in unison.","RK p.83"},
      {"Three-part","Best on trombones, horns or trumpets in threes. If the "
        .. "instruments are mixed, double the number of horns.","RK p.84"},
      {"Several parts","When the whole group plays, double the horns.","RK p.84"},
      {"Discords","Sevenths and seconds are better entrusted to instruments of "
        .. "different tone colour.","RK p.84"},
      {"Duplication","Place a horn chord beside the same chord on trumpets or "
        .. "trombones: the soft round horns intensify the tone and moderate the "
        .. "penetrating timbre.","RK p.85"},
      {"Sustained octaves","Usually 2 trumpets, or 2 or 4 horns. The trombone, "
        .. "with its ponderous tone, rarely takes part.","RK p.86"},
    }},
    {"Stopped and muted brass", {
      {"Where possible","Stopped notes only on trumpets, cornets and horns - the "
        .. "shape of trombones and tubas stops the hand entering the bell. Mutes are "
        .. "used on all brass, though tubas rarely have them.","RK p.25"},
      {"The resulting colour","Tone is deadened, wild and 'crackling' in forte, "
        .. "tender and dull in piano; resonance is greatly reduced, the silvery "
        .. "quality lost, and a timbre resembling oboe and English horn is approached. "
        .. "Muted brass produces an effect of distance.","RK p.25"},
      {"On the trumpet","Muting a note produces a better tone than stopping it. On "
        .. "the horn, single notes are stopped in short phrases and muted in longer "
        .. "ones.","RK p.25"},
    }},
    {"What suits the brass", {
      {"Fanfares and flourishes","The natural-scale figures - trumpet calls - are "
        .. "\"best adapted to the character of brass instruments\", and the full, "
        .. "clear, ringing middle and upper registers of horns and trumpets suit "
        .. "them best.","RK p.53-54"},
      {"Diatonic and unmodulated","After fanfares, the melodies that best suit brass "
        .. "are unmodulated and diatonic - rousing and triumphant in major, dark and "
        .. "gloomy in minor.","RK p.54"},
      {"Not passion or geniality","\"As a general rule, brass instruments lack the "
        .. "capacity to express passion or geniality. Phrases charged with these "
        .. "sentiments become sickly and insipid when confided to the brass.\"","RK p.55"},
      {"Chromatic writing","Much less suitable, though vigorous chromatic fanfares "
        .. "\"sound singularly beautiful on the brass\".","RK p.54-55"},
    }},
    {"Use sparingly", {
      {"Trumpets + trombones in juxtaposition","Less common than pairing either with "
        .. "horns, since it unites the two most powerful agents in the group.","RK p.85"},
      {"Re-entry after a rest","Trombones, trumpets and tuba are often tacet for long "
        .. "periods. When they return it should be at a characteristic intensity, pp "
        .. "or ff - a mezzo-forte re-entry \"produces a colourless and common-place "
        .. "effect\".","RK p.118"},
    }},

    {"Belkin’s practical notes", {
      {"More homogeneous than the woodwind","\"Brass are more homogeneous than "
        .. "woodwind, but less agile. They can play melodic, rhythmic, contrapuntal, and "
        .. "harmonic roles equally well. They also reproduce choral writing better than "
        .. "woodwind; in much early music, brass, especially trombones, simply double "
        .. "the voices.\"","BEL p.10-11"},
      {"Horns are alto instruments","\"Beginners often place them much too low or let "
        .. "them wander too high.\" The best arrangement in harmony: \"three or four "
        .. "horns, in close position, in the range of the alto voice\", sometimes with "
        .. "the fourth doubling the first an octave lower.","BEL p.11"},
      {"High and low horn specialists","Horns 1 and 3 are the high players, 2 and 4 the "
        .. "low, seated alternately. \"Thus, the 'high' horns are uncomfortable on the "
        .. "bottom notes, and the 'low' horns are uncomfortable on the top notes.\"","BEL p.11"},
      {"Low horns for pedals only","\"The horns' lowest notes are best reserved for slow "
        .. "moving pedal passages; they are not suitable for mobile bass lines, which "
        .. "they tend to render ponderous.\"","BEL p.11"},
      {"Write in the spirit of the natural instrument","Piston's advice, which Belkin "
        .. "endorses: prefer open intervals like fifths and octaves, and generally "
        .. "diatonic lines. \"Although horns are now of course chromatic instruments, "
        .. "extreme agility is not in their nature\" - and the same is true of "
        .. "trumpets, though both manage rapid repeated notes.","BEL p.11-12"},
      {"Trumpets need close spacing, trombones do not","\"Trumpets sound oddly empty in "
        .. "wide spacing; trombones, on the other hand, sound full in both open and "
        .. "closed positions.\"","BEL p.12"},
      {"Trombones are lighter than horns in the baritone register","\"A useful fact to "
        .. "remember when using brass to accompany solo instruments, or the human "
        .. "voice.\"","BEL p.12"},
      {"Muted brass is a separate family","\"So different is their timbre from open "
        .. "brass. When soft, muted brass are quite close to double reeds in sound; when "
        .. "loud, their strident sound puts them in a class of their own.\" This is the "
        .. "modern statement of Rimsky-Korsakov's oboe/English-horn "
        .. "affinity.","BEL p.13; cf. RK p.36"},
    }},
  },
  related={"horn","trumpet","trombone","tuba","cornet","woodwind","strings","blend"},
}

e{ id="percussion", name="Percussion Section", family="Percussion", kind="section",
  aliases={"percussion","percussion section","battery","drums","drum section"},
  summary="Two families: instruments of determinate pitch (timpani, glockenspiel, "
       .. "celesta, xylophone, bells) and instruments of indeterminate pitch, which "
       .. "\"do not take any harmonic or melodic part in the orchestra\" and are "
       .. "purely rhythmic and ornamental. Singleton calls the whole group the "
       .. "\"Battery\".",
  facts={
    {"Determinate pitch","Timpani, glockenspiel, celesta, xylophone, tubular bells, piano"},
    {"Indeterminate pitch","Triangle, castanets, little bells, tambourine, rute, "
       .. "side drum, cymbals, bass drum, gong"},
  },
  sec={
    {"Register classes (for matching to the harmony)", {
      {"High","Triangle, castanets, little bells.","RK p.32"},
      {"Medium","Tambourine, rute (switch), side drum, cymbals.","RK p.32"},
      {"Deep","Bass drum, Chinese gong.","RK p.32"},
    }},
    {"Standard pairings", {
      {"Triangle or tambourine tremolo","+ trills in woodwind and violins.","RK p.117"},
      {"Side drum tremolo, or cymbals struck with drum sticks","+ sustained chords "
        .. "on trumpets and horns.","RK p.117"},
      {"Bass drum or gong tremolo","+ chords on trombones, or low sustained notes on "
        .. "'cellos and double basses.","RK p.117"},
      {"Match register to register","Triangle, side drum and tambourine go best with "
        .. "harmony in the upper register; cymbals, bass drum and gong with harmony in "
        .. "the lower.","RK p.117"},
      {"Plucked strings + percussion","\"Excellent; the two blend perfectly, and the "
        .. "consequent increase in resonance yields an admirable effect.\"","RK p.34"},
      {"Wind clarifies percussion","Wood and brass strengthen and clarify pizzicato "
        .. "strings, harp, timpani and percussion generally, while the percussion "
        .. "lends a touch of relief to the woodwind.","RK p.34"},
    }},
    {"Use with rhythm", {
      {"Always double a rhythmic figure","\"Whenever some portion of the orchestra "
        .. "executes a rhythmic figure, percussion instruments should always be "
        .. "employed concurrently.\"","RK p.117"},
      {"Match the rhythm to the instrument","An insignificant and playful rhythm "
        .. "suits triangle, tambourine, castanets and side drum; a vigorous and "
        .. "straightforward one the bass drum, cymbals and gong.","RK p.117"},
      {"Where the strokes fall","Almost invariably on strong beats, highly-accented "
        .. "syncopations, or disconnected sforzandi. The triangle, side drum and "
        .. "tambourine can manage various rhythmic figures.","RK p.117"},
    }},
    {"Writing for the players, not just the instruments", {
      {"Leave time to move","\"A common mistake is to allow insufficient time for "
        .. "players to change instrument or pick up new beaters.\" Pay attention to the "
        .. "physical requirements of the section - the choreography of both players and "
        .. "beaters.","HUG Percussion Section"},
      {"Count the players, not the instruments","Any number of percussion instruments "
        .. "may appear in a score, but they are covered by a fixed number of "
        .. "percussionists, and the timpanist is not one of them.","HUG Percussion Section"},
    }},
    {"Economy", {
      {"Use it seldom","\"The percussion is seldom employed, and practically never "
        .. "all together, but in single instruments or in two's and three's.\" In "
        .. "national dances or ballad style it may be used more freely.","RK p.118"},
      {"Order of frequency","Strings, woodwind, brass, timpani, harps, pizzicato, "
        .. "then percussion - and within percussion: triangle, cymbals, bass drum, "
        .. "side drum, tambourine, gong. Celesta, glockenspiel and xylophone stand "
        .. "further off still, being too characteristic to use often.","RK p.118"},
      {"Careful — they win","Bass drum, cymbals, gong and a fortissimo side-drum "
        .. "tremolo are each \"sufficient to overpower any orchestral tutti\".","RK p.117"},
      {"Against the voice","Percussion rarely accompanies a singer; a timpani figure "
        .. "or tremolo, sometimes the triangle, less often cymbals.","RK p.124"},
    }},
    {"Bowing that imitates percussion", {
      {"Col legno","Strings played with the wood of the bow produce a sound similar "
        .. "to the xylophone, gaining in quality as the number of players increases.","RK p.32"},
    }},

    {"The five functions percussion can serve", {
      {"Accent","\"Adding percussion sharpens the accents, adding impact and power.\" "
        .. "Countless classical final chords add timpani for exactly this.","BEL p.13-14"},
      {"Melody","A marimba line \"emerges easily over the mysterious chord played by "
        .. "divided strings\". Shostakovich's Fifteenth gives the timpani a passacaglia "
        .. "theme while pitched percussion dances around it.","BEL p.14-15"},
      {"Rhythm","Bartok's Concerto for Orchestra opens its second movement with the "
        .. "snare drum, snares off, presenting a theme.","BEL p.15"},
      {"Resonance","\"Without the quiet cymbal roll, the flute line would sound patchy "
        .. "and empty.\" Note that rolls can be \"composed in overlapping waves\" rather "
        .. "than left continuous.","BEL p.15"},
      {"Transition between dynamics","A diminuendo timpani roll \"provides a smooth "
        .. "transition between the loud tutti which precedes it, and the very quiet "
        .. "passage which follows\" - Bruckner's Ninth, first movement.","BEL p.16"},
    }},
    {"Classify by material, not by name", {
      {"Metal is wet","\"Normally 'wet', with substantial reverberation, and therefore "
        .. "not well suited to quick, precise rhythms. On the other hand, they can "
        .. "supply background ambiance very well.\"","BEL p.13"},
      {"Wood is dry","\"Best used where clarity and definition are important.\"","BEL p.13"},
      {"Membranes are in between","\"When low, they can reverberate quite long; as they "
        .. "get higher, their sound resembles that of the wooden percussion.\"","BEL p.13"},
      {"Match the register","\"When percussion is combined with other families in the "
        .. "same plane of tone, it should correspond in register to the music around "
        .. "it\" - the same rule Rimsky-Korsakov gives.","BEL p.16; cf. RK p.117"},
    }},
  },
  related={"timpani","triangle","cymbals","bassdrum","sidedrum","tambourine",
           "glockenspiel","celesta","xylophone","harp"},
}

e{ id="plucked", name="Plucked Strings (group)", family="Plucked", kind="section",
  aliases={"plucked strings","plucked","pizzicato group","harp and pizzicato"},
  summary="Rimsky-Korsakov treats the string quartet played pizzicato together with "
       .. "the harp as a separate group with its own quality of tone, because both "
       .. "produce sound the same way. \"More an instrument of colour than "
       .. "expression.\"",
  sec={
    {"Members", {
      {"Core","Violins I, Violins II, Violas, 'Cellos, D. basses played pizzicato, "
        .. "plus the harp.","RK p.26"},
      {"Also classifiable here","Guitar, zither, balalaika, and quill-plucked "
        .. "instruments such as the domra and mandoline - all usable in an orchestra.","RK p.26"},
    }},
    {"Pairings", {
      {"+ Woodwind or brass","Wind strengthens and clarifies pizzicato strings and "
        .. "harp; the plucked group in turn lends relief to the woodwind.","RK p.34"},
      {"+ Percussion","Excellent - \"the two blend perfectly\".","RK p.34"},
      {"+ Harp and piano","Harp with piano imitates a popular plucked instrument or "
        .. "a soft peal of bells.","RK p.30"},
      {"Tutti pizzicato","The pizzicato quartet, sometimes reinforced by harp and "
        .. "piano, can form a tutti of its own - medium power but fairly brilliant; "
        .. "it only attains real strength with woodwind support.","RK p.103"},
      {"Best setting for a singer","Strings pizzicato + harp \"forms a setting "
        .. "eminently favourable for the voice\".","RK p.120"},
    }},
    {"Use sparingly", {
      {"+ Bowed strings","Uniting plucked with bowed strings \"does not produce such "
        .. "a satisfactory blend, both qualities being heard independently\".","RK p.34"},
      {"Pizzicato chords on open strings","Better avoided - open strings sound more "
        .. "brilliant than covered ones. Four-note chords allow the freest, most "
        .. "vigorous attack.","RK p.27"},
      {"Speed","Pizzicato can never be as quick as arco, and is slower the thicker "
        .. "the string - much slower on double basses than violins.","RK p.27"},
    }},
  },
  related={"pizzicato","harp","percussion","strings"},
}

-- ============================================================================
-- CROSS-GROUP TOPICS
-- ============================================================================

e{ id="strings_wind", name="Strings + Woodwind", family="Combining", kind="topic",
  aliases={"strings and woodwind","strings + woodwind","strings with woodwind",
           "woodwind and strings","string wind combination"},
  summary="\"All combinations of strings and wood-wind are good.\" A wind instrument "
       .. "in unison with a string group increases its resonance and amplifies its "
       .. "tone, while the strings soften the wind. Every combination refines the "
       .. "character of each instrument taken separately - the woodwind losing more "
       .. "than the strings.",
  sec={
    {"Best unison pairs (matched registers)", {
      {"Violins + Flute","Also alto flute or piccolo.","RK p.58"},
      {"Violins + Oboe","",  "RK p.58"},
      {"Violins + Clarinet","Also E-flat clarinet.","RK p.58"},
      {"Violas + Oboe","Also English horn.","RK p.58"},
      {"Violas + Clarinet","",  "RK p.58"},
      {"Violas + Bassoon","",  "RK p.58"},
      {"’Cellos + Clarinet","Also bass clarinet.","RK p.58"},
      {"’Cellos + Bassoon","",  "RK p.58"},
      {"D. basses + Bassoon","Also bass clarinet or contrabassoon.","RK p.58"},
    }},
    {"Why do it", {
      {"Three objects","(a) to obtain a new timbre of definite colour; (b) to "
        .. "strengthen the resonance of the strings; (c) to soften the quality of "
        .. "the wood-wind.","RK p.58"},
      {"Who wins","With instruments of equal power the strings predominate (violins "
        .. "with an oboe, bassoon with the 'cellos). If several winds play in unison "
        .. "against one string group, the strings are overpowered.","RK p.58"},
    }},
    {"Absorption — wind swallows the strings", {
      {"2 Fl + 2 Ob + Violins I","One department of strings added to woodwind in "
        .. "unison gives a sweet coherent quality with the wind timbre still "
        .. "predominating.","RK p.34"},
      {"2 Ob + 2 Cl + Violas","As above.","RK p.34"},
      {"2 Cl + 2 Fag + ’Cellos","As above.","RK p.34"},
    }},
    {"Thickening — strings swallow the wind", {
      {"Vns I + Vns II + 1 Oboe","Adding a single wind to all or part of the strings "
        .. "in unison \"only thickens the resonance of the latter, the wood-wind "
        .. "timbre being lost in the process\".","RK p.34"},
      {"Violas + ’Cellos + 1 Clarinet","As above.","RK p.34"},
      {"’Cellos + D. basses + 1 Bassoon","As above.","RK p.34"},
    }},
    {"Octaves", {
      {"Prefer wind in both octaves","When only one of two octaves is doubled and "
        .. "the melody is in the soprano register, let the woodwind take both octaves "
        .. "and double only the lower part with strings: Picc / Fl + Vns, or Fl / Ob "
        .. "(Cl) + Vns.","RK p.60"},
      {"Sweet low register","'Cellos + Bassoon / D. basses, the double basses "
        .. "undoubled.","RK p.60"},
      {"In three and four octaves","e.g. Vns + 3 Fl / Violas + 2 Ob / 'Cellos + 2 "
        .. "Fag, or Vns I + Picc / Vns II + Fl + Ob / Violas + 'Cellos + 2 Cl + Eng "
        .. "horn + Fag.","RK p.59"},
    }},
    {"In harmony", {
      {"Natural layout","Fl / Ob (Cl) + Vns divisi; Cl / Fag + 'Cellos + Violas "
        .. "divisi. Frequently used as comparison of one timbre with another over "
        .. "sustained notes or string tremolando.","RK p.94"},
      {"Sforzando-piano","As the woodwind begins a piano chord, let the strings "
        .. "attack it sforzando (arco or pizz.) - a compound chord for preference. "
        .. "Reverse the order for a cresc.-sf effect.","RK p.111"},
    }},
    {"Use sparingly", {
      {"One group above the other in octaves","Fl / Vns, Ob / 'Cellos and the like - "
        .. "\"not to be recommended, as the tone quality of the two groups is so "
        .. "widely different\" (Steinberg's note; used by the classics for balance, "
        .. "and revived by younger French composers).","RK p.60 n."},
      {"Muted strings + woodwind","They \"do not combine so well\", the two "
        .. "qualities remaining distinct and separate.","RK p.34"},
    }},
  },
  related={"strings","woodwind","strings_brass","three_groups","blend"},
}

e{ id="strings_brass", name="Strings + Brass", family="Combining", kind="topic",
  aliases={"strings and brass","strings + brass","brass and strings","string brass combination"},
  summary="\"Owing to the dissimilarity between the quality of string and brass tone, "
       .. "the combination of these two groups in unison can never yield such a "
       .. "perfect blend as that produced by the union of strings and wood-wind.\" "
       .. "Each instrument is still heard separately - so match the registers and "
       .. "choose the effect deliberately.",
  sec={
    {"Pairs that work (matched registers)", {
      {"Violin + Trumpet","The nearest corresponding registers in the two groups.","RK p.61"},
      {"Viola + Horn","",  "RK p.61"},
      {"’Cellos / D. basses + Trombones / Tuba","For heavy, massive effects.","RK p.61"},
      {"Horns + ’Cellos","\"Frequently employed, produces a beautifully blended, "
        .. "soft quality of tone.\" This is the one combination of the two groups "
        .. "Rimsky-Korsakov singles out for praise.","RK p.61"},
      {"Horns + divided Violas or ’Cellos","\"The splendid effect of horns doubled by "
        .. "divided violas or 'cellos\" - the exception worth seeking out in harmony.","RK p.95"},
    }},
    {"In harmony", {
      {"Keep them apart, not interleaved","Juxtaposition, crossing and enclosure of "
        .. "parts between strings and brass are \"seldom employed\", for lack of any "
        .. "affinity in tone quality.","RK p.94-95"},
      {"When juxtaposition works","When the strings form the harmony tremolando and "
        .. "the brass sustains chords; or when the strings play short disconnected "
        .. "chords sforzando.","RK p.95"},
    }},
    {"Use sparingly", {
      {"Doubling the voice with brass","\"Trombones and trumpets overpower the voice "
        .. "and cannot be used for this purpose.\"","RK p.122"},
    }},
  },
  related={"strings","brass","strings_wind","three_groups","blend"},
}

e{ id="wind_brass", name="Woodwind + Brass", family="Combining", kind="topic",
  aliases={"woodwind and brass","wind and brass","woodwind + brass","brass and woodwind",
           "wind brass combination"},
  summary="\"The combination of a wood-wind and brass instrument produces a complex "
       .. "resonance in which the tone of the brass predominates\" - more powerful "
       .. "than either alone, but slightly sweeter than the brass by itself. The wind "
       .. "blends with the brass, softens and rarefies it, and yields a finer legato "
       .. "than the brass alone.",
  sec={
    {"Pairings in unison", {
      {"Trumpet + Clarinet","The trumpet is the brass instrument most frequently "
        .. "doubled; also Trumpet + Oboe, Trumpet + Flute, and Trumpet + Cl + Ob + "
        .. "Fl. Instances are numerous, especially in forte.","RK p.56"},
      {"Horn + Clarinet","Less often doubled than the trumpet; also Horn + Bassoon.","RK p.57"},
      {"Trombone + Bassoon","Also Tuba + Bassoon.","RK p.57"},
      {"Trombone + English horn","Combining English horn, bass clarinet and "
        .. "contrabassoon with the brass in corresponding registers shows the same "
        .. "characteristics; also 3 Trombones + Bass clarinet.","RK p.57"},
      {"Chord blocks in unison","2 or 3 Trumpets + the same number of Fl, Ob or Cl.  "
        .. "2 or 3 Horns + the same number of Fag or Cl. Also 2 Horns + 2 Fag + 2 Cl.","RK p.88"},
      {"Full brass + full woodwind","A chord for full brass doubled by the same chord "
        .. "for full woodwind in pairs \"produces a magnificent and uniform tone\".","RK p.88"},
    }},
    {"Doublings in octaves", {
      {"Woodwind above one horn","2 Ob, or 2 Cl, or 2 Fl above 1 Horn - this often "
        .. "replaces 1 Trumpet / 1 Horn when you want a richer upper octave than the "
        .. "trumpet can give. Also 1 Ob + 1 Cl / 1 Horn.","RK p.57"},
      {"Woodwind above two horns","If two horns play the lower octave in unison you "
        .. "need three or four wind instruments above, especially in forte: 2 Fl + 2 "
        .. "Cl / 2 Horns.","RK p.57"},
      {"Doubling a trumpet an octave up","Three or four wind instruments are needed - "
        .. "but in the top register two flutes will suffice.","RK p.58"},
    }},
    {"In harmony", {
      {"Bassoon and horn are the bridge","\"The bassoon and horn are the two "
        .. "instruments best capable of reconciling the groups of wood-wind and "
        .. "brass.\" Four-part harmony on 2 Bassoons + 2 Horns yields a finely "
        .. "balanced tone recalling a horn quartet but slightly more transparent - "
        .. "in soft passages.","RK p.90"},
      {"Cross them for blend","In that combination give the concords to the horns and "
        .. "the discords to the bassoons. Bassoons may also be written inside the "
        .. "horns, but not the reverse.","RK p.90-91"},
      {"Completing a horn chord","In the upper register and the higher harmonic "
        .. "parts, a piano chord of four horns may be completed by clarinets as "
        .. "effectively as by oboes or flutes, with a bassoon doubling the bass an "
        .. "octave below.","RK p.92"},
      {"Balance in forte","Played forte the horns are stronger than the woodwind; "
        .. "restore balance by doubling the upper harmonic parts. In difficult cases "
        .. "mark the woodwind one degree louder than the brass.","RK p.92 & p.94"},
      {"Who moves, who holds","In a chain of consecutive chords, entrust the "
        .. "stationary parts to the brass and the moving parts to the woodwind.","RK p.91"},
      {"Above the trumpets","If trumpets and trombones take part in a chord, put "
        .. "flutes, oboes and clarinets in the harmonic part above the trumpets.","RK p.93"},
      {"Flute thirds between trumpet octaves","In soft passages, thirds in the low "
        .. "register of the flutes - sometimes with clarinets - \"produce a beautiful "
        .. "mysterious effect between trumpets in octaves\".","RK p.91"},
    }},
    {"Stopped and muted brass with reeds", {
      {"Muted brass + oboe / English horn","Stopped or muted trumpets and horns "
        .. "resemble the oboe and English horn in quality; \"the combination of these "
        .. "instruments produces a magnificent tone\".","RK p.89"},
      {"Stopped horns + clarinet","\"A beautiful dark tone is derived from the "
        .. "combination of middle notes in stopped horns and deep notes in the "
        .. "clarinet.\" Substituting bassoons for clarinets loses part of the "
        .. "character.","RK p.89"},
      {"Muted trumpets as an echo","\"Muted trumpets are eminently suited to echo a "
        .. "theme in the oboes\"; flutes may imitate clarinets and oboes successfully. "
        .. "A woodwind instrument cannot echo the strings, or the reverse.","RK p.110"},
    }},
    {"Use sparingly", {
      {"Woodwind above a trombone","\"Wood-wind instruments should not be used to "
        .. "double a trombone in the octave above; trumpets are more suitable.\"","RK p.58"},
      {"3 Trombones + 3 Bassoons / 3 Clarinets","\"Very rare.\"","RK p.88"},
      {"Clarinets inside the horns","\"On account of their tone quality\" clarinets "
        .. "should rarely be set inside the horns.","RK p.92"},
      {"2 Bassoons + 2 Horns in forte","The horns overwhelm the bassoons - \"it is "
        .. "wiser to employ four horns alone\".","RK p.90"},
    }},
  },
  related={"woodwind","brass","horn","bassoon","trumpet","three_groups","blend"},
}

e{ id="three_groups", name="All Three Groups Combined", family="Combining", kind="topic",
  aliases={"three groups","all three groups","strings woodwind brass","full combination",
           "combining the three groups","tutti combination"},
  summary="\"The combination of the three different timbres in unison produces a rich, "
       .. "mellow and coherent tone\" - the woodwind's presence is what makes the "
       .. "blend full and even. Which group predominates depends on how many "
       .. "instruments you use. Reserve these groupings for loud passages or a heavy "
       .. "piano effect.",
  sec={
    {"The standard groupings", {
      {"Violins + Oboe (or Flute, Clarinet) + Trumpet","The soprano grouping.","RK p.61"},
      {"Violas (or ’Cellos) + Clarinet (or English horn) + Horn","The alto-tenor "
        .. "grouping.","RK p.61"},
      {"’Cellos / D. basses + 2 Bassoons + 3 Trombones + Tuba","The bass grouping.","RK p.61"},
    }},
    {"In harmony", {
      {"Side by side","Setting strings, woodwind and brass side by side \"produces a "
        .. "full, round and firm tone\".","RK p.95"},
      {"What matters most","Balance and distribution matter far more in long "
        .. "sustained or rhythmic chords than in short disconnected ones - though the "
        .. "latter should not be neglected entirely.","RK p.95-96"},
    }},
    {"Tutti", {
      {"Full tutti","All three melodic groups - strings, wind, brass - together. "
        .. "\"All\" is relative: in the extreme high register the piccolo may be "
        .. "essential, in the low register the flutes unnecessary, and the passage is "
        .. "still a tutti.","RK p.101-102"},
      {"Partial tutti","Only part of the brass takes part, e.g. 2 horns alone, or 2 "
        .. "horns with 1-3 trombones and no tuba, trumpets or remaining horns.","RK p.101"},
      {"Tutti in the wind","Woodwind and brass alone, most often with horn support. "
        .. "Adding timpani and percussion gives what the Germans call "
        .. "\"Janitscharenmusik\". Wind tutti is not very powerful in forte; brass "
        .. "tutti alone can reach extraordinary volume.","RK p.103"},
      {"Sharpening wind tutti","'Cello and double bass pizzicato notes, the rest of "
        .. "the strings and the harps are often added - this renders the sustained "
        .. "woodwind notes more distinct.","RK p.103"},
      {"Dynamic","The tutti is used essentially in forte and fortissimo, rarely in "
        .. "piano and pianissimo.","RK p.102"},
    }},
    {"Building and unwinding", {
      {"Crescendo order","Add instruments in this order: strings, wood-wind, brass.","RK p.112"},
      {"Diminuendo order","Remove them in reverse: brass, wood-wind, strings.","RK p.112"},
      {"Amplification","While the first group makes its crescendo gradually, the "
        .. "second enters piano and crescendos faster, so a simple timbre becomes a "
        .. "complex one and the whole process tightens.","RK p.109"},
    }},
    {"Economy", {
      {"The warning","\"Neither musical feeling nor the ear itself can stand, for "
        .. "long, the full resources of the orchestra combined together.\" A group "
        .. "that has been silent gains fresh interest on reappearing.","RK p.118"},
      {"Against constant mixing","\"The constant use of compound timbres, in pair's, "
        .. "in three's etc. eliminates characteristics of tone, and produces a dull, "
        .. "neutral texture, whereas the employment of simple, elementary combinations "
        .. "gives infinitely greater scope for variety in colour.\"","RK p.35"},
    }},
  },
  related={"strings_wind","strings_brass","wind_brass","balance","blend","strings"},
}

e{ id="blend", name="Blend Bridges Between Groups", family="Combining", kind="topic",
  aliases={"blend","bridges","blend bridges","links between groups","what blends with what",
           "affinity","timbre bridges"},
  summary="Rimsky-Korsakov names the specific points of contact where one group's "
       .. "colour shades into another's. These are the most reliable seams to write "
       .. "across when you want a join nobody hears.",
  sec={
    {"The bridges", {
      {"String harmonics – Flute / Piccolo","\"The relationship which exists between "
        .. "string harmonics and the flute or piccolo constitutes a link between the "
        .. "two groups in the upper range of the orchestra.\"","RK p.35"},
      {"Viola – Bassoon (middle) / Clarinet (lowest)","\"The timbre of the viola may "
        .. "be vaguely compared to the middle register of the bassoon and the lowest "
        .. "compass of the clarinet; hence, in the medium orchestral range, a point of "
        .. "contact is established between the quartet of strings and the wood-wind.\"","RK p.35-36"},
      {"Bassoon – Horn","\"The bassoon and horn provide the connection between "
        .. "wood-wind and brass, these two instruments being somewhat analogous in "
        .. "character when played piano or mezzo-forte.\" The horn \"serves as a link "
        .. "between the brass and wood-wind\".","RK p.36 & p.24"},
      {"Low Flute – pianissimo Trumpet","\"The flute also, in its lowest register, "
        .. "recalls the pianissimo trumpet tone.\"","RK p.36"},
      {"Stopped / muted Horns and Trumpets – Oboe / English horn","\"Similar in "
        .. "quality to the oboe and Eng. horn, and blend tolerably well with the "
        .. "latter instrument.\"","RK p.36"},
    }},
    {"What the groups do to each other", {
      {"Wind thickens strings, softens brass","\"Re-inforcing both, the wind "
        .. "thickens the strings and softens the brass.\"","RK p.35"},
      {"Strings and brass stay separate","\"The strings do not blend so well with the "
        .. "brass, and when the two groups are placed side by side, each is heard too "
        .. "distinctly.\"","RK p.35"},
      {"All three in unison","\"Produces a rich, mellow and coherent tone.\"","RK p.35"},
    }},
    {"Berlioz’s statement of the aim", {
      {"What combining is for","He sets out two purposes: modifying the sound of some "
        .. "instruments by others, and drawing from the ensemble a sound that none of "
        .. "them could produce alone or with others of its own family. The second is the "
        .. "ambition behind everything on this page - and, written in 1843, it is the "
        .. "mixture principle described under Doubling, a century before it was analysed "
        .. "as such.","BERL Introduction"},
      {"And what cannot be taught","Berlioz thought the invention of beautiful "
        .. "orchestral effects could not be explained - a gift practice and observation "
        .. "develop rather than supply. What can be taught, he says, is how to assemble "
        .. "an orchestra fit to render a given work faithfully. This encyclopaedia is on "
        .. "the teachable side of that line, and does not pretend otherwise.",
        "BERL The Orchestra"},
    }},
    {"Ranking for expression", {
      {"The order","Strings first, then woodwind, brass, plucked strings, percussion "
        .. "of definite pitch, percussion of indefinite pitch. \"As regards "
        .. "expression, the strings come first, and the expressive capacity of the "
        .. "other groups diminishes in the above order, colour being the only "
        .. "attribute of the last group.\"","RK p.35"},
    }},
  },
  related={"strings_wind","wind_brass","strings_brass","balance","three_groups"},
}

e{ id="spectrum", name="Overtones, Formants and Penetration", family="Craft", kind="topic",
  aliases={"overtones","overtone","formants","formant","spectrum","spectra",
           "penetration","penetrating","harmonics of a sound","timbre acoustics",
           "why is it loud","cuts through","brightness","hiss"},
  summary="Why one instrument cuts through a tutti and another vanishes, when both are "
       .. "marked forte. The answer is usually not power but the shape of the sound's "
       .. "overtone spectrum - and it changes from register to register on the same "
       .. "instrument, sometimes from note to note.",
  facts={
    {"The rule of thumb","Strong, high overtones penetrate. Few overtones blend, and "
        .. "can be masked by the overtones of instruments below."},
    {"Why it matters","Knowledge of volume and timbre across an instrument's registers "
        .. "is \"a fundamental requirement for any instrumentation\"."},
  },
  sec={
    {"Sounds that cut through", {
      {"Where it comes from","Formants - powerful high-pitched peaks or clusters in "
        .. "the spectrum. They are audible as a kind of \"hiss\" in the sound, and they "
        .. "are what makes a tone intense and penetrating.","IDIO ch.12"},
      {"The list","Oboe; sharply muted brass, especially loud; stopped horn; the "
        .. "clarinet's low chalumeau register; the violin's G string; the 'cello's A "
        .. "string; low contrabassoon, and to some extent low bassoon.","IDIO ch.12"},
      {"Sul ponticello","Bowing at the bridge - or near the soundboard on the harp - "
        .. "produces high, powerful formants which the player can modulate by bow "
        .. "placement and pressure, to the point where the fundamental disappears "
        .. "entirely.","IDIO ch.12"},
    }},
    {"Sounds that blend", {
      {"Where it comes from","Few or weak overtones. Nothing high and sharp to "
        .. "announce the instrument, so it merges into whatever it is doubling.",
        "IDIO ch.12"},
      {"The list","Flute; string harmonics; the clarinet's weak middle-register "
        .. "\"filling in\" notes (written G, G-sharp, A and A-sharp above the treble "
        .. "staff's second line); alternative woodwind fingerings; overblowing on a "
        .. "different fundamental; the celesta. Sul tasto weakens or removes overtones "
        .. "as well.","IDIO ch.12"},
      {"What to use them for","Exactly this quality makes them the right choice for "
        .. "mixture - see Doubling. They can supply an artificial overtone without "
        .. "being heard as an added part.","IDIO ch.12"},
    }},
    {"Register turns the rule around", {
      {"Flute","Very soft and of limited penetration at the bottom, because it has so "
        .. "few overtones there; easily penetrating at the top.","IDIO Dynamics and Balance"},
      {"Piccolo","A high-pitched piccolo solo \"will often be easily audible even in a "
        .. "full orchestral tutti\".","IDIO Dynamics and Balance"},
      {"Oboe, the other way round","\"A low oboe is far more penetrating than the same "
        .. "instrument in its highest register.\" The intuition that high means "
        .. "piercing is simply wrong here.","IDIO Dynamics and Balance"},
      {"Adjacent notes can differ","On some instruments \"even adjacent notes may "
        .. "involve considerable differences\" in volume and timbre.","IDIO Dynamics and Balance"},
    }},
    {"Protecting a weak instrument", {
      {"The real risk is masking, not volume","The flute's few overtones mean that "
        .. "overtones from lower instruments can drown it in its middle register, and "
        .. "the bottom register is at greater risk still.","IDIO ch.12"},
      {"The fix is a clear register","\"As long as one makes sure that they are not "
        .. "drowned out by other instruments in the same register or by overtones from "
        .. "lower instruments, even very low flutes will most often be audible.\" Leave "
        .. "the register empty rather than marking the part louder.","IDIO ch.12"},
    }},
    {"Bolero as the textbook", {
      {"What Ravel is doing","The order of solos in the first half is a step-by-step "
        .. "increase in intensity by spectrum: a flute at the bottom of its range with "
        .. "few overtones, a clarinet in the neutral middle, a high bassoon, a high "
        .. "E-flat clarinet. The oboe - intense, overtone-rich - is deliberately held "
        .. "back, and the oboe d'amore used instead where that colour is wanted.",
        "IDIO Parallel Doubling"},
      {"When the oboe finally arrives","Bar 167, almost exactly halfway, and not as a "
        .. "soloist: it appears inside a timbral mixture, in parallel fifths with oboe "
        .. "d'amore, English horn and clarinets.","IDIO Parallel Doubling"},
    }},
  },
  related={"blend","balance","doubling","flute","oboe","clarinet","range"},
}

e{ id="listening", name="Where to Hear These Combinations", family="Reference", kind="topic",
  aliases={"listening","hear it","examples","score examples","repertoire",
           "where to hear","recordings","heard in","find it in a score",
           "which piece","real examples","listen"},
  summary="The doublings in this encyclopaedia described as standard are standard because "
       .. "they are everywhere in the repertoire. These are places to hear them, taken "
       .. "from Andrew Hugill's index of the Philharmonia Orchestra's recorded archive, "
       .. "which gives work, movement and bar or rehearsal figure. Follow with the score "
       .. "open if you can; a recording tells you what it sounds like, the score tells "
       .. "you why.",
  facts={
    {"Locators","MI, MII = movement; b or bb = bar; Fig. or a letter = rehearsal mark"},
    {"Why these pieces","Hugill indexes what the Philharmonia had recorded, so the list "
        .. "runs from Beethoven to Lindberg rather than being a canon"},
  },
  sec={
    {"Woodwind in unison and octaves", {
      {"Cor anglais + bassoon in unison","Saint-Saens, Symphony 3, MI 11 before I - "
        .. "answered by three flutes.","HUG Woodwind Section: Standard Combinations"},
      {"Flutes + oboe in unison","Debussy, Nocturnes 2 'Fetes', Fig. 1.",
        "HUG Woodwind Section: Standard Combinations"},
      {"Clarinet + bassoon in octaves","Tchaikovsky, Symphony 5, MI.",
        "HUG Woodwind Section: Standard Combinations"},
      {"Oboes + clarinets in octaves","Ravel, Bolero, Fig. 9 - the pairing modern "
        .. "teaching often warns against, in the most studied orchestration there is.",
        "HUG Woodwind Section: Standard Combinations"},
      {"Cor anglais + oboe + bassoon in octaves","Debussy, La Mer, III Fig. 46.",
        "HUG Woodwind Section: Standard Combinations"},
      {"Flute + clarinet + bassoon in octaves","Saint-Saens, Symphony 3, MII 3 before R.",
        "HUG Woodwind Section: Standard Combinations"},
      {"Clarinets + high bassoon in octaves","Stravinsky, Petrushka, Fig. 223-225.",
        "HUG Woodwind Section: Standard Combinations"},
      {"Two high clarinets in unison","Stravinsky, Petrushka, Fig. 188-190 - the "
        .. "stridently penetrating effect.","HUG Woodwind Section: Standard Combinations"},
    }},
    {"Wind with brass", {
      {"Horn + bassoons","Stravinsky, Petrushka, Fig. 132-134 - the bridge doubling.",
        "HUG Section Combinations in twos"},
      {"Horn with woodwind, filling a countermelody","Mahler, Symphony 4, MI b63-65. "
        .. "\"Horns frequently combine with woodwind in this way.\"",
        "HUG Section Combinations in twos"},
      {"Solo horn with flutes and oboes in close harmony","Holst, The Planets: Venus, "
        .. "opening.","HUG Section Combinations in twos"},
      {"Trumpet + flute in octaves","Ravel, Bolero, Fig. 5 - the artificial oboe "
        .. "described under Doubling.","HUG Section Combinations in twos"},
      {"Trumpet + cor anglais in unison","Debussy, La Mer, I three bars before Fig. 1.",
        "HUG Section Combinations in twos"},
      {"Horn + celesta + two piccolos in octaves","Ravel, Bolero, Fig. 8 - the organ "
        .. "mixture, and the clearest case of an invented instrument in the repertoire.",
        "HUG Section Combinations in twos"},
    }},
    {"Wind with strings", {
      {"Violas + clarinets","Mahler, Symphony 5, M3 b.39-47 - the standard blend pair.",
        "HUG Section Combinations in twos"},
      {"Pizzicato strings + bassoon","Mahler, Symphony 5, M3 b.308-328.",
        "HUG Section Combinations in twos"},
      {"’Cellos + basses + bassoons in octaves","Holst, The Planets: Mars, 4 after VI.",
        "HUG Section Combinations in twos"},
      {"Violas + horn + bassoon in unison","Elgar, Symphony 1, Fig. 137.",
        "HUG Section Combinations in threes"},
      {"Violas + flutes + clarinets + bassoons in octaves","Elgar, Symphony 1, opening.",
        "HUG Section Combinations in twos"},
      {"Oboes + clarinet + violins in unison, ’cellos an octave below","Mahler, "
        .. "Symphony 5, MI b96-104.","HUG Section Combinations in twos"},
      {"Bass clarinet + bassoon + muted strings","Elgar, Symphony 1, IV.",
        "HUG Section Combinations in twos"},
      {"Violins I with upper woodwind in octaves","Ravel, Bolero, Fig. 12.",
        "HUG Section Combinations in twos"},
    }},
    {"Horns with strings", {
      {"Violas + ’cellos + 8 horns in unison","Holst, The Planets: Jupiter, opening - "
        .. "the big-tune version of the horn/'cello blend.","HUG Section Combinations in twos"},
      {"Horn + 1st violin in unison","Stravinsky, Petrushka, Fig. 176-178.",
        "HUG Section Combinations in twos"},
      {"Violins I and II in unison over four horns","Holst, The Planets: Venus, 5 "
        .. "before II - the horn quartet as background harmony.",
        "HUG Section Combinations in twos"},
      {"Two muted horns with second violins","Debussy, Prelude a l'apres-midi d'un "
        .. "faune, bb. 106-107.","HUG Section Combinations in twos"},
    }},
    {"Brass on its own", {
      {"Trombone trio, joined by trumpet trio","Holst, The Planets: Saturn, 3 after I, "
        .. "over low pizzicato strings - three-part trombones, the standard use.",
        "HUG Brass Section: solos and groups"},
      {"Muted trumpets in octaves","Stravinsky, The Rite of Spring, Fig. 132.",
        "HUG Brass Section: solos and groups"},
      {"Open horns alternating with stopped","Mahler, Symphony 5, M3 b.296-307.",
        "HUG Brass Section: solos and groups"},
      {"Classic natural-horn writing","Beethoven, Symphony 7, MIV bb. 231-248 - the "
        .. "harmonic series and the high register.","HUG Brass Section: solos and groups"},
    }},
    {"Strings on their own", {
      {"Violas + ’cellos in unison","Beethoven, Symphony 7, MII bb. 27-34.",
        "HUG String Section"},
      {"Violins + violas in octaves","Tchaikovsky, Symphony 5, MII.","HUG String Section"},
      {"Strings in octaves","Sibelius, Symphony 5, Molto moderato 2 after M.",
        "HUG String Section"},
      {"All strings in close harmony","Saint-Saens, Symphony 3, MI letter M.",
        "HUG String Section"},
      {"’Cellos high, joined by violas","Debussy, La Mer, II Fig. 26.","HUG String Section"},
    }},
    {"Whole-orchestra scoring", {
      {"Typical romantic tutti","Mahler, Symphony 4, MI b264-266 - violins carrying the "
        .. "melody with a prominent horn countermelody.","HUG Section Combinations in threes"},
      {"Horns softened by doubled strings","Sibelius, Symphony 5, Allegro molto 14 after "
        .. "D - melody on flute, oboes, clarinets and 'cellos in octaves, the famous "
        .. "horn theme lent a shimmer by the strings.","HUG Section Combinations in threes"},
      {"Piccolo colouring the top of a chord","Holst, The Planets: Mars, 6 after VII, in "
        .. "a build to tutti.","HUG Tuttis"},
      {"Trombones doubled by bassoons and strings","Elgar, Symphony 1, Fig. 45, with "
        .. "horns doubled by cor anglais.","HUG Section Combinations in threes"},
      {"A tutti that is not a climax","Lindberg, Cantigas, bb. 475-490 - instrumental "
        .. "groups in layers, \"clearly distinct rather than climactic\".","HUG Tuttis"},
    }},
    {"How to use this list", {
      {"Check a recommendation before you trust it","A combination this encyclopaedia "
        .. "calls standard should be findable in the repertoire. If you cannot hear why "
        .. "it is recommended, the fault may be in the recommendation.","HUG Tuttis"},
      {"A tutti is not everyone playing","\"A full orchestral tutti does not necessarily "
        .. "mean every single instrument is playing. However, the great majority of "
        .. "instruments will join in. To make a controlled climax using a tutti is a "
        .. "great skill in orchestration.\"","HUG Tuttis"},
    }},
  },
  related={"doubling","blend","balance","spectrum","composers","three_groups"},
}

e{ id="idiomatic", name="Writing Playable Music", family="Craft", kind="topic",
  aliases={"idiomatic","playable","playability","difficulty","hard to play",
           "unidiomatic","writing for players","practical","will they play it",
           "too difficult","technique","performability"},
  summary="Almost anything is possible with enough rehearsal, and that is not the same "
       .. "as practical. The question is not whether a passage can be played but whether "
       .. "it will be played well by the players you actually have, in the time they "
       .. "actually get - and small changes often buy a great deal of it back.",
  facts={
    {"The trade","Difficult writing may be exactly what the music needs. The price is "
        .. "that it may not be played correctly, or at all."},
    {"Where it bites hardest","Large ensembles rehearse less per player than chamber "
        .. "groups, so the same passage is riskier in an orchestra."},
  },
  sec={
    {"Possible is not the same as practical", {
      {"The precedent cuts both ways","Tchaikovsky's First Piano Concerto was called "
        .. "unplayable and is now repertoire, and Ferneyhough's music gets performed and "
        .. "recorded. So difficulty is not a veto. But \"just because something is "
        .. "possible does not mean that it is practical or idiomatic\".",
        "ACTOR All Instruments: Effective Instrumental Writing"},
      {"Difficulty accumulates","A hard passage that works in isolation may be near "
        .. "impossible strung together with a series of other acrobatic demands. Budget "
        .. "difficulty across a movement, not per bar.",
        "ACTOR All Instruments: Effective Instrumental Writing"},
      {"“Professional” does not mean flawless","It means the players are paid. Top "
        .. "players still face the same challenge, with less rehearsal time than an "
        .. "amateur group might give you. Write for the players you have, knowing their "
        .. "strengths and how long they will have.",
        "ACTOR All Instruments: Effective Instrumental Writing"},
    }},
    {"Write what the practice room rewards", {
      {"Scales and arpeggios","String players practise them obsessively, so a scalar or "
        .. "arpeggiated passage will come off convincingly even at a quick tempo - where "
        .. "frequent large leaps, string crossings or irregular melodic patterns will "
        .. "not.","ACTOR All Instruments: Effective Instrumental Writing"},
      {"Change a note or two","Slightly varying an unidiomatic passage can make it "
        .. "\"exponentially easier to execute, while preserving the desired effect and "
        .. "essence\". If two versions sound equivalent and one is far easier, there is no "
        .. "argument for the harder one.","ACTOR All Instruments: Effective Instrumental Writing"},
      {"Distribute what one player cannot do","Berlioz splits a theme of wide fast leaps "
        .. "between the violins so no desk has to make them; Ravel modifies Bolero's "
        .. "triple-tonguing for the woodwind while the horns play it straight. See "
        .. "Doubling.","IDIO Partial Doubling"},
      {"Let the less agile instrument simplify","Where 'cellos and basses share a line, "
        .. "the basses take a plainer version. Berlioz gives the same reason for "
        .. "separating them at all: figuration quicker than the basses could manage "
        .. "cleanly.","IDIO Partial Doubling; BERL The cello"},
    }},
    {"Look after the player, not just the part", {
      {"Do not start cold on an exposure","The piccolo's first entrance in Tchaikovsky's "
        .. "Fourth is a fortissimo octave doubling in the third movement - musically "
        .. "effective, and \"physically and psychologically unfriendly to the piccolo "
        .. "player\". An inconsequential warm-up passage a few bars earlier would make it "
        .. "far less alarming.","ACTOR Woodwinds: Scoring Excerpts"},
      {"Leave time to move","Percussionists need time to change instrument or pick up "
        .. "different beaters; not allowing for it is a common mistake. Think about the "
        .. "choreography of the section.","HUG Percussion Section"},
      {"Cover the principal where you can","A fifth horn may be engaged to take the less "
        .. "important passages in the first part so the principal can save themselves for "
        .. "the solos. You do not write this, but it explains why a demanding first horn "
        .. "part is less unreasonable than it looks.","HUG Brass Section"},
    }},
    {"Say what you want in the score", {
      {"Descriptors carry what notation cannot","Adjectives - boldly, whispering, "
        .. "crunchy, like a bad joke - give players insight no combination of notes, "
        .. "rhythms, dynamics and articulations will. The more character the descriptor "
        .. "suggests, the more use it is.","ACTOR All Instruments: Effective Instrumental Writing"},
      {"Details define character","Notes and rhythms supply the material; the expressive "
        .. "markings define what it is. Treating dynamics, articulations, inflections and "
        .. "descriptors as a last-minute layer is a missed opportunity, not a tidy "
        .. "workflow.","ACTOR All Instruments: Effective Instrumental Writing"},
      {"Do not mark every note the same","\"Some orchestrators fall into the trap of an "
        .. "articulation area, in which every note has the same marking.\" Consistency may "
        .. "be right; uniformity by default is not.",
        "ACTOR All Instruments: Effective Instrumental Writing"},
      {"Write the layout down too","Where a dialogue depends on the groups being far "
        .. "apart, Berlioz says the composer should indicate the seating he wants in the "
        .. "score. See The Modern Orchestra.","BERL The Orchestra"},
    }},
    {"Register changes the instrument, not just the pitch", {
      {"The general trend","Instruments tend to sound dark at the bottom of their range "
        .. "and brighter as the pitch rises - but the character changes, not only the "
        .. "brightness.","ACTOR All Instruments: Effective Instrumental Writing"},
      {"The same note, two instruments","Middle C sits at the bottom of the flute's range "
        .. "and sounds rich and colourful; the same sounding pitch is extremely high, thin "
        .. "and pinched on contrabassoon. Choose the instrument for where the note falls "
        .. "in its range, not for the note.","ACTOR All Instruments: Effective Instrumental Writing"},
      {"And check the exceptions","A low oboe penetrates more than a high one. See "
        .. "Overtones, Formants and Penetration.","IDIO Dynamics and Balance"},
    }},
  },
  related={"quality","dynamics","doubling","spectrum","percussion","horn","orchestra"},
}

e{ id="balance", name="Balance and Relative Strength", family="Combining", kind="topic",
  aliases={"balance","relative strength","loudness","power","how loud",
           "instrument strength","weight","balancing"},
  summary="The numbers you need to make a doubling actually balance. All of these are "
       .. "Rimsky-Korsakov's forte ratios unless noted; in piano, all wind - wood and "
       .. "brass alike - are of fairly equal weight.",
  sec={
    {"Within the brass", {
      {"1 Trumpet = 1 Trombone = 1 Tuba = 2 Horns","In loud passages the horns are "
        .. "only half as strong.","RK p.33"},
      {"Cornets","Slightly less force than trumpets and trombones.","RK p.23"},
      {"Marking","Horns should be marked one degree stronger than the rest of the "
        .. "brass: trumpets and trombones pp, horns p.","RK p.23"},
    }},
    {"Brass against woodwind", {
      {"1 Horn = 2 Clarinets = 2 Oboes = 2 Flutes = 2 Bassoons","\"Wood-wind "
        .. "instruments, in forte passages, are twice as weak as the horns.\"","RK p.33"},
      {"Equal families","Flutes, oboes, clarinets and bassoons may be taken as of "
        .. "equal power. The special instruments (piccolo, alto flute, English horn, "
        .. "E-flat clarinet, bass clarinet, contrabassoon) may not be.","RK p.19"},
    }},
    {"Wind against strings", {
      {"Piano","Violins I = 1 Flute; one whole string department equals one wind "
        .. "instrument.","RK p.33"},
      {"Forte","Violins I = 2 Flutes = 1 Oboe + 1 Clarinet.","RK p.33"},
      {"Caveat","This assumes a medium-sized body of strings - everything depends on "
        .. "the number of players.","RK p.33"},
    }},
    {"Instruments of little sustaining power", {
      {"Easily overpowered","The combined force of the sustaining groups easily "
        .. "overpowers strings pizzicato or col legno, a softly played piano, or the "
        .. "celesta.","RK p.34"},
      {"Easily overpowering","Glockenspiel, bells and xylophone \"will easily prevail "
        .. "over other groups in combination\" - as will the timpani.","RK p.34"},
      {"Harps","At least three, and preferably four, harps in unison are needed to be "
        .. "heard against a full orchestra playing forte. The faster a glissando, the "
        .. "louder it sounds.","RK p.29"},
      {"Percussion that wins outright","Bass drum, cymbals, gong, and a fortissimo "
        .. "side-drum tremolo will each overpower any orchestral tutti.","RK p.117"},
    }},
    {"Balance in chords", {
      {"The acoustic rescue","\"In every chord the parts in octaves strengthen one "
        .. "another, the harmonic sounds in the lowest register coinciding with and "
        .. "supporting those in the highest\" - which compensates for inequalities "
        .. "you could not avoid.","RK p.94"},
      {"Which parts are weakest","In four-part wind harmony \"the two extreme parts "
        .. "are the thinnest and weakest in tone, the intermediate parts the fullest "
        .. "and strongest\".","RK p.77"},
      {"Last resort","Where balance cannot be secured by distribution, secure it by "
        .. "dynamic grading - marking the woodwind one degree louder than the brass.","RK p.94"},
    }},

    {"Counting a chord — the balance ratio", {
      {"The whole system, in four numbers","One string group (e.g. all 1st violins) = "
        .. "2  ~  one woodwind instrument = 1  ~  one horn, or one saxophone = 2  ~  "
        .. "one other brass instrument = 4. Add up each note of a chord and compare. "
        .. "This is Rimsky-Korsakov's experience reduced to something you can count "
        .. "with, and it is the only tool of its kind in the literature.",
        "IDIO Dynamics and Balance"},
      {"The number that surprises people","It takes four clarinets to match one "
        .. "trumpet. Counter-intuitive, and \"largely confirmed by practical "
        .. "experience, although they admittedly are beyond scientific proof\".",
        "IDIO Dynamics and Balance"},
      {"Use it in forte","Forte is the reliable basis, because instrumental power "
        .. "varies far more in piano - muted brass or a string group can play "
        .. "extremely softly, while very soft is awkward for a low oboe, a very high "
        .. "clarinet or an unmuted high trumpet.","IDIO Dynamics and Balance"},
      {"Counting divisi and double stops","Each divisi note counts 2, the same as a "
        .. "whole group. For double stops, count each sustained note.","IDIO Chords"},
      {"What to leave out","Timpani: their dynamic range is effectively unlimited so "
        .. "no ratio fits, and in classical and romantic scoring they mark the root "
        .. "anyway, which only reinforces it. Harp and piano chords are also left out "
        .. "unless they exist to create a deliberately unusual balance.","IDIO Chords"},
      {"Where it does not reach","Short chords, where balance matters less; and "
        .. "ranking one segment against another, because the ear does not weigh "
        .. "segments by power alone. In a Heldenleben tutti the busy woodwind flurry "
        .. "scores only 6-7 while the trombone melody scores 16 - and elsewhere a "
        .. "1st-violin countermelody scoring 2 still emerges over a main subject "
        .. "scoring 12, because the subject is a near-immobile ostinato.","IDIO Chords"},
    }},
    {"What a balanced final chord looks like", {
      {"The root takes most of it","Measured as fifth/third/root, the last chord of "
        .. "Brahms's 2nd symphony is 9/8/35 - that is 17/15/67 per cent, so two "
        .. "thirds of the sound power is on the root. His 1st gives 22/22/57 and his "
        .. "4th gives 8/23/70. Root predominance is the norm across the classical and "
        .. "romantic repertoire.","IDIO Chords"},
      {"Reinforce rather than thin out","Ending Ein Heldenleben, Strauss diminuendos "
        .. "to piano but does not remove instruments: he adds four horns and moves a "
        .. "trumpet and three trombones off the fifth and third onto the root. The "
        .. "chord gets quieter and more focused at once.","IDIO Chords"},
      {"Weighting the third on purpose","Mahler's 6th - \"a battle between minor and "
        .. "major\" - ends 13/24/19, weighting the third rather than the root, so the "
        .. "minor third is unmistakably the victor. Break the rule when the piece is "
        .. "about the thing you are breaking it for.","IDIO Chords"},
    }},
    {"Loudness is not the same as thickness", {
      {"Koechlin’s distinction","\"By 'volume' he means the thickness of a given sound. "
        .. "For example, at any dynamic level, a horn will always sound thicker, or "
        .. "'fatter', than a violin. Acoustically, thick sounds tend to have stronger "
        .. "fundamentals than thin sounds.\"","BEL p.34"},
      {"Two ways to get a fat sound","As a chosen timbre - horn, tuba - or as the "
        .. "result of unison doubling, which \"adds more volume than loudness\".","BEL p.34-35"},
      {"Sixteen violins are not sixteen times one","Doubling the sound pressure does "
        .. "not double what the ear hears. A large string group reads as a different "
        .. "kind of sound rather than a louder one - \"full, rich, more mellow and far "
        .. "more dense\". This is why a single soloist can be heard over thirty-two of "
        .. "them at all.","IDIO Dynamics and Balance"},
      {"Balance is not only power","\"A melodic line (or the highest part) always "
        .. "attracts attention - activity and movement capture more attention than, "
        .. "for example, sustained notes.\" Contrast of sonority or register shifts "
        .. "perceived dynamics as much as the dynamic marks do.","IDIO Dynamics and Balance"},
      {"Successive balance","\"This is a problem mainly when passing from very thick "
        .. "sounds to very thin ones: The thin sound can seem disagreeable by comparison "
        .. "with the previous richness... after a loud, full brass passage, an oboe will "
        .. "sound thinner than usual, by contrast.\"","BEL p.35-36"},
    }},
    {"What the ear picks out, all else being equal", {
      {"The top line","\"The top line normally attracts the most attention.\"","BEL p.36"},
      {"Whatever is moving","\"The ear normally follows activity: If, say, in the string "
        .. "choir, all the parts except the viola are static, the movement in the viola "
        .. "will stand out.\"","BEL p.36"},
      {"Activity can also obscure","Koechlin again: strings are ideal for accompanying a "
        .. "voice, \"but if they are playing vigorous counterpoint they will cover the "
        .. "voice much more easily than if they have long held notes. In other words, "
        .. "balance is not just a function of the choice of instruments, but also of what "
        .. "they are doing.\"","BEL p.36"},
    }},
    {"Use sparingly", {
      {"Two solo violins in perfect unison","Doubling all the 1st and 2nd violins in "
        .. "unison gives greater density and is standard; but two solo violins in "
        .. "perfect unison \"often sound poor, if not to say 'impoverished'\". The "
        .. "effect that works with a section does not scale down to a pair.",
        "IDIO Dynamics and Balance"},
      {"Solo strings against solo brass","In a sinfonietta-sized ensemble this needs "
        .. "meticulous care. String instruments have been essentially unchanged since "
        .. "the end of the 1700s, while brass instruments have changed substantially "
        .. "and are considerably more powerful today - so a classical-era balance does "
        .. "not transfer to a modern chamber orchestra.","IDIO Dynamics and Balance"},
      {"Measuring it in decibels","\"Practically useless\" for music: manufacture, "
        .. "playing style, hall acoustics, seating and the players' own instinctive "
        .. "adjustment all change constantly. Use the ratios and your ears, not a "
        .. "meter.","IDIO Dynamics and Balance"},
    }},
  },
  related={"blend","three_groups","brass","woodwind","strings","range"},
}

e{ id="range", name="Orchestral Range and Score Order", family="Reference", kind="topic",
  aliases={"range","score order","limits","orchestral range","compass","layout",
           "score layout","order of the score","register"},
  summary="How the orchestra is laid out on the page, and how far it reaches at the "
       .. "top and bottom.",
  sec={
    {"Score order (top to bottom)", {
      {"Woodwind","Flutes, Oboes, Clarinets, Bassoons - the natural order of "
        .. "register and the order of the full score.","RK p.46"},
      {"Brass","Trumpets, Horns, Trombones, Tuba.","RK p.22"},
      {"Then","Percussion (timpani first), harp, then strings: Violins I, Violins II, "
        .. "Violas, Violoncellos, Double basses.","SIN p.276"},
      {"Reading it","Singleton's walk-through of a page of Beethoven's Fifth notes "
        .. "the clef and key problem: flutes and oboes in treble, clarinets in treble "
        .. "but a different key, bassoons in bass, horns in another key again, timpani, "
        .. "then the strings - violas in alto or tenor clef, 'cellos in bass, tenor "
        .. "or treble.","SIN p.276"},
    }},
    {"Limits of the range", {
      {"The whole scale","Modern limits run up to the high C of the 7th octave and "
        .. "down to the low 16-foot C, which is why the piccolo is indispensable and "
        .. "the contrabassoon valuable.","RK p.18"},
      {"All in the top","Seldom done; use flutes and piccolo with the upper notes of "
        .. "the violins, soli or divisi. Gives brilliant colour.","RK p.106"},
      {"All in the bottom","Still rarer, because close harmonic intervals down there "
        .. "create a bad effect. Use contrabassoon, low bassoons, bass clarinet, "
        .. "horns, trombones, tuba. Dark and gloomy - and the reverse of these two "
        .. "cases is \"fundamentally impossible\".","RK p.106"},
      {"Empty middle","Widely separated extremes without the intermediate octaves "
        .. "filled in is contrary to proper distribution - but the unusual resonance "
        .. "serves for strange and grotesque effects.","RK p.106-107"},
    }},
    {"Distributing a chord", {
      {"Follow the harmonic series","Wide intervals (octaves, sixths) in the bass, "
        .. "lesser ones (fifths, fourths) in the middle, close ones (thirds, seconds) "
        .. "in the upper register.","RK p.67 & p.79"},
      {"Bass spacing","The bass should rarely lie more than an octave from the part "
        .. "directly above it, and should never mix with the other parts.","RK p.64 & p.67"},
      {"Duplication","Harmony that looks like 5, 6, 7 or 8 parts is usually four-part "
        .. "harmony with the upper parts doubled in the octave above - the bass only "
        .. "ever doubled in the octave below.","RK p.64"},
      {"In widely-spaced writing","Only the soprano and alto may be doubled in "
        .. "octaves; doubling the tenor produces close writing, and doubling the bass "
        .. "creates heaviness.","RK p.64"},
      {"Why that spacing works","The strongest overtones of a very low note land in "
        .. "the middle of the hearing range, where the ear resolves pitch most "
        .. "precisely. Wide intervals low down keep those overtones from colliding "
        .. "dissonantly with the notes actually written in that register - which is "
        .. "why the low register is dominated by the octave, then the fifth, and why "
        .. "the third with its dissonant overtones appears there only in deliberately "
        .. "unusual chords.","IDIO Chords"},
      {"It is not only a tonal rule","\"All chords, tonal or atonal, triadic or not, "
        .. "tend to be structured in such a way that the largest intervals are placed "
        .. "in the bass register.\" The weight of a balanced orchestral chord usually "
        .. "sits in that central area, whatever the harmonic language.","IDIO Chords"},
    }},
    {"How harsh a dissonance sounds", {
      {"Spread it and it softens","\"The further apart two notes are placed from each "
        .. "other in terms of register, the less intense or obtrusive the dissonance "
        .. "between them will be perceived.\" Register does as much work as the "
        .. "interval itself.","IDIO Chords"},
      {"The instrument decides the bite","Powerful high overtones make a piercing "
        .. "dissonance. A minor second \"seems far less harsh when played by two low "
        .. "flutes than by two low oboes\" - the same interval, a different result.",
        "IDIO Chords"},
      {"Where the ear hears intonation most clearly","Pitch is resolved most precisely "
        .. "in the centre of the hearing range and less so at the extremes. The "
        .. "violin's high register sits where the ear is more forgiving; the 'cello's "
        .. "high register sits right in the middle, so slight intonation trouble there "
        .. "is immediately noticeable.","IDIO Chords"},
      {"Mind the diminuendo too","A low oboe has very little room for diminuendo, "
        .. "while a string instrument or a low clarinet has almost no limit. If a "
        .. "chord is marked to fade, check that every instrument in it can.","IDIO Chords"},
    }},
    {"Instrumentation shorthand", {
      {"The formula","Flute . Oboe . Clarinet . Bassoon - Horn . Trumpet . Trombone . "
        .. "Tuba. A dot separates one player from another, a slash indicates doubling; "
        .. "timpani and percussion are written tmp+n.","WP"},
      {"Worked example","3[1.2.3/pic] 2[1.Eh] 3[1.2.3/Ebcl/bcl] 3[1.2/cbn.cbn] tmp+2 "
        .. "= 3 flutes (3rd doubling piccolo), 2 oboes (2nd on English horn "
        .. "throughout), 3 clarinets (3rd also on E-flat and bass clarinet), 3 "
        .. "bassoons (2nd doubling contra, 3rd on contra only), timpani + 2 "
        .. "percussion.","WP"},
    }},

    {"Belkin on register planning", {
      {"Why register matters most","\"Register planning is essential to good "
        .. "orchestration, since a change of register is obvious even to a "
        .. "non-musician.\"","BEL p.28"},
      {"Follow the overtone series for a blended mass","\"Wider in the lower range and "
        .. "more compact getting higher, with no large gaps in the middle - such gaps "
        .. "tend to divide the sound mass into separate planes.\" Where you *want* "
        .. "differentiation, as in some counterpoint, the gaps become useful.","BEL p.28"},
      {"Leave part of the range empty sometimes","\"It is advisable not to fill the "
        .. "entire audible range all the time: Occasional passages in the higher or the "
        .. "lower range alone provide valuable contrast and relief for the ear.\"","BEL p.28"},
      {"Fewer instruments are needed at the extremes","\"Even in a large tutti, one "
        .. "piccolo in its highest register will penetrate without difficulty.\" "
        .. "Extremes fatigue the ear, so do not stay there.","BEL p.29"},
      {"Hollow textures work softly","\"Textures with large gaps can occasionally be "
        .. "quite effective, although the ear tires of this effect rather quickly. This "
        .. "sonority also works better in softer dynamics: Loud passages with holes in "
        .. "the middle tend to sound feeble.\"","BEL p.30"},
      {"Registral progressions as direction","Widening out from the middle in both "
        .. "directions, or piling up high or low material, are \"powerful sources of "
        .. "musical direction\", especially into and out of climaxes.","BEL p.31"},
      {"Strain within the range reads as intensity","Trumpets and horns not high in "
        .. "absolute terms but high *for them* create \"an effect of intensity and "
        .. "strain\".","BEL p.30"},
    }},
  },
  related={"woodwind","brass","strings","percussion","orchestra"},
}

-- Additional sources: present-day practice. These corroborate and update the
-- historical treatises. See README.md for how they were consulted.
D.SOURCES.BEL = {
  tag="BEL", short="Belkin, Artistic Orchestration",
  full="Alan Belkin, 'Artistic Orchestration' (c) Alan Belkin 2001, 2008 - the "
    .. "third volume of his free online series on musical technique, published by "
    .. "the author at alanbelkinmusic.com. 65 pages; cited by page from the "
    .. "author's PDF. Belkin states: \"The material may be used free of charge "
    .. "provided that the author's name is included.\" His own debts, which he "
    .. "names, are chiefly to Koechlin's 'Traite de l'Orchestration', and to "
    .. "Rimsky-Korsakov, Piston and Adler.",
}
D.SOURCES.BERL = {
  tag="BERL", short="Berlioz, Treatise on Instrumentation and Orchestration",
  full="Hector Berlioz, 'Grand traite d'instrumentation et d'orchestration "
    .. "modernes' (Paris, 1843; second edition 1855). The underlying text is public "
    .. "domain. Consulted in the English translation by Michel Austin on the Hector "
    .. "Berlioz Website, which is a *selection* - roughly the third of the book "
    .. "given to technical range and mechanism is omitted, leaving the material on "
    .. "timbre, character and combination, which is the part this encyclopaedia "
    .. "needs. That translation reserves all rights, so BERL items paraphrase "
    .. "Berlioz's substance rather than reproducing the translator's sentences; "
    .. "where Berlioz is quoted word for word in this encyclopaedia it is from the "
    .. "older public-domain translation Singleton uses, and is tagged SIN as well. "
    .. "Cited by the instrument or chapter heading.",
}
D.SOURCES.ACTOR = {
  tag="ACTOR", short="Freund & Cutler, Extreme Orchestration",
  full="Don Freund and David Cutler, 'Extreme Orchestration' (published February "
    .. "2024), on the Timbre and Orchestration Resource of the ACTOR Project "
    .. "(Analysis, Creation and Teaching of Orchestration). Cited by chapter title. "
    .. "Split out of the MOD group when the full text was supplied: it is the "
    .. "present-day teaching text MOD was standing in for. Its particular "
    .. "contribution is on dynamics, idiomatic writing, and why piling on "
    .. "instruments reduces colour rather than adding it.",
}
D.SOURCES.OMT = {
  tag="OMT", short="Open Music Theory, “Core Principles of Orchestration”",
  full="Gotham et al. (eds.), 'Open Music Theory' 2e, chapter 'Core Principles of "
    .. "Orchestration' - open-access music theory textbook.",
}
D.SOURCES.IDIO = {
  tag="IDIO", short="The Idiomatic Orchestra",
  full="'The Idiomatic Orchestra' (theidiomaticorchestra.net), an online "
    .. "orchestration manual. Cited by chapter or page title: the pages have no "
    .. "numbering, but each claim can be found in the named chapter. It began "
    .. "here as a tag-only source gathered from search summaries; when the full "
    .. "text was supplied every existing claim was re-checked against it and all "
    .. "were confirmed, so the citations were upgraded rather than rewritten. Its "
    .. "particular contribution is the balance-ratio method, which it takes from "
    .. "Rimsky-Korsakov and states in a usable form, and a careful separation of "
    .. "sound power from sound density - a distinction it credits to Koechlin's "
    .. "'Traite de l'Orchestration', which it notes has never been translated.",
}
D.SOURCES.HUG = {
  tag="HUG", short="Hugill, The Orchestra: A User’s Manual",
  full="Andrew Hugill, 'The Orchestra: A User's Manual' (c) Andrew Hugill 2015, "
    .. "written with the Philharmonia Orchestra. Cited by page title. Split out "
    .. "of the MOD group when the full site was supplied: it is mostly an index "
    .. "of the Philharmonia's recorded archive, giving composer, work, recording "
    .. "and bar or figure number for a great many scorings, plus prose on each "
    .. "section. Claims previously cited to MOD that this text supports have been "
    .. "re-cited here. All rights reserved by the author; used as short factual "
    .. "statements with attribution.",
}
D.SOURCES.MOD = {
  tag="MOD", short="Present-day practice (several sources)",
  full="Consensus of present-day orchestration references consulted together: "
    .. "the Timbre and Orchestration Resource (ACTOR Project); Orchestration "
    .. "Online; Wikipedia, 'Orchestra', 'String section', 'Brass section'; and "
    .. "film-score and programme notes where no better source exists. Used for "
    .. "present-day section sizes and standard practice. Cited by tag only: "
    .. "these were gathered from search-result summaries rather than full page "
    .. "reads. Hugill was originally part of this group and is now cited "
    .. "separately as HUG, having been read in full.",
}

e{ id="orchestra", name="The Modern Orchestra", family="Reference", kind="section",
  aliases={"orchestra","modern orchestra","symphony orchestra","full orchestra",
           "orchestra size","roster","the orchestra","standard orchestra"},
  summary="What a full symphony orchestra actually contains today, and how it is "
       .. "laid out. Roughly a hundred permanent players, in four groups plus harp "
       .. "and keyboards.",
  facts={
    {"Four groups","Strings, Woodwind, Brass, Percussion - each a choir of soprano, "
       .. "alto, tenor and bass"},
    {"Outside the groups","Harp, piano and celesta stand apart; Singleton notes the "
       .. "harp \"does not belong to any family\" and comes from the minstrels and "
       .. "bards, not the violin tribe"},
  },
  sec={
    {"Berlioz: build the orchestra to the work", {
      {"The principle","Unless the available forces are fixed, assemble the players "
        .. "according to the style and character of the piece and the effects it needs - "
        .. "the reverse of writing for a standard roster and hoping. For the Requiem he "
        .. "put four brass orchestras at the four corners of the main one, with ten "
        .. "players on eight pairs of timpani, and says plainly that no other "
        .. "arrangement could have produced the effect.","BERL The Orchestra"},
      {"Haydn and Mozart want fewer strings","The modest wind of an opera-comique "
        .. "orchestra suits their symphonies, and a larger string body would often be "
        .. "too loud for the delicate effects they give to flutes, oboes and bassoons "
        .. "alone. Beethoven's symphonies, Weber's overtures and anything in a grand and "
        .. "passionate style need the full string body instead.","BERL The Orchestra"},
      {"His own ideal concert orchestra","21 first violins, 20 seconds, 18 violas, 8 "
        .. "first 'cellos, 7 second 'cellos, 11 double basses, 4 harps, and wind "
        .. "including 2 piccolos, cor anglais, bass clarinet, 4 bassoons, 4 valve horns, "
        .. "2 valve trumpets, 2 cornets, 4 trombones, ophicleide or tuba, two pairs of "
        .. "timpani with four players. Note the 'cellos divided into firsts and seconds.",
        "BERL The Orchestra"},
      {"The other system","The string-dominant scheme is not the only one that works. "
        .. "Invert it and the strings become the bridge to a wind-and-brass orchestra - "
        .. "too few to dominate, they soften the brilliance of the brass, or lend warmth "
        .. "and impetus, their tremolo able to make even a drum roll musical by blending "
        .. "with it.","BERL The Orchestra"},
    }},
    {"Where the players sit", {
      {"Tiers, not a flat floor","The best arrangement raises the players one above "
        .. "another so each row projects to the audience with nothing in the way. An "
        .. "opera pit gives up most of that advantage, being low, central and flat - "
        .. "which is why, Berlioz says, delicate effects are lost in the theatre, and "
        .. "why a dramatic score should not be written exactly like a concert work.",
        "BERL The Orchestra"},
      {"Distance is a compositional choice","Groups meant to question and answer each "
        .. "other only read as dialogue if they are far enough apart, and the composer "
        .. "should mark the layout he wants in the score. Percussion playing an ordinary "
        .. "rhythm together can sit together; percussion in rhythmic dialogue is better "
        .. "split to the two ends of the orchestra.","BERL The Orchestra"},
      {"Keep percussion near the conductor","They drag at a distance, and need to be "
        .. "close enough to respond instantly to the beat.","BERL The Orchestra"},
      {"Uniform placement is a habit, not a law","Berlioz calls the constant uniformity "
        .. "in placing masses of instruments one of the greatest obstacles to genuinely "
        .. "new large-scale work, imposed by habit, routine and laziness more than by "
        .. "cost.","BERL The Orchestra"},
      {"There is no open-air music","Reflectors are indispensable, and the nearer they "
        .. "are to the source the better they work. A thousand wind players and two "
        .. "thousand voices in an open plain would not have a twentieth of the effect of "
        .. "eighty players and a hundred voices in a good hall. Street bands appear to "
        .. "contradict this and in fact confirm it: the tall houses, trees and facades "
        .. "are the reflectors, and the music evaporates the moment the band marches "
        .. "out into open ground.","BERL The Orchestra"},
    }},
    {"Present-day string sizes", {
      {"Common professional layout","14 first violins / 12 seconds / 10 violas / 8 "
        .. "'cellos / 6 basses - written \"14/12/10/8/6\".","MOD"},
      {"Typical professional section","16 firsts / 14 seconds / 12 violas / 10 "
        .. "'cellos / 8 basses - the Philharmonia's usual strength, and the same "
        .. "proportions Rimsky-Korsakov gives for a full orchestra. Numbers vary with "
        .. "the piece, the venue and the conductor.","HUG String Section; cf. RK p.6"},
      {"Full-scale (c.100 players)","16-18 firsts / 16 seconds / 12 violas / 12 "
        .. "'cellos / 8 basses. Strauss \"and many others\" generally required 16-18 "
        .. "first violins and 16 seconds for a full-scale symphony orchestra.",
        "IDIO Dynamics and Balance"},
      {"How much variation there really is","Standard classical works are performed "
        .. "today with anywhere from about 20 to more than 60 string players, and "
        .. "composers rarely specify a number in the score.","IDIO Dynamics and Balance"},
      {"Rule of thumb","Subtract about 2 for each next-lower string section to keep "
        .. "the proportions balanced.","MOD"},
      {"Why bigger than 1922","Modern halls are larger and the wind more powerful, so "
        .. "the strings must be increased to keep the ensemble in balance - exactly "
        .. "the trend Rimsky-Korsakov complained about.","MOD; cf. RK p.6 & p.48"},
    }},
    {"Present-day wind and brass", {
      {"Double woodwind","2 flutes, 2 oboes, 2 clarinets, 2 bassoons. No auxiliary "
        .. "instruments.","HUG Woodwind Section"},
      {"Triple woodwind","2 flutes + piccolo, 2 oboes + English horn, 2 clarinets + "
        .. "bass clarinet, 2 bassoons + contrabassoon - so three players per family, "
        .. "the third taking the auxiliary. \"This is the standard lineup for most "
        .. "symphony orchestras.\"","HUG Woodwind Section"},
      {"Quadruple woodwind","3 flutes + piccolo, 3 oboes + English horn, 3 clarinets "
        .. "+ bass clarinet, 3 bassoons + contrabassoon - four players per family. "
        .. "Saxophones may be added to any of the three.","HUG Woodwind Section"},
      {"Brass","4 horns, 3 trumpets, 3 trombones (the third a bass trombone), 1 tuba "
        .. "- \"probably the most common orchestral combination\", with numerous "
        .. "variations and occasional massive expansions.","HUG Brass Section; cf. RK p.21"},
      {"Percussion","Timpani plus 2-4 percussionists, and one or two harps.","MOD"},
    }},
    {"Seating (Singleton’s 1917 description, still recognisable)", {
      {"Left of the conductor","First violins, with the 'cellos beside them and the "
        .. "double basses behind.","SIN p.9"},
      {"Right of the conductor","Second violins, with the violas beside them.","SIN p.9"},
      {"Centre, facing the conductor","Clarinets by the violas; then oboes and English "
        .. "horn; then flutes. Bassoons behind the flutes; horns behind the oboes and "
        .. "clarinets.","SIN p.9"},
      {"Back row","Trombones, trumpets, drums, triangle, cymbals and the rest of the "
        .. "percussion. Harp on the right behind the first violins.","SIN p.9"},
    }},
    {"Historic rosters, for reference", {
      {"Haydn","String quartet, 2 flutes, 2 oboes, 2 clarinets, 2 bassoons, 2 horns, "
        .. "2 trumpets and kettledrums. He was the first to give the timpani an "
        .. "artistic part.","SIN p.200"},
      {"Mozart / Haydn inheritance","Strings, 2 flutes, 2 oboes, 2 bassoons, 2 horns, "
        .. "2 trumpets, kettledrums and occasionally 2 clarinets. Neither used "
        .. "trombones in a symphony.","SIN p.219"},
      {"Beethoven’s Fifth","First appearance in his symphonies of piccolo, trombones "
        .. "and contrabassoon.","SIN p.229"},
      {"Beethoven’s Ninth","2 flutes, 2 oboes, 2 clarinets, 2 bassoons, 4 horns, 2 "
        .. "trumpets, 2 drums and strings; with 3 trombones, contrabassoon, piccolo, "
        .. "triangle, cymbals and bass drum in some movements.","SIN p.240"},
      {"Debussy, Prelude a l’apres-midi d’un faune","3 flutes, oboes, clarinets, 4 "
        .. "horns, 2 harps, antique cymbals and strings - no trumpets, trombones, "
        .. "timpani or tuba at all.","SIN p.270"},
      {"Cesti, Il Pomo d’oro (1666)","Thirty players: 6 violins, 12 alto violas, "
        .. "tenor, bass, contrabass, 2 flutes, trumpets, 2 cornets, 3 trombones, a "
        .. "bassoon and a little organ - strings accompanied the voices, flutes did "
        .. "the pastoral scenes, trumpets the choral scenes, cornets and trombones "
        .. "the infernal ones.","SIN p.155"},
    }},
  },
  related={"strings","woodwind","brass","percussion","range","doubling"},
}

e{ id="doubling", name="Doubling: General Principles", family="Combining", kind="topic",
  aliases={"doubling","doublings","how to double","unison doubling","octave doubling",
           "when to double","coupling","mixture","parallel doubling","partial doubling",
           "artificial overtone","perfect unison"},
  summary="The general rules that govern every specific pairing in this book - when "
       .. "to double at all, what doubling costs you, and how to keep planes of tone "
       .. "distinct.",
  sec={
    {"When to double", {
      {"To make a risky note secure","A doubling can exist for the player's sake rather "
        .. "than the listener's. In Strauss, first and second horns at the top of their "
        .. "range are given security by a unison doubling from the third trumpet - the "
        .. "note is guaranteed whether or not the horns land it cleanly. Worth "
        .. "remembering whenever you write near the top of a brass part.",
        "ACTOR Brass: Introduction"},
      {"The elementary rule","\"Do not double at the unison, unless there is a "
        .. "definite need for more volume, or unless the particular color is exactly "
        .. "what is needed for the musical character.\"","BEL p.35"},
      {"What you lose","Combining timbres adds resonance, sweetness and power but "
        .. "\"possesses the disadvantage of restricting the variety of colour and "
        .. "expression. Individual timbres lose their characteristics when associated "
        .. "with others.\" Give phrases needing diverse expression to solo "
        .. "instruments.","RK p.48"},
      {"A solo line stays solo","\"A line whose character requires a solo sound will "
        .. "be less effective when doubled.\" An instrument \"enjoys greater "
        .. "independence and freedom when used as a solo than when it is doubled.\"","BEL p.7; RK p.48"},
      {"Where doubling belongs","Doubling and mixed timbres are naturally more "
        .. "frequent in loud than in soft passages, and where the expression is broad "
        .. "rather than intimate.","RK p.48"},
      {"Making a line stand out","Melody in the upper parts stands out by position "
        .. "alone, and to a lesser degree in the low register. In the middle of the "
        .. "orchestral range it needs help: contrast of timbre, doubling, tripling, or "
        .. "crossing of parts.","RK p.36"},
    }},
    {"Planes of tone", {
      {"What a plane of tone is","\"By 'plane of tone' (D. F. Tovey's term) we "
        .. "refer to one instrument, or a blended group of instruments, not "
        .. "necessarily from the same family, sharing one rhythmic outline. A plane "
        .. "may consist of one line or a textural mass.\" Decide the role of each "
        .. "plane first: \"otherwise, confusion will result.\"","BEL p.39-40"},
      {"Blend within a plane","\"Within a plane of tone, blend is achieved by "
        .. "similarity of timbre and rhythm, close spacing (no large gaps), and "
        .. "balance (all elements fairly equal in force).\"","BEL p.40"},
      {"Separate the planes","\"Between planes of tone, clear differentiation is "
        .. "essential. This is achieved by contrast of register, timbre, and/or "
        .. "rhythm.\"","BEL p.40"},
      {"Interlock to blend, space to separate","For a blended sound use integrated "
        .. "\"interlocking\" voicing balanced to each instrument's strength in that "
        .. "register; for a different colour on each note, use wider spacing.","OMT"},
    }},
    {"Unison vs octave", {
      {"Perfect unison","Fuses tone colour and increases the density of the sound - but \"volume (amplitude) is only partly affected\". If you want it louder, this is not the doubling that does it.","IDIO Perfect Unison"},
      {"Two of the same instrument","Gains power and weight, keeps its individuality, "
        .. "but loses expressive capacity. Two identical instruments in unison may "
        .. "have intonation trouble; three or more turn into a small chorus - three "
        .. "oboes are not twice as loud as one, but the quality changes.","RK p.48; BEL p.7"},
      {"Octaves","\"Octave doubling will always result in an increase in volume, and "
        .. "is by far the most common type of doubling.\" This is the one to reach for "
        .. "when you want more sound, and the one that also clarifies the relation "
        .. "between melody and accompaniment by spreading it across registers.",
        "IDIO Octaves"},
      {"Octaves are easier to hear as two things","Octave doublings, and unison "
        .. "doublings between timbrally diverse instruments, fuse less readily than "
        .. "unisons of similar instruments.","MOD; cf. IDIO Perfect Unison"},
      {"Within-family first","Orchestral practice favours doubling within a family; "
        .. "'cello and double bass are the closest-allied pair in the whole orchestra, "
        .. "playing the same pitch class in the great majority of sonorities where "
        .. "both sound - they played from identical parts as a matter of course well "
        .. "into the 19th century.","MOD; IDIO Unisono and Doubling"},
      {"A line too wide for one instrument","When a unison line runs through more "
        .. "octaves than any one player can cover, instruments change lanes - jumping "
        .. "an octave to carry on. Stagger those shifts: they must not all happen at "
        .. "once, but \"smoothly and carefully graduated\".","IDIO Octaves"},
    }},
    {"Parallel doubling — other intervals", {
      {"What it does","Doubling at intervals other than the octave - most often the "
        .. "third, fifth or sixth, adjusted to fit the current key or scale. \"Even "
        .. "more than octave doubling, parallel doubling results in increased volume "
        .. "and density.\" It is the heaviest of the three, so spend it deliberately.",
        "IDIO Parallel Doubling"},
      {"It still reads as one line","Identity survives a good deal of divergence. In "
        .. "a Messiaen example most instruments descend a major second while the 2nd "
        .. "violins rise an augmented fourth, and the passage is still heard as a "
        .. "single line - because the rhythm, articulation and contour agree. Shared "
        .. "rhythm holds a doubling together more strongly than shared intervals.",
        "IDIO Parallel Doubling"},
      {"Where it shades into polyphony","\"Borderline situations between extended "
        .. "parallel doubling and polyphony are not rare.\" Judge it by weighing "
        .. "independent melodic movement against rhythmic unison: the first splits a "
        .. "texture into segments, the second ties it into one.","IDIO Parallel Doubling"},
      {"Growing habit since 1900","Interest in parallel doublings beyond the octave, "
        .. "third and sixth is noticeably greater in music from the early 20th century "
        .. "onward - Bolero saturates nearly the whole texture with them once it "
        .. "reaches forte.","IDIO Parallel Doubling"},
    }},
    {"Mixture — building an instrument that does not exist", {
      {"The idea","Doubling does not only blend colours; it can synthesise one. Add "
        .. "instruments on a note's own overtones, soft enough that the ear takes them "
        .. "for overtones rather than notes, and the result is a timbre no player "
        .. "possesses - \"invented instruments, so to say\". The organ mixture stop is "
        .. "the model.","IDIO Parallel Doubling"},
      {"The worked example","In Bolero, a horn melody is joined by two piccolos on "
        .. "its 2nd and 4th overtones and a celesta on its 1st and 3rd. Because "
        .. "overtones are fixed intervals independent of tonality, Ravel notates the "
        .. "2nd overtone of a C major melody in G major and the 4th in E major, and "
        .. "marks individual dynamics so the added parts stay below the threshold of "
        .. "being heard as themselves.","IDIO Parallel Doubling"},
      {"The cheap version","A muted trumpet with a flute an octave above: the flute "
        .. "supplies an artificial first overtone and the pair passes for a gentle "
        .. "oboe. Ravel uses it in Bolero to postpone the real oboe. Note that this "
        .. "needs a straight mute, which enhances high overtones; a cup or velvet mute "
        .. "reduces them and gives a closed, less oboe-like sound.","IDIO Parallel Doubling"},
      {"What to double with","Instruments whose own spectra are weak in overtones, so "
        .. "they disappear into the sound they are colouring: flute, string harmonics, "
        .. "celesta, the clarinet's weak middle-register notes.","IDIO ch.12"},
    }},
    {"Partial doubling", {
      {"Don’t double everything","Complete doubling produces a heavy, massive sound. "
        .. "Partial doubling - woodwind partly doubling the high strings while horns "
        .. "partly double the lower ones - keeps weight without clogging.","IDIO Partial Doubling"},
      {"Modify as you double","A bassoon and flute may double the first violins' "
        .. "melody with tiny modifications, dropping embellishments or notes in a "
        .. "strained register so the melodic line keeps its elegance.","IDIO Partial Doubling"},
      {"Let the less agile part simplify","Where two instruments do not share the same "
        .. "agility - 'cellos and basses being the standard case - the slower one plays "
        .. "a simpler version of the line. This is not a compromise; it is how the "
        .. "pairing has always worked.","IDIO Partial Doubling"},
      {"Split a passage to make it playable","Large intervals, high and fast, invite "
        .. "intonation trouble. Berlioz distributes such a theme between the violins "
        .. "so no one desk has to leap - orchestration solving a technical problem "
        .. "rather than a colouristic one. Ravel does the same for the triple-tonguing "
        .. "in Bolero, modifying it for the woodwind while the horns play it straight.",
        "IDIO Partial Doubling"},
      {"Dividing a group costs density, not volume","Splitting a string group into two "
        .. "equal parts \"does not noticeably influence the volume of each half, but "
        .. "can reduce the density of sound to a certain degree\". Divide freely for "
        .. "texture; do not expect each half to sound half as loud.","IDIO Partial Doubling"},
      {"Orchestrated gesture","Rapid runs in the most agile instruments - strings, "
        .. "flute, clarinet, piano, harp - written differently for each to mark an "
        .. "overall sweep rather than a line. Doubling them exactly \"would sound "
        .. "unnecessarily weighty or overly defined\".","IDIO Partial Doubling"},
      {"Transference","When a phrase outruns one instrument's range, hand it on: make "
        .. "the last note of each part coincide with the first note of the next.","RK p.107"},
    }},
    {"The wind/string equivalences", {
      {"Rough family mapping","Violins answer to flutes and oboes, viola to clarinet, "
        .. "'cello to bassoon - a serviceable first guess when choosing which wind to "
        .. "add to which string group.","MOD"},
      {"Standard blended pairs","Low clarinet + viola; horn + 'cello (or all horns "
        .. "with all low strings); oboes + trumpets at soft dynamics; bassoons + "
        .. "string pizzicato; horn + bassoon in the middle register for a slimmer, "
        .. "more focused horn sound.","IDIO ch.12"},
    }},

    {"Why more instruments is not more colour", {
      {"The paint analogy","Mixing many colours of paint gives grey or black, and "
        .. "combining many instruments cancels the unique qualities of each. Flute, "
        .. "clarinet, trumpet, marimba and violin in unison do not sound five times as "
        .. "colourful; they sound generic. This is the mechanism behind the grayness "
        .. "Belkin warns of below.","ACTOR All Instruments: Effective Instrumental Writing"},
      {"Colour is contextual, not absolute","\"A single clarinet sounds much less "
        .. "colorful when draped over a backdrop of saxophones than it does when combined "
        .. "with a string choir.\" And the dense combination that sounds generic on its "
        .. "own can be striking if it follows a long passage of solo writing. Judge a "
        .. "colour against what precedes and surrounds it.",
        "ACTOR All Instruments: Effective Instrumental Writing"},
      {"Mixed timbres penetrate further than matched ones","In an octave doubling, \"the "
        .. "mix of the different timbres in each octave is more penetrating than doubles "
        .. "of the same timbre a2\" - so oboes and clarinets each in octaves project "
        .. "better than either pair doubled in unison. Tchaikovsky's Fourth uses exactly "
        .. "this for its strongest lines.","ACTOR Woodwinds: Scoring Excerpts"},
      {"The flute is the exception","Its weak low register means a flute taken down to "
        .. "double an oboe contributes less than it would playing a2 in the higher "
        .. "octave. In the middle octave, though, flutes add body to oboes for a full but "
        .. "less brilliant sound.","ACTOR Woodwinds: Scoring Excerpts"},
      {"How many sounds an instrument has","Not one. A clarinet alone offers low, "
        .. "middle and high, staccato and legato, sustained, loud and soft - before any "
        .. "combination. A woodwind quintet has far more than five sounds, and thinking "
        .. "of an instrument as a single colour is the beginner's error.",
        "ACTOR All Instruments: Effective Instrumental Writing"},
    }},
    {"Doubling without grayness", {
      {"The problem with literal doubling","\"Too frequent literal doubling leads to "
        .. "heaviness and a rather gray sound.\" Grayness - too much unison doubling - is "
        .. "one of Belkin's named symptoms of poor orchestration.","BEL p.37 & p.18"},
      {"Double at intervals other than the unison","\"Doubling at the octave allows for "
        .. "greater transparency of color, and also fills the musical space in more "
        .. "interesting and varied ways. Occasional doubling at other intervals, "
        .. "especially in the higher octaves, can also create interesting synthetic "
        .. "timbres (like mutation stops on the organ).\" Bolero doubles a horn at the "
        .. "twelfth and two octaves plus a third.","BEL p.37-38"},
      {"Heterophony","\"Rather than literal doubling, each doubled part can be an "
        .. "ornamental variation on the same basic contour. This keeps the overall design "
        .. "clear, but allows for individuality.\" Mozart's Figaro overture stays light in "
        .. "a tutti this way.","BEL p.38"},
      {"Let doubling become counterpoint","\"An instrument can begin a phrase as a "
        .. "doubling, and at some musically meaningful point - a change of motive, a "
        .. "climax, a cadence - become more contrapuntal, or vice versa.\"","BEL p.38"},
      {"Piece-meal doubling","Doubling that moves between several lines in turn, "
        .. "\"creating new lines, which do not, however, add significant polyphony to the "
        .. "texture\". Mahler's Ninth: the first horn is an inner counterpoint, then "
        .. "doubles the 'cello, then the first trombone.","BEL p.38"},
      {"Partial doubling","Double only the highlights - the beginning, the end, or a few "
        .. "motives. \"The doubling can then drop out, or become background resonance, "
        .. "settling down on a held note. The opposite (a held note becomes a doubling) is "
        .. "also possible.\"","BEL p.38"},
      {"Why it is worth the trouble","\"By individualizing doublings in these ways - "
        .. "creating a sort of pseudo-counterpoint rather than simply duplicating lines "
        .. "mechanically - the overall effect gains in subtlety and nuance. The players' "
        .. "parts are also more individual and interesting to play.\"","BEL p.39"},
    }},
  },
  related={"blend","balance","strings_wind","wind_brass","three_groups","strings_brass"},
}

-- ============================================================================
-- STRINGS
-- ============================================================================

e{ id="violin", name="Violin", family="Strings", kind="instrument",
  aliases={"violin","violins","violin i","violin ii","violins i","violins ii",
           "first violins","second violins","vn","vns","fiddle","vln"},
  summary="\"Pre-eminently a melodic instrument - the splendid sparkling soprano of "
       .. "the stringed tribe, the richest in varied effects, the most agile and the "
       .. "most impassioned of orchestral elements\" (Lavignac). Melody in the "
       .. "soprano-alto register and above usually falls to the first violins.",
  facts={
    {"Strings","G - D - A - E"},
    {"In the choir","Violins I sing soprano, Violins II mezzo-soprano"},
    {"Numbers","16/12/8 firsts and 14/10/6 seconds (full/medium/small, RK); 14/12 "
      .. "firsts/seconds is a common professional layout today"},
  },
  sec={
    {"Pairings in unison", {
      {"+ Violins II","Gains power and richness without altering colour; the tone "
        .. "stays that of the string quartet, enriched. The weight of violins prevents "
        .. "any doubling woodwind from predominating.","RK p.39"},
      {"+ Violas","Violins remain predominant; rich, full resonance.","RK p.39"},
      {"+ ’Cellos","The 'cello tone prevails and the resonance is fuller.","RK p.40"},
      {"+ Flute","One of the best and most natural string/wind combinations - "
        .. "registers correspond closely. Also with alto flute or piccolo.","RK p.58"},
      {"+ Oboe","A classic: the oboe gives the violins bite and definite colour, the "
        .. "violins soften the oboe.","RK p.58"},
      {"+ Clarinet","As above, warmer; also with E-flat clarinet.","RK p.58"},
      {"+ Trumpet","The best-matched string/brass pair by register - though the two "
        .. "are always heard distinctly.","RK p.61"},
      {"+ Oboe (or Flute, Clarinet) + Trumpet","The standard soprano grouping of all "
        .. "three orchestral groups, for loud passages or heavy piano.","RK p.61"},
      {"+ 2 Fl + 2 Ob (absorbed)","With that much wind in unison, the wind timbre "
        .. "predominates and the violins are absorbed into a sweet coherent quality.","RK p.34"},
      {"+ 1 Oboe only (thickened)","A single wind added to the whole violin body only "
        .. "thickens the strings; the wind timbre is lost.","RK p.34"},
    }},
    {"Doublings in octaves", {
      {"Vns I / Vns II","\"A very common process used for all kinds of melodic "
        .. "figures, in particular those in the very high register\", which otherwise "
        .. "stand too isolated. Secures expression, fullness and firmness of timbre. "
        .. "The classic orchestral sound: high octave to the firsts, lower to the "
        .. "seconds.","RK p.40; ACTOR Woodwinds: Scoring Excerpts"},
      {"But Berlioz prefers the unison","He grants that doubling the firsts with the "
        .. "seconds an octave below is the common way to give a violin passage power - "
        .. "and says that unless the passage lies high, putting all the violins in "
        .. "unison is far better, incomparably more powerful and beautiful. He cites "
        .. "the end of the first movement of Beethoven's Fifth, whose electrifying "
        .. "effect he attributes to violins in unison. Rimsky-Korsakov recommends the "
        .. "octave; Berlioz recommends the unison below the top of the range. Both are "
        .. "in the repertoire, so decide by register: high, octave; otherwise, try the "
        .. "unison first.","BERL The violin; cf. RK p.40"},
      {"Vns / Violas","Common, especially when the lower octave goes below the open G.","RK p.41"},
      {"Violins in unison + Violas an octave below","Berlioz warns against it: having "
        .. "reached a violin unison, reinforcing it with violas an octave down is too "
        .. "weak and out of proportion to the part above, and adds a superfluous "
        .. "buzzing that obscures the violins rather than strengthening them. If the "
        .. "viola part cannot be made distinctive, put the violas in unison with the "
        .. "'cellos instead - as Beethoven does in the same movement.","BERL The viola"},
      {"Vns / ’Cellos","For very expressive passages, with the 'cellos on the A or D "
        .. "string. More resonant than violas/'cellos; instances are frequent.","RK p.42"},
      {"Vns I + II / Violas + ’Cellos","Each octave doubled in unison; \"constantly "
        .. "found\" for melodies in the middle range, beautiful and somewhat severe.","RK p.43"},
      {"Picc / Fl + Vns","When only one of two octaves may be doubled in a soprano "
        .. "melody, let the woodwind take both octaves and double just the lower one "
        .. "with violins. Also Fl / Ob (Cl) + Vns.","RK p.60"},
    }},
    {"Thirds and sixths", {
      {"Thirds","Use the same colour in both parts; write thirds doubled in octaves "
        .. "with firsts and seconds - despite unequal numbers the thirds will not "
        .. "sound unbalanced.","RK p.45"},
      {"Sixths","Different timbres may be used. A striking inversion: 'Cellos above, "
        .. "Violins I + II on the G string below, in sixths - \"distinctly original in "
        .. "character\".","RK p.45-46"},
      {"Second violins as harmony","Rather than doubling, the seconds often take a "
        .. "harmony part in thirds and sixths below the melody.","WP"},
    }},
    {"Technique and colour", {
      {"The E string","Diminishes in fullness the higher it climbs above the soprano "
        .. "voice - a reason to double high figures an octave below.","RK p.40"},
      {"Extreme high register","Playable but piercing; one or two desks on the top "
        .. "octave with the rest of the firsts an octave below diminishes the shrillness "
        .. "and strengthens the expressive lower octave.","RK p.42 n."},
      {"Muted (con sordini)","Gives a dull, ethereal quality - but muted strings do "
        .. "not combine well with woodwind, the qualities staying distinct.","RK p.36-37 & p.34"},
      {"Harmonics","Related in quality to the flute and piccolo; that relationship is "
        .. "the link between the two groups in the orchestra's upper range.","RK p.35"},
      {"Col legno","Struck with the wood of the bow, the sound resembles a xylophone "
        .. "and improves as more players join.","RK p.32"},
      {"Solo violin","One of the two string solos that are reasonably frequent (with "
        .. "the 'cello). Needs a light, transparent accompaniment; avoid writing "
        .. "difficult virtuoso solos, which draw too much attention.","RK p.104-105"},
      {"Solo violin + Flute or Piccolo","Two solo violins, or solo violin + flute, are "
        .. "often enough to double a melody in the upper register while keeping the "
        .. "solo timbre.","RK p.105-106"},
    }},
    {"Divisi", {
      {"Score alike across the section","A good rule is all divisi or none, so no "
        .. "string group is unduly heavy against another. A standard approach keeps the "
        .. "firsts in unison and divides seconds, violas and 'cellos as voice leading "
        .. "requires.","MOD"},
      {"Balanced six/seven-part harmony","If the whole group divides the same way - "
        .. "Vns I div., Vns II div., Violas div. - the balance is completely "
        .. "satisfactory; ease the undivided 'cellos and basses by marking them down "
        .. "or reducing players.","RK p.70"},
      {"Not divided in octaves","Violins divisi in octaves halves the players and "
        .. "drains resonance; usable when the woodwind doubles them.","RK p.40-41"},
    }},
  },
  related={"strings","viola","cello","flute","oboe","clarinet","trumpet","strings_wind"},
}

e{ id="viola", name="Viola", family="Strings", kind="instrument",
  aliases={"viola","violas","alto violin","vla","vlas"},
  summary="\"Of all instruments in the Orchestra the one whose excellent qualities "
       .. "have been longest misappreciated\" (Berlioz). Melody in the alto-tenor "
       .. "register and above; better fitted for short characteristic phrases than "
       .. "long cantabile, and usually doubled by other strings or by woodwind.",
  facts={
    {"Strings","C - G - D - A (a fifth below the violin, an octave above the 'cello)"},
    {"In the choir","Alto / tenor"},
    {"Numbers","12/8/4 (full/medium/small, RK); around 10-12 today"},
  },
  sec={
    {"Pairings in unison", {
      {"+ ’Cellos","Rich, full resonance with the 'cello quality predominating.","RK p.39"},
      {"+ Violins","No special new character; the violins stay predominant.","RK p.39"},
      {"+ Oboe or English horn","One of the best-matched string/wind pairs.","RK p.58"},
      {"+ Clarinet","Especially the clarinet's low register: the viola's timbre is "
        .. "comparable to the lowest compass of the clarinet, making this one of the "
        .. "standard blended doublings.","RK p.58 & p.35-36; IDIO ch.12"},
      {"+ Bassoon","The viola also resembles the bassoon's middle register; "
        .. "Tchaikovsky's Marche Slave uses bassoon with violas \"very effectively\".","RK p.58 & p.35-36; SIN p.97"},
      {"+ Horn","The best-matched string/brass pair in the alto-tenor range; muted "
        .. "violas with horn is a favourite effect.","RK p.61"},
      {"+ Clarinet (or Eng. horn) + Horn","The standard alto-tenor grouping of all "
        .. "three groups.","RK p.61"},
      {"+ 2 Ob + 2 Cl (absorbed)","With that much wind, the wind timbre predominates.","RK p.34"},
      {"+ ’Cellos + 1 Clarinet (thickened)","A single wind added to the string body "
        .. "only thickens it; the wind timbre disappears.","RK p.34"},
    }},
    {"Doublings in octaves", {
      {"Vns / Violas","Common, especially when the lower octave falls below the "
        .. "violin's open G. Vns I + II / Violas gives brilliance above; Vns I / Vns II "
        .. "+ Violas gives a fuller, more cantabile lower octave.","RK p.41"},
      {"Violas / ’Cellos","Of special use when the violins are otherwise employed; "
        .. "often doubled by bassoons.","RK p.41"},
      {"Violas + 2 Cl / ’Cellos + D. basses + 2 Fag","A fully scored low-middle "
        .. "octave doubling.","RK p.59"},
    }},
    {"Character", {
      {"Berlioz","\"No less agile than the violin. The sound of its strings is "
        .. "peculiarly telling. Its upper notes are distinguished by their mournfully "
        .. "passionate accent; and its quality of tone, altogether of profound "
        .. "melancholy, differs from that of other instruments played with a bow.\"","SIN p.51"},
      {"Berlioz, on the high strings","\"Melodies on the high strings of the viola "
        .. "have a marvellous beauty in scenes of a religious and unique character.\"","SIN p.51"},
      {"Range of sentiment","\"From sad reverie to agonized pathos.\" Slightly nasal "
        .. "in quality.","SIN p.52; RK p.37"},
      {"How many you need","Berlioz: its tone \"so strongly attracts and captivates "
        .. "the attention that it is not necessary to have in the Orchestra quite so "
        .. "many violas as second violins\".","SIN p.51"},
      {"The repertoire that made the case","Berlioz's Harold en Italie (solo viola as "
        .. "Childe Harold); Wagner's Venusberg motive in the Tannhauser overture; "
        .. "Strauss's Sancho Panza in Don Quixote.","SIN p.50-51"},
    }},
    {"Berlioz on how many, and how to divide them", {
      {"You need fewer than the second violins","Its tone is distinctive enough that a "
        .. "section need not match the seconds in number - the colour carries without "
        .. "the weight.","BERL The viola"},
      {"Divide only if you have the players","Berlioz approves dividing violas into "
        .. "firsts and seconds where the numbers are adequate, and warns that with only "
        .. "four or five it can only damage a group already weak and easily overwhelmed.",
        "BERL The viola"},
      {"Check the instruments are real violas","He complains that many violas then in "
        .. "French orchestras were undersized - effectively violins strung as violas - "
        .. "and so lacked the tonal power of the real instrument, draining colour and "
        .. "energy from the low notes especially.","BERL The viola"},
    }},
    {"Use sparingly", {
      {"A whole work built on violas","Mehul wrote Uthal for violas with no violins at "
        .. "all, to match the dreamy character of Ossianic poetry; contemporaries found "
        .. "it unbearably monotonous and it damaged the work. Gretry is said to have "
        .. "offered a louis to hear an E string. Berlioz's verdict is that the viola's "
        .. "tone, valuable when contrasted with others, becomes wearisome quickly: it "
        .. "is too short of variety and too tinged with sadness to sustain a whole "
        .. "piece.","BERL The viola"},
      {"Solo viola","\"The solo viola is seldom found\" - unlike violin and 'cello "
        .. "solos.","RK p.104"},
      {"Violas / D. basses in octaves","Seldom arises; only when the 'cellos are "
        .. "otherwise employed.","RK p.42"},
      {"Long cantabile","Cantabile melodies go less often to violas than to violins "
        .. "and 'cellos, both because the tone is slightly nasal and because there are "
        .. "fewer players.","RK p.37"},
    }},
  },
  related={"strings","violin","cello","clarinet","englishhorn","horn","bassoon"},
}

e{ id="cello", name="Violoncello", family="Strings", kind="instrument",
  aliases={"cello","cellos","violoncello","violoncellos","vc","vlc","'cello","'cellos"},
  summary="\"A ravishing instrumental tenor, of pure, warm timbre, ecstatic or "
       .. "passionate, but always distinguished and captivating\" (Lavignac). More "
       .. "often entrusted with tense, passionate cantabile than with rapid figures; "
       .. "such melodies are usually laid out for the top (A) string.",
  facts={
    {"Strings","C - G - D - A (an octave below the viola)"},
    {"In the choir","Tenor and bass; \"usually it gives, reinforced by the double "
      .. "bass, the bass of the harmony. This is its natural work.\""},
    {"Numbers","10/6/3 (full/medium/small, RK); 8-12 today"},
  },
  sec={
    {"Pairings in unison", {
      {"+ Double basses","Rich, full resonance; the standard bass. Empirically the "
        .. "closest-allied pair in the whole orchestra.","RK p.40; MOD"},
      {"+ Violas","Rich and full, with the 'cello on top.","RK p.39"},
      {"+ Violins","The 'cello tone prevails and the resonance is fuller.","RK p.40"},
      {"+ Bassoon","One of the best-matched string/wind pairs; bassoons added to "
        .. "'cello and bass parts clarify and reinforce them.","RK p.58; MOD"},
      {"+ Clarinet or Bass clarinet","As above, for a darker colour.","RK p.58"},
      {"+ Horns","\"Frequently employed, produces a beautifully blended, soft quality "
        .. "of tone\" - the one string/brass combination Rimsky-Korsakov singles out, "
        .. "and a standard blended pair in modern practice too.","RK p.61; IDIO ch.12"},
      {"+ Trombones / Tuba (with D. basses)","For heavy, massive effects.","RK p.61"},
      {"+ 2 Fag + 3 Trombones + Tuba (with D. basses)","The standard bass grouping of "
        .. "all three groups.","RK p.61"},
      {"+ 2 Cl + 2 Fag (absorbed)","With that much wind in unison the wind timbre "
        .. "predominates.","RK p.34"},
      {"+ English horn (with violins or violas)","Rimsky-Korsakov's own favourite "
        .. "recipe - 'Cellos + Violas + Eng. horn, or Vns + 'Cellos + Eng. horn.","RK p.58-59"},
    }},
    {"Doublings in octaves", {
      {"’Cellos / D. basses","\"The bass is usually constructed in this manner. "
        .. "Examples of it are to be found everywhere.\" The bass part is sometimes "
        .. "simplified against the 'cello part.","RK p.42"},
      {"Vns / ’Cellos","For very expressive passages with the 'cellos on the A or D "
        .. "string; more resonant than violas/'cellos, and frequent.","RK p.42"},
      {"Violas / ’Cellos","When the violins are otherwise employed.","RK p.41"},
      {"’Cellos + Bassoon / D. basses","For a low melody needing a sweet, soft tone - "
        .. "the basses left undoubled.","RK p.60"},
      {"’Cellos + Bass cl / D. basses + C-Fag","A fully reinforced low octave.","RK p.59"},
    }},
    {"When to separate from the basses", {
      {"The default, and why to leave it","Orchestral practice gives 'cellos and "
        .. "double basses the same part, in unison or an octave apart. Berlioz lists "
        .. "four reasons to separate them, and says the cases are numerous: to let the "
        .. "'cellos sing a melody on their upper strings; to put them below the basses "
        .. "for an open-string or harmonic effect; or to give them the bass line with "
        .. "figuration quicker than the basses could manage cleanly.",
        "BERL The cello; cf. RK p.42"},
    }},
    {"Character", {
      {"Berlioz","\"Violoncellos together to the number of eight, or ten, are "
        .. "essentially melodious; their quality on the upper strings is one of the "
        .. "most expressive in the Orchestra. Nothing is more voluptuously melancholy "
        .. "or more suited to the utterance of tender, languishing themes than a mass "
        .. "of violoncellos playing in unison upon their first string.\"","SIN p.65"},
      {"Also","\"Excellent for airs of a religious character.\" The two lower strings "
        .. "are smooth and deep, but too low to carry melodies.","SIN p.65"},
      {"Solo ’cello","With the violin, one of the two string solos reasonably often "
        .. "used. A solo 'cello combined with violins gives the latter a touch of "
        .. "'cello timbre.","RK p.104 & p.40"},
      {"Clefs","Bass clef for the lower and middle registers, tenor clef above that, "
        .. "treble for the top notes.","SIN p.62"},
    }},
  },
  related={"strings","doublebass","viola","bassoon","horn","clarinet","trombone"},
}

e{ id="doublebass", name="Double Bass", family="Strings", kind="instrument",
  aliases={"double bass","double-bass","doublebass","double basses","basses","contrabass",
           "bass","db","cb","string bass","d. basses"},
  summary="\"Dull in tone and of little flexibility, chiefly employed in unison or in "
       .. "octaves with the violoncellos.\" It doubles - it plays the bass an octave "
       .. "below whatever instrument carries it. \"Its heavy notes are for the good of "
       .. "the community.\"",
  facts={
    {"Strings","E - A - D - G, tuned in fourths (inherited from the viol family)"},
    {"Notation","Bass clef, written an octave above the real sound"},
    {"Numbers","8-10/4-6/2-3 (full/medium/small, RK); 6-8 today"},
  },
  sec={
    {"Pairings in unison", {
      {"+ ’Cellos","Rich and full; the standard low-register combination, and the "
        .. "closest-allied pair in the orchestra.","RK p.40; MOD"},
      {"+ Bassoon","One of the best-matched string/wind pairs in the bass.","RK p.58"},
      {"+ Contrabassoon","For the true bottom of the orchestra.","RK p.58"},
      {"+ Bass clarinet","As above, darker and smoother.","RK p.58"},
      {"+ Trombones / Tuba (with ’cellos)","For heavy, massive effects.","RK p.61"},
      {"+ 2 Fag + 3 Trombones + Tuba (with ’cellos)","The standard bass grouping of "
        .. "all three groups; the tuba is \"eminently useful for doubling, an octave "
        .. "lower, the bass of the group to which it belongs\".","RK p.61 & p.24"},
      {"+ ’Cellos + D. basses + 1 Bassoon (thickened)","One wind added to the string "
        .. "bass only thickens it; the bassoon timbre is lost.","RK p.34"},
    }},
    {"Doublings in octaves", {
      {"’Cellos / D. basses","The normal bass; the bass part is sometimes simplified.","RK p.42"},
      {"’Cellos + Fag / D. basses","For a sweet, soft low melody - leave the basses "
        .. "undoubled. Sometimes obligatory when no contrabassoon is available.","RK p.60"},
      {"’Cellos + Bass cl / D. basses + C-Fag","Fully reinforced.","RK p.59"},
      {"Violas / ’Cellos / D. basses","In double octaves, for the low register and "
        .. "rough, severe phrases.","RK p.44"},
    }},
    {"Character", {
      {"Verdi and Wagner","Verdi treated it as \"a dark, morbid personality, "
        .. "particularly fitted for tragedy\" (Otello's entrance into Desdemona's "
        .. "chamber). Stanford praised Die Meistersinger for \"the most economical and "
        .. "perfectly proportionate use of that dangerous rogue-elephant, the "
        .. "double-bass\".","SIN p.69-70"},
      {"Best notes","Open strings; harmonics are frequent and effective.","SIN p.69"},
      {"Against the voice","Frequent long sustained bass notes are unfavourable to a "
        .. "singer - the combination \"produces a peculiar throbbing effect\".","RK p.121"},
    }},
    {"Use sparingly", {
      {"Solo double bass","\"Practically unknown\"; Rimsky-Korsakov writes no "
        .. "important phrase for it \"without the support of 'cellos or bassoons\".","RK p.104 & p.38"},
      {"Broad cantabile","Its muffled resonance makes it little capable of broad "
        .. "cantabile except in unison or octaves with the 'cellos.","RK p.38"},
      {"Pizzicato speed","Much slower than on the violins - the thicker the string, "
        .. "the slower the pizzicato.","RK p.27"},
    }},
  },
  related={"strings","cello","bassoon","contrabassoon","tuba","bassclarinet"},
}

e{ id="pizzicato", name="Pizzicato", family="Strings", kind="technique",
  aliases={"pizzicato","pizz","plucked","pizzicati","plucking"},
  summary="\"Although capable of every degree of power from ff to pp, pizzicato "
       .. "playing has but small range of expression, and is used chiefly as a colour "
       .. "effect.\" Rimsky-Korsakov classes it with the harp as a separate group of "
       .. "plucked strings.",
  sec={
    {"Pairings", {
      {"+ Woodwind or brass","Wind strengthens and clarifies pizzicato strings; the "
        .. "black (dry, resonance-less) top notes \"should only be used when doubled "
        .. "with the wood-wind\".","RK p.34 & p.31"},
      {"+ Percussion","Excellent - \"the two blend perfectly, and the consequent "
        .. "increase in resonance yields an admirable effect\".","RK p.34"},
      {"+ Harp","The natural partner; together they form the plucked group.","RK p.26"},
      {"+ Bassoons","One of the standard blended pairs - close enough in colour that the combination reads as a single sound.","IDIO ch.12"},
      {"+ same woodwind in octaves","Two of the same woodwind in octaves - normally "
        .. "not recommended - becomes safe when pizzicato (or arco) strings double both "
        .. "members, especially in the middle compass.","RK p.50"},
      {"Sforzando-piano","As the woodwind begins a piano chord, the strings attack it "
        .. "sforzando pizzicato - a compound chord for preference.","RK p.111"},
      {"For a singer","Strings pizzicato + harp \"forms a setting eminently favourable "
        .. "for the voice\"; complicated figures are better given partly to pizzicato "
        .. "and harp, which have little chance of overpowering it.","RK p.120 & p.122"},
    }},
    {"Writing it", {
      {"Speed","Never as fast as arco, and slower the thicker the string.","RK p.27"},
      {"Tone","Resonant and heavy on open strings, shorter and duller on stopped "
        .. "strings, dry and hard in high positions.","RK p.27"},
      {"Chords","Avoid open strings, which are more brilliant than covered ones. "
        .. "Four-note chords allow the greatest freedom and vigour of attack.","RK p.27"},
      {"Harmonics pizzicato","\"Create a charming effect\"; weak in tone, and most "
        .. "successful on the 'cello.","RK p.27"},
      {"Tutti pizzicato","The pizzicato quartet with harp and piano can form its own "
        .. "tutti - medium power, fairly brilliant, and only really strong with "
        .. "woodwind support.","RK p.103"},
    }},
    {"Use sparingly", {
      {"+ Bowed strings","Uniting plucked with bowed strings \"does not produce such a "
        .. "satisfactory blend, both qualities being heard independently\".","RK p.34"},
    }},
  },
  related={"strings","harp","plucked","percussion"},
}

-- ============================================================================
-- WOODWIND
-- ============================================================================

e{ id="flute", name="Flute", family="Woodwind", kind="instrument",
  aliases={"flute","flutes","fl","concert flute","transverse flute"},
  summary="\"Cold in quality, specially suitable, in the major key, to melodies of "
       .. "light and graceful character; in the minor key, to slight touches of "
       .. "transient sorrow.\" With the clarinet, the most flexible of the woodwind, "
       .. "and the only one capable of double tonguing.",
  facts={
    {"Class","Bright 'chest-voice' quality, with the clarinets"},
    {"Registers","Low: dull, cold.  Very high: brilliant"},
    {"Notes","Non-transposing. No way has been found to mute it"},
  },
  sec={
    {"Pairings in unison", {
      {"+ Oboe","Fuller than the flute alone, sweeter than the oboe alone. Played "
        .. "softly the flute predominates low, the oboe in the upper register.","RK p.47"},
      {"+ Clarinet","Fuller than the flute, duller than the clarinet; flute "
        .. "predominates lower, clarinet higher. In the clarinet's clarino register the "
        .. "two have a particular affinity, and in octaves their combined resonance "
        .. "turns almost organ-like.","RK p.47; MOD"},
      {"+ Oboe + Clarinet","Very full; flute low, oboe middle, clarinet high.","RK p.48"},
      {"+ Violins","One of the best and most natural string/wind combinations.","RK p.58"},
      {"+ Trumpet","One of the trumpet doublings Rimsky-Korsakov lists as fairly "
        .. "numerous, especially in forte; also Trumpet + Cl + Ob + Fl.","RK p.56"},
      {"+ Solo violin","Violin + flute, or 2 solo violins, often suffice to double a "
        .. "melody in the upper register while keeping the solo character.","RK p.105-106"},
      {"2 Flutes","Gains power, keeps its individuality, but loses expressive capacity "
        .. "- as with any pair of like instruments.","RK p.48"},
    }},
    {"Doublings in octaves", {
      {"Picc / Fl","Same-branch octaves \"always produce a good effect\", and this is "
        .. "the standard way to extend the top of the orchestra.","RK p.50"},
      {"Fl / Ob  and  Fl / Cl","The natural resonance order, flute on top.","RK p.49"},
      {"Fl / Alto flute","Same-branch octaves.","RK p.50"},
      {"Picc / Fl / Ob or Cl","Three-octave layouts with the flute in the middle.","RK p.51"},
      {"2 Flutes above a trumpet","To double a trumpet an octave up normally needs "
        .. "three or four wind instruments - \"but in the top register two flutes will "
        .. "suffice\".","RK p.58"},
      {"2 Fl above 1 Horn","One of the standard woodwind-above-horn octave doublings, "
        .. "used to give the upper octave a richness the trumpet cannot supply.","RK p.57"},
      {"Low flute thirds between trumpet octaves","In soft passages, thirds in the low "
        .. "flutes - sometimes with clarinets - \"produce a beautiful mysterious "
        .. "effect\" between trumpets an octave apart.","RK p.91"},
    }},
    {"As an artificial overtone", {
      {"Why it works","The flute's first overtone - the octave - is powerfully "
        .. "present, which gives it a near-sine tone and makes it the ideal instrument "
        .. "for supplying an overtone another instrument lacks.","IDIO ch.12"},
      {"Two octaves above the fundamental","Doubling a clarinet or bassoon two octaves "
        .. "up - the third overtone - goes back to the classical period and Mozart, and "
        .. "\"nearly became a trademark for Sibelius\". Despite the high register the "
        .. "flute \"increases the fullness of sound without becoming overly prominent in "
        .. "itself\".","IDIO ch.12"},
      {"An octave above a muted trumpet","The flute supplies the trumpet's artificial "
        .. "first overtone and the pair reads as a gentle oboe. Needs a straight mute: a "
        .. "cup or velvet mute removes the high overtones the effect depends on.",
        "IDIO Parallel Doubling"},
      {"Guard its register","Having few overtones of its own, the flute is masked by "
        .. "the overtones of lower instruments in its middle register, and more easily "
        .. "still at the bottom. Keep the register clear rather than marking it louder.",
        "IDIO ch.12"},
    }},
    {"Character and use", {
      {"Singleton","\"The nightingale, the thrush, the lark, the oriole, the "
        .. "mocking-bird of the Orchestra. It warbles.\" Its voice is gentle, ethereal, "
        .. "pure, sweet and soothing - used for poetic and tender sentiment, religious "
        .. "scenes, and to suggest beautiful dreams.","SIN p.73"},
      {"Lavignac","\"The ethereal, suave, transparent timbre of the flute, with its "
        .. "placidity and its poetic charm, produces an auditive sensation similar to "
        .. "the visual impression of the color blue, a fine blue, pure and luminous as "
        .. "the azure of the sky.\"","SIN p.74"},
      {"With the first violins","\"Very often it doubles the first violins in the "
        .. "melody, running along with them smoothly and sweetly.\"","SIN p.73"},
      {"Blend bridge","Its lowest register recalls the pianissimo trumpet; string "
        .. "harmonics relate closely to the flute and piccolo, linking strings and "
        .. "woodwind at the top of the orchestra.","RK p.36 & p.35"},
      {"As an echo","\"Flutes also may imitate clarinets and oboes successfully.\"","RK p.110"},
      {"Modern scoring","\"Modern compositions usually call for two flutes and a "
        .. "piccolo.\"","SIN p.78"},
    }},
    {"Use sparingly", {
      {"+ Bassoon","\"Very seldom found except in certain orchestral tutti\" in unison, "
        .. "and rare in octaves because the registers lie so far apart. (Some modern "
        .. "writers find flute and bassoon work better than oboe and bassoon.)","RK p.48-49; MOD"},
      {"2 Flutes in octaves","\"Certainly not to be recommended\" - the two registers "
        .. "do not correspond. Safe when strings double both parts.","RK p.49-50"},
      {"Below the oboes or bassoons","Placing flutes below oboes and clarinets, and "
        .. "especially below the bassoons, \"creates a far-fetched, unnatural tone\".","RK p.46"},
      {"Doubling a trombone an octave up","Use trumpets instead.","RK p.58"},
    }},
  },
  related={"woodwind","piccolo","altoflute","oboe","clarinet","violin","strings_wind"},
}

e{ id="piccolo", name="Piccolo", family="Woodwind", kind="instrument",
  aliases={"piccolo","piccolos","picc","piccolo flute","ottavino"},
  summary="\"The duty of the piccolo and small clarinet is, principally, to extend the "
       .. "range of the ordinary flute and clarinet in the high register.\" Its "
       .. "whistling, piercing top compass is extraordinarily powerful but will not "
       .. "take moderate shades of expression; it and the contrabassoon are the two "
       .. "instruments with no \"scope of greatest expression\" at all.",
  facts={
    {"Notation","Treble clef, written an octave below the real pitch"},
    {"Range","Over two octaves; almost every player has high B and C"},
    {"Low register","Corresponds to the flute's, but so much weaker as to be of "
      .. "little service"},
  },
  sec={
    {"Pairings and doublings", {
      {"Picc / Fl in octaves","The standard extension of the flute upward, and one of "
        .. "the same-branch octave pairs that \"always produce a good effect\".","RK p.50"},
      {"Picc / Ob  ·  Picc / Cl","Double a piccolo line an octave lower with flute, "
        .. "oboe or clarinet - as a rule, always double a melody lying in the extremely "
        .. "high compass an octave below.","RK p.50"},
      {"Picc / E-flat clarinet","The two shrillest instruments in octaves, for "
        .. "deliberately piercing colour.","RK p.50"},
      {"Picc + Vns I (top of a 3-octave melody)","e.g. Vns I + Picc / Vns II + Fl + "
        .. "Ob / Violas + 'Cellos + 2 Cl + Eng horn + Fag.","RK p.59"},
      {"Solo violin + Piccolo","Used to gild a solo line without losing it.","RK p.105-106"},
      {"+ Celesta","A modern pairing: a piccolo melody doubled by celesta gains a "
        .. "bright, chiming edge.","WP"},
    }},
    {"Character and use", {
      {"Gilt edging","\"The piccolo is often used to brighten the upper notes of the "
        .. "other members of the Woodwind Family in all kinds of combinations. This "
        .. "method of using the piccolo might be likened to brightening up an article "
        .. "with gold leaf.\"","SIN p.79"},
      {"Berlioz on its proper use","\"In pieces of a joyous character, the sounds of "
        .. "the second octave are suitable in all their gradations; while the upper "
        .. "notes are excellent fortissimo for violent and tearing effects: in a storm, "
        .. "for instance, or in a scene of fierce, or infernal, character.\"","SIN p.80"},
      {"Berlioz’s warning","He calls it \"a stupid method of instrumentation\" to use "
        .. "the piccolo to double a baritone line in triple octave, to cast its "
        .. "squeaking voice into religious harmony, or to sharpen the top of the "
        .. "orchestra \"for the sake of noise only\".","SIN p.81"},
      {"Also usable softly","\"The piccolo flute may have a very happy effect in soft "
        .. "passages; and it is mere prejudice to think that it should only be played "
        .. "loud.\"","SIN p.81"},
      {"With cymbals","Spontini's discovery: a short piercing piccolo cry joined to a "
        .. "cymbal stroke - \"it cuts and rends instantaneously\". Augment it with an "
        .. "abrupt timpani stroke and a brief chord from the rest of the orchestra.","SIN p.80"},
      {"Extending the flute invisibly","Used to continue the flute's scale upward so "
        .. "\"it may appear that there is only one flute of extraordinary compass\".","SIN p.81"},
      {"Indispensable","Now that the orchestral range reaches the high C of the 7th "
        .. "octave, the piccolo \"forms an indispensable constituent of the "
        .. "wind-group\".","RK p.18"},
      {"Nickname","\"The imp, or demon, of the Orchestra, or the flash of lightning, "
        .. "or the darting flame, or the whistling wind.\"","SIN p.82"},
    }},
    {"Use sparingly", {
      {"Its low and middle register","Too weak to be of service - that is what the "
        .. "flute is for.","RK p.18"},
      {"No mute","\"It has not yet been discovered how to mute the flutes; such a "
        .. "discovery would render great service to the piccolo.\"","RK p.21"},
    }},
  },
  related={"flute","woodwind","clarinet_eb","cymbals","celesta"},
}

e{ id="altoflute", name="Alto Flute (Bass Flute)", family="Woodwind", kind="instrument",
  aliases={"alto flute","bass flute","altoflute","flute in g","alto fl"},
  summary="Rimsky-Korsakov's \"bass flute\" - the alto flute in G. \"It possesses the "
       .. "same features as the flute, but it is colder in colour, and crystalline in "
       .. "the middle and high regions.\" Seldom used even then, and valued for its own "
       .. "distinctive timbre as much as for extending the flute downward.",
  facts={{"Pitch","In F or G"}},
  sec={
    {"Pairings and doublings", {
      {"Fl / Alto flute in octaves","A same-branch pair, which \"always produce a good "
        .. "effect\".","RK p.50"},
      {"Fl + Alto fl / Cl + Bass cl","A mixed low-register octave doubling from Mlada.","RK p.51"},
      {"+ Violins","Listed with flute and piccolo among the good string/wind unison "
        .. "pairs.","RK p.58"},
    }},
    {"Use", {
      {"Exposed solo","Like the English horn and bass clarinet, it has \"its own "
        .. "distinctive peculiarities of timbre\" and is often used as a solo "
        .. "instrument, clearly exposed - not merely as an extension.","RK p.20"},
      {"Who plays it","The second or third flute, not the first.","RK p.12"},
    }},
  },
  related={"flute","woodwind","piccolo"},
}

e{ id="oboe", name="Oboe", family="Woodwind", kind="instrument",
  aliases={"oboe","oboes","ob","hautbois"},
  summary="\"Artless and gay in the major, pathetic and sad in the minor.\" First of "
       .. "all a melodic instrument, valued for tone quality rather than brilliant "
       .. "passages. Less mobile than flute and clarinet because of its double reed, "
       .. "but excellent in distinct, penetrating staccato.",
  facts={
    {"Class","Nasal and dark, with the bassoons"},
    {"Registers","Low: wild, thick and rough.  Very high: hard and dry"},
    {"Notes","Non-transposing. Can be muted - so deadened it reaches an extreme "
      .. "pianissimo, though its lowest notes become impossible"},
  },
  sec={
    {"Pairings in unison", {
      {"+ Flute","Fuller than the flute, sweeter than the oboe; flute predominates "
        .. "low, oboe in the upper register.","RK p.47"},
      {"+ Clarinet","Fuller than either alone. The dark, nasal oboe prevails low, the "
        .. "bright 'chest' clarinet high. Modern writers often warn against this "
        .. "doubling, yet many great works use it - Schubert's Unfinished has a famous "
        .. "unison clarinet-and-oboe melody, and Tchaikovsky scores it freely.","RK p.47; MOD"},
      {"+ Flute + Clarinet","Very full; flute low, oboe middle, clarinet high.","RK p.48"},
      {"+ Violins","One of the best-matched string/wind pairs.","RK p.58"},
      {"+ Violas (or with English horn)","Rimsky-Korsakov's own Violas + Ob + Eng horn.","RK p.58-59"},
      {"+ Trumpet","One of the frequent trumpet doublings; at soft dynamics oboes and "
        .. "trumpets are a standard blended pair.","RK p.56; IDIO ch.12"},
      {"+ stopped or muted Horns / Trumpets","Stopped brass approaches the oboe and "
        .. "English horn in quality, so \"the combination of these instruments produces "
        .. "a magnificent tone\".","RK p.89"},
      {"+ 1 Ob + 1 Cl instead of a trumpet","When a fanfare figure lies too high for "
        .. "the trumpets, oboes and clarinets in unison are the closest substitute \"both "
        .. "in character and power\".","RK p.98"},
    }},
    {"Doublings in octaves", {
      {"Ob / Eng horn","Same-branch octaves; \"always produce a good effect\".","RK p.50"},
      {"Fl / Ob","Natural order, flute above.","RK p.49"},
      {"Ob / Cl  ·  Ob / Fag","Natural order, oboe above.","RK p.49"},
      {"Picc / Ob","Doubling an extreme high line an octave below.","RK p.50"},
      {"2 Ob above 1 Horn","One of the standard woodwind-above-horn octave doublings.","RK p.57"},
    }},
    {"Thirds and sixths", {
      {"2 Oboes in thirds","For thirds, one colour in both parts gives the best "
        .. "equality of tone.","RK p.52"},
      {"Ob / Cl  ·  Ob / Fag  ·  Fl / Ob in sixths","Different colours suit sixths, "
        .. "kept in natural register order.","RK p.52"},
    }},
    {"Character", {
      {"Lavignac","\"The timbre is thin and nasal, very piercing in its forte "
        .. "passages, of exquisite refinement in its piano passages; harsh and of bad "
        .. "quality in its very high and very low notes. The oboe is artless and rustic "
        .. "in its expression; it is pastoral and melancholy... its natural tone is of "
        .. "a gentle sadness and a resigned endurance.\"","SIN p.85"},
      {"Berlioz","\"Candor, artless grace, soft joy, or the grief of a fragile being "
        .. "suits the oboe's accents.\" But \"care should be taken not to urge it into "
        .. "utterance of passion - a rash outburst of anger, threat, or even heroism; "
        .. "for then its small acid-sweet voice becomes uneffectual and absolutely "
        .. "grotesque.\"","SIN p.86-87"},
      {"Breathing","The player must take the lips off the reed to exhale, so long "
        .. "sustained passages need pauses - the difficulty is refilling the lungs, not "
        .. "the air supply.","SIN p.88"},
    }},
    {"Register — against the intuition", {
      {"Low is the penetrating end","\"A low oboe is far more penetrating than the same "
        .. "instrument in its highest register.\" If you want the oboe to cut through, "
        .. "the bottom of its range does it, not the top.","IDIO Dynamics and Balance"},
      {"Why","Formants - strong high-pitched peaks in its spectrum - which also make it "
        .. "one of the sharpest sounds in the orchestra. See Overtones, Formants and "
        .. "Penetration.","IDIO ch.12"},
      {"Little room to fade","A low oboe \"has very limited room for diminuendo\", "
        .. "unlike a string instrument or a low clarinet, which have almost none. Check "
        .. "any chord you have marked to die away.","IDIO Chords"},
      {"The soft alternative","Where the oboe's intensity is too much, the oboe d'amore "
        .. "has fewer high, penetrating overtones - Ravel's choice in Bolero precisely "
        .. "to avoid the oboe's intense solo sound.","IDIO Parallel Doubling"},
    }},
    {"Use sparingly", {
      {"+ Bassoon","\"Very seldom found except in certain orchestral tutti\", where it "
        .. "adds resonance without a fresh colour.","RK p.48"},
      {"Discords on like instruments","With its penetrating tone, the rule against "
        .. "giving fifths, fourths, seconds and sevenths to instruments of the same "
        .. "colour \"should be specially observed in writing for the oboe\".","RK p.72"},
      {"Oboe in the high register within a chord","Enclosing parts can leave the oboe "
        .. "\"too piercing\" - check the register of every isolated chord.","RK p.73"},
    }},

    {"In a woodwind chord", {
      {"It decides the blend","\"When writing for massed woodwinds, the oboe is the "
        .. "instrument most likely to hurt the overall blend. It will definitively color "
        .. "any combination, for better or for worse.\" The same chord scored with oboes "
        .. "is \"considerably more pungent\" - which may be exactly what you "
        .. "want.","BEL p.8"},
      {"Watch a dissonant interval in the oboe","In Belkin's comparison of woodwind "
        .. "chord layouts, the worst are those where \"the oboe's dissonant 4th sticks "
        .. "out\".","BEL p.8"},
      {"After heavy brass it will sound thin","A consequence of successive balance: "
        .. "\"after a loud, full brass passage, an oboe will sound thinner than usual, by "
        .. "contrast\".","BEL p.36"},
    }},
  },
  related={"woodwind","englishhorn","flute","clarinet","bassoon","trumpet","violin"},
}

e{ id="englishhorn", name="English Horn (Cor Anglais)", family="Woodwind", kind="instrument",
  aliases={"english horn","cor anglais","englishhorn","eng horn","eh","alto oboe",
           "cor anglais (english horn)","corno inglese"},
  summary="The alto oboe, in F. \"Similar in tone to the ordinary oboe, the listless, "
       .. "dreamy quality of its timbre being sweet in the extreme. In the low register "
       .. "it is fairly penetrating.\" Called \"an oboe in mourning\".",
  facts={
    {"Transposition","In F - written a fifth above the real sounds"},
    {"Played by","The second or third oboist; any good oboist can play it, the "
      .. "technique being practically the same"},
  },
  sec={
    {"Pairings in unison", {
      {"+ Violas","A best-matched string/wind pair; also Violas + Ob + Eng horn, and "
        .. "Violas + Ob + Eng horn in Sheherazade.","RK p.58-59"},
      {"+ ’Cellos and/or Violins","Rimsky-Korsakov's recurring recipe: 'Cellos + Violas "
        .. "+ Eng horn, and Vns I + II + 'Cellos + Eng horn - the English horn is "
        .. "absorbed into the texture while the 'cellos stand out.","RK p.39-40 & p.58-59"},
      {"+ Trombone","Listed among the brass/reed unison combinations that share the "
        .. "brass doubling characteristics.","RK p.57"},
      {"+ stopped or muted Horns / Trumpets","Stopped brass approaches the English "
        .. "horn's quality; 2 Ob + Eng horn + 3 muted trumpets is one of his own "
        .. "combinations.","RK p.89"},
      {"+ Clarinets and Bassoon","Eng horn + 2 Cl + Fag, and Eng horn + 2 Cl + Bass cl "
        .. "+ Fag, as harmonic basis.","RK p.80-81"},
    }},
    {"Doublings in octaves", {
      {"Ob / Eng horn","Same-branch octaves; always effective.","RK p.50"},
      {"Fl / Eng horn","Used repeatedly in Snegourotchka and Sadko.","RK p.49"},
      {"Cl + Ob / Cl + Eng horn","A mixed-timbre octave doubling.","RK p.50-51"},
      {"2 Ob + Eng horn / 3 stopped Horns","A striking octave pairing of reeds with "
        .. "stopped brass.","RK p.93"},
    }},
    {"Character", {
      {"Lavignac","\"Its tone is essentially sad, melancholy, sorrowful. The cor "
        .. "anglais exactly suits the expression of mental suffering.\"","SIN p.89"},
      {"Berlioz","\"A melancholy, dreamy, and rather noble voice, of which the "
        .. "sonorousness has something vague and remote about it which renders it "
        .. "superior to all others in exciting regret and reviving images and "
        .. "sentiments of the past.\" Where melancholy prevails, \"the frequent use of "
        .. "the cor anglais hidden in the midst of the great mass of instruments is "
        .. "perfectly suited\".","SIN p.89"},
      {"Its limits","Berlioz: less able than the oboe to give rustic gaiety, and "
        .. "\"accents of keen grief are almost beyond its powers\".","SIN p.89"},
      {"With a voice","A solo English horn accompanying a contralto is one of "
        .. "Rimsky-Korsakov's named pairings for characterisation.","RK p.124"},
      {"The famous solo","Act III of Tristan und Isolde - the shepherd's long sad "
        .. "melody given to \"the saddest voice in the orchestra\".","SIN p.90"},
    }},
  },
  related={"oboe","woodwind","viola","cello","horn","bassclarinet"},
}

e{ id="clarinet", name="Clarinet", family="Woodwind", kind="instrument",
  aliases={"clarinet","clarinets","cl","clarinette","klarinette","b flat clarinet",
           "a clarinet"},
  summary="\"Pliable and expressive, suitable, in the major, to melodies of a joyful "
       .. "or contemplative character, or to outbursts of mirth; in the minor, to sad "
       .. "and reflective melodies or impassioned and dramatic passages.\" For "
       .. "expressive power and subtlety of nuance it surpasses even the flute - \"this "
       .. "instrument can reduce volume of tone to a mere breath\".",
  facts={
    {"Class","Bright 'chest-voice' quality, with the flutes"},
    {"Registers","Four, clearly defined: chalumeau (deepest), medium (warm and "
      .. "expressive), high (brilliant and energetic), very high (biting and strident)"},
    {"Transposition","In B-flat or A"},
    {"Mute","Unnecessary - \"they can play quite softly enough without artificial means\""},
  },
  sec={
    {"Pairings in unison", {
      {"+ Bassoon","Very full. The clarinet's gloom prevails in the lower register, "
        .. "the bassoon's thinner quality higher.","RK p.48"},
      {"+ Flute","Fuller than the flute, duller than the clarinet. In the clarino "
        .. "register the two have a special affinity, and their combined resonance in "
        .. "octaves turns almost organ-like.","RK p.47; MOD"},
      {"+ Oboe","Fuller than either alone; oboe prevails low, clarinet high. Often "
        .. "warned against in modern teaching, but used by Schubert (the Unfinished) and "
        .. "freely by Tchaikovsky - and clarinets \"interlock quite well with "
        .. "middle-register oboes\".","RK p.47; MOD"},
      {"+ Flute + Oboe","Very full; clarinet on top of the register scheme.","RK p.48"},
      {"+ Violins","One of the best-matched string/wind pairs; also with the E-flat "
        .. "clarinet.","RK p.58"},
      {"+ Violas","Especially the clarinet's low register - the viola's timbre is "
        .. "comparable to the clarinet's lowest compass, making this a standard blended "
        .. "doubling in modern practice too.","RK p.58 & p.35-36; IDIO ch.12"},
      {"+ ’Cellos","With bass clarinet as the darker alternative.","RK p.58"},
      {"+ Trumpet","\"The trumpet is the instrument most frequently doubled\", and "
        .. "Trumpet + Cl heads Rimsky-Korsakov's list; also Trumpet + Cl + Ob + Fl.","RK p.56"},
      {"+ Horn","Horn + Cl is the commonest horn/woodwind doubling; also 2 or 3 Horns "
        .. "+ the same number of clarinets as a chord block.","RK p.57 & p.88"},
      {"+ stopped Horns (low clarinet notes)","\"A beautiful dark tone is derived from "
        .. "the combination of middle notes in stopped horns and deep notes in the "
        .. "clarinet.\" Substituting bassoons loses part of the character.","RK p.89"},
      {"+ 1 Ob + 1 Cl instead of a trumpet","When a fanfare lies too high for the "
        .. "trumpets, oboes and clarinets in unison come closest in character and power.","RK p.98"},
    }},
    {"Doublings in octaves", {
      {"Cl / Bass clarinet","Same-branch octaves; \"always produce a good effect\".","RK p.50"},
      {"E-flat clarinet / Cl","As above, upward.","RK p.50"},
      {"Fl / Cl  ·  Ob / Cl","Natural order, clarinet below.","RK p.49"},
      {"Cl / Fag","Natural order, clarinet above - a very common pairing.","RK p.49"},
      {"Cl / Bass cl / C-Fag","Three-octave low doubling.","RK p.51"},
      {"Cl / Fag  or  Cl / Bass cl","To double an extreme low line an octave higher.","RK p.50"},
      {"2 Cl above 1 Horn","One of the standard woodwind-above-horn octave doublings; "
        .. "2 Fl + 2 Cl above 2 Horns for forte.","RK p.57"},
      {"2 Cl / ’Cellos + 2 Horns","A mixed octave doubling from Sheherazade.","RK p.60"},
    }},
    {"Thirds and sixths", {
      {"2 Clarinets in thirds","One colour gives the best equality of tone in thirds.","RK p.52"},
      {"Cl / Fag in sixths","Different colours suit sixths, in natural register order.","RK p.52"},
    }},
    {"Character", {
      {"Lavignac","\"One of the most beautiful voices in the orchestra... the richest "
        .. "in varied timbres of all the wind instruments. Almost as agile as the flute, "
        .. "as tender as, and more passionate than, the oboe, the clarinet is infinitely "
        .. "more energetic and richer in color.\"","SIN p.96-97"},
      {"Berlioz","\"It is an epic instrument, like horns, trumpets and trombones. The "
        .. "voice is like that of heroic love.\" And: \"It is the one of all the wind "
        .. "instruments which can best breathe forth, swell, diminish and die away. "
        .. "Thence the precious faculty of producing distance, echo, the echo of echo, "
        .. "and a twilight sound.\"","SIN p.99-100"},
      {"Diminuendo specialist","\"Clarinets specialise in diminuendo effects and are "
        .. "capable of decreasing their tone to a breath (morendo).\"","RK p.112"},
      {"Low register","Ringing and threatening; Weber was the first \"to discover all "
        .. "that there is of the terrible in the quality of tone of these low sounds\".","RK p.17; SIN p.100"},
      {"With a voice","Listed among the solo instruments that accompany a cantabile "
        .. "aria beautifully.","RK p.124"},
    }},
    {"High clarinets in unison", {
      {"The effect","Two or more clarinets in the high or highest register in perfect "
        .. "unison give a \"very characteristic, stridently penetrating sound\" - a "
        .. "reminder that etymologically clarinet means \"little trumpet\". Mahler, "
        .. "Stravinsky and Debussy all use it, and it is \"very impressive when used "
        .. "with clear intent\".","IDIO ch.12"},
      {"The opposite end of the same instrument","The weak middle-register \"filling "
        .. "in\" notes have so few overtones that they blend into anything - which is "
        .. "what makes them useful for mixture. Same instrument, opposite job.",
        "IDIO ch.12"},
    }},
    {"Use sparingly", {
      {"Octave leaps","\"On account of its construction the clarinet is not well "
        .. "adapted to sudden leaps from one octave to another.\"","RK p.20"},
      {"In a 4-way tutti mix","In Bassoon + Clarinet + Oboe + Flute the clarinet, weak "
        .. "in the middle compass, \"will not stand out prominently\".","RK p.48"},
      {"2 Clarinets in octaves","\"Certainly not to be recommended\" unless strings "
        .. "double both parts.","RK p.49-50"},
      {"Inside the horns","\"On account of their tone quality\" clarinets should rarely "
        .. "be set inside a horn chord - though in the upper register they may complete "
        .. "one as well as oboes or flutes.","RK p.92"},
      {"Doubling for a singer","Two clarinets in unison forming one harmonic part is "
        .. "among the combinations to avoid when accompanying a voice.","RK p.121"},
    }},
  },
  related={"woodwind","bassclarinet","clarinet_eb","flute","oboe","bassoon","horn","viola"},
}

e{ id="clarinet_eb", name="E-flat Clarinet (Small Clarinet)", family="Woodwind", kind="instrument",
  aliases={"e flat clarinet","eb clarinet","small clarinet","piccolo clarinet",
           "d clarinet","sopranino clarinet","clarinet_eb"},
  summary="Extends the clarinet upward. \"The small clarinet in its highest register is "
       .. "more penetrating than the ordinary clarinet.\" Rarely employed, and only for "
       .. "colour effects.",
  facts={{"Transposition","In E-flat or D"}},
  sec={
    {"Pairings and doublings", {
      {"E-flat cl / Cl in octaves","Same-branch octaves; always good.","RK p.50"},
      {"Picc / E-flat cl in octaves","The two most piercing instruments together, for "
        .. "deliberately shrill colour.","RK p.50"},
      {"+ Violins","Listed with the clarinet among good string/wind unison pairs.","RK p.58"},
      {"+ 2 Vns + Flute","In The Christmas Night, 2 Vns + Fl + small Cl doubling a solo "
        .. "line.","RK p.105"},
    }},
    {"Use", {
      {"Rare by design","\"The small clarinet is rarely employed and only for colour "
        .. "effects.\" Its low and middle range is much weaker than the ordinary "
        .. "clarinet's and of little service.","RK p.18"},
      {"Who plays it","The second clarinet.","RK p.12"},
      {"On stage","One of the instruments Rimsky-Korsakov specifies for the wings - "
        .. "small clarinets and piccolos in Mlada; Serov used the E-flat clarinet to "
        .. "imitate a fife in a carnival procession.","RK p.130-131"},
    }},
  },
  related={"clarinet","woodwind","piccolo"},
}

e{ id="bassclarinet", name="Bass Clarinet", family="Woodwind", kind="instrument",
  aliases={"bass clarinet","bassclarinet","bass cl","bcl","contrabass clarinet",
           "pedal clarinet"},
  summary="\"Though strongly resembling the ordinary clarinet, it is of darker colour "
       .. "in the low register and lacks the silvery quality in the upper notes; it is "
       .. "incapable of joyful expression.\" Like the English horn and alto flute, it "
       .. "has its own distinctive timbre and is often used as an exposed solo.",
  facts={
    {"Transposition","In B-flat or A"},
    {"Played by","The second or third clarinet (a dedicated fourth player when the "
      .. "wind is in fours)"},
  },
  sec={
    {"Pairings in unison", {
      {"+ ’Cellos","One of the best-matched string/wind pairs in the low register.","RK p.58"},
      {"+ D. basses","For the bottom of the orchestra, with bassoon and contrabassoon.","RK p.58"},
      {"+ 3 Trombones","One of Rimsky-Korsakov's own low-brass/reed combinations "
        .. "(Mlada); also Trombone + Bass cl.","RK p.57"},
      {"+ Horn","Bass cl + Horn / D. basses + C-Fag + Tuba in Ivan the Terrible.","RK p.62"},
      {"+ Clarinets (harmony)","2 Cl + Bass cl is a recurring three-part harmonic "
        .. "basis; also Cl + Bass cl + Fag + C-Fag.","RK p.80-81"},
      {"+ solo ’cello","'Cello + Bass cl as a doubled solo line, and Bass cl + C-Fag "
        .. "doubling a solo double bass.","RK p.105"},
    }},
    {"Doublings in octaves", {
      {"Cl / Bass clarinet","Same-branch octaves; always good.","RK p.50"},
      {"Bass cl / Fag  ·  Cl / Bass cl","To double an extremely low line an octave "
        .. "higher.","RK p.50"},
      {"2 Cl / Bass cl / C-Fag","A three-octave low doubling from Kitesh.","RK p.51"},
      {"Fl + Alto fl / Cl + Bass cl","Mixed-timbre octaves in the low register.","RK p.51"},
      {"Trombone + Bass cl / Tuba + C-Fag","Mixed wood-and-brass octaves.","RK p.58"},
    }},
    {"Use", {
      {"Widely-divided three-part harmony","Three instruments of one timbre sound "
        .. "inferior in widely-divided three-part harmony - unless the third is a "
        .. "low-register instrument such as the bass clarinet, alto flute, English horn "
        .. "or contrabassoon, when \"the resonance will be satisfactory\".","RK p.75-76"},
      {"With a voice","Among the solo instruments listed for accompanying a cantabile "
        .. "aria; Rimsky-Korsakov pairs a baritone with bass clarinet.","RK p.124"},
      {"Modern users","\"Wagner uses it a great deal\"; conspicuous in the Danse de la "
        .. "Fee Dragee of Tchaikovsky's Nutcracker and in Strauss's Don Quixote.","SIN p.101"},
      {"Its double","\"The bass-clarinet is doubled by the contrabass clarinet\", an "
        .. "octave below - a rival to the contrabassoon.","SIN p.101-102"},
    }},
  },
  related={"clarinet","woodwind","bassoon","contrabassoon","cello","doublebass","trombone"},
}

e{ id="bassoon", name="Bassoon", family="Woodwind", kind="instrument",
  aliases={"bassoon","bassoons","fagotto","fagott","fag","bsn","bn"},
  summary="\"In the major, an atmosphere of senile mockery; a sad, ailing quality in "
       .. "the minor.\" The bass of the oboe group, and - with the horn - one of the two "
       .. "instruments that reconcile the woodwind and brass. Increasingly used as a "
       .. "tenor or even alto voice, doubling the high 'cello or the low viola.",
  facts={
    {"Class","Nasal and dark, with the oboes"},
    {"Registers","Low: sinister, \"solemn and pontifical, like an organ pedal\".  "
      .. "Very high: tense, the sweet \"vox humana notes\""},
    {"Notes","Non-transposing; bass and tenor clefs. Can be muted, though its lowest "
      .. "notes then become impossible"},
  },
  sec={
    {"Pairings in unison", {
      {"+ Clarinet","Very full. The clarinet's gloom prevails low, the bassoon's "
        .. "thinner quality higher. The one woodwind pairing with the bassoon that "
        .. "Rimsky-Korsakov recommends outright.","RK p.48"},
      {"+ ’Cellos","One of the best-matched string/wind pairs; bassoons added to 'cello "
        .. "and bass parts clarify and reinforce them.","RK p.58; MOD"},
      {"+ Violas","The viola's timbre is comparable to the bassoon's middle register; "
        .. "Tchaikovsky's Marche Slave uses the two together \"very effectively\".","RK p.58 & p.35-36; SIN p.97"},
      {"+ D. basses","With contrabassoon and bass clarinet, the bass reinforcement.","RK p.58"},
      {"+ Horn","Horn + Fag - the bridge doubling. \"The middle notes resemble those of "
        .. "the bassoon and the two instruments blend well together.\" In the middle "
        .. "register this gives a slimmer, more focused horn sound.","RK p.57 & p.24; IDIO ch.12"},
      {"+ Trombone or Tuba","Trombone + Fag and Tuba + Fag; the bassoon is also the "
        .. "usual instrument for doubling a brass bass in octaves, in place of the "
        .. "too-resonant trombone or tuba.","RK p.57 & p.82"},
      {"+ 2 Fag + 3 Trombones + Tuba + ’Cellos/D. basses","The standard bass grouping "
        .. "of all three orchestral groups.","RK p.61"},
      {"+ string pizzicato","One of the standard blended pairs - close enough in colour that the combination reads as a single sound.","IDIO ch.12"},
      {"+ ’Cellos + D. basses (thickened)","One bassoon added to the string bass only "
        .. "thickens it; the bassoon timbre is lost.","RK p.34"},
    }},
    {"Doublings in octaves", {
      {"Fag / Contrabassoon","Same-branch octaves; always good.","RK p.50"},
      {"Ob / Fag  ·  Cl / Fag","Natural order, bassoon below - very common.","RK p.49"},
      {"Fag / C-Fag  ·  Bass cl / Fag  ·  Cl / Fag","To double an extremely low line an "
        .. "octave higher.","RK p.50"},
      {"’Cellos + Fag / D. basses","For a sweet, soft low melody, the basses undoubled.","RK p.60"},
      {"Violas + Fag / ’Cellos + Fag / D. basses","A three-octave low scheme from Tsar "
        .. "Saltan.","RK p.60"},
    }},
    {"In harmony — the bridge", {
      {"2 Bassoons + 2 Horns","\"The bassoon and horn are the two instruments best "
        .. "capable of reconciling the groups of wood-wind and brass.\" Four-part "
        .. "harmony on this quartet yields a finely balanced tone recalling a horn "
        .. "quartet but slightly more transparent - in soft passages.","RK p.90"},
      {"Cross the parts","Give the concords to the horns and the discords to the "
        .. "bassoons. Bassoons may be written inside the horns, but not the reverse.","RK p.90-91"},
      {"Doubling the brass bass","When a brass chord's bass needs doubling in octaves, "
        .. "the duplication \"is effected by the bassoon\" rather than by trombone or "
        .. "tuba.","RK p.82"},
      {"2 Fag as the bass","A frequent role in mixed-timbre woodwind chords.","RK p.80"},
    }},
    {"Character", {
      {"Lavignac","\"Its lowest tones are solemn and pontifical, like an organ pedal. "
        .. "Its medium register has a sweet sonority of some richness but little "
        .. "strength; and its high register has the most expression, but is painful, "
        .. "distressed and dejected. At the same time this instrument has comic "
        .. "possibilities.\"","SIN p.95"},
      {"As tenor","\"It has gradually risen to the position of a tenor, or even alto, "
        .. "frequently doubling the high notes of the violoncello, or the lower register "
        .. "of the viola\" - the extreme high notes are the \"vox humana notes\" (Stone).","SIN p.95-96"},
      {"Comic and rustic","Mendelssohn's two bassoons lead the Clown's March in thirds "
        .. "in the Midsummer Night's Dream music, and imitate a small country band with "
        .. "clarinet in the Funeral March.","SIN p.97"},
      {"Staccato","With the oboe, best suited to distinct and penetrating staccato.","RK p.19"},
      {"With a voice","Listed among the solo instruments that accompany a cantabile "
        .. "aria; bassoons also double men's voices well.","RK p.124 & p.122"},
    }},
    {"Berlioz on writing the parts", {
      {"Four bassoons, three parts","Bassoons are normally written in two parts, but a "
        .. "large orchestra has four. Berlioz's preference is not four real parts but "
        .. "three, with the lowest doubled an octave below, which puts the extra weight "
        .. "where it does most good - on the bass line.","BERL The bassoon"},
      {"The top of the range has a character","He describes the upper notes as pained, "
        .. "suffering, close to pitiful - and says that is exactly why they work in a "
        .. "slow melody or an accompanying figure, used deliberately.","BERL The bassoon"},
    }},
    {"Use sparingly", {
      {"+ Oboe or Flute in unison","\"Very seldom found except in certain orchestral "
        .. "tutti\", where they produce increased resonance \"without creating a fresh "
        .. "atmosphere\". The same applies to Fag+Cl+Ob and Fag+Cl+Fl, and all four "
        .. "together is \"equally rare\".","RK p.48"},
      {"Flute + Bassoon in octaves","Rare - the registers lie too far apart.","RK p.49"},
      {"Above the clarinets or oboes","Placing bassoons above clarinets and oboes "
        .. "inverts the natural order and \"creates an unnatural resonance occasioned by "
        .. "the confusion of registers\".","RK p.49 & p.46"},
      {"2 Bassoons in octaves","Not recommended unless strings double both parts.","RK p.49-50"},
      {"Against 4 forte horns","In forte the horns overwhelm the bassoons - \"it is "
        .. "wiser to employ four horns alone\".","RK p.90"},
      {"Substituted for clarinet under stopped horns","Loses part of the character of "
        .. "that dark combination.","RK p.89"},
    }},
  },
  related={"woodwind","contrabassoon","oboe","clarinet","horn","cello","doublebass","wind_brass"},
}

e{ id="contrabassoon", name="Contrabassoon", family="Woodwind", kind="instrument",
  aliases={"contrabassoon","contra bassoon","double bassoon","double-bassoon","c-fag",
           "contrafagotto","cbn","contra"},
  summary="Extends the bassoon downward an octave. \"The very deep notes of the double "
       .. "bassoon are remarkably thick and dense in quality, very powerful in piano "
       .. "passages.\" With the piccolo, it is one of the two instruments that have no "
       .. "\"scope of greatest expression\" - highly coloured, but not expressive.",
  facts={
    {"Notation","Written an octave higher than it sounds"},
    {"Reach","Down to the 16-foot C"},
  },
  sec={
    {"Pairings and doublings", {
      {"Fag / C-Fag in octaves","Same-branch octaves; always good, and the standard way "
        .. "to extend the bassoon down.","RK p.50"},
      {"+ D. basses","\"Like the double bass and double bassoon, the tuba is eminently "
        .. "useful for doubling, an octave lower, the bass of the group to which it "
        .. "belongs\" - the contrabassoon does the same job for the woodwind.","RK p.58 & p.24"},
      {"’Cellos + Bass cl / D. basses + C-Fag","A fully reinforced low octave.","RK p.59"},
      {"+ Tuba (+ D. basses)","Tuba + C-Fag / D. basses in Ivan the Terrible.","RK p.62"},
      {"Doubled an octave up","By bassoon, clarinet or bass clarinet - always double a "
        .. "melody lying in the extreme low compass an octave higher.","RK p.50"},
      {"+ solo double bass","The contrabassoon doubling a double-bass solo is one of "
        .. "the rare ways to give that instrument a line.","RK p.38 & p.105"},
      {"In widely-divided three-part harmony","As the low member of three instruments "
        .. "of one timbre, it makes the resonance satisfactory where it would otherwise "
        .. "be poor.","RK p.75-76"},
    }},
    {"Use", {
      {"Its middle and top","\"By no means so useful\" as the low register - use it for "
        .. "the bottom.","RK p.18"},
      {"Historically","Neglected after Beethoven's death, it reappeared towards the end "
        .. "of the 19th century and is \"capable of supplying valuable assistance\".","RK p.18"},
    }},
  },
  related={"bassoon","woodwind","doublebass","tuba","bassclarinet"},
}

-- ============================================================================
-- BRASS
-- ============================================================================

e{ id="horn", name="Horn", family="Brass", kind="instrument",
  aliases={"horn","horns","french horn","french horns","hn","hns","cor","waldhorn",
           "corno","f horn"},
  summary="\"The tone of this instrument is soft, poetical, and full of beauty. In the "
       .. "lower register it is dark and brilliant; round and full in the upper. The "
       .. "middle notes resemble those of the bassoon and the two instruments blend well "
       .. "together. The horn, therefore, serves as a link between the brass and "
       .. "wood-wind.\" It doubles with almost anything.",
  facts={
    {"Transposition","In F"},
    {"Strength","Half as strong as trumpet, trombone or tuba in forte; equal to them "
      .. "in piano. Two horns balance one trumpet or trombone"},
    {"Marking","Mark the horns one degree louder than the rest of the brass"},
    {"Four-part convention","Horns 1 and 3 take the high parts, 2 and 4 the low; 1 the "
      .. "highest, 4 the lowest"},
  },
  sec={
    {"Pairings in unison", {
      {"4 Horns","Frequently met with; the standard way to give the group melodic "
        .. "weight. Also 4 Horns + 2 Trumpets, and 6 Horns in Mlada.","RK p.55"},
      {"+ ’Cellos","\"Frequently employed, produces a beautifully blended, soft quality "
        .. "of tone\" - the one string/brass combination Rimsky-Korsakov singles out for "
        .. "praise, and a standard blended pair today.","RK p.61; IDIO ch.12"},
      {"+ Violas","The best-matched string/brass pair by register; muted violas with "
        .. "horn is a favourite effect.","RK p.61"},
      {"+ Bassoon","The bridge doubling - the two blend well, and in the middle "
        .. "register this gives a slimmer, more focused horn sound.","RK p.57 & p.24; IDIO ch.12"},
      {"+ Clarinet","Horn + Cl is the commonest horn/woodwind doubling; also 2-3 Horns "
        .. "with the same number of clarinets as a chord block, or 2 Horns + 2 Fag + 2 Cl.","RK p.57 & p.88"},
      {"+ Clarinet (or Eng. horn) + Violas or ’Cellos","The standard alto-tenor grouping "
        .. "of all three orchestral groups.","RK p.61"},
      {"Divided violas or ’cellos","\"The splendid effect of horns doubled by divided "
        .. "violas or 'cellos\" - the exception worth seeking in string/brass harmony.","RK p.95"},
      {"Stopped horns + Clarinet (low notes)","\"A beautiful dark tone.\" Substituting "
        .. "bassoons loses part of the character.","RK p.89"},
      {"Stopped horns + Oboe / English horn","Stopped and muted horns resemble the oboe "
        .. "and English horn, so the three may share one chord played p or sfp.","RK p.93"},
    }},
    {"Doublings in octaves", {
      {"Trumpet / 2 Horns","The normal-register brass octave pairing.","RK p.56"},
      {"2 Horns / Tuba","As above, at the bottom.","RK p.56"},
      {"2 Ob or 2 Cl or 2 Fl / 1 Horn","Woodwind above one horn - this often replaces "
        .. "1 Trumpet / 1 Horn when you want an upper octave richer than the trumpet can "
        .. "give. Also 1 Ob + 1 Cl / 1 Horn.","RK p.57"},
      {"2 Fl + 2 Cl / 2 Horns","With two horns in unison below, you need three or four "
        .. "wind instruments above, especially in forte.","RK p.57"},
      {"2 Horns / 1 Trombone  ·  4 Horns / 2 Trombones","Horns above trombones, "
        .. "exclusively in octaves - \"possible, though not so reliable\".","RK p.56"},
      {"2 Cl / ’Cellos + 2 Horns","A mixed string/wind/brass octave doubling.","RK p.60"},
      {"2 Ob + Eng horn / 3 stopped Horns","Reeds above stopped brass.","RK p.93"},
    }},
    {"Writing the parts", {
      {"High and low alternate","Horns 1 and 3 take the high parts, 2 and 4 the low, "
        .. "with 1 the highest and 4 the lowest. Write to that convention and the "
        .. "section can read it without negotiation.","HUG Brass Section; cf. RK p.24"},
      {"The bumper","\"A fifth horn may well be used even when only four are required "
        .. "by the score, to cover the less important passages in the Horn 1 part, "
        .. "allowing the principal to concentrate on important solos.\" You do not "
        .. "write for this player; the section arranges it. But it explains why a "
        .. "demanding first-horn part is less unreasonable than it looks.",
        "HUG Brass Section"},
      {"Weaker than the rest of the brass","Horns \"generally have a weaker sound than "
        .. "the other brass\", which is why they are so often grouped with the woodwind "
        .. "rather than against it.","HUG Brass Section; cf. RK p.33"},
    }},
    {"In harmony", {
      {"The horn quartet","4 Horns give \"every facility for four-part harmony, "
        .. "perfectly balanced in tone, without doubling the bass in octaves\" - the "
        .. "single most reliable brass chord in the orchestra.","RK p.82"},
      {"As background harmony","\"A quartet of horns will be very effective and "
        .. "unobtrusive when carrying the harmonic background to a passage\" - the "
        .. "quality that makes it the default choice for sustained inner harmony.",
        "HUG Brass Section"},
      {"2 Horns + Tuba + 3 Trombones","2 horns and tuba take the bass in octaves, the "
        .. "trombones the three upper parts: \"beautiful full resonance\".","RK p.83"},
      {"As the 4th part","With 3 trumpets, give the fourth part to one trombone or two "
        .. "horns in unison; with 2 trumpets on the upper parts, complete the chord with "
        .. "two trombones or four horns in pairs.","RK p.83"},
      {"Always double the horns when mixing","\"If the instruments are mixed the number "
        .. "of horns should be doubled\", and when the whole brass group plays.","RK p.84"},
      {"Softening the others","A horn chord placed beside the same chord on trumpets or "
        .. "trombones intensifies the tone and moderates their penetrating timbre.","RK p.85"},
      {"Completed by woodwind","In the upper register a piano chord of four horns may be "
        .. "completed by clarinets as effectively as by oboes or flutes, with a bassoon "
        .. "doubling the bass an octave below.","RK p.92"},
      {"With only 2 trumpets","The horns then cannot proceed in pairs; mark them one "
        .. "degree louder than the other instruments to secure balance.","RK p.85"},
      {"In widely-divided chords","The horns' register need not be doubled - lay the "
        .. "chord out like a chorale for double or triple choir.","RK p.85"},
    }},
    {"Character", {
      {"Lavignac","\"It is heroic or rustic; savage or exquisitely poetic; and it is, "
        .. "perhaps, in the expression of tenderness and emotion that it best develops "
        .. "its mysterious qualities.\"","SIN p.108"},
      {"Berlioz","\"A noble and melancholy instrument. It blends easily with the general "
        .. "harmony.\" No one used it better than Weber, who \"causes the horn to speak a "
        .. "language as admirable as it is novel\".","SIN p.105"},
      {"Piano melodies","\"The genial and poetic tone of the horn in piano passages "
        .. "affords greater scope in the choice of melodies and phrases that may be "
        .. "entrusted to this instrument.\"","RK p.54"},
      {"Mobility","\"In spite of valves the horn has but little mobility and would seem "
        .. "to produce its tone in a languid and lazy manner.\"","RK p.24"},
      {"Never singly","\"In the Orchestra the horn is seldom played singly. A pair of "
        .. "horns, or four horns (two pairs), are usually employed.\"","SIN p.109"},
      {"Fanfares","With the trumpet, the natural home of fanfare and flourish figures; "
        .. "if a fanfare lies too low for the trumpets, give it to the horns.","RK p.53-54 & p.98"},
      {"Doubling voices","One of the instruments that double men's voices naturally, and "
        .. "listed for accompanying a cantabile aria.","RK p.122 & p.124"},
      {"Muted","Produces an effect of distance and \"a dreamy effect\"; single notes are "
        .. "stopped in short phrases, muted in longer ones.","RK p.25; SIN p.107"},
    }},
    {"Use sparingly", {
      {"Clarinets inside a horn chord","Rarely - the tone quality does not suit.","RK p.92"},
      {"Against bassoons in forte","The horns overwhelm them; use four horns alone.","RK p.90"},
      {"Doubling a singer with 2 horns in unison","Among the combinations to avoid when "
        .. "accompanying the voice.","RK p.121"},
      {"Mezzo-forte re-entry","After a long rest, bring the horns back at pp or ff - "
        .. "mf or mp \"produces a colourless and common-place effect\".","RK p.118"},
    }},
  },
  related={"brass","trumpet","trombone","tuba","bassoon","clarinet","cello","viola",
           "wind_brass","blend"},
}

e{ id="trumpet", name="Trumpet", family="Brass", kind="instrument",
  aliases={"trumpet","trumpets","tpt","tpts","tromba","clarino","alto trumpet",
           "small trumpet","bass trumpet"},
  summary="\"Clear and fairly penetrating in tone, stirring and rousing in forte "
       .. "passages; in piano phrases the high notes are full and silvery, the low notes "
       .. "troubled, as though threatening danger.\" The brass instrument most frequently "
       .. "doubled by the woodwind.",
  facts={
    {"Transposition","In B-flat or A (alto trumpet in F; small trumpet in E-flat or D)"},
    {"Strength","1 Trumpet = 1 Trombone = 1 Tuba = 2 Horns in forte"},
    {"Agility","With the cornet, one of the only brass that can double-tongue and play "
      .. "rapid tremolando"},
  },
  sec={
    {"Pairings in unison", {
      {"+ Clarinet","\"The trumpet is the instrument most frequently doubled: Trumpet + "
        .. "Cl., Trumpet + Ob., Trumpet + Fl., as well as Trumpet + Cl. + Ob. + Fl.\" "
        .. "Instances are numerous, especially in forte, and the wind gives a finer "
        .. "legato than the brass alone.","RK p.56-57"},
      {"+ Oboe","As above; at soft dynamics oboes and trumpets are a standard blended "
        .. "pair in modern practice.","RK p.56; IDIO ch.12"},
      {"+ Flute","As above.","RK p.56"},
      {"2 or 3 Trumpets + 2 or 3 Fl / Ob / Cl","Chord blocks in unison: 2 Trumpets + 2 "
        .. "Fl, 3 Trumpets + 3 Cl, and so on.","RK p.88"},
      {"1, 2 or 3 Trumpets in unison","The standard fanfare reinforcement; also 4 Horns "
        .. "+ 2 Trumpets.","RK p.55"},
      {"+ Violins","The best-matched string/brass pair by register - though the two are "
        .. "always heard distinctly.","RK p.61"},
      {"+ Violins + Oboe (or Fl, Cl)","The standard soprano grouping of all three "
        .. "orchestral groups.","RK p.61"},
      {"Muted trumpets + Oboes / English horn","Stopped and muted trumpets resemble the "
        .. "oboe and English horn: \"the combination of these instruments produces a "
        .. "magnificent tone\". 2 Ob + Eng horn + 3 muted trumpets is one of his own.","RK p.89"},
      {"Alto trumpet with 2 ordinary trumpets","\"Two ordinary trumpets with an alto "
        .. "trumpet produce greater smoothness and equality in resonance than three "
        .. "ordinary trumpets.\"","RK p.23"},
    }},
    {"Doublings in octaves", {
      {"Trumpet / 2 Horns","The normal-register brass pairing.","RK p.56"},
      {"Trumpet / Trombone","As above.","RK p.56"},
      {"2 Trumpets / 2 Trombones","As above, doubled.","RK p.56"},
      {"Trumpet / Trumpet","Used directly in Sadko.","RK p.56"},
      {"3–4 wind above a trumpet","To double a trumpet an octave up you need three or "
        .. "four wind instruments - but in the top register two flutes will suffice.","RK p.58"},
      {"Woodwind above, not below","If trumpets and trombones take part in a chord, put "
        .. "flutes, oboes and clarinets in the harmonic part above the trumpets.","RK p.93"},
      {"Flute thirds between trumpet octaves","In soft passages, thirds in the low "
        .. "flutes, sometimes with clarinets, between trumpets an octave apart - \"a "
        .. "beautiful mysterious effect\".","RK p.91"},
    }},
    {"Quiet trumpets", {
      {"Against the routine","Berlioz notes that despite the convention of using "
        .. "trumpets loudly, delightful effects come from them played piano, and credits "
        .. "Gluck with showing it first - the two trumpets holding the dominant in "
        .. "unison in the introduction to Iphigenie en Tauride. Beethoven (the slow "
        .. "movement of the Seventh) and Weber follow him.","BERL The trumpet"},
    }},
    {"Character and use", {
      {"Lavignac","\"A stately and heraldic instrument\" - \"of great agility, the "
        .. "trumpet is admirably suited to rapid figures, arpeggios and especially to "
        .. "repetitions of notes. Besides noisy fanfares and strident calls, it is able "
        .. "to produce in piano, or pianissimo, effects either fantastic, or of extreme "
        .. "sweetness.\"","SIN p.109-111"},
      {"Berlioz","\"The quality of the trumpet tone is noble and brilliant. It suits "
        .. "with warlike ideas, with cries of fury and vengeance, as with songs of "
        .. "triumph... It may even figure in a jocund piece, provided the joy assume a "
        .. "character of pomp and grandeur.\"","SIN p.111"},
      {"Fanfares","Fanfares and flourishes \"fall specially to the lot of the trumpets "
        .. "and horns\", using the clear, ringing middle and upper registers.","RK p.53-54"},
      {"When it is too high or too low","Too low for the trumpets, give it to the horns; "
        .. "too high, give it to oboes and clarinets in unison, \"this combination "
        .. "possessing the closest resemblance to the trumpet tone both in character and "
        .. "power\".","RK p.98"},
      {"As an echo","\"Muted trumpets are eminently suited to echo a theme in the oboes.\"","RK p.110"},
      {"Sustained notes","The tenuto in two or three octaves is generally given to two "
        .. "trumpets, or two or four horns; the octave is sometimes formed by trumpets and "
        .. "horns acting together.","RK p.86"},
      {"On stage","Trumpets are among the instruments Rimsky-Korsakov specifies for the "
        .. "wings.","RK p.129"},
    }},
    {"Use sparingly", {
      {"+ trombones side by side","Juxtaposing trumpet and trombone chords \"is not so "
        .. "common, as this unites the two most powerful agents in the group\".","RK p.85"},
      {"Doubling the voice","\"Trombones and trumpets overpower the voice and cannot be "
        .. "used for this purpose.\"","RK p.122"},
      {"Stopped notes","On the trumpet, muting gives a better tone than stopping.","RK p.25"},
      {"Mezzo-forte re-entry","After a long rest, return at pp or ff.","RK p.118"},
    }},
  },
  related={"brass","horn","trombone","cornet","clarinet","oboe","violin","wind_brass"},
}

e{ id="cornet", name="Cornet", family="Brass", kind="instrument",
  aliases={"cornet","cornets","cornett","corneta","cornet a pistons"},
  summary="\"Possessing a quality of tone similar to the trumpet, but softer and "
       .. "weaker. It is a beautiful instrument though rarely employed today in theatre "
       .. "or concert room. Expert players can imitate the cornet tone on the trumpet, "
       .. "and vice versa.\"",
  facts={
    {"Transposition","In B-flat or A"},
    {"Strength","Slightly less than trumpet, trombone or tuba"},
  },
  sec={
    {"Use", {
      {"In place of trumpets","When the woodwind is in threes, the brass may be 2 "
        .. "Cornets + 2 Trumpets instead of 3 trumpets.","RK p.22"},
      {"Stopped notes and double tonguing","Possible, as on the trumpet - small "
        .. "mouthpiece instruments can double-tongue and play rapid tremolando.","RK p.25 & p.24"},
      {"On stage","Listed among the instruments for the wings.","RK p.130"},
      {"Ancestry","Singleton traces the tuba's line back through the ophicleide and "
        .. "serpent to \"the rather commonplace and blatant Cornet Family\"; the cornet "
        .. "is \"nothing more nor less than a bugle, a development of the old post-horn\".","SIN p.116-117"},
    }},
  },
  related={"trumpet","brass","tuba"},
}

e{ id="trombone", name="Trombone", family="Brass", kind="instrument",
  aliases={"trombone","trombones","tbn","posaune","sackbut","bass trombone",
           "tenor trombone","alto trombone","trb"},
  summary="\"Dark and threatening in the deepest register, brilliant and triumphant in "
       .. "the high compass. The piano is full but somewhat heavy, the forte powerful and "
       .. "sonorous.\" Berlioz called it \"the true chief of that race of wind instruments "
       .. "which I distinguish as epic instruments\".",
  facts={
    {"Notes","Non-transposing - it plays what is written"},
    {"Strength","1 Trombone = 1 Trumpet = 1 Tuba = 2 Horns in forte"},
    {"Numbers","3 in the orchestra, normally all tenors (today the third is a bass "
      .. "trombone); the alto is not used"},
    {"Mobility","Valve trombones are more mobile, but slide trombones are preferred for "
      .. "\"nobility and equality of sound\""},
  },
  sec={
    {"Pairings in unison", {
      {"3 Trombones","Frequently met with, and producing extreme power and resonance - "
        .. "the group's characteristic sound.","RK p.55"},
      {"+ Bassoon","Trombone + Fag; the bassoon is also the instrument normally used to "
        .. "double a brass bass an octave below, in place of trombone or tuba.","RK p.57 & p.82"},
      {"+ English horn","One of the reed/brass unison combinations sharing the same "
        .. "characteristics; also 3 Trombones + Bass clarinet.","RK p.57"},
      {"+ ’Cellos / D. basses","With the tuba, for heavy massive effects; \"cello equals "
        .. "trombones\" is a serviceable modern rule of thumb.","RK p.61; MOD"},
      {"+ 2 Fag + Tuba + ’Cellos/D. basses","The standard bass grouping of all three "
        .. "orchestral groups.","RK p.61"},
      {"+ divided ’cellos","Trombones + 'Cellos divisi, alongside Horn + Violas divisi, "
        .. "is one of the few string/brass harmonies Rimsky-Korsakov praises.","RK p.95"},
    }},
    {"Doublings in octaves", {
      {"Trombone / Tuba","The normal-register brass pairing at the bottom.","RK p.56"},
      {"2 Trombones / Trombone + Tuba","As above, doubled.","RK p.56"},
      {"Trumpet / Trombone  ·  2 Trumpets / 2 Trombones","Trumpets above.","RK p.56"},
      {"2 Horns / 1 Trombone  ·  4 Horns / 2 Trombones","Horns above trombones, "
        .. "exclusively in octaves - possible \"though not so reliable\".","RK p.56"},
      {"Trombone + Bass cl / Tuba + C-Fag","Mixed wood-and-brass octaves.","RK p.58"},
    }},
    {"In harmony", {
      {"Three-part trombones","\"The best combination is trombones, horns, or trumpets "
        .. "in three's\" - trombones in 3-part harmony is the standard use, often "
        .. "combined with the horns.","RK p.84; MOD"},
      {"With the tuba","Commonly 4-part harmony with the tuba, or bass trombone doubled "
        .. "with tuba.","MOD"},
      {"The best heavy layout","2 Horns + Tuba on the bass in octaves, the three other "
        .. "parts on trombones: \"beautiful full resonance\".","RK p.83"},
      {"Reinforced trombone quartet","The third trombone and tuba take the bass in "
        .. "octaves, the three upper parts going to the two remaining trombones "
        .. "reinforced by a trumpet or two horns in unison, for perfect balance.","RK p.82-83"},
      {"Softened by horns","A horn chord beside the trombone chord moderates its "
        .. "penetrating timbre.","RK p.85"},
    }},
    {"Character", {
      {"Lavignac","\"Majestic and imposing... sufficiently powerful to dominate a whole "
        .. "Orchestra. It produces above all things the impression of power, a power "
        .. "superhuman... but it can also become terrible, or, even terrific... It is a "
        .. "superb instrument of lofty dramatic power, which should be reserved for great "
        .. "occasions; when properly introduced, its effect is overwhelming.\"","SIN p.115"},
      {"Berlioz","\"The composer can make it chant like a choir of priests, threaten, "
        .. "lament, ring a funeral knell, raise a hymn of glory, break forth into frantic "
        .. "cries, or sound a dread flourish to awaken the dead, or to doom the living.\"","SIN p.116"},
      {"Reserve it","Mozart kept the trombones out of Don Giovanni until the scene with "
        .. "the statue, so that they arrive as a climax.","SIN p.115"},
      {"Fanfares","Fanfare figures belong chiefly to trumpets and horns, \"but they may "
        .. "also be given to the trombones\".","RK p.53"},
      {"Quick passages","Rarely required, \"owing to the special character of their "
        .. "tone\".","RK p.24"},
    }},
    {"Use sparingly", {
      {"Woodwind an octave above a trombone","\"Wood-wind instruments should not be used "
        .. "to double a trombone in the octave above; trumpets are more suitable.\"","RK p.58"},
      {"3 Trombones + 3 Bassoons / 3 Clarinets","\"Very rare.\"","RK p.88"},
      {"Trombones + trumpets side by side","Not so common - it unites the two most "
        .. "powerful agents in the group.","RK p.85"},
      {"Doubling the voice","Trombones overpower the voice and cannot be used for it.","RK p.122"},
      {"In sustained octaves","\"The trombone with its ponderous tone rarely takes part "
        .. "in such combinations.\"","RK p.86"},
      {"Mezzo-forte re-entry","After a long rest, return at pp or ff.","RK p.118"},
    }},
  },
  related={"brass","tuba","horn","trumpet","bassoon","cello","wind_brass"},
}

e{ id="tuba", name="Tuba", family="Brass", kind="instrument",
  aliases={"tuba","tubas","bass tuba","contrabass tuba","wagner tuba","wagner tubas",
           "tuben","ophicleide"},
  summary="\"Thick and rough in quality, less characteristic than the trombone, but "
       .. "valuable for the strength and beauty of its low notes. Like the double bass and "
       .. "double bassoon, the tuba is eminently useful for doubling, an octave lower, the "
       .. "bass of the group to which it belongs.\" It has the deepest notes in the "
       .. "orchestra.",
  facts={
    {"Notes","In C (bass); fairly flexible thanks to its valves"},
    {"Strength","1 Tuba = 1 Trumpet = 1 Trombone = 2 Horns in forte"},
    {"Numbers","1, occasionally 2 (Glazunov's Finnish Fantasia)"},
    {"Mutes","Tubas rarely possess them, and the bell's shape prevents stopped notes"},
  },
  sec={
    {"Pairings and doublings", {
      {"Trombone / Tuba in octaves","The normal-register brass pairing at the bottom; "
        .. "also 2 Trombones / Trombone + Tuba.","RK p.56"},
      {"2 Horns / Tuba in octaves","As above.","RK p.56"},
      {"+ Bassoon","Tuba + Fag in unison.","RK p.57"},
      {"+ ’Cellos / D. basses (with trombones)","For heavy massive effects; most "
        .. "commonly the tuba doubles other bass instruments for stability, in unison or "
        .. "an octave below.","RK p.61; MOD"},
      {"+ 2 Fag + 3 Trombones + ’Cellos/D. basses","The standard bass grouping of all "
        .. "three orchestral groups.","RK p.61"},
      {"+ Contrabassoon","Tuba + C-Fag / D. basses as a reinforced bottom.","RK p.62"},
      {"Tuba + C-Fag / Trombone + Bass cl","Mixed wood-and-brass octaves.","RK p.58"},
    }},
    {"In harmony", {
      {"The best heavy layout","2 Horns + Tuba forming the bass in octaves with the "
        .. "three upper parts on trombones: \"beautiful full resonance\".","RK p.83"},
      {"In the trombone quartet","The third trombone and tuba usually form the bass in "
        .. "octaves.","RK p.82-83"},
      {"With trombones","4-part harmony with the trombones, or bass trombone doubled "
        .. "with tuba.","MOD"},
    }},
    {"Character", {
      {"Singleton","\"The sound of its voice is solemn, mysterious and lugubrious. It is "
        .. "very rich in its deepest notes.\" Its tone \"might be described as partaking "
        .. "of both the trombone and the organ\".","SIN p.117"},
      {"Wagner’s use","The deep dark caverns under the Rhine, the first heavy roll of "
        .. "the waves in Das Rheingold, and the dragon Fafner's voice in Siegfried.","SIN p.117-118"},
      {"Not expressive","With the piccolo, contrabassoon and small trumpet, the tuba is "
        .. "not given to playing with any great amount of expression.","RK p.25"},
      {"Wagner tubas","A separate matter: \"a quartet of two high and two low modified "
        .. "horns and one true tuba\" (Forsyth). Wagner meant them as a new colour akin to "
        .. "but distinct from the horns, playable by four of his horn players.","SIN p.118-119"},
    }},
    {"Use sparingly", {
      {"Extra tubas and contrabass trombone","Wagner's additional quartet in the Ring "
        .. "\"sometimes weigh too heavily on the other groups, and at other times render "
        .. "the rest of the brass ineffective\" - Wagner himself dropped them for Parsifal.","RK p.22-23"},
      {"In close four-part brass","\"The quartet of trombones and tuba is not often "
        .. "employed in close four-part harmony.\"","RK p.82"},
      {"Mezzo-forte re-entry","After a long rest, return at pp or ff.","RK p.118"},
    }},
  },
  related={"brass","trombone","horn","contrabassoon","doublebass"},
}

-- ============================================================================
-- PERCUSSION, HARP, KEYBOARDS
-- ============================================================================

e{ id="timpani", name="Timpani (Kettledrums)", family="Percussion", kind="instrument",
  aliases={"timpani","timpano","kettledrum","kettledrums","kettle drums","tympani",
           "timps","drums"},
  summary="\"Kettle-drums, indispensable to every theatre and concert orchestra, occupy "
       .. "the most important place in the group of percussion instruments.\" Capable of "
       .. "every dynamic shade from thundering fortissimo to a barely perceptible "
       .. "pianissimo, and of the most gradual crescendo, diminuendo, sfp and morendo in "
       .. "tremolando.",
  facts={
    {"How many","A pair up to and including Beethoven; from the mid-19th century three "
      .. "or four. Assume three screw drums and a good player who can retune one during "
      .. "a long pause"},
    {"Recommended compass","E2 to G-sharp3, chromatically"},
    {"Muffling","A cloth on the skin: timpani coperti"},
  },
  sec={
    {"Pairings", {
      {"+ Bass drum or gong tremolo + trombone chords","The standard low-register "
        .. "percussion-and-brass combination; or with low sustained 'cellos and basses.","RK p.117"},
      {"+ Wind","Wood and brass strengthen and clarify timpani and percussion generally.","RK p.34"},
      {"With plucked strings","Plucked strings and percussion \"blend perfectly\".","RK p.34"},
      {"+ cymbals + piccolo cry","Spontini's effect - a short piercing piccolo note with "
        .. "a cymbal stroke, its force augmented \"by an abrupt stroke of the kettledrums "
        .. "joined to a brief chord of all the other instruments\".","SIN p.80"},
      {"Under a voice","One of the few percussion uses in accompaniment: a figure or "
        .. "tremolo on the kettledrums.","RK p.124"},
    }},
    {"Its place in the section", {
      {"The one constant","Timpani are \"the only percussion instrument present in "
        .. "nearly all orchestral music\", and are played by a specialist who will not "
        .. "normally play any other percussion.","HUG Percussion Section"},
      {"Left out of balance sums","Their dynamic range is effectively unlimited, so no "
        .. "balance ratio fits them; and in classical and romantic scoring they mark the "
        .. "root, which simply reinforces it.","IDIO Chords"},
    }},
    {"Character and use", {
      {"Its ringing quality","Along with glockenspiel, bells and xylophone, the timpani's "
        .. "\"ringing, resounding quality\" will easily prevail over other groups in "
        .. "combination - so it needs no reinforcement.","RK p.34"},
      {"Beethoven’s contribution","He changed only how they were tuned - and \"that made "
        .. "all the difference in the world\": a minor sixth in the Seventh Symphony's "
        .. "Scherzo, octaves in the Ninth, and the dominant rather than the tonic in the "
        .. "First.","SIN p.120; SIN p.219"},
      {"Sticks","Felt-padded for normal use; wooden balls for special effects; ordinary "
        .. "street drumsticks for very fine crisp rolls (Elgar's Variations); sponge "
        .. "sticks for delicate work.","SIN p.121"},
      {"Only four good notes per drum","Which is why kettledrums are made in about six "
        .. "sizes. Allow bars of rest for retuning.","SIN p.120-121"},
    }},
    {"Use sparingly", {
      {"Against a singer","A timpani tremolo can overpower a voice even more easily than "
        .. "the doubled wind and brass can.","RK p.121"},
    }},
  },
  related={"percussion","bassdrum","cymbals","sidedrum","gong","trombone"},
}

e{ id="sidedrum", name="Side Drum (Snare Drum)", family="Percussion", kind="instrument",
  aliases={"side drum","snare drum","sidedrum","snare","military drum","tamburo",
           "tambour militaire"},
  summary="The military drum, used in the orchestra for rhythmic effects. A medium-register "
       .. "instrument of indeterminate pitch, and one of the three that can manage "
       .. "genuinely varied rhythmic figures.",
  sec={
    {"Pairings", {
      {"Tremolo + sustained trumpet and horn chords","The standard pairing - as with "
        .. "cymbals struck with drum sticks.","RK p.117"},
      {"With upper-register harmony","Side drum, triangle and tambourine go best with "
        .. "harmony in the upper register.","RK p.117"},
    }},
    {"Use", {
      {"Which rhythms","\"An insignificant and playful rhythm is suitable to the "
        .. "triangle, tambourine, castanets and side drum.\"","RK p.117"},
      {"Strokes","Its technique rests not on a single stroke but on a double alternate "
        .. "stroke with each hand. Besides the Long Roll there are the flam (a short note "
        .. "before a longer one) and the drag (a roll preceding a note).","SIN p.123"},
      {"Careful","A fortissimo side-drum tremolo will overpower any orchestral tutti.","RK p.117"},
    }},
  },
  related={"percussion","timpani","bassdrum","cymbals","tambourine"},
}

e{ id="bassdrum", name="Bass Drum", family="Percussion", kind="instrument",
  aliases={"bass drum","bassdrum","gran cassa","big drum","grosse caisse"},
  summary="A deep instrument of indeterminate pitch. \"May be used for noisy moments to "
       .. "imitate the firing of guns and the roll, or crash, of thunder and also to mark "
       .. "crescendos and climaxes. If played very softly, it is solemn and awe-inspiring.\"",
  sec={
    {"Pairings", {
      {"Tremolo + trombone chords","Or with low sustained 'cellos and double basses - the "
        .. "standard low-register pairing, shared with the gong.","RK p.117"},
      {"With lower-register harmony","Bass drum, cymbals and gong go with harmony in the "
        .. "low register.","RK p.117"},
      {"Which rhythms","\"A vigourous and straightforward rhythm may be given to the bass "
        .. "drum, cymbals and gong.\"","RK p.117"},
    }},
    {"Use", {
      {"On stage","Bass drum without cymbals, to imitate cannon (Tsar Saltan).","RK p.131"},
      {"Careful","Fortissimo, it will overpower any orchestral tutti.","RK p.117"},
    }},
  },
  related={"percussion","cymbals","gong","timpani","trombone"},
}

e{ id="cymbals", name="Cymbals", family="Percussion", kind="instrument",
  aliases={"cymbals","cymbal","piatti","antique cymbals","crotales","suspended cymbal"},
  summary="A deep-to-medium instrument of indeterminate pitch, used like the triangle to "
       .. "accentuate a climax - but more vigorously.",
  sec={
    {"Pairings", {
      {"Struck with drum sticks + sustained trumpet and horn chords","The standard "
        .. "pairing, shared with the side-drum tremolo.","RK p.117"},
      {"+ piccolo cry","Spontini's discovery: a short piercing piccolo note joined to a "
        .. "cymbal stroke. \"The singular sympathy, which is thus created between these "
        .. "very dissimilar instruments, had not been thought of before. It cuts and rends "
        .. "instantaneously, like the stab of a poignard.\"","SIN p.80"},
      {"With lower-register harmony","With bass drum and gong.","RK p.117"},
    }},
    {"Use", {
      {"Ways of playing","The two-plate stroke with a brushing movement for single notes; "
        .. "rubbing the plates together; the two-plate roll, loud or soft; or hanging one "
        .. "cymbal up and beating it with a stick like a gong.","SIN p.124-125"},
      {"With a voice","Used to accompany a singer less often than the triangle.","RK p.124"},
      {"Careful","Fortissimo, they will overpower any orchestral tutti.","RK p.117"},
    }},
  },
  related={"percussion","bassdrum","triangle","gong","piccolo"},
}

e{ id="triangle", name="Triangle", family="Percussion", kind="instrument",
  aliases={"triangle","triangolo"},
  summary="A high instrument of indeterminate pitch - which means it can be used in all "
       .. "keys and with all chords. \"The sound is clear as crystal. Sometimes it even "
       .. "seems silvery. It can play from the lightest pianissimo to the loudest "
       .. "fortissimo.\"",
  sec={
    {"Pairings", {
      {"Tremolo + trills in woodwind and violins","The standard pairing, shared with the "
        .. "tambourine.","RK p.117"},
      {"+ soft strings and woodwind","\"Mixed with soft strings and woodwind instruments, "
        .. "the triangle is of charming effect.\"","SIN p.124"},
      {"With upper-register harmony","Triangle, side drum and tambourine go best with "
        .. "harmony in the upper register.","RK p.117"},
      {"With glockenspiel, in fire music","Wagner's Walkure fire music - the glockenspiel "
        .. "adds \"brilliant tips of light to the soaring plumes of flame\" and \"here, "
        .. "too, the triangle contributes its white notes like vivid points of heat and "
        .. "light\".","SIN p.127"},
    }},
    {"Use", {
      {"Which rhythms","Suits \"an insignificant and playful rhythm\"; it can manage "
        .. "complicated rhythms and even a tremolo.","RK p.117; SIN p.124"},
      {"Widor’s remark","\"At the climax of a crescendo, when the Orchestra would seem to "
        .. "have reached the height of intensity, the introduction of the Triangle converts "
        .. "red heat into white heat.\"","SIN p.124"},
      {"With a voice","The percussion instrument most often used to accompany a singer.","RK p.124"},
      {"Economy","First in the order of percussion frequency, ahead of cymbals, bass "
        .. "drum, side drum, tambourine and gong.","RK p.118"},
    }},
  },
  related={"percussion","cymbals","tambourine","glockenspiel"},
}

e{ id="tambourine", name="Tambourine", family="Percussion", kind="instrument",
  aliases={"tambourine","tambour de basque","tamburino","tambourin"},
  summary="A medium instrument of indeterminate pitch, used in the orchestra \"to give "
       .. "'local color', especially to folk-music of Spain and Italy; to 'gypsy-music'; "
       .. "and to some kinds of dance-music\".",
  sec={
    {"Pairings", {
      {"Tremolo + trills in woodwind and violins","The standard pairing, shared with the "
        .. "triangle.","RK p.117"},
      {"With upper-register harmony","With triangle and side drum.","RK p.117"},
      {"+ castanets","Wagner uses both in the Tannhauser Bacchanale.","SIN p.126"},
    }},
    {"Use", {
      {"Three ways to play it","Striking the head with the knuckles (detached notes and "
        .. "simple rhythmic groups); shaking the hoop (a rolling noise from the jingles); "
        .. "rubbing the head with the thumb (a hollow, swishing sound with a tremolo of "
        .. "the jingles).","SIN p.125-126"},
      {"Which rhythms","Suits \"an insignificant and playful rhythm\", and can manage "
        .. "varied rhythmic figures.","RK p.117"},
      {"Also","The tambourin is a different instrument: a long narrow drum from Provence, "
        .. "beaten with one stick while the player holds a flageolet in the other hand.","SIN p.126"},
    }},
  },
  related={"percussion","triangle","castanets","sidedrum"},
}

e{ id="castanets", name="Castanets", family="Percussion", kind="instrument",
  aliases={"castanets","castanet","castagnette"},
  summary="A high instrument of indeterminate pitch, \"generally used to accent the rhythm "
       .. "of Spanish dance-music, or to give color to music of a Spanish character\". "
       .. "The sound is \"a deep, hollow click, which, although not a musical note, is not "
       .. "unpleasing when heard with its appropriate music\".",
  sec={
    {"Use", {
      {"Which rhythms","Suits \"an insignificant and playful rhythm\", with triangle, "
        .. "tambourine and side drum.","RK p.117"},
      {"With upper-register harmony","Classed among the high percussion with triangle and "
        .. "little bells.","RK p.32"},
      {"+ tambourine","Wagner uses both in the Tannhauser Bacchanale; Saint-Saens calls "
        .. "for castanets in Samson et Dalila.","SIN p.126"},
      {"Spanish practice","The dancer holds a pair in each hand - the right plays the full "
        .. "rhythm (the hembra), the left a simplified rhythm on a larger pair (the marcho).","SIN p.126"},
      {"Economy","Like the piano, \"too characteristic in timbre to be employed over "
        .. "frequently\".","RK p.118"},
    }},
  },
  related={"percussion","tambourine","triangle"},
}

e{ id="gong", name="Gong (Tam-tam)", family="Percussion", kind="instrument",
  aliases={"gong","tam tam","tam-tam","tamtam","chinese gong"},
  summary="With the bass drum, the deepest instrument of indeterminate pitch in the "
       .. "orchestra.",
  sec={
    {"Pairings", {
      {"Tremolo + trombone chords","Or with low sustained 'cellos and basses - the "
        .. "standard low-register pairing, shared with the bass drum.","RK p.117"},
      {"Which rhythms","\"A vigourous and straightforward rhythm may be given to the bass "
        .. "drum, cymbals and gong.\"","RK p.117"},
    }},
    {"Use", {
      {"On stage","Used to imitate a church bell (Ivan the Terrible).","RK p.131"},
      {"Careful","Fortissimo, it will overpower any orchestral tutti.","RK p.117"},
      {"Economy","Last in the order of percussion frequency.","RK p.118"},
    }},
  },
  related={"percussion","bassdrum","cymbals","bells"},
}

e{ id="glockenspiel", name="Glockenspiel", family="Percussion", kind="instrument",
  aliases={"glockenspiel","campanelli","bells (glockenspiel)","orchestra bells","carillon",
           "keyed glockenspiel"},
  summary="Steel or bronze bars struck with small hammers. \"The use of the glockenspiel "
       .. "is similar to the celesta, but its tone is more brilliant and penetrating.\" "
       .. "The bar type is more satisfactory and more resonant than the keyboard type.",
  sec={
    {"Pairings and use", {
      {"It wins","With bells and xylophone, its \"emphatic tone will easily prevail over "
        .. "other groups in combination\" - so use it sparingly and never to force a "
        .. "balance.","RK p.34"},
      {"+ first violins","A melody in the firsts doubled by glockenspiel gains \"a "
        .. "sparkling, chime-like colour\".","WP"},
      {"+ triangle","Wagner's Walkure fire music: the glockenspiel makes \"brilliant tips "
        .. "of light to the soaring plumes of flame\", the triangle \"vivid points of heat "
        .. "and light\".","SIN p.127"},
      {"+ piccolo and harp","In Snegourotchka a piccolo figure doubled by harp and "
        .. "glockenspiel, set four octaves from the bass - \"the general effect is "
        .. "fanciful\".","RK p.106-107"},
      {"Economy","With celesta and xylophone, \"too characteristic in timbre to be "
        .. "employed over frequently\".","RK p.118"},
    }},
  },
  related={"percussion","celesta","xylophone","bells","harp"},
}

e{ id="celesta", name="Celesta", family="Percussion", kind="instrument",
  aliases={"celesta","celeste","keyboard glockenspiel"},
  summary="Small steel plates struck by hammers from a keyboard: \"the hammers falling on "
       .. "them produce a delightful sound, very similar to the glockenspiel\". Sweet, "
       .. "clear, fairy-like and graceful - and it never goes out of tune.",
  facts={{"Notation","Like piano music, two hands, sounding an octave higher than written"}},
  sec={
    {"Pairings and use", {
      {"+ piccolo","A piccolo melody doubled by celesta gains a bright tone - a standard "
        .. "modern colour doubling.","WP"},
      {"+ harp","Debussy's Jeux pairs a harp doubling horns with \"the bell-like celesta\".","WP"},
      {"Easily overpowered","The combined force of the sustaining groups easily overpowers "
        .. "the celesta - so keep the texture thin around it.","RK p.34"},
      {"Substitute","\"The celesta is only found in full orchestras; when it is not "
        .. "available it should be replaced by an upright piano, and not the glockenspiel.\"","RK p.31"},
      {"Who introduced it","First used by Tchaikovsky - famously in the Nutcracker; "
        .. "Tchaikovsky and Strauss gave it its popularity.","RK p.31; SIN p.128"},
      {"Economy","Too characteristic to use often.","RK p.118"},
    }},
  },
  related={"percussion","glockenspiel","piano","harp","piccolo"},
}

e{ id="xylophone", name="Xylophone", family="Percussion", kind="instrument",
  aliases={"xylophone","xylophon","xilofono"},
  summary="\"A species of harmonica composed of strips or cylinders of wood, struck with "
       .. "two little hammers. It produces a clattering sound, both powerful and piercing.\" "
       .. "Dry and hollow, and suited to grotesque music.",
  sec={
    {"Pairings and use", {
      {"It wins","With glockenspiel and bells, its emphatic tone easily prevails over "
        .. "other groups in combination.","RK p.34"},
      {"Its string equivalent","Strings col legno produce a sound similar to the "
        .. "xylophone, gaining in quality as more players join.","RK p.32"},
      {"Its character role","Saint-Saens's Danse Macabre, \"in which it represents the "
        .. "clattering of the bones of the dancing skeletons\".","SIN p.129"},
      {"Economy","Too characteristic in timbre to be employed over frequently.","RK p.118"},
    }},
  },
  related={"percussion","glockenspiel","celesta"},
}

e{ id="bells", name="Bells (Tubular Chimes)", family="Percussion", kind="instrument",
  aliases={"bells","tubular bells","chimes","tubular chimes","campane","church bells"},
  summary="\"Big bells in the shape of hollow discs or metal tubes, or real church bells "
       .. "of moderate size may be considered more as theatrical properties than orchestral "
       .. "instruments.\" Modern suspended metal plates have \"the rare quality of a fairly "
       .. "pure tone\" and are portable enough for the concert platform.",
  sec={
    {"Pairings and use", {
      {"It wins","With glockenspiel and xylophone, its emphatic tone easily prevails over "
        .. "other groups.","RK p.34"},
      {"+ bassoons and clarinets","Meyerbeer's big bell in low F for the massacre of the "
        .. "Huguenots, \"combined with bassoons and clarinets, which give the music a "
        .. "sinister quality that is very impressive\".","SIN p.130"},
      {"On stage","\"Bells in various keys\" are among the instruments Rimsky-Korsakov "
        .. "specifies for the wings.","RK p.131"},
      {"Substitutes","Saint-Saens's midnight chime in Danse Macabre is twelve notes "
        .. "plucked on the harp; Strauss tells the hour with taps on the glockenspiel; the "
        .. "bells of Montsalvat in Parsifal are usually played on tubular chimes.","SIN p.131"},
      {"Why they are hard to pitch","Lavignac: of all sound-producing agents the bell "
        .. "\"develops the greatest number of over-tones, often discordant even, which "
        .. "sometimes causes a difficulty in discovering which is the fundamental musical "
        .. "tone\".","SIN p.130"},
    }},
  },
  related={"percussion","glockenspiel","gong","harp"},
}

e{ id="harp", name="Harp", family="Plucked", kind="instrument",
  aliases={"harp","harps","arpa","concert harp","double action harp"},
  summary="\"In the orchestra, the harp is almost entirely an harmonic or accompanying "
       .. "instrument... The tender poetic quality of the harp is adapted to every dynamic "
       .. "shade, but it is never a very powerful instrument, and the orchestrator should "
       .. "treat it with respect.\" Like pizzicato strings, more an instrument of colour "
       .. "than of expression.",
  facts={
    {"Range","C-flat1 to F-sharp7, but normally only the 1st to 4th octaves are used"},
    {"How many","1 part is usual; 2 or 3 in later scores. 3-4 in unison are needed to be "
      .. "heard against a full forte orchestra"},
    {"Limits","Diatonic by nature - all chromatic passages depend on the pedals. No double "
      .. "sharps or double flats"},
  },
  sec={
    {"Pairings", {
      {"+ Brass","Berlioz: \"Of all known qualities of tone it is singular that the "
        .. "quality of horns, of trombones, and, generally, of brass instruments mingles "
        .. "best with theirs.\"","SIN p.281"},
      {"+ pizzicato strings","The two form the plucked group together; for a singer, "
        .. "\"strings pizz. and the harp forms a setting eminently favourable for the "
        .. "voice\".","RK p.26 & p.120"},
      {"+ Percussion","Wind clarifies harp and percussion alike, and plucked strings with "
        .. "percussion \"blend perfectly\".","RK p.34"},
      {"+ Piano","Harp with piano imitates a popular plucked instrument or a soft peal of "
        .. "bells.","RK p.30"},
      {"+ 2 Flutes","Berlioz's trio for two flutes and harp in L'Enfance du Christ; Mozart "
        .. "wrote a concerto for flute and harp.","SIN p.286 & p.288"},
      {"+ Piccolo and glockenspiel","A piccolo figure doubled by harp and glockenspiel, "
        .. "far from the bass - \"the general effect is fanciful\".","RK p.106-107"},
      {"Accompanying a cantabile aria","Listed among the solo instruments for this.","RK p.124"},
    }},
    {"Writing for it", {
      {"Chords must be broken","Only four notes per hand at most, written close together, "
        .. "and always arpeggiato unless you mark non arpeggiato.","RK p.28"},
      {"Rapid figures","Only clear in the upper register, where the strings are shorter "
        .. "and harder - lower down, one chord mixes into the next.","RK p.28"},
      {"Glissando","Peculiar to the harp. As a purely musical effect it works only in the "
        .. "upper octaves, quite piano. Forte glissandi through the low and middle strings "
        .. "are permissible only as embellishment; glissandi in sevenths and ninths, got "
        .. "enharmonically, take any dynamic.","RK p.29"},
      {"Modulation","It does not lend itself to rapid modulation - use two harps "
        .. "alternately. Some transitions are only possible enharmonically.","RK p.28"},
      {"Harmonics","Great charm but little resonance; only three notes, close together, "
        .. "two for the left hand and one for the right; possible only quite softly.","RK p.29 & p.29"},
      {"Berlioz on its bass","The veiled, mysterious low strings \"have scarcely ever been "
        .. "employed except for bass accompaniments of the left hand; and the more the "
        .. "pity!\"","SIN p.281"},
      {"Berlioz on its top","\"A delicate, crystalline sound of voluptuous freshness\" - "
        .. "but never attacked with violence, or it gives \"a dry, hard sound, similar to "
        .. "that of broken glass\".","SIN p.282"},
      {"Artificial effect","Long glissandi are more resonant and brilliant than short "
        .. "ones, so composers write glissando notes that do not correspond with what the "
        .. "rest of the orchestra is playing.","RK p.116"},
    }},
  },
  related={"plucked","pizzicato","percussion","brass","celesta","piano"},
}

e{ id="piano", name="Piano in the Orchestra", family="Plucked", kind="instrument",
  aliases={"piano","pianoforte","upright piano","keyboard","harpsichord","cembalo"},
  summary="\"The use of a piano in the orchestra (apart from pianoforte concertos) belongs "
       .. "almost entirely to the Russian school.\" Two purposes: to imitate a popular "
       .. "plucked instrument, or a soft peal of bells.",
  sec={
    {"Pairings and use", {
      {"+ Harp","The standard combination, for a plucked-instrument or bell effect.","RK p.30"},
      {"+ pizzicato strings","Piano and harp can reinforce a tutti pizzicato.","RK p.103"},
      {"Which piano","\"When the piano forms part of an orchestra, not as a solo "
        .. "instrument, an upright is preferable to a grand.\"","RK p.30"},
      {"Superseded","\"Today the piano is gradually being superseded by the celesta\" - "
        .. "but where no celesta is available, an upright piano replaces it, not the "
        .. "glockenspiel.","RK p.30-31"},
      {"Easily overpowered","A softly played piano is easily overpowered by the sustaining "
        .. "groups.","RK p.34"},
      {"Economy","With the castanets, too characteristic in timbre to be used often.","RK p.118"},
      {"Historically","\"The piano, or harpsichord, ceased to belong to the Orchestra in "
        .. "the days of Haydn\" - and in the 20th century composers began experimenting "
        .. "with it as an orchestral instrument again.","SIN p.290"},
    }},
  },
  related={"harp","celesta","plucked","percussion"},
}

-- ============================================================================
-- CRAFT (Belkin's Artistic Orchestration)
-- ============================================================================

e{ id="contrast", name="Scale of Timbral Contrast", family="Craft", kind="topic",
  aliases={"contrast","timbral contrast","how much contrast","degree of contrast",
           "scale of contrast","changing instrument","switching instruments"},
  summary="How big a change the ear actually hears when a line passes from one "
       .. "instrument to another. \"The degree of timbral change must correspond to the "
       .. "degree of formal contrast required: A major section break requires more "
       .. "orchestral contrast than a new motive within a phrase.\" Beginners "
       .. "habitually misjudge this.",
  facts={
    {"The governing principle","\"Timbres which blend well in chords present little "
       .. "or no contrast when heard in succession; timbres which do not blend in "
       .. "chords make for stronger contrasts\""},
    {"Caveat","Perceived contrast depends on register, articulation and texture too, "
       .. "not timbre alone"},
  },
  sec={
    {"Group 1 — imperceptible or very mild", {
      {"Same instrument, different register","e.g. low flute to high flute, excepting "
        .. "the most extreme registers.","BEL p.24"},
      {"Between adjacent members of the string family","",  "BEL p.24"},
      {"Between trumpets and trombones","",  "BEL p.24"},
    }},
    {"Group 2 — mild to moderate", {
      {"Within the same woodwind sub-family","e.g. flute to alto flute, oboe to "
        .. "English horn.","BEL p.24"},
      {"Within one instrument or sub-family, but into an extreme register","",  "BEL p.24"},
      {"Between diverse woodwinds in registers that blend well","e.g. clarinets to "
        .. "bassoons in the middle register, flutes to oboes higher up.","BEL p.24"},
      {"Between woodwind and brass that would blend simultaneously","e.g. bassoons to "
        .. "horns.","BEL p.24"},
      {"Horn to trumpet, or horn to trombone","",  "BEL p.24"},
    }},
    {"Group 3 — more marked", {
      {"Between diverse woodwinds that would not blend in chords","e.g. low oboe to "
        .. "low flute. \"Very often these cases involve the oboe.\"","BEL p.24"},
      {"Between woodwind and brass that do not blend simultaneously","",  "BEL p.24"},
      {"Between woodwind and strings","",  "BEL p.24"},
      {"Between brass and strings","",  "BEL p.24"},
    }},
    {"Group 4 — contrast outweighs the similarity", {
      {"A completely different nature of sound","e.g. strings arco exchanging with "
        .. "strings pizzicato.","BEL p.24"},
    }},
    {"Group 5 — extreme", {
      {"Only one aspect of the phrase survives the exchange","e.g. flute against "
        .. "snare drum: only the rhythm can be imitated.","BEL p.25"},
    }},
    {"Adjusting the scale", {
      {"A constant background reduces it","\"In a passage with more than one plane of "
        .. "tone, contrast will be lessened if the background plane remains constant\" "
        .. "- a flute phrase answered by oboe over the same string accompaniment reads "
        .. "as less of a change.","BEL p.25"},
      {"Mixed timbres share their elements","Oboe+flute in unison is closer to "
        .. "oboe+clarinet in unison than oboe alone is to clarinet alone. And "
        .. "\"extensive use of mixed timbres makes larger formal contrasts harder to "
        .. "effect, since the colors, not being pure, are less distinct\".","BEL p.25"},
      {"Pizzicato counts as percussion","Treat plucked strings as a kind of pitched "
        .. "percussion when judging contrast; percussion itself divides into "
        .. "sub-families by material - woods, metals, skins, pitched and "
        .. "unpitched.","BEL p.25 & p.7"},
      {"Very loud to very soft needs help","\"After a fortissimo tutti, the ear "
        .. "requires a moment to adapt to very quiet music; otherwise the first few "
        .. "quiet notes can pass unnoticed.\" Hold one or two instruments over from "
        .. "the loud passage for a few beats.","BEL p.25"},
    }},
  },
  related={"form","blend","doubling","planes","balance"},
}

e{ id="form", name="Orchestration and Form", family="Craft", kind="topic",
  aliases={"form","structure","orchestration and form","where to change",
           "rate of change","climax","climaxes","cadence","accents","phrasing"},
  summary="The subject Belkin wrote his book to cover, because the other treatises do "
       .. "not: orchestration as a structural device rather than a colouring one. "
       .. "\"A change of sound creates a formal articulation.\"",
  sec={
    {"Where a change of timbre belongs", {
      {"Between phrases and sections","\"The normal place for timbre to change is "
        .. "between phrases, sections, etc.\"","BEL p.19"},
      {"Inside a phrase, only at meaningful moments","\"Motivic changes, climactic "
        .. "moments, and cadences. Changes at other places sound arbitrary.\" Belkin "
        .. "notes that arbitrary mid-phrase changes are \"common in student "
        .. "work\".","BEL p.19"},
      {"Accents","Usually need a new sound added momentarily, or a change of playing "
        .. "technique - double stops in the strings, a percussive attack. \"The change "
        .. "must of course be proportional to degree of accent required\", and normally "
        .. "in the same register as the main line.","BEL p.19 & p.25"},
      {"Cadences","\"Structural articulations can often be enhanced by some change in "
        .. "the orchestration.\"","BEL p.19"},
    }},
    {"Rate of orchestral change", {
      {"It works like harmonic rhythm","\"Like harmonic rhythm - the rate of harmonic "
        .. "change - the rate of orchestral change has an important impact on the "
        .. "music's pacing.\" Speeding it up and slowing it down creates tension and "
        .. "relaxation.","BEL p.21"},
      {"Not all changes weigh the same","\"Adding a unison flute doubling to a line in "
        .. "the violins does not have the same impact as adding three trumpets playing "
        .. "chords.\"","BEL p.21"},
      {"A worked case","Mahler's Fourth, second movement: subtle changes for eight "
        .. "bars, then stopped horns and the theme moved to woodwind create the "
        .. "intensity. The nervous character of that movement comes from frequent "
        .. "prominent timbre changes - and the calm of the third movement comes from "
        .. "\"remaining entirely within the string choir\".","BEL p.23"},
    }},
    {"Progressions and climaxes", {
      {"Orchestral progressions","Crescendi and diminuendi; gradually rising or "
        .. "falling passages; texture getting thicker or thinner. All \"powerful "
        .. "sources of musical direction\".","BEL p.20 & p.31"},
      {"Reserve something for the main climax","\"Usually one climax, near the end, "
        .. "stands out more than the others. It is important to reserve some unique "
        .. "orchestral resource for this moment.\"","BEL p.20"},
      {"Crescendo by addition, diminuendo by subtraction","\"An orchestral crescendo "
        .. "is achieved by adding instruments in a well graduated order, and a "
        .. "diminuendo by subtracting them.\" Beethoven's Ninth opens with the "
        .. "textbook case: violin 1, double bass, viola, clarinet, oboe, flute, "
        .. "bassoon.","BEL p.26-27; cf. RK p.112"},
      {"Never contradict the dynamic","\"It is especially important not to "
        .. "inadvertently contradict the dynamic evolution of a phrase by doing the "
        .. "opposite, e.g. adding instruments during a diminuendo.\"","BEL p.26"},
    }},
  },
  related={"contrast","dynamics","planes","quality","three_groups"},
}

e{ id="dynamics", name="Orchestrating Dynamics", family="Craft", kind="topic",
  aliases={"dynamics","loud","soft","absolute dynamics","relative dynamics",
           "how loud can it play","dynamic marks","pp","ff"},
  summary="\"Orchestrate your dynamics instead of just writing them as textual "
       .. "indications.\" Some instruments simply cannot reach some dynamics in some "
       .. "registers, however you mark them.",
  sec={
    {"Absolute vs relative", {
      {"The distinction","\"Every instrument has some relative dynamic control in "
        .. "every register. However, some instruments, in particular registers, simply "
        .. "cannot achieve certain absolute dynamics.\" A group of brass high up will "
        .. "never be very soft; a low flute can never be very loud.","BEL p.27"},
      {"Who can start from nothing","\"Strings and certain percussion (tam-tam, "
        .. "cymbals, and the lower drums) can start practically inaudibly.\" The "
        .. "clarinet can play whisper-soft provided it is not written too high.","BEL p.27"},
      {"Who has the most power","\"For sheer power, nothing has the force and impact "
        .. "of high brass plus percussion.\"","BEL p.27"},
    }},
    {"Making a dynamic change register", {
      {"Skip a gradation","\"For noticeable contrasts, skip at least one gradation. The "
        .. "difference between mf and f is negligible. Moving from mp to f or mf to ff "
        .. "will have a more dramatic impact.\" The concrete version of Belkin's advice to "
        .. "work with four levels.","ACTOR All Instruments: Effective Instrumental Writing"},
      {"Players respond to extremes","An expanded range from ppp to fff gets attention, "
        .. "while p and mp are often ignored or under-played. If you want quiet, write pp "
        .. "or ppp. Musicians answer wide contrasts more readily than subtle ones.",
        "ACTOR All Instruments: Effective Instrumental Writing"},
      {"Dynamics are relative, not absolute","There is no decibel level that constitutes "
        .. "forte; the loudness that results is set by the context and by the marks "
        .. "around it. This is why orchestrating the level beats marking it.",
        "ACTOR All Instruments: Effective Instrumental Writing"},
    }},
    {"How to notate them", {
      {"Work with four levels","\"A good approach is to act as though there are only "
        .. "four dynamic levels: pp, mf, f, and ff.\"","BEL p.27"},
      {"Get the level from the scoring first","\"Orchestrate the passage so that the "
        .. "absolute dynamic level desired results naturally from the choice of "
        .. "instruments and registers.\" Then treat the mark as a character "
        .. "indication.","BEL p.27"},
      {"Avoid the middle as a starting point","\"Avoid the middle dynamics (mp, mf) as "
        .. "starting points: these are what players do when there are no dynamics "
        .. "notated at all.\"","BEL p.27"},
      {"Per-instrument dynamics are advanced","\"Beginners should avoid writing "
        .. "different dynamics for different instruments; this requires a great deal of "
        .. "experience: Players normally do not see each other's parts, and will not "
        .. "adjust unless the conductor specifies otherwise.\" Set against "
        .. "Rimsky-Korsakov's rule that horns be marked a degree louder than the rest "
        .. "of the brass, and Mahler's practice of calibrating every instrument "
        .. "separately: the technique is real, but it is not a beginner's "
        .. "tool.","BEL p.27-28; cf. RK p.23"},
    }},
  },
  related={"balance","form","brass","strings","percussion"},
}

e{ id="planes", name="Planes of Tone", family="Craft", kind="topic",
  aliases={"planes","planes of tone","plane of tone","foreground","background",
           "texture","layers","layering","accompaniment figuration"},
  summary="Tovey's term, and the organising idea of modern orchestration: \"one "
       .. "instrument, or a blended group of instruments, not necessarily from the same "
       .. "family, sharing one rhythmic outline\". Think in planes first, then decide "
       .. "what each contains.",
  facts={
    {"Why it matters","\"The listener cannot pay equal attention to several musical "
       .. "strands for any length of time. Even in contrapuntal music, the ear jumps "
       .. "from one part to another rather than following all the parts continuously\""},
  },
  sec={
    {"Making a plane hold together", {
      {"Blend inside it","Similarity of timbre and rhythm, close spacing with no large "
        .. "gaps, and balance - all elements fairly equal in force.","BEL p.40"},
      {"Differentiate between them","Contrast of register, timbre and/or rhythm.","BEL p.40"},
      {"Disparate timbres need tricks","\"If there are disparate timbres, as in the "
        .. "woodwind, special strategies, such as close overlapping, are required to "
        .. "trick the ear into accepting the result as a unified whole.\" This is what "
        .. "Rimsky-Korsakov's overlaying and enclosure are for.","BEL p.40 & p.7"},
    }},
    {"The hierarchy", {
      {"One foreground only","\"Although multiple foreground planes are not possible, "
        .. "multiple background planes can coexist.\" The foreground is usually louder, "
        .. "strongly coloured and prominently placed - often on top.","BEL p.41"},
      {"Dialogue between equals","Possible, but the planes must match in loudness "
        .. "*and* in thickness; contrast then comes from colour, register and rhythm.","BEL p.40"},
      {"Two kinds of background","Movement, and resonance.","BEL p.41"},
    }},
    {"The four types of orchestral movement", {
      {"Trills and tremolos","Wagner's Ride of the Valkyries - trills in the winds "
        .. "adding energy and momentum.","BEL p.41"},
      {"Repeated notes","Beethoven's Fifth, second movement coda: the bassoon theme "
        .. "over repeated string chords alternating with rests.","BEL p.41"},
      {"Scales","Die Meistersinger overture - scales in the strings under a majestic "
        .. "chordal theme in the winds.","BEL p.42"},
      {"Arpeggiation","Brahms's Third, third movement - rocking arpeggio figures in "
        .. "the strings.","BEL p.42"},
      {"How to keep them in their place","\"They must not attract too much attention "
        .. "on their own... usually limited to one or two mildly varied motives, with a "
        .. "high degree of consistency, and do not involve too many varied timbres. "
        .. "Often the accompaniment is lightened with rests.\"","BEL p.42"},
      {"Movement as direction","Rising and falling passages can be reinforced by fast "
        .. "runs, scales or harp glissandi in the same direction - and \"often takes "
        .. "slightly different forms in different instruments, so as to create general "
        .. "momentum rather than one thickly doubled line\".","BEL p.42"},
    }},
    {"Resonance — the quietest plane", {
      {"It should not be noticed","\"Resonance, the quietest of all planes, should not "
        .. "be noticed on its own. Therefore it is characterized by the softest "
        .. "timbres, the dullest registers, and the least activity.\"","BEL p.43"},
      {"Put it in the foreground’s register","\"Resonance is usually in the same "
        .. "register as the foreground, so as not to draw attention to itself as "
        .. "something apart.\"","BEL p.43"},
      {"Depth is the mark of a master","\"One sign of a master orchestrator is the "
        .. "refinement and depth of his orchestral backgrounds.\" Where a background "
        .. "has several elements, \"rests and intermittent motives help to space out "
        .. "details, while maintaining clarity\".","BEL p.44"},
    }},
  },
  related={"resonance","contrast","doubling","counterpoint","tutti","balance"},
}

e{ id="resonance", name="Sustained vs Dry Sound", family="Craft", kind="topic",
  aliases={"resonance","sustained","dry","wet","sustain","background resonance",
           "held notes","reverberation","sustaining pedal"},
  summary="\"It is often remarked that the orchestra has no sustaining pedal.\" So "
       .. "resonance has to be composed - and a texture with none, kept up for long, is "
       .. "one of the named symptoms of poor orchestration.",
  sec={
    {"Composing resonance", {
      {"It is a background layer by definition","Literally it means the echo of a live "
        .. "room - \"however, resonance can also be deliberately composed "
        .. "orchestrally, and therefore individualized\".","BEL p.33"},
      {"Bach got there first","He \"already shows sensitivity to the way a long held "
        .. "note can enrich the texture\", and goes further, using such notes as "
        .. "points of departure for important lines.","BEL p.33"},
      {"Ravel is the model","The Epilogue of Valses nobles et sentimentales - held "
        .. "strings set off by harp harmonics, \"a shimmering halo surrounding the main "
        .. "motives in the winds. This conception of the background as delicate "
        .. "vibration is omnipresent in Ravel.\"","BEL p.33"},
      {"Lines can dissolve into it","A line that settles onto a held note becomes "
        .. "resonance; a held note can equally become a doubling.","BEL p.33 & p.38"},
    }},
    {"Dry sound", {
      {"Effective, but not as a norm","\"Although it is not good practice to "
        .. "orchestrate for long without sustained sound, occasional dry passages can "
        .. "be extraordinarily effective.\"","BEL p.33"},
      {"Wet and dry percussion","Metal instruments are \"wet\", with substantial "
        .. "reverberation - poor for quick precise rhythms, excellent for background "
        .. "ambiance. Wooden instruments are \"dry\", for clarity and definition. "
        .. "Membranes sit in between: low ones reverberate, high ones behave like "
        .. "wood.","BEL p.13 & p.33"},
      {"It translates into articulation","The wet/dry distinction is the same choice "
        .. "as staccato against legato, seen from the rhythmic and motivic side.","BEL p.33"},
    }},
  },
  related={"planes","percussion","harp","counterpoint","quality"},
}

e{ id="counterpoint", name="Orchestrating Counterpoint", family="Craft", kind="topic",
  aliases={"counterpoint","contrapuntal","fugue","polyphony","imitative",
           "orchestrating counterpoint","entries"},
  summary="Four problems, and Belkin's answers to each: balancing the lines, colouring "
       .. "them, marking the entries, and stopping the result from sounding dry.",
  sec={
    {"Balancing the lines", {
      {"Simplest strategy — one family","\"Assuming all the lines are of equal "
        .. "importance, the simplest strategy is to give all the lines to the same "
        .. "family, or, if a thicker sound is appropriate, families: Each line is "
        .. "doubled by a similar combination of instruments.\" Beethoven's Seventh, "
        .. "second movement, keeps all the counterpoint in the strings.","BEL p.46-47"},
      {"Different colours per line","Requires the colours to be equal in loudness *and* "
        .. "in thickness. \"This latter method can be tiring to the ear and is best used "
        .. "for short passages\", and suits stratified counterpoint better than "
        .. "consistent imitation.","BEL p.47"},
    }},
    {"Marking the entries", {
      {"Treat an entry as an accent","\"In counterpoint with frequent imitative "
        .. "entries, it is sometimes effective to treat the beginning of an important "
        .. "entry as an accent, orchestrally enhancing the first few notes in some "
        .. "way.\" Mahler's Fifth finale doubles the strings' first few notes with a "
        .. "horn in a luminous register.","BEL p.47"},
    }},
    {"Avoiding dryness", {
      {"Add a harmonic plane behind it","\"It is usually a good idea either to add a "
        .. "complete harmonic plane of tone in the background, covering the middle "
        .. "register in particular, or to leave sustained 'trailers' (held notes at the "
        .. "end of a phrase) behind the main lines from time to time.\" The Baroque "
        .. "continuo was in part an answer to the same problem.","BEL p.47"},
      {"Let doubling instruments change role","Bassoons switching which line they "
        .. "double, trombones stopping once they have marked an entry, horns leaving a "
        .. "sustained note behind - \"thereby avoiding dryness\".","BEL p.47"},
    }},
  },
  related={"planes","resonance","tutti","doubling","woodwind"},
}

e{ id="tutti", name="The Tutti", family="Craft", kind="topic",
  aliases={"tutti","full orchestra playing","everyone playing","full tutti",
           "organising a tutti"},
  summary="\"One can speak of a tutti when at least three of the four orchestral "
       .. "families are present.\" The paradox: \"the more instruments are playing, the "
       .. "less ways there are to combine them\", because acoustic balance closes off "
       .. "most of the options.",
  sec={
    {"The three ways to organise one", {
      {"1. Each family complete, part-writing independent","\"This is the most common "
        .. "method; it gives a rich sound, without grayness. The overall harmonic unity "
        .. "guarantees coherence, and the differences between the families create "
        .. "richness of color.\" Die Meistersinger's prelude: the winds begin by "
        .. "doubling the violins and are adding their own detail by bar 7.","BEL p.49-50"},
      {"2. Each musical element to a distinct family","\"This method has the advantage "
        .. "of bringing out each musical element clearly, differentiating it from the "
        .. "others through timbre.\" Tchaikovsky's Fifth finale: strings on the melody "
        .. "in octaves, horns and winds on two counterpoints, repeated notes in low "
        .. "brass and basses.","BEL p.50-51"},
      {"3. Literally double everything in every family","\"While occasionally suitable "
        .. "for short, vigorous passages, this method usually sounds heavy and "
        .. "gray.\"","BEL p.51-52"},
    }},
    {"Practicalities", {
      {"Leave the middle empty when the brass is loud","\"Sometimes winds and, more "
        .. "rarely, strings, are left empty in the middle register when a large brass "
        .. "section is very fully scored; they would not in any case be audible in this "
        .. "register over the brass.\"","BEL p.49"},
      {"Differentiate the rhythm at least mildly","\"As the number of instruments "
        .. "increases, if all the instruments are moving on the same rhythmic plane, "
        .. "the effect becomes more and more ponderous. Thus the need, even in a "
        .. "homophonic tutti of any length, for at least mild rhythmic differentiation "
        .. "between parts and families.\"","BEL p.41"},
      {"The soft tutti","\"Usually tutti passages are loud, but the occasional soft "
        .. "tutti can be very effective; the sound has something menacing about it, "
        .. "like a great power restrained.\" Beethoven's Ninth, first movement, bar "
        .. "469.","BEL p.49"},
      {"Everyone should play sometimes","\"If one writes for orchestra, all the "
        .. "instruments should play together at least some of the time.\" Against which: "
        .. "most of the time only part of the orchestra should be playing.","BEL p.49 & p.37"},
    }},
  },
  related={"three_groups","planes","balance","counterpoint","quality"},
}

e{ id="accompaniment", name="Accompanying a Soloist", family="Craft", kind="topic",
  aliases={"accompaniment","accompanying","soloist","concerto","orchestral accompaniment",
           "accompany a soloist","backing a soloist"},
  summary="\"The main problem is how to make full use of the orchestra, while not "
       .. "drowning out the soloist. If the orchestra is too often reduced to discrete "
       .. "murmuring in the background, the overall effect will be feeble.\"",
  sec={
    {"The principles", {
      {"Win by contrast, not by retreat","Contrast of timbre (violin solo against "
        .. "woodwind), of register (accompany a 'cello solo with upper strings only), or "
        .. "of rhythm (make the solo line more active than the accompaniment).","BEL p.52"},
      {"Aerate the texture","\"Lighten the orchestra by aerating the texture with "
        .. "frequent rests, plucked or staccato basses. Limit held notes in the "
        .. "accompaniment to dull or weak registers.\"","BEL p.53"},
      {"Activity can substitute for weight","A piano too weak to dominate can still "
        .. "lead by \"sheer intensity of activity\" - fastest note values, runs covering "
        .. "the orchestra's whole range.","BEL p.53"},
      {"Keep the relationship moving","\"Sometimes use dialogue, sometimes have each "
        .. "accompany the other.\"","BEL p.54"},
      {"For great force, alternate","\"Present the soloist in alternation with the "
        .. "orchestra: This gives the illusion of a confrontation between "
        .. "equals.\"","BEL p.55"},
      {"Richness from many thin planes","\"To avoid thinness in the orchestral writing, "
        .. "create richness by multiple planes, even if each plane only contains a few "
        .. "notes.\"","BEL p.56"},
    }},
    {"With a singer", {
      {"Double at the octave, not the unison","\"Generally such doubling is less "
        .. "obtrusive at the octave than at the unison\" - though unison doubling is "
        .. "commoner in opera, partly because the orchestra is in the pit and the voices "
        .. "on the stage.","BEL p.57"},
      {"What never to double","\"Elaborate fiorituras should not be doubled, nor should "
        .. "passages where detailed understanding of the words is critical: Doubling "
        .. "obscures detail, and submerges the consonants necessary to clear "
        .. "speech.\"","BEL p.57"},
      {"Activity covers a voice faster than volume","Koechlin's point: \"normally "
        .. "strings are ideal for accompanying the voice, but if they are playing "
        .. "vigorous counterpoint they will cover the voice much more easily than if "
        .. "they have long held notes\".","BEL p.36"},
    }},
  },
  related={"voice","planes","balance","strings","quality"},
}

e{ id="quality", name="Good and Poor Orchestration", family="Craft", kind="topic",
  aliases={"good orchestration","poor orchestration","bad orchestration","checklist",
           "what is good orchestration","mistakes","common mistakes","diagnosis"},
  summary="Belkin's two checklists, and the reason the second is needed: \"if the parts "
       .. "are reasonably playable... it is almost as hard to write glaringly badly for "
       .. "the orchestra as it is to write glowingly well\". Poor orchestration does not "
       .. "announce itself - \"it only shows itself over fairly long spans or in repeated "
       .. "listening\".",
  sec={
    {"Symptoms of poor orchestration", {
      {"Feebleness of effect","Not using the resources available for the character "
        .. "wanted, or making contradictory gestures - adding instruments during a "
        .. "diminuendo.","BEL p.18"},
      {"Aural fatigue","Overuse of extreme registers or very distinctive colours; lack "
        .. "of blend in harmonic masses.","BEL p.18"},
      {"Grayness","Too much unison doubling.","BEL p.18"},
      {"Heaviness","Too much doubling, or overloading the low register.","BEL p.18"},
      {"Consistently dry sound","No background resonance anywhere. \"Dry sound can be "
        .. "effective, but not as a norm.\"","BEL p.18"},
      {"Confusion among elements","Poorly differentiated planes of tone.","BEL p.18"},
      {"Formal confusion","Changes of timbre at arbitrary places, or changes not "
        .. "proportional to the contrast required.","BEL p.18"},
      {"Lack of clear character","",  "BEL p.18"},
    }},
    {"What good orchestration does", {
      {"Makes formal sense","Changes arrive at appropriate places with appropriate "
        .. "degrees of contrast.","BEL p.58"},
      {"Supplies variety and freshness of colour","Enough to maintain interest.","BEL p.58"},
      {"Enhances the phrasing","",  "BEL p.58"},
      {"Ensures every element is audible","",  "BEL p.58"},
      {"Gives every player something individual","What Richard Strauss, writing of "
        .. "Wagner, called \"the spiritual participation of the players\".","BEL p.58"},
      {"Is as easily playable as possible","\"Always using the simplest means to create "
        .. "the desired effect.\"","BEL p.58"},
      {"Is aurally rich","Usually through multiple planes of tone.","BEL p.58"},
      {"Expresses a clear character","",  "BEL p.58"},
      {"Uses the whole ensemble effectively","",  "BEL p.58"},
    }},
    {"The underlying point", {
      {"Colour is not the main issue","\"Color is not as important an issue in "
        .. "orchestration as is commonly thought.\" What matters more: \"Color is less "
        .. "the result of exotic timbres than of novelty in the context of the piece. "
        .. "Even a familiar timbre like an oboe can sound striking and novel, provided "
        .. "it has not been heard for a while. This is why Mozart's orchestration is "
        .. "always so fresh, despite its limited number of colors.\"","BEL p.32-33"},
      {"Orchestration is composition","\"Orchestration can bring out and enhance any "
        .. "aspect of the music\" - and once that habit forms it becomes \"an integral "
        .. "part of composition itself\". Compare Rimsky-Korsakov: \"orchestration is "
        .. "part of the very soul of the work\".","BEL p.58-59; cf. RK p.1"},
    }},
  },
  related={"form","planes","contrast","doubling","character"},
}

-- ============================================================================
-- CHARACTER GLOSSARY (Belkin, Artistic Orchestration, Appendix 2)
-- ============================================================================
-- Belkin's own caveats apply to every entry below and are reproduced in the
-- "character" entry. Used as a recipe book these become cliches; they are meant
-- as a point of departure.

e{ id="character", name="Character: Scoring for a Mood", family="Character", kind="topic",
  aliases={"character","mood","emotion","feeling","atmosphere","character glossary",
           "how to sound","what sound for","expression"},
  summary="The reverse lookup: start from the character you want and find the "
       .. "orchestral resources that produce it. Belkin compiled this as a teaching "
       .. "device - \"a list of character words, and orchestral suggestions for how to "
       .. "express them\" - and warns clearly about how to use it.",
  sec={
    {"Read these caveats first", {
      {"The words are approximate","\"A word like 'lyrical' can imply many different "
        .. "emotions, each of which would be orchestrated somewhat differently.\"","BEL p.62"},
      {"A point of departure, not a recipe book","\"Used simplistically, the "
        .. "combinations given here easily become cliches. Cliches quickly lose their "
        .. "effect, and can even become inappropriately comic. (Think of the diminished "
        .. "chord tremolos signifying danger, in silent films.)\"","BEL p.62"},
      {"Orchestration is not the only dimension","\"Other aspects of the music, like "
        .. "harmony, tempo, rhythm, etc., are equally important.\" The entries for "
        .. "\"terrifying\" and \"brilliant\" are deliberately similar - \"the resulting "
        .. "effect will depend strongly on the kind of harmony used\".","BEL p.62"},
      {"Everything must pull the same way","\"One characteristic of weak music is the "
        .. "way certain aspects of the music contribute nothing, or even distract from "
        .. "the desired effect.\"","BEL p.62"},
      {"Make your own","The method matters more than the list: \"list every orchestral "
        .. "resource which can contribute to creating a given character\". Belkin "
        .. "suggests similar glossaries for harmony, rhythm and the rest.","BEL p.60 & p.62"},
    }},
    {"The characters covered", {
      {"Search any of these directly","Luminous · Mysterious · Menacing · Terrifying "
        .. "· Brilliant · Splendid · Dramatic · Funereal · Playful · Sad.","BEL p.62-64"},
    }},
  },
  related={"luminous","mysterious","menacing","terrifying","brilliant","splendid",
           "dramatic","funereal","playful","sad"},
}

e{ id="luminous", name="Luminous", family="Character", kind="mood",
  aliases={"luminous","radiant","glowing","shimmering","light","luminosity"},
  summary="\"This character requires two elements: a soft background, usually sustained "
       .. "strings, and another element to add 'light'.\"",
  sec={
    {"Scoring it", {
      {"The background","Soft sustained strings.","BEL p.62"},
      {"Soft medium-high trumpets or horns","One of the three ways to add the light.","BEL p.62"},
      {"Flutes, medium-high, not too loud","",  "BEL p.62"},
      {"Touches of high metal percussion","Suspended cymbal, glockenspiel - \"again, "
        .. "not too loud\".","BEL p.62"},
    }},
    {"Related craft", {
      {"Woodwind doubling an octave above strings adds luminosity","An oboe doubling "
        .. "the second violins \"helps it to emerge more clearly, and makes it "
        .. "brighter\".","BEL p.9"},
    }},
  },
  related={"character","strings","horn","trumpet","flute","glockenspiel","resonance"},
}

e{ id="mysterious", name="Mysterious", family="Character", kind="mood",
  aliases={"mysterious","mystery","eerie","veiled","ethereal","enigmatic","misty"},
  summary="\"Mystery comes from lack of clarity. Appropriate sounds include very "
       .. "delicate background resonance (sustained sound) and/or very quiet movement, "
       .. "not too thickly spaced.\"",
  sec={
    {"Scoring it", {
      {"Muted strings","",  "BEL p.62-63"},
      {"String harmonics","",  "BEL p.63"},
      {"Low flutes","",  "BEL p.63"},
    }},
    {"Related craft", {
      {"A gentle cymbal crescendo adds mystery to a background","Belkin's own example "
        .. "pairs a rising harp and clarinet with one.","BEL p.32"},
      {"Held string harmonics as resonance","\"Delicate held notes in violins "
        .. "(harmonics) and violas provide mysterious background resonance.\"","BEL p.44"},
    }},
  },
  related={"character","strings","flute","harp","cymbals","resonance"},
}

e{ id="menacing", name="Menacing", family="Character", kind="mood",
  aliases={"menacing","threatening","ominous","foreboding","dread","sinister"},
  summary="\"Certain sounds, often starting softly and making a crescendo, which evoke "
       .. "natural threats (e.g. earthquakes, eruptions) are very potent.\"",
  sec={
    {"Scoring it", {
      {"Low drums, rolls or rhythmic patterns","\"Create an almost primeval, "
        .. "threatening effect.\"","BEL p.63"},
      {"Low, closely spaced strings and/or woodwinds, muted brass","",  "BEL p.63"},
      {"Extreme low sounds, soft","Tam-tam, bass drum.","BEL p.63"},
    }},
    {"Related craft", {
      {"The soft tutti","\"The occasional soft tutti can be very effective; the sound "
        .. "has something menacing about it, like a great power restrained.\"","BEL p.49"},
    }},
  },
  related={"character","timpani","bassdrum","gong","strings","brass","tutti"},
}

e{ id="terrifying", name="Terrifying, Angry, Savage", family="Character", kind="mood",
  aliases={"terrifying","terror","angry","anger","savage","violent","fury","harsh",
           "frightening"},
  summary="\"Loud and piercing sounds, which often resemble animal cries, harsh and "
       .. "strident.\" Note that Belkin's scoring for this and for \"brilliant\" is "
       .. "deliberately similar - the harmony decides which one you get.",
  sec={
    {"Scoring it", {
      {"High, dissonant woodwinds and/or brass","\"Perhaps in insistent repeated notes "
        .. "or trills.\"","BEL p.63"},
      {"High, dry percussion","A loud xylophone; cymbal roll crescendos.","BEL p.63"},
    }},
    {"Related craft", {
      {"Loud muted brass is in a class of its own","\"When loud, their strident sound "
        .. "puts them in a class of their own.\"","BEL p.13"},
      {"Instruments strained within their range","Trumpets and horns high *for them*, "
        .. "though not high absolutely, create \"an effect of intensity and "
        .. "strain\".","BEL p.30"},
    }},
  },
  related={"character","brilliant","woodwind","brass","xylophone","cymbals","range"},
}

e{ id="brilliant", name="Brilliant", family="Character", kind="mood",
  aliases={"brilliant","brilliance","dazzling","virtuosic","sparkling","glittering"},
  summary="\"Often suggests a certain virtuosity, speed.\"",
  sec={
    {"Scoring it", {
      {"Brass in their high registers, open intervals","\"In fast figuration, e.g. "
        .. "repeated notes, trills.\"","BEL p.63"},
      {"Brass crescendos","",  "BEL p.63"},
      {"Fast rising lines in strings and woodwinds","",  "BEL p.64"},
    }},
    {"Related craft", {
      {"One piccolo is enough at the top","\"Even in a large tutti, one piccolo in its "
        .. "highest register will penetrate without difficulty.\" The number of "
        .. "instruments needed at the extremes is much smaller than in the "
        .. "middle.","BEL p.29"},
      {"Movement in the direction of the line","Fast runs, scales and harp glissandi "
        .. "reinforce a rising or falling passage.","BEL p.42"},
    }},
  },
  related={"character","terrifying","brass","piccolo","strings","harp","planes"},
}

e{ id="splendid", name="Splendid, Rich, Triumphant", family="Character", kind="mood",
  aliases={"splendid","rich","triumphant","majestic","noble","grand","heroic",
           "glorious"},
  summary="\"Requires a mass of instruments, suggesting generosity and richness.\"",
  sec={
    {"Scoring it", {
      {"Tutti with sustained brass","\"Closely spaced in upper middle register "
        .. "(especially horns, in the range of the alto voice), along with high strings, "
        .. "in octaves.\"","BEL p.64"},
    }},
    {"Related craft", {
      {"Why the horns sit there","\"The best arrangement for horns in harmony is: three "
        .. "or four horns, in close position, in the range of the alto voice.\" "
        .. "Sometimes the fourth doubles the first an octave lower.","BEL p.11"},
      {"Which tutti method","Each family complete but independently written gives \"a "
        .. "rich sound, without grayness\"; literal doubling of everything \"usually "
        .. "sounds heavy and gray\".","BEL p.49 & p.51-52"},
      {"Rimsky-Korsakov’s heavy brass layout","2 horns + tuba on the bass in octaves, "
        .. "three trombones above: \"beautiful full resonance\".","RK p.83"},
    }},
  },
  related={"character","tutti","horn","brass","strings","three_groups"},
}

e{ id="dramatic", name="Dramatic", family="Character", kind="mood",
  aliases={"dramatic","drama","theatrical","striking","startling"},
  summary="\"Sudden contrasts in register, timbre, and dynamics.\" The shortest entry in "
       .. "Belkin's glossary, and the one that leans hardest on the rest of the book.",
  sec={
    {"Scoring it", {
      {"Sudden contrast in all three dimensions at once","Register, timbre and "
        .. "dynamics together.","BEL p.64"},
    }},
    {"Related craft", {
      {"Grade the contrast deliberately","Use the five-group scale of timbral contrast "
        .. "- \"too great a contrast will create an inappropriate break in the music; "
        .. "too small a contrast will deprive the music of necessary "
        .. "punctuation\".","BEL p.23-25"},
      {"High against low sections","\"The contrast of low and high chords provides a "
        .. "simple but dramatic contrast\" - Brahms's Fourth, third movement.","BEL p.29"},
      {"Help the ear after a fortissimo","Hold one or two instruments over for a few "
        .. "beats, or the first quiet notes will pass unnoticed.","BEL p.25"},
    }},
  },
  related={"character","contrast","form","range","dynamics"},
}

e{ id="funereal", name="Funereal", family="Character", kind="mood",
  aliases={"funereal","funeral","mourning","solemn","lament","dirge","march funebre"},
  summary="\"Heavy, dragging sounds, suggesting a mourning procession.\"",
  sec={
    {"Scoring it", {
      {"Low register brass and winds playing slowly","",  "BEL p.64"},
      {"Timpani or bass drum dotted rhythms","",  "BEL p.64"},
    }},
    {"Related craft", {
      {"Low horns for slow pedals only","\"The horns' lowest notes are best reserved "
        .. "for slow moving pedal passages; they are not suitable for mobile bass lines, "
        .. "which they tend to render ponderous.\" Here that ponderousness is the "
        .. "point.","BEL p.11"},
      {"The dark low orchestra","Contrabassoon, low bassoons, bass clarinet, horns, "
        .. "trombones and tuba - Rimsky-Korsakov's combination for the bottom of the "
        .. "orchestra, \"dark and gloomy\".","RK p.106"},
    }},
  },
  related={"character","brass","timpani","bassdrum","contrabassoon","range"},
}

e{ id="playful", name="Playful, Funny", family="Character", kind="mood",
  aliases={"playful","funny","comic","humorous","lightness","scherzando","witty",
           "grotesque"},
  summary="\"The key here is lightness, unless a grotesque effect is wanted.\"",
  sec={
    {"Scoring it", {
      {"Lots of rests","",  "BEL p.64"},
      {"High, staccato sounds","",  "BEL p.64"},
      {"Avoid sustained sounds in brass","",  "BEL p.64"},
      {"Pizzicato","",  "BEL p.64"},
      {"Bassoon staccato","",  "BEL p.64"},
      {"For grotesque, use caricature","\"Instruments playing passagework "
        .. "characteristic of others, e.g. a tuba playing a comic line which would "
        .. "normally be given to the bassoon.\"","BEL p.64"},
    }},
    {"Related craft", {
      {"The bassoon’s comic register","Its medium and lower staccato notes have \"a "
        .. "certain grotesqueness bordering on awkwardness\" (Lavignac); Humperdinck has "
        .. "it comment on the stage action in Hansel und Gretel.","SIN p.95 & p.98"},
      {"Gaps are allowed here","Large registral gaps \"may be effective in one "
        .. "situation, for example a quiet, playful passage, but not in another, where "
        .. "fullness and richness are required\".","BEL p.4"},
    }},
  },
  related={"character","bassoon","pizzicato","tuba","woodwind","range"},
}

e{ id="sad", name="Sad, Melancholy, Poignant", family="Character", kind="mood",
  aliases={"sad","sadness","melancholy","poignant","mournful","wistful","sorrowful",
           "elegiac","plaintive"},
  summary="\"Often suggests an individual (solo) lamenting, or discouragement, "
       .. "weakness.\"",
  sec={
    {"Scoring it", {
      {"Slow, sustained strings in the lower register","",  "BEL p.64"},
      {"A wind solo over sustained strings","\"Especially oboe or clarinet, or low "
        .. "flute.\"","BEL p.64"},
    }},
    {"Related craft", {
      {"Which solo instrument","The oboe's \"natural tone is of a gentle sadness and a "
        .. "resigned endurance\" (Lavignac); the English horn is \"essentially sad, "
        .. "melancholy, sorrowful\", superior to all others \"in exciting regret\" "
        .. "(Berlioz); the viola runs \"from sad reverie to agonized pathos\".","SIN p.85, p.89, p.52"},
      {"The reference cases","Dvorak's New World Largo - English horn over muted "
        .. "strings. Tristan Act III - the shepherd's melody on \"the saddest voice in "
        .. "the orchestra\".","SIN p.90"},
      {"A solo line must stay solo","Doubling it will weaken exactly the quality you "
        .. "want: \"a line whose character requires a solo sound will be less effective "
        .. "when doubled\".","BEL p.7"},
    }},
  },
  related={"character","oboe","englishhorn","clarinet","flute","viola","strings"},
}

-- ============================================================================
-- VOICES
-- ============================================================================

e{ id="voice", name="Solo Voice with Orchestra", family="Voices", kind="section",
  aliases={"voice","voices","singer","solo voice","soprano","mezzo","mezzo-soprano",
           "contralto","alto","tenor","baritone","bass voice","accompanying the voice",
           "aria"},
  summary="\"In accompanying the voice orchestral scoring should be light enough for the "
       .. "singer to make free use of all the dynamic shades of expression without hardness "
       .. "of tone.\" The six principal solo voices are soprano, mezzo-soprano, contralto, "
       .. "tenor, baritone and bass.",
  sec={
    {"Doubling the voice", {
      {"Women’s voices in unison","Violins, violas, clarinets and oboes - \"the most "
        .. "natural duplication\".","RK p.122"},
      {"Men’s voices in unison","Violas, 'cellos, bassoons and horns.","RK p.122"},
      {"Octaves","Doubling in octaves is usually done in the upper register.","RK p.122"},
      {"Keep it brief","\"Uninterrupted or too frequent duplication should be avoided\" - "
        .. "it robs the singer of freedom and replaces the rare quality of the human voice "
        .. "with a mixed timbre. Limited to a few phrases it \"supports the voice and endows "
        .. "it with beauty and colour\".","RK p.122"},
      {"Only in tempo","Doubling in unison or octaves \"is only suitable in tempo; to apply "
        .. "it to a passage ad lib. is both ineffective and dangerous\".","RK p.122-123"},
    }},
    {"Transparency — what is safe to accompany with", {
      {"The order","\"The group of strings is the most transparent medium and the one least "
        .. "likely to overpower the voice. Then come the wood-wind and the brass, the latter "
        .. "in the following order: horns, trombones, trumpets.\"","RK p.120"},
      {"The best setting","Strings pizzicato + harp.","RK p.120"},
      {"Short beats sustained ones","\"As a general rule a singer is more easily overpowered "
        .. "by long sustained notes than by short detached ones.\"","RK p.120"},
      {"Where sustained harmony is safe","Between the 2nd octave and the middle of the 3rd "
        .. "it overpowers neither women's nor men's voices.","RK p.121"},
      {"Reduce as the voice does","As the singer moves from cantabile into declamation, thin "
        .. "or drop harmony that has become too heavy; support broad phrases and climaxes "
        .. "with a fuller tone.","RK p.121-122"},
    }},
    {"Solo instrument with a solo voice", {
      {"Which instruments","Violin, viola, 'cello; flute, oboe, English horn, clarinet, bass "
        .. "clarinet, bassoon, horn, harp. \"In combination with the voice... a solo "
        .. "instrument is a powerful expedient for musical characterisation.\"","RK p.124"},
      {"Rimsky-Korsakov’s own pairs","Soprano + oboe; contralto + English horn; baritone + "
        .. "bass clarinet; soprano + viola; soprano, 'cello and oboe together.","RK p.124"},
    }},
    {"Duet spacing", {
      {"Related within an octave","Sopr./Ten., M.-sopr./Bar., C.-alto/Bass - move in tenths, "
        .. "sixths, thirds or octaves; rarely separated by more than a tenth.","RK p.139-140"},
      {"Related in fifths and fourths","Sopr./C.-alto, C.-alto/Ten., Ten./Bass - keep them "
        .. "closer; common in sixths and thirds, rare in tenths, and they may go in unison.","RK p.140"},
      {"Related in thirds","Sopr./M.-sopr., M.-sopr./C.-alto, Ten./Bass, Bar./Bass - unison, "
        .. "thirds and sixths, with much crossing of parts.","RK p.140-141"},
      {"Related in twelfths","Sopr./Bass - avoid close intervals and thirds; use sixths, "
        .. "tenths and thirteenths; no crossing.","RK p.141"},
    }},
    {"Use sparingly", {
      {"Brass on the melody","Trombones and trumpets overpower the voice and cannot double "
        .. "it.","RK p.122"},
      {"Doubled groups","Strings doubled in wood and brass, and brass doubled by woodwind, "
        .. "\"are combinations liable to drown the singer\"; so is a timpani tremolo.","RK p.120-121"},
      {"Two like instruments as one part","\"Doubling of wood-wind and horns, and the use of "
        .. "two clarinets, two oboes or two horns in unison to form one harmonic part is "
        .. "likewise to be avoided.\"","RK p.121"},
      {"Long low bass notes","Frequent sustained double-bass notes under a voice \"produce a "
        .. "peculiar throbbing effect\".","RK p.121"},
      {"Rhythmic imitation","When the vocal part is busy, do not write rhythmic figures in "
        .. "the orchestra that correspond to it; leave the voice free.","RK p.119"},
    }},

    {"Belkin’s practical notes", {
      {"Plan the climaxes around singable words","\"Singing, by nature, strongly "
        .. "distorts words in favor of vowels; consonants function mainly as "
        .. "articulation.\" The voice cannot open out on a closed vowel like the French "
        .. "u, so \"climactic passages must be planned around important words, which also "
        .. "permit the voice to sing out\".","BEL p.16-17"},
      {"Follow the spoken phrase","\"The rhythm, accentuation, and contour of the vocal "
        .. "line should follow that of the words, well spoken. They may exaggerate, but "
        .. "should not contradict\" it.","BEL p.17"},
      {"Agility is a special effect","\"Voices need time to open out to their full sound; "
        .. "therefore very agile and/or staccato writing is a rare, special "
        .. "effect.\"","BEL p.17"},
      {"Stay in the middle","\"More than any other instrument, voices require writing in "
        .. "the middle of their range most of the time, to avoid discomfort. Very low and "
        .. "(especially) very high writing should be reserved for special "
        .. "moments.\"","BEL p.17"},
      {"Trombones are the gentlest brass here","In the baritone register, close-written "
        .. "trombones are lighter than horns - useful when brass must accompany a "
        .. "voice.","BEL p.12"},
    }},
  },
  related={"chorus","strings","harp","pizzicato","englishhorn","oboe","cello"},
}

e{ id="chorus", name="Chorus with Orchestra", family="Voices", kind="section",
  aliases={"chorus","choir","choral","mixed chorus","womens chorus","mens chorus",
           "chorus with orchestra","sopranos","altos","tenors","basses"},
  summary="\"The chorus, possessing much greater unity and power than the solo voice, does "
       .. "not demand such careful handling in the accompaniment. On the contrary, too great "
       .. "a refinement of orchestral treatment will prove harmful to the resonance of the "
       .. "chorus.\" Choral scoring follows the rules for purely instrumental writing.",
  facts={
    {"Numbers","Full chorus: 32 singers to each of the four parts. Medium: 16-20. Small: "
      .. "8-10. Women often predominate, and the firsts outnumber the seconds"},
  },
  sec={
    {"Pairings in unison", {
      {"Sopranos + Altos","\"The simplest and most natural combination\" - ample and "
        .. "vigorous, and good for bringing out a melody in the upper part.","RK p.145"},
      {"Tenors + Basses","As above, for the bass part.","RK p.145"},
    }},
    {"Doublings in octaves", {
      {"8 [Sopranos / Tenors]","\"The most beautiful and natural combinations\"; the tone is "
        .. "both brilliant and powerful.","RK p.145"},
      {"8 [Altos / Basses]","As above.","RK p.145"},
      {"8 [Sopr + Altos / Ten + Basses]","\"A beautifully round tone.\"","RK p.146"},
      {"8 [Sopr/Altos in 3rds / Ten/Basses in 3rds]","\"Brilliance and vigour is achieved\" "
        .. "when sopranos and altos in thirds are doubled an octave below by tenors and "
        .. "basses in thirds.","RK p.146"},
    }},
    {"Orchestrating around it", {
      {"Doubling choral parts","\"Generally a good plan.\" In cantabile passages the "
        .. "duplication may be melodic, with the orchestral design more ornamental than the "
        .. "chorus's.","RK p.126"},
      {"What to double","Not the repeated notes required by declamation - double the melodic "
        .. "or harmonic basis only. Sometimes the choral rhythm is simplified against its "
        .. "orchestral duplication.","RK p.127"},
      {"Isolated exclamations","Melodic doubling is not always suitable; support the voices "
        .. "with harmonic duplication instead.","RK p.127"},
      {"A cappella passages","Choral writing complete in itself often stays undoubled, "
        .. "accompanied only by sustained notes or an independent polyphonic figure.","RK p.127"},
      {"Weight by chorus type","Heavier scoring for a mixed chorus; lighter for men's "
        .. "voices; lighter still for women's alone. A chorus in the wings needs as light an "
        .. "accompaniment as a solo singer.","RK p.128"},
      {"What can beat a chorus","\"A ff passage on an enlarged orchestra, comprising "
        .. "wood-wind in fours, and numerous brass (sometimes in three's), is capable of "
        .. "overpowering a large mixed chorus.\"","RK p.128"},
      {"Unlike the orchestra","Doubling like instruments in unison - 2 Ob, 2 Cl, 4 Horns, 3 "
        .. "Trombones - is perfectly possible under a chorus, where it would be avoided under "
        .. "a solo voice.","RK p.126"},
    }},
    {"Balanced forte chord in close harmony", {
      {"The layout","Sopr I / Sopr II / Altos, doubled an octave below by Ten I / Ten II / "
        .. "Basses I, with Basses II independent on the bottom. \"In this manner the tenors "
        .. "sing in the soprano octave, the 1st basses in the alto octave and the 2nd basses "
        .. "are independent.\"","RK p.147"},
      {"Wide spacing is more natural","Purely harmonic four-part choral writing \"is more "
        .. "natural and resonant when the harmony is of the widely divided order\", so each "
        .. "voice sits in its proper register.","RK p.146 & p.141"},
      {"Strengthen the middle","In three-part choruses double the middle part; giving the "
        .. "upper part to the firsts and dividing the seconds for the two lower parts \"can "
        .. "never be equal\".","RK p.148-149 & p.151"},
    }},
    {"Use sparingly", {
      {"Altos + Tenors in unison","\"Produces a peculiar mixed tone quality, somewhat "
        .. "bizarre and seldom used.\"","RK p.145"},
      {"Sopr/Altos or Ten/Basses in octaves","\"Seldom practised\" - the registers do not "
        .. "give the balance you get from voices of distinctive kind.","RK p.145-146"},
      {"Dividing like voices in octaves","8 [Sopr I / Sopr II] etc. is seldom done, except "
        .. "perhaps in the basses where the part-writing demands it.","RK p.146"},
      {"A female chorus’s bass","A women's chorus does not normally carry the real harmonic "
        .. "bass when that lies low; give the harmony to the three upper parts and let the "
        .. "lowest act as accompanying bass - watching for empty fourths and fifths.","RK p.151"},
    }},
  },
  related={"voice","strings","woodwind","brass"},
}

-- ============================================================================

return D
