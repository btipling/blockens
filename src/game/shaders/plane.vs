#version 330 core
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 entityTexCoord;
layout (location = 2) in vec4 entityColor;

out vec4 eColor;

uniform mat4 transform;
uniform mat4 projection;

void main()
{
    gl_Position = projection * transform * vec4(position.xyz, 1.0);
    eColor = entityColor;
}