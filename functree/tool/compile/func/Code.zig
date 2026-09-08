const System = @import("../../System.zig");
const Memory = System.Memory;
const DataType = System.DataType;
const String = DataType.String;
const List = DataType.List;
const Map = DataType.Map;
const StaticStringMap = DataType.StaticStringMap;

const Token = @import("Token.zig");
const TokenIndex = Token.TokenIndex;

const Node = @import("Node.zig");
const NodeIndex = Node.NodeIndex;
const root_node_index = Node.root_node_index;

memory: *Memory,
code_type: CodeType,
start_token: TokenIndex,
end_token: TokenIndex,
node_map: Map.t(NodeIndex, Node),
arg_node_index_map: Map.t(NodeIndex, List.t(NodeIndex)),
parent: ?*Code,
child_list: List.t(Code),
is_pub: bool = false,
is_comptime: bool = false,
is_inline: bool = false,

is_capitalization: bool = false,
is_array_init: bool = false,
is_container: bool = false,
is_fn: bool = false,
has_const_var: bool = false,
has_call_fn: bool = false,

pub fn a(memory: *Memory, start_token: TokenIndex, parent: ?*Code) Code {
    const self = Code{
        .memory = memory,
        .code_type = CodeType.unkown,
        .start_token = start_token,
        .end_token = start_token,
        .node_map = Map.t(NodeIndex, Node).a(memory),
        .arg_node_index_map = Map.t(NodeIndex, List.t(NodeIndex)).a(memory),
        .parent = parent,
        .child_list = List.t(Code).a(memory),
    };
    return self;
}

pub fn incEndToken(self: *Code) void {
    self.end_token += 1;
}

pub fn appendRootNode(self: *Code, node: Node) !NodeIndex {
    try self.node_map.add(root_node_index, node);
    return root_node_index;
}
pub fn appendNode(self: *Code, node: Node) !NodeIndex {
    const node_index = DataType.intCast(NodeIndex, self.node_map.count()) + 1;
    try self.node_map.add(node_index, node);
    return node_index;
}
pub fn removeNode(self: *Code, node_index: NodeIndex) bool {
    return self.node_map.remove(node_index);
}
pub fn getNode(self: Code, node_index: NodeIndex) !Node {
    const node = self.node_map.get(node_index);
    if (node == null) return CodeError.code_node_is_null;
    return node.?;
}
pub fn setNode(self: *Code, node_index: NodeIndex, node: Node) !NodeIndex {
    try self.node_map.add(node_index, node);
    return node_index;
}
pub fn putArgNodeIndexMap(self: *Code, param_arg_index: NodeIndex, node_index: NodeIndex) !void {
    const node_index_list = self.arg_node_index_map.getPtr(param_arg_index);
    if (node_index_list == null) {
        var list = List.t(NodeIndex).a(self.memory);
        try list.add(node_index);
        try self.arg_node_index_map.add(param_arg_index, list);
    } else {
        try node_index_list.?.*.add(node_index);
    }
}

pub fn appendChildCodeList(self: *Code, child_code: Code) !void {
    try self.child_list.add(child_code);
}
pub fn getChildCodeList(self: *Code) List.t(Code) {
    return self.child_list;
}

pub const CodeType = enum {
    define_var,
    declare_param,
    assign,
    _continue,
    _break,
    _unreachable,
    _return,
    call_fn,
    _asm,
    _code,
    _try,
    _include,
    _block,
    define_fn,
    if_block,
    else_block,
    else_if_block,
    for_block,
    while_block,
    switch_block,
    switch_case_block,
    test_block,
    _defer,
    _errdefer,
    _comptime,
    unkown,
    invalid,
};

pub const CodeError = error{
    invalid_catch_code,
    expected_r_brace,
    expected_else_expression,
    expected_identifier,
    expected_identifier_value,
    expected_fn_result,
    expected_capitalization_for_container_name,
    expected_no_capitalization_for_function_name,
    skip_one_invalid_token_type,
    catch_block_invalid_token_type,
    define_fn_invalid_token_type,
    invalid_symbol_type,
    define_var_invalid_operator,
    expected_data_type,
    expected_array_type,
    expected_semicolon,
    unknow_code_type,
    invalid_code_type,
    code_node_is_null,
    invalid_token_type,
    redeclaration_of_variable,
    out_of_memory,
};

const Code = @This();
