#version 330 core
layout (location = 0) in vec3 position;
layout (location = 1) in vec3 entityColor;

out vec3 eColor;

void main()
{
    gl_Position = vec4(position.xyz, 1.0);
    eColor = entityColor;
}