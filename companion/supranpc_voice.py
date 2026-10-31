#!/usr/bin/env python3
"""SupraNPC offline PT-BR microphone bridge (Windows, or other supported OS).
Uses native game Lua file APIs and a local faster-whisper model.
No HTTP server, online transcription or Win+H; model download only on first run.
Start this program before PZ. Speech is processed after releasing PTT.
"""
from __future__ import annotations
import argparse
import os
import re
import sys
import time
import threading
from pathlib import Path

FILES = {
    "request": "SupraNPC_voice_request.txt",
    "result": "SupraNPC_voice_result.txt",
    "status": "SupraNPC_voice_status.txt",
}

def cache_dir() -> Path:
    return Path(os.environ.get("SUPRANPC_LUA_DIR", Path.home() / "Zomboid" / "Lua"))

def read_line(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig").splitlines()[0].strip()
    except (FileNotFoundError, IndexError, PermissionError, UnicodeError):
        return ""

def put_line(path: Path, line: str):
    """Write a short complete single-line response; atomic on Windows."""
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(line.replace("\r", " ").replace("\n", " ") + "\n", encoding="utf-8")
    os.replace(tmp, path)

class Voice:
    def __init__(self, folder: Path, model_name: str = "base", device: str = None):
        self.folder = folder
        self.model_name = model_name
        self.device = device
        self.stream = None
        self.frames = []
        self.session = None
        self.lock = threading.RLock()
        self.busy = False
        self.engine = None

    def _capture(self, indata, frames, time_info, status):
        with self.lock:
            if self.stream is not None and len(self.frames) < 3000:
                self.frames.append(indata.copy())

    def start(self, request: str):
        with self.lock:
            if self.busy or self.stream is not None:
                self.respond("ERROR", request, "transcricao anterior em andamento")
                return
            try:
                import sounddevice as sd
                stream = sd.InputStream(samplerate=16000, channels=1, dtype="float32",
                                        device=self.device, callback=self._capture)
                self.frames = []
                self.session = request
                self.stream = stream
                stream.start()
                print("Capturando audio - solte a tecla para transcrever", flush=True)
            except Exception as exc:
                self.stream = None
                self.session = None
                self.respond("ERROR", request, "microfone: " + str(exc))

    def stop(self, request: str):
        with self.lock:
            if self.session != request or self.stream is None:
                self.respond("ERROR", request, "captura nao iniciada")
                return
            stream = self.stream
            self.stream = None
            audio = self.frames[:]
            self.frames = []
            self.session = None
            try:
                stream.stop()
                stream.close()
            except Exception:
                pass
            self.busy = True
            threading.Thread(target=self.transcribe, args=(request, audio), daemon=True).start()

    def transcribe(self, request: str, frames):
        try:
            import numpy as np
            from faster_whisper import WhisperModel
            if not frames:
                raise ValueError("nenhum audio capturado")
            audio = np.concatenate(frames, axis=0).reshape(-1).astype("float32")
            if len(audio) < 1600:
                raise ValueError("fale por pelo menos 0,1 segundo")
            if self.engine is None:
                print("Carregando modelo Whisper PT-BR (primeira vez pode baixar)...", flush=True)
                self.engine = WhisperModel(self.model_name, device="cpu", compute_type="int8")
            segments, info = self.engine.transcribe(audio, language="pt", beam_size=1,
                vad_filter=True, condition_on_previous_text=False)
            text = " ".join(s.text.strip() for s in segments)
            text = re.sub(r"\s+", " ", text).strip().replace("|", " ")
            if not text:
                raise ValueError("nenhuma fala reconhecida")
            print("Reconhecido:", text, flush=True)
            self.respond("TRANSCRIPT", request, text[:200])
        except Exception as exc:
            print("STT error:", repr(exc), file=sys.stderr, flush=True)
            self.respond("ERROR", request, str(exc)[:180].replace("|", " "))
        finally:
            with self.lock:
                self.busy = False

    def respond(self, kind: str, request: str, value: str):
        put_line(self.folder / FILES["result"], f"{kind}|{request}|{value}")

def parse_command(text: str):
    match = re.fullmatch(r"(START|STOP)\|([0-9]{1,12})", text)
    return match.groups() if match else None

def serve(folder: Path, model: str, device: str = None, loop_delay: float = 0.03):
    folder.mkdir(parents=True, exist_ok=True)
    voice = Voice(folder, model, device)
    req = folder / FILES["request"]
    status = folder / FILES["status"]
    last = read_line(req)   # ignore stale commands left from earlier game sessions
    last_heartbeat = 0.0
    beat = 0
    print(f"SupraNPC local STT PT-BR: {folder}", flush=True)
    print("Abra o jogo, segure Mouse Btn 3 e fale; solte para enviar.", flush=True)
    while True:
        now = time.monotonic()
        if now - last_heartbeat >= 0.45:
            beat += 1
            put_line(status, f"READY|{beat}")
            last_heartbeat = now
        cmd = read_line(req)
        if cmd and cmd != last:
            last = cmd
            parsed = parse_command(cmd)
            if parsed:
                action, token = parsed
                if action == "START":
                    voice.start(token)
                else:
                    voice.stop(token)
        time.sleep(loop_delay)

def main():
    parser = argparse.ArgumentParser(description="SupraNPC offline PT-BR voice companion")
    parser.add_argument("--model", default="base", help="Whisper model (tiny, base, small)")
    parser.add_argument("--device", default=None, help="sounddevice audio input device")
    parser.add_argument("--directory", type=Path, default=cache_dir())
    args = parser.parse_args()
    try:
        serve(args.directory, args.model, args.device)
    except KeyboardInterrupt:
        print("STT encerrado.", flush=True)
    return 0

if __name__ == "__main__":
    sys.exit(main())
