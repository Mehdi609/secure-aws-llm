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
# from pymongo import MongoClient, ReturnDocument
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

import boto3
from boto3.dynamodb.conditions import Key


load_dotenv()

AWS_REGION = os.getenv("AWS_REGION", "us-west-1")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5:1.5b")
OLLAMA_TIMEOUT_SECONDS = int(os.getenv("OLLAMA_TIMEOUT_SECONDS", "180"))
OLLAMA_NUM_CTX = int(os.getenv("OLLAMA_NUM_CTX", "2048"))
OLLAMA_NUM_PREDICT = int(os.getenv("OLLAMA_NUM_PREDICT", "256"))
OLLAMA_NUM_THREAD = int(os.getenv("OLLAMA_NUM_THREAD", "2"))
OLLAMA_TEMPERATURE = float(os.getenv("OLLAMA_TEMPERATURE", "0.3"))
OLLAMA_KEEP_ALIVE = os.getenv("OLLAMA_KEEP_ALIVE", "30m")

dynamodb = boto3.resource(
    "dynamodb",
    region_name=AWS_REGION
)

users_table = dynamodb.Table("SecureLLM-Users")
chats_table = dynamodb.Table("SecureLLM-Chats")
messages_table = dynamodb.Table("SecureLLM-Messages")



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




app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
    ollama_url = os.getenv("OLLAMA_URL") or os.getenv("AI_BASE_URL", "http://ollama:11434")
    try:
        response = requests.post(
            f"{ollama_url.rstrip('/')}/api/generate",
            json={
                "model": OLLAMA_MODEL,
                "prompt": styled_prompt,
                "stream": True,
                "keep_alive": OLLAMA_KEEP_ALIVE,
                "options": {
                    "num_ctx": OLLAMA_NUM_CTX,
                    "num_predict": OLLAMA_NUM_PREDICT,
                    "num_thread": OLLAMA_NUM_THREAD,
                    "temperature": OLLAMA_TEMPERATURE,
                },
            },
            stream=True,
            timeout=OLLAMA_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
    except requests.exceptions.Timeout as exc:
        raise HTTPException(
            status_code=504,
            detail="The model took too long to answer. Try a shorter prompt or check Ollama CPU/RAM usage.",
        ) from exc
    except requests.exceptions.ConnectionError as exc:
        raise HTTPException(
            status_code=502,
            detail="FastAPI cannot connect to Ollama. Check OLLAMA_URL and that the Ollama container is running.",
        ) from exc
    except requests.exceptions.HTTPError as exc:
        detail = response.text.strip() if response is not None else str(exc)
        raise HTTPException(
            status_code=502,
            detail=f"Ollama returned an error for model '{OLLAMA_MODEL}': {detail}",
        ) from exc

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
    if not raw_text:
        raise HTTPException(status_code=502, detail="Ollama returned an empty response.")
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
        "id": chat["chat_id"],
        "title": chat["title"],
        "timestamp": chat["updated_at"],
    }


# def get_chat_or_404(chat_id: str, user_id: str, projection: Dict | None = None) -> Dict:
#     chat = chats_collection.find_one({"id": chat_id, "user_id": user_id}, projection or {"_id": 0})
#     if not chat:
#         raise HTTPException(status_code=404, detail=CHAT_NOT_FOUND)
#     chat.pop("_id", None)
#     return chat

def get_chat_or_404(chat_id: str, user_id: str):
    response = chats_table.get_item(
        Key={"chat_id": chat_id}
    )

    chat = response.get("Item")

    if not chat or chat["user_id"] != user_id:
        raise HTTPException(status_code=404, detail=CHAT_NOT_FOUND)

    return chat

def reserve_next_seq(chat_id: str, user_id: str) -> int:
    response = chats_table.update_item(
        Key={"chat_id": chat_id},
        UpdateExpression="SET next_seq = next_seq + :inc",
        ConditionExpression="user_id = :uid",
        ExpressionAttributeValues={
            ":inc": 1,
            ":uid": user_id
        },
        ReturnValues="UPDATED_NEW"
    )

    return int(response["Attributes"]["next_seq"])


def append_message(
    chat_id: str,
    user_id: str,
    role: str,
    content: str,
    timestamp: str
) -> Dict:

    seq = reserve_next_seq(chat_id, user_id)

    messages_table.put_item(
        Item={
            "chat_id": chat_id,
            "seq": seq,
            "role": role,
            "content": content,
            "created_at": timestamp,
        }
    )

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
    response = chats_table.query(
        IndexName="UserChatsIndex",
        KeyConditionExpression=Key("user_id").eq(current_user["sub"])
    )

    chats = response.get("Items", [])

    chats.sort(
        key=lambda x: x.get("updated_at", ""),
        reverse=True
    )

    return {
        "chats": [
            build_chat_summary(chat)
            for chat in chats[:limit]
        ]
    }

@app.get("/chats/{chat_id}")
def get_chat(
    chat_id: str,
    limit: int = Query(DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE),
    before_seq: int | None = Query(None, ge=1),
    current_user: dict = Depends(get_current_user)
):
    chat_meta = get_chat_or_404(
        chat_id,
        current_user["sub"]
    )

    if before_seq is not None:
        response = messages_table.query(
            KeyConditionExpression=
                Key("chat_id").eq(chat_id) &
                Key("seq").lt(before_seq),
            ScanIndexForward=False,
            Limit=limit + 1
        )
    else:
        response = messages_table.query(
            KeyConditionExpression=
                Key("chat_id").eq(chat_id),
            ScanIndexForward=False,
            Limit=limit + 1
        )

    docs = response.get("Items", [])

    has_more = len(docs) > limit
    docs = docs[:limit]
    docs.reverse()

    messages = [
        {
            "seq": msg["seq"],
            "role": msg["role"],
            "content": msg["content"],
            "timestamp": msg["created_at"],
        }
        for msg in docs
    ]

    next_before_seq = (
        messages[0]["seq"]
        if has_more and messages
        else None
    )

    return {
        "chat": {
            "id": chat_meta["chat_id"],
            "title": chat_meta["title"],
            "created_at": chat_meta["created_at"],
            "updated_at": chat_meta["updated_at"],
            "messages": messages,
        },
        "page": {
            "limit": limit,
            "has_more": has_more,
            "next_before_seq": next_before_seq,
        },
    }

@app.delete("/chats/{chat_id}")
def delete_chat(
    chat_id: str,
    current_user: dict = Depends(get_current_user)
):
    user_id = current_user["sub"]

    get_chat_or_404(chat_id, user_id)

    chats_table.delete_item(
        Key={"chat_id": chat_id}
    )

    last_evaluated_key = None

    while True:

        query_args = {
            "KeyConditionExpression": Key("chat_id").eq(chat_id)
        }

        if last_evaluated_key:
            query_args["ExclusiveStartKey"] = last_evaluated_key

        response = messages_table.query(**query_args)

        with messages_table.batch_writer() as batch:
            for message in response.get("Items", []):
                batch.delete_item(
                    Key={
                        "chat_id": chat_id,
                        "seq": message["seq"]
                    }
                )

        last_evaluated_key = response.get("LastEvaluatedKey")

        if not last_evaluated_key:
            break

    return {"ok": True}
    



# -----------------------
# MAIN API
# -----------------------
@app.get("/health")
def health():
    return {"ok": True}


@app.post("/chat")
def chat(data: dict, current_user: dict = Depends(get_current_user)):
    user_id = current_user["sub"]

    user_input = data.get("message", "").strip()
    chat_id = data.get("chat_id", "").strip()

    if not user_input:
        raise HTTPException(status_code=400, detail="Empty message.")

    if not chat_id:
        raise HTTPException(status_code=400, detail="chat_id is required.")

    chat_meta = get_chat_or_404(chat_id, user_id)

    user_timestamp = now_iso()

    user_message = append_message(
        chat_id,
        user_id,
        "user",
        user_input,
        user_timestamp
    )

    if chat_meta["title"] == DEFAULT_CHAT_TITLE:
        chats_table.update_item(
            Key={"chat_id": chat_id},
            UpdateExpression="SET title = :title",
            ExpressionAttributeValues={
                ":title": make_title(user_input)
            }
        )

    model_text = call_llama(user_input)

    assistant_timestamp = now_iso()

    assistant_message = append_message(
        chat_id,
        user_id,
        "assistant",
        model_text,
        assistant_timestamp
    )

    chats_table.update_item(
        Key={"chat_id": chat_id},
        UpdateExpression="SET updated_at = :ts",
        ExpressionAttributeValues={
            ":ts": assistant_timestamp
        }
    )

    updated_chat = get_chat_or_404(chat_id, user_id)

    return {
        "response": model_text,
        "chat": build_chat_summary(updated_chat),
        "messages": {
            "user": user_message,
            "assistant": assistant_message,
        },
    }

@app.post("/chats")
def create_chat(current_user: dict = Depends(get_current_user)):
    print("CREATE_CHAT CALLED")

    chat_id = str(uuid4())
    timestamp = now_iso()

    chat_doc = {
        "chat_id": chat_id,
        "user_id": current_user["sub"],
        "title": DEFAULT_CHAT_TITLE,
        "created_at": timestamp,
        "updated_at": timestamp,
        "next_seq": 0,
    }

    print("USER:", current_user["sub"])
    print("WRITING CHAT:", chat_doc)

    chats_table.put_item(Item=chat_doc)

    return {
        "chat": {
            "id": chat_doc["chat_id"],
            "title": chat_doc["title"],
            "timestamp": chat_doc["updated_at"]
        }
    }
