// Copyright (C) 2025-2026  Philip Linde
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

const samples = @import("samples.zig");
const Kit = @import("Kit.zig");
const DrumMachine = @This();
const Mixer = @import("Mixer.zig");
const midi = @import("midi.zig");
const a = @import("access.zig");
const Ducker = @import("Ducker.zig");
const TextMatrix = @import("TextMatrix.zig");
const Theme = @import("Theme.zig");

pub const Mutes = packed struct(u8) {
    pub const Group = enum { bd, sd, hhcy, tm, b1, b2, rscp };

    bd: bool = false,
    sd: bool = false,
    hhcy: bool = false,
    tm: bool = false,
    b1: bool = false,
    b2: bool = false,
    rscp: bool = false,

    _: u1 = 0,

    pub fn toggle(self: *Mutes, comptime group: Group) void {
        var new = @atomicLoad(Mutes, self, .seq_cst);
        switch (group) {
            inline else => |v| @field(new, @tagName(v)) = !@field(new, @tagName(v)),
        }
        @atomicStore(Mutes, self, new, .seq_cst);
    }

    pub fn get(self: *const Mutes, comptime group: Group) bool {
        const copy = @atomicLoad(Mutes, self, .seq_cst);
        return switch (group) {
            inline else => |v| @field(copy, @tagName(v)),
        };
    }

    pub fn display(self: *const Mutes, theme: *const Theme, tm: *TextMatrix, x: usize, y: usize) void {
        const Pair = struct { muted: bool, char: u8 };
        const m = @atomicLoad(Mutes, self, .seq_cst);

        const pairs = [_]Pair{
            .{ .char = '1', .muted = m.b1 },
            .{ .char = '2', .muted = m.b2 },
            .{ .char = 'b', .muted = m.bd },
            .{ .char = 's', .muted = m.sd },
            .{ .char = 'h', .muted = m.hhcy },
            .{ .char = 't', .muted = m.tm },
            .{ .char = 'r', .muted = m.rscp },
        };

        for (&pairs, 0..) |pair, i| {
            const attrib = if (pair.muted)
                theme.hilight
            else
                theme.hilight2;

            tm.putch(x + i, y, attrib, pair.char);
        }
    }
};
pub const Params = struct {
    accent: u8 = 0x40,
    kit: Kit.Id = .R6,
    duck_time: u8 = 0x20,
};

channel: u4,
params: *const Params,
mutes: *Mutes,

ducker: Ducker = .{},

bd: samples.Player = .{},
sd: samples.Player = .{},
hh: samples.Player = .{},
lt: samples.Player = .{},
ht: samples.Player = .{},
cy: samples.Player = .{},
xx: samples.Player = .{},
yy: samples.Player = .{},

pub inline fn next(self: *DrumMachine, mixer: *Mixer, srate: f32) void {
    mixer.channels[2].in = self.bd.next(srate);
    mixer.channels[3].in = self.sd.next(srate);
    mixer.channels[4].in = self.hh.next(srate);
    mixer.channels[5].in = self.lt.next(srate) + self.ht.next(srate);
    mixer.channels[6].in = self.cy.next(srate);
    mixer.channels[7].in = self.xx.next(srate);
    mixer.channels[8].in = self.yy.next(srate);
}

pub fn handleMidiEvent(self: *DrumMachine, event: midi.Event) void {
    if ((event.channel() orelse return) != self.channel) return;

    switch (event) {
        .note_on => |e| {
            if (e.velocity == 0) return;
            const lev: f32 = if (e.velocity < 96)
                @as(f32, @floatFromInt(@as(u8, 0xff) - a.get(self.params, .accent))) / 0xff
            else
                1;

            const bdm = self.mutes.get(.bd);
            const sdm = self.mutes.get(.sd);
            const hhcym = self.mutes.get(.hhcy);
            const tmm = self.mutes.get(.tm);
            const rscpm = self.mutes.get(.rscp);

            const kit = a.get(self.params, .kit).resolve();

            switch (e.pitch) {
                0 => if (!bdm) {
                    self.bd.trigger(kit.bd, lev);
                    self.ducker.trigger();
                },
                1 => if (!sdm) self.sd.trigger(kit.sd, lev),
                2 => if (!hhcym) self.hh.trigger(kit.ch, lev),
                3 => if (!hhcym) self.hh.trigger(kit.oh, lev),
                4 => if (!hhcym) self.hh.trigger(kit.choh, lev),
                5 => if (!tmm) self.lt.trigger(kit.lt, lev),
                6 => if (!tmm) self.ht.trigger(kit.ht, lev),
                7 => if (!hhcym) self.cy.trigger(kit.cy, lev),
                8 => if (!rscpm) self.xx.trigger(kit.xx, lev),
                9 => if (!rscpm) self.yy.trigger(kit.yy, lev),
                else => {},
            }
        },
        else => {},
    }
}
