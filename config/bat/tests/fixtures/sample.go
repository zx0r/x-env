// Environment X Syntax Test Fixture: Go
package main

import (
	"context"
	"fmt"
	"sync"
	"time"
)

type Worker interface {
	Execute(ctx context.Context, id int) error
}

type Service struct {
	Name    string
	Workers int
	mu      sync.RWMutex
}

func NewService(name string) *Service {
	return &Service{
		Name:    name,
		Workers: 4,
	}
}

func (s *Service) Run(ctx context.Context) <-chan int {
	out := make(chan int, s.Workers)
	var wg sync.WaitGroup

	for i := 0; i < s.Workers; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			select {
			case <-ctx.Done():
				return
			case out <- id * 42:
				time.Sleep(10 * time.Millisecond)
			}
		}(i)
	}

	go func() {
		wg.Wait()
		close(out)
	}()

	return out
}

func main() {
	svc := NewService("x-worker")
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	for val := range svc.Run(ctx) {
		fmt.Printf("Received token: %d\n", val)
	}
}
