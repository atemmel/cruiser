const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

const math = std.math;
const mem = std.mem;

const cwd = std.fs.cwd;
const usleep = std.Thread.sleep;

const PROG_NAME = "cruiser";
const H = 480;
const W = 640;

fn oom() noreturn {
    @panic("Out of memory");
}

fn sdlError(msg: []const u8) void {
    std.debug.print("{s} {s}\n", .{ msg, c.SDL_GetError() });
}

fn printnsDuration(msg: []const u8, ns: i128) void {
    const print = std.debug.print;
    if (ns < 1_000) {
        print("{s} {}ns\n", .{ msg, ns });
    } else if (ns < 1_000_000) {
        print("{s} {}us\n", .{ msg, @divTrunc(ns, 1_000) });
    } else if (ns < 1_000_000_000) {
        print("{s} {}ms\n", .{ msg, @divTrunc(ns, 1_000_000) });
    } else {
        print("{s} {}s\n", .{ msg, @divTrunc(ns, 1_000_000_000) });
    }
}

fn waitNextFrame() void {
    std.Thread.sleep(refresh_rate_ns);
}

fn setRefreshRate(display_fps: f32) void {
    refresh_rate_ns = @intFromFloat(1_000_000 / display_fps);
}

const Application = struct {
    Name: []const u8 = "",
    Comment: []const u8 = "",
    Exec: []const u8 = "",
    Icon: []const u8 = "",
    Terminal: bool = false,
    Type: []const u8 = "",
    Categories: []const u8 = "",
};

var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var refresh_rate_ns: u64 = undefined;
var arena: std.mem.Allocator = undefined;
var scratch: std.mem.Allocator = undefined;
var home: []const u8 = "";

pub fn main() !void {
    _ = c.SDL_SetAppMetadata(PROG_NAME, "whatever dude", PROG_NAME);

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        sdlError("Couldn't initalize SDL:");
        return;
    }

    var arena_impl = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena_impl.deinit();
    arena = arena_impl.allocator();

    home = std.process.getEnvVarOwned(arena, "HOME") catch oom();

    var scratch_impl = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer scratch_impl.deinit();
    scratch = scratch_impl.allocator();

    const display_mode = c.SDL_GetCurrentDisplayMode(c.SDL_GetPrimaryDisplay());
    setRefreshRate(display_mode.*.refresh_rate);

    _ = c.SDL_SetHint(c.SDL_HINT_WINDOW_ALLOW_TOPMOST, "1");

    const win_flags = c.SDL_WINDOW_BORDERLESS | c.SDL_WINDOW_ALWAYS_ON_TOP | c.SDL_WINDOW_TRANSPARENT | c.SDL_WINDOW_INPUT_FOCUS | c.SDL_WINDOW_UTILITY;

    if (!c.SDL_CreateWindowAndRenderer(PROG_NAME, W, H, win_flags, &window, &renderer)) {
        sdlError("Couldn't create window/renderer:");
        return;
    }

    const begin = std.time.nanoTimestamp();
    const applications = findApplications();
    const end = std.time.nanoTimestamp();
    printnsDuration("Found applications in:", end - begin);

    _ = applications;

    loop();

    c.SDL_DestroyRenderer(renderer);
    c.SDL_DestroyWindow(window);
}

fn loop() void {
    while (true) {
        var had_event = false;
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            had_event = true;
            switch (event.type) {
                c.SDL_EVENT_KEY_DOWN => switch (event.key.key) {
                    c.SDLK_ESCAPE => {
                        return;
                    },
                    else => {},
                },
                c.SDL_EVENT_WINDOW_FOCUS_LOST => {
                    return;
                },
                else => {},
            }
        }
        if (!had_event) {
            // nothing's changed, don't even render
            waitNextFrame();
            continue;
        }

        _ = c.SDL_SetRenderDrawColorFloat(renderer, 0.0, 0.0, 0.0, 0.7);
        _ = c.SDL_RenderClear(renderer);
        drawRoundCorners();
        _ = c.SDL_RenderPresent(renderer);

        waitNextFrame();
    }
}

fn drawRoundCorners() void {
    _ = c.SDL_SetRenderDrawColorFloat(renderer, 0.0, 0.0, 0.0, 0.0);
    const R = 50.0;
    drawRoundCorner(0.0, 0.0, 0.0, 0.0, R);
    drawRoundCorner(W - R, 0.0, W - R - R, 0.0, R);
    drawRoundCorner(0.0, H - R, 0.0, H - R - R, R);
}

fn drawRoundCorner(ox: f32, oy: f32, cx: f32, cy: f32, r: f32) void {
    var x: f32 = ox;
    while (x < W and x < ox + r) : (x += 1.0) {
        var y: f32 = oy;
        while (y < H and y < oy + r) : (y += 1.0) {
            const C = math.sqrt((x - cx - r) * (x - cx - r) + (y - cy - r) * (y - cy - r));
            if (C > r) {
                _ = c.SDL_RenderPoint(renderer, x, y);
            }
        }
    }
}

const application_dirs = [_][]const u8{
    "/usr/share/applications/",
    "$HOME/.local/share/applications/",
};

fn findApplications() []Application {
    var applications = std.ArrayList(Application).initCapacity(arena, 16) catch oom();

    //TODO: these guys
    //std.Thread.Mutex
    //std.Thread.Pool

    for (application_dirs) |orig_dir| {
        const dir = mem.replaceOwned(u8, arena, orig_dir, "$HOME", home) catch oom();
        std.debug.print("dir: {s}\n", .{dir});

        var open_dir = cwd().openDir(dir, .{
            .iterate = true,
        }) catch continue;
        defer open_dir.close();
        var it = open_dir.iterate();
        while (it.next() catch continue) |entry| {
            // ignore non-applications
            if (!mem.endsWith(u8, entry.name, ".desktop")) continue;

            if (parseDesktopEntry(dir, entry.name)) |appl| {
                applications.append(appl) catch oom();
            }
        }
    }

    const cmp = struct {
        pub fn less_than(_: void, lhs: Application, rhs: Application) bool {
            return std.mem.order(u8, lhs.Name, rhs.Name) == .lt;
        }
    };

    mem.sortUnstable(Application, applications.items, {}, cmp.less_than);

    return applications.toOwnedSlice() catch oom();
}

fn parseDesktopEntry(desktop_dir_path: []const u8, desktop_file_path: []const u8) ?Application {
    // read file
    const full_path = mem.concat(arena, u8, &.{ desktop_dir_path, desktop_file_path }) catch oom();
    var file = cwd().openFile(full_path, .{}) catch return null;
    defer file.close();
    var orig_src = file.readToEndAlloc(arena, 1_000_000) catch return null;

    // trim header
    const HEADER = "[Desktop Entry]";
    var src: []const u8 = if (mem.startsWith(u8, orig_src, HEADER)) orig_src[HEADER.len..] else orig_src;
    src = mem.trim(u8, src, " \n\r\t");
    var it = mem.splitAny(u8, src, "=\n");

    const DesktopEntryKeys = std.meta.FieldEnum(Application);
    const State = enum { key, value };

    var appl: Application = .{};
    var now_reading = State.key;
    var just_found: ?DesktopEntryKeys = null;

    while (it.next()) |buf| {
        switch (now_reading) {
            .key => {
                now_reading = .value;
                just_found = std.meta.stringToEnum(DesktopEntryKeys, buf);
            },
            .value => {
                now_reading = .key;
                switch (just_found orelse continue) {
                    .Categories => appl.Categories = buf,
                    .Comment => appl.Comment = buf,
                    .Exec => appl.Exec = buf,
                    .Icon => appl.Icon = buf,
                    .Name => appl.Name = buf,
                    .Terminal => appl.Terminal = std.ascii.eqlIgnoreCase(buf, "false"),
                    .Type => appl.Type = buf,
                }
            },
        }
    }
    return appl;
}
