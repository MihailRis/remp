# REMP

**Re**translator **m**ulti**p**layer demo implementation for [VoxelCore](github.com/MihailRis/VoxelEngine-Cpp/).

**Status:** in-development

**Synchronized:**
- chat
- players movement
- placing/breaking/interactions for blocks

**In-development:**
- synchronize:
  - chunks
  - day time
  - player selected item

## Starting server

To start the server run following command:

```sh
$ VoxelCore --headless --script path/to/remp/remp_server.lua
```

Script will generate a server configuration. You will see message `Configuration generated. See "config:remp/config.toml"`.

File contains server settings including port.

Re-execute command to finally start the server.

## Connecting to server

Add pack to one of content sources (~/.voxeng/content (working directory) or res/content).

Start the VoxelCore and open `Scripts` main menu page.

![image](https://github.com/user-attachments/assets/9dcdb8b8-9e02-4f9a-aa93-d561e15928fb)

Click to `client` script.

![image](https://github.com/user-attachments/assets/983eebd6-3683-4601-a8cb-066abd3d3867)

Fill in the `IP` and `Username` fields and click `Connect`.
