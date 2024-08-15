
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_example/voice_player.dart';
class TestWebSocket extends StatefulWidget{
  const TestWebSocket({super.key});

  @override
  State<TestWebSocket> createState() => _TestWebSocketState();
}

class _TestWebSocketState extends State<TestWebSocket> {
  WebSocket? nlsSocket;
  final _voicePlayer = VoicePlayer();
  var _taskId = '';
  var tempToken = '142eeb8638e648e3ab5d2b2e5d641c3f';
  var textToPlay = 'This behavior is subject to change. It is recommended that app developers double check whether the requested max input size is in reasonable range.';
  final appKey = 'q7xK62NKNuYr5gWm';
  final appNameSpace = 'FlowingSpeechSynthesizer';
  final cmdStart = 'StartSynthesis';
  final cmdRun = 'RunSynthesis';

  //StopSynthesis指令要求服务端停止语音合成，并且合成所有缓存文本。
  final cmdStop = 'StopSynthesis';

  //返回一个session_id  客户端请求时传入session_id的话则原样返回，否则由服务端自动生成32位唯一ID。
  static const eventStart = 'SynthesisStarted';

  //SentenceBegin事件表示服务端检测到了一句话的开始。
  static const eventBegin = 'SentenceBegin';
  static const nlsEventBegin = 20000;

  //SentenceSynthesis事件表示有新的合成结果返回，包含最新的音频和时间戳，句内全量，句间增量。
  static const eventRun = 'SentenceSynthesis';

  //SentenceEnd事件表示服务端检测到了一句话的结束，返回该句的全量时间戳。
  static const eventEnd = 'SentenceEnd';
  static const nlsEventEnd = 20001;
  static const nlsEventCompleted = 20002;

  //SynthesisCompleted事件表示服务端已停止了语音合成并且所有音频数据下发完毕。
  static const eventCompleted = 'SynthesisCompleted';
  static const eventTaskFailed = 'TaskFailed';

  //回调事件成功status
  final eventSuccessCode = 20000000;
  var _nlsStared = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _voicePlayer.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Text(textToPlay),
            TextButton(onPressed: _playText, child: Text("Play")),
          ],),
        ),
      ),
    );
  }

  void _initWebSocket()async {
    _taskId = generateUUID();
    nlsSocket = await WebSocket.connect(
      'wss://nls-gateway.aliyuncs.com/ws/v1',
      headers: {'X-NLS-Token': tempToken},
    );
    _log('_initWebSocket()...nlsSocket.hashCode=${nlsSocket?.hashCode},readyState=${nlsSocket?.readyState}');
    nlsSocket!.listen((data) async{
      if (data is String) {
        _log('nls.text2audio.callback()...data=$data');
        var dataMap = json.decode(data);
        _checkData(dataMap['header']);
      } else if (data is Uint8List) {
        _log('nls.text2audio.callback()...play audio bytes,data=${data.length}');
        _voicePlayer.play(data);
      }
    });
    text2audio('', false);
  }

  text2audio(String text, end) async {
    if(_isEmpty(text) && !end){
      text = ' ';
    }
    Map payload;
    String name;

    if (end) {
      name = cmdStop;
      payload = {};
    } else if (_nlsStared) {
      name = cmdRun;
      payload = {'text': text};
    } else {
      name = cmdStart;
      payload = {
        "voice": "loongstella",
        "format": "wav",
        "sample_rate": 16000,
        "volume": 50,
        "speech_rate": 100,
        "pitch_rate": 0,
        "enable_phoneme_timestamp": true,
        "enable_subtitle": true
      };
    }

    var header = {
      "message_id": generateUUID(),
      "task_id": _taskId,
      "namespace": appNameSpace,
      "name": name,
      "appkey": appKey
    };

    _log(
        'nls.text2audio.sendMsg()...text=$text,end=$end,task_id=$_taskId,socket=$nlsSocket,header=$header,payload=$payload');
    if (end) {
      nlsSocket?.add(json.encode({"header": header}));
    } else {
      nlsSocket?.add(json.encode({"header": header, "payload": payload}));
    }
  }

  void _playText() {
    if(!_nlsStared){
      _initWebSocket();
      return;
    }
    var texts = textToPlay.split(' ');
    for(int i=0;i<texts.length;i++){
      _log('index=$i,text=[${texts[i]}]');
      text2audio(texts[i], false);
    }
    text2audio('', true);
  }

  String generateUUID() {
    var d = DateTime.now().millisecondsSinceEpoch;
    var d2 = (DateTime.now().microsecond / 1000.0).floor();
    return 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'.replaceAllMapped(
      RegExp(r'[xy]'),
          (match) {
        var r = Random().nextInt(16); // random number between 0 and 15
        int source;
        if (d > 0) {
          r = (d + r) % 16;
          d = d ~/ 16;
          source = d;
        } else {
          r = (d2 + r) % 16;
          d2 = d2 ~/ 16;
          source = d2;
        }
        if (match.group(0) == 'x') {
          return r.toRadixString(16);
        } else {
          return (r & 0x3 | 0x8).toRadixString(16);
        }
      },
    );
  }

  bool _isEmpty(String? text) => text ==null || text.isEmpty;

  void _log(String s) {
    print(s);
  }

  void _checkData(dataMap,)async {
    var name = dataMap['name'];
    var messageId = dataMap['message_id'];
    var status = dataMap['status'];
    var success = status == eventSuccessCode;
    _log('nls.checkData.name=$name,$dataMap');
    switch (name) {
      case eventStart:
        if (success) {

        } else {
          _log(' 建立socket失败,status=$status,status_text=${dataMap['status_text']}',);
        }
        _nlsStared = true;
        _playText();
        break;
      case eventBegin:
        break;
      case eventEnd:
        break;
      case eventRun:
        break;
      case eventTaskFailed:
        nlsSocket?.close();
        nlsSocket = null;
        _nlsStared = false;
        _log('nls._checkData.eventTaskFailed stop()');
        // text2audio(aliToken, msgId, '', false);
        break;
      case eventCompleted:
        _log('nls._checkData.eventCompleted stop()');
        nlsSocket?.close();
        _nlsStared = false;
        nlsSocket = null;
        break;
    }
  }
}