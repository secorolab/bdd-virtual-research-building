FROM intel4coro/jupyter-ros2:humble-py3.10

# --- Define Environment Variables--- #
ENV DEBIAN_FRONTEND=noninteractive
ENV VENV_DIR=/home/${NB_USER}/venv
ENV OMNI_KIT_ACCEPT_EULA=YES
ENV OMNI_USER_CACHE_DIR=/home/${NB_USER}/.cache/ov

# --- Install basic tools --- #
USER root
RUN  apt update -q && apt install -y \
        software-properties-common \
        gnupg2 \
        curl \
        wget \
        vim \
        git \
        byobu \
        net-tools\
        ca-certificates \
        apt-transport-https \
        build-essential \
        locales \
        lsb-release

# --- Install VNC server and XFCE desktop environment --- #
USER root
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
    # Disable the automatic screenlock since the account password is unknown
 && apt-get -y -qq remove xfce4-screensaver \
 && mkdir -p /opt/install \
 && chown -R $NB_UID:$NB_GID $HOME /opt/install

# Install a VNC server, (TurboVNC)
ENV PATH=/opt/TurboVNC/bin:$PATH
RUN echo "Installing TurboVNC"; \
    # Install instructions from https://turbovnc.org/Downloads/YUM
    wget -q -O- https://packagecloud.io/dcommander/turbovnc/gpgkey | \
    gpg --dearmor >/etc/apt/trusted.gpg.d/TurboVNC.gpg; \
    wget -O /etc/apt/sources.list.d/TurboVNC.list https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.list; \
    apt-get -y -qq update; \
    apt-get -y -qq install \
        turbovnc \
    ; \
    rm -rf /var/lib/apt/lists/*;

# Install VNC jupyterlab extension
USER ${NB_USER}
RUN mamba install -y websockify
ENV DISPLAY=:1

# --- Install python packages --- #
USER ${NB_USER}
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
USER ${NB_USER}
RUN python3.10 -m venv $VENV_DIR && \
    $VENV_DIR/bin/python -m ensurepip && \
    $VENV_DIR/bin/pip install --upgrade pip setuptools wheel
ENV PATH="$VENV_DIR/bin:$PATH"

# Clone bdd repositories
USER ${NB_USER}
RUN mkdir -p /home/${NB_USER}/behave-isaac-bdd
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
USER root
RUN chown -R ${NB_USER}:users /home/${NB_USER}/.cache

# --- Install VSCode server --- #
USER ${NB_USER}
RUN conda install -y conda-forge::code-server
RUN echo 'alias code="$(which code-server)"' >> ~/.bashrc
RUN code-server --install-extension ms-python.python \
  && code-server --install-extension ms-toolsai.jupyter
RUN pip install git+https://github.com/yxzhan/jupyter-code-server.git
ENV CODE_WORKING_DIRECTORY=${HOME}/

# --- Entrypoint --- #
COPY --chown=${NB_USER}:users entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "start-notebook.sh" ]
