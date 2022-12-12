# helper script for generating term fixtures
# usage: elixir src/_term_fixtures.exs -name <name> '<<"term to be evaluated">>'
{args, extra} = OptionParser.parse!(System.argv, switches: [name: :string], aliases: [n: :name])
name = args[:name] || raise("Name is required")
name = Macro.underscore(name)

[code | _] = extra
{result, _binding} = Code.eval_string(code, [], __ENV__)
IO.inspect(result, label: "Saving to term to #{name}")
File.write!(Path.join(__DIR__, "#{name}.term"), :erlang.term_to_binary(result))
IO.puts("""
const #{name} = @embedFile("term_fixtures/#{name}.term");

test "decode #{name}" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, #{name}.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, #{name});

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    std.debug.print("value={any}\\n", .{term.value});
    @panic("impl incomplete");
}
""")
