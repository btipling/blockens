#version 330 core
layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 texCoords;
layout (location = 3) in vec4 color;

out vec3 Normal;
out vec2 TexCoord;
flat out vec4 Color;

uniform mat4 projection;
uniform mat4 toModelSpace;

layout(std140) uniform ViewMatrixBlock {
    mat4 viewMatrix;
};

void main()
{
    gl_Position = projection * viewMatrix  * toModelSpace * vec4(position.xyz, 1.0);
    Normal = normal;
    TexCoord = texCoords;
    Color = color;
}