#!/bin/bash
MAMBA_ENV_NAME=robin
MAMBA_PREFIX="${HOME}/miniforge3"

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


init_mamba
activate_mamba_env
print_python_env_info

exec("$@")
