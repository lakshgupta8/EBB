# Demo checklist: Co-op and PvP

Two laptops, same build on both. About 10 minutes.

## Before the day

- [ ] Both laptops run the same version (the title shows `EBB x.y.z` bottom right; a mismatch is refused
      with a clear message, which is itself a nice thing to show).
- [ ] Build or copy the same exe/project to both. Test once on the venue's network if possible.
- [ ] Windows Firewall: allow the game on private networks (a prompt appears the first time the host opens
      a session), or add an inbound UDP rule for port 24680.
- [ ] Run `tools/test.ps1` and `tools/net_sim.ps1` once on the day before; keep the output.
- [ ] Have `docs/NETWORKING.md` and `docs/net/measurements.csv` open, and a recorded fallback video of the
      one-machine run (two game windows on 127.0.0.1) in case the venue network blocks UDP.

## Getting connected

1. Put both laptops on the same Wi-Fi, a phone hotspot, or one Ethernet cable between them.
   Some venues isolate wireless clients from each other; if the join fails, switch to the hotspot.
2. Host: title → **Two keepers** → **Host a night**. The screen shows the address to give out.
3. Guest: title → **Two keepers**, type the address, **Join**. Both land in the lobby and see the link time.
4. Different versions: the guest sees "version mismatch" (expected, good to know).
5. Over the internet instead: both join the same Tailscale network and use the host's Tailscale address.

## What to show

1. **Lobby:** mode toggle (host), ready on both sides, the link time (RTT) updating.
2. **Co-op:** start; fight 2–3 rooms with the guest in the room. Point out: the guest's own keeper moves
   with no delay (prediction); enemies and the host's keeper are smooth (interpolation); hits and deaths show
   on both screens.
3. **F3** on the guest: RTT, bytes per second, snapshots per second, corrections.
4. **F4** sliders on the guest: add 100 ms latency and 5 % loss while playing. The local keeper stays
   responsive, remote things get slightly delayed but stay smooth, corrections rise. Reset to zero.
5. **Boss** (if reached): telegraph flashes and phase changes arrive on the guest as events.
6. **Fall and revive:** let one keeper fall; the night continues until both are down; clearing the room
   revives them.
7. **PvP:** leave to the lobby, host switches the mode to duel, ready, start. Best of three; two falls in the
   same moment is a draw and the round repeats.
8. **Disconnect:** pull the cable or close one window: the other returns to the menu with a message after
   at most 5 seconds, and the host's real save is untouched.

## If something goes wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| Guest stays on "reaching the other keeper" | Firewall, wrong address, client isolation on Wi-Fi | Allow UDP 24680, check the address, use a hotspot or cable |
| "could not connect" after 5 s | Same as above | Same |
| "version mismatch" | Different builds | Copy the same build to both |
| Guest sees nothing after Start | Room message missed | It resends on its own (`RESYNC`); if not, leave and rejoin |
| Everything feels slow | Wi-Fi congestion | F3: RTT above 100 ms; move to a hotspot or cable |

## Rehearsal log

Record here after the rehearsal on two real machines: date, network, build, what worked, what did not.
