#!/bin/bash

# Simple Jekyll development server for Cyberknight Websites corporate site

HOST="${1:-0.0.0.0}"
PORT="${2:-4000}"

echo "Starting Jekyll development server..."
echo "Host: $HOST"
echo "Port: $PORT"
echo ""
echo "Server will be accessible at:"
echo "  - http://127.0.0.1:$PORT/"
echo "  - http://localhost:$PORT/"
echo ""

bundle exec jekyll serve --host "$HOST" --port "$PORT"
