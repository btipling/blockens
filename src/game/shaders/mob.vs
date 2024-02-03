#version 330 core
layout (location = 0) in vec3 position;

out vec3 fragPos;

uniform mat4 projection;

layout(std140) uniform ViewMatrixBlock {
    mat4 viewMatrix;
};

void main()
{
    gl_Position = projection * viewMatrix * vec4(position.xyz, 1.0);
}