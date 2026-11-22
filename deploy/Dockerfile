# OpenWrt x86-64 固件编译容器（与 CI 的 ubuntu-22.04 + 同套包对齐）
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ccache ecj fastjar file g++ gawk \
        gettext git java-propose-classpath libelf-dev libncurses5-dev libncursesw5-dev \
        libssl-dev python3 python3-distutils python3-pyelftools python3-setuptools \
        rsync subversion swig time xsltproc zlib1g-dev p7zip-full jq wget curl unzip \
        qemu-utils \
    && rm -rf /var/lib/apt/lists/*

# OpenWrt 禁止 root 编译，容器内固定 builder(1000) 用户
RUN useradd -m -u 1000 builder
USER builder
WORKDIR /build

CMD ["bash"]
