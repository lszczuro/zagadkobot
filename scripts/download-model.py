import os
from huggingface_hub import snapshot_download

local_dir = "./assets/models/llm/Qwen3.5-4b-polish-riddles"
os.makedirs(local_dir, exist_ok=True)

snapshot_download(
    repo_id="lszczuro/Qwen3.5-4b-polish-riddles-GGUF",
    local_dir=local_dir,
)
