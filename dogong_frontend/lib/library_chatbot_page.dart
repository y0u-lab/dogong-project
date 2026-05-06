// ==============================================================================
// 파일명: library_chatbot_page.dart
// 역할: "도공이" 서비스의 AI 챗봇 대화 화면 (STT 포함)
// 기능:
//    1. 자연어 대화 인터페이스: Ollama 기반 백엔드와 통신하여 도서관 안내 서비스 제공
//    2. 멀티턴 대화 처리: 대화 이력(History)을 관리하여 문맥에 맞는 답변 유지
//    3. 음성 인식(STT) 기능: speech_to_text 패키지를 활용한 음성 입력 지원
//    4. 자동 스크롤 및 UI 피드백: 메시지 수신 시 하단 자동 스크롤 및 로딩 상태 표시
// 기술 스택: Flutter(Dart), http, speech_to_text, JSON
// ==============================================================================
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class LibraryChatbotPage extends StatefulWidget {
  @override
  _LibraryChatbotPageState createState() => _LibraryChatbotPageState();
}

class _LibraryChatbotPageState extends State<LibraryChatbotPage> {
  late TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 대화 기록 저장 리스트 (백엔드 멀티턴 구현용)
  final List<Map<String, String>> _messages = []; // 대화 기록 저장 (멀티턴용)
  stt.SpeechToText _speech = stt.SpeechToText();

  bool _isLoading = false; // 서버 응답 대기 상태
  bool _isListening = false; // 음성 인식 중 상태
  bool _isStopping = false; // 음성 인식 중단 프로세스 중
  bool _isInitializing = false; // 음성 인식 엔진 초기화 중

  void initState() {
    super.initState();
    _controller = TextEditingController();

    // 초기 웰컴 메시지 설정
    _messages.add({
      "role": "assistant",
      "content":
          "안녕하세요! 도서관 안내 비서 <도공이 AI>입니다. \n도서관 좌석 현황이나 이용 정보는 물론, 가벼운 일상 대화도 가능해요! 무엇을 도와드릴까요?",
    });
  }

  // [STT] 음성 인식 시작/중지 함수
  void _listen() async {
    // 작업 중이면 차단
    if (_isInitializing || _isStopping) return;

    // 듣고 있으면 stop
    if (_isListening) {
      _isStopping = true;
      await _speech.stop();
      await Future.delayed(Duration(milliseconds: 300));
      if (mounted) {
        setState(() => _isListening = false);
      }
      _isStopping = false;
      return;
    }

    // 초기화 시작
    _isInitializing = true;
    bool available = await _speech.initialize(
      onStatus: (val) {
        if (!mounted) return;
        debugPrint('음성인식 상태: $val'); // 상태 로그 확인용

        if (val == 'done' || val == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (val) {
        if (!mounted) return;
        setState(() => _isListening = false);
        debugPrint('음성인식 에러: $val');
      },
    );
    _isInitializing = false;

    if (!available) return;
    if (mounted) {
      setState(() => _isListening = true);
    }

    await _speech.listen(
      onResult: (val) {
        if (!mounted || !_isListening) return;
        setState(() {
          _controller.text = val.recognizedWords;
          // 실시간 텍스트 입력에 맞춰 커서를 항상 마지막으로 유지
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
      // 사용자가 말을 멈추면 자동으로 인식을 종료하게 함
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
    );
  }

  // [API]  백엔드 서버로 사용자 메시지 전송/답변 수신
  Future<void> _sendMessage(String text) async {
    String trimmedText = text.trim(); // 보낼 텍스트 미리 저장
    if (trimmedText.isEmpty) return;
    // 키보드 닫기
    FocusScope.of(context).unfocus();

    if (_isListening) {
      await _speech.stop();
      await Future.delayed(Duration(milliseconds: 200)); // 안정화
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
    if (!mounted) return;
    // 리스트에 추가함과 동시에 입력란 비우기
    setState(() {
      _messages.add({"role": "user", "content": text});
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      // 도공이 서비스 백엔드 챗봇 엔드포인트
      final url = Uri.parse('https://dogong-library.duckdns.org/chat');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "query": trimmedText,
          "history": _messages, // 멀티턴을 위해 전체 대화 내역 전송
        }),
      );
      if (!mounted) return;
      // 서버 응답 추가
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _messages.add({"role": "assistant", "content": data['answer']});
        });
        _scrollToBottom();
      } else {
        if (!mounted) return;
        setState(() {
          _messages.add({
            "role": "assistant",
            "content": "죄송합니다. 서버와 연결이 원활하지 않습니다.",
          });
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({"role": "assistant", "content": "에러가 발생했습니다: $e"});
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 스크롤 함수 - 스크롤 끝까지 내리기
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 글자들을 왼쪽 정렬
          mainAxisSize: MainAxisSize.min, // 세로 공간 최소한으로 사용
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.blueAccent,
                  size: 28,
                ),
                SizedBox(width: 8),
                Text(
                  "도공이 AI",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(left: 2), // 아이콘 위치에 맞춰 미세하게 조정
              child: Text(
                "AI 비서 도공이와 대화해 보세요",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),

      body: Column(
        children: [
          // 채팅 메시지 표시 영역
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      msg["content"]!,
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          // 로딩 표시
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          // 입력창 영역 (음성 인식 버튼 포함)
          _buildInputArea(),
        ],
      ),
    );
  }

  // [UI] 음성 인식과 전송 버튼이 포함된 하단 입력 위젯
  Widget _buildInputArea() {
    bool isSendDisabled = _isListening || _isLoading;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        // ✅ Row를 Column으로 감싸서 아래에 텍스트 공간 확보
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 텍스트 입력 필드
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_isLoading,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (value) {
                    if (!_isLoading && !_isListening) {
                      _sendMessage(value);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? "듣고 있어요..."
                        : (_isLoading
                              ? "답변을 기다리는 중..."
                              : "질문을 입력하거나 마이크를 눌러보세요"),
                    hintStyle: TextStyle(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
              SizedBox(width: 8),
              // 마이크 버튼
              CircleAvatar(
                backgroundColor: _isListening
                    ? Colors.redAccent
                    : Colors.grey[200],
                child: IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.white : Colors.blueAccent,
                  ),
                  onPressed: _isLoading ? null : _listen,
                ),
              ),
              SizedBox(width: 8),
              // 전송 버튼
              CircleAvatar(
                backgroundColor: isSendDisabled
                    ? Colors.grey[300]
                    : Colors.blueAccent,
                child: IconButton(
                  icon: Icon(Icons.send, color: Colors.white),
                  onPressed: isSendDisabled
                      ? null
                      : () => _sendMessage(_controller.text),
                ),
              ),
            ],
          ),
          SizedBox(height: 8), // 입력창과 멘트 사이 간격
          // AI 안내 멘트 추가
          Text(
            "도공이 AI는 AI 기반으로 답변하므로 실수를 할 수 있습니다.",
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop(); // 마이크 중지
    _controller.dispose(); // 텍스트 컨트롤러 해제
    _scrollController.dispose();
    super.dispose();
  }
}
