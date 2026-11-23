extends TestCase
## NetSim (delay, jitter, loss) and NetStats (rolling one-second window).

var PKT := PackedByteArray([1, 2, 3, 4])


func test_latency_delays_delivery() -> void:
	var s := NetSim.new()
	s.latency_ms = 100
	s.submit(PKT, 0, 0, false)
	assert_eq(s.poll(99).size(), 0)
	var due := s.poll(100)
	assert_eq(due.size(), 1)
	assert_eq(due[0].data, PKT)
	assert_eq(due[0].channel, 0)
	assert_eq(s.poll(1000).size(), 0, "delivered exactly once")


func test_loss_is_deterministic_for_seed() -> void:
	var a := NetSim.new(7)
	var b := NetSim.new(7)
	a.loss = 0.3
	b.loss = 0.3
	for i in 200:
		a.submit(PKT, 0, i, false)
		b.submit(PKT, 0, i, false)
	assert_eq(a.poll(10000).size(), b.poll(10000).size())


func test_loss_rate_close() -> void:
	var s := NetSim.new(1)
	s.loss = 0.05
	for i in 10000:
		s.submit(PKT, 0, 0, false)
	var got := s.poll(1).size()
	assert_true(got >= 9400 and got <= 9600, "got %d of 10000 at 5%% loss" % got)


func test_reliable_never_dropped() -> void:
	var s := NetSim.new()
	s.loss = 1.0
	s.latency_ms = 10
	for i in 50:
		s.submit(PKT, 1, 0, true)
	assert_eq(s.poll(10).size(), 50)


func test_reliable_keeps_order_under_jitter() -> void:
	var s := NetSim.new(3)
	s.latency_ms = 20
	s.jitter_ms = 80
	for i in 40:
		s.submit(PackedByteArray([i]), 1, i, true)
	var got := s.poll(100000)
	assert_eq(got.size(), 40)
	for i in 40:
		assert_eq(got[i].data[0], i)


func test_stats_window_and_csv() -> void:
	var t := [0]
	var st := NetStats.new()
	st.clock = func(): return t[0]
	st.record_sent(0, 100)
	st.record_sent(1, 50)
	st.record_received(0, 70)
	st.record_snapshot()
	st.record_snapshot()
	st.record_correction(4.0)
	st.record_correction(2.0)
	st.record_underrun()
	st.record_lost(3)
	st.record_rtt(50.0)
	t[0] = 500
	var r := st.report(500)
	assert_eq(r.bytes_out, 150)
	assert_eq(r.bytes_out_0, 100)
	assert_eq(r.bytes_in, 70)
	assert_eq(r.snaps_per_s, 2)
	assert_eq(r.corrections, 2)
	assert_near(r.mean_correction, 3.0)
	assert_eq(r.underruns, 1)
	assert_eq(r.lost, 3)
	assert_near(r.rtt, 50.0)
	t[0] = 1600
	var later := st.report(1600)
	assert_eq(later.bytes_out, 0, "samples older than one second fall out of the window")
	assert_eq(st.csv_header().split(",").size(), st.csv_row(1600).split(",").size())
