package main

import (
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// TestTokenBucketSerial checks the basic grant/deny behavior with no
// concurrency: a bucket of 3 tokens grants 3 then denies.
func TestTokenBucketSerial(t *testing.T) {
	b := NewTokenBucket(3, 1)
	for i := 0; i < 3; i++ {
		if !b.Acquire() {
			t.Fatalf("acquire %d denied; expected grant", i)
		}
	}
	if b.Acquire() {
		t.Fatal("4th acquire granted; bucket should be empty")
	}
}

// TestTokenBucketConcurrent is the real concurrency test: N goroutines race
// for tokens from a bucket that holds exactly K. The atomic CAS loop must
// grant EXACTLY K and deny the rest — no double-spend, no lost tokens.
func TestTokenBucketConcurrent(t *testing.T) {
	const capacity = 100
	const workers = 500

	b := NewTokenBucket(capacity, 0) // refillRate 0: no refills during the race

	var granted atomic.Int64
	var denied atomic.Int64
	var wg sync.WaitGroup

	start := make(chan struct{})
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start // release all goroutines at once to maximize contention
			if b.Acquire() {
				granted.Add(1)
			} else {
				denied.Add(1)
			}
		}()
	}
	close(start)
	wg.Wait()

	if g := granted.Load(); g != capacity {
		t.Fatalf("granted=%d, want exactly %d (double-spend or lost token)", g, capacity)
	}
	if d := denied.Load(); d != workers-capacity {
		t.Fatalf("denied=%d, want %d", d, workers-capacity)
	}
	if got := b.tokens.Load(); got != 0 {
		t.Fatalf("final token count=%d, want 0", got)
	}
}

// TestTokenBucketRefill checks that lazy refill via CAS actually accrues
// tokens over time.
func TestTokenBucketRefill(t *testing.T) {
	b := NewTokenBucket(10, 10) // 10 tokens/sec
	b.tokens.Store(0)           // drain it
	time.Sleep(1100 * time.Millisecond)
	if !b.Acquire() {
		t.Fatal("acquire denied after >1s of refill at 10/s; expected grant")
	}
}

// TestEndpoints exercises both HTTP handlers through httptest (stdlib only).
func TestEndpoints(t *testing.T) {
	srv := NewServer(2, 0)
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/":
			srv.handleRoot(w, r)
		case "/limited":
			srv.handleLimited(w, r)
		default:
			http.NotFound(w, r)
		}
	}))
	defer ts.Close()

	// root always 200
	resp, err := http.Get(ts.URL + "/")
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("root status=%d, want 200", resp.StatusCode)
	}
	resp.Body.Close()

	// limited: 2 grants then 429
	for i := 0; i < 2; i++ {
		resp, err := http.Get(ts.URL + "/limited")
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("limited #%d status=%d, want 200", i, resp.StatusCode)
		}
		resp.Body.Close()
	}
	resp, err = http.Get(ts.URL + "/limited")
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != http.StatusTooManyRequests {
		t.Fatalf("3rd limited status=%d, want 429", resp.StatusCode)
	}
	if resp.Header.Get("Retry-After") != "1" {
		t.Fatalf("Retry-After=%q, want \"1\"", resp.Header.Get("Retry-After"))
	}
	resp.Body.Close()
}
