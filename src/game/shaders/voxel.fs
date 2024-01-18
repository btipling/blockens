#version 330 core
out vec4 FragColor;

in vec3 barycentric;
in vec2 edge;
in vec3 fragPos; 
flat in vec3 fragNormal; // flat interpolation

uniform sampler2D ourTexture;

void main()
{
   // This is a fragment shader for a meshed chunk of voxels. The textures are sprites of 16x16 voxels
   // for 3 surfaces, top, sides and bottom stack down the texture. The mesh is scaled for a block type
   // into dimensions that increment the model space vertices via integers. To make the texture sprites
   // map and repeat correctly, the texture coordinates are scaled by the block type dimensions. This will
   // be done by reducing the fragPos to a 0-1 range, by removing the integer part of the position.
   // Then the texture coordinates will be manually interpolated by the fragPos.
   if (abs(fragNormal.y) > 0.5) {
      // top or bottom of voxel
      if (fragNormal.y > 0) {
         FragColor = texture(ourTexture, vec2(fract(fragPos.x), fract(fragPos.z * -1.0) * 0.333));
      } else {
         FragColor = texture(ourTexture, vec2(fract(fragPos.x), (fract(fragPos.z) * 0.333) + 0.666));
      }
   } else if (abs(fragNormal.x) > 0.5) {
      // side of voxel
      if (fragNormal.x > 0) {
         // right
         FragColor = texture(ourTexture, vec2(fract(fragPos.z), (fract(fragPos.y * -1.0) * 0.333) + 0.333));
      } else {
         // left
         FragColor = texture(ourTexture, vec2(fract(fragPos.z * -1.0), (fract(fragPos.y * -1.0) * 0.333) + 0.333));
      }
   } else {
      // front or back of voxel
      if (fragNormal.z > 0) {
         // front
         FragColor = texture(ourTexture, vec2(fract(fragPos.x), (fract(fragPos.y * -1.0) * 0.333) + 0.333));
      } else {
         // back
         FragColor = texture(ourTexture, vec2(fract(fragPos.x), (fract(fragPos.y * -1.0) * 0.333) + 0.333));
      }
   }
}