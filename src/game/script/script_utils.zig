pub const maxLuaScriptSize = 360_000;
pub const maxLuaScriptNameSize = 20;

pub const ScriptError = error{
    ExpectedTable,
};

pub fn dataScriptToScript(scriptData: [360_001]u8) [maxLuaScriptSize]u8 {
    var buf = [_]u8{0} ** maxLuaScriptSize;
    @memcpy(buf[0..maxLuaScriptSize], scriptData[0..maxLuaScriptSize]);
    return buf;
}
