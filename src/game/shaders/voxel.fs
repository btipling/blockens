#version 330 core
out vec4 FragColor;

in vec2 TexCoord;
in vec3 barycentric;
in vec2 edge;

uniform sampler2D ourTexture;
uniform int highlight;

void main()
{
   FragColor = texture(ourTexture, TexCoord); 
}