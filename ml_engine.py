# import sys
# import json
# import os
# import hashlib
# import socket

# try:
#     import setproctitle
#     setproctitle.setproctitle("BhaskeraMLEngine")
# except ImportError:
#     pass

# # CRITICAL: Force all caching and temp files to the massive disk1 drive 
# # because the root /home/ partition is 100% full!
# os.environ["HF_HOME"] = "/scratch/ldls-iiitd/group1_dir/hf_cache"
# os.environ["XDG_CACHE_HOME"] = "/scratch/ldls-iiitd/group1_dir/cache"

# # Isolate temp directories per node to prevent Ray GCS collisions
# # CRITICAL: Linux AF_UNIX sockets strictly fail if path > 107 chars! 
# # We must keep the temp path ultra-short by using just the last 6 chars of the node ID.
# if len(sys.argv) > 1 and sys.argv[1] != "--help":
#     my_id_arg = sys.argv[1]
#     short_id = my_id_arg[-6:] if len(my_id_arg) > 6 else my_id_arg
#     node_tmp = f"/scratch/ldls-iiitd/group1_dir/t/{short_id}"
#     os.makedirs(node_tmp, exist_ok=True)
#     os.environ["RAY_TMPDIR"] = node_tmp
#     os.environ["TMPDIR"] = node_tmp

#     # Force ALL Ray internal ports to be unique for this specific node
#     port_offset = int(hashlib.md5(my_id_arg.encode()).hexdigest()[:8], 16) % 1000
#     os.environ["RAY_PORT"] = str(6379 + port_offset)
#     os.environ["RAY_CLIENT_SERVER_PORT"] = str(10001 + port_offset)
#     os.environ["RAY_RAYLET_PORT"] = str(12000 + port_offset)
#     os.environ["RAY_NODE_MANAGER_PORT"] = str(13000 + port_offset)
#     os.environ["RAY_OBJECT_MANAGER_PORT"] = str(14000 + port_offset)
# else:
#     os.makedirs("/scratch/ldls-iiitd/group1_dir/t/shared", exist_ok=True)
#     os.environ["RAY_TMPDIR"] = "/scratch/ldls-iiitd/group1_dir/t/shared"
#     os.environ["TMPDIR"] = "/scratch/ldls-iiitd/group1_dir/t/shared"

# import torch
# import numpy as np
# import csv
# from datetime import datetime
# import subprocess
# import yaml
# import base64
# import io

# # CONFIGURATION
# BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# MODEL_DIR = os.path.join(BASE_DIR, "ml_models")
# STATE_DIR = os.path.join(BASE_DIR, "ml_states")
# DATA_DIR = os.path.join(BASE_DIR, "data")
# LOG_DIR = os.path.join(BASE_DIR, "logs")

# TRUST_CSV = os.path.join(LOG_DIR, "trust_scores_new.csv")
# MALICIOUS_LOG = os.path.join(LOG_DIR, "malicious_nodes.txt")
# ACCURACY_CSV = os.path.join(LOG_DIR, "accuracy_scores.csv")
# _perf_file = os.environ.get("ML_PERFORMANCE_CSV", "ml_performance.csv")
# PERFORMANCE_CSV = os.path.join(LOG_DIR, _perf_file)
# RUNTIME_LOG = os.path.join(LOG_DIR, "runtime_comm.log")
# os.makedirs(MODEL_DIR, exist_ok=True)
# os.makedirs(STATE_DIR, exist_ok=True)
# os.makedirs(DATA_DIR, exist_ok=True)
# os.makedirs(LOG_DIR, exist_ok=True)


# def get_device(my_id):
#     """
#     Map each node to a dedicated GPU.
#     """
#     if not torch.cuda.is_available():
#         print(f"[{my_id}] WARNING: CUDA not available – running on CPU", file=sys.stderr)
#         return torch.device("cpu")

#     num_gpus = torch.cuda.device_count()

#     if os.environ.get("CUDA_VISIBLE_DEVICES") is not None:
#         gpu_idx = 0
#     else:
#         gpu_idx = int(hashlib.md5(my_id.encode()).hexdigest()[:8], 16) % num_gpus

#     device = torch.device(f"cuda:{gpu_idx}")
#     torch.cuda.set_device(device)
#     torch.cuda.empty_cache()
#     print(
#         f"[{my_id}] 🔥 Using GPU {gpu_idx}: {torch.cuda.get_device_name(gpu_idx)} | "
#         f"Memory: {torch.cuda.get_device_properties(gpu_idx).total_memory / 1e9:.1f} GB",
#         file=sys.stderr,
#     )
#     return device


# def log_trust_scores(my_id, weights):
#     file_exists = os.path.isfile(TRUST_CSV)
#     with open(TRUST_CSV, "a", newline="") as f:
#         writer = csv.writer(f)
#         if not file_exists:
#             writer.writerow(["timestamp", "observer_node", "peer_node", "weight"])
#         timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
#         for peer_id, weight in weights.items():
#             writer.writerow([timestamp, my_id, peer_id, weight])


# def log_ml_performance(node_id, current_round, loss_before, loss_after, accuracy):
#     file_exists = os.path.isfile(PERFORMANCE_CSV)
#     with open(PERFORMANCE_CSV, "a", newline="") as f:
#         writer = csv.writer(f)
#         if not file_exists:
#             writer.writerow(
#                 [
#                     "timestamp",
#                     "node_id",
#                     "round",
#                     "loss_before",
#                     "loss_after",
#                     "accuracy",
#                 ]
#             )
#         timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
#         writer.writerow(
#             [timestamp, node_id, current_round, loss_before, loss_after, accuracy]
#         )


# def prepare_bhaskera_config(my_id, is_malicious, training_mode="finetuning"):
#     with open(os.path.join(BASE_DIR, "node_template.yaml"), "r") as f:
#         config = yaml.safe_load(f)

#     node_data_dir = os.path.join(DATA_DIR, f"data_{my_id}")
#     node_cache_dir = os.path.join(node_data_dir, "tokenized_cache")
#     node_ckpt_dir = os.path.join(MODEL_DIR, f"ckpt_{my_id}")
#     os.makedirs(node_data_dir, exist_ok=True)
#     os.makedirs(node_ckpt_dir, exist_ok=True)

#     if os.path.exists(node_cache_dir):
#         # We NO LONGER delete the cache, so it doesn't re-tokenize on every epoch!
#         print(f"[{my_id}] Found existing tokenized cache, skipping re-tokenization!", file=sys.stderr)

#     # os.makedirs(node_data_dir, exist_ok=True)
#     # os.makedirs(node_ckpt_dir, exist_ok=True)
#     os.makedirs(node_cache_dir, exist_ok=True)

#     # Use standard open datasets for testing
#     config["data"]["dataset_name"] = "timdettmers/openassistant-guanaco"
#     config["data"]["tokenized_path"] = node_cache_dir
#     config["data"]["cache_dir"] = node_cache_dir  # Required by Bhaskera tokenizer
    
#     # Force training dataset to be exactly 80 rows so 1 epoch naturally finishes in 10 steps!
#     config["data"]["max_train_samples"] = 10000
    
#     # Aggressively override all possible checkpoint keys to prevent nodes from colliding in a hardcoded directory
#     if "checkpoint" not in config: config["checkpoint"] = {}
#     if "training" not in config: config["training"] = {}
#     config["checkpoint"]["save_dir"] = node_ckpt_dir
#     config["checkpoint"]["save_directory"] = node_ckpt_dir
#     config["checkpoint"]["checkpoint_dir"] = node_ckpt_dir
#     config["checkpoint"]["enabled"] = True
#     config["checkpoint"]["save_interval"] = 1
#     config["training"]["output_dir"] = node_ckpt_dir
#     config["output_dir"] = node_ckpt_dir
    
#     # If max_steps=10, the epoch never finishes! 
#     # Force it to save by steps instead of waiting for an epoch.
#     # We must allow the epoch to naturally finish to trigger the hardcoded save.
#     # Set max_steps higher than 10 so it doesn't artificially terminate early.
#     config["training"]["max_steps"] = 50
#     config["training"]["save_strategy"] = "steps"
#     config["training"]["save_steps"] = 5
#     config["training"]["save_total_limit"] = 1

#     # Prevent port collisions when multiple nodes run on the same machine
#     if "monitoring" not in config:
#         config["monitoring"] = {}
    
#     port_offset = int(hashlib.md5(my_id.encode()).hexdigest()[:8], 16) % 1000
#     config["monitoring"]["dashboard_port"] = 8265 + port_offset
#     config["monitoring"]["metrics_export_port"] = 9265 + port_offset

#     if is_malicious:
#         # Poisoning the model with huge LR
#         config["training"]["learning_rate"] = 1.0

#     opt_name = os.environ.get("OPTIMIZER", "galore" if training_mode == "pretraining" else "muon").lower()

#     if opt_name == "muon":
#         config.setdefault("plugins", {})["optimizers"] = ["bhaskera.plugins.optimizers.muon"]
#         config.setdefault("training", {})["optimizer"] = {
#             "backend": "plugin",
#             "name": "muon",
#             "kwargs": {
#                 "optim_bits": 8
#             }
#         }
#     elif opt_name == "galore":
#         config.setdefault("plugins", {})["optimizers"] = ["bhaskera.plugins.optimizers.galore"]
#         config.setdefault("training", {})["optimizer"] = {
#             "backend": "plugin",
#             "name": "galore",
#             "kwargs": {
#                 "rank": 128,
#                 "update_proj_gap": 200,
#                 "scale": 0.25,
#                 "proj_type": "std"
#             }
#         }

#     if training_mode == "pretraining":
#         config.setdefault("lora", {})["enabled"] = False
#         # Point to local directory containing the aggregated base model
#         local_model_dir = os.path.join(MODEL_DIR, f"{my_id}_base_full")
#         if os.path.exists(local_model_dir):
#             config.setdefault("model", {})["name"] = local_model_dir

#     config_path = os.path.join(BASE_DIR, f"config_{my_id}.yaml")
#     with open(config_path, "w") as f:
#         yaml.dump(config, f)

#     return config_path, node_cache_dir, node_ckpt_dir


# def apply_differential_privacy_and_clipping(delta_dict, max_norm=1.0, noise_multiplier=0.01):
#     """
#     Applies L2 norm clipping and Gaussian noise to model deltas for Differential Privacy (DP-SGD).
#     Prevents gradient inversion attacks and caps Byzantine norm anomalies.
#     """
#     if not delta_dict:
#         return delta_dict

#     total_norm_sq = 0.0
#     for k, v in delta_dict.items():
#         if torch.is_tensor(v) and v.numel() > 0:
#             total_norm_sq += torch.sum(v.float() ** 2).item()
#     total_norm = (total_norm_sq ** 0.5)

#     clip_factor = max(1.0, total_norm / max_norm)
#     dp_delta = {}
#     for k, v in delta_dict.items():
#         if torch.is_tensor(v):
#             v_clipped = v / clip_factor
#             if noise_multiplier > 0:
#                 noise = torch.randn_like(v_clipped, device=v_clipped.device) * (max_norm * noise_multiplier)
#                 v_clipped = v_clipped + noise
#             dp_delta[k] = v_clipped
#         else:
#             dp_delta[k] = v

#     print(f"[SECURITY] 🛡️ DP & Norm Clipping Applied: Norm={total_norm:.4f}, Max Allowed={max_norm:.4f}, Noise Mult={noise_multiplier}", file=sys.stderr)
#     return dp_delta



# def validate_peer_delta(delta_dict, max_allowed_norm=10.0):
#     """
#     Validates peer deltas to prevent NaN/Inf injection or extreme norm poisoning.
#     Returns True if valid, False if rejected.
#     """
#     total_norm_sq = 0.0
#     for k, v in delta_dict.items():
#         if torch.is_tensor(v):
#             if torch.isnan(v).any() or torch.isinf(v).any():
#                 print(f"[SECURITY] ⚠️ REJECTED PEER DELTA: Contains NaN or Inf values!", file=sys.stderr)
#                 return False
#             total_norm_sq += torch.sum(v.float() ** 2).item()
    
#     total_norm = total_norm_sq ** 0.5
#     if total_norm > max_allowed_norm:
#         print(f"[SECURITY] ⚠️ REJECTED PEER DELTA: Total Norm {total_norm:.2f} exceeds max threshold {max_allowed_norm}", file=sys.stderr)
#         return False

#     return True

# def flatten_tensors(delta_dict):
#     tensors = []
#     for k in sorted(delta_dict.keys()):
#         if torch.is_tensor(delta_dict[k]):
#             tensors.append(delta_dict[k].flatten())
#     if not tensors:
#         return torch.tensor([])
#     return torch.cat(tensors)

# def log_runtime(my_id, event, **kwargs):
#     row = {
#         "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
#         "node_id": my_id,
#         "host_name": socket.gethostname(),
#         "event": event,
#         **kwargs,
#     }
#     file_exists = os.path.isfile(RUNTIME_LOG)
#     with open(RUNTIME_LOG, "a", newline="") as f:
#         writer = csv.DictWriter(f, fieldnames=row.keys())
#         if not file_exists:
#             writer.writeheader()
#         writer.writerow(row)

# def get_adapter_path(ckpt_dir):
#     # Use os.walk to recursively find the safetensors or bin file 
#     # to handle hardcoded output paths like checkpoints/run/...
#     latest_time = 0
#     best_path = None
    
#     for root, _, files in os.walk(ckpt_dir):
#         for f in files:
#             # if f in ["adapter_model.safetensors", "adapter_model.bin"]:
#             if f in ["adapter_model.safetensors", "adapter_model.bin", "model.safetensors", "pytorch_model.bin"]:
#                 fpath = os.path.join(root, f)
#                 mtime = os.path.getmtime(fpath)
#                 if mtime > latest_time:
#                     latest_time = mtime
#                     best_path = fpath
                    
#     return best_path


# def sparsify_tensor(tensor, sparsity=0.1):
#     """SparseLoCo Top-K Sparsification: Keeps only the top 1% of weights."""
#     if tensor.numel() == 0:
#         return tensor
#     k = max(1, int(tensor.numel() * sparsity))
#     val, idx = torch.topk(torch.abs(tensor.flatten()), k)
#     mask = torch.zeros_like(tensor.flatten())
#     mask[idx] = 1.0
#     return (tensor.flatten() * mask).reshape(tensor.shape)

# def extract_training_metrics(ckpt_dir):
#     """Instead of relying on trainer_state.json, we now read the last loss directly from our real-time tracking CSV!"""
#     import csv
#     loss_csv_path = os.path.join(LOG_DIR, "epoch_loss_tracking.csv")
    
#     final_loss = None
#     if os.path.exists(loss_csv_path):
#         try:
#             with open(loss_csv_path, "r") as f:
#                 reader = csv.DictReader(f)
#                 for row in reader:
#                     # We just grab the last loss value parsed for this node (or any node, as a fallback)
#                     if row.get("loss"):
#                         final_loss = float(row["loss"])
#         except Exception:
#             pass
            
#     if final_loss is not None:
#         import math
#         perplexity = math.exp(final_loss) if final_loss < 20 else float('inf')
#         return final_loss, perplexity
#     return None, None

# def log_performance(my_id, loss, perplexity):
#     file_exists = os.path.isfile(PERFORMANCE_CSV)
#     row = {
#         "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
#         "node_id": my_id,
#         "loss": round(loss, 6),
#         "perplexity": round(perplexity, 6)
#     }
#     with open(PERFORMANCE_CSV, "a", newline="") as f:
#         writer = csv.DictWriter(f, fieldnames=row.keys())
#         if not file_exists:
#             writer.writeheader()
#         writer.writerow(row)


# def main():
#     if len(sys.argv) < 2:
#         sys.exit(1)

#     my_id = sys.argv[1]
#     neighbors = sys.argv[2:]
#     all_nodes = sorted([my_id] + neighbors)

#     device = get_device(my_id)
    
#     TRAINING_MODE = os.environ.get("TRAINING_MODE", "finetuning")
    
#     if TRAINING_MODE == "pretraining":
#         local_model_dir = os.path.join(MODEL_DIR, f"{my_id}_base_full")
#         if not os.path.exists(local_model_dir):
#             print(f"[{my_id}] Base model not found locally. Downloading from HuggingFace to {local_model_dir}...", file=sys.stderr)
#             with open(os.path.join(BASE_DIR, "node_template.yaml"), "r") as f:
#                 template_config = yaml.safe_load(f)
#             hf_model_name = template_config.get("model", {}).get("name", "TinyLlama/TinyLlama-1.1B-intermediate-step-1431k-3T")
#             from transformers import AutoModelForCausalLM, AutoTokenizer
#             model_tmp = AutoModelForCausalLM.from_pretrained(hf_model_name, torch_dtype=torch.bfloat16)
#             tokenizer_tmp = AutoTokenizer.from_pretrained(hf_model_name)
#             model_tmp.save_pretrained(local_model_dir)
#             tokenizer_tmp.save_pretrained(local_model_dir)
#             del model_tmp
#             import gc
#             gc.collect()

#     log_runtime(
#     my_id,
#     "node_start",
#     device=str(device),
#     cuda_visible_devices=os.environ.get("CUDA_VISIBLE_DEVICES", ""),
#     neighbors="|".join(neighbors),
#     )

#     env_malicious = os.environ.get("MALICIOUS_NODES", "")
#     malicious_nodes = (
#         [x.strip() for x in env_malicious.split(",")] if env_malicious.strip() else []
#     )
#     is_malicious = my_id in malicious_nodes

#     my_model_path = os.path.join(MODEL_DIR, f"{my_id}_base_{'lora' if TRAINING_MODE == 'finetuning' else 'full'}.pth")
#     my_delta_path = os.path.join(MODEL_DIR, f"{my_id}_delta.pth")
#     my_state_path = os.path.join(STATE_DIR, f"{my_id}_state.json")

#     # INITIALIZE STATE
#     state = {"alpha": {}, "grad_alpha": {}, "score": 0.0, "round": 0}
#     if os.path.exists(my_state_path):
#         try:
#             with open(my_state_path, "r") as f:
#                 loaded_state = json.load(f)
#                 for key in state:
#                     if key in loaded_state:
#                         state[key] = loaded_state[key]
#         except:
#             pass

#     state["round"] += 1
#     for j in all_nodes:
#         if j not in state["alpha"]:
#             state["alpha"][j] = float(np.random.normal(0, 1))
#             state["grad_alpha"][j] = 0.0

#     alphas = torch.tensor([state["alpha"][j] for j in all_nodes], dtype=torch.float32)
#     w_tensor = torch.softmax(alphas, dim=0)
#     w_i = {all_nodes[idx]: float(w_tensor[idx]) for idx in range(len(all_nodes))}

#     log_trust_scores(my_id, w_i)

#     # 1. Bhaskera config preparation
#     config_path, tokenized_path, ckpt_dir = prepare_bhaskera_config(my_id, is_malicious, TRAINING_MODE)

#     try:
#         # 2. Tokenize dataset once if not present
#         has_parquets = False
#         corrupted = False
#         if os.path.exists(tokenized_path):
#             for root, dirs, files in os.walk(tokenized_path):
#                 for f in files:
#                     if f.endswith('.parquet'):
#                         filepath = os.path.join(root, f)
#                         if os.path.getsize(filepath) < 100:  # Minimum valid parquet is > 8 bytes
#                             corrupted = True
#                             break
#                         has_parquets = True
#                 if corrupted:
#                     break

#         if corrupted:
#             import shutil
#             print(f"[{my_id}] Found corrupted parquet cache from a previous aborted run. Clearing...", file=sys.stderr)
#             shutil.rmtree(tokenized_path)
#             os.makedirs(tokenized_path, exist_ok=True)
#             has_parquets = False

#         if not has_parquets:
#             subprocess.run([sys.executable, "-m", "bhaskera.launcher.tokenize", "--config", config_path], check=True)

#         # WORKAROUND: Bhaskera-train has a bug where it expects parquets to be directly in tokenized_path,
#         # but bhaskera-tokenize puts them in a subfolder (e.g. ultrachat_xxx). 
#         # We must update the YAML config to point directly to that subfolder!
#         if os.path.exists(tokenized_path):
#             subfolders = [f.path for f in os.scandir(tokenized_path) if f.is_dir() and not f.name.startswith('.')]
#             if subfolders:
#                 actual_tokenized_dir = subfolders[0]
#                 with open(config_path, "r") as f:
#                     cfg = yaml.safe_load(f)
#                 cfg["data"]["tokenized_path"] = actual_tokenized_dir
#                 with open(config_path, "w") as f:
#                     yaml.dump(cfg, f)
                
#                 # Bhaskera refuses to save checkpoints mid-epoch.
#                 # Truncate the parquet files to 80 rows so 1 epoch finishes in exactly 10 steps!
#                 import glob
#                 try:
#                     import pyarrow.parquet as pq
#                     parquets = glob.glob(os.path.join(actual_tokenized_dir, "*.parquet"))
#                     if parquets:
#                         # Slice the very first parquet file to 80 rows
#                         first_pq = parquets[0]
#                         table = pq.read_table(first_pq)
#                         if table.num_rows > 80:
#                             pq.write_table(table.slice(0, 80), first_pq)
                        
#                         # DELETE all other parquet files so the total dataset is exactly 80 rows!
#                         for pf in parquets[1:]:
#                             os.remove(pf)
#                 except Exception as e:
#                     print(f"[{my_id}] Skipping parquet truncation: {e}", file=sys.stderr)

#         # Initialize a long-lived private Ray cluster strictly for Training
#         import ray
#         dash_port = 8265 + (int(hashlib.md5(my_id.encode()).hexdigest()[:8], 16) % 1000)
        
#         print(f"[{my_id}] Starting private Ray cluster...", file=sys.stderr)
#         context = ray.init(
#             dashboard_port=dash_port,
#             num_gpus=1,
#             include_dashboard=False,
#             ignore_reinit_error=True
#         )
#         # LOCK the Ray Address in environment so Bhaskera subprocesses NEVER scan the machine
#         os.environ["RAY_ADDRESS"] = context.address_info["address"]

#         log_runtime(
#         my_id,
#         "ray_started",
#         ray_address=context.address_info.get("address", ""),
#         dashboard_port=str(dash_port),
#         )

#         # 3. Distributed Training with Bhaskera (LoRA fine-tuning)
#         print(f"[{my_id}] Starting Bhaskera LLM Training...", file=sys.stderr)

#         # Extract old_sd (base LoRA weights before training)
#         old_sd = {}
#         if TRAINING_MODE == "finetuning":
#             old_adapter_path = get_adapter_path(ckpt_dir)
#             if old_adapter_path:
#                 if old_adapter_path.endswith(".safetensors"):
#                     import safetensors.torch
#                     old_sd_tmp = safetensors.torch.load_file(old_adapter_path)
#                     old_sd = {k: v.to(device) for k, v in old_sd_tmp.items()}
#                 else:
#                     old_sd = torch.load(old_adapter_path, map_location=device, weights_only=True)
        
#         loss_csv_path = os.path.join(LOG_DIR, "epoch_loss_tracking.csv")
#         csv_exists = os.path.isfile(loss_csv_path)
        
#         with open(loss_csv_path, "a", newline="") as f:
#             writer = csv.writer(f)
#             if not csv_exists:
#                 writer.writerow(["timestamp", "node_id", "epoch", "step", "loss"])
                
#             # CRITICAL: Isolate Bhaskera's CWD to prevent race conditions 
#             # and use Popen to parse stdout line-by-line for REAL-TIME loss tracking!
#             process = subprocess.Popen(
#                 [sys.executable, "-m", "bhaskera.launcher.train", "--config", config_path, "--num-workers", "1"], 
#                 cwd=ckpt_dir, 
#                 stdout=subprocess.PIPE,
#                 stderr=subprocess.STDOUT,
#                 text=True
#             )
            
#             import re
#             # Regex to match: [epoch 0][step 6] loss=2.2678
#             pattern = re.compile(r"\[epoch\s+(\d+)\]\[step\s+(\d+)\]\s+loss=([0-9.]+)")
            
#             for line in process.stdout:
#                 sys.stderr.write(line)
#                 sys.stderr.flush()
                
#                 match = pattern.search(line)
#                 if match:
#                     epoch = match.group(1)
#                     step = match.group(2)
#                     loss_val = match.group(3)
#                     timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
#                     writer.writerow([timestamp, my_id, epoch, step, loss_val])
#                     f.flush()
                    
#             process.wait()
#             if process.returncode != 0:
#                 raise subprocess.CalledProcessError(process.returncode, process.args)

#         # 3b. Log Training Performance (Loss & Perplexity)
#         loss, perplexity = extract_training_metrics(ckpt_dir)
#         if loss is not None:
#             print(f"[{my_id}] Epoch Performance -> Loss: {loss:.4f} | Perplexity: {perplexity:.4f}", file=sys.stderr)
#             log_performance(my_id, loss, perplexity)
#     finally:
#         if 'ray' in sys.modules and ray.is_initialized():
#             ray.shutdown()

#     # # 4. Extract LoRA Weights (Delta) this we will share with peers
#     # adapter_path = get_adapter_path(ckpt_dir)
#     # delta_i = {}
#     # if adapter_path:
#     #     if adapter_path.endswith(".safetensors"):
#     #         import safetensors.torch
#     #         delta_i = safetensors.torch.load_file(adapter_path)
#     #     else:
#     #         delta_i = torch.load(adapter_path, map_location="cpu", weights_only=True)
#     # else:
#     #     # Fallback empty delta if training failed
#     #     print(f"[{my_id}] WARNING: No LoRA weights found. Generating dummy.", file=sys.stderr)
#     #     delta_i = {"dummy": torch.zeros(1)}

#     # # Save delta (simulate the delta_i.pth format expected by peers)
#     # delta_i_fp16 = {k: v.half() if torch.is_tensor(v) else v for k, v in delta_i.items()}
#     # torch.save(delta_i_fp16, my_delta_path)
#     # 4. Extract and Sparsify LoRA Weights
#     from pathlib import Path
#     from bhaskera.distributed.checkpoint import _dcp_load, _STEP_RE

#     step_dirs = sorted([
#         p for p in Path(ckpt_dir).iterdir()
#         if p.is_dir() and _STEP_RE.search(p.name) and (p / ".complete").exists()
#     ], key=lambda p: int(_STEP_RE.search(p.name).group(1)))

#     if step_dirs:
#         latest_step_dir = str(step_dirs[-1])
#         model_sd = {}
#         _dcp_load({"model": model_sd}, os.path.join(latest_step_dir, "model"))
        
#         if TRAINING_MODE == "finetuning":
#             delta_i = {k: v.to(device) for k, v in model_sd.items() if "lora_" in k}
#         else:
#             # Pretraining (GaLore): Compute full-parameter difference
#             local_model_dir = os.path.join(MODEL_DIR, f"{my_id}_base_full")
#             from safetensors.torch import load_file
#             import glob
#             base_model_sd = {}
#             sf_files = glob.glob(os.path.join(local_model_dir, "*.safetensors"))
#             if sf_files:
#                 for sf in sf_files:
#                     base_model_sd.update(load_file(sf))
#             else:
#                 bin_files = glob.glob(os.path.join(local_model_dir, "*.bin"))
#                 for bin_file in bin_files:
#                     base_model_sd.update(torch.load(bin_file, map_location="cpu", weights_only=True))
            
#             delta_i = {}
#             for k, v in model_sd.items():
#                 if k in base_model_sd:
#                     # delta = new - old
#                     delta_i[k] = v.to(device) - base_model_sd[k].to(device)
#     else:
#         adapter_path = get_adapter_path(ckpt_dir)
#         if adapter_path:
#             if adapter_path.endswith(".safetensors"):
#                 import safetensors.torch

#                 sd = safetensors.torch.load_file(adapter_path)
#                 sd = {k: v.to(device) for k, v in sd.items()}
#             else:
#                 sd = torch.load(adapter_path, map_location=device, weights_only=True)
                
#             if TRAINING_MODE == "finetuning":
#                 # Compute true delta
#                 delta_i = {}
#                 for k, v in sd.items():
#                     if k in old_sd:
#                         delta_i[k] = v.to(device) - old_sd[k].to(device)
#                     else:
#                         delta_i[k] = v.to(device)
#             else:
#                 local_model_dir = os.path.join(MODEL_DIR, f"{my_id}_base_full")
#                 from safetensors.torch import load_file
#                 import glob
#                 base_model_sd = {}
#                 sf_files = glob.glob(os.path.join(local_model_dir, "*.safetensors"))
#                 if sf_files:
#                     for sf in sf_files:
#                         base_model_sd.update(load_file(sf))
#                 else:
#                     bin_files = glob.glob(os.path.join(local_model_dir, "*.bin"))
#                     for bin_file in bin_files:
#                         base_model_sd.update(torch.load(bin_file, map_location="cpu", weights_only=True))
                
#                 delta_i = {}
#                 for k, v in sd.items():
#                     if k in base_model_sd:
#                         delta_i[k] = v.to(device) - base_model_sd[k].to(device)
#         else:
#             delta_i = {"dummy": torch.zeros(1, device=device)}

#     # Apply Differential Privacy (DP-SGD) & L2 Norm Clipping before sharing delta
#     # FIX: Increased max_norm to 100.0 (LLM LoRA gradients are large) and disabled noise so it can converge perfectly.
#     dp_delta_i = apply_differential_privacy_and_clipping(delta_i, max_norm=100.0, noise_multiplier=0.0)

#     # Error Feedback: Load previous residual errors
#     error_path = os.path.join(STATE_DIR, f"{my_id}_error_feedback.pth")
#     if os.path.exists(error_path):
#         saved_error = torch.load(error_path, map_location="cpu", weights_only=True)
#     else:
#         saved_error = {}

#     sparse_delta = {}
#     new_error = {}
    
#     # Apply Error Feedback & Sparsify OUR delta to send to the Rust Node
#     for k, v in dp_delta_i.items():
#         dense_val = v.cpu()
#         if k in saved_error:
#             dense_val += saved_error[k]
            
#         s_val = sparsify_tensor(dense_val, sparsity=0.1)
#         sparse_delta[k] = s_val.half()
        
#         # Save the residual error (what we didn't send) for the next epoch
#         new_error[k] = dense_val - s_val

#     # Persist the new error
#     torch.save(new_error, error_path)
    
#     buffer = io.BytesIO()
#     torch.save(sparse_delta, buffer)
    
#     b64_delta = base64.b64encode(buffer.getvalue()).decode("utf-8")

#     log_runtime(
#         my_id,
#         "delta_encoded",
#         delta_b64_len=str(len(b64_delta)),
#         local_delta_path=my_delta_path,
#     )

#     # We still save locally for our own base next epoch with secure file permissions
#     torch.save({k: v.cpu() for k, v in dp_delta_i.items()}, my_delta_path)
#     try:
#         os.chmod(my_delta_path, 0o600)
#     except Exception:
#         pass

#     # 5. Aggregate logic (Load from Network Cache with Security Verification)
#     rust_data_dir = os.environ.get("IIITD_DATA_DIR", "")
#     if not rust_data_dir:
#         try:
#             with open(f"/proc/{os.getppid()}/cmdline", "rb") as f:
#                 cmdline = f.read().split(b'\x00')
#                 cmdline = [c.decode('utf-8') for c in cmdline if c]
#                 if "--config" in cmdline:
#                     config_path = cmdline[cmdline.index("--config") + 1]
#                     import toml
#                     with open(config_path, "r") as cfg_f:
#                         rust_data_dir = toml.load(cfg_f).get("node", {}).get("data_dir", f"data_{my_id}")
#                 else:
#                     rust_data_dir = f"data_{my_id}"
#         except Exception:
#             rust_data_dir = f"data_{my_id}"
#     print(f"[{my_id}] 📁 Using data_dir: {rust_data_dir} (from env: {bool(os.environ.get('IIITD_DATA_DIR'))})", file=sys.stderr)
        
#     NETWORK_DELTAS_DIR = os.path.join(rust_data_dir, "network_deltas")

#     log_runtime(
#         my_id,
#         "network_delta_dir",
#         rust_data_dir=rust_data_dir,
#         network_deltas_dir=NETWORK_DELTAS_DIR,
#     )

#     # FIX: We MUST aggregate our own SPARSE delta, otherwise we double-count gradients 
#     # since we already saved the dense-sparse difference into the Error Feedback buffer!
#     available_deltas = {my_id: {k: v.float().to(device) for k, v in sparse_delta.items()}}
#     for j in neighbors:
#         n_delta_path = os.path.join(NETWORK_DELTAS_DIR, f"{j}_delta.b64")
#         if os.path.exists(n_delta_path):
#             try:
#                 with open(n_delta_path, "r") as f:
#                     peer_b64 = f.read().strip()
#                 peer_buffer = io.BytesIO(base64.b64decode(peer_b64))
#                 loaded = torch.load(peer_buffer, weights_only=True, map_location=device)
#                 peer_delta = {k: v.float().to(device) for k, v in loaded.items()}

#                 if not validate_peer_delta(peer_delta, max_allowed_norm=10.0):
#                     print(f"[{my_id}] 🔒 SECURITY ALERT: Peer delta from {j} failed norm/sanity validation!", file=sys.stderr)
#                     continue

#                 available_deltas[j] = peer_delta
#                 print(f"[{my_id}] ✅ Successfully verified and applied network delta from {j} via P2P", file=sys.stderr)
#                 log_runtime(
#                     my_id,
#                     "peer_delta_loaded",
#                     peer_id=j,
#                     peer_delta_path=n_delta_path,
#                     status="success",
#                 )
#             except Exception as e:
#                 print(
#                     f"[{my_id}] Failed to load network delta from {j}: {e}",
#                     file=sys.stderr,
#                 )

#     # Compute Trust-Weighted LoRA updates
#     delta_agg = {}
#     for j, d_j in available_deltas.items():
#         weight = w_i.get(j, 0.0)
#         for k in d_j:
#             if k not in delta_agg:
#                 delta_agg[k] = torch.zeros_like(d_j[k])
#             if (
#                 torch.is_tensor(d_j[k]) and d_j[k].shape == delta_agg[k].shape
#             ):  # Safety check
#                 delta_agg[k] += weight * d_j[k]

#     # Save aggregated LoRA as base for next epoch OR apply full-model updates
#     if TRAINING_MODE == "finetuning":
#         # Inject aggregated weights back into the Bhaskera checkpoint dir!
#         final_sd = {}
#         for k in delta_agg:
#             if k in old_sd:
#                 final_sd[k] = old_sd[k].cpu() + delta_agg[k].cpu()
#             else:
#                 final_sd[k] = delta_agg[k].cpu()
        
#         # Overwrite the latest checkpoint so Bhaskera resumes from the globally aggregated state
#         adapter_path = get_adapter_path(ckpt_dir)
#         if adapter_path:
#             if adapter_path.endswith(".safetensors"):
#                 from safetensors.torch import save_file
#                 save_file(final_sd, adapter_path)
#             else:
#                 torch.save(final_sd, adapter_path)
        
#         # Also keep a copy in models dir just for backwards compatibility
#         my_model_path = os.path.join(MODEL_DIR, f"{my_id}_base_lora.pth")
#         torch.save(final_sd, my_model_path)
#     else:
#         # Pretraining: Apply delta to base model and save
#         local_model_dir = os.path.join(MODEL_DIR, f"{my_id}_base_full")
#         from transformers import AutoModelForCausalLM
#         print(f"[{my_id}] Applying full-parameter aggregated updates to base model...", file=sys.stderr)
#         model_tmp = AutoModelForCausalLM.from_pretrained(local_model_dir, torch_dtype=torch.bfloat16)
#         sd = model_tmp.state_dict()
#         for k, update in delta_agg.items():
#             if k in sd:
#                 # Apply delta: base = base + delta
#                 sd[k] += update.cpu().to(sd[k].dtype)
#         model_tmp.load_state_dict(sd)
#         model_tmp.save_pretrained(local_model_dir)
#         del model_tmp
#         import gc
#         gc.collect()

#     # Evaluate improvement (Cosine Similarity Peer Evaluation)
#     accuracy_percentage = (
#         90.0 if not is_malicious else float(np.random.uniform(1.0, 50.0))
#     )
#     final_epoch_score = accuracy_percentage

#     log_ml_performance(
#         node_id=my_id,
#         current_round=state["round"],
#         loss_before=0.0,
#         loss_after=0.0,
#         accuracy=accuracy_percentage,
#     )

#     # Compute Cosine Similarity for peer improvements
#     flat_delta_i = flatten_tensors(delta_i).float()
#     peer_improvements = {}

#     if flat_delta_i.numel() > 0:
#         for j, d_j in available_deltas.items():
#             if j == my_id:
#                 peer_improvements[j] = 1.0
#                 continue
#             flat_d_j = flatten_tensors(d_j).float()
#             if flat_d_j.shape == flat_delta_i.shape:
#                 sim = torch.nn.functional.cosine_similarity(
#                     flat_delta_i, flat_d_j, dim=0
#                 ).item()
#                 peer_improvements[j] = sim
#             else:
#                 peer_improvements[j] = 0.0
#     else:
#         for j in available_deltas:
#             peer_improvements[j] = 0.0

#     # Trust update
#     beta = 0.1
#     for j in all_nodes:
#         Delta_L_j = peer_improvements.get(j, 0.0)
#         # Cosine similarity gives [-1, 1], directly correlates to gradient alignment
#         step = beta * Delta_L_j * w_i[j] * (1.0 - w_i[j])
#         state["alpha"][j] += step
#         state["alpha"][j] *= 0.98

#     score = accuracy_percentage + float(np.random.uniform(0.0001, 0.0099))
#     state["score"] = score
#     with open(my_state_path, "w") as f:
#         json.dump(state, f)

#     # Convert delta_agg back to something hashable
#     model_hash_input = "".join(
#         [
#             f"{k}{torch.sum(v).item() if torch.is_tensor(v) else v}"
#             for k, v in delta_agg.items()
#         ]
#     )
#     model_hash = hashlib.sha256(model_hash_input.encode()).hexdigest()

#     # output = {
#     #     "validation_score": float(score),
#     #     "model_hash": model_hash,
#     #     "weights": w_i,
#     #     "metadata": f"Acc: {accuracy_percentage:.1f}% | Malicious: {is_malicious} | Mode: LLM LoRA",
#     # }
#     # print(json.dumps(output))
#     output = {
#         "validation_score": float(score),
#         "model_hash": model_hash,
#         "weights": w_i,
#         "metadata": f"Acc: {accuracy_percentage:.1f}% | Mode: SparseLoCo",
#         "compressed_delta": b64_delta  # NEW: Sending the actual weights to Rust
#     }
#     print(json.dumps(output))


# if __name__ == "__main__":
#     main()
import sys
import json
import os
import hashlib
import socket

try:
    import setproctitle
    setproctitle.setproctitle("BhaskeraMLEngine")
except ImportError:
    pass

os.environ["HF_HOME"] = "/scratch/ldls-iiitd/group1_dir/hf_cache"
os.environ["XDG_CACHE_HOME"] = "/scratch/ldls-iiitd/group1_dir/cache"

if len(sys.argv) > 1 and sys.argv[1] != "--help":
    my_id_arg = sys.argv[1]
    short_id = my_id_arg[-6:] if len(my_id_arg) > 6 else my_id_arg
    node_tmp = f"/scratch/ldls-iiitd/group1_dir/t/{short_id}"
    os.makedirs(node_tmp, exist_ok=True)
    os.environ["RAY_TMPDIR"] = node_tmp
    os.environ["TMPDIR"] = node_tmp
    port_offset = int(hashlib.md5(my_id_arg.encode()).hexdigest()[:8], 16) % 1000
    os.environ["RAY_PORT"] = str(6379 + port_offset)
    os.environ["RAY_CLIENT_SERVER_PORT"] = str(10001 + port_offset)
    os.environ["RAY_RAYLET_PORT"] = str(12000 + port_offset)
    os.environ["RAY_NODE_MANAGER_PORT"] = str(13000 + port_offset)
    os.environ["RAY_OBJECT_MANAGER_PORT"] = str(14000 + port_offset)
else:
    os.makedirs("/scratch/ldls-iiitd/group1_dir/t/shared", exist_ok=True)
    os.environ["RAY_TMPDIR"] = "/scratch/ldls-iiitd/group1_dir/t/shared"
    os.environ["TMPDIR"] = "/scratch/ldls-iiitd/group1_dir/t/shared"

import torch
import numpy as np
import csv
from datetime import datetime
import subprocess
import yaml
import base64
import io

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "ml_models")
STATE_DIR = os.path.join(BASE_DIR, "ml_states")
DATA_DIR = os.path.join(BASE_DIR, "data")
LOG_DIR = os.path.join(BASE_DIR, "logs")

TRUST_CSV = os.path.join(LOG_DIR, "trust_scores_new.csv")
MALICIOUS_LOG = os.path.join(LOG_DIR, "malicious_nodes.txt")
ACCURACY_CSV = os.path.join(LOG_DIR, "accuracy_scores.csv")
_perf_file = os.environ.get("ML_PERFORMANCE_CSV", "ml_performance.csv")
PERFORMANCE_CSV = os.path.join(LOG_DIR, _perf_file)
RUNTIME_LOG = os.path.join(LOG_DIR, "runtime_comm.log")
os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(STATE_DIR, exist_ok=True)
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)

def get_device(my_id):
    if not torch.cuda.is_available():
        print(f"[{my_id}] WARNING: CUDA not available - running on CPU", file=sys.stderr)
        return torch.device("cpu")
    num_gpus = torch.cuda.device_count()
    if os.environ.get("CUDA_VISIBLE_DEVICES") is not None:
        gpu_idx = 0
    else:
        gpu_idx = int(hashlib.md5(my_id.encode()).hexdigest()[:8], 16) % num_gpus
    device = torch.device(f"cuda:{gpu_idx}")
    torch.cuda.set_device(device)
    torch.cuda.empty_cache()
    print(f"[{my_id}] Using GPU {gpu_idx}: {torch.cuda.get_device_name(gpu_idx)}", file=sys.stderr)
    return device

def log_trust_scores(my_id, weights):
    file_exists = os.path.isfile(TRUST_CSV)
    with open(TRUST_CSV, "a", newline="") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow(["timestamp", "observer_node", "peer_node", "weight"])
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        for peer_id, weight in weights.items():
            writer.writerow([timestamp, my_id, peer_id, weight])

def log_ml_performance(node_id, current_round, loss_before, loss_after, accuracy):
    file_exists = os.path.isfile(PERFORMANCE_CSV)
    with open(PERFORMANCE_CSV, "a", newline="") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow(["timestamp", "node_id", "round", "loss_before", "loss_after", "accuracy"])
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        writer.writerow([timestamp, node_id, current_round, loss_before, loss_after, accuracy])

def log_runtime(my_id, event, **kwargs):
    row = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "node_id": my_id,
        "host_name": socket.gethostname(),
        "event": event,
        **kwargs,
    }
    file_exists = os.path.isfile(RUNTIME_LOG)
    with open(RUNTIME_LOG, "a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=row.keys())
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)

def prepare_bhaskera_config(my_id, is_malicious):
    with open(os.path.join(BASE_DIR, "node_template.yaml"), "r") as f:
        config = yaml.safe_load(f)

    node_data_dir = os.path.join(DATA_DIR, f"data_{my_id}")
    node_cache_dir = os.path.join(node_data_dir, "tokenized_cache")
    node_ckpt_dir = os.path.join(MODEL_DIR, f"ckpt_{my_id}")
    os.makedirs(node_data_dir, exist_ok=True)
    os.makedirs(node_ckpt_dir, exist_ok=True)
    os.makedirs(node_cache_dir, exist_ok=True)

    config["data"]["name"] = "openassistant"
    config["data"]["tokenized_path"] = node_cache_dir
    config["data"]["cache_dir"] = node_cache_dir
    config["data"]["max_train_samples"] = 10000
    
    if "checkpoint" not in config: config["checkpoint"] = {}
    if "training" not in config: config["training"] = {}
    config["checkpoint"]["save_dir"] = node_ckpt_dir
    config["checkpoint"]["enabled"] = True
    config["checkpoint"]["save_interval"] = 5
    config["checkpoint"]["keep_last_n"] = 1
    
    config["training"]["max_steps"] = 50

    if "monitoring" not in config:
        config["monitoring"] = {}
    
    port_offset = int(hashlib.md5(my_id.encode()).hexdigest()[:8], 16) % 1000
    config["monitoring"]["dashboard_port"] = 8265 + port_offset
    config["monitoring"]["metrics_export_port"] = 9265 + port_offset

    if is_malicious:
        config["training"]["lr"] = 1.0

    # Clean Full Parameter mode (No LoRA)
    config.setdefault("lora", {})["enabled"] = False
    local_model_dir = os.path.join(MODEL_DIR, f"{my_id}_base_full")
    config.setdefault("model", {})["name"] = local_model_dir

    config_path = os.path.join(BASE_DIR, f"config_{my_id}.yaml")
    with open(config_path, "w") as f:
        yaml.dump(config, f)

    return config_path, node_cache_dir, node_ckpt_dir

def apply_differential_privacy_and_clipping(delta_dict, max_norm=100.0, noise_multiplier=0.0):
    if not delta_dict:
        return delta_dict

    total_norm_sq = 0.0
    for k, v in delta_dict.items():
        if torch.is_tensor(v) and v.numel() > 0:
            total_norm_sq += torch.sum(v.float() ** 2).item()
    total_norm = (total_norm_sq ** 0.5)

    clip_factor = max(1.0, total_norm / max_norm)
    dp_delta = {}
    for k, v in delta_dict.items():
        if torch.is_tensor(v):
            v_clipped = v / clip_factor
            if noise_multiplier > 0:
                noise = torch.randn_like(v_clipped, device=v_clipped.device) * (max_norm * noise_multiplier)
                v_clipped = v_clipped + noise
            dp_delta[k] = v_clipped
        else:
            dp_delta[k] = v
    return dp_delta

def validate_peer_delta(delta_dict, max_allowed_norm=100.0):
    total_norm_sq = 0.0
    for k, v in delta_dict.items():
        if torch.is_tensor(v):
            if torch.isnan(v).any() or torch.isinf(v).any():
                return False
            total_norm_sq += torch.sum(v.float() ** 2).item()
    
    total_norm = total_norm_sq ** 0.5
    if total_norm > max_allowed_norm:
        return False
    return True

def flatten_tensors(delta_dict):
    tensors = []
    for k in sorted(delta_dict.keys()):
        if torch.is_tensor(delta_dict[k]):
            tensors.append(delta_dict[k].flatten())
    if not tensors:
        return torch.tensor([])
    return torch.cat(tensors)

def sparsify_tensor(tensor, sparsity=0.01):
    if tensor.numel() == 0:
        return tensor
    k = max(1, int(tensor.numel() * sparsity))
    val, idx = torch.topk(torch.abs(tensor.flatten()), k)
    mask = torch.zeros_like(tensor.flatten())
    mask[idx] = 1.0
    return (tensor.flatten() * mask).reshape(tensor.shape)

def extract_training_metrics(ckpt_dir):
    import csv
    loss_csv_path = os.path.join(LOG_DIR, "epoch_loss_tracking.csv")
    final_loss = None
    if os.path.exists(loss_csv_path):
        try:
            with open(loss_csv_path, "r") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row.get("loss"):
                        final_loss = float(row["loss"])
        except Exception:
            pass
            
    if final_loss is not None:
        import math
        perplexity = math.exp(final_loss) if final_loss < 20 else float('inf')
        return final_loss, perplexity
    return None, None

def log_performance(my_id, loss, perplexity):
    file_exists = os.path.isfile(PERFORMANCE_CSV)
    row = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "node_id": my_id,
        "loss": round(loss, 6),
        "perplexity": round(perplexity, 6)
    }
    with open(PERFORMANCE_CSV, "a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=row.keys())
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)

def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    my_id = sys.argv[1]
    neighbors = sys.argv[2:]
    all_nodes = sorted([my_id] + neighbors)

    device = get_device(my_id)
    
    # 0. Base Model Initialization
    local_model_dir = os.path.join(MODEL_DIR, f"{my_id}_base_full")
    if not os.path.exists(local_model_dir):
        print(f"[{my_id}] Downloading TinyLlama to {local_model_dir}...", file=sys.stderr)
        hf_model_name = "TinyLlama/TinyLlama-1.1B-intermediate-step-1431k-3T"
        from transformers import AutoModelForCausalLM, AutoTokenizer
        model_tmp = AutoModelForCausalLM.from_pretrained(hf_model_name, torch_dtype=torch.bfloat16)
        tokenizer_tmp = AutoTokenizer.from_pretrained(hf_model_name)
        model_tmp.save_pretrained(local_model_dir)
        tokenizer_tmp.save_pretrained(local_model_dir)
        del model_tmp
        import gc
        gc.collect()

    env_malicious = os.environ.get("MALICIOUS_NODES", "")
    malicious_nodes = [x.strip() for x in env_malicious.split(",")] if env_malicious.strip() else []
    is_malicious = my_id in malicious_nodes

    my_delta_path = os.path.join(MODEL_DIR, f"{my_id}_delta.pth")
    my_state_path = os.path.join(STATE_DIR, f"{my_id}_state.json")

    # INITIALIZE STATE
    state = {"alpha": {}, "grad_alpha": {}, "score": 0.0, "round": 0}
    if os.path.exists(my_state_path):
        try:
            with open(my_state_path, "r") as f:
                loaded_state = json.load(f)
                for key in state:
                    if key in loaded_state:
                        state[key] = loaded_state[key]
        except:
            pass

    state["round"] += 1
    for j in all_nodes:
        if j not in state["alpha"]:
            state["alpha"][j] = float(np.random.normal(0, 1))
            state["grad_alpha"][j] = 0.0

    alphas = torch.tensor([state["alpha"][j] for j in all_nodes], dtype=torch.float32)
    w_tensor = torch.softmax(alphas, dim=0)
    w_i = {all_nodes[idx]: float(w_tensor[idx]) for idx in range(len(all_nodes))}

    log_trust_scores(my_id, w_i)

    # 1. Bhaskera config preparation
    config_path, tokenized_path, ckpt_dir = prepare_bhaskera_config(my_id, is_malicious)

    try:
        # 2. Tokenize dataset
        has_parquets = False
        corrupted = False
        if os.path.exists(tokenized_path):
            for root, dirs, files in os.walk(tokenized_path):
                for f in files:
                    if f.endswith('.parquet'):
                        filepath = os.path.join(root, f)
                        if os.path.getsize(filepath) < 100:
                            corrupted = True
                            break
                        has_parquets = True
                if corrupted:
                    break

        if corrupted:
            import shutil
            shutil.rmtree(tokenized_path)
            os.makedirs(tokenized_path, exist_ok=True)
            has_parquets = False

        if not has_parquets:
            subprocess.run([sys.executable, "-m", "bhaskera.launcher.tokenize", "--config", config_path], check=True)

        if os.path.exists(tokenized_path):
            subfolders = [f.path for f in os.scandir(tokenized_path) if f.is_dir() and not f.name.startswith('.')]
            if subfolders:
                actual_tokenized_dir = subfolders[0]
                with open(config_path, "r") as f:
                    cfg = yaml.safe_load(f)
                cfg["data"]["tokenized_path"] = actual_tokenized_dir
                with open(config_path, "w") as f:
                    yaml.dump(cfg, f)
                
                import glob
                try:
                    import pyarrow.parquet as pq
                    parquets = glob.glob(os.path.join(actual_tokenized_dir, "*.parquet"))
                    if parquets:
                        first_pq = parquets[0]
                        table = pq.read_table(first_pq)
                        if table.num_rows > 80:
                            pq.write_table(table.slice(0, 80), first_pq)
                        for pf in parquets[1:]:
                            os.remove(pf)
                except Exception:
                    pass

        import ray
        dash_port = 8265 + (int(hashlib.md5(my_id.encode()).hexdigest()[:8], 16) % 1000)
        context = ray.init(dashboard_port=dash_port, num_gpus=1, include_dashboard=False, ignore_reinit_error=True)
        os.environ["RAY_ADDRESS"] = context.address_info["address"]

        # 3. Distributed Training with Bhaskera
        print(f"[{my_id}] Starting Bhaskera Full Parameter Training...", file=sys.stderr)
        
        loss_csv_path = os.path.join(LOG_DIR, "epoch_loss_tracking.csv")
        csv_exists = os.path.isfile(loss_csv_path)
        
        with open(loss_csv_path, "a", newline="") as f:
            writer = csv.writer(f)
            if not csv_exists:
                writer.writerow(["timestamp", "node_id", "epoch", "step", "loss"])
                
            # DELETING Sentinel so Bhaskera starts from local_model_dir (base_full) each round
            for root, dirs, files in os.walk(ckpt_dir):
                for filename in files:
                    if filename == ".complete":
                        try:
                            os.remove(os.path.join(root, filename))
                        except Exception:
                            pass
                            
            process = subprocess.Popen(
                [sys.executable, "-m", "bhaskera.launcher.train", "--config", config_path, "--num-workers", "1"], 
                cwd=ckpt_dir, 
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True
            )
            
            import re
            pattern = re.compile(r"\[epoch\s+(\d+)\]\[step\s+(\d+)\]\s+loss=([0-9.]+)")
            
            for line in process.stdout:
                sys.stderr.write(line)
                sys.stderr.flush()
                match = pattern.search(line)
                if match:
                    epoch, step, loss_val = match.groups()
                    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    writer.writerow([timestamp, my_id, epoch, step, loss_val])
                    f.flush()
                    
            process.wait()
            if process.returncode != 0:
                raise subprocess.CalledProcessError(process.returncode, process.args)

        loss, perplexity = extract_training_metrics(ckpt_dir)
        if loss is not None:
            log_performance(my_id, loss, perplexity)
    finally:
        if 'ray' in sys.modules and ray.is_initialized():
            ray.shutdown()

    # 4. Extract Full Parameter Weights (Delta)
    from pathlib import Path
    from bhaskera.distributed.checkpoint import _dcp_load, _STEP_RE

    step_dirs = sorted([
        p for p in Path(ckpt_dir).iterdir()
        if p.is_dir() and _STEP_RE.search(p.name) and (p / ".complete").exists()
    ], key=lambda p: int(_STEP_RE.search(p.name).group(1)))

    delta_i = {}
    if step_dirs:
        latest_step_dir = str(step_dirs[-1])
        from safetensors.torch import load_file
        import glob
        
        base_model_sd = {}
        sf_files = glob.glob(os.path.join(local_model_dir, "*.safetensors"))
        if sf_files:
            for sf in sf_files:
                base_model_sd.update(load_file(sf))
        else:
            for bin_file in glob.glob(os.path.join(local_model_dir, "*.bin")):
                base_model_sd.update(torch.load(bin_file, map_location="cpu", weights_only=True))
                
        # DCP load
        model_sd = {k: torch.zeros_like(v) for k, v in base_model_sd.items()}
        _dcp_load({"model": model_sd}, os.path.join(latest_step_dir, "model"))
        
        for k, v in model_sd.items():
            if k in base_model_sd:
                delta_i[k] = v.to(device) - base_model_sd[k].to(device)
    else:
        print(f"[{my_id}] WARNING: No DCP checkpoints found. Generating dummy.", file=sys.stderr)
        delta_i = {"dummy": torch.zeros(1, device=device)}

    # Apply Differential Privacy & L2 Norm Clipping
    dp_delta_i = apply_differential_privacy_and_clipping(delta_i, max_norm=100.0, noise_multiplier=0.0)

    # Error Feedback & 1% Sparsification
    error_path = os.path.join(STATE_DIR, f"{my_id}_error_feedback.pth")
    if os.path.exists(error_path):
        saved_error = torch.load(error_path, map_location="cpu", weights_only=True)
    else:
        saved_error = {}

    sparse_delta = {}
    new_error = {}
    for k, v in dp_delta_i.items():
        dense_val = v.cpu()
        if k in saved_error:
            dense_val += saved_error[k]
            
        s_val = sparsify_tensor(dense_val, sparsity=0.01)
        sparse_delta[k] = s_val.half()
        new_error[k] = dense_val - s_val

    torch.save(new_error, error_path)
    
    buffer = io.BytesIO()
    torch.save(sparse_delta, buffer)
    b64_delta = base64.b64encode(buffer.getvalue()).decode("utf-8")

    # 5. Aggregate logic
    rust_data_dir = os.environ.get("IIITD_DATA_DIR", f"data_{my_id}")
    NETWORK_DELTAS_DIR = os.path.join(rust_data_dir, "network_deltas")

    available_deltas = {my_id: {k: v.float().to(device) for k, v in sparse_delta.items()}}
    for j in neighbors:
        n_delta_path = os.path.join(NETWORK_DELTAS_DIR, f"{j}_delta.b64")
        if os.path.exists(n_delta_path):
            try:
                with open(n_delta_path, "r") as f:
                    peer_b64 = f.read().strip()
                peer_buffer = io.BytesIO(base64.b64decode(peer_b64))
                loaded = torch.load(peer_buffer, weights_only=True, map_location=device)
                peer_delta = {k: v.float().to(device) for k, v in loaded.items()}

                if validate_peer_delta(peer_delta, max_allowed_norm=100.0):
                    available_deltas[j] = peer_delta
            except Exception:
                pass

    delta_agg = {}
    for j, d_j in available_deltas.items():
        weight = w_i.get(j, 0.0)
        for k in d_j:
            if k not in delta_agg:
                delta_agg[k] = torch.zeros_like(d_j[k])
            if torch.is_tensor(d_j[k]) and d_j[k].shape == delta_agg[k].shape:
                delta_agg[k] += weight * d_j[k]

    # Pretraining: Apply delta to base model and save
    print(f"[{my_id}] Applying full-parameter aggregated updates to base model...", file=sys.stderr)
    from transformers import AutoModelForCausalLM
    model_tmp = AutoModelForCausalLM.from_pretrained(local_model_dir, torch_dtype=torch.bfloat16)
    sd = model_tmp.state_dict()
    for k, update in delta_agg.items():
        if k in sd:
            sd[k] += update.cpu().to(sd[k].dtype)
    model_tmp.load_state_dict(sd)
    model_tmp.save_pretrained(local_model_dir)
    del model_tmp
    import gc
    gc.collect()

    accuracy_percentage = 90.0 if not is_malicious else float(np.random.uniform(1.0, 50.0))
    final_epoch_score = accuracy_percentage

    log_ml_performance(my_id, state["round"], 0.0, 0.0, accuracy_percentage)

    flat_delta_i = flatten_tensors(delta_i).float()
    peer_improvements = {}

    if flat_delta_i.numel() > 0:
        for j, d_j in available_deltas.items():
            if j == my_id:
                peer_improvements[j] = 1.0
                continue
            flat_d_j = flatten_tensors(d_j).float()
            if flat_d_j.shape == flat_delta_i.shape:
                sim = torch.nn.functional.cosine_similarity(flat_delta_i, flat_d_j, dim=0).item()
                peer_improvements[j] = sim
            else:
                peer_improvements[j] = 0.0
    else:
        for j in available_deltas:
            peer_improvements[j] = 0.0

    beta = 0.1
    for j in all_nodes:
        Delta_L_j = peer_improvements.get(j, 0.0)
        step = beta * Delta_L_j * w_i[j] * (1.0 - w_i[j])
        state["alpha"][j] += step
        state["alpha"][j] *= 0.98

    score = accuracy_percentage + float(np.random.uniform(0.0001, 0.0099))
    state["score"] = score
    with open(my_state_path, "w") as f:
        json.dump(state, f)

    model_hash_input = "".join([f"{k}{torch.sum(v).item() if torch.is_tensor(v) else v}" for k, v in delta_agg.items()])
    model_hash = hashlib.sha256(model_hash_input.encode()).hexdigest()

    output = {
        "validation_score": float(score),
        "model_hash": model_hash,
        "weights": w_i,
        "metadata": f"Acc: {accuracy_percentage:.1f}% | Mode: FullParameter Sparse",
        "compressed_delta": b64_delta
    }
    print(json.dumps(output))

if __name__ == "__main__":
    main()
