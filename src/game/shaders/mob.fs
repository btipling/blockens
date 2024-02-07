#version 330 core
out vec4 FragColor;

in vec3 Normal;
in vec2 TexCoord;
flat in vec4 Color;

uniform sampler2D texture1;

void main()
{
   vec4 textureColor = texture(texture1, TexCoord);
   vec4 finalColor = mix(Color, textureColor, textureColor.a);
   FragColor = finalColor;
}