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

const RGB = @import("rgb.zig").RGB;
const Attrib = @import("CharDisplay.zig").Attrib;
const NextPrevEnum = @import("NextPrevEnum.zig").NextPrevEnum;
const Theme = @This();

normal: Attrib,
hilight: Attrib,
hilight2: Attrib,
playing: Attrib,

pub fn faded(self: *const @This(), amt: f32) @This() {
    return .{
        .normal = .{ .bg = self.normal.bg, .fg = self.normal.fg.interpolate(self.normal.bg, amt) },
        .hilight = .{ .bg = self.hilight.bg, .fg = self.hilight.fg.interpolate(self.hilight.bg, amt) },
        .hilight2 = .{ .bg = self.hilight2.bg, .fg = self.hilight2.fg.interpolate(self.hilight2.bg, amt) },
        .playing = .{ .bg = self.playing.bg, .fg = self.playing.fg.interpolate(self.playing.bg, amt) },
    };
}

pub const Id = enum {
    term,
    panel,
    forest,
    papaya,

    pub fn resolve(self: Id) *const Theme {
        return switch (self) {
            .term => &term,
            .panel => &panel,
            .forest => &forest,
            .papaya => &papaya,
        };
    }

    pub fn next(self: @This()) @This() {
        return NextPrevEnum(@This(), false).next(self);
    }

    pub fn prev(self: @This()) @This() {
        return NextPrevEnum(@This(), false).prev(self);
    }
};

const term = theme(.{
    .bg = RGB.init(0, 0, 0),
    .hilight2 = RGB.init(80, 43, 255),
    .playing = RGB.init(255, 241, 232),
    .normal = RGB.init(0, 228, 54),
    .hilight = RGB.init(255, 236, 39),
});

const panel = theme(.{
    .bg = RGB.init(48, 48, 48),
    .hilight2 = RGB.init(0, 0, 0),
    .playing = RGB.init(255, 255, 255),
    .normal = RGB.init(78, 178, 212),
    .hilight = RGB.init(178, 62, 189),
});

const forest = theme(.{
    .bg = RGB.init(30, 48, 28),
    .hilight2 = RGB.init(97, 161, 87),
    .playing = RGB.init(255, 255, 255),
    .normal = RGB.init(161, 148, 87),
    .hilight = RGB.init(161, 109, 87),
});

const papaya = theme(.{
    .bg = RGB.init(0xff, 0xee, 0xcc),
    .hilight2 = RGB.init(0x44, 0x66, 0x22),
    .normal = RGB.init(0x22, 0x44, 0x66),
    .playing = RGB.init(192, 192, 0),
    .hilight = RGB.init(0x66, 0x22, 0x44),
});

fn theme(th: InnerTheme) Theme {
    return .{
        .normal = Attrib{ .fg = th.normal, .bg = th.bg },
        .hilight = Attrib{ .fg = th.hilight, .bg = th.bg },
        .hilight2 = Attrib{ .fg = th.hilight2, .bg = th.bg },
        .playing = Attrib{ .fg = th.playing, .bg = th.bg },
    };
}

const InnerTheme = struct {
    bg: RGB,
    normal: RGB,
    hilight: RGB,
    hilight2: RGB,
    playing: RGB,
};
