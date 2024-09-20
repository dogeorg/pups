package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
    "strings"
    "time"
)

var httpClient *http.Client

type Metrics struct {
    Balance          string `json:"balance"`
    AddressCount     int    `json:"address_count"`
    TransactionCount int    `json:"transaction_count"`
    UnspentCount     int    `json:"unspent_count"`
    Chaintip         int    `json:"chaintip"`
}

func init() {
    httpClient = &http.Client{
        Timeout: 5 * time.Second,
        Transport: &http.Transport{
            DisableKeepAlives: true,
        },
    }
}

func fetchEndpoint(endpoint string) (string, error) {
    url := fmt.Sprintf("http://0.0.0.0:12345%s", endpoint)

    req, err := http.NewRequest("GET", url, nil)
    if err != nil {
        return "", fmt.Errorf("error creating request: %w", err)
    }

    req.Header.Set("Connection", "close")

    resp, err := httpClient.Do(req)
    if err != nil {
        return "", fmt.Errorf("error sending request to %s: %w", endpoint, err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        body, _ := io.ReadAll(resp.Body)
        return "", fmt.Errorf("unexpected status code %d for %s: %s", resp.StatusCode, endpoint, string(body))
    }

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return "", fmt.Errorf("error reading response body for %s: %w", endpoint, err)
    }

    return string(body), nil
}

func cleanBalanceOutput(output string) string {
    return strings.TrimPrefix(strings.TrimSpace(output), "Wallet balance: ")
}

func collectMetrics() (Metrics, error) {
    var metrics Metrics

    // Fetch and clean balance
    balance, err := fetchEndpoint("/getBalance")
    if err != nil {
        return metrics, err
    }
    metrics.Balance = cleanBalanceOutput(balance)

    // Fetch addresses and count them
    addresses, err := fetchEndpoint("/getAddresses")
    if err != nil {
        return metrics, err
    }
    metrics.AddressCount = strings.Count(addresses, "address: ")

    // Fetch transactions and count them
    transactions, err := fetchEndpoint("/getTransactions")
    if err != nil {
        return metrics, err
    }
    metrics.TransactionCount = strings.Count(transactions, "txid: ")

    // Fetch unspent UTXOs and count them
    utxos, err := fetchEndpoint("/getUTXOs")
    if err != nil {
        return metrics, err
    }
    metrics.UnspentCount = strings.Count(utxos, "Unspent UTXO:")

    // Fetch chain tip
    chaintip, err := fetchEndpoint("/getChaintip")
    if err != nil {
        return metrics, err
    }
    fmt.Sscanf(strings.TrimSpace(chaintip), "Chain tip: %d", &metrics.Chaintip)

    return metrics, nil
}

func submitMetrics(metrics Metrics) {
    client := &http.Client{}

    // Create a nested structure for the metrics data
    jsonData := map[string]interface{}{
        "balance":           map[string]interface{}{"value": metrics.Balance},
        "address_count":     map[string]interface{}{"value": metrics.AddressCount},
        "transaction_count": map[string]interface{}{"value": metrics.TransactionCount},
        "unspent_count":     map[string]interface{}{"value": metrics.UnspentCount},
        "chaintip":          map[string]interface{}{"value": metrics.Chaintip},
    }

    // Marshal the data to JSON
    marshalledData, err := json.Marshal(jsonData)
    if err != nil {
        log.Printf("Error marshalling metrics: %v", err)
        return
    }

    log.Printf("Submitting metrics: %+v", jsonData)

    port := os.Getenv("DBX_PORT")
    if port == "" {
        port = "8888" // Default port if not set
    }

    url := fmt.Sprintf("http://%s:%s/dbx/metrics", os.Getenv("DBX_HOST"), port)

    req, err := http.NewRequest("POST", url, bytes.NewBuffer(marshalledData))
    if err != nil {
        log.Printf("Error creating request: %v", err)
        return
    }

    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Connection", "close")

    resp, err := client.Do(req)
    if err != nil {
        log.Printf("Error sending metrics: %v", err)
        return
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        body, _ := io.ReadAll(resp.Body)
        log.Printf("Unexpected status code when submitting metrics: %d", resp.StatusCode)
        log.Printf("Response body: %s", string(body))
        return
    }

}

func main() {
    log.Println("Sleeping to give spvnode time to start...")
    time.Sleep(10 * time.Second)

    ticker := time.NewTicker(10 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ticker.C:
            metrics, err := collectMetrics()
            if err != nil {
                log.Printf("Error collecting metrics: %v", err)
                continue
            }

            log.Printf("Metrics: %+v", metrics)
            submitMetrics(metrics)

            log.Printf("----------------------------------------")
        }
    }
}
