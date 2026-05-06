// ==============================================================
// 파일명: library_list_page.dart
// 역할: "도공이" 서비스이 도서관 검색 및 위치 정보 시각화 화면
// 기능:
//    1. 전국 도서관 통합 검색: 시/도 및 시/군/구 필터링을 통한 맞춤형 도서관 탐색
//    2. 인터랙티브 지도 구현: 오픈스트리트맵(OSM) 기반 도서관 위치 마커 표시 및 이동
//    3. 좌표 데이터 보정 및 처리: API의 위경도 데이터 예외 처리 및 지도 중심점 자동 동기화
//    4. 실시간 서비스 연동: 선택된 도서관의 실시간 좌석 정보 페이지(RAG/API) 연결
// 기술 스택: Flutter(Dart), flutter_map, latlong2, HTTP(ApiService 연동)
// ==============================================================

import 'package:dogong/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // 지도 표시를 위한 패키지
import 'package:latlong2/latlong.dart'; // 위도, 경도 좌표 처리를 위한 패키지
import 'library_seat_info_page.dart';

class LibraryListPage extends StatefulWidget {
  const LibraryListPage({super.key});

  @override
  State<LibraryListPage> createState() => _LibraryListPageState();
}

class _LibraryListPageState extends State<LibraryListPage> {
  // API 호출을 위한 서비스 클래스 인스턴스
  final ApiService _apiService = ApiService();
  // 지도를 프로그램적으로 제어하기 위한 컨트롤러(이동, 확대 등)
  final MapController _mapController = MapController();

  // 초기 지도의 중심 좌표 (대한민국 중심부 부근)
  LatLng _currentCenter = const LatLng(36.5, 127.5);

  // --- 데이터 담을 변수 선언 ---
  List<dynamic> _allLibraries = []; // 전체 도서관 데이터
  List<String> _cities = []; // 지역 목록 (시/도)
  List<String> _districts = []; // 세부 지역 목록 (시/군/구)
  List<dynamic> _filteredLibs = []; // 특정 지역 선택 시 필터링된 도서관 객체 목록

  // --- 사용자가 선택한 값들 ---
  String? _selectedCity; // 선택된 시/도 이름
  String? _selectedDistrict; // 선택된 시/군/구 이름
  String? _selectedLibraryId; // 선택된 도서관 고유 ID
  dynamic _selectedLibrary; // 선택된 도서관 전체 데이터

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // 페이지 시작 시 전체 도서관 데이터 불러옴
  }

  // 초기 데이터를 API에서 비동기로 가져오는 함수
  Future<void> _loadInitialData() async {
    try {
      final data = await _apiService.fetchAllLibraries();
      setState(() {
        _allLibraries = data;
        // 전체 데이터에서 시/도 목록 추출 후 정렬
        _cities = data.map((e) => e['ctpvNm'].toString()).toSet().toList()
          ..sort();
      });
    } catch (e) {
      // 에러 발생 시 콘솔에 출력
      print("데이터 로드 중 에러 발생: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: const Color(0xFF6C63FF),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),

        title: const Text(
          "도서관 검색",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0, // 그림자 제거
        centerTitle: true,
        // 앱바 하단에 연한 구분선 추가
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.withValues(alpha: 0.1),
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchCard(), // 검색 조건(드롭다운) 영역
            const SizedBox(height: 25),
            _buildMapSection(), // 지도 및 마커 표시 영역
          ],
        ),
      ),
    );
  }

  // 검색 드롭다운들이 포함된 카드 위젯
  Widget _buildSearchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.search, color: const Color(0xFF6C63FF), size: 20),
              SizedBox(width: 8),
              Text(
                "지역별 도서관 검색",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. 시/도 선택 드롭다운
          const Text("지역", style: TextStyle(fontSize: 13, color: Colors.grey)),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            initialValue: _selectedCity,
            hint: const Text("시/도를 선택하세요"),
            items: [
              const DropdownMenuItem(value: "ALL", child: Text("전체")),
              ..._cities
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
            ],
            onChanged: (val) {
              setState(() {
                if (val == "ALL" || val == null) {
                  // '전체' 선택 시 모든 선택 값 초기화 및 지도 초기화
                  _selectedCity = null;
                  _selectedDistrict = null;
                  _selectedLibraryId = null;
                  _selectedLibrary = null;
                  _districts = [];
                  _filteredLibs = [];
                  _mapController.move(const LatLng(36.5, 127.5), 7.0);
                } else {
                  // 특정 시/도 선택 시 해당 지역의 시/군/구 목록 필터링
                  _selectedCity = val;
                  _selectedDistrict = null;
                  _selectedLibraryId = null;
                  _selectedLibrary = null;
                  _districts =
                      _allLibraries
                          .where((e) => e['ctpvNm'] == val)
                          .map((e) => e['sggNm'].toString())
                          .toSet()
                          .toList()
                        ..sort();
                }
              });
            },
          ),
          const SizedBox(height: 15),

          // 2. 시/군/구 선택 드롣다운
          const Text(
            "세부 지역",
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedCity),
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            initialValue: _selectedDistrict,
            hint: const Text("시/군/구를 선택하세요"),
            items: _districts
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedDistrict = val;
                _selectedLibraryId = null;
                _selectedLibrary = null;
                // 선택된 시/도 + 시/군/구에 해당하는 도서관 목록 필터링
                _filteredLibs = _allLibraries
                    .where(
                      (e) => e['ctpvNm'] == _selectedCity && e['sggNm'] == val,
                    )
                    .toList();
                _filteredLibs.sort(
                  (a, b) => (a['pblibNm'] ?? "").toString().compareTo(
                    (b['pblibNm'] ?? "").toString(),
                  ),
                );
              });
            },
          ),
          const SizedBox(height: 15),

          // 3. 개별 도서관 선택 드롭다운
          const Text("도서관", style: TextStyle(fontSize: 13, color: Colors.grey)),
          DropdownButtonFormField<String>(
            key: ValueKey(
              "lib_drop_${_selectedDistrict}_${_filteredLibs.length}",
            ),
            initialValue: _selectedLibraryId,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            hint: const Text("도서관을 선택하세요"),
            items: (() {
              // 중복 데이터 방지를 위해 고유 ID 체크 후 리스트 생성
              final seenIds = <String>{};
              return _filteredLibs
                  .where((lib) {
                    final String id = lib['pblibId']?.toString() ?? "";
                    if (id.isEmpty || seenIds.contains(id)) return false;
                    seenIds.add(id);
                    return true;
                  })
                  .map((lib) {
                    return DropdownMenuItem<String>(
                      value: lib['pblibId']?.toString(),
                      child: Text(
                        lib['pblibNm']?.toString() ?? "이름 없음",
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  })
                  .toList();
            }()),
            onChanged: (val) {
              setState(() {
                _selectedLibraryId = val;
                // 선택된 ID에 해당하는 도서관 객체 찾기
                _selectedLibrary = _allLibraries.firstWhere(
                  (e) =>
                      e['pblibId']?.toString() == val &&
                      e['ctpvNm'] == _selectedCity &&
                      e['sggNm'] == _selectedDistrict,
                  orElse: () => null,
                );

                // 선택된 도서관이 있다면 좌표를 보정하여 지도를 해당 위치로 이동
                if (_selectedLibrary != null) {
                  // 좌표 보정 및 지도 이동
                  String rawLat =
                      _selectedLibrary['lat']?.toString().trim() ?? "";
                  String rawLot =
                      _selectedLibrary['lot']?.toString().trim() ?? "";

                  // 소수점이 없는 데이터에 대한 예외 처리
                  if (!rawLat.contains('.') && rawLat.length > 2)
                    rawLat = "${rawLat.substring(0, 2)}.${rawLat.substring(2)}";
                  if (!rawLot.contains('.') && rawLot.length > 3)
                    rawLot = "${rawLot.substring(0, 3)}.${rawLot.substring(3)}";

                  double? lat = double.tryParse(rawLat);
                  double? lot = double.tryParse(rawLot);

                  if (lat != null && lot != null) {
                    // 위도 경도 반전 체크
                    if (lat > 100 && lot < 100) {
                      double temp = lat;
                      lat = lot;
                      lot = temp;
                    }
                    _mapController.move(LatLng(lat, lot), 15.0);
                  }
                }
              });
            },
          ),
          const SizedBox(height: 25),

          // 4. 드롭다운에서 선택 완료 시 나타나는 바로가기 버튼
          if (_selectedLibrary != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  // 상세 페이지(좌석 정보)로 이동
                  if (_selectedLibrary != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LibrarySeatInfoPage(
                          pblibId: _selectedLibrary['pblibId'].toString(),
                          pblibNm: _selectedLibrary['pblibNm'].toString(),
                        ),
                      ),
                    );
                  }
                },
                child: const Text(
                  "실시간 좌석 확인하기",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 지도 영역 위젯
  Widget _buildMapSection() {
    return Container(
      height: 400,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentCenter,
            initialZoom: 7.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onTap: (_, __) => setState(() => _selectedLibrary = null),
          ),
          children: [
            // 오픈스트리트맵 타일 레이어(지도 배경)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),
            // 도서관 위치 마커 레이어
            MarkerLayer(
              key: ValueKey("all_lib_markers_${_allLibraries.length}"),
              markers: _allLibraries
                  .map((lib) {
                    final double? lat = double.tryParse(
                      lib['lat'].toString().trim(),
                    );
                    final double? lot = double.tryParse(
                      lib['lot'].toString().trim(),
                    );
                    if (lat == null || lot == null) return null;

                    return Marker(
                      point: LatLng(lat, lot),
                      width: 40,
                      height: 40,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLibrary = lib;
                              _selectedLibraryId = lib['pblibId']?.toString();
                            });
                          },
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF6C63FF),
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  })
                  .whereType<Marker>()
                  .toList(),
            ),
            // 마커 클릭 시 지도 위에 띄울 커스텀 팝업
            if (_selectedLibrary != null) _buildCustomPopup(_selectedLibrary!),
          ],
        ),
      ),
    );
  }

  // 지도 위에 표시되는 상세 정보 팝업 위젯
  Widget _buildCustomPopup(dynamic lib) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.only(bottom: 100), // 마커보다 약가 위에 표시되도록 조정
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    lib['pblibNm'] ?? "도서관",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedLibrary = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lib['pblibRoadNmAddr'] ?? "주소 정보 없음",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTag(lib['ctpvNm'] ?? "지역"),
                const SizedBox(width: 5),
                _buildTag(lib['sggNm'] ?? "구군"),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LibrarySeatInfoPage(
                        pblibId: lib['pblibId']?.toString() ?? "",
                        pblibNm: lib['pblibNm']?.toString() ?? "",
                      ),
                    ),
                  );
                },
                child: const Text(
                  "좌석 정보 보기",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 시/도, 구/군 표시를 위한 작은 태그 위젯
  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.indigo),
      ),
    );
  }
}
