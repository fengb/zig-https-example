const std = @import("std");

const hzzp = @import("hzzp");
const iguana = @import("iguanaTLS");

// POST https://ptsv2.com:443/t/c3p0/post
// ---
// {{LINK}}

const HOST = "ptsv2.com";
const PORT = 443;
const PATH = "/t/c3p0/post";
const PAYLOAD = "{{LINK}}";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    const tcp_conn = try std.net.tcpConnectToHost(allocator, HOST, PORT);
    defer tcp_conn.close();

    var tls_conn = try iguana.client_connect(.{
        .rand = null,
        .reader = tcp_conn.reader(),
        .writer = tcp_conn.writer(),
        .cert_verifier = .none,
    }, HOST);
    defer tls_conn.close_notify() catch {};

    var hzzp_buffer: [4096]u8 = undefined;
    var client = hzzp.base.client.create(&hzzp_buffer, tls_conn.reader(), tls_conn.writer());

    try client.writeStatusLine("POST", "/t/c3p0/post");
    try client.writeHeaderValue("Host", HOST);
    try client.writeHeaderValue("User-Agent", "C3P0");
    var len_buffer: [16]u8 = undefined;
    try client.writeHeaderValue("Content-Length", try std.fmt.bufPrint(&len_buffer, "{}", .{PAYLOAD.len}));
    try client.finishHeaders();
    try client.writePayload(PAYLOAD);

    while (try client.next()) |event| {
        switch (event) {
            .status => |status| std.debug.print("<HTTP Status {}>\n", .{status.code}),
            .header => |header| std.debug.print("{}: {}\n", .{ header.name, header.value }),
            .head_done => {
                std.debug.print("---\n", .{});
                break;
            },
            .skip => {},
            .payload => unreachable,
            .end => std.debug.print("<empty body>", .{}),
        }
    }

    var reader = client.reader();

    var read_buffer: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&read_buffer, '\r')) |chunk| {
        std.debug.print("{}", .{chunk});
    }
    std.debug.print("\n", .{});
}
