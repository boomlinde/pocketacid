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

const std = @import("std");

const DigiBass = @import("DigiBass.zig");
const TextMatrix = @import("TextMatrix.zig");
const InputState = @import("ButtonHandler.zig").States;
const StereoFeedbackDelay = @import("StereoFeedbackDelay.zig");
const Attrib = @import("CharDisplay.zig").Attrib;
const FontType = @import("CharDisplay.zig").FontType;
const Kit = @import("Kit.zig");
const Theme = @import("Theme.zig");
const kits = @import("kits.zig");

pub const Entry = union(enum) {
    u8: U8Entry,
    bool: BoolEntry,
    Kit: KitEntry,
    Theme: EnumEntry(Theme.Id),
    FontType: EnumEntry(FontType),
    BassType: EnumEntry(DigiBass.Params.Type),
    spacer,

    fn up(self: Entry) void {
        switch (self) {
            inline else => |e| if (@TypeOf(e) != void and @hasDecl(@TypeOf(e), "up")) e.up(),
        }
    }
    fn down(self: Entry) void {
        switch (self) {
            inline else => |e| if (@TypeOf(e) != void and @hasDecl(@TypeOf(e), "down")) e.down(),
        }
    }
    fn left(self: Entry) void {
        switch (self) {
            inline else => |e| if (@TypeOf(e) != void and @hasDecl(@TypeOf(e), "left")) e.left(),
        }
    }
    fn right(self: Entry) void {
        switch (self) {
            inline else => |e| if (@TypeOf(e) != void and @hasDecl(@TypeOf(e), "right")) e.right(),
        }
    }
    fn press(self: Entry) void {
        switch (self) {
            inline else => |e| if (@TypeOf(e) != void and @hasDecl(@TypeOf(e), "press")) e.press(),
        }
    }

    fn display(self: Entry, tm: *TextMatrix, x: usize, y: usize, color: Attrib) void {
        switch (self) {
            inline else => |e| if (@TypeOf(e) != void) e.display(tm, x, y, color),
        }
    }
};

pub const BoolEntry = struct {
    label: []const u8,
    ptr: *bool,
    t: []const u8 = "true",
    f: []const u8 = "false",

    fn press(self: BoolEntry) void {
        const value = @atomicLoad(bool, self.ptr, .seq_cst);
        @atomicStore(bool, self.ptr, !value, .seq_cst);
    }

    fn display(self: BoolEntry, tm: *TextMatrix, x: usize, y: usize, color: Attrib) void {
        const value = @atomicLoad(bool, self.ptr, .seq_cst);
        tm.print(x, y, color, "{s} {s}", .{ self.label, if (value) self.t else self.f });
    }
};

pub const U8Entry = struct {
    label: []const u8,
    ptr: *u8,

    inline fn up(self: U8Entry) void {
        self.inc(0x10);
    }
    inline fn down(self: U8Entry) void {
        self.dec(0x10);
    }
    inline fn left(self: U8Entry) void {
        self.dec(1);
    }
    inline fn right(self: U8Entry) void {
        self.inc(1);
    }

    fn display(self: U8Entry, tm: *TextMatrix, x: usize, y: usize, color: Attrib) void {
        const value = @atomicLoad(u8, self.ptr, .seq_cst);
        tm.print(x, y, color, "{s} {x:0>2}", .{ self.label, value });
    }

    fn inc(self: U8Entry, by: u8) void {
        const prev = @atomicLoad(u8, self.ptr, .seq_cst);
        _ = @cmpxchgStrong(u8, self.ptr, prev, prev +| by, .seq_cst, .seq_cst);
    }

    fn dec(self: U8Entry, by: u8) void {
        const prev = @atomicLoad(u8, self.ptr, .seq_cst);
        _ = @cmpxchgStrong(u8, self.ptr, prev, prev -| by, .seq_cst, .seq_cst);
    }
};

left: []const Entry,
right: []const Entry,
current: []const Entry,

idx: u8 = 0,
blink: f32 = 0,

pub fn display(
    self: *@This(),
    tm: *TextMatrix,
    x: usize,
    y: usize,
    dt: f32,
    active: bool,
    c: *const Theme,
) void {
    const faded = c.faded(0.5);
    const colors = if (active) c else &faded;
    const on = @mod(self.blink * 4, 1) < 0.5 and active;

    var vx = x;

    const menus = [_][]const Entry{ self.left, self.right };

    for (menus) |menu| {
        for (menu, 0..) |entry, i| {
            const color = if (i == self.idx and menu.ptr == self.current.ptr)
                invertIf(colors.hilight, on)
            else
                colors.normal;

            entry.display(tm, vx, y + i, color);
        }
        vx += 15;
    }

    self.blink = @mod(self.blink + dt, 1);
}

pub fn handle(self: *@This(), input: InputState, active: bool) void {
    if (!active) return;
    if (input.hold.any()) self.blink = 0;

    const entry = self.current[self.idx];
    if (input.press.a or input.press.b) entry.press();
    if (input.hold.a or input.hold.b) {
        if (input.repeat.up) entry.up();
        if (input.repeat.down) entry.down();
        if (input.repeat.left) entry.left();
        if (input.repeat.right) entry.right();
        return;
    }

    if (input.press.left and self.left.len > self.idx and self.left[self.idx] != .spacer)
        self.current = self.left;
    if (input.press.right and self.right.len > self.idx and self.right[self.idx] != .spacer)
        self.current = self.right;

    if (input.repeat.up) {
        const prev_idx = self.idx;
        self.idx -|= 1;
        while (self.current[self.idx] == .spacer and self.idx != 0)
            self.idx -|= 1;

        if (self.current[self.idx] == .spacer)
            self.idx = prev_idx;
    }
    if (input.repeat.down) {
        const prev_idx = self.idx;
        self.idx = @min(self.current.len - 1, self.idx + 1);
        while (self.current[self.idx] == .spacer and self.idx != self.current.len - 1)
            self.idx = @min(self.current.len - 1, self.idx + 1);

        if (self.current[self.idx] == .spacer)
            self.idx = prev_idx;
    }
}

fn invertIf(a: Attrib, condition: bool) Attrib {
    return if (condition)
        a.invert()
    else
        a;
}

pub fn EnumEntry(comptime E: type) type {
    return struct {
        label: []const u8,
        ptr: *E,

        fn up(self: @This()) void {
            _ = self;
        }
        fn down(self: @This()) void {
            _ = self;
        }

        fn display(self: @This(), tm: *TextMatrix, x: usize, y: usize, color: Attrib) void {
            const value = @atomicLoad(E, self.ptr, .seq_cst);
            tm.print(x, y, color, "{s} {s}", .{ self.label, @tagName(value) });
        }

        fn left(self: @This()) void {
            const current = @atomicLoad(E, self.ptr, .seq_cst);
            switch (current) {
                inline else => |v| {
                    const values = comptime std.enums.values(E);
                    const idx = comptime std.mem.indexOfScalar(E, values, v) orelse @compileError("bad EnumEntry enum value");
                    const new_idx: usize = if (idx == 0) 0 else idx - 1;

                    _ = @cmpxchgStrong(E, self.ptr, current, values[new_idx], .seq_cst, .seq_cst);
                },
            }
        }

        fn right(self: @This()) void {
            const current = @atomicLoad(E, self.ptr, .seq_cst);
            switch (current) {
                inline else => |v| {
                    const values = comptime std.enums.values(E);
                    const idx = comptime std.mem.indexOfScalar(E, values, v) orelse @compileError("bad EnumEntry enum value");
                    const new_idx: usize = if (idx == values.len - 1) values.len - 1 else idx + 1;

                    _ = @cmpxchgStrong(E, self.ptr, current, values[new_idx], .seq_cst, .seq_cst);
                },
            }
        }
    };
}

const KitEntry = struct {
    label: []const u8,
    ptr: *usize,

    fn display(self: KitEntry, tm: *TextMatrix, x: usize, y: usize, color: Attrib) void {
        const value = @atomicLoad(usize, self.ptr, .seq_cst);
        tm.print(x, y, color, "{s} {s}", .{ self.label, kits.get(value).name.slice() });
    }

    fn left(self: *const KitEntry) void {
        const value = @atomicLoad(usize, self.ptr, .seq_cst);
        @atomicStore(usize, self.ptr, kits.prev(value), .seq_cst);
    }

    fn right(self: *const KitEntry) void {
        const value = @atomicLoad(usize, self.ptr, .seq_cst);
        @atomicStore(usize, self.ptr, kits.next(value), .seq_cst);
    }
};
