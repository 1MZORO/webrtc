import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling.dart';

void main() => runApp(const MaterialApp(home: CallPage()));

class CallPage extends StatefulWidget {
  const CallPage({super.key});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final _roomController = TextEditingController(text: 'room1');
  final _serverController = TextEditingController(text: '10.0.2.2:8080');

  Signaling? _signaling;
  bool _inCall = false;
  String _status = 'idle';

  @override
  Future<void> didChangeDependencies() async {
    super.didChangeDependencies();
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _signaling?.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final host = _serverController.text.trim();
    final s = Signaling('ws://$host/ws', _roomController.text.trim());
    s.onRemoteStream = (stream) =>
        setState(() => _remoteRenderer.srcObject = stream);
    s.onConnectionState = (state) {
      setState(() => _status = state.toString().split('.').last);
    };

    await s.openUserMedia(_localRenderer);
    await s.connect();

    setState(() {
      _signaling = s;
      _inCall = true;
    });
  }

  Future<void> _hangup() async {
    await _signaling?.dispose();
    setState(() {
      _signaling = null;
      _inCall = false;
      _status = 'idle';
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WebRTC Call — $_status')),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: RTCVideoView(_localRenderer, mirror: true)),
                Expanded(child: RTCVideoView(_remoteRenderer)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _serverController,
                    decoration: const InputDecoration(labelText: 'Server (host:port)'),
                    enabled: !_inCall,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _roomController,
                    decoration: const InputDecoration(labelText: 'Room ID'),
                    enabled: !_inCall,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _inCall ? _hangup : _join,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _inCall ? Colors.red : Colors.green,
                  ),
                  child: Text(_inCall ? 'Hang Up' : 'Join'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
