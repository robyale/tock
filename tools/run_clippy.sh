#!/usr/bin/env bash

# Licensed under the Apache License, Version 2.0 or the MIT License.
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright Tock Contributors 2023.

# Notably, this runs clippy on the workspace from which it is called. When invoked
# from the root folder, as is done in CI or by invoking `make ci-job-clippy`,
# this code is not run on the rust code in tools/, as that code is in a
# separate cargo workspace.

# We start by turning most lints off (by -A with most of the categories), then
# specifically turn on lints that make sense. We do keep `clippy::correctness`
# on.
#
# There are some lints we specifically do not want:
#
# - `clippy::if_same_then_else`: There are often good reasons to enumerate
#   different states that have the same effect.

CLIPPY_ARGS="
-A clippy::complexity
-A clippy::pedantic
-A clippy::nursery
-A clippy::style
-A clippy::perf
-A clippy::cargo
-A clippy::restriction

-A clippy::if_same_then_else

-D clippy::needless_return
-D clippy::unnecessary_mut_passed
-D clippy::empty_line_after_outer_attr
-D clippy::default_trait_access
-D clippy::map_unwrap_or
-D clippy::wildcard_imports
"

cargo clippy -- $CLIPPY_ARGS
