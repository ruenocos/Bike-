# Credits

Third-party assets and code used in Bike!. Licence texts sit next to each one.

| What | Where in the project | Author / source | Licence |
|---|---|---|---|
| Cel shader (base, cut-out, outline, includes) | `vfx/cel/` | Rafael de Lima Bordoni (eldskald), [godot4-cel-shader](https://github.com/eldskald/godot4-cel-shader) | MIT (`vfx/cel/LICENSE.txt`) |
| Stylized Nature MegaKit (Standard): trees, rocks, bushes, textures | `art/nature/megakit/` | [Quaternius](https://quaternius.itch.io/stylized-nature-megakit) | CC0 (`art/nature/megakit/License_Standard.txt`) |
| Nature Kit: fences, logs, stumps | `art/props/kenney/` | [Kenney](https://kenney.nl/assets/nature-kit) | CC0 (`art/props/kenney/License.txt`) |
| Painted anime sky panoramas (sky_101, 113, 116, 118) | `sky/painted/` | [FreeStylized](https://freestylized.com/category/skybox/anime) | Royalty free, commercial use OK (`sky/painted/LICENSE.txt`) |

Everything else (code, terrain, grass, set pieces, HUD, the rider and BMX) is made for Bike!.
Sky3D was looked at for v0.10 but not used: the built-in procedural sky
already gives the golden-hour look.

## Sound

Every sound is cut from these CC0 packs by `audio/tools/cut_samples.py` (trim, mix, pitch, filter, loop seams; nothing is synthesized).

| File (`audio/sfx/`) | Pack(s) | Author | Licence | URL | Edit |
|---|---|---|---|---|---|
| `wind/wind_low.ogg` | Park Ambiences; Wind Whoosh Loop | Thimras; SketchMan3 | CC0 | https://opengameart.org/content/park-ambiences https://opengameart.org/content/wind-whoosh-loop | evenest 10 s of the field recording + the whoosh loop 6 st down, low-passed, seam crossfaded |
| `wind/wind_mid.ogg` | Wind Whoosh Loop | SketchMan3 | CC0 | https://opengameart.org/content/wind-whoosh-loop | normalized |
| `wind/wind_high.ogg` | Short Wind Sound; Wind Whoosh Loop | remaxim; SketchMan3 | CC0 | https://opengameart.org/content/short-wind-sound https://opengameart.org/content/wind-whoosh-loop | whoosh loop high-passed and 7 st up + short wind sound; channels offset for width |
| `tank/engine_idle.ogg` | Engine/Mechanic Working Sound; Racing Car Engine Sound Loops | jwiese; domasx2 | CC0 | https://opengameart.org/content/enginemechanic-working-sound https://opengameart.org/content/racing-car-engine-sound-loops | engine loop doubled, a low car engine under it, seam crossfaded |
| `tank/engine_high.ogg` | Car Sound Effects Pack; Steamboat Engine Sound | GGBotNet; Spring Spring | CC0 | https://opengameart.org/content/car-sound-effects-pack-low-quality https://opengameart.org/content/steamboat-engine-sound | chugging engine 4 st up + car engine 4 st down, seam crossfaded |
| `tank/tread_slow.ogg` | 30 CC0 SFX Loops; Chain Winch Sounds | rubberduck; bart | CC0 | https://opengameart.org/content/30-cc0-sfx-loops https://opengameart.org/content/chain-winch-sounds | chain winch ratchet + machine thump, seam crossfaded |
| `tank/tread_fast.ogg` | 30 CC0 SFX Loops; Chain Winch Sounds | rubberduck; bart | CC0 | https://opengameart.org/content/30-cc0-sfx-loops https://opengameart.org/content/chain-winch-sounds | machine loop + the chain ratchet 4 st up, seam crossfaded |
| `tank/grind_loop.ogg` | 31 Pings and Metal Filing Sounds | bart | CC0 | https://opengameart.org/content/31-pings-and-metal-filing-sounds | two metal filing takes mixed, seam crossfaded |
| `tank/grind_catch_1.wav` | Impact Sounds; 31 Pings and Metal Filing Sounds; Mechanical Sounds | Kenney; bart; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/31-pings-and-metal-filing-sounds https://opengameart.org/content/mechanical-sounds | heavy metal hit + clank + ping ring-out |
| `tank/grind_catch_2.wav` | Impact Sounds; 31 Pings and Metal Filing Sounds; Mechanical Sounds | Kenney; bart; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/31-pings-and-metal-filing-sounds https://opengameart.org/content/mechanical-sounds | heavy metal hit + clank + ping ring-out |
| `tank/grind_catch_3.wav` | Impact Sounds; 31 Pings and Metal Filing Sounds; Mechanical Sounds | Kenney; bart; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/31-pings-and-metal-filing-sounds https://opengameart.org/content/mechanical-sounds | heavy metal hit + clank + ping ring-out |
| `tank/grind_catch_4.wav` | Impact Sounds; 31 Pings and Metal Filing Sounds; Mechanical Sounds | Kenney; bart; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/31-pings-and-metal-filing-sounds https://opengameart.org/content/mechanical-sounds | heavy metal hit + clank + ping ring-out |
| `tank/hop_1.wav` | Impact Sounds; Mechanical Sounds | Kenney; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/mechanical-sounds | soft thump + short metal clunk + spring squeak |
| `tank/hop_2.wav` | Impact Sounds; Mechanical Sounds | Kenney; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/mechanical-sounds | soft thump + short metal clunk + spring squeak |
| `tank/hop_3.wav` | Impact Sounds; Mechanical Sounds | Kenney; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/mechanical-sounds | soft thump + short metal clunk + spring squeak |
| `tank/hop_4.wav` | Impact Sounds; Mechanical Sounds | Kenney; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/mechanical-sounds | soft thump + short metal clunk + spring squeak |
| `tank/boost_1.wav` | 25 CC0 Bang / Firework SFX; Swishes Sound Pack | rubberduck; artisticdude | CC0 | https://opengameart.org/content/25-cc0-bang-firework-sfx https://opengameart.org/content/swishes-sound-pack | two swishes pitched down + a firework burst far down |
| `tank/boost_2.wav` | 25 CC0 Bang / Firework SFX; Swishes Sound Pack | rubberduck; artisticdude | CC0 | https://opengameart.org/content/25-cc0-bang-firework-sfx https://opengameart.org/content/swishes-sound-pack | two swishes pitched down + a firework burst far down |
| `tank/boost_3.wav` | 25 CC0 Bang / Firework SFX; Swishes Sound Pack | rubberduck; artisticdude | CC0 | https://opengameart.org/content/25-cc0-bang-firework-sfx https://opengameart.org/content/swishes-sound-pack | two swishes pitched down + a firework burst far down |
| `tank/cannon_blast_1.wav` | Impact Sounds; 25 CC0 Bang / Firework SFX; Swishes Sound Pack | Kenney; rubberduck; artisticdude | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/25-cc0-bang-firework-sfx https://opengameart.org/content/swishes-sound-pack | cannon boom + thud + swish |
| `tank/cannon_blast_2.wav` | Impact Sounds; Cannon Fire; Swishes Sound Pack | Kenney; Thimras; artisticdude | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/cannon-fire https://opengameart.org/content/swishes-sound-pack | cannon boom + thud + swish |
| `tank/cannon_blast_3.wav` | Impact Sounds; 25 CC0 Bang / Firework SFX; Swishes Sound Pack | Kenney; rubberduck; artisticdude | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/25-cc0-bang-firework-sfx https://opengameart.org/content/swishes-sound-pack | cannon boom + thud + swish |
| `tank/land_perfect_1.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | tight metal hit cut to 0.3 s + punch |
| `tank/land_good_1.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | softer metal hit + soft thud |
| `tank/land_sketchy_1.wav` | Impact Sounds; 80 CC0 RPG SFX; Mechanical Sounds | Kenney; rubberduck; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/80-cc0-rpg-sfx https://opengameart.org/content/mechanical-sounds | big slam: thud + plate + metal + rattle + chain |
| `tank/crash_1.wav` | Impact Sounds; 25 CC0 Bang / Firework SFX; Cave In; Crash / Collision; Scrapes | Kenney; rubberduck; StarNinjas; qubodup; AntumDeluge | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/25-cc0-bang-firework-sfx https://opengameart.org/content/cave-in https://opengameart.org/content/crash-collision https://opengameart.org/content/scrapes | metal crash + boom + stapler crash + debris + scrape |
| `tank/land_perfect_2.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | tight metal hit cut to 0.3 s + punch |
| `tank/land_good_2.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | softer metal hit + soft thud |
| `tank/land_sketchy_2.wav` | Impact Sounds; 80 CC0 RPG SFX; Mechanical Sounds | Kenney; rubberduck; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/80-cc0-rpg-sfx https://opengameart.org/content/mechanical-sounds | big slam: thud + plate + metal + rattle + chain |
| `tank/crash_2.wav` | Impact Sounds; 25 CC0 Bang / Firework SFX; Cave In; Crash / Collision; Scrapes | Kenney; rubberduck; StarNinjas; qubodup; AntumDeluge | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/25-cc0-bang-firework-sfx https://opengameart.org/content/cave-in https://opengameart.org/content/crash-collision https://opengameart.org/content/scrapes | metal crash + boom + stapler crash + debris + scrape |
| `tank/land_perfect_3.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | tight metal hit cut to 0.3 s + punch |
| `tank/land_good_3.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | softer metal hit + soft thud |
| `tank/land_sketchy_3.wav` | Impact Sounds; 80 CC0 RPG SFX; Mechanical Sounds | Kenney; rubberduck; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/80-cc0-rpg-sfx https://opengameart.org/content/mechanical-sounds | big slam: thud + plate + metal + rattle + chain |
| `tank/crash_3.wav` | Impact Sounds; 25 CC0 Bang / Firework SFX; Cave In; Crash / Collision; Scrapes | Kenney; rubberduck; StarNinjas; qubodup; AntumDeluge | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/25-cc0-bang-firework-sfx https://opengameart.org/content/cave-in https://opengameart.org/content/crash-collision https://opengameart.org/content/scrapes | metal crash + boom + stapler crash + debris + scrape |
| `tank/land_perfect_4.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | tight metal hit cut to 0.3 s + punch |
| `tank/land_good_4.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | softer metal hit + soft thud |
| `tank/land_sketchy_4.wav` | Impact Sounds; 80 CC0 RPG SFX; Mechanical Sounds | Kenney; rubberduck; BMacZero | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/80-cc0-rpg-sfx https://opengameart.org/content/mechanical-sounds | big slam: thud + plate + metal + rattle + chain |
| `tank/crash_4.wav` | Impact Sounds; 25 CC0 Bang / Firework SFX; Cave In; Crash / Collision; Scrapes | Kenney; rubberduck; StarNinjas; qubodup; AntumDeluge | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/25-cc0-bang-firework-sfx https://opengameart.org/content/cave-in https://opengameart.org/content/crash-collision https://opengameart.org/content/scrapes | metal crash + boom + stapler crash + debris + scrape |
| `tank/crush_1.wav` | Impact Sounds; RPG Audio | Kenney; Kenney | CC0 | https://kenney.nl/assets/impact-sounds https://kenney.nl/assets/rpg-audio | wood: chop + plank + heavy wood |
| `tank/crush_2.wav` | Impact Sounds; RPG Audio | Kenney; Kenney | CC0 | https://kenney.nl/assets/impact-sounds https://kenney.nl/assets/rpg-audio | wood: plank + wood + chop |
| `tank/crush_3.wav` | Impact Sounds; Cave In | Kenney; StarNinjas | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/cave-in | rock: mining hits + debris |
| `tank/crush_4.wav` | Impact Sounds; Cave In | Kenney; StarNinjas | CC0 | https://kenney.nl/assets/impact-sounds https://opengameart.org/content/cave-in | rock + wood + debris |
| `tank/turret_1.wav` | 30 CC0 SFX Loops; Chain Winch Sounds | rubberduck; bart | CC0 | https://opengameart.org/content/30-cc0-sfx-loops https://opengameart.org/content/chain-winch-sounds | machine loop cut short + winch |
| `tank/turret_2.wav` | 30 CC0 SFX Loops; Chain Winch Sounds | rubberduck; bart | CC0 | https://opengameart.org/content/30-cc0-sfx-loops https://opengameart.org/content/chain-winch-sounds | machine loop pitched up + winch |
| `tank/turret_3.wav` | 30 CC0 SFX Loops; Chain Winch Sounds | rubberduck; bart | CC0 | https://opengameart.org/content/30-cc0-sfx-loops https://opengameart.org/content/chain-winch-sounds | machine loop pitched down + winch |
| `feedback/note_perfect_1.wav` | Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds | major stab tuned to A + glass shimmer |
| `feedback/note_perfect_2.wav` | Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds | open fifth tuned to A + glass shimmer |
| `feedback/note_perfect_3.wav` | Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds | both stabs on A + glass shimmer |
| `feedback/note_good_1.wav` | Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds | pluck on A |
| `feedback/note_good_2.wav` | Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds | pluck tuned to A |
| `feedback/note_sketchy_1.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | off-key bell; slides down at runtime |
| `feedback/note_sketchy_2.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | off-key bell; slides down at runtime |
| `feedback/trick_1.wav` | Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds | glass ping |
| `feedback/trick_2.wav` | Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds | glass ping |
| `feedback/trick_3.wav` | Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds | glass ping |
| `feedback/gate_1.wav` | Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds | normalized |
| `feedback/gate_2.wav` | Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds | pitched |
| `feedback/banked_1.wav` | Music Jingles | Kenney | CC0 | https://kenney.nl/assets/music-jingles | steel drum jingle, on A |
| `feedback/banked_2.wav` | Music Jingles | Kenney | CC0 | https://kenney.nl/assets/music-jingles | steel drum jingle |
| `collapse/rumble.ogg` | Rumble FX | cinameng | CC0 | https://opengameart.org/content/rumble-fx | steady middle, seam crossfaded |
| `collapse/debris.ogg` | Cave In | StarNinjas | CC0 | https://opengameart.org/content/cave-in | steady middle played forward then back, seam crossfaded |
| `collapse/roar.ogg` | Earthquake and Open Sesame | mieki256 | CC0 | https://opengameart.org/content/earthquake-and-open-sesame | seam crossfaded |
| `collapse/crack_1.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | pitched down |
| `collapse/crack_2.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | pitched down |
| `collapse/crack_3.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | pitched down |
| `collapse/crack_4.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | pitched down |
| `collapse/crack_5.wav` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds | pitched down |
