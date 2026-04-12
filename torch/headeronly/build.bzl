def define_targets(rules):
    # workaround issue where open source bazel requires $(location ...)
    # for filepaths but the buck conversion requires no $(location ...)
    # for filepaths.
    is_buck = hasattr(native, "read_config")
    template_arg = "version.h.in" if is_buck else "$(location version.h.in)"

    genrule_args = {
        "name": "version_h",
        "srcs": [
            "version.h.in",
            "//:version.txt",
        ],
        "outs": ["version.h"],
        "cmd": "$(execpath //tools/setup_helpers:gen_version_header) " +
               "--template-path " + template_arg + " " +
               "--version-path $(location //:version.txt) --output-path $@ ",
        "tools": ["//tools/setup_helpers:gen_version_header"],
    }

    # Add visibility only for Bazel, buck genrule in fbcode.bzl does not
    # support this argument
    if not is_buck:
        genrule_args["visibility"] = ["//visibility:public"]

    rules.genrule(**genrule_args)

    # Generate core/enum_tag.h from tags.yaml using the real torchgen codegen.
    # The main generate_aten rule (in //:BUILD.bazel) also produces this file
    # via headeronly_fm, but Bazel can't declare genrule outputs across package
    # boundaries.
    genrule_args = {
        "name": "enum_tag_h",
        "srcs": ["//:aten_srcs_for_headeronly"],
        "outs": ["core/enum_tag.h"],
        "cmd": "$(execpath //torchgen:gen) " +
               "--source-path aten/src/ATen " +
               "--install_dir $(RULEDIR)/__aten_unused " +
               "--headeronly-install-dir $(@D) " +
               "--generate headers",
        "tools": ["//torchgen:gen"],
    }

    if not is_buck:
        genrule_args["visibility"] = ["//visibility:public"]

    rules.genrule(**genrule_args)

    rules.cc_library(
        name = "torch_headeronly",
        hdrs = rules.glob([
            "**/*.h"
        ]) + ["version.h.in", ":enum_tag_h"],
        visibility = ["//visibility:public"],
        deps = [
            "//torch/headeronly/macros",
        ],
    )
