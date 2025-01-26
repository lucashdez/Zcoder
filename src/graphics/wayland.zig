const std = @import("std");
const sdl = @cImport(@cInclude("SDL2/SDL.h"));
const u = @import("lhvk_utils.zig");



pub const Window = struct {
    handle: ?*sdl.SDL_Window,
    instance: ?*anyopaque,
    surface: ?*anyopaque,
    display: ?*anyopaque,
    width: u32,
    height: u32,
};


pub fn create_window(name: []const u8) Window {
 _ = name;
    return Window {
    .handle = null,
    .instance = null,
    .surface = null,
    .display = null,
    .width = 800,
    .height = 600,
    };
}