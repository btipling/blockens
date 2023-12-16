const gl = @import("zopengl");

pub const State = struct {
    cameraPos: @Vector(4, gl.Float),
    cameraFront: @Vector(4, gl.Float),
    cameraUp: @Vector(4, gl.Float),
    lastFrame: gl.Float,
    deltaTime: gl.Float,
    firstMouse: bool,
    lastX: gl.Float,
    lastY: gl.Float,
    yaw: gl.Float,
    pitch: gl.Float,

    pub fn init() State {
        return State{
            .cameraPos = @Vector(4, gl.Float){ 0.0, 1.0, 3.0, 1.0 },
            .cameraFront = @Vector(4, gl.Float){ 0.0, 0.0, -1.0, 0.0 },
            .cameraUp = @Vector(4, gl.Float){ 0.0, 1.0, 0.0, 0.0 },
            .lastFrame = 0.0,
            .deltaTime = 0.0,
            .firstMouse = true,
            .lastX = 0.0,
            .lastY = 0.0,
            .yaw = -90.0,
            .pitch = 0.0,
        };
    }
};
