const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;

pub fn main() !void {
    _ = c.SDL_SetAppMetadata("Example Renderer Clear", "1.0", "com.example.renderer-clear");

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        c.SDL_Log("Couldn't initialize SDL: %s", c.SDL_GetError());
        return;
    }

    _ = c.SDL_SetHint(c.SDL_HINT_WINDOW_ALLOW_TOPMOST, "1");

    const win_flags = c.SDL_WINDOW_BORDERLESS | c.SDL_WINDOW_ALWAYS_ON_TOP | c.SDL_WINDOW_TRANSPARENT | c.SDL_WINDOW_INPUT_FOCUS | c.SDL_WINDOW_UTILITY;

    if (!c.SDL_CreateWindowAndRenderer("examples/renderer/clear", 640, 480, win_flags, &window, &renderer)) {
        c.SDL_Log("Couldn't create window/renderer: %s", c.SDL_GetError());
        return;
    }

    var running = true;
    while (running) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            if (event.key.key == c.SDLK_ESCAPE) {
                running = false;
            }
        }
        _ = c.SDL_SetRenderDrawColorFloat(renderer, 0.5, 0.5, 0.5, c.SDL_ALPHA_OPAQUE_FLOAT);
        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_RenderPresent(renderer);

        _ = c.SDL_SetWindowPosition(window, 100, 100);

        std.Thread.sleep(16_000_000);
    }

    c.SDL_DestroyRenderer(renderer);
    c.SDL_DestroyWindow(window);
}
