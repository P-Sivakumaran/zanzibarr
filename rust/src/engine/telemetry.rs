//! Bounded native observations. This module accepts no free-form text.
use once_cell::sync::Lazy;
use std::collections::VecDeque;
use std::future::Future;
use std::sync::{Arc, Mutex};
use std::time::Instant;

tokio::task_local! { static CURRENT: Arc<PlaybackTrace>; }

#[derive(Clone, Copy)]
pub enum Event {
    Started,
    SelectionFailed,
    ArchivePreparing,
    StreamPreparing,
    PreparationFailed,
    StreamReady,
    RangeRequested,
    RangeCompleted,
    RangeFailed,
    SegmentRequested,
    SegmentDecoded,
    SegmentFailed,
    NetworkFailed,
    DecodeFailed,
    ConnectionRetry,
    Cancelled,
    Finished,
}
impl Event {
    pub fn name(self) -> &'static str {
        match self {
            Self::Started => "started",
            Self::SelectionFailed => "selection_failed",
            Self::ArchivePreparing => "archive_preparing",
            Self::StreamPreparing => "stream_preparing",
            Self::PreparationFailed => "preparation_failed",
            Self::StreamReady => "stream_ready",
            Self::RangeRequested => "range_requested",
            Self::RangeCompleted => "range_completed",
            Self::RangeFailed => "range_failed",
            Self::SegmentRequested => "segment_requested",
            Self::SegmentDecoded => "segment_decoded",
            Self::SegmentFailed => "segment_failed",
            Self::NetworkFailed => "network_failed",
            Self::DecodeFailed => "decode_failed",
            Self::ConnectionRetry => "connection_retry",
            Self::Cancelled => "cancelled",
            Self::Finished => "finished",
        }
    }
}
#[derive(Clone)]
pub struct Observation {
    pub sequence: u64,
    pub elapsed_ms: u64,
    pub event: &'static str,
}
struct State {
    events: VecDeque<Observation>,
    sequence: u64,
    dropped: u64,
    finished: bool,
}
pub struct PlaybackTrace {
    started: Instant,
    state: Mutex<State>,
}
impl PlaybackTrace {
    fn new() -> Arc<Self> {
        let trace = Arc::new(Self {
            started: Instant::now(),
            state: Mutex::new(State {
                events: VecDeque::new(),
                sequence: 0,
                dropped: 0,
                finished: false,
            }),
        });
        trace.record(Event::Started);
        trace
    }
    pub fn record(&self, event: Event) {
        let mut state = self.state.lock().expect("trace lock");
        if state.finished {
            return;
        }
        state.sequence = state.sequence.saturating_add(1);
        if state.events.len() == 128 {
            state.events.pop_front();
            state.dropped = state.dropped.saturating_add(1);
        }
        let sequence = state.sequence;
        state.events.push_back(Observation {
            sequence,
            elapsed_ms: self.started.elapsed().as_millis().min(u64::MAX as u128) as u64,
            event: event.name(),
        });
    }
    pub fn snapshot(&self) -> (Vec<Observation>, u64) {
        let state = self.state.lock().expect("trace lock");
        (state.events.iter().cloned().collect(), state.dropped)
    }
    pub fn finish(&self) {
        self.record(Event::Finished);
        self.state.lock().expect("trace lock").finished = true;
    }
    pub async fn scope<F: Future>(self: Arc<Self>, future: F) -> F::Output {
        CURRENT.scope(self, future).await
    }
}
// At most four recent sessions, with no media identity, address or credentials.
type RecentTraces = VecDeque<(u64, Arc<PlaybackTrace>)>;
static RECENT: Lazy<Mutex<RecentTraces>> = Lazy::new(|| Mutex::new(VecDeque::new()));
pub fn create(session: u64) -> Arc<PlaybackTrace> {
    let trace = PlaybackTrace::new();
    let mut recent = RECENT.lock().expect("trace registry lock");
    if recent.len() == 4 {
        recent.pop_front();
    }
    recent.push_back((session, trace.clone()));
    trace
}
pub fn for_session(session: u64) -> Option<Arc<PlaybackTrace>> {
    RECENT
        .lock()
        .expect("trace registry lock")
        .iter()
        .find(|(id, _)| *id == session)
        .map(|(_, trace)| trace.clone())
}
pub fn current() -> Option<Arc<PlaybackTrace>> {
    CURRENT.try_with(Arc::clone).ok()
}
pub fn record(event: Event) {
    if let Some(trace) = current() {
        trace.record(event);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[tokio::test]
    async fn traces_are_bounded_isolated_and_closed() {
        let one = PlaybackTrace::new();
        let two = PlaybackTrace::new();
        one.clone()
            .scope(async {
                for _ in 0..200 {
                    record(Event::SegmentRequested);
                }
            })
            .await;
        let (events, dropped) = one.snapshot();
        assert_eq!(events.len(), 128);
        assert_eq!(dropped, 73);
        assert_eq!(two.snapshot().0.len(), 1);
        assert!(events.iter().all(|e| e.event == "segment_requested"));
        one.finish();
        let count = one.snapshot().0.last().unwrap().sequence;
        one.record(Event::NetworkFailed);
        assert_eq!(one.snapshot().0.last().unwrap().sequence, count);
        assert!(current().is_none());
    }
}
