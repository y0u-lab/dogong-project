"""
==============================================================
파일명: main.py
역할: 백엔드 API 서버 (FastAPI 기반)
기능:
    1. RAG 기반 도서관 정보 검색
    2. 공공데이터포털 API 연동을 통한 실시간 열람실 좌석 정보 조회
    3. Ollma(Gemma 3:4b) 모델을 활용한 자연어 대화 생성
기술 스택: FastAPI, LangChain, Ollama, FAISS, HuggingFaceEmbeddings
==============================================================
"""

import os
import requests
from fastapi import FastAPI
from pydantic import BaseModel
from dotenv import load_dotenv

# LangChain 및 AI 관련 라이브러리
from langchain_openai import ChatOpenAI  # OpenAI 이용 시 필요
from langchain_community.llms import Ollama
from langchain_community.vectorstores import FAISS
from langchain_huggingface import HuggingFaceEmbeddings
from fastapi.middleware.cors import CORSMiddleware

# [1단계] 환경 설정 및 초기화
current_dir = os.path.dirname(os.path.abspath(__file__))
dotenv_path = os.path.join(current_dir, ".env")

if load_dotenv(dotenv_path):
    print(".env 파일을 성공적으로 로드했습니다.")
else:
    print(".env 파일을 찾을 수 없거나 로드에 실패했습니다.")
app = FastAPI()

# CORS 설정 : 플러터 앱(외부 기기)에서 이 서버에 접속할 수 있도록 허용
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# [2단계] AI 모델 및 지식 베이스(Vector DB) 로드
# 2-1. 한국어 문장 임베딩에 특화된 모델 로드
embeddings = HuggingFaceEmbeddings(model_name="jhgan/ko-sroberta-multitask")

# 2-2. 미리 만들어둔 FAISS 인덱스 로드 - 도서관 정보
vector_db = FAISS.load_local(
    "library_faiss_index", embeddings, allow_dangerous_deserialization=True
)

# 2-3. GCP 서버에서 설치한 Gemma 3 모델 연결
# llm = Ollama(
#     model="gemma3:4b",
#     temperature=0,
# )

from dotenv import dotenv_values

# .env 파일에서 직접 딕셔너리 형태로 값을 가져옵니다.
config = dotenv_values(dotenv_path)
my_key = config.get("OPENAI_API_KEY")

# 만약 파일에서 못 가져왔다면 os 환경변수에서라도 마지막으로 찾아봅니다.
if not my_key:
    my_key = os.getenv("OPENAI_API_KEY")

# 최종 확인: 그래도 없으면 서버 실행을 중단하고 에러를 출력합니다.
if not my_key:
    raise ValueError(
        "❌ OPENAI_API_KEY를 찾을 수 없습니다. .env 파일의 변수명을 확인해주세요!"
    )

# (오픈AI 이용시 필요한 코드)
llm = ChatOpenAI(
    model="gpt-4o-mini", api_key=os.getenv("OPENAI_API_KEY"), temperature=0
)


# [3단계] 공공데이터 API 연동 함수 (실시간 좌석 정보)
def get_realtime_seats(pblib_id, library_name):
    url = "https://apis.data.go.kr/B551982/plr_v2/rlt_rdrm_info_v2"
    service_key = "Rg+tITFp4U+mh8rLJNx1vfgXMQqVk28Ne0TSi91Uj1YfYzpBO763pBtDyoD1M8L/RroVlAYRscdJOb87trHWPA=="  # 본인 키

    target_id = str(pblib_id).strip().upper()
    target_name = library_name.replace(" ", "")

    params = {
        "serviceKey": requests.utils.unquote(service_key),  # 키 인코딩 방지
        "type": "json",
        "pblibId": target_id,
    }

    try:
        response = requests.get(url, params=params, timeout=5)
        print(f"좌석 API 상태 코드: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            items = data.get("body", {}).get("item", [])
            if isinstance(
                items, dict
            ):  # item이 리스트가 아니라 단일 객체인 경우 예외 처리
                items = [items]

            if items:
                seat_info = ""
                for item in items:
                    current_item_id = str(item.get("pblibId", "")).strip().upper()
                    current_item_name = item.get("pblibNm", "").replace(" ", "")

                    # 내가 찾는 도서관이 맞는지 ID와 이름으로 이중 검증
                    if current_item_id == target_id and (
                        target_name in current_item_name
                        or current_item_name in target_name
                    ):
                        name = item.get("rdrmNm", "열람실")
                        total = item.get("tseatCnt", "확인 불가")
                        use = item.get("useSeatCnt", "0")
                        remain = item.get("rmndSeatCnt", "확인 불가")
                        seat_info += f"- {name}: 전체 {total}석 중 {use}석 사용 중 ({remain}석 남음)\n"
                return (
                    seat_info
                    if seat_info
                    else "일치하는 도서관 정보를 찾을 수 없습니다."
                )
    except Exception as e:
        print(f"좌석 API 호출 에러: {e}")
    return "현재 실시간 좌석 정보를 불러올 수 없습니다."


# [4단계] 데이터 요청 모델 정의
class ChatRequest(BaseModel):
    query: str  # 사용자 질문
    history: list = []  # 이전 대화 내역


# [5단계] 메인 채팅 엔드포인트
@app.post("/chat")
async def chat(request: ChatRequest):
    # [A단계] 대화 맥락 유지 (최근 5개 대화만 요약)
    history_str = "\n".join(
        [f"{m['role']}: {m['content']}" for m in request.history[-5:]]
    )

    # [B단계] 의도 파악: 질문에서 어떤 도서관을 말하는지 추출
    extract_prompt = f"""
    대화 맥락에서 도서관 이름을 추출하세요. 없으면 'NONE'
    맥락: {history_str}
    질문: {request.query}
    이름:"""
    extracted_lib = llm.invoke(extract_prompt).content.strip()
    # extracted_lib = llm.invoke(extract_prompt).content.strip() # 오픈AI 사용시 필요
    current_lib_name = extracted_lib.replace("'", "").replace('"', "").replace(".", "")

    # [C단계] RAG(검색) 수행: Vector DB에서 관련 지식 찾기
    # search_query = request.query
    context = ""
    realtime_info = ""
    if "NONE" not in current_lib_name.upper() and current_lib_name:
        docs = vector_db.similarity_search(f"{current_lib_name} {request.query}", k=1)
        if docs:
            context = docs[0].page_content  # 도서관 위치, 이용 시간 등 기본 지식
            pblib_id = docs[0].metadata.get("pblibId")
            lib_name = docs[0].metadata.get("name")
            # [D단계] 실시간 정보 보충: API 호출
            realtime_info = get_realtime_seats(pblib_id, lib_name)

    # [E단계] 최종 프롬프트 구성 : 지식 + 실시간 정보 + 대화 내역
    prompt = f"""
    당신은 도서관내 비서 '도공'입니다. 
    1. [참고 데이터]나 [실시간 정보]가 있다면 이를 바탕으로 답변하세요.
    2. 관련 정보가 없다면 당신의 지식을 활용해 친절하게 일상적인 대화를 나누세요.
    3. 실시간 정보에 좌석 수 숫자가 있다면 절대 "정보가 없다"고 하지 마세요.

    [참고 데이터]: {context}
    [실시간 정보]: {realtime_info}
    
    이전 대화: {history_str}
    사용자 질문: {request.query}
    도공의 답변:"""

    # [F단계] 답변 생성 및 반환
    res = llm.invoke(prompt)
    final_answer = res.content
    # final_answer = res if isinstance(res, str) else getattr(res, "content", str(res))
    return {"answer": final_answer}


# [6단계] 서버 실행 설정
if __name__ == "__main__":
    import uvicorn

    # host를 0.0.0.0으로 해서 외부(플러터)에서 접근 가능하게
    uvicorn.run(app, host="0.0.0.0", port=8000)
