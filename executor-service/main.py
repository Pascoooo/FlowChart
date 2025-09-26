import os
import subprocess
import threading
import uuid
from flask import Flask
from flask_sockets import Sockets
from gevent import pywsgi
from geventwebsocket.handler import WebSocketHandler

# Inizializza l'applicazione Flask e l'estensione Sockets
app = Flask(__name__)
sockets = Sockets(app)

def execute_c_code(ws, code):
    """
    Compila ed esegue il codice C in modo interattivo, gestendo I/O tramite WebSocket.
    """
    # Genera un nome di file univoco per evitare conflitti
    session_id = str(uuid.uuid4())
    source_filename = f"/tmp/{session_id}.c"
    executable_filename = f"/tmp/{session_id}"

    try:
        # 1. Scrive il codice C ricevuto in un file temporaneo
        with open(source_filename, "w") as f:
            f.write(code)

        # 2. Compila il codice C usando gcc
        compile_process = subprocess.run(
            ["gcc", source_filename, "-o", executable_filename],
            capture_output=True, text=True, timeout=10
        )

        # Se la compilazione fallisce, invia l'errore al client e termina
        if compile_process.returncode != 0:
            error_message = f"[ERRORE DI COMPILAZIONE]\n{compile_process.stderr}"
            ws.send(error_message)
            return

        # 3. Esegue il programma compilato
        ws.send("[ESECUZIONE AVVIATA]")
        proc = subprocess.Popen(
            [executable_filename],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,  # Line-buffered
            universal_newlines=True
        )

        # Funzione per leggere l'output (stdout) del programma C in un thread separato
        def read_output():
            for line in iter(proc.stdout.readline, ''):
                # Invia ogni riga di output immediatamente al client Flutter
                ws.send(line.strip())
            proc.stdout.close()

        output_thread = threading.Thread(target=read_output)
        output_thread.start()

        # 4. Gestisce l'input/output interattivo
        while proc.poll() is None:
            # Attende un messaggio (input) dal client Flutter
            message = ws.receive()
            if message:
                try:
                    # Invia l'input ricevuto al programma C in esecuzione
                    proc.stdin.write(message + '\n')
                    proc.stdin.flush()
                except (IOError, BrokenPipeError):
                    # Il processo potrebbe essere terminato mentre attendevamo l'input
                    break

        output_thread.join(timeout=2) # Attende che il thread di output termini

    except subprocess.TimeoutExpired:
        ws.send("\n[ERRORE] L'esecuzione ha superato il limite di tempo.")
    except Exception as e:
        ws.send(f"\n[ERRORE DEL SERVER] Si è verificato un errore: {e}")
    finally:
        # 5. Pulizia dei file temporanei e chiusura del processo
        if 'proc' in locals() and proc.poll() is None:
            proc.kill()
        if os.path.exists(source_filename):
            os.remove(source_filename)
        if os.path.exists(executable_filename):
            os.remove(executable_filename)
        ws.send("[ESECUZIONE TERMINATA]")
        ws.close()

@sockets.route('/console')
def console_socket(ws):
    """
    Endpoint WebSocket. Attende il codice C, poi avvia l'esecuzione.
    """
    try:
        # Il primo messaggio che ci aspettiamo è il codice C da eseguire
        initial_code = ws.receive()
        if initial_code:
            # Avvia la funzione di esecuzione
            execute_c_code(ws, initial_code)
    except Exception as e:
        # Gestisce errori nella connessione WebSocket
        app.logger.error(f"Errore nel WebSocket: {e}")
    finally:
        # Assicura che il socket sia chiuso se non lo è già
        if not ws.closed:
            ws.close()

@app.route('/')
def health_check():
    """
    Endpoint HTTP di base per verificare che il server sia in esecuzione.
    """
    return "Backend interattivo per C in esecuzione!", 200

# Questo blocco non è strettamente necessario per Cloud Run, ma utile per test locali
if __name__ == "__main__":
    print("Avvio del server su http://127.0.0.1:8080")
    server = pywsgi.WSGIServer(('0.0.0.0', 8080), app, handler_class=WebSocketHandler)
    server.serve_forever()