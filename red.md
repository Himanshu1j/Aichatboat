# Local Chat: Technical Workflow and Developer Notes

## 1. Overview

This project is a small, locally hosted, browser-based chat application. It combines:

- **Model:** Qwen2.5-1.5B-Instruct in GGUF format, quantized as `Q4_K_M`.
- **Inference runtime:** `llama.cpp`'s `llama-server`, built for CPU execution.
- **Web interface:** A single HTML page with embedded CSS and JavaScript.
- **Local web server and API proxy:** Python's standard-library HTTP server.

The browser is served at `http://127.0.0.1:8000`. The Python server forwards chat requests to the local `llama.cpp` API at `http://127.0.0.1:8081`. Both services bind to loopback, so they are intended for use on this machine.

## 2. Repository layout

```text
.
├── index.html                         # Browser UI, styles, and chat client logic
├── server.py                          # Serves index.html and proxies chat API calls
├── start.sh                           # Starts llama-server, then the Python web server
├── setup.sh                           # Downloads the model and builds llama.cpp
├── README.md                          # Short setup and usage guide
├── red.md                             # This workflow and developer reference
├── models/
│   └── qwen2.5-1.5b-instruct-q4_k_m.gguf
└── vendor/
    └── llama.cpp/                     # Upstream source and local build output
        └── build/bin/llama-server
```

The GGUF model and `vendor/llama.cpp` are generated/downloaded dependencies. They are not application source files and should not be hand-edited.

## 3. First-time setup

### Requirements

The setup script expects Linux and the following command-line tools:

- Python 3
- Git
- `curl`
- CMake
- A C/C++ compiler and build tools
- `nproc` (used to choose the build parallelism)

The model download is about 1.07 GB. Building `llama.cpp` requires additional disk space and can take several minutes, depending on the machine.

### Install steps

From the project directory, run:

```bash
./setup.sh
```

`setup.sh` performs these steps:

1. Creates `models/` and `vendor/` if needed.
2. If the expected model file is missing, downloads the Qwen GGUF from Hugging Face to a temporary `.part` file and renames it after a successful download.
3. If `llama-server` has not already been built, shallow-clones the upstream `ggml-org/llama.cpp` repository into `vendor/llama.cpp`.
4. Configures a native CPU Release build with CMake (`GGML_NATIVE=ON`, `GGML_OPENMP=ON`).
5. Builds the `llama-server` target using the available CPU cores.

The script skips a model download when the expected file exists and skips compilation when the expected executable exists. To force a fresh model download, remove the GGUF first. To rebuild llama.cpp, run `FORCE_REBUILD=1 ./setup.sh`; this removes only the generated `vendor/llama.cpp/build` directory, then configures and compiles for the current system. The model and downloaded llama.cpp source are kept.

## 4. Starting and stopping the application

Start the app with:

```bash
./start.sh
```

Then open `http://127.0.0.1:8000` in a browser. Stop both processes with **Ctrl+C** in the terminal running the script.

`start.sh` checks that both the model and compiled server exist. It then launches:

```bash
vendor/llama.cpp/build/bin/llama-server \
  -m models/qwen2.5-1.5b-instruct-q4_k_m.gguf \
  --host 127.0.0.1 --port 8081 -c 4096 -ngl 0
```

The important runtime settings are:

- `-m`: path to the GGUF model file.
- `--host 127.0.0.1 --port 8081`: local inference API address.
- `-c 4096`: context size configured for the server.
- `-ngl 0`: request zero GPU layers; this installation is configured for CPU inference.

After starting `llama-server` in the background, the script runs `python3 server.py` in the foreground. Its exit/interrupt trap terminates the model server when the Python server stops.

## 5. Model loading and request lifecycle

### Model loading

The model is not loaded by Python or by the browser. The `start.sh` command passes the GGUF path to `llama-server` using `-m`. `llama.cpp` reads the model into memory during server startup and exposes an OpenAI-compatible chat completion endpoint. The startup log reports when the model has loaded and the API is listening.

### A chat turn

1. The user types a message in `index.html` and presses Enter or clicks the send button. Shift+Enter inserts a line break.
2. Browser JavaScript appends the user message to an in-memory `history` array and sends the full conversation to `POST /v1/chat/completions` on the same origin as the page.
3. `server.py` accepts that route and forwards the JSON body to `http://127.0.0.1:8081/v1/chat/completions`.
4. `llama-server` formats the conversation for the selected model, runs inference, and returns a completion.
5. `server.py` relays the JSON response to the browser.
6. The page displays the assistant response and appends it to `history` for the next turn.

The browser currently sends `temperature: 0.7`, `max_tokens: 768`, and `stream: false`. Responses are therefore displayed after the whole completion returns rather than token-by-token.

### Other routes

- `GET /` and `GET /index.html`: return the browser UI.
- `GET /health`: return a small Python-server health response. This does not currently verify that the model server is healthy.
- Unknown routes return a JSON 404 response.
- If the llama.cpp API cannot be reached, the proxy returns a 503 response.

## 6. Which files developers should change

For normal UI and application work, the files to edit are:

| File | Change this file when… |
| --- | --- |
| `index.html` | Updating layout, styling, labels, keyboard behavior, chat history, generation options, or browser-side API interaction. The HTML, CSS, and JavaScript are all in this one file. |
| `server.py` | Changing routes, static-file serving, proxy behavior, API address, request handling, or the Python web server. |
| `start.sh` | Changing model path, llama-server command-line options, ports, or process lifecycle. |
| `setup.sh` | Changing model repository/filename, llama.cpp source, CMake configuration, or build steps. |
| `README.md` | Updating the concise instructions shown to users. |
| `red.md` | Updating this technical workflow documentation when implementation changes. |
| `.gitignore` | Updating which local/generated files Git must exclude. |

Do not edit `models/*.gguf`: these are binary model weights. Do not make routine changes directly inside `vendor/llama.cpp`: it is upstream third-party code. If upstream runtime changes are required, use a documented patch or update the upstream dependency deliberately, and update the build notes accordingly.

### Common configuration locations

- **Model file path:** `MODEL` in `start.sh` and `setup.sh`.
- **llama-server executable path:** `BIN` in `start.sh`; build output path in `setup.sh`.
- **Inference port and context size:** llama-server command in `start.sh`.
- **Python proxy destination:** `LLAMA_API` in `server.py`.
- **Python UI port:** the `ThreadingHTTPServer` bind in `server.py`.
- **Generation controls:** request JSON in the `submit()` function in `index.html`.

If any port or model path changes, update all references that depend on it and this document. The `.gitignore` file excludes the downloaded model and `vendor/` tree so source pushes stay small; see `README.md` for Git push and USB-drive setup instructions.

## 7. Current limitations

- **Small model:** 1.5B parameters is modest in capability. It can be less accurate, less reliable at complex reasoning, and more likely to miss nuance than larger hosted models.
- **Quantization:** Q4_K_M reduces memory and storage requirements, with some quality tradeoff compared with higher precision weights.
- **CPU-only configuration:** `-ngl 0` keeps inference on CPU. Response speed depends on the CPU and workload; there is no GPU acceleration configured in this build.
- **Context limit:** The server is launched with a 4096-token context. Long chat histories consume that context and can eventually be truncated or rejected by the runtime.
- **No streaming:** The browser waits for the complete response. Long generations may look inactive until the request finishes.
- **No persistent chat storage:** Conversation history is held in page memory only. Refreshing the page or choosing **New chat** clears it.
- **Single local user workflow:** There is no authentication, user management, database, or multi-user session isolation.
- **Local bind only:** Both services bind to `127.0.0.1`. This is appropriate for same-machine use but does not expose the app to other devices on a network.
- **Basic proxy:** The Python server has no production-grade request queue, rate limiting, authentication, TLS, structured logging, or cancellation handling.
- **Health check scope:** `/health` only confirms the Python server responded; it does not currently check model availability.
- **Text chat only:** The interface has no file upload, image input, audio, tools, browsing, or retrieval system.
- **Model and dependency updates are manual:** `setup.sh` uses the current upstream llama.cpp source when first cloned. It does not pin a specific commit or automatically update an existing clone.

## 8. Operational and security notes

The app is intended to run locally. Keep the loopback bindings unless you deliberately add the access controls, network exposure protections, and deployment configuration required for remote use. The chat content is sent from the browser to the local Python proxy and then to the local llama.cpp process; this app itself does not call a hosted inference API.

The initial build can fetch upstream build assets as part of CMake configuration. Setup therefore requires network access for the initial source/model downloads and any upstream assets that the build process fetches.

## 9. Quick troubleshooting

- **`llama-server missing` or `Model missing`:** Run `./setup.sh` from the project directory and resolve any download/build errors.
- **Port bind error:** Another process may be using port 8000 or 8081. Stop that process or update the relevant bind setting in `server.py`/`start.sh` consistently.
- **Chat returns a connection error:** Confirm both services are still running in the terminal. The model server must listen on port 8081, and the Python app must be available on port 8000.
- **Slow first response:** The model runs locally on CPU and may take time to process the prompt and produce tokens.
- **Need a clean build:** Remove `vendor/llama.cpp/build` and rerun `./setup.sh`. The existing model file will be retained.

