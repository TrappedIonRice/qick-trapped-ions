#!/usr/bin/env python3
"""QICK Pyro server for the ZCU216. This script runs ON THE BOARD and replaces the server notebook.

The GUI starts it through PuTTY with a command like
    sudo -i /usr/local/share/pynq-venv/bin/python3 "<folder>/rfsoc_server.py" --bitfile <path to .bit>
It starts the Pyro nameserver (unless one is already running), loads the firmware, and serves the board as a FastQickSoc:
the stock QickSoc plus
  * wait_round_and_rearm: waits for a shot to finish and re-arms the external trigger on the board in one call
    (measured blind time about 0.1 ms, against 1-4 ms when the PC re-arms), and
  * request_shutdown: lets the GUI stop this server cleanly.
Closing the PuTTY window also stops it. Only Python 3.8 syntax is used here, because the board's PYNQ environment is 3.8.
"""
import argparse
import importlib.util
import os
import signal
import subprocess
import sys
import threading
import time

DEFAULT_BITFILE = ("/home/xilinx/jupyter_notebooks/qick/firmware/projects/"
                   "qick_tprocv2_216_rfbv2_16mixmux16/out/qick_216_rfbv2.bit")
DEFAULT_QICK_SEARCH_PATHS = ["/home/xilinx/jupyter_notebooks/qick/qick_lib", "/home/xilinx/jupyter_notebooks/qick"]
NAMESERVER_START_WAIT_S = 10.0

_nameserver_process = None


def parse_arguments(argument_list=None):
    """Read the command-line options (bitfile, nameserver port, proxy name, clock source)."""
    parser = argparse.ArgumentParser(description="QICK Pyro server for the ZCU216 (FastQickSoc)")
    parser.add_argument("--bitfile", default=DEFAULT_BITFILE, help="firmware .bit file on the board")
    parser.add_argument("--ns-port", type=int, default=8888, help="Pyro nameserver port")
    parser.add_argument("--proxy", default="myqick", help="name the board is registered under")
    parser.add_argument("--internal-clk", action="store_true", help="use the internal clock (default: external reference)")
    return parser.parse_args(argument_list)


def ensure_qick_importable(search_paths=None):
    """Make `import qick` work: return None if it already does, else add the first search path that contains it."""
    if importlib.util.find_spec("qick") is not None:
        return None
    search_paths = DEFAULT_QICK_SEARCH_PATHS if search_paths is None else search_paths
    for candidate in search_paths:
        if os.path.isdir(os.path.join(candidate, "qick")):
            sys.path.insert(0, candidate)
            existing = os.environ.get("PYTHONPATH", "")
            os.environ["PYTHONPATH"] = candidate + (os.pathsep + existing if existing else "")   # for the nameserver process
            return candidate
    raise SystemExit("RFSOC_SERVER: cannot find the qick package; searched " + ", ".join(search_paths))


def nameserver_is_running(port):
    """True if a Pyro nameserver answers on localhost at this port."""
    import Pyro4
    Pyro4.config.SERIALIZER = "pickle"
    try:
        Pyro4.locateNS(host="localhost", port=port)
        return True
    except Exception:
        return False


def start_nameserver(port, wait_seconds=NAMESERVER_START_WAIT_S):
    """Start the nameserver in its own process unless one is running; returns the process (or None if reusing one)."""
    if nameserver_is_running(port):
        print("RFSOC_SERVER: nameserver already running on port %d" % port, flush=True)
        return None
    command = [sys.executable, "-c",
               "from qick.pyro import start_nameserver; start_nameserver(ns_host='0.0.0.0', ns_port=%d)" % port]
    process = subprocess.Popen(command, env=dict(os.environ))
    deadline = time.time() + wait_seconds
    while time.time() < deadline:
        if nameserver_is_running(port):
            print("RFSOC_SERVER: nameserver started on port %d" % port, flush=True)
            return process
        time.sleep(0.3)
    process.terminate()
    raise SystemExit("RFSOC_SERVER: the nameserver did not start within %.0f s" % wait_seconds)


def shutdown_now():
    """Stop the nameserver process this script started, then end this process immediately."""
    if _nameserver_process is not None:
        try:
            _nameserver_process.terminate()
        except OSError:
            pass
    os._exit(0)


def build_fast_soc_class():
    """Define and return FastQickSoc (this needs the qick package, so it is done only after qick is importable)."""
    from qick import QickSoc

    class FastQickSoc(QickSoc):
        """QickSoc plus board-side re-arming and a remote stop."""

        def wait_round_and_rearm(self, total_count, counter_addr=1, rearm=True, reload_mem=False, timeout_s=None):
            """Wait until the running round has completed, then (optionally) re-arm the external start at once.

            Returns {"done": bool, "dead_ms": float}; dead_ms is the board-side time from 'round finished' to 'armed again'.
            With timeout_s the call gives up after that long and returns done=False, so the client can check for new commands.
            """
            started = time.perf_counter()
            while self.get_tproc_counter(addr=counter_addr) < total_count:
                if timeout_s is not None and (time.perf_counter() - started) > timeout_s:
                    return {"done": False}
            finished_at = time.perf_counter()
            if rearm:
                if reload_mem:
                    self.reload_mem()
                self.clear_tproc_counter(addr=counter_addr)
                self.start_src("external")
            return {"done": True, "dead_ms": (time.perf_counter() - finished_at) * 1e3}

        def request_shutdown(self):
            """Stop this server process a moment after replying (used by the GUI's Stop button)."""
            threading.Timer(0.3, shutdown_now).start()
            return True

    return FastQickSoc


def main(argument_list=None):
    """Start the nameserver, load the firmware and serve the board; returns an exit code (the server call blocks)."""
    global _nameserver_process
    arguments = parse_arguments(argument_list)
    if not os.path.exists(arguments.bitfile):
        print("RFSOC_SERVER: firmware file not found: %s" % arguments.bitfile, flush=True)
        return 2
    try:
        import Pyro4   # noqa: F401
    except ImportError:
        print("RFSOC_SERVER: Pyro4 is not installed in this Python (%s); install it from /home/xilinx/pyro_wheels" % sys.executable,
              flush=True)
        return 3
    ensure_qick_importable()
    for signal_name in ("SIGHUP", "SIGTERM"):
        if hasattr(signal, signal_name):
            signal.signal(getattr(signal, signal_name), lambda signal_number, frame: shutdown_now())
    _nameserver_process = start_nameserver(arguments.ns_port)
    fast_soc_class = build_fast_soc_class()
    print("RFSOC_SERVER: loading firmware %s (this takes a while)" % arguments.bitfile, flush=True)
    from qick.pyro import start_server
    start_server(ns_host="localhost", ns_port=arguments.ns_port, proxy_name=arguments.proxy, soc_class=fast_soc_class,
                 bitfile=arguments.bitfile, external_clk=not arguments.internal_clk)
    return 0


if __name__ == "__main__":
    sys.exit(main())
