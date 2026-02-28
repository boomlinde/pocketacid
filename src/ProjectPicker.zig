const std = @import("std");

const InputState = @import("ButtonHandler.zig").States;
const TextMatrix = @import("TextMatrix.zig");
const Theme = @import("Theme.zig");

const oldname = "state.sav";

const prefix = "project";
const suffix = ".sav";
const tpl = prefix ++ "00" ++ suffix;
const bak_tpl = prefix ++ "00" ++ suffix ++ ".bak";
const tmp_tpl = tpl ++ ".tmp";
const hex = "0123456789abcdef";

var namebuf: [tpl.len]u8 = undefined;
var tmpbuf: [tmp_tpl.len]u8 = undefined;
var bakbuf: [bak_tpl.len]u8 = undefined;

cursor: u8,
current: u8,

dir: std.fs.Dir,
avail: [256]bool = [1]bool{false} ** 256,
blink: f32 = 0,

pub const Request = enum { switch_project, copy_project, close_picker, reload };

pub fn migrate(dir: std.fs.Dir) !void {
    // Return if there is no state.sav
    dir.access(oldname, .{}) catch |err| {
        if (err == error.FileNotFound) return;
        return err;
    };

    // Rename to tpl if that doesn't already exist
    dir.access(tpl, .{}) catch |err| {
        if (err == error.FileNotFound) {
            try dir.rename(oldname, tpl);
            return;
        }
    };

    return error.ProjectFileExists;
}

pub fn updateAvail(self: *@This()) !void {
    var iter = self.dir.iterate();

    for (0..256) |i| self.avail[i] = false;

    while (try iter.next()) |file| switch (file.kind) {
        .file, .sym_link => {
            if (file.name.len != tpl.len) continue;
            if (!std.mem.startsWith(u8, file.name, prefix)) continue;
            if (!std.mem.endsWith(u8, file.name, suffix)) continue;
            const ms: u8 = @intCast(std.mem.indexOf(u8, hex, file.name[prefix.len .. prefix.len + 1]) orelse continue);
            const ls: u8 = @intCast(std.mem.indexOf(u8, hex, file.name[prefix.len + 1 .. prefix.len + 2]) orelse continue);
            const idx: u8 = (ms << 4) | ls;
            self.avail[idx] = true;
        },
        else => {},
    };
}

pub fn handle(self: *@This(), input: InputState) !?Request {
    if (input.hold.any()) self.blink = 0;

    if (input.hold.y and input.press.down) return .reload;
    if (input.repeat.left and self.cursor & 0xf != 0) self.cursor -= 1;
    if (input.repeat.right and self.cursor & 0xf != 0xf) self.cursor += 1;
    if (input.repeat.up and self.cursor & 0xf0 != 0) self.cursor -= 0x10;
    if (input.repeat.down and self.cursor & 0xf0 != 0xf0) self.cursor += 0x10;

    if ((input.hold.l2 and input.hold.r2 and input.press.start) or
        (input.hold.l2 and input.hold.r and input.press.start))
    {
        return .close_picker;
    }

    if (input.comboPress("start")) return .switch_project;
    if (input.comboPress("a") and !self.avail[self.cursor] and self.current != self.cursor)
        return .copy_project;
    if (input.comboPress("b") and self.avail[self.cursor] and self.current != self.cursor) {
        const fname = @This().name(self.cursor);
        const bakname = @This().bakName(self.cursor);
        self.dir.rename(fname, bakname) catch |err| {
            if (err == error.FileNotFound) return null;
            return err;
        };
        try self.updateAvail();
    }

    return null;
}

pub fn display(self: *@This(), tm: *TextMatrix, x: usize, y: usize, dt: f32, c: *const Theme) void {
    const on = @mod(self.blink * 4, 1) < 0.5;

    for (0..16) |iy| {
        for (0..16) |ix| {
            const idx: u8 = @intCast(ix | (iy << 4));
            const color = if (idx == self.current) c.hilight else c.normal;
            const cursor_attr = if (on) color.invert() else color;
            const attr = if (idx == self.cursor) cursor_attr else color;

            if (self.avail[idx])
                tm.puts(x + ix, y + iy, attr, "\xfe")
            else
                tm.puts(x + ix, y + iy, attr, "\xfa");
        }
    }
    tm.print(x, y + 16, c.hilight, "project: {x:0>2}", .{self.cursor});

    self.blink = @mod(self.blink + dt, 1);
}

pub fn name(project: u8) []const u8 {
    return std.fmt.bufPrint(&namebuf, prefix ++ "{x:0>2}" ++ suffix, .{project}) catch unreachable;
}

pub fn tmpName(project: u8) []const u8 {
    return std.fmt.bufPrint(&tmpbuf, prefix ++ "{x:0>2}" ++ suffix ++ ".tmp", .{project}) catch unreachable;
}

pub fn bakName(project: u8) []const u8 {
    return std.fmt.bufPrint(&bakbuf, prefix ++ "{x:0>2}" ++ suffix ++ ".bak", .{project}) catch unreachable;
}
