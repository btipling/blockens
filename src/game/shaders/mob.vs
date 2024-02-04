#version 330 core
layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 texCoords;
layout (location = 3) in vec4 color;
layout (location = 4) in mat4 modelMatrix;

out vec3 Normal;
out vec2 TexCoord;
flat out vec4 Color;

uniform mat4 projection;

layout(std140) uniform ViewMatrixBlock {
    mat4 viewMatrix;
};

void main()
{
    gl_Position = projection * viewMatrix * modelMatrix * vec4(position.xyz, 1.0);
    Normal = normal;
    TexCoord = texCoords;
    Color = color;
}