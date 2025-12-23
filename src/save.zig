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

const std = @import("std");

const DrumPattern = @import("DrumPattern.zig");
const PDBass = @import("PDBass.zig");
const DrumMachine = @import("DrumMachine.zig");
const BassPattern = @import("BassPattern.zig");
const Arranger = @import("Arranger.zig");
const MixerEditor = @import("MixerEditor.zig");
const Mixer = @import("Mixer.zig");
const StereoFeedbackDelay = @import("StereoFeedbackDelay.zig");
const Ducker = @import("Ducker.zig");
const Kit = @import("Kit.zig");
const Params = @import("Params.zig");
const Snapshot = @import("Snapshot.zig");

var chunkbuf: [0xffff]u8 = undefined;

pub const ChunkTag = enum {
    // patterns
    BPAT,
    DPAT,

    // arrangement columns
    ARR1,
    ARR2,
    ARR3,

    // Snapshots
    SNAP,

    // Arranger state
    ARRS,

    // Mixer editor state
    MXED,

    // Params
    PARM,

    fn str(self: ChunkTag) [4]u8 {
        return switch (self) {
            inline else => |tag| @tagName(tag).*,
        };
    }
};

pub const State = struct {
    params: *Params,
    arr1: *[256]u8,
    arr2: *[256]u8,
    arr3: *[256]u8,
    bpat: *[256]BassPattern,
    dpat: *[256]DrumPattern,
    arranger: *Arranger,
    mixer_editor: *MixerEditor,
    snapshots: *[256]Snapshot,
    snap_map: *[256]u8,
};

fn writeChunk(tag: ChunkTag, version: u16, data: []const u8, w: std.io.AnyWriter) !void {
    if (data.len > 0xffff) return error.TooBigChunk;

    try w.writeAll(&tag.str());
    try w.writeInt(u16, version, .little);
    try w.writeInt(u16, @intCast(data.len), .little);
    try w.writeAll(data);
}

const ChunkHandle = struct {
    tag: ChunkTag,
    version: u16,
    w: std.io.FixedBufferStream([]u8),

    fn finalize(self: *const ChunkHandle, w: std.io.AnyWriter) !void {
        try writeChunk(self.tag, self.version, self.w.buffer[0..self.w.pos], w);
    }
};

fn beginChunk(tag: ChunkTag, version: u16) ChunkHandle {
    return .{
        .tag = tag,
        .version = version,
        .w = .{ .buffer = &chunkbuf, .pos = 0 },
    };
}

pub fn load(dir: std.fs.Dir, fname: []const u8, state: State) !void {
    const stderr = std.io.getStdErr().writer().any();
    const file = dir.openFile(fname, .{ .mode = .read_only }) catch |err| {
        if (err == error.FileNotFound) return else {
            stderr.print("failed to open save file: {}\n", .{err}) catch {};
            return err;
        }
    };
    defer file.close();

    var br = std.io.bufferedReader(file.reader());

    loadReader(br.reader().any(), state) catch |err| {
        stderr.print("failed to load save file: {}\n", .{err}) catch {};
        return err;
    };
}

pub fn save(dir: std.fs.Dir, fname: []const u8, tmpname: []const u8, state: State) void {
    const stderr = std.io.getStdErr().writer().any();
    {
        const f = dir.createFile(tmpname, .{}) catch |err| {
            stderr.print("failed to create temporary save file: {}\n", .{err}) catch {};
            return;
        };
        const writer = f.writer().any();
        defer f.close();

        saveWriter(writer, state) catch |err| {
            stderr.print("failed to write save: {}\n", .{err}) catch {};
            return;
        };
    }
    dir.rename(tmpname, fname) catch |err| {
        stderr.print("failed to rename temporary save file: {}\n", .{err}) catch {};
        return;
    };
}

pub fn loadReader(r: std.io.AnyReader, s: State) !void {
    chunkloop: while (true) {
        var tagnamebuf: [4]u8 = undefined;
        r.readNoEof(&tagnamebuf) catch |err| {
            if (err == error.EndOfStream)
                break :chunkloop
            else
                return err;
        };
        const tag = std.meta.stringToEnum(ChunkTag, &tagnamebuf) orelse return error.UnknownTag;
        const version = try r.readInt(u16, .little);
        const len = try r.readInt(u16, .little);

        switch (tag) {
            .ARRS => try readArrangerState(r, s.arranger, version, len),
            .BPAT => try readBassPatterns(r, s.bpat, version, len),
            .DPAT => try readDrumPatterns(r, s.dpat, version, len),
            .ARR1 => try readArr(r, s.arr1, version, len),
            .ARR2 => try readArr(r, s.arr2, version, len),
            .ARR3 => try readArr(r, s.arr3, version, len),
            .MXED => try readMixerEditorState(r, s.mixer_editor, version, len),
            .PARM => try readParams(r, s.params, version, len),
            .SNAP => try readSnapshots(r, s.snapshots, version, len),
        }
    }
}

fn readSnapshots(r: std.io.AnyReader, snapshots: *[256]Snapshot, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 73 * 256) return error.SnapshotsBadLength;

            for (0..256) |i| {
                const enabled = 0 != (try r.readInt(u8, .little));
                try bareReadParams(r, &snapshots[i].params);
                @atomicStore(bool, &snapshots[i].enabled, enabled, .seq_cst);
            }
        },
        else => return error.SnapshotsBadVersion,
    }
}

fn readParams(r: std.io.AnyReader, params: *Params, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 72) return error.BadParamLen;
            try bareReadParams(r, params);
        },
        else => return error.BadParamVersion,
    }
}

fn bareReadParams(r: std.io.AnyReader, params: *Params) !void {
    // Engine (4)
    params.engine.set(.bpm, try r.readInt(i16, .little));
    params.engine.set(.drive, try r.readInt(u8, .little));
    params.engine.set(.mutes, @bitCast(try r.readInt(u8, .little)));
    params.engine.set(.swing, try r.readInt(u8, .little));

    // Bass synths (28)
    try readBassPatch(r, &params.bass1);
    try readBassPatch(r, &params.bass2);

    // Drums (33)
    params.drums.set(.accent, try r.readInt(u8, .little));
    var kitnamebuf: [2]u8 = undefined;
    try r.readNoEof(&kitnamebuf);
    const kit = std.meta.stringToEnum(Kit.Id, &kitnamebuf) orelse return error.DrumKitBadId;
    params.drums.set(.kit, kit);
    params.drums.set(.duck_time, try r.readInt(u8, .little));

    // Delay (36)
    params.delay.set(.time, try r.readInt(u8, .little));
    params.delay.set(.feedback, try r.readInt(u8, .little));
    params.delay.set(.duck, try r.readInt(u8, .little));

    // Mixer (72)
    for (0..Mixer.nchannels) |i| {
        params.mixer[i].set(.level, try r.readInt(u8, .little));
        params.mixer[i].set(.pan, try r.readInt(u8, .little));
        params.mixer[i].set(.send, try r.readInt(u8, .little));
        params.mixer[i].set(.duck, try r.readInt(u8, .little));
    }
}

fn readBassPatch(r: std.io.AnyReader, params: *PDBass.Params) !void {
    params.set(.timbre, try readFloat01(r));
    params.set(.mod_depth, try readFloat01(r));
    params.set(.res, try readFloat01(r));
    params.set(.feedback, try readFloat01(r));
    params.set(.decay, try readFloat01(r));
    params.set(.accentness, try readFloat01(r));
}

fn readMixerEditorState(r: std.io.AnyReader, mixer_editor: *MixerEditor, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 2) return error.MixerEditorStateBadLen;

            const channel = try r.readInt(u8, .little);
            if (channel >= Mixer.nchannels)
                return error.MixerEditorStateBadChannel;
            mixer_editor.selected_channel = channel;

            const row_ch = try r.readInt(u8, .little);
            switch (row_ch) {
                'l' => mixer_editor.selected_row = .lvl,
                'p' => mixer_editor.selected_row = .pan,
                's' => mixer_editor.selected_row = .snd,
                'd' => mixer_editor.selected_row = .dck,
                else => return error.MixerEditorStateBadRow,
            }
        },
        else => return error.MixerEditorStateBadVersion,
    }
}

fn readArrangerState(r: std.io.AnyReader, arranger: *Arranger, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 2) return error.ArrangerStateBadLen;

            const column = try r.readInt(u8, .little);
            const row = try r.readInt(u8, .little);

            if (column >= 3) return error.ArrangerStateColumnOutOfRange;

            arranger.column = column;
            arranger.row = row;
        },
        else => return error.ArrangerStateBadVersion,
    }
}

fn readBassPatterns(r: std.io.AnyReader, patterns: *[256]BassPattern, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != (2 + BassPattern.maxlen) * 255) return error.BassPatternsBadLen;
            for (0..255) |i| {
                try readBassPattern(r, &patterns.*[i]);
            }
        },
        else => return error.BassPatternsBadVersion,
    }
}

fn readBassPattern(r: std.io.AnyReader, pattern: *BassPattern) !void {
    const len = try r.readInt(u8, .little);
    if (len > BassPattern.maxlen) return error.BassPatternLenNotInRange;
    pattern.len = len;

    const base = try r.readInt(u8, .little);
    if (base > 127) return error.BassPatternBaseNotInRange;
    pattern.base = @intCast(base);

    for (0..BassPattern.maxlen) |i| {
        pattern.steps[i] = @bitCast(try r.readInt(u8, .little));
    }
}

fn readDrumPatterns(r: std.io.AnyReader, patterns: *[256]DrumPattern, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != (1 + 2 * DrumPattern.maxlen) * 255) return error.DrumPatternsBadLen;
            for (0..255) |i| try readDrumPattern(r, &patterns.*[i]);
        },
        2 => {
            if (len != (1 + 2 + 2 * DrumPattern.maxlen) * 255) return error.DrumPatternsBadLen;
            for (0..255) |i| try readDrumPattern2(r, &patterns.*[i]);
        },
        else => return error.DrumPatternsBadVersion,
    }
}

fn readDrumPattern(r: std.io.AnyReader, pattern: *DrumPattern) !void {
    const len = try r.readInt(u8, .little);
    if (len > DrumPattern.maxlen) return error.DrumPatternLenNotInRange;
    pattern.len = len;

    for (0..DrumPattern.maxlen) |i| {
        const step_int = try r.readInt(u16, .little);
        pattern.steps[i] = @bitCast(step_int);
    }
}

fn readDrumPattern2(r: std.io.AnyReader, pattern: *DrumPattern) !void {
    const len = try r.readInt(u8, .little);
    if (len > DrumPattern.maxlen) return error.DrumPatternLenNotInRange;
    pattern.len = len;

    var kitnamebuf: [2]u8 = undefined;
    try r.readNoEof(&kitnamebuf);
    const kit = std.meta.stringToEnum(Kit.Id, &kitnamebuf) orelse return error.DrumPatternBadKit;

    _ = kit;

    for (0..DrumPattern.maxlen) |i| {
        const step_int = try r.readInt(u16, .little);
        pattern.steps[i] = @bitCast(step_int);
    }
}

fn readFloat01(r: std.io.AnyReader) !f32 {
    return @as(f32, @floatFromInt(try r.readInt(u16, .little))) / 0xffff;
}

fn readArr(r: std.io.AnyReader, arr: *[256]u8, version: u16, len: u16) !void {
    switch (version) {
        1 => {
            if (len != 256) return error.ArrBadLen;
            try r.readNoEof(arr);
        },
        else => return error.ArrUnknownVersion,
    }
}

pub fn saveWriter(w: std.io.AnyWriter, s: State) !void {
    var handle = beginChunk(.ARR1, 1);
    {
        const hw = handle.w.writer().any();
        for (0..256) |i| {
            try hw.writeInt(u8, @atomicLoad(u8, &s.arr1[i], .seq_cst), .little);
        }
    }
    try handle.finalize(w);

    handle = beginChunk(.ARR2, 1);
    {
        const hw = handle.w.writer().any();
        for (0..256) |i| {
            try hw.writeInt(u8, @atomicLoad(u8, &s.arr2[i], .seq_cst), .little);
        }
    }
    try handle.finalize(w);

    handle = beginChunk(.ARR3, 1);
    {
        const hw = handle.w.writer().any();
        for (0..256) |i| {
            try hw.writeInt(u8, @atomicLoad(u8, &s.arr3[i], .seq_cst), .little);
        }
    }
    try handle.finalize(w);

    handle = beginChunk(.BPAT, 1);
    {
        const hw = handle.w.writer().any();
        for (0..255) |i| {
            const pat = &s.bpat.*[i];

            try hw.writeInt(u8, pat.length(), .little);
            try hw.writeInt(u8, pat.getBase(), .little);

            for (0..BassPattern.maxlen) |j| {
                try hw.writeInt(u8, @bitCast(pat.steps[j].copy()), .little);
            }
        }
    }
    try handle.finalize(w);

    handle = beginChunk(.DPAT, 1);
    {
        const hw = handle.w.writer().any();
        for (0..255) |i| {
            const pat = &s.dpat.*[i];

            try hw.writeInt(u8, pat.length(), .little);

            for (0..DrumPattern.maxlen) |j| {
                const step_int: u16 = @bitCast(pat.steps[j].copy());
                try hw.writeInt(u16, step_int, .little);
            }
        }
    }
    try handle.finalize(w);

    handle = beginChunk(.PARM, 1);
    try writeParams(handle.w.writer().any(), s.params);
    try handle.finalize(w);

    handle = beginChunk(.ARRS, 1);
    {
        const hw = handle.w.writer().any();
        try hw.writeInt(u8, s.arranger.column, .little);
        try hw.writeInt(u8, s.arranger.row, .little);
    }
    try handle.finalize(w);

    handle = beginChunk(.MXED, 1);
    {
        const hw = handle.w.writer().any();

        try hw.writeInt(u8, s.mixer_editor.selected_channel, .little);

        const row_ch: u8 = switch (s.mixer_editor.selected_row) {
            .lvl => 'l',
            .pan => 'p',
            .snd => 's',
            .dck => 'd',
        };
        try hw.writeInt(u8, row_ch, .little);
    }
    try handle.finalize(w);

    handle = beginChunk(.SNAP, 1);
    {
        const hw = handle.w.writer().any();

        for (0..256) |i| {
            const snap_idx = @atomicLoad(u8, &s.snap_map[i], .seq_cst);
            try hw.writeInt(u8, if (s.snapshots[snap_idx].active()) 1 else 0, .little);
            try writeParams(hw, &s.snapshots[snap_idx].params);
        }
    }
    try handle.finalize(w);
}

fn writeParams(w: std.io.AnyWriter, params: *const Params) !void {
    // engine
    try w.writeInt(i16, params.engine.get(.bpm), .little);
    try w.writeInt(u8, params.engine.get(.drive), .little);
    try w.writeInt(u8, @bitCast(params.engine.get(.mutes)), .little);
    try w.writeInt(u8, params.engine.get(.swing), .little);

    // Bass synths
    try writeBassParams(w, &params.bass1);
    try writeBassParams(w, &params.bass2);

    // Drums
    try w.writeInt(u8, params.drums.get(.accent), .little);
    try w.writeAll(@tagName(params.drums.get(.kit)));
    try w.writeInt(u8, params.drums.get(.duck_time), .little);

    // Delay
    try w.writeInt(u8, params.delay.get(.time), .little);
    try w.writeInt(u8, params.delay.get(.feedback), .little);
    try w.writeInt(u8, params.delay.get(.duck), .little);

    // Mixer
    for (0..Mixer.nchannels) |i| {
        try w.writeInt(u8, params.mixer[i].get(.level), .little);
        try w.writeInt(u8, params.mixer[i].get(.pan), .little);
        try w.writeInt(u8, params.mixer[i].get(.send), .little);
        try w.writeInt(u8, params.mixer[i].get(.duck), .little);
    }
}

fn writeBassParams(w: std.io.AnyWriter, params: *const PDBass.Params) !void {
    try writeParam01(w, params.get(.timbre));
    try writeParam01(w, params.get(.mod_depth));
    try writeParam01(w, params.get(.res));
    try writeParam01(w, params.get(.feedback));
    try writeParam01(w, params.get(.decay));
    try writeParam01(w, params.get(.accentness));
}

fn writeParam01(w: std.io.AnyWriter, val: f32) !void {
    const capped: f32 = 0xffff * @min(1, @max(0, val));
    const int: u16 = @intFromFloat(@round(capped));

    try w.writeInt(u16, int, .little);
}
