# Ubuntu 기반 (리눅스 표준 환경)
FROM ubuntu:22.04

# 기본 설정
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 필수 패키지 설치
RUN apt-get update && apt-get install -y \
    # 개발 도구
    build-essential \
    gcc \
    g++ \
    make \
    gdb \
    valgrind \
    # 쉘 및 유틸리티
    bash \
    zsh \
    vim \
    nano \
    git \
    curl \
    wget \
    # 디버깅 및 분석 도구
    strace \
    ltrace \
    lsof \
    procps \
    # 기타 유용한 도구
    man-db \
    manpages-dev \
    sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 작업 디렉토리 설정
WORKDIR /workspace

# 기본 사용자 설정 (root가 아닌 사용자로 작업)
RUN useradd -m -s /bin/bash -G sudo vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 기본 사용자로 전환
USER vscode

# 쉘 환경 설정
RUN echo 'export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ~/.bashrc

# 컨테이너를 계속 실행 상태로 유지
CMD ["sleep", "infinity"]
