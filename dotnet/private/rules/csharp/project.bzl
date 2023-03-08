def _project_impl(ctx):
    executable = ctx.actions.declare_file(ctx.attr.name)

    ctx.actions.run(
        inputs = ctx.files.srcs,
        outputs = [executable],
        executable = "/bin/bash",
        arguments = ["-c", "echo hello > " + executable.path],
    )

    return [
        DefaultInfo(
            executable = executable,
        ),
    ]

csharp_project = rule(
    _project_impl,
    doc = "Generate a csproj file for an IDE",
    attrs = {
        "srcs": attr.label_list(
            doc = "The csharp library and binary targets for this csproj.",
        ),
    },
    executable = True,
    toolchains = ["@rules_dotnet//dotnet:toolchain_type"],
)
