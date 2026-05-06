// ==============================================================================
// 파일명: main.dart
// 역할: '도공이' 애플리케이션의 엔트리 포인트 및 메인 대시보드 화면
// 기능:
//    1. 앱 초기 설정: 테마 컬러(DeepPurple) 및 기본 머티리얼 디자인 설정
//    2. 내비게이션 허브: 실시간 좌석 확인 및 AI 챗봇 화면으로 이동할 수 있는 관문 역할
//    3. 반응형 UI: MediaQuery를 활용하여 기기 너비에 대응하는 카드 디자인 구현
//    4. 사용자 경험(UX): InkWell을 사용한 시각적 피드백(물결 효과) 및 그림자 효과 적용
// 기술 스택: Flutter(Dart), Material Design
// ==============================================================================
import 'package:flutter/material.dart';
import 'library_list_page.dart';
import 'library_chatbot_page.dart';

// [앱의 시작점]
void main() {
  runApp(const MyApp());
}

// 앱의 전체적인 테마와 설정
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: '도공 (도서관 공부) 메이트'),
    );
  }
}

// 실제로 눈에 보이는 화면
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //Scaffold: 앱의 기본 골격
      backgroundColor: const Color(0xFFF1F3FF),
      body: SafeArea(
        // SafeArea: 글자가 시계나 카메라 구멍에 가려지지 않게 자동으로 여백을 주는 위젯
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. 아이콘 추가 (보라색 원형 배경)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF6C63FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              // 2. 메인 제목
              const Text(
                '도공이',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              const Text('도서관 공부를 돕는 지능형 비서'),

              const SizedBox(height: 8), //const SizedBox: 위젯 사이 공간 확보
              // 3. 소제목
              const Text('실시간 좌석 확인부터 AI와 대화까지, 도공이와 시작해 보세요'),
              const SizedBox(height: 40),

              const SizedBox(height: 40),

              // 4. 첫 번째 카드 만들기 - 실시간 좌석 정보
              InkWell(
                onTap: () {
                  // 카드 누르면 실행될 코드
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LibraryListPage(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20), //클릭 효과: 둥글게
                child: Container(
                  width:
                      MediaQuery.of(context).size.width * 0.85, //화며 너비의 85%만 차지
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white, //배경: 흰색
                    borderRadius: BorderRadius.circular(20), //모서리 둥글게
                    border: Border.all(
                      color: const Color(0xFF6C63FF),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chair_alt_rounded,
                        color: Color(0xFF6C63FF),
                        size: 30,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '좌석 정보 확인하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6C63FF),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '현재 열람실 이용 현황을 한눈에 확인하세요',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16), //카드 사이 간격
              // 5. 두 번째 카드 만들기 - 도서관 정보 톡톡
              InkWell(
                onTap: () {
                  // 카드 누르면 실행될 코드
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LibraryChatbotPage(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20), //클릭 효과: 둥글게
                child: Container(
                  width:
                      MediaQuery.of(context).size.width * 0.85, //화며 너비의 85%만 차지
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white, //배경: 흰색
                    borderRadius: BorderRadius.circular(20), //모서리 둥글게
                    border: Border.all(
                      color: Colors.blueAccent,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.smart_toy_outlined,
                        color: Colors.blueAccent,
                        size: 30,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'AI 비서와 대화하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '도서관 정보에 대해 도공이 AI가 답해드려요',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
