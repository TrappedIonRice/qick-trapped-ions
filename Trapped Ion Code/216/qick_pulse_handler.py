"""
qick_pulse_handler.py

Board-side QICK logic ONLY -- no networking. Given a config dict (same
shape as your notebook's `config = {...}`), this initializes the board
once and can run any number of pulse schedules on it. You could import
this in a Jupyter cell right now and call run_pulse_schedule(config) and
get exactly the notebook's behavior.

The TCP/IP layer (a later step) will just be a thin wrapper that receives
a config over the network and calls run_pulse_schedule() with it -- it
won't need to know anything about tones, DACs, or QICK.
"""

import logging
from pathlib import Path
import os
from collections import defaultdict

logger = logging.getLogger("qick_pulse_handler")

# DDS Nyquist-zone bandwidth used to pick a mixer frequency that fits every
# tone on a channel into one mux window (same constant as the notebook).
F_DDS = 430.08  # MHz


def initialize_board():
    """Load the firmware bitstream and return (soc, soccfg) -- identical
    to your notebook's init cell. Called once, whenever this program
    starts up."""
    base = Path("/home/xilinx/jupyter_notebooks/qick/firmware/projects/qick_tprocv2_216_16mixmux16")
    out_dir = base / "out"

    # Recreate the firmware symlinks (same fix your notebook applied for
    # "the non-working links").
    for name in ["qick_216.bit", "qick_216.hwh"]:
        f = out_dir / name
        if f.exists() or f.is_symlink():
            f.unlink()
    os.symlink("../top/top.runs/impl_1/d_1_wrapper.bit", str(out_dir / "qick_216.bit"))
    os.symlink("../top/top.gen/sources_1/bd/d_1/hw_handoff/d_1.hwh", str(out_dir / "qick_216.hwh"))
    logger.info("Firmware symlinks recreated")

    from qick import QickSoc
    soc = QickSoc(str(out_dir / "qick_216.bit"), force_init_clks=True)
    soccfg = soc
    logger.info(f"Board initialized:\n{soc}")
    return soc, soccfg


def decompose_schedule(pulse_schedule):
    """
    Decomposes schedule into non-overlapping segments with masks.
    Handles simultaneous tones and repeated frequencies on the same channel.
    All times in µs. (Copied unchanged from the notebook.)
    """
    ch_pulses = defaultdict(list)
    for tone in pulse_schedule:
        ch_pulses[tone["channel"]].append(tone)

    decomposed = []
    for ch, tones in ch_pulses.items():
        time_points = set()
        for tone in tones:
            time_points.add(tone["t_off"])
            time_points.add(tone["t_off"] + tone["pulse_length"])
        time_points = sorted(time_points)

        for i in range(len(time_points) - 1):
            t_start = time_points[i]
            t_end = time_points[i + 1]
            active = [
                tone for tone in tones
                if tone["t_off"] <= t_start and tone["t_off"] + tone["pulse_length"] >= t_end
            ]
            if active:
                decomposed.append({
                    "channel": ch,
                    "t_off": t_start,
                    "pulse_length": t_end - t_start,
                    "active_tones": active,
                })

    decomposed.sort(key=lambda p: (p["channel"], p["t_off"]))
    return decomposed


def _build_scheduled_mix_mux_prog_class():
    """ScheduledMixMuxProg needs to subclass AveragerProgramV2, which comes
    from the qick package. We build the class lazily inside a function
    (rather than at module import time) so this file can be imported for
    inspection/testing even in an environment without qick installed --
    the class only gets built the first time you actually call
    run_pulse_schedule()."""
    from qick.asm_v2 import AveragerProgramV2

    class ScheduledMixMuxProg(AveragerProgramV2):
        def _initialize(self, cfg):
            ch_tones = {}
            for tone in cfg["pulse_schedule"]:
                ch = tone["channel"]
                if ch not in ch_tones:
                    ch_tones[ch] = {}
                freq = tone["freq"]
                if freq not in ch_tones[ch]:
                    ch_tones[ch][freq] = (tone["gain"], tone["phase"])

            self.ch_freq_index = {}
            for ch, tones in ch_tones.items():
                freqs = list(tones.keys())
                gains = [tones[f][0] for f in freqs]
                phases = [tones[f][1] for f in freqs]
                self.ch_freq_index[ch] = {f: i for i, f in enumerate(freqs)}

                if (max(freqs) - min(freqs)) < F_DDS:
                    mixer_freq = (max(freqs) + min(freqs)) / 2  # center the DDS window
                else:
                    # NOTE: notebook had bare `raise("Range of frequencies to wide")`,
                    # which is invalid in Python 3 (raise needs an exception
                    # instance, not a string) -- fixed here.
                    raise ValueError("Range of frequencies too wide")

                self.declare_gen(
                    ch=ch, nqz=1, ro_ch=cfg["ro_ch"],
                    mixer_freq=mixer_freq,
                    mux_freqs=freqs,
                    mux_gains=gains,
                    mux_phases=phases
                )

            # Dummy readout
            self.declare_readout(ch=cfg["ro_ch"], length=cfg["ro_len"])  # <- no gen_ch
            first = cfg["pulse_schedule"][0]
            self.add_readoutconfig(
                ch=cfg["ro_ch"], name="myro",
                freq=first["freq"], phase=0,
                gen_ch=first["channel"]
            )

            self.decomposed = decompose_schedule(cfg["pulse_schedule"])
            for i, seg in enumerate(self.decomposed):
                ch = seg["channel"]
                freqs = [t["freq"] for t in seg["active_tones"]]
                mask = [self.ch_freq_index[ch][f] for f in freqs]
                self.add_pulse(
                    ch=ch,
                    name=f"pulse_{i}",
                    style="const",
                    length=seg["pulse_length"],
                    mask=mask
                )

        def _body(self, cfg):
            self.trigger(ros=[cfg["ro_ch"]], pins=[0], t=cfg["trig_time"])  # trigger dummy readout
            for i, seg in enumerate(self.decomposed):
                self.pulse(ch=seg["channel"], name=f"pulse_{i}", t=seg["t_off"])

    return ScheduledMixMuxProg


def run_pulse_schedule(config, soc, soccfg, reps=1000, final_delay=0.0, start_src='internal'):
    """The one function everything else in this file exists to support.
    Equivalent to your notebook's:
        prog = ScheduledMixMuxProg(soccfg, reps=reps, final_delay=final_delay, cfg=config)
        results = prog.acquire(soc)

    Args:
        config: dict with keys 'ro_ch', 'ro_len', 'trig_time', 'pulse_schedule'
                (pulse_schedule is a list of {channel, freq, gain, phase,
                pulse_length, t_off} dicts, same shape as the GUI sends).
        soc, soccfg: from initialize_board().
        reps: number of repetitions (matches ScheduledMixMuxProg's reps=).
        final_delay: matches ScheduledMixMuxProg's final_delay=.
        start_src: 'internal' (tProc fires immediately, the notebook's
            default/only behavior) or 'external' (tProc arms and waits for
            a hardware trigger signal before firing). Passed straight
            through to acquire() -- confirmed to exist on the v1
            AveragerProgram API in QICK's docs; not independently verified
            here against AveragerProgramV2 specifically, so if this raises
            a TypeError about an unexpected keyword argument, that's the
            first thing to check against your installed qick version.

    Returns:
        Whatever prog.acquire(soc) returns (typically array-like acquired
        readout data).
    """
    if not config.get('pulse_schedule'):
        raise ValueError("config['pulse_schedule'] is empty -- nothing to run")

    ScheduledMixMuxProg = _build_scheduled_mix_mux_prog_class()
    prog = ScheduledMixMuxProg(soccfg, reps=reps, final_delay=final_delay, cfg=config)
    if start_src == 'external':
        logger.info("Arming tProc for external trigger -- acquire() will block until a hardware trigger arrives")
    results = prog.acquire(soc, start_src=start_src)
    logger.info(f"Ran {len(config['pulse_schedule'])} pulse(s), reps={reps}, start_src={start_src}")
    return results


def reset_generators(soc):
    """Equivalent to the notebook's soc.reset_gens() cell -- call this
    between runs if you want the DACs silenced/reset rather than left in
    their last-programmed state."""
    soc.reset_gens()
