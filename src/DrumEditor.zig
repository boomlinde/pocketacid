// Copyright (C) 2025  Philip Linde
//
// This file is part of Pocket Acid.
//
// Pocket Acid is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Pocket Acid is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Pocket Acid.  If not, see <https://www.gnu.org/licenses/>.

const Attrib = @import("CharDisplay.zig").Attrib;
const InputState = @import("ButtonHandler.zig").States;
const DrumPattern = @import("DrumPattern.zig");
const DrumMachine = @import("DrumMachine.zig");
const TextMatrix = @import("TextMatrix.zig");
const PlaybackInfo = @import("PlaybackInfo.zig").PlaybackInfo;
const Theme = @import("Theme.zig");

bank: []DrumPattern,
pattern_idx: u8 = 0,
idx: u8 = 0,
blink: f32 = 0,
drumtype: DrumPattern.DrumType = .bd,

pub fn handle(self: *@This(), input: InputState, autoadvance: bool) void {
    if (input.hold.any()) self.blink = 0;

    if (input.hold.x) {
        if (input.repeat.left) self.rotLeft();
        if (input.repeat.right) self.rotRight();
        return;
    }

    if (input.hold.y) {
        if (input.repeat.left) self.selectedPattern().decLength();
        if (input.repeat.right) self.selectedPattern().incLength();
        return;
    }

    if (input.repeat.up) self.drumtype.prev();
    if (input.repeat.down) self.drumtype.next();
    if (input.repeat.left) self.prevIdx();
    if (input.repeat.right) self.nextIdx();
    if (input.repeat.a) {
        self.selectedStep().toggle(self.drumtype);
        if (autoadvance) self.nextIdx();
    }
    if (input.repeat.b) {
        self.selectedStep().set(self.drumtype, false);
        if (autoadvance) self.nextIdx();
    }
}

pub fn display(
    self: *@This(),
    tm: *TextMatrix,
    xo: usize,
    yo: usize,
    dt: f32,
    active: bool,
    pi: PlaybackInfo,
    mutes: DrumMachine.Mutes,
    c: *const Theme,
) void {
    const current_pattern = self.selectedPattern();
    const current_len = current_pattern.length();
    const on = active and @mod(self.blink * 4, 1) < 0.5;

    const faded = c.faded(0.5);
    const colors = if (active) c else &faded;

    tm.print(xo + 3, yo, colors.hilight2, "ptn:{x:0>2}", .{self.pattern_idx});

    inline for (DrumPattern.types, 0..) |t, i| {
        tm.puts(xo, yo + 1 + i, if (t.muted(mutes)) colors.hilight else colors.normal, t.str());
    }

    for (DrumPattern.types, 0..) |t, row| {
        for (0..DrumPattern.maxlen) |column| {
            const x = xo + 3 + column;
            const y = yo + 1 + row;

            const playing = pi.pattern == self.pattern_idx and pi.step == column and pi.running;

            const hilight = if (column % 4 == 0) colors.hilight else colors.normal;
            const bgmix = Attrib{ .bg = hilight.bg, .fg = hilight.fg.interpolate(hilight.bg, 0.9) };
            const base_color = if (playing)
                colors.playing
            else if (column >= current_len)
                bgmix
            else
                hilight;

            const do_marker = on and t == self.drumtype and column == self.idx and on;
            const color = if (do_marker)
                base_color.invert()
            else
                base_color;

            const step = &current_pattern.steps[column];
            if (step.get(t))
                tm.puts(x, y, color, "\x09")
            else
                tm.puts(x, y, color, ".");
        }
    }

    self.blink = @mod(self.blink + dt, 1);
}

fn selectedStep(self: *const @This()) *DrumPattern.Step {
    return &self.selectedPattern().steps[self.idx];
}

fn selectedPattern(self: *const @This()) *DrumPattern {
    return &self.bank[self.pattern_idx];
}

pub inline fn setPattern(self: *@This(), pat: u8) void {
    self.pattern_idx = pat;
    self.idx = @min(self.idx, self.selectedPattern().length() - 1);
}

inline fn nextIdx(self: *@This()) void {
    self.idx = (self.idx + 1) % self.selectedPattern().len;
}

inline fn prevIdx(self: *@This()) void {
    self.idx = if (self.idx != 0)
        (self.idx - 1) % self.selectedPattern().len
    else
        self.selectedPattern().len - 1;
}

fn rotLeft(self: *@This()) void {
    const p = self.selectedPattern();
    const plen = p.length();
    const first = p.steps[0].copy();
    for (1..plen) |i| p.steps[i - 1].assume(p.steps[i].copy());
    p.steps[plen - 1].assume(first);
}

fn rotRight(self: *@This()) void {
    const p = self.selectedPattern();
    const plen = p.length();

    var prev = p.steps[plen - 1].copy();
    for (0..plen) |i| {
        const tmp = p.steps[i].copy();
        p.steps[i].assume(prev);
        prev = tmp;
    }
}
