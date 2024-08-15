


import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';

class VoicePlayer {

  final _player = AudioPlayer();

  StreamSubscription? _playerStatus;
  // PlayerStream _streamPlayer = PlayerStream();
  var _streamPlayerStarted = false;

  final StreamController<List<int>> _audioDataController = StreamController<List<int>>.broadcast();

  VoicePlayer(){
    _playerStatus = _player.playerStateStream.listen((state){
      _log('VoicePlayer(0)....playerStateStream...tate=$state');
      if(state.processingState == ProcessingState.completed){
        _player.stop();
      }
    },onError:(e){
      _log('VoicePlayer(1)....Error...$e');
    },onDone: (){
      _log('VoicePlayer(2)....Done');
    });


    // _streamPlayer.initialize(showLogs: true);
    // _playerStatus = _streamPlayer.status.listen((status){
    //   if(status == SoundStreamStatus.Stopped){
    //   }
    //   _log('VoicePlayer(3)._streamPlayer.status.listen()...state=$status');
    // },onDone: (){
    //   _log('VoicePlayer(4)._streamPlayer.status.listen()...done()');
    // },onError: (e){
    //   _log('VoicePlayer(5)._streamPlayer.status.listen()...error(),$e');
    // });
  }


  dispose(){
    _playerStatus?.cancel();
  }
  // playSoundStream(Uint8List audioBytes)async{
  //   if(!_streamPlayerStarted){
  //     _streamPlayerStarted = true;
  //     _streamPlayer.start();
  //   }
  //   _streamPlayer.writeChunk(audioBytes);
  // }

  play(Uint8List audioBytes)async{
    if(_player.audioSource == null || _player.audioSource is! CustomStreamAudioSource){
      final source= CustomStreamAudioSource(_audioDataController.stream);
      _player.setAudioSource(source);
      _player.play();
    }
    _log('VoicePlayer.play().....${audioBytes.length}');
    _audioDataController.add(audioBytes);
  }


  void _log(String s) {
    print(s);
  }
}

class CustomStreamAudioSource extends StreamAudioSource {
  final Stream<List<int>> stream;

  CustomStreamAudioSource(this.stream);

  void _log(String s) {
    print(s);
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // Since we don't know the total length in advance, we assume the stream is infinite.
    final contentLength = await stream.length; // We don't know the total length in advance.
    final offset = start ?? 0;
    _log('CustomStreamAudioSource.request()...start=$start,end=$end,contentLength=$contentLength');

    return StreamAudioResponse(
      rangeRequestsSupported: false, // We can't support range requests.
      sourceLength: null,
      contentLength: contentLength,
      offset: offset,
      contentType: 'audio/wav', // Or another appropriate MIME type.
      stream: stream.asBroadcastStream(onListen: (data){
        _log('CustomStreamAudioSource.request.onListen()..data=${data}');
      },onCancel: (c){
        _log('CustomStreamAudioSource.request.onCancel()..data=${c}');
      }), // Wrap the stream as a broadcast stream.
    );
  }
}