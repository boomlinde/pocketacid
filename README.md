# Pocket Acid

Pocket Acid is a self-contained music studio designed for use with game
controllers and cheap, handheld Linux-based game consoles like the [R36S](https://handhelds.wiki/R36S_Handheld_Wiki).
It's designed for live use, with quick access to synthesizer parameters via
joysticks, muting using button combinations and pattern queuing.

The patterns, arrangement and parameters and so on are all contained in
one of up to 256 project files, which is automatically saved upon exit.

![Picture of R36XX running Pocket Acid](.readme-assets/r36xx_small.jpg)

[Watch a demo video on YouTube](https://www.youtube.com/watch?v=6xw3qoWYFCo)

# Installation

If you are using Windows or ArkOS (or any 64-bit platform using PortMaster),
[get the latest release build here.](https://github.com/boomlinde/pocketacid/releases/latest)

To install on an ArkOS device, extract the `.portmaster.zip` archive to the
ports directory in the EASYROMS partition. The ports directory should now
contain the file `Pocket Acid.sh` and the directory `pocketacid`. Pocket Acid
will be available under the ports entry in the main menu on the next boot.

To install on Windows, simply extract the `.win64.zip` archive to the desired
location.

To build on Linux, build the port using zig 0.15.2 compiler. After you run the
`release.sh` script, that version of Zig will be available in prereqs/zig.

Then you can simply run:

    prereqs/zig/zig build -Doptimize=ReleaseFast

after which the executable will be available at `zig-out/bin/pocketacid`.

If you have problems launching the portmaster release of Pocket Acid from a
Unix filesystem, make sure `that ports/pocketacid/pocketacid` is marked as
executable. A few people experienced this problem after extracting the files
to a Windows filesystem (which doesn't preserve the executable flag) and then
copying the files to a device which used a Unix filesystem. This is not a
problem in ArkOS: it uses a FAT filesystem and all files are implicitly
executable.

# Bassline synthesizer

The bassline synthesizer architecture has two modes:

## Phase distortion

One mode is based on phase distortion, but is designed to roughly emulate
the sound and control of a classic, subtractive bassline synthesizer. Unlike
a typical phase distortion synthesizer, it employs feedback phase modulation
to optionally produce a harsher, distorted tone. Unlike a classic bassline
synthesizer, controlling the waveform and "filter cutoff" are unified into a
single control, called "timbre".

Parameters:

* **timbre**: controls the timbre of the synth. The closer to the center it
  is, the less overtones the sound will have. Above the center, the timbre
  tends more towards a square wave. Below the center, more towards a sawtooth
  wave.
* **env**: controls how great a portion of the timbre parameter is
  controlled by the timbre envelope.
* **res**: controls the "resonance" of the synth. The "resonance" is a
  sinewave synchronized to the body of the sound and windowed and
  attenuated in a way that corresponds to the level of the parameter.
  The frequency of the resonance is determined by the timbre and env
  parameters.
* **feedback**: controls the feedback phase modulation level. At low
  settings, there is no feedback and the sound predictably reflects
  the other parameter settings. At higher settings, the output of
  the synth is fed back via a unit delay to control the phase of
  both the body of the sound and the resonance wave, causing less
  predictable distortion.
* **decay**: controls the decay time of the timbre envelope.
* **accent**: controls the level of influence an accent in the
  sequencer will have on the timbre

## FM

The other mode is based on FM. Its controls are exactly the same as for the
phase distortion mode, but they map to slightly different settings internally.

The descriptions for the phase distortion mode still apply except the following:

* **timbre**: controls the timbre of the synth. The closer to the center it
  is, the less overtones the sound will have. Above the center, the resonance
  parameter controls the integer modulator ratio. Below the center, the ratio
  is not integer, but a window function is applied so as to avoid sharp
  transitions.
* **res**: controls the modulator ratio of the synth. The exact application of
  the paramater depends on whether the timbre setting is above or below center.

The parameter settings are visible at the bottom of the arranger/pattern
sequencer page. Which parameters are shown (and edited by the joysticks)
can momentarily be toggled. If a bassline synth is muted, it will also be
indicated here using color.

# Drum machine

The drum machine is more simple, based on built-in recordings of drum
machines that can't be manipulated except to change the set of samples
used.

## Controls

Pocket Acid assumes a controller layout similar to that of a typical
Xbox/Playstation controller, with two sticks and four shoulder
buttons. The buttons are named as follows:

        L2                      R2
        L1                      R1

        up                       Y
    left  right  select start  X   B
       down                      A
               L3        R3

If your face buttons are not laid out like that, you can swap Y with X
and A with B using the "swap buttons" setting.

If your controller doesn't have joysticks, see the section on the joyless
mode below.

Globally, you can always control the bassline timbre and envelope using the
left stick for bassline 1 and right stick for bassline 2. You can hold L2 or
R2 to control other bassline parameters using the sticks (see below).

The buttons are also mapped to the computer keyboard buttons:

| Keyboard key | Controller button |
| ------------ | ----------------- |
| return       | start             |
| tab          | select            |
| z            | A                 |
| x            | B                 |
| a            | X                 |
| s            | Y                 |
| q            | L1                |
| w            | R1                |
| 1            | L2                |
| 2            | R2                |

Since there are no joysticks on the keyboard, these don't represent
a full set of controls, but can for example be used while sequencing.

Some controls apply globally across the program (except in the project
picker):

| Button(s)    | Effect                                              |
| ------------ | --------------------------------------------------- |
| select       | Toggle sequencer/arranger and mixer/settings        |
| start        | Toggle playback at current arranger row             |
| L1+select    | Copy selected pattern content                       |
| L1+start     | Paste selected pattern content                      |
| L1+left      | Decrement tempo                                     |
| L1+right     | Increment tempo                                     |
| L1+down      | Decrease tempo by 10 BPM                            |
| L1+up        | Increase tempo by 10 BPM                            |
| L1+X         | Toggle mute of bass drum                            |
| L1+Y         | Toggle mute of snare drum                           |
| L1+B         | Toggle mute of hihat and cymbal                     |
| L1+A         | Toggle mute of toms                                 |
| L1+R1        | Toggle mute of rimshot and clap                     |
| L1+L2        | Toggle mute of bassline 1                           |
| L1+R2        | Toggle mute of bassline 2                           |
| L2           | Momentarily control bassline resonance and feedback |
| R2           | Momentarily control bassline decay and accent       |
| start+select | Exit Pocket Acid                                    |
| L2+R2+start  | Enter project picker                                |
| L2+R1+start  | Enter project picker (alternative, see note below)  |

Others are specific to the different sections of the programs described below.

MustardOS globally binds L2+R2+start to reset the console, so an alternative
button combination is provided.

### Joyless mode

Although Pocket Acid is primarily designed to be controlled using a dual
joystick controller, you can activate the *joyless mode* in the settings
to enable control of the bassline parameters by other means.

While in joyless mode, the L2 and R2 bindings no longer apply. Instead,
holding either L2 or R2 will control enable the following bindings:


| Button(s)   | Effect                                              |
| ----------- | --------------------------------------------------- |
| up          | Increase Y parameter                                |
| down        | Decrease Y parameter                                |
| left        | Decrease X parameter                                |
| right       | Increase X parameter                                |
| A+up        | Increase Y parameter (8x faster)                    |
| A+down      | Decrease Y parameter (8x faster)                    |
| A+left      | Decrease X parameter (8x faster)                    |
| A+right     | Increase X parameter (8x faster)                    |
| X           | Set the current parameters to timbre and env mod    |
| Y           | Set the current parameters to res and feedback      |
| B           | Set the current parameters to decay and accent      |

The dpad buttons apply to either or both of of the bassline synthesizers
depending on whether you are holding L2, R2 or both.

## Sections

Pocket Acid is divided into several sections which you can normally move
between using the select and R1 buttons:

* **Project picker**: used to manage projects
* **Arranger**: used for arranging patterns into loops or songs
* **Bassline pattern sequencer**: used to compose bassline patterns
* **Drum machine pattern sequencer**: used to compose drum machine patterns
* **Mixer**: used to control levels, panning, effect send and ducking
* **Settings**: used to control various parameters not mapped to the
  joysticks, as well as global settings for the application.

The sections are described in greater detail below.

Regardless of which section you're in, the current tempo, playback status
and mute state will be displayed at the top of the screen area.

### Project picker

A project is essentially a savefile, containing the arrangement, patterns,
snapshots and musical settings that you edit in every other mode.  With the
project picker you can switch, delete and clone projects.

Pocket Acid can manage up to 256 project. In the project picker, these are
arranged in a grid of cells either displaying a dot (for a currently unsaved
slot) or a block (for an existing project). The currently selected  project
is highlighted.

| Button(s)   | Effect                                                   |
| ----------- | -------------------------------------------------------- |
| up          | Navigate to previous row                                 |
| down        | Navigate to next row                                     |
| left        | Navigate to previous column                              |
| right       | Navigate to next column                                  |
| start       | Save current project and switch to project under cursor  |
| A           | Write current project to cell under cursor               |
| B           | Remove project under cursor                              |
| Y+down      | Reload currently active project                          |
| L2+R2+start | Exit project picker                                      |
| L2+R1+start | Exit project picker (alternative)                        |

* The currently active project can't be removed/overwritten in the project
  picker. Pressing `a` also can't overwrite *any* saved projects; the
  project occupying the slot you want to use has to be removed first.
* The currently selected project index will be saved in the configuration,
  and Pocket Acid will always load that when starting up.
* The currently active project may still appear as a dot if it hasn't been
  saved.
* Switching to the currently selected project will effectively just save
  it.
* Removing a project removes it from the grid, but leaves it backed up in
  the file system. If you accidentally remove e.g. project 3f, you can
  restore it by exiting Pocket Acid and renaming "project3f.sav.bak"
  to "project3f.sav".
* Each project is ~32k in size. In the absolute worst case (256 projects and
  256 backups), Pocket Acid will use ~16M of disk space for the projects.
* If you have an old workspace save file (named "state.sav"), it will be
  migrated and saved as project 00. The migration process may fail if you
  already have a file called "project00.sav" in the save directory.
* The current project is automatically saved on exit.
* Reloading the currently active project will restore the last saved state
  of the active project and return to the project picker.

### Arranger

    00......
    01......
    02010201≡
    03010202
    01......

The arranger contains sequences of patterns for each of the first bassline,
second bassline and drum sequencers, arranged in columns in that order.
Lumps of consecutive pattern indices separated by empty rows are called
sections.

When you start playback inside a section and the playhead reaches the end of
the section, the playhead loops back to where you started playback. The only
exception to this is if you have queued a row, in which case the playhead
will instead jump to the queued row.

The playhead moves individually for each column, which is important to
consider if you are using odd pattern lengths.

You can attach a snapshot to each row in the arranger. If there is a snapshot
at a given row, it will be visible as a ≡ symbol to the right of the arranger
columns.

A snapshot contains all the settings and controls for the synthesizers, drum
machine and mixer, and also tempo.

When the drum sequencer playhead starts playing a row with a snapshot on it,
the snapshot will be loaded. If this happens mid-playback, the tempo won't
be changed, disregarding the tempo setting in the snapshot.

The sequencer will keep track of which snapshot was last loaded while
playing, so it won't reload the same snapshot twice in a row. This way,
you can for example use snapshots as an initial set of settings for a
section.  You can always load snapshots manually as well.

If the arranger cursor hovers over a pattern number, the respective
pattern sequencer will be shown to the right. You can switch to this
to edit the pattern.

Controls:

| Button(s)   | Effect                                              |
| ----------- | --------------------------------------------------- |
| up          | Navigate to previous row                            |
| down        | Navigate to next row                                |
| left        | Navigate to previous column                         |
| right       | Navigate to next column                             |
| B+up        | Navigate to the 16th previous line                  |
| B+down      | Navigate to the 16th next line                      |
| B+left      | Navigate to the previous section                    |
| B+down      | Navigate to the next section                        |
| B+select    | Clone pattern to unused, empty slot                 |
| B+start     | Pick empty, unused pattern and initialize it        |
| A           | Toggle pattern on step                              |
| A+left      | Decrement pattern number                            |
| A+right     | Increment pattern number                            |
| A+up        | Increase pattern number by 16                       |
| A+down      | Decrease pattern number by 16                       |
| Y+up        | Save snapshot at current row                        |
| Y+down      | Load snapshot at current row                        |
| Y+left      | Delete current row (moving rows below up)           |
| Y+right     | Insert row before current row                       |
| Y+B         | Delete snapshot at current row                      |
| X           | (While playing) Queue the current row               |
| X           | Start playback at current row but don't change BPM  |
| R1          | Switch to pattern sequencer                         |

For the B+select and B+start commands, it's important to know what
Pocket Acid considers an empty, unused pattern. A pattern is considered
unused if it doesn't currently appear in the arrangement. A pattern is
considered empty if there are no notes or note attributes (like
accent, slides, repeats...). That means a pattern that has a non-default
length or a non-default base pitch can still be considered empty.

### Bassline pattern sequencer

        ptn:01  base:C-3
    C   ................
    B   ................
    A#  ................
    A   ................
    G#  ................
    G   ................
    F#  ................
    F   ................
    E   ................
    D#  ................
    D   ................
    C#  ................
    C   ................

    +   ................
    -   ................
    /   ................
    ◆   ................

The bassline sequencer is of a classic design with a sequence of pitches
and gates, with parallel sequences of octave, slide and accent modifiers.
The first 13 rows represent pitch and gate as a piano roll, while the next
four rows represent the modifiers.

Unlike the classic design, each pattern has its own base pitch, meaning the
pitch at which the octave starts.

Modifier legend:

| Symbol | Effect                          |
| ------ | ------------------------------- |
| +      | Play the pitch an octave higher |
| -      | Play the pitch an octave lower  |
| /      | Slide into the next note        |
| ◆      | Accent the note                 |

Controls:

| Button(s)   | Effect                                              |
| ----------- | --------------------------------------------------- |
| up          | Navigate to pitch/previous modifier                 |
| down        | Navigate to next modifier                           |
| left        | Navigate to previous step                           |
| right       | Navigate to next step                               |
| A           | Toggle modifier/gate and advance cursor             |
| A+up        | Increment pitch (while on pitch section)            |
| A+down      | Decrement pitch (while on pitch section)            |
| X+up        | Transpose notes to the right up                     |
| X+down      | Transpose notes to the right down                   |
| X+left      | Shift pattern to the left                           |
| X+right     | Shift pattern to the right                          |
| B           | Remove modifier/gate and advance cursor             |
| Y+up        | Increment pattern base pitch                        |
| Y+down      | Decrement pattern base pitch                        |
| Y+left      | Decrement pattern length                            |
| Y+right     | Increment pattern length                            |
| R1          | Switch to arranger                                  |

### Drum machine pattern sequencer

       ptn:01
    bd ................
    sd ................
    ch ................
    oh ................
    lt ................
    ht ................
    cy ................
    rs ................
    cp ................
    ac ................
    ·· ................

The drum machine sequencer is arranged as rows of steps, each row
representing either an instrument (bd, sd, ch, oh, lt, ht, cy, rs, cp) or
an effect (ac, ··).

If drum instruments are muted (via the global button combinations), it will be
indicated using color in the drum pattern sequencer instrument name column.

Instruments:

* bd: bass drum
* sd: snare drum
* ch: closed hi-hat
* oh: open hi-hat
* lt: low tom
* ht: high tom
* cy: cymbal
* rs: rimshot
* cp: hand clap

Effects:

* ac: accent; play all instruments triggered on the same step louder
* ··: retrigger; play all the instruments triggered on the same step twice

Controls:

| Button(s)   | Effect                                              |
| ----------- | --------------------------------------------------- |
| up          | Navigate to previous instrument/effect              |
| down        | Navigate to next instrument/effect                  |
| left        | Navigate to previous step                           |
| right       | Navigate to next step                               |
| A           | Toggle trigger and advance cursor                   |
| B           | Remove trigger and advance cursor                   |
| Y+left      | Decrement pattern length                            |
| Y+right     | Increment pattern length                            |
| X+left      | Rotate pattern left                                 |
| X+right     | Rotate pattern right                                |
| R1          | Switch to arranger                                  |

### Mixer

    ♪ B1 B2 bd sd hh tm cy rs cp
      ━━ ━━ ━━ ━━ ━━ ━━ ━━ ━━ ━━
    ↕ 80 80 80 80 80 80 80 80 80
    ↔ 80 80 80 80 80 80 80 80 80
    ░ 00 00 00 00 00 00 00 00 00
    ◄ 00 00 00 00 00 00 00 00 00

The bassline synthesizers' and drum machine's output signals are all mixed
together in the mixer. The mixer is also connected to a stereo feedback
delay as a send effect, and each channel can optionally be attenuated by
an envelope following the bass drum (referred to as "ducking" below).

Symbol legend:

| Symbol | Purpose                  |
| ------ | ------------------------ |
| ↕      | Volume                   |
| ↔      | Panning (80 = center)    |
| ░      | Delay send amount        |
| ◄      | Bass drum ducking amount |

Controls:

| Button(s)   | Effect                                              |
| ----------- | --------------------------------------------------- |
| up          | Navigate to previous setting                        |
| down        | Navigate to next setting                            |
| left        | Navigate to previous channel                        |
| right       | Navigate to next channel                            |
| A+up        | Increase current setting by 16                      |
| A+down      | Decrease current setting by 16                      |
| A+left      | Decrement current setting                           |
| A+right     | Increment current setting                           |
| R1          | Switch to settings                                  |

### Settings

    drive:      00 bass1: pd
    accent:     00 bass2: pd
    duck time:  40
    delay time: 40
    delay fb:   80
    delay duck: 80
    swing:      00
    drum kit:   R7

    theme: forest  swap btn: no
    font: mcr      auto-adv: yes
    fullscr: no    joyless: no

These musical settings are included in snapshots:

* drive: drive amount on the master output
* accent: higher values lower volume of non-accented drum notes
* duck time: The decay time of the bass drum ducking envelope (unspecified
  unit)
* delay time: delay line time specified in 16ths of a step's length given
  the current tempo. For example, 30 is three steps.
* delay fb: the delay feedback amount
* delay duck: bass drum ducking amount for the delay return
* swing: controls the time ratio between odd and even steps, allowing for
  16th note swing
* drum kit: the built-in drum kit sample set to use
* bass1 and bass2: the synthesis mode of the bassline synthesizers

These settings concern the whole program and are not included in snapshots:

* theme: the color theme to use for the user interface
* swap btn: swap A with B and X with Y
* font: font type to use for drawing the screen
* auto-adv: auto-advance cursor in pattern sequencer or not
* fullscr: toggle fullscreen
* joyless: activate joyless mode (see Joyless mode in the controls section)

Controls:

| Button(s)   | Effect                                              |
| ----------- | --------------------------------------------------- |
| up          | Navigate to previous setting                        |
| down        | Navigate to next setting                            |
| left        | Select the left menu column                         |
| right       | Select the right menu column                        |
| A+up        | Increase current setting by 16 (for numbers)        |
| A+down      | Decrease current setting by 16 (for numbers)        |
| A+left      | Decrement current setting/previous value            |
| A+right     | Increment current setting/next value                |
| A           | Toggle boolean setting                              |
| R1          | Switch to mixer                                     |

## Command line arguments

    Usage: pocketacid [OPTIONS] [savedir]

    Options:
    --help
            Display this information
    --nokeyboard
            Disable keyboard input

If a savedir is not supplied, a default location appropriate for the OS
will be used (via [`SDL_GetPrefPath`](https://wiki.libsdl.org/SDL2/SDL_GetPrefPath)).
This is where the configuration and project files will be saved.

## Acknowledgement

This project uses resources from multiple authors:

* Some of the [UNSCII fonts](http://viznut.fi/unscii/) by Viznut, which are
  distributed as being in the public domain.
* `stb_image.h` from [stb](https://github.com/nothings/stb), which
  is distributed as being in the Public Domain as defined by
  [unlicense.org](https://unlicense.org/).
* [SDL2](https://www.libsdl.org/), which is included under the zlib license.
  See README-SDL.txt for more information.
* The [Zig](https://ziglang.org/) standard library. The Zig license (MIT) is
  retrieved upon building and is included in the release archives.
* [Salkinitzor](https://salkinitzor.bandcamp.com/) made the N1 drum kit sounds
* [Andreya](https://soundcloud.com/aliv_music/) made the AN drum kit sounds
* [Ess](https://github.com/ess-m) made the OS X build script

## Copyright and license

    Pocket Acid
    Copyright (C)  2025-2026 Philip Linde
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
