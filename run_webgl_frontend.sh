#!/usr/bin/env bash
set -e

# ============================================================
#              CONFIGURATION (EDIT THESE ONLY)
# ============================================================
COMPOSE_FILE="docker-compose.yml"
PORT="${FRONTEND_PORT:-5173}"
URL="http://localhost:$PORT"

# ============================================================
#                    HELPER FUNCTIONS
# ============================================================

start_service() {
    echo ""
    echo "============================================"
    echo "   WebGL Immersive Navigation Framework"
    echo "============================================"
    echo ""
    echo "  Frontend:  $URL"
    echo ""
    echo "============================================"
    echo ""

    echo "Starting Docker Compose..."
    docker compose -f "$COMPOSE_FILE" up --build -d

    echo ""
    echo "Waiting for frontend to start..."

    MAX_WAIT=60
    WAITED=0
    while ! curl -s -o /dev/null -w "" "$URL" 2>/dev/null; do
        sleep 1
        WAITED=$((WAITED + 1))
        if [[ $WAITED -ge $MAX_WAIT ]]; then
            echo "Warning: Frontend did not respond within ${MAX_WAIT}s."
            echo "Check logs with: docker compose logs"
            return 1
        fi
    done

    echo "Frontend is ready!"
    echo "Opening $URL ..."
    if command -v open &>/dev/null; then
        open "$URL"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$URL"
    else
        echo "Open $URL in your browser."
    fi
    return 0
}

remove_images() {
    echo ""
    echo "Removing images..."
    IMAGE_NAME=$(docker compose -f "$COMPOSE_FILE" config --images 2>/dev/null || true)

    if [[ -n "$IMAGE_NAME" ]]; then
        echo "Found image: $IMAGE_NAME"
        docker rmi -f "$IMAGE_NAME" 2>/dev/null || true
    fi

    for IMAGE in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -i "webgl.frontend"); do
        echo "Found image: $IMAGE"
        docker rmi -f "$IMAGE" 2>/dev/null || true
    done

    echo "Images removed."
}

show_menu() {
    echo ""
    echo "=============================="
    echo "Service running at $URL"
    echo ""
    echo "  k = stop (keep image)"
    echo "  q = stop + remove image"
    echo "  v = stop + remove image + volumes"
    echo "  r = full restart (stop, remove, rebuild, relaunch)"
    echo "=============================="
}

# ============================================================
#                     START THE SERVICE
# ============================================================

start_service
show_menu

# ============================================================
#                     MAIN LOOP
# ============================================================

while true; do
    read -rp "Enter selection (k/q/v/r): " CHOICE
    CHOICE=$(printf '%s' "$CHOICE" | tr '[:upper:]' '[:lower:]')

    case "$CHOICE" in
        k)
            echo ""
            echo "Stopping containers..."
            docker compose -f "$COMPOSE_FILE" down
            echo "Done."
            exit 0
            ;;
        q)
            echo ""
            echo "Stopping containers..."
            docker compose -f "$COMPOSE_FILE" down --remove-orphans
            remove_images
            echo "Done."
            exit 0
            ;;
        v)
            echo ""
            echo "Stopping containers and removing volumes..."
            docker compose -f "$COMPOSE_FILE" down --volumes --remove-orphans
            remove_images
            echo "Done."
            exit 0
            ;;
        r)
            echo ""
            echo "=== FULL RESTART ==="
            echo "Stopping containers..."
            docker compose -f "$COMPOSE_FILE" down --remove-orphans
            remove_images
            echo ""
            start_service
            show_menu
            ;;
        *)
            echo "Invalid selection. Enter k, q, v, or r."
            ;;
    esac
done