#!/bin/bash

# This script is used to setup the experiment on the cluster.

if [ -z "$WANDB_PAT" ]; then
    echo "WANDB_PAT is not set. Please set the WANDB_PAT environment variable."
    exit 1
fi

if [ -z "$BLOBFUSE_KEY" ]; then
    echo "BLOBFUSE_KEY is not set. Please set the BLOBFUSE_KEY environment variable."
    exit 1
fi

BLOBFUSE_CFG="${HOME}/fuse_connection.cfg"
BLOBFUSE_TMP="/mnt/resource/blobfusetmp"
BLOBFUSE_MNT="/mnt/lmmm-blob-data"

GIT_REPO="https://github.com/floschne/Robin.git"
GIT_REPO_DIR="${HOME}/robin"

MAMBA_ENV_NAME=robin
MAMBA_PREFIX="${HOME}/miniforge3"

setup_blobfuse() {
    if ! mountpoint -q $BLOBFUSE_MNT; then
        echo "Creating blobfuse config file at $BLOBFUSE_CFG"
        cat >$BLOBFUSE_CFG <<EOF
accountName floschne
accountKey $BLOBFUSE_KEY
containerName lmmm-blob-data
authType Key
EOF
        sudo chmod 600 $BLOBFUSE_CFG

        echo "Creating cache disk for blobfuse at $BLOBFUSE_TMP"
        sudo mkdir $BLOBFUSE_TMP -p
        sudo chown $USER $BLOBFUSE_TMP

        echo "Creating mount point for blobfuse at $BLOBFUSE_MNT"
        sudo mkdir $BLOBFUSE_MNT -p
        sudo chown $USER $BLOBFUSE_MNT

        sudo blobfuse $BLOBFUSE_MNT --tmp-path=$BLOBFUSE_TMP --config-file=$BLOBFUSE_CFG -o attr_timeout=240 -o entry_timeout=240 -o negative_timeout=120 -o allow_other
        echo "Blobfuse mounted at $BLOBFUSE_MNT"

    else
        echo "Blobfuse is already mounted at $BLOBFUSE_MNT"
    fi
    ls -lah $BLOBFUSE_MNT
}

setup_git() {
    echo "Setting up git"

    if [ -d "$GIT_REPO_DIR" ]; then
        echo "Git repo already exists at $GIT_REPO_DIR! Pulling ..."
        cd $GIT_REPO_DIR
    else
        echo "Cloning git repo $GIT_REPO to $GIT_REPO_DIR"
        git clone $GIT_REPO $GIT_REPO_DIR
    fi
}

print_python_env_info() {
    echo ""
    echo ""
    echo ""
    echo "##################### PYTHON ENV INFO START #####################"
    echo "Python version: $(python -c 'import sys; print(sys.version)')"
    echo "PyTorch version: $(python -c 'import torch; print(torch.__version__)')"
    echo "CUDA available: $(python -c 'import torch; print(torch.cuda.is_available())')"
    echo "CUDA version: $(python -c 'import torch; print(torch.version.cuda)')"
    echo "CUDA devices: $(python -c 'import torch; print(torch.cuda.device_count())')"
    echo "Flash Attention 2 Support: $(python -c 'import torch; import flash_attn_2_cuda as flash_attn_cuda; print("Yes")')"
    echo "Transformers version: $(python -c 'import transformers; print(transformers.__version__)')"
    echo "##################### PYTHON ENV INFO END #####################"
    echo ""
    echo ""
    echo ""
}

install_mamba() {
    echo "Installing mamba"
    cd
    curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
    bash Miniforge3-$(uname)-$(uname -m).sh -b
}

init_mamba() {
    # >>> conda initialize >>>
    CONDA_SETUP="${MAMBA_PREFIX}/bin/conda 'shell.bash' 'hook'"
    __conda_setup=$("$CONDA_SETUP" 2>/dev/null)
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "$MAMBA_PREFIX/etc/profile.d/conda.sh" ]; then
            . "$MAMBA_PREFIX/etc/profile.d/conda.sh"
        else
            export PATH="$MAMBA_PREFIX/bin:$PATH"
        fi
    fi
    unset __conda_setup

    if [ -f "$MAMBA_PREFIX/etc/profile.d/mamba.sh" ]; then
        . "$MAMBA_PREFIX/etc/profile.d/mamba.sh"
    fi
    # <<< conda initialize <<<
}

activate_mamba_env() {
    mamba activate $MAMBA_ENV_NAME || {
        echo "Failed to activate Conda environment"
        exit 1
    }
}

setup_env_mamba() {
    echo "Setting up python environment with mamba"

    init_mamba

    mamba create -y -n $MAMBA_ENV_NAME python=3.10

    activate_mamba_env
    mamba install nvidia/label/cuda-11.7.0::cuda-nvcc
    pip install --no-cache-dir ninja packaging
    pip install flash-attn==2.3.3 --no-build-isolation

    echo "Setting up wandb"
    wandb login $WANDB_PAT

    print_python_env_info
}

remove_env_mamba() {
    echo "Removing python environment with mamba"

    init_mamba

    mamba env remove -n $MAMBA_ENV_NAME
}

if [ $# -eq 0 ]; then
    setup_blobfuse
    setup_git
    install_mamba
    setup_env_mamba
else
    for arg in "$@"; do
        case $arg in
        "blobfuse")
            setup_blobfuse
            ;;
        "git")
            setup_git
            ;;
        "env_mamba")
            install_mamba
            setup_env_mamba
            ;;
        "env_mamba_force")
            remove_env_mamba
            setup_env_mamba
            ;;
        *)
            echo "Invalid argument: $arg"
            ;;
        esac
    done
fi

