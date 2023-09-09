//! Container Argument for Sub Commands, Options, and Values.
//!
//! A Command may contain any mix of those Arguments or none at all if it's to be used as a standalone Command.
//!
//! End User Example:
//!
//! ```
//! # Standalone Command
//! myapp help
//!
//! # Command w/ Options and Values
//! myapp -d "This Value belongs to the 'd' Option." --toggle "This is a standalone Value."
//! 
//! # Command w/ Sub Command
//! myapp --opt "Option for 'myapp' Command." subcmd --subcmd_opt "Option for 'subcmd' Sub Command."
//! ```

const std = @import("std");
const ascii = std.ascii;
const builtin = std.builtin;
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const meta = std.meta;
const ComptimeStringMap = std.ComptimeStringMap;
const StringHashMap = std.StringHashMap;

const toLower = ascii.toLower;
const toUpper = ascii.toUpper;

const Option = @import("Option.zig");
const Value = @import("Value.zig");
const utils = @import("utils.zig");
const indexOfEql = utils.indexOfEql;


/// Config for custom Command types. 
pub const Config = struct {
    /// Option Config for this Command type.
    opt_config: Option.Config = .{},
    /// Value Config for this Command type.
    val_config: Value.Config = .{},

    /// Sub Commands Help Format.
    /// Must support the following format types in this order:
    /// 1. String (Command Name)
    /// 2. String (Command Description)
    subcmds_help_fmt: []const u8 = "{s}: {s}",
    /// Values Help Format.
    /// Must support the following format types in this order:
    /// 1. String (Value Name)
    /// 2. String (Value Type)
    /// 3. String (Value Description)
    vals_help_fmt: []const u8 = "{s} ({s}): {s}",
    /// Sub Commands Usage Format.
    /// Must support the following format types in this order:
    /// 1. String (Command Name)
    subcmds_usage_fmt: []const u8 ="'{s}'", 
    /// Values Usage Format.
    /// Must support the following format types in this order:
    /// 1. String (Value Name)
    /// 2. String (Value Type)
    vals_usage_fmt: []const u8 = "\"{s} ({s})\"",

    /// The Global Help Prefix for all instances of this Command type.
    /// This can be overwritten per instance using the `help_prefix` field. 
    global_help_prefix: []const u8 = "",

    /// The Default Max Number of Arguments for Commands, Options, and Values individually.
    /// This is used in for both `init()` and `from()` but can be overwritten for the latter.
    max_args: u8 = 25, 

    /// During parsing, mandate that a Sub Command be used with a Command if one is available.
    /// This will not include Usage/Help Commands.
    /// This can be overwritten on individual Commands using the `Command.Custom.sub_cmds_mandatory` field.
    sub_cmds_mandatory: bool = true,
    /// During parsing, mandate that all Values for a Command must be filled, otherwise error out.
    /// This should generally be set to `true`. Prefer to use Options over Values for Arguments that are not mandatory.
    /// This can be overwritten on individual Commands using the `Command.Custom.vals_mandatory` field.
    vals_mandatory: bool = true,
};

/// Create a Command type with the Base (default) configuration.
pub fn Base() type { return Custom(.{}); }

/// Create a Custom Command type from the provided Config (`config`).
pub fn Custom(comptime config: Config) type {
    return struct {
        /// The Custom Option type to be used by this Custom Command type.
        const opt_config = optConfig: {
            var val_opt_config = config.opt_config;
            val_opt_config.val_config = config.val_config;
            break :optConfig val_opt_config;
        };
        pub const OptionT = Option.Custom(opt_config);
        /// The Custom Value type to be used by this Custom Command type.
        pub const ValueT = Value.Custom(config.val_config);

        /// Sub Commands Help Format.
        /// Check (`Command.Config`) for details.
        pub const subcmds_help_fmt = config.subcmds_help_fmt;
        /// Values Help Format.
        /// Check (`Command.Config`) for details.
        pub const vals_help_fmt = config.vals_help_fmt;
        /// Sub Commands Usage Format.
        /// Check (`Command.Config`) for details.
        pub const subcmds_usage_fmt = config.subcmds_usage_fmt;
        /// Values Usage Format.
        /// Check (`Command.Config`) for details.
        pub const vals_usage_fmt = config.vals_usage_fmt;
        /// Global Help Prefix.
        /// Check (`Command.Config`) for details.
        pub const global_help_prefix = config.global_help_prefix;
        /// Max Args.
        /// Check (`Command.Config`) for details.
        pub const max_args = config.max_args;

        /// Flag denoting if this Command has been initialized to memory using `init()`.
        ///
        /// **Internal Use.**
        _is_init: bool = false,
        /// The Allocator for this Command.
        /// This is set using `init()`.
        ///
        /// **Internal Use.**
        _alloc: ?mem.Allocator = null,

        /// The list of Sub Commands this Command can take.
        sub_cmds: ?[]const @This() = null,
        /// The Sub Command assigned to this Command during Parsing, if any.
        ///
        /// *This should be Read-Only for library users.*
        sub_cmd: ?*const @This() = null,

        /// The list of Options this Command can take.
        opts: ?[]const OptionT = null,
        /// The list of Values this Command can take.
        vals: ?[]const ValueT = null,

        /// The Name of this Command for user identification and Usage/Help messages.
        name: []const u8,
        /// The Prefix message used immediately before a Usage/Help message is displayed.
        help_prefix: []const u8 = global_help_prefix,
        /// The Description of this Command for Usage/Help messages.
        description: []const u8 = "",

        /// During parsing, mandate that a Sub Command be used with this Command if one is available.
        /// Note, this will not include Usage/Help Commands.
        sub_cmds_mandatory: bool = config.sub_cmds_mandatory,
        /// During parsing, mandate that all Values for this Command must be filled, otherwise error out.
        /// This should generally be set to `true`. Prefer to use Options over Values for Arguments that are not mandatory.
        vals_mandatory: bool = config.vals_mandatory,

        /// Sets the active Sub Command for this Command.
        pub fn setSubCmd(self: *const @This(), set_cmd: *const @This()) void {
            @constCast(self).*.sub_cmd = set_cmd;
        }
        /// Gets a reference to the Sub Command of this Command that matches the provided Name (`cmd_name`).
        pub fn getSubCmd(self: *const @This(), cmd_name: []const u8) ?*const @This() {
            if (self.sub_cmds == null) return null;
            for (self.sub_cmds.?[0..]) |*cmd| if (mem.eql(u8, cmd.name, cmd_name)) return cmd;
            return null;
        }
        /// Check if the active Sub Command of this Command has the provided Name (`cmd_name`).
        /// This is useful for analyzing Commands that DO NOT have Sub Commands that need to be subsequently analyzed.
        pub fn checkSubCmd(self: *const @This(), cmd_name: []const u8) bool {
            return if (self.sub_cmd) |cmd| mem.eql(u8, cmd.name, cmd_name) else false;
        }
        /// Returns the active Sub Command of this Command if it matches the provided Name (`cmd_name`). 
        /// This is useful for analyzing Commands that DO have Sub Commands that need to be subsequently analyzed.
        pub fn matchSubCmd(self: *const @This(), cmd_name: []const u8) ?*const @This() {
            return if (self.checkSubCmd(cmd_name)) self.sub_cmd.? else null;
        }

        /// Gets a StringHashMap of this Command's Options.
        pub fn getOpts(self: *const @This()) !StringHashMap(OptionT) {
            if (!self._is_init) return error.CommandNotInitialized;
            return self.getOptsAlloc(self._alloc.?);
        }
        /// Gets a StringHashMap of this Command's Options using the provided Allocator (`alloc`).
        pub fn getOptsAlloc(self: *const @This(), alloc: mem.Allocator) !StringHashMap(OptionT) {
            if (self.opts == null) return error.NoOptionsInCommand;
            var map = StringHashMap(OptionT).init(alloc);
            for (self.opts.?) |opt| { try map.put(opt.name, opt); }
            return map;
        }

        /// Gets a StringHashMap of this Command's Values.
        pub fn getVals(self: *const @This()) !StringHashMap(ValueT) {
            if (!self._is_init) return error.CommandNotInitialized;
            return self.getValsAlloc(self._alloc.?);
        }
        /// Gets a StringHashMap of this Command's Values using the provided Allocator (`alloc`).
        pub fn getValsAlloc(self: *const @This(), alloc: mem.Allocator) !StringHashMap(ValueT) {
            if (self.vals == null) return error.NoValuesInCommand;
            var map = StringHashMap(Value).init(alloc);
            for (self.vals.?) |val| { try map.put(val.name, val); }
            return map;
        }

        /// Creates the Help message for this Command and Writes it to the provided Writer (`writer`).
        pub fn help(self: *const @This(), writer: anytype) !void {
            try writer.print("{s}\n", .{ self.help_prefix });

            try self.usage(writer);

            try writer.print(
                \\HELP:
                \\    COMMAND: {s}
                \\
                \\    DESCRIPTION: {s}
                \\
                \\
                , .{ self.name, self.description }
            );
            
            if (self.sub_cmds != null) {
                try writer.print("    SUB COMMANDS:\n", .{});
                for (self.sub_cmds.?) |cmd| {
                    try writer.print("        ", .{});
                    try writer.print(subcmds_help_fmt, .{cmd.name, cmd.description});
                    try writer.print("\n", .{});
                }
            }
            try writer.print("\n", .{});

            if (self.opts != null) {
                try writer.print("    OPTIONS:\n", .{});
                for (self.opts.?) |opt| {
                    try writer.print("        ", .{});
                    try opt.help(writer);
                    try writer.print("\n", .{});
                }
            }
            try writer.print("\n", .{});

            if (self.vals != null) {
                try writer.print("    VALUES:\n", .{});
                for (self.vals.?) |val| {
                    try writer.print("        ", .{});
                    try writer.print(vals_help_fmt, .{ val.name(), val.valType(), val.description() });
                    try writer.print("\n", .{});
                }
            }
            try writer.print("\n", .{});
        }

        /// Creates the Usage message for this Command and Writes it to the provided Writer (`writer`).
        pub fn usage(self: *const @This(), writer: anytype) !void {
            try writer.print("USAGE: {s} ", .{ self.name });
            if (self.opts != null) {
                for (self.opts.?) |opt| {
                    try opt.usage(writer);
                    try writer.print(" ", .{});
                }
                try writer.print("| ", .{});
            }
            if (self.vals != null) {
                for (self.vals.?) |val| {
                    try writer.print(vals_usage_fmt, .{ val.name(), val.valType() });
                    try writer.print(" ", .{});
                }
                try writer.print("| ", .{});
            }
            if (self.sub_cmds != null) {
                for (self.sub_cmds.?) |cmd| {
                    try writer.print(subcmds_usage_fmt, .{ cmd.name });
                    try writer.print(" ", .{});
                }
            } 

            try writer.print("\n\n", .{});
        }

        /// Check if Usage or Help have been set and call their respective methods.
        /// Output will be written to the provided Writer (`writer`).
        pub fn checkUsageHelp(self: *const @This(), writer: anytype) !bool {
            if (self.checkFlag("usage")) {
                try self.usage(writer);
                return true;
            }
            if (self.checkFlag("help")) {
                try self.help(writer);
                return true;
            }
            return false;
        }

        /// Check if a Flag (`flag_name`) has been set on this Command as a Command, Option, or Value.
        /// This is particularly useful for checking if Help or Usage has been called.
        pub fn checkFlag(self: *const @This(), flag_name: []const u8) bool {
            return (
                (self.sub_cmd != null and mem.eql(u8, self.sub_cmd.?.name, flag_name)) or
                checkOpt: {
                    if (self.opts != null) {
                        for (self.opts.?) |opt| {
                            if (mem.eql(u8, opt.name, flag_name) and 
                                mem.eql(u8, opt.val.valType(), "bool") and 
                                opt.val.getAs(bool) catch false)
                                    break :checkOpt true;
                        }
                    }
                    break :checkOpt false;
                } or
                checkVal: {
                    if (self.vals != null) {
                        for (self.vals.?) |val| {
                            if (mem.eql(u8, val.name(), flag_name) and
                                mem.eql(u8, val.valType(), "bool") and
                                val.getAs(bool) catch false)
                                    break :checkVal true;
                        }
                    }
                    break :checkVal false;
                }
            );
        }

        /// Config for creating Commands from Structs using `from()`.
        pub const FromConfig = struct {
            /// Ignore incompatible types.
            ignore_incompatible: bool = true,
            /// Ignore prefix.
            /// Any Field that matches this prefix will not be converted in to an Argument Type.
            /// Setting this to `null` will disable prefix checks.
            ignore_prefix: ?[]const u8 = "_",
            /// Ignore the first field or parameter.
            /// This is particularly useful when converting a Function that has a `self` parameter.
            ignore_first: bool = false,
            /// Convert underscores '_' to dashes '-' in field names.
            /// Be sure to set the counterpart to this flag in the `ToConfig` if this Command will be converted back to a Struct or Union.
            convert_syntax: bool = true,
            /// Attempt to create Short Options.
            /// This will attempt to make a short option name from the first letter of the field name in lowercase then uppercase, sequentially working through each next letter if the previous one has already been used. (Note, user must deconflict for 'u' and 'h' if using auto-generated Usage/Help Options.)
            attempt_short_opts: bool = true,

            /// A Name for the Command.
            /// A blank value will default to the type name of the Struct.
            cmd_name: []const u8 = "",
            /// A Description for the Command.
            cmd_description: []const u8 = "",
            /// A Help Prefix for the Command.
            cmd_help_prefix: []const u8 = global_help_prefix,

            /// Descriptions of the Command's Arguments (Sub Commands, Options, and Values).
            /// These Descriptions will be used across this Command and all of its Sub Commands.
            ///
            /// Format: `.{ "argument_name", "Description of the Argument." }`
            sub_descriptions: []const struct { []const u8, []const u8 } = &.{ .{ "__nosubdescriptionsprovided__", "" } },
            /// During parsing, mandate that a Sub Command be used with a Command if one is available.
            /// This will not include Usage/Help Commands.
            sub_cmds_mandatory: ?bool = null,
            /// During parsing, mandate that all Values for a Command must be filled, otherwise error out.
            /// This should generally be set to `true`. Prefer to use Options over Values for Arguments that are not mandatory.
            vals_mandatory: ?bool = null,

            /// Max number of Sub Commands.
            max_cmds: u8 = max_args,
            /// Max number of Options.
            max_opts: u8 = max_args,
            /// Max number of Values.
            max_vals: u8 = max_args,
        };
        
        /// Create a Command from the provided Type (`From_T`).
        /// The provided Type must be a Comptime-known Function, Struct, or Union.
        pub fn from(comptime From_T: type, comptime from_config: FromConfig) @This() {
            const from_info = @typeInfo(From_T);
            return switch (from_info) {
                .Fn => fromFn(From_T, from_config),
                .Struct, .Union => fromStructOrUnion(From_T, from_config),
                else => @compileError("The provided type '" ++ @typeName(From_T) ++ "' must be a Function, Struct, or Union."),
            };
        }

        /// Create a Command from the provided Struct (`FromStruct`).
        /// The provided Struct must be Comptime-known.
        ///
        /// Field Types are converted as follows:
        /// - Functions, Structs, Unions = Commands
        /// - Valid Values = Single-Values (Valid Values can be found under `Value.zig/Generic`.)
        /// - Valid Optionals = Single-Options (Valid Optionals are nullable versions of Valid Values.)
        /// - Arrays of Valid Values = Multi-Values
        /// - Arrays of Valid Optionals = Multi-Options 
        pub fn fromStructOrUnion(comptime From_T: type, comptime from_config: FromConfig) @This() {
            const from_info = @typeInfo(From_T);
            if (from_info != .Struct and from_info != .Union) @compileError("Provided Type is not a Struct or Union.");

            var from_cmds_buf: [from_config.max_cmds]@This() = undefined;
            const from_cmds = from_cmds_buf[0..];
            var cmds_idx: u8 = 0;
            var from_opts_buf: [from_config.max_opts]OptionT = undefined;
            const from_opts = from_opts_buf[0..];
            var opts_idx: u8 = 0;
            var short_names_buf: [from_config.max_opts]u8 = undefined;
            const short_names = short_names_buf[0..];
            var short_idx: u8 = 0;
            var from_vals_buf: [from_config.max_vals]ValueT = undefined;
            const from_vals = from_vals_buf[0..];
            var vals_idx: u8 = 0;

            const arg_descriptions = ComptimeStringMap([]const u8, from_config.sub_descriptions);

            const fields = meta.fields(From_T);
            const start_idx = if (from_config.ignore_first) 1 else 0;
            inline for (fields[start_idx..]) |field| {
                if (from_config.ignore_prefix) |prefix| {
                    if (field.name.len > prefix.len and mem.eql(u8, field.name[0..prefix.len], prefix)) continue;
                }
                var arg_name_buf: [field.name.len]u8 = field.name[0..].*;
                const arg_name = if (!from_config.convert_syntax) field.name else argName: {
                    _ = mem.replace(u8, field.name[1..], "_", "-", arg_name_buf[1..]);
                    break :argName arg_name_buf[0..];
                };
                const arg_description = arg_descriptions.get(field.name);
                // Handle Argument types.
                switch (field.type) {
                    @This() => {
                        if (field.default_value != null) {
                            from_cmds[cmds_idx] = @as(*field.type, @ptrCast(@alignCast(@constCast(field.default_value)))).*;
                            cmds_idx += 1;
                            continue;
                        }
                    },
                    OptionT => {
                        if (field.default_value != null) {
                            from_opts[opts_idx] = @as(*field.type, @ptrCast(@alignCast(@constCast(field.default_value)))).*;
                            opts_idx += 1;
                            continue;
                        }
                    },
                    ValueT => {
                        if (field.default_value != null) {
                            from_vals[vals_idx] = @as(*field.type, @ptrCast(@alignCast(@constCast(field.default_value)))).*;
                            vals_idx += 1;
                            continue;
                        }
                    },
                    inline else => {},
                }

                const field_info = @typeInfo(field.type);
                // Handle non-Argument types.
                switch (field_info) {
                    // Commands
                    .Fn, .Struct => {
                        const sub_config = comptime subConfig: {
                            var new_config = from_config;
                            new_config.cmd_name = arg_name;
                            new_config.cmd_description = arg_description orelse "The '" ++ arg_name ++ "' Command.";
                            break :subConfig new_config;
                        };
                        from_cmds[cmds_idx] = from(field.type, sub_config);
                        cmds_idx += 1;
                    },
                    // Options
                    // TODO - Handle Command types passed as Optionals?
                    .Optional => {
                        const short_name = shortName: {
                            if (!from_config.attempt_short_opts) break :shortName null;
                            for (arg_name) |char| {
                                const ul_chars: [2]u8 = .{ toLower(char), toUpper(char) };
                                for (ul_chars) |ul| {
                                    if (short_idx > 0 and indexOfEql(u8, short_names[0..short_idx], ul) != null) continue;
                                    short_names[short_idx] = ul;
                                    short_idx += 1;
                                    break :shortName ul;
                                }
                            }
                            break :shortName null;
                        };
                        from_opts[opts_idx] = (OptionT.from(field, .{ 
                            .name = arg_name,
                            .short_name = short_name, 
                            .long_name = arg_name,
                            .ignore_incompatible = from_config.ignore_incompatible,
                            .opt_description = arg_description
                        }) orelse continue);
                        opts_idx += 1;
                    },
                    // Values
                    .Bool, .Int, .Float, .Pointer => {
                        from_vals[vals_idx] = (ValueT.from(field, .{
                            .ignore_incompatible = from_config.ignore_incompatible,
                            .val_name = arg_name,
                            .val_description = arg_description
                        }) orelse continue);
                        vals_idx += 1;
                    },
                    // Multi
                    .Array => |ary| {
                        const ary_info = @typeInfo(ary.child);
                        switch (ary_info) {
                            // Options
                            .Optional => {
                                const short_name = shortName: {
                                    if (!from_config.attempt_short_opts) break :shortName null;
                                    for (arg_name) |char| {
                                        const ul_chars: [2]u8 = .{ toLower(char), toUpper(char) };
                                        for (ul_chars) |ul| {
                                            if (short_idx > 0 and indexOfEql(u8, short_names[0..short_idx], ul) != null) continue;
                                            short_names[short_idx] = ul;
                                            short_idx += 1;
                                            break :shortName ul;
                                        }
                                    }
                                    break :shortName null;
                                };
                                from_opts[opts_idx] = OptionT.from(field, .{
                                    .name = arg_name,
                                    .short_name = short_name, 
                                    .long_name = arg_name,
                                    .ignore_incompatible = from_config.ignore_incompatible,
                                    .opt_description = arg_description
                                }) orelse continue;
                                opts_idx += 1;
                            },
                            // Values
                            .Bool, .Int, .Float, .Pointer => {
                                from_vals[vals_idx] = ValueT.from(field, .{
                                    .ignore_incompatible = from_config.ignore_incompatible,
                                    .val_name = arg_name,
                                    .val_description = arg_description
                                }) orelse continue;
                                vals_idx += 1;
                            },
                            else => if (!from_config.ignore_incompatible) @compileError("The field '" ++ field.name ++ "' of type 'Array' is incompatible. Arrays must contain one of the following types: Bool, Int, Float, Pointer (const u8), or their Optional counterparts."),
                        }
                    },
                    // Incompatible
                    else => if (!from_config.ignore_incompatible) @compileError("The field '" ++ field.name ++ "' of type '" ++ @typeName(field.type) ++ "' is incompatible as it cannot be converted to a Command, Option, or Value."),
                }
            }

            var cmd_name_buf: [@typeName(From_T).len]u8 = undefined;
            const cmd_name = if (from_config.cmd_name.len > 0) from_config.cmd_name else cmdName: {
                if (!from_config.convert_syntax) break :cmdName @typeName(From_T) else {
                    _ = mem.replace(u8, @typeName(From_T), "_", "-", cmd_name_buf);
                    break :cmdName cmd_name_buf[0..];
                }
            };
            return @This(){
                .name = cmd_name,
                .description = from_config.cmd_description,
                .help_prefix = from_config.cmd_help_prefix,
                .sub_cmds = if (cmds_idx > 0) from_cmds[0..cmds_idx] else null,
                .opts = if (opts_idx > 0) from_opts[0..opts_idx] else null,
                .vals = if (vals_idx > 0) from_vals[0..vals_idx] else null,
                .sub_cmds_mandatory = if (from_config.sub_cmds_mandatory) |config_sub_man| config_sub_man else config.sub_cmds_mandatory,
                .vals_mandatory = if (from_config.vals_mandatory) |config_vals_man| config_vals_man else config.vals_mandatory,
            };
        }

        /// Create a Command from the provided Function (`from_fn`).
        /// The provided Function must be Comptime-known.
        ///
        /// Types are converted as follows:
        /// - Functions, Structs, Unions = Commands
        /// - Valid Single-Parameters = Single-Values (Valid Values can be found under `Value.zig/Generic`.)
        /// - Valid Array/Slice-Parameters = Multi-Values
        /// - Note: Options can not be generated from Functions due to the lack of parameter names in `std.builtin.Type.Fn.Param`.
        pub fn fromFn(comptime FromFn: type, comptime from_config: FromConfig) @This() {
            const from_info = @typeInfo(FromFn);
            if (from_info != .Fn) @compileError("Provided Type is not a Function.");

            var from_cmds_buf: [from_config.max_cmds]@This() = undefined;
            const from_cmds = from_cmds_buf[0..];
            var cmds_idx: u8 = 0;
            var from_vals_buf: [from_config.max_vals]ValueT = undefined;
            const from_vals = from_vals_buf[0..];
            var vals_idx: u8 = 0;

            //const arg_descriptions = ComptimeStringMap([]const u8, from_config.sub_descriptions);

            const params = from_info.Fn.params;
            const start_idx = if (from_config.ignore_first) 1 else 0;
            inline for (params[start_idx..]) |param| {
                const arg_description = "No description. (Descriptions cannot currently be generated from Function Parameters.)";//arg_descriptions.get(param.name);
                // Handle Argument types.
                switch (@typeInfo(param.type.?)) {
                    // Commands
                    .Fn, .Struct, .Union => {
                        const sub_config = comptime subConfig: {
                            var new_config = from_config;
                            new_config.cmd_name = "cmd-" ++ &.{ cmds_idx + 48 };
                            new_config.cmd_description = arg_description orelse "The '" ++ new_config.cmd_name ++ "' Command.";
                            break :subConfig new_config;
                        };
                        from_cmds[cmds_idx] = from(param.type, sub_config);
                        cmds_idx += 1;
                    },
                    // Values
                    .Bool, .Int, .Float, .Optional, .Pointer => {
                        from_vals[vals_idx] = (ValueT.from(param, .{
                            .ignore_incompatible = from_config.ignore_incompatible,
                            .val_name = "val-" ++ .{ '0', (vals_idx + 48), },
                            .val_description = arg_description
                        }) orelse continue);
                        vals_idx += 1;
                    },
                    // Multi
                    .Array => |ary| {
                        const ary_info = @typeInfo(ary.child);
                        switch (ary_info) {
                            // Values
                            .Bool, .Int, .Float, .Optional, .Pointer => {
                                from_vals[vals_idx] = ValueT.from(param, .{
                                    .ignore_incompatible = from_config.ignore_incompatible,
                                    .val_description = arg_description
                                }) orelse continue;
                                vals_idx += 1;
                            },
                            else => if (!from_config.ignore_incompatible) @compileError("The parameter of type 'Array' is incompatible. Arrays must contain one of the following types: Bool, Int, Float, Pointer (const u8), or their Optional counterparts."),
                        }
                    },
                    // Incompatible
                    else => if (!from_config.ignore_incompatible) @compileError("The parameter of type '" ++ @typeName(param.type) ++ "' is incompatible as it cannot be converted to a Command or Value."),
                }
            }

            return @This(){
                .name = if (from_config.cmd_name.len > 0) from_config.cmd_name else @typeName(FromFn),
                .description = from_config.cmd_description,
                .help_prefix = from_config.cmd_help_prefix,
                .sub_cmds = if (cmds_idx > 0) from_cmds[0..cmds_idx] else null,
                .vals = if (vals_idx > 0) from_vals[0..vals_idx] else null,
            };
        }

        /// Config for creating Structs from Commands using `to()`.
        pub const ToConfig = struct {
            /// Allow Unset Options and Values to be included.
            /// When this is active, an attempt will be made to use the Struct's default value (if available) in the event of an Unset Option/Value.
            allow_unset: bool = true,
            /// Ignore Incompatible types. Incompatible types are those that fall outside of the conversion rules listed under `from()`.
            /// When this is active, an attempt will be made to use the Struct's default value (if available) in the event of an Incompatible type.
            /// This will also allow Values to be set to sane defaults for Integers and Floats (0) as well as Strings ("").
            allow_incompatible: bool = true,
            /// Convert dashes '-' to underscores '_' in field names.
            /// Be sure to set the counterpart to this flag in the `FromConfig` if this Command will be converted from a Struct or Union.
            convert_syntax: bool = true,
        };

        /// Convert this Command to an instance of the provided Struct or Union Type (`to_T`).
        /// This is the inverse of `from()`.
        ///
        /// Types are converted as follows:
        /// - Commmands: Structs or Unions by recursively calling `to()`.
        /// - Single-Options: Optional versions of Values.
        /// - Single-Values: Booleans, Integers (Signed/Unsigned), and Pointers (`[]const u8`) only)
        /// - Multi-Options/Values: Arrays of the corresponding Optionals or Values.
        // TODO: Catch more error cases for incompatible types (i.e. Pointer not (`[]const u8`).
        pub fn to(self: *const @This(), comptime To_T: type, to_config: ToConfig) !To_T {
            if (!self._is_init) return error.CommandNotInitialized;
            const type_info = @typeInfo(To_T);
            if (type_info == .Union) { 
                const vals_idx = if (self.vals) |vals| valsIdx: {
                    var idx: u8 = 0;
                    for (vals) |val| { if (val.isSet()) idx += 1; }
                    break :valsIdx idx;
                } else 0;
                const opts_idx = if (self.opts) |opts| optsIdx: {
                    var idx: u8 = 0;
                    for (opts) |opt| { 
                        if (
                            opt.val.isSet() and
                            !mem.eql(u8, opt.name, "usage") and
                            !mem.eql(u8, opt.name, "help")
                        ) idx += 1; 
                    }
                    break :optsIdx idx;
                } else 0;
                const total_idx = vals_idx + opts_idx;
                if (total_idx > 1) { 
                    log.err("Commands from Unions can only hold 1 Value or Option, but '{d}' were given.", .{ total_idx });
                    return error.ExpectedOnlyOneValOrOpt;
                }
            }
            var out: To_T = undefined;
            const fields = meta.fields(To_T);
            inline for (fields) |field| {
                if (field.type == @This() or field.type == OptionT or field.type == ValueT) continue;
                var arg_name_buf: [field.name.len]u8 = field.name[0..].*;
                const arg_name = if (!to_config.convert_syntax) field.name else argName: {
                    _ = mem.replace(u8, field.name[1..], "_", "-", arg_name_buf[1..]);
                    break :argName arg_name_buf[0..];
                };
                const field_info = @typeInfo(field.type);
                switch (field_info) {
                    .Struct => if (self.sub_cmd != null and mem.eql(u8, self.sub_cmd.?.name, arg_name)) {
                        @field(out, field.name) = try self.sub_cmd.?.to(field.type, to_config);
                    },
                    .Union => if (self.sub_cmd != null and mem.eql(u8, self.sub_cmd.?.name, arg_name)) {
                        return @unionInit(To_T, field.name, try self.sub_cmd.?.to(field.type, to_config));
                    },
                    .Optional => |f_opt| if (self.opts != null) {
                        for (self.opts.?) |opt| {
                            if (mem.eql(u8, opt.name, arg_name)) {
                                if (!opt.val.isSet() and type_info == .Struct) {
                                    if (!to_config.allow_unset) return error.ValueNotSet;
                                    if (field.default_value != null) 
                                        @field(out, field.name) = @as(*field.type, @ptrCast(@alignCast(@constCast(field.default_value)))).*;
                                    break;
                                }
                                //const val_tag = if (f_opt.child == []const u8) "string" else @typeName(f_opt.child);
                                //if (type_info == .Union) return @unionInit(To_T, field.name, @field(opt.val.generic, val_tag).get() catch continue); 
                                //@field(out, field.name) = try @field(opt.val.generic, val_tag).get();
                                if (type_info == .Union) return @unionInit(To_T, field.name, opt.val.getAs(f_opt.child) catch continue); 
                                @field(out, field.name) = try opt.val.getAs(f_opt.child);
                            }
                        }
                    },
                    .Bool, .Int, .Float, .Pointer => if (self.vals != null) {
                        for (self.vals.?) |val| {
                            if (mem.eql(u8, val.name(), arg_name)) {
                                if (!val.isSet() and val.argIdx() == val.maxArgs() and type_info == .Struct) {
                                    if (!to_config.allow_unset) return error.ValueNotSet;
                                    if (field.default_value != null) 
                                        @field(out, field.name) = @as(*field.type, @ptrCast(@alignCast(@constCast(field.default_value)))).*;
                                    break;
                                }
                                //const val_tag = if (field.type == []const u8) "string" else @typeName(field.type);
                                //if (type_info == .Union) return @unionInit(To_T, field.name, @field(val.generic, val_tag).get() catch continue); 
                                //@field(out, field.name) = try @field(val.generic, val_tag).get();
                                if (type_info == .Union) return @unionInit(To_T, field.name, val.getAs(field.type) catch continue); 
                                @field(out, field.name) = val.getAs(field.type) catch |err| setVal: {
                                    if (!to_config.allow_incompatible) return error.IncompatibleType;
                                    break :setVal switch (field_info) {
                                        .Bool => false,
                                        .Int, .Float, => @as(field.type, 0),
                                        .Pointer => "",    
                                        else => return err,
                                    };
                                };
                            }
                        } 
                    },
                    .Array => |ary| {
                        const ary_info = @typeInfo(ary.child);
                        switch (ary_info) {
                            .Optional => |a_opt| if (self.opts != null) {
                                for (self.opts.?) |opt| {
                                    if (mem.eql(u8, opt.name, arg_name)) {
                                        if (!opt.val.isSet() and type_info == .Struct) {
                                            if (!to_config.allow_unset) return error.ValueNotSet;
                                            if (field.default_value != null)  
                                                @field(out, field.name) = @as(*field.type, @ptrCast(@alignCast(@constCast(field.default_value)))).*;
                                            break;
                                        }
                                        const val_tag = if (a_opt.child == []const u8) "string" else @typeName(a_opt.child);
                                        var f_ary: field.type = undefined;
                                        const f_ary_slice = f_ary[0..];
                                        for (f_ary_slice, 0..) |*elm, idx| elm.* = @field(opt.val.generic, val_tag)._set_args[idx];
                                        if (type_info == .Union) return @unionInit(To_T, field.name, f_ary); 
                                        @field(out, field.name) = f_ary;
                                        break;
                                    }
                                }
                            },
                            .Bool, .Int, .Float, .Pointer => if (self.vals != null) {
                                for (self.vals.?) |val| {
                                    if (mem.eql(u8, val.name(), arg_name)) {
                                        if (!val.isSet() and val.argIdx() == val.maxArgs() and type_info == .Struct) {
                                            if (!to_config.allow_unset) return error.ValueNotSet;
                                            if (field.default_value != null) 
                                                @field(out, field.name) = @as(*field.type, @ptrCast(@alignCast(@constCast(field.default_value)))).*;
                                            break;
                                        }
                                        const val_tag = if (ary.child == []const u8) "string" else @typeName(ary.child);
                                        var f_ary: field.type = undefined;
                                        const f_ary_slice = f_ary[0..];
                                        for (f_ary_slice, 0..) |*elm, idx| elm.* = @field(val.generic, val_tag)._set_args[idx] orelse elmVal: {
                                            break :elmVal switch (ary_info) {
                                                .Bool => false,
                                                .Int, .Float, => @as(ary.child, 0),
                                                .Pointer => "",    
                                                else => if (!to_config.allow_incompatible) return error.IncompatibleType,
                                            };
                                        };
                                        if (type_info == .Union) return @unionInit(To_T, field.name, f_ary); 
                                        @field(out, field.name) = f_ary;
                                        break;
                                    }
                                } 
                            },
                            else => {
                                if (!to_config.allow_incompatible) return error.IncompatibleType;
                            },
                        }
                    },
                    else => {
                        if (!to_config.allow_incompatible) return error.IncompatibleType;
                    },
                }
            }
            return out;
        }

        /// Call this Command as the provided Function (`call_fn`), returning the provided Return Type (`Return_T`).
        /// If the Return Type is an Error Union, this method expects only the payload Type.
        /// If the Function has a `self` parameter it can be provided using (`fn_self`). 
        /// This effectively wraps the `@call()` builtin function by using this Command's Values as the function parameters.
        pub fn callAs(self: *const @This(), comptime call_fn: anytype, fn_self: anytype, comptime Return_T: type) !Return_T {
            const fn_info = @typeInfo(@TypeOf(call_fn));
            const fn_name = @typeName(@TypeOf(call_fn));
            if (fn_info != .Fn) {
                log.err("Expected a Function but received '{s}'.", .{ fn_name });
                return error.ExpectedFn;
            }
            if (self.vals == null or self.vals.?.len < fn_info.Fn.params.len) {
                log.err("The provided function requires {d} parameters but only {d} was/were provided.", .{ 
                    fn_info.Fn.params.len, 
                    if (self.vals == null) 0 else self.vals.?.len });
                return error.ExpectedMoreParameters;
            }
            if (fn_info.Fn.return_type.? != Return_T) checkErrorUnion: {
                const return_info = @typeInfo(fn_info.Fn.return_type.?);
                if (return_info == .ErrorUnion and return_info.ErrorUnion.payload == Return_T) break :checkErrorUnion;
                log.err("The return type of '{s}' does not match the provided return type '{s}'.", .{ fn_name, @typeName(Return_T) });
                return error.ReturnTypeMismatch;
            }

            const params = valsToParams: { 
                const param_types = comptime paramTypes: {
                    var types: [fn_info.Fn.params.len]type = undefined;
                    for (types[0..], fn_info.Fn.params) |*T, param| T.* = param.type.?;
                    break :paramTypes types;
                };
                var params_tuple: meta.Tuple(param_types[0..]) = undefined;
                const start_idx = if (@TypeOf(fn_self) == param_types[0]) 1 else 0;
                if (start_idx == 1) params_tuple[0] = fn_self;
                inline for (self.vals.?, &params_tuple, 0..) |val, *param, idx| {
                    if (idx < start_idx) continue;
                    param.* = try val.getAs(@TypeOf(param.*)); 
                }
                
                break :valsToParams params_tuple;
            };

            return @call(.auto, call_fn, params); 
        }

        /// Create Sub Commands Enum.
        /// This is useful for switching on the Sub Commands of this Command during analysis, but the Command (`self`) must be comptime-known.
        pub fn SubCommandsEnum(comptime self: *const @This()) ?type {
            if (self.sub_cmds == null) return null; //@compileError("Could not create Sub Commands Enum. This Command has no Sub Commands.");
            var cmd_fields: [self.sub_cmds.?.len]builtin.Type.EnumField = undefined;
            for (self.sub_cmds.?, cmd_fields[0..], 0..) |cmd, *field, idx| {
                field.* = .{
                    .name = cmd.name,
                    .value = idx,
                };
            }
            return @Type(builtin.Type{
                .Enum = .{
                    .tag_type = u8,
                    .fields = cmd_fields[0..],
                    .decls = &.{},
                    .is_exhaustive = true,
                }
            });
        }

        /// Config for the Validation of this Command.
        pub const ValidateConfig = struct {
            // Check for Usage/Help Commands
            check_help_cmds: bool = false,
            // Check for Usage/Help Options
            check_help_opts: bool = false,
        };

        /// Validate this Command during Comptime for distinct Sub Commands, Options, and Values using the provided ValidateConfig (`valid_config`). 
        pub fn validate(comptime self: *const @This(), comptime valid_config: ValidateConfig) void {
            comptime {
                @setEvalBranchQuota(100_000);
                const usage_help_strs = .{ "usage", "help" } ++ (.{ "" } ** (max_args - 2));
                // Check for distinct Sub Commands and Validate them.
                if (self.sub_cmds != null) {
                    const idx_offset: u2 = if (valid_config.check_help_cmds) 2 else 0;
                    const cmds = self.sub_cmds.?;
                    var distinct_cmd: [max_args][]const u8 =
                        if (!valid_config.check_help_cmds) .{ "" } ** max_args
                        else usage_help_strs; 
                    for (cmds, 0..) |cmd, idx| {
                        if (indexOfEql([]const u8, distinct_cmd[0..idx], cmd.name) != null) 
                            @compileError("The Sub Command '" ++ cmd.name ++ "' is set more than once.");
                        //cmd.validate();
                        distinct_cmd[idx + idx_offset] = cmd.name;
                    }
                }

                // Check for distinct Options.
                if (self.opts != null) {
                    const idx_offset: u2 = if (valid_config.check_help_cmds) 2 else 0;
                    const opts = self.opts.?;
                    var distinct_name: [max_args][]const u8 = 
                        if (!valid_config.check_help_opts) .{ "" } ** max_args
                        else usage_help_strs; 
                    var distinct_short: [max_args]u8 = 
                        if (!valid_config.check_help_opts) .{ ' ' } ** max_args
                        else .{ 'u', 'h' } ++ (.{ ' ' } ** (max_args - 2));
                    var distinct_long: [max_args][]const u8 = 
                        if (!valid_config.check_help_opts) .{ "" } ** max_args
                        else usage_help_strs; 
                    for (opts, 0..) |opt, idx| {
                        if (indexOfEql([]const u8, distinct_name[0..], opt.name) != null) 
                            @compileError("The Option '" ++ opt.name ++ "' is set more than once.");
                        distinct_name[idx + idx_offset] = opt.name;
                        if (opt.short_name != null and indexOfEql(u8, distinct_short[0..], opt.short_name.?) != null) 
                            @compileError("The Option Short Name '" ++ .{ opt.short_name.? } ++ "' is set more than once.");
                        distinct_short[idx + idx_offset] = opt.short_name orelse ' ';
                        if (opt.long_name != null and indexOfEql([]const u8, distinct_long[0..], opt.long_name.?) != null) 
                            @compileError("The Option Long Name '" ++ opt.long_name.? ++ "' is set more than once.");
                        distinct_long[idx + idx_offset] = opt.long_name orelse "a!garbage@long#name$";
                    }
                }

                // Check for distinct Values.
                if (self.vals != null) {
                    const vals = self.vals.?;
                    var distinct_val: [max_args][]const u8 = .{ "" } ** max_args;
                    for (vals, 0..) |val, idx| {
                        if (indexOfEql([]const u8, distinct_val[0..], val.name()) != null) 
                            @compileError("The Value '" ++ val.name ++ "' is set more than once.");
                        distinct_val[idx] = val.name();
                    }
                }
            }
        }

        /// Config for the Initialization of this Command.
        pub const InitConfig = struct {
            /// Validate this Command.
            validate_cmd: bool = true,
            /// Add Usage/Help message Commands to this Command.
            add_help_cmds: bool = true,
            /// Add Usage/Help message Options to this Command.
            add_help_opts: bool = true,
            /// Initialize this Command's Sub Commands.
            init_subcmds: bool = true,
        };

        /// Initialize this Command with the provided InitConfig (`init_config`) by duplicating it with the provided Allocator (`alloc`) for Runtime use.
        /// This should be used after this Command has been created in Comptime. 
        pub fn init(comptime self: *const @This(), alloc: mem.Allocator, comptime init_config: InitConfig) !@This() {
            if (init_config.validate_cmd) self.validate(.{ 
                .check_help_cmds = init_config.add_help_cmds,
                .check_help_opts = init_config.add_help_opts,    
            });

            var init_cmd = (try alloc.dupe(@This(), &.{ self.* }))[0];

            const usage_description = try mem.concat(alloc, u8, &.{ "Show the '", init_cmd.name, "' usage display." });
            const help_description = try mem.concat(alloc, u8, &.{ "Show the '", init_cmd.name, "' help display." });

            if (init_config.add_help_cmds and (indexOfEql([]const u8, &.{ "help", "usage" }, self.name) == null)) {
                const help_sub_cmds = &[2]@This(){
                    .{
                        .name = "usage",
                        .help_prefix = init_cmd.name,
                        .description = usage_description,
                        ._is_init = true,
                        ._alloc = alloc,
                    },
                    .{
                        .name = "help",
                        .help_prefix = init_cmd.name,
                        .description = help_description,
                        ._is_init = true,
                        ._alloc = alloc,
                    }
                };

                init_cmd.sub_cmds = 
                    if (init_cmd.sub_cmds != null) try mem.concat(alloc, @This(), &.{ init_cmd.sub_cmds.?, help_sub_cmds[0..] })
                    else try alloc.dupe(@This(), help_sub_cmds[0..]);
            }

            if (init_config.init_subcmds and self.sub_cmds != null) {
                const sub_len = init_cmd.sub_cmds.?.len;
                var init_subcmds = try alloc.alloc(@This(), sub_len);
                inline for (self.sub_cmds.?, 0..) |cmd, idx| init_subcmds[idx] = try cmd.init(alloc, init_config);
                if (init_config.add_help_cmds and (indexOfEql([]const u8, &.{ "help", "usage" }, self.name) == null)) {
                    init_subcmds[sub_len - 2] = init_cmd.sub_cmds.?[sub_len - 2];
                    init_subcmds[sub_len - 1] = init_cmd.sub_cmds.?[sub_len - 1];
                }
                init_cmd.sub_cmds = init_subcmds;
            }

            if (init_config.add_help_opts) {
                const help_opts = &[2]OptionT{
                    .{
                        .name = "usage",
                        .short_name = 'u',
                        .long_name = "usage",
                        .description = usage_description,
                        .val = ValueT.ofType(bool, .{ .name = "usage_flag" }),
                    },
                    .{
                        .name = "help",
                        .short_name = 'h',
                        .long_name = "help",
                        .description = help_description,
                        .val = ValueT.ofType(bool, .{ .name = "help_flag" }),
                    },
                };

                init_cmd.opts = 
                    if (init_cmd.opts != null) try mem.concat(alloc, @This().OptionT, &.{ init_cmd.opts.?, help_opts[0..] })
                    else try alloc.dupe(OptionT, help_opts[0..]);
            }

            init_cmd._is_init = true;
            init_cmd._alloc = alloc;

            return init_cmd; 
        }

        /// De-initialize this Command with its original Allocator.
        /// If this Command has not yet been initialized, this does nothing.
        pub fn deinit(self: *const @This()) void {
            if (!self._is_init) return;
            if (self.sub_cmds != null)
                for (self.sub_cmds.?) |*cmd| cmd.deinit();
            self._alloc.?.destroy(self);
        }
    };
}

