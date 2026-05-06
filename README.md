## 프로젝트 개요
- 진행 기간: 26.3.30.(월) ∼ 4.12.(일) (2주간)
- 목표: "전국 통합데이터 활용 공모전" 참여를 위해 제작된 프로젝트

## 주요 기능
1. 전국 도서관 통합 검색 및 시각화
- 지역별 필터링: 시/도 및 시/군/구 단위의 상세 필터링을 통해 원하는 지역의 도서관을 빠르게 탐색
- 인터랙티브 지도: flutter_map을 활용하여 도서관 위치를 마커로 표시하며, 선택 시 해당 위치로 부드럽게 이동
- 데이터 보정: 공공 데이터 API의 불규칙한 위경도 좌표(소수점 누락)를 자동으로 보정하여 정확한 위치 제공
  
2. RAG 기반 AI 도서관 비서 '도공이'
- 자연어 질의응답: 사용자 질문의 의도를 파악하여 도서관 위치, 이용 시간 등을 친절하게 안내
- 문맥 유지: 이전 대화 내역을 기억하여 연속성 있는 대화 가능
- RAG: FAISS 벡터 DB와 ko-sroberta 임베딩을 사용하여 도서관 관련 전문 지식을 바탕을 정확한 답변 생성

3. 실시간 열람실 좌석 정보 조화
- 실시간 API 연동: 공공데이터포털의 실시간 열람실 정보를 호출하여 현재 이용 가능한 좌석 수를 즉시 확인
- 하이브리드 답변: AI가 정적 정보(도서관 통합 정보)와 동적 정보(실시간 좌석 정보)를 결합하여 최종 답변 구성

# 기술 스택
1. fontend
- framework: flutter(dart)
- map: flutter_map, latlong2
- networking: http

2. backend
- framework: fastapi(python)
- AI/LLM: LangChain, OpenAI(GPT-4o-mini)
- Vector DB: FAISS
- Embeddings: HuggingFace(jhgan/ko-sroberta-multitask)

# 실행 방법
1. backend
   (1) 필요 라이브러리 설치
   pip install fastapi uvicorn langchain langchain-openai faiss-cpu sentence-transformers python-dotenv
   (2) .env 파일 설정
   OPENAI_API_KEY=your_api_key_here
   (3) 서버 실행
   python main.py

3. frontend
   (1) 패키지 가져오기
   flutter pub get
   (2) 앱 실행
   flutter run
