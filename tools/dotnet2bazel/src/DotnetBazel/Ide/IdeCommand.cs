using System.ComponentModel;
using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Build.Construction;
using Microsoft.Build.Evaluation;
using Microsoft.Build.Execution;
using Microsoft.Build.Locator;
using Spectre.Console.Cli;

namespace DotnetBazel.Ide;

public sealed class IdeCommandSettings : CommandSettings
{
    [CommandOption("--references")]
    [Description("Path to a JSON file containing project references.")]
    public string ReferencesJsonFile { get; init; } = null!;
}

public class IdeCommand : AsyncCommand<IdeCommandSettings>
{
    public IdeCommand()
    {
        // must be called before any msbuild APIs are used
        // and must be call from a seperate method.
        MSBuildLocator.RegisterDefaults();
    }

    public override async Task<int> ExecuteAsync(CommandContext context, IdeCommandSettings settings)
    {
        if (string.IsNullOrWhiteSpace(settings.ReferencesJsonFile))
        {
            throw new ArgumentException("--references flag is required");
        }

        using FileStream input = File.OpenRead(settings.ReferencesJsonFile);

        var references = await JsonSerializer.DeserializeAsync<ReferencesJsonFile>(input);
        if (references == null)
        {
            throw new ArgumentException("invalid references JSON file");
        }

        var refs = Enumerable.Empty<DotnetReference>()
            .Concat(references.SourceFiles
                .Select((r) => new DotnetReference()
                {
                    Type = "Compile",
                    Include = Path.GetRelativePath(references.ProjectPath, r),
                }))
            .Concat(references.GeneratedSourceFiles
                .Select((r) => new DotnetReference()
                {
                    Type = "Compile",
                    Include = Path.Combine("$(BazelOut)", r.EndsWith(".cs") ? r : Path.Combine(r, "**/*.cs")),
                }))
            .Concat(references.References
                .Where((r) => !r.StartsWith("../../../external"))
                .Select((r) => new DotnetReference()
                {
                    Type = "ProjectReference",
                    Include = Path.GetRelativePath(references.ProjectPath, Path.Combine(string.Join("/", r.Split("/").TakeWhile(folder => folder != "bazelout")), Path.GetFileNameWithoutExtension(r) + ".csproj")),
                }))
            .Concat(references.References
                .Where((r) => r.StartsWith("../../../external"))
                .Select((r) => new DotnetReference()
                {
                    Type = "Reference",
                    Include = Path.Combine("$(BazelOut)", r),
                }));

        var project = this.GenerateProject(refs);
        project.Save(Console.Out);

        return 0;
    }

    private Project GenerateProject(IEnumerable<DotnetReference> references)
    {
        var root = ProjectRootElement.Create();
        root.ToolsVersion = "";
        root.Sdk = "Microsoft.NET.Sdk";

        var project = new Project(root);

        project.SetProperty("TargetFramework", "net7.0");
        project.SetProperty("EnableDefaultItems", "false");
        project.SetProperty("NoStdLib", "true");
        project.SetProperty("NoCompilerStandardLib", "true");
        project.SetProperty("DisableImplicitFrameworkReferences", "true");
        project.SetProperty("DisableTransitiveProjectReferences", "true");
        project.SetProperty("SkipResolvePackageAssets", "true");

        // the IDE command will be executed using a bazel genrule so the
        // cwd will be execroot (from my testing this is true).
        project.SetProperty("BazelOut", Path.Combine(Directory.GetCurrentDirectory(), "bazel-out", "k8-fastbuild", "bin"));

        foreach (var reference in references)
        {
            project.AddItemFast(reference.Type, reference.Include);
        }

        return project;
    }
}

public class DotnetReference
{
    public string Type { get; set; } = null!;

    public string Include { get; set; } = null!;
}

public class ReferencesJsonFile
{
    [JsonPropertyName("workspace_path")]
    public string WorkspacePath { get; set; } = "";

    [JsonPropertyName("project_path")]
    public string ProjectPath { get; set; } = "";

    [JsonPropertyName("source_files")]
    public IEnumerable<string> SourceFiles { get; set; } = null!;

    [JsonPropertyName("generated_source_files")]
    public IEnumerable<string> GeneratedSourceFiles { get; set; } = null!;

    [JsonPropertyName("references")]
    public IEnumerable<string> References { get; set; } = null!;
}
