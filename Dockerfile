FROM alpine as build
LABEL Description="Docker container for building VoxelEngine for Linux"

RUN apk update && apk add --no-cache \
    git \
    g++ \
    make \
    cmake \
    glfw-dev \
    glfw \
    glew-dev \
    glm-dev \
    libpng-dev \
    openal-soft-dev \
    luajit-dev \
    libvorbis-dev \
    curl-dev

RUN git clone https://github.com/skypjack/entt.git && \
    cd entt/build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DENTT_INSTALL=on .. && make install


RUN git clone https://luajit.org/git/luajit.git \
    && cd luajit \
    && make && make install INSTALL_INC=/usr/include/lua \
    && cd .. && rm -rf luajit

RUN git clone https://github.com/MihailRis/VoxelEngine-Cpp
RUN cd VoxelEngine-Cpp && mkdir build && cmake -DCMAKE_BUILD_TYPE=Release -B build && cmake --build  build -j 8
RUN git clone https://github.com/MihailRis/remp
RUN ls VoxelEngine-Cpp/build

FROM alpine

COPY --from=build /lib/ld-musl-x86_64.so.1 /usr/lib/libglfw.so.3 /usr/lib/libGL.so.1 /usr/lib/libopenal.so.1 /usr/lib/libGLEW.so.2.2 /usr/lib/libpng16.so.16 /usr/lib/libz.so.1 /usr/lib/libcurl.so.4 /usr/lib/libvorbisfile.so.3 /usr/lib/libluajit-5.1.so.2 /usr/lib/libstdc++.so.6 /usr/lib/libgcc_s.so.1 /lib/ld-musl-x86_64.so.1 /usr/lib/libX11.so.6 /usr/lib/libglapi.so.0 /usr/lib/libgallium-24.2.8.so /usr/lib/libdrm.so.2 /usr/lib/libxcb-glx.so.0 /usr/lib/libxcb.so.1 /usr/lib/libX11-xcb.so.1 /usr/lib/libxcb-dri2.so.0 /usr/lib/libXext.so.6 /usr/lib/libXfixes.so.3 /usr/lib/libXxf86vm.so.1 /usr/lib/libxcb-shm.so.0 /usr/lib/libexpat.so.1 /usr/lib/libxshmfence.so.1 /usr/lib/libxcb-randr.so.0 /usr/lib/libxcb-dri3.so.0 /usr/lib/libxcb-present.so.0 /usr/lib/libxcb-sync.so.1 /usr/lib/libxcb-xfixes.so.0 /usr/lib/libcares.so.2 /usr/lib/libnghttp2.so.14 /usr/lib/libidn2.so.0 /usr/lib/libpsl.so.5 /usr/lib/libssl.so.3 /usr/lib/libcrypto.so.3 /usr/lib/libzstd.so.1 /usr/lib/libbrotlidec.so.1 /usr/lib/libvorbis.so.0 /usr/lib/libogg.so.0 /usr/lib/libLLVM.so.19.1 /usr/lib/libdrm_radeon.so.1 /usr/lib/libelf.so.1 /usr/lib/libdrm_amdgpu.so.1 /usr/lib/libdrm_intel.so.1 /usr/lib/libXau.so.6 /usr/lib/libXdmcp.so.6 /usr/lib/libunistring.so.5 /usr/lib/libbrotlicommon.so.1 /usr/lib/libffi.so.8 /usr/lib/libxml2.so.2 /usr/lib/libpciaccess.so.0 /usr/lib/libbsd.so.0 /usr/lib/liblzma.so.5 /usr/lib/libmd.so.0 /usr/lib/
COPY --from=build /usr/include/lua /usr/include/lua
COPY --from=build /VoxelEngine-Cpp /VoxelEngine-Cpp
COPY --from=build /remp /VoxelEngine-Cpp/content/remp

WORKDIR /VoxelEngine-Cpp
RUN ./build/VoxelEngine --headless --script content/remp/remp_server.lua

CMD ["./build/VoxelEngine", "--headless", "--script", "content/remp/remp_server.lua"]