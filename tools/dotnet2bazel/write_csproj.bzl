load("@aspect_bazel_lib//lib:write_source_files.bzl", "write_source_file", "write_source_files")
load("@rules_dotnet//dotnet/private:providers.bzl", "DotnetAssemblyInfo")
load("@aspect_bazel_lib//lib:paths.bzl", "relative_file", "to_output_relative_path", "to_workspace_path")
load("@bazel_skylib//lib:paths.bzl", "paths")

DotnetReferencesInfo = provider(
    fields = {
        "project_references": "the csharp project name",
        "source_files": "cs files",
        "generated_source_files": "generated cs files",
        "references": "assembly references",
    },
)

def _dotnet_references_aspect_impl(target, ctx):
    source_files = []
    generated_source_files = []
    if hasattr(ctx.rule.attr, "srcs"):
        for src in ctx.rule.attr.srcs:
            for f in src.files.to_list():
                if f.is_source:
                    source_files.append(f)
                else:
                    generated_source_files.append(f)

    references = []
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if DotnetAssemblyInfo in dep:
                references.extend(dep[DotnetAssemblyInfo].refs)

    if hasattr(ctx.rule.attr, "private_deps"):
        for dep in ctx.rule.attr.private_deps:
            if DotnetAssemblyInfo in dep:
                references.extend(dep[DotnetAssemblyInfo].refs)
                references.extend(dep[DotnetAssemblyInfo].analyzers)

    transitive_source_files = []
    # transitive_source_files = [dep[DotnetReferencesInfo].source_files for dep in ctx.rule.attr.deps]

    transitive_generated_source_files = []
    # transitive_generated_source_files = [dep[DotnetReferencesInfo].generated_source_files for dep in ctx.rule.attr.deps]

    transitive_references = []
    # transitive_references = [dep[DotnetReferencesInfo].references for dep in ctx.rule.attr.deps]

    return [
        DotnetReferencesInfo(
            source_files = depset(source_files, transitive = transitive_source_files),
            generated_source_files = depset(generated_source_files, transitive = transitive_generated_source_files),
            references = depset(references, transitive = transitive_references),
        ),
    ]

_dotnet_references_aspect = aspect(
    implementation = _dotnet_references_aspect_impl,
    attr_aspects = ["deps"],
)

def _dotnet_references_json_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)

    workspace_path = relative_file("/", to_workspace_path(out))

    src = ctx.attr.src
    if DotnetReferencesInfo in src:
        info = src[DotnetReferencesInfo]
        ctx.actions.write(out, json.encode_indent({
            "workspace_path": workspace_path,
            "project_path": src.label.package,
            "source_files": [to_workspace_path(f) for f in info.source_files.to_list()],
            "generated_source_files": [to_output_relative_path(f) for f in info.generated_source_files.to_list()],
            "references": [to_output_relative_path(f) for f in info.references.to_list()],
        }))

    return DefaultInfo(files = depset([out]))

_dotnet_references_json = rule(
    implementation = _dotnet_references_json_impl,
    attrs = {
        "src": attr.label(aspects = [_dotnet_references_aspect]),
        "out": attr.string(),
    },
)

def write_csproj(name, src, out):
    _dotnet_references_json(
        name = name + "_sources",
        src = src,
        out = out.replace("/", "_") + "_references.json",
    )

    native.genrule(
        name = name + "_gen",
        srcs = [":" + name + "_sources"],
        outs = [out.replace("/", "_")],
        cmd = " ".join([
            "DOTNET_CLI_HOME=\"$$(dirname $(DOTNET_BIN))\"",
            "$(location @rules_dotnet//tools/dotnet2bazel:dotnet2bazel)",
            "ide",
            "--references=$(location {0})".format(":" + name + "_sources"),
            "> $@",
        ]),
        toolchains = [
            "@rules_dotnet//dotnet:resolved_toolchain",
        ],
        tools = [
            "@rules_dotnet//tools/dotnet2bazel:dotnet2bazel",
            "@rules_dotnet//dotnet:resolved_toolchain",
        ],
    )

    write_source_file(
        name = name,
        in_file = ":" + name + "_gen",
        out_file = out,
        visibility = ["//visibility:public"],
        diff_test = False,
        tags = ["generate"],
    )
