--[[
  orchestration_composers.lua
  Composer entries for Orchestration Helper - who favoured what, and why.

  Loaded automatically by the main script if it sits alongside it. The script
  works without this file; composers are simply absent.

  Same editorial rule as the main database: cited claims only, and a combination
  a source calls rare or exceptional is never presented as a recommendation.

  A note on what these entries are for. They are not biographies. Each one
  answers a working question: if I want this composer's sound, what did they
  actually put together, and what would I reach for?

  CITATION TAGS beyond those in orchestration_data.lua:
    FILM - film-music references, see D.SOURCES.FILM below.
]]--

local D = { ENTRIES = {}, SOURCES = {} }
local function e(t) D.ENTRIES[#D.ENTRIES + 1] = t; return t end

D.SOURCES.FILM = {
  tag   = "FILM",
  short = "Film-music references",
  full  = "Present-day film-music references consulted together for the film "
       .. "composer entries: score studies and analyses from Movie Music UK, the "
       .. "Timbre and Orchestration Resource (ACTOR Project), Sound on Sound, "
       .. "Soundfly/Flypaper, Classic FM, the Vienna Symphonic Library forum's "
       .. "orchestration threads, publishers' and orchestras' programme notes "
       .. "(LA Phil, Hollywood Bowl, Wise Music Classical), and Wikipedia's "
       .. "articles on the individual scores and composers. Cited by tag, not by "
       .. "page: see README.md on how these were consulted.",
}

-- ============================================================================
-- INDEX ENTRY
-- ============================================================================

e{ id="composers", name="Composers: How to Use Them", family="Reference", kind="topic",
  aliases={"composers","composer","who used","famous composers","study scores",
           "learn from composers","composer index"},
  summary="Every composer entry answers one working question: if you want this "
       .. "sound, what did they actually put together? Look up a composer to get "
       .. "their favoured combinations, their signature colours, and the specific "
       .. "thing worth stealing.",
  sec={
    {"How to read a composer entry", {
      {"Favoured combinations","The doublings and pairings they returned to. "
        .. "Cross-check these against the instrument pages: a combination that "
        .. "appears on both is about as safe as orchestration gets.","MOD"},
      {"Signature colours","The sound they are recognised by, and the "
        .. "instrumentation that produces it.","MOD"},
      {"What to take from them","The transferable lesson, separated from the "
        .. "period style.","MOD"},
    }},
    {"Rimsky-Korsakov’s advice on whom to study", {
      {"Study the fairly modern, not the ancient","\"Fairly modern music will "
        .. "teach the student how to score - classical music will prove of "
        .. "negative value to him... It is useless for a Berlioz or a Gevaert to "
        .. "quote examples from the works of Gluck. The musical idiom is too "
        .. "old-fashioned and strange to modern ears.\" He names Weber, "
        .. "Mendelssohn, Meyerbeer, Berlioz, Glinka, Wagner, Liszt and the modern "
        .. "French and Russians as the best guides.","RK p.3-4"},
      {"Beethoven stands apart","\"His music abounds in countless leonine leaps "
        .. "of orchestral imagination, but his technique, viewed in detail, "
        .. "remains much inferior to his titanic conception\" - his trumpets stand "
        .. "out above the orchestra, his horn intervals are difficult and unhappy. "
        .. "Expect to \"stumble upon a thousand and one points in "
        .. "contradiction\".","RK p.4"},
      {"The four phases a student passes through","\"1. the phase during which he "
        .. "puts his entire faith in percussion instruments... 2. the period when "
        .. "he acquires a passion for the harp... 3. the stage during which he "
        .. "adores the wood-wind and horns... 4. the more advanced period, when he "
        .. "has come to recognise that the string group is the richest and most "
        .. "expressive of all.\" Try to skip the first three.","RK p.4"},
      {"How to study","\"The best plan is to study full-scores, and listen to an "
        .. "orchestra, score in hand.\"","RK p.4"},
    }},
    {"Belkin’s order for studying scores", {
      {"1. Mendelssohn","\"An excellent starting point... His orchestration is classical "
        .. "in spirit, economical, simple, and always effective. Mendelssohn's part "
        .. "writing is straightforward, his orchestration perfectly balanced, and his "
        .. "figuration imaginative without being overly elaborate.\"","BEL p.60"},
      {"2. Tchaikovsky","\"A logical next step, similar in technique to Mendelssohn, but "
        .. "with a larger orchestra. Again, his orchestration is effective, clear, and "
        .. "easily understood.\"","BEL p.61"},
      {"3. Bizet’s Carmen","\"A basic text for orchestration with voices.\"","BEL p.61"},
      {"4. Mozart","\"Although he uses an orchestra smaller than Mendelssohn's, has more "
        .. "complex and refined methods of part writing, and therefore should follow, "
        .. "rather than precede the latter.\"","BEL p.61"},
      {"5. Beethoven","\"Introduces many novel orchestral ideas, and, properly "
        .. "understood, his approach to the orchestra will greatly increase the student's "
        .. "sophistication.\"","BEL p.61"},
      {"6. Wagner","\"More advanced orchestration begins with Wagner, in particular the "
        .. "richness of his orchestral polyphony as a norm, and the way he uses the "
        .. "enlarged orchestral families.\"","BEL p.61"},
      {"7. Then Ravel, Mahler, Strauss","Only after the rest have been assimilated. "
        .. "\"Composers like Mahler and Ravel, wonderful orchestrators though they are, "
        .. "are not suitable for beginners since their textures are often very rich and "
        .. "complex.\"","BEL p.60-61"},
    }},
    {"Where the two authorities disagree", {
      {"They agree on Mendelssohn","Both put him among the first composers a student "
        .. "should study.","RK p.4; BEL p.60"},
      {"They disagree sharply about the classics","Rimsky-Korsakov: \"Fairly modern "
        .. "music will teach the student how to score - classical music will prove of "
        .. "negative value to him\", and Mozart and Haydn are of \"no further use "
        .. "today\". Belkin puts Mozart fourth in a graded sequence and Beethoven fifth, "
        .. "as steps that increase sophistication.","RK p.4; BEL p.61"},
      {"And about where Wagner sits","Rimsky-Korsakov lists Wagner among the basic "
        .. "guides for a student. Belkin makes him the threshold of *advanced* study.","RK p.4; BEL p.61"},
      {"How to read the disagreement","Rimsky-Korsakov was arguing in 1891 against a "
        .. "conservatoire tradition that taught scoring from Gluck and Mozart, and "
        .. "against an idiom he found too remote to imitate. Belkin is grading by "
        .. "technical complexity for a student who will study all of it eventually. The "
        .. "two are answering different questions.","MOD"},
    }},
    {"Also worth studying, though not given entries here", {
      {"Not covered, deliberately","Nino Rota, Georges Delerue, Elmer Bernstein, "
        .. "Maurice Jarre, Alfred Newman, Franz Waxman, James Horner, Thomas "
        .. "Newman, Michael Giacchino, Hildur Gudnadottir, Ludwig Goransson; and "
        .. "among the concert composers Sibelius, Copland, Britten, Bartok, "
        .. "Prokofiev, Respighi, Janacek, Vaughan Williams, Messiaen and Ligeti. "
        .. "They are omitted not for lack of interest but because this "
        .. "encyclopaedia only records what it can cite, and the sources to hand "
        .. "gave no orchestration specifics for them. Better an honest gap than a "
        .. "confident guess.","MOD"},
    }},
  },
  related={"doubling","blend","balance","orchestra"},
}

-- ============================================================================
-- CONCERT COMPOSERS
-- ============================================================================

e{ id="monteverdi", name="Claudio Monteverdi", family="Composers", kind="composer",
  aliases={"monteverdi","monteverde","claudio monteverdi","claudio monteverde"},
  summary="The first composer to treat instrumentation as a choice rather than an "
       .. "accident. Where earlier scores often left the instruments to the leader, "
       .. "Monteverdi specified them.",
  facts={ {"Dates","1567-1643"}, {"Look at","Orfeo (1607), Il Combattimento, "
          .. "L'Incoronazione di Poppea"} },
  sec={
    {"His orchestra", {
      {"Plucked continuo in quantity","Chitarroni, theorbo and lutes formed the "
        .. "backbone - instruments of five and six feet in length carrying six pairs "
        .. "of unisons on the fingerboard and seven or eight open bass strings.","SIN p.136-140"},
      {"Strings already central","Venetian and Roman orchestras of the period ran "
        .. "to bodies of violins with alto violas, tenor, bass and contrabass, "
        .. "against a handful of winds - flutes for pastoral scenes, trumpets for "
        .. "the choral ones, cornets and trombones for the infernal ones.","SIN p.155"},
    }},
    {"What to take from him", {
      {"Assign the colour deliberately","The habit of naming which instrument plays "
        .. "which line - the root of everything in this encyclopaedia - starts here.","MOD"},
    }},
  },
  instruments={"plucked","harp","trombone","strings"},
  related={"composers","plucked","orchestra"},
}

e{ id="bach", name="Johann Sebastian Bach", family="Composers", kind="composer",
  aliases={"bach","js bach","j s bach","johann sebastian bach","jsbach"},
  summary="\"Bach's contribution to the development of the Orchestra is that he "
       .. "treated each separate instrument lovingly and as if it were an individual, "
       .. "so that he prepared the way for the occasional solos in orchestral "
       .. "compositions.\" Stravinsky: \"What incomparable instrumental writing is "
       .. "Bach's. You can smell the resin in his violin parts, and taste the reeds "
       .. "in the oboes.\"",
  facts={ {"Dates","1685-1750"},
          {"Look at","Magnificat BWV 243, Cantatas BWV 65 and 67, St John Passion, "
            .. "Brandenburg Concertos"} },
  sec={
    {"Favoured combinations", {
      {"Muted strings + flutes","The accompaniment to 'et misericordia' from the "
        .. "Magnificat: muted strings doubled by flutes, \"a subtle combination of "
        .. "mellow instrumental timbres\".","WP"},
      {"Agitated strings handing over to sustained woodwind","In Cantata BWV 67 the "
        .. "strings dovetail with sustained woodwind chords to accompany the solo "
        .. "singer - an effect John Eliot Gardiner likens to \"a cinematic "
        .. "dissolve\".","WP"},
      {"Oboes and flutes in lyrical dialogue over a tremulant bass","The opening of "
        .. "the St John Passion: reiterated bass, sighing violas, swirling violins, "
        .. "and above that ferment pairs of oboes and flutes locked together with "
        .. "anguished dissonances.","WP"},
      {"Recorders, oboes da caccia, horns and strings together","The opening chorus "
        .. "of Cantata BWV 65 puts all four in eight bars, ranging from two horns "
        .. "over a string pedal to the whole body spread across five octaves.","WP"},
      {"Many trumpets of different sizes","\"The scores of Bach and Handel often "
        .. "call for many trumpets. In their day it was necessary to use a number of "
        .. "trumpets of different size, because no one instrument could play all the "
        .. "notes required.\"","SIN p.112"},
    }},
    {"Characteristic instruments", {
      {"The obsolescent ones","He wrote for a great many instruments already going "
        .. "out of fashion: oboe d'amore, oboe da caccia, viola d'amore, viola da "
        .. "gamba.","SIN p.187"},
      {"The violin as a self-sufficient voice","With Bach \"the violin became a solo "
        .. "instrument which could speak unaided for itself\"; his unaccompanied "
        .. "violin works are \"the most stupendous works ever written by anybody for "
        .. "a single instrument\".","SIN p.186-187"},
      {"Horn and flute","He scored frequently for the horn, newly admitted to the "
        .. "orchestra around 1720, and wrote six sonatas for the flute.","SIN p.104 & p.77"},
    }},
    {"What to take from him", {
      {"But not his colour scheme","\"Bach's Orchestra and Handel's Orchestra were "
        .. "both neutral in tint; or, if we prefer, black and white. The instruments "
        .. "all played their separate parts, but their individual voices had as yet "
        .. "hardly been discovered.\" Take the part-writing, not the palette.","SIN p.192"},
      {"Obbligato thinking","One instrument set against the voice as an equal partner "
        .. "- the ancestor of every solo-instrument-with-singer pairing.","MOD"},
    }},
  },
  instruments={"violin","oboe","flute","englishhorn","trumpet","horn","cello"},
  related={"composers","handel","violin","oboe","strings_wind"},
}

e{ id="handel", name="George Frideric Handel", family="Composers", kind="composer",
  aliases={"handel","haendel","george frideric handel","georg friedrich handel"},
  summary="His scores look thin on the page because they were never the whole story: "
       .. "he improvised at the keyboard and expected the gaps to be filled. What he "
       .. "did fix in writing was the technique of individual instruments, through "
       .. "obbligato arias.",
  facts={ {"Dates","1685-1759"},
          {"Look at","Messiah, Esther, Acis and Galatea, Il Penseroso, Rinaldo"} },
  sec={
    {"Favoured combinations", {
      {"One obbligato instrument against the voice","\"As a rule, these arias are "
        .. "accompanied by several instruments supporting one that plays an obbligato "
        .. "part; and these show what Handel did to develop and exhibit the technique "
        .. "of various instruments.\"","SIN ch.VIII"},
      {"Flute imitating a bird","The obbligato to \"Sweet bird that shun'st the noise "
        .. "of folly\" in Il Penseroso.","SIN p.77"},
      {"High flute with a bass voice","\"O ruddier than the Cherry\" in Acis and "
        .. "Galatea - written for the flute, now played on the piccolo, and given a "
        .. "pastoral character.","SIN p.79-80"},
      {"Harp with theorbo","In Esther (1720), \"Breathe soft, ye winds\" - one of the "
        .. "first orchestral uses of the harp.","SIN p.288"},
      {"Violoncello obbligato","He \"took great pleasure in the violoncello\" and gave "
        .. "it obbligati in several oratorio and cantata arias.","SIN p.58"},
    }},
    {"His orchestra", {
      {"Woodwind-heavy balance","\"The balance of Handel's Orchestra was very "
        .. "different from ours, because of the overwhelming number of woodwind "
        .. "instruments.\"","SIN ch.VIII"},
      {"Three bodies of strings","A concertino of first violin, second violin and "
        .. "solo 'cello; a concerto grosso of 8+8 violins, 6 violas, 4-6 'cellos and "
        .. "4 basses; and a ripieno band of 6+6 violins, 4 violas, 3-4 'cellos and 3 "
        .. "basses to fill in harmonies and support the solos.","SIN p.190"},
      {"Contrabassoon","In use in his orchestra already.","SIN p.101"},
    }},
    {"What to take from him", {
      {"Terraced dynamics","He made \"great use of crescendo and diminuendo\" at a "
        .. "time when that was new; the effect came from adding and removing bodies of "
        .. "players, not from players swelling.","SIN ch.VIII; MOD"},
    }},
  },
  instruments={"flute","piccolo","cello","harp","trumpet","oboe","contrabassoon"},
  related={"composers","bach","harp","flute","strings"},
}

e{ id="rameau", name="Jean-Philippe Rameau", family="Composers", kind="composer",
  aliases={"rameau","jean philippe rameau","jean-philippe rameau"},
  summary="\"He gave to the different members of the Orchestra an individual role; he "
       .. "extended the technique of the violins; he made an increasing use of "
       .. "arpeggios; and he was the first to use pizzicato chords with all the strings "
       .. "at once. He also made a delicate and light use of the woodwind.\" Famous for "
       .. "\"the eloquence of his orchestral writing... with a feeling for colour that "
       .. "is altogether 'modern'\".",
  facts={ {"Dates","1683-1764"},
          {"Look at","Les Boreades, Hippolyte et Aricie, Castor et Pollux"} },
  sec={
    {"Favoured combinations", {
      {"Bassoon scales through a string texture","'The Entrance of Polymnie' from Les "
        .. "Boreades: the predominant string texture \"is shot through with descending "
        .. "scale figures on the bassoon, creating an exquisite blend of timbres\".","WP"},
      {"Two flutes + solo violin over sustained strings","'Rossignols amoureux' from "
        .. "Hippolyte et Aricie evokes lovelorn nightingales by blending two flutes "
        .. "with a solo violin while the rest of the violins sustain in the background.","WP"},
      {"Pizzicato chords across the whole string body","His innovation, and still a "
        .. "useful attack.","SIN p.166"},
    }},
    {"What to take from him", {
      {"Light woodwind, not thick","His woodwind use is \"delicate and light\" - a "
        .. "corrective if your wind writing has gone stodgy.","SIN p.166"},
    }},
  },
  instruments={"bassoon","flute","violin","pizzicato","woodwind"},
  related={"composers","gluck","bassoon","flute","pizzicato"},
}

e{ id="gluck", name="Christoph Willibald Gluck", family="Composers", kind="composer",
  aliases={"gluck","christoph gluck","christoph willibald gluck"},
  summary="\"Gluck gave the Orchestra a new life, assigning the first place to it in "
       .. "some cases, letting it express the feeling that captivates the listener. "
       .. "With him violins, oboes and trombones are not merely sonorous agents; they "
       .. "are living entities, personages of action... Gluck's great gift to the "
       .. "Orchestra was to make it speak.\"",
  facts={ {"Dates","1714-1787"}, {"Look at","Orfeo ed Euridice, Alceste, Armide, "
          .. "Iphigenie en Tauride"} },
  sec={
    {"What he added and removed", {
      {"Out went the harpsichord","He removed the continuo keyboard from the "
        .. "orchestra - the single change that forced everything else to carry the "
        .. "harmony.","SIN ch.VIII"},
      {"In came harp and trombones","And he employed the clarinets, then new.","SIN ch.VIII"},
    }},
    {"Favoured combinations", {
      {"Oboe with flute, and oboe with violin","\"Perhaps the most beautiful use of "
        .. "the oboe in all music is in Gluck's opera of Orfeo, in which it plays an "
        .. "exquisite minuet with the flute and a beautiful ballet with the violin.\"","SIN p.88"},
      {"Flute alone in the Elysian Fields","\"Its pure and ethereal voice, heard in a "
        .. "solo of ravishing beauty, lifts us out of the everyday world.\"","SIN p.77-78"},
      {"Two stopped horns muting each other","Charon's conch in Alceste: two horns in "
        .. "D on middle C with both bells closed, so that \"the two instruments serve "
        .. "mutually as a sordino; and the sounds, interclashing, assume a distant "
        .. "accent and a cavernous quality of tone of the most strange and dramatic "
        .. "effect\" (Berlioz).","SIN p.105-106"},
      {"Double basses doubled with violas and ’cellos","For the howling of Cerberus "
        .. "in Orfeo - the first time anyone gave the double bass a characterising "
        .. "role.","SIN p.69"},
      {"Clarinet instead of flute for desolation","In Alceste's 'Ah, malgre moi' he had "
        .. "first written the ritornello for flute, then moved it to clarinet, finding "
        .. "the flute \"too weak and lacked the nobility necessary\".","SIN p.100"},
      {"Piccolo in unison, written in sixths","In the tempest of Iphigenie en Tauride, "
        .. "a fourth above the first violins, producing elevenths - \"the harshness of "
        .. "which is here of the very best effect\" (Berlioz).","SIN p.80"},
    }},
    {"Use sparingly", {
      {"His horn writing generally","\"The horn is of all orchestral instruments the "
        .. "one which Gluck wrote least well for\" (Berlioz) - the Charon effect being "
        .. "the exception.","SIN p.105"},
      {"And a warning from Rimsky-Korsakov","He thought Gluck's idiom \"too "
        .. "old-fashioned and strange to modern ears\" to serve as a model, however "
        .. "much he admired the man.","RK p.4"},
    }},
  },
  instruments={"oboe","flute","clarinet","horn","trombone","harp","doublebass","piccolo"},
  related={"composers","rameau","haydn","oboe","horn"},
}

e{ id="haydn", name="Joseph Haydn", family="Composers", kind="composer",
  aliases={"haydn","joseph haydn","papa haydn","franz joseph haydn"},
  summary="Called the Father of the Orchestra, and by Rimsky-Korsakov's reckoning the "
       .. "greatest of all masters of orchestration. He had what few composers ever "
       .. "have: a standing orchestra he could test ideas on the same afternoon he had "
       .. "them.",
  facts={ {"Dates","1732-1809"},
          {"His orchestra","String quartet, 2 flutes, 2 oboes, 2 clarinets, 2 "
            .. "bassoons, 2 horns, 2 trumpets and kettledrums"},
          {"Look at","Symphonies 94 (Surprise), 97, 100 (Military), The Creation"} },
  sec={
    {"Favoured combinations", {
      {"Kettledrums and trumpets pianissimo","The minuet of Symphony 97 renders a "
        .. "German dance band \"with the utmost refinement, amazingly by kettledrums "
        .. "and trumpets pianissimo\", the rustic glissando given \"a finicky elegance "
        .. "by the grace notes in the horns\".","WP"},
      {"Melody doubled an octave up by a solo violin","In the same movement - and "
        .. "these details \"are not intended to blend, but to be set in relief; they "
        .. "are individually exquisite\".","WP"},
      {"Oboes and bassoons over sustained strings","The close of Symphony 94's second "
        .. "movement: oboes and bassoons take the theme while the strings accompany "
        .. "with \"soft, but very dissonant harmony\", flute, horns and timpani added "
        .. "to the mix.","WP"},
      {"High bassoon as a principal voice","In the minuet of the Military Symphony a "
        .. "bassoon melody reaches the treble A - one of \"the most prominent voices of "
        .. "his orchestra\".","SIN p.96"},
      {"A trio for flutes","In The Creation.","SIN p.77"},
      {"Contrabassoon","Also in The Creation.","SIN p.101"},
    }},
    {"Characteristic instruments", {
      {"The kettledrums","\"His practical knowledge of the kettledrums made him very "
        .. "partial to them; and he was the first to give this instrument an "
        .. "individuality and artistic part in the Orchestra.\" He played them as a "
        .. "boy.","SIN p.200-201"},
      {"Percussion as an exception","The Military Symphony's big drum, triangle and "
        .. "cymbals were exceptional for him - and for the period.","SIN p.219"},
      {"Two horns as standard","He and Mozart \"generally called for two horns in "
        .. "their scores\" and were the first to write real music rather than fanfares "
        .. "for them.","SIN p.104"},
    }},
    {"What to take from him", {
      {"Know the instrument before you write the note","\"As soon as his imagination "
        .. "supplied him with a passage, a chord, or a single note, he immediately saw "
        .. "by what instrument it should be executed, in order to produce the most "
        .. "sonorous and agreeable effect.\" Where he was unsure, he called a rehearsal "
        .. "and had it played three ways.","SIN p.196"},
      {"Relief, not blend","Much of his best scoring sets a detail deliberately apart "
        .. "from the texture rather than folding it in.","WP"},
    }},
  },
  instruments={"timpani","bassoon","flute","horn","oboe","trumpet","contrabassoon",
               "triangle","cymbals","strings"},
  related={"composers","mozart","beethoven","timpani","bassoon"},
}

e{ id="mozart", name="Wolfgang Amadeus Mozart", family="Composers", kind="composer",
  aliases={"mozart","wolfgang mozart","wolfgang amadeus mozart","wa mozart"},
  summary="\"What did Mozart do towards the development of our modern Orchestra? The "
       .. "question is easily answered. Mozart gave the Orchestra tone-color.\" Before "
       .. "him a melody could go to almost any instrument; after him each instrument "
       .. "had to \"speak for itself and with its own true voice\".",
  facts={ {"Dates","1756-1791"},
          {"Look at","Symphonies 39, 40 and 41, Don Giovanni, Piano Concerto K482, "
            .. "Clarinet Concerto, Requiem"} },
  sec={
    {"Favoured combinations", {
      {"Strings answered by woodwind","The opening of Symphony 39 contains \"a "
        .. "charming dialogue between strings and woodwind\" - first and second violins "
        .. "weaving parallel lines a tenth apart over a double-bass pedal and a "
        .. "sustained horn octave, the wind answering two bars later against a spidery "
        .. "chromatic line in the 'cellos.","WP"},
      {"Clarinets and bassoons with the lower strings supplying the bass","The "
        .. "continuation of that passage.","WP"},
      {"Pizzicato ’cellos and basses under bowed violins and violas in thirds","A few "
        .. "bars later - the same material, a new colour.","WP"},
      {"Violins as the bass for solo clarinets","In the Piano Concerto K482: \"the "
        .. "unusual sound on the violins providing the bass for the solo clarinets. The "
        .. "simplicity of the sequence concentrates all our interest on "
        .. "tone-colour.\"","WP"},
      {"Antiphony between wind and strings","In the trio of Symphony 41's minuet, "
        .. "flute, bassoons and horn exchange phrases with the strings, the first violin "
        .. "doubled at the octave by the first oboe.","WP"},
      {"Horns and bassoon answering the full tutti","The opening of K482: two bars of "
        .. "tutti answered by horns and bassoon alone.","WP"},
      {"Basset horn with the voice","The obbligato to 'Non piu di fiori' in La Clemenza "
        .. "di Tito; two basset horns in the Requiem.","SIN p.101"},
      {"Flute and harp","He wrote a concerto for the pair.","SIN p.288"},
    }},
    {"Characteristic instruments", {
      {"The clarinet","\"Mozart was the first to appreciate the beauties and "
        .. "capabilities of the clarinet.\" His Symphony in E-flat is so full of it that "
        .. "it is called the Clarinet Symphony. On first hearing clarinets at Mannheim: "
        .. "\"Oh, if we only had clarinets! You cannot think what a splendid effect a "
        .. "symphony makes with flutes, oboes and clarinets!\"","SIN p.99 & p.212"},
      {"The viola","\"Mozart gave the viola its proper place in the Orchestra, making "
        .. "it something more than a large violin filling up a gap between soprano and "
        .. "bass.\" Listen to it under Zerlina's 'Vedrai carino'.","SIN p.49-50"},
      {"The bassoon","\"Until Mozart's time the bassoon was little else but an "
        .. "instrument for doubling the bass of the Strings; but Mozart did great things "
        .. "with it.\"","SIN p.96"},
      {"Trombones held in reserve","Kept out of Don Giovanni until the statue scene, so "
        .. "they arrive as a climax; also for the priests' march in The Magic Flute.","SIN p.115"},
    }},
    {"What to take from him", {
      {"Spacing","\"A meticulous attitude towards the spacing of chords\" - and a "
        .. "density that is \"part of his density of thought\".","WP"},
      {"Orchestrate the repeat differently","His habit of restating four bars with a "
        .. "fresh colour is the cheapest variety in orchestration and still the most "
        .. "effective.","WP; MOD"},
    }},

    {"Belkin’s verdict", {
      {"Study him after Mendelssohn, not before","\"Although he uses an orchestra "
        .. "smaller than Mendelssohn's, [he] has more complex and refined methods of part "
        .. "writing, and therefore should follow, rather than precede the latter.\"","BEL p.61"},
      {"Why his scoring stays fresh","\"Color is less the result of exotic timbres than "
        .. "of novelty in the context of the piece. Even a familiar timbre like an oboe "
        .. "can sound striking and novel, provided it has not been heard for a while. "
        .. "This is why Mozart's orchestration is always so fresh, despite its limited "
        .. "number of colors.\"","BEL p.33"},
      {"Heterophony in a tutti","The Figaro overture keeps a tutti \"light and "
        .. "transparent\" because upper winds and strings follow the same outline with "
        .. "different detail, rather than doubling literally.","BEL p.38"},
    }},
  },
  instruments={"clarinet","viola","bassoon","horn","flute","oboe","trombone","harp",
               "strings","pizzicato"},
  related={"composers","haydn","beethoven","clarinet","viola","bassoon"},
}

e{ id="beethoven", name="Ludwig van Beethoven", family="Composers", kind="composer",
  aliases={"beethoven","ludwig van beethoven","ludwig beethoven"},
  summary="He brought instrument after instrument forward into a soloist's role - and "
       .. "wrote for them so demandingly that players had to improve their technique to "
       .. "keep up. Rimsky-Korsakov admired the imagination and distrusted the "
       .. "technique.",
  facts={ {"Dates","1770-1827"},
          {"Look at","Symphonies 3, 5, 6, 9; Piano Concerto 5; Egmont and Leonore "
            .. "overtures"} },
  sec={
    {"Favoured combinations", {
      {"Violas + ’cellos carrying the melody","The Andante of the Fifth. \"The first "
        .. "critics who heard this Symphony noticed to their amazement that the "
        .. "violoncellos gained roundness and purity of tone from their association with "
        .. "the viola!\" Violas also sing with 'cellos and bassoons in the Egmont "
        .. "Overture.","SIN p.50"},
      {"’Cello + double bass alone","The opening of the Fifth's Scherzo as a solo for "
        .. "the two - \"the people who first heard such a strange innovation were aghast "
        .. "and horrified\".","SIN p.70"},
      {"Horns in unison with strings, over a bassoon pedal","The Emperor Concerto's "
        .. "second subject: horns legato on the tune, sustained bassoon pedal beneath, "
        .. "violins simultaneously playing an elaborated version, timpani and pizzicato "
        .. "lower strings adding colour. The same theme appears in five different "
        .. "orchestrations across the movement.","WP"},
      {"Bassoon against ’cellos and violins in unison","The opening of the Ninth's "
        .. "Finale - the theme in 'cellos and violins, accompanied by \"a long "
        .. "independent melody of the greatest ingenuity\" in the first bassoon.","SIN p.96-97"},
      {"Two bassoons working independently, then joining two clarinets","The First "
        .. "Symphony's slow movement and the trio's \"curious dialogue between strings "
        .. "and reeds\".","SIN p.96"},
      {"Bird calls by instrument","In the Pastoral: flute the nightingale, oboe the "
        .. "quail, two clarinets the cuckoo.","SIN p.99"},
      {"Extreme contrast bar by bar","The Scherzo of the Second: \"we have first the "
        .. "full orchestra, then a single violin, then two horns, then two violins, then "
        .. "the full orchestra again, all within the space of half-a-dozen bars\".","WP"},
    }},
    {"What he added", {
      {"Piccolo, trombones and contrabassoon","All three make their first appearance in "
        .. "his symphonies in the Fifth.","SIN p.229"},
      {"Three horns","The Eroica - \"perhaps the first appearance of three horns in the "
        .. "Orchestra\".","SIN p.220"},
      {"Timpani as a solo instrument","He changed only how they were tuned, and \"that "
        .. "made all the difference in the world\": a minor sixth in the Seventh's "
        .. "Scherzo, octaves in the Ninth's finale, the dominant rather than the tonic in "
        .. "the First.","SIN p.120 & p.219"},
      {"The double bass as a voice","In the Ninth he uses it with the viola \"as a kind "
        .. "of bridge leading from the sounds of instruments to human voices\".","SIN p.70"},
    }},
    {"Use sparingly", {
      {"Don’t copy his brass or horn intervals","Rimsky-Korsakov: \"His use of the "
        .. "trumpets, standing out above the rest of the orchestra, the difficult and "
        .. "unhappy intervals he gives to the horns, the distinctive features of the "
        .. "string parts and his often highly-coloured employment of the wood-wind - "
        .. "these features will combine causing the student of Beethoven to stumble upon "
        .. "a thousand and one points in contradiction.\"","RK p.4"},
    }},

    {"Belkin’s verdict", {
      {"Fifth in the study order","\"Introduces many novel orchestral ideas, and, "
        .. "properly understood, his approach to the orchestra will greatly increase the "
        .. "student's sophistication.\" A milder view than Rimsky-Korsakov's.","BEL p.61"},
      {"The textbook orchestral crescendo","The Ninth's opening: \"the magnificent "
        .. "crescendo is achieved by gradually adding instruments: violin 1, double bass, "
        .. "viola, clarinet, oboe, flute, bassoon\".","BEL p.27"},
      {"The soft tutti","The Ninth's first movement, bar 469 - Belkin's example of a "
        .. "quiet tutti sounding \"like a great power restrained\".","BEL p.49"},
      {"Counterpoint kept in one family","The Seventh's second movement puts all the "
        .. "counterpoint in the strings - the simplest way to balance "
        .. "polyphony.","BEL p.47"},
    }},
  },
  instruments={"viola","cello","doublebass","bassoon","timpani","horn","piccolo",
               "trombone","contrabassoon","clarinet","flute","oboe"},
  related={"composers","mozart","haydn","weber","viola","timpani","bassoon"},
}

e{ id="weber", name="Carl Maria von Weber", family="Composers", kind="composer",
  aliases={"weber","carl maria von weber","von weber","carl weber"},
  summary="\"Weber's instrumentation was founded on Beethoven's. He introduced no new "
       .. "instruments. What he did was to develop the woodwind and make new and lovely "
       .. "combinations.\" He is also, by Berlioz's reckoning and everyone else's, the "
       .. "composer of the horn - and \"the composer, par excellence, of the clarinet\".",
  facts={ {"Dates","1786-1826"},
          {"Look at","Der Freischutz, Oberon, Euryanthe"} },
  sec={
    {"Favoured combinations", {
      {"Four horns as a forest","The introduction to the Der Freischutz overture - \"an "
        .. "exquisite introduction for four horns, descriptive of the forest\". In "
        .. "Preciosa he calls for eight.","SIN p.104 & p.109"},
      {"Two piccolos in thirds","\"Everyone has remarked the diabolic sneer of the two "
        .. "piccolo flutes in thirds in the drinking-song of Freischutz. It is one of "
        .. "Weber's happiest orchestral inventions\" (Berlioz).","SIN p.81"},
      {"Clarinet over a string tremolo","\"The dreamy phrase of the clarinet accompanied "
        .. "by a tremolo of stringed instruments in the midst of the Allegro of the "
        .. "Overture to Freischutz\" - Berlioz's chosen example of the clarinet's power "
        .. "to produce distance and twilight.","SIN p.99"},
      {"Clarinet arpeggios with flute","The \"drops of water\" figures.","SIN p.100"},
      {"Low clarinet for terror","\"It was reserved for Weber to discover all that there "
        .. "is of the terrible in the quality of tone of these low sounds.\"","SIN p.100"},
    }},
    {"What to take from him", {
      {"The horn as a character, not a section","Berlioz: \"No master, in my opinion, has "
        .. "ever known how to avail himself of its powers more originally, more "
        .. "poetically, and, at the same time, more completely than Weber. In his three "
        .. "finest works - Oberon, Euryanthe and Freischutz - he causes the horn to speak "
        .. "a language as admirable as it is novel.\"","SIN p.105"},
      {"Learn the instrument from its player","Weber toured with the clarinettist "
        .. "Baermann and \"learned much from the latter about the resources of this "
        .. "instrument\".","SIN ch.VIII"},
      {"And Rimsky-Korsakov’s endorsement","Weber heads his list of the composers a "
        .. "student should actually study for scoring.","RK p.4"},
    }},
  },
  instruments={"horn","clarinet","piccolo","flute","woodwind","strings"},
  related={"composers","beethoven","mendelssohn","horn","clarinet","piccolo"},
}

e{ id="schubert", name="Franz Schubert", family="Composers", kind="composer",
  aliases={"schubert","franz schubert"},
  summary="\"Schubert's gift to the Orchestra was his novel way of writing for the "
       .. "trombones and for his use of the woodwind. He gave a conversational treatment "
       .. "of oboe, flute and clarinet.\"",
  facts={ {"Dates","1797-1828"},
          {"Look at","Symphony 8 (Unfinished), Symphony 9 in C (the Great)"} },
  sec={
    {"Favoured combinations", {
      {"Clarinet and oboe in unison","The Unfinished Symphony's famous unison "
        .. "clarinet-and-oboe melody - the standard counter-example to the modern warning "
        .. "against doubling those two.","MOD"},
      {"Two horns in unison, unaccompanied","The Symphony in C opens with eight bars for "
        .. "the pair.","SIN p.104"},
      {"Conversational woodwind","Oboe, flute and clarinet handing a line between them "
        .. "rather than doubling it.","SIN ch.VIII"},
      {"Oboe in the slow movement","\"Schubert uses it charmingly in the second movement "
        .. "of his Symphony in C-major.\"","SIN p.88"},
      {"Trombones used melodically","\"Schubert uses them strikingly in his Symphony in "
        .. "C.\"","SIN p.115"},
    }},
    {"His orchestra", {
      {"Symphony 5, without trumpets or drums","2 violins, viola, 'cello, double bass, "
        .. "one flute, 2 oboes, 2 bassoons, 2 horns - worth studying as a deliberately "
        .. "reduced palette.","SIN ch.VIII"},
      {"Symphony 9 in C","2 violins, viola, 'cello, double bass; 2 flutes, 2 oboes, 2 "
        .. "clarinets, 2 bassoons, 2 horns, 2 trumpets and drums.","SIN ch.VIII"},
    }},
  },
  instruments={"clarinet","oboe","horn","trombone","flute","woodwind"},
  related={"composers","beethoven","weber","clarinet","oboe","trombone"},
}

e{ id="mendelssohn", name="Felix Mendelssohn", family="Composers", kind="composer",
  aliases={"mendelssohn","felix mendelssohn","mendelsohn"},
  summary="\"Mendelssohn's orchestration is noted for its perfect balance, its clarity "
       .. "and its polish. He seems to have cared less for the brass than the other "
       .. "groups.\" The model to study if your scoring is muddy.",
  facts={ {"Dates","1809-1847"},
          {"Look at","A Midsummer Night's Dream, Hebrides Overture, Elijah, Violin "
            .. "Concerto, Scotch Symphony"} },
  sec={
    {"Favoured combinations", {
      {"Horns in soft close harmony","The Nocturne of A Midsummer Night's Dream - \"a "
        .. "most poetic and dreamy use\". The overture's opening chords are \"the horns of "
        .. "Elfland faintly blowing\".","SIN p.104 & p.6"},
      {"Sustained flute chords","In the Midsummer Night's Dream overture, with a "
        .. "celebrated flute passage in the Scherzo.","SIN p.77"},
      {"Two bassoons in thirds, comically","The Clown's March in the same work; and the "
        .. "Funeral March imitates \"a small country band, consisting of clarinet and "
        .. "bassoon, the latter ending unexpectedly and humorously on a solitary low "
        .. "C\".","SIN p.97"},
      {"Bassoon with trombones","\"The grand chords of the Overture to Ruy Blas\"; and he "
        .. "used the bassoon's low register at the opening of the Scotch Symphony.","SIN p.97"},
      {"Clarinet for water","\"Mendelssohn also used the clarinet for the idea of water. "
        .. "It is very evident in the Hebrides Overture and in the Overture of Melusine it "
        .. "suggests the rolling waves.\"","SIN p.100"},
      {"’Cello obbligato with a solo voice","\"It is Enough\" in Elijah - finer even than "
        .. "the solo in Saint Paul.","SIN p.58-59"},
      {"Flute obbligato in a vocal quartet","\"O Rest in the Lord\" in Elijah.","SIN p.77"},
      {"Contrabassoon","In the Hebrides Overture.","SIN p.101"},
    }},
    {"What to take from him", {
      {"Balance first","Clarity and polish are his subject. If a passage of yours does "
        .. "not come through, the fault is usually spacing and doubling, not choice of "
        .. "instrument - and he is the clearest demonstration of that.","SIN ch.VIII; MOD"},
      {"Rimsky-Korsakov’s endorsement","Another of the handful he names as a model for "
        .. "students of scoring.","RK p.4"},
    }},

    {"Belkin’s verdict", {
      {"Where to start","\"An excellent starting point\" for learning orchestration "
        .. "from the repertoire: \"classical in spirit, economical, simple, and always "
        .. "effective\", with straightforward part-writing, perfectly balanced "
        .. "orchestration, and \"figuration imaginative without being overly "
        .. "elaborate\".","BEL p.60"},
    }},
  },
  instruments={"horn","flute","clarinet","bassoon","cello","violin","contrabassoon"},
  related={"composers","weber","schubert","horn","flute","clarinet","balance"},
}

e{ id="berlioz", name="Hector Berlioz", family="Composers", kind="composer",
  aliases={"berlioz","hector berlioz"},
  summary="\"The Father of Modern Orchestration\", and the first composer for whom "
       .. "orchestration \"was intrinsic to composition, not something applied to "
       .. "finished music\". He wrote the Treatise on Instrumentation that every later "
       .. "author, including Rimsky-Korsakov, argues with.",
  facts={ {"Dates","1803-1869"},
          {"Look at","Symphonie fantastique, Romeo et Juliette, Harold en Italie, "
            .. "La Damnation de Faust, L'Enfance du Christ"} },
  sec={
    {"What he discovered", {
      {"Pianissimo brass","He \"discovered the value of pianissimo brass effects\" - a "
        .. "colour the earlier orchestra had barely used.","SIN p.247"},
      {"Divided violins","\"The ethereal charm of harmonies on divided violins\", and he "
        .. "divided the strings into many parts.","SIN p.247"},
      {"The viola","\"He discovered the true worth of the viola\" and wrote Harold en "
        .. "Italie around a solo one for Paganini's Stradivari.","SIN p.247 & p.50"},
      {"The harp in the symphony orchestra","His introduction.","SIN p.247"},
      {"Instruments grouped as families","\"He grouped instruments into families and got "
        .. "from them rich chords in different shades of the same tone-color\" - the "
        .. "principle Wagner then built on.","SIN p.247"},
      {"The tuba over the ophicleide","He advocated the swap.","SIN p.247"},
      {"The hidden orchestra","He advocated the sunken pit that Wagner built at "
        .. "Bayreuth.","SIN p.247"},
    }},
    {"Favoured combinations", {
      {"Timpani + double basses in thick low chords against muted brass","The opening of "
        .. "the March to the Scaffold - \"chords in close position in the low register of "
        .. "the double basses\", against snarling muted brass, which runs \"counter to the "
        .. "rules of composition in general\".","WP"},
      {"Low clarinet + high harps + antique cymbals","The end of the Queen Mab scherzo: "
        .. "\"the sounds become more ethereal and fairylike... some of the most ethereally "
        .. "brilliant music ever penned\".","WP"},
      {"Two flutes and harp","The trio in L'Enfance du Christ; he also uses two flutes "
        .. "and harp for the Cris des Ismaelites.","SIN p.288 & p.78"},
      {"Three piccolos","In the Minuet of the Will o' the Wisps in La Damnation de "
        .. "Faust.","SIN p.81"},
      {"Piccolo for gilding","He liked the piccolo as ornamentation on the top of the "
        .. "woodwind - but condemned using it merely to sharpen the orchestra \"for the "
        .. "sake of noise only\" as \"a stupid method of instrumentation\".","SIN p.79-81"},
    }},
    {"What to take from him", {
      {"Orchestration is composition","\"In his hands timbre became something that could "
        .. "be used in free combinations, as an artist might use his palette, without "
        .. "bowing to the demands of line, and this leads to the rich orchestral resource "
        .. "of Debussy and Ravel\" (New Grove).","WP"},
      {"Delicacy, not just scale","Queen Mab is \"Berlioz's supreme exercise in light "
        .. "orchestral texture, a brilliant, gossamer fabric, prestissimo and pianissimo "
        .. "almost without pause\" - the answer to anyone who thinks him only a "
        .. "monster-orchestra man.","WP"},
    }},
  },
  instruments={"viola","harp","timpani","doublebass","clarinet","piccolo","flute",
               "cymbals","brass","strings"},
  related={"composers","wagner","liszt","viola","harp","strings_brass"},
}

e{ id="liszt", name="Franz Liszt", family="Composers", kind="composer",
  aliases={"liszt","franz liszt"},
  summary="\"In his orchestration Liszt followed Beethoven, Berlioz and Wagner. It is "
       .. "always rich and heavy and full of color. Liszt makes great use of the harp and "
       .. "his Hungarian blood shows itself in his marvellous and stirring rhythms.\"",
  facts={ {"Dates","1811-1886"},
          {"Look at","Mazeppa, Hungarian Rhapsodies, Piano Concerto in E-flat"} },
  sec={
    {"Favoured combinations", {
      {"The harp, everywhere","\"Liszt treats the harp most poetically; and it occurs in "
        .. "almost all of his works.\"","SIN p.288"},
      {"Triangle as a near-soloist","\"Liszt made almost a solo part for this instrument "
        .. "in the accompaniment to his Concerto for the Pianoforte in E-flat.\"","SIN p.124"},
      {"Bass clarinet","\"Liszt has a good part for it in his Mazeppa.\"","SIN p.101"},
      {"Flute in the foreground","Conspicuous in the Hungarian Rhapsody No. 2.","SIN p.78"},
      {"Col legno strings","He calls for it in Mazeppa.","SIN p.15"},
    }},
    {"What to take from him", {
      {"Rimsky-Korsakov’s endorsement","Named among the best guides for a student of "
        .. "scoring.","RK p.4"},
    }},
  },
  instruments={"harp","triangle","bassclarinet","flute","strings"},
  related={"composers","berlioz","wagner","harp","triangle"},
}

e{ id="wagner", name="Richard Wagner", family="Composers", kind="composer",
  aliases={"wagner","richard wagner"},
  summary="\"Wagner is the greatest master of orchestration that the world has ever "
       .. "seen.\" His governing idea was to complete each family of wind so that every "
       .. "group could produce full chords in its own timbre, without mixture unless he "
       .. "chose - and then to move his themes around those pure colours.",
  facts={ {"Dates","1813-1883"},
          {"Look at","Lohengrin, Tristan und Isolde, Die Meistersinger, the Ring, "
            .. "Parsifal"} },
  sec={
    {"His organising principle", {
      {"Complete each family for full chords","\"Wagner rarely employs instruments "
        .. "unknown to Beethoven, but he completes each group or family of wind-instruments "
        .. "with a view to getting full chords from each group.\" Two clarinets become "
        .. "three plus a bass clarinet; two oboes become three plus a cor anglais; two "
        .. "bassoons become three plus a contrabassoon; two trumpets become three plus a "
        .. "bass trumpet.","SIN ch.VIII"},
      {"Then keep the timbres unmixed","\"Each set of instruments can thus produce "
        .. "complete chords and can be employed in full harmony without mixture of "
        .. "timbre unless the composer so chooses.\"","SIN ch.VIII"},
      {"Simple methods, large forces","\"Notwithstanding the large number of performers "
        .. "he requires, he never has recourse to complicated methods in his "
        .. "orchestration. The combinations are always clear and simple, resulting in a "
        .. "sonority that is both plain and powerful.\"","SIN ch.VIII"},
      {"A theme, an instrument","The leitmotifs move all around the orchestra, \"but, "
        .. "nevertheless, each one has a fondness for one special instrument, or one group "
        .. "of instruments, which agrees with its character, on which it is first heard and "
        .. "to which it returns whenever it must be heard again with preponderating "
        .. "importance\".","SIN ch.VIII"},
    }},
    {"Favoured combinations", {
      {"Eight horns for moving water","The opening of Das Rheingold: to get \"the full, "
        .. "smooth wavelike motion upon the notes of a single chord\", two or four horns "
        .. "are not enough, so he takes eight.","SIN ch.VIII"},
      {"Thirteen brass, piano, for Walhalla","Trumpets, trombones and tuba supplemented by "
        .. "a bass trumpet, two tenor and two bass tubas, a contrabass trombone and a "
        .. "contrabass tuba - \"one of the simplest and noblest effects of sonority in "
        .. "existence\".","SIN ch.VIII"},
      {"Six harps for the rainbow bridge","One harp \"would appear trivial, or would "
        .. "hardly be audible against the full Orchestra\", so he writes six separate "
        .. "parts.","SIN ch.VIII"},
      {"Violins divided into four, five or eight","The Lohengrin prelude, in the high "
        .. "register, using harmonics on a long-held chord - \"it is undoubtedly an A major "
        .. "chord, but it is also high strings, harmonics, long notes\".","SIN p.49; WP"},
      {"A unison line shared out so you cannot name the instruments","The Parsifal prelude: "
        .. "\"the violins are halved, then doubled by the cellos, a clarinet, and a "
        .. "bassoon, as well as, for the peak of the phrase, an alto oboe [cor "
        .. "anglais]\".","WP"},
      {"’Cellos supported by wind","The opening phrase of the Tristan prelude; when it "
        .. "returns at the end, cor anglais and bass clarinet colour it, with the timpani "
        .. "rumbling beneath.","WP"},
      {"Six horns offstage and two in the pit","The hunting horns of Tristan Act II - "
        .. "\"faint far-away horns and their echoes ringing through the moonlight\". He "
        .. "called for sixteen hunting-horns in Tannhauser Act I.","SIN p.109"},
      {"Viola as the fiery voice","The Venusberg motive in the Tannhauser overture - "
        .. "Wagner \"was the first to exhibit the viola in such a role\".","SIN p.51"},
      {"Glockenspiel and triangle in fire music","The close of Die Walkure: the "
        .. "glockenspiel makes \"brilliant tips of light to the soaring plumes of flame\", "
        .. "the triangle \"vivid points of heat and light\". Arpeggiated wind chords against "
        .. "contrary-motion strings give \"an oscillation of tone-colours almost literally "
        .. "matching the visual flickering of the flames\".","SIN p.127; WP"},
      {"Two clarinets in duet for thirty bars","Act I scene 3 of Gotterdammerung.","SIN p.100"},
      {"Eighteen anvils in nine parts","Das Rheingold's Nibelungs, in three sizes.","SIN p.130"},
    }},
    {"What he added", {
      {"Wagner tubas and the bass trumpet","\"A family intermediate between horns and "
        .. "trumpets\" which \"singularly enriches the group of brasses without rendering "
        .. "his instrumentation any more noisy\". Four of his horn players switch to them.","SIN ch.VIII & p.118-119"},
    }},
    {"Use sparingly", {
      {"His extra low brass","Rimsky-Korsakov: the tenor and bass tubas and contrabass "
        .. "trombone of the Ring \"sometimes weigh too heavily on the other groups, and at "
        .. "other times they render the rest of the brass ineffective\" - Wagner himself "
        .. "dropped them for Parsifal.","RK p.22-23"},
      {"His vocal demands","Rimsky-Korsakov thought the Wagnerian voice types asked "
        .. "\"something little short of the miraculous\", and that singers who chase them "
        .. "lose \"correct intonation, beauty of tone, and all subtlety of nuances\".","RK p.138-139"},
    }},

    {"Belkin’s verdict", {
      {"Where advanced orchestration begins","\"More advanced orchestration begins with "
        .. "Wagner, in particular the richness of his orchestral polyphony as a norm, and "
        .. "the way he uses the enlarged orchestral families.\"","BEL p.61"},
      {"His tutti method","The Meistersinger prelude: each family has independent "
        .. "part-writing, the winds starting by doubling the violins and \"by m. 7 they "
        .. "are already adding details of their own\".","BEL p.50"},
    }},
  },
  instruments={"horn","tuba","trumpet","trombone","harp","viola","cello","clarinet",
               "bassclarinet","englishhorn","glockenspiel","triangle","strings","brass"},
  related={"composers","berlioz","strauss","mahler","horn","tuba","harp","brass"},
}

e{ id="verdi", name="Giuseppe Verdi", family="Composers", kind="composer",
  aliases={"verdi","giuseppe verdi"},
  summary="An orchestrator of dramatic economy: he reaches for an instrument because a "
       .. "character needs it, not to fill the texture.",
  facts={ {"Dates","1813-1901"}, {"Look at","Otello, Falstaff, Il Trovatore, Requiem"} },
  sec={
    {"Favoured combinations", {
      {"Double bass as a murderer’s voice","Otello's entrance into Desdemona's chamber - "
        .. "\"here the double-bass darkly and wickedly mutters all that is in Otello's "
        .. "savage heart and tells us just what he means to do\". He considered the "
        .. "instrument \"a dark, morbid personality, particularly fitted for tragedy\".","SIN p.69-70"},
      {"Piccolo in a drinking song","Iago's, in Otello.","SIN p.81"},
      {"Anvils","The Anvil Chorus in Il Trovatore, played on steel bars rather than real "
        .. "anvils.","SIN p.130"},
      {"A bell offstage","The prison bell in Il Trovatore.","SIN p.130"},
    }},
  },
  instruments={"doublebass","piccolo","percussion","bells"},
  related={"composers","wagner","doublebass","percussion"},
}

e{ id="brahms", name="Johannes Brahms", family="Composers", kind="composer",
  aliases={"brahms","johannes brahms"},
  summary="The great test case for whether orchestral colour is the point of "
       .. "orchestration. Rimsky-Korsakov's verdict is worth having in full: \"Was Brahms "
       .. "ignorant of orchestration? And yet, nowhere in his works do we find evidence "
       .. "of brilliant tone or picturesque fancy. The truth is that his thoughts did not "
       .. "turn towards colour; his mind did not exact it.\"",
  facts={ {"Dates","1833-1897"}, {"Look at","Symphony 1 in C minor, Symphony 4, "
          .. "Violin Concerto, Variations on a Theme by Haydn"} },
  sec={
    {"Characteristic instruments", {
      {"Bassoon","\"Brahms shows it off well in his C-minor Symphony.\"","SIN p.97"},
      {"Contrabassoon","Also in the C-minor Symphony - one of the works that brought the "
        .. "instrument back after its post-Beethoven neglect.","SIN p.101"},
    }},
    {"What to take from him", {
      {"Colour is optional; sound is not","\"More than one classical and modern composer "
        .. "has lacked the capacity to orchestrate with imagination and power; the secret "
        .. "of colour has remained outside the range of his creative faculty. Does it "
        .. "follow that these composers do not know how to orchestrate? Many among them "
        .. "have had greater knowledge of the subject than the mere colourist.\"","RK p.2"},
      {"The underlying lesson","Rimsky-Korsakov's companion point: \"unsatisfactory "
        .. "resonance is often solely the outcome of faulty handling of parts, and such a "
        .. "composition will continue to sound badly whatever choice of instruments is "
        .. "made\". Brahms is proof that sound part-writing carries a score without "
        .. "colour; the reverse is not true.","RK p.63"},
    }},
  },
  instruments={"bassoon","contrabassoon","horn","strings"},
  related={"composers","balance","doubling","bassoon"},
}

e{ id="glinka", name="Mikhail Glinka", family="Composers", kind="composer",
  aliases={"glinka","mikhail glinka","michael glinka"},
  summary="The father of the Russian school, and the composer Rimsky-Korsakov names "
       .. "among the handful worth studying for scoring. Notable for refusing to pad his "
       .. "orchestra with extra players.",
  facts={ {"Dates","1804-1857"}, {"Look at","A Life for the Tsar, Rousslan and Ludmilla"} },
  sec={
    {"Habits worth noting", {
      {"No extras","Where Meyerbeer freely added extra players for short stretches, "
        .. "\"other composers, Glinka for example, refrain from increasing the number of "
        .. "performers by employing extras\" - the English horn part in Rousslan is taken "
        .. "by an existing player.","RK p.14"},
      {"Piano in the orchestra","He used it with the harp to imitate the guzli, a popular "
        .. "plucked instrument - the beginning of a Russian habit.","RK p.30"},
      {"Stage bands","One of the composers who put brass, or brass and woodwind, on the "
        .. "stage itself in the mid-19th century.","RK p.129"},
    }},
    {"What to take from him", {
      {"Rimsky-Korsakov’s endorsement","Named alongside Weber, Mendelssohn, Berlioz, "
        .. "Wagner and Liszt as the best guides for a student of orchestration.","RK p.4"},
    }},
  },
  instruments={"piano","harp","englishhorn","brass"},
  related={"composers","rimskykorsakov","mussorgsky","piano","harp"},
}

e{ id="rimskykorsakov", name="Nikolay Rimsky-Korsakov", family="Composers", kind="composer",
  aliases={"rimsky korsakov","rimsky-korsakov","rimsky","korsakov","nikolay rimsky korsakov",
           "rimskykorsakov"},
  summary="The author of this encyclopaedia's principal source, and its most consistent "
       .. "practitioner - nearly every combination recommended in these pages is "
       .. "illustrated from his own scores. His own summary of his method: obtain a new "
       .. "timbre of definite colour, strengthen the strings, soften the woodwind.",
  facts={ {"Dates","1844-1908"},
          {"Look at","Sheherazade, Capriccio espagnol, Russian Easter Festival Overture, "
            .. "The Golden Cockerel, Sadko, Snegourotchka"},
          {"His own formations","Mlada alone uses woodwind in fours; Sadko, Tsar Saltan, "
            .. "Kitesh, The Golden Cockerel and Ivan the Terrible use threes; the rest "
            .. "pairs with extras"} },
  sec={
    {"Favoured combinations", {
      {"Violas + ’cellos + English horn","His signature warm middle voice, returned to "
        .. "again and again in Snegourotchka - and he notes that \"the addition of the Eng. "
        .. "horn makes no essential difference to the compound tone; the 'cellos stand out "
        .. "above the rest\".","RK p.39"},
      {"Violins + ’cellos + English horn","The same melody, fuller: \"the Eng. horn is "
        .. "absorbed in the musical texture, the principal colour being that of the "
        .. "'cellos. Still more powerful in resonance.\"","RK p.40"},
      {"Violas + English horn","A favourite for short characteristic phrases, in Sadko "
        .. "and Sheherazade.","RK p.59"},
      {"Stopped horns + oboes and English horn","Muted brass approaching the reeds in "
        .. "quality: 2 oboes + English horn + 3 muted trumpets, or 3 stopped horns under "
        .. "oboes and English horn.","RK p.89 & p.93"},
      {"2 horns + tuba on the bass, trombones above","His own preferred heavy brass "
        .. "layout: \"I have often adopted the following combination of brass instruments, "
        .. "and consider it eminently satisfactory.\"","RK p.83"},
      {"Alto trumpet with two ordinary trumpets","His own invention, first used in Mlada: "
        .. "the three \"produce greater smoothness and equality in resonance than three "
        .. "ordinary trumpets\".","RK p.23"},
      {"Harp + glockenspiel + piccolo far above a single bass","Snegourotchka - a figure "
        .. "four octaves clear of the bass, with flutes filling the gap. \"The general "
        .. "effect is fanciful.\"","RK p.106-107"},
      {"Two solo violins above the section","A single desk or two carrying the top octave "
        .. "while the rest play below, so the highest notes lose their piercing "
        .. "quality.","RK p.42 & p.106"},
    }},
    {"What to take from him", {
      {"Economy","\"Neither musical feeling nor the ear itself can stand, for long, the "
        .. "full resources of the orchestra combined together.\" And: \"the constant use of "
        .. "compound timbres... produces a dull, neutral texture, whereas the employment of "
        .. "simple, elementary combinations gives infinitely greater scope for variety in "
        .. "colour.\"","RK p.118 & p.35"},
      {"His three axioms","\"In the orchestra there is no such thing as ugly quality of "
        .. "tone.\" \"Orchestral writing should be easy to play.\" \"A work should be "
        .. "written for the size of orchestra that is to perform it.\"","RK p.3"},
      {"And his warning","\"To orchestrate is to create, and this is something which "
        .. "cannot be taught... The power of subtle orchestration is a secret impossible to "
        .. "transmit, and the composer who possesses this secret should value it highly, and "
        .. "never debase it to the level of a mere collection of formulae learned by "
        .. "heart.\"","RK p.1-2"},
    }},
    {"His own admitted mistakes", {
      {"Two he pointed out himself","Tsar Saltan [[220]] bar 7 - the brass theme is not "
        .. "prominent enough because the trombones are tacet. The Golden Cockerel [[233]] "
        .. "bars 10-14 - if the brass dynamics are observed, the viola and 'cello "
        .. "counter-melody will hardly be heard.","RK p.x (Steinberg's preface)"},
    }},
  },
  instruments={"englishhorn","viola","cello","horn","trumpet","tuba","trombone","harp",
               "glockenspiel","violin","strings","woodwind"},
  related={"composers","glinka","mussorgsky","englishhorn","viola","blend","doubling"},
}

e{ id="mussorgsky", name="Modest Mussorgsky", family="Composers", kind="composer",
  aliases={"mussorgsky","moussorgsky","modest mussorgsky","musorgsky"},
  summary="Studied less for his own orchestration than for what others made of it - his "
       .. "scores are the most-reorchestrated in the repertoire, which makes them an "
       .. "unusually direct lesson in how much the choice of instruments changes.",
  facts={ {"Dates","1839-1881"}, {"Look at","Boris Godunov, Khovanshchina, Pictures at "
          .. "an Exhibition (in Ravel's orchestration)"} },
  sec={
    {"Why he is useful to study", {
      {"The same music, two orchestrations","Ravel's orchestration of Pictures at an "
        .. "Exhibition - a solo piano work - is one of the two standard examples of "
        .. "orchestration as a separate art from composition.","WP"},
      {"Strings and brass, done well","Rimsky-Korsakov's editor singles out \"the "
        .. "introduction to the 2nd scene of the 4th act of Khovanstchina by Moussorgsky, "
        .. "orchestrated by Rimsky-Korsakov\" as a splendid example of combining the two "
        .. "groups - normally an awkward pairing.","RK p.95 n."},
      {"Piano in the orchestra","Boris Godunov is one of the two scores Rimsky-Korsakov's "
        .. "translator names as particularly interesting for orchestral piano.","RK p.30 n."},
    }},
    {"Use sparingly", {
      {"Orchestrating music never meant for orchestra","Rimsky-Korsakov's own view of the "
        .. "practice, despite doing it himself: \"to score a composition never intended for "
        .. "the orchestra is an undesirable practice... In any case this is the lowest form "
        .. "of instrumentation, akin to colour photography.\"","RK p.2"},
    }},
  },
  instruments={"piano","strings","brass"},
  related={"composers","rimskykorsakov","ravel","strings_brass","piano"},
}

e{ id="tchaikovsky", name="Pyotr Ilyich Tchaikovsky", family="Composers", kind="composer",
  aliases={"tchaikovsky","tschaikowsky","tchaikowsky","chaikovsky","pyotr tchaikovsky",
           "peter tchaikovsky"},
  summary="\"A remarkable feature of his scoring is the extreme modern effect secured "
       .. "with comparatively modest means.\" For the Pathetique he used the Beethoven "
       .. "orchestra plus a tuba - nothing more.",
  facts={ {"Dates","1840-1893"},
          {"Look at","Symphonies 4, 5 and 6; The Nutcracker; Romeo and Juliet; "
            .. "Francesca da Rimini; Marche Slave"} },
  sec={
    {"Favoured combinations", {
      {"Low woodwind with the violas","\"He made prominent use of low woodwind, which "
        .. "were constantly combined with the violas, and he evinced peculiar predilection "
        .. "for clarinets in their low range and bassoons in their upper range.\"","SIN ch.VIII"},
      {"Bassoon in unison with violas","\"In his Marche Slave it is very effective in "
        .. "unison with the violas.\"","SIN p.97"},
      {"Bassoon exposed","\"A notable example is in Tschaikowsky's Pathetic Symphony and "
        .. "in the waltz movement of his Fifth Symphony.\"","SIN p.97"},
      {"Clarinet solo","In Francesca da Rimini.","SIN p.100"},
      {"Celesta","He introduced it to the orchestra - famously in the Nutcracker's Dance "
        .. "of the Sugar Plum Fairy - and, with Strauss, gave it its popularity.","RK p.31; SIN p.128"},
      {"Bass clarinet","Conspicuous in the Danse de la Fee Dragee of the Nutcracker.","SIN p.101"},
      {"Flute in the foreground","\"An exceptionally striking use of the flute is in the "
        .. "Danse des Mirlitons and Danse Chinoise in the Nut-cracker Suite\"; he played "
        .. "the flute himself.","SIN p.78"},
      {"Oboe and clarinet in unison","He scores the pairing freely, in both harmony and "
        .. "melody, despite the common modern warning against it.","MOD"},
      {"Pizzicato scherzo","The Scherzo of his F-minor Symphony, following Beethoven's "
        .. "Fifth.","SIN p.15"},
    }},
    {"What to take from him", {
      {"Modest forces, modern effect","The lesson is that a distinctive orchestral voice "
        .. "comes from consistent choices of register and combination, not from adding "
        .. "instruments.","SIN ch.VIII; MOD"},
    }},

    {"Belkin’s verdict", {
      {"The second composer to study","\"A logical next step, similar in technique to "
        .. "Mendelssohn, but with a larger orchestra. Again, his orchestration is "
        .. "effective, clear, and easily understood.\"","BEL p.61"},
      {"His clarinet and oboe interlocking","Tchaikovsky's Fifth, first movement, is "
        .. "Belkin's example of clarinets and oboes \"interlocked for better blend, in a "
        .. "standard classical technique\".","BEL p.40"},
      {"His tutti method","The Fifth's finale gives each musical element to a distinct "
        .. "family: strings on the melody in octaves, horns and winds on two "
        .. "counterpoints, repeated notes in low brass and basses.","BEL p.51"},
    }},
  },
  instruments={"bassoon","clarinet","bassclarinet","viola","celesta","flute","tuba",
               "pizzicato","woodwind"},
  related={"composers","rimskykorsakov","celesta","bassoon","clarinet","viola"},
}

e{ id="saintsaens", name="Camille Saint-Saens", family="Composers", kind="composer",
  aliases={"saint saens","saint-saens","saintsaens","camille saint-saens","camille saint saens"},
  summary="\"The greatest name in the development of Orchestral music since Berlioz is "
       .. "that of Saint-Saens, whose orchestration, although rich and elaborate, is "
       .. "always clear and polished to the last degree.\"",
  facts={ {"Dates","1835-1921"}, {"Look at","Le Rouet d'Omphale, Danse Macabre, Samson "
          .. "et Dalila, Carnival of the Animals"} },
  sec={
    {"Favoured combinations", {
      {"Xylophone as bones","Danse Macabre - \"in which it represents the clattering of "
        .. "the bones of the dancing skeletons\". The xylophone is \"only suited to "
        .. "grotesque music\", and this is the defining example.","SIN p.129"},
      {"Harp instead of a bell","The midnight chime in Danse Macabre is twelve notes "
        .. "plucked on the harp - a lesson in suggesting an instrument you have not "
        .. "got.","SIN p.131"},
      {"Col legno strings","Also in Danse Macabre.","SIN p.15"},
      {"Castanets","In Samson et Dalila.","SIN p.126"},
    }},
    {"What to take from him", {
      {"Rich but clear","His example is that elaborate scoring and transparency are not "
        .. "opposites; Le Rouet d'Omphale \"is not merely a beautiful piece of descriptive "
        .. "writing, but it is beautifully scored\".","SIN ch.VIII"},
    }},
  },
  instruments={"xylophone","harp","castanets","strings"},
  related={"composers","berlioz","debussy","xylophone","harp"},
}

e{ id="dvorak", name="Antonin Dvorak", family="Composers", kind="composer",
  aliases={"dvorak","antonin dvorak","dvorzak"},
  summary="Best known orchestrally for one of the repertoire's most famous solo "
       .. "wind-and-strings combinations.",
  facts={ {"Dates","1841-1904"}, {"Look at","Symphony 9 (From the New World), "
          .. "'Cello Concerto"} },
  sec={
    {"Favoured combinations", {
      {"English horn over muted strings","The Largo of the New World Symphony - \"having "
        .. "a melody in the Largo with accompaniment of strings con sordini\". The "
        .. "reference case for the instrument.","SIN p.90"},
      {"Flute with oboe","\"It is important in the Largo of Dvorak's New World Symphony, "
        .. "where it plays with the oboe.\"","SIN p.78"},
      {"Clarinet","Also conspicuous in the New World.","SIN p.100"},
    }},
  },
  instruments={"englishhorn","flute","oboe","clarinet","cello","strings"},
  related={"composers","englishhorn","strings_wind"},
}

e{ id="grieg", name="Edvard Grieg", family="Composers", kind="composer",
  aliases={"grieg","edvard grieg"},
  summary="A miniaturist's orchestration - small gestures, clearly coloured.",
  facts={ {"Dates","1843-1907"}, {"Look at","Peer Gynt suites, Piano Concerto"} },
  sec={
    {"Favoured combinations", {
      {"Solo flute as dawn","\"It sings in the Morning of Grieg's Peer Gynt Suite\" - a "
        .. "standard reference for the flute's pastoral character.","SIN p.78"},
    }},
  },
  instruments={"flute","strings","oboe"},
  related={"composers","flute"},
}

e{ id="mahler", name="Gustav Mahler", family="Composers", kind="composer",
  aliases={"mahler","gustav mahler"},
  summary="He expanded the orchestra not to get louder but to get more gradations. "
       .. "\"Mahler only occasionally required all his vast orchestra to play together, "
       .. "and his music was as often soft as loud. Its colours were continually shifting, "
       .. "blending or contrasting with each other.\"",
  facts={ {"Dates","1860-1911"},
          {"Symphony 2’s wind and brass","4 flutes, 4 oboes, 5 clarinets, 4 bassoons; "
            .. "10 horns, 8 trumpets, 4 trombones, tuba; 2 sets of timpani + 4 "
            .. "percussion, 2 harps, organ, strings"},
          {"Look at","Symphonies 2, 4, 5 and 9"} },
  sec={
    {"Favoured combinations", {
      {"Chamber groups inside a huge orchestra","His symphonic writing is characterised "
        .. "by \"massive tutti effects\" contrasted with \"chamber-music procedures\" "
        .. "(Adorno). In the first movement of the Fourth, only the opening bar is a full "
        .. "ensemble; the rest is small, highly differentiated groups.","WP"},
      {"Calibrated dynamics inside one chord","In that passage, the low harp note is "
        .. "marked forte, the clarinets mezzo-forte, the horns piano - three dynamics in "
        .. "one bar so that the balance comes out as intended.","WP"},
      {"A perfect fourth in two flutes","The closing bars of the Fourth's slow movement - "
        .. "\"an instance of inspired orchestration... the unusual spacing of the chord... "
        .. "and the placing of the perfect fourth in the two flutes. The effect is quite "
        .. "unexpected and magical\" (Walter Piston).","WP"},
    }},
    {"What to take from him", {
      {"Write the dynamics per instrument, not per bar","\"Mahler cared about the finest "
        .. "nuances of loudness and tempo and worked tirelessly to fix these details in his "
        .. "scores.\" His conductor's ear told him that balance is notated, not hoped "
        .. "for.","WP"},
      {"The purpose of a big orchestra","\"The rational basis of Mahler's orchestration "
        .. "was to enable us to comprehend his music by hearing precisely what was going "
        .. "on\" (Donald Mitchell). More instruments meant more distinguishable lines, not "
        .. "a thicker wall.","WP"},
    }},

    {"Belkin’s verdict", {
      {"Not for beginners","With Ravel, \"not suitable for beginners since their "
        .. "textures are often very rich and complex\".","BEL p.60"},
      {"Rate of change as character","In the Fourth's second movement the nervous "
        .. "character comes from \"the frequent, prominent, changes of timbre\" - and the "
        .. "third movement's calm \"results from remaining entirely within the string "
        .. "choir\".","BEL p.23"},
      {"Piece-meal doubling","In the Ninth, the first horn is an inner counterpoint, "
        .. "then doubles the 'cello, then the first trombone - creating a new line without "
        .. "adding polyphony.","BEL p.38"},
      {"Sustained chords rescue tutti counterpoint","The Fifth's third movement: "
        .. "\"vigorous, tutti counterpoint is drawn into a rich whole by the sustained "
        .. "trombone chords\".","BEL p.47"},
    }},
  },
  instruments={"harp","clarinet","horn","flute","percussion","woodwind","brass","strings"},
  related={"composers","wagner","strauss","balance","doubling","orchestra"},
}

e{ id="strauss", name="Richard Strauss", family="Composers", kind="composer",
  aliases={"strauss","richard strauss","r strauss"},
  summary="\"The greatest technical master of the Orchestra, making of it a vibrating "
       .. "dynamic machine, a humming mountain of fire.\" His method is to divide the "
       .. "instrumental choirs and set them against each other: \"his Orchestra flashes "
       .. "like a canvas of Monet\".",
  facts={ {"Dates","1864-1949"},
          {"Look at","Don Quixote, Till Eulenspiegel, Ein Heldenleben, Don Juan, "
            .. "Sinfonia Domestica, Also sprach Zarathustra"} },
  sec={
    {"Favoured combinations", {
      {"Instruments as characters","Don Quixote: the solo 'cello is the knight, the solo "
        .. "viola his squire. \"With great poetic judgment Strauss selected the violoncello "
        .. "and the viola as the most suitable instruments to convey these "
        .. "impressions.\"","SIN p.66"},
      {"Divided choirs in opposition","\"He intricately divides his various instrumental "
        .. "choirs: setting one group in opposition, or juxtaposition, to another; producing "
        .. "the most marvellous, unexpected effects by acoustical mirroring and transmutation "
        .. "of motives.\"","SIN ch.VIII"},
      {"Four horns on a four-part shake","In Till Eulenspiegel - \"a very peculiar way\" "
        .. "of using them.","SIN p.109"},
      {"Celesta","He and Tchaikovsky gave the instrument its popularity; in Sinfonia "
        .. "Domestica seven little taps on the glockenspiel tell the hour.","SIN p.128 & p.131"},
      {"Bass clarinet, bassoon, cor anglais as soloists","Bass clarinet conspicuous in Don "
        .. "Quixote; bassoon in Heldenleben, Till and Don Juan; cor anglais prominent in "
        .. "Heldenleben.","SIN p.101, p.97, p.90"},
      {"Wind machine and rattle","The Windmill adventure of Don Quixote uses the wind "
        .. "machine; Till Eulenspiegel uses the watchman's rattle.","SIN p.129"},
      {"Flutter tongue on the flute","Also the Windmill variation - \"a new way of rolling "
        .. "the tongue\", Strauss \"always goes a little farther than anybody else\".","SIN p.78"},
      {"Col legno strings","In Also sprach Zarathustra.","SIN p.15"},
    }},
    {"Use sparingly", {
      {"Five trumpets","Rimsky-Korsakov notes, with reserve, that \"some present-day "
        .. "composers (Richard Strauss, Scriabine) write for as many as five "
        .. "trumpets\".","RK p.22"},
    }},

    {"Belkin’s verdict", {
      {"For the advanced student only","Grouped with Ravel and Mahler as the last stage "
        .. "of study.","BEL p.61"},
      {"Several rising figures instead of one doubled line","Die Frau ohne Schatten, "
        .. "first act: \"a wispy image of a rising shadow is created by using several "
        .. "different rising figures simultaneously (combined with held notes for "
        .. "resonance)\".","BEL p.42"},
      {"The phrase he gave us","Writing of Wagner's polyphony, Strauss called for the "
        .. "\"spiritual participation of the players\" - which Belkin makes one of his "
        .. "criteria for good orchestration.","BEL p.36 & p.58"},
    }},
  },
  instruments={"cello","viola","horn","celesta","bassclarinet","bassoon","englishhorn",
               "flute","xylophone","percussion","strings"},
  related={"composers","wagner","mahler","cello","viola","celesta"},
}

e{ id="elgar", name="Edward Elgar", family="Composers", kind="composer",
  aliases={"elgar","edward elgar"},
  summary="An orchestrator of fine gradations - his scores are full of very specific "
       .. "instructions about how a sound is to be produced, not merely which instrument "
       .. "produces it.",
  facts={ {"Dates","1857-1934"}, {"Look at","Enigma Variations, Pomp and Circumstance "
          .. "marches, 'Cello Concerto, Symphony 1"} },
  sec={
    {"Favoured combinations", {
      {"Bassoon exposed","\"Elgar in his Pomp and Circumstance March and Variations III "
        .. "and IX of the Enigma.\"","SIN p.97"},
      {"Viola given real work","\"Elgar also gives the viola much to do in his "
        .. "works.\"","SIN p.51"},
      {"Street drumsticks on the timpani","His Variations call for ordinary street "
        .. "drumsticks rather than felt, \"for very fine crisp rolls\" - an example of "
        .. "specifying the stick, not just the note.","SIN p.121"},
    }},
    {"What to take from him", {
      {"Specify the means","Where a colour depends on how the sound is made - the stick, "
        .. "the bowing, the mute - write it in. The score is the only place the information "
        .. "survives.","MOD"},
    }},
  },
  instruments={"bassoon","viola","timpani","cello","strings"},
  related={"composers","timpani","bassoon","viola"},
}

e{ id="debussy", name="Claude Debussy", family="Composers", kind="composer",
  aliases={"debussy","claude debussy"},
  summary="\"One idea of Debussy's in orchestral writing is to get the greatest effect "
       .. "with the simplest means... His instrumentation, therefore, seems diaphanous, "
       .. "ethereal, and suffused with delicate, opalescent colors.\" Boulez thought his "
       .. "orchestration showed \"an infinitely fresher imagination\" than Strauss's or "
       .. "Mahler's.",
  facts={ {"Dates","1862-1918"},
          {"Faune’s orchestra","3 flutes, oboes, clarinets, 4 horns, 2 harps, antique "
            .. "cymbals and strings - no trumpets, trombones, tuba or timpani at all"},
          {"Look at","Prelude a l'apres-midi d'un faune, Nocturnes, La Mer, Jeux, "
            .. "Pelleas et Melisande"} },
  sec={
    {"Favoured combinations", {
      {"A chord split between oboes and clarinets, with a harp glissando","The opening of "
        .. "the Faune: a half-diminished seventh \"spread between oboes and clarinets, "
        .. "reinforced by a glissando on the harp\".","WP"},
      {"Unaccompanied flute","The Faune's opening bars - the most imitated gesture in "
        .. "French orchestration.","SIN p.270"},
      {"Harp varying the flute line","Later in the Faune, \"the first harp varies the "
        .. "flute parts in almost the same way that the smallest bells of a Javanese gamelan "
        .. "vary the slower basic melody\".","WP"},
      {"Harp doubling horns, with celesta","The opening of Jeux: divided strings spread "
        .. "wide, a harp doubling horns, \"with the addition of the bell-like celesta in the "
        .. "5th bar and the sultry voicing of the whole tone chords in the woodwind\".","WP"},
      {"Muted strings as a background to wind solos","\"The strings, muted or otherwise, "
        .. "are often used as a kind of background to the wind solos, which is most "
        .. "effective.\"","SIN ch.VIII"},
      {"Interspersed solos as embroidery","\"The interspersed solos for violin, oboe, "
        .. "clarinet, cor anglais, resemble dainty broidery.\"","SIN ch.VIII"},
      {"Antique cymbals","In the Faune - a rare, specific colour rather than a rhythm "
        .. "instrument.","SIN p.270"},
    }},
    {"What to take from him", {
      {"Leave instruments out","The Faune's power comes substantially from what is absent: "
        .. "no heavy brass, no timpani. Subtraction is an orchestration technique.","SIN p.270; MOD"},
      {"Timbre without glare","Of Jeux he wrote: \"I am thinking of that orchestral colour "
        .. "which seems to be illuminated from behind\" - \"to produce timbre without glare, "
        .. "subdued... but to do so with clarity and precision\".","WP"},
      {"The orchestra as atmosphere","In Pelleas \"the Orchestra did not annotate, nor "
        .. "emphasize the actions of the persons on the stage, but it became a soft, "
        .. "melodious atmosphere, a delicious web of harmony enfolding the entire work\".","SIN p.270"},
    }},
  },
  instruments={"flute","harp","celesta","oboe","clarinet","englishhorn","horn","cymbals",
               "strings"},
  related={"composers","ravel","saintsaens","flute","harp","strings"},
}

e{ id="ravel", name="Maurice Ravel", family="Composers", kind="composer",
  aliases={"ravel","maurice ravel"},
  summary="The orchestrator's orchestrator. Bolero is, in effect, eighteen "
       .. "orchestrations of one unchanging theme - the single most concentrated lesson in "
       .. "instrumental colour in the repertoire.",
  facts={ {"Dates","1875-1937"},
          {"Look at","Bolero, Daphnis et Chloe, Pictures at an Exhibition "
            .. "(orchestrating Mussorgsky), La Valse, Rapsodie espagnole"} },
  sec={
    {"Why he is the reference", {
      {"Bolero","\"A set of 18 variations on an original two-part theme - or perhaps, more "
        .. "properly speaking, 18 orchestrations of that theme, for the theme itself does "
        .. "not change, though the instruments do.\" It \"gradually introduces new timbres "
        .. "and textures at each iteration, employing different instrumental solos and "
        .. "combinations, thereby creating a kaleidoscope of sound\".","MOD"},
      {"Pictures at an Exhibition","His orchestration of Mussorgsky's piano work is one of "
        .. "the two standard examples of orchestration practised as an art distinct from "
        .. "composition.","WP"},
    }},
    {"What to take from him", {
      {"One idea, many colours","The Bolero method - restate without changing the notes and "
        .. "let the instrumentation carry the whole development - is directly usable, and is "
        .. "the extreme case of Rimsky-Korsakov's \"different ways of orchestrating the same "
        .. "music\".","MOD; cf. RK p.97"},
      {"The inheritance","New Grove traces the line: Berlioz's free use of timbre \"leads "
        .. "to the rich orchestral resource of Debussy and Ravel\".","WP"},
    }},

    {"Belkin’s verdict", {
      {"Not for beginners","\"Wonderful orchestrators though they are, [Mahler and "
        .. "Ravel] are not suitable for beginners since their textures are often very "
        .. "rich and complex.\"","BEL p.60"},
      {"The master of background resonance","The Epilogue of Valses nobles et "
        .. "sentimentales: held strings and harp harmonics give \"a shimmering halo "
        .. "surrounding the main motives in the winds. This conception of the background "
        .. "as delicate vibration is omnipresent in Ravel. Indeed, Ravel's orchestral "
        .. "technique is often most sophisticated in his treatment of such sustained "
        .. "sound in the background.\"","BEL p.33"},
      {"An organ-stop doubling in Bolero","A horn carrying the line is doubled by "
        .. "celesta in higher octaves and by two piccolos at a twelfth and two octaves "
        .. "plus a major third - \"very similar to a common organ combination (the "
        .. "'cornet'), which gives a rich, piercing sound\".","BEL p.38"},
    }},
  },
  instruments={"woodwind","brass","strings","harp","celesta","percussion"},
  related={"composers","debussy","mussorgsky","berlioz","doubling","blend"},
}

e{ id="stravinsky", name="Igor Stravinsky", family="Composers", kind="composer",
  aliases={"stravinsky","igor stravinsky","stravinski"},
  summary="He got new sounds not by adding instruments but by writing for familiar ones "
       .. "in unfamiliar places: \"He pushed them to the extreme heights and depths of "
       .. "their ranges. He put them in uncomfortable positions which resulted in that "
       .. "strained, weird quality he was looking for.\"",
  facts={ {"Dates","1882-1971"},
          {"Look at","The Rite of Spring, Petrushka, The Firebird, Symphony of Psalms"} },
  sec={
    {"Favoured methods", {
      {"Extreme registers as colour","The Rite opens with a bassoon at the very top of its "
        .. "compass - the classic case of choosing a register precisely because it strains. "
        .. "Compare Rimsky-Korsakov's more cautious view that the bassoon's high compass is "
        .. "\"tense\" and \"painful, distressed and dejected\": Stravinsky wanted exactly "
        .. "that.","MOD; cf. RK p.17 and SIN p.95"},
      {"Uncomfortable writing on purpose","The general principle - the strain is the "
        .. "sound.","MOD"},
    }},
    {"What he said about others", {
      {"On Bach","\"What incomparable instrumental writing is Bach's. You can smell the "
        .. "resin in his violin parts, and taste the reeds in the oboes.\"","WP"},
    }},
  },
  instruments={"bassoon","woodwind","brass","percussion","strings"},
  related={"composers","bach","bassoon","range","doubling"},
}

e{ id="holst", name="Gustav Holst", family="Composers", kind="composer",
  aliases={"holst","gustav holst"},
  summary="A large orchestra used for character rather than weight - each movement of The "
       .. "Planets is built on a distinct instrumental identity.",
  facts={ {"Dates","1874-1934"}, {"Look at","The Planets"} },
  sec={
    {"Favoured methods", {
      {"Broad strokes, simple material","\"The music is relatively simple, but the way that "
        .. "Holst manipulates, orchestrates and colours the themes make this movement "
        .. "incredibly exciting.\"","MOD"},
      {"Ostinato as the engine","In Mars, \"the repeating ostinato rhythm from the strings "
        .. "drives and dominates this whole movement\" - including its famous col legno "
        .. "attack.","MOD"},
      {"A big ensemble for colour, not volume","He used the large orchestra \"to create a "
        .. "sound world of astonishing color, power, and atmospheric depth\", influenced by "
        .. "Stravinsky and Schoenberg.","MOD"},
    }},
  },
  instruments={"strings","brass","woodwind","percussion"},
  related={"composers","stravinsky","percussion","strings"},
}

e{ id="shostakovich", name="Dmitri Shostakovich", family="Composers", kind="composer",
  aliases={"shostakovich","dmitri shostakovich","schostakowitsch"},
  summary="Orchestration as dramatic function: \"its orchestration is dense but clear, "
       .. "with each instrument having a specific dramatic function\".",
  facts={ {"Dates","1906-1975"}, {"Look at","Symphonies 5, 7, 10; Festive Overture"} },
  sec={
    {"Favoured methods", {
      {"Extreme dynamic contrast","\"Shostakovich's music uses extreme contrasts: "
        .. "whispering passages followed by brutal orchestral explosions.\"","MOD"},
      {"Trumpets and trombones as the voice of protest","\"Brass instruments play a leading "
        .. "role, especially trumpets and trombones, which 'shout out' repressed "
        .. "emotions.\"","MOD"},
      {"Solo winds against near-silence","The whispering end of the contrast - thin "
        .. "textures that make the explosions work.","MOD"},
    }},
  },
  instruments={"trumpet","trombone","brass","woodwind","strings","percussion"},
  related={"composers","mahler","brass","balance"},
}

e{ id="meyerbeer", name="Giacomo Meyerbeer", family="Composers", kind="composer",
  aliases={"meyerbeer","giacomo meyerbeer"},
  summary="A specialist in the striking effect, and the composer who normalised bringing "
       .. "in extra players for a single scene.",
  facts={ {"Dates","1791-1864"}, {"Look at","Robert le Diable, Les Huguenots, Le Prophete"} },
  sec={
    {"Favoured combinations", {
      {"A low bell with bassoons and clarinets","The signal for the massacre in Les "
        .. "Huguenots - a big bell in low F \"combined with bassoons and clarinets, which "
        .. "give the music a sinister quality that is very impressive\".","SIN p.130"},
      {"English horn obbligato with the voice","'Robert, toi que j'aime' in Robert le "
        .. "Diable.","SIN p.90"},
      {"Two double-action harps","He was the first to use the modern harp, calling for two "
        .. "in Robert le Diable.","SIN p.288"},
      {"Piccolo for the infernal and the martial","The infernal waltz in Robert le Diable; "
        .. "Marcel's \"Piff Paff\" in Les Huguenots.","SIN p.80"},
    }},
    {"Use sparingly", {
      {"Extras","\"Meyerbeer was fond of\" introducing extra players for a short period "
        .. "within a big work. Rimsky-Korsakov notes it without approving, contrasting "
        .. "Glinka's refusal to do the same.","RK p.14"},
    }},
    {"What to take from him", {
      {"Rimsky-Korsakov’s endorsement","Named - specifically for Le Prophete - among the "
        .. "scores a student should study.","RK p.4"},
    }},
  },
  instruments={"bells","bassoon","clarinet","englishhorn","harp","piccolo"},
  related={"composers","glinka","bells","harp","piccolo"},
}

e{ id="rossini", name="Gioachino Rossini", family="Composers", kind="composer",
  aliases={"rossini","gioachino rossini","gioacchino rossini"},
  summary="Notable orchestrally for a handful of famous solo and sectional openings.",
  facts={ {"Dates","1792-1868"}, {"Look at","Guillaume Tell, Stabat Mater, "
          .. "Il Barbiere di Siviglia"} },
  sec={
    {"Favoured combinations", {
      {"Five solo ’cellos","The Overture to William Tell opens with five solo "
        .. "violoncellos, accompanied by two more playing pizzicato in first and second "
        .. "parts.","SIN p.65"},
      {"English horn as a cowherd’s call","The \"Ranz des vaches\" in William Tell - "
        .. "originally written for the oboe da caccia and inherited by the cor anglais when "
        .. "that instrument became obsolete.","SIN p.90"},
      {"Bassoon opening","He opens the Stabat Mater with it.","SIN p.97"},
      {"A bell onstage","In Act II of Guillaume Tell.","SIN p.130"},
    }},
  },
  instruments={"cello","englishhorn","bassoon","bells","pizzicato"},
  related={"composers","cello","englishhorn"},
}

e{ id="humperdinck", name="Engelbert Humperdinck", family="Composers", kind="composer",
  aliases={"humperdinck","engelbert humperdinck"},
  summary="A Wagnerian technique turned to fairy-tale ends, and a good study in "
       .. "orchestral comedy.",
  facts={ {"Dates","1854-1921"}, {"Look at","Hansel und Gretel"} },
  sec={
    {"Favoured combinations", {
      {"Bassoon as comic commentator","\"Humperdinck makes comic use of it in Hansel and "
        .. "Gretel, where it frequently comments on what is happening on the stage.\"","SIN p.98"},
      {"The cuckoo","The toy instrument - two tiny wooden pipes on a bellows - appears in "
        .. "Hansel und Gretel, as in Haydn's Toy Symphony.","SIN p.130"},
    }},
  },
  instruments={"bassoon","percussion","woodwind"},
  related={"composers","bassoon","percussion"},
}

e{ id="delibes", name="Leo Delibes", family="Composers", kind="composer",
  aliases={"delibes","leo delibes","léo delibes"},
  summary="Ballet orchestration of exceptional clarity, and a model for writing character "
       .. "into a dance.",
  facts={ {"Dates","1836-1891"}, {"Look at","Coppelia, Sylvia, Lakme"} },
  sec={
    {"Favoured combinations", {
      {"Piccolo for the mechanical and grotesque","\"It is conspicuous in the grotesque "
        .. "dances of the dolls in the ballet of Coppelia.\"","SIN p.81"},
    }},
  },
  instruments={"piccolo","strings","woodwind"},
  related={"composers","piccolo"},
}

e{ id="bizet", name="Georges Bizet", family="Composers", kind="composer",
  aliases={"bizet","georges bizet"},
  summary="Bright, economical scoring with a strong taste for characteristic percussion "
       .. "and wind colour.",
  facts={ {"Dates","1838-1875"}, {"Look at","Carmen, L'Arlesienne suites"} },
  sec={
    {"Favoured combinations", {
      {"Ophicleide","He wrote for it in Carmen - one of the last composers to do so before "
        .. "the tuba displaced it.","SIN p.117"},
      {"Characteristic Spanish percussion","Carmen is the standard reference for "
        .. "tambourine and castanets used for local colour rather than rhythm alone.","MOD; cf. SIN p.126"},
    }},

    {"Belkin’s verdict", {
      {"The text for voices","\"Bizet's Carmen is a basic text for orchestration with "
        .. "voices.\"","BEL p.61"},
      {"A model of transparency","Carmen's first act: \"Short string chords accompany "
        .. "high violins in a light, triplet figure, and a simple woodwind counterpoint "
        .. "in half notes. The effect is rich but extremely transparent.\"","BEL p.57"},
    }},
  },
  instruments={"tuba","tambourine","castanets","flute","woodwind"},
  related={"composers","castanets","tambourine","percussion"},
}

-- ============================================================================
-- FILM COMPOSERS
-- ============================================================================

e{ id="steiner", name="Max Steiner", family="Film Composers", kind="composer",
  aliases={"steiner","max steiner"},
  summary="One of the emigre composers who invented the Hollywood orchestral sound out of "
       .. "Central European late Romanticism. \"Steiner's lush, emotionally direct style "
       .. "drew on late Romantic techniques, using large orchestras and unabashed sentiment "
       .. "to underscore dramatic moments.\"",
  facts={ {"Dates","1888-1971"}, {"Look at","King Kong, Gone with the Wind, Casablanca, "
          .. "Now, Voyager"} },
  sec={
    {"Favoured methods", {
      {"Late-Romantic full orchestra","Large string body, full wind and brass, used as a "
        .. "19th-century symphonist would - the reason a Golden Age score sounds like "
        .. "Wagner's grandchild.","FILM"},
      {"Leitmotif","Wagnerian theme-and-character association carried wholesale into "
        .. "film.","FILM"},
      {"Strings carrying the sentiment","The emotional weight sits in the strings, with wind "
        .. "and brass for colour and punctuation.","FILM"},
    }},
    {"What to take from him", {
      {"The pattern the rest inherited","Nearly every convention of orchestral film scoring "
        .. "- theme, orchestra, and the string section as the emotional centre - is his and "
        .. "his contemporaries'. Study him for the grammar, later composers for the "
        .. "vocabulary.","FILM; MOD"},
    }},
  },
  instruments={"strings","brass","woodwind","horn"},
  related={"composers","korngold","rozsa","wagner","strings"},
}

e{ id="korngold", name="Erich Wolfgang Korngold", family="Film Composers", kind="composer",
  aliases={"korngold","erich korngold","erich wolfgang korngold"},
  summary="A concert-hall prodigy who brought an intact late-Romantic technique to "
       .. "Hollywood: \"Korngold applied full Romantic orchestration, Wagnerian leitmotifs, "
       .. "and sophisticated harmonic language to his film scores.\"",
  facts={ {"Dates","1897-1957"}, {"Look at","The Adventures of Robin Hood, The Sea Hawk, "
          .. "Kings Row, Violin Concerto"} },
  sec={
    {"Favoured methods", {
      {"Full Romantic orchestra, opera technique","He scored films as he scored operas - "
        .. "which is literally what he called them.","FILM"},
      {"Heroic brass over running strings","The swashbuckler sound: horns and trumpets "
        .. "carrying the theme above busy string figuration.","FILM"},
      {"Sophisticated harmony under simple themes","The harmonic language does the work that "
        .. "a plainer scorer would ask the orchestration to do.","FILM"},
    }},
    {"What to take from him", {
      {"Reuse across media","His film scores fed his concert works and back again - the "
        .. "Violin Concerto is largely built from film material. Orchestral craft does not "
        .. "care which medium it was learnt in.","FILM"},
    }},
  },
  instruments={"horn","trumpet","strings","brass","woodwind","harp","celesta"},
  related={"composers","steiner","wagner","williams","horn","brass"},
}

e{ id="rozsa", name="Miklos Rozsa", family="Film Composers", kind="composer",
  aliases={"rozsa","miklos rozsa","miklós rózsa","rózsa"},
  summary="\"A more austere, intellectual approach while maintaining classical "
       .. "foundations\" than his Golden Age contemporaries - and the composer who put the "
       .. "theremin into the orchestra.",
  facts={ {"Dates","1907-1995"}, {"Look at","Spellbound, Ben-Hur, Double Indemnity, "
          .. "The Thief of Bagdad"} },
  sec={
    {"Favoured combinations", {
      {"Theremin with full orchestra","Spellbound was \"the first score to use a theremin "
        .. "supported by a full orchestra within a motion picture\", for the protagonist's "
        .. "phobia. Hitchcock had asked for \"a big sweeping love theme... and a 'new sound' "
        .. "for the paranoia\". It won the 1945 Oscar.","FILM"},
      {"Two themes, two sound worlds","The love theme in the orchestra, the phobia theme in "
        .. "the theremin - a clean demonstration of using instrumentation, not melody, to "
        .. "separate two ideas.","FILM"},
      {"Austere large-scale brass and chorus","Ben-Hur's processional writing.","FILM"},
    }},
    {"What to take from him", {
      {"One unfamiliar timbre goes a long way","A single strange instrument against a "
        .. "conventional orchestra reads far more strongly than a generally strange "
        .. "orchestra.","FILM; MOD"},
    }},
  },
  instruments={"strings","brass","woodwind","percussion"},
  related={"composers","steiner","korngold","herrmann","blend"},
}

e{ id="herrmann", name="Bernard Herrmann", family="Film Composers", kind="composer",
  aliases={"herrmann","bernard herrmann","bernard hermann","hermann","herman",
           "bernard herman"},
  summary="The most radical orchestrator in film music. He rarely wrote for the standard "
       .. "orchestra at all: he built a bespoke ensemble for each picture, frequently "
       .. "leaving out whole families. \"Herrmann's orchestrations were entirely original, "
       .. "daring and inventive; always appropriate for the context and subsequently "
       .. "incredibly influential in film scoring.\"",
  facts={ {"Dates","1911-1975"},
          {"Look at","Citizen Kane, The Day the Earth Stood Still, Vertigo, North by "
            .. "Northwest, Psycho, Fahrenheit 451, Taxi Driver"} },
  sec={
    {"His signature ensembles", {
      {"Psycho — strings only","Scored for string orchestra alone, to match Hitchcock's "
        .. "black-and-white photography with a \"black and white\" sound. The most famous "
        .. "single orchestration decision in film music.","FILM"},
      {"Journey to the Center of the Earth — no violins, five organs","Woodwind, brass, a "
        .. "large percussion ensemble, nine harps, and five organs (one pipe, four "
        .. "electronic).","FILM"},
      {"Torn Curtain — no strings at all","A large brass section including nine trombones, "
        .. "percussion, and twelve flutes as the entire woodwind.","FILM"},
      {"The Day the Earth Stood Still — electronics and brass","Brass ensemble, harps, "
        .. "electronic organ, theremin and electric violin - the founding science-fiction "
        .. "palette.","FILM"},
      {"Vertigo — harp and vibraphone","The pairing that gives the score its vertiginous "
        .. "shimmer.","FILM"},
    }},
    {"What to take from him", {
      {"Choose the ensemble, then compose","His method inverts the usual order: decide what "
        .. "the film's sound world is, build an orchestra that can only make that sound, and "
        .. "write inside it. Rimsky-Korsakov's principle taken to its limit - \"a work "
        .. "should be written for the size of orchestra that is to perform it\".","FILM; cf. RK p.3"},
      {"Subtraction as the strongest move","Removing a family - strings, or everything but "
        .. "strings - changes a score more than any addition can.","FILM; MOD"},
      {"Multiples of one instrument","Nine harps, twelve flutes, nine trombones: a section "
        .. "of one colour behaves like a new instrument, not like a louder old one. Compare "
        .. "Wagner's six harps and Rimsky-Korsakov's note that three or four harps are needed "
        .. "to be heard at all.","FILM; cf. RK p.29"},
      {"Sustained low ostinati","His habit of building tension on repeated low figures "
        .. "rather than on melody.","FILM"},
    }},
  },
  instruments={"strings","harp","brass","trombone","flute","percussion","celesta","woodwind"},
  related={"composers","rozsa","goldsmith","elfman","strings","harp","plucked"},
}

e{ id="morricone", name="Ennio Morricone", family="Film Composers", kind="composer",
  aliases={"morricone","ennio morricone"},
  summary="\"He treated the orchestra not as a homogeneous bloc but as a collection of "
       .. "distinctive timbres.\" His orchestration \"often calls for an unusual combination "
       .. "of instruments, voices, and whistling\" - and much of it began as a way round a "
       .. "small budget.",
  facts={ {"Dates","1928-2020"},
          {"Look at","The Good, the Bad and the Ugly; Once Upon a Time in the West; The "
            .. "Mission; Cinema Paradiso; The Untouchables"} },
  sec={
    {"His signature colours", {
      {"Human whistling as a lead instrument","Alessandro Alessandroni's whistle in the "
        .. "Dollars trilogy \"became a shorthand for danger. It was no longer just a tune; it "
        .. "was a character in itself.\"","FILM"},
      {"Wordless soprano as an orchestral layer","Edda Dell'Orso's voice. Constrained to a "
        .. "small orchestra, \"one idea he had was to replace instruments with human "
        .. "voices\"; she \"pioneered the model of the voice as an atmospheric, non-verbal "
        .. "layer of the orchestration\".","FILM"},
      {"Electric guitar with orchestra","The then-new Fender, set against traditional "
        .. "forces.","FILM"},
      {"Harmonica, acoustic and electric guitar","The Western palette, blended with "
        .. "\"experimental elements like slide-whistle, woodblock, and male "
        .. "whistling\".","FILM"},
      {"Found and non-musical sounds","Gunshots, whips, cracks - treated as instruments in "
        .. "the score, not as sound effects.","FILM"},
      {"Oboe as the voice of innocence","The Mission's Gabriel's Oboe - the reference "
        .. "modern use of the instrument's pastoral character.","FILM; cf. SIN p.85"},
    }},
    {"What to take from him", {
      {"A budget limit is a style","The whole approach came from not having a full orchestra "
        .. "available. Constraint produced a recognisable voice where abundance might not "
        .. "have.","FILM"},
      {"Treat the voice as a wind instrument","Wordless soprano doubles and blends like a "
        .. "woodwind - and Rimsky-Korsakov's rules for doubling women's voices (violins, "
        .. "violas, clarinets, oboes) apply directly.","FILM; cf. RK p.122"},
    }},
  },
  instruments={"oboe","voice","strings","trumpet","percussion","woodwind"},
  related={"composers","voice","oboe","percussion","herrmann"},
}

e{ id="barry", name="John Barry", family="Film Composers", kind="composer",
  aliases={"barry","john barry","john barry prendergast"},
  summary="A jazz arranger's ear applied to the orchestra: \"fusing romantic string "
       .. "melodies with explosive outbursts of brass\". His palette is \"jazz and blues "
       .. "tinged harmonic language, alternately brooding and stabbing brass chords, "
       .. "sustained string lines, florid violin arabesques, and jabbing percussion\".",
  facts={ {"Dates","1933-2011"}, {"Look at","the James Bond scores, Out of Africa, "
          .. "Dances with Wolves, Midnight Cowboy"} },
  sec={
    {"His signature colours", {
      {"Low electric guitar figure under brass","His own description of the Bond theme: \"a "
        .. "peculiar mixture of that low rock guitar figure, the brass sound, and a bridge "
        .. "that was almost like a Dizzy Gillespie bebop phrase. It was kind of a hybrid of "
        .. "all these things.\"","FILM"},
      {"Stabbing muted brass chords","The Bond punctuation - brass used rhythmically rather "
        .. "than melodically.","FILM"},
      {"Long sustained string lines","His romantic manner, often a single unbroken melody "
        .. "over slow harmony.","FILM"},
      {"Jabbing percussion","Sharp, dry hits rather than rolls or swells.","FILM"},
    }},
    {"What to take from him", {
      {"A rhythm-section instrument inside an orchestra","Electric guitar or drum kit "
        .. "treated as a normal member of the ensemble, not a novelty - the model for most "
        .. "later hybrid scoring.","FILM; MOD"},
    }},
  },
  instruments={"brass","trumpet","trombone","strings","percussion"},
  related={"composers","zimmer","brass","strings","percussion"},
}

e{ id="goldsmith", name="Jerry Goldsmith", family="Film Composers", kind="composer",
  aliases={"goldsmith","jerry goldsmith"},
  summary="\"Extremely sensitive to orchestral timbre while exploring unusual instrumental "
       .. "combinations\", and the most inventive extender of orchestral technique in film. "
       .. "\"He never shied away from utilizing unusual instrumentation, found sounds, "
       .. "emerging technologies, and extended techniques in harmony with more traditional "
       .. "orchestral elements.\"",
  facts={ {"Dates","1929-2004"}, {"Look at","Planet of the Apes, Alien, Chinatown, "
          .. "Patton, The Omen, Star Trek: The Motion Picture"} },
  sec={
    {"His signature methods", {
      {"Instruments played wrongly on purpose","Planet of the Apes: \"horns blown without "
        .. "mouthpieces\", and woodwind players \"fingering their keys without using any "
        .. "air\" - the orchestra made to imitate the apes' grunting.","FILM"},
      {"Orchestra through an echoplex","Drums looped into an echoplex in Planet of the "
        .. "Apes; string pizzicati filtered through one in Alien to create \"alien\" "
        .. "sounds.","FILM"},
      {"Extended string techniques as biology","Alien's col legno, sul ponticello and "
        .. "harmonics \"create sounds that don't register as music as much as they do "
        .. "biological processes\".","FILM"},
      {"Antique and non-orchestral instruments","Alien's orchestra was augmented by shofar, "
        .. "steel drum, serpent (the medieval bass cornet), didgeridoo, whistles and "
        .. "rattles.","FILM"},
      {"Twelve-tone rows as an alien language","Planet of the Apes is written wholesale in "
        .. "an avant-garde idiom, its tone rows creating \"an alien musical language that "
        .. "perfectly matched the film's inverted world\".","FILM"},
    }},
    {"What to take from him", {
      {"The serpent is in this book for a reason","Singleton records the serpent as the "
        .. "obsolete bass of the cornet family, \"now obsolete\", hanging on a workshop wall. "
        .. "Goldsmith put it in a 1979 film score. Nothing in the orchestra is permanently "
        .. "dead.","FILM; cf. SIN p.117"},
      {"Extend before you add","Most of his strangest sounds come from ordinary instruments "
        .. "played unusually, which any orchestra can do, rather than from instruments you "
        .. "have to find.","FILM; MOD"},
    }},
  },
  instruments={"horn","woodwind","strings","pizzicato","percussion","brass","cornet"},
  related={"composers","herrmann","strauss","stravinsky","percussion","pizzicato"},
}

e{ id="williams", name="John Williams", family="Film Composers", kind="composer",
  aliases={"williams","john williams","john t williams"},
  summary="The late-Romantic orchestra maintained as a living idiom. \"Williams is a master "
       .. "not just of composition but of the mechanics of the orchestra, with precise "
       .. "indications of dynamics and articulations being particularly important to his "
       .. "orchestrations.\"",
  facts={ {"Dates","b. 1932"},
          {"Star Wars’ orchestra","Triple woodwind, five horns and the usual brass"},
          {"Look at","Star Wars, E.T., Jaws, Schindler's List, Harry Potter, "
            .. "Horn Concerto (2003)"} },
  sec={
    {"His signature colours", {
      {"Horns in unison with other brass, not in octaves","When he transposes a theme into "
        .. "a key comfortable for horns, \"he writes them as unison parts with other brass "
        .. "(like trumpets) rather than in octaves, producing a noble, heroic sound\". Note "
        .. "that this is Rimsky-Korsakov's brass-unison practice, not his octave "
        .. "practice.","FILM; cf. RK p.55"},
      {"The horn as the leading voice","He has named the French horn as one of his great "
        .. "loves; \"brass writing has been his signature at least from Star Wars "
        .. "onward\".","FILM"},
      {"Precise articulation and dynamics","The detail in his parts is where the sound comes "
        .. "from - the same lesson as Mahler's per-instrument dynamics.","FILM"},
      {"Careful woodwind balance","\"While strings generally balance themselves regardless "
        .. "of voicing, woodwinds require careful attention to achieve proper blend and "
        .. "balance.\"","FILM"},
      {"Celesta, harp and high woodwind for magic","The Harry Potter manner - the "
        .. "light-plucked-and-struck group used as a colour block.","FILM; MOD"},
      {"Solo violin as elegy","Schindler's List - the concert-soloist convention brought "
        .. "into a score.","FILM"},
    }},
    {"What to take from him", {
      {"The tradition still works","His career is the practical demonstration that the "
        .. "19th-century orchestra and the doublings in this encyclopaedia remain a living "
        .. "technique rather than a historical one.","FILM; MOD"},
      {"Write for the players you will get","Five horns rather than four, triple woodwind, "
        .. "and parts that professional orchestras can read at speed.","FILM; cf. RK p.3"},
    }},
  },
  instruments={"horn","trumpet","brass","celesta","harp","violin","woodwind","strings",
               "piccolo","timpani"},
  related={"composers","korngold","wagner","horn","brass","celesta","balance"},
}

e{ id="elfman", name="Danny Elfman", family="Film Composers", kind="composer",
  aliases={"elfman","danny elfman"},
  summary="A gothic-carnival palette: \"Elfman's signature sound is often characterized by "
       .. "unique timbres like celesta and choirs that evoke gothic elements\".",
  facts={ {"Dates","b. 1953"}, {"Look at","Edward Scissorhands, Batman, Beetlejuice, "
          .. "The Nightmare Before Christmas, Mars Attacks!"} },
  sec={
    {"His signature colours", {
      {"Celesta","The instrument most associated with him - used melodically, not as "
        .. "decoration.","FILM"},
      {"Boy soprano and wordless choir","\"An array of 'exotic' sounds, including solos for "
        .. "boy soprano\" - Edward Scissorhands being the defining case.","FILM"},
      {"Theremin","Used extensively in Mars Attacks!, \"harkening back to Bernard "
        .. "Herrmann's score for The Day the Earth Stood Still\".","FILM"},
      {"Idioms outside the orchestra","He also draws on \"the German music hall tradition, "
        .. "1930's swing, bluegrass, and African percussion styles\".","FILM"},
      {"Low brass and bass voices against high bells","The gothic contrast: something very "
        .. "dark at the bottom, something glittering at the top, little in the middle. "
        .. "Compare Rimsky-Korsakov on widely separated extremes, which he calls good for "
        .. "\"strange and grotesque effects\".","FILM; cf. RK p.106-107"},
    }},
  },
  instruments={"celesta","glockenspiel","voice","chorus","brass","percussion","harp",
               "strings"},
  related={"composers","herrmann","celesta","chorus","glockenspiel"},
}

e{ id="shore", name="Howard Shore", family="Film Composers", kind="composer",
  aliases={"shore","howard shore"},
  summary="The most systematic use of instrumentation as world-building in film music: in "
       .. "The Lord of the Rings each culture has its own instruments, so that the "
       .. "orchestration tells you where you are before the theme does.",
  facts={ {"Dates","b. 1946"}, {"Look at","The Lord of the Rings trilogy, The Hobbit, "
          .. "The Fly, Hugo, Crash"} },
  sec={
    {"Instruments as places", {
      {"The Shire — British and Irish folk instruments","Mandolin, Celtic harp, musette (a "
        .. "kind of accordion) and bodhran, \"reflecting how Tolkien saw the Shire\".","FILM"},
      {"Rohan — Hardanger fiddle","The Norwegian fiddle for the horse-riders.","FILM"},
      {"Gollum — Hungarian cimbalom","\"A creepy theme on the Hungarian cimbalom (similar to "
        .. "a hammered dulcimer)\".","FILM"},
      {"The Ents — woody percussion","Log drums and marimba.","FILM"},
      {"Antiquity — ethnic flutes and djembe","\"The haunting sounds of ethnic flutes and "
        .. "djembe drums introduce a sense of ancient mystery.\"","FILM"},
    }},
    {"What to take from him", {
      {"Let the instrument carry the identity","A theme can be moved anywhere; an instrument "
        .. "cannot be mistaken. Assigning a culture, character or place its own timbre is "
        .. "Wagner's leitmotif principle applied to orchestration rather than to "
        .. "melody.","FILM; cf. SIN ch.VIII"},
      {"Folk instruments inside an orchestral texture","Rimsky-Korsakov made the same point "
        .. "about guitar, domra, zither, mandoline and oriental tambourine - \"employed from "
        .. "time to time for descriptive-aesthetic purposes\".","FILM; cf. RK p.118"},
    }},
  },
  instruments={"harp","plucked","percussion","flute","strings","brass","chorus"},
  related={"composers","wagner","plucked","percussion","flute"},
}

e{ id="zimmer", name="Hans Zimmer", family="Film Composers", kind="composer",
  aliases={"zimmer","hans zimmer"},
  summary="\"A minimalist composer with a sort of maximalist production sense.\" He "
       .. "\"cultivated a hybrid electronic-orchestral aesthetic that uses analog and "
       .. "digital oscillators, filters, and amplifiers to twist and augment solo instrument "
       .. "samples into a synthesized whole\" - orchestration as sound design.",
  facts={ {"Dates","b. 1957"}, {"Look at","Gladiator, The Dark Knight, Inception, "
          .. "Interstellar, Dune"} },
  sec={
    {"His signature methods", {
      {"’Cello and low string ostinato","\"Low-frequency synths or cellos often underpin "
        .. "rhythmic motifs to create urgency, and repeating rhythmic cells in strings, "
        .. "percussion or synths provide propulsion and allow harmonic shifts above a fixed "
        .. "groove.\"","FILM"},
      {"Orchestra blended with synthesizers","\"Blending classic orchestral instruments - "
        .. "strings, brass, and percussion - with modern synthesizers and sound design, "
        .. "digital textures and ambient pads.\"","FILM"},
      {"Extended techniques for edge","\"Bowed cymbal, col legno strings, muted brass, sul "
        .. "ponticello, breathy choir, and granularly treated piano sounds are common to add "
        .. "edge and atmosphere.\"","FILM"},
      {"Massed brass on very few notes","The maximalist-minimalist signature: enormous "
        .. "forces on simple material.","FILM"},
      {"Organ as an orchestral instrument","Interstellar - a colour largely absent from the "
        .. "concert orchestra brought back as a lead.","FILM"},
    }},
    {"What to take from him", {
      {"The balance rules still apply","Massed low brass over a fixed ostinato is a "
        .. "distribution problem like any other - and Rimsky-Korsakov's warning that widely "
        .. "separated extremes with an empty middle sound strange is exactly what this style "
        .. "exploits.","FILM; cf. RK p.106-107"},
      {"Orchestrating for the microphone","Much of the sound is made after the players "
        .. "leave, in processing and mixing. That is a real technique, but it is not "
        .. "transferable to a concert score.","FILM; MOD"},
    }},
  },
  instruments={"cello","doublebass","brass","percussion","strings","chorus","piano"},
  related={"composers","barry","cello","brass","balance","range"},
}

e{ id="desplat", name="Alexandre Desplat", family="Film Composers", kind="composer",
  aliases={"desplat","alexandre desplat"},
  summary="\"Playful themes, insistent accompaniments, unusual orchestration and an innate "
       .. "understanding of screen drama.\" The most woodwind-forward of the major film "
       .. "composers.",
  facts={ {"Dates","b. 1961"}, {"Look at","The Grand Budapest Hotel, The Shape of Water, "
          .. "Harry Potter and the Deathly Hallows, The Painted Veil, Little Women"} },
  sec={
    {"His signature colours", {
      {"Twelve flutes and nothing else in the woodwind","The Shape of Water: \"the woodwind "
        .. "section is comprised entirely of flutes - 12 of them across the entire sonic "
        .. "range - but no oboes, no bassoons, no clarinets. This was a conscious choice... "
        .. "to give his woodwind section a specific timbre that represents the sound of "
        .. "water.\" Compare Herrmann's twelve flutes in Torn Curtain, and Mendelssohn's and "
        .. "Weber's older association of woodwind with water.","FILM"},
      {"Woodwind trills as an action device","\"The familiar woodwind trills that abound are "
        .. "a hallmark and have underpinned Desplat's action material throughout his "
        .. "career.\" Note Rimsky-Korsakov's pairing of woodwind and violin trills with a "
        .. "triangle or tambourine tremolo.","FILM; cf. RK p.117"},
      {"Plucked and struck instruments as rhythm","Harp, celesta, pizzicato and light "
        .. "percussion carrying the pulse instead of drums.","FILM"},
      {"Chamber-scale colours inside a film orchestra","Small, clearly identifiable groups "
        .. "rather than tutti.","FILM"},
    }},
    {"What to take from him", {
      {"A family of one instrument","Building a whole section from one instrument across its "
        .. "range - twelve flutes - produces a colour no mixed section can. The same logic as "
        .. "Herrmann's nine harps.","FILM; MOD"},
    }},
  },
  instruments={"flute","woodwind","harp","celesta","pizzicato","percussion","strings"},
  related={"composers","herrmann","debussy","flute","woodwind","harp"},
}

e{ id="greenwood", name="Jonny Greenwood", family="Film Composers", kind="composer",
  aliases={"greenwood","jonny greenwood","johnny greenwood"},
  summary="A composer who came to film from rock and brought concert-hall modernism with "
       .. "him - Penderecki and Messiaen rather than Korngold.",
  facts={ {"Dates","b. 1971"}, {"Look at","There Will Be Blood, The Master, Phantom "
          .. "Thread, You Were Never Really Here, Norwegian Wood"} },
  sec={
    {"His signature colours", {
      {"Ondes Martenot","\"The Martenot has featured in almost all of his film scores, and "
        .. "it has come to embody his voice.\" His interest comes from Messiaen, and the "
        .. "Turangalila Symphony in particular.","FILM"},
      {"Aleatoric string writing","\"Greenwood shows his taste for aleatoric techniques in "
        .. "string writing, used in conjunction with the use of motif\" - clusters and "
        .. "controlled indeterminacy rather than tunes.","FILM"},
      {"Strings played for texture, not line","Extended techniques used so the string body "
        .. "reads as material rather than melody.","FILM"},
    }},
    {"What to take from him", {
      {"Where the strings can still go","The one group Rimsky-Korsakov says we can listen to "
        .. "indefinitely without tiring is also the one with the most unexplored technique. "
        .. "Greenwood is the current demonstration.","FILM; cf. RK p.35"},
    }},
  },
  instruments={"strings","violin","viola","cello","percussion"},
  related={"composers","stravinsky","strings","violin"},
}

return D
