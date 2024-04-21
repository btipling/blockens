# blockens
 A voxel game project.

![image](https://github.com/btipling/blockens/assets/249641/710dea7c-21ed-4764-8c78-06cee476c957)

 ## Requirements
 This project is built with OpenGL 4.6 and thus will not work with MacOS until I build a backend to support that OS.

 I am developing this game using Windows 11 Pro NVDIA GeForce RTX 3060 Laptop GPU and a GeForce RTX 3070 Desktop GPU. 

 Currently using zig version 0.12.0-dev.3428+d8bb139da to build.

## Running

The project must currently be run from the projects root directory.
```
zig build run
```
Should do it. Note, lua script evals are much slower in debug builds than they are in fast release builds.

 ## Notes

 There is a very mimial default world that is created on first run. Setting up a world requires writing lua scripts
 for textures and blocks. There are a few in the src/script/lua folder to get started with. Most of chunk scripts
 assume block ids that will not match what you create.

 The order to build a world from scripts is:
 1. Create lua texture scripts in the texture editor.
 2. Configure and save blocks with texture scripts in the block editor
 3. Create lua chunk scripts in the chunk editor, the block ids have to match your block ids that will be unique to you.
 4. Save chunks in the chunk editor.
 5. Go into world editor and configure different coordinates to load your saved chunks. It's not very intuitve right now.
  - In the world editor have update the table with your options.
  - Generate the world.
  - Save the world.
  - If you save the world before you generated I think it will not save any of your changes. WIP to fix.

## More images

![image](https://github.com/btipling/blockens/assets/249641/6ba459b6-9735-43f3-9ed3-305db5a5e538)

![image](https://github.com/btipling/blockens/assets/249641/dace9cd6-d44f-4ed1-950d-a950ca85ecd0)

![blockens 4_8_2024 8_03_19 PM](https://github.com/btipling/blockens/assets/249641/1dd3cfb9-0120-4280-92b3-dba13b013aca)

![blockens 4_8_2024 8_04_38 PM](https://github.com/btipling/blockens/assets/249641/eacefa1a-93d1-4232-b869-b227271332fb)

![blockens 4_8_2024 8_07_14 PM](https://github.com/btipling/blockens/assets/249641/8b358a95-3b8a-4f3c-b919-f4a215a758e7)

![blockens 4_8_2024 8_09_31 PM](https://github.com/btipling/blockens/assets/249641/4bcde1ad-e598-46e6-bd3a-2bafbf839dc5)

![image](https://github.com/btipling/blockens/assets/249641/dd6cb670-548b-44fc-b7c0-b681e9a8376c)

![image](https://github.com/btipling/blockens/assets/249641/74770b22-e036-451f-b768-14040bd08976)

![image](https://github.com/btipling/blockens/assets/249641/4c710c3e-051a-4e39-8e6f-503817c56045)

![image](https://github.com/btipling/blockens/assets/249641/9819303a-7cb0-43d5-8f6f-8dba0f9484ce)

![image](https://github.com/btipling/blockens/assets/249641/6f0d042f-f6a0-4320-8a4a-429dc892967e)

![image](https://github.com/btipling/blockens/assets/249641/868a1585-2315-4e9d-a1a9-74192de6cf50)

