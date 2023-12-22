var guideSections =[{"name":"","guides":[]},{"name":"Getting Started","guides":[{"name":"../docs/guides/overview.md","body":"# Overview\n\nCommands, Options, Values, Arguments. A simple yet robust command line argument parsing library for Zig.\n\nCova is based on the idea that arguments will fall into one of three Argument Types: Commands, Options, or Values. These types are assembled into a single Command struct which is then used to parse argument tokens.\n\nThis guide is a Work in Progress, but is intended to cover everything from how to install the cova libary into a project, to basic setup and many of the library's advanced features. For a more direct look at the library in action, checkout `examples/covademo.zig`, `examples/basic-app.zig`, and the tests in `src/cova.zig` where many of the examples are lifted directly from.\n"},{"name":"../docs/guides/getting_started/install.md","body":"# Install\n## Package Manager\n1. Find the latest `v#.#.#` commit [here](https://github.com/00JCIV00/cova/commits/main).\n2. Copy the full SHA for the commit.\n3. Add the dependency to `build.zig.zon`:\n```zig \n.dependencies = .{\n    .cova = .{\n        .url = \"https://github.com/00JCIV00/cova/archive/<GIT COMMIT SHA FROM STEP 2 HERE>.tar.gz\",\n    },\n},\n```\n4. Add the dependency and module to `build.zig`:\n```zig\n// Cova Dependency\nconst cova_dep = b.dependency(\"cova\", .{ .target = target });\n// Cova Module\nconst cova_mod = cova_dep.module(\"cova\");\n// Executable\nconst exe = b.addExecutable(.{\n    .name = \"cova_example\",\n    .root_source_file = .{ .path = \"src/main.zig\" },\n    .target = target,\n    .optimize = optimize,\n});\n// Add the Cova Module to the Executable\nexe.addModule(\"cova\", cova_mod);\n```\n5. Run `zig build <PROJECT BUILD STEP IF APPLICABLE>` to get the hash.\n6. Insert the hash into `build.zig.zon`:\n```bash \n.dependencies = .{\n    .cova = .{\n        .url = \"https://github.com/00JCIV00/cova/archive/<GIT COMMIT SHA FROM STEP 2 HERE>.tar.gz\",\n        .hash = \"HASH FROM STEP 5 HERE\",\n    },\n},\n```\n\n## Build the Basic-App Demo from source\n1. Use Zig v0.12 for your system. Available [here](https://ziglang.org/download/).\n2. Run the following in whichever directory you'd like to install to:\n```\ngit clone https://github.com/00JCIV00/cova.git\ncd cova\nzig build basic-app -Doptimize=ReleaseSafe\n```\n3. Try it out!\n```\ncd bin \n./basic-app help\n```\n"},{"name":"../docs/guides/getting_started/quick_setup.md","body":"# Quick Setup\n- This is a minimum working demo of Cova integrated into a project.\n\n```zig\nconst std = @import(\"std\");\nconst cova = @import(\"cova\");\nconst CommandT = cova.Command.Base();\n\npub const ProjectStruct = struct {\n    pub const SubStruct = struct {\n        sub_uint: ?u8 = 5,\n        sub_string: []const u8,\n    },\n\n    subcmd: SubStruct = .{},\n    int: ?i4 = 10,\n    flag: ?bool = false,\n    strings: [3]const []const u8 = .{ \"Three\", \"default\", \"strings.\" },\n};\n\nconst setup_cmd = CommandT.from(ProjectStruct);\n\npub fn main() !void {\n    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);\n    defer arena.deinit();\n    const alloc = arena.allocator();\n    const stdout = std.io.getStdOut().writer();\n\n    const main_cmd = try setup_cmd.init(alloc, .{});\n    defer main_cmd.deinit();\n\n    var args_iter = try cova.ArgIteratorGeneric.init(alloc);\n    defer args_iter.deinit();\n\n    cova.parseArgs(&args_iter, CommandT, &main_cmd, stdout, .{}) catch |err| switch(err) {\n        error.UsageHelpCalled,\n        else => return err,\n    }\n    try cova.utils.displayCmdInfo(CommandT, &main_cmd, alloc, stdout);\n}\n``` \n\n## Breakdown\n- Imports\n```zig\n...\n// The main cova library module. This is added via `build.zig` & `build.zig.zon` during\n// installation.\nconst cova = @import(\"cova\");\n\n// The Command Type for all Commands in this project.\nconst CommandT = cova.Command.Base();\n...\n```\n\n- A Valid Project Struct. The rules for what makes a Valid struct and how they're converted into Commands can be found in the API Documentation under `cova.Command.Custom.from()`.\n```zig\n...\n// This comptime struct is valid to be parsed into a cova Command.\npub const ProjectStruct = struct {\n    // This nested struct is also valid.\n    pub const SubStruct = struct {\n        // Optional Primitive type fields will be converted into cova Options.\n        // By default, Options will be given a long name and a short name based on the\n        // field name. (i.e. int = `-i` or `--int`)\n        sub_uint: ?u8 = 5,\n\n        // Primitive type fields will be converted into Values.\n        sub_string: []const u8,\n    },\n\n    // Struct fields will be converted into cova Commands.\n    subcmd: SubStruct = .{},\n\n    // The default values of Primitive type fields will be applied as the default value\n    // of the converted Option or Value.\n    int: ?i4 = 10,\n\n    // Optional Booleans will become cova Options that don't take a Value and are set to\n    // `true` simply by calling the Option's short or long name.\n    flag: ?bool = false,\n\n    // Arrays will be turned into Multi-Values or Multi-Options based on the array's\n    // child type.\n    strings: [3]const []const u8 = .{ \"Three\", \"default\", \"strings.\" },\n};\n...\n```\n\n- Creating the Comptime Command.\n```zig\n...\n// `from()` method will convert the above Struct into a Command.\n// This must be done at Comptime for proper Validation before Initialization to memory\n// for Runtime use.\nconst setup_cmd = CommandT.from(ProjectStruct);\n...\n```\n\n- Command Validation and Initialization to memory for Runtime Use.\n```zig\n...\npub fn main() !void {\n    ...\n\n    // The `init()` method of a Command instance will Validate the Command's\n    // Argument Types for correctness and distinct names, then it will return a\n    // memory allocated copy of the Command for argument token parsing and\n    // follow on analysis.\n    const main_cmd = try setup_cmd.init(alloc, .{});\n    defer main_cmd.deinit();\n    \n    ...\n}\n```\n\n- Set up the Argument Iterator.\n```zig\npub fn main() {\n    ...\n\n    // The ArgIteratorGeneric is used to step through argument tokens.\n    // By default (using `init()`), it will provide Zig's native, cross-platform ArgIterator\n    // with end user argument tokens. There's also cova's RawArgIterator that can be used to\n    // parse any slice of strings as argument tokens.\n    var args_iter = try cova.ArgIteratorGeneric.init(alloc);\n    defer args_iter.deinit();\n\n    ...\n}\n```\n\n- Parse argument tokens and Display the result.\n```zig\npub fn main() !void {\n    ...\n\n    // The `parseArgs()` function will parse the provided ArgIterator's (`&args_iter`)\n    // tokens into Argument Types within the provided Command (`main_cmd`).\n    try cova.parseArgs(&args_iter, CommandT, &main_cmd, stdout, .{});\n\n    // Once parsed, the provided Command will be available for analysis by the\n    // project code. Using `utils.displayCmdInfoi()` will create a neat display\n    // of the parsed Command for debugging.\n    try utils.displayCmdInfo(CommandT, &main_cmd, alloc, stdout);\n}\n```\n"}]},{"name":"Argument Types","guides":[{"name":"../docs/guides/arg_types/command.md","body":"# Command\nA Command is a container Argument Type for sub-Commands, Options, and Values. It can contain any mix of those Argument Types or none at all if it's to be used as a standalone Command (i.e. `covademo help`). \n\n## Configuring a Command Type\nBefore a Command is used within a project, a Command Type should be configured. A Command Type is used to set common-to-all properties of each Command created from it. Typically, this will cover the main Command of a project and all of its sub-Commands. The easiest way to configure a Command Type is to simply use `cova.Command.Base`() which is the default Command Type. To configure a custom Command Type, use `cova.Command.Custom`() with a `cova.Command.Config` (`config`) which provides several customizations to set up the Option Type, Value Type, Help/Usage messages, Mandatory sub-Commands/Values, and max sub Arguments. Once configured, the Command Type has access to all of the functions under `cova.Command.Custom` and any Command created from the Command Type similarly has access to all of the corresponding methods.\n\n## Setting up a Command\nCommands are meant to be set up in Comptime and used in Runtime. This means that the Command and all of its subordinate Arguments (Commands, Options, and Values) should be Comptime-known, allowing for proper Validation which provides direct feedback to the library user during compilation instead of preventable errors to the end user during Runtime. \n\nThere are two ways to set up a Command. The first is to use Zig's standard syntax for creating a struct instance and fill in the fields of the previously configured Command Type. Alternatively, if the project has a Struct, Union, or Function Type that can be represented as a Command, the `cova.Command.Custom.from`() function can be used to create the Command.\n\nAfter they're set up, Commands should be Validated and Allocated to the heap for Runtime use. This is accomplished using `cova.Command.Custom.init()`. At this point, the data within the Command should be treated as read-only by the libary user, so the library is set up to handle initialized Commands as constants (`const`).\n\n## Additional Info\nFor easy analysis, parsed Commands can be converted to valid Structs or Unions using the `cova.Command.Custom.to`() function, or called as Functions using the `cova.Command.Custom.callAs`() function. Other functions for analysis include creating a String HashMap<Name, Value/Option> for Options or Values using the respective `cova.Command.Custom.getOpts`() or `cova.Command.Custom.getVals`() methods, and using the `cova.Command.Custom.checkFlag`() method to simply check if a sub-Argument was set. Usage and Help statements for a Command can also be generated using the `cova.Command.Custom.usage`() and `cova.Command.Custom.help`() methods respectively.\n\n## Example:\n```zig\n...\npub const cova = @import(\"cova\");\npub const CommandT = cova.Command.Custom(.{ global_help_prefix = \"CovaDemo\" });\n\n// Comptime Setup\nconst setup_cmd: CommandT = .{\n    .name = \"covademo\",\n    .description = \"A demo of the Cova command line argument parser.\",\n    .sub_cmds = &.{\n        .{\n            .name = \"sub_cmd\",\n            .description = \"This is a Sub Command within the 'covademo' main Command.\",\n        },\n        command_from_elsewhere,\n        CommandT.from(SomeValidStructType),\n    }\n    .opts = { ... },\n    .vals = { ... }\n}\n\npub fn main() !void {\n    ...\n    // Runtime Use\n    const main_cmd = try setup_cmd.init(alloc);\n    defer main_cmd.deinit();\n\n    cova.parseArgs(..., main_cmd, ...);\n    utils.displayCmdInfo(CustomCommand, main_cmd, alloc, stdout);\n}\n```\n"},{"name":"../docs/guides/arg_types/option.md","body":"# Option\nAn Option is an Argument Type which wraps a Value and is typically optional. They should be used for Values that an end user is not always expected to provide. Additionally, unlike Values, they can be expected in any order since they are set by name.\n\n## Configuring an Option Type\nSimilar to Commands, an Option Type should be configured before any Options are created. Fortunately, the process is virtually the same as with Command Types and both configurations are designed to be done simultaneously. The standard way to configure an Option Type is by configuring the `cova.Command.Config.opt_config` field during Command Type configuration. This field is a `cova.Option.Config` and works effectively the same way as its Command counterpart. If the field is not configured it will be set to the default configuration. Done this way, the Option Type will be a part of the Command Type and will have access to all of the respective functions and methods within `cova.Option.Custom`().\n\n## Setting up an Option\nThe most straightforward way to set up an Option is to simply use Zig's standard syntax for filling out a struct. More specifically, Options can bet set up within the `opts` field of a Command using Anonymous Struct (or Tuple) syntax. Similarly, an Option's internal Value can also be set up this way via the Option's `val` field.\n\nAlternatively, Options will be created automatically when using `cova.Command.Custom.from`().\n\n## Additional Info\nAn Option must have a Short Name (ex: `-h`), a Long Name (ex: `--name \"Lilly\"`), or both. The prefixes for both Short and Long names are set by the library user during a normal setup. If the wrapped Value of an Option has a Boolean Type it will default to `false` and can be set to `true` using the Option without a following argument token from the end user (ex: `-t` or `--toggle`). They also provide `usage()` and `help()` methods similar to Commands.\n\n## Example:\n```zig\n// Within a Command\n...\n.opts = &.{\n    .{\n        .name = \"string_opt\",\n        .description = \"A string option.\",\n        .short_name = 's',\n        .long_name = \"string\",\n        .val = ValueT.ofType([]const u8, .{\n            .name = \"stringVal\",\n            .description = \"A string value.\",\n        }),\n    },\n    .{\n        .name = \"int_opt\",\n        .description = \"An integer option.\",\n        .short_name = 'i',\n        .long_name = \"int\",\n        .val = ValueT.ofType(i16, .{\n            .name = \"int_opt_val\",\n            .description = \"An integer option value.\",\n            .val_fn = struct{ fn valFn(int: i16) bool { return int < 666; } }.valFn\n        }),\n    },\n},\n```\n"},{"name":"../docs/guides/arg_types/value.md","body":"# Value\nA Value (also known as a Positional Argument) is an Argument Type that is expected in a specific order and should be interpreted as a specific Type. The full list of available Types can be seen in `cova.Value.Generic` and customized via `cova.Value.Custom`, but the basics are Boolean, String (`[]const u8`), Integer (`u/i##`), or Float (`f##`). A single Value can store individual or multiple instances of one of these Types. Values are also used to hold and represent the data held by an Option via the `cova.Option.Custom.val` field. As such, anything that applies to Values is also \"inherited\" by Options.\n\n## Understanding Typed vs Generic vs Custom Values\nThe base data for a Value is held within a `cova.Value.Typed` instance. However, to provide flexibility for the cova library and library users, the `cova.Value.Generic` union will wrap any `cova.Value.Typed` and provide access to several common-to-all methods. This allows Values to be handled in a generic manner in cases such as function parameters, function returns, collections, etc. However, if the actual parsed data of the Value is needed, the appropriate `cova.Value.Generic` field must be used. Field names for this union are simply the data type name with the exception of `[]const u8` which is the `.string` field.\n\nFinally, the `cova.Value.Custom` sets up and wraps `cova.Value.Generic` union. This Type is used similary to `cova.Command.Custom` and `cova.Option.Custom`. It allows common-to-all properties of Values within a project to be configured and provides easy methods for accessing properties of individual Values. \n\n## Configuring a Value Type\nThis process mirrors that of Option Types nearly one-for-one. A `cova.Value.Config` can be figured directly within the Command Type via the `cova.Command.Config.val_config` field. If not configured, the defaults will be used. A major feature of the Custom Value Type and Generic Value Union combination is the ability to set custom types for the Generic Value Union. This is accomplished via the `cova.Value.Config`, by setting the `cova.Value.Config.custom_types` field.\n\n## Setting up a Value\nSimilar to Options, Values are designed to be set up within a Command. Specifically, within a Command's `.vals` field. This can be done using a combination of Zig's Union and Anonymous Struct (Tuple) syntax or by using the `cova.Value.ofType`() function.\n\nValues can be given a Default value using the `.default_val` field as well as an alternate Parsing Function and a Validation Function using the `.parse_fn` and `.valid_fn` fields respectively. An example of how to create an anonymous function for these fields can be seen below. There are also common functions and function builders available within both `cova.Value.ParsingFns` and `cova.Value.ValidationFns`. \n\nThese functions allow for simple and powerful additions to how Values are parsed. For instance, the `true` value for Booleans can be expanded to include more words (i.e. `true = \"yes\", \"y\", \"on\"`), a numeric value can be limited to a certain range of numbers (i.e. `arg > 10 and arg <= 1000`), or an arbitrary string can be converted to something else (i.e. `\"eight\" = 8`). Moreover, since these functions all follow normal Zig syntax, they can be combined into higher level functions for more complex parsing and validation.\n\n## Additional Info \nValues will be parsed to their corresponding types which can then be retrieved using `get()` for Inidivual Values or `getAll()` for Multi-Values. \n\n## Example:\n```zig\n// Within a Command\n...\n.vals = &.{\n    Value.ofType([]const u8, .{\n        .name = \"str_val\",\n        .description = \"A string value for the command.\",\n    }),\n\t// Using Zig's union creation syntax\n    .{ .generic = .{ .u128, .{\n        .name = \"cmd_u128\",\n        .description = \"A u128 value for the command.\",\n        // Default Value\n        .default_val = 654321,\n        // Validation Function\n        .valid_fn = struct{ fn valFn(val: u128) bool { return val > 123 and val < 987654321; } }.valFn,\n    } } },\n}\n```\n\n"}]},{"name":"Parsing & Analysis","guides":[{"name":"../docs/guides/parsing_analysis/parsing.md","body":"# Parsing\nParsing is handled by the `cova.parseArgs`() function. It takes in a pointer to an ArgIterator (`args`), a Command type (`CommandT`), a pointer to an initialized Command (`cmd`), a Writer (`writer`), and a ParseConfig (`parse_config`), then parses each argument token sequentially. The results of a successful parse are stored in the provided Command (`cmd`) which can then be analyzed by the library user's project code.\n\nNotably, the `cova.parseArgs`() function can return several errorrs, most of which (especially `error.UsageHelpCalled`) can be safely ignored when using the default behavior. This is demonstrated below.\n\n## Default Setup\nFor the default setup, all that's needed is a pointer to an initialized `cova.ArgIteratorGeneric` (`&args_iter`), the project's Command Type (`CommandT`), a pointer to an initialized Command (`main_cmd`), a Writer to stdout (`stdout`), and the default `ParseConfig` (`.{}`) as shown here:\n\n```zig\nconst cova = @import(\"cova\");\n\n// Command Type\nconst CommandT = cova.Command.Custom(.{});\n\n// Comptime Setup Command\nconst setup_cmd: CommandT = .{ ... };\n\npub fn main() !void {\n    // Allocator\n    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);\n    defer arena.deinit();\n    const alloc = arena.allocator();\n\n    // Command\n    // Note, the Command Type and `setup_cmd` are created during comptime before the `main()` function.\n    const main_cmd = &(try setup_cmd.init(alloc, .{})); \n    defer main_cmd.deinit();\n\n    // Argument Iterator\n    var args_iter = try cova.ArgIteratorGeneric.init(alloc);\n    defer args_iter.deinit();\n\n    // Writer to stdout\n    const stdout = std.io.getStdOut().writer();\n\n    // Parse Function\n    cova.parseArgs(&args_iter, CommandT, main_cmd, stdout, .{}) catch |err| switch (err) {\n\t\terror.UsageHelpCalled,\n\t\telse => return err,\n\t};\n}\n```\n\n## Custom Setup\n### Choosing an ArgIterator\nThere are two implementations to choose from within `cova.ArgIteratorGeneric`: `.zig` and `.raw`.\n- `.zig`: This implementation uses a `std.process.ArgIterator`, which is the default, cross-platform ArgIterator for Zig. It should be the most common choice for normal argument token parsing since it pulls the argument string from the process and tokenizes it into iterable arguments. Setup is handled by the `.init()` method as shown above.\n- `.raw`: This implementation uses the `cova.RawArgIterator` and is intended for testing, but can also be useful parsing externally sourced argument tokens. \"Externally sourced\" meaning argument tokens that aren't provided by the process from the OS or Shell when the project application is run. It's set up as follows:\n```zig\nconst test_args: []const [:0]const u8 = &.{ \"test-cmd\", \"--string\", \"opt string 1\", \"-s\", \"opt string 2\", \"--int=1,22,333,444,555,666\", \"--flo\", \"f10.1,20.2,30.3\", \"-t\", \"val string\", \"sub-test-cmd\", \"--sub-s=sub_opt_str\", \"--sub-int\", \"21523\", \"help\" }; \nvar raw_iter = RawArgIterator{ .args = test_args };\nvar test_iter = ArgIteratorGeneric.from(raw_iter);\ntry parseArgs(&test_iter...);\n```\n\n#### Tokenization\nAs mentioned, the `std.process.ArgIterator` tokenizes its arguments automatically. However, if the `cova.RawArgIterator` is needed, then the `cova.tokenizeArgs`() function can be used to convert an argument string (`[]const u8`) into a slice of argument token strings (`[]const []const u8`). This slice can then be provided to `cova.RawArgIterator`. The `cova.TokenizeConfig` can be used to configure how the argument string is tokenized. Example:\n```zig\nvar arena = std.heap.ArenaAllocator.init(testing.allocator);\ndefer arena.deinit();\nconst alloc = arena.allocator();\nconst arg_str = \"cova struct-cmd --multi-str \\\"demo str\\\" -m 'a \\\"quoted string\\\"' -m \\\"A string using an 'apostrophe'\\\" 50\";\nconst test_args = try tokenizeArgs(arg_str, alloc, .{});\n```\n\n### Creating a Command Type and a Command\nThe specifics for this can be found under `cova.Command` in the API and [Argument Types/Command](../Argument Types/Command) in the Guides.\n\nThe basic steps are:\n1. Configure a Command Type.\n2. Create a comptime-known Command.\n3. Initialize the comptime-known Command for runtime-use.\n\n### Setting up a Writer\nThe Writer is used to output Usage/Help messages to the app user in the event of an error during parsing. The standard is to use a Writer to `stdout` or `stderr` for this as shown above. However, a Writer to a different file can also be used to avoid outputting to the app user as shown here:\n```zig\nvar arena = std.heap.ArenaAllocator.init(testing.allocator);\ndefer arena.deinit();\nconst alloc = arena.allocator();\n\nvar writer_list = std.ArrayList(u8).init(alloc);\ndefer writer_list.deinit();\nconst writer = writer_list.writer();\n```\n\n### Parsing Configuration\nThe `cova.ParseConfig` allows for several configurations pertaining to how argument tokens are parsed.\n"},{"name":"../docs/guides/parsing_analysis/analysis.md","body":"# Analysis\nOnce initialized and parsed, a Command can be analyzed. In the context of Cova, Analysis refers to dealing with the result of parsed Argument Types. This can range from simply debugging the results, to checking if an Argument Type was set, to utilizing the resulting values in a project. The Command Type has several functions and methods to make this easier, with methods for checking and matching sub-Commands being the standard starting point. Addtionally, it's possible to convert the Command into a comptime-known Struct, Union, or Function Type and use the resulting Type normally. For a more direct look, all of the sub-Arguments of a Command can also be analyzed individually.\n\n## Checking and Matching Sub Commands\nThe `cova.Command.Custom.checkSubCmd`() and `cova.Command.Custom.matchSubCmd`() methods are designed to be the starting point for analysis. The check function simply returns a Boolean value based on a check of whether or not the provided Command name (`cmd_name`) is the same as the Command's active sub-Command. The match function works similarly, but will return the active sub-Command if it's matched or `null` otherwise. Chaining these methods into conditional `if/else` statements makes iterating over and analyzing all sub-Commands of each Command simple and easy, even when done recursively.\n\nFor a detailed example of these methods in action, refer to the [Basic-App](https://github.com/00JCIV00/cova/blob/main/examples/basic_app.zig) demo under the `// - Handle Parsed Commands` comment in the `main()` function.\n\nOf note, there is also the `cova.Command.Custom.SubCommandsEnum`() method which will create an Enum of all of the sub-Commands of a given Command. Unfortunately, the Command this is called from must be comptime-known, making it cumbersome to use in all but the most basic of cases. For the time being, the check and match methods above should be preferred.\n\n## Conversions\n### To a Struct or Union\nOnce a Command has been initialized and parsed to, using the `cova.Command.Custom.to`() method will convert it into a struct or union of a comptime-known Struct or Union Type. The function takes a valid comptime-known Struct or Union Type (`ToT`) and a ToConfig (`to_config`). Details for the method, including the rules for a valid Struct or Union Type, can be found under `cova.Command.Custom.to`(). Once sucessfully created, the new struct or union can be used normally throughout the rest of the project. This process looks as follows:\n```zig\nconst DemoStruct {\n    // Valid field values\n    ...\n};\n\n...\n\npub fn main() !void {\n    ...\n    const main_cmd = ...;\n    // Parse into the initialized Command\n    ...\n\n    // Convert to struct\n    const demo_struct = main_cmd.to(DemoStruct, .{}); \n\n    // Use the struct normally\n    some_fn(demo_struct);\n}\n\n```\n\nThe `cova.Command.Custom.ToConfig` can be used to specify how the Command will be converted to a struct.\n\n### To a Function\nAlternatively, the Command can also be called as a comptime-known function using `cova.Command.Custom.callAs`(). This method takes a function (`call_fn`), an optional self parameter for the function (`fn_self`), and the return Type of the function (`ReturnT`) to call the function using the Command's Arguments as the parameters. Example:\n```zig\npub fn projectFn(some: anytype, params: []const u8) void {\n    _ = some;\n    _ = params;\n}\n\n...\n\npub fn main() !void {\n    ...\n    const main_cmd = ...;\n    // Parse into the initialized Command\n    ...\n\n    // Call as a Function\n    main_cmd.callAs(projectFn, null, void); \n}\n\n```\n\n\n## Direct Access\nTo directly access the sub-Argument of a Command the following fields and methods of `cova.Command.Custom` can be used: \n### Fields\n- `sub_cmd`: Access the sub Command of this Command if set.\n- `opts`: Access the Options of this Command if any.\n- `vals`: Access the Values of this Command if any.\n\n### Methods\n- `checkFlag()`: Check if a Command or Boolean Option/Value is set for this Command.\n- `getOpts()` / `getOptsAlloc`: Get a String Hashmap of all of the Options in this Command as `<Name, Option>`.\n- `getVals()` / `getValsAlloc`: Get a String Hashmap of all of the Values in this Command as `<Name, Value>`.\n\n### Examples\nCheck the `cova.utils.displayCmdInfo`() and `cova.utils.displayValInfo`() functions for examples of direct access.\n"}]}];