//! Argument that is expected in a specific order and should be interpreted as a specific type.
//!
//! End User Example:
//!
//! ```
//! # Values belonging to a Command.
//! myapp "This string Value and the int Value after it both belong to the 'myapp' main Command." 13
//!
//! # Values belonging to an Option.
//! myapp --string_opt "This Value belongs to the 'string_opt' Option."
//! ```

const std = @import("std");
const builtin = std.builtin;
const ascii = std.ascii;
const fmt = std.fmt;
const fs = std.fs;
const log = std.log;
const mem = std.mem;
const meta = std.meta;

const toLower = ascii.lowerString;
const toUpper = ascii.upperString;
const parseInt = fmt.parseInt;
const parseFloat = fmt.parseFloat;
const Type = builtin.Type;

const utils = @import("utils.zig");

/// Config for custom Value types. 
/// This Config is shared across Typed, Generic, and Custom.
pub const Config = struct {
    /// Default Set Behavior for all Values.
    /// This can be overwritten on individual Values using the `Value.Typed.set_behavior` field.
    global_set_behavior: SetBehavior = .Last,
    /// Default Argument Delimiters for all Values.
    /// This can be overwritten on individual Values using the `Value.Typed.arg_delims` field.
    global_arg_delims: []const u8 = ",;",
    /// Maximum instances of a Child Type that a Value can hold.
    max_children: u8 = 10,

    /// Custom Types for this project's Custom Values. 
    /// If these Types are `Value.Typed` they'll be coerced to match the parent `Value.Config` (not preferred).
    /// Otherwise, each Type will be wrapped into a `Value.Typed` (preferred).
    /// This is useful for adding additional types that aren't covered by the base `Value.Generic` union.
    /// Note, any non-numeric (Int, UInt, Float) or non-`Value.Typed` Types will require their own Parse Function.
    /// This function is implemented on the `Value.Typed.parse_fn` field.
    custom_types: []const type = &.{},
    /// Use the slim base Union. This is automatically treated as true if there are any custom Types specified.
    /// This toggle can be used to slim down the base `Value.Generic` Union to only `bool` and `[]const u8` (string).
    /// In turn, this will help reduce the overall binary size.
    /// Be sure to set `add_base_ints` and `add_base_floats` appropriately as well.
    use_slim_base: bool = false,
    /// Add Base Integers (signed and unsigned) when adding custom Types.
    /// This includes `u1`-`u4` directly and `u8`-`u64` by powers of 2, along with their signed counterparts.
    add_base_ints: bool = true,
    /// Add Base Floats when adding custom Types.
    /// This includes `f16`, `f32`, and `f64`.
    add_base_floats: bool = true,

    /// Custom Parsing Functions to be used in place of the normal `parse()` for Argument Parsing for all instances of a `Value.Typed` Child Type.
    /// These functions will be used SECOND, after an instance's `self.parse_fn` but before the normal `parse()` functions are tried.
    /// This can be used to overwrite the `parse()` implementation for an existing Child Type that's already in `Value.Generic`.
    /// Note that any error caught from these function will be returned as `error.CannotParseArgToValue`.
    child_type_parse_fns: ?[]const struct{ 
        /// The Child Type this function applies to.
        ChildT: type,
        /// The custom Parse Function.
        parse_fn: *const anyopaque, 
    } = null,

    /// Use Custom Bit Width Range for Ints and UInts.
    /// This is useful for specifying a wide range of Int and UInt types for a project.
    /// Note, this will slow down compilation speed!!! (It does not affect runtime speed).
    use_custom_bit_width_range: bool = false,
    /// Minimum Bit Width for Ints and UInts in this Custom Value type.
    /// Note, only applies if `use_custom_bit_width_range` is set to `true`.
    min_int_bit_width: u16 = 1,
    /// Minimum Bit Width for Ints and UInts in this Custom Value type.
    /// Note, only applies if `use_custom_bit_width_range` is set to `true`.
    max_int_bit_width: u16 = 256,

    /// A custom Help function to override the default `help()` function globally for ALL Value instances of this custom Value Type.
    /// This function is 2nd in precedence.
    ///
    /// Function parameters:
    /// 1. ValueT (This should be the `self` parameter. As such it needs to match the Value Type the function is being called on.)
    /// 2. Writer (This is the Writer that will written to.)
    /// 3. Allocator (This does not have to be used within in the function, but must be supported in case it's needed.)
    global_help_fn: ?*const fn(anytype, anytype, mem.Allocator)anyerror!void = null,
    /// A custom Help function to override the default `usage()` function globally for ALL Value instances of this custom Value Type.
    /// This function is 2nd in precedence.
    ///
    /// Function parameters:
    /// 1. ValueT (This should be the `self` parameter. As such it needs to match the Value Type the function is being called on.)
    /// 2. Writer (This is the Writer that will written to.)
    /// 3. Allocator (This does not have to be used within the function, but must be supported in case it's needed.)
    global_usage_fn: ?*const fn(anytype, anytype, mem.Allocator)anyerror!void = null,
    /// Custom Help functions to override the default `help()` function for all Value instances with a matching Child Type.
    /// These functions are 1st in precedence.
    child_type_help_fns: ?[]const struct{ 
        /// The Child Type this function applies to.
        ChildT: type,
        /// The custom Help Function.
        ///
        /// Function parameters:
        /// 1. ValueT (This should be the `self` parameter. As such it needs to match the Value Type the function is being called on.)
        /// 2. Writer (This is the Writer that will written to.)
        /// 3. Allocator (This does not have to be used within in the function, but must be supported in case it's needed.)
        help_fn: *const fn(anytype, anytype, mem.Allocator)anyerror!void,
    } = null,
    /// Custom Usage functions to override the default `usage()` function for all Value instances with a matching Child Type.
    /// These functions are 1st in precedence.
    child_type_usage_fns: ?[]const struct{ 
        /// The Child Type this function applies to.
        ChildT: type,
        /// The custom Usage Function.
        ///
        /// Function parameters:
        /// 1. ValueT (This should be the `self` parameter. As such it needs to match the Value Type the function is being called on.)
        /// 2. Writer (This is the Writer that will written to.)
        /// 3. Allocator (This does not have to be used within in the function, but must be supported in case it's needed.)
        usage_fn: *const fn(anytype, anytype, mem.Allocator)anyerror!void,
    } = null,

    /// Indent string used for Usage/Help formatting.
    /// Note, if this is left null, it will inherit from the Command Config. 
    indent_fmt: ?[]const u8 = null,
    /// Values Usage Format.
    /// Must support the following format types in this order:
    /// 1. String (Value Name)
    /// 2. String (Value Type)
    vals_usage_fmt: []const u8 = "\"{s} ({s})\"",
    /// Values Help Format.
    /// Must support the following format types in this order:
    /// 1. String (Value Name)
    /// 2. String (Value Type)
    /// 3. String (Value Description)
    vals_help_fmt: []const u8 = "{s} ({s}): {s}",
    
};

/// The Behavior for Setting Values with `set()`.
/// This applies to Values within Options and standalone Values.
pub const SetBehavior = enum {
    /// Keeps the First Argument this Value was `set()` to.
    First,
    /// Keeps the Last Argument this Value was `set()` to.
    Last,
    /// Keeps Multiple Arguments in this Value up to the Value's `max_args`.
    Multi,
};

/// Create a Value with a specific Type (`SetT`).
pub fn Typed(comptime SetT: type, comptime config: Config) type {
    return struct {
        /// The child Type of this Value.
        pub const ChildT = SetT;

        /// An Alias for the Child Type.
        /// This is useful for changing the type hint shown in Usage/Help messages or other Generated Docs.
        child_type_alias: ?[]const u8 = null,

        /// The Allocator for this Value's parent Command.
        /// This is set during the `init()` call of this Value's parent Command.
        ///
        /// **Internal Use.**
        _alloc: ?mem.Allocator = null,

        /// Value Group of this Value.
        /// This must line up with one of the Value Groups in the `val_groups` of the parent Command or it will be ignored.
        /// This can be Validated using `Command.Custom.ValidateConfig.check_arg_groups`.
        val_group: ?[]const u8 = null,

        /// The Parsed and Validated Argument(s) this Value has been set to.
        ///
        /// **Internal Use.**
        _set_args: [config.max_children]?ChildT = .{ null } ** config.max_children,
        /// The current Index of Raw Arguments for this Value.
        ///
        /// **Internal Use.**
        _arg_idx: u7 = 0,
        /// The Max number of Raw Arguments that can be provided.
        /// This must be between 1 to the value of `config.max_children`.
        max_args: u7 = 1,
        /// Flag to determine if this Value is at max capacity for Raw Arguments.
        ///
        /// *This should be Read-Only for library users.*
        is_maxed: bool = false,
        /// Delimiter Characters that can be used to split up Multi-Values or Multi-Options.
        /// This is only applicable if `set_behavior = .Multi`.
        arg_delims: []const u8 = config.global_arg_delims,
        /// Set Behavior for this Value.
        set_behavior: SetBehavior = config.global_set_behavior,
        /// An optional Default value for this Value.
        default_val: ?ChildT = null,
        /// Flag to determine if this Value has been Parsed and Validated.
        ///
        /// *This should be Read-Only for library users.*
        is_set: bool = false,

        /// A Parsing Function to be used in place of the normal `parse()` for Argument Parsing for this specific Value.
        /// This will be used FIRST, before `type_parse_fn` then the normal `parse()` functions are tried.
        /// Note that any error caught from this function will be returned as `error.CannotParseArgToValue`.
        parse_fn: ?*const fn([]const u8, mem.Allocator) anyerror!ChildT = null,
        /// A Validation Function to be used for Argument Validation in `set()` following Argument Parsing with `parse()`.
        valid_fn: ?*const fn(ChildT, mem.Allocator) bool = null, 
            
        /// The Name of this Value for user identification and Usage/Help messages.
        name: []const u8 = "",
        /// The Description of this Value for Usage/Help messages.
        description: []const u8 = "",

        /// Custom Parsing function for this Value Type.
        /// Check `Value.Config` for details.
        pub const child_type_parse_fn: ?*const fn([]const u8, mem.Allocator) anyerror!ChildT = typeParseFn: {
            for (config.child_type_parse_fns orelse break :typeParseFn null) |elm| {
                if (elm.ChildT == SetT) break :typeParseFn @as(*const fn([]const u8, mem.Allocator) anyerror!ChildT, @alignCast(@ptrCast(elm.parse_fn)));
            }
            else break :typeParseFn null;
        };

        /// Custom Help function for this Value Type.
        /// Check `Value.Config` for details.
        pub const child_type_help_fn: ?*const fn([]const u8, mem.Allocator) anyerror!ChildT = typeHelpFn: {
            for (config.child_type_help_fns orelse break :typeHelpFn null) |elm| {
                if (elm.ChildT == SetT) break :typeHelpFn @as(*const fn(anytype, anytype, mem.Allocator) anyerror!ChildT, @alignCast(@ptrCast(elm.help_fn)));
            }
            else break :typeHelpFn null;
        };
        /// Custom Usage function for this Value Type.
        /// Check `Value.Config` for details.
        pub const child_type_usage_fn: ?*const fn([]const u8, mem.Allocator) anyerror!ChildT = typeUsageFn: {
            for (config.child_type_usage_fns orelse break :typeUsageFn null) |elm| {
                if (elm.ChildT == SetT) break :typeUsageFn @as(*const fn(anytype, anytype, mem.Allocator) anyerror!ChildT, @alignCast(@ptrCast(elm.usage_fn)));
            }
            else break :typeUsageFn null;
        };

        /// Parse the given argument token (`arg`) to this Value's Type.
        pub fn parse(self: *const @This(), arg: []const u8) !ChildT {
            if (self.parse_fn) |parseFn| return parseFn(arg, self._alloc orelse return error.ValueNotInitialized) catch error.CannotParseArgToValue;
            if (child_type_parse_fn) |parseFn| return parseFn(arg, self._alloc orelse return error.ValueNotInitialized) catch error.CannotParseArgToValue;
            var san_arg_buf: [512]u8 = undefined;
            const san_arg = toLower(san_arg_buf[0..], arg);
            return switch (@typeInfo(ChildT)) {
                .Bool => isTrue: {
                    const true_words = [_][]const u8{ "true", "t", "yes", "y", "1" };
                    for (true_words[0..]) |word| { if (mem.eql(u8, word, san_arg)) break :isTrue true; } else break :isTrue false;
                },
                .Pointer => arg,
                .Int => parseInt(ChildT, arg, 0),
                .Float => parseFloat(ChildT, arg),
                else => error.CannotParseArgToValue,
            };
        }

        /// Set this Value if the provided argument token (`set_arg`) can be Parsed and Validated.
        pub fn set(self: *const @This(), set_arg: []const u8) !void {
            // Delimited Args
            var arg_delim: u8 = ' ';
            const check_delim: bool = checkDelim: {
                for (self.arg_delims) |delim| {
                    if (mem.indexOfScalar(u8, set_arg, delim) != null) {
                        arg_delim = delim;
                        break :checkDelim true;
                    }
                }
                break :checkDelim false;
            };
            if (self.set_behavior == .Multi and meta.activeTag(@typeInfo(ChildT)) != .Pointer and check_delim) {
                var split_args = mem.splitScalar(u8, set_arg, arg_delim);
                while (split_args.next()) |arg| try self.set(arg);
                return;
            }

            // Single Arg
            const parsed_arg = try self.parse(set_arg);
            @constCast(self).is_set =
                if (self.valid_fn) |validFn| validFn(parsed_arg, self._alloc orelse { 
                    log.err("The Value '{s}' does not have an Allocator!", .{ self.name }); 
                    return error.ValueNotInitialized; }
                )
                else true;
            if (self.is_set) {
                switch (self.set_behavior) {
                    .First => if (self._set_args[0] == null) { 
                        @constCast(self)._set_args[0] = parsed_arg;
                        @constCast(self)._arg_idx += 1;
                    },
                    .Last => {
                        @constCast(self)._set_args[0] = parsed_arg;
                        if (self._arg_idx < 1) @constCast(self)._arg_idx += 1;
                    },
                    .Multi => if (self._arg_idx < self.max_args) {
                        @constCast(self)._set_args[self._arg_idx] = parsed_arg;
                        @constCast(self)._arg_idx += 1;
                    }
                }
                @constCast(self).is_maxed = self._arg_idx == self.max_args;
            }
            else return error.InvalidValue;
        }

        /// Get the first Parsed and Validated value of this Value.
        /// This will pull the first value from `_set_args` and should be used with the `First` or `Last` Set Behaviors.
        pub fn get(self: *const @This()) !ChildT {
            return 
                if (self.is_set) self._set_args[0].?
                else if (self.default_val) |def_val| def_val
                else if (ChildT == bool) false
                else error.ValueNotSet;
        }

        /// Get All Parsed and Validated Arguments of this Value.
        /// This will pull All values from `_set_args` and should be used with `Multi` Set Behavior.
        pub fn getAll(self: *const @This(), alloc: mem.Allocator) ![]ChildT {
            if (!self.is_set) {
                if (self.default_val) |def_val| {
                    var val = try alloc.alloc(ChildT, 1);
                    val[0] = def_val;
                    return val;
                }
                else return error.ValueNotSet;
            }
            var vals = try alloc.alloc(ChildT, self._arg_idx);
            for (self._set_args[0..self._arg_idx], 0..) |arg, idx| vals[idx] = arg.?;
            return vals;
        }

        /// Initialize this Value with the provided Allocator (`alloc`).
        pub fn init(self: *const @This(), alloc: mem.Allocator) @This() {
            var val = self.*;
            val._alloc = alloc;
            return val;
        }
    };
}

/// Generic Value to handle a Value regardless of its inner Child Type. 
/// This encompasses Typed Values with Boolean, String `[]const u8`, Floats, and the Config (`config`) specified Types.
pub fn Generic(comptime config: Config) type {
    // Base Implementation
    const slim_base = config.use_slim_base or config.custom_types.len > 0;
    return if (!slim_base and !config.use_custom_bit_width_range) union(enum){
        bool: Typed(bool, config),
        
        string: Typed([]const u8, config),
        
        u1: Typed(u1, config),
        u2: Typed(u2, config),
        u3: Typed(u3, config),
        u4: Typed(u4, config),
        u8: Typed(u8, config),
        u16: Typed(u16, config),
        u32: Typed(u32, config),
        u64: Typed(u64, config),
        //u128: Typed(u128, config),
        //u256: Typed(u256, config),

        i1: Typed(i1, config),
        i2: Typed(i2, config),
        i3: Typed(i3, config),
        i4: Typed(i4, config),
        i8: Typed(i8, config),
        i16: Typed(i16, config),
        i32: Typed(i32, config),
        i64: Typed(i64, config),
        //i128: Typed(i128, config),
        //i256: Typed(i256, config),

        f16: Typed(f16, config),
        f32: Typed(f32, config),
        f64: Typed(f64, config),
        //f128: Typed(f128, config),
    }
    // Custom Implementation
    else customUnion: { 
        const base_union = union(enum){
            bool: Typed(bool, config),
            string: Typed([]const u8, config),
        };
        
        var union_info = @typeInfo(base_union).Union;
        var tag_info = @typeInfo(union_info.tag_type.?).Enum;
        tag_info.tag_type = usize;
        if (config.use_custom_bit_width_range) {
            @setEvalBranchQuota(config.max_int_bit_width * 10);
            inline for (config.min_int_bit_width..config.max_int_bit_width) |bit_width| {
                const uint_name = @typeName(meta.Int(.unsigned, bit_width));
                const uint_type = Typed(meta.Int(.unsigned, bit_width), config);
                union_info.fields = union_info.fields ++ .{ .{
                   .name = uint_name, 
                   .type = uint_type,
                   .alignment = @alignOf(uint_type),
                } };
                tag_info.fields = tag_info.fields ++ .{ .{
                    .name = uint_name,
                    .value = tag_info.fields.len
                } };

                const int_name = @typeName(meta.Int(.signed, bit_width));
                const int_type = Typed(meta.Int(.signed, bit_width), config);
                union_info.fields = union_info.fields ++ .{ .{
                   .name = int_name,
                   .type = int_type, 
                   .alignment = @alignOf(int_type),
                } };
                tag_info.fields = tag_info.fields ++ .{ .{
                    .name = int_name,
                    .value = tag_info.fields.len
                } };
            }
        }
        else {
            if (config.add_base_ints) {
                const int_union = union(enum) {
                    u1: Typed(u1, config),
                    u2: Typed(u2, config),
                    u3: Typed(u3, config),
                    u4: Typed(u4, config),
                    u8: Typed(u8, config),
                    u16: Typed(u16, config),
                    u32: Typed(u32, config),
                    u64: Typed(u64, config),
                    //u128: Typed(u128, config),
                    //u256: Typed(u256, config),

                    i1: Typed(i1, config),
                    i2: Typed(i2, config),
                    i3: Typed(i3, config),
                    i4: Typed(i4, config),
                    i8: Typed(i8, config),
                    i16: Typed(i16, config),
                    i32: Typed(i32, config),
                    i64: Typed(i64, config),
                    //i128: Typed(i128, config),
                    //i256: Typed(i256, config),
                };
                const int_info = @typeInfo(int_union).Union;
                const int_tag_info = @typeInfo(int_info.tag_type.?).Enum;

                union_info.fields = union_info.fields ++ int_info.fields;
                for (int_tag_info.fields) |tag| {
                    tag_info.fields = tag_info.fields ++ .{ .{
                        .name = tag.name,
                        .value = tag.value + 2,
                    } };
                }
            }
            if (config.add_base_floats) {
                const float_union = union(enum) {
                    f16: Typed(f16, config),
                    f32: Typed(f32, config),
                    f64: Typed(f64, config),
                    //f128: Typed(f128, config),
                };
                const float_info = @typeInfo(float_union).Union;
                const float_tag_info = @typeInfo(float_info.tag_type.?).Enum;

                const add_val = if (config.add_base_ints) 18 else 2;
                union_info.fields = union_info.fields ++ float_info.fields;
                for (float_tag_info.fields) |tag| {
                    tag_info.fields = tag_info.fields ++ .{ .{
                        .name = tag.name,
                        .value = tag.value + add_val,
                    } };
                }
            }
        }

        var adds: u16 = 0;
        for (config.custom_types) |T| {
            const AddT = addT: {
                const add_info = @typeInfo(T);
                switch (add_info) {
                    // Check for `Value.Typed`
                    .Struct => |struct_info| {
                        const base_fields = @typeInfo(@TypeOf(Typed(bool, config){})).Struct.fields;
                        if (struct_info.fields.len != base_fields.len) break :addT Typed(T, config);
                        for (struct_info.fields, base_fields) |a_field, b_field| {
                            if (!mem.eql(u8, a_field.name, b_field.name)) break :addT Typed(T, config);
                        }
                        break :addT Typed(T.ChildT, config);
                    },
                    inline else => break :addT Typed(T, config),
                }
            };
            const union_field = Type.UnionField{
               .name = @typeName(AddT.ChildT), 
               .type = AddT,
               .alignment = @alignOf(AddT),
            };
            const union_tag = Type.EnumField{
                .name = @typeName(AddT.ChildT),
                .value = tag_info.fields.len + adds,
            };
            for (union_info.fields, 0..) |field, idx| {
                if (!mem.eql(u8, field.name, union_field.name)) continue;
                adds += 1;
                union_info.fields = rebuildFields: {
                    var rebuild: [union_info.fields.len]Type.UnionField = undefined;
                    for (rebuild[0..], union_info.fields, 0..) |*r_fld, o_fld, r_idx|
                       r_fld.* = if (r_idx == idx) union_field else o_fld;
                    break :rebuildFields rebuild[0..]; // Scope lifetime issue??
                };    
                tag_info.fields = rebuildFields: {
                    var rebuild: [tag_info.fields.len]Type.EnumField = undefined;
                    for (rebuild[0..], tag_info.fields, 0..) |*r_fld, o_fld, r_idx|
                       r_fld.* = if (r_idx == idx) union_tag else o_fld;
                    break :rebuildFields rebuild[0..]; // Scope lifetime issue??
                };    
                break;
            }
            else {
                union_info.fields = union_info.fields ++ .{ union_field };
                tag_info.fields = tag_info.fields ++ .{ union_tag };
            }
            
        }

        union_info.tag_type = @Type(.{ .Enum = tag_info }); 
        break :customUnion @Type(.{ .Union = union_info });
    };
}

/// Create a Custom Value type from the provided Config (`config`).
pub fn Custom(comptime config: Config) type {
    return struct{
        /// Custom Generic Value type.
        pub const GenericT = Generic(config);

        /// Wrapped Generic Value union.
        generic: GenericT = .{ .bool = .{} },

        /// Custom Help Function.
        /// Check (`Command.Config`) for details.
        pub const global_help_fn = config.global_help_fn;
        /// Custom Usage Function.
        /// Check (`Command.Config`) for details.
        pub const global_usage_fn = config.global_usage_fn;

        /// Values Help Format.
        /// Check (`Command.Config`) for details.
        pub const vals_help_fmt = config.vals_help_fmt;
        /// Values Usage Format.
        /// Check (`Command.Config`) for details.
        pub const vals_usage_fmt = config.vals_usage_fmt;

        /// Get the Parsed and Validated Value of the inner Typed Value.
        /// Comptime Only 
        // TODO: See if this can be made Runtime
        pub inline fn get(self: *const @This()) !switch (meta.activeTag(self.*.generic)) { 
            inline else => |tag| @TypeOf(@field(self.*.generic, @tagName(tag))).ChildT, 
        } {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| try @field(self.*.generic, @tagName(tag)).get(),
            };
        }

        /// Get the Parsed and Validated value of the inner Typed Value as the specified type (`T`).
        pub fn getAs(self: *const @This(), comptime T: type) !T {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| {
                    const typed_val = @field(self.*.generic, @tagName(tag));
                    return 
                        if (@TypeOf(typed_val).ChildT == T) try typed_val.get()
                        else if (
                            @typeInfo(T) == .Enum or (
                                @typeInfo(T) == .Optional and
                                @typeInfo(@typeInfo(T).Optional.child) == .Enum
                            )
                        ) {
                            const val = try typed_val.get();
                            switch (@typeInfo(@TypeOf(val))) {
                                .Int => return @enumFromInt(val),
                                inline else => return error.RequestedTypeMismatch,
                            }
                        }
                        else error.RequestedTypeMismatch;
                },
            };
        }

        /// Set the inner Typed Value if the provided Argument (`arg`) can be Parsed and Validated.
        pub fn set(self: *const @This(), arg: []const u8) !void { 
            switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| try @field(self.*.generic, @tagName(tag)).set(arg),
            }
        }

        /// Get the inner Typed Value's Allocator.
        pub fn allocator(self: *const @This()) ?mem.Allocator {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| @field(self.*.generic, @tagName(tag))._alloc,
            };
        }

        /// Get the inner Typed Value's Group.
        pub fn valGroup(self: *const @This()) ?[]const u8 {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| @field(self.*.generic, @tagName(tag)).val_group,
            };
        }

        /// Get the inner Typed Value's Name.
        pub fn name(self: *const @This()) []const u8 {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| @field(self.*.generic, @tagName(tag)).name,
            };
        }
        /// Get the inner Typed Value's Child Type Name.
        pub fn childType(self: *const @This()) []const u8 {
            @setEvalBranchQuota(config.max_int_bit_width * 10);
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| typeName: {
                    const val = @field(self.*.generic, @tagName(tag));
                    break :typeName 
                        if (val.child_type_alias) |alias| alias
                        else @typeName(@TypeOf(val).ChildT);
                }
            };
        }
        /// Get the inner Typed Value's Description.
        pub fn description(self: *const @This()) []const u8 {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| @field(self.*.generic, @tagName(tag)).description,
            };
        }
        /// Check if the inner Typed Value is Set.
        pub fn isSet(self: *const @This()) bool {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| @field(self.*.generic, @tagName(tag)).is_set,
            };
        }
        /// Check if the inner Typed Value has a default value.
        pub fn hasDefault(self: *const @This()) bool {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| @field(self.*.generic, @tagName(tag)).default_val != null,
            };
        }
        /// Get the inner Typed Value's Argument Index.
        pub fn argIdx(self: *const @This()) u7 {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| @field(self.*.generic, @tagName(tag))._arg_idx,
            };
        }
        /// Get the inner Typed Value's Max Arguments.
        pub fn maxArgs(self: *const @This()) u7 {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| @field(self.*.generic, @tagName(tag)).max_args,
            };
        }
        /// Check if the inner Typed Value's has a custom `parse_fn`.
        pub fn hasCustomParseFn(self: *const @This()) bool {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| hasFn: {
                    const val = @field(self.*.generic, @tagName(tag));
                    break :hasFn val.parse_fn != null or @TypeOf(val).child_type_parse_fn != null;
                }
            };
        }
        /// Check if the inner Typed Value's has a custom `valid_fn`.
        pub fn hasCustomValidFn(self: *const @This()) bool {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| @field(self.*.generic, @tagName(tag)).valid_fn != null,
            };
        }
        /// Check if the inner Typed Value's has a custom `parse_fn` or `valid_fn`.
        pub fn hasCustomFn(self: *const @This()) bool {
            return self.hasCustomParseFn() or self.hasCustomValidFn();
        }

        /// Create a Custom Value with a specific Type (`T`).
        pub fn ofType(comptime T: type, comptime typed_val: Typed(T, config)) @This() {
            const active_tag = 
                if (T == []const u8) "string" 
                //else if (@typeInfo(T) == .Enum) @typeName(@typeInfo(T).Enum.tag_type)
                else @typeName(T);
            return @This(){ .generic = @unionInit(GenericT, active_tag, typed_val) };
        }

        /// Config for creating Values from Componenet Types (Function Parameters, Struct Fields, and Union Fields) using `from()`.
        pub const FromConfig = struct {
            /// Ignore Incompatible types or error during compile time.
            ignore_incompatible: bool = true,
            /// Name for the Value.
            /// If this is left blank, an attempt will be made to create a name based on the Component Type.
            val_name: ?[]const u8 = null,
            /// Description for the Value.
            val_description: ?[]const u8 = null,
        };

        /// Create a Generic Value from a Valid Componenent Param, StructField, or UnionField (`from_comp`) using the provided FromConfig (`from_config`).
        /// This is intended for use with the corresponding `from()` methods in Command and Option, which ultimately create a Command from a given Struct.
        pub fn from(comptime from_comp: anytype, from_config: FromConfig) ?@This() {
            const comp_name = 
                if (from_config.val_name) |val_name| val_name    
                else switch (@TypeOf(from_comp)) {
                    std.builtin.Type.StructField, std.builtin.Type.UnionField => from_comp.name,
                    std.builtin.Type.Fn.Param => "",
                    else => @compileError("The provided component must be a Function Parameter, Struct Field, or Union Field."), 
                };

            const FromT = switch(@TypeOf(from_comp)) {
               std.builtin.Type.StructField, std.builtin.Type.UnionField => from_comp.type,
               std.builtin.Type.Fn.Param => from_comp.type.?,
               else => unreachable,
            };
            const comp_info = @typeInfo(FromT);
            if (comp_info == .Pointer and comp_info.Pointer.child != u8) {
                if (!from_config.ignore_incompatible) @compileError(
                    "The component '" ++ 
                    if (comp_name.len > 0) comp_name else "' function parameter of type '" ++ 
                    @typeName(FromT) ++ "' is incompatible. Pointers must be of type '[]const u8'.")
                else return null;
            }
            const CompT = switch (comp_info) {
                .Optional => |optl| OptT: {
                    break :OptT switch (@typeInfo(optl.child)) {
                        .Enum => |enum_info| enum_info.tag_type,
                        inline else => optl.child,
                    };
                },
                .Array => aryType: {
                    const ary_info = @typeInfo(comp_info.Array.child);
                    if (ary_info == .Optional) break :aryType ary_info.Optional.child
                    else break :aryType comp_info.Array.child;
                },
                .Enum => |enum_info| enum_info.tag_type,
                // TODO: Check if Pointer is a String.
                .Bool, .Int, .Float, .Pointer => FromT,
                else => { 
                    if (!from_config.ignore_incompatible) @compileError("The comp '" ++ comp_name ++ "' of type '" ++ @typeName(FromT) ++ "' is incompatible.")
                    else return null;
                },
            };
            //const out_info = @typeInfo(CompT);
            return ofType(CompT, .{
                .name = comp_name,
                .description = from_config.val_description orelse "The '" ++ comp_name ++ "' Value of type '" ++ @typeName(FromT) ++ "'.",
                .max_args = 
                    if (comp_info == .Array) comp_info.Array.len
                    else 1,
                .set_behavior =
                    if (comp_info == .Array) .Multi
                    else .Last,
                // TODO: Handle default Array Elements.
                .default_val = defVal: { 
                    if (
                        utils.indexOfEql([]const u8, meta.fieldNames(@TypeOf(from_comp))[0..], "default_value") != null and 
                        from_comp.default_value != null
                    ) {
                        switch (comp_info) {
                            .Array => break :defVal null,
                            .Optional => |optl| {
                                break :defVal switch (@typeInfo(optl.child)) {
                                    .Enum => break :defVal null,
                                    inline else => break :defVal @as(*FromT, @ptrCast(@alignCast(@constCast(from_comp.default_value)))).*,
                                };
                            },
                            .Enum => break :defVal 0, 
                            inline else => break :defVal @as(*FromT, @ptrCast(@alignCast(@constCast(from_comp.default_value.?)))).*
                        }
                    }
                    else break :defVal null;
                },
                .parse_fn = pFn: {
                    switch (comp_info) {
                        .Optional => |optl| {
                            break :pFn switch (@typeInfo(optl.child)) {
                                .Enum => ParsingFns.Builder.asEnumType(optl.child),
                                inline else => null,
                            };
                        },
                        .Enum => break :pFn ParsingFns.Builder.asEnumType(FromT),
                        inline else => break :pFn null,
                    }
                },
            });
        }

        /// Format function for Values
        pub fn format(self: @This(), _: []const u8, _: fmt.FormatOptions, writer: anytype) !void {
            try writer.print("{s}", .{ @tagName(meta.activeTag(self.generic)) });
            try writer.print("{s}:  Type: {s}, Set: {any}", .{
                self.name(),
                self.childType(),
                self.isSet(),
            });
        }

        /// Creates the Help message for this Value and Writes it to the provided Writer (`writer`).
        pub fn help(self: *const @This(), writer: anytype) !void {
            switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| {
                    const val = @field(self.*.generic, @tagName(tag));
                    if (@TypeOf(val).child_type_help_fn)|helpFn| return helpFn(self, writer, self.allocator() orelse return error.ValueNotInitialized);
                }
            }
            if (global_help_fn) |helpFn| return helpFn(self, writer, self.allocator() orelse return error.ValueNotInitialized);
            try writer.print(vals_help_fmt, .{ self.name(), self.childType(), self.description() });
        }
        /// Creates the Usage message for this Value and Writes it to the provided Writer (`writer`).
        pub fn usage(self: *const @This(), writer: anytype) !void {
            switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| {
                    const val = @field(self.*.generic, @tagName(tag));
                    if (@TypeOf(val).child_type_usage_fn)|usageFn| return usageFn(self, writer, self.allocator() orelse return error.ValueNotInitialized);
                }
            }
            if (global_usage_fn) |usageFn| return usageFn(self, writer, self.allocator orelse return error.ValueNotInitialized);
            try writer.print(vals_usage_fmt, .{ self.name(), self.childType() });
        }

        /// Initialize this Value with the provided Allocator (`alloc`).
        pub fn init(self: *const @This(), alloc: mem.Allocator) @This() {
            return switch (meta.activeTag(self.*.generic)) {
                inline else => |tag| @This(){ .generic = @unionInit(GenericT, @tagName(tag), @field(self.*.generic, @tagName(tag)).init(alloc)) },
            };
        }
    };
}

/// Parsing Functions for various common requirements to be used with `parse_fn` in place of normal `parse()`.
/// Note, `parse_fn` is in no way limited to these functions.
pub const ParsingFns = struct {
    /// Builder Functions for common Parsing Functions.
    pub const Builder = struct {
        pub const BoolNoMatch = enum{
            True,
            False,
            Error,
        };
        /// Check for Alternate True Words (`true_words`) and False Words (`false_words`) when parsing the provided Argument (`arg`) to a Boolean.
        /// In the event of no match, This function will return based on (`no_match`).
        pub fn altBool(
            comptime true_words: []const []const u8,
            comptime false_words: []const []const u8,
            comptime no_match: BoolNoMatch
        ) fn([]const u8, mem.Allocator) anyerror!bool {
            return struct {
                fn boolCheck(arg: []const u8, alloc: mem.Allocator) !bool {
                    _ = alloc;
                    for (true_words[0..]) |word| { if (mem.eql(u8, word, arg)) return true; } 
                    else for (false_words[0..]) |word| { if (mem.eql(u8, word, arg)) return false; } 
                    else return switch (no_match) {
                        .True => true,
                        .False => false,
                        .Error => error.UnrecognizedBooleanValue,
                    };
                }
            }.boolCheck;
        }

        /// Parse the given Integer (`arg`) as Base (`base`). Base options:
        /// - 0: Uses the 2 character prefix to determine the base. Default is Base 10. (This is also the default parsing option for Integers.)
        /// - 2: Base 2 / Binary
        /// - 8: Base 8 / Octal
        /// - 10: Base 10 / Decimal
        /// - 16: Base 16 / Hexadecimal
        pub fn asBase(comptime NumT: type, comptime base: u8) fn([]const u8, mem.Allocator) anyerror!NumT {
            return struct { 
                fn toBase(arg: []const u8, alloc: mem.Allocator) !NumT { 
                    _ = alloc;
                    return fmt.parseInt(NumT, arg, base); 
                } 
            }.toBase;
        }

        /// Parse the given argument token (`arg`) to an Enum Tag of the provided `EnumT`.
        pub fn asEnumType(comptime EnumT: type) enumFnType: {
            const enum_info = @typeInfo(EnumT);
            if (enum_info != .Enum) @compileError("The type of `EnumT` must be Enum!");
            break :enumFnType fn([]const u8, mem.Allocator) anyerror!enum_info.Enum.tag_type;
        } {
            const EnumTagT: type = @typeInfo(EnumT).Enum.tag_type;
            return struct { 
                fn enumInt(arg: []const u8, alloc: mem.Allocator) !EnumTagT {
                    _ = alloc;
                    const enum_tag = meta.stringToEnum(EnumT, mem.trim(u8, arg, &.{ 0, ' ', '\t' })) orelse return error.EnumTagDoesNotExist;
                    return @intFromEnum(enum_tag);
                }
            }.enumInt;
        }

    };

    /// Trim all Whitespace from the beginning and end of the provided argument token (`arg`).
    pub fn trimWhitespace(arg: []const u8, alloc: mem.Allocator) anyerror![]const u8 {
        _ = alloc;
        return mem.trim(u8, arg, ascii.whitespace[0..]);
    }

    /// Return the provided argument token (`arg`) in all uppercase.
    pub fn toUpper(arg: []const u8, alloc: mem.Allocator) anyerror![]const u8 {
        const out_buf = try alloc.alloc(u8, arg.len);
        return ascii.upperString(out_buf, arg);
    }

    /// Return the provided argument token (`arg`) in all lowercase.
    pub fn toLower(arg: []const u8, alloc: mem.Allocator) anyerror![]const u8 {
        const out_buf = try alloc.alloc(u8, arg.len);
        return ascii.lowerString(out_buf, arg);
    }
};

/// Validation Functions for various common requirements to be used with `valid_fn`.
/// Note, `valid_fn` is in no way limited to these functions.
pub const ValidationFns = struct {
    /// Builder Functions for common Validation Functions.
    pub const Builder = struct {
        /// Check if the provided `NumT` (`num`) is within an inclusive or exclusive range.
        pub fn inRange(comptime NumT: type, comptime start: NumT, comptime end: NumT, comptime inclusive: bool) fn(NumT, mem.Allocator) bool {
            const num_info = @typeInfo(NumT);
            switch (num_info) {
                .Int, .Float => {},
                inline else => @compileError("The provided type '" ++ @typeName(NumT) ++ "' is not a numeric type. It must be an Integer or a Float."),
            }

            return 
                if (inclusive) struct { fn inRng(num: NumT, alloc: mem.Allocator) bool { _ = alloc; return num >= start and num <= end; } }.inRng
                else struct { fn inRng(num: NumT, alloc: mem.Allocator) bool { _ = alloc; return num > start and num < end; } }.inRng;
        }
    };

    /// Check if the provided argument token (`filepath`) is a valid filepath.
    pub fn validFilepath(filepath: []const u8, alloc: mem.Allocator) bool {
        _ = alloc;
        const test_file = fs.cwd().openFile(filepath, .{}) catch {
            log.err("The file '{s}' could not be found.", .{ filepath });
            return false;
        };
        test_file.close();
        return true;
    } 
    /// Check if the provided argument token (`num_str`) is a valid Ordinal Number.
    pub fn ordinalNum(num_str: []const u8, alloc: mem.Allocator) bool {
        _ = alloc;
        const ordinals = enum {
            first,
            second,
            third,
            fourth,
            fifth,
            sixth,
            seventh,
            eigth,
            ninth,
            tenth,
        };
        var lower_buf: [100]u8 = undefined;
        const lower_slice = toLower(lower_buf[0..], num_str);
        return meta.stringToEnum(ordinals, lower_slice) != null;
    }
};

