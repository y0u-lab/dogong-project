// ==============================================================
// 파일명: api_service.dart
// 역할: 공공데이터포털 API 통신 및 데이터 파싱 전담 클래스
//    1. 전국 도서관 정보 조회: 위치, 주소 등 도서관 기본 마스터 데이터 수신
//    2. 실시간 좌석 현황 조회: 특정 도서관의 열람실별 실시간 잔여 좌석 데이터 연동
//    3. 데이터 정제 및 필터링: API 응답 데이터의 유효성 검사 및 조건별(ID, 이름) 필터링
//    4. 네트워크 예외 처리: HTTP 상태 코드 검사 및 User-Agent 설정을 통한 보안 차단 방지
// 기술 스택: Dart, http, json_convert, 공공데이터포털 REST API
// ==============================================================

import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  // 공공데이터포털 인증키 (Decoding 방식)
  static const String serviceKey =
      'Rg+tITFp4U+mh8rLJNx1vfgXMQqVk28Ne0TSi91Uj1YfYzpBO763pBtDyoD1M8L/RroVlAYRscdJOb87trHWPA==';
  // API 호스트 주소
  static const String baseUrl = 'apis.data.go.kr';

  // 지역 검색 및 지도 표시를 위한 전체 도서관 정보 가져오기
  Future<List<dynamic>> fetchAllLibraries() async {
    final uri = Uri.https(baseUrl, '/B551982/plr_v2/info_v2', {
      'serviceKey': serviceKey,
      'type': 'json',
      'pageNo': '1',
      'numOfRows': '100', // 한 번에 가져올 데이터 수량
    });

    try {
      // 일부 서버의 보안 정책(403 Forbidden)을 회피하기 위해 User-Agent 헤더 명시
      final response = await http.get(
        uri,
        headers: {"User-Agent": "Mozilla/5.0"},
      );

      if (response.statusCode == 200) {
        // 한글 깨짐 방지를 위해 UTF-8 디코딩 후 JSON 파싱
        String body = utf8.decode(response.bodyBytes);
        var data = jsonDecode(body);

        // API 응답 구조의 body > item 경로를 통해 리스트 추출
        if (data['body'] != null && data['body']['item'] != null) {
          return data['body']['item'] as List<dynamic>;
        }
        return [];
      } else {
        // HTTP 응답이 성공(200)이 아닐 경우 에러 로그 출력
        print('서버 응답 오류 상세: ${response.body}');
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('연결 에러 발생: $e');
      rethrow; // 호출부에서 에러를 처리할 수 있도록 다시 던짐
    }
  }

  // 특정 도서관의 실시간 좌석 정보 가져오기
  // [pblibId]와 [pblibNm]을 모두 확인하여 데이터 정확성 보장
  Future<List<dynamic>> fetchSeatInfo(String pblibId, String pblibNm) async {
    final uri = Uri.https(baseUrl, '/B551982/plr_v2/rlt_rdrm_info_v2', {
      'serviceKey': serviceKey,
      'type': 'json',
      'pageNo': '1',
      'numOfRows': '1000', // 좌석 데이터는 양이 많을 수 있으므로 넉넉히 설정
    });

    try {
      final response = await http.get(
        uri,
        headers: {"User-Agent": "Mozilla/5.0"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic> allItems = data['body']['item'] ?? [];

        // ID와 이름을 모두 비교하여 정확한 도서관 데이터만 필터링
        return allItems.where((item) {
          return item['pblibId'].toString().trim() == pblibId.trim() &&
              item['pblibNm'].toString().trim() == pblibNm.trim();
        }).toList();
      }
      return [];
    } catch (e) {
      // 에러 발생 시 빈 리스트를 반환하여 UI 흐름이 끊기지 않게 함
      return [];
    }
  }
}
