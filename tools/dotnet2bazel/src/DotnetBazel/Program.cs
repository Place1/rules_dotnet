using DotnetBazel.Ide;
using DotnetBazel.Repository;
using DotnetBazel.Skaffold;
using Spectre.Console.Cli;

var app = new CommandApp();

app.Configure(options =>
{
    // #if DEBUG
    options.PropagateExceptions();
    // #endif

    options.AddCommand<RepositoryCommand>("repository");
    options.AddCommand<SkaffoldCommand>("skaffold");
    options.AddCommand<IdeCommand>("ide");
});

return await app.RunAsync(args);
