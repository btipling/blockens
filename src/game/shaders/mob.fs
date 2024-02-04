#version 330 core
out vec4 FragColor;

in vec3 Normal;
in vec2 TexCoord;
flat in vec4 Color;

uniform sampler2D ourTexture;

void main()
{
   FragColor = Color;
}