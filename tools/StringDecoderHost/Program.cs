using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text.Json;

var options = CliOptions.Parse(args);
if (options.AssemblyPath is null || options.DecoderType is null || options.DecoderMethod is null)
{
    Console.Error.WriteLine("Usage: StringDecoderHost --assembly <dll> --type <type> --method <method> [--guard-field <field> --guard-value <int> --search-path <dir>] --values <json-array>");
    return 2;
}

foreach (var dir in options.SearchPaths.Prepend(Path.GetDirectoryName(Path.GetFullPath(options.AssemblyPath))!).Where(Directory.Exists).Distinct(StringComparer.OrdinalIgnoreCase))
{
    options.ResolvedSearchPaths.Add(Path.GetFullPath(dir));
}

AppDomain.CurrentDomain.AssemblyResolve += (_, eventArgs) =>
{
    var name = new AssemblyName(eventArgs.Name).Name + ".dll";
    foreach (var dir in options.ResolvedSearchPaths)
    {
        var candidate = Path.Combine(dir, name);
        if (File.Exists(candidate))
        {
            return Assembly.LoadFrom(candidate);
        }
    }

    return null;
};

try
{
    var assembly = Assembly.LoadFrom(Path.GetFullPath(options.AssemblyPath));
    var type = assembly.GetType(options.DecoderType, throwOnError: true)!;
    RuntimeHelpers.RunClassConstructor(type.TypeHandle);

    if (!string.IsNullOrWhiteSpace(options.GuardField))
    {
        var field = type.GetField(options.GuardField, BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static);
        field?.SetValue(null, options.GuardValue);
    }

    var method = type.GetMethod(options.DecoderMethod, BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static);
    if (method is null)
    {
        throw new MissingMethodException(options.DecoderType, options.DecoderMethod);
    }

    var results = new List<DecodeResult>();
    foreach (var value in options.Values.Distinct())
    {
        try
        {
            var decoded = method.Invoke(null, new object[] { value }) as string;
            results.Add(new DecodeResult(value, true, decoded, null));
        }
        catch (TargetInvocationException ex)
        {
            results.Add(new DecodeResult(value, false, null, ex.InnerException?.Message ?? ex.Message));
        }
        catch (Exception ex)
        {
            results.Add(new DecodeResult(value, false, null, ex.Message));
        }
    }

    Console.WriteLine(JsonSerializer.Serialize(new HostResult(true, null, results, options.ResolvedSearchPaths), new JsonSerializerOptions { WriteIndented = false }));
    return 0;
}
catch (Exception ex)
{
    Console.WriteLine(JsonSerializer.Serialize(new HostResult(false, ex.ToString(), Array.Empty<DecodeResult>(), options.ResolvedSearchPaths)));
    return 1;
}

internal sealed record DecodeResult(int Value, bool Ok, string? Decoded, string? Error);
internal sealed record HostResult(bool Ok, string? Error, IReadOnlyList<DecodeResult> Results, IReadOnlyList<string> SearchPaths);

internal sealed class CliOptions
{
    public string? AssemblyPath { get; private set; }
    public string? DecoderType { get; private set; }
    public string? DecoderMethod { get; private set; }
    public string? GuardField { get; private set; }
    public int GuardValue { get; private set; }
    public List<string> SearchPaths { get; } = new();
    public List<string> ResolvedSearchPaths { get; } = new();
    public List<int> Values { get; } = new();

    public static CliOptions Parse(string[] args)
    {
        var options = new CliOptions();
        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            string Next()
            {
                if (i + 1 >= args.Length) throw new ArgumentException($"Missing value for {arg}");
                return args[++i];
            }

            switch (arg)
            {
                case "--assembly":
                    options.AssemblyPath = Next();
                    break;
                case "--type":
                    options.DecoderType = Next();
                    break;
                case "--method":
                    options.DecoderMethod = Next();
                    break;
                case "--guard-field":
                    options.GuardField = Next();
                    break;
                case "--guard-value":
                    options.GuardValue = int.Parse(Next());
                    break;
                case "--search-path":
                    options.SearchPaths.Add(Next());
                    break;
                case "--values":
                    var json = Next();
                    var parsed = JsonSerializer.Deserialize<int[]>(json) ?? Array.Empty<int>();
                    options.Values.AddRange(parsed);
                    break;
                default:
                    throw new ArgumentException($"Unknown argument: {arg}");
            }
        }

        return options;
    }
}
