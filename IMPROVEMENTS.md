# WebRTC Production Improvements

## Phase 1: Essential Features (1-2 weeks)

### 1. Call Controls
```dart
// Add to signaling.dart
void toggleAudio() {
  localStream?.getAudioTracks().forEach((track) {
    track.enabled = !track.enabled;
  });
}

void toggleVideo() {
  localStream?.getVideoTracks().forEach((track) {
    track.enabled = !track.enabled;
  });
}

Future<void> switchCamera() async {
  await Helper.switchCamera(localStream!.getVideoTracks()[0]);
}
```

### 2. Connection State Monitoring
```dart
// Show connection quality
_pc!.onIceConnectionState = (state) {
  switch (state) {
    case RTCIceConnectionState.RTCIceConnectionStateConnected:
      // Show "Connected" badge
    case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
      // Show "Reconnecting..."
    case RTCIceConnectionState.RTCIceConnectionStateFailed:
      // Show error, offer to retry
  }
};
```

### 3. Secure Signaling
```go
// Use WSS instead of WS
// Add TLS certificates
http.ListenAndServeTLS(":8443", "cert.pem", "key.pem", nil)
```

### 4. Authentication
```go
// Add JWT token validation
type Message struct {
    Type    string `json:"type"`
    Token   string `json:"token"`  // Add this
    RoomID  string `json:"room_id"`
    Payload json.RawMessage `json:"payload"`
}
```

## Phase 2: Reliability (2-3 weeks)

### 5. Reconnection Logic
```dart
_pc!.onIceConnectionState = (state) async {
  if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
    await Future.delayed(Duration(seconds: 2));
    await _pc!.restartIce(); // Attempt reconnect
  }
};
```

### 6. Better Error Handling
```dart
try {
  await s.connect();
} on WebSocketException catch (e) {
  showDialog(context, "Can't reach server");
} on PlatformException catch (e) {
  showDialog(context, "Camera/mic permission denied");
}
```

### 7. Network Quality Monitoring
```dart
_pc!.getStats().then((stats) {
  stats.forEach((report) {
    if (report.type == 'inbound-rtp') {
      // Check packetsLost, jitter, bytesReceived
      // Show quality indicator (good/medium/poor)
    }
  });
});
```

## Phase 3: Scale & Features (3-4 weeks)

### 8. Group Calls (SFU Architecture)
- Replace peer-to-peer with Selective Forwarding Unit
- Use mediasoup or Janus server
- Each peer sends once, server forwards to all

### 9. Recording
```dart
// Use flutter_screen_recording or platform channels
await FlutterScreenRecording.startRecordScreen("call_recording");
```

### 10. Push Notifications
- Firebase Cloud Messaging for incoming calls
- Show call UI even when app is closed

### 11. Database Persistence
```go
// Store call history, user status
db.Exec("INSERT INTO calls (room_id, started_at, participants) VALUES (?, ?, ?)")
```

### 12. TURN Server (Self-hosted)
```bash
# Install coturn
sudo apt install coturn

# Configure /etc/turnserver.conf
listening-port=3478
realm=yourdomain.com
user=username:password
```

## Phase 4: Advanced (4+ weeks)

### 13. Adaptive Bitrate
```dart
// Adjust quality based on network
final constraints = {
  'video': {
    'width': networkQuality == 'good' ? 1280 : 640,
    'height': networkQuality == 'good' ? 720 : 480,
  }
};
```

### 14. Noise Cancellation
- Use WebRTC's built-in AEC/NS (already enabled)
- Add Krisp.ai or similar for advanced noise removal

### 15. Virtual Backgrounds
- Use TensorFlow Lite for background segmentation
- Replace background in video frames

### 16. Screen Sharing
```dart
final stream = await navigator.mediaDevices.getDisplayMedia({
  'video': true,
});
// Replace video track with screen track
```

### 17. End-to-End Encryption
```dart
// Use Insertable Streams API
_pc!.getSenders().forEach((sender) {
  sender.transform = RTCRtpScriptTransform(
    // Custom encryption worker
  );
});
```

## Quick Priority List

**Must Have (Week 1):**
1. Mute/unmute buttons
2. Camera switch
3. Hang up properly cleans up resources
4. Show connection state

**Should Have (Week 2-3):**
5. Reconnection on network drop
6. WSS with proper certificates
7. User authentication
8. Error messages in UI

**Nice to Have (Month 2):**
9. Call history/logs
10. Network quality indicator
11. Recording
12. Push notifications for incoming calls

**Future:**
13. Group calls (requires SFU server)
14. Screen sharing
15. Virtual backgrounds
16. E2E encryption
