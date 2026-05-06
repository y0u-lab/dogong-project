"""
==============================================================
파일명: data_process.py
역할: 도서관 정보 수집 및 Vector DB 생성
기능:
    1. 공공데이터포털 API를 통한 전국 도서관 상세 정보 수집
    2. 수집된 원시 데이터를 검색에 최적화된 문서(Document) 형태로 가공
    3. HuggingFace 임베딩 모델을 활용한 FAISS 벡터 인덱스 생성 및 저장
기술 스택: Python, LangChain, FAISS, HuggingFace(Sentence-Transformers), REST API
==============================================================
"""

import requests
from langchain_community.vectorstores import FAISS
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_core.documents import Document

# 1. [설정] 공공데이터 API 정보 및 저장 경로
SERVICE_KEY = "Rg+tITFp4U+mh8rLJNx1vfgXMQqVk28Ne0TSi91Uj1YfYzpBO763pBtDyoD1M8L/RroVlAYRscdJOb87trHWPA=="
API_URL = "https://apis.data.go.kr/B551982/plr_v2/info_v2"
DB_SAVE_PATH = "library_faiss_index"  # FAISS 인덱스가 저장될 폴더명
MODEL_NAME = "jhgan/ko-sroberta-multitask"


# 2. 공공데이터 API 호출하여 도서관 데이터 가져오기
def fetch_library_info():
    params = {"serviceKey": SERVICE_KEY, "type": "json", "numOfRows": "200"}

    try:
        print(f" API 연결 시도 중: {API_URL}")
        response = requests.get(API_URL, params=params, timeout=10)

        if response.status_code == 200:
            data = response.json()
            items = data.get("body", {}).get("item", [])
            print(f"가져온 데이터 개수: {len(items)}개")
            return items
        else:
            print(f"API 응답 에러: 상태 코드 {response.status_code}")
            return []
    except Exception as e:
        print(f"네트워크 연결 중 오류 발생: {e}")


# 3. 수집된 도서관 데이터를 벡터 DB로 변환하여 로컬에 저장
def save_vector_db():
    items = fetch_library_info() # services/api_service.dart
    if not items:
        print(" 저장할 데이터가 없습니다. API 서비스키나 인터넷 연결을 확인하세요.")
        return

    # 3-1. 문서 가공 (AI가 이해하기 쉬운 텍스트 구조화)
    docs = []
    for item in items:
        content = (
            f"도서관 이름: {item['pblibNm']}\n"
            f"주소: {item['pblibRoadNmAddr']}\n"
            f"지역: {item['ctpvNm']} {item['sggNm']}\n"
            f"전화번호: {item.get('pblibTelno')}\n"
            f"홈페이지: {item.get('siteUrlAddr')}\n"
            f"휴관일 정보: {item.get('clsrInfoExpln')}\n" 
            f"평일 운영시간: {item.get('wkdyOperBgngTm')} ~ {item.get('wkdyOperEndTm')}\n" 
            f"주말 운영시간: {item.get('wkndOperBgngTm')} ~ {item.get('wkndOperEndTm')}\n"
            f"도서관 ID(pblibId): {item['pblibId']}"
        )

        # 메타데이터 부여 (추후 특정 ID 조회를 위해 필요)
        metadata = {"pblibId": str(item["pblibId"]), "name": item["pblibNm"]}
        docs.append(Document(page_content=content, metadata=metadata))

    # 3-2. 벡터DB 생성 및 물리 파일 저장
    print(" 임베딩 모델 로드 및 벡터화 시작 (Model: {MODEL_NAME})...")
    embeddings = HuggingFaceEmbeddings(model_name=MODEL_NAME)

    print("FAISS 인덱스 생성 중...")
    vector_db = FAISS.from_documents(docs, embeddings)
    vector_db.save_local("library_faiss_index")

    print("도서관 정보 벡터 DB 생성 완료!")


if __name__ == "__main__":
    save_vector_db()
