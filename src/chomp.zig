const std = @import("std");
const testing = std.testing;

// TODO(SeedyROM): This should probably be a struct and not a tuple???
// Only strings are the testing setup right now so WHATEVA!
/// The result of a parser combinator.
fn Result(comptime T: type) type {
    return [2]T;
}

/// Take a single value from the input.
pub fn takeOne(input: []const u8) !Result([]const u8) {
    if (input.len == 0) {
        return error.EmptyInput;
    }

    return .{ input[0..1], input[1..] };
}

/// Take a slice of values from the input while the predicate returns true.
/// If the predicate never returns true, return an error.
pub fn takeWhile(input: []const u8, comptime pred: fn (u8) bool) !Result([]const u8) {
    // Check if the input is empty.
    if (input.len == 0) {
        return error.UnexpectedEof;
    }

    // Scan the input until we find a character that doesn't match the predicate.
    var i: usize = 0;
    var found = false;
    while (i < input.len) : (i += 1) {
        // If the predicate returns false, we've found the end of the match.
        if (pred(input[i])) {
            found = true;
        } else {
            break;
        }
    }

    // If the predicate never matches we've run out of input.
    if (!found) {
        return error.UnexpectedEof;
    }

    return .{ input[0..i], input[i..] };
}

/// Skip a single value from the input.
pub fn skipOne(input: []const u8) ![]const u8 {
    if (input.len == 0) {
        return error.EmptyInput;
    }

    return input[1..];
}

/// Skip a slice of values from the input while the predicate returns true.
/// If the predicate never returns true, return an error.
pub fn skipWhile(input: []const u8, comptime pred: fn (u8) bool) ![]const u8 {
    // Check if the input is empty.
    if (input.len == 0) {
        return error.UnexpectedEof;
    }

    // Scan the input until we find a character that doesn't match the predicate.
    var i: usize = 0;
    var found = false;
    while (i < input.len) : (i += 1) {
        // If the predicate returns false, we've found the end of the match.
        if (pred(input[i])) {
            found = true;
        } else {
            break;
        }
    }

    // If the predicate never matches we've run out of input.
    if (!found) {
        return error.UnexpectedEof;
    }

    return input[i..];
}

/// Take a slice of values from the input that match the given tag.
/// If the input doesn't match the tag, return an error.
pub fn tag(input: []const u8, match: []const u8) !Result([]const u8) {
    // If the input is shorter than the match, we can't match.
    if (input.len < match.len) {
        return error.MissingTag;
    }

    // If the input doesn't match the tag, we can't match.
    if (!std.mem.eql(u8, input[0..match.len], match)) {
        return error.MissingTag;
    }

    // Otherwise, we've matched.
    return .{ input[0..match.len], input[match.len..] };
}

test "take one" {
    const input = "hello";
    const expected = "h";
    const actual, _ = try takeOne(input);
    try testing.expectEqualStrings(actual, expected);
}

test "take one empty" {
    try testing.expectError(error.EmptyInput, takeOne(""));
}

test "take while" {
    const input = "123hello";
    const expected = "123";
    const actual, const rest = try takeWhile(input, std.ascii.isDigit);
    try testing.expectEqualStrings(expected, actual);

    const expectedRest = "hello";
    try testing.expectEqualStrings(expectedRest, rest);
}

test "take while empty" {
    try testing.expectError(error.UnexpectedEof, takeWhile("", std.ascii.isDigit));
}

test "take while no match" {
    const input = "hello";
    try testing.expectError(error.UnexpectedEof, takeWhile(input, std.ascii.isDigit));
}

test "skip one" {
    const input = "hello";
    const expected = "ello";
    const actual = try skipOne(input);
    try testing.expectEqualStrings(expected, actual);
}

test "skip while" {
    const input = "123hello";
    const expected = "hello";
    const actual = try skipWhile(input, std.ascii.isDigit);
    try testing.expectEqualStrings(expected, actual);
}

test "skip while empty" {
    try testing.expectError(error.UnexpectedEof, skipWhile("", std.ascii.isDigit));
}

test "tag" {
    const input = "hello";
    const expected = "he";
    const actual, const rest = try tag(input, "he");
    try testing.expectEqualStrings(expected, actual);

    const expectedRest = "llo";
    try testing.expectEqualStrings(expectedRest, rest);
}

test "parse simple expression" {
    const input = "1337 + 420";

    const one, var rest = try takeWhile(input, std.ascii.isDigit);
    rest = try skipWhile(rest, std.ascii.isWhitespace);
    const plus, rest = try tag(rest, "+");
    rest = try skipWhile(rest, std.ascii.isWhitespace);
    const two, _ = try takeWhile(rest, std.ascii.isDigit);

    try testing.expectEqualStrings(one, "1337");
    try testing.expectEqualStrings(plus, "+");
    try testing.expectEqualStrings(two, "420");
}
