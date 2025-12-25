# Functree

**Functree**是一个基于zig语言的编译器学习项目，实现了部分zig语法。

## 安装

 * 安装zig环境，zig的目前版本为0.15.2；
 * 克隆或下载项目到本地；
 * 进入`Functree`根目录，生成`Functree.exe`可执行文件：zig build-exe Functree.zig

## 运行、测试与编译
 * 目前`Functree.exe`实现的行为包括：`run`、`test`、`build-exe`、`build-lib`、`build-obj`；
 * 因此，进入`Functree`根目录，可执行下列命令，以运行、测试、编译目标功件源文件：
 `Functree run functree/app/Hello.func [-target x86_64-linux -O ReleaseSmall...]`
 `Functree test functree/app/Hello.func [-target x86_64-linux -O ReleaseSmall...]`
 `Functree build-exe functree/app/Hello.func [-target x86_64-linux -O ReleaseSmall...]`
 `Functree build-lib functree/app/Hello.func [-target x86_64-linux -O ReleaseSmall...]`
 `Functree build-obj functree/app/Hello.func [-target x86_64-linux -O ReleaseSmall...]`
 * 示例：
 `zig test Functree.zig`
 `Functree test functree/app/Hello.func`
 `Functree run functree/app/Hello.func -target x86_64-windows`
 `Functree build-exe functree/app/Hello.func -target x86_64-windows -O ReleaseFast`
 `functree_app_Hello.exe`

## 规范

 * 每个程序文件视为一个**功件**，功能单一、明确，源文件内容均为UTF-8编码。
 * 所有**功件文件名称**的首字母大写（**TitleCase**），文件后缀为 `.func`，如：`Hello.func`，**功件文件**以 `functree` 为根目录进行组织，子目录名称均为小写。
 * 程序中标识符的位数应大于5位，尽量不小于3位。
 * **功件文件**中的函数名称的首字母小写（**camelCase**），如：`fn getName() str {}`；常量、变量、参数的名称均为全小写，中间以下划线 `_`分隔（**snake_case**），如：`const func_name: str = "abc";`。
 * 声明`enum`、`error`、`struct`、`union`等聚合类型时，其名称的首字母大写（**TitleCase**），如：`const UserType = enum {...};`。

## 第一个程序(Hello Word)

 `第一个功件源文件functree/app/Hello.func:`
 ```
const Console = import("functree/app/Console.func");

pub fn main() void {
    Console.print("Hello, world!\n");
}
 ```
 
 `Shell命令:`
 ```
$ ./Functree build-exe functree/app/Hello.func
$ ./functree_app_Hello
Hello, world!
 ```

## 语法说明
#### 1. 注释(Comment)
  
代码行注释以 `//` 开头到行尾，如下列代码：`//print("Hello?");`
 ```
const Console = import("functree/app/Console.func");
const print = Console.print;
pub fn main() void {
    //print("Hello?");
    print("Hello, world!\n");
}
 ```

文档注释行以 `///` 开始，如下列代码：`///程序入口`
 ```
const Console = import("functree/app/Console.func");
const print = Console.print;
///程序入口
pub fn main() void {
    //print("Hello?");
    print("Hello, world!\n");
}
 ```

整个文件的注释以 `//!` 开始，文件注释行只能放在文件的最前面，如下列代码：`//!文件说明`
 ```
//!文件说明
const Console = import("functree/app/Console.func");
const print = Console.print;
///程序入口
pub fn main() void {
    //print("Hello?");
    print("Hello, world!\n");
}
 ```

#### 2. 基本类型

**整数、浮点数和布尔**类型(Integer and float and bool)：

|  类型      |  说明                  |
|  ---      |  ---                   |
|  i8       |  有符号8位整数：`const int: i8 = -127;` |
|  u8       |  无符号8位整数，比特位长为8位，相当于C语言中的 unsigned char 类型：`const int: u8 = 255;` |
|  i16       |  有符号16位整数：`const int: i16 = -32767;` |
|  u16       |  无符号16位整数：`const int: u16 = 65535;`  |
|  i32       |  有符号32位整数：`const int: i32 = -2_147_483_647;`  |
|  u32       |  无符号32位整数：`const int: u32 = 4_294_967_295;`  |
|  i64       |  有符号64位整数：`const int: i64 = -9_223_372_036_854_775_807;`  |
|  u64       |  无符号64位整数：`const int: u64 = 18_446_744_073_709_551_615;`  |
|  i128       |  有符号128位整数：`const int: i128 = -17_014_118_346_046_923_1731_687_303_715_884_105_727;`  |
|  u128       |  无符号128位整数：`const int: u128 = 340_282_366_920_938_463_463_374_607_431_768_211_455;`  |
|  isize       |  目标平台有符号整数类型：`const int: isize = -127;`  |
|  usize       |  目标平台无符号整数类型：`const int: usize = 66;`  |
|  f16       |  16位浮点数 (10位尾数)：`const float: f16 = -1.2 + 1.0;`  |
|  f32       |  32位浮点数 (23位尾数)：`const float: f32 = 7.0 / 3.0;`  |
|  f64       |  64位浮点数 (52位尾数)：`const float: f64 = -1.2;`  |
|  f80       |  80位浮点数 (64位尾数)：`const float: f80 = -1.2;`  |
|  f128       |  128位浮点数 (112位尾数)：`const float: f128 = -1.2;`  |
|  bool       |  只有2个值，true 或 false：`const flag: bool = false;`  |
|  void       |  零位长的类型：`fn main() void {}`  |
|  type       |  编译期可知的类型值的类型：`fn get(T: type) T {}`  |
|  anyerror       |  任意错误代码的类型：`var number_or_error: anyerror!i32 = error.ArgNotFound;`，`fn clone() anyerror!u8 {}`  |
|  comptime_int       |  编译期可知的整数字面值的类型：`const int = 65;` 或 `const int: comptime_int = 65;`，以单引号包围的单个字符，类型是 comptime_int ，值是 unicode 码点：`const char = 'A';` 或 `const char = '中';`  |
|  comptime_float       |  编译期可知的浮点数字面值的类型：`const float = 1.2;` 或 `const float: comptime_float = 1.2;`  |

原始值：

|  名称      |  说明                  |
|  ---      |  ---                   |
|  true 或 false       |  布尔类型的值  |
|  null       |  可选类型的空值：`var optional_value: ?[]const u8 = null`  |
|  undefined       |  变量的未定义初始值：`var count: u8 = undefined;` |

转义序列：

|  名称   | 码点   |  说明                  |
|  ---   | ---  |  ---                   |
|  \t    | 09   |  水平制表符：`const string = "\tHello World!";` |
|  \n    | 10   |  换行：`const string = "Hello World!\n";`  |
|  \r    | 13   |  回车：`const char = '\r';`  |
|  \\"    | 34   |  双引号  |
|  \\'    | 39   |  单引号  |
|  \\\    | 92   |  反斜杠  |
|  \xNN    |    |  8位长的字节值（2个十六进制数字）：`const char = '\x41'; // 'A'` 或 `const string = "h\x65llo"; // "hello"` 或 `const string = "\xf0\x9f\x92\xaf"; // "💯"` |
|  \u{NNNNNN}    |    |  Unicode码点值（1个或多个十六进制数字）：`const char = '\u{4e2d}'; // '中'`  |

#### 3. 数组类型(Array)与字符串(String)

**一维数组**语法：`[N]T`；索引：`array[i]`；**数组**的长度为编译时已知，通过 `array.len` 获取数组长度：
 ```
var array: [2]u8 = [10,20];
_ = array[0];  // array[0] = 10
array[1] += 5; // array[1] = 25
_ = array.len; // array数组的长度 = 2
 ```
**多维数组**语法：`[N][M]T`；索引：`array[i][j]`：
 ```
var array: [2][2]u8 = [[1,2], [10,20]];
_ = array.len; // array数组的长度 = 2
_ = array[1]; // array[1] = [10,20]，其类型是 [2]u8
_ = array[1].len; // array[1]数组的长度 = 2
_ = array[1][0];  // array[1][0] = 10
array[1][1] += 5; // array[1][1] = 25
 ```
**数组**近似一个指向数组的**单项指针**，支持以下操作：
  - 索引：`array_ptr[i]`；
  - 切片：`array_ptr[start..end]`；
  - 获取长度：`array_ptr.len`；
  - 指针减法：`array_ptr - array_ptr`；

**切片**是**数组**的某个范围的局部**切片**，也可以是**切片**的**切片**，**切片**的长度可在运行时指定，可使用**数组或切片**索引的 `start..end` 设置**切片**范围：
 ```
var array: [3]i32 = [1, 2, 3]; // array的类型是 [3]i32

var known_at_runtime_one: usize = 1;
_ = &known_at_runtime_one;
//数组长度是3，切片范围是[1..3)，左闭右开，切片长度是2
const slice = array[known_at_runtime_one..array.len]; // slice的类型是*const [2]i32
_ = slice[0];  // slice[0] = array[1] = 2
slice[1] += 5; // slice[1] = array[2] = 8
_ = slice.len; // slice的长度 = 2
 ```
也可以用 `&` 操作符，获取**数组**地址设置**切片**：
 ```
const array: [3]i32 = [1, 2, 3]; // array的类型是[3]i32
const slice = &array; // slice的类型是*const [3]i32
_ = slice.len; // slice的长度 = 3

//还可以直接声明一个切片
const slice2: []i32 = &[ 1, 2, 3]; // slice2的类型是*const [3]i32
_ = slice2.len; // slice2的长度 = 3
 ```
**切片**近似一个包含长度的**多项指针**，支持以下操作：
  - 索引：slice[i]；
  - 切片：slice[start..end]；
  - 获取长度：slice.len。

**字符串**可视为元素类型为 `u8` 的常量数组**切片**：`[]const u8`，可以用 `str` 标识：
 ```
const string1 = "hello ";
const string2: str = ['w', 'o', 'r', 'l', 'd'];
const string3: []const u8 = "!";
const string = string1 ++ string2 ++ string3; // string="hello world!"
 ```
**多行字符串**，是以3个引号 `'''` 围起来的多行文本：
 ```
const text = '''
    #include <stdio.h>
    
    int main(int argc, char **argv) {
        printf("hello world\n");
        return 0;
    }
''';
 ```

#### 4. 指针(Pointer)
**单项指针**仅指向1个单独的变量。**单项指针**语法：`*T`，**解引用**获取指针对应内容的语法：`ptr.*`；取变量地址的语法：`&x`：
 ```
test "address of syntax" {
    // 获取常量地址，常量值只可读取，不可更改
    const x: i32 = 1234;
    const x_ptr = &x; // x_ptr 的类型为 *const i32
    // 获取指针对应的常量值
    if (x_ptr.* == 1234) {
        expr;
    }

    // 如果需要更改变量的值, 需要获取可变变量 var 的地址
    var y: i32 = 5678;
    const y_ptr = &y; // y_ptr 的类型为 *i32
    y_ptr.* += 1; // y_ptr 指向的变量值 + 1
    // 获取指针对应的变量值
    if (y_ptr.* == 5679) {
        expr;
    }
}

test "pointer array access" {
    var array: [10]u8 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    // 指向数组的某个元素的指针，也是单项指针
    const ptr = &array[2]; // ptr 的类型为 *u8

    // 更改 array[2] 的值
    ptr.* += 1; // array[2] = 4
}
 ```
**单项指针**支持以下操作：
  - 解引用：`ptr.*`，可读取变量值，可重新赋值;
  - 切片：`ptr[0..1]`；
  - 指针减法：`ptr - ptr`。

**多项指针**是指向未知个数元素的指针。**多项指针**语法：`[*]T`，获取指针数组中的某一项：`ptr[i]`：
 ```
test "pointer arithmetic with many-item pointer" {
    const array: [4]i32 = [1, 6, 3, 4];
    var ptr: [*]const i32 = &array;
    // 这里的 ptr[0] = 1
    ptr += 1; // 指针指向第2个元素
    // 这里的 ptr[0] = 6

    // 不设 end 数值的多项指针切片 ptr[start..] == ptr + start
    if (ptr[1..] == ptr + 1) {
        expr;
    }
}
 ```
**多项指针**支持以下操作：
  - 指针索引：`ptr[i]`;
  - 切片：`ptr[start..end] and ptr[start..]`；
  - 指针整数运算：`ptr + int`, `ptr - int`；
  - 指针减法：`ptr - ptr`。

通过下列方法，可以将**单项指针**转换为**多项指针**：
 ```
test "slice syntax" {
    var x: i32 = 1234;
    const x_ptr = &x;

    // 通过切片将单项指针转换为指向数组的单项指针
    const x_array_ptr = x_ptr[0..1]; // x_array_ptr的类型是 *[1]i32

    // 指向数组的单项指针，强制转换为多项指针:
    const x_many_ptr: [*]i32 = x_array_ptr; // x_many_ptr的类型是 [*]i32
}
 ```

#### 5. 结构(struct)
**结构**为**聚合类型**，可以携带多个字段信息，目前不支持内置函数。
语法：`struct {field_name1: type1, field_name2: type2, ...}`，使用点操作符访问内部字段：
 ```
// 声明一个结构，注意：结构名称的首字母必须大写
const Point = struct {
    x: f32,
    y: f32,
};

// 声明一个结构实例，注意：常量或变量名称为全小写，可以下划线 _ 分隔
const point: Point = .{
    .x = 0.12,
    .y = 0.34,
};

_ = point.x;

// 声明结构时，可以设初始值
const Point2 = struct {
    x: f32 = 0.12,
    y: f32,
};

// 声明结构实例时，初始值可为 undefined
const point2: Point2 = .{
    .y = undefined,
};
 ```

#### 6. 元组(Tuple)
未指定字段名称的struct，即为一个**元组**，目前不支持内置函数。
语法：`struct {type1, type2, ...}`；与数组一样，使用方括号访问内部字段，使用 `.len` 获取元素数量：
```
// 声明一个元组，注意：元组名称的首字母必须大写
const Point = struct {
    f32,
    f32,
};

// 声明一个元组实例，注意：常量或变量名称为全小写，可以下划线 _ 分隔
const point: Point = .{
    0.12,
    0.34,
};

_ = point[0]; // 0.12
_ = point.len; // 2

// 也可以直接匿名声明一个元组实例
const point2 = .{
    0.12,
    0.34,
};
// 匿名元组作为函数的返回值为
fn divmod(numerator: u32, denominator: u32) struct { u32, u32 } {
    return .{ numerator / denominator, numerator % denominator };
}
const div, const mod = divmod(10, 3);
_ = div; // 这里的 div = 3
_ = mod; // 这里的 mod = 1
 ```

#### 7. 枚举(enum)
**枚举**为**聚合类型**，可以有多个预设值，目前不支持内置函数。
语法：`enum {value1, value2, ...}`，使用点操作符访问内部元素：
 ```
// 声明一个枚举，注意：枚举名称的首字母必须大写
const Result = enum {ok, not_ok};

// 声明一个枚举实例常量，注意：常量或变量名称为全小写，可以下划线 _ 分隔
const result_ok = Result.ok;
const result_not_ok: Result = .not_ok;

//声明一个枚举类型时，可以指定枚举元素的数据类型
const Value = enum(u2) {
    zero,
    one,
    two,
};
_ = Value.zero; // 0
_ = Value.one; // 1
_ = Value.two; // 2

//声明一个枚举类型时，可以指定枚举元素的默认值
const Value2 = enum(u32) {
    hundred = 100,
    thousand = 1000,
    million = 1000000,
};
_ = Value2.hundred; // 100
_ = Value2.thousand; // 1000
_ = Value2.million; // 1000000
 ```

#### 8. 联合(union)
**联合**类似于 `struct`，可以定义多个预设值，当同时只能有一个字段值有效，目前不支持内置函数。
**结构**为**聚合类型**，可以携带多个字段信息，目前不支持内置函数。
语法：`union {field_name1: type1, field_name2: type2, ...}`，使用点操作符访问内部字段：
 ```
// 声明一个联合，注意：联合名称的首字母必须大写
const Payload = union {
    int: i64,
    float: f64,
    boolean: bool,
};

test "simple union" {
    // 声明一个联合变量，注意：常量或变量名称为全小写，可以下划线 _ 分隔
    var payload = Payload{ .int = 1234 };
    try expect(payload.int == 1234);
    // 联合变量的再次赋值，必须使用完整的联合变量初始化方式
    payload = Payload{ .float = 12.34 };
    try expect(payload.float == 12.34);
}
 ```
如果要用 `switch` 语句处理 `union`，需要使用 `enum` 变量进行标记：
 ```
// 声明一个枚举变量
const ResultTypeTag = enum {
    ok,
    not_ok,
};
// 使用枚举变量声明一个联合变量
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

#### 9. 变量和赋值(Variable and Assignment)
使用 `const` 定义的变量，实际是一个常量，其值不允许修改；使用 `var` 定义的变量，其值在定义后，必须有修改或引用操作。
变量必须有类型，不存在没有类型的变量，定义语法：`const name: type = v;` 或 `var name: type = v;`，类型和变量名之间用冒号 `:` 隔开：
 ```
pub fn main() void {
    var y: i32 = 5678;
    y += 1;
}
 ``` 
定义变量时，尽可能用 `const`，这样不容易出现 bug，且易于优化与维护。如果声明 `const` 变量时设置了初始值，则说明此变量为**编译时已知**。
变量定义后必须要使用，可以用 `_ = name;` 方式忽略变量的使用；同样可以用 `_ = expr;` 的方式，忽略表达式 expr 的运算结果。
 ```
pub fn main() void {
    const x: i32 = 1;
    _ = x;
}
 ``` 
定义常量时必须赋初始值，没有初始值则编译出错，当初始值可以推导出准确类型时，可省略类型：
 ```
pub fn main() void {
    const count = 1; // count的类型为 comptime_int
    _ = count;
    const tuple = .{1, 2, 3}; // tuple的类型为 comptime_int 元组
    _ = tuple;
}
 ```
如果定义变量时不赋初始值，想稍后再赋值，则须设变量值为 `undefined`：
 ```
pub fn main() void {
    var x: i32 = undefined;
    x = 3;
}
 ``` 

作用域是指**标识符号**（包括普通变量、类型定义、函数定义等）在程序运行期间的有效使用区域。
通常变量的**生命周期**全过程包括定义、使用、失效；当**标识符号**离开其**作用域**时，将失效且无法使用；在一个**作用域**内，不允许定义同名的**标识符号**。

**局部变量**是指其生命周期内仅在本函数或本语句块内有效的变量：
 ```
test "local var" {
    var i: i32 = 5;
    {
        var j: i32 = 10;
        // 这里 i 和 j 都有效
    }
    i = j; // 报错：use of undeclared identifier 'j'
}
 ```
局部变量可以定义在 `comptime` 块内，或用`comptime` 关键字来修饰。这样该变量的值是**编译时已知**的，并且该变量的所有读取和写入都发生在程序**编译时**，而不是在**运行时**：
 ```
test "comptime var" {
    comptime var y: i32 = 1;
    y += 1; // 编译时执行
    if (y != 2) { // 编译时执行
        expr; // 编译时执行
    }
}
 ```
在 `comptime` 块中定义的所有变量都是 `comptime` 变量：
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

**静态局部变量**是指在函数或块作用域内声明的struct、枚举等**聚合类型**变量。**静态局部变量**有静态生命周期，其作用域属于**函数作用域**或**块作用域**：
 ```
test "static local variable" {
    foo(); // S.x = 1235
    foo(); // S.x = 1236
    foo1(); // x = 1235
    foo1(); // x = 1235
}
fn foo() i32 {
    const S = struct{ // S 为静态局部变量
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

**容器级变量**是指在**功件文件**（功件文件也是容器）中顶级声明的变量，其具有静态生命周期，其作用域属于**功件作用域**。如果声明**容器级变量**时，设置了初始值，则其值为**编译时已知**，否则为**运行时已知**：
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
**容器级变量**还可以声明在**功件文件**中顶级的struct、枚举等**聚合类型**的内部，其具有静态生命周期，其作用域属于**功件作用域**：
 ```
test "container level variable" {
    foo(); // S.x = 1235
    foo(); // S.x = 1236;
}

const S = struct {
    var x: i32 = 1234; // x 为编译时已知，其属于定义 S 的文件级作用域
};

fn foo() i32 {
    S.x += 1;
    return S.x;
}
 ```

**全局变量**是指在**功件文件**中顶级声明的变量，并且使用 `pub` 修饰符定义的变量，其具有全局的静态生命周期，在引用此**功件文件**的其他**功件文件**中也可以使用：
**功件文件** `functree/system/Config.func`：
 ```
pub const j = i + 3;
const i: i32 = 1;
pub fn getName() void {}
 ```
引入 `functree/system/Config.func` 的**功件文件** `functree/app/Hello.func`：
 ```
const Config = import("functree/system/Config.func"); // 引入其他功件
test "global var"{
    _ = Config.j; // Config.j = 4
    Config.getName();
}
 ```

#### 10. 运算符(Operator)
运算符列表：

|  名称   | 符号   |  适用类型     |  说明   |  示例               |
|  ---   | ---  |  ---            |  ---        |  ---        |
| 加 | `x + y` 或 `x += y`  | 整数、浮点数 | 整数运算注意溢出问题   |  `5 + 2 == 7` |
| 减 | `x - y` 或 `x -= y` | 整数、浮点数 | 整数运算注意溢出问题  |  `2 - 5 == -3` |
| 负数 | `-x` | 整数、浮点数 | 整数运算注意溢出问题  |  `-1 == 0 - 1` |
| 乘 | `x * y` 或 `x *= y` | 整数、浮点数 | 整数运算注意溢出问题  |  `2 * 5 == 10` |
|  除    | `x / y` 或 `x /= y` | 整数、浮点数 | 整数运算注意溢出和零除问题  |  `10 / 5 == 2` |
|  取余  | `x % y` 或 `x %= y` | 整数、浮点数 | 整数和浮点数运算都要注意零除问题  |  `10 % 3 == 1` |
|  左移位  | `x << y` | 整数 | b必须**编译时已知**  |  `0b1 << 8 == 0b100000000` |
|  右移位  | `x >> y` | 整数 | b必须**编译时已知**  |  `0b1010 >> 1 == 0b101` |
|  位与    | `x & y` | 整数 |   |  `0b011 & 0b101 == 0b001` |
|  位或    | `x \| y` | 整数 |   |  `0b010 \| 0b100 == 0b110` |
|  异或    | `x ^ y` | 整数 |   |  `0b011 ^ 0b101 == 0b110` |
| 取反  | `~x` | 整数 |   |   |
| 可选类型取值 | `x.?` | 可选类型 | 整数运算注意溢出问题  |  `const value: ?u32 = 5678; // value.? == 5678` |
| 捕获错误 | `x catch y` 或 `x catch \|err\| y` | 错误联合类型 |   |  `const value: anyerror!u32 = error.Broken;const unwrapped = value catch 1234; // unwrapped == 1234` |
|  逻辑与 | `x and y` | 布尔型 |   |  `(false and true) == false` |
|  逻辑或 | `x or y` | 布尔型 |   |  `(false or true) == true` |
|  逻辑非    | `!x` | 布尔型 |   |  `!false == true` |
| 等于 | `x == y` | 整数、浮点数、布尔型 |   |  `(1 == 1) == true` |
| null判断    | `x == null` | 可选类型 |   |  `const value: ?u32 = null; // (value == null) == true` |
| 不等于 | `x != y` | 整数、浮点数、布尔型 |   |  `(1 != 1) == false` |
| 非null判断 | `x != null` | 可选类型 |   |  `const value: ?u32 = null; // (value != null) == false` |
| 大于 | `x > y` | 整数、浮点数 |   |  `(2 > 1) == true` |
| 大于等于 | `x >= y` | 整数、浮点数 |   |  `(2 >= 1) == true` |
| 小于 | `x < y` | 整数、浮点数 |   |  `(1 < 2) == true` |
| 小于等于 | `x <= y` | 整数、浮点数 |   |  `(1 <= 2) == true` |
| 数组合并 | `x ++ y` | 数组 | 所有数组的长度必须==编译时==已知  |  `const array1 = [1,2];const array2 = [3,4];const together = array1 ++ array2; // together=[1,2,3,4]` |
| 数组重复 | `x ** y` | 数组 | 数组a的长度和数字b的值必须**编译时**已知  |  `const pattern = "ab" ** 3; // pattern="ababab"` |
| 获取指针内容 | `x.*` | 指针 |   |  `const x: u32 = 1234;const ptr = &x; // ptr.* == 1234` |
| 取地址 | `&x` | 所有类型 |   |  `const x: u32 = 1234;const ptr = &x; // ptr.* == 1234` |
| 错误合并 | `x \|\| y` | 错误集类型 | 合并错误集 |  `const A = error{One};const B = error{Two}; // (A \|\| B) == error{One, Two}` |

运算符的优先级：
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

#### 11. 块(Block)
内有0条或多条语句组成，用 **{ }** 括起来的语法单元，称为语句块。语句块用来限制声明变量的**作用域**，语句块内部声明的变量，在语句块外部无法使用，下列测试无法通过：
 ```
test "access variable after block scope" {
    {
        var x: i32 = 1;
        _ = &x;
    }
    x += 1; // 报错：use of undeclared identifier 'x'
}
 ```
语句块外部声明的变量，在语句块内部可以使用，下列测试将通过：
 ```
test "access variable in block scope" {
    var x: i32 = 1;
    {
        x += 1; // 这里的 x = 2
    }
}
 ```

空语句块等于 **void{}**，不执行任何操作：
 ```
const block = {};
_ = block; // block的类型是 void{}
 ```

使用 `comptime { }` 包裹的块，为**编译时运行**语句块：
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

#### 12. if 控制语句
`if` 控制语句，根据判断条件是否为真，执行不同的程序分支：
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
`if` 表达式还可以作为运算结果：
 ```
test "if expression" {
    const x: u32 = 5;
    const y: u32 = 4;
    const result = if (x != y) 1 else 2;
    _ = result; // 这里的 result = 1
}
 ```

#### 13. switch分支语句
`switch` 分支选择语句，通常用来处理**枚举类型**变量：
 ```
const Color = enum {
    auto,
    off,
    on,
};
test "switch enum" {
    const color = Color.off;

    // 需要处理所有已知枚举元素
    switch (color) {
        .auto, .off => {},
        .on => {},
    }

    // 否则，需要设置else分支，捕捉处理其他枚举元素
    switch (color) {
        .on => {},
        else => {},
    }
}
 ```

`switch` 语句处理整数分支：
 ```
test "switch integer" {
    const x: u64 = 10;

    switch (x) {
        1, 2, 3 => {},
        5...100 => {},
        // 需要设置else分支，捕捉处理其他整数
        else => {},
    };
}
 ```

#### 14. while循环语句
`while` 循环语句，用于重复执行一段程序，直到判断条件不为真时结束：
 ```
test "while basic" {
    var i: usize = 0;
    while (i < 10) {
        i += 1;
    }
    // 这里的 i = 10
}
 ```
可以在满足某些条件时，使用 `break` 提前跳出循环：
 ```
test "while break" {
    var i: usize = 0;
    while (true) {
        if (i == 10)
            break;
        i += 1;
    }
    // 这里的 i = 10
}
 ```
同样，可以在满足某些条件时，使用 `continue` 跳过后面语句的执行，返回到循环的开始处：
 ```
test "while continue" {
    var i: usize = 0;
    while (true) {
        i += 1;
        if (i < 10)
            continue;
        break;
    }
    // 这里的 i = 10
}
 ```
`while` 循环语句，可以用一个**可选类型变量**作为判断条件，当此**可选类型变量**为 `null` 时，才跳出循环：
 ```
test "while null capture" {
    var sum1: u32 = 0;
    numbers_left = 3;
    // while (value in eventuallyNullSequence()) {
    while (eventuallyNullSequence()) |value| {
        sum1 += value;
    }
    // 这里的 sum1 = 3
}
var numbers_left: u32 = undefined;
fn eventuallyNullSequence() ?u32 {
    numbers_left -= 1;
    return if (numbers_left == 0) null else numbers_left;
}
 ```

#### 15. for循环语句
`for` 循环语句，用于遍历数组和切片等集合，直到遍历完成：
 ```
test "for basics" {
    const items: [5]i32 = [1, 2, 3, 0, 5];
    var sum: i32 = 0;

    //遍历数组，每个元素捕捉到变量 value 中
    // for (value in items) {
    for (items) |value| {
        // 支持break和continue
        if (value == 0) {
            continue;
        }
        sum += value;
    }
    // 这里的 sum = 11

    //遍历切片，切片范围为[0, 1)，即只包含一个元素：1
    for (items[0..1]) |value| {
        sum += value;
    }
    // 这里的 sum = 12;

    // 遍历时，可以将数组索引作为第2个条件，并将索引值捕捉到第2个变量 index 中
    for (items, 0..) |_, index| {
        _ = index; // index的值为 0 至 4
    }

    // 还可以遍历一个整数范围
    var sum2: usize = 0;
    for (0..5) |i| {
        sum2 += i; // i的值为 0 至 4
    }
    // 这里的 sum2 = 10;
}
 ```

#### 16. defer语句
如果**函数**或**代码块**中包含 `defer` 语句，则在程序运行离开当前作用域前，执行 `defer` 语句，与 `defer` 语句在当前作用域的位置无关：
 ```
fn deferExample() !usize {
    var x: usize = 1;

    {
        defer x = 2;
        x = 1;
    }
    // 离开前处理 defer x = 2，所以这里的 x = 2

    x = 5;
    return x; // 返回值 = 5
}
 ```
同一个作用域有多个 `defer` 语句时，按定义的反向顺序运行，先定义的后运行，后定义的先运行：
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
            print("defer3"); // 不运行的语句块内的 defer3 语句，不会运行
        }
    }
}
pub fn main() void{
    deferUnwind(); // 执行defer的顺序：defer2 defer1
}
 ```
`defer` 语句块中不能有 **return** 语句，否则编译出错：
 ```
fn deferInvalidExample() !void {
    defer {
        return error.DeferError; // 报错：cannot return from defer expression
    }

    return error.DeferError;
}
 ```

#### 17. 函数(Function)
语法：`specifier fn name(varlist) result body`。
函数由函数名name、参数列表varlist、返回值类型result、函数体body、修饰符specifier组成：
 ```
fn add(x:i8, y:i8) i8 { //参数x、y为“值传递“
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
    _ = add(x, y); // 返回结果 = 30
}
 ```

当整数和浮点数等基本类型作为函数的参数时，在函数体内使用的是参数值的副本，即“**值传递**”。这种情况基本只涉及到 CPU 中的寄存器复制，代价极小。
当struct、数组等**聚合类型**作为函数的参数时，在函数体内使用的可能是参数值的副本，也可能是参数值的引用地址，即“**引用传递**”，因为有些**聚合类型**很复杂，复制代价很高。
因此，按**值传递**时（基本类型与某些聚合类型），在函数体内不能改变参数的值：
 ```
fn test1(i: i32) void {
    i += 1; // 报错：cannot assign to constant
}
test "change parameter" {
    var i: i32 = 0;
    test1(i);
}
 ```

按**引用传递**时，在函数体内可以改变参数的引用内容，但不能改变参数的地址：
 ```
fn test2(p: *i32) void {
    p.* += 10; // 正常：p = 10
    var i: i32 = 1;
    p = &i; // 报错：cannot assign to constant
}
test "change parameter" {
    var i: i32 = 0;
    test2(&i);
}
 ```
所以，不管函数的参数是**基本类型**还是**聚合类型**，如果想要更改参数的内容，需要将参数的类型设为**指针**。

函数的参数可以设为 **编译时已知**，语法：`comptime name: type`:
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

函数具有一个 `comptime` 参数，说明：
  - 在调用此函数时，此参数值是**编译时已知**，或者此参数是一个编译时错误；
  - 在函数定义时，此参数值是**编译时已知**。

调用函数前增加 `comptime` 关键词，表示**编译时调用**：
 ```
fn expect(ok: bool) !void {
    if (!ok) return error.TestUnexpectedResult;
}

fn fibonacci(index: u32) u32 {
    if (index < 2) return index;
    return fibonacci(index - 1) + fibonacci(index - 2);
}

test "fibonacci" {
    // 运行时测试 fibonacci 函数
    try expect(fibonacci(7) == 13);

    // 编译时测试 fibonacci 函数
    try comptime expect(fibonacci(7) == 13);
}
 ```

#### 18. 错误(error)
错误相关类型，包括**错误集类型**、**错误联合类型**，主要用于函数返回值相关的错误处理上。<br />
**错误集类型** 与 **枚举类型** 有类似的定义语法：`error{err1, err2, ...}`，也使用点操作符访问内部元素：
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

// 函数体返回的错误集 AllocationError，是函数定义返回错误集 FileOpenError 的子集，被允许
fn foo(err: AllocationError) FileOpenError {
    return err;
}
 ```

上述函数体返回的**错误集**，是函数定义返回错误集合的**子集**，所以是被允许的。反之则不被允许：
 ```
// 函数体返回的错误集 FileOpenError，是函数定义返回错误集 AllocationError 的超集，不被允许
fn foo(err: FileOpenError) AllocationError {
    return err; // 报错： expected type 'error{OutOfMemory}', found 'error{AccessDenied,OutOfMemory,FileNotFound}'
}
 ```

合并**错误集**语法：`a||b`，说明：用 `||` 可将两个错误集合并，结果将包含了两个**错误集**的错误元素。
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

用感叹号 `!` 将**错误集类型**和普通类型组合在一起，就是：**错误联合类型**，表示函数的返回值，要么是一个普通类型，要么是一个**错误集类型**。
语法：`errset!T` 或 `!T`，**错误集类型**可以省略：
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
    _ = r; // 这里的 r=true;

    var e1: ResultError = undefined;
    _ = intobool(-10) catch |e| {
        e1 = e;
    };
    // 这里的 e1 = ResultError.notbool
}
 ```

捕获**错误联合类型**的语法：`a catch b` 或 `a catch |err| b`，说明：如果 `a` 是错误，则返回 `b` ，否则返回 `a` 的载荷值，`err` 是捕获到的错误，其作用域是在 `b` 范围内：
 ```
fn doAThing(string: []u8) void {
    const number = parseU64(string, 10) catch 13;
    _ = number; // ...
}
 ```
上述函数中，如果 `string` 字符串是数字，则 `number` 等于相应数字，否则 `number = 13`。<br />
尝试调用 “返回错误联合类型” **函数**的语法：`try a`，说明：`a` 为正常值时继续执行下列语句，`a` 为错误时跳出本函数体的执行，并返回错误。
如果函数体内部有 `try`，则函数的返回值必须是**错误联合类型**，如果函数不需要返回**错误联合类型**，则用 `catch` 捕获错误即可：
 ```
fn doAThing(string: []u8) !void {
    const number = try parseU64(string, 10);
    _ = number; // ...
}
 ```

类似 `defer`，离开当前作用域出错时，可以用 `errdefer` 语句，清理错误现场：
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

#### 19. 可选类型(Optional)
**可选类型**的语法：`?T`
 ```
// 一般整型
const normal_int: i32 = 1234;

// 可选整型
const optional_int: ?i32 = 5678;
 ```
 **可选类型变量** `optional_int` 的值可以为 `i32`，也可以是 `null`，在确定 `optional_int` 不为 `null` 时，使用语法 `optional_int.?` 获取**可选类型变量**的值： 
 ```
test "optional type" {
    // 声明可选类型为null
    var optional_int: ?i32 = null;
    optional_int = 1234;

    if (optional_int.? == 1234) {
        expr;
    }
}
 ```
指针不可以设为 `null`，但是**可选类型指针**能够设为 `null`，**可选类型指针**的语法：`?*T`，使用 `ptr.?.*` 获取**可选类型指针**的对应内容:
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

#### 20. 代码嵌入
语法：`code(''' ''');` 包裹的**多行字符串**，将直接嵌入到**功件文件**的代码中，并与其他代码共享上下文**变量**和**作用域**：
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

#### 21. 引入功件(import)
语法：`const FuncName = import(comptime func_path: str) type` 或 `import(comptime func_path: []const u8) type`。
这个功能将根据 `func_path` 路径**字符串**引入**功件文件**，默认将**功件文件名称**作为变量名称：
 ```
import("functree/system/Config.func"); // 等同于const Config = import("functree/system/Config.func");
const Console = import("functree/app/Console.func");
const print = Console.print;

pub fn main() void {
    print("Hello, world!\n");
    print(Config.getName());
}
 ```

#### 22. 测试(test)
语法：`test testname {block}`。
`testname` 可以字符串或变量标识符，包含在 `test` 块中的代码，将在 `./Functree test path/FuncName.func` 时执行测试：
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

#### 23. 关键字(Keyword)列表

|关键字|简要说明|
|---|---|
|align | 对齐，指定指针的对齐方式 |
|and | 逻辑与运算符 |
|anyerror | **全局错误集** |
|anytype | 在函数调用时推导出参数具体类型 |
|bool | 布尔类型 |
|break | 从循环中退出 |
|catch | 捕捉错误值 |
|comptime | 确保表达式在编译期计算 |
|comptime_int | **编译时已知**整数字面值类型 |
|comptime_float | **编译时已知**浮点数字面值类型 |
|const | 定义只读变量 |
|continue | 在循环中跳回到开始处继续 |
|defer | 控制流离开当前块时执行表达式 |
|else | `if` 表达式子句 |
|enum | 定义**枚举类型** |
|errdefer | 如果代码块中发生错误，则在控制流离开当前块时执行 `errdefer` 表达式 |
|error | 定义**错误集类型** |
|false | 假 |
|fn | 定义一个**函数** |
|for | 用于遍历**切片**、**数组**、**元组**或数字范围中的元素 |
|func | 等同于 `struct` |
|if | `if` 表达式 |
|import | 引入其他功件文件 |
|in | `for` 循环条件表达式 |
|isize | 有符号平台相关整数类型 |
|or | 逻辑或运算符 |
|pub | 可以从其它**功件文件**引用 `pub` 定义的标识符号 |
|return | 带返回值退出函数 |
|str | **字符串**类型，等同于 `[]const u8` |
|struct | 定义**结构** |
|switch | 分支选择表达式 |
|test | 测试声明 |
|true | 真 |
|try | 取出调用函数的返回值或退出函数返回错误 |
|type | **编译时已知**参数的类型 |
|undefined | 未定义值 |
|usize | 无符号平台相关整数类型 |
|var | 定义可以修改的变量 |
|void | 零位长类型 |
|while | 条件循环语句，条件为 `true` 或不为 `null` 时执行循环 |
|code | 嵌入代码 |
