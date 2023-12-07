const std = @import("std");
const zap = @import("zap");

// Custom Types
const str = []const u8;

// Global Variables
var number_of_requests: i32 = 0;

// Bearer Tokens
const token = "VERUSKA";

const Handler = struct {
    var alloc: std.mem.Allocator = undefined;

    // HTTP Responses
    const HTTP_RESPONSE_SUCCESS: str =
        \\ <html><body>
        \\   <h1> VOCÊ FORNECEU O TOKEN CORRETO! </h1>
        \\   <h2> ACESSO LIBERADO! </h2>
        \\ </body></html>
    ;

    const HTTP_RESPONSE_FAIL: str =
        \\ <html><body>
        \\   <h1> ACESSO NEGADO! </h1>
        \\ </body></html>
    ;

    pub fn request_counter(r: zap.SimpleRequest) void {
        number_of_requests += 1;
        var buffer: [128]u8 = undefined; // Buffer capaz de armazenar 128 bytes = 128 caracteres
        const filled_buffer = std.fmt.bufPrintZ(
            &buffer,
            \\<html>
            \\  <body>
            \\      <h1> REQUEST NUMBER #{d} </h1>
            \\  </body>
            \\</html>
            \\
        ,
            .{number_of_requests},
        ) catch "ERROR";
        r.sendBody(filled_buffer) catch return;
    }

    // Authenticated Requests Handler
    fn endpoint_http_get(_: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
        r.sendBody(HTTP_RESPONSE_SUCCESS) catch return;
    }

    // Unauthorized Requests Handler
    fn endpoint_http_unauthorized(_: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
        r.setStatus(.unauthorized);
        r.sendBody(HTTP_RESPONSE_FAIL) catch return;
    }
};

pub fn main() !void {
    // Setup Listener
    const allocator = std.heap.page_allocator;
    Handler.alloc = allocator;
    var listener = zap.SimpleEndpointListener.init(
        allocator,
        .{
            .port = 3000,
            .on_request = Handler.request_counter,
            .log = true,
            .max_clients = 10,
            .max_body_size = 1 * 1024,
        },
    );
    defer listener.deinit();

    var ep = zap.SimpleEndpoint.init(.{
        .path = "/auth",
        .get = Handler.endpoint_http_get,
        .unauthorized = Handler.endpoint_http_unauthorized,
    });

    // Bearer Authenticator (Single Token)
    const Authenticator = zap.BearerAuthSingle;
    var authenticator = try Authenticator.init(allocator, token, null);
    defer authenticator.deinit();

    const BearerAuthEndpoint = zap.AuthenticatingEndpoint(Authenticator);
    var auth_ep = BearerAuthEndpoint.init(&ep, &authenticator);

    // Setup routes
    try listener.addEndpoint(auth_ep.getEndpoint());

    listener.listen() catch {};
    std.debug.print(
        \\
        \\ REQUEST
        \\ 
        \\ 200: curl http://localhost:3000/auth -i -H "Authorization: Bearer {s}" -v 
    , .{token});

    // Start sever with 1 thread and 1 worker
    // 1 thread = 1 OS threads
    // 1 worker = 1 thread that will handle all requests
    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
