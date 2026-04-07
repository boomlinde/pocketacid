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

const DigiBass = @import("DigiBass.zig");
const BassSeq = @import("BassSeq.zig");
const DrumSeq = @import("DrumSeq.zig");
const MidiBuf = @import("MidiBuf.zig");
const Mixer = @import("Mixer.zig");
const DrumMachine = @import("DrumMachine.zig");
const Ducker = @import("Ducker.zig");
const StereoFeedbackDelay = @import("StereoFeedbackDelay.zig");
const calcDrive = @import("drive.zig").drive;
const song = @import("song.zig");
const GlobalParams = @import("Params.zig");
const Accessor = @import("Accessor.zig").Accessor;

const maxtempo = 300;
const mintempo = 1;

var delay_buf_left: [48000 * 10]f32 = undefined;
var delay_buf_right: [48000 * 10]f32 = undefined;

pub const Params = struct {
    bpm: i16 = 120,
    drive: u8 = 0,
    mutes: DrumMachine.Mutes = .{},
    swing: u8 = 0,

    pub usingnamespace Accessor(@This());

    pub inline fn changeTempo(self: *@This(), change: i16) void {
        const bpm = self.get(.bpm);
        const new = @min(maxtempo, @max(mintempo, bpm + change));
        self.set(.bpm, new);
    }
};

midibuf: *MidiBuf,
params: *Params = undefined,
global_params: *GlobalParams = undefined,

phase: f32 = 0,
prevphase: f32 = 0,
startrow: u8 = 0,
snapshot_row: ?u8 = null,
swing: u8 = 0x00,

bs1: BassSeq = .{
    .patterns = &song.bass_patterns,
    .arrangement = &song.bass1_arrange,
    .channel = 0,
},
bs2: BassSeq = .{
    .patterns = &song.bass_patterns,
    .arrangement = &song.bass2_arrange,
    .channel = 1,
},
ds: DrumSeq = .{
    .patterns = &song.drum_patterns,
    .arrangement = &song.drum_arrange,
    .channel = 2,
},

pdbass1: DigiBass = .{ .channel = 0, .params = undefined },
pdbass2: DigiBass = .{ .channel = 1, .params = undefined },
drums: DrumMachine = .{ .channel = 2, .params = undefined, .mutes = undefined },

delay: StereoFeedbackDelay = .{
    .left = .{ .delay = .{ .buffer = &delay_buf_left } },
    .right = .{ .delay = .{ .buffer = &delay_buf_right } },
    .params = undefined,
},

cmd: Cmd = .{},

mixer: Mixer = .{ .channels = .{
    .{ .label = "B1", .params = undefined },
    .{ .label = "B2", .params = undefined },
    .{ .label = "bd", .params = undefined },
    .{ .label = "sd", .params = undefined },
    .{ .label = "hh", .params = undefined },
    .{ .label = "tm", .params = undefined },
    .{ .label = "cy", .params = undefined },
    .{ .label = "rs", .params = undefined },
    .{ .label = "cp", .params = undefined },
} },

running: bool = false,
toggle_running: bool = false,

const CmdType = enum(u2) { none, startstop, enqueue };
const Cmd = packed struct {
    t: CmdType = .none,
    row: u8 = 0,
    _: u6 = 0,
};

pub fn init(self: *@This(), params: *GlobalParams) void {
    for (0..delay_buf_left.len) |i| delay_buf_left[i] = 0;
    for (0..delay_buf_right.len) |i| delay_buf_right[i] = 0;
    for (0..Mixer.nchannels) |i| self.mixer.channels[i].params = &params.mixer[i];

    self.global_params = params;
    self.params = &params.engine;
    self.pdbass1.params = &params.bass1;
    self.pdbass2.params = &params.bass2;
    self.drums.params = &params.drums;
    self.delay.params = &params.delay;

    self.bs1.midibuf = self.midibuf;
    self.bs2.midibuf = self.midibuf;
    self.ds.midibuf = self.midibuf;

    self.drums.mutes = &self.params.mutes;
}

pub fn resetDelay(self: *@This()) void {
    const time = @as(f32, @floatFromInt(self.delay.params.get(.time))) / 16;
    const tempo: f32 = @floatFromInt(self.params.get(.bpm));
    self.delay.smoothed_delay_time.short(StereoFeedbackDelay.calcDelayTime(time, tempo));
}

pub fn everyBuffer(self: *@This()) void {
    const cmd = @atomicRmw(Cmd, &self.cmd, .Xchg, .{}, .seq_cst);
    const running = @atomicLoad(bool, &self.running, .seq_cst);

    switch (cmd.t) {
        .startstop => {
            const snap_idx = @atomicLoad(u8, &song.snap_map[cmd.row], .seq_cst);
            const snap = &song.snapshots[snap_idx];
            if (!running and snap.active())
                self.params.set(.bpm, snap.params.engine.get(.bpm));
            self.start(cmd.row, running);
        },
        .enqueue => {
            if (!running)
                self.start(cmd.row, running)
            else {
                self.bs1.enqueue(cmd.row);
                self.bs2.enqueue(cmd.row);
                self.ds.enqueue(cmd.row);
            }
        },
        .none => {},
    }

    for (self.midibuf.emit()) |event| {
        self.pdbass1.handleMidiEvent(event);
        self.pdbass2.handleMidiEvent(event);
    }
}

fn start(self: *@This(), row: u8, running: bool) void {
    if (running) {
        @atomicStore(bool, &self.running, false, .seq_cst);
        self.bs1.stop();
        self.bs2.stop();
        self.ds.stop();
        self.snapshot_row = null;
    } else {
        emptyblk: {
            if (@atomicLoad(u8, &song.bass1_arrange[row], .seq_cst) != 0xff) break :emptyblk;
            if (@atomicLoad(u8, &song.bass2_arrange[row], .seq_cst) != 0xff) break :emptyblk;
            if (@atomicLoad(u8, &song.drum_arrange[row], .seq_cst) != 0xff) break :emptyblk;
            return;
        }
        @atomicStore(bool, &self.running, true, .seq_cst);
        self.phase = 0;
        self.prevphase = 0.999;
        self.bs1.start(row);
        self.bs2.start(row);
        self.ds.start(row);
        self.snapshot_row = null;
    }
}

var sample: u64 = 0;

pub fn next(self: *@This(), srate: f32) Mixer.Frame {
    defer sample += 1;

    const bpm: f32 = @floatFromInt(self.params.get(.bpm));
    const gated = @mod(shuffleSkew(self.phase, self.swing) * 12, 1) < 0.5;
    const prevgated = @mod(shuffleSkew(self.prevphase, self.swing) * 12, 1) < 0.5;
    const tick = gated and !prevgated;

    if (tick) {
        if (self.ds.tick()) |row| {
            const snap_idx = @atomicLoad(u8, &song.snap_map[row], .seq_cst);
            if (song.snapshots[snap_idx].active() and snap_idx != self.snapshot_row) {
                self.snapshot_row = snap_idx;
                self.global_params.assumeNoTempo(&song.snapshots[snap_idx].params);
                self.drums.ducker.current = 1;
                self.pdbass1.short();
                self.pdbass2.short();
            }
        }
        self.bs1.tick(self.params.mutes.get(.b1));
        self.bs2.tick(self.params.mutes.get(.b2));
    }

    if (self.prevphase >= self.phase) {
        // Reload swing value
        const swing = self.params.get(.swing);
        self.swing = swing;
    }

    self.prevphase = self.phase;
    self.phase = @mod(self.phase + 2 * bpm / (60 * srate), 1);

    for (self.midibuf.emit()) |event| {
        self.pdbass1.handleMidiEvent(event);
        self.pdbass2.handleMidiEvent(event);
        self.drums.handleMidiEvent(event);
    }

    // TODO can this be handled by DrumMachine itself?
    const duck = self.drums.ducker.next(self.drums.params.get(.duck_time), srate);

    // TODO better way of naming channel indices
    self.mixer.channels[0].in = self.pdbass1.next(srate);
    self.mixer.channels[1].in = self.pdbass2.next(srate);
    self.drums.next(&self.mixer, srate);

    var send: Mixer.Frame = .{};
    var out = self.mixer.mix(&send, duck);
    out.add(self.delay.next(send, bpm, duck, srate));

    const drive = self.params.get(.drive);
    return .{
        .left = calcDrive(out.left, drive),
        .right = calcDrive(out.right, drive),
    };
}

pub fn startstop(self: *@This(), row: u8) void {
    @atomicStore(Cmd, &self.cmd, .{
        .t = .startstop,
        .row = row,
    }, .seq_cst);
}

pub fn enqueue(self: *@This(), row: u8) void {
    @atomicStore(Cmd, &self.cmd, .{
        .t = .enqueue,
        .row = row,
    }, .seq_cst);
}

pub fn isRunning(self: *@This()) bool {
    return @atomicLoad(bool, &self.running, .seq_cst);
}

fn shuffleSkew(x: f32, v: u8) f32 {
    const k = (@as(f32, @floatFromInt(v)) / 255) * 0.25 + 0.5;
    const div = 4 * k * (1 - k);
    return (x + k * (1 - 2 * k) + (2 * k - 1) * @abs(x - k)) / div;
}
