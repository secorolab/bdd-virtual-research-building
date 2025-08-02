FROM quay.io/jupyter/minimal-notebook:ubuntu-24.04

# --- Define Environment Variables--- #
ENV DEBIAN_FRONTEND=noninteractive \
    VENV_DIR=/home/${NB_USER}/venv \
    OMNI_KIT_ACCEPT_EULA=YES \
    OMNI_USER_CACHE_DIR=/home/${NB_USER}/.cache/ov \
    DISPLAY=:1 \
    PATH=/opt/TurboVNC/bin:$PATH

# --- Install system dependencies --- #
USER root
RUN apt update -qq && apt install -y --no-install-recommends \
        software-properties-common \
        gnupg2 \
        curl \
        wget \
        vim \
        git \
        byobu \
        net-tools \
        ca-certificates \
        apt-transport-https \
        build-essential \
        lsb-release \
        && rm -rf /var/lib/apt/lists/*

# --- Install VNC server and XFCE desktop environment --- #
RUN apt-get -y -qq update \
 && apt-get -y -qq install \
        dbus-x11 \
        tmux \
        xfce4 \
        xfce4-panel \
        xfce4-session \
        xfce4-settings \
        xorg \
        gnome-shell \
        gnome-session \
        gnome-terminal \
        xubuntu-icon-theme \
        fonts-dejavu \
        libfuse2 \
        iputils-ping \
        iproute2 \
        # Disable the automatic screenlock since the account password is unknown
        && apt-get -y -qq remove xfce4-screensaver \
        && mkdir -p /opt/install \
        && chown -R $NB_UID:$NB_GID $HOME /opt/install

# install python3.10 from deadsnakes
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.10 python3.10-venv python3.10-dev && \
    rm -rf /var/lib/apt/lists/*

# Install a VNC server, (TurboVNC)
RUN echo "Installing TurboVNC"; \
    # Install instructions from https://turbovnc.org/Downloads/YUM
    wget -q -O- https://packagecloud.io/dcommander/turbovnc/gpgkey | \
    gpg --dearmor >/etc/apt/trusted.gpg.d/TurboVNC.gpg; \
    wget -O /etc/apt/sources.list.d/TurboVNC.list https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.list; \
    apt-get -y -qq update; \
    apt-get -y -qq install turbovnc; \
    rm -rf /var/lib/apt/lists/*;

# change ownership of the cache directory
RUN mkdir -p /home/${NB_USER}/.cache && \
    chown -R ${NB_USER}:users /home/${NB_USER}/.cache

# Install VNC jupyterlab extension
USER ${NB_USER}
RUN mamba install -y websockify

# --- Install python packages --- #
RUN pip install --upgrade \
        ipywidgets \
        jupyter-resource-usage \
        jupyter-server-proxy \
        jupyterlab-git \
        jupyter-remote-desktop-proxy\
        jupyter_offlinenotebook \
        Pillow \
        rosdep \
        sidecar \
        lark \
        catkin_tools \
        colcon-common-extensions \
    && pip cache purge

# create virtualenv and install pip
RUN python3.10 -m venv $VENV_DIR && \
    $VENV_DIR/bin/python -m ensurepip && \
    $VENV_DIR/bin/pip install --upgrade pip setuptools wheel
ENV PATH="$VENV_DIR/bin:$PATH"

# Clone bdd repositories
WORKDIR /home/${NB_USER}/behave-isaac-bdd
RUN git clone https://github.com/minhnh/bdd-dsl.git && \
    git clone https://github.com/minhnh/bdd-isaacsim-exec.git && \
    git clone https://github.com/secorolab/metamodels-bdd.git && \
    git clone https://github.com/minhnh/rdf-utils.git && \
    git clone https://github.com/secorolab/models-bdd.git

# Install the packages
WORKDIR /home/${NB_USER}/behave-isaac-bdd/rdf-utils
RUN $VENV_DIR/bin/pip install -e .
WORKDIR /home/${NB_USER}/behave-isaac-bdd/bdd-dsl
RUN $VENV_DIR/bin/pip install -e .
WORKDIR /home/${NB_USER}/behave-isaac-bdd/bdd-isaacsim-exec
RUN $VENV_DIR/bin/pip install -e .

# Download the WebRTC Client AppImage
WORKDIR ${HOME}/isaacsim-webrtc-client
RUN curl -L -o webrtc-client.AppImage https://download.isaacsim.omniverse.nvidia.com/isaacsim-webrtc-streaming-client-1.0.6-linux-x64.AppImage && \
    chmod +x webrtc-client.AppImage

# Copy notebooks folder #
COPY --chown=${NB_USER}:users ./notebooks ${HOME}/notebooks

# --- Entrypoint --- #
COPY --chown=${NB_USER}:users entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["jupyter", "lab", "--allow-root", "--NotebookApp.token=''", "--no-browser", "--ip=0.0.0.0"]