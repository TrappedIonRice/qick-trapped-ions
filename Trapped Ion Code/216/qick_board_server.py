"""
qick_board_server.py

The TCP/IP "receiving" side on the board. This file knows ABOUT sockets
but nothing about QICK internals -- all the actual pulse-playing logic
lives in qick_pulse_handler.py and gets called from here. Run this on the
board; it stays running and listens, exactly like the server script from
the earlier two-script exercise, just upgraded to call real QICK code
instead of printing a message.

Wire format (must match the GUI's QICKDevices.py exactly):
    every message, either direction: [4-byte big-endian length][UTF-8 JSON]

Messages from the GUI:
    {"cmd": "load_and_run", "config": {...}, "reps": 1000, "final_delay": 0.0}
    {"cmd": "ping"}

Replies:
    {"status": "ok", "result": <acquired data, or null>}
    {"status": "error", "error": "<message>"}
"""

import socket
import struct
import json
import logging
import traceback

import qick_pulse_handler as qph

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
logger = logging.getLogger("qick_board_server")

_LENGTH_STRUCT = struct.Struct('>I')  # big-endian unsigned 4-byte length prefix -- same as the GUI side


# ------------------------------------------------------------------
# Message framing -- read/write one [length][JSON] message on a socket.
# This is the server-side mirror of QICKDevices.py's _send_message/_recv_message.
# ------------------------------------------------------------------
def recv_exactly(sock, numBytes):
    """TCP's recv() can hand back fewer bytes than you asked for, even
    mid-message -- this loops until exactly numBytes have been collected."""
    chunks = []
    remaining = numBytes
    while remaining > 0:
        chunk = sock.recv(remaining)
        if not chunk:
            raise ConnectionError("Client closed the connection unexpectedly")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b''.join(chunks)


def recv_message(sock):
    header = recv_exactly(sock, _LENGTH_STRUCT.size)
    (length,) = _LENGTH_STRUCT.unpack(header)
    payload = recv_exactly(sock, length)
    return json.loads(payload.decode('utf-8'))


def send_message(sock, messageDict):
    payload = json.dumps(messageDict).encode('utf-8')
    header = _LENGTH_STRUCT.pack(len(payload))
    sock.sendall(header + payload)


# ------------------------------------------------------------------
# Command handlers -- each one just unpacks the message and calls into
# qick_pulse_handler.py, which does the actual QICK/DAC work.
# ------------------------------------------------------------------
def handle_load_and_run(message, soc, soccfg):
    config = message['config']
    reps = message.get('reps', 1000)
    final_delay = message.get('final_delay', 0.0)
    start_src = message.get('start_src', 'internal')

    results = qph.run_pulse_schedule(config, soc, soccfg, reps=reps, final_delay=final_delay, start_src=start_src)

    try:
        result_out = _to_plain(results)
    except Exception:
        # If the acquired data can't be cleanly turned into JSON, just
        # confirm success without echoing it back rather than failing the
        # whole command.
        result_out = None

    return {'status': 'ok', 'result': result_out}


def _to_plain(obj):
    """Recursively convert numpy arrays into plain Python lists so
    json.dumps() can serialize them -- json has no concept of numpy dtypes."""
    if hasattr(obj, 'tolist'):
        return obj.tolist()
    if isinstance(obj, (list, tuple)):
        return [_to_plain(item) for item in obj]
    return obj


def handle_ping(message, soc, soccfg):
    """Cheap reachability check that doesn't touch the hardware."""
    return {'status': 'ok'}


COMMAND_HANDLERS = {
    'load_and_run': handle_load_and_run,
    'ping': handle_ping,
}


def handle_client(conn, addr, soc, soccfg):
    """Service one connected GUI client until it disconnects, handling
    each message it sends in turn."""
    logger.info(f"Client connected: {addr}")
    try:
        while True:
            try:
                message = recv_message(conn)
            except ConnectionError:
                break  # client disconnected cleanly

            cmd = message.get('cmd')
            handler = COMMAND_HANDLERS.get(cmd)
            if handler is None:
                send_message(conn, {'status': 'error', 'error': f"Unknown command '{cmd}'"})
                continue

            try:
                reply = handler(message, soc, soccfg)
            except Exception as e:
                # Never let one bad command crash the server -- report the
                # error back to the GUI and keep listening for the next one.
                logger.error(f"Error handling '{cmd}': {e}\n{traceback.format_exc()}")
                reply = {'status': 'error', 'error': str(e)}

            send_message(conn, reply)
    finally:
        conn.close()
        logger.info(f"Client disconnected: {addr}")


def main(host='0.0.0.0', port=5001):
    """Initialize the board once, then listen forever. This is the 'ready
    to accept the signal' state: after this prints 'Listening on...', the
    GUI's Connect button will succeed any time it tries."""
    soc, soccfg = qph.initialize_board()
    logger.info("Board initialized, ready to accept connections")

    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)  # allows quick restart without "address already in use"
    server_socket.bind((host, port))
    server_socket.listen(1)  # 1 connection waiting at a time -- the GUI is expected to be the only client
    logger.info(f"Listening on {host}:{port}")

    try:
        while True:
            conn, addr = server_socket.accept()  # blocks here until a client connects
            conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            handle_client(conn, addr, soc, soccfg)
            # loop back to accept() and wait for the next connection
    except KeyboardInterrupt:
        logger.info("Server shutting down")
    finally:
        server_socket.close()


if __name__ == '__main__':
    main()
