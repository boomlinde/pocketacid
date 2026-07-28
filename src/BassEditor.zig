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
const BassPattern = @import("BassPattern.zig");
const Step = BassPattern.Step;
const InputState = @import("ButtonHandler.zig").States;
const TextMatrix = @import("TextMatrix.zig");
const PlaybackInfo = @import("PlaybackInfo.zig").PlaybackInfo;
const Theme = @import("Theme.zig");

const NoteInfo = struct {
    str: []const u8,
    inv: bool,
};

const notes = [12]NoteInfo{
    .{ .str = "C", .inv = false },
    .{ .str = "C#", .inv = true },
    .{ .str = "D", .inv = false },
    .{ .str = "D#", .inv = true },
    .{ .str = "E", .inv = false },
    .{ .str = "F", .inv = false },
    .{ .str = "F#", .inv = true },
    .{ .str = "G", .inv = false },
    .{ .str = "G#", .inv = true },
    .{ .str = "A", .inv = false },
    .{ .str = "A#", .inv = true },
    .{ .str = "B", .inv = false },
};

const Row = enum {
    pitch,
    octup,
    octdown,
    slide,
    accent,

    fn next(self: *Row) void {
        self.* = switch (self.*) {
            .pitch => .octup,
            .octup => .octdown,
            .octdown => .slide,
            .slide => .accent,
            .accent => .accent,
        };
    }

    fn prev(self: *Row) void {
        self.* = switch (self.*) {
            .pitch => .pitch,
            .octup => .pitch,
            .octdown => .octup,
            .slide => .octdown,
            .accent => .slide,
        };
    }
};

const Request = enum { none, prev, next };

bank: []BassPattern,
pattern_idx: usize = 0,
idx: usize = 0,
blink: f32 = 0,
buffer: u4 = 0,
row: Row = .pitch,
changedpitch: bool = false,

pub inline fn setPattern(self: *@This(), pat: u8) void {
    self.pattern_idx = pat;
    self.idx = @min(self.idx, self.selectedPattern().length() - 1);
}

pub fn handle(self: *@This(), input: InputState, autoadvance: bool) Request {
    const step = self.selectedStep();

    if (input.hold.any()) self.blink = 0;

    if (input.combo("up")) {
        self.row.prev();
        return .none;
    }
    if (input.combo("down")) {
        self.row.next();
        return .none;
    }
    if (input.combo("right")) return self.nextIdx();
    if (input.combo("left")) return self.prevIdx();

    if (input.hold.y) {
        const sp = self.selectedPattern();
        if (input.repeat.left) {
            sp.decLength();
            self.idx = @min(self.idx, sp.length() - 1);
        }
        if (input.repeat.right) sp.incLength();

        if (input.repeat.up) self.selectedPattern().incBase();
        if (input.repeat.down) self.selectedPattern().decBase();

        return .none;
    }

    if (input.hold.x) {
        if (input.repeat.up) self.incRight();
        if (input.repeat.down) self.decRight();
        if (input.repeat.left) self.rotLeft();
        if (input.repeat.right) self.rotRight();
        return .none;
    }

    if (self.row == .pitch) {
        var sc = step.copy();

        if ((input.press.a) and sc.pitch == BassPattern.off) {
            sc.pitch = self.buffer;
            step.assume(sc);
            self.changedpitch = true;
        }

        if (sc.pitch != BassPattern.off) {
            if (input.hold.a) {
                if (input.repeat.up) {
                    self.changedpitch = true;
                    sc.pitch = @min(12, sc.pitch + 1);
                    if (sc.pitch != BassPattern.off) self.buffer = sc.pitch;
                    step.assume(sc);
                } else if (input.repeat.down) {
                    self.changedpitch = true;
                    if (sc.pitch != 0) sc.pitch = sc.pitch - 1;
                    if (sc.pitch != BassPattern.off) self.buffer = sc.pitch;
                    step.assume(sc);
                }
            }
        }

        if (input.release.a) {
            if (!self.changedpitch) {
                if (sc.pitch != BassPattern.off) self.buffer = sc.pitch;
                sc.pitch = BassPattern.off;
                step.assume(sc);
            }
            self.changedpitch = false;
            if (autoadvance) return self.nextIdx();
        }
    }

    if (input.repeat.a) switch (self.row) {
        .pitch => {},
        .octup => {
            var c = step.copy();
            c.octup = !c.octup;
            step.assume(c);
            if (autoadvance) return self.nextIdx();
        },
        .octdown => {
            var c = step.copy();
            c.octdown = !c.octdown;
            step.assume(c);
            if (autoadvance) return self.nextIdx();
        },
        .slide => {
            var c = step.copy();
            c.slide = !c.slide;
            step.assume(c);
            if (autoadvance) return self.nextIdx();
        },
        .accent => {
            var c = step.copy();
            c.accent = !c.accent;
            step.assume(c);
            if (autoadvance) return self.nextIdx();
        },
    };

    if (input.repeat.b) switch (self.row) {
        .pitch => {
            var c = step.copy();
            c.pitch = BassPattern.off;
            step.assume(c);
            if (autoadvance) return self.nextIdx();
        },
        .octup => {
            var c = step.copy();
            c.octup = false;
            step.assume(c);
            if (autoadvance) return self.nextIdx();
        },
        .octdown => {
            var c = step.copy();
            c.octdown = false;
            step.assume(c);
            if (autoadvance) return self.nextIdx();
        },
        .slide => {
            var c = step.copy();
            c.slide = false;
            step.assume(c);
            if (autoadvance) return self.nextIdx();
        },
        .accent => {
            var c = step.copy();
            c.accent = false;
            step.assume(c);
            if (autoadvance) return self.nextIdx();
        },
    };

    return .none;
}

fn selectedStep(self: *const @This()) *BassPattern.Step {
    return &self.selectedPattern().steps[self.idx];
}

pub fn selectedPattern(self: *const @This()) *BassPattern {
    return &self.bank[self.pattern_idx];
}

fn nextIdx(self: *@This()) Request {
    self.idx = (self.idx + 1) % self.selectedPattern().length();
    return if (self.idx == 0) .next else .none;
}

fn prevIdx(self: *@This()) Request {
    if (self.idx != 0) {
        self.idx = (self.idx - 1) % self.selectedPattern().length();
        return .none;
    } else {
        self.idx = self.selectedPattern().length() - 1;
        return .prev;
    }
}

fn incRight(self: *@This()) void {
    for (self.idx..self.selectedPattern().length()) |i| {
        const step = &self.selectedPattern().steps[i];
        var s = @atomicLoad(BassPattern.Step, step, .seq_cst);
        if (s.pitch != BassPattern.off) {
            s.pitch = @min(12, s.pitch + 1);
            @atomicStore(BassPattern.Step, step, s, .seq_cst);
        }
    }
}

fn decRight(self: *@This()) void {
    for (self.idx..self.selectedPattern().length()) |i| {
        const step = &self.selectedPattern().steps[i];
        var s = @atomicLoad(BassPattern.Step, step, .seq_cst);
        if (s.pitch != BassPattern.off) {
            if (s.pitch != 0) s.pitch -= 1;
            @atomicStore(BassPattern.Step, step, s, .seq_cst);
        }
    }
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

pub fn display(
    self: *@This(),
    tm: *TextMatrix,
    x: usize,
    y: usize,
    dt: f32,
    active: bool,
    pi: PlaybackInfo,
    c: *const Theme,
) void {
    const pattern = self.selectedPattern();
    const pattern_len = pattern.length();
    const base = pattern.getBase();

    const faded = c.faded(0.5);
    const colors = if (active) c else &faded;

    const on = active and @mod(self.blink * 4, 1) < 0.5;

    tm.print(x + 3, y, colors.hilight2, "ptn:{x:0>2}", .{self.pattern_idx});
    tm.print(x + 11, y, colors.hilight2, "base:{s:-<2}{}", .{
        notes[base % 12].str,
        (base / 12) - 1,
    });

    for (0..13) |i| {
        const basecolor: Attrib = if (pattern.steps[self.idx].pitch == @as(usize, i))
            colors.playing
        else
            colors.normal;
        const notesidx = (i + base) % 12;
        const color = if (notes[notesidx].inv) basecolor else basecolor.invert();
        tm.puts(x, y + 13 - i, color, notes[notesidx].str);
    }
    tm.putch(x + 1, y + 15, colors.normal, '+');
    tm.putch(x + 1, y + 16, colors.normal, '-');
    tm.putch(x + 1, y + 17, colors.normal, '/');
    tm.putch(x + 1, y + 18, colors.normal, 4);
    for (0..BassPattern.maxlen) |i| {
        const playing = pi.pattern == self.pattern_idx and pi.step == i and pi.running;
        self.column(tm, x + 3 + i, y, i, i < pattern_len, on, playing, colors);
    }

    self.blink = @mod(self.blink + dt, 1);
}

fn column(
    self: *const @This(),
    tm: *TextMatrix,
    x: usize,
    y: usize,
    idx: usize,
    active: bool,
    blink: bool,
    playing: bool,
    colors: *const Theme,
) void {
    const pattern = self.bank[self.pattern_idx];
    const step = pattern.steps[idx].copy();
    const selected = idx == self.idx;
    const hilight: Attrib = if (@as(usize, idx & 0x3) == 0) colors.hilight else colors.normal;
    const bgmix = Attrib{ .bg = hilight.bg, .fg = hilight.fg.interpolate(hilight.bg, 0.9) };
    const color: Attrib = if (playing) colors.playing else if (active) hilight else bgmix;
    const blinked = if (blink and selected) color.invert() else color;

    // Pitches
    for (0..13) |i| {
        const pc = if (self.row == .pitch) blinked else color;
        const ch: u8 = if (step.pitch == i) 9 else '.';
        tm.putch(x, y + 13 - i, pc, ch);
    }

    // oct up, down, accent, slide

    tm.putch(x, y + 15, if (self.row == .octup) blinked else color, if (step.octup) 9 else '.');
    tm.putch(x, y + 16, if (self.row == .octdown) blinked else color, if (step.octdown) 9 else '.');
    tm.putch(x, y + 17, if (self.row == .slide) blinked else color, if (step.slide) 9 else '.');
    tm.putch(x, y + 18, if (self.row == .accent) blinked else color, if (step.accent) 9 else '.');
}
