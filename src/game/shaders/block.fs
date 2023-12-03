#version 330 core
out vec4 FragColor;

in vec3 eColor;

void main()
{
    FragColor = vec4(eColor, 1.0);
} 