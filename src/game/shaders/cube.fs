#version 330 core
out vec4 FragColor;

in vec3 eColor;
in vec2 TexCoord;
in vec3 barycentric;
in vec2 edge;

uniform sampler2D ourTexture;

void main()
{
   
   float threshold = 0.01;
   float edgeThreshold = 0.99;
   if (barycentric.x < threshold || barycentric.y < threshold || barycentric.z < threshold) {
      if (edge.s > edgeThreshold) {
         // in this case a cyan outline
         FragColor = vec4(1.0, 0.0, 1.0, 1.0);
         return;
      } else if (edge.t > edgeThreshold ) {
         // in this case a cyan outline
         FragColor = vec4(1.0, 0.0, 1.0, 1.0);
         return;
      } else if (edge.s < threshold) {
         // in this case a cyan outline
         FragColor = vec4(1.0, 0.0, 1.0, 1.0);
         return;
      } else if (edge.t < threshold) {
         // in this case a cyan outline
         FragColor = vec4(1.0, 0.0, 1.0, 1.0);
         return;
      }
   }
   FragColor = texture(ourTexture, TexCoord) * vec4(eColor, 1.0); 
} 