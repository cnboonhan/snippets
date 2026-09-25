set -x

export CACHE_PATH="/tier2/persistent_data/boonhan"
export UV_CACHE_DIR="$CACHE_PATH/uv_cache"
export HF_HOME="$CACHE_PATH/hf_cache"
export TORCH_HOME="$CACHE_PATH/torch_cache"
export PIP_CACHE_DIR="$CACHE_PATH/pip_cache"
export TRITON_CACHE_DIR="$CACHE_PATH/triton_cache"
export TORCHINDUCTOR_CACHE_DIR="$CACHE_PATH/triton_cache/inductor"
export VLLM_CACHE_ROOT="$CACHE_PATH/triton_cache/vllm"
export CUDA_CACHE_PATH="$CACHE_PATH/triton_cache/nv"
export XDG_CACHE_HOME="$CACHE_PATH/xdg_cache"
export XDG_DATA_HOME="$CACHE_PATH/xdg_data"
export UV_PYTHON_INSTALL_DIR="$CACHE_PATH/uv_python"
export MUJOCO_PATH="$CACHE_PATH/mujoco"

set +x
export HF_TOKEN=""
