//!zig-autodoc-section: Introduction
//!zig-autodoc-guide: ../../README.md
//!zig-autodoc-guide: ../../LICENSE.md

const std = @import("std");

/// Structures used in the API
pub const types = @import("types.zig");

/// HTTP client related items
pub const http = @import("http.zig");
/// Gateway client related items
pub const gateway = @import("gateway.zig");
