#!/bin/bash
cd "$(dirname "$0")/../agent"
source .venv/bin/activate
uvicorn server:app --reload --host 127.0.0.1 --port 8000
