#version 330 core
layout (location = 0) in vec3 position;
layout (location = 1) in vec3 entityColor;
layout (location = 2) in vec2 entityTexCoord;

out vec3 eColor;
out vec2 TexCoord;

uniform mat4 transform;

void main()
{
    gl_Position = transform * vec4(position.xyz, 1.0);
    eColor = entityColor;
    TexCoord = entityTexCoord;
}