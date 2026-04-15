from fastapi import FastAPI, HTTPException, Query, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
import requests
import json
import re
import os
from dotenv import load_dotenv
from typing import Tuple, Dict, Any
from datetime import datetime, UTC
from uuid import uuid4
from pymongo import MongoClient, ReturnDocument
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB_NAME = os.getenv("MONGO_DB_NAME", "chat_db")
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")

def get_current_user(authorization: str = Header(None)) -> Dict[str, Any]:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    token = authorization.split(" ")[1]
    try:
        idinfo = id_token.verify_oauth2_token(token, google_requests.Request(), GOOGLE_CLIENT_ID)
        return idinfo
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid Token")

client = MongoClient(MONGO_URI)
db = client[MONGO_DB_NAME]
chats_collection = db["chats"]
messages_collection = db["chat_messages"]
chats_collection.create_index("id", unique=True)
chats_collection.create_index("updated_at")
messages_collection.create_index([("chat_id", 1), ("seq", 1)], unique=True)
messages_collection.create_index([("chat_id", 1), ("created_at", -1)])


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------
# SAFETY LAYER
# -----------------------
# Keep this simple for now. You can expand patterns later.
BLOCKED_PATTERNS = [
    "ignore instructions",
    "system prompt",
    "how to steal",
    "steal a car",
    "hotwire",
    "break into",
    "bypass alarm",
    "hack password",
    "make a bomb",
]


def is_safe_text(text: str) -> bool:
    lower = text.lower()
    return not any(pattern in lower for pattern in BLOCKED_PATTERNS)


def safety_check(text: str) -> Tuple[bool, str]:
    if not is_safe_text(text):
        return False, "Request blocked by safety filter."
    return True, ""


# -----------------------
# AI CALL (LOCAL LLM)
# -----------------------
TOPIC_STYLES = [
    {
        "name": "career",
        "emoji": "🎯",
        "title_hint": "Career Guide",
        "keywords": ["career", "job", "interview", "resume", "cv", "hiring"],
    },
    {
        "name": "coding",
        "emoji": "💻",
        "title_hint": "Coding Help",
        "keywords": ["code", "python", "javascript", "react", "api", "bug", "debug"],
    },
    {
        "name": "business",
        "emoji": "📈",
        "title_hint": "Business Insight",
        "keywords": ["business", "startup", "sales", "marketing", "strategy", "finance"],
    },
    {
        "name": "learning",
        "emoji": "📘",
        "title_hint": "Learning Plan",
        "keywords": ["learn", "study", "roadmap", "course", "beginner", "practice"],
    },
]


def detect_topic_style(user_prompt: str) -> Tuple[str, str]:
    prompt_lower = user_prompt.lower()
    for topic in TOPIC_STYLES:
        if any(keyword in prompt_lower for keyword in topic["keywords"]):
            return topic["emoji"], topic["title_hint"]
    return "✨", "Helpful Answer"


def build_styled_prompt(user_prompt: str) -> str:
    emoji, title_hint = detect_topic_style(user_prompt)
    return f"""You are a helpful career assistant.

Formatting rules (must follow):
- Start with exactly one emoji: {emoji}
- Then add a space and a bold title on the same line.
- Keep the title short and aligned with this theme: "{title_hint}".
- Use Markdown.
- Leave one empty line between each major paragraph.
- If the user asks for steps, return a numbered list.
- Keep the answer clear and concise.

User request:
{user_prompt}
"""


def call_llama(prompt: str) -> str:
    styled_prompt = build_styled_prompt(prompt)
    ollama_url = os.getenv("OLLAMA_URL", "http://localhost:11434")
    response = requests.post(
        f"{ollama_url}/api/generate",
        json={
            "model": "dolphin-llama3",
            "prompt": styled_prompt,
            "stream": True,
        },
        stream=True,
        timeout=120,
    )
    response.raise_for_status()

    chunks = []
    for line in response.iter_lines(decode_unicode=True):
        if not line:
            continue

        # Each line is a JSON object in Ollama streaming format
        # e.g. {"response":"To","done":false}
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            # Skip malformed chunks rather than crashing
            continue

        token = obj.get("response", "")
        if token:
            chunks.append(token)

        if obj.get("done", False):
            break

    raw_text = "".join(chunks).strip()
    return format_structured_response(raw_text)


def format_structured_response(text: str) -> str:
    # Normalize common streamed list formatting like:
    # "1. ... 2. ... 3. ..." into multiline markdown-friendly output.
    formatted = re.sub(r"\s+(\d+\.\s+\*\*)", r"\n\n\1", text)
    formatted = re.sub(r"\s+(\d+\.\s+)", r"\n\n\1", formatted)
    return formatted.strip()


# -----------------------
# CHAT SESSIONS (MONGODB)
# -----------------------
DEFAULT_CHAT_TITLE = "New Chat"
CHAT_NOT_FOUND = "Chat not found."
DEFAULT_PAGE_SIZE = 100
MAX_PAGE_SIZE = 500
DEFAULT_CHAT_LIST_LIMIT = 100
MAX_CHAT_LIST_LIMIT = 500


def now_iso() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def make_title(first_message: str) -> str:
    cleaned = " ".join(first_message.strip().split())
    if not cleaned:
        return DEFAULT_CHAT_TITLE
    return cleaned[:60] + ("..." if len(cleaned) > 60 else "")


def build_chat_summary(chat: Dict) -> Dict:
    return {
        "id": chat["id"],
        "title": chat["title"],
        "timestamp": chat["updated_at"],
    }


def get_chat_or_404(chat_id: str, user_id: str, projection: Dict | None = None) -> Dict:
    chat = chats_collection.find_one({"id": chat_id, "user_id": user_id}, projection or {"_id": 0})
    if not chat:
        raise HTTPException(status_code=404, detail=CHAT_NOT_FOUND)
    chat.pop("_id", None)
    return chat


def reserve_next_seq(chat_id: str, user_id: str) -> int:
    chat = chats_collection.find_one_and_update(
        {"id": chat_id, "user_id": user_id},
        {"$inc": {"next_seq": 1}},
        projection={"_id": 0, "next_seq": 1},
        return_document=ReturnDocument.AFTER,
    )
    if not chat:
        raise HTTPException(status_code=404, detail=CHAT_NOT_FOUND)
    return int(chat["next_seq"])


def append_message(chat_id: str, user_id: str, role: str, content: str, timestamp: str) -> Dict:
    seq = reserve_next_seq(chat_id, user_id)
    message_doc = {
        "chat_id": chat_id,
        "seq": seq,
        "role": role,
        "content": content,
        "created_at": timestamp,
    }
    messages_collection.insert_one(message_doc)
    return {
        "seq": seq,
        "role": role,
        "content": content,
        "timestamp": timestamp,
    }


@app.get("/chats")
def list_chats(
    limit: int = Query(DEFAULT_CHAT_LIST_LIMIT, ge=1, le=MAX_CHAT_LIST_LIMIT),
    current_user: dict = Depends(get_current_user)
):
    chats = list(
        chats_collection.find(
            {"user_id": current_user["sub"]},
            {
                "_id": 0,
                "id": 1,
                "title": 1,
                "updated_at": 1,
            },
        )
        .sort("updated_at", -1)
        .limit(limit)
    )
    return {"chats": [build_chat_summary(chat) for chat in chats]}


@app.post("/chats")
def create_chat(current_user: dict = Depends(get_current_user)):
    chat_id = str(uuid4())
    timestamp = now_iso()
    chat_doc = {
        "id": chat_id,
        "user_id": current_user["sub"],
        "title": DEFAULT_CHAT_TITLE,
        "created_at": timestamp,
        "updated_at": timestamp,
        "next_seq": 0,
    }
    chats_collection.insert_one(chat_doc)
    return {"chat": {k: v for k, v in chat_doc.items() if k != "_id"}}


@app.get("/chats/{chat_id}")
def get_chat(
    chat_id: str,
    limit: int = Query(DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE),
    before_seq: int | None = Query(None, ge=1),
    current_user: dict = Depends(get_current_user)
):
    chat_meta = get_chat_or_404(
        chat_id,
        current_user["sub"],
        {
            "_id": 0,
            "id": 1,
            "title": 1,
            "created_at": 1,
            "updated_at": 1,
        },
    )

    query: Dict = {"chat_id": chat_id}
    if before_seq is not None:
        query["seq"] = {"$lt": before_seq}

    # Read latest N then reverse for chronological rendering in UI.
    docs = list(
        messages_collection.find(
            query,
            {
                "_id": 0,
                "seq": 1,
                "role": 1,
                "content": 1,
                "created_at": 1,
            },
        )
        .sort("seq", -1)
        .limit(limit + 1)
    )
    has_more = len(docs) > limit
    docs = docs[:limit]
    docs.reverse()

    messages = [
        {
            "seq": doc["seq"],
            "role": doc["role"],
            "content": doc["content"],
            "timestamp": doc["created_at"],
        }
        for doc in docs
    ]
    next_before_seq = messages[0]["seq"] if has_more and messages else None

    return {
        "chat": {
            **chat_meta,
            "messages": messages,
        },
        "page": {
            "limit": limit,
            "has_more": has_more,
            "next_before_seq": next_before_seq,
        },
    }


@app.delete("/chats/{chat_id}")
def delete_chat(chat_id: str, current_user: dict = Depends(get_current_user)):
    user_id = current_user["sub"]
    result = chats_collection.delete_one({"id": chat_id, "user_id": user_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail=CHAT_NOT_FOUND)
    messages_collection.delete_many({"chat_id": chat_id})
    return {"ok": True}


# -----------------------
# MAIN API
# -----------------------
@app.post("/chat")
def chat(data: dict, current_user: dict = Depends(get_current_user)):
    user_id = current_user["sub"]
    user_input = data.get("message", "").strip()
    chat_id = data.get("chat_id", "").strip()
    if not user_input:
        raise HTTPException(status_code=400, detail="Empty message.")
    if not chat_id:
        raise HTTPException(status_code=400, detail="chat_id is required.")
    chat_meta = get_chat_or_404(chat_id, user_id, {"_id": 0, "id": 1, "title": 1})

    user_timestamp = now_iso()
    user_message = append_message(chat_id, user_id, "user", user_input, user_timestamp)

    if chat_meta["title"] == DEFAULT_CHAT_TITLE:
        chats_collection.update_one(
            {"id": chat_id, "user_id": user_id, "title": DEFAULT_CHAT_TITLE},
            {"$set": {"title": make_title(user_input)}},
        )

    # Call model with stream parser
    model_text = call_llama(user_input)

    assistant_timestamp = now_iso()
    assistant_message = append_message(chat_id, user_id, "assistant", model_text, assistant_timestamp)
    chats_collection.update_one({"id": chat_id, "user_id": user_id}, {"$set": {"updated_at": assistant_timestamp}})
    updated_chat = get_chat_or_404(chat_id, user_id, {"_id": 0, "id": 1, "title": 1, "updated_at": 1})

    return {
        "response": model_text,
        "chat": build_chat_summary(updated_chat),
        "messages": {
            "user": user_message,
            "assistant": assistant_message,
        },
    }