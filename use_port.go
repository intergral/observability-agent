package main

import (
	"fmt"
	"net/http"
)

func main() {
	port := "5432"
	fmt.Println("Listening on port", port)
	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		fmt.Println(err)
	}
}
