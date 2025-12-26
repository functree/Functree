# Functree

**Functree** is a compiler learning project based on the Zig language, implementing a subset of Zig syntax.

## Installation

* Install the Zig environment; the current Zig version is 0.15.2.
* Clone or download the project locally.
* Navigate to the `Functree` root directory and generate the `Functree.exe` executable: `zig build-exe Functree.zig`

## Running, Testing, and Building
* The current behaviors implemented by `Functree.exe` include: `run`, `test`, `build-exe`, `build-lib`, `build-obj`.
* Therefore, from the `Functree` root directory, you can execute the following commands to run, test, or compile target function source files:
    `Functree run functree/app/Hello.func [-target x86_64-linux -O ReleaseSmall...]`
    `Functree test functree/app/Hello.func [-target x86_64-linux -O ReleaseSmall...]`
    `Functree build-exe functree/app/Hello.func [-target x86_64-linux -O ReleaseSmall...]`
    `Functree build-lib functree/app/Hello.func [-target x86_64-linux -O ReleaseSmall...]`
    `Functree build-obj functree/app/Hello.func [-target x86_64-linux -O ReleaseSmall...]`
* Examples:
    `zig test Functree.zig`
    `Functree test functree/app/Hello.func`
    `Functree run functree/app/Hello.func -target x86_64-windows`
    `Functree build-exe functree/app/Hello.func -target x86_64-windows -O ReleaseFast`
    `functree_app_Hello.exe`

## Specification

* Each program file is considered a **function unit** (功件), with a single, clear purpose. Source file contents are UTF-8 encoded.
* All **function unit file names** start with an uppercase letter (**TitleCase**), have the `.func` extension, e.g., `Hello.func`. **Function unit files** are organized under the `functree` root directory, with subdirectory names in lowercase.
* Identifiers in programs should be longer than 5 characters, and preferably no less than 3 characters.
* Function names within **function unit files** start with a lowercase letter (**camelCase**), e.g., `fn getName() str {}`. Names of constants, variables, and parameters are entirely lowercase, separated by underscores `_` (**snake_case**), e.g., `const func_name: str = "abc";`.
* When declaring aggregate types like `enum`, `error`, `struct`, `union`, their names start with an uppercase letter (**TitleCase**), e.g., `const UserType = enum {...};`.

## First Program (Hello World)

 `First function unit source file functree/app/Hello.func:`
 ```
const Console = import("functree/app/Console.func");

pub fn main() void {
    Console.print("Hello, world!\n");
}
 ```

 `Shell commands:`
 ```
$ ./Functree build-exe functree/app/Hello.func
$ ./functree_app_Hello
Hello, world!
 ```

## Syntax Guide
#### 1. Comments

Line comments start with `//` and extend to the end of the line, e.g., `//print("Hello?");`
 ```
const Console = import("functree/app/Console.func");
const print = Console.print;
pub fn main() void {
    //print("Hello?");
    print("Hello, world!\n");
}
 ```

Documentation comment lines start with `///`, e.g., `///Program entry point`
 ```
const Console = import("functree/app/Console.func");
const print = Console.print;
///Program entry point
pub fn main() void {
    //print("Hello?");
    print("Hello, world!\n");
}
 ```

Whole-file comments start with `//!`. File comment lines must be placed at the very beginning of the file, e.g., `//!File description`
 ```
//!File description
const Console = import("functree/app/Console.func");
const print = Console.print;
///Program entry point
pub fn main() void {
    //print("Hello?");
    print("Hello, world!\n");
}
 ```

#### 2. Basic Types

**Integer, Float, and Boolean** types:

| Type | Description |
| --- | --- |
| i8 | Signed 8-bit integer: `const int: i8 = -127;` |
| u8 | Unsigned 8-bit integer, 8-bit length, equivalent to `unsigned char` in C: `const int: u8 = 255;` |
| i16 | Signed 16-bit integer: `const int: i16 = -32767;` |
| u16 | Unsigned 16-bit integer: `const int: u16 = 65535;` |
| i32 | Signed 32-bit integer: `const int: i32 = -2_147_483_647;` |
| u32 | Unsigned 32-bit integer: `const int: u32 = 4_294_967_295;` |
| i64 | Signed 64-bit integer: `const int: i64 = -9_223_372_036_854_775_807;` |
| u64 | Unsigned 64-bit integer: `const int: u64 = 18_446_744_073_709_551_615;` |
| i128 | Signed 128-bit integer: `const int: i128 = -17_014_118_346_046_923_1731_687_303_715_884_105_727;` |
| u128 | Unsigned 128-bit integer: `const int: u128 = 340_282_366_920_938_463_463_374_607_431_768_211_455;` |
| isize | Target-platform dependent signed integer type: `const int: isize = -127;` |
| usize | Target-platform dependent unsigned integer type: `const int: usize = 66;` |
| f16 | 16-bit floating-point number (10-bit mantissa): `const float: f16 = -1.2 + 1.0;` |
| f32 | 32-bit floating-point number (23-bit mantissa): `const float: f32 = 7.0 / 3.0;` |
| f64 | 64-bit floating-point number (52-bit mantissa): `const float: f64 = -1.2;` |
| f80 | 80-bit floating-point number (64-bit mantissa): `const float: f80 = -1.2;` |
| f128 | 128-bit floating-point number (112-bit mantissa): `const float: f128 = -1.2;` |
| bool | Has only two values, `true` or `false`: `const flag: bool = false;` |
| void | Zero-bit type: `fn main() void {}` |
| type | Type of compile-time known type values: `fn get(T: type) T {}` |
| anyerror | Type of any error code: `var number_or_error: anyerror!i32 = error.ArgNotFound;`, `fn clone() anyerror!u8 {}` |
| comptime_int | Type of compile-time known integer literals: `const int = 65;` or `const int: comptime_int = 65;`. A single character surrounded by single quotes has type `comptime_int` and its value is the Unicode code point: `const char = 'A';` or `const char = '中';` |
| comptime_float | Type of compile-time known floating-point literals: `const float = 1.2;` or `const float: comptime_float = 1.2;` |

Primitive Values:

| Name | Description |
| --- | --- |
| true or false | Boolean values |
| null | Null value for optional types: `var optional_value: ?[]const u8 = null` |
| undefined | Undefined initial value for variables: `var count: u8 = undefined;` |

Escape Sequences:

| Name | Code Point | Description |
| --- | --- | --- |
| \t | 09 | Horizontal tab: `const string = "\tHello World!";` |
| \n | 10 | Line feed: `const string = "Hello World!\n";` |
| \r | 13 | Carriage return: `const char = '\r';` |
| \\" | 34 | Double quote |
| \\' | 39 | Single quote |
| \\\ | 92 | Backslash |
| \xNN | | 8-bit byte value (2 hex digits): `const char = '\x41'; // 'A'` or `const string = "h\x65llo"; // "hello"` or `const string = "\xf0\x9f\x92\xaf"; // "💯"` |
| \u{NNNNNN} | | Unicode code point value (1 or more hex digits): `const char = '\u{4e2d}'; // '中'` |

#### 3. Array Type and String

**Single-dimensional array** syntax: `[N]T`. Indexing: `array[i]`. The length of an **array** is known at compile time, accessible via `array.len`:
 ```
var array: [2]u8 = [10,20];
_ = array[0];  // array[0] = 10
array[1] += 5; // array[1] = 25
_ = array.len; // length of array = 2
 ```
**Multi-dimensional array** syntax: `[N][M]T`. Indexing: `array[i][j]`:
 ```
var array: [2][2]u8 = [[1,2], [10,20]];
_ = array.len; // length of array = 2
_ = array[1]; // array[1] = [10,20], its type is [2]u8
_ = array[1].len; // length of array[1] = 2
_ = array[1][0];  // array[1][0] = 10
array[1][1] += 5; // array[1][1] = 25
 ```
An **array** approximates a **single-item pointer** to an array, supporting:
  - Indexing: `array_ptr[i]`;
  - Slicing: `array_ptr[start..end]`;
  - Getting length: `array_ptr.len`;
  - Pointer subtraction: `array_ptr - array_ptr`.

A **slice** is a local **slice** of some range of an **array**, or can also be a **slice** of a **slice**. The length of a **slice** can be specified at runtime. Use the `start..end` indexing syntax on **arrays or slices** to define the slice range:
 ```
var array: [3]i32 = [1, 2, 3]; // array type is [3]i32

var known_at_runtime_one: usize = 1;
_ = &known_at_runtime_one;
// Array length is 3, slice range is [1..3) (left-inclusive, right-exclusive), slice length is 2
const slice = array[known_at_runtime_one..array.len]; // slice type is *const [2]i32
_ = slice[0];  // slice[0] = array[1] = 2
slice[1] += 5; // slice[1] = array[2] = 8
_ = slice.len; // slice length = 2
 ```
You can also use the `&` operator to take the address of an **array** to create a **slice**:
 ```
const array: [3]i32 = [1, 2, 3]; // array type is [3]i32
const slice = &array; // slice type is *const [3]i32
_ = slice.len; // slice length = 3

// You can also directly declare a slice
const slice2: []i32 = &[ 1, 2, 3]; // slice2 type is *const [3]i32
_ = slice2.len; // slice2 length = 3
 ```
A **slice** approximates a **many-item pointer** with a length, supporting:
  - Indexing: slice[i];
  - Slicing: slice[start..end];
  - Getting length: slice.len.

A **string** can be considered as a constant array **slice** with element type `u8`: `[]const u8`. Can be aliased as `str`:
 ```
const string1 = "hello ";
const string2: str = ['w', 'o', 'r', 'l', 'd'];
const string3: []const u8 = "!";
const string = string1 ++ string2 ++ string3; // string="hello world!"
 ```
**Multiline strings** are text surrounded by three quotes `'''`:
 ```
const text = '''
    #include <stdio.h>

    int main(int argc, char **argv) {
        printf("hello world\n");
        return 0;
    }
''';
 ```

#### 4. Pointer
**Single-item pointers** point to a single variable. Syntax: `*T`. Dereferencing to access pointed-to content: `ptr.*`. Taking address of variable: `&x`:
 ```
test "address of syntax" {
    // Get address of constant. Constant value is read-only, cannot be changed.
    const x: i32 = 1234;
    const x_ptr = &x; // x_ptr type is *const i32
    // Get constant value pointed to by pointer
    if (x_ptr.* == 1234) {
        expr;
    }

    // To change variable value, need address of mutable var variable
    var y: i32 = 5678;
    const y_ptr = &y; // y_ptr type is *i32
    y_ptr.* += 1; // Increment value pointed to by y_ptr
    // Get variable value pointed to by pointer
    if (y_ptr.* == 5679) {
        expr;
    }
}

test "pointer array access" {
    var array: [10]u8 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    // Pointer to an element of an array is also a single-item pointer
    const ptr = &array[2]; // ptr type is *u8

    // Change value of array[2]
    ptr.* += 1; // array[2] = 4
}
 ```
**Single-item pointers** support:
  - Dereference: `ptr.*`, can read/write variable value;
  - Slice: `ptr[0..1]`;
  - Pointer subtraction: `ptr - ptr`.

**Many-item pointers** point to an unknown number of elements. Syntax: `[*]T`. Accessing an element: `ptr[i]`:
 ```
test "pointer arithmetic with many-item pointer" {
    const array: [4]i32 = [1, 6, 3, 4];
    var ptr: [*]const i32 = &array;
    // Here ptr[0] = 1
    ptr += 1; // Pointer points to second element
    // Here ptr[0] = 6

    // Many-item pointer slice without end value: ptr[start..] == ptr + start
    if (ptr[1..] == ptr + 1) {
        expr;
    }
}
 ```
**Many-item pointers** support:
  - Pointer indexing: `ptr[i]`;
  - Slicing: `ptr[start..end] and ptr[start..]`;
  - Pointer-integer arithmetic: `ptr + int`, `ptr - int`;
  - Pointer subtraction: `ptr - ptr`.

You can convert a **single-item pointer** to a **many-item pointer** via:
 ```
test "slice syntax" {
    var x: i32 = 1234;
    const x_ptr = &x;

    // Convert single-item pointer to single-item pointer to array via slicing
    const x_array_ptr = x_ptr[0..1]; // x_array_ptr type is *[1]i32

    // Coerce single-item pointer to array to a many-item pointer:
    const x_many_ptr: [*]i32 = x_array_ptr; // x_many_ptr type is [*]i32
}
 ```

#### 5. Struct
**Struct** is an **aggregate type** that can carry multiple fields. Built-in functions are not currently supported.
Syntax: `struct {field_name1: type1, field_name2: type2, ...}`. Use dot operator to access fields:
 ```
// Declare a struct. Note: struct name must start with uppercase letter.
const Point = struct {
    x: f32,
    y: f32,
};

// Declare a struct instance. Note: constant/variable names are all lowercase, may use underscore _.
const point: Point = .{
    .x = 0.12,
    .y = 0.34,
};

_ = point.x;

// Can set default values when declaring struct.
const Point2 = struct {
    x: f32 = 0.12,
    y: f32,
};

// When declaring a struct instance, initial values can be undefined.
const point2: Point2 = .{
    .y = undefined,
};
 ```

#### 6. Tuple
A struct without specified field names is a **tuple**. Built-in functions are not currently supported.
Syntax: `struct {type1, type2, ...}`. Like arrays, use square brackets to access elements, use `.len` to get element count:
```
// Declare a tuple. Note: tuple name must start with uppercase letter.
const Point = struct {
    f32,
    f32,
};

// Declare a tuple instance. Note: constant/variable names are all lowercase, may use underscore _.
const point: Point = .{
    0.12,
    0.34,
};

_ = point[0]; // 0.12
_ = point.len; // 2

// Can also directly declare an anonymous tuple instance.
const point2 = .{
    0.12,
    0.34,
};
// Anonymous tuple as function return value
fn divmod(numerator: u32, denominator: u32) struct { u32, u32 } {
    return .{ numerator / denominator, numerator % denominator };
}
const div, const mod = divmod(10, 3);
_ = div; // Here div = 3
_ = mod; // Here mod = 1
 ```

#### 7. Enum
**Enum** is an **aggregate type** with multiple predefined values. Built-in functions are not currently supported.
Syntax: `enum {value1, value2, ...}`. Use dot operator to access elements:
 ```
// Declare an enum. Note: enum name must start with uppercase letter.
const Result = enum {ok, not_ok};

// Declare enum instance constants. Note: constant/variable names are all lowercase, may use underscore _.
const result_ok = Result.ok;
const result_not_ok: Result = .not_ok;

// When declaring an enum type, can specify the data type for enum elements.
const Value = enum(u2) {
    zero,
    one,
    two,
};
_ = Value.zero; // 0
_ = Value.one; // 1
_ = Value.two; // 2

// When declaring an enum type, can specify default values for enum elements.
const Value2 = enum(u32) {
    hundred = 100,
    thousand = 1000,
    million = 1000000,
};
_ = Value2.hundred; // 100
_ = Value2.thousand; // 1000
_ = Value2.million; // 1000000
 ```

#### 8. Union
**Union** is similar to `struct`, can define multiple fields, but only one field value is valid at a time. Built-in functions are not currently supported.
Syntax: `union {field_name1: type1, field_name2: type2, ...}`. Use dot operator to access fields:
 ```
// Declare a union. Note: union name must start with uppercase letter.
const Payload = union {
    int: i64,
    float: f64,
    boolean: bool,
};

test "simple union" {
    // Declare a union variable. Note: constant/variable names are all lowercase, may use underscore _.
    var payload = Payload{ .int = 1234 };
    try expect(payload.int == 1234);
    // Reassigning union variable requires full union initializer.
    payload = Payload{ .float = 12.34 };
    try expect(payload.float == 12.34);
}
 ```
To use a `switch` statement with a `union`, an `enum` tag is needed:
 ```
// Declare an enum tag.
const ResultTypeTag = enum {
    ok,
    not_ok,
};
// Declare a union using the enum tag.
const ResultType = union(ResultTypeTag) {
    ok: u8,
    not_ok: void,
};

test "switch on tagged union" {
    const result = ResultType{ .ok = 42 };

    switch (result) {
        .ok => try expect(result.ok == 42),
        .not_ok => unreachable,
    }
}
 ```

#### 9. Variable and Assignment
Variables defined with `const` are actually constants; their values cannot be modified. Variables defined with `var` must be modified or referenced after definition.
Variables must have a type; typeless variables do not exist. Definition syntax: `const name: type = v;` or `var name: type = v;`. Type and variable name separated by colon `:`:
 ```
pub fn main() void {
    var y: i32 = 5678;
    y += 1;
}
 ```
When defining variables, prefer `const` where possible, as it reduces bugs and aids optimization/maintenance. If a `const` variable is given an initial value at declaration, it is **compile-time known**.
Variables must be used after definition. Use `_ = name;` to ignore a variable's use; similarly, `_ = expr;` can ignore the result of expression expr.
 ```
pub fn main() void {
    const x: i32 = 1;
    _ = x;
}
 ```
Constants must be initialized at definition; otherwise, compilation error. When the type can be inferred from the initializer, it can be omitted:
 ```
pub fn main() void {
    const count = 1; // count type is comptime_int
    _ = count;
    const tuple = .{1, 2, 3}; // tuple type is comptime_int tuple
    _ = tuple;
}
 ```
If defining a variable without an initial value, intending to assign later, must set variable value to `undefined`:
 ```
pub fn main() void {
    var x: i32 = undefined;
    x = 3;
}
 ```

Scope refers to the valid usage region of an **identifier** (including ordinary variables, type definitions, function definitions, etc.) during program execution.
Typically, the full **lifetime** of a variable includes definition, use, and invalidation. When an **identifier** leaves its **scope**, it becomes invalid and unusable. Within a **scope**, duplicate **identifiers** are not allowed.

**Local variables** are variables whose lifetime is only effective within the current function or block:
 ```
test "local var" {
    var i: i32 = 5;
    {
        var j: i32 = 10;
        // Both i and j are valid here.
    }
    i = j; // Error: use of undeclared identifier 'j'
}
 ```
Local variables can be defined within a `comptime` block or modified with the `comptime` keyword. Such a variable's value is **compile-time known**, and all reads/writes happen at **compile time**, not **runtime**:
 ```
test "comptime var" {
    comptime var y: i32 = 1;
    y += 1; // Executed at compile time.
    if (y != 2) { // Evaluated at compile time.
        expr; // Executed at compile time.
    }
}
 ```
All variables defined within a `comptime` block are `comptime` variables:
 ```
test "comptime pointers" {
    comptime {
        var x: i32 = 1;
        const ptr = &x;
        ptr.* += 1;
        x += 1;
    }
}
 ```

**Static local variables** refer to **aggregate type** variables (struct, enum, etc.) declared within a function or block scope. **Static local variables** have static lifetime, but their scope is **function scope** or **block scope**:
 ```
test "static local variable" {
    foo(); // S.x = 1235
    foo(); // S.x = 1236
    foo1(); // x = 1235
    foo1(); // x = 1235
}
fn foo() i32 {
    const S = struct{ // S is a static local variable.
        var x: i32 = 1234;
    };
    S.x += 1;
    return S.x;
}
fn foo1() i32 {
    var x: i32 = 1234;
    x += 1;
    return x;
}
 ```

**Container-level variables** are variables declared at the top level of a **function unit file** (which is also a container). They have static lifetime, and their scope is **function unit scope**. If a **container-level variable** is initialized at declaration, its value is **compile-time known**; otherwise, it's **runtime known**:
 ```
var y: i32 = add(10, x);
const x: i32 = add(12, 34);

test "container level variables" {
    try expect(x == 46);
    try expect(y == 56);
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}
 ```
**Container-level variables** can also be declared inside **aggregate types** (struct, enum, etc.) at the top level of a **function unit file**. They have static lifetime, and their scope is **function unit scope**:
 ```
test "container level variable" {
    foo(); // S.x = 1235
    foo(); // S.x = 1236;
}

const S = struct {
    var x: i32 = 1234; // x is compile-time known, belongs to file-level scope where S is defined.
};

fn foo() i32 {
    S.x += 1;
    return S.x;
}
 ```

**Global variables** are variables declared at the top level of a **function unit file** and defined with the `pub` modifier. They have global static lifetime and can be used in other **function unit files** that import this file:
Function unit file `functree/system/Config.func`:
 ```
pub const j = i + 3;
const i: i32 = 1;
pub fn getName() void {}
 ```
Function unit file `functree/app/Hello.func` importing `functree/system/Config.func`:
 ```
const Config = import("functree/system/Config.func"); // Import other function unit.
test "global var"{
    _ = Config.j; // Config.j = 4
    Config.getName();
}
 ```

#### 10. Operators
Operator list:

| Name | Symbol | Applicable Types | Notes | Example |
| --- | --- | --- | --- | --- |
| Add | `x + y` or `x += y` | Integers, floats | Watch for overflow with integers | `5 + 2 == 7` |
| Subtract | `x - y` or `x -= y` | Integers, floats | Watch for overflow with integers | `2 - 5 == -3` |
| Negation | `-x` | Integers, floats | Watch for overflow with integers | `-1 == 0 - 1` |
| Multiply | `x * y` or `x *= y` | Integers, floats | Watch for overflow with integers | `2 * 5 == 10` |
| Divide | `x / y` or `x /= y` | Integers, floats | Watch for overflow and division by zero | `10 / 5 == 2` |
| Modulo | `x % y` or `x %= y` | Integers, floats | Watch for division by zero for both ints and floats | `10 % 3 == 1` |
| Left Shift | `x << y` | Integers | b must be **compile-time known** | `0b1 << 8 == 0b100000000` |
| Right Shift | `x >> y` | Integers | b must be **compile-time known** | `0b1010 >> 1 == 0b101` |
| Bitwise AND | `x & y` | Integers | | `0b011 & 0b101 == 0b001` |
| Bitwise OR | `x \| y` | Integers | | `0b010 \| 0b100 == 0b110` |
| Bitwise XOR | `x ^ y` | Integers | | `0b011 ^ 0b101 == 0b110` |
| Bitwise NOT | `~x` | Integers | | |
| Optional Unwrap | `x.?` | Optional types | Watch for overflow with integers | `const value: ?u32 = 5678; // value.? == 5678` |
| Error Catch | `x catch y` or `x catch \|err\| y` | Error union types | | `const value: anyerror!u32 = error.Broken;const unwrapped = value catch 1234; // unwrapped == 1234` |
| Logical AND | `x and y` | Boolean | | `(false and true) == false` |
| Logical OR | `x or y` | Boolean | | `(false or true) == true` |
| Logical NOT | `!x` | Boolean | | `!false == true` |
| Equal | `x == y` | Integers, floats, Boolean | | `(1 == 1) == true` |
| Null Check | `x == null` | Optional types | | `const value: ?u32 = null; // (value == null) == true` |
| Not Equal | `x != y` | Integers, floats, Boolean | | `(1 != 1) == false` |
| Not Null Check | `x != null` | Optional types | | `const value: ?u32 = null; // (value != null) == false` |
| Greater Than | `x > y` | Integers, floats | | `(2 > 1) == true` |
| Greater Than or Equal | `x >= y` | Integers, floats | | `(2 >= 1) == true` |
| Less Than | `x < y` | Integers, floats | | `(1 < 2) == true` |
| Less Than or Equal | `x <= y` | Integers, floats | | `(1 <= 2) == true` |
| Array Concatenation | `x ++ y` | Arrays | Length of all arrays must be ==compile-time== known | `const array1 = [1,2];const array2 = [3,4];const together = array1 ++ array2; // together=[1,2,3,4]` |
| Array Repeat | `x ** y` | Arrays | Length of array a and value of number b must be **compile-time** known | `const pattern = "ab" ** 3; // pattern="ababab"` |
| Pointer Dereference | `x.*` | Pointers | | `const x: u32 = 1234;const ptr = &x; // ptr.* == 1234` |
| Address Of | `&x` | All types | | `const x: u32 = 1234;const ptr = &x; // ptr.* == 1234` |
| Error Set Merge | `x \|\| y` | Error set types | Merge error sets | `const A = error{One};const B = error{Two}; // (A \|\| B) == error{One, Two}` |

Operator precedence:
 ```
1  x() x[] x.y x.* x.?
2  x!y
3  x{}
4  !x -x ~x &x ?x
5  * / % ** ||
6  + - ++
7  << >>
8  & ^ | catch
9  == != < > <= >=
10 and
11 or
12 = *= /= %= += -=
 ```

#### 11. Block
A syntactic unit consisting of zero or more statements enclosed by **{ }** is called a statement block. Blocks are used to limit the **scope** of declared variables. Variables declared inside a block cannot be used outside. The following test fails:
 ```
test "access variable after block scope" {
    {
        var x: i32 = 1;
        _ = &x;
    }
    x += 1; // Error: use of undeclared identifier 'x'
}
 ```
Variables declared outside a block can be used inside the block. The following test passes:
 ```
test "access variable in block scope" {
    var x: i32 = 1;
    {
        x += 1; // Here x = 2
    }
}
 ```

An empty block equals **void{}**, performing no operation:
 ```
const block = {};
_ = block; // block type is void{}
 ```

A block wrapped with `comptime { }` is a **compile-time execution** block:
 ```
fn expect(ok: bool) !void {
    if (!ok) return error.TestUnexpectedResult;
}

test "comptime pointers" {
    comptime {
        var x: i32 = 1;
        const ptr = &x;
        ptr.* += 1;
        x += 1;
        try expect(ptr.* == 3);
    }
}
 ```

#### 12. if Control Statement
The `if` control statement executes different program branches based on whether a condition is true:
 ```
test "if boolean" {
    const x: u32 = 5;
    const y: u32 = 4;
    if (x != y) {
        expr1;
    } else if (x == 9) {
        expr2;
    } else {
        expr3;
    }
}
 ```
`if` can also be an expression returning a value:
 ```
test "if expression" {
    const x: u32 = 5;
    const y: u32 = 4;
    const result = if (x != y) 1 else 2;
    _ = result; // Here result = 1
}
 ```

#### 13. switch Branch Statement
The `switch` branch selection statement is often used to handle **enumeration type** variables:
 ```
const Color = enum {
    auto,
    off,
    on,
};
test "switch enum" {
    const color = Color.off;

    // Need to handle all known enum elements
    switch (color) {
        .auto, .off => {},
        .on => {},
    }

    // Otherwise, need an else branch to handle other enum elements
    switch (color) {
        .on => {},
        else => {},
    }
}
 ```

`switch` with integer branches:
 ```
test "switch integer" {
    const x: u64 = 10;

    switch (x) {
        1, 2, 3 => {},
        5...100 => {},
        // Need else branch to handle other integers
        else => {},
    };
}
 ```

#### 14. while Loop Statement
The `while` loop statement repeats a block of code until the condition is no longer true:
 ```
test "while basic" {
    var i: usize = 0;
    while (i < 10) {
        i += 1;
    }
    // Here i = 10
}
 ```
Use `break` to exit the loop early when certain conditions are met:
 ```
test "while break" {
    var i: usize = 0;
    while (true) {
        if (i == 10)
            break;
        i += 1;
    }
    // Here i = 10
}
 ```
Similarly, use `continue` to skip remaining statements and return to the start of the loop when certain conditions are met:
 ```
test "while continue" {
    var i: usize = 0;
    while (true) {
        i += 1;
        if (i < 10)
            continue;
        break;
    }
    // Here i = 10
}
 ```
A **while** loop can use an **optional type variable** as the condition, exiting only when it is `null`:
 ```
test "while null capture" {
    var sum1: u32 = 0;
    numbers_left = 3;
    // while (value in eventuallyNullSequence()) {
    while (eventuallyNullSequence()) |value| {
        sum1 += value;
    }
    // Here sum1 = 3
}
var numbers_left: u32 = undefined;
fn eventuallyNullSequence() ?u32 {
    numbers_left -= 1;
    return if (numbers_left == 0) null else numbers_left;
}
 ```

#### 15. for Loop Statement
The `for` loop statement iterates over collections like arrays and slices until traversal is complete:
 ```
test "for basics" {
    const items: [5]i32 = [1, 2, 3, 0, 5];
    var sum: i32 = 0;

    // Iterate array, each element captured in variable value
    // for (value in items) {
    for (items) |value| {
        // Supports break and continue
        if (value == 0) {
            continue;
        }
        sum += value;
    }
    // Here sum = 11

    // Iterate slice, slice range [0, 1), i.e., only element: 1
    for (items[0..1]) |value| {
        sum += value;
    }
    // Here sum = 12;

    // During iteration, can take array index as second condition, capturing index value into second variable index
    for (items, 0..) |_, index| {
        _ = index; // index values 0 to 4
    }

    // Can also iterate over an integer range
    var sum2: usize = 0;
    for (0..5) |i| {
        sum2 += i; // i values 0 to 4
    }
    // Here sum2 = 10;
}
 ```

#### 16. defer Statement
If a **function** or **code block** contains a `defer` statement, it executes when control flow leaves the current scope, regardless of its position within the scope:
 ```
fn deferExample() !usize {
    var x: usize = 1;

    {
        defer x = 2;
        x = 1;
    }
    // Before leaving, execute defer x = 2, so here x = 2

    x = 5;
    return x; // Return value = 5
}
 ```
Multiple `defer` statements in the same scope execute in reverse order of definition: last defined, first executed.
 ```
fn deferUnwind() void{
    defer {
        print("defer1");
    }
    defer {
        print("defer2");
    }
    if (false) {
        defer {
            print("defer3"); // defer3 inside unreachable block does not run.
        }
    }
}
pub fn main() void{
    deferUnwind(); // Execution order: defer2 defer1
}
 ```
A `defer` block cannot contain a **return** statement, otherwise compilation error:
 ```
fn deferInvalidExample() !void {
    defer {
        return error.DeferError; // Error: cannot return from defer expression
    }

    return error.DeferError;
}
 ```

#### 17. Function
Syntax: `specifier fn name(varlist) result body`.
Function consists of name, parameter list varlist, return type result, body, and modifier specifier:
 ```
fn add(x:i8, y:i8) i8 { // Parameters x, y are "passed by value"
    if (x == 0) {
        return y;
    }
    return x + y;
}
test "functions" {
    const i = add(0, 9);
    _ = i; // i = 9

    const x: i8 = 10;
    const y: i8 = 20;
    _ = add(x, y); // Return result = 30
}
 ```

When basic types like integers and floats are passed as function parameters, the function body uses a copy of the parameter value, i.e., "**pass by value**". This typically involves minimal CPU register copying.
When **aggregate types** like structs, arrays are passed as function parameters, the function body might use a copy of the parameter value or a reference address, i.e., "**pass by reference**", because some **aggregate types** are complex and expensive to copy.
Thus, when **passing by value** (basic types and some aggregate types), the parameter's value cannot be changed inside the function:
 ```
fn test1(i: i32) void {
    i += 1; // Error: cannot assign to constant
}
test "change parameter" {
    var i: i32 = 0;
    test1(i);
}
 ```

When **passing by reference**, the referenced content can be changed inside the function, but the address of the parameter cannot be changed:
 ```
fn test2(p: *i32) void {
    p.* += 10; // Normal: p = 10
    var i: i32 = 1;
    p = &i; // Error: cannot assign to constant
}
test "change parameter" {
    var i: i32 = 0;
    test2(&i);
}
 ```
Therefore, regardless of whether a function parameter is a **basic type** or **aggregate type**, if you want to change its content, you need to make the parameter type a **pointer**.

Function parameters can be **compile-time known**, syntax: `comptime name: type`:
 ```
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}
fn gimmeTheBiggerFloat(a: f32, b: f32) f32 {
    return max(f32, a, b);
}
fn gimmeTheBiggerInteger(a: u64, b: u64) u64 {
    return max(u64, a, b);
}
 ```

A function with a `comptime` parameter means:
  - When calling this function, this parameter value is **compile-time known**, or it's a compile-time error;
  - At function definition, this parameter value is **compile-time known**.

Adding the `comptime` keyword before a function call indicates **compile-time call**:
 ```
fn expect(ok: bool) !void {
    if (!ok) return error.TestUnexpectedResult;
}

fn fibonacci(index: u32) u32 {
    if (index < 2) return index;
    return fibonacci(index - 1) + fibonacci(index - 2);
}

test "fibonacci" {
    // Runtime test of fibonacci function
    try expect(fibonacci(7) == 13);

    // Compile-time test of fibonacci function
    try comptime expect(fibonacci(7) == 13);
}
 ```

#### 18. Error
Error-related types include **error set type** and **error union type**, mainly used for error handling in function returns.
**Error set type** has syntax similar to **enum type**: `error{err1, err2, ...}`, also uses dot operator to access elements:
 ```
const FileOpenError = error{
    AccessDenied,
    OutOfMemory,
    FileNotFound,
};

const AllocationError = error{
    OutOfMemory,
};

test "coerce subset to superset" {
    const err = foo(AllocationError.OutOfMemory);
    _ = err; // err = FileOpenError.OutOfMemory
}

// The error set returned by function body, AllocationError, is a subset of the function's defined return error set, FileOpenError, which is allowed.
fn foo(err: AllocationError) FileOpenError {
    return err;
}
 ```

The error set returned by the function body is a **subset** of the function's defined return error set, so it's allowed. The opposite is not allowed:
 ```
// The error set returned by function body, FileOpenError, is a superset of the function's defined return error set, AllocationError, not allowed.
fn foo(err: FileOpenError) AllocationError {
    return err; // Error: expected type 'error{OutOfMemory}', found 'error{AccessDenied,OutOfMemory,FileNotFound}'
}
 ```

Merge **error sets** syntax: `a||b`. Note: `||` merges two error sets; the result contains the error elements of both.
 ```
const A = error{
    NotDir,
    PathNotFound,
};
const B = error{
    OutOfMemory,
    PathNotFound,
};

const C = A || B;
fn foo() C!void {
    return error.NotDir;
}

test "merge error sets" {
    foo() catch |err| {
        switch (err) {
            error.OutOfMemory => {},
            error.PathNotFound => {},
            error.NotDir => {},
        }
    };
}
 ```

Using exclamation mark `!` to combine an **error set type** with a normal type yields: **error union type**, indicating a function return value is either a normal type or an **error set type**.
Syntax: `errset!T` or `!T`. The **error set type** can be omitted:
 ```
const ResultError = error{
    notbool,
    notint,
};
fn intobool(i: i32) ResultError!bool {
    if (i > 0) {
        return true;
    } else if (i == 0) {
        return false;
    } else {
        return ResultError.notbool;
    }
}
test "error union type" {
    const r = try intobool(10);
    _ = r; // Here r=true;

    var e1: ResultError = undefined;
    _ = intobool(-10) catch |e| {
        e1 = e;
    };
    // Here e1 = ResultError.notbool
}
 ```

Catching **error union type** syntax: `a catch b` or `a catch |err| b`. If `a` is an error, returns `b`; otherwise returns the payload value of `a`. `err` is the caught error, its scope is within `b`:
 ```
fn doAThing(string: []u8) void {
    const number = parseU64(string, 10) catch 13;
    _ = number; // ...
}
 ```
In the above function, if `string` is a number, then `number` equals that number; otherwise `number = 13`.
Attempting to call a function returning an error union: syntax `try a`. If `a` is a normal value, continue execution; if `a` is an error, exit the function body and return the error.
If a function body contains `try`, the function's return type must be an **error union type**. If the function doesn't need to return an **error union type**, use `catch` to handle the error:
 ```
fn doAThing(string: []u8) !void {
    const number = try parseU64(string, 10);
    _ = number; // ...
}
 ```

Similar to `defer`, `errdefer` can be used to clean up on error when leaving the current scope:
 ```
fn createFoo(param: i32) !Foo {
    const foo = try tryToAllocateFoo();
    errdefer deallocateFoo(foo);

    const tmp_buf = try allocateTmpBuffer();
    defer deallocateTmpBuffer(tmp_buf);

    if (param > 1337) return error.InvalidParam;

    return foo;
}
 ```

#### 19. Optional Type
**Optional type** syntax: `?T`
 ```
// Normal integer
const normal_int: i32 = 1234;

// Optional integer
const optional_int: ?i32 = 5678;
 ```
 The **optional type variable** `optional_int` can have a value of type `i32` or be `null`. When it's certain that `optional_int` is not `null`, use syntax `optional_int.?` to get its value:
 ```
test "optional type" {
    // Declare optional type as null
    var optional_int: ?i32 = null;
    optional_int = 1234;

    if (optional_int.? == 1234) {
        expr;
    }
}
 ```
Pointers cannot be set to `null`, but **optional pointers** can. **Optional pointer** syntax: `?*T`. Use `ptr.?.*` to access the content pointed to:
 ```
test "optional pointers" {
    var ptr: ?*i32 = null;

    var x: i32 = 1;
    ptr = &x;

    if (ptr.?.* == 1) {
        expr;
    }
}
 ```

#### 20. Code Embedding
Syntax: `code(''' ''');` wrapped **multiline string** directly embeds code into the **function unit file**, sharing context **variables** and **scope** with other code:
 ```
code('''const std = @import("std");''');
code('''
    const Point = struct {
        x: u32,
        y: u32,

        pub var z: u32 = 1;
    };
''');

test "field access by string" {
    const expect = std.testing.expect;
    var p = Point{ .x = 0, .y = 0 };
    code('''
        @field(p, "x") = 4;
        @field(p, "y") = @field(p, "x") + 1;

        try expect(@field(p, "x") == 4);
        try expect(@field(p, "y") == 5);
    ''');
}

test "decl access by string" {
    const expect = std.testing.expect;
    code('''
        try expect(@field(Point, "z") == 1);

        @field(Point, "z") = 2;
        try expect(@field(Point, "z") == 2);
    ''');
}
 ```

#### 21. Import Function Unit
Syntax: `const FuncName = import(comptime func_path: str) type` or `import(comptime func_path: []const u8) type`.
This function imports a **function unit file** based on the `func_path` **string**, defaulting the **function unit file name** as the variable name:
 ```
import("functree/system/Config.func"); // Equivalent to const Config = import("functree/system/Config.func");
const Console = import("functree/app/Console.func");
const print = Console.print;

pub fn main() void {
    print("Hello, world!\n");
    print(Config.getName());
}
 ```

#### 22. Test
Syntax: `test testname {block}`.
`testname` can be a string or variable identifier. Code within a `test` block is executed when running `./Functree test path/FuncName.func`:
 ```
code('''const std = @import("std");''');

test "expect addOne adds one to 41" {
    try std.testing.expect(addOne(41) == 42);
}

test addOne {
    try std.testing.expect(addOne(41) == 42);
}

fn addOne(number: i32) i32 {
    return number + 1;
}
 ```

#### 23. Keywords List

| Keyword | Brief Description |
|---|---|
| align | Alignment, specifies pointer alignment |
| and | Logical AND operator |
| anyerror | **Global error set** |
| anytype | Deduces parameter concrete type at function call |
| bool | Boolean type |
| break | Exit from loop |
| catch | Catch error value |
| comptime | Ensures expression evaluated at compile time |
| comptime_int | **Compile-time known** integer literal type |
| comptime_float | **Compile-time known** floating-point literal type |
| const | Define read-only variable |
| continue | Jump back to start of loop |
| defer | Execute expression when control flow leaves current block |
| else | `if` expression clause |
| enum | Define **enumeration type** |
| errdefer | If error occurs in block, execute `errdefer` expression when control flow leaves block |
| error | Define **error set type** |
| false | False |
| fn | Define a **function** |
| for | Iterate over elements in **slice**, **array**, **tuple**, or numeric range |
| func | Equivalent to `struct` |
| if | `if` expression |
| import | Import other function unit file |
| in | `for` loop condition expression |
| isize | Signed platform-dependent integer type |
| or | Logical OR operator |
| pub | Identifiers defined with `pub` can be referenced from other **function unit files** |
| return | Exit function with return value |
| str | **String** type, equivalent to `[]const u8` |
| struct | Define **struct** |
| switch | Branch selection expression |
| test | Test declaration |
| true | True |
| try | Unwrap function return value or exit function returning error |
| type | Type of **compile-time known** parameter |
| undefined | Undefined value |
| usize | Unsigned platform-dependent integer type |
| var | Define mutable variable |
| void | Zero-bit type |
| while | Conditional loop statement, executes while condition is `true` or not `null` |
| code | Embed code |