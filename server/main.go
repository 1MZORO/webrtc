package main

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
)

// Message is the signaling envelope exchanged between peers.
type Message struct {
	Type    string          `json:"type"`    // "offer" | "answer" | "ice" | "join"
	RoomID  string          `json:"room_id"` // room the peer belongs to
	Payload json.RawMessage `json:"payload"` // SDP or ICE candidate (opaque)
}

// Room holds at most two peers.
type Room struct {
	peers [2]*websocket.Conn
	mu    sync.Mutex
}

var (
	rooms    = make(map[string]*Room)
	roomsMu  sync.Mutex
	upgrader = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool { return true },
	}
)

func getOrCreateRoom(id string) *Room {
	roomsMu.Lock()
	defer roomsMu.Unlock()
	if r, ok := rooms[id]; ok {
		return r
	}
	r := &Room{}
	rooms[id] = r
	return r
}

// addPeer returns the slot index (0 or 1) or -1 if the room is full.
func (r *Room) addPeer(conn *websocket.Conn) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	for i, p := range r.peers {
		if p == nil {
			r.peers[i] = conn
			return i
		}
	}
	return -1
}

func (r *Room) removePeer(conn *websocket.Conn) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for i, p := range r.peers {
		if p == conn {
			r.peers[i] = nil
		}
	}
}

// other returns the peer that is NOT conn.
func (r *Room) other(conn *websocket.Conn) *websocket.Conn {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, p := range r.peers {
		if p != nil && p != conn {
			return p
		}
	}
	return nil
}

func handleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("upgrade:", err)
		return
	}

	var room *Room
	var slot int

	defer func() {
		conn.Close()
		if room != nil {
			room.removePeer(conn)
		}
	}()

	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			break
		}

		var msg Message
		if err := json.Unmarshal(raw, &msg); err != nil {
			log.Println("bad message:", err)
			continue
		}

		switch msg.Type {
		case "join":
			room = getOrCreateRoom(msg.RoomID)
			slot = room.addPeer(conn)
			if slot == -1 {
				conn.WriteJSON(map[string]string{"type": "error", "message": "room full"})
				return
			}
			log.Printf("peer joined room=%s slot=%d", msg.RoomID, slot)

			// Notify the other peer that someone joined so they can initiate the offer.
			if other := room.other(conn); other != nil {
				log.Printf("✅ both peers connected in room=%s — starting call", msg.RoomID)
				other.WriteJSON(map[string]string{"type": "peer_joined"})
			}

		case "offer", "answer", "ice":
			if room == nil {
				continue
			}
			if other := room.other(conn); other != nil {
				other.WriteMessage(websocket.TextMessage, raw)
			}
		}
	}
}

func main() {
	http.HandleFunc("/ws", handleWS)
	log.Println("signaling server listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
