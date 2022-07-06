ARG PYTHON_VERSION=python-3.8.8
ARG BASE_IMAGE=jupyter/scipy-notebook
FROM $BASE_IMAGE:$PYTHON_VERSION

LABEL org.opencontainers.image.source="https://github.com/MaastrichtU-IDS/jupyterlab://github.com/ccnmaastricht/jupyterlab_msb1013"

# Install yarn for handling npm packages
RUN npm install --global yarn
# Enable yarn global add:
ENV PATH="$PATH:$HOME/.yarn/bin"

# Install extensions for JupyterLab with conda and pip
# Multi conda kernels: #   https://stackoverflow.com/questions/53004311/how-to-add-conda-environment-to-jupyter-lab
RUN mamba install --quiet -y \
      openjdk=11 \
      maven \
      ipywidgets \
      ipython-sql \
      jupyterlab \
      jupyterlab-git \
      jupyterlab-lsp \
      jupyter-lsp-python \
      jupyter_bokeh \ 
      jupyterlab-drawio \
      rise \
      pyspark=$APACHE_SPARK_VERSION \
      nb_conda_kernels \
      'jupyter-server-proxy>=3.1.0' && \
    mamba install -y -c plotly 'plotly>=4.8.2'


RUN pip install --upgrade pip && \
    pip install --upgrade \
      mitosheet3 \
      jupyterlab-spreadsheet-editor \
      jupyterlab_latex \
      jupyterlab-github \
    #   pyspark==$APACHE_SPARK_VERSION \
      jupyterlab-system-monitor

RUN conda install nb_conda_kernels 

# create environment for NEURON simulation environment 
RUN conda create --name neuron_env python=$PYTHON_VERSION \ 
                  ipykernel \ 
                  numpy \ 
                  scipy \ 
                  matplotlib \ 
                  seaborn 


# Change to root user to install things
USER root

RUN apt update && \
    apt install -y curl wget unzip zsh vim htop gfortran \
        python3-dev libpq-dev libclang-dev raptor2-utils

# Install Java kernel
RUN wget -O /opt/ijava-kernel.zip https://github.com/SpencerPark/IJava/releases/download/v1.3.0/ijava-1.3.0.zip && \
    unzip /opt/ijava-kernel.zip -d /opt/ijava-kernel && \
    cd /opt/ijava-kernel && \
    python install.py --sys-prefix && \
    rm /opt/ijava-kernel.zip

# Add JupyterLab and VSCode settings
COPY jupyter_notebook_config.py /etc/jupyter/jupyter_notebook_config.py

RUN fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    fix-permissions /home/$NB_USER/.local && \
    fix-permissions /opt && \
    fix-permissions /etc/jupyter


# Switch back to the notebook user to finish installation
USER ${NB_UID}

RUN mkdir -p ~/.jupyter/lab/user-settings/@jupyterlab/terminal-extension
# COPY --chown=$NB_USER:100 plugin.jupyterlab-settings /home/$NB_USER/.jupyter/lab/user-settings/@jupyterlab/terminal-extension/plugin.jupyterlab-settings
COPY themes.jupyterlab-settings /home/$NB_USER/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/themes.jupyterlab-settings
COPY settings.json /home/$NB_USER/.local/share/code-server/User/settings.json

RUN mkdir -p /home/$NB_USER/work

# Update and compile JupyterLab extensions
# RUN jupyter labextension update --all && \
#     jupyter lab build 

# Install Oh My ZSH! and custom theme
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
RUN curl -fsSL -o ~/.oh-my-zsh/custom/themes/biratime.zsh-theme https://raw.github.com/vemonet/biratime/main/biratime.zsh-theme
RUN sed -i 's/^ZSH_THEME=".*"$/ZSH_THEME="biratime"/g' ~/.zshrc
RUN echo "\`conda config --set changeps1 false\`" >> ~/.oh-my-zsh/plugins/virtualenv/virtualenv.plugin.zsh
RUN echo 'setopt NO_HUP' >> ~/.zshrc
ENV SHELL=/bin/zsh

USER root
RUN chsh -s /bin/zsh 
USER ${NB_UID}

ADD bin/* ~/.local/bin/
# ENV PATH=$PATH:/home/$NB_USER/.local/bin

# Presets for git
RUN git config --global credential.helper 'store --file ~/.git-credentials' && \
    git config --global diff.colorMoved zebra && \
    git config --global fetch.prune true && \
    git config --global pull.rebase true


ENV WORKSPACE="/home/${NB_USER}/work"
ENV PERSISTENT_FOLDER="${WORKSPACE}/persistent"
RUN mkdir -p $PERSISTENT_FOLDER
WORKDIR ${WORKSPACE}
VOLUME [ "${PERSISTENT_FOLDER}" ]

ADD README.ipynb $WORKSPACE

CMD [ "start-notebook.sh", "--no-browser", "--ip=0.0.0.0", "--config=/etc/jupyter/jupyter_notebook_config.py" ]

# ENTRYPOINT ["jupyter", "lab", "--allow-root", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--config=/etc/jupyter/jupyter_notebook_config.py"]
