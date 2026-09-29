package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"sync/atomic"
	"time"
)

// ---------------------------------------------------------------------------
// TokenBucket is a lock-free rate limiter built entirely on sync/atomic.
//
// It stores the current token count as a single atomic int64. Refills happen
// lazily: on each Acquire we compute how many tokens should have accrued since
// the last refill and CAS them into the counter. No mutex, no channel, no
// goroutine — just compare-and-swap.
//
//	capacity  = max tokens the bucket can hold
//	refillRate = tokens added per second
//
// ---------------------------------------------------------------------------
type TokenBucket struct {
	capacity   int64
	refillRate int64
	tokens     atomic.Int64 // current token count
	lastRefill atomic.Int64 // unix nanoseconds of last refill
}

func NewTokenBucket(capacity, refillRate int64) *TokenBucket {
	b := &TokenBucket{
		capacity:   capacity,
		refillRate: refillRate,
	}
	b.tokens.Store(capacity)
	b.lastRefill.Store(time.Now().UnixNano())
	return b
}

// Acquire attempts to take one token. Returns true if granted.
//
// The refill step is a CAS loop: we read the last refill time, compute the
// elapsed tokens, and try to swap in (oldTokens + accrued). If another
// goroutine wins the CAS first, we retry with the fresh values. This is the
// classic lock-free pattern — no critical section, no blocking.
func (b *TokenBucket) Acquire() bool {
	now := time.Now().UnixNano()

	for {
		last := b.lastRefill.Load()
		elapsed := now - last
		if elapsed <= 0 {
			break // clock skew / same nanosecond: no refill due
		}

		accrued := (elapsed * b.refillRate) / int64(time.Second)
		if accrued <= 0 {
			break // less than one token's worth of time passed
		}

		cur := b.tokens.Load()
		next := cur + accrued
		if next > b.capacity {
			next = b.capacity
		}

		// Try to claim the refill atomically. If we lose the race, loop again
		// and recompute against the winner's updated lastRefill.
		if b.lastRefill.CompareAndSwap(last, now) {
			b.tokens.CompareAndSwap(cur, next)
			break
		}
	}

	// Now spend a token. CAS cur -> cur-1; if it fails, another goroutine
	// spent one first, so re-read and retry.
	for {
		cur := b.tokens.Load()
		if cur <= 0 {
			return false // bucket empty: request denied
		}
		if b.tokens.CompareAndSwap(cur, cur-1) {
			return true
		}
	}
}

// ---------------------------------------------------------------------------
// Stats tracks server-wide counters with atomics so they can be read without
// stopping the world.
// ---------------------------------------------------------------------------
type Stats struct {
	requests atomic.Int64
	granted  atomic.Int64
	denied   atomic.Int64
	inFlight atomic.Int64
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------
type Server struct {
	bucket *TokenBucket
	stats  *Stats
}

func NewServer(capacity, refillRate int64) *Server {
	return &Server{
		bucket: NewTokenBucket(capacity, refillRate),
		stats:  &Stats{},
	}
}

// handleRoot is the plain endpoint: always 200, reports live counters.
func (s *Server) handleRoot(w http.ResponseWriter, r *http.Request) {
	s.stats.requests.Add(1)
	s.stats.inFlight.Add(1)
	defer s.stats.inFlight.Add(-1)

	fmt.Fprintf(w, "ok\nrequests=%d granted=%d denied=%d in_flight=%d\n",
		s.stats.requests.Load(),
		s.stats.granted.Load(),
		s.stats.denied.Load(),
		s.stats.inFlight.Load(),
	)
}

// handleLimited is the concurrency endpoint: it runs the atomic token-bucket
// algorithm and returns 429 when the bucket is dry.
func (s *Server) handleLimited(w http.ResponseWriter, r *http.Request) {
	s.stats.requests.Add(1)
	s.stats.inFlight.Add(1)
	defer s.stats.inFlight.Add(-1)

	if s.bucket.Acquire() {
		s.stats.granted.Add(1)
		fmt.Fprintf(w, "granted\nremaining=%d\n", s.bucket.tokens.Load())
		return
	}

	s.stats.denied.Add(1)
	w.Header().Set("Retry-After", "1")
	http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
}

func main() {
	capacity := int64(10)
	refillRate := int64(5) // 5 tokens/sec

	srv := NewServer(capacity, refillRate)

	mux := http.NewServeMux()
	mux.HandleFunc("/", srv.handleRoot)
	mux.HandleFunc("/limited", srv.handleLimited)

	addr := ":8080"
	if len(os.Args) > 1 {
		addr = os.Args[1]
	}

	log.Printf("listening on %s (bucket capacity=%d refill=%d/s)", addr, capacity, refillRate)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}
