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
const sdl = @import("sdl.zig");
const song = @import("song.zig");

const Sys = @import("Sys.zig");
const TextMatrix = @import("TextMatrix.zig");
const CharDisplay = @import("CharDisplay.zig");
const ButtonHandler = @import("ButtonHandler.zig");
const ControllerManager = @import("ControllerManager.zig");
const ButtonState = ButtonHandler.ButtonState;
const BassEditor = @import("BassEditor.zig");
const BassPattern = @import("BassPattern.zig");
const Arranger = @import("Arranger.zig");
const JoystickHandler = @import("JoystickHandler.zig");
const PlaybackInfo = @import("PlaybackInfo.zig").PlaybackInfo;
const PDBass = @import("PDBass.zig");
const JoyMode = @import("JoyMode.zig").JoyMode;
const save = @import("save.zig");
const MixerEditor = @import("MixerEditor.zig");
const DrumEditor = @import("DrumEditor.zig");
const MasterEditor = @import("MasterEditor.zig");
const Clipboard = @import("Clipboard.zig");
const Params = @import("Params.zig");
const Config = @import("Config.zig");
const InputState = @import("ButtonHandler.zig").States;
const ProjectPicker = @import("ProjectPicker.zig");

const w = 30;
const h = 22;

const Opts = struct {
    nokeyboard: bool = false,
    savepath_override: ?[]const u8 = null,
};

pub fn main() !void {
    // Parse args
    const stderr = std.io.getStdErr().writer().any();
    var opts = Opts{};

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer {
        _ = arena.reset(.free_all);
        arena.deinit();
    }

    const args = try std.process.argsAlloc(arena.allocator());
    defer std.process.argsFree(arena.allocator(), args);

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--help")) {
            help(stderr, args[0]);
            return;
        }
        if (std.mem.eql(u8, arg, "--nokeyboard")) {
            opts.nokeyboard = true;
            continue;
        }
        if (opts.savepath_override == null)
            opts.savepath_override = arg
        else {
            help(stderr, args[0]);
            std.process.exit(1);
        }
    }

    // Init system
    var sys = try Sys.init(w * 8, h * 8);
    defer sys.cleanup();

    // Get savedir
    var savedir = if (opts.savepath_override) |sp|
        try std.fs.cwd().openDir(sp, .{ .iterate = true })
    else pathsblk: {
        const paths = try sys.paths();
        defer paths.deinit();
        break :pathsblk try std.fs.cwd().openDir(paths.pref, .{ .iterate = true });
    };
    defer savedir.close();

    // Get config
    var config = Config{};
    try config.load(savedir);
    defer config.save(savedir) catch {};

    // Migrate old savefile
    try ProjectPicker.migrate(savedir);

    // Start controller manager
    var cm = ControllerManager{};

    cm.openAll();
    defer cm.closeAll();

    // Run sequencer
    var known_fullscreen = false;
    var clipboard = Clipboard{};
    while (true) {
        var pp = ProjectPicker{
            .dir = savedir,
            .cursor = config.project,
            .current = config.project,
        };
        switch (try sequencer(
            &sys,
            savedir,
            &config,
            opts.nokeyboard,
            &pp,
            &known_fullscreen,
            &cm,
            &clipboard,
        )) {
            .exit => break,
            .reload => {},
        }
    }
}

const SeqReturn = enum { exit, reload };

pub fn sequencer(
    sys: *Sys,
    savedir: std.fs.Dir,
    config: *Config,
    nokeyboard: bool,
    pp: *ProjectPicker,
    known_fullscreen: *bool,
    cm: *ControllerManager,
    clipboard: *Clipboard,
) !SeqReturn {
    song.init();

    var skipsave = false;

    var params = Params{};

    var cells: [w * h]CharDisplay.Cell = undefined;
    var last_rendered: [w * h]CharDisplay.Cell = undefined;
    for (0..w * h) |i| last_rendered[i] = .{ .char = 0, .attrib = .{} };
    var tm = TextMatrix{ .w = w, .h = h, .out = &cells };

    var arrange = true;
    var mixer = false;

    var last_t = sdl.getPerformanceCounter();
    const perf_freq: f64 = @floatFromInt(sdl.getPerformanceFrequency());

    var held = ButtonState{};
    var jh = JoystickHandler{};
    var bh = ButtonHandler{};

    var mixer_channels = true;

    var bass_editor = BassEditor{ .bank = &song.bass_patterns };
    var drum_editor = DrumEditor{ .bank = &song.drum_patterns };
    var mixer_editor = MixerEditor{ .channels = &params.mixer, .mixer = &Sys.sound_engine.mixer };

    Sys.sound_engine.init(&params);

    const left_menu = [_]MasterEditor.Entry{
        .{ .u8 = .{ .label = "drive:     ", .ptr = &params.engine.drive } },
        .{ .u8 = .{ .label = "accent:    ", .ptr = &params.drums.accent } },
        .{ .u8 = .{ .label = "duck time: ", .ptr = &params.drums.duck_time } },
        .{ .u8 = .{ .label = "delay time:", .ptr = &params.delay.time } },
        .{ .u8 = .{ .label = "delay fb:  ", .ptr = &params.delay.feedback } },
        .{ .u8 = .{ .label = "delay duck:", .ptr = &params.delay.duck } },
        .{ .u8 = .{ .label = "swing:     ", .ptr = &params.engine.swing } },
        .{ .Kit = .{ .label = "drum kit:  ", .ptr = &params.drums.kit } },
        .spacer,
        .{ .Theme = .{ .label = "theme:", .ptr = &config.theme } },
        .{ .FontType = .{ .label = "font:", .ptr = &config.font } },
        .{ .bool = .{ .label = "fullscr:", .ptr = &config.fullscreen, .t = "yes", .f = "no" } },
    };

    var master_editor = MasterEditor{
        .left = &left_menu,
        .right = &.{
            .spacer,
            .spacer,
            .spacer,
            .spacer,
            .spacer,
            .spacer,
            .spacer,
            .spacer,
            .spacer,
            .{ .bool = .{ .label = "swap btn:", .ptr = &config.swapbuttons, .t = "yes", .f = "no" } },
            .{ .bool = .{ .label = "auto-adv:", .ptr = &config.autoadvance, .t = "yes", .f = "no" } },
            .{ .bool = .{ .label = "joyless:", .ptr = &config.joyless, .t = "yes", .f = "no" } },
        },
        .current = &left_menu,
    };

    var arranger = Arranger{
        .params = &params,
        .snapshots = &song.snapshots,
        .columns = &[_]*[256]u8{
            &song.bass1_arrange,
            &song.bass2_arrange,
            &song.drum_arrange,
        },
        .snap_map = &song.snap_map,
    };

    const save_state = save.State{
        .params = &params,
        .arr1 = &song.bass1_arrange,
        .arr2 = &song.bass2_arrange,
        .arr3 = &song.drum_arrange,
        .bpat = &song.bass_patterns,
        .dpat = &song.drum_patterns,
        .arranger = &arranger,
        .mixer_editor = &mixer_editor,
        .snapshots = &song.snapshots,
        .snap_map = &song.snap_map,
    };

    try save.load(
        savedir,
        ProjectPicker.name(config.project),
        save_state,
    );
    defer {
        if (!skipsave) save.save(
            savedir,
            ProjectPicker.name(config.project),
            ProjectPicker.tmpName(config.project),
            save_state,
        );
    }

    Sys.sound_engine.resetDelay();

    try sys.startAudio(config.samples);
    defer sys.stopAudio();

    var cd = CharDisplay{
        .w = w,
        .h = h,
        .cells = &cells,
        .last_rendered = &last_rendered,
        .out = sys.r,
        .font = sys.font,
        .fonttype = &config.font,
    };

    var j_mode: JoyMode = .timbre_mod;
    var pick_project = false;

    mainloop: while (true) {
        var redraw = false;
        defer {
            sys.preRender();
            cd.flush(redraw);
            sys.postRender();
        }

        var dont_handle = false;
        if (config.fullscreen != known_fullscreen.*) {
            known_fullscreen.* = config.fullscreen;
            _ = sdl.setWindowFullscreen(
                sys.w,
                if (config.fullscreen) sdl.WINDOW_FULLSCREEN_DESKTOP else 0,
            );
        }
        const colors = config.theme.resolve();
        const current_t = sdl.getPerformanceCounter();
        const dt: f32 = @floatCast(@as(f64, @floatFromInt(current_t -% last_t)) / perf_freq);
        last_t = current_t;

        var e: sdl.Event = undefined;
        while (0 != sdl.pollEvent(&e)) {
            if (jh.handle(&e)) continue;
            if (held.handle(&e, nokeyboard)) continue;

            switch (e.type) {
                sdl.QUIT => break :mainloop,
                sdl.WINDOWEVENT => switch (e.window.event) {
                    sdl.WINDOWEVENT_SIZE_CHANGED => redraw = true,
                    else => {},
                },
                sdl.CONTROLLERDEVICEADDED => {
                    cm.open(e.cdevice.which);
                },
                sdl.CONTROLLERDEVICEREMOVED => {
                    cm.close(e.cdevice.which);
                },
                else => {},
            }
        }

        tm.clear(colors.normal);

        const trig = bh.handle(held, dt, config.swapbuttons);

        if (trig.comboPress("start+select") or trig.comboPress("select+start"))
            break :mainloop;

        if (pick_project) {
            if (try pp.handle(trig)) |req| switch (req) {
                .switch_project => {
                    if (config.project != pp.cursor) {
                        save.save(
                            savedir,
                            ProjectPicker.name(config.project),
                            ProjectPicker.tmpName(config.project),
                            save_state,
                        );
                        config.project = pp.cursor;
                        skipsave = true;
                        return .reload;
                    }
                    pick_project = false;
                },
                .copy_project => {
                    save.save(
                        savedir,
                        ProjectPicker.name(pp.cursor),
                        ProjectPicker.tmpName(pp.cursor),
                        save_state,
                    );
                    try pp.updateAvail();
                },
                .close_picker => {
                    pick_project = false;
                    pp.cursor = config.project;
                },
            };
            pp.display(&tm, 7, 3, dt, colors);
            continue :mainloop;
        }

        if ((trig.hold.l2 and trig.hold.r2 and trig.press.start and !pick_project) or
            (trig.hold.l2 and trig.hold.r and trig.press.start and !pick_project))
        {
            try pp.updateAvail();
            pick_project = true;
        }

        if (config.joyless) {
            if (!dont_handle and (trig.hold.l2 or trig.hold.r2)) {
                if (trig.hold.l2) joylessHandleParams(trig, j_mode, &params.bass1);
                if (trig.hold.r2) joylessHandleParams(trig, j_mode, &params.bass2);

                if (trig.press.x) j_mode = .timbre_mod;
                if (trig.press.y) j_mode = .res_feedback;
                if (trig.press.b) j_mode = .decay_accent;
                dont_handle = true;
            }
        } else {
            j_mode = if (trig.hold.l2)
                .res_feedback
            else if (trig.hold.r2)
                .decay_accent
            else
                .timbre_mod;
            handleParams(jh.lx, jh.ly, dt, j_mode, &params.bass1);
            handleParams(jh.rx, jh.ry, dt, j_mode, &params.bass2);
        }

        if (trig.hold.l) {
            if (trig.repeat.up) params.engine.changeTempo(10);
            if (trig.repeat.down) params.engine.changeTempo(-10);
            if (trig.repeat.left) params.engine.changeTempo(-1);
            if (trig.repeat.right) params.engine.changeTempo(1);
            if (trig.press.x) params.engine.mutes.toggle(.bd);
            if (trig.press.y) params.engine.mutes.toggle(.sd);
            if (trig.press.b) params.engine.mutes.toggle(.hhcy);
            if (trig.press.a) params.engine.mutes.toggle(.tm);
            if (trig.press.l2) params.engine.mutes.toggle(.b1);
            if (trig.press.r2) params.engine.mutes.toggle(.b2);
            if (trig.press.r) params.engine.mutes.toggle(.rscp);
            if (trig.press.select and !mixer) clipboard.copy(&arranger);
            if (trig.press.start and !mixer) clipboard.paste(&arranger);
            dont_handle = true;
        }
        if (trig.comboPress("select")) mixer = !mixer;
        if (trig.comboPress("start")) Sys.sound_engine.startstop(arranger.row);
        if (Sys.sound_engine.isRunning()) tm.putch(0, 0, colors.playing, 0x10);
        tm.print(1, 0, colors.normal, "{}", .{params.engine.get(.bpm)});
        tm.print(5, 0, colors.faded(0.5).hilight, "({x:0>2})", .{config.project});
        params.engine.mutes.display(colors, &tm, 22, 0);

        const pi: []const PlaybackInfo = &[_]PlaybackInfo{
            Sys.sound_engine.bs1.playbackInfo(),
            Sys.sound_engine.bs2.playbackInfo(),
            Sys.sound_engine.ds.playbackInfo(),
        };

        if (mixer) {
            if (trig.press.r) mixer_channels = !mixer_channels;
            mixer_editor.handle(trig, mixer_channels);
            if (!dont_handle) master_editor.handle(trig, !mixer_channels);
            mixer_editor.display(&tm, 1, 14, dt, mixer_channels, colors);
            master_editor.display(&tm, 1, 1, dt, !mixer_channels, colors);
            continue :mainloop;
        }
        if (!dont_handle and trig.comboPress("r")) {
            if (arrange) {
                if (!arranger.selEmpty()) arrange = false;
            } else arrange = true;
        }

        if (arrange) {
            if (!dont_handle and trig.comboPress("x")) Sys.sound_engine.enqueue(arranger.row);
            if (!dont_handle) {
                if (arranger.handle(trig)) |request| switch (request) {
                    .clone => Clipboard.clone(&arranger),
                    .new => Clipboard.new(&arranger),
                };
            }
        }
        if (arranger.selectedPattern()) |p| {
            switch (arranger.column) {
                0, 1 => {
                    bass_editor.setPattern(p);
                    if (!arrange and !dont_handle) bass_editor.handle(trig, config.autoadvance);
                    bass_editor.display(
                        &tm,
                        10,
                        1,
                        dt,
                        !arrange,
                        pi[arranger.column],
                        colors,
                    );
                },
                2 => {
                    drum_editor.setPattern(p);
                    if (!arrange and !dont_handle) drum_editor.handle(trig, config.autoadvance);
                    drum_editor.display(
                        &tm,
                        10,
                        1,
                        dt,
                        !arrange,
                        pi[arranger.column],
                        params.engine.get(.mutes),
                        colors,
                    );
                },
                else => {},
            }
        }

        const qi: []const ?u8 = &[_]?u8{
            Sys.sound_engine.bs1.queued(),
            Sys.sound_engine.bs2.queued(),
            Sys.sound_engine.ds.queued(),
        };

        arranger.display(&tm, 1, 2, dt, arrange, pi, qi, colors);

        const lxy = j_mode.values(&params.bass1);
        const rxy = j_mode.values(&params.bass2);
        tm.print(1, 20, colors.hilight2, "{s: <14}", .{j_mode.str()});

        const lcolor = if (params.engine.mutes.get(.b1)) colors.hilight else colors.hilight2;
        const rcolor = if (params.engine.mutes.get(.b2)) colors.hilight else colors.hilight2;
        tm.print(15, 20, lcolor, "{x:0>2}/{x:0>2}", .{ lxy.y, lxy.x });
        tm.print(24, 20, rcolor, "{x:0>2}/{x:0>2}", .{ rxy.y, rxy.x });
    }

    return .exit;
}

fn joylessHandleParams(trig: ButtonHandler.States, mode: JoyMode, params: *PDBass.Params) void {
    const single_step: f32 = @as(f32, 1) / 0xff;

    const step = single_step * @as(f32, if (trig.hold.a) 8 else 1);

    var xadd: ?f32 = null;
    var yadd: ?f32 = null;

    if (trig.repeat.up) yadd = step;
    if (trig.repeat.down) yadd = -step;
    if (trig.repeat.left) xadd = -step;
    if (trig.repeat.right) xadd = step;

    if (xadd) |x| {
        const prev = switch (mode) {
            .timbre_mod => params.get(.mod_depth),
            .res_feedback => params.get(.feedback),
            .decay_accent => params.get(.accentness),
        };

        const new: f32 = @min(1, @max(0, x + prev));

        switch (mode) {
            .timbre_mod => params.setCmp(.mod_depth, new, prev),
            .res_feedback => params.setCmp(.feedback, new, prev),
            .decay_accent => params.setCmp(.accentness, new, prev),
        }
    }

    if (yadd) |y| {
        const prev = switch (mode) {
            .timbre_mod => params.get(.timbre),
            .res_feedback => params.get(.res),
            .decay_accent => params.get(.decay),
        };

        const new: f32 = @min(1, @max(0, y + prev));

        switch (mode) {
            .timbre_mod => params.setCmp(.timbre, new, prev),
            .res_feedback => params.setCmp(.res, new, prev),
            .decay_accent => params.setCmp(.decay, new, prev),
        }
    }
}

fn handleParams(ux: f32, uy: f32, dt: f32, mode: JoyMode, params: *PDBass.Params) void {
    const joy_sensitivity = 0.5;
    const x = ux * joy_sensitivity * dt;
    const y = uy * joy_sensitivity * dt;
    switch (mode) {
        .timbre_mod => {
            const prevx = params.get(.mod_depth);
            const prevy = params.get(.timbre);
            params.setCmp(.mod_depth, @min(1, @max(0, x + prevx)), prevx);
            params.setCmp(.timbre, @min(1, @max(0, prevy - y)), prevy);
        },
        .res_feedback => {
            const prevx = params.get(.feedback);
            const prevy = params.get(.res);
            params.setCmp(.feedback, @min(1, @max(0, x + prevx)), prevx);
            params.setCmp(.res, @min(1, @max(0, prevy - y)), prevy);
        },
        .decay_accent => {
            const prevx = params.get(.accentness);
            const prevy = params.get(.decay);
            params.setCmp(.accentness, @min(1, @max(0, x + prevx)), prevx);
            params.setCmp(.decay, @min(1, @max(0, prevy - y)), prevy);
        },
    }
}

fn help(writer: std.io.AnyWriter, arg0: []const u8) void {
    writer.print("Usage: {s} [OPTIONS] [savedir]\n\n", .{arg0}) catch {};
    writer.print("Options:\n", .{}) catch {};
    writer.print("--help\n\tDisplay this information\n", .{}) catch {};
    writer.print("--nokeyboard\n\tDisable keyboard input\n", .{}) catch {};
}
