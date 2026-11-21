// SPDX-License-Identifier: GPL-2.0-or-later
// Sync-only extraction of the accepted offset renderer; audio modules excluded.
#include "connector.hpp"
#include <cstdlib>
#include <lv2/core/lv2.h>
#include <lv2/state/state.h>
namespace {
using namespace hector;
struct Plugin {
  double rate;
  Connector connector;
  uint64_t connectionEpoch = 0;
  std::array<float *, 15> ports{};
  SampleClock clock;
  Timeline timeline;
  bool initializedControls = false;
  int64_t lastTick = INT64_MIN;
  double lastTempo = -1, lastTransport = -2, lastQuantum = -1, lastEnable = -1,
         lastSS = -1;
  int pulse = 0, reset = 0;
  bool previousPlaying = false;
  Plugin(double r, const char *path) : rate(r), connector(false, path) {}
  double input(unsigned i, double d = 0) const {
    return ports[i] ? cleanNumber(*ports[i], d) : d;
  }
  void output(unsigned i, float v) { if (ports[i]) *ports[i] = v; }
  void changed(double v, double &old, std::atomic<uint64_t> &dst, bool floating = false) {
    if (v != old) { dst.store(floating ? bits(v) : uint64_t(v), std::memory_order_release); old = v; }
  }
  void run(uint32_t n) {
    if (!n) return;
    const int64_t start = clock.advance(n, rate);
    Connector::Pin pin(connector);
    auto *s = pin.ptr;
    if (pin.epoch != connectionEpoch) {
      connectionEpoch = pin.epoch; initializedControls = false;
      lastEnable = lastSS = lastQuantum = -1;
    }
    const bool healthy = s && s->heartbeat.load(std::memory_order_acquire) > uint64_t(nowUs() - 500000);
    if (healthy) s->syncRunHeartbeat.store(nowUs(), std::memory_order_release);
    if (s) {
      // Restored controls are preferences, never new session commands.
      if (!initializedControls) {
        lastTempo = input(2);
        lastTransport = input(5, -1);
        initializedControls = true;
      }
      changed(input(0) > .5, lastEnable, s->enable);
      changed(input(1) > .5, lastSS, s->startStop);
      const auto tempo = std::clamp(input(2), 0., 999.);
      if (tempo > 0 && tempo != lastTempo)
        s->requestedTempo.store(bits(tempo), std::memory_order_release);
      lastTempo = tempo;
      changed(std::clamp(input(3, 4), 1., 32.), lastQuantum,
              s->requestedQuantum, true);
      const auto transport = input(5, -1);
      if (transport != lastTransport && transport >= 0)
        s->requestedTransport.store(transport > 0 ? 2 : 1,
                                    std::memory_order_release);
      lastTransport = transport;
    }
    if (healthy)
      s->snapshot(timeline);
    const bool enabled = healthy && s->enable.load();
    const int ppq = int(std::clamp(input(4, 1), 1., 24.));
    // Only Clock is adjustable. Existing Reset remains exactly 1 ms.
    const int resetWidth = std::max(1, int(rate * 0.001));
    const double requestedWidth = input(14, 1);
    const int widthMs = requestedWidth == 5 ? 5 : requestedWidth == 10 ? 10 : 1;
    // Preserve distinct clock edges even when 5/10 ms exceeds half a period.
    const double bpm = std::max(1., cleanNumber(timeline.bpm, 120));
    const int halfPeriod = std::max(1, int(rate * 30. / (bpm * ppq)));
    const int clockWidth = std::min(std::max(1, int(rate * widthMs / 1000.)), halfPeriod);
    // Positive offset emits local timing later; the network timeline is unchanged.
    const int64_t offsetUs = int64_t(std::llround(std::clamp(input(13), -500., 500.) * 1000.));
    for (uint32_t i = 0; i < n; ++i) {
      const int64_t localTime = start + int64_t(i * 1000000. / rate) - offsetUs;
      const double beat = beatAt(timeline, localTime);
      const auto tick = int64_t(std::floor(beat * ppq));
      const bool playing =
          enabled && timeline.playing &&
          localTime >= timeline.transportTime;
      if (playing) {
        if (!previousPlaying) {
          reset = resetWidth;
          lastTick = tick;
          pulse = clockWidth;
        } else if (tick != lastTick) {
          pulse = clockWidth;
          lastTick = tick;
        }
      } else {
        pulse = reset = 0;
        lastTick = tick;
      }
      previousPlaying = playing;
      if (ports[7])
        ports[7][i] = pulse > 0 ? 1 : 0;
      if (ports[8])
        ports[8][i] = previousPlaying ? 1 : 0;
      if (ports[9])
        ports[9][i] = reset > 0 ? 1 : 0;
      if (ports[10])
        ports[10][i] = enabled ? float((beat / timeline.quantum) -
                                       std::floor(beat / timeline.quantum))
                               : 0;
      if (pulse > 0)
        --pulse;
      if (reset > 0)
        --reset;
    }
    output(6, float(timeline.bpm));
    output(11, healthy ? float(timeline.peers) : 0);
    output(12, healthy ? 1 : 0);
  }
};
LV2_Handle instantiate(const LV2_Descriptor *, double rate, const char *, const LV2_Feature *const *) {
  if (!std::isfinite(rate) || rate < 8000 || rate > 192000) return nullptr;
  try { const char *path = std::getenv("HECTOR_LINK_SYNC_SESSION");
    return new Plugin(rate, path ? path : "/run/hector-link-sync/session");
  } catch (...) { return nullptr; }
}
void connect(LV2_Handle h, uint32_t p, void *v) { if(p<15) static_cast<Plugin *>(h)->ports[p]=static_cast<float *>(v); }
void run(LV2_Handle h,uint32_t n) { static_cast<Plugin *>(h)->run(n); }
void cleanup(LV2_Handle h) { delete static_cast<Plugin *>(h); }
LV2_State_Status save(LV2_Handle, LV2_State_Store_Function, LV2_State_Handle, uint32_t, const LV2_Feature *const *) { return LV2_STATE_SUCCESS; }
LV2_State_Status restore(LV2_Handle, LV2_State_Retrieve_Function, LV2_State_Handle, uint32_t, const LV2_Feature *const *) { return LV2_STATE_SUCCESS; }
const void *extension(const char *uri) { static const LV2_State_Interface state{save,restore}; return !std::strcmp(uri,LV2_STATE__interface)? &state:nullptr; }
const LV2_Descriptor descriptor{kSyncUri,instantiate,connect,nullptr,run,nullptr,cleanup,extension};
}
extern "C" LV2_SYMBOL_EXPORT const LV2_Descriptor *lv2_descriptor(uint32_t i) {return i==0? &descriptor:nullptr;}
