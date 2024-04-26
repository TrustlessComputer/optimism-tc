package txmgr

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

func StoreBlob(url string, data []byte) (string, error) {
	start := time.Now()
	defer func() {
		duration := time.Since(start)
		fmt.Println("da store data time process", duration, "len", len(data))
	}()
	//base64 encode data
	base64Data := base64.StdEncoding.EncodeToString(data)

	// Data for the POST request
	requestData := map[string]string{
		"data": base64Data,
	}

	// Convert the data to JSON
	jsonData, err := json.Marshal(requestData)
	if err != nil {
		return "", err
	}

	// Create a new request using http
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", err
	}

	// Set the Content-Type header
	req.Header.Set("Content-Type", "application/json")

	// Send the request using http.Client
	client := &http.Client{
		Timeout: time.Second * 120, // Set the timeout to 10 seconds
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Println("error  when read body response from da ", err.Error())
		return "", err
	}
	if resp.Status != "200 OK" {
		fmt.Println("error  when read body response from da code ", resp.Status, "body", string(body))
		return "", fmt.Errorf("Error: %s", resp.Status)
	}
	// Read the response body

	return string(body), nil
}

func GetBlob(url string) ([]byte, error) {

	// Create a new request using http
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	// Send the request using http.Client
	client := &http.Client{
		Timeout: time.Second * 60, // Set the timeout to 10 seconds
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	return body, nil
}
