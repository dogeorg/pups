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

type Metrics struct {
    Chaintip         string `json:"chaintip"`
    Balance          string `json:"balance"`
    Addresses        string `json:"addresses"`
    TransactionCount string `json:"transaction_count"`
    UnspentCount     string `json:"unspent_count"`
}

func fetchEndpoint(endpoint string) (string, error) {
    url := fmt.Sprintf("http://0.0.0.0:8888%s", endpoint)

    client := &http.Client{
        Timeout: 10 * time.Second,
        Transport: &http.Transport{
            DisableKeepAlives: true,
        },
    }

    req, err := http.NewRequest("GET", url, nil)
    if err != nil {
        return "", fmt.Errorf("error creating request: %w", err)
    }

    req.Header.Set("Connection", "close")

    resp, err := client.Do(req)
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

func collectMetrics() (Metrics, error) {
    var metrics Metrics

    // Fetch chain tip
    chaintipStr, err := fetchEndpoint("/getChaintip")
    if err != nil {
        return metrics, err
    }
    chaintipLine := strings.TrimSpace(chaintipStr)
    if strings.HasPrefix(chaintipLine, "Chain tip: ") {
        metrics.Chaintip = strings.TrimPrefix(chaintipLine, "Chain tip: ")
    } else {
        metrics.Chaintip = chaintipLine // In case the format is different
    }

    // Fetch balance
    balanceStr, err := fetchEndpoint("/getBalance")
    if err != nil {
        return metrics, err
    }
    balanceLine := strings.TrimSpace(balanceStr)
    if strings.HasPrefix(balanceLine, "Wallet balance: ") {
        metrics.Balance = strings.TrimPrefix(balanceLine, "Wallet balance: ")
    } else {
        metrics.Balance = balanceLine // In case the format is different
    }

    // Fetch addresses
    addressesStr, err := fetchEndpoint("/getAddresses")
    if err != nil {
        return metrics, err
    }
    var addresses []string
    for _, line := range strings.Split(addressesStr, "\n") {
        line = strings.TrimSpace(line)
        if strings.HasPrefix(line, "address: ") {
            address := strings.TrimPrefix(line, "address: ")
            addresses = append(addresses, address)
        }
    }
    if len(addresses) > 0 {
        metrics.Addresses = strings.Join(addresses, "\n")
    } else {
        metrics.Addresses = "No addresses found"
    }

    // Fetch transaction count
    transactionsStr, err := fetchEndpoint("/getTransactions")
    if err != nil {
        return metrics, err
    }
    transactionCount := 0
    for _, line := range strings.Split(transactionsStr, "\n") {
        if strings.HasPrefix(line, "----------------------") {
            transactionCount++
        }
    }
    metrics.TransactionCount = fmt.Sprintf("%d", transactionCount)

    // Fetch unspent UTXO count
    utxosStr, err := fetchEndpoint("/getUTXOs")
    if err != nil {
        return metrics, err
    }
    unspentCount := 0
    for _, line := range strings.Split(utxosStr, "\n") {
        if strings.HasPrefix(line, "----------------------") {
            unspentCount++
        }
    }
    metrics.UnspentCount = fmt.Sprintf("%d", unspentCount)

    return metrics, nil
}

func submitMetrics(metrics Metrics) {
    client := &http.Client{
        Timeout: 10 * time.Second,
    }

    // Create a nested structure for the metrics data
    jsonData := map[string]interface{}{
        "chaintip":          map[string]interface{}{"value": metrics.Chaintip},
        "balance":           map[string]interface{}{"value": metrics.Balance},
        "addresses":         map[string]interface{}{"value": metrics.Addresses},
        "transaction_count": map[string]interface{}{"value": metrics.TransactionCount},
        "unspent_count":     map[string]interface{}{"value": metrics.UnspentCount},
    }

    // Marshal the data to JSON
    marshalledData, err := json.Marshal(jsonData)
    if err != nil {
        log.Printf("Error marshalling metrics: %v", err)
        return
    }

    log.Printf("Submitting metrics: %+v", jsonData)

    url := fmt.Sprintf("http://%s:%s/dbx/metrics", os.Getenv("DBX_HOST"), os.Getenv("DBX_PORT"))

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
