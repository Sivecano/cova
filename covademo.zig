//! Example usage of Cova.
//! Comptime Setup, Runtime Use.

const std = @import("std");
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const meta = std.meta;
const proc = std.process;
const StringHashMap = std.StringHashMap;
const testing = std.testing;

const eql = mem.eql;

const cova = @import("src/cova.zig");
const Command = cova.Command;
const Option = cova.Option;
const Value = cova.Value;
const ex_structs = @import("example_structs.zig");
pub const CustomCommand = Command.Custom(.{ .global_help_prefix = "CovaDemo", }); 

pub const log_level: log.Level = .err;

pub const DemoStruct = struct {
    pub const InnerStruct = struct {
        in_bool: bool = false,
        in_float: f32 = 0,
    };
    // Command
    inner_config: InnerStruct = .{
        .in_bool = true,
        .in_float = 0,
    },
    // Options
    int: ?i32 = 26,
    str: ?[]const u8 = "Demo Opt string.",
    str2: ?[]const u8 = "Demo Opt string 2.",
    flt: ?f16 = 0,
    int2: ?u16 = 0,
    multi_str: [5]?[]const u8,
    multi_int: [3]?u8,
    // Values
    struct_bool: bool = false,
    struct_str: []const u8 = "Demo Struct string.",
    struct_int: i64,
    multi_int_val: [2]u16,
};
    
const setup_cmd: CustomCommand = .{
    .name = "covademo",
    .description = "A demo of the Cova command line argument parser.",
    .sub_cmds = &.{
        .{
            .name = "demo-cmd",
            .description = "A demo sub command.",
            .opts = &.{
                .{
                    .name = "nested_int_opt",
                    .short_name = 'i',
                    .long_name = "nested_int",
                    .val = Value.ofType(u8, .{
                        .name = "nested_int_val",
                        .description = "A nested integer value.",
                        .default_val = 203,
                    }),
                    .description = "A nested integer option.",
                },
                .{
                    .name = "nested_str_opt",
                    .short_name = 's',
                    .long_name = "nested_str",
                    .val = Value.ofType([]const u8, .{
                        .name = "nested_str_val",
                        .description = "A nested string value.",
                        .default_val = "A nested string value.",
                    }),
                    .description = "A nested string option.",
                },
            },
            .vals = &.{
                Value.ofType(f32, .{
                    .name = "nested_float_val",
                    .description = "A nested float value.",
                    .default_val = 0,
                }),
            }
        },
        CustomCommand.from(DemoStruct, .{
            .cmd_name = "struct-cmd",
            .cmd_description = "A demo sub command made from a struct.",
        }),
        CustomCommand.from(ex_structs.add_user, .{
            .cmd_name = "add-user",
            .cmd_description = "A demo sub command for adding a user.",
        }),
    },
    .opts = &.{
        .{ 
            .name = "string_opt",
            .short_name = 's',
            .long_name = "string",
            .val = Value.ofType([]const u8, .{
                .name = "string_val",
                .description = "A string value.",
                .default_val = "A string value.",
                .set_behavior = .Multi,
                .max_args = 4,
            }),
            .description = "A string option. (Can be given up to 4 times.)",
        },
        .{
            .name = "int_opt",
            .short_name = 'i',
            .long_name = "int",
            .val = Value.ofType(i16, .{
                .name = "int_val",
                .description = "An integer value.",
                .valid_fn = struct{ fn valFn(int: i16) bool { return int < 666; } }.valFn,
                .set_behavior = .Multi,
                .max_args = 10,
            }),
            .description = "An integer option. (Can be given up to 10 times.)",
        },
        .{
            .name = "file_opt",
            .short_name = 'f',
            .long_name = "file",
            .val = .{ .string = .{
                .name = "file_val",
                .description = "A filepath value.",
                .valid_fn = Value.ValidationFns.validFilepath,
            } },
            .description = "A filepath option.",
        },
        .{
            .name = "ordinal_opt",
            .short_name = 'o',
            .long_name = "ordinal",
            .val = .{ .string = .{
                .name = "ordinal_val",
                .description = "An ordinal number value.",
                .valid_fn = Value.ValidationFns.ordinalNum,
            } },
            .description = "An ordinal number value.",
        },
        .{
            .name = "toggle_opt",
            .short_name = 't',
            .long_name = "toggle",
            .val = Value.ofType(bool, .{
                .name = "toggle_val",
                .description = "A toggle/boolean value.",
            }),
            .description = "A toggle/boolean option.",
        },
        .{
            .name = "verbosity_opt",
            .short_name = 'v',
            .long_name = "verbosity",
            .val = Value.ofType(u4, .{
                .name = "verbosity_level",
                .description = "The verbosity level from 0 (err) to 3 (debug).",
                .default_val = 3,
                .valid_fn = struct{ fn valFn(val: u4) bool { return val >= 0 and val <= 3; } }.valFn,
            }),
            .description = "Set the CovaDemo verbosity level. (WIP)",
        },
    },
    .vals = &.{
        Value.ofType([]const u8, .{
            .name = "cmd_str",
            .description = "A string value for the command.",
            .parse_fn = Value.ParsingFns.trimWhitespace,
        }),
        .{ .bool = .{
            .name = "cmd_bool",
            .description = "A boolean value for the command.",
            .parse_fn = Value.ParsingFns.Builder.altTrue(&.{ "potatoe" }),
        } },
        .{ .u128 = .{
            .name = "cmd_u128",
            .description = "A u128 value for the command.",
            .default_val = 654321,
            .set_behavior = .Multi,
            .max_args = 3,
            .parse_fn = struct{ fn parseFn(arg: []const u8) !u128 { return (try fmt.parseInt(u128, arg, 0)) * 100; } }.parseFn, 
            .valid_fn = Value.ValidationFns.Builder.inRange(u128, 123456, 9999999999, true),
        } },
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const stdout = std.io.getStdOut().writer();

    const main_cmd = &(try setup_cmd.init(alloc, .{})); 
    defer main_cmd.deinit();

    var args = try proc.argsWithAllocator(alloc);
    defer args.deinit();
    try cova.parseArgs(&args, CustomCommand, main_cmd, stdout, .{ .vals_mandatory = false, .allow_opt_val_no_space = true });
    try stdout.print("\n", .{});
    try displayCmdInfo(main_cmd, alloc);

    if (main_cmd.sub_cmd != null and mem.eql(u8, main_cmd.sub_cmd.?.name, "add-user")) {
        log.debug("To Struct:\n{any}\n\n", .{ main_cmd.sub_cmd.?.to(ex_structs.add_user, .{}) });
    }

    // Verbosity Change (WIP)
    //@constCast(&log_level).* = verbosity: {
    //    var opt_map = try cmd.getOpts(alloc);
    //    defer opt_map.deinit();
    //    const log_lvl = try opt_map.get("verbosity").?.val.u4.get();
    //    break :verbosity @intToEnum(log.Level, log_lvl);
    //};
    //try stdout.print("\n\nLogging Level ({any}):\n", .{ log.default_level });
    //log.err("Err", .{});
    //log.warn("Warn", .{});
    //log.info("Info", .{});
    //log.debug("Debug", .{});
}

/// A demo function to show what all is captured by Cova parsing.
fn displayCmdInfo(display_cmd: *const CustomCommand, alloc: mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    var cur_cmd: ?*const CustomCommand = display_cmd;
    while (cur_cmd != null) {
        const cmd = cur_cmd.?;

        if (cmd.checkFlag("help")) try cmd.help(stdout);
        if (cmd.checkFlag("usage")) try cmd.usage(stdout);

        try stdout.print("- Command: {s}\n", .{ cmd.name });
        if (cmd.opts != null) {
            for (cmd.opts.?) |opt| try displayValInfo(opt.val, opt.long_name, true, alloc);
        }
        if (cmd.vals != null) {
            for (cmd.vals.?) |val| try displayValInfo(val, val.name(), false, alloc);
        }
        try stdout.print("\n", .{});
        cur_cmd = cmd.sub_cmd;
    }
}

fn displayValInfo(val: Value.Generic, name: ?[]const u8, isOpt: bool, alloc: mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const prefix = if (isOpt) "Opt" else "Val";

    switch (meta.activeTag(val)) {
        .string => {
            try stdout.print("    {s}: {?s}, Data: \"{s}\"\n", .{
                prefix,
                name, 
                mem.join(alloc, "; ", val.string.getAll(alloc) catch &.{ "" }) catch "",
            });
        },
        inline else => |tag| {
            const tag_self = @field(val, @tagName(tag));
            if (tag_self.set_behavior == .Multi) {
                const raw_data: ?[]const @TypeOf(tag_self).val_type = rawData: { 
                    if (tag_self.getAll(alloc) catch null) |data| break :rawData data;
                    const data: ?@TypeOf(tag_self).val_type = tag_self.get() catch null;
                    if (data != null) break :rawData &.{ data.? };
                    break :rawData null;
                };
                try stdout.print("    {s}: {?s}, Data: {any}\n", .{ 
                    prefix,
                    name, 
                    raw_data,
                });
            }
            else {
                try stdout.print("    {s}: {?s}, Data: {any}\n", .{ 
                    prefix,
                    name, 
                    tag_self.get() catch null,
                });
            }
        },
    }
}
