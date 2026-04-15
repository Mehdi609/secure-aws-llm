import { useEffect, useMemo, useState, useCallback } from "react";
import ReactMarkdown from "react-markdown";
import { GoogleLogin, googleLogout } from "@react-oauth/google";
import { jwtDecode } from "jwt-decode";

const API_BASE = "http://localhost:8000";

function formatTimestamp(value) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleString([], {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function App() {
  const [token, setToken] = useState(localStorage.getItem("token") || null);
  const [user, setUser] = useState(() => {
    try {
      return token ? jwtDecode(token) : null;
    } catch {
      return null;
    }
  });

  const handleLoginSuccess = (credentialResponse) => {
    const t = credentialResponse.credential;
    setToken(t);
    localStorage.setItem("token", t);
    setUser(jwtDecode(t));
  };

  const handleLogout = () => {
    googleLogout();
    setToken(null);
    setUser(null);
    localStorage.removeItem("token");
    setChatHistory([]);
    setMessages([]);
    setActiveChatId("");
  };

  const [message, setMessage] = useState("");
  const [messages, setMessages] = useState([]);
  const [chatHistory, setChatHistory] = useState([]);
  const [activeChatId, setActiveChatId] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [isSidebarOpen, setIsSidebarOpen] = useState(true);
  const [isLoading, setIsLoading] = useState(false);

  const filteredChats = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) return chatHistory;
    return chatHistory.filter((chat) => chat.title.toLowerCase().includes(q));
  }, [chatHistory, searchQuery]);

  const fetchWithAuth = useCallback(async (url, options = {}) => {
    const headers = {
      ...(options.headers || {}),
      "Authorization": `Bearer ${token}`
    };
    const res = await fetch(url, { ...options, headers });
    if (res.status === 401) {
      handleLogout();
      return null; // Will cause JSON parsing to fail implicitly handled below by optional chaining. Better to throw but let's just keep it simple.
    }
    return res;
  }, [token]);

  const fetchChats = useCallback(async () => {
    if (!token) return [];
    try {
      const res = await fetchWithAuth(`${API_BASE}/chats`);
      if (!res) return [];
      const data = await res.json();
      const chats = data.chats || [];
      setChatHistory(chats);
      return chats;
    } catch (e) {
      return [];
    }
  }, [token, fetchWithAuth]);

  const loadChat = useCallback(async (chatId) => {
    if (!chatId || !token) return;
    setActiveChatId(chatId);
    try {
      const res = await fetchWithAuth(`${API_BASE}/chats/${chatId}`);
      if (!res) return;
      const data = await res.json();
      if (data.chat?.messages) {
        setMessages(data.chat.messages);
      } else {
        setMessages([]);
      }
    } catch (e) {}
  }, [token, fetchWithAuth]);

  const createNewChat = async () => {
    if (isLoading || !token) return;
    try {
      const res = await fetchWithAuth(`${API_BASE}/chats`, { method: "POST" });
      if (!res) return;
      const data = await res.json();
      const created = data.chat;
      if (!created?.id) return;
      await fetchChats();
      await loadChat(created.id);
    } catch (e) {}
  };

  const removeChat = async (chatId) => {
    if (!token) return;
    try {
      const res = await fetchWithAuth(`${API_BASE}/chats/${chatId}`, {
        method: "DELETE",
      });
      if (!res) return;
      const data = await res.json();
      if (!data.ok) return;
      const chats = await fetchChats();
      if (chatId === activeChatId) {
        if (chats.length > 0) {
          await loadChat(chats[0].id);
        } else {
          setActiveChatId("");
          setMessages([]);
        }
      }
    } catch (e) {}
  };

  useEffect(() => {
    const init = async () => {
      const chats = await fetchChats();
      if (chats.length > 0) {
        await loadChat(chats[0].id);
      } else {
        await createNewChat();
      }
    };
    if (token) {
      init();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  const sendMessage = async () => {
    const trimmedMessage = message.trim();
    if (!trimmedMessage || isLoading || !activeChatId) return;

    const optimisticUser = {
      role: "user",
      content: trimmedMessage,
      timestamp: new Date().toISOString(),
    };
    setMessages((prev) => [...prev, optimisticUser]);
    setMessage("");
    setIsLoading(true);

    try {
      const res = await fetchWithAuth(`${API_BASE}/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: trimmedMessage, chat_id: activeChatId }),
      });
      if (!res) return;

      const data = await res.json();
    const aiReply = data.response || data.error || "No response received.";
    if (data.chat?.messages) {
      setMessages(data.chat.messages);
    } else {
      setMessages((prev) => [...prev, { role: "assistant", content: aiReply }]);
    }
      await fetchChats();
    } catch (e) {} finally {
      setIsLoading(false);
    }
  };

  if (!token) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-black px-4">
        <div className="w-full max-w-md rounded-2xl border border-gray-800 bg-gray-900 p-8 text-center shadow-xl shadow-black/50">
          <h1 className="mb-2 text-3xl font-bold text-white">Dolphin LLM</h1>
          <p className="mb-8 text-gray-400">Sign in to start your AI sessions</p>
          <div className="flex justify-center">
            <GoogleLogin
              onSuccess={handleLoginSuccess}
              onError={() => console.error("Login Failed")}
              theme="filled_blue"
              shape="pill"
            />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="h-screen bg-black text-white">
      <div className="flex h-full w-full overflow-hidden">
        <aside
          className={`relative h-full border-r border-gray-800 bg-gray-950 transition-all duration-300 ease-in-out ${
            isSidebarOpen ? "w-80" : "w-0"
          }`}
        >
          <div
            className={`h-full overflow-hidden transition-opacity duration-200 ${
              isSidebarOpen ? "opacity-100" : "pointer-events-none opacity-0"
            }`}
          >
            <div className="flex h-full flex-col p-3">
              <button
                onClick={createNewChat}
                className="mb-3 rounded-xl border border-gray-700 bg-white px-4 py-2 text-sm font-medium text-black transition hover:bg-gray-200"
              >
                + New Chat
              </button>
              <input
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search chats..."
                className="mb-3 w-full rounded-xl border border-gray-700 bg-black px-3 py-2 text-sm text-white placeholder:text-gray-500 outline-none focus:border-gray-500"
              />
              <div className="flex-1 space-y-2 overflow-y-auto">
                {filteredChats.map((chat) => (
                  <button
                    key={chat.id}
                    onClick={() => loadChat(chat.id)}
                    className={`group w-full rounded-xl border px-3 py-3 text-left transition ${
                      chat.id === activeChatId
                        ? "border-gray-500 bg-gray-800"
                        : "border-gray-800 bg-gray-900 hover:border-gray-700"
                    }`}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <p className="truncate text-sm font-medium text-white">
                          {chat.title}
                        </p>
                        <p className="mt-1 text-xs text-gray-400">
                          {formatTimestamp(chat.timestamp)}
                        </p>
                      </div>
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          removeChat(chat.id);
                        }}
                        className="rounded-md px-2 py-1 text-xs text-gray-400 opacity-0 transition hover:bg-gray-700 hover:text-white group-hover:opacity-100"
                      >
                        Delete
                      </button>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </div>
        </aside>

        <div className="flex min-w-0 flex-1 flex-col px-3 py-4 sm:px-5 sm:py-6">
          <header className="mb-4 flex items-center gap-3 rounded-2xl border border-gray-800 bg-gray-900 px-5 py-4 shadow-lg shadow-black/40">
            <button
              onClick={() => setIsSidebarOpen((prev) => !prev)}
              className="rounded-lg border border-gray-700 bg-black px-3 py-2 text-sm text-gray-200 transition hover:bg-gray-800"
            >
              {isSidebarOpen ? "←" : "→"}
            </button>
            <div className="flex-1">
              <h1 className="text-xl font-semibold text-white">Dolphin LLM</h1>
              <p className="mt-1 text-sm text-gray-400">
                Ask anything and get instant AI-powered answers.
              </p>
            </div>
            {user && (
              <div className="flex items-center gap-3">
                <img
                  src={user.picture}
                  alt="Profile"
                  className="h-8 w-8 rounded-full border border-gray-700"
                />
                <button
                  onClick={handleLogout}
                  className="rounded-lg border border-gray-700 bg-black px-3 py-1 text-sm text-gray-300 hover:bg-gray-800"
                >
                  Logout
                </button>
              </div>
            )}
          </header>

          <main className="flex-1 overflow-hidden rounded-2xl border border-gray-800 bg-gray-900 shadow-xl shadow-black/40">
            <div className="h-full overflow-y-auto px-3 py-4 sm:px-5 sm:py-6">
              <div className="mx-auto flex w-full max-w-3xl flex-col gap-4">
                {messages.length === 0 && (
                  <div className="rounded-2xl border border-gray-800 bg-gray-900 px-4 py-5 text-center text-sm text-gray-400">
                    Start a conversation with Ollama AI.
                  </div>
                )}

                {messages.map((chatMessage, index) => (
                  <div
                    key={`${chatMessage.role}-${index}`}
                    className={`animate-fadeIn ${
                      chatMessage.role === "user" ? "ml-auto" : "mr-auto"
                    } max-w-[85%] sm:max-w-[75%]`}
                  >
                    <div
                      className={`rounded-2xl px-4 py-3 text-sm leading-relaxed shadow-md ${
                        chatMessage.role === "user"
                          ? "bg-white text-black shadow-black/30"
                          : "bg-gray-800 text-white shadow-black/40"
                      }`}
                    >
                      {chatMessage.role === "assistant" ? (
                        <div className="prose prose-invert prose-sm max-w-none">
                          <ReactMarkdown>{chatMessage.content}</ReactMarkdown>
                        </div>
                      ) : (
                        <div className="whitespace-pre-wrap">
                          {chatMessage.content}
                        </div>
                      )}
                    </div>
                  </div>
                ))}
                {isLoading && (
                  <div className="mr-auto max-w-[75%] animate-fadeIn">
                    <div className="inline-flex items-center gap-2 rounded-2xl bg-gray-800 px-4 py-3 text-sm text-gray-300 shadow-md shadow-black/40">
                      <span className="h-2 w-2 animate-bounce rounded-full bg-gray-400 [animation-delay:-0.3s]" />
                      <span className="h-2 w-2 animate-bounce rounded-full bg-gray-400 [animation-delay:-0.15s]" />
                      <span className="h-2 w-2 animate-bounce rounded-full bg-gray-400" />
                      <span className="ml-1 text-gray-400">Thinking...</span>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </main>

          <footer className="sticky bottom-0 mt-4 rounded-2xl border border-gray-800 bg-gray-900 p-3 shadow-lg shadow-black/40 backdrop-blur">
            <div className="mx-auto flex w-full max-w-3xl items-center gap-2 sm:gap-3">
              <input
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    e.preventDefault();
                    sendMessage();
                  }
                }}
                placeholder="Ask something..."
                className="w-full rounded-xl border border-gray-700 bg-black px-4 py-3 text-sm text-white placeholder:text-gray-500 outline-none transition focus:border-gray-500 focus:ring-2 focus:ring-gray-500/30"
              />

              <button
                onClick={sendMessage}
                disabled={!message.trim() || isLoading || !activeChatId}
                className="inline-flex items-center justify-center rounded-xl bg-white px-4 py-3 text-sm font-medium text-black shadow-md shadow-black/30 transition hover:bg-gray-200 focus:outline-none focus:ring-2 focus:ring-gray-400/50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <span className="hidden sm:inline">Send</span>
                <svg
                  className="h-4 w-4 sm:ml-2"
                  viewBox="0 0 24 24"
                  fill="none"
                  xmlns="http://www.w3.org/2000/svg"
                >
                  <path
                    d="M5 12H19M19 12L13 6M19 12L13 18"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </button>
            </div>
          </footer>
        </div>
      </div>
    </div>
  );
}

export default App;
