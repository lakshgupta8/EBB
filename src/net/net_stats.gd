class_name NetStats
extends RefCounted
## Rolling one-second view of the connection: what the overlay shows and the bench records.

const WINDOW_MS := 1000

## Injectable so tests can move time by hand.
var clock: Callable = func(): return Time.get_ticks_msec()

var _sent: Array = []     # [t, channel, bytes]
var _recv: Array = []
var _snaps: Array = []    # t
var _corr: Array = []     # [t, px]
var _under: Array = []    # t
var _lost: Array = []     # [t, n]
var _rtt: float = 0.0
var _jitter: float = 0.0
var _have_rtt: bool = false


func _now() -> int:
	return int(clock.call())


func record_sent(channel: int, bytes: int) -> void:
	_sent.append([_now(), channel, bytes])


func record_received(channel: int, bytes: int) -> void:
	_recv.append([_now(), channel, bytes])


func record_rtt(ms: float) -> void:
	if not _have_rtt:
		_rtt = ms
		_have_rtt = true
		return
	_jitter = lerpf(_jitter, absf(ms - _rtt), 0.2)
	_rtt = lerpf(_rtt, ms, 0.2)


func record_snapshot() -> void:
	_snaps.append(_now())


func record_correction(px: float) -> void:
	_corr.append([_now(), px])


func record_underrun() -> void:
	_under.append(_now())


func record_lost(n: int) -> void:
	_lost.append([_now(), n])


static func _prune(a: Array, now_ms: int, is_scalar: bool) -> void:
	while not a.is_empty() and (int(a[0]) if is_scalar else int(a[0][0])) <= now_ms - WINDOW_MS:
		a.pop_front()


static func _sum(a: Array, channel: int) -> int:
	var total := 0
	for s in a:
		if channel < 0 or int(s[1]) == channel:
			total += int(s[2])
	return total


func report(now_ms: int) -> Dictionary:
	_prune(_sent, now_ms, false)
	_prune(_recv, now_ms, false)
	_prune(_snaps, now_ms, true)
	_prune(_corr, now_ms, false)
	_prune(_under, now_ms, true)
	_prune(_lost, now_ms, false)
	var corr_sum := 0.0
	for c in _corr:
		corr_sum += float(c[1])
	var lost := 0
	for l in _lost:
		lost += int(l[1])
	return {
		"rtt": _rtt, "jitter": _jitter,
		"bytes_in": _sum(_recv, -1), "bytes_out": _sum(_sent, -1),
		"bytes_in_0": _sum(_recv, 0), "bytes_in_1": _sum(_recv, 1),
		"bytes_out_0": _sum(_sent, 0), "bytes_out_1": _sum(_sent, 1),
		"snaps_per_s": _snaps.size(), "lost": lost,
		"corrections": _corr.size(), "mean_correction": corr_sum / float(_corr.size()) if not _corr.is_empty() else 0.0,
		"underruns": _under.size(),
	}


func csv_header() -> String:
	return "t_ms,rtt,jitter,bytes_in,bytes_out,snaps_per_s,lost,corrections,mean_correction,underruns"


func csv_row(now_ms: int) -> String:
	var r := report(now_ms)
	return "%d,%.1f,%.1f,%d,%d,%d,%d,%d,%.2f,%d" % [now_ms, r.rtt, r.jitter, r.bytes_in, r.bytes_out,
			r.snaps_per_s, r.lost, r.corrections, r.mean_correction, r.underruns]
