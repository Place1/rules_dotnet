load("@aspect_bazel_lib//lib:write_source_files.bzl", "write_source_file")
load("@bazel_skylib//lib:paths.bzl", "paths")

def write_nuget_repo(name, src, target_framework, out, tags = []):
    native.genrule(
        name = name + "_gen",
        srcs = [src],
        outs = ["nuget.bzl"],
        cmd = " ".join([
            "DOTNET_CLI_HOME=\"$$(dirname $(DOTNET_BIN))\"",
            "$(location @rules_dotnet//tools/dotnet2bazel:dotnet2bazel)",
            "repository",
            "$(location %s)" % src,
            "--name=%s" % paths.basename(name),
            "--framework=%s" % target_framework,
            "--output=$@",
        ]),
        toolchains = [
            "@rules_dotnet//dotnet:resolved_toolchain",
        ],
        tools = [
            "@rules_dotnet//tools/dotnet2bazel:dotnet2bazel",
            "@rules_dotnet//dotnet:resolved_toolchain",
        ],
        tags = ["manual", "local"],
    )

    write_source_file(
        name = name,
        in_file = ":" + name + "_gen",
        out_file = out,
        visibility = ["//visibility:public"],
        diff_test = False,
        tags = ["manual", "local"] + tags,
    )
