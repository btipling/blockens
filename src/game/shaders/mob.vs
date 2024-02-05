#version 330 core
layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 texCoords;
layout (location = 3) in vec4 color;
layout (location = 4) in vec4 modelMatrixC1;
layout (location = 5) in vec4 modelMatrixC2;
layout (location = 6) in vec4 modelMatrixC3;
layout (location = 7) in vec4 modelMatrixC4;

out vec3 Normal;
out vec2 TexCoord;
flat out vec4 Color;

uniform mat4 projection;

layout(std140) uniform ViewMatrixBlock {
    mat4 viewMatrix;
};

void main()
{
    // vec4 c1 = vec4(1, 0, 0, 0);
    // vec4 c2 = vec4(0, 1, 0, 0);
    // vec4 c3 = vec4(0, 0, 1, 0);
    // vec4 c4 = vec4(10, 0, 0, 1);
    // mat4 modelMatrix = mat4(c1, c2, c3, c4);
    mat4 modelMatrix = mat4(modelMatrixC1, modelMatrixC2, modelMatrixC3, modelMatrixC4);
    gl_Position = projection * viewMatrix * modelMatrix * vec4(position.xyz, 1.0);
    Normal = normal;
    TexCoord = texCoords;
    Color = color;
}