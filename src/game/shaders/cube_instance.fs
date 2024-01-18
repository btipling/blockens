#version 330 core
out vec4 FragColor;

in vec3 eColor;
in vec2 TexCoord;
in vec3 barycentric;
in vec2 edge;

uniform sampler2D ourTexture;
uniform int highlight;

void main()
{
   // float threshold = 0.01;
   // float edgeThreshold = 0.99;
   // vec4 outlineColor = vec4(0.0, 0.0, 0.0, 1.0);
   // if (highlight == 1) {
   //    outlineColor = vec4(1.0, 1.0, 1.0, 1.0);
   // }

   // if (barycentric.x < threshold || barycentric.y < threshold || barycentric.z < threshold) {
   //    if (edge.s > edgeThreshold) {
   //       FragColor = outlineColor;
   //       return;
   //    } else if (edge.t > edgeThreshold ) {
   //       FragColor = outlineColor;
   //       return;
   //    } else if (edge.s < threshold) {
   //       FragColor = outlineColor;
   //       return;
   //    } else if (edge.t < threshold) {
   //       FragColor = outlineColor;
   //       return;
   //    }
   // }
   // if (highlight == 1) {
   //    FragColor = texture(ourTexture, TexCoord) * vec4(1.5, 1.5, 1.5, 1.0);
   //    return;
   // }
   FragColor = texture(ourTexture, TexCoord) * vec4(eColor, 1.0); 
} 