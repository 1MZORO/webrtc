import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef StreamStateCallback = void Function(MediaStream stream);
typedef ConnectionStateCallback = void Function(RTCPeerConnectionState state);

class Signaling {
  final String _serverUrl;
  final String _roomId;

  WebSocketChannel? _channel;
  RTCPeerConnection? _pc;

  MediaStream? localStream;
  StreamStateCallback? onRemoteStream;
  ConnectionStateCallback? onConnectionState;

  Signaling(this._serverUrl, this._roomId);

  final Map<String, dynamic> _pcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
  };

  Future<void> openUserMedia(RTCVideoRenderer local) async {
    localStream = await navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': true});
    local.srcObject = localStream;
    dev.log('📷 local media opened');
  }

  Future<void> connect() async {
    _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
    _channel!.stream.listen(_onMessage);
    _send({'type': 'join', 'room_id': _roomId});
    dev.log('🔌 joined room=$_roomId on $_serverUrl');
  }

  Future<void> _onMessage(dynamic raw) async {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'peer_joined':
        dev.log('👥 second peer joined — creating offer');
        await _createPeerConnection();
        final offer = await _pc!.createOffer();
        await _pc!.setLocalDescription(offer);
        _send({'type': 'offer', 'room_id': _roomId, 'payload': offer.toMap()});

      case 'offer':
        dev.log('📨 received offer — sending answer');
        await _createPeerConnection();
        await _pc!.setRemoteDescription(
            RTCSessionDescription(msg['payload']['sdp'], msg['payload']['type']));
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        _send({'type': 'answer', 'room_id': _roomId, 'payload': answer.toMap()});

      case 'answer':
        dev.log('📨 received answer — setting remote description');
        await _pc!.setRemoteDescription(
            RTCSessionDescription(msg['payload']['sdp'], msg['payload']['type']));

      case 'ice':
        final c = msg['payload'];
        await _pc!.addCandidate(RTCIceCandidate(
            c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
    }
  }

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection(_pcConfig);

    localStream?.getTracks().forEach((t) {
      dev.log('➕ adding local track: ${t.kind}');
      _pc!.addTrack(t, localStream!);
    });

    _pc!.onIceCandidate = (c) {
      if (c.candidate != null) {
        dev.log('🧊 sending ICE candidate');
        _send({'type': 'ice', 'room_id': _roomId, 'payload': c.toMap()});
      }
    };

    _pc!.onIceConnectionState = (state) {
      dev.log('🧊 ICE connection state: $state');
    };

    _pc!.onConnectionState = (state) {
      dev.log('🔗 peer connection state: $state');
      onConnectionState?.call(state);
    };

    _pc!.onTrack = (event) {
      dev.log('📥 onTrack fired — streams: ${event.streams.length}, track: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        dev.log('🎥 remote stream received — setting to renderer');
        onRemoteStream?.call(event.streams.first);
      }
    };
  }

  void _send(Map<String, dynamic> msg) =>
      _channel?.sink.add(jsonEncode(msg));

  Future<void> dispose() async {
    await _pc?.close();
    await _channel?.sink.close();
    localStream?.dispose();
  }
}
