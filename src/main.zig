const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});

const math = std.math;
const mem = std.mem;
const meta = std.meta;

const cwd = std.fs.cwd;
const usleep = std.Thread.sleep;

const PROG_NAME = "cruiser";
const H = LIST_PADDING_TOP + LIST_PADDING_BOTTOM + LIST_GAP * 10.0;
const W = 640;
const HEADER_FONT_SIZE = 16.0;
const WINDOW_RADIUS = 50.0;
const LIST_MARGIN_LEFT = 100.0;
const LIST_PADDING_TOP = 64.0;
const LIST_PADDING_BOTTOM = 32.0;
const LIST_GAP = 32.0;
const QUERY_PADDING_TOP = 16.0;

const WHITE = c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

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
var scratch_impl: std.heap.ArenaAllocator = undefined;
var home: []const u8 = "";

var applications: []const Application = &.{};
var matches: []const Application = &.{};
var query: std.ArrayList(u8) = undefined;

var header_font: ?*c.TTF_Font = undefined;
var font_bytes: []const u8 = "";

pub fn main() void {
    _ = c.SDL_SetAppMetadata(PROG_NAME, "whatever dude", PROG_NAME);

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        sdlError("Couldn't initalize SDL:");
        return;
    }

    if (!c.TTF_Init()) {
        sdlError("Couldn't initalize TTF:");
        return;
    }

    var arena_impl = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena_impl.deinit();
    arena = arena_impl.allocator();

    home = std.process.getEnvVarOwned(arena, "HOME") catch oom();

    scratch_impl = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer scratch_impl.deinit();
    scratch = scratch_impl.allocator();

    font_bytes = cwd().readFileAlloc(arena, "/usr/share/fonts/noto/NotoSans-Medium.ttf", 10_000_000) catch |e| {
        std.debug.print("Couldn't open font: {any}\n", .{e});
        return;
    };

    header_font = c.TTF_OpenFontIO(c.SDL_IOFromConstMem(font_bytes.ptr, font_bytes.len), false, 24.0);
    if (header_font == null) {
        sdlError("Couldn't load font:");
        return;
    }

    const display_mode = c.SDL_GetCurrentDisplayMode(c.SDL_GetPrimaryDisplay());
    setRefreshRate(display_mode.*.refresh_rate);

    _ = c.SDL_SetHint(c.SDL_HINT_WINDOW_ALLOW_TOPMOST, "1");

    const win_flags = c.SDL_WINDOW_BORDERLESS | c.SDL_WINDOW_ALWAYS_ON_TOP | c.SDL_WINDOW_TRANSPARENT | c.SDL_WINDOW_INPUT_FOCUS | c.SDL_WINDOW_UTILITY | c.SDL_WINDOW_HIGH_PIXEL_DENSITY;

    if (!c.SDL_CreateWindowAndRenderer(PROG_NAME, W, H, win_flags, &window, &renderer)) {
        sdlError("Couldn't create window/renderer:");
        return;
    }

    query = std.ArrayList(u8).initCapacity(arena, 16) catch oom();

    const begin = std.time.nanoTimestamp();
    applications = findApplications();
    const end = std.time.nanoTimestamp();
    printnsDuration("Found applications in:", end - begin);
    matches = applications;

    loop();

    c.SDL_DestroyRenderer(renderer);
    c.SDL_DestroyWindow(window);
}

fn loop() void {
    _ = c.SDL_StartTextInput(window);
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
                    c.SDLK_BACKSPACE => {
                        if (event.key.mod & c.SDL_KMOD_CTRL != 0) {
                            while (query.items.len > 0 and !std.ascii.isWhitespace(query.getLast())) {
                                _ = query.pop();
                            }

                            if (query.items.len > 0) {
                                _ = query.pop();
                            }
                        } else {
                            _ = query.pop();
                        }
                        match();
                    },
                    c.SDLK_U => {
                        if (event.key.mod & c.SDL_KMOD_CTRL != 0) {
                            query.clearRetainingCapacity();
                        }
                        match();
                    },
                    else => {},
                },
                c.SDL_EVENT_TEXT_INPUT => {
                    query.appendSlice(mem.sliceTo(event.text.text, 0)) catch oom();
                    match();
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
        draw();
        _ = c.SDL_RenderPresent(renderer);

        waitNextFrame();
    }
}

fn match() void {
    _ = scratch_impl.reset(.retain_capacity);
    var new_matches = std.ArrayList(Application).initCapacity(scratch, 16) catch oom();
    var cmp_buf = std.ArrayList(u8).initCapacity(scratch, 16) catch oom();
    const cmp_query = std.ascii.allocLowerString(scratch, query.items) catch oom();
    for (applications) |appl| {
        defer cmp_buf.clearRetainingCapacity();
        cmp_buf.appendSlice(appl.Name) catch oom();
        for (cmp_buf.items, 0..) |b, i| {
            cmp_buf.items[i] = std.ascii.toLower(b);
        }
        if (std.mem.indexOf(u8, cmp_buf.items, cmp_query)) |_| {
            new_matches.append(appl) catch oom();
        }
    }

    matches = new_matches.toOwnedSlice() catch oom();
}

fn draw() void {
    for (matches, 0..) |appl, idx| {
        const y_idx: f32 = @floatFromInt(idx);
        const y = LIST_PADDING_TOP + y_idx * LIST_GAP;
        drawText(header_font, str(appl.Name), WHITE, LIST_MARGIN_LEFT, y);
        if (y + LIST_PADDING_BOTTOM + LIST_GAP + HEADER_FONT_SIZE > H) break;
    }

    drawText(header_font, str(query.items), WHITE, LIST_MARGIN_LEFT, QUERY_PADDING_TOP);

    const text_dim = strdim(header_font, query.items);

    _ = c.SDL_SetRenderDrawColorFloat(renderer, 1.0, 1.0, 1.0, 1.0);
    const marker = c.SDL_FRect{
        .x = LIST_MARGIN_LEFT + text_dim.w,
        .y = QUERY_PADDING_TOP,
        .h = HEADER_FONT_SIZE * 2,
        .w = 2,
    };

    _ = c.SDL_RenderFillRect(renderer, &marker);
}

fn drawText(font: ?*c.TTF_Font, text: [*c]const u8, color: c.SDL_Color, x: f32, y: f32) void {
    const surface = c.TTF_RenderText_Blended(font, text, 0, color) orelse return;
    defer c.SDL_DestroySurface(surface);
    const texture = c.SDL_CreateTextureFromSurface(renderer, surface) orelse return;

    const dst = c.SDL_FRect{
        .x = x,
        .y = y,
        .h = @floatFromInt(texture.*.h),
        .w = @floatFromInt(texture.*.w),
    };

    _ = c.SDL_RenderTexture(renderer, texture, null, &dst);
}

fn drawRoundCorners() void {
    _ = c.SDL_SetRenderDrawColorFloat(renderer, 0.0, 0.0, 0.0, 0.0);
    const R = WINDOW_RADIUS;
    drawRoundCorner(0.0, 0.0, 0.0 + R, 0.0 + R, R);
    drawRoundCorner(W - R, 0.0, W - R, 0.0 + R, R);
    drawRoundCorner(0.0, H - R, 0.0 + R, H - R, R);
    drawRoundCorner(W - R, H - R, W - R, H - R, R);
}

fn drawRoundCorner(ox: f32, oy: f32, cx: f32, cy: f32, r: f32) void {
    var x: f32 = ox;
    while (x < W and x < ox + r) : (x += 1.0) {
        var y: f32 = oy;
        while (y < H and y < oy + r) : (y += 1.0) {
            const C = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
            if (C > r) {
                _ = c.SDL_RenderPoint(renderer, x, y);
            }
        }
    }
}

const static_icon_dirs = &.{
    "/usr/share/pixmaps/",
    "$XDG_DATA_DIRS/icons/",
};

const application_dirs = [_][]const u8{
    "/usr/share/applications/",
    "$HOME/.local/share/applications/",
};

fn findApplications() []Application {
    var appls = std.ArrayList(Application).initCapacity(arena, 16) catch oom();

    //TODO: these guys
    //std.Thread.Mutex
    //std.Thread.Pool

    for (application_dirs) |orig_dir| {
        const dir = mem.replaceOwned(u8, arena, orig_dir, "$HOME", home) catch oom();

        var open_dir = cwd().openDir(dir, .{
            .iterate = true,
        }) catch continue;
        defer open_dir.close();
        var it = open_dir.iterate();
        while (it.next() catch continue) |entry| {
            // ignore non-applications
            if (!mem.endsWith(u8, entry.name, ".desktop")) continue;

            if (parseDesktopEntry(dir, entry.name)) |appl| {
                appls.append(appl) catch oom();
            }
        }
    }

    const cmp = struct {
        pub fn less_than(_: void, lhs: Application, rhs: Application) bool {
            return std.mem.order(u8, lhs.Name, rhs.Name) == .lt;
        }
    };

    mem.sortUnstable(Application, appls.items, {}, cmp.less_than);

    return appls.toOwnedSlice() catch oom();
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

    const DesktopEntryKeys = meta.FieldEnum(Application);
    const State = enum { key, value };

    var appl: Application = .{};
    var now_reading = State.key;
    var just_found: ?DesktopEntryKeys = null;

    while (it.next()) |buf| {
        switch (now_reading) {
            .key => {
                now_reading = .value;
                just_found = meta.stringToEnum(DesktopEntryKeys, buf);
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
    if (appl.Name.len == 0) {
        return null;
    }
    return appl;
}

fn str(s: []const u8) [*c]const u8 {
    const static = struct {
        var buffer: [2048]u8 = undefined;
    };
    return std.fmt.bufPrintZ(&static.buffer, "{s}", .{s}) catch {
        return static.buffer[0..0];
    };
}

fn strdim(font: ?*c.TTF_Font, s: []const u8) struct { w: f32, h: f32 } {
    if (s.len == 0) {
        return .{
            .w = 0,
            .h = 0,
        };
    }
    var w: c_int = 0;
    var h: c_int = 0;
    _ = c.TTF_GetStringSize(font, s.ptr, s.len, &w, &h);
    return .{
        .w = @floatFromInt(w),
        .h = @floatFromInt(h),
    };
}
