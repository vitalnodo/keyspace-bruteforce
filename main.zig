const std = @import("std");
const Managed = std.math.big.int.Managed;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const two = try Managed.initSet(allocator, 2);
    var raised = try Managed.init(allocator);
    defer raised.deinit();
    const key_sizes = [9]u12{ 8, 16, 32, 64, 128, 256, 512, 1024, 2048 };
    var random_keys = [_]Managed{undefined} ** 9;
    for (key_sizes) |key_size, index| {
        try raised.pow(&two, key_size);
        try stdout.print("{d}-bits key space: {d};\n", .{ key_size, raised });
        random_keys[index] = try getRandKeyManaged(allocator, key_size);
        try stdout.print("Random key in hex: {x:0}\n", .{random_keys[index]});
    }

    for (key_sizes) |key_size, index| {
        try stdout.print(
            "\nIt took {d} ms to get {d}-bits key",
            .{
                try getTimeUntilKey(allocator, random_keys[index]),
                key_size,
            },
        );
    }
}

pub fn getRandKeyManaged(
    allocator: std.mem.Allocator,
    key_size: usize,
) !Managed {
    var buf = try allocator.alloc(u8, key_size / 8);
    defer allocator.free(buf);
    std.crypto.random.bytes(buf);

    var limbs = try allocator.alloc(usize, (buf.len / @sizeOf(usize)) + 1);
    std.mem.set(usize, limbs, 0);
    defer allocator.free(limbs);
    var limb_ptr = @ptrCast([*]u8, limbs);
    std.mem.copy(u8, limb_ptr[0..buf.len], buf[0..]);

    const res = std.math.big.int.Const{ .limbs = limbs, .positive = true };
    return res.toManaged(allocator);
}

pub fn getTimeUntilKey(
    allocator: std.mem.Allocator,
    key_to_be_found: Managed,
) !i64 {
    var key = try Managed.initSet(allocator, 0);
    defer key.deinit();
    const one = try Managed.initSet(allocator, 1);
    const start_time = std.time.milliTimestamp();
    while (!key.eq(key_to_be_found)) {
        try key.add(&key, &one);
    }
    const end_time = std.time.milliTimestamp();
    return end_time - start_time;
}
