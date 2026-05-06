// ==============================================================================
// 파일명: library_seat_info_page.dart
// 역할: 특정 도서관의 실시간 열람실 좌석 현황 시각화 화면
// 기능:
//    1. 실시간 데이터 로드: ApiService를 통해 해당 도서관의 열람실별 실시간 정보 수신
//    2. 데이터 파싱 및 시간 변환: 서버의 타임스탬프(totDt)를 가독성 있는 형식으로 변환 표시
//    3. 이용률 시각화: LinearProgressIndicator를 활용하여 열람실별 혼잡도를 직관적으로 표현
//    4. 예외 처리: 좌석 정보를 제공하지 않는 도서관에 대한 Empty State 화면 대응
// 기술 스택: Flutter(Dart), ApiService(HTTP 연동)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:dogong/services/api_service.dart';

class LibrarySeatInfoPage extends StatefulWidget {
  final String pblibId; // 도서관 고유 ID
  final String pblibNm; // 도서관 이름

  const LibrarySeatInfoPage({
    super.key,
    required this.pblibId,
    required this.pblibNm,
  });

  @override
  State<LibrarySeatInfoPage> createState() => _LibrarySeatInfoPageState();
}

class _LibrarySeatInfoPageState extends State<LibrarySeatInfoPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _seatData = [];
  bool _isLoading = true;
  String _lastUpdate = "-";

  @override
  void initState() {
    super.initState();
    _loadSeatInfo(); // 화면 진입 시 초기 데이터 로드
  }

  // [API] 실시간 좌석 정보 불러오고 마지막 업데이트 시간 계산
  Future<void> _loadSeatInfo() async {
    setState(() => _isLoading = true);
    try {
      // ApiService의 fetchSeatInfo 함수 호출
      final filteredData = await _apiService.fetchSeatInfo(
        widget.pblibId,
        widget.pblibNm,
      );

      setState(() {
        _seatData = filteredData;

        // 데이터가 있다면 마지막 업데이트 시간 설정 (totDt: 20260409184402 형태)
        if (_seatData.isNotEmpty) {
          String rawDt = _seatData[0]['totDt']?.toString() ?? "";
          if (rawDt.length >= 14) {
            String month = rawDt.substring(4, 6);
            String day = rawDt.substring(6, 8);
            String hour = rawDt.substring(8, 10);
            String min = rawDt.substring(10, 12);
            String sec = rawDt.substring(12, 14);
            _lastUpdate = "$month.$day $hour:$min:$sec 기준";
          } else if (rawDt.length >= 12) {
            // 혹시라도 서버 데이터가 초 단위를 안 줄 경우를 대비한 방어 로직
            String hour = rawDt.substring(8, 10);
            String min = rawDt.substring(10, 12);
            _lastUpdate = "$hour:$min 기준";
          } else {
            _lastUpdate = "방금 전";
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("좌석 정보 로드 에러: $e");
      setState(() {
        _seatData = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF6C63FF),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.pblibNm,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "실시간 좌석 현황",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadSeatInfo,
        color: const Color(0xFF6C63FF),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeaderInfo(), // 업데이트 시간 및 버튼
                  Expanded( // 열람실 카드 리스트
                    child: _seatData.isEmpty
                        ? _buildEmptyState()
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 15,
                                  crossAxisSpacing: 15,
                                  childAspectRatio: (MediaQuery.of(context).size.width / 2) / 220,
                                ),
                            itemCount: _seatData.length,
                            itemBuilder: (context, index) {
                              return _buildSeatCard(_seatData[index]);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  // [UI] 업데이트 시간 및 새로고침 버튼
  Widget _buildHeaderInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "마지막 업데이트: $_lastUpdate",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          ElevatedButton.icon(
            onPressed: _loadSeatInfo,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("새로고침"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [UI] 개별 열림실 정보를 보여주는 카드 위젯
  Widget _buildSeatCard(Map<String, dynamic> room) {
    // API 데이터 파싱 (String -> int 안전하게 변환)
    int total = int.tryParse(room['tseatCnt']?.toString() ?? "0") ?? 0;
    int used = int.tryParse(room['useSeatCnt']?.toString() ?? "0") ?? 0;
    int remain = int.tryParse(room['rmndSeatCnt']?.toString() ?? "0") ?? 0;
    double usageRate = total > 0 ? (used / total) : 0.0;

    return Container(
      // GridView 내부에 들어가므로 마진은 GridView의 spacing으로 조절
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // 첫 번째 이미지처럼 둥글게
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start, // 위젯들을 왼쪽부터 차곡차곡 쌓기
        children: [
          // 헤더 영역 (열람실 이름, 타입 태그, 층수)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room['rdrmNm'] ?? "열람실",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      room['bldgFlrExpln'] ?? "-",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _buildTypeTag(room['rdrmTypeNm'] ?? "일반"), // 기존 태그 위젯 사용
            ],
          ),
          const SizedBox(height: 12), // 헤더와 현황판 사이 간격
          // 현황판(총 좌석, 가능, 사용중)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildSmallStatusCard(
                  "총 좌석",
                  total.toString(),
                  Colors.grey.shade200,
                  Colors.black,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSmallStatusCard(
                  "이용가능",
                  remain.toString(),
                  Colors.green.shade100,
                  Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 4), 
              Expanded(
                child: _buildSmallStatusCard(
                  "사용 중",
                  used.toString(),
                  Colors.red.shade100,
                  Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12,), // 중간 공간 확보
          // 하단 이용률 프로그레스바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "이용률",
                      style: TextStyle(fontSize: 10, color: Colors.black87),
                    ),
                    Text(
                      "${(usageRate * 100).toInt()}%",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: usageRate,
                    minHeight: 6,
                    backgroundColor: Colors.white,
                    // 사용률 높으면 빨간색, 낮으면 검은색 계열
                    valueColor: AlwaysStoppedAnimation<Color>(
                      usageRate > 0.8 ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // [UI] GridView 내부에 맞춘 미니 현황판 상자 도우미 함수
  Widget _buildSmallStatusCard(
    String title,
    String count,
    Color borderColor,
    Color textColor,
  ) {
    return Container(
      // 카드 크기에 맞춰 너비를 좁게 설정
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              color: textColor,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // [UI] 열람실 종류 태그 위젯 (정숙, 노트북 등)
  Widget _buildTypeTag(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: Color(0xFF6C63FF),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // [UI] 데이터를 로드할 수 없을 때 표시되는 안내 화면
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_seat_outlined,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 15),
          const Text(
            "실시간 좌석 정보를 제공하지 않는\n도서관입니다.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
