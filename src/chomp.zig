const std = @import("std");
const testing = std.testing;

// TODO(SeedyROM): This should probably be a struct and not a tuple???
// Only strings are the testing setup right now so WHATEVA!
/// The result of a parser combinator.
fn Result(comptime T: type) type {
    return [2]T;
}

pub fn Parser(comptime T: type) type {
    return struct {
        /// Get the position based on the initial slice and the current slice.
        /// This is used to calculate the offset of the current slice.
        pub fn getPosition(initial: T, current: T) usize {
            return @abs(@as(i64, @intCast(current.len)) - @as(i64, @intCast(initial.len)));
        }

        /// Take a single value from the input.
        pub fn takeOne(input: T) !Result(T) {
            if (input.len == 0) {
                return error.UnexpectedEndfInput;
            }

            return .{ input[0..1], input[1..] };
        }

        /// Take a slice of values from the input while the predicate returns true.
        /// If the predicate never returns true, return an error.
        pub fn takeWhile(input: T, comptime pred: fn (u8) bool) !Result(T) {
            // Check if the input is empty.
            if (input.len == 0) {
                return error.UnexpectedEndOfInput;
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
                return error.UnexpectedEndOfInput;
            }

            return .{ input[0..i], input[i..] };
        }

        /// Skip a single value from the input.
        pub fn skipOne(input: T) !T {
            if (input.len == 0) {
                return error.UnexpectedEndOfInput;
            }

            return input[1..];
        }

        /// Skip a slice of values from the input while the predicate returns true.
        /// If the predicate never returns true, return an error.
        pub fn skipWhile(input: T, comptime pred: fn (u8) bool) !T {
            // Check if the input is empty.
            if (input.len == 0) {
                return error.UnexpectedEndOfInput;
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

            // Our loop broke on the first try because we didn't match the predicate return the input.
            if (i == 0) {
                return input;
            }

            // If the predicate never matches we've run out of input.
            if (!found) {
                return error.UnexpectedEndOfInput;
            }

            return input[i..];
        }

        /// Take a slice of values from the input that match the given tag.
        /// If the input doesn't match the tag, return an error.
        pub fn tag(input: T, match: T) !Result(T) {
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
    };
}

const str = Parser([]const u8);

test "take one" {
    const input = "hello";
    const expected = "h";
    const actual, const rest = try str.takeOne(input);
    const offset = str.getPosition(input, rest);
    try testing.expectEqual(@as(usize, 1), offset);
    try testing.expectEqualStrings(actual, expected);
}

test "take one empty" {
    try testing.expectError(error.UnexpectedEndfInput, str.takeOne(""));
}

test "take while" {
    const input = "123hello";
    const expected = "123";
    const actual, const rest = try str.takeWhile(input, std.ascii.isDigit);
    const offset = str.getPosition(input, rest);
    try testing.expectEqual(@as(usize, 3), offset);
    try testing.expectEqualStrings(expected, actual);

    const expectedRest = "hello";
    try testing.expectEqualStrings(expectedRest, rest);
}

test "take while empty" {
    try testing.expectError(error.UnexpectedEndOfInput, str.takeWhile("", std.ascii.isDigit));
}

test "take while no match" {
    const input = "hello";
    try testing.expectError(error.UnexpectedEndOfInput, str.takeWhile(input, std.ascii.isDigit));
}

test "skip one" {
    const input = "hello";
    const expected = "ello";
    const actual = try str.skipOne(input);
    const offset = str.getPosition(input, actual);
    try testing.expectEqual(@as(usize, 1), offset);
    try testing.expectEqualStrings(expected, actual);
}

test "skip while" {
    const input = "123hello";
    const expected = "hello";
    const actual = try str.skipWhile(input, std.ascii.isDigit);
    const offset = str.getPosition(input, actual);
    try testing.expectEqual(@as(usize, 3), offset);
    try testing.expectEqualStrings(expected, actual);
}

test "skip while empty" {
    try testing.expectError(error.UnexpectedEndOfInput, str.skipWhile("", std.ascii.isDigit));
}

test "tag" {
    const input = "hello";
    const expected = "he";
    const actual, const rest = try str.tag(input, "he");
    const offset = str.getPosition(input, rest);
    try testing.expectEqual(@as(usize, 2), offset);
    try testing.expectEqualStrings(expected, actual);

    const expectedRest = "llo";
    try testing.expectEqualStrings(expectedRest, rest);
}

test "parse simple expression" {
    const input = "1337    +                   420";

    const lhs, var rest = try str.takeWhile(input, std.ascii.isDigit);
    rest = try str.skipWhile(rest, std.ascii.isWhitespace);
    const op, rest = try str.tag(rest, "+");
    rest = try str.skipWhile(rest, std.ascii.isWhitespace);
    const rhs, _ = try str.takeWhile(rest, std.ascii.isDigit);

    try testing.expectEqualStrings(lhs, "1337");
    try testing.expectEqualStrings(op, "+");
    try testing.expectEqualStrings(rhs, "420");
}

test "simple whitespace split tokenizer" {
    const SplitByWhiteSpace = struct {
        fn isWhitespace(c: u8) bool {
            return std.ascii.isWhitespace(c);
        }

        fn isNotWhitespace(c: u8) bool {
            return !isWhitespace(c);
        }

        pub fn tokenize(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList([]const u8) {
            var tokens = std.ArrayList([]const u8).init(allocator);
            var rest = input;
            while (rest.len > 0) {
                // Skip whitespace.
                rest = try str.skipWhile(rest, isWhitespace);
                // If we skip over the rest of the input, we're done.
                if (rest.len == 0) {
                    break;
                }
                // Take all non-whitespace.
                const token, rest = try str.takeWhile(rest, isNotWhitespace);
                // Add the token to the list.
                try tokens.append(token);
            }
            return tokens;
        }
    };

    const input = "   hello   world I     am here!   ";

    const tokens = try SplitByWhiteSpace.tokenize(testing.allocator, input);
    defer tokens.deinit();

    try testing.expectEqual(@as(usize, 5), tokens.items.len);
}
