# docker run -it dockcross/windows-x64:latest /bin/bash
# docker images --digests | grep dockcross/windows-static-x64
# FROM dockcross/windows-static-x64:latest
FROM dockcross/windows-static-x64@sha256:097ef6c1f7f631fdd501adeedcfc5696d22ef69526596b57fc2778dfe87682aa

RUN mkdir -p /opt
WORKDIR /opt

# BOOST
RUN cd /usr/src/mxe &&  \
    make TARGET=x86_64-w64-mingw32.static boost bzip2_URL=force_mirror.org && \
    rm -rf /usr/src/mxe/pkg/*

# BOOST Geometry extension
RUN git clone https://github.com/boostorg/geometry && \
    cd geometry && \
    git checkout 4aa61e59a72b44fb3c7761066d478479d2dd63a0 && \
    cp -rf include/boost/geometry/extensions /usr/src/mxe/usr/x86_64-w64-mingw32.static/include/boost/geometry/. && \
    cd .. && \
    rm -rf geometry

# Ipopt 3.12.9
# http://www.coin-or.org/Ipopt/documentation/node10.html
# Command 'make test' is disabled : wine has to be used to run tests
RUN wget http://www.coin-or.org/download/source/Ipopt/Ipopt-3.12.9.tgz -O ipopt_src.tgz && \
    mkdir -p /opt/CoinIpopt && \
    mkdir -p ipopt_src && \
    tar -xf ipopt_src.tgz --strip 1 -C ipopt_src && \
    rm -rf ipopt_src.tgz && \
    cd ipopt_src && \
    cd ThirdParty/Blas && \
        ./get.Blas && \
    cd ../Lapack && \
        ./get.Lapack && \
    cd ../Mumps && \
        ./get.Mumps && \
    cd ../../ && \
    mkdir build && \
    cd build && \
    CC=/usr/src/mxe/usr/bin/x86_64-w64-mingw32.static-gcc \
    CXX=/usr/src/mxe/usr/bin/x86_64-w64-mingw32.static-g++ \
    F77=/usr/src/mxe/usr/bin/x86_64-w64-mingw32.static-gfortran \
    ../configure \
        --disable-shared \
        --prefix=/opt/CoinIpopt \
        --host=x86_64-w64-mingw32 \
        && \
    make && \
    make install && \
    cd .. && \
    cd .. && \
    rm -rf ipopt_src

RUN wget https://github.com/eigenteam/eigen-git-mirror/archive/3.3.7.tar.gz -O eigen.tgz && \
    mkdir -p /opt/eigen && \
    tar -xzf eigen.tgz --strip 1 -C /opt/eigen && \
    rm -rf eigen.tgz

RUN wget https://github.com/jbeder/yaml-cpp/archive/release-0.3.0.tar.gz -O yaml_cpp.tgz && \
    mkdir -p /opt/yaml_cpp && \
    tar -xzf yaml_cpp.tgz --strip 1 -C /opt/yaml_cpp && \
    rm -rf yaml_cpp.tgz

RUN wget https://github.com/google/googletest/archive/release-1.8.1.tar.gz -O googletest.tgz && \
    mkdir -p /opt/googletest && \
    tar -xzf googletest.tgz --strip 1 -C /opt/googletest && \
    rm -rf googletest.tgz

RUN wget https://github.com/zaphoyd/websocketpp/archive/0.7.0.tar.gz -O websocketpp.tgz && \
    mkdir -p /opt/websocketpp && \
    tar -xzf websocketpp.tgz --strip 1 -C /opt/websocketpp && \
    rm -rf websocketpp.tgz

RUN mkdir -p /opt/libf2c && \
    cd /opt/libf2c && \
    wget http://www.netlib.org/f2c/libf2c.zip -O libf2c.zip && \
    unzip libf2c.zip && \
    rm -rf libf2c.zip

RUN wget https://sourceforge.net/projects/geographiclib/files/distrib/archive/GeographicLib-1.30.tar.gz/download -O geographiclib.tgz && \
    mkdir -p /opt/geographiclib && \
    tar -xzf geographiclib.tgz --strip 1 -C /opt/geographiclib && \
    rm -rf geographiclib.tgz

RUN git clone https://github.com/google/protobuf.git protobuf_src && \
    cd protobuf_src && \
    git checkout v3.0.0-beta-2 && \
    mkdir cmake_build && \
    cd cmake_build && \
    cmake ../cmake \
        -Dprotobuf_BUILD_TESTS:BOOL=OFF \
        -Dprotobuf_BUILD_EXAMPLES:BOOL=OFF \
        -Dprotobuf_BUILD_PROTOC_BINARIES:BOOL=ON \
        -Dprotobuf_BUILD_SHARED_LIBS:BOOL=OFF \
        -Dprotobuf_WITH_ZLIB:BOOL=OFF \
        -DCMAKE_INSTALL_PREFIX=/opt/protobuf && \
    make && \
    make install && \
    cd .. && \
    cd .. && \
    rm -rf protobuf_src

RUN cd / && \
echo '\#!/bin/bash\n\
/usr/bin/wine /opt/protobuf/bin/protoc.exe `echo $*`\n'\
> /usr/bin/protoc && \
sed -i 's/\\#/#/g' /usr/bin/protoc && \
chmod 740 /usr/bin/protoc && \
cat /usr/bin/protoc

# libzmq
# Test program needs to be linked to ws_32 library.
# RUN find /usr/src/mxe/usr -name "*ws_32*" -type f && find /usr/src/mxe/usr -name "*wsock32*" -type f
# /usr/src/mxe/usr/x86_64-w64-mingw32.static/lib/libwsock32.a
RUN git clone https://github.com/zeromq/libzmq.git libzmq_src && \
    cd libzmq_src && \
    git checkout v4.2.2 && \
    mkdir build && \
    cd build && \
    cmake \
        -DWITH_PERF_TOOL=OFF \
        -DZMQ_BUILD_TESTS=OFF \
        -DENABLE_CPACK=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/libzmq \
        .. && \
    make && \
    echo "if(NOT TARGET libzmq) # in case find_package is called multiple times" >> ZeroMQConfig.cmake && \
    echo "  add_library(libzmq SHARED IMPORTED)" >> ZeroMQConfig.cmake && \
    echo "  set_target_properties(libzmq PROPERTIES IMPORTED_LOCATION \${\${PN}_LIBRARY})" >> ZeroMQConfig.cmake && \
    echo "endif(NOT TARGET libzmq)" >> ZeroMQConfig.cmake && \
    echo "" >> ZeroMQConfig.cmake && \
    echo "if(NOT TARGET libzmq-static) # in case find_package is called multiple times" >> ZeroMQConfig.cmake && \
    echo "  add_library(libzmq-static STATIC IMPORTED)" >> ZeroMQConfig.cmake && \
    echo "  set_target_properties(libzmq-static PROPERTIES IMPORTED_LOCATION \${\${PN}_STATIC_LIBRARY})" >> ZeroMQConfig.cmake && \
    echo "endif(NOT TARGET libzmq-static)" >> ZeroMQConfig.cmake && \
    make install && \
    # Patch CMake install files (Replace lib/libzmq.dll with bin\libzmq.dll)
    sed -i 's/lib\/libzmq\.dll/bin\/libzmq\.dll/g' /opt/libzmq/share/cmake/ZeroMQ/ZeroMQConfig.cmake && \
    cat /opt/libzmq/share/cmake/ZeroMQ/ZeroMQConfig.cmake && \
    cd .. && \
    cd .. && \
    rm -rf libzmq_src

RUN git clone https://github.com/zeromq/cppzmq.git cppzmq_src && \
    cd cppzmq_src && \
    git checkout v4.2.2 && \
    mkdir build && \
    cd build && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/libzmq \
        -DZeroMQ_DIR:PATH=/opt/libzmq/share/cmake/ZeroMQ \
        .. && \
    make install && \
    cd .. && \
    cd .. && \
    rm -rf cppzmq_src

RUN cd /opt && \
    git clone https://github.com/garrison/eigen3-hdf5 && \
    cd eigen3-hdf5 && \
    git checkout 2c782414251e75a2de9b0441c349f5f18fe929a2

# HDF5 with C/C++/Fortran support Version 1.8.20. Higher versions are incompatible with eigen-hdf5
RUN wget https://support.hdfgroup.org/ftp/HDF5/prev-releases/hdf5-1.8/hdf5-1.8.20/src/hdf5-1.8.20.tar.gz -O hdf5_src.tar.gz && \
    mkdir -p HDF5_SRC && \
    tar -xf hdf5_src.tar.gz --strip 1 -C HDF5_SRC && \
    cd HDF5_SRC && \
    # Patch CMakeLists.txt to avoid warning message for each compiled file
    cp CMakeLists.txt CMakeListsORI.txt && \
    awk 'NR==3{print "ADD_DEFINITIONS(-DH5_HAVE_RANDOM=0)"}1' CMakeListsORI.txt > CMakeLists.txt && \
    # diff CMakeListsORI.txt CMakeLists.txt && \
    rm CMakeListsORI.txt && \
    # Patch src/CMakeLists.txt to work with wine when running a program while configuring/compiling
    cd src && \
    cp CMakeLists.txt CMakeListsORI.txt && \
    sed -i 's/COMMAND\ \${CMD}/COMMAND wine \${CMD}/g' CMakeLists.txt && \
    # diff CMakeListsORI.txt CMakeLists.txt && \
    cd .. && \
    # Patch fortran/src/CMakeLists.txt
    cd fortran && \
    cd src && \
    cp CMakeLists.txt CMakeListsORI.txt && \
    sed -i 's/COMMAND\ \${CMD}/COMMAND wine \${CMD}/g' CMakeLists.txt && \
    # diff CMakeListsORI.txt CMakeLists.txt && \
    cd .. && \
    cd .. && \
    # Patch hl/fortran/src/CMakeLists.txt
    cd hl && \
    cd fortran && \
    cd src && \
    cp CMakeLists.txt CMakeListsORI.txt && \
    sed -i 's/COMMAND\ \${CMD}/COMMAND wine \${CMD}/g' CMakeLists.txt && \
    # diff CMakeListsORI.txt CMakeLists.txt && \
    cd .. && \
    cd .. && \
    cd .. && \
    # Move back
    cd .. && \
    mkdir -p HDF5_build && \
    cd HDF5_build && \
    cmake \
      -DCMAKE_BUILD_TYPE:STRING=Release \
      -DCMAKE_INSTALL_PREFIX:PATH=/opt/HDF5_1_8_20 \
      -DBUILD_SHARED_LIBS:BOOL=ON \
      -DBUILD_TESTING:BOOL=OFF \
      -DHDF5_BUILD_EXAMPLES:BOOL=OFF \
      -DHDF5_BUILD_HL_LIB:BOOL=ON \
      -DHDF5_BUILD_CPP_LIB:BOOL=ON \
      -DHDF5_BUILD_FORTRAN:BOOL=ON \
      ../HDF5_SRC && \
    # Patch cmake files
    # http://hdf-forum.184993.n3.nabble.com/Compilation-of-HDF5-1-10-1-with-MSYS-and-MiNGW-td4029696.html
    # sed -i 's/\r//g' H5config_f.inc && \
    # sed -i 's/\r//g' fortran/H5fort_type_defines.h && \
    make && \
    # Fixed Fortran mod install bug
    mkdir -p bin/static/Release && \
    cp bin/static/*.mod bin/static/Release/. && \
    make install && \
    cd .. && \
    rm -rf HDF5_build && \
    rm -rf HDF5_SRC && \
    rm -rf hdf5_src.tar.gz

## pandoc
#RUN wget https://github.com/jgm/pandoc/releases/download/2.1.3/pandoc-2.1.3-linux.tar.gz -O pandoc.tar.gz && \
#    mkdir pandoc_bin && \
#    cd pandoc_bin && \
#    tar -xzf ../pandoc.tar.gz --strip 1 && \
#    ls && \
#    cp bin/* /usr/bin && \
#    cd .. && \
#    rm -rf pandoc_bin pandoc.tar.gz
#
#
## Added python dependencies: numpy and matplotlib
## matplotlib also requires subprocess32 that can be installed with
## debian package manager : python-subprocess32
#RUN python -m pip install matplotlib numpy && \
#    sed -i 's/^backend .*/backend : Agg/' `python -c'import matplotlib;print(matplotlib.matplotlib_fname())'`

# ADD protoc /usr/bin/protoc
